local placeid = game.PlaceId
local PLACE_AUTOFARM = 119987266683883
local PLACE_AIMBOT_ONE = 72920620366355
local PLACE_AIMBOT_TWO = 136801880565837

if placeid == PLACE_AUTOFARM then
    --// ============================================================
--//   AutoFarm v5 — Obsidian UI Edition
--//   Uses: https://github.com/deividcomsono/Obsidian
--// ============================================================

--// SERVICES
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer

--// ============================================================
--// LOAD OBSIDIAN LIBRARY
--// ============================================================
local repo         = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library      = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager  = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

--// ============================================================
--// EXECUTOR CAPABILITY DETECTION
--// ============================================================
--[[
    ┌─────────────────────────────────────────────────────────────┐
    │  HOW PROXIMITYPROMPT HOLDING WORKS                          │
    │                                                             │
    │  For HoldDuration > 0, the server expects this sequence:   │
    │    1. ButtonHoldBegan fires                                 │
    │    2. Player stays in range for full HoldDuration           │
    │    3. ButtonHoldEnded + Triggered fires                     │
    │                                                             │
    │  fireproximityprompt alone sends only a single trigger      │
    │  event — the server ignores it for hold prompts.            │
    ├─────────────────────────────────────────────────────────────┤
    │  EXECUTOR SUPPORT TIERS                                     │
    │                                                             │
    │  TIER 1 — holdproximityprompt(prompt) available             │
    │    Synapse X, Solara, Wave, Script-Ware                     │
    │    → Single call. Cleanest, most reliable.                  │
    │                                                             │
    │  TIER 2 — Only fireproximityprompt available (~75% UNC)     │
    │    Xeno, KRNL, Fluxus, most free executors                  │
    │    → Loop spam + constant re-land on the part               │
    │      This works because repeated fire calls in a tight      │
    │      loop approximate the hold sequence server-side.        │
    │      We re-teleport onto the part every 0.15s to prevent   │
    │      drift outside MaxActivationDistance mid-hold.          │
    │      Buffer = HoldDuration + 0.5s for Xeno's jitter.       │
    └─────────────────────────────────────────────────────────────┘
]]

-- Tier 1 detection: native hold function
local HAS_HOLD_FIRE = typeof(holdproximityprompt) == "function"

-- Try to identify which executor we're on for better logging
local EXECUTOR_NAME = (function()
    if syn then return "Synapse X"
    elseif KRNL_LOADED then return "KRNL"
    elseif identifyexecutor then
        local ok, name = pcall(identifyexecutor)
        if ok and name then return name end
    elseif getexecutorname then
        local ok, name = pcall(getexecutorname)
        if ok and name then return name end
    end
    return "Unknown"
end)()

print("[AutoFarm v5] Executor:", EXECUTOR_NAME)
print("[AutoFarm v5] holdproximityprompt:", HAS_HOLD_FIRE and "YES (Tier 1)" or "NO (Tier 2 loop fallback)")

--// ============================================================
--// DEFAULTS
--// ============================================================
local DEFAULTS = {
    FlySpeed      = 60,
    FlyHeight     = 35,
    MaxRange      = 9999,
    LoopDelay     = 0.2,
    InteractTries = 8,
    InteractDelay = 0.08,
    LandOffset    = 2,
    ManualScanRadius = 20, -- studs to scan for manual interact
    RespawnBoostTime = 8,
    RespawnLoopDelay = 0.05,
}

--// ============================================================
--// STATE
--// ============================================================
local State = {
    Endpoint         = nil,
    SelectedRarities = {},
    FarmedCount      = 0,
    Running          = false,
    Log              = {},
    -- Manual interact
    NearbyPrompt     = nil, -- closest ProximityPrompt to player right now
    ManualHolding    = false,
    ForceNextCycle   = false,
    RespawnBoostUntil = 0,
}

--// ============================================================
--// BRAINROTS FOLDER + RARITY LIST
--// ============================================================
local brainrotsFolder = nil
local rarityList      = {}

pcall(function()
    brainrotsFolder = workspace:WaitForChild("GameFolder", 10)
        :WaitForChild("Brainrots", 10)
end)

if brainrotsFolder then
    for _, child in ipairs(brainrotsFolder:GetChildren()) do
        if child:IsA("Folder") or child:IsA("Model") then
            table.insert(rarityList, child.Name)
        end
    end
    table.sort(rarityList)
else
    rarityList = { "Secret", "Divine", "Celestial", "Legendary", "Epic" }
    warn("[AutoFarm] Brainrots folder not found — using fallback rarity list.")
end

--// ============================================================
--// WINDOW
--// ============================================================
local Window = Library:CreateWindow({
    Title            = "AutoFarm v5",
    Footer           = "github.com/deividcomsono/Obsidian",
    ShowCustomCursor = true,
    NotifySide       = "Right",
    AutoShow         = true,
})

local Tabs = {
    Farm    = Window:AddTab("Farm",    "crosshair"),
    Manual  = Window:AddTab("Manual",  "hand"),
    Settings = Window:AddTab("Settings","sliders-horizontal"),
    UISettings = Window:AddTab("UI Settings","settings"),
}

--// ============================================================
--// ══════════════════  FARM TAB  ═══════════════════════════
--// ============================================================

--// LEFT: Controls
local ControlBox = Tabs.Farm:AddLeftGroupbox("Controls", "play")

ControlBox:AddToggle("AutoFarm", {
    Text    = "Auto Farm",
    Default = false,
    Risky   = true,
    Tooltip = "Starts the automated farm loop for selected rarities",
})

ControlBox:AddToggle("FastReacquire", {
    Text    = "Fast Reacquire (respawn/spawn)",
    Default = true,
    Tooltip = "When you respawn or a brainrot appears, force a quick cycle so targets are detected faster.",
})

ControlBox:AddToggle("AutoTeleport", {
    Text    = "Teleport Mode",
    Default = false,
    Tooltip = "Instantly teleport instead of flying — faster but more detectable",
})

ControlBox:AddToggle("AutoReturn", {
    Text    = "Auto Return",
    Default = true,
    Tooltip = "Return to Endpoint after each collect. Disable to stay at target.",
})

ControlBox:AddDivider()

ControlBox:AddButton({
    Text    = "Set Endpoint",
    Tooltip = "Save your current position as the return point after each collect",
    Func = function()
        local char = player.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            State.Endpoint = char.HumanoidRootPart.CFrame
            Library:Notify({ Title = "Endpoint Saved", Description = "Return point locked.", Time = 3 })
        else
            Library:Notify({ Title = "Error", Description = "No character found.", Time = 3 })
        end
    end,
})

ControlBox:AddButton({
    Text    = "Collect Once",
    Tooltip = "Run one single farm cycle right now",
    Func = function()
        if State.Running then
            Library:Notify({ Title = "Busy", Description = "Already running a cycle.", Time = 2 })
            return
        end
        task.spawn(function()
            State.Running = true
            pcall(_G.AF_SingleCycle)
            State.Running = false
        end)
    end,
})

ControlBox:AddDivider()

ControlBox:AddDropdown("TargetRarities", {
    Text       = "Target Rarities",
    Tooltip    = "Select which rarities to farm. Ordered by the folder's natural priority.",
    Values     = rarityList,
    Default    = rarityList[1] or "Secret",
    Multi      = true,
    Searchable = #rarityList > 5,
})

Options.TargetRarities:OnChanged(function()
    State.SelectedRarities = {}
    for rarity, enabled in pairs(Options.TargetRarities.Value) do
        if enabled then table.insert(State.SelectedRarities, rarity) end
    end
end)

--// LEFT: Live Status
local StatusBox = Tabs.Farm:AddLeftGroupbox("Live Status", "activity")

local LblStatus  = StatusBox:AddLabel("Idle", true)
local LblTarget  = StatusBox:AddLabel("Target: None", true)
local LblCount   = StatusBox:AddLabel("Farmed this session: 0", true)
local LblDist    = StatusBox:AddLabel("Last dist: -", true)
local LblPrompts = StatusBox:AddLabel("Prompts fired: -", true)
local LblHoldCap = StatusBox:AddLabel(
    string.format("Executor: %s | Hold: %s",
        EXECUTOR_NAME,
        HAS_HOLD_FIRE and "Tier 1 (native)" or "Tier 2 (loop)"
    ), true
)

--// RIGHT: Interact Debug
local DebugBox = Tabs.Farm:AddRightGroupbox("Interact Debug", "terminal")

local LblDbgMode  = DebugBox:AddLabel("Mode: -", true)
local LblDbgHold  = DebugBox:AddLabel("Hold: -", true)
local LblDbgActiv = DebugBox:AddLabel("ActivDist: -", true)
local LblDbgFound = DebugBox:AddLabel("Prompts found: -", true)

DebugBox:AddDivider()
DebugBox:AddLabel("Recent Log", false)

local LogLabels = {}
for i = 1, 6 do
    LogLabels[i] = DebugBox:AddLabel("-", true)
end

DebugBox:AddButton({
    Text = "Clear Log",
    Func = function()
        State.Log = {}
        for i = 1, 6 do pcall(function() LogLabels[i]:SetText("-") end) end
    end,
})

--// RIGHT: Loaded Rarities
local RarityBox = Tabs.Farm:AddRightGroupbox("Loaded Rarities", "list")

if #rarityList > 0 then
    for _, r in ipairs(rarityList) do RarityBox:AddLabel(r, false) end
else
    RarityBox:AddLabel("None found — check GameFolder/Brainrots path", true)
end

--// ============================================================
--// ══════════════════  MANUAL TAB  ═════════════════════════
--// ============================================================
--[[
    Manual Interact lets the user interact with nearby prompts themselves
    via a keybind. The script scans for the nearest ProximityPrompt within
    ManualScanRadius studs and fires / holds it when the key is pressed.
    This is useful for testing, or just playing normally while having the
    script handle the boring hold timing for you.
]]

--// LEFT: Manual Interact
local ManualBox = Tabs.Manual:AddLeftGroupbox("Manual Interact", "hand")

ManualBox:AddLabel(
    "Press your keybind near any brainrot to interact.\n" ..
    "Works with both instant and hold prompts automatically.",
    true
)

ManualBox:AddDivider()

-- The keybind the user presses to manually interact
ManualBox:AddLabel("Interact Keybind"):AddKeyPicker("ManualInteractKey", {
    Default          = "E",
    Mode             = "Press",
    Text             = "Manual Interact",
    Tooltip          = "Press this key when near a target to interact with its prompt",
    WaitForCallback  = false,
    Callback = function()
        if State.ManualHolding then return end -- already interacting
        local prompt = State.NearbyPrompt
        if not prompt or not prompt.Enabled then
            Library:Notify({ Title = "No Prompt", Description = "No interactable prompt nearby.", Time = 2 })
            return
        end
        task.spawn(function()
            State.ManualHolding = true
            pcall(_G.AF_FirePrompt, prompt)
            State.ManualHolding = false
        end)
    end,
})

ManualBox:AddDivider()

ManualBox:AddSlider("ManualScanRadius", {
    Text    = "Scan Radius",
    Default = DEFAULTS.ManualScanRadius,
    Min     = 5,
    Max     = 60,
    Rounding = 0,
    Suffix  = " st",
    Tooltip = "How far to scan for nearby prompts for manual interact",
})

--// LEFT: Nearby Prompt Info (updated by RunService loop)
local NearbyBox = Tabs.Manual:AddLeftGroupbox("Nearby Prompt", "radar")

local LblNearName   = NearbyBox:AddLabel("Name: scanning...", true)
local LblNearDist   = NearbyBox:AddLabel("Distance: -", true)
local LblNearHold   = NearbyBox:AddLabel("Hold Duration: -", true)
local LblNearActiv  = NearbyBox:AddLabel("Max Activ Dist: -", true)
local LblNearStatus = NearbyBox:AddLabel("Status: -", true)

--// RIGHT: Manual Log
local ManualLogBox = Tabs.Manual:AddRightGroupbox("Manual Log", "scroll-text")

local ManualLogLabels = {}
for i = 1, 8 do
    ManualLogLabels[i] = ManualLogBox:AddLabel("-", true)
end

local manualLog = {}
local function pushManualLog(msg)
    table.insert(manualLog, 1, msg)
    if #manualLog > 8 then table.remove(manualLog) end
    for i, entry in ipairs(manualLog) do
        pcall(function() ManualLogLabels[i]:SetText(entry) end)
    end
end

ManualLogBox:AddButton({
    Text = "Clear",
    Func = function()
        manualLog = {}
        for i = 1, 8 do pcall(function() ManualLogLabels[i]:SetText("-") end) end
    end,
})

--// RIGHT: Nearby Prompt List (top 5 closest)
local ScanListBox = Tabs.Manual:AddRightGroupbox("Closest Prompts (top 5)", "list")

local ScanListLabels = {}
for i = 1, 5 do
    ScanListLabels[i] = ScanListBox:AddLabel("-", true)
end

--// ============================================================
--// ══════════════════  SETTINGS TAB  ═══════════════════════
--// ============================================================

local FlyBox = Tabs.Settings:AddLeftGroupbox("Movement", "navigation")

FlyBox:AddSlider("FlySpeed", {
    Text = "Fly Speed", Default = DEFAULTS.FlySpeed,
    Min = 10, Max = 400, Rounding = 0, Suffix = " st/s",
    Tooltip = "Speed while flying to a target",
})

FlyBox:AddSlider("FlyHeight", {
    Text = "Fly Height", Default = DEFAULTS.FlyHeight,
    Min = 5, Max = 120, Rounding = 0, Suffix = " st",
    Tooltip = "Height to travel at to avoid terrain collisions",
})

FlyBox:AddSlider("LandOffset", {
    Text = "Land Offset", Default = DEFAULTS.LandOffset,
    Min = 0, Max = 10, Rounding = 0, Suffix = " st",
    Tooltip = "Height above the prompt part when landing. Keep at 0-3 so you're within activation range.",
})

FlyBox:AddSlider("MaxRange", {
    Text = "Max Target Range", Default = DEFAULTS.MaxRange,
    Min = 50, Max = 9999, Rounding = 0, Suffix = " st",
    Tooltip = "Ignore targets farther than this",
})

local InteractBox = Tabs.Settings:AddRightGroupbox("Interaction", "mouse-pointer")

InteractBox:AddLabel(
    string.format(
        "Executor: %s\n%s",
        EXECUTOR_NAME,
        HAS_HOLD_FIRE
            and "Tier 1 — native holdproximityprompt.\nHold prompts: single call."
            or  "Tier 2 — loop fallback mode.\nXeno/KRNL/Fluxus: fires every 0.06s\nfor HoldDuration + 0.5s buffer,\nre-landing every 0.15s."
    ), true
)

InteractBox:AddDivider()

InteractBox:AddToggle("UseHoldFire", {
    Text    = "Handle Hold Prompts",
    Default = true,
    Tooltip = "Properly complete hold prompts (HoldDuration > 0). Uses native holdproximityprompt if available, otherwise fires in a tight loop.",
})

InteractBox:AddToggle("SearchNearby", {
    Text    = "Fallback: Nearby Scan",
    Default = true,
    Tooltip = "If no prompts found inside the target model, fall back to scanning nearby workspace within activation radius.",
})

InteractBox:AddDivider()

InteractBox:AddSlider("InteractTries", {
    Text = "Instant Fire Attempts", Default = DEFAULTS.InteractTries,
    Min = 1, Max = 20, Rounding = 0,
    Tooltip = "For instant prompts: how many times to call fireproximityprompt",
})

InteractBox:AddSlider("InteractDelay", {
    Text = "Fire Delay", Default = DEFAULTS.InteractDelay,
    Min = 0.02, Max = 1, Rounding = 2, Suffix = "s",
    Tooltip = "Delay between each fire attempt for instant prompts",
})

InteractBox:AddSlider("LoopDelay", {
    Text = "Loop Delay", Default = DEFAULTS.LoopDelay,
    Min = 0.05, Max = 5, Rounding = 2, Suffix = "s",
    Tooltip = "Pause between full farm cycles",
})

InteractBox:AddSlider("RespawnBoostTime", {
    Text = "Respawn Boost Time", Default = DEFAULTS.RespawnBoostTime,
    Min = 0, Max = 20, Rounding = 0, Suffix = "s",
    Tooltip = "How long to keep fast checks active after respawn or fresh brainrot spawn",
})

InteractBox:AddSlider("RespawnLoopDelay", {
    Text = "Boost Loop Delay", Default = DEFAULTS.RespawnLoopDelay,
    Min = 0.02, Max = 0.5, Rounding = 2, Suffix = "s",
    Tooltip = "Temporary loop delay used while boost window is active",
})

InteractBox:AddDivider()

InteractBox:AddToggle("NotifyOnFarm", {
    Text = "Notify on each farm", Default = false,
})

InteractBox:AddToggle("NotifyOnError", {
    Text = "Notify on errors", Default = true,
})

--// ============================================================
--// ══════════════  UI SETTINGS TAB  ════════════════════════
--// ============================================================

local MenuGroup = Tabs.UISettings:AddLeftGroupbox("Menu", "wrench")

MenuGroup:AddToggle("KeybindMenuOpen", {
    Default = Library.KeybindFrame.Visible, Text = "Show Keybind Menu",
    Callback = function(v) Library.KeybindFrame.Visible = v end,
})
MenuGroup:AddToggle("ShowCustomCursor", {
    Text = "Custom Cursor", Default = true,
    Callback = function(v) Library.ShowCustomCursor = v end,
})
MenuGroup:AddDropdown("NotifSide", {
    Values = {"Left","Right"}, Default = "Right", Text = "Notify Side",
    Callback = function(v) Library:SetNotifySide(v) end,
})
MenuGroup:AddDropdown("DPIScale", {
    Values = {"50%","75%","100%","125%","150%","175%","200%"},
    Default = "100%", Text = "DPI Scale",
    Callback = function(v) Library:SetDPIScale(tonumber((v:gsub("%%","")))) end,
})
MenuGroup:AddDivider()
MenuGroup:AddLabel("Menu Keybind")
    :AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })
MenuGroup:AddButton("Unload", function() Library:Unload() end)
Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
ThemeManager:SetFolder("AutoFarmV5")
SaveManager:SetFolder("AutoFarmV5/brainrots")
SaveManager:BuildConfigSection(Tabs.UISettings)
ThemeManager:ApplyToTab(Tabs.UISettings)
SaveManager:LoadAutoloadConfig()

--// ============================================================
--// RUNTIME HELPERS
--// ============================================================
local function getCfg()
    return {
        FlySpeed      = Options.FlySpeed.Value,
        FlyHeight     = Options.FlyHeight.Value,
        LandOffset    = Options.LandOffset.Value,
        MaxRange      = Options.MaxRange.Value,
        LoopDelay     = Options.LoopDelay.Value,
        InteractTries = Options.InteractTries.Value,
        InteractDelay = Options.InteractDelay.Value,
        ManualRadius  = Options.ManualScanRadius.Value,
        RespawnBoostTime = Options.RespawnBoostTime.Value,
        RespawnLoopDelay = Options.RespawnLoopDelay.Value,
    }
end

local function setStatus(text)
    pcall(function() LblStatus:SetText(text) end)
end

local function pushLog(msg)
    table.insert(State.Log, 1, msg)
    if #State.Log > 6 then table.remove(State.Log) end
    for i, entry in ipairs(State.Log) do
        pcall(function() LogLabels[i]:SetText(entry) end)
    end
end

--// ============================================================
--// GET NEAREST TARGET (farm)
--// ============================================================
local function getNearest()
    if not brainrotsFolder then return nil end
    local char = player.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local ordered = {}
    for _, child in ipairs(brainrotsFolder:GetChildren()) do
        for _, r in ipairs(State.SelectedRarities) do
            if child.Name == r then table.insert(ordered, child.Name); break end
        end
    end

    local c = getCfg()
    for _, rarity in ipairs(ordered) do
        local folder = brainrotsFolder:FindFirstChild(rarity)
        if folder then
            local best, bestDist = nil, c.MaxRange
            for _, v in ipairs(folder:GetChildren()) do
                if v:IsA("Model") then
                    local part = v:FindFirstChild("RootPart") or v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart")
                    if part then
                        local d = (hrp.Position - part.Position).Magnitude
                        if d < bestDist then bestDist, best = d, v end
                    end
                end
            end
            if best then return best, rarity, math.floor(bestDist) end
        end
    end
end

--// ============================================================
--// FLY + MOVE
--// ============================================================
local function flyTo(destCF, h)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local c    = getCfg()
    local dest = destCF.Position + Vector3.new(0, h or c.FlyHeight, 0)

    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e5,1e5,1e5)
    bv.Velocity = Vector3.zero
    bv.Parent   = hrp

    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(1e5,1e5,1e5)
    bg.D         = 60
    bg.CFrame    = hrp.CFrame
    bg.Parent    = hrp

    local timeout = 0
    while hrp and hrp.Parent and (hrp.Position - dest).Magnitude > 3 do
        bv.Velocity = (dest - hrp.Position).Unit * c.FlySpeed
        bg.CFrame   = CFrame.new(hrp.Position, dest)
        timeout    += task.wait()
        if timeout > 18 then break end
    end

    pcall(function() bv:Destroy() end)
    pcall(function() bg:Destroy() end)
end

local function moveTo(cf, h)
    local c = getCfg()
    if Toggles.AutoTeleport.Value then
        pcall(function() player.Character:PivotTo(cf + Vector3.new(0, h or c.FlyHeight, 0)) end)
    else
        flyTo(cf, h)
    end
end

--// ============================================================
--// ══════════════  PROMPT FIRE ENGINE  ═════════════════════
--//
--//  ProximityPrompts with HoldDuration > 0 require a proper
--//  hold sequence. Two methods are tried:
--//
--//  METHOD A — holdproximityprompt(prompt)
--//    Some executors expose this built-in. It properly simulates
--//    the full ButtonHoldBegan → hold → ButtonHoldEnded + Triggered
--//    sequence on the server. Single call, reliable.
--//    Detected at load: HAS_HOLD_FIRE = ` .. tostring(HAS_HOLD_FIRE) .. `
--//
--//  METHOD B — fireproximityprompt loop (fallback)
--//    Repeatedly calls fireproximityprompt every ~0.06s for
--//    (HoldDuration + 0.4s). Less reliable but works on most
--//    executors that don't expose the native hold function.
--//    The extra 0.4s buffer compensates for network jitter.
--//
--//  Instant prompts (HoldDuration == 0):
--//    A single fireproximityprompt call is sufficient.
--//    We retry InteractTries times with InteractDelay spacing
--//    in case the first fires hit a cooldown window.
--// ============================================================

-- Land the player right next to the prompt part so they are inside
-- MaxActivationDistance before the prompt is fired.
local function landNearPrompt(prompt)
    local part = prompt.Parent
    if not (part and part:IsA("BasePart")) then return end
    local c = getCfg()
    pcall(function()
        player.Character:PivotTo(
            CFrame.new(part.Position + Vector3.new(0, c.LandOffset, 0))
        )
    end)
    task.wait(0.04)
end

-- Core: fire a single prompt correctly based on its type and executor tier.
-- Exported to _G so the manual keybind can also call it.
function _G.AF_FirePrompt(prompt)
    if not prompt or not prompt.Enabled then return end

    local holdDur = prompt.HoldDuration or 0

    -- Always land before firing (ensures we're within activation range)
    landNearPrompt(prompt)

    -- Update debug labels
    pcall(function()
        LblDbgHold:SetText("Hold: " .. (holdDur > 0 and holdDur.."s" or "instant"))
        LblDbgActiv:SetText("ActivDist: " .. prompt.MaxActivationDistance .. " st")
    end)

    if holdDur > 0 and Toggles.UseHoldFire.Value then

        if HAS_HOLD_FIRE then
            -- ── TIER 1: native holdproximityprompt ──────────────────────
            -- (Synapse X, Solara, Wave, Script-Ware)
            -- Single call, handles the full ButtonHoldBegan→Triggered sequence.
            pcall(holdproximityprompt, prompt)

        else
            -- ── TIER 2: loop fallback (Xeno, KRNL, Fluxus, etc.) ────────
            --
            -- Strategy for Xeno / partial-UNC executors:
            --   1. Re-land on the part every 0.15s so we never drift outside
            --      MaxActivationDistance mid-hold (Xeno's physics tick can move
            --      the character slightly between fires).
            --   2. Fire every 0.06s — tight enough to keep the server's hold
            --      timer ticking without overwhelming the remote event rate limit.
            --   3. Add 0.5s buffer on top of HoldDuration to absorb Xeno's
            --      larger network jitter compared to paid executors.
            --   4. After the loop, fire once more immediately to ensure the
            --      final Triggered event fires cleanly.
            --
            local elapsed    = 0
            local needed     = holdDur + 0.5   -- 0.5s buffer for Xeno jitter
            local relandEvery = 0.15

            while elapsed < needed do
                pcall(fireproximityprompt, prompt)

                -- Periodic re-land to stay inside activation distance
                if elapsed % relandEvery < 0.06 then
                    landNearPrompt(prompt)
                end

                elapsed += task.wait(0.06)
            end

            -- Final fire to ensure server registers the Triggered event
            landNearPrompt(prompt)
            pcall(fireproximityprompt, prompt)
            task.wait(0.1)
        end

    else
        -- ── Instant prompt (HoldDuration == 0) ──────────────────────────
        -- Works on all executors — fire N times with small delay.
        local c = getCfg()
        for _ = 1, c.InteractTries do
            pcall(fireproximityprompt, prompt)
            task.wait(c.InteractDelay)
        end
    end
end

-- Collect all prompts for a given target model, with workspace fallback
local function getPromptsForTarget(targetModel)
    local prompts = {}

    for _, v in ipairs(targetModel:GetDescendants()) do
        if v:IsA("ProximityPrompt") and v.Enabled then
            table.insert(prompts, v)
        end
    end

    if #prompts == 0 and Toggles.SearchNearby.Value then
        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            for _, v in ipairs(workspace:GetDescendants()) do
                if v:IsA("ProximityPrompt") and v.Enabled then
                    local part = v.Parent
                    if part and part:IsA("BasePart") then
                        if (hrp.Position - part.Position).Magnitude <= v.MaxActivationDistance then
                            table.insert(prompts, v)
                        end
                    end
                end
            end
        end
    end

    return prompts
end

-- Interact with all prompts on a target model, return count fired
local function tryInteract(targetModel)
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return 0 end

    local prompts = getPromptsForTarget(targetModel)
    local fired   = 0

    pcall(function()
        LblDbgMode:SetText("Mode: " .. (Toggles.AutoTeleport.Value and "Teleport" or "Fly"))
        LblDbgFound:SetText("Prompts found: " .. #prompts)
    end)

    if #prompts == 0 then
        pushLog("No prompts: " .. targetModel.Name)
        return 0
    end

    for _, prompt in ipairs(prompts) do
        pcall(function()
            _G.AF_FirePrompt(prompt)
            fired += 1
        end)
    end

    return fired
end

--// ============================================================
--// SINGLE FARM CYCLE
--// ============================================================
function _G.AF_SingleCycle()
    if not State.Endpoint then
        setStatus("Set an Endpoint first!")
        return
    end
    if #State.SelectedRarities == 0 then
        setStatus("Select at least one rarity!")
        return
    end

    local target, rarity, dist = getNearest()
    if not target then
        setStatus("No targets in range")
        pcall(function() LblTarget:SetText("Target: None") end)
        return
    end

    local part = target:FindFirstChild("RootPart") or target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
    if not part then
        pushLog("No part on " .. target.Name)
        return
    end

    local displayName = string.format("[%s] %s  %d st", rarity, target.Name, dist)
    pcall(function()
        LblTarget:SetText(displayName)
        LblDist:SetText("Last dist: " .. dist .. " st")
    end)

    setStatus("Moving...")
    moveTo(part.CFrame, getCfg().FlyHeight)

    setStatus("Interacting...")
    local fired = tryInteract(target)
    pcall(function() LblPrompts:SetText("Prompts fired: " .. fired) end)

    task.wait(0.3)

    State.FarmedCount += 1
    pcall(function() LblCount:SetText("Farmed this session: " .. State.FarmedCount) end)
    pushLog(string.format("[%s] %s", rarity, target.Name))

    if Toggles.NotifyOnFarm.Value then
        Library:Notify({ Title = "Collected!", Description = displayName, Time = 2 })
    end

    if Toggles.AutoReturn.Value then
        setStatus("Returning...")
        moveTo(State.Endpoint, getCfg().FlyHeight)
    end

    setStatus("Ready")
end

local function queueFastCycle(reason)
    if not Toggles.FastReacquire.Value then return end
    State.ForceNextCycle = true
    local c = getCfg()
    if c.RespawnBoostTime > 0 then
        State.RespawnBoostUntil = math.max(State.RespawnBoostUntil, os.clock() + c.RespawnBoostTime)
    end
    if reason then pushLog("Fast scan: " .. reason) end
end

player.CharacterAdded:Connect(function(char)
    queueFastCycle("respawn")
    setStatus("Respawned - reacquiring targets")
    task.spawn(function()
        local hrp = char:WaitForChild("HumanoidRootPart", 6)
        if hrp and not State.Endpoint then
            State.Endpoint = hrp.CFrame
            pushLog("Endpoint auto-set after respawn")
        end
    end)
end)

if brainrotsFolder then
    brainrotsFolder.DescendantAdded:Connect(function(desc)
        if desc:IsA("Model") then
            queueFastCycle("brainrot spawned")
        end
    end)
end

--// ============================================================
--// MAIN FARM LOOP
--// ============================================================
task.spawn(function()
    while true do
        local baseDelay = Options.LoopDelay and Options.LoopDelay.Value or 0.2
        local delay = baseDelay
        if os.clock() < State.RespawnBoostUntil then
            delay = math.min(baseDelay, Options.RespawnLoopDelay and Options.RespawnLoopDelay.Value or 0.05)
        end
        if State.ForceNextCycle then
            delay = 0.03
            State.ForceNextCycle = false
        end
        task.wait(delay)

        if not Toggles.AutoFarm.Value then
            setStatus("Idle")
            State.Running = false
            continue
        end

        if State.Running then continue end
        State.Running = true

        local ok, err = pcall(_G.AF_SingleCycle)
        State.Running = false

        if not ok then
            local msg = tostring(err):sub(1, 70)
            setStatus("Error: " .. msg)
            pushLog("ERR: " .. msg)
            if Toggles.NotifyOnError.Value then
                Library:Notify({ Title = "AutoFarm Error", Description = msg, Time = 4 })
            end
            task.wait(1)
        end
    end
end)

--// ============================================================
--// PROXIMITY PROMPT CACHE
--// Tracks prompts once and updates the cache incrementally so
--// manual scans don't walk the entire workspace each tick.
--// ============================================================
local trackedPrompts = {}

local function trackPrompt(instance)
    if instance:IsA("ProximityPrompt") then
        trackedPrompts[instance] = true
    end
end

local function untrackPrompt(instance)
    if instance:IsA("ProximityPrompt") then
        trackedPrompts[instance] = nil
    end
end

for _, desc in ipairs(workspace:GetDescendants()) do
    trackPrompt(desc)
end

workspace.DescendantAdded:Connect(trackPrompt)
workspace.DescendantRemoving:Connect(untrackPrompt)
ProximityPromptService.PromptShown:Connect(trackPrompt)

--// ============================================================
--// MANUAL INTERACT — NEARBY PROMPT SCANNER (RunService)
--// Updates the Manual tab's nearby prompt info every 0.25s
--// and keeps State.NearbyPrompt up to date for the keybind.
--// ============================================================
local scanClock = 0

RunService.Heartbeat:Connect(function(dt)
    scanClock += dt
    if scanClock < 0.25 then return end
    scanClock = 0

    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local c = getCfg()
    local radius = c.ManualRadius

    -- Collect all enabled prompts within scan radius, sorted by distance
    local found = {}
    for prompt in pairs(trackedPrompts) do
        if not prompt.Parent then
            trackedPrompts[prompt] = nil
        elseif prompt.Enabled then
            local part = prompt.Parent
            if part and part:IsA("BasePart") then
                local d = (hrp.Position - part.Position).Magnitude
                if d <= radius then
                    table.insert(found, { prompt = prompt, dist = d })
                end
            end
        end
    end

    table.sort(found, function(a, b) return a.dist < b.dist end)

    -- Update State.NearbyPrompt
    State.NearbyPrompt = found[1] and found[1].prompt or nil

    -- Update nearby labels (closest)
    if State.NearbyPrompt then
        local p    = State.NearbyPrompt
        local part = p.Parent
        local d    = found[1].dist
        pcall(function()
            LblNearName:SetText("Name: " .. (part and part.Name or "?"))
            LblNearDist:SetText("Distance: " .. math.floor(d) .. " st")
            LblNearHold:SetText("Hold Duration: " .. (p.HoldDuration > 0 and p.HoldDuration.."s" or "instant"))
            LblNearActiv:SetText("Max Activ Dist: " .. p.MaxActivationDistance .. " st")
            LblNearStatus:SetText(State.ManualHolding and ">> Interacting..." or "Ready (press keybind)")
        end)
    else
        pcall(function()
            LblNearName:SetText("Name: none in range")
            LblNearDist:SetText("Distance: -")
            LblNearHold:SetText("Hold Duration: -")
            LblNearActiv:SetText("Max Activ Dist: -")
            LblNearStatus:SetText("Move closer to a brainrot")
        end)
    end

    -- Update top-5 list
    for i = 1, 5 do
        local entry = found[i]
        pcall(function()
            if entry then
                local part = entry.prompt.Parent
                ScanListLabels[i]:SetText(string.format(
                    "%d. %s  (%.0f st | hold: %s)",
                    i,
                    part and part.Name or "?",
                    entry.dist,
                    entry.prompt.HoldDuration > 0 and entry.prompt.HoldDuration.."s" or "instant"
                ))
            else
                ScanListLabels[i]:SetText("-")
            end
        end)
    end
end)

-- Log manual interact events
Options.ManualInteractKey:OnClick(function()
    local p = State.NearbyPrompt
    if p then
        pushManualLog(string.format("Manual: %s (hold: %s)", 
            p.Parent and p.Parent.Name or "?",
            p.HoldDuration > 0 and p.HoldDuration.."s" or "instant"
        ))
    end
end)

--// ============================================================
--// UNLOAD CLEANUP
--// ============================================================
Library:OnUnload(function()
    Toggles.AutoFarm:SetValue(false)
    State.Running       = false
    State.ManualHolding = false
    _G.AF_SingleCycle   = nil
    _G.AF_FirePrompt    = nil
    print("[AutoFarm v5] Unloaded cleanly.")
end)

print("[AutoFarm v5] Loaded.")
print("  holdproximityprompt available:", HAS_HOLD_FIRE)
print("  Rarities detected:", table.concat(rarityList, ", "))
print("  Menu: RightShift | Manual interact key: E (rebindable)")
elseif placeid == PLACE_AIMBOT_ONE or placeid == PLACE_AIMBOT_TWO then
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
else
    warn("[Universal] This place is not configured:", placeid)
end
