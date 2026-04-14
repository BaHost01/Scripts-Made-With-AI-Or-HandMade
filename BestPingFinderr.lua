print("Made By agente0981 In discord.")

--// SERVICES
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Stats = game:GetService("Stats")
local CoreGui = game:GetService("CoreGui")

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
        promptTitle = "Switch Server",
        currentPing = "Current Ping: %s ms",
        expectedPing = "Expected Ping: %s ms",
        teleportAgain = "Teleport to this server?",
        yes = "YES",
        no = "NO",
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
        promptTitle = "Trocar Servidor",
        currentPing = "Ping Atual: %s ms",
        expectedPing = "Ping Esperado: %s ms",
        teleportAgain = "Teleportar para este servidor?",
        yes = "SIM",
        no = "NÃO",
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
        promptTitle = "Cambiar Servidor",
        currentPing = "Ping Actual: %s ms",
        expectedPing = "Ping Esperado: %s ms",
        teleportAgain = "¿Teletransportar a este servidor?",
        yes = "SÍ",
        no = "NO",
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
        queue_on_teleport(game:HttpGet("https://raw.githubusercontent.com/BaHost01/Scripts-Made-With-AI-Or-HandMade/refs/heads/main/BestPingFinderr.lua"))
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

--// FIND BEST SERVER (pagination + retries + ignore current server)
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
            task.wait(0.25)
        end

        if not data then
            FETCHING = false
            return nil, "request_error"
        end

        for _, s in ipairs(data.data) do
            local ping = tonumber(s.ping)
            local playing = tonumber(s.playing)
            local maxP = tonumber(s.maxPlayers)

            if s.id ~= jobId and ping and playing and maxP and playing < maxP and ping <= Config.pingTarget then
                if not best or ping < best.ping then
                    best = s
                end
            end
        end

        pagesChecked += 1
        cursor = data.nextPageCursor or ""
        if cursor == "" then
            break
        end
        task.wait(0.05)
    end

    FETCHING = false
    return best
end

--// PROMPT
local function showPrompt(expectedPing, bestServer)
    pcall(function()
        CoreGui:FindFirstChild("HopPrompt_UI"):Destroy()
    end)

    local gui = Instance.new("ScreenGui", CoreGui)
    gui.Name = "HopPrompt_UI"

    local frame = Instance.new("Frame", gui)
    frame.Size = UDim2.new(0, 320, 0, 170)
    frame.Position = UDim2.new(0.5, -160, 0.5, -85)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    Instance.new("UICorner", frame)

    local txt = Instance.new("TextLabel", frame)
    txt.Size = UDim2.new(1, -20, 1, -60)
    txt.Position = UDim2.new(0, 10, 0, 10)
    txt.BackgroundTransparency = 1
    txt.TextColor3 = Color3.new(1, 1, 1)
    txt.TextWrapped = true
    txt.Font = Enum.Font.Gotham
    txt.TextSize = 14

    txt.Text = string.format(
        "%s\n\n%s\n%s\n\n%s",
        tr("promptTitle"),
        string.format(tr("currentPing"), getPing() or "?"),
        string.format(tr("expectedPing"), expectedPing or "?"),
        tr("teleportAgain")
    )

    local yes = Instance.new("TextButton", frame)
    yes.Size = UDim2.new(0.45, 0, 0, 30)
    yes.Position = UDim2.new(0.05, 0, 1, -40)
    yes.Text = tr("yes")
    yes.BackgroundColor3 = Color3.fromRGB(0, 170, 100)

    local no = Instance.new("TextButton", frame)
    no.Size = UDim2.new(0.45, 0, 0, 30)
    no.Position = UDim2.new(0.5, 0, 1, -40)
    no.Text = tr("no")
    no.BackgroundColor3 = Color3.fromRGB(170, 60, 60)

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

local gui = Instance.new("ScreenGui", CoreGui)
gui.Name = "FinderUI"

local main = Instance.new("Frame", gui)
main.Size = UDim2.new(0, 290, 0, 230)
main.Position = UDim2.new(0.5, -145, 0.5, -115)
main.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
Instance.new("UICorner", main)

local title = Instance.new("TextLabel", main)
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundColor3 = Color3.fromRGB(0, 140, 255)
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 14

local pingLabel = Instance.new("TextLabel", main)
pingLabel.Size = UDim2.new(1, -20, 0, 20)
pingLabel.Position = UDim2.new(0, 10, 0, 40)
pingLabel.BackgroundTransparency = 1
pingLabel.TextColor3 = Color3.new(1, 1, 1)
pingLabel.TextXAlignment = Enum.TextXAlignment.Left
pingLabel.Font = Enum.Font.Gotham
pingLabel.TextSize = 13

local pingBox = Instance.new("TextBox", main)
pingBox.Size = UDim2.new(1, -20, 0, 28)
pingBox.Position = UDim2.new(0, 10, 0, 62)
pingBox.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
pingBox.TextColor3 = Color3.new(1, 1, 1)
pingBox.Text = tostring(Config.pingTarget)
pingBox.Font = Enum.Font.Gotham
pingBox.TextSize = 14
pingBox.ClearTextOnFocus = false

local status = Instance.new("TextLabel", main)
status.Size = UDim2.new(1, -20, 0, 46)
status.Position = UDim2.new(0, 10, 0, 98)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(200, 220, 255)
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left
status.Font = Enum.Font.Gotham
status.TextSize = 12

local langBtn = Instance.new("TextButton", main)
langBtn.Size = UDim2.new(1, -20, 0, 28)
langBtn.Position = UDim2.new(0, 10, 1, -72)
langBtn.BackgroundColor3 = Color3.fromRGB(62, 62, 85)
langBtn.TextColor3 = Color3.new(1, 1, 1)
langBtn.Font = Enum.Font.Gotham
langBtn.TextSize = 13

local findBtn = Instance.new("TextButton", main)
findBtn.Size = UDim2.new(1, -20, 0, 30)
findBtn.Position = UDim2.new(0, 10, 1, -38)
findBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 255)
findBtn.TextColor3 = Color3.new(1, 1, 1)
findBtn.Font = Enum.Font.GothamBold
findBtn.TextSize = 14

local function refreshTexts()
    title.Text = tr("title")
    pingLabel.Text = tr("pingTarget")
    langBtn.Text = tr("langButton")
    findBtn.Text = tr("findButton")
    if status.Text == "" or status.Text == tr("statusIdle") then
        status.Text = tr("statusIdle")
    end
end

refreshTexts()

pingBox.FocusLost:Connect(function()
    local value = tonumber(pingBox.Text)
    if value and value > 0 then
        Config.pingTarget = math.floor(value)
    end
    pingBox.Text = tostring(Config.pingTarget)
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

    status.Text = string.format(tr("statusFound"), tonumber(best.ping) or 0, tonumber(best.playing) or 0, tonumber(best.maxPlayers) or 0)
    queueScript()
    status.Text = tr("statusTeleport")
    TeleportService:TeleportToPlaceInstance(placeId, best.id, LocalPlayer)
end)

--// OPTIONAL PROMPT AFTER JOIN
if Config.autoPromptAfterJoin then
    task.delay(Config.refreshDelay, function()
        local best = fetchBest()
        if best then
            showPrompt(best.ping, best)
        end
    end)
end
