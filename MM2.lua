-- MM2.lua (Revamp)
-- Expanded with player filtering and target priority simulation.

local Core = getgenv().RemakeCore or loadstring(readfile("Universal.lua"))()
local runtime = Core.new("MM2")

local config = {
    espEnabled = true,
    trackingInterval = 0.5,
    trackInnocents = true,
    trackSheriff = true,
    trackMurderer = true,
    roleColors = {
        Innocent = Color3.fromRGB(85, 170, 255),
        Sheriff = Color3.fromRGB(255, 220, 90),
        Murderer = Color3.fromRGB(255, 80, 80),
    },
}

local mockTargets = {
    { name = "PlayerA", role = "Innocent", danger = 0.1 },
    { name = "PlayerB", role = "Sheriff", danger = 0.4 },
    { name = "PlayerC", role = "Murderer", danger = 0.95 },
}

local function roleEnabled(role)
    if role == "Innocent" then return config.trackInnocents end
    if role == "Sheriff" then return config.trackSheriff end
    if role == "Murderer" then return config.trackMurderer end
    return false
end

local function getPriorityTarget()
    local best
    for _, target in ipairs(mockTargets) do
        if roleEnabled(target.role) then
            if not best or target.danger > best.danger then
                best = target
            end
        end
    end
    return best
end

runtime:every(config.trackingInterval, function()
    if not config.espEnabled then
        return
    end

    local top = getPriorityTarget()
    if top then
        runtime:log("target_update", top)
    end
end)

runtime:setFlag("mm2_revamp_loaded", true)
return config
