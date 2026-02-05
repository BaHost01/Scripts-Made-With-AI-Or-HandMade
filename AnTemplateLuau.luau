--[[ 
Horror Framework Creator (MP + First Person + Sanity Hallucinations)
Paste in Roblox Studio Command Bar and run.

Cria:
- ReplicatedStorage/Remotes + Modules (configs)
- ServerScriptService services (GameLoop, SanityService, MonsterService placeholder)
- StarterPlayerScripts (SanityClient, HallucinationsClient, PostFX)
- StarterGui (HUD básico com sanity/hunger + clock fake)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")

local function ensure(parent, className, name)
	local obj = parent:FindFirstChild(name)
	if obj and obj.ClassName ~= className then
		obj:Destroy()
		obj = nil
	end
	if not obj then
		obj = Instance.new(className)
		obj.Name = name
		obj.Parent = parent
	end
	return obj
end

local function createScript(parent, className, name, source)
	local s = ensure(parent, className, name)
	-- Source property exists in Studio environment
	s.Source = source
	return s
end

local function stamp()
	return ("-- generated %s\n"):format(os.date("!%Y-%m-%dT%H:%M:%SZ"))
end

-- =============== ReplicatedStorage ===============
local RS_Remotes = ensure(ReplicatedStorage, "Folder", "Remotes")
local RS_Modules = ensure(ReplicatedStorage, "Folder", "Modules")

ensure(RS_Remotes, "RemoteEvent", "SanityFX")        -- server -> client (trigger spike/breakdown)
ensure(RS_Remotes, "RemoteEvent", "ClockSync")       -- server -> client (optional fake clock drift)
ensure(RS_Remotes, "RemoteFunction", "GetServerState") -- client asks for night/time

-- Config Modules
createScript(RS_Modules, "ModuleScript", "SanityConfig", stamp() .. [[
local SanityConfig = {}

-- Core ranges
SanityConfig.MAX_SANITY = 100
SanityConfig.MIN_SANITY = 0

-- Drain rates (per second)
SanityConfig.DRAIN_BASE = 0.08
SanityConfig.DRAIN_IN_DARK = 0.35
SanityConfig.DRAIN_HUNGER_LOW = 0.22
SanityConfig.DRAIN_MONSTER_NEAR = 0.55

-- Recovery rates (per second)
SanityConfig.RECOVER_IN_LIGHT = 0.28
SanityConfig.RECOVER_SAFEZONE = 0.22

-- Breakdown (when sanity hits 0)
SanityConfig.BREAKDOWN_DURATION_MIN = 25
SanityConfig.BREAKDOWN_DURATION_MAX = 45
SanityConfig.BREAKDOWN_MIN_RETURN = 12      -- after breakdown, sanity returns to at least this
SanityConfig.BREAKDOWN_COOLDOWN = 60        -- seconds before another breakdown can trigger

-- Hallucination intensity thresholds
SanityConfig.T1 = 60 -- mild
SanityConfig.T2 = 30 -- heavy
SanityConfig.T3 = 1  -- extreme

return SanityConfig
]])

createScript(RS_Modules, "ModuleScript", "NightConfig", stamp() .. [[
local NightConfig = {}

-- Time
NightConfig.NIGHT_START_CLOCKTIME = 0      -- 12 AM
NightConfig.NIGHT_END_CLOCKTIME = 7        -- 7 AM
NightConfig.NIGHT_DURATION_SECONDS = 420   -- 7 minutes per night (tune)
NightConfig.DAY_DURATION_SECONDS = 120     -- preparation time (tune)

NightConfig.TARGET_NIGHTS = 6

-- Scaling
NightConfig.SCALE_SANITY_DRAIN_PER_NIGHT = 0.05 -- increases base drain
NightConfig.SCALE_EVENT_CHANCE_PER_NIGHT = 0.03

return NightConfig
]])

-- =============== Server scripts ===============
local SSS = ServerScriptService
local ServicesFolder = ensure(SSS, "Folder", "Services")

createScript(ServicesFolder, "Script", "GameLoop", stamp() .. [[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local NightConfig = require(ReplicatedStorage.Modules.NightConfig)

local Remotes = ReplicatedStorage.Remotes
local ClockSync = Remotes.ClockSync
local GetServerState = Remotes.GetServerState

local state = {
	Night = 1,
	IsNight = true,
	PhaseTime = 0, -- seconds elapsed in current phase
	ServerStart = os.clock(),
}

local function setClockProgress(t)
	-- Linear interpolation between start and end ClockTime
	local startCT = NightConfig.NIGHT_START_CLOCKTIME
	local endCT = NightConfig.NIGHT_END_CLOCKTIME
	local alpha = math.clamp(t / NightConfig.NIGHT_DURATION_SECONDS, 0, 1)
	Lighting.ClockTime = startCT + (endCT - startCT) * alpha
end

local function beginNight()
	state.IsNight = true
	state.PhaseTime = 0
	Lighting.ClockTime = NightConfig.NIGHT_START_CLOCKTIME
end

local function beginDay()
	state.IsNight = false
	state.PhaseTime = 0
	-- Daytime look (you can customize)
	Lighting.ClockTime = 12
end

GetServerState.OnServerInvoke = function(player)
	return {
		Night = state.Night,
		IsNight = state.IsNight,
		PhaseTime = state.PhaseTime,
		ClockTime = Lighting.ClockTime,
		ServerNow = os.clock(),
	}
end

-- Main loop
task.spawn(function()
	beginNight()
	while true do
		task.wait(1)
		state.PhaseTime += 1

		if state.IsNight then
			setClockProgress(state.PhaseTime)

			-- Optional: send slight drift to clients for fake UI clocks
			ClockSync:FireAllClients({
				Night = state.Night,
				IsNight = true,
				ServerClockTime = Lighting.ClockTime,
				DriftSeconds = math.random(-9, 9), -- clients can use this to lie
			})

			if state.PhaseTime >= NightConfig.NIGHT_DURATION_SECONDS then
				beginDay()
			end
		else
			ClockSync:FireAllClients({
				Night = state.Night,
				IsNight = false,
				ServerClockTime = Lighting.ClockTime,
				DriftSeconds = math.random(-5, 5),
			})

			if state.PhaseTime >= NightConfig.DAY_DURATION_SECONDS then
				state.Night += 1
				beginNight()
			end
		end
	end
end)
]])

createScript(ServicesFolder, "Script", "SanityService", stamp() .. [[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local SanityConfig = require(ReplicatedStorage.Modules.SanityConfig)
local NightConfig = require(ReplicatedStorage.Modules.NightConfig)

local Remotes = ReplicatedStorage.Remotes
local SanityFX = Remotes.SanityFX
local GetServerState = Remotes.GetServerState

-- Attributes on Player:
-- Sanity (0..100)
-- Hunger (0..100)
-- InSafeZone (bool)
-- LastBreakdown (server time)

local function setDefaultAttributes(plr)
	if plr:GetAttribute("Sanity") == nil then plr:SetAttribute("Sanity", SanityConfig.MAX_SANITY) end
	if plr:GetAttribute("Hunger") == nil then plr:SetAttribute("Hunger", 100) end
	if plr:GetAttribute("InSafeZone") == nil then plr:SetAttribute("InSafeZone", false) end
	if plr:GetAttribute("LastBreakdown") == nil then plr:SetAttribute("LastBreakdown", -1e9) end
end

local function isDarkAround(char)
	-- Simple heuristic: if it's night-ish OR player's light is off (client can still show effects)
	-- Server shouldn't trust client flashlight state for core, so we use environment time.
	local ct = Lighting.ClockTime
	-- treat 0..6 and 18..24 as dark
	return (ct >= 18 or ct <= 6)
end

local function getNight()
	local ok, s = pcall(function() return GetServerState:InvokeServer() end)
	if ok and s then return s.Night, s.IsNight end
	return 1, true
end

local function clamp01(x, a, b)
	if x < a then return a end
	if x > b then return b end
	return x
end

local function tickPlayer(plr, dt, currentNight, isNight)
	local sanity = plr:GetAttribute("Sanity") or SanityConfig.MAX_SANITY
	local hunger = plr:GetAttribute("Hunger") or 100
	local inSafe = plr:GetAttribute("InSafeZone") == true

	-- Hunger decay (server authoritative)
	local hungerDecay = isNight and 0.05 or 0.03
	hunger = clamp01(hunger - hungerDecay * dt, 0, 100)
	plr:SetAttribute("Hunger", hunger)

	-- Base drain scales by night
	local scale = 1 + (currentNight - 1) * NightConfig.SCALE_SANITY_DRAIN_PER_NIGHT
	local drain = SanityConfig.DRAIN_BASE * scale

	-- Dark increases drain
	if isNight and isDarkAround(plr.Character) then
		drain += SanityConfig.DRAIN_IN_DARK * scale
	end

	-- Hunger low increases drain
	if hunger <= 25 then
		drain += SanityConfig.DRAIN_HUNGER_LOW * scale
	end

	-- Safe/light recovery
	local recover = 0
	if not isNight then
		recover += SanityConfig.RECOVER_IN_LIGHT
	end
	if inSafe then
		recover += SanityConfig.RECOVER_SAFEZONE
	end

	-- Net change
	local delta = (recover - drain) * dt
	sanity = clamp01(sanity + delta, SanityConfig.MIN_SANITY, SanityConfig.MAX_SANITY)

	-- Breakdown trigger (sanity hits 0)
	if sanity <= 0 then
		local now = os.clock()
		local last = plr:GetAttribute("LastBreakdown") or -1e9
		if (now - last) >= SanityConfig.BREAKDOWN_COOLDOWN then
			plr:SetAttribute("LastBreakdown", now)

			local duration = math.random(SanityConfig.BREAKDOWN_DURATION_MIN, SanityConfig.BREAKDOWN_DURATION_MAX)
			-- Tell only that client to go insane (visual/audio hallucinations)
			SanityFX:FireClient(plr, {
				Type = "BREAKDOWN",
				Duration = duration,
				Night = currentNight,
			})

			-- After breakdown, bring sanity back so the player isn't trapped at 0 forever
			task.delay(duration, function()
				if plr.Parent then
					local sNow = plr:GetAttribute("Sanity") or 0
					local target = math.max(sNow, SanityConfig.BREAKDOWN_MIN_RETURN)
					plr:SetAttribute("Sanity", target)
					-- Small "aftershock"
					SanityFX:FireClient(plr, { Type = "AFTERSHOCK", Duration = 8 })
				end
			end)
		else
			-- In cooldown, keep at 0 but do not retrigger
			sanity = 0
		end
	else
		-- Occasional spike events when low sanity (server chooses, client renders)
		if sanity <= SanityConfig.T2 and math.random() < (0.01 * scale) then
			SanityFX:FireClient(plr, { Type = "SPIKE", Duration = math.random(2,4) })
		end
	end

	plr:SetAttribute("Sanity", sanity)
end

Players.PlayerAdded:Connect(function(plr)
	setDefaultAttributes(plr)
	plr.CharacterAdded:Connect(function()
		setDefaultAttributes(plr)
	end)
end)

for _, plr in ipairs(Players:GetPlayers()) do
	setDefaultAttributes(plr)
end

-- Main tick
local accum = 0
RunService.Heartbeat:Connect(function(dt)
	accum += dt
	if accum < 0.25 then return end -- tick 4x per second
	dt = accum
	accum = 0

	-- Read server state (cheap)
	-- We'll approximate night using Lighting.ClockTime + Day/Night loop set in GameLoop
	local ct = Lighting.ClockTime
	local isNight = (ct <= 7 or ct >= 18)

	-- Approx night number based on time sync from GameLoop via Attribute not present, so we infer:
	-- Better: store Night as Lighting Attribute in GameLoop if you want. For now, keep simple:
	local nightGuess = math.max(1, math.floor((os.clock() / 600)) + 1)

	for _, plr in ipairs(Players:GetPlayers()) do
		tickPlayer(plr, dt, nightGuess, isNight)
	end
end)
]])

createScript(ServicesFolder, "Script", "MonsterService", stamp() .. [[
-- Placeholder: aqui você vai colocar IA REAL (server authoritative).
-- Mantém isso vazio por enquanto pra não virar bagunça.

-- Ideia:
-- - Spawner por noite
-- - State machine: Stalk -> Test -> Attack -> Retreat
-- - Server decide, client só vê/anima

print("MonsterService loaded (placeholder).")
]])

-- =============== StarterPlayerScripts (Client) ===============
local SPS = ensure(StarterPlayer, "Folder", "StarterPlayerScripts")

createScript(SPS, "LocalScript", "SanityClient", stamp() .. [[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SanityFX = Remotes:WaitForChild("SanityFX")
local ClockSync = Remotes:WaitForChild("ClockSync")

local sanity = 100
local hunger = 100

local fakeClock = {
	drift = 0,
	serverClockTime = 0,
	isNight = true,
	night = 1,
}

local function getAttr(name, fallback)
	local v = player:GetAttribute(name)
	if v == nil then return fallback end
	return v
end

ClockSync.OnClientEvent:Connect(function(payload)
	fakeClock.drift = payload.DriftSeconds or 0
	fakeClock.serverClockTime = payload.ServerClockTime or 0
	fakeClock.isNight = payload.IsNight
	fakeClock.night = payload.Night
end)

-- Keep camera first-person (soft)
local function enforceFirstPerson()
	player.CameraMode = Enum.CameraMode.LockFirstPerson
end

enforceFirstPerson()
player:GetPropertyChangedSignal("CameraMode"):Connect(enforceFirstPerson)

RunService.RenderStepped:Connect(function()
	sanity = getAttr("Sanity", sanity)
	hunger = getAttr("Hunger", hunger)

	-- Update HUD if exists
	local gui = player:FindFirstChild("PlayerGui")
	if not gui then return end
	local hud = gui:FindFirstChild("HorrorHUD")
	if not hud then return end

	local stats = hud:FindFirstChild("Stats")
	if stats then
		stats.SanityValue.Text = ("SANITY: %d"):format(math.floor(sanity + 0.5))
		stats.HungerValue.Text = ("HUNGER: %d"):format(math.floor(hunger + 0.5))
	end

	-- Fake clock UI: lie when sanity is low (client-side deception)
	local clock = hud:FindFirstChild("Clock")
	if clock then
		local t = fakeClock.serverClockTime
		local s = sanity
		local lie = 0

		if s <= 60 and s > 30 then lie = math.random(-1, 1) end
		if s <= 30 and s > 1 then lie = math.random(-2, 2) end
		if s <= 1 then lie = math.random(-4, 4) end

		local shown = (t + (fakeClock.drift or 0) / 60) + lie
		local hh = math.floor(shown) % 24
		local mm = math.floor((shown - math.floor(shown)) * 60)

		clock.ClockText.Text = ("Night %d | %02d:%02d"):format(fakeClock.night or 1, hh, mm)
	end
end)
]])

createScript(SPS, "LocalScript", "PostFX", stamp() .. [[
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- Create post effects once
local blur = Lighting:FindFirstChild("SanityBlur") or Instance.new("BlurEffect")
blur.Name = "SanityBlur"
blur.Parent = Lighting

local cc = Lighting:FindFirstChild("SanityColor") or Instance.new("ColorCorrectionEffect")
cc.Name = "SanityColor"
cc.Parent = Lighting

local function getAttr(name, fallback)
	local v = player:GetAttribute(name)
	if v == nil then return fallback end
	return v
end

RunService.RenderStepped:Connect(function(dt)
	local sanity = getAttr("Sanity", 100)

	-- Map sanity -> intensity
	local t = math.clamp(1 - (sanity / 100), 0, 1) -- 0 good, 1 bad

	blur.Size = 0 + (18 * t)
	cc.Contrast = 0 + (0.35 * t)
	cc.Saturation = 0 - (0.55 * t)
	cc.Brightness = 0 - (0.08 * t)
end)
]])

createScript(SPS, "LocalScript", "HallucinationsClient", stamp() .. [[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SanityConfig = require(ReplicatedStorage.Modules.SanityConfig)

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local Remotes = ReplicatedStorage.Remotes
local SanityFX = Remotes.SanityFX

-- Audio (client-only lies)
local folder = SoundService:FindFirstChild("HallucinationSounds") or Instance.new("Folder")
folder.Name = "HallucinationSounds"
folder.Parent = SoundService

local function mkSound(name, soundId, volume)
	local s = folder:FindFirstChild(name) or Instance.new("Sound")
	s.Name = name
	s.SoundId = soundId
	s.Volume = volume or 0.3
	s.Looped = false
	s.Parent = folder
	return s
end

-- Put any placeholder IDs you want later
local whisper = mkSound("Whisper", "rbxassetid://9118828567", 0.25)
local knock = mkSound("Knock", "rbxassetid://9118826040", 0.25)
local breath = mkSound("Breath", "rbxassetid://9118827765", 0.22)

local breakdownActive = false
local breakdownEndsAt = 0

local function getSanity()
	return player:GetAttribute("Sanity") or 100
end

local function intensityFromSanity(s)
	if s > SanityConfig.T1 then return 0 end
	if s > SanityConfig.T2 then return 1 end
	if s > SanityConfig.T3 then return 2 end
	return 3
end

local function spawnPhantom()
	-- Spawn a client-only "shadow" crossing view
	if not camera then return end

	local part = Instance.new("Part")
	part.Name = "Phantom"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Transparency = 0.35
	part.Material = Enum.Material.SmoothPlastic
	part.Color = Color3.new(0, 0, 0)
	part.Size = Vector3.new(1.5, 3.5, 0.6)

	-- Spawn relative to camera
	local cf = camera.CFrame
	local right = cf.RightVector
	local forward = cf.LookVector
	local up = cf.UpVector

	local startPos = cf.Position + right * (-10) + forward * 8 + up * (-1)
	local endPos = cf.Position + right * (10) + forward * 8 + up * (-1)

	part.CFrame = CFrame.new(startPos, startPos + forward)
	part.Parent = Workspace

	local t = TweenService:Create(part, TweenInfo.new(0.7, Enum.EasingStyle.Linear), {
		CFrame = CFrame.new(endPos, endPos + forward),
		Transparency = 1
	})
	t:Play()
	t.Completed:Connect(function()
		part:Destroy()
	end)
end

local function fakePrompt()
	-- Creates a quick fake center text prompt
	local gui = player:FindFirstChild("PlayerGui")
	if not gui then return end
	local hud = gui:FindFirstChild("HorrorHUD")
	if not hud then return end

	local p = hud:FindFirstChild("FakePrompt")
	if not p then return end

	p.Visible = true
	p.TextLabel.Text = (math.random() < 0.5) and "LOCK DOOR (E)" or "HIDE (E)"
	task.delay(math.random(1,2), function()
		if p then p.Visible = false end
	end)
end

local function microShake(duration, magnitude)
	local start = os.clock()
	local base = camera.CFrame
	while os.clock() - start < duration do
		RunService.RenderStepped:Wait()
		if not camera then break end
		local dx = (math.random() - 0.5) * magnitude
		local dy = (math.random() - 0.5) * magnitude
		camera.CFrame = base * CFrame.new(dx, dy, 0)
	end
	-- let Roblox camera resume
end

SanityFX.OnClientEvent:Connect(function(payload)
	if payload.Type == "BREAKDOWN" then
		breakdownActive = true
		breakdownEndsAt = os.clock() + (payload.Duration or 30)

		-- Strong effects burst
		task.spawn(function() microShake(1.6, 0.25) end)
		task.spawn(function()
			for i=1, math.random(3,6) do
				whisper:Play()
				task.wait(math.random(1,2))
			end
		end)
	elseif payload.Type == "SPIKE" then
		task.spawn(function() microShake(payload.Duration or 2, 0.08) end)
		if math.random() < 0.7 then knock:Play() else breath:Play() end
	elseif payload.Type == "AFTERSHOCK" then
		task.spawn(function() microShake(payload.Duration or 6, 0.05) end)
	end
end)

-- Main hallucination loop
task.spawn(function()
	while true do
		task.wait(0.4)

		local s = getSanity()
		local tier = intensityFromSanity(s)

		-- During breakdown, force max tier
		if breakdownActive then
			tier = 3
			if os.clock() >= breakdownEndsAt then
				breakdownActive = false
			end
		end

		-- Nothing when sane
		if tier == 0 then
			continue
		end

		-- Tier-based random events (client-only lies)
		local chance = (tier == 1 and 0.06) or (tier == 2 and 0.12) or 0.18

		if math.random() < chance then
			local roll = math.random(1, 3 + tier)
			if roll <= 2 then
				spawnPhantom()
			elseif roll == 3 then
				fakePrompt()
			else
				-- audio
				if math.random() < 0.5 then whisper:Play() else knock:Play() end
			end
		end
	end
end)
]])

-- =============== StarterGui (HUD) ===============
local gui = ensure(StarterGui, "ScreenGui", "HorrorHUD")
gui.ResetOnSpawn = false

-- Clean existing children
for _, c in ipairs(gui:GetChildren()) do
	c:Destroy()
end

local Stats = Instance.new("Frame")
Stats.Name = "Stats"
Stats.AnchorPoint = Vector2.new(0, 1)
Stats.Position = UDim2.fromScale(0.02, 0.98)
Stats.Size = UDim2.fromOffset(280, 90)
Stats.BackgroundTransparency = 0.25
Stats.BorderSizePixel = 0
Stats.Parent = gui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = Stats

local function mkText(parent, name, y, text)
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, -16, 0, 24)
	t.Position = UDim2.new(0, 8, 0, y)
	t.Font = Enum.Font.GothamSemibold
	t.TextSize = 16
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextColor3 = Color3.fromRGB(235, 235, 235)
	t.Text = text
	t.Parent = parent
	return t
end

mkText(Stats, "SanityValue", 8, "SANITY: 100")
mkText(Stats, "HungerValue", 34, "HUNGER: 100")

local Clock = Instance.new("Frame")
Clock.Name = "Clock"
Clock.AnchorPoint = Vector2.new(1, 0)
Clock.Position = UDim2.fromScale(0.98, 0.02)
Clock.Size = UDim2.fromOffset(260, 44)
Clock.BackgroundTransparency = 0.25
Clock.BorderSizePixel = 0
Clock.Parent = gui

local UICorner2 = Instance.new("UICorner")
UICorner2.CornerRadius = UDim.new(0, 10)
UICorner2.Parent = Clock

local ClockText = Instance.new("TextLabel")
ClockText.Name = "ClockText"
ClockText.BackgroundTransparency = 1
ClockText.Size = UDim2.new(1, -16, 1, 0)
ClockText.Position = UDim2.new(0, 8, 0, 0)
ClockText.Font = Enum.Font.GothamSemibold
ClockText.TextSize = 16
ClockText.TextXAlignment = Enum.TextXAlignment.Left
ClockText.TextColor3 = Color3.fromRGB(235, 235, 235)
ClockText.Text = "Night 1 | 00:00"
ClockText.Parent = Clock

local FakePrompt = Instance.new("TextButton")
FakePrompt.Name = "FakePrompt"
FakePrompt.Visible = false
FakePrompt.AutoButtonColor = false
FakePrompt.Text = ""
FakePrompt.BackgroundTransparency = 1
FakePrompt.Size = UDim2.fromScale(1, 1)
FakePrompt.Parent = gui

local Center = Instance.new("Frame")
Center.Name = "Center"
Center.AnchorPoint = Vector2.new(0.5, 0.5)
Center.Position = UDim2.fromScale(0.5, 0.65)
Center.Size = UDim2.fromOffset(420, 60)
Center.BackgroundTransparency = 1
Center.Parent = FakePrompt

local PromptLabel = Instance.new("TextLabel")
PromptLabel.Name = "TextLabel"
PromptLabel.BackgroundTransparency = 0.2
PromptLabel.BorderSizePixel = 0
PromptLabel.Size = UDim2.new(1, 0, 1, 0)
PromptLabel.Font = Enum.Font.GothamBold
PromptLabel.TextSize = 20
PromptLabel.TextColor3 = Color3.fromRGB(250, 250, 250)
PromptLabel.Text = "LOCK DOOR (E)"
PromptLabel.Parent = Center

local UICorner3 = Instance.new("UICorner")
UICorner3.CornerRadius = UDim.new(0, 12)
UICorner3.Parent = PromptLabel

-- =============== Lighting basic atmosphere ===============
-- (Optional) you can delete these if you don't want
local atmo = Lighting:FindFirstChild("Atmosphere") or Instance.new("Atmosphere")
atmo.Density = 0.35
atmo.Offset = 0.1
atmo.Haze = 1.4
atmo.Parent = Lighting

print("✅ Horror framework created: Remotes + Modules + Server Services + Client FX + HUD.")
print("Next: build SafeZones (set player attribute InSafeZone true/false via zone parts).")
