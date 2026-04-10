--[[
Universal Remake Core v4
Expanded runtime for all scripts in this repository.
New features:
- command registry (:command/:run)
- event bus (:on/:emit)
- periodic tasks (:every)
- lifecycle cleanup (:destroy)
]]

local Core = {}
Core.__index = Core

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local function nowISO()
    return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

function Core.new(scriptName)
    local self = setmetatable({}, Core)
    self.name = scriptName or "UnnamedScript"
    self.startedAt = tick()
    self.flags = {}
    self.commands = {}
    self.listeners = {}
    self.metrics = {
        actions = 0,
        errors = 0,
        events = 0,
        commands = 0,
    }
    self.connections = {}
    return self
end

function Core:log(message, payload)
    self.metrics.actions += 1
    print(string.format("[%s][%s] %s", self.name, nowISO(), tostring(message)))
    if payload ~= nil then
        print("[Payload]", HttpService:JSONEncode(payload))
    end
end

function Core:warn(message)
    self.metrics.errors += 1
    warn(string.format("[%s] %s", self.name, tostring(message)))
end

function Core:setFlag(flagName, value)
    self.flags[flagName] = value
    self:log("flag_update", { flag = flagName, value = value })
end

function Core:getFlag(flagName, defaultValue)
    local v = self.flags[flagName]
    if v == nil then
        return defaultValue
    end
    return v
end

function Core:on(eventName, callback)
    self.listeners[eventName] = self.listeners[eventName] or {}
    table.insert(self.listeners[eventName], callback)
    return callback
end

function Core:emit(eventName, data)
    self.metrics.events += 1
    local group = self.listeners[eventName]
    if not group then
        return
    end

    for _, callback in ipairs(group) do
        local ok, err = pcall(callback, data)
        if not ok then
            self:warn(err)
        end
    end
end

function Core:command(name, callback)
    self.commands[name] = callback
    self:log("command_registered", { name = name })
end

function Core:run(name, payload)
    local fn = self.commands[name]
    if not fn then
        self:warn("missing command: " .. tostring(name))
        return nil
    end

    self.metrics.commands += 1
    local ok, result = pcall(fn, payload)
    if not ok then
        self:warn(result)
        return nil
    end

    return result
end

function Core:every(seconds, callback)
    local elapsed = 0
    local connection
    connection = RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed >= seconds then
            elapsed = 0
            local ok, err = pcall(callback)
            if not ok then
                self:warn(err)
            end
        end
    end)
    table.insert(self.connections, connection)
    return connection
end

function Core:health()
    return {
        uptime = math.floor(tick() - self.startedAt),
        actions = self.metrics.actions,
        errors = self.metrics.errors,
        events = self.metrics.events,
        commands = self.metrics.commands,
        flags = self.flags,
    }
end

function Core:destroy()
    for _, connection in ipairs(self.connections) do
        if connection and connection.Disconnect then
            connection:Disconnect()
        end
    end
    table.clear(self.connections)
    self:log("destroy", self:health())
end

getgenv().RemakeCore = Core
return Core
