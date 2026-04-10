-- KillerInPurple2MadeWithAI.luau (Remade)
-- Rebuilt with cleaner staged setup and configurable gameplay knobs.

local Core = getgenv().RemakeCore or loadstring(readfile("Universal.lua"))()
local runtime = Core.new("KillerInPurple2")

local config = {
    npcDifficulty = 1.15,
    policeResponseScale = 1.2,
    maxHeat = 100,
    buildLimit = 220,
    dynamicEconomy = true,
}

runtime:log("installer_start", config)

local function setupWorld()
    runtime:log("setup_world")
end

local function setupNPCs()
    runtime:log("setup_npcs", { difficulty = config.npcDifficulty })
end

local function setupSystems()
    runtime:log("setup_systems", {
        police = config.policeResponseScale,
        economy = config.dynamicEconomy,
    })
end

setupWorld()
setupNPCs()
setupSystems()
runtime:setFlag("installed", true)
