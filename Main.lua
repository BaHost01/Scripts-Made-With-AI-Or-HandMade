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
    TargetPart   = "Head",
    Priority     = "Closest to Crosshair",
    WallCheck    = true,

    -- FILTERS
    NPCEnabled   = false,
    TeamCheck    = true,

    -- FOV DRAWING
    ShowFOV      = true,
    ShowDot      = true,

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
local CharacterRegistry = {} -- [char] = true
local DestroyEntry

local function RegisterCharacter(char)
    if char and char:IsA("Model") then
        CharacterRegistry[char] = true
    end
end

local function UnregisterCharacter(char)
    if not char then return end
    CharacterRegistry[char] = nil
    if Pool[char] then DestroyEntry(char) end
end

local function IsCharacterCandidate(char)
    if char == LPChar then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    return true
end

local function AddPlayerCharacterHooks(player)
    player.CharacterAdded:Connect(RegisterCharacter)
    player.CharacterRemoving:Connect(UnregisterCharacter)
    if player.Character then RegisterCharacter(player.Character) end
end

for _, p in ipairs(Players:GetPlayers()) do
    AddPlayerCharacterHooks(p)
end

Players.PlayerAdded:Connect(AddPlayerCharacterHooks)
Players.PlayerRemoving:Connect(function(p)
    if p.Character then UnregisterCharacter(p.Character) end
end)

-- Optional NPC folder support (common convention)
local NPCFolder = workspace:FindFirstChild("NPCs")
if NPCFolder then
    for _, npc in ipairs(NPCFolder:GetChildren()) do
        RegisterCharacter(npc)
    end
    NPCFolder.ChildAdded:Connect(RegisterCharacter)
    NPCFolder.ChildRemoved:Connect(UnregisterCharacter)
end

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

function DestroyEntry(char)
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
local function CheckWall(part)
    if not S.WallCheck then return true end
    WallParams.FilterDescendantsInstances = { LPChar, part.Parent }
    local origin = Camera.CFrame.Position
    local result = workspace:Raycast(origin, part.Position - origin, WallParams)
    return result == nil
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

    for char in pairs(CharacterRegistry) do
        if not IsCharacterCandidate(char) then continue end
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

--// ═══════════════════════════════════════════
--//  RAYFIELD UI
--// ═══════════════════════════════════════════
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Window   = Rayfield:CreateWindow({
    Name            = "Aimbot + Box ESP",
    LoadingTitle    = "Loading v4.0...",
    LoadingSubtitle = "Optimized Edition",
    ConfigurationSaving = { Enabled = true, FileName = "AimBox_v4" },
    KeySystem       = false
})

local AimTab    = Window:CreateTab("Aimbot",   4483362458)
local BoxTab    = Window:CreateTab("2D Boxes", 4483362458)
local FilterTab = Window:CreateTab("Filters",  4483362458)
local MiscTab   = Window:CreateTab("Misc",     4483362458)

--// ─── AIMBOT TAB ─────────────────────────────
AimTab:CreateSection("Core")
AimTab:CreateToggle({ Name="Enable Aimbot",       CurrentValue=false, Flag="AimEn",   Callback=function(v) S.AimEnabled  =v end })
AimTab:CreateToggle({ Name="Auto Attack",         CurrentValue=false, Flag="AutoFire",Callback=function(v) S.AutoFire    =v end })
AimTab:CreateToggle({ Name="Velocity Prediction", CurrentValue=true,  Flag="VelPred", Callback=function(v) S.Prediction  =v end })

AimTab:CreateSection("Parameters")
AimTab:CreateSlider({ Name="FOV Radius",                    Range={30,450},Increment=5, CurrentValue=150,Flag="FOVRad",
    Callback=function(v) S.FOV=v; FOVCircle.Radius=v end })
AimTab:CreateSlider({ Name="Smoothness  (lower = snappier)",Range={1,100}, Increment=1, CurrentValue=18, Flag="Smooth",
    Callback=function(v) S.Smoothness=v/100 end })
AimTab:CreateSlider({ Name="Spread",                        Range={0,20},  Increment=1, CurrentValue=2,  Flag="Spread",
    Callback=function(v) S.Spread=v end })
AimTab:CreateSlider({ Name="Prediction Strength",           Range={0,30},  Increment=1, CurrentValue=8,  Flag="PredStr",
    Callback=function(v) S.PredStrength=v/100 end })

AimTab:CreateSection("Target")
AimTab:CreateDropdown({ Name="Priority",
    Options={"Closest to Crosshair","Lowest Health","Closest Distance"},
    CurrentOption={"Closest to Crosshair"},Flag="Prio",
    Callback=function(o) S.Priority=o[1] end })
AimTab:CreateDropdown({ Name="Target Part",
    Options={"Head","HumanoidRootPart","UpperTorso","Torso"},
    CurrentOption={"Head"},Flag="TgtPart",
    Callback=function(o) S.TargetPart=o[1] end })

AimTab:CreateSection("Visuals")
AimTab:CreateToggle({ Name="Show FOV Circle",CurrentValue=true, Flag="ShowFOV",Callback=function(v) S.ShowFOV=v; FOVCircle.Visible=v end })
AimTab:CreateToggle({ Name="Show Target Dot",CurrentValue=true, Flag="ShowDot",Callback=function(v) S.ShowDot=v end })

--// ─── 2D BOXES TAB ────────────────────────────
BoxTab:CreateSection("Box")
BoxTab:CreateToggle({ Name="Enable Boxes", CurrentValue=true, Flag="BoxEn",
    Callback=function(v)
        S.BoxEnabled = v
        if not v then
            for _, e in pairs(Pool) do HideEntry(e) end
        end
    end
})
BoxTab:CreateDropdown({ Name="Box Style",
    Options={"Corner","Full"},
    CurrentOption={"Corner"}, Flag="BoxStyle",
    Callback=function(o) S.BoxStyle=o[1] end })
BoxTab:CreateSlider({ Name="Thickness",         Range={1,4},   Increment=1,  CurrentValue=2,  Flag="BoxThick",   Callback=function(v) S.BoxThickness=v end })
BoxTab:CreateSlider({ Name="Corner Arm Length", Range={5,50},  Increment=1,  CurrentValue=25, Flag="CornerLen",  Callback=function(v) S.CornerLen=v/100 end })
BoxTab:CreateSlider({ Name="Max Render Distance",Range={50,2000},Increment=50,CurrentValue=500,Flag="MaxDist",   Callback=function(v) S.MaxDist=v end })

BoxTab:CreateSection("Fill")
BoxTab:CreateToggle({ Name="Filled Box",        CurrentValue=false,Flag="BoxFill",   Callback=function(v) S.BoxFilled=v end })
BoxTab:CreateSlider({ Name="Fill Transparency", Range={0,100},Increment=5,CurrentValue=85,Flag="FillTrans",
    Callback=function(v) S.BoxFillTrans=v/100 end })

BoxTab:CreateSection("Colors")
BoxTab:CreateToggle({ Name="Type Color  (Enemy=Red / NPC=Orange)", CurrentValue=true, Flag="TypeCol",
    Callback=function(v)
        S.BoxColorEnemy = v and Color3.fromRGB(255,55,55)   or Color3.fromRGB(255,255,255)
        S.BoxColorNPC   = v and Color3.fromRGB(255,165,0)   or Color3.fromRGB(255,255,255)
    end
})

BoxTab:CreateSection("Labels")
BoxTab:CreateToggle({ Name="Show Names",    CurrentValue=true,  Flag="ShowNames", Callback=function(v) S.ShowNames=v end })
BoxTab:CreateToggle({ Name="Show Distance", CurrentValue=true,  Flag="ShowDist",  Callback=function(v) S.ShowDistance=v end })
BoxTab:CreateToggle({ Name="Show Health Bar",CurrentValue=true, Flag="ShowHP",    Callback=function(v) S.ShowHealthBar=v end })
BoxTab:CreateToggle({ Name="Show Tracers",  CurrentValue=false, Flag="ShowTrac",  Callback=function(v) S.ShowTracers=v end })

BoxTab:CreateSection("Tracer")
BoxTab:CreateDropdown({ Name="Tracer Origin", Options={"Bottom","Center"}, CurrentOption={"Bottom"}, Flag="TracOrig",
    Callback=function(o) S.TracerOrigin=o[1] end })

BoxTab:CreateSection("Text Sizes")
BoxTab:CreateSlider({ Name="Name Size",     Range={8,24},Increment=1,CurrentValue=13,Flag="NameSz",Callback=function(v) S.NameSize=v end })
BoxTab:CreateSlider({ Name="Distance Size", Range={8,20},Increment=1,CurrentValue=11,Flag="DistSz",Callback=function(v) S.DistSize=v end })

--// ─── FILTERS TAB ─────────────────────────────
FilterTab:CreateSection("Filters")
FilterTab:CreateToggle({ Name="Target NPCs",     CurrentValue=false,Flag="NPCEn",    Callback=function(v) S.NPCEnabled=v end })
FilterTab:CreateToggle({ Name="Team Check",      CurrentValue=true, Flag="TeamChk",  Callback=function(v) S.TeamCheck=v end })
FilterTab:CreateToggle({ Name="Wall Check (Aim)",CurrentValue=true, Flag="WallChk",  Callback=function(v) S.WallCheck=v end })

--// ─── MISC TAB ─────────────────────────────────
MiscTab:CreateSection("Utilities")
MiscTab:CreateButton({ Name="Clear All Boxes",
    Callback=function()
        for char, _ in pairs(Pool) do DestroyEntry(char) end
        Rayfield:Notify({ Title="Done", Content="All boxes cleared.", Duration=2 })
    end
})
MiscTab:CreateButton({ Name="Reset to Defaults",
    Callback=function()
        S.AimEnabled=false; S.FOV=150; S.Smoothness=0.18; S.Spread=2
        FOVCircle.Radius=150
        Rayfield:Notify({ Title="Reset", Content="Defaults restored.", Duration=3 })
    end
})
MiscTab:CreateSection("Info")
MiscTab:CreateLabel("Platform  : " .. (IsMobile and "Mobile (Screen-center aim)" or "PC (Mouse aim)"))
MiscTab:CreateLabel("Aimbot    : Camera+1 priority — overwrites game camera last")
MiscTab:CreateLabel("Boxes     : Humanoid.Died → instant Drawing:Remove()")
MiscTab:CreateLabel("WallCheck : Global RaycastParams reused every frame")

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

    --// ── AIMBOT ──────────────────────────────
    local target = GetTarget()

    if target then
        if S.ShowDot then
            local sp = Camera:WorldToViewportPoint(target.Position)
            TargetDot.Position = Vector2.new(sp.X, sp.Y)
            TargetDot.Visible  = true
        else
            TargetDot.Visible = false
        end

        if S.AimEnabled and CheckWall(target) then
            local sp = S.Spread / 10
            local ap = Predict(target) + Vector3.new(
                (math.random()*2-1)*sp,
                (math.random()*2-1)*sp,
                (math.random()*2-1)*sp
            )
            -- Camera+1 priority: this is the last CFrame write this frame
            Camera.CFrame = Camera.CFrame:Lerp(
                CFrame.new(Camera.CFrame.Position, ap),
                S.Smoothness
            )

            if S.AutoFire and not IsMobile then
                task.spawn(function()   -- non-blocking: won't stall render step
                    pcall(mouse1press)
                    task.wait(0.05)
                    pcall(mouse1release)
                end)
            end
        end
    else
        TargetDot.Visible = false
    end

    --// ── BOX ESP  (throttled) ────────────────
    if FRAME % BOX_RATE ~= 0 then return end
    if not S.BoxEnabled then return end

    local seen = {}

    for char in pairs(CharacterRegistry) do
        local hum = char:FindFirstChildOfClass("Humanoid")

        if not char.Parent then
            UnregisterCharacter(char)
            continue
        end
        if char == LPChar then continue end

        -- Dead char still sitting in workspace → nuke immediately
        if hum and hum.Health <= 0 and Pool[char] then
            DestroyEntry(char)
            CharacterRegistry[char] = nil
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
-- Character model removed from workspace (respawn cycle, kicked, etc.)
workspace.ChildRemoved:Connect(function(child)
    if CharacterRegistry[child] then
        UnregisterCharacter(child)
    elseif Pool[child] then
        DestroyEntry(child)
    end
end)

--// ═══════════════════════════════════════════
--//  LOAD + NOTIFY
--// ═══════════════════════════════════════════
Rayfield:LoadConfiguration()

Rayfield:Notify({
    Title    = "Aimbot + Box ESP v4.0",
    Content  = "Corner & Full box modes. Platform: " .. (IsMobile and "Mobile" or "PC"),
    Duration = 5,
    Image    = 4483362458
})
