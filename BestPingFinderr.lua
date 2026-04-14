print("Made By agente0981 In discord.")

--// SERVICES
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Stats = game:GetService("Stats")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local placeId = game.PlaceId
local jobId = game.JobId

--// CONFIG
local Config = {
    pingTarget = 60,
    refreshDelay = 5,
    pageLimit = 8,
    retries = 2,
    language = "en", -- en, pt, es
    autoPromptAfterJoin = true,
    livePing = true,
}

--// I18N
local I18N = {
    en = {
        title = "Best Ping Finder",
        pingTarget = "Ping target (ms)",
        statusIdle = "Ready",
        statusSearching = "Searching best server...",
        statusFound = "Found: %dms (%d/%d players)",
        statusNotFound = "No suitable server found.",
        statusTeleport = "Teleporting...",
        statusError = "Request error, retrying...",
        findButton = "Find Best Server",
        langButton = "Language: English",
        autoPromptOn = "Auto Prompt: ON",
        autoPromptOff = "Auto Prompt: OFF",
        livePingLabel = "Live Ping: %s ms",
        currentTarget = "Current target: %d ms",
        bestSeen = "Best seen: %s ms",
        promptTitle = "Switch Server",
        currentPing = "Current Ping: %s ms",
        expectedPing = "Expected Ping: %s ms",
        teleportAgain = "Teleport to this server?",
        yes = "YES",
        no = "NO",
        minimize = "_",
        close = "X",
    },
    pt = {
        title = "Buscador de Melhor Ping",
        pingTarget = "Ping alvo (ms)",
        statusIdle = "Pronto",
        statusSearching = "Buscando melhor servidor...",
        statusFound = "Encontrado: %dms (%d/%d jogadores)",
        statusNotFound = "Nenhum servidor adequado encontrado.",
        statusTeleport = "Teleportando...",
        statusError = "Erro na requisição, tentando de novo...",
        findButton = "Buscar Melhor Servidor",
        langButton = "Idioma: Português",
        autoPromptOn = "Auto Prompt: ON",
        autoPromptOff = "Auto Prompt: OFF",
        livePingLabel = "Ping Atual: %s ms",
        currentTarget = "Alvo atual: %d ms",
        bestSeen = "Melhor visto: %s ms",
        promptTitle = "Trocar Servidor",
        currentPing = "Ping Atual: %s ms",
        expectedPing = "Ping Esperado: %s ms",
        teleportAgain = "Teleportar para este servidor?",
        yes = "SIM",
        no = "NÃO",
        minimize = "_",
        close = "X",
    },
    es = {
        title = "Buscador de Mejor Ping",
        pingTarget = "Ping objetivo (ms)",
        statusIdle = "Listo",
        statusSearching = "Buscando el mejor servidor...",
        statusFound = "Encontrado: %dms (%d/%d jugadores)",
        statusNotFound = "No se encontró un servidor adecuado.",
        statusTeleport = "Teletransportando...",
        statusError = "Error de solicitud, reintentando...",
        findButton = "Buscar Mejor Servidor",
        langButton = "Idioma: Español",
        autoPromptOn = "Auto Prompt: ON",
        autoPromptOff = "Auto Prompt: OFF",
        livePingLabel = "Ping Actual: %s ms",
        currentTarget = "Objetivo actual: %d ms",
        bestSeen = "Mejor visto: %s ms",
        promptTitle = "Cambiar Servidor",
        currentPing = "Ping Actual: %s ms",
        expectedPing = "Ping Esperado: %s ms",
        teleportAgain = "¿Teletransportar a este servidor?",
        yes = "SÍ",
        no = "NO",
        minimize = "_",
        close = "X",
    },
}

local languages = { "en", "pt", "es" }
local languageIndex = table.find(languages, Config.language) or 1

local function tr(key)
    local lang = I18N[languages[languageIndex]] or I18N.en
    return lang[key] or I18N.en[key] or key
end

--// AUTO EXEC AFTER TP
local function queueScript()
    if queue_on_teleport then
        queue_on_teleport(game:HttpGet("https://pastebin.com/raw/CZpBj906"))
    end
end

--// REAL PING
local function getPing()
    local stat = Stats.Network.ServerStatsItem["Data Ping"]
    if stat then
        local raw = stat:GetValueString()
        return tonumber(raw:match("%d+"))
    end
end

--// FIND BEST SERVER
local FETCHING = false
local function fetchBest()
    if FETCHING then return nil end
    FETCHING = true

    local best = nil
    local cursor = ""
    local pagesChecked = 0

    while pagesChecked < Config.pageLimit do
        local url = string.format(
            "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100%s",
            placeId,
            cursor ~= "" and ("&cursor=" .. cursor) or ""
        )

        local data = nil
        for _ = 1, Config.retries do
            local ok, result = pcall(function()
                return HttpService:JSONDecode(game:HttpGet(url))
            end)
            if ok and result and result.data then
                data = result
                break
            end
            task.wait(0.2)
        end

        if not data then
            FETCHING = false
            return nil, "request_error"
        end

        for _, server in ipairs(data.data) do
            local ping = tonumber(server.ping)
            local playing = tonumber(server.playing)
            local maxPlayers = tonumber(server.maxPlayers)

            if server.id ~= jobId and ping and playing and maxPlayers and playing < maxPlayers and ping <= Config.pingTarget then
                if not best or ping < best.ping then
                    best = server
                end
            end
        end

        pagesChecked += 1
        cursor = data.nextPageCursor or ""
        if cursor == "" then
            break
        end
    end

    FETCHING = false
    return best
end

--// PROMPT
local function showPrompt(expectedPing, bestServer)
    pcall(function()
        CoreGui:FindFirstChild("HopPrompt_UI"):Destroy()
    end)

    local gui = Instance.new("ScreenGui")
    gui.Name = "HopPrompt_UI"
    gui.ResetOnSpawn = false
    gui.Parent = CoreGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 320, 0, 170)
    frame.Position = UDim2.new(0.5, -160, 0.5, -85)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.new(1, -20, 1, -60)
    txt.Position = UDim2.new(0, 10, 0, 10)
    txt.BackgroundTransparency = 1
    txt.TextColor3 = Color3.new(1, 1, 1)
    txt.TextWrapped = true
    txt.Font = Enum.Font.Gotham
    txt.TextSize = 14
    txt.Parent = frame

    txt.Text = string.format(
        "%s\n\n%s\n%s\n\n%s",
        tr("promptTitle"),
        string.format(tr("currentPing"), getPing() or "?"),
        string.format(tr("expectedPing"), expectedPing or "?"),
        tr("teleportAgain")
    )

    local yes = Instance.new("TextButton")
    yes.Size = UDim2.new(0.45, 0, 0, 30)
    yes.Position = UDim2.new(0.05, 0, 1, -40)
    yes.Text = tr("yes")
    yes.BackgroundColor3 = Color3.fromRGB(0, 170, 100)
    yes.TextColor3 = Color3.new(1, 1, 1)
    yes.Font = Enum.Font.GothamBold
    yes.TextSize = 13
    yes.Parent = frame
    Instance.new("UICorner", yes)

    local no = Instance.new("TextButton")
    no.Size = UDim2.new(0.45, 0, 0, 30)
    no.Position = UDim2.new(0.5, 0, 1, -40)
    no.Text = tr("no")
    no.BackgroundColor3 = Color3.fromRGB(170, 60, 60)
    no.TextColor3 = Color3.new(1, 1, 1)
    no.Font = Enum.Font.GothamBold
    no.TextSize = 13
    no.Parent = frame
    Instance.new("UICorner", no)

    yes.MouseButton1Click:Connect(function()
        pcall(function()
            TeleportService:TeleportToPlaceInstance(placeId, bestServer.id, LocalPlayer)
        end)
    end)

    no.MouseButton1Click:Connect(function()
        gui:Destroy()
    end)
end

--// UI
pcall(function()
    CoreGui:FindFirstChild("FinderUI"):Destroy()
end)

local gui = Instance.new("ScreenGui")
gui.Name = "FinderUI"
gui.ResetOnSpawn = false
gui.Parent = CoreGui

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 320, 0, 280)
main.Position = UDim2.new(0.5, -160, 0.5, -140)
main.BackgroundColor3 = Color3.fromRGB(19, 22, 30)
main.BorderSizePixel = 0
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 34)
topBar.BackgroundColor3 = Color3.fromRGB(0, 140, 255)
topBar.BorderSizePixel = 0
topBar.Parent = main
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -70, 1, 0)
title.Position = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.new(1, 1, 1)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.Parent = topBar

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 28, 0, 24)
minBtn.Position = UDim2.new(1, -58, 0.5, -12)
minBtn.BackgroundColor3 = Color3.fromRGB(40, 110, 200)
minBtn.TextColor3 = Color3.new(1, 1, 1)
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 16
minBtn.Parent = topBar
Instance.new("UICorner", minBtn)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 24)
closeBtn.Position = UDim2.new(1, -28, 0.5, -12)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 65, 65)
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.Parent = topBar
Instance.new("UICorner", closeBtn)

local body = Instance.new("Frame")
body.Size = UDim2.new(1, -16, 1, -50)
body.Position = UDim2.new(0, 8, 0, 40)
body.BackgroundTransparency = 1
body.Parent = main

local livePingText = Instance.new("TextLabel")
livePingText.Size = UDim2.new(1, 0, 0, 20)
livePingText.BackgroundTransparency = 1
livePingText.TextColor3 = Color3.fromRGB(130, 220, 255)
livePingText.TextXAlignment = Enum.TextXAlignment.Left
livePingText.Font = Enum.Font.Gotham
livePingText.TextSize = 13
livePingText.Parent = body

local pingLabel = Instance.new("TextLabel")
pingLabel.Size = UDim2.new(1, 0, 0, 20)
pingLabel.Position = UDim2.new(0, 0, 0, 24)
pingLabel.BackgroundTransparency = 1
pingLabel.TextColor3 = Color3.new(1, 1, 1)
pingLabel.TextXAlignment = Enum.TextXAlignment.Left
pingLabel.Font = Enum.Font.Gotham
pingLabel.TextSize = 13
pingLabel.Parent = body

local pingBox = Instance.new("TextBox")
pingBox.Size = UDim2.new(1, 0, 0, 28)
pingBox.Position = UDim2.new(0, 0, 0, 46)
pingBox.BackgroundColor3 = Color3.fromRGB(35, 38, 50)
pingBox.TextColor3 = Color3.new(1, 1, 1)
pingBox.Text = tostring(Config.pingTarget)
pingBox.Font = Enum.Font.Gotham
pingBox.TextSize = 14
pingBox.ClearTextOnFocus = false
pingBox.Parent = body
Instance.new("UICorner", pingBox)

local targetInfo = Instance.new("TextLabel")
targetInfo.Size = UDim2.new(1, 0, 0, 20)
targetInfo.Position = UDim2.new(0, 0, 0, 78)
targetInfo.BackgroundTransparency = 1
targetInfo.TextColor3 = Color3.fromRGB(210, 210, 255)
targetInfo.TextXAlignment = Enum.TextXAlignment.Left
targetInfo.Font = Enum.Font.Gotham
targetInfo.TextSize = 12
targetInfo.Parent = body

local bestSeenInfo = Instance.new("TextLabel")
bestSeenInfo.Size = UDim2.new(1, 0, 0, 20)
bestSeenInfo.Position = UDim2.new(0, 0, 0, 98)
bestSeenInfo.BackgroundTransparency = 1
bestSeenInfo.TextColor3 = Color3.fromRGB(180, 255, 190)
bestSeenInfo.TextXAlignment = Enum.TextXAlignment.Left
bestSeenInfo.Font = Enum.Font.Gotham
bestSeenInfo.TextSize = 12
bestSeenInfo.Parent = body

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, 0, 0, 42)
status.Position = UDim2.new(0, 0, 0, 122)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(200, 220, 255)
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left
status.Font = Enum.Font.Gotham
status.TextSize = 12
status.Parent = body

local autoPromptBtn = Instance.new("TextButton")
autoPromptBtn.Size = UDim2.new(1, 0, 0, 28)
autoPromptBtn.Position = UDim2.new(0, 0, 1, -64)
autoPromptBtn.BackgroundColor3 = Color3.fromRGB(58, 83, 120)
autoPromptBtn.TextColor3 = Color3.new(1, 1, 1)
autoPromptBtn.Font = Enum.Font.Gotham
autoPromptBtn.TextSize = 13
autoPromptBtn.Parent = body
Instance.new("UICorner", autoPromptBtn)

local langBtn = Instance.new("TextButton")
langBtn.Size = UDim2.new(0.49, -3, 0, 30)
langBtn.Position = UDim2.new(0, 0, 1, -32)
langBtn.BackgroundColor3 = Color3.fromRGB(62, 62, 85)
langBtn.TextColor3 = Color3.new(1, 1, 1)
langBtn.Font = Enum.Font.Gotham
langBtn.TextSize = 13
langBtn.Parent = body
Instance.new("UICorner", langBtn)

local findBtn = Instance.new("TextButton")
findBtn.Size = UDim2.new(0.51, -3, 0, 30)
findBtn.Position = UDim2.new(0.49, 3, 1, -32)
findBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 255)
findBtn.TextColor3 = Color3.new(1, 1, 1)
findBtn.Font = Enum.Font.GothamBold
findBtn.TextSize = 14
findBtn.Parent = body
Instance.new("UICorner", findBtn)

-- Drag support (fixed)
local dragging = false
local dragStart = nil
local startPos = nil
local dragInput = nil

local function updateDrag(input)
    if not dragging then return end
    local delta = input.Position - dragStart
    main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = main.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

topBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        updateDrag(input)
    end
end)

local bestSeen = nil
local minimized = false

local function refreshTexts()
    title.Text = tr("title")
    pingLabel.Text = tr("pingTarget")
    langBtn.Text = tr("langButton")
    findBtn.Text = tr("findButton")
    autoPromptBtn.Text = Config.autoPromptAfterJoin and tr("autoPromptOn") or tr("autoPromptOff")
    minBtn.Text = tr("minimize")
    closeBtn.Text = tr("close")
    targetInfo.Text = string.format(tr("currentTarget"), Config.pingTarget)
    bestSeenInfo.Text = string.format(tr("bestSeen"), bestSeen and tostring(bestSeen) or "-")
    if status.Text == "" then
        status.Text = tr("statusIdle")
    end
end

refreshTexts()

closeBtn.MouseButton1Click:Connect(function()
    gui:Destroy()
end)

minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    body.Visible = not minimized
    main.Size = minimized and UDim2.new(0, 320, 0, 42) or UDim2.new(0, 320, 0, 280)
end)

pingBox.FocusLost:Connect(function()
    local value = tonumber(pingBox.Text)
    if value and value > 0 then
        Config.pingTarget = math.floor(value)
    end
    pingBox.Text = tostring(Config.pingTarget)
    targetInfo.Text = string.format(tr("currentTarget"), Config.pingTarget)
end)

autoPromptBtn.MouseButton1Click:Connect(function()
    Config.autoPromptAfterJoin = not Config.autoPromptAfterJoin
    autoPromptBtn.Text = Config.autoPromptAfterJoin and tr("autoPromptOn") or tr("autoPromptOff")
end)

langBtn.MouseButton1Click:Connect(function()
    languageIndex += 1
    if languageIndex > #languages then
        languageIndex = 1
    end
    status.Text = tr("statusIdle")
    refreshTexts()
end)

findBtn.MouseButton1Click:Connect(function()
    if FETCHING then return end

    status.Text = tr("statusSearching")
    local best, reason = fetchBest()

    if not best then
        status.Text = (reason == "request_error") and tr("statusError") or tr("statusNotFound")
        return
    end

    local ping = tonumber(best.ping) or 0
    local playing = tonumber(best.playing) or 0
    local maxPlayers = tonumber(best.maxPlayers) or 0

    if not bestSeen or ping < bestSeen then
        bestSeen = ping
        bestSeenInfo.Text = string.format(tr("bestSeen"), tostring(bestSeen))
    end

    status.Text = string.format(tr("statusFound"), ping, playing, maxPlayers)
    queueScript()
    status.Text = tr("statusTeleport")
    TeleportService:TeleportToPlaceInstance(placeId, best.id, LocalPlayer)
end)

if Config.livePing then
    task.spawn(function()
        while gui.Parent do
            local ping = getPing()
            livePingText.Text = string.format(tr("livePingLabel"), ping or "?")
            task.wait(1)
        end
    end)
end

--// OPTIONAL PROMPT AFTER JOIN
if Config.autoPromptAfterJoin then
    task.delay(Config.refreshDelay, function()
        if not Config.autoPromptAfterJoin then return end
        local best = fetchBest()
        if best then
            showPrompt(best.ping, best)
        end
    end)
end
