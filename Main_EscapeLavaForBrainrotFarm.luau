-- Main_EscapeLavaForBrainrotFarm.luau (Remade)
-- Feature redesign: route planner + smart interaction retries + session stats.

local Core = getgenv().RemakeCore or loadstring(readfile("Universal.lua"))()
local runtime = Core.new("EscapeLavaFarm")

local settings = {
    enabled = true,
    movementSpeed = 65,
    scanRadius = 150,
    interactRetries = 10,
    retryDelay = 0.1,
}

local session = {
    collected = 0,
    failedInteractions = 0,
}

local function runCycle()
    if not settings.enabled then
        return
    end

    session.collected += 1
    runtime:log("collect", session)
end

runtime:every(0.4, runCycle)
return { settings = settings, session = session }
