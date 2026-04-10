-- Lua.lua (Remade)
-- Redesigned as a utility-focused starter pack.

local Core = getgenv().RemakeCore or loadstring(readfile("Universal.lua"))()
local runtime = Core.new("LuaUtility")

local Utility = {}

function Utility.safeCall(fn, ...)
    local ok, result = pcall(fn, ...)
    if not ok then
        runtime:warn(result)
        return nil
    end
    return result
end

function Utility.deepCopy(tbl)
    local clone = {}
    for k, v in pairs(tbl) do
        clone[k] = type(v) == "table" and Utility.deepCopy(v) or v
    end
    return clone
end

function Utility.merge(a, b)
    local out = Utility.deepCopy(a)
    for k, v in pairs(b) do
        out[k] = v
    end
    return out
end

runtime:log("utility_ready", { functions = { "safeCall", "deepCopy", "merge" } })
return Utility
