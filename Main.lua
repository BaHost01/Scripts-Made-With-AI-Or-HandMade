--[[
    ╔══════════════════════════════════════════╗
    ║       AIMBOT + ESP SYSTEM  v3.0          ║
    ║       2D Boxes | ESP | Aimbot            ║
    ╚══════════════════════════════════════════╝
--]]

--// ══════════════════════════════════════
--//  SERVICES
--// ══════════════════════════════════════
local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local UIS            = game:GetService("UserInputService")
local Camera         = workspace.CurrentCamera
local LP             = Players.LocalPlayer
local Mouse          = LP:GetMouse()

--// ══════════════════════════════════════
--//  PLATFORM DETECTION
--// ══════════════════════════════════════
local IsMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled

local function GetAimOrigin()
    if IsMobile then
        local vp = Camera.ViewportSize
        return Vector2.new(vp.X / 2, vp.Y / 2)
    end
    return Vector2.new(Mouse.X, Mouse.Y)
end

--// ══════════════════════════════════════
--//  SETTINGS TABLE
--// ══════════════════════════════════════
local S = {
    -- [ AIMBOT ]
    AimEnabled       = false,
    SilentAim        = false,
    AutoFire         = false,
    Prediction       = true,
    PredStrength     = 0.08,
    FOV              = 150,
    Smoothness       = 0.18,
    Spread           = 2,
    TargetPart       = "Head",
    Priority         = "Closest to Crosshair",

    -- [ FILTERS ]
    NPCEnabled       = false,
    TeamCheck        = true,
    WallCheck        = true,

    -- [ FOV CIRCLE ]
    ShowFOV          = true,
    FOVColor         = Color3.fromRGB(255, 255, 255),
    FOVThickness     = 1.5,

    -- [ ESP MASTER ]
    ESPEnabled       = true,
    MaxESPDist       = 500,

    -- [ 2D BOX ]
    ShowBoxes        = true,
    BoxColor         = Color3.fromRGB(255, 255, 255),
    BoxColorEnemy    = Color3.fromRGB(255, 60,  60),
    BoxColorNPC      = Color3.fromRGB(255, 165,  0),
    BoxThickness     = 1,
    BoxFilled        = false,
    BoxFillColor     = Color3.fromRGB(255, 255, 255),
    BoxFillTrans     = 0.85,

    -- [ NAME ]
    ShowNames        = true,
    NameColor        = Color3.fromRGB(255, 255, 255),
    NameSize         = 13,

    -- [ HEALTH BAR ]
    ShowHealthBar    = true,
    HealthBarWidth   = 3,

    -- [ DISTANCE ]
    ShowDistance     = true,
    DistColor        = Color3.fromRGB(180, 180, 180),
    DistSize         = 11,

    -- [ TRACER ]
    ShowTracers      = false,
    TracerColor      = Color3.fromRGB(255, 60, 60),
    TracerOrigin     = "Bottom",   -- "Bottom" | "Center"

    -- [ HIGHLIGHT ]
    ShowHighlight    = false,
    HighlightColor   = Color3.fromRGB(255, 60, 60),
    HighlightFillTrans = 0.55,

    -- [ TARGET DOT ]
    ShowTargetDot    = true,
}

--// ══════════════════════════════════════
--//  RAYFIELD UI
--// ══════════════════════════════════════
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name         = "Aim & ESP System",
    LoadingTitle = "Loading v3.0...",
    LoadingSubtitle = "Enhanced Edition",
    ConfigurationSaving = {
        Enabled  = true,
        FileName = "AimESP_v3"
    },
    KeySystem = false
})

local AimTab     = Window:CreateTab("Aimbot",    4483362458)
local ESPTab     = Window:CreateTab("ESP",       4483362458)
local BoxTab     = Window:CreateTab("2D Boxes",  4483362458)
local FilterTab  = Window:CreateTab("Filters",   4483362458)
local MiscTab    = Window:CreateTab("Misc",      4483362458)

--// ══════════════════════════════════════
--//  DRAWING: FOV CIRCLE
--// ══════════════════════════════════════
local FOVCircle        = Drawing.new("Circle")
FOVCircle.Radius       = S.FOV
FOVCircle.Filled       = false
FOVCircle.Thickness    = S.FOVThickness
FOVCircle.Color        = S.FOVColor
FOVCircle.Visible      = S.ShowFOV
FOVCircle.NumSides     = 64

--// ══════════════════════════════════════
--//  DRAWING: TARGET DOT
--// ══════════════════════════════════════
local TargetDot        = Drawing.new("Circle")
TargetDot.Radius       = 5
TargetDot.Filled       = true
TargetDot.Color        = Color3.fromRGB(255, 60, 60)
TargetDot.Visible      = false
TargetDot.NumSides     = 16

--// ══════════════════════════════════════
--//  HIGHLIGHT CACHE
--// ══════════════════════════════════════
local HighlightCache = {}

local function SetHighlight(char, enabled)
    if not char then return end
    local key = tostring(char)
    if enabled and S.ShowHighlight then
        if not HighlightCache[key] then
            local h = Instance.new("Highlight")
            h.FillColor          = S.HighlightColor
            h.OutlineColor       = Color3.fromRGB(255, 255, 255)
            h.FillTransparency   = S.HighlightFillTrans
            h.OutlineTransparency = 0
            h.Parent             = char
            HighlightCache[key]  = h
        end
    else
        if HighlightCache[key] then
            HighlightCache[key]:Destroy()
            HighlightCache[key] = nil
        end
    end
end

local function ClearAllHighlights()
    for k, h in pairs(HighlightCache) do
        if h and h.Parent then h:Destroy() end
        HighlightCache[k] = nil
    end
end

--// ══════════════════════════════════════
--//  ESP DRAWING CACHE
--// ══════════════════════════════════════
local ESPObjects = {} -- [char] = { lines, text, etc. }

local function NewLine(color, thickness)
    local l = Drawing.new("Line")
    l.Color     = color or Color3.fromRGB(255,255,255)
    l.Thickness = thickness or 1
    l.Visible   = false
    return l
end

local function NewText(size, color, center, outline)
    local t      = Drawing.new("Text")
    t.Size       = size   or 13
    t.Color      = color  or Color3.fromRGB(255,255,255)
    t.Center     = center ~= nil and center or true
    t.Outline    = outline ~= nil and outline or true
    t.Visible    = false
    t.Font       = Drawing.Fonts.UI
    return t
end

local function NewSquare(color, thickness, filled)
    local sq         = Drawing.new("Square")
    sq.Color         = color or Color3.fromRGB(255,255,255)
    sq.Thickness     = thickness or 1
    sq.Filled        = filled or false
    sq.Visible       = false
    return sq
end

local function CreateESPObject(char)
    local obj = {
        -- 2D Box (single Square drawing — much more efficient than 4 lines)
        box         = NewSquare(S.BoxColor,        S.BoxThickness, S.BoxFilled),
        boxFill     = NewSquare(S.BoxFillColor,    1,              true),

        -- Name tag
        name        = NewText(S.NameSize, S.NameColor, true, true),

        -- Distance label (below box)
        dist        = NewText(S.DistSize, S.DistColor, true, true),

        -- Health bar: background line + foreground line
        hpBG        = NewLine(Color3.fromRGB(0,   0,   0),   3),
        hpFG        = NewLine(Color3.fromRGB(0,   255, 60),  3),

        -- Tracer
        tracer      = NewLine(S.TracerColor, 1),
    }
    obj.boxFill.Transparency = S.BoxFillTrans
    return obj
end

local function DestroyESPObject(obj)
    if not obj then return end
    for _, d in pairs(obj) do
        if typeof(d) == "Instance" or (type(d) == "table" and d.Remove) then
            pcall(function() d:Remove() end)
        end
    end
end

local function GetOrCreateESP(char)
    if not ESPObjects[char] then
        ESPObjects[char] = CreateESPObject(char)
    end
    return ESPObjects[char]
end

local function HideESP(obj)
    if not obj then return end
    obj.box.Visible     = false
    obj.boxFill.Visible = false
    obj.name.Visible    = false
    obj.dist.Visible    = false
    obj.hpBG.Visible    = false
    obj.hpFG.Visible    = false
    obj.tracer.Visible  = false
end

local function RemoveCharESP(char)
    local obj = ESPObjects[char]
    if obj then
        DestroyESPObject(obj)
        ESPObjects[char] = nil
    end
    SetHighlight(char, false)
end

--// ══════════════════════════════════════
--//  2D BOUNDING BOX CALCULATION
--// ══════════════════════════════════════
local function Get2DBox(char)
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    if not hrp or not head then return nil end

    -- Top = above head, Bottom = feet
    local topWorld = head.Position + Vector3.new(0, head.Size.Y * 0.5 + 0.05, 0)
    local botWorld = hrp.Position  - Vector3.new(0, hrp.Size.Y * 0.5 + 1.6,  0)

    local topSP, topVis = Camera:WorldToViewportPoint(topWorld)
    local botSP         = Camera:WorldToViewportPoint(botWorld)

    if not topVis or topSP.Z <= 0 then return nil end

    -- Width via side projection from HRP orientation
    local right       = hrp.CFrame.RightVector
    local halfW       = 1.1  -- studs (rough shoulder width)
    local leftSP      = Camera:WorldToViewportPoint(hrp.Position + right *  halfW)
    local rightSP     = Camera:WorldToViewportPoint(hrp.Position + right * -halfW)

    local x1 = math.min(leftSP.X, rightSP.X)
    local x2 = math.max(leftSP.X, rightSP.X)
    local y1 = math.min(topSP.Y,  botSP.Y)
    local y2 = math.max(topSP.Y,  botSP.Y)

    return {
        X      = x1,
        Y      = y1,
        W      = x2 - x1,
        H      = y2 - y1,
        CenterX = (x1 + x2) / 2,
        CenterY = (y1 + y2) / 2,
        Depth  = topSP.Z,
    }
end

--// ══════════════════════════════════════
--//  HEALTH COLOR GRADIENT
--// ══════════════════════════════════════
local function GetHealthColor(pct)
    -- Red → Yellow → Green
    if pct > 0.5 then
        return Color3.fromRGB(
            math.floor((1 - pct) * 2 * 255),
            255,
            0
        )
    else
        return Color3.fromRGB(
            255,
            math.floor(pct * 2 * 255),
            0
        )
    end
end

--// ══════════════════════════════════════
--//  UPDATE ESP FOR A SINGLE CHARACTER
--// ══════════════════════════════════════
local function UpdateESP(char, isPlayer)
    local obj      = GetOrCreateESP(char)
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local head     = char:FindFirstChild("Head")
    if not humanoid or not head or humanoid.Health <= 0 then
        HideESP(obj)
        return
    end

    -- Distance check
    local dist3D = (Camera.CFrame.Position - head.Position).Magnitude
    if dist3D > S.MaxESPDist then
        HideESP(obj)
        return
    end

    local box = Get2DBox(char)
    if not box then
        HideESP(obj)
        return
    end

    -- Box color based on type
    local bColor = isPlayer and S.BoxColorEnemy or S.BoxColorNPC

    --// 2D BOX
    if S.ShowBoxes then
        obj.box.Position  = Vector2.new(box.X, box.Y)
        obj.box.Size      = Vector2.new(box.W, box.H)
        obj.box.Color     = bColor
        obj.box.Thickness = S.BoxThickness
        obj.box.Filled    = false
        obj.box.Visible   = true

        if S.BoxFilled then
            obj.boxFill.Position     = Vector2.new(box.X, box.Y)
            obj.boxFill.Size         = Vector2.new(box.W, box.H)
            obj.boxFill.Color        = S.BoxFillColor
            obj.boxFill.Transparency = S.BoxFillTrans
            obj.boxFill.Filled       = true
            obj.boxFill.Visible      = true
        else
            obj.boxFill.Visible = false
        end
    else
        obj.box.Visible     = false
        obj.boxFill.Visible = false
    end

    --// NAME TAG
    if S.ShowNames then
        local label = isPlayer
            and Players:GetPlayerFromCharacter(char).Name
            or  (char.Name)
        obj.name.Text     = label
        obj.name.Color    = S.NameColor
        obj.name.Size     = S.NameSize
        obj.name.Position = Vector2.new(box.CenterX, box.Y - S.NameSize - 2)
        obj.name.Visible  = true
    else
        obj.name.Visible  = false
    end

    --// DISTANCE
    if S.ShowDistance then
        obj.dist.Text     = string.format("%.0f studs", dist3D)
        obj.dist.Color    = S.DistColor
        obj.dist.Size     = S.DistSize
        obj.dist.Position = Vector2.new(box.CenterX, box.Y + box.H + 2)
        obj.dist.Visible  = true
    else
        obj.dist.Visible  = false
    end

    --// HEALTH BAR (left side, vertical)
    if S.ShowHealthBar then
        local hpPct  = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
        local barX   = box.X - 5
        local barTop = box.Y
        local barBot = box.Y + box.H
        local barH   = box.H

        -- BG (full bar, dark)
        obj.hpBG.From    = Vector2.new(barX, barTop)
        obj.hpBG.To      = Vector2.new(barX, barBot)
        obj.hpBG.Color   = Color3.fromRGB(30, 30, 30)
        obj.hpBG.Visible = true

        -- FG (health portion, colored)
        local fgTo = barTop + barH * (1 - hpPct)
        obj.hpFG.From    = Vector2.new(barX, fgTo)
        obj.hpFG.To      = Vector2.new(barX, barBot)
        obj.hpFG.Color   = GetHealthColor(hpPct)
        obj.hpFG.Visible = true
    else
        obj.hpBG.Visible = false
        obj.hpFG.Visible = false
    end

    --// TRACER
    if S.ShowTracers then
        local vp    = Camera.ViewportSize
        local fromY = S.TracerOrigin == "Center" and vp.Y / 2 or vp.Y
        obj.tracer.From    = Vector2.new(vp.X / 2, fromY)
        obj.tracer.To      = Vector2.new(box.CenterX, box.Y + box.H)
        obj.tracer.Color   = S.TracerColor
        obj.tracer.Visible = true
    else
        obj.tracer.Visible = false
    end

    --// HIGHLIGHT
    SetHighlight(char, true)
end

--// ══════════════════════════════════════
--//  WALL CHECK  (new RaycastParams API)
--// ══════════════════════════════════════
local function CheckWall(targetPart)
    if not S.WallCheck then return true end
    local origin    = Camera.CFrame.Position
    local direction = targetPart.Position - origin
    local params    = RaycastParams.new()
    params.FilterDescendantsInstances = {LP.Character, targetPart.Parent}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local result = workspace:Raycast(origin, direction, params)
    return result == nil
end

--// ══════════════════════════════════════
--//  VELOCITY PREDICTION
--// ══════════════════════════════════════
local function Predict(part)
    if not S.Prediction then return part.Position end
    local ok, vel = pcall(function() return part.AssemblyLinearVelocity end)
    if ok and vel then
        return part.Position + (vel * S.PredStrength)
    end
    return part.Position
end

--// ══════════════════════════════════════
--//  GET BEST TARGET
--// ══════════════════════════════════════
local function GetTarget()
    local best      = nil
    local bestScore = math.huge
    local origin    = GetAimOrigin()

    for _, char in ipairs(workspace:GetChildren()) do
        -- Check if it's a character model
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        local hrp      = char:FindFirstChild("HumanoidRootPart")
        local part     = char:FindFirstChild(S.TargetPart) or char:FindFirstChild("Head")
        if not humanoid or not hrp or not part then continue end
        if humanoid.Health <= 0 then continue end
        if char == LP.Character then continue end

        local player = Players:GetPlayerFromCharacter(char)
        if player then
            if S.TeamCheck and player.Team and player.Team == LP.Team then continue end
        else
            if not S.NPCEnabled then continue end
        end

        local sp, vis = Camera:WorldToViewportPoint(part.Position)
        if not vis or sp.Z <= 0 then continue end

        local dist2D = (Vector2.new(sp.X, sp.Y) - origin).Magnitude
        if dist2D > S.FOV then continue end

        local score
        if S.Priority == "Closest to Crosshair" then
            score = dist2D
        elseif S.Priority == "Lowest Health" then
            score = humanoid.Health
        elseif S.Priority == "Closest Distance" then
            score = (Camera.CFrame.Position - part.Position).Magnitude
        else
            score = dist2D
        end

        if score < bestScore then
            bestScore = score
            best      = part
        end
    end

    return best
end

--// ══════════════════════════════════════
--//  BUILD UI — AIMBOT TAB
--// ══════════════════════════════════════
AimTab:CreateSection("Core")

AimTab:CreateToggle({
    Name = "Enable Aimbot", CurrentValue = false, Flag = "AimEnabled",
    Callback = function(v) S.AimEnabled = v end
})
AimTab:CreateToggle({
    Name = "Auto Attack", CurrentValue = false, Flag = "AutoFire",
    Callback = function(v) S.AutoFire = v end
})
AimTab:CreateToggle({
    Name = "Silent Aim", CurrentValue = false, Flag = "SilentAim",
    Callback = function(v) S.SilentAim = v end
})
AimTab:CreateToggle({
    Name = "Velocity Prediction", CurrentValue = true, Flag = "Prediction",
    Callback = function(v) S.Prediction = v end
})

AimTab:CreateSection("Parameters")

AimTab:CreateSlider({
    Name = "FOV Radius", Range = {30, 450}, Increment = 5,
    CurrentValue = 150, Flag = "FOVRadius",
    Callback = function(v)
        S.FOV = v
        FOVCircle.Radius = v
    end
})
AimTab:CreateSlider({
    Name = "Smoothness  (lower = faster)", Range = {1, 100}, Increment = 1,
    CurrentValue = 18, Flag = "Smoothness",
    Callback = function(v) S.Smoothness = v / 100 end
})
AimTab:CreateSlider({
    Name = "Spread", Range = {0, 20}, Increment = 1,
    CurrentValue = 2, Flag = "Spread",
    Callback = function(v) S.Spread = v end
})
AimTab:CreateSlider({
    Name = "Prediction Strength", Range = {0, 30}, Increment = 1,
    CurrentValue = 8, Flag = "PredStr",
    Callback = function(v) S.PredStrength = v / 100 end
})

AimTab:CreateSection("Target")

AimTab:CreateDropdown({
    Name = "Priority",
    Options = {"Closest to Crosshair", "Lowest Health", "Closest Distance"},
    CurrentOption = {"Closest to Crosshair"}, Flag = "Priority",
    Callback = function(o) S.Priority = o[1] end
})
AimTab:CreateDropdown({
    Name = "Target Body Part",
    Options = {"Head", "HumanoidRootPart", "UpperTorso", "Torso"},
    CurrentOption = {"Head"}, Flag = "TargetPart",
    Callback = function(o) S.TargetPart = o[1] end
})

AimTab:CreateSection("FOV Circle")

AimTab:CreateToggle({
    Name = "Show FOV Circle", CurrentValue = true, Flag = "ShowFOV",
    Callback = function(v)
        S.ShowFOV = v
        FOVCircle.Visible = v
    end
})
AimTab:CreateToggle({
    Name = "Show Target Dot", CurrentValue = true, Flag = "ShowDot",
    Callback = function(v) S.ShowTargetDot = v end
})

--// ══════════════════════════════════════
--//  BUILD UI — ESP TAB
--// ══════════════════════════════════════
ESPTab:CreateSection("Master")

ESPTab:CreateToggle({
    Name = "Enable ESP", CurrentValue = true, Flag = "ESPEnabled",
    Callback = function(v)
        S.ESPEnabled = v
        if not v then
            for char, obj in pairs(ESPObjects) do HideESP(obj) end
            ClearAllHighlights()
        end
    end
})

ESPTab:CreateSlider({
    Name = "Max ESP Distance (studs)", Range = {50, 2000}, Increment = 50,
    CurrentValue = 500, Flag = "MaxESPDist",
    Callback = function(v) S.MaxESPDist = v end
})

ESPTab:CreateSection("Elements")

ESPTab:CreateToggle({
    Name = "Names", CurrentValue = true, Flag = "ShowNames",
    Callback = function(v) S.ShowNames = v end
})
ESPTab:CreateToggle({
    Name = "Health Bar", CurrentValue = true, Flag = "ShowHP",
    Callback = function(v) S.ShowHealthBar = v end
})
ESPTab:CreateToggle({
    Name = "Distance", CurrentValue = true, Flag = "ShowDist",
    Callback = function(v) S.ShowDistance = v end
})
ESPTab:CreateToggle({
    Name = "Tracers", CurrentValue = false, Flag = "ShowTracers",
    Callback = function(v) S.ShowTracers = v end
})
ESPTab:CreateToggle({
    Name = "Highlight (3D)", CurrentValue = false, Flag = "ShowHL",
    Callback = function(v)
        S.ShowHighlight = v
        if not v then ClearAllHighlights() end
    end
})

ESPTab:CreateSection("Tracer Options")

ESPTab:CreateDropdown({
    Name = "Tracer Origin",
    Options = {"Bottom", "Center"},
    CurrentOption = {"Bottom"}, Flag = "TracerOrigin",
    Callback = function(o) S.TracerOrigin = o[1] end
})

ESPTab:CreateSection("Text Sizes")

ESPTab:CreateSlider({
    Name = "Name Size", Range = {8, 24}, Increment = 1,
    CurrentValue = 13, Flag = "NameSize",
    Callback = function(v) S.NameSize = v end
})
ESPTab:CreateSlider({
    Name = "Distance Size", Range = {8, 20}, Increment = 1,
    CurrentValue = 11, Flag = "DistSize",
    Callback = function(v) S.DistSize = v end
})

--// ══════════════════════════════════════
--//  BUILD UI — 2D BOXES TAB
--// ══════════════════════════════════════
BoxTab:CreateSection("Box Settings")

BoxTab:CreateToggle({
    Name = "Show 2D Boxes", CurrentValue = true, Flag = "ShowBoxes",
    Callback = function(v) S.ShowBoxes = v end
})
BoxTab:CreateToggle({
    Name = "Filled Box", CurrentValue = false, Flag = "BoxFilled",
    Callback = function(v) S.BoxFilled = v end
})

BoxTab:CreateSlider({
    Name = "Box Thickness", Range = {1, 4}, Increment = 1,
    CurrentValue = 1, Flag = "BoxThick",
    Callback = function(v) S.BoxThickness = v end
})

BoxTab:CreateSection("Box Colors")

BoxTab:CreateLabel("Enemy box: Red  |  NPC box: Orange  |  (color toggles below)")

BoxTab:CreateToggle({
    Name = "Use Colored Box per Type", CurrentValue = true, Flag = "ColoredBox",
    Callback = function(v)
        if not v then
            S.BoxColorEnemy = Color3.fromRGB(255, 255, 255)
            S.BoxColorNPC   = Color3.fromRGB(255, 255, 255)
        else
            S.BoxColorEnemy = Color3.fromRGB(255, 60, 60)
            S.BoxColorNPC   = Color3.fromRGB(255, 165, 0)
        end
    end
})

BoxTab:CreateSlider({
    Name = "Fill Transparency (0=opaque)", Range = {0, 100}, Increment = 5,
    CurrentValue = 85, Flag = "FillTrans",
    Callback = function(v)
        S.BoxFillTrans = v / 100
    end
})

--// ══════════════════════════════════════
--//  BUILD UI — FILTERS TAB
--// ══════════════════════════════════════
FilterTab:CreateSection("Target Filters")

FilterTab:CreateToggle({
    Name = "Target NPCs", CurrentValue = false, Flag = "NPCEnabled",
    Callback = function(v) S.NPCEnabled = v end
})
FilterTab:CreateToggle({
    Name = "Team Check", CurrentValue = true, Flag = "TeamCheck",
    Callback = function(v) S.TeamCheck = v end
})
FilterTab:CreateToggle({
    Name = "Wall Check (Aimbot)", CurrentValue = true, Flag = "WallCheck",
    Callback = function(v) S.WallCheck = v end
})

--// ══════════════════════════════════════
--//  BUILD UI — MISC TAB
--// ══════════════════════════════════════
MiscTab:CreateSection("Utilities")

MiscTab:CreateButton({
    Name = "Clear All Highlights",
    Callback = function()
        ClearAllHighlights()
        Rayfield:Notify({ Title = "Done", Content = "Highlights cleared.", Duration = 2 })
    end
})

MiscTab:CreateButton({
    Name = "Destroy All ESP",
    Callback = function()
        for char, obj in pairs(ESPObjects) do
            DestroyESPObject(obj)
        end
        ESPObjects = {}
        ClearAllHighlights()
        Rayfield:Notify({ Title = "Done", Content = "All ESP destroyed.", Duration = 2 })
    end
})

MiscTab:CreateButton({
    Name = "Reset to Defaults",
    Callback = function()
        S.AimEnabled  = false
        S.ESPEnabled  = true
        S.FOV         = 150
        S.Smoothness  = 0.18
        S.Spread      = 2
        FOVCircle.Radius = 150
        Rayfield:Notify({ Title = "Reset", Content = "Settings restored to defaults.", Duration = 3 })
    end
})

MiscTab:CreateSection("Info")
MiscTab:CreateLabel("Platform : " .. (IsMobile and "Mobile (Screen-Center Aim)" or "PC (Mouse Aim)"))
MiscTab:CreateLabel("ESP draws per workspace child — optimized loop")
MiscTab:CreateLabel("Box type: Square drawing (1 call vs 4 lines)")

--// ══════════════════════════════════════
--//  THROTTLE COUNTER  (ESP every N frames)
--// ══════════════════════════════════════
local frameCount   = 0
local ESP_INTERVAL = 2   -- update ESP every 2 frames (~30fps equivalent at 60fps)

--// ══════════════════════════════════════
--//  MAIN RENDER LOOP
--// ══════════════════════════════════════
local lastTarget = nil

RunService.RenderStepped:Connect(function()
    frameCount = frameCount + 1
    local origin = GetAimOrigin()

    -- Always update FOV circle position
    FOVCircle.Position = origin

    --// ── AIMBOT ──────────────────────────
    local target = GetTarget()

    if target ~= lastTarget then
        if lastTarget and lastTarget.Parent then
            -- nothing needed here; ESP loop handles highlight
        end
        lastTarget = target
    end

    if target then
        if S.ShowTargetDot then
            local sp = Camera:WorldToViewportPoint(target.Position)
            TargetDot.Position = Vector2.new(sp.X, sp.Y)
            TargetDot.Visible  = true
        else
            TargetDot.Visible = false
        end

        if S.AimEnabled and CheckWall(target) then
            local aimPos = Predict(target)
            local spread = S.Spread / 10
            aimPos = aimPos + Vector3.new(
                (math.random() * 2 - 1) * spread,
                (math.random() * 2 - 1) * spread,
                (math.random() * 2 - 1) * spread
            )

            if not S.SilentAim then
                Camera.CFrame = Camera.CFrame:Lerp(
                    CFrame.new(Camera.CFrame.Position, aimPos),
                    S.Smoothness
                )
            end

            if S.AutoFire then
                pcall(function()
                    if IsMobile then
                        -- on mobile we can only attempt click simulation
                    else
                        mouse1press()
                        task.wait(0.05)
                        mouse1release()
                    end
                end)
            end
        end
    else
        TargetDot.Visible = false
    end

    --// ── ESP (throttled) ─────────────────
    if frameCount % ESP_INTERVAL ~= 0 then return end

    if not S.ESPEnabled then return end

    -- Track which chars were seen this frame
    local seen = {}

    for _, char in ipairs(workspace:GetChildren()) do
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end
        if char == LP.Character then continue end

        local player   = Players:GetPlayerFromCharacter(char)
        local isPlayer = player ~= nil

        if not isPlayer and not S.NPCEnabled then continue end
        if isPlayer and S.TeamCheck
            and player.Team and player.Team == LP.Team then continue end

        seen[char] = true
        UpdateESP(char, isPlayer)
    end

    -- Clean up ESP for characters no longer in workspace
    for char, _ in pairs(ESPObjects) do
        if not seen[char] then
            HideESP(ESPObjects[char])
            -- Don't destroy yet — character might respawn; just hide
        end
    end
end)

--// ══════════════════════════════════════
--//  CLEANUP HOOKS
--// ══════════════════════════════════════
LP.CharacterRemoving:Connect(function()
    ClearAllHighlights()
end)

Players.PlayerRemoving:Connect(function(player)
    local char = player.Character
    if char then
        RemoveCharESP(char)
    end
end)

-- Clean up ESP when a character model is removed
workspace.ChildRemoved:Connect(function(child)
    if ESPObjects[child] then
        RemoveCharESP(child)
    end
end)

--// ══════════════════════════════════════
--//  LOAD SAVED CONFIG + NOTIFY
--// ══════════════════════════════════════
Rayfield:LoadConfiguration()

Rayfield:Notify({
    Title    = "Aim & ESP v3.0 Loaded",
    Content  = "2D Boxes + Full ESP active. Platform: " .. (IsMobile and "Mobile" or "PC"),
    Duration = 5,
    Image    = 4483362458
})
