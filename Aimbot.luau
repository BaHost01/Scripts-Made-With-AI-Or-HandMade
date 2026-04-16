--| Internal-AimBot Framework v2.0
--| Roblox Internal Cheat System - Mobile & Desktop Enhanced
--| Features: Aimbot, ESP, Misc, Mobile Support, Config System

local Game = game
local Players = Game:GetService("Players")
local RunService = Game:GetService("RunService")
local UserInputService = Game:GetService("UserInputService")
local ReplicatedStorage = Game:GetService("ReplicatedStorage")
local TweenService = Game:GetService("TweenService")
local TextService = Game:GetService("TextService")
local Lighting = Game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

--| Global State
local cache = {}
local forsakencache = {}
local Info = {}
local GlobalUI = nil
local Connections = {}
local Hooks = {}
local ConfigProfiles = {}
local CurrentProfile = "default"

--| Enhanced Configuration
local Config = {
    Aimbot = {
        Enabled = false,
        FOV = 60,
        Smoothness = 0.5,
        TargetPart = "Head",
        TargetParts = {"Head", "HumanoidRootPart", "UpperTorso"},
        WallCheck = true,
        VisibleOnly = true,
        Prediction = true,
        PredictionScale = 0.5,
        RecoilControl = false,
        RecoilValue = 0.8,
        FOVCircle = false,
        FOVColor = Color3.fromRGB(0, 255, 127),
        AutoFire = false,
        HitChance = 100,
        TeamCheck = true
    },
    ESP = {
        Enabled = false,
        ShowTeam = false,
        ShowName = true,
        ShowDistance = true,
        ShowHealth = true,
        ShowWeapon = true,
        Box = true,
        BoxStyle = "Corner", -- Full, Corner, Outline
        Tracer = false,
        TracerStyle = "Bottom", -- Bottom, Top, Center
        HealthBar = true,
        Skeleton = false,
        Outline = true,
        Color = Color3.fromRGB(0, 255, 127),
        EnemyColor = Color3.fromRGB(255, 50, 50),
        TeamColor = Color3.fromRGB(50, 100, 255),
        DistanceFade = true,
        MaxDistance = 500,
        Transparency = 0
    },
    Misc = {
        FlyEnabled = false,
        FlySpeed = 50,
        SpeedEnabled = false,
        SpeedValue = 16,
        NoClip = false,
        AutoJump = false,
        InfiniteJump = false,
        TeleportToClosest = false,
        AutoFarm = false,
        AntiKick = true
    },
    UI = {
        ToggleKey = Enum.KeyCode.RightShift,
        DragKey = Enum.KeyCode.LeftAlt,
        Position = UDim2.new(0.75, 0, 0.5, 0),
        Size = 1,
        Theme = "Dark", -- Dark, Light, Blue, Purple
        Animations = true,
        MobileMode = false
    },
    Profiles = {
        AutoSave = true,
        CurrentProfile = "default"
    }
}

--| Mobile Detection
local IsMobile = false
local IsTouchSupported = UserInputService.TouchEnabled
if IsTouchSupported then
    IsMobile = true
    Config.UI.MobileMode = true
    Config.UI.Size = 1.2
end

--| Drawing Cache for FOV Circle and Visuals
local DrawingCache = {
    FOVCircle = nil,
    Lines = {},
    Texts = {}
}

--| Utility Functions
local function DrawSquare(points, color, thickness, transparency, filled, outlined)
    local lines = {}
    for i = 1, #points do
        local p1 = points[i]
        local p2 = points[(i % #points) + 1]
        local line = Drawing.new("Line")
        line.From = p1
        line.To = p2
        line.Color = color
        line.Thickness = thickness or 1
        line.Transparency = transparency or 0
        line.Visible = true
        table.insert(lines, line)
    end
    return lines
end

local function GetScreenPos(position)
    local result, onScreen = Camera:WorldToViewportPoint(position)
    return result, onScreen
end

local function IsVisible(fromPos, toPos)
    local ray = Ray.new(fromPos, (toPos - fromPos).Unit * 500)
    local hit = workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character})
    return hit == nil
end

local function GetClosestPlayer()
    local closest = nil
    local closestDist = Config.Aimbot.FOV
    local mousePos = UserInputService:GetMouseLocation()

    for _, player in pairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if Config.Aimbot.TeamCheck and player.Team == LocalPlayer.Team then continue end

        local char = player.Character
        if not char then continue end

        local targetPart = char:FindFirstChild(Config.Aimbot.TargetPart)
        if not targetPart then continue end

        local screenPos, onScreen = GetScreenPos(targetPart.Position)
        if not onScreen then continue end

        if Config.Aimbot.VisibleOnly then
            local origin = LocalPlayer.Character
            if origin and IsVisible(origin.PrimaryPart.Position, targetPart.Position) == false then
                continue
            end
        end

        local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
        if dist < closestDist then
            closestDist = dist
            closest = {Player = player, Part = targetPart, ScreenPos = screenPos, Distance = dist}
        end
    end

    return closest
end

local function GetClosestPlayerToCursor()
    local closest = nil
    local closestDist = math.huge
    local cursorPos = UserInputService:GetMouseLocation()

    for _, player in pairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if Config.Aimbot.TeamCheck and player.Team == LocalPlayer.Team then continue end

        local char = player.Character
        if not char then continue end

        local targetPart = char:FindFirstChild(Config.Aimbot.TargetPart)
        if not targetPart then continue end

        local screenPos, onScreen = GetScreenPos(targetPart.Position)
        if not onScreen then continue end

        local dist = (Vector2.new(screenPos.X, screenPos.Y) - cursorPos).Magnitude
        if dist < closestDist then
            closestDist = dist
            closest = {Player = player, Part = targetPart, ScreenPos = screenPos}
        end
    end

    return closest, closestDist
end

local function PredictPosition(position, velocity, predictionTime)
    return position + velocity * predictionTime
end

local function GetPlayerWeapon(player)
    local char = player.Character
    if not char then return nil end
    for _, v in pairs(char:GetChildren()) do
        if v:IsA("Tool") or v:IsA("RemoteTool") then
            return v.Name
        end
    end
    return "Melee"
end

local function GetTeamColor(player)
    if player.Team == LocalPlayer.Team then
        return Config.ESP.TeamColor
    end
    return Config.ESP.EnemyColor
end

local function LerpColor(color1, color2, alpha)
    return Color3.new(
        color1.R + (color2.R - color1.R) * alpha,
        color1.G + (color2.G - color1.G) * alpha,
        color1.B + (color2.B - color1.B) * alpha
    )
end

local function GetDistanceColor(baseColor, distance, maxDistance)
    if not Config.ESP.DistanceFade then
        return baseColor
    end
    local fade = math.clamp(distance / maxDistance, 0, 1)
    return LerpColor(baseColor, Color3.fromRGB(0, 0, 0), fade * 0.7)
end

--| Enhanced Drawing Functions
local function CreateFOVCircle()
    if DrawingCache.FOVCircle then
        DrawingCache.FOVCircle:Remove()
    end

    local circle = Drawing.new("Circle")
    circle.Radius = Config.Aimbot.FOV
    circle.Color = Config.Aimbot.FOVColor
    circle.Thickness = 2
    circle.NumSides = 64
    circle.Filled = false
    circle.Visible = Config.Aimbot.FOVCircle
    circle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    DrawingCache.FOVCircle = circle
    return circle
end

local function UpdateFOVCircle()
    if not DrawingCache.FOVCircle then
        CreateFOVCircle()
        return
    end

    DrawingCache.FOVCircle.Radius = Config.Aimbot.FOV
    DrawingCache.FOVCircle.Color = Config.Aimbot.FOVColor
    DrawingCache.FOVCircle.Visible = Config.Aimbot.FOVCircle
    DrawingCache.FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
end

--| External Module
local External = {}

function External.HookESP()
    local espConnections = {}

    local function CreateESP(player)
        local espData = {
            Box = {},
            Skeleton = {},
            Tracer = nil,
            Name = nil,
            Distance = nil,
            Health = nil,
            HealthBar = nil,
            HealthBarBg = nil,
            Weapon = nil,
            Player = player
        }

        -- Box lines
        for i = 1, 4 do
            local line = Drawing.new("Line")
            line.Color = Config.ESP.Color
            line.Thickness = 1
            line.Transparency = Config.ESP.Transparency
            line.Visible = false
            espData.Box[i] = line
        end

        -- Skeleton lines
        for i = 1, 6 do
            local line = Drawing.new("Line")
            line.Color = Config.ESP.Color
            line.Thickness = 1
            line.Transparency = Config.ESP.Transparency
            line.Visible = false
            espData.Skeleton[i] = line
        end

        -- Tracer line
        local tracer = Drawing.new("Line")
        tracer.Color = Config.ESP.Color
        tracer.Thickness = 1
        tracer.Transparency = Config.ESP.Transparency
        tracer.Visible = false
        espData.Tracer = tracer

        -- Name text
        local name = Drawing.new("Text")
        name.Color = Config.ESP.Color
        name.Size = 14 * Config.UI.Size
        name.Visible = false
        name.Outline = true
        espData.Name = name

        -- Distance text
        local dist = Drawing.new("Text")
        dist.Color = Config.ESP.Color
        dist.Size = 12 * Config.UI.Size
        dist.Visible = false
        dist.Outline = true
        espData.Distance = dist

        -- Health text
        local health = Drawing.new("Text")
        health.Color = Config.ESP.Color
        health.Size = 12 * Config.UI.Size
        health.Visible = false
        health.Outline = true
        espData.Health = health

        -- Weapon text
        local weapon = Drawing.new("Text")
        weapon.Color = Config.ESP.Color
        weapon.Size = 12 * Config.UI.Size
        weapon.Visible = false
        weapon.Outline = true
        espData.Weapon = weapon

        -- Health bar background
        local healthBarBg = Drawing.new("Line")
        healthBarBg.Color = Color3.fromRGB(50, 50, 50)
        healthBarBg.Thickness = 4
        healthBarBg.Visible = false
        espData.HealthBarBg = healthBarBg

        -- Health bar
        local healthBar = Drawing.new("Line")
        healthBar.Color = Color3.fromRGB(0, 255, 0)
        healthBar.Thickness = 3
        healthBar.Visible = false
        espData.HealthBar = healthBar

        cache[player.UserId] = espData
    end

    local function RemoveESP(player)
        local espData = cache[player.UserId]
        if espData then
            for _, line in pairs(espData.Box) do
                pcall(function() line:Remove() end)
            end
            for _, line in pairs(espData.Skeleton) do
                pcall(function() line:Remove() end)
            end
            if espData.Tracer then pcall(function() espData.Tracer:Remove() end)
            if espData.Name then pcall(function() espData.Name:Remove() end)
            if espData.Distance then pcall(function() espData.Distance:Remove() end)
            if espData.Health then pcall(function() espData.Health:Remove() end)
            if espData.Weapon then pcall(function() espData.Weapon:Remove() end)
            if espData.HealthBar then pcall(function() espData.HealthBar:Remove() end)
            if espData.HealthBarBg then pcall(function() espData.HealthBarBg:Remove() end)
            cache[player.UserId] = nil
        end
    end

    local function UpdateESP()
        if not Config.ESP.Enabled then
            for userId, espData in pairs(cache) do
                for _, line in pairs(espData.Box) do
                    line.Visible = false
                end
                for _, line in pairs(espData.Skeleton) do
                    line.Visible = false
                end
                if espData.Tracer then espData.Tracer.Visible = false end
                if espData.Name then espData.Name.Visible = false end
                if espData.Distance then espData.Distance.Visible = false end
                if espData.Health then espData.Health.Visible = false end
                if espData.Weapon then espData.Weapon.Visible = false end
                if espData.HealthBar then espData.HealthBar.Visible = false end
                if espData.HealthBarBg then espData.HealthBarBg.Visible = false end
            end
            return
        end

        for _, player in pairs(Players:GetPlayers()) do
            if player == LocalPlayer then continue end
            if not Config.ESP.ShowTeam and player.Team == LocalPlayer.Team then continue end

            local char = player.Character
            if not char then
                if cache[player.UserId] then
                    RemoveESP(player)
                end
                continue
            end

            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then continue end

            if not cache[player.UserId] then
                CreateESP(player)
            end

            local espData = cache[player.UserId]
            local screenPos, onScreen = GetScreenPos(hrp.Position)
            local distance = (hrp.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude

            if distance > Config.ESP.MaxDistance then
                for _, line in pairs(espData.Box) do line.Visible = false end
                if espData.Tracer then espData.Tracer.Visible = false end
                if espData.Name then espData.Name.Visible = false end
                continue
            end

            local baseColor = GetTeamColor(player)
            local color = GetDistanceColor(baseColor, distance, Config.ESP.MaxDistance)

            if onScreen then
                local head = char:FindFirstChild("Head")
                local leg = char:FindFirstChild("RightFoot") or char:FindFirstChild("LeftFoot")
                local humanoid = char:FindFirstChild("Humanoid")
                local maxHealth = humanoid and humanoid.MaxHealth or 100
                local health = humanoid and humanoid.Health or 100

                local headScreen = head and GetScreenPos(head.Position)
                local legScreen = leg and GetScreenPos(leg.Position)

                local boxHeight = 0
                local boxWidth = 0
                local boxTop = 0
                local boxLeft = 0

                if headScreen and legScreen then
                    boxHeight = math.abs(headScreen.Z - legScreen.Z)
                    boxWidth = boxHeight / 2
                    boxLeft = headScreen.X - boxWidth / 2
                    boxTop = math.min(headScreen.Y, legScreen.Y)
                end

                -- Draw Box
                if Config.ESP.Box then
                    if Config.ESP.BoxStyle == "Full" then
                        local points = {
                            Vector2.new(boxLeft, boxTop),
                            Vector2.new(boxLeft + boxWidth, boxTop),
                            Vector2.new(boxLeft + boxWidth, boxTop + boxHeight),
                            Vector2.new(boxLeft, boxTop + boxHeight)
                        }
                        for i, line in pairs(espData.Box) do
                            line.Visible = true
                            line.Color = color
                            line.Transparency = Config.ESP.Transparency
                            local p1 = points[i]
                            local p2 = points[(i % 4) + 1]
                            line.From = p1
                            line.To = p2
                        end
                    elseif Config.ESP.BoxStyle == "Corner" then
                        local cornerSize = boxWidth * 0.3
                        local corners = {
                            {Vector2.new(boxLeft, boxTop), Vector2.new(boxLeft + cornerSize, boxTop)},
                            {Vector2.new(boxLeft, boxTop), Vector2.new(boxLeft, boxTop + cornerSize)},
                            {Vector2.new(boxLeft + boxWidth, boxTop), Vector2.new(boxLeft + boxWidth - cornerSize, boxTop)},
                            {Vector2.new(boxLeft + boxWidth, boxTop), Vector2.new(boxLeft + boxWidth, boxTop + cornerSize)},
                            {Vector2.new(boxLeft, boxTop + boxHeight), Vector2.new(boxLeft + cornerSize, boxTop + boxHeight)},
                            {Vector2.new(boxLeft, boxTop + boxHeight), Vector2.new(boxLeft, boxTop + boxHeight - cornerSize)},
                            {Vector2.new(boxLeft + boxWidth, boxTop + boxHeight), Vector2.new(boxLeft + boxWidth - cornerSize, boxTop + boxHeight)},
                            {Vector2.new(boxLeft + boxWidth, boxTop + boxHeight), Vector2.new(boxLeft + boxWidth, boxTop + boxHeight - cornerSize)}
                        }
                        for i, line in pairs(espData.Box) do
                            if corners[i] then
                                line.Visible = true
                                line.Color = color
                                line.From = corners[i][1]
                                line.To = corners[i][2]
                            end
                        end
                    end
                end

                -- Draw Skeleton
                if Config.ESP.Skeleton and head and hrp then
                    local neck = char:FindFirstChild("Neck")
                    local torso = char:FindFirstChild("UpperTorso") or hrp
                    local leftArm = char:FindFirstChild("LeftUpperArm")
                    local rightArm = char:FindFirstChild("RightUpperArm")
                    local leftLeg = char:FindFirstChild("LeftUpperLeg")
                    local rightLeg = char:FindFirstChild("RightUpperLeg")

                    local neckScreen = neck and GetScreenPos(neck.Position)
                    local torsoScreen = GetScreenPos(torso.Position)
                    local leftArmScreen = leftArm and GetScreenPos(leftArm.Position)
                    local rightArmScreen = rightArm and GetScreenPos(rightArm.Position)
                    local leftLegScreen = leftLeg and GetScreenPos(leftLeg.Position)
                    local rightLegScreen = rightLeg and GetScreenPos(rightLeg.Position)

                    local skeletonPoints = {
                        headScreen and neckScreen and {headScreen, neckScreen},
                        neckScreen and torsoScreen and {neckScreen, torsoScreen},
                        torsoScreen and leftArmScreen and {torsoScreen, leftArmScreen},
                        torsoScreen and rightArmScreen and {torsoScreen, rightArmScreen},
                        torsoScreen and leftLegScreen and {torsoScreen, leftLegScreen},
                        torsoScreen and rightLegScreen and {torsoScreen, rightLegScreen}
                    }

                    for i, line in pairs(espData.Skeleton) do
                        if skeletonPoints[i] then
                            line.Visible = true
                            line.Color = color
                            line.From = skeletonPoints[i][1]
                            line.To = skeletonPoints[i][2]
                        else
                            line.Visible = false
                        end
                    end
                else
                    for _, line in pairs(espData.Skeleton) do
                        line.Visible = false
                    end
                end

                -- Draw Tracer
                if Config.ESP.Tracer then
                    espData.Tracer.Visible = true
                    espData.Tracer.Color = color
                    local startPos
                    if Config.ESP.TracerStyle == "Bottom" then
                        startPos = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    elseif Config.ESP.TracerStyle == "Top" then
                        startPos = Vector2.new(Camera.ViewportSize.X / 2, 0)
                    else
                        startPos = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                    end
                    espData.Tracer.From = startPos
                    espData.Tracer.To = Vector2.new(screenPos.X, screenPos.Y)
                else
                    espData.Tracer.Visible = false
                end

                -- Draw Name
                if Config.ESP.ShowName and espData.Name then
                    espData.Name.Visible = true
                    espData.Name.Text = player.Name
                    espData.Name.Color = color
                    espData.Name.Position = Vector2.new(boxLeft, boxTop - 20 * Config.UI.Size)
                else
                    espData.Name.Visible = false
                end

                -- Draw Distance
                if Config.ESP.ShowDistance and espData.Distance then
                    espData.Distance.Visible = true
                    espData.Distance.Text = string.format("%.0f studs", distance)
                    espData.Distance.Color = color
                    espData.Distance.Position = Vector2.new(boxLeft + boxWidth + 5, boxTop + boxHeight / 2)
                else
                    espData.Distance.Visible = false
                end

                -- Draw Health
                if Config.ESP.ShowHealth and humanoid and espData.Health then
                    espData.Health.Visible = true
                    espData.Health.Text = string.format("%.0f/%.0f", health, maxHealth)
                    espData.Health.Color = health > maxHealth * 0.5 and Color3.fromRGB(0, 255, 0) or
                                           health > maxHealth * 0.25 and Color3.fromRGB(255, 255, 0) or
                                           Color3.fromRGB(255, 0, 0)
                    espData.Health.Position = Vector2.new(boxLeft + boxWidth / 2 - 20, boxTop + boxHeight + 5)
                else
                    espData.Health.Visible = false
                end

                -- Draw Weapon
                if Config.ESP.ShowWeapon and espData.Weapon then
                    local weaponName = GetPlayerWeapon(player)
                    if weaponName then
                        espData.Weapon.Visible = true
                        espData.Weapon.Text = weaponName
                        espData.Weapon.Color = color
                        espData.Weapon.Position = Vector2.new(boxLeft, boxTop + boxHeight + 25 * Config.UI.Size)
                    end
                else
                    espData.Weapon.Visible = false
                end

                -- Draw Health Bar
                if Config.ESP.HealthBar and humanoid then
                    espData.HealthBarBg.Visible = true
                    espData.HealthBar.Visible = true
                    local barWidth = 4
                    local barHeight = boxHeight
                    local healthWidth = barWidth * (health / maxHealth)
                    local barX = boxLeft - 8
                    local barY = boxTop

                    espData.HealthBarBg.From = Vector2.new(barX, barY)
                    espData.HealthBarBg.To = Vector2.new(barX, barY + barHeight)

                    espData.HealthBar.From = Vector2.new(barX, barY + barHeight)
                    espData.HealthBar.To = Vector2.new(barX + healthWidth, barY + barHeight)
                    espData.HealthBar.Color = health > maxHealth * 0.5 and Color3.fromRGB(0, 255, 0) or
                                              health > maxHealth * 0.25 and Color3.fromRGB(255, 255, 0) or
                                              Color3.fromRGB(255, 0, 0)
                else
                    espData.HealthBar.Visible = false
                    espData.HealthBarBg.Visible = false
                end
            else
                for _, line in pairs(espData.Box) do line.Visible = false end
                for _, line in pairs(espData.Skeleton) do line.Visible = false end
                if espData.Tracer then espData.Tracer.Visible = false end
                if espData.Name then espData.Name.Visible = false end
                if espData.Distance then espData.Distance.Visible = false end
                if espData.Health then espData.Health.Visible = false end
                if espData.Weapon then espData.Weapon.Visible = false end
                if espData.HealthBar then espData.HealthBar.Visible = false end
                if espData.HealthBarBg then espData.HealthBarBg.Visible = false end
            end
        end
    end

    local espConnection = RunService.RenderStepped:Connect(UpdateESP)
    table.insert(Connections, espConnection)
    return espConnection
end

function External.HookInternal()
    local originalIndex = nil
    local hooked = false

    if hookmetamethod then
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(...)
            local method = getnamecallmethod()
            local args = {...}

            if method == "Kick" and Config.Misc.AntiKick then
                return
            end

            return oldNamecall(...)
        end)
        hooked = true
    end

    return hooked
end

function External.HeartBeat()
    local heartbeatConnection = RunService.Heartbeat:Connect(function()
        -- Aimbot Logic
        if Config.Aimbot.Enabled then
            local target, targetDist = GetClosestPlayerToCursor()
            if target then
                -- Hit chance check
                if Config.Aimbot.HitChance < 100 then
                    if math.random(1, 100) > Config.Aimbot.HitChance then
                        target = nil
                    end
                end

                if target and targetDist <= Config.Aimbot.FOV then
                    local mouse = LocalPlayer:GetMouse()
                    local targetPos = target.Part.Position

                    -- Prediction
                    if Config.Aimbot.Prediction and target.Player.Character:FindFirstChild("HumanoidRootPart") then
                        local velocity = target.Player.Character.HumanoidRootPart.Velocity
                        targetPos = PredictPosition(targetPos, velocity, Config.Aimbot.PredictionScale)
                    end

                    mouse.TargetFilter = target.Player.Character
                    mouse.Target = target.Part

                    -- Auto Fire
                    if Config.Aimbot.AutoFire then
                        mouse1click()
                    end

                    -- Smooth Aim
                    if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) or
                       (IsMobile and UserInputService:IsMouseButtonPressed(Enum.UserInputType.Touch)) then
                        local currentCFrame = Camera.CFrame
                        local targetCFrame = CFrame.new(currentCFrame.Position, targetPos)

                        -- Recoil Control
                        if Config.Aimbot.RecoilControl then
                            local recoilOffset = Vector3.new(
                                math.random(-1, 1) * Config.Aimbot.RecoilValue,
                                Config.Aimbot.RecoilValue,
                                0
                            )
                            targetCFrame = targetCFrame * CFrame.new(recoilOffset)
                        end

                        local tweenInfo = TweenInfo.new(Config.Aimbot.Smoothness, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                        local view = TweenService:Create(Camera, tweenInfo, {CFrame = targetCFrame})
                        view:Play()
                    end
                end
            end
        end

        -- Fly Mode
        if Config.Misc.FlyEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            local humanoid = LocalPlayer.Character.Humanoid
            local rootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if rootPart and humanoid then
                local moveDirection = LocalPlayer.Character.Humanoid.MoveDirection
                if moveDirection.Magnitude > 0 then
                    rootPart.Velocity = moveDirection * Config.Misc.FlySpeed + Vector3.new(0, 0, 0)
                end
                humanoid.PlatformStand = true
            end
        end

        -- Speed Boost
        if Config.Misc.SpeedEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.WalkSpeed = Config.Misc.SpeedValue
        end

        -- No Clip
        if Config.Misc.NoClip and LocalPlayer.Character then
            for _, v in pairs(LocalPlayer.Character:GetDescendants()) do
                if v:IsA("BasePart") then
                    v.CanCollide = false
                end
            end
        end

        -- Auto Jump
        if Config.Misc.AutoJump and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            local humanoid = LocalPlayer.Character.Humanoid
            if humanoid.FloorMaterial ~= Enum.Material.Air then
                humanoid.Jump = true
            end
        end

        -- Infinite Jump
        if Config.Misc.InfiniteJump and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.UseJumpPower = true
            LocalPlayer.Character.Humanoid.JumpPower = 50
        end
    end)
    table.insert(Connections, heartbeatConnection)
    return heartbeatConnection
end

function External.AntiKick()
    if Config.Misc.AntiKick then
        if hookfunction then
            local kickHook = hookfunction(game.Kick, function(...)
                local args = {...}
                return
            end)
            table.insert(Hooks, kickHook)
        end
    end
end

function External.UI()
    if GlobalUI then
        GlobalUI:Destroy()
    end

    local scale = Config.UI.Size
    local themeColors = {
        Dark = {Bg = Color3.fromRGB(30, 30, 30), Title = Color3.fromRGB(45, 45, 45), Text = Color3.fromRGB(255, 255, 255), Accent = Color3.fromRGB(0, 255, 127)},
        Light = {Bg = Color3.fromRGB(240, 240, 240), Title = Color3.fromRGB(220, 220, 220), Text = Color3.fromRGB(0, 0, 0), Accent = Color3.fromRGB(0, 150, 100)},
        Blue = {Bg = Color3.fromRGB(20, 30, 50), Title = Color3.fromRGB(30, 50, 80), Text = Color3.fromRGB(200, 220, 255), Accent = Color3.fromRGB(50, 150, 255)},
        Purple = {Bg = Color3.fromRGB(30, 20, 40), Title = Color3.fromRGB(50, 30, 70), Text = Color3.fromRGB(220, 200, 255), Accent = Color3.fromRGB(150, 50, 255)}
    }
    local theme = themeColors[Config.UI.Theme] or themeColors.Dark

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "AimBotUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.IgnoreGuiInset = true

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 300 * scale, 0, 400 * scale)
    MainFrame.Position = Config.UI.Position
    MainFrame.BackgroundColor3 = theme.Bg
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui

    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 12)
    UICorner.Parent = MainFrame

    local TitleBar = Instance.new("Frame")
    TitleBar.Name = "TitleBar"
    TitleBar.Size = UDim2.new(1, 0, 0, 45 * scale)
    TitleBar.BackgroundColor3 = theme.Title
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = MainFrame

    local UICorner2 = Instance.new("UICorner")
    UICorner2.CornerRadius = UDim.new(0, 12)
    UICorner2.Parent = TitleBar

    local Title = Instance.new("TextLabel")
    Title.Name = "Title"
    Title.Size = UDim2.new(1, -40 * scale, 1, 0)
    Title.Position = UDim2.new(0, 15 * scale, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "Internal AimBot v2.0"
    Title.TextColor3 = theme.Accent
    Title.TextSize = 16 * scale
    Title.Font = Enum.Font.GothamBold
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = TitleBar

    local Version = Instance.new("TextLabel")
    Version.Name = "Version"
    Version.Size = UDim2.new(0, 60 * scale, 0, 20 * scale)
    Version.Position = UDim2.new(1, -65 * scale, 0, 12 * scale)
    Version.BackgroundTransparency = 1
    Version.Text = "MOBILE"
    Version.TextColor3 = IsMobile and theme.Accent or Color3.fromRGB(100, 100, 100)
    Version.TextSize = 10 * scale
    Version.Font = Enum.Font.GothamBold
    Version.Parent = TitleBar

    local ScrollFrame = Instance.new("ScrollingFrame")
    ScrollFrame.Name = "ScrollFrame"
    ScrollFrame.Size = UDim2.new(1, -10 * scale, 1, -55 * scale)
    ScrollFrame.Position = UDim2.new(0, 5 * scale, 0, 50 * scale)
    ScrollFrame.BackgroundTransparency = 1
    ScrollFrame.BorderSizePixel = 0
    ScrollFrame.ScrollBarThickness = 6
    ScrollFrame.ScrollBarImageColor3 = theme.Accent
    ScrollFrame.Parent = MainFrame

    local UIListLayout = Instance.new("UIListLayout")
    UIListLayout.Padding = UDim.new(0, 8 * scale)
    UIListLayout.Parent = ScrollFrame

    local UIPadding = Instance.new("UIPadding")
    UIPadding.PaddingLeft = UDim.new(0, 10 * scale)
    UIPadding.PaddingRight = UDim.new(0, 10 * scale)
    UIPadding.PaddingTop = UDim.new(0, 10 * scale)
    UIPadding.PaddingBottom = UDim.new(0, 10 * scale)
    UIPadding.Parent = ScrollFrame

    local ContentContainer = Instance.new("Frame")
    ContentContainer.Name = "ContentContainer"
    ContentContainer.Size = UDim2.new(1, -20 * scale, 1, 0)
    ContentContainer.BackgroundTransparency = 1
    ContentContainer.Parent = ScrollFrame

    local sectionY = 10 * scale

    local function CreateSection(title, yPos)
        local section = Instance.new("Frame")
        section.Name = title .. "Section"
        section.Size = UDim2.new(1, 0, 0, 30 * scale)
        section.Position = UDim2.new(0, 0, 0, yPos)
        section.BackgroundTransparency = 1
        section.Parent = ContentContainer

        local sectionLabel = Instance.new("TextLabel")
        sectionLabel.Size = UDim2.new(1, 0, 0, 20 * scale)
        sectionLabel.BackgroundTransparency = 1
        sectionLabel.Text = title
        sectionLabel.TextColor3 = theme.Accent
        sectionLabel.TextSize = 14 * scale
        sectionLabel.Font = Enum.Font.GothamBold
        sectionLabel.TextXAlignment = Enum.TextXAlignment.Left
        sectionLabel.Parent = section

        return section
    end

    local function CreateToggle(text, default, callback, yPos)
        local toggleFrame = Instance.new("Frame")
        toggleFrame.Name = text .. "Toggle"
        toggleFrame.Size = UDim2.new(1, 0, 0, 35 * scale)
        toggleFrame.Position = UDim2.new(0, 0, 0, yPos)
        toggleFrame.BackgroundTransparency = 1
        toggleFrame.Parent = ContentContainer

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.65, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = theme.Text
        label.TextSize = 13 * scale
        label.Font = Enum.Font.Gotham
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = toggleFrame

        local toggleBtn = Instance.new("TextButton")
        toggleBtn.Size = UDim2.new(0, 55 * scale, 0, 28 * scale)
        toggleBtn.Position = UDim2.new(1, -55 * scale, 0.5, -14 * scale)
        toggleBtn.BackgroundColor3 = default and theme.Accent or Color3.fromRGB(60, 60, 60)
        toggleBtn.BorderSizePixel = 0
        toggleBtn.Text = default and "ON" or "OFF"
        toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        toggleBtn.TextSize = 12 * scale
        toggleBtn.Font = Enum.Font.GothamBold
        toggleBtn.Parent = toggleFrame

        local UICorner = Instance.new("UICorner")
        UICorner.CornerRadius = UDim.new(0, 6)
        UICorner.Parent = toggleBtn

        local enabled = default
        toggleBtn.MouseButton1Click:Connect(function()
            enabled = not enabled
            toggleBtn.BackgroundColor3 = enabled and theme.Accent or Color3.fromRGB(60, 60, 60)
            toggleBtn.Text = enabled and "ON" or "OFF"
            callback(enabled)
        end)

        -- Touch support for mobile
        if IsMobile then
            toggleBtn.TouchTap:Connect(function()
                enabled = not enabled
                toggleBtn.BackgroundColor3 = enabled and theme.Accent or Color3.fromRGB(60, 60, 60)
                toggleBtn.Text = enabled and "ON" or "OFF"
                callback(enabled)
            end)
        end

        return toggleFrame
    end

    local function CreateSlider(text, min, max, default, callback, yPos)
        local sliderFrame = Instance.new("Frame")
        sliderFrame.Name = text .. "Slider"
        sliderFrame.Size = UDim2.new(1, 0, 0, 50 * scale)
        sliderFrame.Position = UDim2.new(0, 0, 0, yPos)
        sliderFrame.BackgroundTransparency = 1
        sliderFrame.Parent = ContentContainer

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0, 20 * scale)
        label.BackgroundTransparency = 1
        label.Text = text .. ": " .. tostring(default)
        label.TextColor3 = theme.Text
        label.TextSize = 13 * scale
        label.Font = Enum.Font.Gotham
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = sliderFrame

        local sliderBg = Instance.new("Frame")
        sliderBg.Name = "SliderBg"
        sliderBg.Size = UDim2.new(1, 0, 0, 20 * scale)
        sliderBg.Position = UDim2.new(0, 0, 0, 25 * scale)
        sliderBg.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        sliderBg.BorderSizePixel = 0
        sliderBg.Parent = sliderFrame

        local UICorner = Instance.new("UICorner")
        UICorner.CornerRadius = UDim.new(0, 4)
        UICorner.Parent = sliderBg

        local sliderFill = Instance.new("Frame")
        sliderFill.Name = "SliderFill"
        sliderFill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
        sliderFill.BackgroundColor3 = theme.Accent
        sliderFill.BorderSizePixel = 0
        sliderFill.Parent = sliderBg

        local UICorner2 = Instance.new("UICorner")
        UICorner2.CornerRadius = UDim.new(0, 4)
        UICorner2.Parent = sliderFill

        local sliderBtn = Instance.new("TextButton")
        sliderBtn.Size = UDim2.new(1, 0, 0, 20 * scale)
        sliderBtn.BackgroundTransparency = 1
        sliderBtn.Text = ""
        sliderBtn.Parent = sliderBg

        local dragging = false
        local currentValue = default

        local function updateSlider(input)
            local relativePos = (input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X
            relativePos = math.clamp(relativePos, 0, 1)
            currentValue = min + (max - min) * relativePos
            sliderFill.Size = UDim2.new(relativePos, 0, 1, 0)
            label.Text = text .. ": " .. string.format("%.1f", currentValue)
            callback(currentValue)
        end

        sliderBtn.MouseButton1Down:Connect(function()
            dragging = true
        end)

        sliderBtn.MouseButton1Up:Connect(function()
            dragging = false
        end)

        sliderBtn.InputChanged:Connect(function(input)
            if dragging then
                updateSlider(input)
            end
        end)

        -- Mobile touch support
        if IsMobile then
            local touchDragging = false

            sliderBtn.TouchTap:Connect(function()
                touchDragging = true
            end)

            UserInputService.TouchEnded:Connect(function()
                touchDragging = false
            end)

            UserInputService.InputChanged:Connect(function(input)
                if touchDragging and input.UserInputType == Enum.UserInputType.Touch then
                    updateSlider(input)
                end
            end)
        end

        return sliderFrame
    end

    -- Build UI Sections
    local currentY = 0

    CreateSection("AIMBOT", currentY)
    currentY = currentY + 35 * scale

    CreateToggle("Aimbot Enabled", Config.Aimbot.Enabled, function(v) Config.Aimbot.Enabled = v end, currentY)
    currentY = currentY + 40 * scale

    CreateSlider("FOV", 10, 360, Config.Aimbot.FOV, function(v) Config.Aimbot.FOV = v UpdateFOVCircle() end, currentY)
    currentY = currentY + 55 * scale

    CreateSlider("Smoothness", 0, 1, Config.Aimbot.Smoothness, function(v) Config.Aimbot.Smoothness = v end, currentY)
    currentY = currentY + 55 * scale

    CreateToggle("Prediction", Config.Aimbot.Prediction, function(v) Config.Aimbot.Prediction = v end, currentY)
    currentY = currentY + 40 * scale

    CreateSlider("Prediction Scale", 0, 1, Config.Aimbot.PredictionScale, function(v) Config.Aimbot.PredictionScale = v end, currentY)
    currentY = currentY + 55 * scale

    CreateToggle("Recoil Control", Config.Aimbot.RecoilControl, function(v) Config.Aimbot.RecoilControl = v end, currentY)
    currentY = currentY + 40 * scale

    CreateToggle("FOV Circle", Config.Aimbot.FOVCircle, function(v) Config.Aimbot.FOVCircle = v UpdateFOVCircle() end, currentY)
    currentY = currentY + 40 * scale

    CreateToggle("Auto Fire", Config.Aimbot.AutoFire, function(v) Config.Aimbot.AutoFire = v end, currentY)
    currentY = currentY + 40 * scale

    CreateSection("ESP", currentY)
    currentY = currentY + 35 * scale

    CreateToggle("ESP Enabled", Config.ESP.Enabled, function(v) Config.ESP.Enabled = v end, currentY)
    currentY = currentY + 40 * scale

    CreateToggle("Box ESP", Config.ESP.Box, function(v) Config.ESP.Box = v end, currentY)
    currentY = currentY + 40 * scale

    CreateToggle("Skeleton ESP", Config.ESP.Skeleton, function(v) Config.ESP.Skeleton = v end, currentY)
    currentY = currentY + 40 * scale

    CreateToggle("Tracer", Config.ESP.Tracer, function(v) Config.ESP.Tracer = v end, currentY)
    currentY = currentY + 40 * scale

    CreateToggle("Health Bar", Config.ESP.HealthBar, function(v) Config.ESP.HealthBar = v end, currentY)
    currentY = currentY + 40 * scale

    CreateToggle("Show Names", Config.ESP.ShowName, function(v) Config.ESP.ShowName = v end, currentY)
    currentY = currentY + 40 * scale

    CreateToggle("Show Distance", Config.ESP.ShowDistance, function(v) Config.ESP.ShowDistance = v end, currentY)
    currentY = currentY + 40 * scale

    CreateToggle("Show Team", Config.ESP.ShowTeam, function(v) Config.ESP.ShowTeam = v end, currentY)
    currentY = currentY + 40 * scale

    CreateSection("MISC", currentY)
    currentY = currentY + 35 * scale

    CreateToggle("Fly Mode", Config.Misc.FlyEnabled, function(v) Config.Misc.FlyEnabled = v end, currentY)
    currentY = currentY + 40 * scale

    CreateSlider("Fly Speed", 10, 200, Config.Misc.FlySpeed, function(v) Config.Misc.FlySpeed = v end, currentY)
    currentY = currentY + 55 * scale

    CreateToggle("Speed Boost", Config.Misc.SpeedEnabled, function(v) Config.Misc.SpeedEnabled = v end, currentY)
    currentY = currentY + 40 * scale

    CreateSlider("Speed Value", 16, 100, Config.Misc.SpeedValue, function(v) Config.Misc.SpeedValue = v end, currentY)
    currentY = currentY + 55 * scale

    CreateToggle("No Clip", Config.Misc.NoClip, function(v) Config.Misc.NoClip = v end, currentY)
    currentY = currentY + 40 * scale

    CreateToggle("Auto Jump", Config.Misc.AutoJump, function(v) Config.Misc.AutoJump = v end, currentY)
    currentY = currentY + 40 * scale

    CreateToggle("Infinite Jump", Config.Misc.InfiniteJump, function(v) Config.Misc.InfiniteJump = v end, currentY)
    currentY = currentY + 40 * scale

    CreateSection("UI SETTINGS", currentY)
    currentY = currentY + 35 * scale

    CreateToggle("Mobile Mode", Config.UI.MobileMode, function(v) Config.UI.MobileMode = v Config.UI.Size = v and 1.2 or 1 end, currentY)
    currentY = currentY + 40 * scale

    -- Close Button
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Name = "Close"
    CloseBtn.Size = UDim2.new(0, 35 * scale, 0, 35 * scale)
    CloseBtn.Position = UDim2.new(1, -40 * scale, 0, 5 * scale)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    CloseBtn.BorderSizePixel = 0
    CloseBtn.Text = "X"
    CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseBtn.TextSize = 16 * scale
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.Parent = MainFrame

    local UICorner3 = Instance.new("UICorner")
    UICorner3.CornerRadius = UDim.new(0, 6)
    UICorner3.Parent = CloseBtn

    CloseBtn.MouseButton1Click:Connect(function()
        ScreenGui:Destroy()
        GlobalUI = nil
    end)

    -- Dragging Support (Mouse + Touch)
    local dragging = false
    local dragInput
    local dragStart
    local startPos

    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    TitleBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or
           input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    -- Update scroll size
    ContentContainer.Size = UDim2.new(1, -20 * scale, 0, currentY + 20 * scale)
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, currentY + 20 * scale)

    ScreenGui.Parent = LocalPlayer.PlayerGui
    GlobalUI = ScreenGui
    return ScreenGui
end

--| Internal Module
local Internal = {}

function Internal.AddToCache(key, value)
    cache[key] = value
    return cache[key]
end

function Internal.RemoveCache(key)
    cache[key] = nil
end

function Internal.Shutdown()
    -- Disconnect connections
    for _, connection in pairs(Connections) do
        if connection.Connected then
            connection:Disconnect()
        end
    end
    Connections = {}

    -- Remove hooks
    for _, hook in pairs(Hooks) do
        pcall(function() hook:Abort() end)
    end
    Hooks = {}

    -- Remove ESP
    for userId, espData in pairs(cache) do
        for _, line in pairs(espData.Box) do
            pcall(function() line:Remove() end)
        end
        for _, line in pairs(espData.Skeleton) do
            pcall(function() line:Remove() end)
        end
        pcall(function() espData.Tracer:Remove() end)
        pcall(function() espData.Name:Remove() end)
        pcall(function() espData.Distance:Remove() end)
        pcall(function() espData.Health:Remove() end)
        pcall(function() espData.Weapon:Remove() end)
        pcall(function() espData.HealthBar:Remove() end)
        pcall(function() espData.HealthBarBg:Remove() end)
    end
    cache = {}

    -- Remove drawings
    if DrawingCache.FOVCircle then
        pcall(function() DrawingCache.FOVCircle:Remove() end)
    end
    DrawingCache = {}

    -- Remove UI
    if GlobalUI then
        pcall(function() GlobalUI:Destroy() end)
        GlobalUI = nil
    end

    -- Reset state
    Info = {}
end

function Internal.Initialize()
    External.HookInternal()
    External.HookESP()
    External.HeartBeat()
    External.AntiKick()

    -- Create FOV Circle
    if Config.Aimbot.FOVCircle then
        CreateFOVCircle()
    end

    Info.Loaded = true
    Info.LoadTime = tick()
    Info.Version = "2.0"
    Info.MobileEnabled = IsMobile

    -- Toggle UI with keybind
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Config.UI.ToggleKey then
            if GlobalUI then
                GlobalUI:Destroy()
                GlobalUI = nil
            else
                External.UI()
            end
        end
    end)

    -- Mobile: Add touch toggle button
    if IsMobile then
        local TouchToggle = Instance.new("ScreenGui")
        TouchToggle.Name = "TouchToggle"
        TouchToggle.ResetOnSpawn = false

        local ToggleBtn = Instance.new("TextButton")
        ToggleBtn.Name = "ToggleBtn"
        ToggleBtn.Size = UDim2.new(0, 50, 0, 50)
        ToggleBtn.Position = UDim2.new(0, 10, 1, -60)
        ToggleBtn.BackgroundColor3 = Config.UI.MobileMode and Color3.fromRGB(0, 255, 127) or Color3.fromRGB(50, 50, 50)
        ToggleBtn.BorderSizePixel = 0
        ToggleBtn.Text = "UI"
        ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        ToggleBtn.TextSize = 14
        ToggleBtn.Font = Enum.Font.GothamBold

        local UICorner = Instance.new("UICorner")
        UICorner.CornerRadius = UDim.new(0, 8)
        UICorner.Parent = ToggleBtn

        ToggleBtn.MouseButton1Click:Connect(function()
            if GlobalUI then
                GlobalUI:Destroy()
                GlobalUI = nil
                ToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            else
                External.UI()
                ToggleBtn.BackgroundColor3 = Config.UI.MobileMode and Color3.fromRGB(0, 255, 127) or Color3.fromRGB(50, 50, 50)
            end
        end)

        -- Touch support
        ToggleBtn.TouchTap:Connect(function()
            if GlobalUI then
                GlobalUI:Destroy()
                GlobalUI = nil
                ToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            else
                External.UI()
                ToggleBtn.BackgroundColor3 = Config.UI.MobileMode and Color3.fromRGB(0, 255, 127) or Color3.fromRGB(50, 50, 50)
            end
        end)

        TouchToggle.Parent = LocalPlayer.PlayerGui
        ToggleBtn.Parent = TouchToggle
    end
end

function Internal.Hook()
    return {
        Config = Config,
        cache = cache,
        forsakencache = forsakencache,
        Info = Info,
        IsMobile = IsMobile
    }
end

--| Config System (Future Expansion)
function Internal.SaveConfig(profileName)
    profileName = profileName or CurrentProfile
    ConfigProfiles[profileName] = {}
    for k, v in pairs(Config) do
        ConfigProfiles[profileName][k] = {}
        for k2, v2 in pairs(v) do
            if type(v2) ~= "function" then
                ConfigProfiles[profileName][k][k2] = v2
            end
        end
    end
    Info.LastSaved = tick()
end

function Internal.LoadConfig(profileName)
    profileName = profileName or CurrentProfile
    if ConfigProfiles[profileName] then
        for k, v in pairs(ConfigProfiles[profileName]) do
            if Config[k] then
                for k2, v2 in pairs(v) do
                    Config[k][k2] = v2
                end
            end
        end
        CurrentProfile = profileName
        Info.LastLoaded = tick()
        return true
    end
    return false
end

return {External = External, Internal = Internal}