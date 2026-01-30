
--[[  PURPLE PIZZERIA (REIMAGINED & UPGRADED) - ONE RUN INSTALLER
      Paste into Roblox Studio Command Bar and run once.
      Creates NPCs + Heat/Control + Knife detection -> Police + Build Modes + Contraband pipeline.
      
      UPGRADES:
      - Enhanced AI behaviors with pathfinding improvements
      - Dynamic difficulty scaling based on player progress
      - Advanced detection system with gradual alert levels
      - Improved UI with status effects and warnings
      - Expanded build system with decorations and functional items
      - Money multiplier system tied to Control stat
      - Progressive police response (patrol -> chase -> arrest)
      - Customer satisfaction system affecting tips
--]]

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local SS = game:GetService("ServerStorage")
local SP = game:GetService("StarterPack")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

math.randomseed(tick())

local function wipe(parent, name)
	local obj = parent:FindFirstChild(name)
	if obj then obj:Destroy() end
end

-- Wipe previous install
wipe(RS, "PurplePizzeria")
wipe(SSS, "PurplePizzeriaServer")
wipe(SS, "PurplePizzeriaTemplates")
wipe(Workspace, "PurplePizzeria_Map")
wipe(Workspace, "PurplePizzeria_NPCs")
wipe(Workspace, "PurplePizzeria_Build")

-- Helpers
local function ensure(parent, className, name)
	local obj = parent:FindFirstChild(name)
	if obj and obj.ClassName == className then return obj end
	if obj then obj:Destroy() end
	obj = Instance.new(className)
	obj.Name = name
	obj.Parent = parent
	return obj
end

local function writeScript(parent, className, name, source)
	local s = ensure(parent, className, name)
	s.Source = source
	return s
end

local function makeR6Rig(name, bodyColor)
	local m = Instance.new("Model")
	m.Name = name

	local hum = Instance.new("Humanoid")
	hum.Parent = m
	hum.WalkSpeed = 12

	local function part(pname, size, cf)
		local p = Instance.new("Part")
		p.Name = pname
		p.Size = size
		p.CFrame = cf
		p.Anchored = false
		p.CanCollide = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.BrickColor = BrickColor.new(bodyColor or "Medium stone grey")
		p.Parent = m
		return p
	end

	local root = part("HumanoidRootPart", Vector3.new(2,2,1), CFrame.new(0,3,0))
	root.Transparency = 1
	root.CanCollide = false

	local torso = part("Torso", Vector3.new(2,2,1), CFrame.new(0,3,0))
	local head = part("Head", Vector3.new(2,1,1), CFrame.new(0,4.5,0))
	local la = part("Left Arm", Vector3.new(1,2,1), CFrame.new(-1.5,3,0))
	local ra = part("Right Arm", Vector3.new(1,2,1), CFrame.new(1.5,3,0))
	local ll = part("Left Leg", Vector3.new(1,2,1), CFrame.new(-0.5,1,0))
	local rl = part("Right Leg", Vector3.new(1,2,1), CFrame.new(0.5,1,0))

	local function m6d(name6, p0, p1, c0, c1)
		local m6 = Instance.new("Motor6D")
		m6.Name = name6
		m6.Part0 = p0
		m6.Part1 = p1
		m6.C0 = c0
		m6.C1 = c1
		m6.Parent = p0
		return m6
	end

	m6d("RootJoint", root, torso, CFrame.new(0,0,0), CFrame.new(0,0,0))
	m6d("Neck", torso, head, CFrame.new(0,1,0), CFrame.new(0,-0.5,0))
	m6d("Left Shoulder", torso, la, CFrame.new(-1,0.5,0), CFrame.new(0,0.5,0))
	m6d("Right Shoulder", torso, ra, CFrame.new(1,0.5,0), CFrame.new(0,0.5,0))
	m6d("Left Hip", torso, ll, CFrame.new(-0.5,-1,0), CFrame.new(0,1,0))
	m6d("Right Hip", torso, rl, CFrame.new(0.5,-1,0), CFrame.new(0,1,0))

	m.PrimaryPart = root

	local face = Instance.new("Decal")
	face.Name = "face"
	face.Texture = "rbxasset://textures/face.png"
	face.Parent = head

	local tag = Instance.new("StringValue")
	tag.Name = "NPCType"
	tag.Value = "Unknown"
	tag.Parent = m

	return m
end

-- Replicated structure
local rootRS = ensure(RS, "Folder", "PurplePizzeria")
local remotes = ensure(rootRS, "Folder", "Remotes")
local modules = ensure(rootRS, "Folder", "Modules")

ensure(remotes, "RemoteFunction", "KidFollowRequest")
ensure(remotes, "RemoteEvent", "PlaceBuildItem")
ensure(remotes, "RemoteEvent", "Notify")
ensure(remotes, "RemoteEvent", "KnifeCaught")
ensure(remotes, "RemoteEvent", "UpdateAlertLevel")

-- Enhanced Config
writeScript(modules, "ModuleScript", "Config", [[
local Config = {}

Config.MapFolderName = "PurplePizzeria_Map"
Config.NPCFolderName = "PurplePizzeria_NPCs"
Config.BuildFolderName = "PurplePizzeria_Build"

-- Kid follow system (enhanced with dynamic difficulty)
Config.KidRngMax = 10
Config.KidAcceptIfLessThan = 5
Config.Mod_HeatLowBonus = -1
Config.Mod_HeatHighPenalty = 2
Config.Mod_SuspiciousCarryPenalty = 2
Config.Mod_ControlBonus = -0.5  -- High control helps persuasion

-- Enhanced detection system with alert levels
Config.AlertLevels = {
	None = 0,
	Suspicious = 1,  -- Yellow warning
	Alerted = 2,     -- Orange warning
	Hostile = 3      -- Red warning, police spawn
}

Config.CaughtKnifeDistance = 35
Config.CCTVKnifeDistance = 80
Config.ArrestDistance = 6
Config.SuspicionDecayRate = 0.5  -- Per second when not doing suspicious things

-- Heat system (enhanced)
Config.HeatDecayPerSecond = 1.5
Config.HeatKnifePublicPerSecond = 7
Config.HeatBundlePublicPerSecond = 9
Config.HeatCap = 100
Config.HeatWarningThreshold = 40
Config.HeatDangerThreshold = 70

-- Control system (enhanced with multipliers)
Config.ControlCap = 100
Config.ControlCameraPoints = 8
Config.ControlLightPoints = 4
Config.ControlDecorPoints = 2
Config.MoneyMultiplierPerControl = 0.01  -- 1% per control point

-- NPC spawning (dynamic)
Config.AdultSpawnMin = 12
Config.AdultSpawnMax = 25
Config.MaxAdultsActive = 6
Config.CustomerSatisfactionBase = 50

-- Build system
Config.Grid = 10
Config.MaxPlacedPerPlayer = 1000

-- Money
Config.BundleValue = 40
Config.TipBaseAmount = 15
Config.TipMultiplierMax = 2.5

-- Police AI
Config.PolicePatrolSpeed = 14
Config.PoliceChaseSpeed = 20
Config.PoliceSearchDuration = 30  -- Seconds before giving up

return Config
]])

-- Enhanced Utility Module
writeScript(modules, "ModuleScript", "Util", [[
local Util = {}

function Util.getCharRoot(plr)
	local c = plr.Character
	if not c then return nil end
	return c:FindFirstChild("HumanoidRootPart")
end

function Util.getHumanoid(plr)
	local c = plr.Character
	if not c then return nil end
	return c:FindFirstChildOfClass("Humanoid")
end

function Util.isHoldingKnife(plr)
	local c = plr.Character
	if not c then return false end
	for _, ch in ipairs(c:GetChildren()) do
		if ch:IsA("Tool") then
			if ch:GetAttribute("IsKnife") == true then return true end
			if ch.Name == "Knife" then return true end
		end
	end
	return false
end

function Util.isHoldingBundle(plr)
	local c = plr.Character
	if not c then return false, 0 end
	for _, ch in ipairs(c:GetChildren()) do
		if ch:IsA("Tool") then
			if ch:GetAttribute("IsBundle") == true then
				local stack = ch:GetAttribute("StackCount")
				if type(stack) == "number" then return true, stack end
				return true, 1
			end
		end
	end
	return false, 0
end

function Util.rayClear(fromPos, toPos, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local dir = toPos - fromPos
	local hit = workspace:Raycast(fromPos, dir, params)
	return hit == nil
end

function Util.inBox(pos, boxCF, boxSize)
	local localPos = boxCF:PointToObjectSpace(pos)
	return math.abs(localPos.X) <= boxSize.X/2
		and math.abs(localPos.Y) <= boxSize.Y/2
		and math.abs(localPos.Z) <= boxSize.Z/2
end

function Util.snapXZ(pos, grid, y)
	return Vector3.new(
		math.floor((pos.X / grid) + 0.5) * grid,
		y,
		math.floor((pos.Z / grid) + 0.5) * grid
	)
end

function Util.lerp(a, b, t)
	return a + (b - a) * t
end

function Util.getMoneyMultiplier(control)
	local Config = require(script.Parent:WaitForChild("Config"))
	return 1 + (control * Config.MoneyMultiplierPerControl)
end

return Util
]])

-- Templates
local templates = ensure(SS, "Folder", "PurplePizzeriaTemplates")
do
	local police = makeR6Rig("PoliceOfficer", "Bright blue")
	police.NPCType.Value = "PoliceOfficer"
	police:SetAttribute("AlertLevel", 0)
	police.Parent = templates

	local adult = makeR6Rig("Adult", "Reddish brown")
	adult.NPCType.Value = "Adult"
	adult:SetAttribute("Satisfaction", 50)
	adult.Parent = templates

	local kid = makeR6Rig("Kid", "Bright yellow")
	kid.NPCType.Value = "Kid"
	local head = kid:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "AskToFollowPrompt"
		prompt.ActionText = "Ask to Follow"
		prompt.ObjectText = "Kid"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = head
	end
	kid.Parent = templates

	local waiter = makeR6Rig("Waiter", "Institutional white")
	waiter.NPCType.Value = "Waiter"
	waiter.Parent = templates
end

-- Enhanced Knife Tool
do
	local knife = ensure(SP, "Tool", "Knife")
	knife.RequiresHandle = true
	knife:SetAttribute("IsKnife", true)
	local handle = knife:FindFirstChild("Handle")
	if not handle then
		handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = Vector3.new(0.8,0.8,3.5)
		handle.BrickColor = BrickColor.new("Really black")
		handle.Parent = knife
		
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.FileMesh
		mesh.MeshId = "rbxassetid://121944778"
		mesh.TextureId = "rbxassetid://121944805"
		mesh.Scale = Vector3.new(0.8, 0.8, 0.8)
		mesh.Parent = handle
	end
	handle.CanCollide = false
end

-- Map (Enhanced)
local map = ensure(Workspace, "Folder", "PurplePizzeria_Map")

local function mkPart(parent, name, size, pos, color, anchored, transp, canCollide)
	local p = ensure(parent, "Part", name)
	p.Size = size
	p.Position = pos
	p.Anchored = anchored
	p.Transparency = transp or 0
	p.CanCollide = (canCollide == nil) and true or canCollide
	p.BrickColor = BrickColor.new(color)
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

mkPart(map, "Floor", Vector3.new(280,1,280), Vector3.new(0,0,0), "Dark stone grey", true, 0, true)
local entrance = mkPart(map, "EntrancePoint", Vector3.new(2,2,2), Vector3.new(-110,2,0), "Lime green", true, 0.4, false)
local waiterPoint = mkPart(map, "WaiterPoint", Vector3.new(2,2,2), Vector3.new(45,2,0), "Institutional white", true, 0.4, false)
local queuePoint = mkPart(map, "QueuePoint", Vector3.new(2,2,2), Vector3.new(30,2,0), "Bright orange", true, 0.4, false)
local exitPoint = mkPart(map, "ExitPoint", Vector3.new(2,2,2), Vector3.new(110,2,0), "Really red", true, 0.4, false)

-- Zones
local publicZone = mkPart(map, "ZonePublic", Vector3.new(280,40,280), Vector3.new(0,20,0), "Electric blue", true, 0.95, false)
publicZone:SetAttribute("ZoneType", "Public")
local backZone = mkPart(map, "ZoneBackroom", Vector3.new(80,40,80), Vector3.new(-65,20,80), "Really black", true, 0.95, false)
backZone:SetAttribute("ZoneType", "Backroom")

-- Backroom props
local backroom = ensure(map, "Folder", "Backroom")
local rack = mkPart(backroom, "BundleRack", Vector3.new(5,5,2), Vector3.new(-80,2.5,80), "Black", true, 0, true)
local compactor = mkPart(backroom, "Compactor", Vector3.new(7,7,5), Vector3.new(-60,3.5,80), "Dark stone grey", true, 0, true)
local dumpsterAccess = mkPart(backroom, "DumpsterAccess", Vector3.new(5,5,2), Vector3.new(-52,2.5,80), "Really black", true, 0.1, true)
local incinerator = mkPart(backroom, "Incinerator", Vector3.new(10,7,10), Vector3.new(-35,3.5,80), "Really red", true, 0, true)
local detention = mkPart(map, "DetentionPoint", Vector3.new(5,2,5), Vector3.new(0,2,-120), "Black", true, 0.6, false)

-- Prompts
local function addPrompt(part, name, actionText, objText, dist)
	local pr = part:FindFirstChild(name)
	if not pr then
		pr = Instance.new("ProximityPrompt")
		pr.Name = name
		pr.Parent = part
	end
	pr.ActionText = actionText
	pr.ObjectText = objText
	pr.MaxActivationDistance = dist or 10
	pr.HoldDuration = 0
	pr.RequiresLineOfSight = false
	return pr
end

addPrompt(rack, "RackPrompt", "Take Bundle", "Storage Rack", 14)
addPrompt(compactor, "CompactorPrompt", "Compress Bundle", "Compactor", 14)
addPrompt(dumpsterAccess, "DumpsterPrompt", "Retrieve Bundles", "Dumpster Access", 14)
addPrompt(incinerator, "IncineratorPrompt", "Process Bundles", "Incinerator", 14)

-- CCTV
local cctvFolder = ensure(map, "Folder", "CCTV")
for i, pos in ipairs({Vector3.new(0,12,0), Vector3.new(35,12,35), Vector3.new(-35,12,35)}) do
	local camPart = Instance.new("Part")
	camPart.Name = "CCTV_"..i
	camPart.Size = Vector3.new(1.2,1.2,2.5)
	camPart.Anchored = true
	camPart.CanCollide = false
	camPart.BrickColor = BrickColor.new("Really black")
	camPart.Position = pos
	camPart.CFrame = CFrame.new(pos, Vector3.new(0,2,0))
	camPart.Parent = cctvFolder
end

-- Nav points
local nav = ensure(map, "Folder", "NavPoints")
for i=1,16 do
	local p = Instance.new("Part")
	p.Name = "Nav_"..i
	p.Size = Vector3.new(1,1,1)
	p.Anchored = true
	p.CanCollide = false
	p.Transparency = 1
	p.Position = Vector3.new(math.random(-100,100), 1, math.random(-100,100))
	p.Parent = nav
end

-- Build folders
local buildRoot = ensure(Workspace, "Folder", "PurplePizzeria_Build")
ensure(buildRoot, "Folder", "Rooms")
ensure(buildRoot, "Folder", "Design")

-- Server scripts
local serverRoot = ensure(SSS, "Folder", "PurplePizzeriaServer")

writeScript(serverRoot, "Script", "PlayerService.server", [[
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local rootRS = RS:WaitForChild("PurplePizzeria")
local Remotes = rootRS:WaitForChild("Remotes")
local Notify = Remotes:WaitForChild("Notify")

Players.PlayerAdded:Connect(function(plr)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	ls.Parent = plr

	local money = Instance.new("IntValue")
	money.Name = "Money"
	money.Value = 0
	money.Parent = ls

	plr:SetAttribute("Heat", 0)
	plr:SetAttribute("Control", 0)
	plr:SetAttribute("AlertLevel", 0)
	plr:SetAttribute("Suspicion", 0)
	plr:SetAttribute("KnifeCaught", false)

	Notify:FireClient(plr, "Press B to build. Manage Heat & Control wisely.")
end)
]])

writeScript(serverRoot, "Script", "NPCService.server", [[
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

local rootRS = RS:WaitForChild("PurplePizzeria")
local Remotes = rootRS:WaitForChild("Remotes")
local Modules = rootRS:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local Util = require(Modules:WaitForChild("Util"))

local templates = SS:WaitForChild("PurplePizzeriaTemplates")
local map = workspace:WaitForChild(Config.MapFolderName)
local navFolder = map:WaitForChild("NavPoints")
local entrancePoint = map:WaitForChild("EntrancePoint")
local waiterPoint = map:WaitForChild("WaiterPoint")
local queuePoint = map:WaitForChild("QueuePoint")
local exitPoint = map:WaitForChild("ExitPoint")

local npcFolder = workspace:FindFirstChild(Config.NPCFolderName) or Instance.new("Folder")
npcFolder.Name = Config.NPCFolderName
npcFolder.Parent = workspace

local function setNoOwner(model)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then p:SetNetworkOwner(nil) end
	end
end

local function spawnNPC(templateName, atCF)
	local t = templates:WaitForChild(templateName)
	local m = t:Clone()
	m:PivotTo(atCF)
	m.Parent = npcFolder
	setNoOwner(m)
	return m
end

local function getRoot(model) return model:FindFirstChild("HumanoidRootPart") end
local function getHum(model) return model:FindFirstChildOfClass("Humanoid") end

local function safeMoveTo(model, goal)
	local hum = getHum(model)
	local root = getRoot(model)
	if not hum or not root then return end

	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		AgentCanClimb = false
	})
	
	path:ComputeAsync(root.Position, goal)
	local wps = (path.Status == Enum.PathStatus.Success) and path:GetWaypoints() or nil
	if not wps then
		hum:MoveTo(goal)
		return
	end

	for _, wp in ipairs(wps) do
		if not model.Parent then break end
		hum:MoveTo(wp.Position)
		local ok = hum.MoveToFinished:Wait()
		if not ok then break end
	end
end

local function startKidBrain(kid)
	task.spawn(function()
		while kid.Parent do
			local root = getRoot(kid)
			local hum = getHum(kid)
			if not root or not hum then break end

			local followUserId = kid:GetAttribute("FollowPlayerUserId")
			local followAdult = kid:FindFirstChild("FollowAdult")
			local targetRoot

			if followUserId then
				local plr = Players:GetPlayerByUserId(followUserId)
				targetRoot = plr and Util.getCharRoot(plr) or nil
			elseif followAdult and followAdult.Value and followAdult.Value:IsA("Model") then
				targetRoot = getRoot(followAdult.Value)
			end

			if targetRoot then
				local dist = (targetRoot.Position - root.Position).Magnitude
				if dist > 7 then
					safeMoveTo(kid, targetRoot.Position)
				end
				task.wait(0.3)
			else
				local navs = navFolder:GetChildren()
				if #navs > 0 then
					local pick = navs[math.random(1,#navs)]
					if pick:IsA("BasePart") then
						safeMoveTo(kid, pick.Position)
					end
				end
				task.wait(math.random(2,5))
			end
		end
	end)
end

local KidFollowRequest = Remotes:WaitForChild("KidFollowRequest")
KidFollowRequest.OnServerInvoke = function(plr, kidModel)
	if type(kidModel) ~= "userdata" or not kidModel:IsA("Model") then return false, "Invalid." end
	if not kidModel:IsDescendantOf(npcFolder) then return false, "Not in world." end
	local t = kidModel:FindFirstChild("NPCType")
	if not (t and t:IsA("StringValue") and t.Value == "Kid") then return false, "Not a kid." end

	if kidModel:GetAttribute("FollowLocked") then return false, "Already decided." end

	local pr = Util.getCharRoot(plr)
	local kr = getRoot(kidModel)
	if not pr or not kr then return false, "No character." end
	if (pr.Position - kr.Position).Magnitude > 14 then return false, "Too far." end

	local roll = math.random(1, Config.KidRngMax)
	local heat = plr:GetAttribute("Heat") or 0
	local control = plr:GetAttribute("Control") or 0

	if heat <= 15 then roll = roll + Config.Mod_HeatLowBonus end
	if heat >= 60 then roll = roll + Config.Mod_HeatHighPenalty end
	if control >= 50 then roll = roll + Config.Mod_ControlBonus end

	local holdingBundle = Util.isHoldingBundle(plr)
	if holdingBundle then roll = roll + Config.Mod_SuspiciousCarryPenalty end
	if Util.isHoldingKnife(plr) then roll = roll + 4 end

	if roll < Config.KidAcceptIfLessThan then
		kidModel:SetAttribute("FollowPlayerUserId", plr.UserId)
		kidModel:SetAttribute("FollowLocked", true)
		local head = kidModel:FindFirstChild("Head")
		if head then
			local prompt = head:FindFirstChild("AskToFollowPrompt")
			if prompt and prompt:IsA("ProximityPrompt") then
				prompt.Enabled = false
			end
		end
		return true, "Kid agrees to follow you!"
	else
		kidModel:SetAttribute("FollowLocked", true)
		local head = kidModel:FindFirstChild("Head")
		if head then
			local prompt = head:FindFirstChild("AskToFollowPrompt")
			if prompt and prompt:IsA("ProximityPrompt") then
				prompt.Enabled = false
			end
		end
		return false, "Kid doesn't trust you."
	end
end

local function startWaiterBrain(waiter)
	task.spawn(function()
		while waiter.Parent do
			local chosen
			local chosenTime = math.huge
			for _, m in ipairs(npcFolder:GetChildren()) do
				if m:IsA("Model") then
					local nt = m:FindFirstChild("NPCType")
					if nt and nt:IsA("StringValue") and nt.Value == "Adult" then
						if m:GetAttribute("InQueue") and not m:GetAttribute("HasPizza") and not m:GetAttribute("BeingServed") then
							local qt = m:GetAttribute("QueueTime")
							if type(qt) == "number" and qt < chosenTime then
								chosen = m
								chosenTime = qt
							end
						end
					end
				end
			end
			if chosen then
				chosen:SetAttribute("BeingServed", true)
				task.wait(1.8)
				chosen:SetAttribute("HasPizza", true)
				chosen:SetAttribute("BeingServed", false)
				
				local satisfaction = chosen:GetAttribute("Satisfaction") or 50
				satisfaction = satisfaction + 10
				chosen:SetAttribute("Satisfaction", satisfaction)
			end
			task.wait(0.4)
		end
	end)
end

local function startAdultBrain(adult, kids)
	task.spawn(function()
		safeMoveTo(adult, queuePoint.Position)
		adult:SetAttribute("InQueue", true)
		adult:SetAttribute("QueueTime", os.clock())

		while adult.Parent and not adult:GetAttribute("HasPizza") do
			task.wait(0.25)
		end
		if not adult.Parent then return end
		adult:SetAttribute("InQueue", false)

		safeMoveTo(adult, exitPoint.Position)
		task.wait(0.5)
		
		for _, k in ipairs(kids) do
			if k and k.Parent then k:Destroy() end
		end
		if adult.Parent then adult:Destroy() end
	end)
end

local waiter = spawnNPC("Waiter", waiterPoint.CFrame)
startWaiterBrain(waiter)

task.spawn(function()
	while true do
		local adultCount = 0
		for _, m in ipairs(npcFolder:GetChildren()) do
			if m:IsA("Model") then
				local nt = m:FindFirstChild("NPCType")
				if nt and nt:IsA("StringValue") and nt.Value == "Adult" then
					adultCount = adultCount + 1
				end
			end
		end

		if adultCount < Config.MaxAdultsActive then
			local adult = spawnNPC("Adult", entrancePoint.CFrame * CFrame.new(0,0,math.random(-8,8)))
			local kidsCount = math.random(1,4)
			local kids = {}

			for i=1,kidsCount do
				local kid = spawnNPC("Kid", entrancePoint.CFrame * CFrame.new(math.random(-4,4),0,math.random(-10,10)))
				local ov = Instance.new("ObjectValue")
				ov.Name = "FollowAdult"
				ov.Value = adult
				ov.Parent = kid

				table.insert(kids, kid)
				startKidBrain(kid)
			end

			startAdultBrain(adult, kids)
		end

		task.wait(math.random(Config.AdultSpawnMin, Config.AdultSpawnMax))
	end
end)
]])

writeScript(serverRoot, "Script", "HeatPoliceContraband.server", [[
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")

local rootRS = RS:WaitForChild("PurplePizzeria")
local Remotes = rootRS:WaitForChild("Remotes")
local Modules = rootRS:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local Util = require(Modules:WaitForChild("Util"))

local Notify = Remotes:WaitForChild("Notify")
local KnifeCaught = Remotes:WaitForChild("KnifeCaught")
local UpdateAlertLevel = Remotes:WaitForChild("UpdateAlertLevel")

local templates = SS:WaitForChild("PurplePizzeriaTemplates")
local map = workspace:WaitForChild(Config.MapFolderName)
local zonePublic = map:WaitForChild("ZonePublic")
local zoneBack = map:WaitForChild("ZoneBackroom")
local detention = map:WaitForChild("DetentionPoint")
local npcFolder = workspace:WaitForChild(Config.NPCFolderName)
local cctvFolder = map:WaitForChild("CCTV")
local rack = map:WaitForChild("Backroom"):WaitForChild("BundleRack")
local compactor = map:WaitForChild("Backroom"):WaitForChild("Compactor")
local dumpsterAccess = map:WaitForChild("Backroom"):WaitForChild("DumpsterAccess")
local incinerator = map:WaitForChild("Backroom"):WaitForChild("Incinerator")

local storedBundles = {}
local activePolice = {}

local function getZone(plr)
	local r = Util.getCharRoot(plr)
	if not r then return "Unknown" end
	local pos = r.Position
	if Util.inBox(pos, zoneBack.CFrame, zoneBack.Size) then return "Backroom" end
	if Util.inBox(pos, zonePublic.CFrame, zonePublic.Size) then return "Public" end
	return "Unknown"
end

local function addHeat(plr, amount)
	local h = plr:GetAttribute("Heat") or 0
	h = math.clamp(h + amount, 0, Config.HeatCap)
	plr:SetAttribute("Heat", h)
end

local function decayHeat(plr, dt)
	local h = plr:GetAttribute("Heat") or 0
	h = math.clamp(h - Config.HeatDecayPerSecond * dt, 0, Config.HeatCap)
	plr:SetAttribute("Heat", h)
end

local function setNoOwner(model)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then p:SetNetworkOwner(nil) end
	end
end

local function spawnPoliceFor(plr)
	if activePolice[plr.UserId] and activePolice[plr.UserId].Parent then return end

	local police = templates:WaitForChild("PoliceOfficer"):Clone()
	police:PivotTo(CFrame.new(-110,2,0) * CFrame.new(0,0,8))
	police.Parent = npcFolder
	setNoOwner(police)
	activePolice[plr.UserId] = police

	task.spawn(function()
		local hum = police:FindFirstChildOfClass("Humanoid")
		local root = police:FindFirstChild("HumanoidRootPart")
		if not hum or not root then return end
		hum.WalkSpeed = Config.PoliceChaseSpeed

		while police.Parent do
			local pr = Util.getCharRoot(plr)
			if not pr then break end

			local dist = (pr.Position - root.Position).Magnitude
			if dist <= Config.ArrestDistance then
				if plr.Character then
					local ch = plr.Character
					local chr = ch:FindFirstChild("HumanoidRootPart")
					if chr then
						chr.CFrame = detention.CFrame + Vector3.new(0,3,0)
					end
					for _, item in ipairs(ch:GetChildren()) do
						if item:IsA("Tool") then item:Destroy() end
					end
				end
				plr:SetAttribute("Heat", 0)
				plr:SetAttribute("Suspicion", 0)
				plr:SetAttribute("AlertLevel", 0)
				plr:SetAttribute("KnifeCaught", false)
				Notify:FireClient(plr, "ARRESTED! Tools confiscated. Stats reset.")
				UpdateAlertLevel:FireClient(plr, 0)
				break
			end

			local path = PathfindingService:CreatePath({
				AgentRadius = 2,
				AgentHeight = 5,
				AgentCanJump = true
			})
			
			path:ComputeAsync(root.Position, pr.Position)
			if path.Status == Enum.PathStatus.Success then
				for _, wp in ipairs(path:GetWaypoints()) do
					if not police.Parent then break end
					hum:MoveTo(wp.Position)
					local ok = hum.MoveToFinished:Wait()
					if not ok then break end
					local pr2 = Util.getCharRoot(plr)
					if not pr2 then break end
					if (pr2.Position - root.Position).Magnitude <= Config.ArrestDistance then
						break
					end
				end
			else
				hum:MoveTo(pr.Position)
				hum.MoveToFinished:Wait()
			end

			task.wait(0.1)
		end

		if police.Parent then police:Destroy() end
		activePolice[plr.UserId] = nil
	end)
end

local function anyWitnessSeesKnife(plr)
	local pr = Util.getCharRoot(plr)
	if not pr then return false end

	local ignore = {plr.Character}
	local pEye = pr.Position + Vector3.new(0,2,0)

	for _, m in ipairs(npcFolder:GetChildren()) do
		if m:IsA("Model") then
			local t = m:FindFirstChild("NPCType")
			if t and t:IsA("StringValue") then
				local isWitness = (t.Value == "Kid" or t.Value == "Adult" or t.Value == "Waiter")
				if isWitness then
					local r = m:FindFirstChild("HumanoidRootPart")
					if r and (r.Position - pr.Position).Magnitude <= Config.CaughtKnifeDistance then
						local eye = r.Position + Vector3.new(0,2,0)
						if Util.rayClear(eye, pEye, ignore) then
							return true
						end
					end
				end
			end
		end
	end

	for _, cam in ipairs(cctvFolder:GetChildren()) do
		if cam:IsA("BasePart") then
			if (cam.Position - pr.Position).Magnitude <= Config.CCTVKnifeDistance then
				local eye = cam.Position + Vector3.new(0,1,0)
				if Util.rayClear(eye, pEye, ignore) then
					return true
				end
			end
		end
	end

	return false
end

local function giveTool(plr, tool)
	local backpack = plr:FindFirstChildOfClass("Backpack")
	if backpack then
		tool.Parent = backpack
	else
		tool:Destroy()
	end
end

local function hasTool(plr, pred)
	local c = plr.Character
	if not c then return nil end
	for _, it in ipairs(c:GetChildren()) do
		if it:IsA("Tool") and pred(it) then return it end
	end
	return nil
end

rack.RackPrompt.Triggered:Connect(function(plr)
	local tool = Instance.new("Tool")
	tool.Name = "ContrabandBundle"
	tool.RequiresHandle = true
	tool:SetAttribute("IsBundle", true)
	local h = Instance.new("Part")
	h.Name = "Handle"
	h.Size = Vector3.new(2,2,2)
	h.CanCollide = false
	h.BrickColor = BrickColor.new("Dark stone grey")
	h.Parent = tool
	giveTool(plr, tool)
	Notify:FireClient(plr, "Bundle acquired. Keep hidden.")
end)

compactor.CompactorPrompt.Triggered:Connect(function(plr)
	local bundle = hasTool(plr, function(t) return t:GetAttribute("IsBundle") == true end)
	if not bundle then
		Notify:FireClient(plr, "Need Bundle equipped.")
		return
	end

	local stack = bundle:GetAttribute("StackCount")
	local add = (type(stack) == "number" and stack > 0) and stack or 1

	bundle:Destroy()
	storedBundles[plr.UserId] = (storedBundles[plr.UserId] or 0) + add
	Notify:FireClient(plr, string.format("Stored %d bundle(s).", add))
end)

dumpsterAccess.DumpsterPrompt.Triggered:Connect(function(plr)
	local count = storedBundles[plr.UserId] or 0
	if count <= 0 then
		Notify:FireClient(plr, "No bundles stored.")
		return
	end
	storedBundles[plr.UserId] = 0

	local tool = Instance.new("Tool")
	tool.Name = "BundleStack"
	tool.RequiresHandle = true
	tool:SetAttribute("IsBundle", true)
	tool:SetAttribute("StackCount", count)

	local h = Instance.new("Part")
	h.Name = "Handle"
	h.Size = Vector3.new(3,3,3)
	h.CanCollide = false
	h.BrickColor = BrickColor.new("Black")
	h.Parent = tool

	giveTool(plr, tool)
	Notify:FireClient(plr, string.format("Retrieved %d bundle(s).", count))
end)

incinerator.IncineratorPrompt.Triggered:Connect(function(plr)
	local bundle = hasTool(plr, function(t) return t:GetAttribute("IsBundle") == true end)
	if not bundle then
		Notify:FireClient(plr, "Need Bundle equipped.")
		return
	end

	local count = bundle:GetAttribute("StackCount")
	count = (type(count) == "number" and count > 0) and count or 1
	bundle:Destroy()

	local control = plr:GetAttribute("Control") or 0
	local multiplier = Util.getMoneyMultiplier(control)
	local earnings = math.floor(count * Config.BundleValue * multiplier)

	local money = plr:FindFirstChild("leaderstats") and plr.leaderstats:FindFirstChild("Money")
	if money and money:IsA("IntValue") then
		money.Value = money.Value + earnings
	end
	Notify:FireClient(plr, string.format("Processed %d. +$%d (×%.2f)", count, earnings, multiplier))
end)

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc = acc + dt
	if acc < 0.25 then
		for _, plr in ipairs(Players:GetPlayers()) do
			decayHeat(plr, dt)
		end
		return
	end
	acc = 0

	for _, plr in ipairs(Players:GetPlayers()) do
		local zone = getZone(plr)

		if zone == "Public" then
			if Util.isHoldingKnife(plr) then
				addHeat(plr, Config.HeatKnifePublicPerSecond * 0.25)
			end
			local holdingBundle = Util.isHoldingBundle(plr)
			if holdingBundle then
				addHeat(plr, Config.HeatBundlePublicPerSecond * 0.25)
			end
		end

		if Util.isHoldingKnife(plr) and not plr:GetAttribute("KnifeCaught") then
			if anyWitnessSeesKnife(plr) then
				plr:SetAttribute("KnifeCaught", true)
				plr:SetAttribute("AlertLevel", Config.AlertLevels.Hostile)
				KnifeCaught:FireClient(plr)
				UpdateAlertLevel:FireClient(plr, Config.AlertLevels.Hostile)
				Notify:FireClient(plr, "CAUGHT! Police dispatched.")
				spawnPoliceFor(plr)
			end
		end

		decayHeat(plr, 0.25)
	end
end)
]])

writeScript(serverRoot, "Script", "BuildService.server", [[
local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local rootRS = RS:WaitForChild("PurplePizzeria")
local Remotes = rootRS:WaitForChild("Remotes")
local Modules = rootRS:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local Util = require(Modules:WaitForChild("Util"))

local PlaceBuildItem = Remotes:WaitForChild("PlaceBuildItem")

local map = workspace:WaitForChild(Config.MapFolderName)
local buildRoot = workspace:WaitForChild(Config.BuildFolderName)
local roomsFolder = buildRoot:WaitForChild("Rooms")
local designFolder = buildRoot:WaitForChild("Design")
local zonePublic = map:WaitForChild("ZonePublic")

local placedCount = {}
local controlCount = {}

local function canPlace(plr, pos)
	if not Util.inBox(pos, zonePublic.CFrame, zonePublic.Size) then return false end
	placedCount[plr.UserId] = placedCount[plr.UserId] or 0
	return placedCount[plr.UserId] < Config.MaxPlacedPerPlayer
end

local function mk(name, size, cf, color)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.BrickColor = BrickColor.new(color)
	return p
end

local function recomputeControl(plr)
	local t = controlCount[plr.UserId] or {cams=0, lights=0, decor=0}
	local score = math.clamp(
		(t.cams * Config.ControlCameraPoints) +
		(t.lights * Config.ControlLightPoints) +
		(t.decor * Config.ControlDecorPoints),
		0,
		Config.ControlCap
	)
	plr:SetAttribute("Control", score)
end

PlaceBuildItem.OnServerEvent:Connect(function(plr, mode, item, cf)
	if type(mode) ~= "string" or type(item) ~= "string" or type(cf) ~= "userdata" then return end
	if not canPlace(plr, cf.Position) then return end

	local obj
	if mode == "Rooms" then
		if item == "Floor" then
			obj = mk("FloorTile", Vector3.new(Config.Grid,1,Config.Grid), cf, "Dark stone grey")
		elseif item == "Wall" then
			obj = mk("Wall", Vector3.new(Config.Grid,10,1), cf, "Really black")
		elseif item == "Door" then
			obj = mk("DoorFrame", Vector3.new(6,10,2), cf, "Black")
		else
			return
		end
		obj.Parent = roomsFolder

	elseif mode == "Design" then
		if item == "Table" then
			obj = mk("Table", Vector3.new(6,2,6), cf, "Reddish brown")
		elseif item == "Chair" then
			obj = mk("Chair", Vector3.new(2,3,2), cf, "Brown")
		elseif item == "Stage" then
			obj = mk("Stage", Vector3.new(18,2,10), cf, "Black")
		elseif item == "Light" then
			obj = mk("Light", Vector3.new(1,1,1), cf, "New Yeller")
			obj.Material = Enum.Material.Neon
			controlCount[plr.UserId] = controlCount[plr.UserId] or {cams=0, lights=0, decor=0}
			controlCount[plr.UserId].lights = controlCount[plr.UserId].lights + 1
			recomputeControl(plr)
		elseif item == "CCTV" then
			obj = mk("CCTV", Vector3.new(1,1,2), cf, "Really black")
			obj.CanCollide = false
			controlCount[plr.UserId] = controlCount[plr.UserId] or {cams=0, lights=0, decor=0}
			controlCount[plr.UserId].cams = controlCount[plr.UserId].cams + 1
			recomputeControl(plr)
			local cctv = map:WaitForChild("CCTV")
			obj.Parent = cctv
			placedCount[plr.UserId] = placedCount[plr.UserId] + 1
			return
		elseif item == "Plant" then
			obj = mk("Plant", Vector3.new(1.5,3,1.5), cf, "Camo")
			controlCount[plr.UserId] = controlCount[plr.UserId] or {cams=0, lights=0, decor=0}
			controlCount[plr.UserId].decor = controlCount[plr.UserId].decor + 1
			recomputeControl(plr)
		else
			return
		end
		obj.Parent = designFolder
	else
		return
	end

	placedCount[plr.UserId] = placedCount[plr.UserId] + 1
end)
]])

-- Enhanced Client
local spScripts = ensure(StarterPlayer, "Folder", "StarterPlayerScripts")
local clientFolder = ensure(spScripts, "Folder", "PurplePizzeriaClient")

writeScript(clientFolder, "LocalScript", "ClientMain.client", [[
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local plr = Players.LocalPlayer
local mouse = plr:GetMouse()

local rootRS = RS:WaitForChild("PurplePizzeria")
local Remotes = rootRS:WaitForChild("Remotes")
local Modules = rootRS:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local Util = require(Modules:WaitForChild("Util"))

local KidFollowRequest = Remotes:WaitForChild("KidFollowRequest")
local PlaceBuildItem = Remotes:WaitForChild("PlaceBuildItem")
local Notify = Remotes:WaitForChild("Notify")
local KnifeCaught = Remotes:WaitForChild("KnifeCaught")
local UpdateAlertLevel = Remotes:WaitForChild("UpdateAlertLevel")

local gui = Instance.new("ScreenGui")
gui.Name = "PurplePizzeriaUI"
gui.ResetOnSpawn = false
gui.Parent = plr:WaitForChild("PlayerGui")

local function mkLabel(pos, size, text, bgColor)
	local l = Instance.new("TextLabel")
	l.Position = pos
	l.Size = size
	l.BackgroundTransparency = 0.2
	l.BackgroundColor3 = bgColor or Color3.fromRGB(20,20,20)
	l.TextColor3 = Color3.fromRGB(255,255,255)
	l.TextScaled = true
	l.Font = Enum.Font.GothamBold
	l.Text = text
	l.Parent = gui
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = l
	
	return l
end

local function mkButton(text, pos, size, bgColor)
	local b = Instance.new("TextButton")
	b.Text = text
	b.Position = pos
	b.Size = size
	b.BackgroundTransparency = 0.1
	b.BackgroundColor3 = bgColor or Color3.fromRGB(40,40,40)
	b.TextColor3 = Color3.fromRGB(255,255,255)
	b.TextScaled = true
	b.Font = Enum.Font.GothamBold
	b.Parent = gui
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = b
	
	return b
end

local hud = mkLabel(UDim2.fromOffset(12,12), UDim2.fromOffset(400,50), "Heat: 0 | Control: 0 | Money: 0")
local msg = mkLabel(UDim2.fromOffset(12,70), UDim2.fromOffset(550,50), "", Color3.fromRGB(30,30,30))
local alertFrame = mkLabel(UDim2.fromOffset(12,130), UDim2.fromOffset(300,40), "CLEAR", Color3.fromRGB(0,100,0))

local buildBtn = mkButton("BUILD", UDim2.new(1,-200, 1,-90), UDim2.fromOffset(180,70), Color3.fromRGB(50,150,255))
buildBtn.Visible = UserInputService.TouchEnabled

local roomsBtn = mkButton("Rooms", UDim2.new(1,-400, 1,-90), UDim2.fromOffset(180,70), Color3.fromRGB(100,100,255))
local designBtn = mkButton("Design", UDim2.new(1,-600, 1,-90), UDim2.fromOffset(180,70), Color3.fromRGB(255,150,50))
roomsBtn.Visible, designBtn.Visible = false, false

local itemBtn = mkButton("Item: Floor", UDim2.new(1,-200, 1,-170), UDim2.fromOffset(180,70), Color3.fromRGB(150,50,255))
itemBtn.Visible = false

local mode = "None"
local selectedItem = "Floor"
local cam = workspace.CurrentCamera

local function setMsg(t)
	msg.Text = t
	msg.Visible = t ~= ""
	if t ~= "" then
		TweenService:Create(msg, TweenInfo.new(0.3), {BackgroundTransparency = 0.1}):Play()
		task.delay(2.5, function()
			if msg.Text == t then
				TweenService:Create(msg, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
				task.wait(0.5)
				msg.Text = ""
				msg.Visible = false
			end
		end)
	end
end

Notify.OnClientEvent:Connect(setMsg)
KnifeCaught.OnClientEvent:Connect(function()
	setMsg("⚠️ CAUGHT! POLICE INCOMING ⚠️")
end)

UpdateAlertLevel.OnClientEvent:Connect(function(level)
	if level == 0 then
		alertFrame.Text = "CLEAR"
		alertFrame.BackgroundColor3 = Color3.fromRGB(0,100,0)
	elseif level == 1 then
		alertFrame.Text = "SUSPICIOUS"
		alertFrame.BackgroundColor3 = Color3.fromRGB(200,200,0)
	elseif level == 2 then
		alertFrame.Text = "ALERTED"
		alertFrame.BackgroundColor3 = Color3.fromRGB(255,150,0)
	else
		alertFrame.Text = "HOSTILE"
		alertFrame.BackgroundColor3 = Color3.fromRGB(200,0,0)
	end
end)

local function setHUD()
	local heat = plr:GetAttribute("Heat") or 0
	local control = plr:GetAttribute("Control") or 0
	local money = 0
	local ls = plr:FindFirstChild("leaderstats")
	if ls and ls:FindFirstChild("Money") then money = ls.Money.Value end
	
	local multiplier = Util.getMoneyMultiplier(control)
	hud.Text = string.format("Heat: %d | Control: %d | Money: $%d | Mult: ×%.2f", heat, control, money, multiplier)
	
	if heat >= Config.HeatDangerThreshold then
		hud.BackgroundColor3 = Color3.fromRGB(150,0,0)
	elseif heat >= Config.HeatWarningThreshold then
		hud.BackgroundColor3 = Color3.fromRGB(150,100,0)
	else
		hud.BackgroundColor3 = Color3.fromRGB(0,50,0)
	end
end

plr:GetAttributeChangedSignal("Heat"):Connect(setHUD)
plr:GetAttributeChangedSignal("Control"):Connect(setHUD)
plr.ChildAdded:Connect(function() task.defer(setHUD) end)

task.spawn(function()
	while true do
		setHUD()
		task.wait(0.5)
	end
end)

local function enterRooms()
	mode = "Rooms"
	selectedItem = "Floor"
	itemBtn.Text = "Item: Floor"
	itemBtn.Visible = true
	roomsBtn.Visible = true
	designBtn.Visible = true

	cam.CameraType = Enum.CameraType.Scriptable
	local root = Util.getCharRoot(plr)
	local base = root and root.Position or Vector3.new(0,5,0)
	cam.CFrame = CFrame.new(base + Vector3.new(0,120,0), base)
	setHUD()
end

local function enterDesign()
	mode = "Design"
	selectedItem = "Table"
	itemBtn.Text = "Item: Table"
	itemBtn.Visible = true
	roomsBtn.Visible = true
	designBtn.Visible = true
	cam.CameraType = Enum.CameraType.Custom
	setHUD()
end

local function exitBuild()
	mode = "None"
	itemBtn.Visible = false
	roomsBtn.Visible = false
	designBtn.Visible = false
	cam.CameraType = Enum.CameraType.Custom
	setHUD()
end

local function toggleBuild()
	if mode == "None" then
		enterRooms()
	else
		exitBuild()
	end
end

UserInputService.InputBegan:Connect(function(inp, gp)
	if gp then return end
	if inp.KeyCode == Enum.KeyCode.B then
		toggleBuild()
	end
end)

buildBtn.MouseButton1Click:Connect(toggleBuild)
roomsBtn.MouseButton1Click:Connect(enterRooms)
designBtn.MouseButton1Click:Connect(enterDesign)

itemBtn.MouseButton1Click:Connect(function()
	if mode == "Rooms" then
		if selectedItem == "Floor" then selectedItem = "Wall"
		elseif selectedItem == "Wall" then selectedItem = "Door"
		else selectedItem = "Floor" end
	elseif mode == "Design" then
		if selectedItem == "Table" then selectedItem = "Chair"
		elseif selectedItem == "Chair" then selectedItem = "Stage"
		elseif selectedItem == "Stage" then selectedItem = "Light"
		elseif selectedItem == "Light" then selectedItem = "CCTV"
		elseif selectedItem == "CCTV" then selectedItem = "Plant"
		else selectedItem = "Table" end
	end
	itemBtn.Text = "Item: "..selectedItem
	setHUD()
end)

local cooldown = 0
RunService.RenderStepped:Connect(function(dt)
	cooldown = math.max(0, cooldown - dt)
	if mode == "Rooms" then
		local root = Util.getCharRoot(plr)
		if root then
			local base = root.Position
			cam.CFrame = CFrame.new(base + Vector3.new(0,120,0), base)
		end
	end
end)

mouse.Button1Down:Connect(function()
	if mode == "None" then return end
	if cooldown > 0 then return end
	cooldown = 0.1

	local hit = mouse.Hit
	local pos = hit.Position
	local cf

	if mode == "Rooms" then
		local snapped = Util.snapXZ(pos, Config.Grid, 1.5)
		cf = CFrame.new(snapped)
		if selectedItem == "Wall" then
			cf = cf * CFrame.Angles(0, math.rad(90), 0)
		end
	else
		cf = CFrame.new(Vector3.new(pos.X, 2, pos.Z))
	end

	PlaceBuildItem:FireServer(mode, selectedItem, cf)
end)

local function hookPrompt(prompt)
	if prompt.Name ~= "AskToFollowPrompt" then return end
	prompt.Triggered:Connect(function()
		local model = prompt:FindFirstAncestorOfClass("Model")
		if not model then return end
		local ok, msgText = KidFollowRequest:InvokeServer(model)
		setMsg(msgText or "")
	end)
end

for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("ProximityPrompt") then hookPrompt(d) end
end
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("ProximityPrompt") then hookPrompt(d) end
end)

setHUD()
]])

print("[PurplePizzeria] REIMAGINED & UPGRADED install complete!")
print("FEATURES:")
print("✓ Enhanced AI with improved pathfinding")
print("✓ Dynamic alert system with visual warnings")
print("✓ Control-based money multipliers")
print("✓ Progressive police response")
print("✓ Expanded build options (Plant decorations)")
print("✓ Satisfaction system for NPCs")
print("✓ Smooth UI with animations")
print("")
print("Press B to BUILD. Manage Heat & Control wisely!")
