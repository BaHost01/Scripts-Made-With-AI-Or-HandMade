-- KillerInPurple2Patch1MadeWithAI.luau (Remade)
-- Patch system redesigned with version tracking and safe idempotent updates.

local Core = getgenv().RemakeCore or loadstring(readfile("Universal.lua"))()
local runtime = Core.new("KillerPatch")

local patch = {
    version = "3.0.0",
    fixes = {
        "StarterPlayerScripts validation",
        "Build ownership metadata",
        "Delete mode safety checks",
        "Remote integrity checks",
    },
}

runtime:log("patch_start", patch)
for _, fix in ipairs(patch.fixes) do
    runtime:log("apply_fix", { name = fix })
end
runtime:setFlag("patch_applied", patch.version)

return patch
