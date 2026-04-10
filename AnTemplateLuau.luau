-- AnTemplateLuau.luau (Remade)
-- Template to build new scripts quickly with standard lifecycle hooks.

local Core = getgenv().RemakeCore or loadstring(readfile("Universal.lua"))()
local runtime = Core.new("Template")

local Template = {}

function Template.init(options)
    runtime:log("init", options or {})
end

function Template.start()
    runtime:log("start")
end

function Template.stop()
    runtime:log("stop")
    runtime:destroy()
end

return Template
