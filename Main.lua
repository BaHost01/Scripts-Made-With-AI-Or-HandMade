--[[
    ╔══════════════════════════════════════════════╗
    ║     AIMBOT + 2D BOX ESP  v4.0                ║
    ║     Full/Corner Boxes · Camera+1 Aimbot      ║
    ║     Optimized · Instant Death Cleanup        ║
    ╚══════════════════════════════════════════════╝
--]]

--// ═══════════════════════════════════════════
--//  SERVICES
--// ═══════════════════════════════════════════
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local Camera     = workspace.CurrentCamera
local LP         = Players.LocalPlayer
local Mouse      = LP:GetMouse()

--// ═══════════════════════════════════════════
--//  PLATFORM  +  CHARACTER CACHE
--// ═══════════════════════════════════════════
local IsMobile  = UIS.TouchEnabled and not UIS.KeyboardEnabled
local LPChar    = LP.Character  -- cached, updated via event below

LP.CharacterAdded:Connect(function(c)
    LPChar = c
end)
LP.CharacterRemoving:Connect(function()
    LPChar = nil
end)

local function GetAimOrigin()
    if IsMobile then
        local vp = Camera.ViewportSize
        return Vector2.new(vp.X * 0.5, vp.Y * 0.5)
    end
    return Vector2.new(Mouse.X, Mouse.Y)
end

--// ═══════════════════════════════════════════
--//  SETTINGS
--// ═══════════════════════════════════════════
local S = {
    -- AIMBOT
    AimEnabled   = false,
    AutoFire     = false,
    Prediction   = true,
    PredStrength = 0.08,
    FOV          = 150,
    Smoothness   = 0.18,
    Spread       = 2,
    RequireADS   = true,
    VisibleOnly  = false,
    TargetPart   = "Head",
    Priority     = "Closest to Crosshair",
    WallCheck    = true,
    StickyAim    = true,
    StickyTime   = 0.35,
    AutoFireDelay = 0.08,
    TargetSwitchDelay = 0.12,
    Deadzone     = 4,
    AliveCheck   = true,
    AdaptiveSmooth = true,
    AdaptiveMinSmooth = 0.1,

    -- FILTERS
    NPCEnabled   = false,
    TeamCheck    = true,

    -- FOV DRAWING
    ShowFOV      = true,
    ShowDot      = true,
    DynamicFOVColor = true,

    -- 2D BOXES
    BoxEnabled   = true,
    BoxStyle     = "Corner",       -- "Full" | "Corner"
    BoxColorEnemy = Color3.fromRGB(255,  55,  55),
    BoxColorNPC   = Color3.fromRGB(255, 165,   0),
    BoxThickness  = 1.5,
    BoxFilled     = false,
    BoxFillTrans  = 0.85,
    CornerLen     = 0.25,          -- fraction of box size per corner arm

    -- LABELS
    ShowNames    = true,
    NameSize     = 13,
    NameColor    = Color3.fromRGB(255, 255, 255),
    ShowDistance = true,
    DistSize     = 11,
    DistColor    = Color3.fromRGB(180, 180, 180),

    -- HEALTH BAR
    ShowHealthBar = true,

    -- TRACERS
    ShowTracers  = false,
    TracerOrigin = "Bottom",       -- "Bottom" | "Center"
    TracerColor  = Color3.fromRGB(255, 55, 55),

    -- DISTANCE LIMIT
    MaxDist      = 500,
}

local LastFireClock = 0
local LockedTarget = nil
local LockedUntil = 0
local LastTarget = nil
local LastSwitchClock = 0

--// ═══════════════════════════════════════════
--//  GLOBAL RAYCAST PARAMS  (created ONCE)
--//  Reusing avoids per-call allocation.
--//  We update FilterDescendantsInstances in-place.
--// ═══════════════════════════════════════════
local WallParams = RaycastParams.new()
WallParams.FilterType = Enum.RaycastFilterType.Exclude

--// ═══════════════════════════════════════════
--//  DRAWING FACTORIES
--// ═══════════════════════════════════════════
local function MakeLine(col, thick)
    local d = Drawing.new("Line")
    d.Color, d.Thickness, d.Visible = col or Color3.new(1,1,1), thick or 1, false
    return d
end
local function MakeText(sz, col)
    local d = Drawing.new("Text")
    d.Size, d.Color, d.Center, d.Outline, d.Visible, d.Font =
        sz or 13, col or Color3.new(1,1,1), true, true, false, Drawing.Fonts.UI
    return d
end
local function MakeSquare(col, thick)
    local d = Drawing.new("Square")
    d.Color, d.Thickness, d.Filled, d.Visible = col or Color3.new(1,1,1), thick or 1, false, false
    return d
end

--// ═══════════════════════════════════════════
--//  FOV CIRCLE  +  TARGET DOT
--// ═══════════════════════════════════════════
local FOVCircle  = Drawing.new("Circle")
FOVCircle.Radius, FOVCircle.Filled, FOVCircle.Thickness = S.FOV, false, 1.5
FOVCircle.Color, FOVCircle.Visible, FOVCircle.NumSides   = Color3.new(1,1,1), S.ShowFOV, 64

local TargetDot = Drawing.new("Circle")
TargetDot.Radius, TargetDot.Filled, TargetDot.Color = 5, true, Color3.fromRGB(255,55,55)
TargetDot.Visible, TargetDot.NumSides = false, 16

--// ═══════════════════════════════════════════
--//  BOX POOL
--//
--//  Each entry holds BOTH a full-box square AND 8
--//  corner lines.  Only one set is made visible at
--//  a time depending on S.BoxStyle.  Since hidden
--//  drawings have zero render cost, there is no
--//  penalty for keeping both allocated.
--//
--//  Layout keys:
--//    sq       – Square (full box outline)
--//    sqFill   – Square (filled overlay)
--//    tl/tr/bl/br  _h/_v  – 8 corner Line pairs
--//    name, dist           – Text labels
--//    hpBG, hpFG           – health bar lines
--//    tracer               – tracer line
--//    _diedConn            – Humanoid.Died connection
--// ═══════════════════════════════════════════
local Pool = {}   -- [char] = entry

-- All Drawing keys in one place (used for bulk hide/destroy)
local DRAW_KEYS = {
    "sq","sqFill",
    "tlh","tlv","trh","trv","blh","blv","brh","brv",
    "name","dist","hpBG","hpFG","tracer"
}

local function MakeEntry(char)
    local e = {
        -- full box
        sq      = MakeSquare(S.BoxColorEnemy, S.BoxThickness),
        sqFill  = MakeSquare(S.BoxColorEnemy, 1),
        -- corner lines  (tl = top-left, tr = top-right, bl, br; h/v = horizontal/vertical)
        tlh = MakeLine(S.BoxColorEnemy, S.BoxThickness),
        tlv = MakeLine(S.BoxColorEnemy, S.BoxThickness),
        trh = MakeLine(S.BoxColorEnemy, S.BoxThickness),
        trv = MakeLine(S.BoxColorEnemy, S.BoxThickness),
        blh = MakeLine(S.BoxColorEnemy, S.BoxThickness),
        blv = MakeLine(S.BoxColorEnemy, S.BoxThickness),
        brh = MakeLine(S.BoxColorEnemy, S.BoxThickness),
        brv = MakeLine(S.BoxColorEnemy, S.BoxThickness),
        -- labels
        name   = MakeText(S.NameSize,  S.NameColor),
        dist   = MakeText(S.DistSize,  S.DistColor),
        -- health bar
        hpBG   = MakeLine(Color3.fromRGB(20, 20, 20), 3),
        hpFG   = MakeLine(Color3.fromRGB(0, 220, 50), 3),
        -- tracer
        tracer = MakeLine(S.TracerColor, 1),
    }
    e.sqFill.Filled       = true
    e.sqFill.Transparency = S.BoxFillTrans

    -- Bind Humanoid.Died → instant removal (does NOT wait for next tick)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        e._diedConn = hum.Died:Connect(function()
            if Pool[char] then
                Pool[char] = nil
                for _, k in ipairs(DRAW_KEYS) do
                    pcall(function() e[k]:Remove() end)
                end
                pcall(function() e._diedConn:Disconnect() end)
            end
        end)
    end

    Pool[char] = e
    return e
end

local function DestroyEntry(char)
    local e = Pool[char]
    if not e then return end
    Pool[char] = nil
    if e._diedConn then pcall(function() e._diedConn:Disconnect() end) end
    for _, k in ipairs(DRAW_KEYS) do
        pcall(function() e[k]:Remove() end)
    end
end

local function HideEntry(e)
    if not e then return end
    for _, k in ipairs(DRAW_KEYS) do
        if e[k] then e[k].Visible = false end
    end
end

local function IsHumAlive(hum)
    if not hum then return false end
    if hum.Health <= 0 then return false end
    if not S.AliveCheck then return true end

    local ok, state = pcall(function()
        return hum:GetState()
    end)
    if ok and state == Enum.HumanoidStateType.Dead then
        return false
    end

    return true
end

local function IsCharacterAlive(char)
    if not char or not char.Parent then return false end
    if not char:IsDescendantOf(workspace) then return false end

    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    if not hum or not hrp or not head then return false end

    return IsHumAlive(hum)
end

--// ═══════════════════════════════════════════
--//  2D BOUNDING BOX CALCULATOR
--// ═══════════════════════════════════════════
local function GetBox(char)
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    if not hrp or not head then return nil end

    -- Quick 3D cull before any projection
    if (Camera.CFrame.Position - hrp.Position).Magnitude > S.MaxDist then return nil end

    local topW = head.Position + Vector3.new(0, head.Size.Y * 0.5 + 0.1,  0)
    local botW = hrp.Position  - Vector3.new(0, hrp.Size.Y  * 0.5 + 1.65, 0)

    local topSP, vis = Camera:WorldToViewportPoint(topW)
    if not vis or topSP.Z <= 0 then return nil end
    local botSP = Camera:WorldToViewportPoint(botW)

    -- Width from shoulder projection (avoids fixed-pixel guessing)
    local rgt  = hrp.CFrame.RightVector
    local lSP  = Camera:WorldToViewportPoint(hrp.Position + rgt *  1.1)
    local rSP  = Camera:WorldToViewportPoint(hrp.Position - rgt *  1.1)

    local x1 = math.min(lSP.X,  rSP.X)
    local x2 = math.max(lSP.X,  rSP.X)
    local y1 = math.min(topSP.Y, botSP.Y)
    local y2 = math.max(topSP.Y, botSP.Y)

    return x1, y1, x2 - x1, y2 - y1   -- x, y, w, h
end

--// ═══════════════════════════════════════════
--//  HEALTH GRADIENT  (Red → Yellow → Green)
--// ═══════════════════════════════════════════
local function HpColor(pct)
    pct = math.clamp(pct, 0, 1)
    return pct > 0.5
        and Color3.fromRGB(math.floor((1 - pct) * 510), 255, 0)
        or  Color3.fromRGB(255, math.floor(pct * 510), 0)
end

--// ═══════════════════════════════════════════
--//  UPDATE BOX FOR ONE CHARACTER
--// ═══════════════════════════════════════════
local function UpdateBox(char, isPlayer)
    local hum  = char:FindFirstChildOfClass("Humanoid")
    local head = char:FindFirstChild("Head")
    if not hum or not head or hum.Health <= 0 then
        HideEntry(Pool[char])
        return
    end

    local bx, by, bw, bh = GetBox(char)
    if not bx then
        HideEntry(Pool[char])
        return
    end

    local e    = Pool[char] or MakeEntry(char)
    local col  = isPlayer and S.BoxColorEnemy or S.BoxColorNPC
    local midX = bx + bw * 0.5

    -- ── BOX DRAWING ────────────────────────────────────────
    if not S.BoxEnabled then
        e.sq.Visible  = false
        e.sqFill.Visible = false
        for _, k in ipairs({"tlh","tlv","trh","trv","blh","blv","brh","brv"}) do
            e[k].Visible = false
        end

    elseif S.BoxStyle == "Full" then
        -- hide corner lines
        for _, k in ipairs({"tlh","tlv","trh","trv","blh","blv","brh","brv"}) do
            e[k].Visible = false
        end
        -- update Square
        e.sq.Position  = Vector2.new(bx, by)
        e.sq.Size      = Vector2.new(bw, bh)
        e.sq.Color     = col
        e.sq.Thickness = S.BoxThickness
        e.sq.Filled    = false
        e.sq.Visible   = true
        -- filled overlay
        if S.BoxFilled then
            e.sqFill.Position     = Vector2.new(bx, by)
            e.sqFill.Size         = Vector2.new(bw, bh)
            e.sqFill.Color        = col
            e.sqFill.Transparency = S.BoxFillTrans
            e.sqFill.Visible      = true
        else
            e.sqFill.Visible = false
        end

    elseif S.BoxStyle == "Corner" then
        -- hide full square
        e.sq.Visible     = false
        e.sqFill.Visible = false

        -- Corner arm lengths
        local cx = math.max(4, bw * S.CornerLen)
        local cy = math.max(4, bh * S.CornerLen)
        local thick = S.BoxThickness

        --  top-left
        e.tlh.From, e.tlh.To = Vector2.new(bx, by),          Vector2.new(bx + cx, by)
        e.tlv.From, e.tlv.To = Vector2.new(bx, by),          Vector2.new(bx, by + cy)
        --  top-right
        e.trh.From, e.trh.To = Vector2.new(bx+bw-cx, by),    Vector2.new(bx+bw, by)
        e.trv.From, e.trv.To = Vector2.new(bx+bw, by),       Vector2.new(bx+bw, by+cy)
        --  bottom-left
        e.blh.From, e.blh.To = Vector2.new(bx, by+bh),       Vector2.new(bx+cx, by+bh)
        e.blv.From, e.blv.To = Vector2.new(bx, by+bh-cy),    Vector2.new(bx, by+bh)
        --  bottom-right
        e.brh.From, e.brh.To = Vector2.new(bx+bw-cx, by+bh), Vector2.new(bx+bw, by+bh)
        e.brv.From, e.brv.To = Vector2.new(bx+bw, by+bh-cy), Vector2.new(bx+bw, by+bh)

        for _, k in ipairs({"tlh","tlv","trh","trv","blh","blv","brh","brv"}) do
            e[k].Color     = col
            e[k].Thickness = thick
            e[k].Visible   = true
        end
    end

    -- ── NAME ───────────────────────────────────────────────
    if S.ShowNames then
        local lbl = isPlayer and Players:GetPlayerFromCharacter(char).Name or char.Name
        e.name.Text, e.name.Size  = lbl, S.NameSize
        e.name.Color              = S.NameColor
        e.name.Position           = Vector2.new(midX, by - S.NameSize - 2)
        e.name.Visible            = true
    else
        e.name.Visible = false
    end

    -- ── DISTANCE ───────────────────────────────────────────
    if S.ShowDistance then
        local d3 = (Camera.CFrame.Position - head.Position).Magnitude
        e.dist.Text     = string.format("[%.0f]", d3)
        e.dist.Size     = S.DistSize
        e.dist.Color    = S.DistColor
        e.dist.Position = Vector2.new(midX, by + bh + 2)
        e.dist.Visible  = true
    else
        e.dist.Visible = false
    end

    -- ── HEALTH BAR  (vertical, left side) ─────────────────
    if S.ShowHealthBar then
        local pct  = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
        local barX = bx - 5
        e.hpBG.From,  e.hpBG.To  = Vector2.new(barX, by),                 Vector2.new(barX, by + bh)
        e.hpFG.From,  e.hpFG.To  = Vector2.new(barX, by + bh*(1-pct)),    Vector2.new(barX, by + bh)
        e.hpBG.Color  = Color3.fromRGB(20, 20, 20)
        e.hpFG.Color  = HpColor(pct)
        e.hpBG.Visible, e.hpFG.Visible = true, true
    else
        e.hpBG.Visible, e.hpFG.Visible = false, false
    end

    -- ── TRACER ─────────────────────────────────────────────
    if S.ShowTracers then
        local vp    = Camera.ViewportSize
        local fromY = S.TracerOrigin == "Center" and vp.Y * 0.5 or vp.Y
        e.tracer.From    = Vector2.new(vp.X * 0.5, fromY)
        e.tracer.To      = Vector2.new(midX, by + bh)
        e.tracer.Color   = S.TracerColor
        e.tracer.Visible = true
    else
        e.tracer.Visible = false
    end
end

--// ═══════════════════════════════════════════
--//  WALL CHECK  (reuses global RaycastParams)
--// ═══════════════════════════════════════════
local function HasLineOfSight(part)
    if not part or not part.Parent then return false end
    WallParams.FilterDescendantsInstances = { LPChar, part.Parent }
    local origin = Camera.CFrame.Position
    local result = workspace:Raycast(origin, part.Position - origin, WallParams)
    return result == nil
end

local function CheckWall(part)
    if not S.WallCheck then return true end
    return HasLineOfSight(part)
end

--// ═══════════════════════════════════════════
--//  VELOCITY PREDICTION
--// ═══════════════════════════════════════════
local function Predict(part)
    if not S.Prediction then return part.Position end
    local ok, v = pcall(function() return part.AssemblyLinearVelocity end)
    return (ok and v) and (part.Position + v * S.PredStrength) or part.Position
end

--// ═══════════════════════════════════════════
--//  GET BEST AIM TARGET
--// ═══════════════════════════════════════════
local function GetTarget()
    local best, bestScore = nil, math.huge
    local origin = GetAimOrigin()

    for _, char in ipairs(workspace:GetChildren()) do
        if char == LPChar then continue end
        if not IsCharacterAlive(char) then continue end

        local hum  = char:FindFirstChildOfClass("Humanoid")
        local part = char:FindFirstChild(S.TargetPart) or char:FindFirstChild("Head")
        if not part then continue end

        -- 3D cull first (cheap)
        if (Camera.CFrame.Position - part.Position).Magnitude > S.MaxDist then continue end

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
        if S.VisibleOnly and not HasLineOfSight(part) then continue end

        local score =
            S.Priority == "Lowest Health"    and hum.Health or
            S.Priority == "Closest Distance" and (Camera.CFrame.Position - part.Position).Magnitude or
            dist2D  -- default: Closest to Crosshair

        if score < bestScore then
            bestScore = score
            best      = part
        end
    end
    return best
end

local function IsPartTargetable(part)
    if not part or not part.Parent then return false end

    local char = part.Parent
    if char == LPChar then return false end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not IsHumAlive(hum) then return false end

    if (Camera.CFrame.Position - part.Position).Magnitude > S.MaxDist then return false end

    local player = Players:GetPlayerFromCharacter(char)
    if player then
        if S.TeamCheck and player.Team and player.Team == LP.Team then return false end
    else
        if not S.NPCEnabled then return false end
    end

    local sp, vis = Camera:WorldToViewportPoint(part.Position)
    if not vis or sp.Z <= 0 then return false end

    local dist2D = (Vector2.new(sp.X, sp.Y) - GetAimOrigin()).Magnitude
    if dist2D > S.FOV then return false end
    if S.VisibleOnly and not HasLineOfSight(part) then return false end

    return true
end

--// ═══════════════════════════════════════════
--//  OBSIDIAN UI
--// ═══════════════════════════════════════════
local repo         = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library      = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager  = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Window = Library:CreateWindow({
    Title = "Aimbot + Box ESP",
    Footer = "v4.0",
    Icon = 4483362458,
    NotifySide = "Right",
    ShowCustomCursor = true,
})

local Tabs = {
    Aimbot = Window:AddTab("Aimbot", "crosshair"),
    Boxes = Window:AddTab("2D Boxes", "square"),
    Filters = Window:AddTab("Filters", "funnel"),
    Misc = Window:AddTab("Misc", "wrench"),
    ["UI Settings"] = Window:AddTab("UI Settings", "settings"),
}

--// ─── AIMBOT TAB ─────────────────────────────
local AimCore   = Tabs.Aimbot:AddLeftGroupbox("Core", "crosshair")
local AimParams = Tabs.Aimbot:AddRightGroupbox("Parameters", "sliders-horizontal")
local AimTarget = Tabs.Aimbot:AddLeftGroupbox("Target", "target")
local AimVisual = Tabs.Aimbot:AddRightGroupbox("Visuals", "eye")

AimCore:AddToggle("AimEn", { Text="Enable Aimbot", Default=false, Callback=function(v) S.AimEnabled=v end })
AimCore:AddToggle("AutoFire", { Text="Auto Attack", Default=false, Callback=function(v) S.AutoFire=v end })
AimCore:AddToggle("VelPred", { Text="Velocity Prediction", Default=true, Callback=function(v) S.Prediction=v end })
AimCore:AddToggle("ReqADS", { Text="Require Right-Click (PC)", Default=true, Callback=function(v) S.RequireADS=v end })
AimCore:AddToggle("VisOnly", { Text="Visible Targets Only", Default=false, Callback=function(v) S.VisibleOnly=v end })
AimCore:AddToggle("StickyAim", { Text="Sticky Aim", Default=true, Callback=function(v) S.StickyAim=v end })
AimCore:AddToggle("AliveChk", { Text="Strict Alive Check", Default=true, Callback=function(v) S.AliveCheck=v end })
AimCore:AddToggle("AdaptSm", { Text="Adaptive Smooth", Default=true, Callback=function(v) S.AdaptiveSmooth=v end })

AimParams:AddSlider("FOVRad", { Text="FOV Radius", Default=150, Min=30, Max=450, Rounding=0,
    Callback=function(v) S.FOV=v; FOVCircle.Radius=v end })
AimParams:AddSlider("Smooth", { Text="Smoothness (lower = snappier)", Default=18, Min=1, Max=100, Rounding=0,
    Callback=function(v) S.Smoothness=v/100 end })
AimParams:AddSlider("Spread", { Text="Spread", Default=2, Min=0, Max=20, Rounding=0,
    Callback=function(v) S.Spread=v end })
AimParams:AddSlider("PredStr", { Text="Prediction Strength", Default=8, Min=0, Max=30, Rounding=0,
    Callback=function(v) S.PredStrength=v/100 end })
AimParams:AddSlider("StickyTime", { Text="Sticky Time (ms)", Default=350, Min=0, Max=1000, Rounding=0,
    Callback=function(v) S.StickyTime=v/1000 end })
AimParams:AddSlider("AutoAtkDelay", { Text="Auto Attack Delay (ms)", Default=80, Min=20, Max=250, Rounding=0,
    Callback=function(v) S.AutoFireDelay=v/1000 end })
AimParams:AddSlider("SwDelay", { Text="Switch Delay (ms)", Default=120, Min=0, Max=500, Rounding=0,
    Callback=function(v) S.TargetSwitchDelay=v/1000 end })
AimParams:AddSlider("Deadzone", { Text="Aim Deadzone (px)", Default=4, Min=0, Max=35, Rounding=0,
    Callback=function(v) S.Deadzone=v end })
AimParams:AddSlider("MinSmooth", { Text="Adaptive Min Smooth", Default=10, Min=1, Max=100, Rounding=0,
    Callback=function(v) S.AdaptiveMinSmooth=v/100 end })

AimTarget:AddDropdown("Prio", { Text="Priority", Values={"Closest to Crosshair","Lowest Health","Closest Distance"}, Default=1,
    Callback=function(v) S.Priority=v end })
AimTarget:AddDropdown("TgtPart", { Text="Target Part", Values={"Head","HumanoidRootPart","UpperTorso","Torso"}, Default=1,
    Callback=function(v) S.TargetPart=v end })

AimVisual:AddToggle("ShowFOV", { Text="Show FOV Circle", Default=true, Callback=function(v) S.ShowFOV=v; FOVCircle.Visible=v end })
AimVisual:AddToggle("ShowDot", { Text="Show Target Dot", Default=true, Callback=function(v) S.ShowDot=v end })
AimVisual:AddToggle("DynFovCol", { Text="Dynamic FOV Color", Default=true, Callback=function(v) S.DynamicFOVColor=v end })

--// ─── 2D BOXES TAB ────────────────────────────
local BoxCore   = Tabs.Boxes:AddLeftGroupbox("Box", "square")
local BoxStyle  = Tabs.Boxes:AddRightGroupbox("Fill + Style", "paintbrush")
local BoxLabels = Tabs.Boxes:AddLeftGroupbox("Labels", "type")
local BoxTracer = Tabs.Boxes:AddRightGroupbox("Tracer", "move-down")

BoxCore:AddToggle("BoxEn", { Text="Enable Boxes", Default=true,
    Callback=function(v)
        S.BoxEnabled = v
        if not v then
            for _, e in pairs(Pool) do HideEntry(e) end
        end
    end
})
BoxCore:AddSlider("MaxDist", { Text="Max Render Distance", Default=500, Min=50, Max=2000, Rounding=0,
    Callback=function(v) S.MaxDist=v end })
BoxCore:AddSlider("BoxThick", { Text="Thickness", Default=2, Min=1, Max=4, Rounding=0,
    Callback=function(v) S.BoxThickness=v end })
BoxCore:AddSlider("CornerLen", { Text="Corner Arm Length (%)", Default=25, Min=5, Max=50, Rounding=0,
    Callback=function(v) S.CornerLen=v/100 end })

BoxStyle:AddDropdown("BoxStyle", { Text="Box Style", Values={"Corner","Full"}, Default=1,
    Callback=function(v) S.BoxStyle=v end })
BoxStyle:AddToggle("BoxFill", { Text="Filled Box", Default=false, Callback=function(v) S.BoxFilled=v end })
BoxStyle:AddSlider("FillTrans", { Text="Fill Transparency (%)", Default=85, Min=0, Max=100, Rounding=0,
    Callback=function(v) S.BoxFillTrans=v/100 end })
BoxStyle:AddToggle("TypeCol", { Text="Type Color (Enemy/NPC)", Default=true,
    Callback=function(v)
        S.BoxColorEnemy = v and Color3.fromRGB(255,55,55) or Color3.fromRGB(255,255,255)
        S.BoxColorNPC   = v and Color3.fromRGB(255,165,0) or Color3.fromRGB(255,255,255)
    end
})

BoxLabels:AddToggle("ShowNames", { Text="Show Names", Default=true, Callback=function(v) S.ShowNames=v end })
BoxLabels:AddToggle("ShowDist", { Text="Show Distance", Default=true, Callback=function(v) S.ShowDistance=v end })
BoxLabels:AddToggle("ShowHP", { Text="Show Health Bar", Default=true, Callback=function(v) S.ShowHealthBar=v end })
BoxLabels:AddSlider("NameSz", { Text="Name Size", Default=13, Min=8, Max=24, Rounding=0,
    Callback=function(v) S.NameSize=v end })
BoxLabels:AddSlider("DistSz", { Text="Distance Size", Default=11, Min=8, Max=20, Rounding=0,
    Callback=function(v) S.DistSize=v end })

BoxTracer:AddToggle("ShowTrac", { Text="Show Tracers", Default=false, Callback=function(v) S.ShowTracers=v end })
BoxTracer:AddDropdown("TracOrig", { Text="Tracer Origin", Values={"Bottom","Center"}, Default=1,
    Callback=function(v) S.TracerOrigin=v end })

--// ─── FILTERS TAB ─────────────────────────────
local FilterCore = Tabs.Filters:AddLeftGroupbox("Filters", "funnel")
FilterCore:AddToggle("NPCEn", { Text="Target NPCs", Default=false, Callback=function(v) S.NPCEnabled=v end })
FilterCore:AddToggle("TeamChk", { Text="Team Check", Default=true, Callback=function(v) S.TeamCheck=v end })
FilterCore:AddToggle("WallChk", { Text="Wall Check (Aim)", Default=true, Callback=function(v) S.WallCheck=v end })

--// ─── MISC TAB ─────────────────────────────────
local MiscUtils = Tabs.Misc:AddLeftGroupbox("Utilities", "wrench")
local MemeBox   = Tabs.Misc:AddLeftGroupbox("Memes", "laugh")
local MiscInfo  = Tabs.Misc:AddRightGroupbox("Info", "info")

MiscUtils:AddButton({ Text="Clear All Boxes", Func=function()
    for char, _ in pairs(Pool) do DestroyEntry(char) end
    Library:Notify({ Title="Done", Description="All boxes cleared.", Time=2 })
end })

MiscUtils:AddButton({ Text="Reset to Defaults", Func=function()
    S.AimEnabled=false; S.FOV=150; S.Smoothness=0.18; S.Spread=2
    FOVCircle.Radius=150
    LockedTarget=nil; LockedUntil=0; LastTarget=nil
    Library:Notify({ Title="Reset", Description="Defaults restored.", Time=3 })
end })


local MemeLines = {
    "Skill issue detected 👀",
    "Aim.exe atualizado com sucesso 😎",
    "Errou? Lag do servidor 😅",
    "Quando acerta: 300 IQ play 🧠",
    "Quando morre: era só aquecimento 🔥"
}

MemeBox:AddButton({ Text="Meme aleatório", Func=function()
    local msg = MemeLines[math.random(1, #MemeLines)]
    Library:Notify({ Title="Meme Mode", Description=msg, Time=3 })
end })

MemeBox:AddButton({ Text="Ativar energia gamer", Func=function()
    Library:Notify({ Title="Buff ativado", Description="FPS +500 | Mira +999 | Ping -120", Time=3 })
end })

MemeBox:AddLabel("Modo meme habilitado: sem tilt, só hit 😎", true)

MiscInfo:AddLabel("Platform  : " .. (IsMobile and "Mobile (Screen-center aim)" or "PC (Mouse aim)"), true)
MiscInfo:AddLabel("Aimbot    : Camera+1 priority — overwrites game camera last", true)
MiscInfo:AddLabel("Boxes     : Humanoid.Died → instant Drawing:Remove()", true)
MiscInfo:AddLabel("WallCheck : Global RaycastParams reused every frame", true)

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
ThemeManager:SetFolder("AimBox")
SaveManager:SetFolder("AimBox")
SaveManager:SetSubFolder("default")
SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"])
SaveManager:LoadAutoloadConfig()

--// ═══════════════════════════════════════════
--//  MAIN LOOP
--//
--//  BindToRenderStep at Camera.Value + 1 so our
--//  Camera.CFrame write wins over the game's own
--//  camera LocalScript (which runs at Camera priority).
--// ═══════════════════════════════════════════
local FRAME    = 0
local BOX_RATE = 2   -- update boxes every N render frames (~30 fps at 60 fps)

RunService:BindToRenderStep("AimBox_Main", Enum.RenderPriority.Camera.Value + 1, function()
    FRAME = FRAME + 1

    local origin = GetAimOrigin()
    FOVCircle.Position = origin
    if S.DynamicFOVColor then
        FOVCircle.Color = Color3.fromRGB(255, 255, 255)
    end

    --// ── AIMBOT ──────────────────────────────
    local canAim = S.AimEnabled
    if canAim and S.RequireADS and not IsMobile then
        canAim = UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    end

    local now = tick()
    local target
    if S.StickyAim and LockedTarget and now <= LockedUntil and IsPartTargetable(LockedTarget) then
        target = LockedTarget
    else
        target = GetTarget()
        if S.StickyAim and target then
            LockedTarget = target
            LockedUntil = now + S.StickyTime
        else
            LockedTarget = nil
            LockedUntil = 0
        end
    end

    if LastTarget and target and target ~= LastTarget and (now - LastSwitchClock) < S.TargetSwitchDelay and IsPartTargetable(LastTarget) then
        target = LastTarget
    end

    if target ~= LastTarget then
        LastTarget = target
        LastSwitchClock = now
    end

    if target and not IsPartTargetable(target) then
        target = nil
        LockedTarget = nil
        LockedUntil = 0
        LastTarget = nil
    end

    if target then
        if S.DynamicFOVColor then
            FOVCircle.Color = canAim and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(255, 190, 80)
        end

        if S.ShowDot then
            local sp = Camera:WorldToViewportPoint(target.Position)
            TargetDot.Position = Vector2.new(sp.X, sp.Y)
            TargetDot.Visible  = true
        else
            TargetDot.Visible = false
        end

        if canAim and CheckWall(target) then
            local targetSP = Camera:WorldToViewportPoint(target.Position)
            local targetDelta = (Vector2.new(targetSP.X, targetSP.Y) - origin).Magnitude
            if targetDelta > S.Deadzone then
                local smooth = S.Smoothness
                if S.AdaptiveSmooth then
                    local t = math.clamp(targetDelta / math.max(S.FOV, 1), 0, 1)
                    local minS = math.min(S.AdaptiveMinSmooth, S.Smoothness)
                    local maxS = math.max(S.AdaptiveMinSmooth, S.Smoothness)
                    smooth = minS + (maxS - minS) * t
                end

                local sp = S.Spread / 10
                local ap = Predict(target) + Vector3.new(
                    (math.random()*2-1)*sp,
                    (math.random()*2-1)*sp,
                    (math.random()*2-1)*sp
                )
                -- Camera+1 priority: this is the last CFrame write this frame
                Camera.CFrame = Camera.CFrame:Lerp(
                    CFrame.new(Camera.CFrame.Position, ap),
                    smooth
                )

                if S.AutoFire and not IsMobile and (now - LastFireClock) >= S.AutoFireDelay then
                    LastFireClock = now
                    task.spawn(function()   -- non-blocking: won't stall render step
                        pcall(mouse1press)
                        task.wait(0.05)
                        pcall(mouse1release)
                    end)
                end
            end
        end
    else
        TargetDot.Visible = false
        LockedTarget = nil
        LockedUntil = 0
        LastTarget = nil
    end

    --// ── BOX ESP  (throttled) ────────────────
    if FRAME % BOX_RATE ~= 0 then return end
    if not S.BoxEnabled then return end

    local seen = {}

    for _, char in ipairs(workspace:GetChildren()) do
        if char == LPChar then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")

        -- Dead char still sitting in workspace → nuke immediately
        if hum and hum.Health <= 0 and Pool[char] then
            DestroyEntry(char)
            continue
        end
        if not hum or hum.Health <= 0 then continue end

        local player   = Players:GetPlayerFromCharacter(char)
        local isPlayer = player ~= nil
        if not isPlayer and not S.NPCEnabled then continue end
        if isPlayer and S.TeamCheck and player.Team and player.Team == LP.Team then continue end

        seen[char] = true
        UpdateBox(char, isPlayer)
    end

    -- Hide boxes for chars we didn't see this tick (left range, died between ticks, etc.)
    for char, entry in pairs(Pool) do
        if not seen[char] then
            HideEntry(entry)
        end
    end
end)

--// ═══════════════════════════════════════════
--//  GLOBAL CLEANUP HOOKS
--// ═══════════════════════════════════════════

-- Player leaves the game
Players.PlayerRemoving:Connect(function(p)
    if p.Character then DestroyEntry(p.Character) end
end)

-- Character model removed from workspace (respawn cycle, kicked, etc.)
workspace.ChildRemoved:Connect(function(child)
    if Pool[child] then DestroyEntry(child) end
end)

--// ═══════════════════════════════════════════
--//  LOAD + NOTIFY
--// ═══════════════════════════════════════════
Library:Notify({
    Title = "Aimbot + Box ESP v4.0",
    Description = "Obsidian UI loaded. UI antiga removida ✅ | Platform: " .. (IsMobile and "Mobile" or "PC"),
    Time = 5
})
