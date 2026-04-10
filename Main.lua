-- Main.lua (Revamp)
-- Central orchestration script with command + event driven features.

local Core = getgenv().RemakeCore or loadstring(readfile("Universal.lua"))()
local runtime = Core.new("Main")

local profile = {
    autoFarm = true,
    autoCollect = true,
    safeMode = true,
    loopInterval = 0.3,
    maxTicksPerMinute = 300,
}

local tickCount = 0
local minuteWindowStarted = tick()

runtime:command("toggle", function(payload)
    if not payload or not payload.key then
        return false
    end
    profile[payload.key] = not profile[payload.key]
    runtime:emit("profile_changed", { key = payload.key, value = profile[payload.key] })
    return true
end)

runtime:on("profile_changed", function(data)
    runtime:log("profile_changed", data)
end)

runtime:every(profile.loopInterval, function()
    tickCount += 1
    if tick() - minuteWindowStarted >= 60 then
        runtime:log("minute_stats", { ticks = tickCount })
        tickCount = 0
        minuteWindowStarted = tick()
    end

    if profile.safeMode and tickCount > profile.maxTicksPerMinute then
        runtime:warn("safe mode throttled automation")
        return
    end

    if profile.autoFarm then
        runtime:emit("farm_tick", { t = tick() })
    end

    if profile.autoCollect then
        runtime:emit("collect_tick", { t = tick() })
    end
end)

runtime:setFlag("loaded", true)
return runtime
