print("Made By agente0981 In discord.")
--// SERVICES
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Stats = game:GetService("Stats")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local placeId = game.PlaceId

--// CONFIG
local pingValue = 60
local LIVE_ENABLED = false
local FETCHING = false
local REFRESH_DELAY = 5

--// AUTO EXEC AFTER TP
local function queueScript()
    if queue_on_teleport then
        queue_on_teleport(game:HttpGet("https://pastebin.com/raw/CZpBj906"))
    end
end

--// PING REAL
local function getPing()
    local stat = Stats.Network.ServerStatsItem["Data Ping"]
    if stat then
        local raw = stat:GetValueString()
        return tonumber(raw:match("%d+"))
    end
end

--// PROMPT
local function showPrompt(expectedPing, bestServer)
    pcall(function()
        CoreGui:FindFirstChild("HopPrompt_UI"):Destroy()
    end)

    local gui = Instance.new("ScreenGui", CoreGui)
    gui.Name = "HopPrompt_UI"

    local frame = Instance.new("Frame", gui)
    frame.Size = UDim2.new(0,300,0,160)
    frame.Position = UDim2.new(0.5,-150,0.5,-80)
    frame.BackgroundColor3 = Color3.fromRGB(20,20,30)
    Instance.new("UICorner", frame)

    local txt = Instance.new("TextLabel", frame)
    txt.Size = UDim2.new(1,-20,1,-60)
    txt.Position = UDim2.new(0,10,0,10)
    txt.BackgroundTransparency = 1
    txt.TextColor3 = Color3.new(1,1,1)
    txt.TextWrapped = true

    txt.Text =
        "Hop To Server\n\n"..
        "Current Ping: "..(getPing() or "?").." ms\n"..
        "Expected Ping: "..(expectedPing or "?").." ms\n\n"..
        "Teleport again?"

    local yes = Instance.new("TextButton", frame)
    yes.Size = UDim2.new(0.45,0,0,30)
    yes.Position = UDim2.new(0.05,0,1,-40)
    yes.Text = "SIM"
    yes.BackgroundColor3 = Color3.fromRGB(0,170,100)

    local no = Instance.new("TextButton", frame)
    no.Size = UDim2.new(0.45,0,0,30)
    no.Position = UDim2.new(0.5,0,1,-40)
    no.Text = "NÃO"
    no.BackgroundColor3 = Color3.fromRGB(170,60,60)

    yes.MouseButton1Click:Connect(function()
        pcall(function()
            TeleportService:TeleportToPlaceInstance(placeId, bestServer.id, LocalPlayer)
        end)
    end)

    no.MouseButton1Click:Connect(function()
        gui:Destroy()
    end)
end

--// FETCH SERVERS
local function fetchBest()
    if FETCHING then return end
    FETCHING = true

    local best = nil

    for i=1,3 do
        local ok,data = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(
                "https://games.roblox.com/v1/games/"..placeId.."/servers/Public?limit=100"
            ))
        end)

        if ok and data and data.data then
            for _,s in ipairs(data.data) do
                local ping = tonumber(s.ping)
                local playing = tonumber(s.playing)
                local maxP = tonumber(s.maxPlayers)

                if ping and playing and maxP and ping <= pingValue and playing < maxP then
                    if not best or ping < best.ping then
                        best = s
                    end
                end
            end
        end
    end

    FETCHING = false
    return best
end

--// UI COMPACTA
pcall(function()
    CoreGui:FindFirstChild("FinderUI"):Destroy()
end)

local gui = Instance.new("ScreenGui", CoreGui)
gui.Name = "FinderUI"

local main = Instance.new("Frame", gui)
main.Size = UDim2.new(0,260,0,320)
main.Position = UDim2.new(0.5,-130,0.5,-160)
main.BackgroundColor3 = Color3.fromRGB(20,20,28)
Instance.new("UICorner", main)

local title = Instance.new("TextLabel", main)
title.Size = UDim2.new(1,0,0,30)
title.Text = "Finder X"
title.BackgroundColor3 = Color3.fromRGB(0,140,255)
title.TextColor3 = Color3.new(1,1,1)

-- BOTÃO BUSCAR
local btn = Instance.new("TextButton", main)
btn.Size = UDim2.new(1,-20,0,30)
btn.Position = UDim2.new(0,10,1,-40)
btn.Text = "Buscar Melhor Servidor"
btn.BackgroundColor3 = Color3.fromRGB(0,140,255)

btn.MouseButton1Click:Connect(function()
    local best = fetchBest()
    if best then
        queueScript()
        TeleportService:TeleportToPlaceInstance(placeId, best.id, LocalPlayer)
    end
end)

--// AUTO PROMPT APÓS TP
task.delay(3, function()
    local best = fetchBest()
    if best then
        showPrompt(best.ping, best)
    end
end)
