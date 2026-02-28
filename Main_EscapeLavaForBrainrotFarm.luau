--Help: https://discord.gg/xGucmFjGVD
local s_ReplicatedStorage_0 = game:GetService("ReplicatedStorage")
local r_ItemTypes_0 = require(s_ReplicatedStorage_0.Enums.ItemTypes)
require(s_ReplicatedStorage_0.Registries.BrainrotRegistry)
require(s_ReplicatedStorage_0.Registries.LuckyBlocksRegistry)
require(s_ReplicatedStorage_0.Registries.MutationRegistry)
require(s_ReplicatedStorage_0.Registries.TraitsRegistry)
local t1 = {
	[r_ItemTypes_0.Brainrot] = {
		["Name"] = "PipiKiwi",
		["Mutation"] = "Normal",
		["Level"] = 1,
		["Traits"] = {},
		["IsFavorited"] = false,
		["Cash"] = 0
	},
	[r_ItemTypes_0.LuckyBlock] = {
		["Name"] = "LuckyBlock"
	}
}
return table.freeze(t1)
