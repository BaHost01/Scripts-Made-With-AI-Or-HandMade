--[[ Purple Pizzeria PATCH v2
     Fixes broken StarterPlayerScripts, remakes build client + UI, adds delete mode, tags placed parts with owner.
     Paste into Command Bar and run once.
--]]

local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

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

-- 1) Restore real StarterPlayerScripts (your install replaced it with a Folder)
do
	local bad = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	if bad and bad.ClassName == "Folder" then
		bad:Destroy()
	end

	local sps = StarterPlayer:FindFirstChildOfClass("StarterPlayerScripts")
	if not sps then
		-- recreate proper container
		local ok, newObj = pcall(function()
			local o = Instance.new("StarterPlayerScripts")
			o.Parent = StarterPlayer
			return o
		end)
		if not ok then
			error("Could not recreate StarterPlayerScripts. Reopen Studio (it usually restores automatically), then run this patch again.")
		end
	end
end

-- 2) Ensure remotes exist
local rootRS = RS:FindFirstChild("PurplePizzeria") or ensure(RS, "Folder", "PurplePizzeria")
local remotes = rootRS:FindFirstChild("Remotes") or ensure(rootRS, "Folder", "Remotes")
ensure(remotes, "RemoteFunction", "KidFollowRequest")
ensure(remotes, "RemoteEvent", "PlaceBuildItem")
ensure(remotes, "RemoteEvent", "Notify")
ensure(remotes, "RemoteEvent", "KnifeCaught")
ensure(remotes, "RemoteEvent", "DeleteBuildItem") -- NEW

-- 3) Patch BuildService (server)
local serverRoot = SSS:FindFirstChild("PurplePizzeriaServer")
if not serverRoot then
	serverRoot = ensure(SSS, "Folder", "PurplePizzeriaServer")
end

writeScript(serverRoot, "Script", "BuildService.server", [[
local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local rootRS = RS:WaitForChild("PurplePizzeria")
local Remotes = rootRS:WaitForChild("Remotes")
local Modules = rootRS:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local Util = require(Modules:WaitForChild("Util"))

local PlaceBuildItem = Remotes:WaitForChild("PlaceBuildItem")
local DeleteBuildItem = Remotes:WaitForChild("DeleteBuildItem")

local map = workspace:WaitForChild(Config.MapFolderName)
local buildRoot = workspace:WaitForChild(Config.BuildFolderName)
local roomsFolder = buildRoot:WaitForChild("Rooms")
local designFolder = buildRoot:WaitForChild("Design")

local zonePublic = map:WaitForChild("ZonePublic")
local cctvFolder = map:WaitForChild("CCTV")

local placedCount = {} -- [userId]=n
local controlCount = {} -- [userId]={cams=0, lights=0}

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
	p:SetAttribute("PlacedByUserId", 0)
	return p
end

local function recomputeControl(plr)
	local t = controlCount[plr.UserId] or {cams=0, lights=0}
	local score = math.clamp((t.cams * Config.ControlCameraPoints) + (t.lights * Config.ControlLightPoints), 0, Config.ControlCap)
	plr:SetAttribute("Control", score)
end

PlaceBuildItem.OnServerEvent:Connect(function(plr, mode, item, cf)
	if typeof(mode) ~= "string" or typeof(item) ~= "string" or typeof(cf) ~= "CFrame" then return end
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
		obj:SetAttribute("PlacedByUserId", plr.UserId)
		obj.Parent = roomsFolder

	elseif mode == "Design" then
		if item == "Table" then
			obj = mk("Table", Vector3.new(6,2,6), cf, "Reddish brown")
			obj.Parent = designFolder
		elseif item == "Chair" then
			obj = mk("Chair", Vector3.new(2,3,2), cf, "Brown")
			obj.Parent = designFolder
		elseif item == "Stage" then
			obj = mk("Stage", Vector3.new(18,2,10), cf, "Black")
			obj.Parent = designFolder
		elseif item == "Light" then
			obj = mk("Light", Vector3.new(1,1,1), cf, "New Yeller")
			obj.Material = Enum.Material.Neon
			obj.Parent = designFolder
			controlCount[plr.UserId] = controlCount[plr.UserId] or {cams=0, lights=0}
			controlCount[plr.UserId].lights += 1
			recomputeControl(plr)
		elseif item == "CCTV" then
			obj = mk("CCTV", Vector3.new(1,1,2), cf, "Really black")
			obj.CanCollide = false
			obj.Parent = cctvFolder
			controlCount[plr.UserId] = controlCount[plr.UserId] or {cams=0, lights=0}
			controlCount[plr.UserId].cams += 1
			recomputeControl(plr)
		else
			return
		end
		obj:SetAttribute("PlacedByUserId", plr.UserId)
	else
		return
	end

	placedCount[plr.UserId] += 1
end)

DeleteBuildItem.OnServerEvent:Connect(function(plr, target)
	if typeof(target) ~= "Instance" then return end
	if not target:IsA("BasePart") then return end

	-- must be within allowed folders
	local okFolder =
		target:IsDescendantOf(roomsFolder) or
		target:IsDescendantOf(designFolder) or
		target:IsDescendantOf(cctvFolder)

	if not okFolder then return end

	-- ownership check
	local owner = target:GetAttribute("PlacedByUserId")
	if typeof(owner) ~= "number" or owner ~= plr.UserId then
		return
	end

	target:Destroy()
end)
]])

-- 4) Patch Client script + UI (runs properly now)
local sps = StarterPlayer:FindFirstChildOfClass("StarterPlayerScripts") or StarterPlayer:WaitForChild("StarterPlayerScripts")
local clientFolder = ensure(sps, "Folder", "PurplePizzeriaClient")

writeScript(clientFolder, "LocalScript", "ClientMain.client", [[
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local plr = Players.LocalPlayer

local rootRS = RS:WaitForChild("PurplePizzeria")
local Remotes = rootRS:WaitForChild("Remotes")
local Modules = rootRS:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local Util = require(Modules:WaitForChild("Util"))

local KidFollowRequest = Remotes:WaitForChild("KidFollowRequest")
local PlaceBuildItem = Remotes:WaitForChild("PlaceBuildItem")
local DeleteBuildItem = Remotes:WaitForChild("DeleteBuildItem")
local Notify = Remotes:WaitForChild("Notify")

local cam = Workspace.CurrentCamera

-- ===== UI =====
local gui = Instance.new("ScreenGui")
gui.Name = "PurplePizzeriaUI"
gui.ResetOnSpawn = false
gui.Parent = plr:WaitForChild("PlayerGui")

local function mk(c, props)
	local o = Instance.new(c)
	for k,v in pairs(props) do o[k] = v end
	return o
end

local hud = mk("Frame", {
	Parent = gui,
	Position = UDim2.fromOffset(12, 12),
	Size = UDim2.fromOffset(520, 54),
	BackgroundTransparency = 0.2
})

local hudText = mk("TextLabel", {
	Parent = hud,
	Size = UDim2.fromScale(1,1),
	BackgroundTransparency = 1,
	TextScaled = true,
	Text = "Loading..."
})

local toast = mk("TextLabel", {
	Parent = gui,
	Position = UDim2.fromOffset(12, 72),
	Size = UDim2.fromOffset(640, 44),
	BackgroundTransparency = 0.25,
	TextScaled = true,
	Text = ""
})

local panel = mk("Frame", {
	Parent = gui,
	AnchorPoint = Vector2.new(1,1),
	Position = UDim2.new(1,-12, 1,-12),
	Size = UDim2.fromOffset(420, 260),
	BackgroundTransparency = 0.12,
	Visible = false
})

mk("UICorner",{Parent=panel, CornerRadius=UDim.new(0,12)})
mk("UICorner",{Parent=hud, CornerRadius=UDim.new(0,12)})

local title = mk("TextLabel", {
	Parent = panel,
	Position = UDim2.fromOffset(12, 10),
	Size = UDim2.fromOffset(250, 32),
	BackgroundTransparency = 1,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "BUILD"
})

local closeBtn = mk("TextButton", {
	Parent = panel,
	AnchorPoint = Vector2.new(1,0),
	Position = UDim2.new(1,-12, 0, 10),
	Size = UDim2.fromOffset(90, 32),
	TextScaled = true,
	Text = "Close"
})

local modeRow = mk("Frame", {
	Parent = panel,
	Position = UDim2.fromOffset(12, 50),
	Size = UDim2.fromOffset(396, 36),
	BackgroundTransparency = 1
})

local roomsBtn = mk("TextButton", {
	Parent = modeRow,
	Position = UDim2.fromOffset(0,0),
	Size = UDim2.fromOffset(130, 36),
	TextScaled = true,
	Text = "Rooms"
})

local designBtn = mk("TextButton", {
	Parent = modeRow,
	Position = UDim2.fromOffset(140,0),
	Size = UDim2.fromOffset(130, 36),
	TextScaled = true,
	Text = "Design"
})

local actionBtn = mk("TextButton", {
	Parent = modeRow,
	Position = UDim2.fromOffset(280,0),
	Size = UDim2.fromOffset(116, 36),
	TextScaled = true,
	Text = "Place"
})

local grid = mk("Frame", {
	Parent = panel,
	Position = UDim2.fromOffset(12, 92),
	Size = UDim2.fromOffset(396, 120),
	BackgroundTransparency = 1
})

local rotateBtn = mk("TextButton", {
	Parent = panel,
	Position = UDim2.fromOffset(12, 220),
	Size = UDim2.fromOffset(130, 32),
	TextScaled = true,
	Text = "Rotate (R)"
})

local itemLabel = mk("TextLabel", {
	Parent = panel,
	Position = UDim2.fromOffset(152, 220),
	Size = UDim2.fromOffset(256, 32),
	BackgroundTransparency = 1,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "Item: Floor"
})

-- mobile quick button
local mobileBtn = mk("TextButton", {
	Parent = gui,
	AnchorPoint = Vector2.new(1,1),
	Position = UDim2.new(1,-12, 1,-290),
	Size = UDim2.fromOffset(140, 56),
	TextScaled = true,
	Text = "BUILD",
	Visible = UserInputService.TouchEnabled
})

local function toastMsg(t)
	toast.Text = t
	if t ~= "" then
		task.delay(2.0, function()
			if toast.Text == t then toast.Text = "" end
		end)
	end
end

Notify.OnClientEvent:Connect(toastMsg)

-- ===== Build State =====
local buildOpen = false
local mode = "Rooms" -- Rooms/Design
local action = "Place" -- Place/Delete
local selected = "Floor"
local yaw = 0

local roomItems = {"Floor","Wall","Door"}
local designItems = {"Table","Chair","Stage","Light","CCTV"}

local ghost = Instance.new("Part")
ghost.Name = "BuildGhost"
ghost.Anchored = true
ghost.CanCollide = false
ghost.Transparency = 0.6
ghost.Material = Enum.Material.ForceField
ghost.Parent = nil

local function getSizeFor(item)
	if item == "Floor" then return Vector3.new(Config.Grid,1,Config.Grid) end
	if item == "Wall" then return Vector3.new(Config.Grid,10,1) end
	if item == "Door" then return Vector3.new(6,10,2) end
	if item == "Table" then return Vector3.new(6,2,6) end
	if item == "Chair" then return Vector3.new(2,3,2) end
	if item == "Stage" then return Vector3.new(18,2,10) end
	if item == "Light" then return Vector3.new(1,1,1) end
	if item == "CCTV" then return Vector3.new(1,1,2) end
	return Vector3.new(4,2,4)
end

local function rebuildItemButtons()
	grid:ClearAllChildren()
	local list = (mode == "Rooms") and roomItems or designItems
	for i, name in ipairs(list) do
		local b = Instance.new("TextButton")
		b.Size = UDim2.fromOffset(120, 34)
		local col = (i-1) % 3
		local row = math.floor((i-1)/3)
		b.Position = UDim2.fromOffset(col*132, row*42)
		b.TextScaled = true
		b.Text = name
		b.Parent = grid
		b.MouseButton1Click:Connect(function()
			selected = name
			itemLabel.Text = "Item: "..selected
			ghost.Size = getSizeFor(selected)
		end)
	end
end

local function setMode(newMode)
	mode = newMode
	-- default selection
	selected = (mode == "Rooms") and "Floor" or "Table"
	itemLabel.Text = "Item: "..selected
	ghost.Size = getSizeFor(selected)
	rebuildItemButtons()

	-- camera handling for Rooms
	if buildOpen and mode == "Rooms" then
		cam.CameraType = Enum.CameraType.Scriptable
	elseif buildOpen and mode == "Design" then
		cam.CameraType = Enum.CameraType.Custom
	end
end

local function setAction(newAction)
	action = newAction
	actionBtn.Text = action
	ghost.Transparency = (action == "Delete") and 0.85 or 0.6
end

local function openBuild()
	buildOpen = true
	panel.Visible = true
	ghost.Parent = Workspace
	setMode(mode)
	setAction(action)
end

local function closeBuild()
	buildOpen = false
	panel.Visible = false
	ghost.Parent = nil
	cam.CameraType = Enum.CameraType.Custom
end

local function toggleBuild()
	if buildOpen then closeBuild() else openBuild() end
end

closeBtn.MouseButton1Click:Connect(closeBuild)
mobileBtn.MouseButton1Click:Connect(toggleBuild)

roomsBtn.MouseButton1Click:Connect(function() setMode("Rooms") end)
designBtn.MouseButton1Click:Connect(function() setMode("Design") end)

actionBtn.MouseButton1Click:Connect(function()
	setAction((action == "Place") and "Delete" or "Place")
end)

rotateBtn.MouseButton1Click:Connect(function()
	yaw = (yaw + 90) % 360
end)

-- keybinds
UserInputService.InputBegan:Connect(function(inp, gp)
	if gp then return end
	if inp.KeyCode == Enum.KeyCode.B then toggleBuild() end
	if not buildOpen then return end
	if inp.KeyCode == Enum.KeyCode.R then yaw = (yaw + 90) % 360 end
	if inp.KeyCode == Enum.KeyCode.X then setAction((action == "Place") and "Delete" or "Place") end
end)

-- ===== Placement Raycast (mouse + touch) =====
local function screenRay(screenPos)
	local ray = cam:ScreenPointToRay(screenPos.X, screenPos.Y)
	return ray.Origin, ray.Direction * 500
end

local function raycastAt(screenPos)
	local origin, dir = screenRay(screenPos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {plr.Character, ghost}
	return Workspace:Raycast(origin, dir, params)
end

local lastCF = CFrame.new()

local function computeCF(hitPos)
	if mode == "Rooms" then
		local snapped = Util.snapXZ(hitPos, Config.Grid, 1.5)
		return CFrame.new(snapped) * CFrame.Angles(0, math.rad(yaw), 0)
	else
		local p = Vector3.new(hitPos.X, 2, hitPos.Z)
		return CFrame.new(p) * CFrame.Angles(0, math.rad(yaw), 0)
	end
end

-- update ghost + rooms camera
RunService.RenderStepped:Connect(function()
	if not buildOpen then return end

	if mode == "Rooms" then
		local root = Util.getCharRoot(plr)
		if root then
			local base = root.Position
			cam.CFrame = CFrame.new(base + Vector3.new(0,110,0), base)
		end
	end

	local mousePos = UserInputService:GetMouseLocation()
	local hit = raycastAt(mousePos)
	if hit then
		lastCF = computeCF(hit.Position)
		ghost.Size = getSizeFor(selected)
		ghost.CFrame = lastCF
	end
end)

-- place/delete on click/tap
local clickCooldown = 0
local function tryAction(screenPos)
	if not buildOpen then return end
	if tick() < clickCooldown then return end
	clickCooldown = tick() + 0.12

	local hit = raycastAt(screenPos)
	if not hit then return end

	if action == "Place" then
		local cf = computeCF(hit.Position)
		PlaceBuildItem:FireServer(mode, selected, cf)
	else
		local inst = hit.Instance
		DeleteBuildItem:FireServer(inst)
	end
end

-- Mouse
UserInputService.InputBegan:Connect(function(inp, gp)
	if gp then return end
	if inp.UserInputType == Enum.UserInputType.MouseButton1 then
		tryAction(UserInputService:GetMouseLocation())
	elseif inp.UserInputType == Enum.UserInputType.Touch then
		tryAction(inp.Position)
	end
end)

-- Kid prompt hook
local function hookPrompt(prompt)
	if prompt.Name ~= "AskToFollowPrompt" then return end
	prompt.Triggered:Connect(function()
		local model = prompt:FindFirstAncestorOfClass("Model")
		if not model then return end
		local ok, msg = KidFollowRequest:InvokeServer(model)
		toastMsg(msg or "")
	end)
end

for _, d in ipairs(Workspace:GetDescendants()) do
	if d:IsA("ProximityPrompt") then hookPrompt(d) end
end
Workspace.DescendantAdded:Connect(function(d)
	if d:IsA("ProximityPrompt") then hookPrompt(d) end
end)

-- HUD update
local function setHUD()
	local heat = plr:GetAttribute("Heat") or 0
	local control = plr:GetAttribute("Control") or 0
	local money = 0
	local ls = plr:FindFirstChild("leaderstats")
	if ls and ls:FindFirstChild("Money") then money = ls.Money.Value end

	hudText.Text = ("Heat: %d | Control: %d | Money: %d  |  Build: %s (%s/%s)"):format(
		heat, control, money, buildOpen and "ON" or "OFF", mode, action
	)
end

plr:GetAttributeChangedSignal("Heat"):Connect(setHUD)
plr:GetAttributeChangedSignal("Control"):Connect(setHUD)
task.spawn(function()
	while true do
		setHUD()
		task.wait(0.4)
	end
end)

-- init
rebuildItemButtons()
setHUD()
toastMsg("Build fixed. B or BUILD button. R rotate. X delete mode.")
]])

print("[PATCH] Done. Press Play again. Build UI will appear (B / BUILD).")
