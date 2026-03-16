--[[
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   ██╗  ██╗███╗   ███╗ ██████╗██╗     ██╗██████╗              ║
║   ╚██╗██╔╝████╗ ████║██╔════╝██║     ██║██╔══██╗             ║
║    ╚███╔╝ ██╔████╔██║██║     ██║     ██║██████╔╝             ║
║    ██╔██╗ ██║╚██╔╝██║██║     ██║     ██║██╔══██╗             ║
║   ██╔╝ ██╗██║ ╚═╝ ██║╚██████╗███████╗██║██████╔╝             ║
║   ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝╚══════╝╚═╝╚═════╝             ║
║                                                               ║
║   v2.1.0  ·  Memory-Safe · Touch-Ready · Dynamic ZIndex      ║
║   Executor & LocalScript compatible                           ║
╚═══════════════════════════════════════════════════════════════╝

    CHANGELOG v2.1.0
    ─────────────────────────────────────────────────────────────
    [FIX] Memory leaks — all UserInputService global connections
          are now stored in element._connections and cleanly
          Disconnect()ed when :Destroy() is called.

    [FIX] Mobile / Touch support — Slider, Dropdown and the
          Drag module now handle Enum.UserInputType.Touch
          alongside mouse events everywhere.

    [FIX] Dynamic ZIndex — panels and notifications no longer
          use hardcoded ZIndex values. Every window is assigned
          a base ZIndex tier; all children and floating panels
          are computed relative to it, preventing conflicts when
          multiple windows or external UI systems coexist.
    ─────────────────────────────────────────────────────────────
--]]

-- ================================================================
-- SERVICES
-- ================================================================
local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")
local Version = "0.1"

-- Badge map: Badge["BadgeName"] == true means this badge can be granted.
local Badge = {
    ExampleBadge = true,
}

local signals = {}

-- Simple custom signal registry helper.
-- action supports: "newsignal"/"newcall", "firesignal"/"runsignal", "onsignal"/"onsignalevent".
local function CustomSignal(name, params, action)
    if type(name) ~= "string" or name == "" then return nil end

    local normalizedAction = string.lower(tostring(action or ""))

    if normalizedAction == "newsignal" or normalizedAction == "newcall" then
        signals[name] = signals[name] or {}
        return signals[name]
    elseif normalizedAction == "firesignal" or normalizedAction == "runsignal" then
        local listeners = signals[name]
        if not listeners then return nil end

        for _, callback in ipairs(listeners) do
            local ok, err = pcall(callback, params)
            if not ok then warn("[XMCLib] CustomSignal callback error: " .. tostring(err)) end
        end
        return true
    elseif normalizedAction == "onsignal" or normalizedAction == "onsignalevent" then
        if type(params) ~= "function" then return nil end

        signals[name] = signals[name] or {}
        table.insert(signals[name], params)
        return params
    end

    return nil
end
local CustomMods = {}
local Placeid = game.PlaceId

local LocalPlayer = Players.LocalPlayer


local attacher = {}
local injectconnector = {}

function injectconnector.isconf()
    if isfile("XMCLib/config.conf") then
    print("Arquivo existe")
end

end
function injectconnector.confcontent()
  local content = readfile("XMCLib/config.conf")
print(content)
end
function injectconnector.write(string: StringValue)
  appendfile("XMCLib/config.conf", "\n"..string)
end
function attacher.attach()
     -- start an error and warning logger

    -- start proc:
    -- DO NOT CHANGE THIS IF YOU DONT KNOW WHAT YOU ARE DOING.
    if not isfolder("XMCLib") then
    makefolder("XMCLib") -- INIT 
end
writefile("XMCLib/config.conf", "debug")

end
function attacher.detach()
    -- ends the error and warning logger and writes it into an file
end
-- ================================================================
-- UTILITY
-- ================================================================
local Utility = {}

-- Tween helper — silently skips destroyed instances
function Utility.Tween(inst, info, props)
    if not inst or not inst.Parent then return end
    local ok, t = pcall(TweenService.Create, TweenService, inst, info, props)
    if ok and t then t:Play() return t end
end

-- Safe callback — wraps every user-supplied function in pcall
function Utility.SafeCall(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, err = pcall(fn, ...)
    if not ok then warn("[XMCLib] callback error: " .. tostring(err)) end
end

-- ── Connection management ────────────────────────────────────────
-- Utility.Connect() stores every RBXScriptConnection in a table so
-- that Utility.DisconnectAll() can terminate them all at once.
-- Pass the element's _connections table as the first argument.

function Utility.Connect(conns, signal, fn)
    local c = signal:Connect(fn)
    table.insert(conns, c)
    return c
end

function Utility.DisconnectAll(conns)
    for _, c in ipairs(conns) do
        if c and c.Connected then
            pcall(c.Disconnect, c)
        end
    end
    table.clear(conns)
end

-- ── Instance helpers ─────────────────────────────────────────────
function Utility.Corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = p
    return c
end

function Utility.Pad(p, t, b, l, r)
    local pad = Instance.new("UIPadding")
    pad.PaddingTop    = UDim.new(0, t or 0)
    pad.PaddingBottom = UDim.new(0, b or 0)
    pad.PaddingLeft   = UDim.new(0, l or 0)
    pad.PaddingRight  = UDim.new(0, r or 0)
    pad.Parent = p
    return pad
end

function Utility.Stroke(p, col, thick)
    local s = Instance.new("UIStroke")
    s.Color     = col   or Color3.fromRGB(50, 50, 70)
    s.Thickness = thick or 1
    s.Parent    = p
    return s
end

-- ── Math helpers ─────────────────────────────────────────────────
function Utility.Clamp(v, mn, mx) return math.max(mn, math.min(mx, v)) end
function Utility.Round(v, d)      local m = 10^(d or 0); return math.floor(v*m+.5)/m end
function Utility.UID()            return ("%x"):format(math.random(0xFFFFF)) .. ("%x"):format(math.floor(tick()*1000) % 0xFFFFF) end

-- ── Input type helpers ───────────────────────────────────────────
-- Returns true for any primary-press input (mouse or touch)
function Utility.IsPrimaryPress(inputType)
    return inputType == Enum.UserInputType.MouseButton1
        or inputType == Enum.UserInputType.Touch
end

-- Returns true for any move/drag input (mouse or touch)
function Utility.IsDragMove(inputType)
    return inputType == Enum.UserInputType.MouseMovement
        or inputType == Enum.UserInputType.Touch
end

-- Returns true for any primary-release input
function Utility.IsPrimaryRelease(inputType)
    return inputType == Enum.UserInputType.MouseButton1
        or inputType == Enum.UserInputType.Touch
end

-- ================================================================
-- ZINDEX MANAGER
-- ================================================================
-- Each window claims a tier from a global counter.
-- Tier 1 = ZIndex 10–29, Tier 2 = 30–49, etc.
-- All children and floating panels are offset inside the tier.
--
-- ZIndex layout within a tier (base = tier * 20):
--   base +  0  root frame
--   base +  2  content area, sidebar patches
--   base +  3  sidebar, topbar
--   base +  4  sidebar labels, tab buttons
--   base +  5  element rows
--   base +  6  element labels
--   base +  7  interactive controls (toggles, sliders…)
--   base +  8  interactive overlays
--   base + 14  floating dropdown panel
--   base + 15  dropdown options
--   base + 16  dropdown option labels
--
-- Notifications use a separate high tier (tier 30+ = ZIndex 600+).

local ZIndexManager = {}
ZIndexManager._windowCount = 0
ZIndexManager._TIER_SIZE   = 20
ZIndexManager._NOTIF_BASE  = 600   -- always above all windows

function ZIndexManager.ClaimWindowBase()
    ZIndexManager._windowCount = ZIndexManager._windowCount + 1
    return ZIndexManager._windowCount * ZIndexManager._TIER_SIZE
end

function ZIndexManager.NotifBase()
    return ZIndexManager._NOTIF_BASE
end

-- ================================================================
-- THEMES
-- ================================================================
local Themes = {}

Themes.Dark = {
    Base             = Color3.fromRGB(10,  10,  15),
    Surface0         = Color3.fromRGB(14,  14,  20),
    Surface1         = Color3.fromRGB(18,  18,  26),
    Surface2         = Color3.fromRGB(23,  23,  34),
    Surface3         = Color3.fromRGB(29,  29,  43),
    Surface3Hover    = Color3.fromRGB(36,  36,  54),
    Border0          = Color3.fromRGB(30,  30,  45),
    Border1          = Color3.fromRGB(40,  40,  58),
    Border2          = Color3.fromRGB(52,  52,  75),
    Accent           = Color3.fromRGB(105, 145, 255),
    AccentSoft       = Color3.fromRGB(75,  105, 210),
    AccentGlow       = Color3.fromRGB(80,  110, 220),
    AccentDim        = Color3.fromRGB(45,  65,  140),
    TextPrimary      = Color3.fromRGB(228, 228, 245),
    TextSecondary    = Color3.fromRGB(140, 140, 168),
    TextMuted        = Color3.fromRGB(75,  75,  100),
    TextOnAccent     = Color3.fromRGB(255, 255, 255),
    SidebarTitle     = Color3.fromRGB(235, 235, 255),
    SidebarTabText   = Color3.fromRGB(155, 155, 185),
    SidebarTabHover  = Color3.fromRGB(30,  30,  44),
    SidebarTabActive = Color3.fromRGB(26,  30,  52),
    SidebarDivider   = Color3.fromRGB(30,  30,  45),
    ToggleOn         = Color3.fromRGB(105, 145, 255),
    ToggleOff        = Color3.fromRGB(38,  38,  58),
    ToggleThumb      = Color3.fromRGB(255, 255, 255),
    SliderTrack      = Color3.fromRGB(32,  32,  48),
    SliderFill       = Color3.fromRGB(105, 145, 255),
    InputBg          = Color3.fromRGB(16,  16,  24),
    InputBorder      = Color3.fromRGB(42,  42,  62),
    InputBorderFocus = Color3.fromRGB(105, 145, 255),
    DropBg           = Color3.fromRGB(17,  17,  26),
    DropItemHover    = Color3.fromRGB(28,  30,  50),
    Success          = Color3.fromRGB(72,  210, 128),
    Warning          = Color3.fromRGB(245, 185, 60),
    Error            = Color3.fromRGB(235, 75,  75),
    Info             = Color3.fromRGB(105, 145, 255),
    Scrollbar        = Color3.fromRGB(48,  48,  70),
    Shadow           = Color3.fromRGB(0,   0,   0),
    Close            = Color3.fromRGB(235, 75,  75),
    Minimize         = Color3.fromRGB(245, 185, 60),
    Separator        = Color3.fromRGB(34,  34,  52),
}

Themes.Purple = {
    Base             = Color3.fromRGB(9,   8,   16),
    Surface0         = Color3.fromRGB(13,  11,  22),
    Surface1         = Color3.fromRGB(17,  15,  30),
    Surface2         = Color3.fromRGB(22,  19,  38),
    Surface3         = Color3.fromRGB(27,  24,  46),
    Surface3Hover    = Color3.fromRGB(34,  30,  58),
    Border0          = Color3.fromRGB(40,  32,  65),
    Border1          = Color3.fromRGB(50,  42,  80),
    Border2          = Color3.fromRGB(65,  52,  100),
    Accent           = Color3.fromRGB(168, 110, 255),
    AccentSoft       = Color3.fromRGB(128, 82,  205),
    AccentGlow       = Color3.fromRGB(140, 90,  220),
    AccentDim        = Color3.fromRGB(80,  50,  145),
    TextPrimary      = Color3.fromRGB(230, 225, 248),
    TextSecondary    = Color3.fromRGB(148, 132, 190),
    TextMuted        = Color3.fromRGB(82,  72,  115),
    TextOnAccent     = Color3.fromRGB(255, 255, 255),
    SidebarTitle     = Color3.fromRGB(238, 230, 255),
    SidebarTabText   = Color3.fromRGB(158, 140, 198),
    SidebarTabHover  = Color3.fromRGB(28,  24,  48),
    SidebarTabActive = Color3.fromRGB(28,  22,  54),
    SidebarDivider   = Color3.fromRGB(36,  28,  58),
    ToggleOn         = Color3.fromRGB(168, 110, 255),
    ToggleOff        = Color3.fromRGB(45,  36,  72),
    ToggleThumb      = Color3.fromRGB(255, 255, 255),
    SliderTrack      = Color3.fromRGB(36,  28,  60),
    SliderFill       = Color3.fromRGB(168, 110, 255),
    InputBg          = Color3.fromRGB(14,  12,  24),
    InputBorder      = Color3.fromRGB(52,  42,  82),
    InputBorderFocus = Color3.fromRGB(168, 110, 255),
    DropBg           = Color3.fromRGB(16,  14,  28),
    DropItemHover    = Color3.fromRGB(30,  25,  52),
    Success          = Color3.fromRGB(72,  210, 128),
    Warning          = Color3.fromRGB(245, 185, 60),
    Error            = Color3.fromRGB(235, 75,  75),
    Info             = Color3.fromRGB(168, 110, 255),
    Scrollbar        = Color3.fromRGB(60,  48,  90),
    Shadow           = Color3.fromRGB(0,   0,   0),
    Close            = Color3.fromRGB(235, 75,  75),
    Minimize         = Color3.fromRGB(245, 185, 60),
    Separator        = Color3.fromRGB(36,  28,  58),
}

Themes.Red = {
    Base             = Color3.fromRGB(14,  8,   8),
    Surface0         = Color3.fromRGB(19,  11,  11),
    Surface1         = Color3.fromRGB(24,  14,  14),
    Surface2         = Color3.fromRGB(30,  18,  18),
    Surface3         = Color3.fromRGB(36,  22,  22),
    Surface3Hover    = Color3.fromRGB(44,  27,  27),
    Border0          = Color3.fromRGB(58,  28,  28),
    Border1          = Color3.fromRGB(72,  35,  35),
    Border2          = Color3.fromRGB(90,  44,  44),
    Accent           = Color3.fromRGB(235, 75,  75),
    AccentSoft       = Color3.fromRGB(185, 55,  55),
    AccentGlow       = Color3.fromRGB(210, 65,  65),
    AccentDim        = Color3.fromRGB(120, 35,  35),
    TextPrimary      = Color3.fromRGB(242, 228, 228),
    TextSecondary    = Color3.fromRGB(175, 138, 138),
    TextMuted        = Color3.fromRGB(105, 72,  72),
    TextOnAccent     = Color3.fromRGB(255, 255, 255),
    SidebarTitle     = Color3.fromRGB(248, 235, 235),
    SidebarTabText   = Color3.fromRGB(182, 142, 142),
    SidebarTabHover  = Color3.fromRGB(38,  22,  22),
    SidebarTabActive = Color3.fromRGB(42,  20,  20),
    SidebarDivider   = Color3.fromRGB(48,  26,  26),
    ToggleOn         = Color3.fromRGB(235, 75,  75),
    ToggleOff        = Color3.fromRGB(52,  30,  30),
    ToggleThumb      = Color3.fromRGB(255, 255, 255),
    SliderTrack      = Color3.fromRGB(44,  24,  24),
    SliderFill       = Color3.fromRGB(235, 75,  75),
    InputBg          = Color3.fromRGB(16,  10,  10),
    InputBorder      = Color3.fromRGB(68,  36,  36),
    InputBorderFocus = Color3.fromRGB(235, 75,  75),
    DropBg           = Color3.fromRGB(18,  11,  11),
    DropItemHover    = Color3.fromRGB(36,  20,  20),
    Success          = Color3.fromRGB(72,  210, 128),
    Warning          = Color3.fromRGB(245, 185, 60),
    Error            = Color3.fromRGB(235, 75,  75),
    Info             = Color3.fromRGB(235, 75,  75),
    Scrollbar        = Color3.fromRGB(72,  36,  36),
    Shadow           = Color3.fromRGB(0,   0,   0),
    Close            = Color3.fromRGB(235, 75,  75),
    Minimize         = Color3.fromRGB(245, 185, 60),
    Separator        = Color3.fromRGB(44,  24,  24),
}

Themes.Green = {
    Base             = Color3.fromRGB(8,   14,  10),
    Surface0         = Color3.fromRGB(10,  18,  13),
    Surface1         = Color3.fromRGB(13,  23,  17),
    Surface2         = Color3.fromRGB(17,  28,  21),
    Surface3         = Color3.fromRGB(21,  34,  26),
    Surface3Hover    = Color3.fromRGB(26,  42,  32),
    Border0          = Color3.fromRGB(28,  55,  36),
    Border1          = Color3.fromRGB(36,  68,  46),
    Border2          = Color3.fromRGB(46,  86,  58),
    Accent           = Color3.fromRGB(72,  210, 128),
    AccentSoft       = Color3.fromRGB(52,  162, 96),
    AccentGlow       = Color3.fromRGB(60,  185, 110),
    AccentDim        = Color3.fromRGB(32,  102, 58),
    TextPrimary      = Color3.fromRGB(225, 242, 230),
    TextSecondary    = Color3.fromRGB(140, 185, 155),
    TextMuted        = Color3.fromRGB(72,  110, 86),
    TextOnAccent     = Color3.fromRGB(10,  30,  16),
    SidebarTitle     = Color3.fromRGB(230, 248, 236),
    SidebarTabText   = Color3.fromRGB(145, 192, 162),
    SidebarTabHover  = Color3.fromRGB(18,  36,  24),
    SidebarTabActive = Color3.fromRGB(18,  38,  25),
    SidebarDivider   = Color3.fromRGB(24,  46,  30),
    ToggleOn         = Color3.fromRGB(72,  210, 128),
    ToggleOff        = Color3.fromRGB(28,  52,  36),
    ToggleThumb      = Color3.fromRGB(255, 255, 255),
    SliderTrack      = Color3.fromRGB(24,  46,  32),
    SliderFill       = Color3.fromRGB(72,  210, 128),
    InputBg          = Color3.fromRGB(10,  18,  13),
    InputBorder      = Color3.fromRGB(36,  72,  48),
    InputBorderFocus = Color3.fromRGB(72,  210, 128),
    DropBg           = Color3.fromRGB(11,  20,  14),
    DropItemHover    = Color3.fromRGB(20,  40,  26),
    Success          = Color3.fromRGB(72,  210, 128),
    Warning          = Color3.fromRGB(245, 185, 60),
    Error            = Color3.fromRGB(235, 75,  75),
    Info             = Color3.fromRGB(72,  210, 128),
    Scrollbar        = Color3.fromRGB(36,  78,  50),
    Shadow           = Color3.fromRGB(0,   0,   0),
    Close            = Color3.fromRGB(235, 75,  75),
    Minimize         = Color3.fromRGB(245, 185, 60),
    Separator        = Color3.fromRGB(24,  48,  32),
}

-- ================================================================
-- CONFIG MODULE
-- ================================================================
local Config = {}
Config.__index = Config

function Config.new()
    return setmetatable({ _data = {}, _flags = {} }, Config)
end

function Config:Register(flag, default)
    if flag and self._flags[flag] == nil then
        self._flags[flag] = default
        self._data[flag]  = default
    end
end

function Config:Set(flag, val)
    if not flag then return end
    self._data[flag]  = val
    self._flags[flag] = val
end

function Config:Get(flag)
    return self._data[flag]
end

function Config:Save(name)
    name = name or "default"
    local ok, json = pcall(HttpService.JSONEncode, HttpService, self._data)
    if not ok then return false, "encode error" end
    if writefile then
        local s = pcall(writefile, "XMCLib_" .. name .. ".json", json)
        return s, s and "Saved" or "writefile failed"
    end
    return false, "writefile not available"
end

function Config:Load(name)
    name = name or "default"
    if not readfile then return false, "readfile not available" end
    local ok, content = pcall(readfile, "XMCLib_" .. name .. ".json")
    if not ok or not content then return false, "file not found" end
    local ok2, data = pcall(HttpService.JSONDecode, HttpService, content)
    if not ok2 then return false, "decode error" end
    for k, v in pairs(data) do
        self._data[k]  = v
        self._flags[k] = v
    end
    return true, "Loaded"
end

-- ================================================================
-- DRAG MODULE  (touch + mouse)
-- ================================================================
local Drag = {}

-- Returns a connections table so the caller can disconnect on destroy.
-- [FIX] All connections now go through Utility.Connect() into `conns`.
-- [FIX] Touch events handled alongside mouse events.
function Drag.Enable(root, handle, conns)
    conns  = conns or {}
    handle = handle or root

    local dragging, dragInput, mStart, fStart = false, nil, nil, nil

    Utility.Connect(conns, handle.InputBegan, function(inp)
        if Utility.IsPrimaryPress(inp.UserInputType) then
            dragging = true
            mStart   = inp.Position
            fStart   = root.Position
            -- Track end of this specific input object
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    Utility.Connect(conns, handle.InputChanged, function(inp)
        if Utility.IsDragMove(inp.UserInputType) then
            dragInput = inp
        end
    end)

    Utility.Connect(conns, UserInputService.InputChanged, function(inp)
        if inp == dragInput and dragging then
            local d = inp.Position - mStart
            root.Position = UDim2.new(
                fStart.X.Scale, fStart.X.Offset + d.X,
                fStart.Y.Scale, fStart.Y.Offset + d.Y
            )
        end
    end)

    return conns
end

-- ================================================================
-- MAIN LIBRARY
-- ================================================================
local XMCLib   = {}
XMCLib.__index = XMCLib
XMCLib._version = "2.1.0"

function XMCLib.new()
    local self       = setmetatable({}, XMCLib)
    self.Theme       = {}
    self.Config      = Config.new()
    self._gui        = nil
    self._windows    = {}
    self._visible    = true
    self._notifQueue = {}

    for k, v in pairs(Themes.Dark) do self.Theme[k] = v end
    self:_InitGui()
    return self
end

-- ScreenGui mounting: gethui() → CoreGui → PlayerGui
function XMCLib:_InitGui()
    local function try(parent)
        local g = Instance.new("ScreenGui")
        g.Name           = "XMCLib_" .. Utility.UID()
        g.ResetOnSpawn   = false
        g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        g.IgnoreGuiInset = true
        g.Parent         = parent
        return g
    end
    local gui
    if gethui then pcall(function() gui = try(gethui()) end) end
    if not gui then pcall(function() gui = try(game:GetService("CoreGui")) end) end
    if not gui then gui = try(LocalPlayer:WaitForChild("PlayerGui")) end
    self._gui = gui
end

-- Theme API
function XMCLib:SetTheme(t)   for k, v in pairs(t) do self.Theme[k] = v end end
function XMCLib:ThemeDark()   self:SetTheme(Themes.Dark)   end
function XMCLib:ThemePurple() self:SetTheme(Themes.Purple) end
function XMCLib:ThemeRed()    self:SetTheme(Themes.Red)    end
function XMCLib:ThemeGreen()  self:SetTheme(Themes.Green)  end

-- Visibility
function XMCLib:ToggleVisible()
    self._visible = not self._visible
    for _, w in ipairs(self._windows) do
        if w._root then w._root.Visible = self._visible end
    end
end
function XMCLib:SetVisible(s)
    self._visible = s
    for _, w in ipairs(self._windows) do
        if w._root then w._root.Visible = s end
    end
end
function XMCLib:BindToggleKey(key)
    UserInputService.InputBegan:Connect(function(inp, gp)
        if not gp and inp.KeyCode == key then self:ToggleVisible() end
    end)
end

-- ================================================================
-- WINDOW
-- ================================================================
local Window = {}
Window.__index = Window

local SIDEBAR_W  = 148
local TOPBAR_H   = 44
local WIN_RADIUS = 12

function XMCLib:CreateWindow(opts)
    opts  = type(opts) == "string" and { Title = opts } or (opts or {})
    local title = opts.Title  or "XMCLib"
    local W     = opts.Width  or 600
    local H     = opts.Height or 430
    local pos   = opts.Position or UDim2.new(0.5, -W/2, 0.5, -H/2)

    local win = setmetatable({}, Window)
    win._lib         = self
    win._tabs        = {}
    win._activeTab   = nil
    win._connections = {}  -- stores all drag connections for this window

    -- [FIX] Each window claims a unique ZIndex tier.
    local BASE = ZIndexManager.ClaimWindowBase()
    win._zBase = BASE

    -- ZIndex constants for this window (all relative to BASE)
    local Z = {
        shadow  = BASE - 2,
        glow    = BASE - 1,
        root    = BASE,
        content = BASE + 2,
        sidebar = BASE + 3,
        labels  = BASE + 4,
        tabs    = BASE + 5,
        rows    = BASE + 5,
        rowLbl  = BASE + 6,
        ctrl    = BASE + 7,
        overlay = BASE + 8,
        panel   = BASE + 14,  -- floating dropdown
        panelOpt= BASE + 15,
        panelLbl= BASE + 16,
    }
    win._Z = Z

    -- ── Root frame ───────────────────────────────────────────
    local root = Instance.new("Frame")
    root.Name             = "XMCWin_" .. Utility.UID()
    root.Size             = UDim2.new(0, W, 0, 0)
    root.Position         = pos
    root.BackgroundColor3 = self.Theme.Base
    root.BorderSizePixel  = 0
    root.ClipsDescendants = true
    root.ZIndex           = Z.root
    root.Parent           = self._gui
    Utility.Corner(root, WIN_RADIUS)
    Utility.Stroke(root, self.Theme.Border0, 1)
    win._root = root

    -- Ambient glow
    local glow = Instance.new("Frame")
    glow.Size                  = UDim2.new(1, 32, 1, 32)
    glow.Position              = UDim2.new(0, -16, 0, -16)
    glow.BackgroundColor3      = self.Theme.AccentGlow
    glow.BackgroundTransparency= 0.86
    glow.BorderSizePixel       = 0
    glow.ZIndex                = Z.glow
    glow.Parent                = root
    Utility.Corner(glow, WIN_RADIUS + 8)

    -- Drop shadow
    local shadow = Instance.new("Frame")
    shadow.Size                  = UDim2.new(1, 50, 1, 50)
    shadow.Position              = UDim2.new(0, -25, 0, 10)
    shadow.BackgroundColor3      = self.Theme.Shadow
    shadow.BackgroundTransparency= 0.52
    shadow.BorderSizePixel       = 0
    shadow.ZIndex                = Z.shadow
    shadow.Parent                = root
    Utility.Corner(shadow, WIN_RADIUS + 12)

    -- ── Sidebar ──────────────────────────────────────────────
    local sidebar = Instance.new("Frame")
    sidebar.Name             = "Sidebar"
    sidebar.Size             = UDim2.new(0, SIDEBAR_W, 1, 0)
    sidebar.BackgroundColor3 = self.Theme.Surface0
    sidebar.BorderSizePixel  = 0
    sidebar.ZIndex           = Z.sidebar
    sidebar.Parent           = root
    Utility.Corner(sidebar, WIN_RADIUS)

    local sidePatch = Instance.new("Frame")
    sidePatch.Size             = UDim2.new(0, WIN_RADIUS, 1, 0)
    sidePatch.Position         = UDim2.new(1, -WIN_RADIUS, 0, 0)
    sidePatch.BackgroundColor3 = self.Theme.Surface0
    sidePatch.BorderSizePixel  = 0
    sidePatch.ZIndex           = Z.sidebar
    sidePatch.Parent           = sidebar

    local sideBorder = Instance.new("Frame")
    sideBorder.Size             = UDim2.new(0, 1, 1, 0)
    sideBorder.Position         = UDim2.new(1, 0, 0, 0)
    sideBorder.BackgroundColor3 = self.Theme.Border0
    sideBorder.BorderSizePixel  = 0
    sideBorder.ZIndex           = Z.sidebar + 1
    sideBorder.Parent           = sidebar

    -- Logo / title area
    local logoArea = Instance.new("Frame")
    logoArea.Size             = UDim2.new(1, 0, 0, TOPBAR_H + 14)
    logoArea.BackgroundTransparency = 1
    logoArea.BorderSizePixel  = 0
    logoArea.ZIndex           = Z.labels
    logoArea.Parent           = sidebar

    local dot = Instance.new("Frame")
    dot.Size             = UDim2.new(0, 7, 0, 7)
    dot.Position         = UDim2.new(0, 14, 0.5, -3)
    dot.BackgroundColor3 = self.Theme.Accent
    dot.BorderSizePixel  = 0
    dot.ZIndex           = Z.labels + 1
    dot.Parent           = logoArea
    Utility.Corner(dot, 4)

    local dotGlow = Instance.new("Frame")
    dotGlow.Size                  = UDim2.new(0, 14, 0, 14)
    dotGlow.Position              = UDim2.new(0, 10, 0.5, -7)
    dotGlow.BackgroundColor3      = self.Theme.Accent
    dotGlow.BackgroundTransparency= 0.6
    dotGlow.BorderSizePixel       = 0
    dotGlow.ZIndex                = Z.labels
    dotGlow.Parent                = logoArea
    Utility.Corner(dotGlow, 7)

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size            = UDim2.new(1, -32, 1, 0)
    titleLbl.Position        = UDim2.new(0, 28, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text            = title
    titleLbl.TextColor3      = self.Theme.SidebarTitle
    titleLbl.TextSize        = 14
    titleLbl.Font            = Enum.Font.GothamBold
    titleLbl.TextXAlignment  = Enum.TextXAlignment.Left
    titleLbl.TextTruncate    = Enum.TextTruncate.AtEnd
    titleLbl.ZIndex          = Z.labels + 1
    titleLbl.Parent          = logoArea
    win._titleLabel = titleLbl

    local logoDivider = Instance.new("Frame")
    logoDivider.Size             = UDim2.new(1, -20, 0, 1)
    logoDivider.Position         = UDim2.new(0, 10, 0, TOPBAR_H + 13)
    logoDivider.BackgroundColor3 = self.Theme.SidebarDivider
    logoDivider.BorderSizePixel  = 0
    logoDivider.ZIndex           = Z.labels
    logoDivider.Parent           = sidebar

    -- Tab list scroll frame
    local tabList = Instance.new("ScrollingFrame")
    tabList.Size                  = UDim2.new(1, 0, 1, -(TOPBAR_H + 30 + 28))
    tabList.Position              = UDim2.new(0, 0, 0, TOPBAR_H + 20)
    tabList.BackgroundTransparency= 1
    tabList.BorderSizePixel       = 0
    tabList.ScrollBarThickness    = 0
    tabList.CanvasSize            = UDim2.new(0, 0, 0, 0)
    tabList.AutomaticCanvasSize   = Enum.AutomaticSize.Y
    tabList.ZIndex                = Z.tabs
    tabList.Parent                = sidebar
    win._tabList = tabList

    local tabLL = Instance.new("UIListLayout")
    tabLL.SortOrder = Enum.SortOrder.LayoutOrder
    tabLL.Padding   = UDim.new(0, 2)
    tabLL.Parent    = tabList
    Utility.Pad(tabList, 0, 0, 8, 8)

    -- Version watermark
    local verLbl = Instance.new("TextLabel")
    verLbl.Size             = UDim2.new(1, 0, 0, 22)
    verLbl.Position         = UDim2.new(0, 0, 1, -26)
    verLbl.BackgroundTransparency = 1
    verLbl.Text             = "XMCLib  v" .. XMCLib._version
    verLbl.TextColor3       = self.Theme.TextMuted
    verLbl.TextSize         = 9
    verLbl.Font             = Enum.Font.Gotham
    verLbl.ZIndex           = Z.labels
    verLbl.Parent           = sidebar

    -- ── Top bar (window controls) ─────────────────────────────
    local topBar = Instance.new("Frame")
    topBar.Size             = UDim2.new(1, -SIDEBAR_W, 0, TOPBAR_H)
    topBar.Position         = UDim2.new(0, SIDEBAR_W, 0, 0)
    topBar.BackgroundColor3 = self.Theme.Surface1
    topBar.BorderSizePixel  = 0
    topBar.ZIndex           = Z.sidebar
    topBar.Parent           = root

    local topBorder = Instance.new("Frame")
    topBorder.Size             = UDim2.new(1, 0, 0, 1)
    topBorder.Position         = UDim2.new(0, 0, 1, -1)
    topBorder.BackgroundColor3 = self.Theme.Border0
    topBorder.BorderSizePixel  = 0
    topBorder.ZIndex           = Z.sidebar + 1
    topBorder.Parent           = topBar

    -- Control buttons (minimize / close)
    local ctrlHolder = Instance.new("Frame")
    ctrlHolder.Size             = UDim2.new(0, 56, 0, 20)
    ctrlHolder.Position         = UDim2.new(1, -64, 0.5, -10)
    ctrlHolder.BackgroundTransparency = 1
    ctrlHolder.ZIndex           = Z.ctrl
    ctrlHolder.Parent           = topBar

    local ctrlLL = Instance.new("UIListLayout")
    ctrlLL.FillDirection       = Enum.FillDirection.Horizontal
    ctrlLL.HorizontalAlignment = Enum.HorizontalAlignment.Right
    ctrlLL.VerticalAlignment   = Enum.VerticalAlignment.Center
    ctrlLL.Padding             = UDim.new(0, 6)
    ctrlLL.Parent              = ctrlHolder

    local function makeCtrl(baseColor, sym, cb)
        local btn = Instance.new("TextButton")
        btn.Size                  = UDim2.new(0, 18, 0, 18)
        btn.BackgroundColor3      = baseColor
        btn.BackgroundTransparency= 0.3
        btn.Text                  = ""
        btn.BorderSizePixel       = 0
        btn.ZIndex                = Z.ctrl
        btn.Parent                = ctrlHolder
        Utility.Corner(btn, 9)

        local symLbl = Instance.new("TextLabel")
        symLbl.Size             = UDim2.new(1, 0, 1, 0)
        symLbl.BackgroundTransparency = 1
        symLbl.Text             = sym
        symLbl.TextColor3       = Color3.new(1, 1, 1)
        symLbl.TextSize         = 9
        symLbl.Font             = Enum.Font.GothamBold
        symLbl.TextTransparency = 1
        symLbl.ZIndex           = Z.ctrl + 1
        symLbl.Parent           = btn

        btn.MouseEnter:Connect(function()
            Utility.Tween(btn,    TweenInfo.new(0.1), { BackgroundTransparency = 0 })
            Utility.Tween(symLbl, TweenInfo.new(0.1), { TextTransparency = 0 })
        end)
        btn.MouseLeave:Connect(function()
            Utility.Tween(btn,    TweenInfo.new(0.1), { BackgroundTransparency = 0.3 })
            Utility.Tween(symLbl, TweenInfo.new(0.1), { TextTransparency = 1 })
        end)
        btn.MouseButton1Click:Connect(function() Utility.SafeCall(cb) end)
        return btn
    end

    local minimized = false
    local fullSize  = UDim2.new(0, W, 0, H)

    makeCtrl(self.Theme.Minimize, "─", function()
        minimized = not minimized
        local sz = minimized and UDim2.new(0, W, 0, TOPBAR_H) or fullSize
        Utility.Tween(root, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = sz })
    end)

    makeCtrl(self.Theme.Close, "✕", function()
        Utility.Tween(root, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
            { Size = UDim2.new(0, W, 0, 0), BackgroundTransparency = 1 })
        task.delay(0.3, function()
            -- Disconnect all window-level drag connections
            Utility.DisconnectAll(win._connections)
            if root and root.Parent then root:Destroy() end
        end)
    end)

    -- [FIX] Drag connections stored in win._connections for cleanup
    Drag.Enable(root, topBar,    win._connections)
    Drag.Enable(root, logoArea,  win._connections)

    -- ── Content area ─────────────────────────────────────────
    local content = Instance.new("Frame")
    content.Name             = "ContentArea"
    content.Size             = UDim2.new(1, -SIDEBAR_W, 1, -TOPBAR_H)
    content.Position         = UDim2.new(0, SIDEBAR_W, 0, TOPBAR_H)
    content.BackgroundColor3 = self.Theme.Surface1
    content.BorderSizePixel  = 0
    content.ClipsDescendants = true
    content.ZIndex           = Z.content
    content.Parent           = root
    Utility.Corner(content, WIN_RADIUS)

    local contentPatch = Instance.new("Frame")
    contentPatch.Size             = UDim2.new(0, WIN_RADIUS, 0, WIN_RADIUS)
    contentPatch.BackgroundColor3 = self.Theme.Surface1
    contentPatch.BorderSizePixel  = 0
    contentPatch.ZIndex           = Z.content
    contentPatch.Parent           = content

    local accentStrip = Instance.new("Frame")
    accentStrip.Size             = UDim2.new(1, 0, 0, 52)
    accentStrip.BackgroundColor3 = self.Theme.Accent
    accentStrip.BackgroundTransparency = 0.93
    accentStrip.BorderSizePixel  = 0
    accentStrip.ZIndex           = Z.content
    accentStrip.Parent           = content

    win._contentArea = content

    -- Open animation
    root.BackgroundTransparency = 1
    task.defer(function()
        Utility.Tween(root, TweenInfo.new(0.38, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            { Size = fullSize, BackgroundTransparency = 0 })
    end)

    table.insert(self._windows, win)
    return win
end

-- ================================================================
-- TAB
-- ================================================================
local Tab = {}
Tab.__index = Tab

function Window:CreateTab(name, icon)
    name = name or "Tab"
    local win   = self
    local lib   = self._lib
    local theme = lib.Theme
    local Z     = win._Z

    local tab = setmetatable({}, Tab)
    tab._win      = win
    tab._lib      = lib
    tab._sections = {}
    tab._name     = name

    local btnH = 36
    local btn  = Instance.new("TextButton")
    btn.Name                  = "SideTab_" .. name
    btn.Size                  = UDim2.new(1, 0, 0, btnH)
    btn.BackgroundColor3      = theme.SidebarTabHover
    btn.BackgroundTransparency= 1
    btn.Text                  = ""
    btn.BorderSizePixel       = 0
    btn.LayoutOrder           = #win._tabs + 1
    btn.ZIndex                = Z.tabs
    btn.Parent                = win._tabList
    Utility.Corner(btn, 7)
    tab._btn = btn

    local indicator = Instance.new("Frame")
    indicator.Size                  = UDim2.new(0, 3, 0.6, 0)
    indicator.Position              = UDim2.new(0, 0, 0.2, 0)
    indicator.BackgroundColor3      = theme.Accent
    indicator.BackgroundTransparency= 1
    indicator.BorderSizePixel       = 0
    indicator.ZIndex                = Z.tabs + 2
    indicator.Parent                = btn
    Utility.Corner(indicator, 2)
    tab._indicator = indicator

    local indGlow = Instance.new("Frame")
    indGlow.Size                  = UDim2.new(0, 8, 0.8, 0)
    indGlow.Position              = UDim2.new(0, -2, 0.1, 0)
    indGlow.BackgroundColor3      = theme.Accent
    indGlow.BackgroundTransparency= 1
    indGlow.BorderSizePixel       = 0
    indGlow.ZIndex                = Z.tabs + 1
    indGlow.Parent                = btn
    Utility.Corner(indGlow, 4)
    tab._indGlow = indGlow

    if icon and icon ~= "" then
        local iconLbl = Instance.new("TextLabel")
        iconLbl.Size            = UDim2.new(0, 20, 1, 0)
        iconLbl.Position        = UDim2.new(0, 10, 0, 0)
        iconLbl.BackgroundTransparency = 1
        iconLbl.Text            = icon
        iconLbl.TextColor3      = theme.SidebarTabText
        iconLbl.TextSize        = 14
        iconLbl.Font            = Enum.Font.GothamBold
        iconLbl.ZIndex          = Z.tabs + 1
        iconLbl.Parent          = btn
        tab._iconLbl = iconLbl
    end

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size           = UDim2.new(1, (icon and -38 or -16), 1, 0)
    nameLbl.Position       = UDim2.new(0, (icon and 34 or 12), 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text           = name
    nameLbl.TextColor3     = theme.SidebarTabText
    nameLbl.TextSize       = 13
    nameLbl.Font           = Enum.Font.Gotham
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.ZIndex         = Z.tabs + 1
    nameLbl.Parent         = btn
    tab._nameLbl = nameLbl

    -- Scrollable content pane
    local pane = Instance.new("ScrollingFrame")
    pane.Size                  = UDim2.new(1, 0, 1, 0)
    pane.BackgroundTransparency= 1
    pane.BorderSizePixel       = 0
    pane.ScrollBarThickness    = 3
    pane.ScrollBarImageColor3  = theme.Scrollbar
    pane.CanvasSize            = UDim2.new(0, 0, 0, 0)
    pane.AutomaticCanvasSize   = Enum.AutomaticSize.Y
    pane.Visible               = false
    pane.ZIndex                = Z.content + 1
    pane.ClipsDescendants      = true
    pane.Parent                = win._contentArea
    tab._pane = pane

    local paneLL = Instance.new("UIListLayout")
    paneLL.SortOrder = Enum.SortOrder.LayoutOrder
    paneLL.Padding   = UDim.new(0, 8)
    paneLL.Parent    = pane
    Utility.Pad(pane, 12, 12, 12, 12)

    btn.MouseEnter:Connect(function()
        if win._activeTab ~= tab then
            Utility.Tween(btn, TweenInfo.new(0.12), {
                BackgroundColor3      = theme.SidebarTabHover,
                BackgroundTransparency= 0,
            })
        end
    end)
    btn.MouseLeave:Connect(function()
        if win._activeTab ~= tab then
            Utility.Tween(btn, TweenInfo.new(0.12), { BackgroundTransparency = 1 })
        end
    end)
    btn.MouseButton1Click:Connect(function() win:_ActivateTab(tab) end)

    table.insert(win._tabs, tab)
    if #win._tabs == 1 then win:_ActivateTab(tab) end
    return tab
end

function Window:_ActivateTab(target)
    local theme = self._lib.Theme
    for _, t in ipairs(self._tabs) do
        t._pane.Visible = false
        Utility.Tween(t._indicator, TweenInfo.new(0.18), { BackgroundTransparency = 1 })
        Utility.Tween(t._indGlow,   TweenInfo.new(0.18), { BackgroundTransparency = 1 })
        Utility.Tween(t._btn,       TweenInfo.new(0.14), { BackgroundTransparency = 1 })
        Utility.Tween(t._nameLbl,   TweenInfo.new(0.14), { TextColor3 = theme.SidebarTabText })
        t._nameLbl.Font = Enum.Font.Gotham
        if t._iconLbl then
            Utility.Tween(t._iconLbl, TweenInfo.new(0.14), { TextColor3 = theme.SidebarTabText })
        end
    end

    self._activeTab = target
    target._pane.Visible = true
    Utility.Tween(target._indicator, TweenInfo.new(0.22, Enum.EasingStyle.Quart), { BackgroundTransparency = 0 })
    Utility.Tween(target._indGlow,   TweenInfo.new(0.22, Enum.EasingStyle.Quart), { BackgroundTransparency = 0.75 })
    Utility.Tween(target._btn,       TweenInfo.new(0.14), {
        BackgroundColor3      = theme.SidebarTabActive,
        BackgroundTransparency= 0,
    })
    Utility.Tween(target._nameLbl, TweenInfo.new(0.14), { TextColor3 = theme.Accent })
    target._nameLbl.Font = Enum.Font.GothamSemibold
    if target._iconLbl then
        Utility.Tween(target._iconLbl, TweenInfo.new(0.14), { TextColor3 = theme.Accent })
    end
end

-- ================================================================
-- SECTION
-- ================================================================
local Section = {}
Section.__index = Section

function Tab:CreateSection(title)
    local theme = self._lib.Theme
    local Z     = self._win._Z

    local sec   = setmetatable({}, Section)
    sec._tab      = self
    sec._lib      = self._lib
    sec._win      = self._win
    sec._elements = {}

    local card = Instance.new("Frame")
    card.AutomaticSize    = Enum.AutomaticSize.Y
    card.Size             = UDim2.new(1, 0, 0, 0)
    card.BackgroundColor3 = theme.Surface2
    card.BorderSizePixel  = 0
    card.LayoutOrder      = #self._sections + 1
    card.ZIndex           = Z.rows
    card.Parent           = self._pane
    Utility.Corner(card, 10)
    Utility.Stroke(card, theme.Border1, 1)

    local header = Instance.new("Frame")
    header.Size             = UDim2.new(1, 0, 0, 34)
    header.BackgroundTransparency = 1
    header.ZIndex           = Z.rows + 1
    header.Parent           = card

    if title and title ~= "" then
        local hdot = Instance.new("Frame")
        hdot.Size             = UDim2.new(0, 5, 0, 5)
        hdot.Position         = UDim2.new(0, 12, 0.5, -2)
        hdot.BackgroundColor3 = theme.Accent
        hdot.BackgroundTransparency = 0.25
        hdot.BorderSizePixel  = 0
        hdot.ZIndex           = Z.rows + 2
        hdot.Parent           = header
        Utility.Corner(hdot, 3)

        local hLbl = Instance.new("TextLabel")
        hLbl.Size            = UDim2.new(1, -26, 1, 0)
        hLbl.Position        = UDim2.new(0, 22, 0, 0)
        hLbl.BackgroundTransparency = 1
        hLbl.Text            = title:upper()
        hLbl.TextColor3      = theme.TextSecondary
        hLbl.TextSize        = 10
        hLbl.Font            = Enum.Font.GothamBold
        hLbl.TextXAlignment  = Enum.TextXAlignment.Left
        hLbl.ZIndex          = Z.rows + 2
        hLbl.Parent          = header
    end

    local divider = Instance.new("Frame")
    divider.Size             = UDim2.new(1, -20, 0, 1)
    divider.Position         = UDim2.new(0, 10, 0, 33)
    divider.BackgroundColor3 = theme.Border0
    divider.BorderSizePixel  = 0
    divider.ZIndex           = Z.rows + 1
    divider.Parent           = card

    local holder = Instance.new("Frame")
    holder.AutomaticSize  = Enum.AutomaticSize.Y
    holder.Size           = UDim2.new(1, 0, 0, 0)
    holder.Position       = UDim2.new(0, 0, 0, 35)
    holder.BackgroundTransparency = 1
    holder.ZIndex         = Z.rows + 1
    holder.Parent         = card

    local holderLL = Instance.new("UIListLayout")
    holderLL.SortOrder = Enum.SortOrder.LayoutOrder
    holderLL.Padding   = UDim.new(0, 1)
    holderLL.Parent    = holder
    Utility.Pad(holder, 2, 6, 0, 0)

    sec._holder = holder
    sec._card   = card
    table.insert(self._sections, sec)
    return sec
end

-- ================================================================
-- ELEMENT HELPERS
-- ================================================================
local function makeRow(sec, h)
    local theme  = sec._lib.Theme
    local Z      = sec._win._Z
    local holder = sec._holder

    local row = Instance.new("Frame")
    row.Size                  = UDim2.new(1, 0, 0, h or 42)
    row.BackgroundColor3      = theme.Surface3
    row.BackgroundTransparency= 0.7
    row.BorderSizePixel       = 0
    row.ZIndex                = Z.rows + 1
    row.Parent                = holder
    Utility.Corner(row, 7)
    Utility.Pad(row, 0, 0, 14, 14)

    row.MouseEnter:Connect(function()
        Utility.Tween(row, TweenInfo.new(0.1), {
            BackgroundColor3      = theme.Surface3Hover,
            BackgroundTransparency= 0.4,
        })
    end)
    row.MouseLeave:Connect(function()
        Utility.Tween(row, TweenInfo.new(0.1), {
            BackgroundColor3      = theme.Surface3,
            BackgroundTransparency= 0.7,
        })
    end)
    return row
end

local function placeLabels(row, text, desc, theme, Z)
    if desc and desc ~= "" then
        local n = Instance.new("TextLabel")
        n.Size            = UDim2.new(0.54, 0, 0, 18)
        n.Position        = UDim2.new(0, 0, 0, 6)
        n.BackgroundTransparency = 1
        n.Text            = text
        n.TextColor3      = theme.TextPrimary
        n.TextSize        = 13
        n.Font            = Enum.Font.GothamSemibold
        n.TextXAlignment  = Enum.TextXAlignment.Left
        n.TextTruncate    = Enum.TextTruncate.AtEnd
        n.ZIndex          = Z.rowLbl
        n.Parent          = row

        local s = Instance.new("TextLabel")
        s.Size            = UDim2.new(0.54, 0, 0, 14)
        s.Position        = UDim2.new(0, 0, 0, 23)
        s.BackgroundTransparency = 1
        s.Text            = desc
        s.TextColor3      = theme.TextMuted
        s.TextSize        = 10
        s.Font            = Enum.Font.Gotham
        s.TextXAlignment  = Enum.TextXAlignment.Left
        s.TextTruncate    = Enum.TextTruncate.AtEnd
        s.ZIndex          = Z.rowLbl
        s.Parent          = row
        return n, s
    end

    local n = Instance.new("TextLabel")
    n.Size            = UDim2.new(0.54, 0, 1, 0)
    n.BackgroundTransparency = 1
    n.Text            = text
    n.TextColor3      = theme.TextPrimary
    n.TextSize        = 13
    n.Font            = Enum.Font.GothamSemibold
    n.TextXAlignment  = Enum.TextXAlignment.Left
    n.TextTruncate    = Enum.TextTruncate.AtEnd
    n.ZIndex          = Z.rowLbl
    n.Parent          = row
    return n
end

-- ================================================================
-- BUTTON
-- ================================================================
function Section:CreateButton(opts)
    opts = opts or {}
    local theme   = self._lib.Theme
    local Z       = self._win._Z
    local name    = opts.Name        or "Button"
    local desc    = opts.Description or ""
    local btnText = opts.ButtonText  or "Run"
    local cb      = opts.Callback

    local row = makeRow(self, desc ~= "" and 48 or 42)
    row.LayoutOrder = #self._elements + 1
    placeLabels(row, name, desc, theme, Z)

    local bW  = math.max(64, #btnText * 8 + 28)
    local btn = Instance.new("TextButton")
    btn.Size                  = UDim2.new(0, bW, 0, 28)
    btn.Position              = UDim2.new(1, -bW, 0.5, -14)
    btn.BackgroundColor3      = theme.Accent
    btn.Text                  = btnText
    btn.TextColor3            = theme.TextOnAccent
    btn.TextSize              = 12
    btn.Font                  = Enum.Font.GothamBold
    btn.BorderSizePixel       = 0
    btn.AutoButtonColor       = false
    btn.ZIndex                = Z.ctrl
    btn.Parent                = row
    Utility.Corner(btn, 7)

    local shine = Instance.new("Frame")
    shine.Size             = UDim2.new(1, -4, 0, 1)
    shine.Position         = UDim2.new(0, 2, 0, 2)
    shine.BackgroundColor3 = Color3.new(1, 1, 1)
    shine.BackgroundTransparency = 0.55
    shine.BorderSizePixel  = 0
    shine.ZIndex           = Z.ctrl + 1
    shine.Parent           = btn
    Utility.Corner(shine, 3)

    btn.MouseEnter:Connect(function()
        Utility.Tween(btn, TweenInfo.new(0.1), {
            BackgroundColor3 = theme.AccentSoft:Lerp(Color3.new(1,1,1), 0.1)
        })
    end)
    btn.MouseLeave:Connect(function()
        Utility.Tween(btn, TweenInfo.new(0.1), { BackgroundColor3 = theme.Accent })
    end)
    btn.MouseButton1Down:Connect(function()
        Utility.Tween(btn, TweenInfo.new(0.07), {
            BackgroundColor3 = theme.AccentDim,
            Size     = UDim2.new(0, bW-2, 0, 26),
            Position = UDim2.new(1, -(bW-1), 0.5, -13),
        })
    end)
    btn.MouseButton1Up:Connect(function()
        Utility.Tween(btn, TweenInfo.new(0.12, Enum.EasingStyle.Quart), {
            BackgroundColor3 = theme.Accent,
            Size     = UDim2.new(0, bW, 0, 28),
            Position = UDim2.new(1, -bW, 0.5, -14),
        })
    end)
    btn.MouseButton1Click:Connect(function() Utility.SafeCall(cb) end)

    -- Buttons only connect to local instance events — no global UIS, no leak.
    local el = { _row = row, _btn = btn }
    function el:SetText(t)     btn.Text = t end
    function el:SetCallback(f) cb = f       end
    function el:Destroy()      row:Destroy() end
    table.insert(self._elements, el)
    return el
end

-- ================================================================
-- TOGGLE
-- ================================================================
function Section:CreateToggle(opts)
    opts = opts or {}
    local theme   = self._lib.Theme
    local Z       = self._win._Z
    local name    = opts.Name        or "Toggle"
    local desc    = opts.Description or ""
    local default = opts.Default     or false
    local flag    = opts.Flag
    local cb      = opts.Callback

    if flag then self._lib.Config:Register(flag, default) end
    local state = flag and self._lib.Config:Get(flag) or default

    local row = makeRow(self, desc ~= "" and 48 or 42)
    row.LayoutOrder = #self._elements + 1
    placeLabels(row, name, desc, theme, Z)

    local tW, tH = 44, 24
    local track = Instance.new("Frame")
    track.Size             = UDim2.new(0, tW, 0, tH)
    track.Position         = UDim2.new(1, -tW, 0.5, -tH/2)
    track.BackgroundColor3 = state and theme.ToggleOn or theme.ToggleOff
    track.BorderSizePixel  = 0
    track.ZIndex           = Z.ctrl
    track.Parent           = row
    Utility.Corner(track, tH/2)
    local tkStroke = Utility.Stroke(track, state and theme.AccentSoft or theme.Border2, 1)

    local tInner = Instance.new("Frame")
    tInner.Size             = UDim2.new(1, -2, 1, -2)
    tInner.Position         = UDim2.new(0, 1, 0, 1)
    tInner.BackgroundColor3 = Color3.new(0, 0, 0)
    tInner.BackgroundTransparency = 0.82
    tInner.BorderSizePixel  = 0
    tInner.ZIndex           = Z.ctrl
    tInner.Parent           = track
    Utility.Corner(tInner, tH/2)

    local thSz = tH - 6
    local thumb = Instance.new("Frame")
    thumb.Size             = UDim2.new(0, thSz, 0, thSz)
    thumb.Position         = state
        and UDim2.new(1, -(thSz+3), 0.5, -thSz/2)
        or  UDim2.new(0, 3, 0.5, -thSz/2)
    thumb.BackgroundColor3 = theme.ToggleThumb
    thumb.BorderSizePixel  = 0
    thumb.ZIndex           = Z.ctrl + 2
    thumb.Parent           = track
    Utility.Corner(thumb, thSz/2)

    local thGlow = Instance.new("Frame")
    thGlow.Size             = UDim2.new(0, thSz+8, 0, thSz+8)
    thGlow.Position         = UDim2.new(0.5, -(thSz+8)/2, 0.5, -(thSz+8)/2)
    thGlow.BackgroundColor3 = theme.Accent
    thGlow.BackgroundTransparency = state and 0.6 or 1
    thGlow.BorderSizePixel  = 0
    thGlow.ZIndex           = Z.ctrl + 1
    thGlow.Parent           = track
    Utility.Corner(thGlow, (thSz+8)/2)

    -- Toggle only needs a local click proxy — no global UIS connections.
    local proxy = Instance.new("TextButton")
    proxy.Size             = UDim2.new(1, 0, 1, 0)
    proxy.BackgroundTransparency = 1
    proxy.Text             = ""
    proxy.ZIndex           = Z.overlay
    proxy.Parent           = track

    local tw = TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

    local function apply(s, animate)
        state = s
        if flag then self._lib.Config:Set(flag, s) end
        local onP  = UDim2.new(1, -(thSz+3), 0.5, -thSz/2)
        local offP = UDim2.new(0, 3, 0.5, -thSz/2)
        if animate then
            Utility.Tween(track,    tw, { BackgroundColor3 = s and theme.ToggleOn or theme.ToggleOff })
            Utility.Tween(thumb,    tw, { Position = s and onP or offP })
            Utility.Tween(thGlow,   tw, { BackgroundTransparency = s and 0.6 or 1 })
            Utility.Tween(tkStroke, tw, { Color = s and theme.AccentSoft or theme.Border2 })
        else
            track.BackgroundColor3 = s and theme.ToggleOn or theme.ToggleOff
            thumb.Position         = s and onP or offP
            thGlow.BackgroundTransparency = s and 0.6 or 1
        end
        Utility.SafeCall(cb, s)
    end

    proxy.MouseButton1Click:Connect(function() apply(not state, true) end)

    local el = { _row = row }
    function el:Set(s)         apply(s, true)        end
    function el:Get()          return state          end
    function el:Toggle()       apply(not state, true) end
    function el:SetCallback(f) cb = f               end
    function el:Destroy()      row:Destroy()         end
    table.insert(self._elements, el)
    return el
end

-- ================================================================
-- SLIDER
-- ================================================================
function Section:CreateSlider(opts)
    opts = opts or {}
    local theme  = self._lib.Theme
    local Z      = self._win._Z
    local name   = opts.Name        or "Slider"
    local desc   = opts.Description or ""
    local mn     = opts.Min         or 0
    local mx     = opts.Max         or 100
    local def    = opts.Default     or mn
    local decs   = opts.Decimals    or 0
    local suffix = opts.Suffix      or ""
    local flag   = opts.Flag
    local cb     = opts.Callback

    if flag then self._lib.Config:Register(flag, def) end
    local value = Utility.Clamp(flag and self._lib.Config:Get(flag) or def, mn, mx)

    local row = makeRow(self, desc ~= "" and 58 or 52)
    row.LayoutOrder = #self._elements + 1
    placeLabels(row, name, desc, theme, Z)

    -- Value badge
    local badge = Instance.new("Frame")
    badge.Size             = UDim2.new(0, 58, 0, 22)
    badge.Position         = UDim2.new(1, -58, 0, desc ~= "" and 5 or 0)
    badge.BackgroundColor3 = theme.AccentDim
    badge.BackgroundTransparency = 0.3
    badge.BorderSizePixel  = 0
    badge.ZIndex           = Z.ctrl
    badge.Parent           = row
    Utility.Corner(badge, 5)

    local valLbl = Instance.new("TextLabel")
    valLbl.Size             = UDim2.new(1, 0, 1, 0)
    valLbl.BackgroundTransparency = 1
    valLbl.Text             = Utility.Round(value, decs) .. suffix
    valLbl.TextColor3       = theme.Accent
    valLbl.TextSize         = 11
    valLbl.Font             = Enum.Font.GothamBold
    valLbl.ZIndex           = Z.ctrl + 1
    valLbl.Parent           = badge

    -- Track
    local tY = desc ~= "" and 34 or 30
    local trackBg = Instance.new("Frame")
    trackBg.Size             = UDim2.new(1, 0, 0, 6)
    trackBg.Position         = UDim2.new(0, 0, 0, tY)
    trackBg.BackgroundColor3 = theme.SliderTrack
    trackBg.BorderSizePixel  = 0
    trackBg.ZIndex           = Z.ctrl
    trackBg.Parent           = row
    Utility.Corner(trackBg, 3)
    Utility.Stroke(trackBg, theme.Border1, 1)

    local pct  = (value - mn) / (mx - mn)

    local fill = Instance.new("Frame")
    fill.Size             = UDim2.new(pct, 0, 1, 0)
    fill.BackgroundColor3 = theme.SliderFill
    fill.BorderSizePixel  = 0
    fill.ZIndex           = Z.ctrl + 1
    fill.Parent           = trackBg
    Utility.Corner(fill, 3)

    local tSz = 14
    local thumb = Instance.new("Frame")
    thumb.Size             = UDim2.new(0, tSz, 0, tSz)
    thumb.Position         = UDim2.new(pct, -tSz/2, 0.5, -tSz/2)
    thumb.BackgroundColor3 = Color3.new(1, 1, 1)
    thumb.BorderSizePixel  = 0
    thumb.ZIndex           = Z.ctrl + 3
    thumb.Parent           = trackBg
    Utility.Corner(thumb, tSz/2)
    Utility.Stroke(thumb, theme.Accent, 2)

    local tGlow = Instance.new("Frame")
    tGlow.Size             = UDim2.new(0, tSz+8, 0, tSz+8)
    tGlow.Position         = UDim2.new(pct, -(tSz+8)/2, 0.5, -(tSz+8)/2)
    tGlow.BackgroundColor3 = theme.Accent
    tGlow.BackgroundTransparency = 0.7
    tGlow.BorderSizePixel  = 0
    tGlow.ZIndex           = Z.ctrl + 2
    tGlow.Parent           = trackBg
    Utility.Corner(tGlow, (tSz+8)/2)

    -- [FIX] Store all UIS connections so :Destroy() can clean them up.
    local conns   = {}
    local dragging = false
    local ftw      = TweenInfo.new(0.04)

    local function updateVal(pos)
        local ap  = trackBg.AbsolutePosition.X
        local as  = trackBg.AbsoluteSize.X
        local p   = Utility.Clamp((pos - ap) / as, 0, 1)
        value     = Utility.Round(mn + (mx - mn) * p, decs)
        Utility.Tween(fill,  ftw, { Size     = UDim2.new(p, 0, 1, 0) })
        Utility.Tween(thumb, ftw, { Position = UDim2.new(p, -tSz/2, 0.5, -tSz/2) })
        Utility.Tween(tGlow, ftw, { Position = UDim2.new(p, -(tSz+8)/2, 0.5, -(tSz+8)/2) })
        valLbl.Text = Utility.Round(value, decs) .. suffix
        if flag then self._lib.Config:Set(flag, value) end
        Utility.SafeCall(cb, value)
    end

    -- [FIX] InputBegan on trackBg is local — no global UIS needed here.
    trackBg.InputBegan:Connect(function(inp)
        if Utility.IsPrimaryPress(inp.UserInputType) then
            dragging = true
            updateVal(inp.Position.X)
        end
    end)

    -- [FIX] Global InputChanged — stored for disconnect.
    Utility.Connect(conns, UserInputService.InputChanged, function(inp)
        if dragging and Utility.IsDragMove(inp.UserInputType) then
            updateVal(inp.Position.X)
        end
    end)

    -- [FIX] Global InputEnded — stored for disconnect.
    --        Also handles Touch end (UserInputState.End on the touch object).
    Utility.Connect(conns, UserInputService.InputEnded, function(inp)
        if Utility.IsPrimaryRelease(inp.UserInputType) then
            dragging = false
        end
    end)

    local el = { _row = row, _connections = conns }

    function el:Set(v)
        v = Utility.Clamp(v, mn, mx); value = Utility.Round(v, decs)
        local p = (value - mn) / (mx - mn)
        fill.Size      = UDim2.new(p, 0, 1, 0)
        thumb.Position = UDim2.new(p, -tSz/2, 0.5, -tSz/2)
        tGlow.Position = UDim2.new(p, -(tSz+8)/2, 0.5, -(tSz+8)/2)
        valLbl.Text    = value .. suffix
        if flag then self._lib.Config:Set(flag, value) end
        Utility.SafeCall(cb, value)
    end
    function el:Get()          return value   end
    function el:SetCallback(f) cb = f         end
    -- [FIX] Disconnect global UIS listeners before destroying the row.
    function el:Destroy()
        Utility.DisconnectAll(conns)
        row:Destroy()
    end
    table.insert(self._elements, el)
    return el
end

-- ================================================================
-- DROPDOWN
-- ================================================================
function Section:CreateDropdown(opts)
    opts = opts or {}
    local theme   = self._lib.Theme
    local Z       = self._win._Z
    local name    = opts.Name        or "Dropdown"
    local desc    = opts.Description or ""
    local items   = opts.Items       or {}
    local default = opts.Default     or (items[1] or "")
    local flag    = opts.Flag
    local cb      = opts.Callback

    if flag then self._lib.Config:Register(flag, default) end
    local selected = flag and self._lib.Config:Get(flag) or default

    local row = makeRow(self, desc ~= "" and 48 or 42)
    row.LayoutOrder = #self._elements + 1
    placeLabels(row, name, desc, theme, Z)

    local dW = 148
    local dropBtn = Instance.new("Frame")
    dropBtn.Size             = UDim2.new(0, dW, 0, 28)
    dropBtn.Position         = UDim2.new(1, -dW, 0.5, -14)
    dropBtn.BackgroundColor3 = theme.InputBg
    dropBtn.BorderSizePixel  = 0
    dropBtn.ZIndex           = Z.ctrl
    dropBtn.Parent           = row
    Utility.Corner(dropBtn, 7)
    Utility.Stroke(dropBtn, theme.InputBorder, 1)

    local selLbl = Instance.new("TextLabel")
    selLbl.Size             = UDim2.new(1, -26, 1, 0)
    selLbl.Position         = UDim2.new(0, 10, 0, 0)
    selLbl.BackgroundTransparency = 1
    selLbl.Text             = tostring(selected)
    selLbl.TextColor3       = theme.TextPrimary
    selLbl.TextSize         = 12
    selLbl.Font             = Enum.Font.Gotham
    selLbl.TextXAlignment   = Enum.TextXAlignment.Left
    selLbl.TextTruncate     = Enum.TextTruncate.AtEnd
    selLbl.ZIndex           = Z.ctrl + 1
    selLbl.Parent           = dropBtn

    local chevron = Instance.new("TextLabel")
    chevron.Size            = UDim2.new(0, 18, 1, 0)
    chevron.Position        = UDim2.new(1, -20, 0, 0)
    chevron.BackgroundTransparency = 1
    chevron.Text            = "⌄"
    chevron.TextColor3      = theme.TextSecondary
    chevron.TextSize        = 14
    chevron.Font            = Enum.Font.GothamBold
    chevron.ZIndex          = Z.ctrl + 1
    chevron.Parent          = dropBtn

    local proxy = Instance.new("TextButton")
    proxy.Size             = UDim2.new(1, 0, 1, 0)
    proxy.BackgroundTransparency = 1
    proxy.Text             = ""
    proxy.ZIndex           = Z.ctrl + 2
    proxy.Parent           = dropBtn

    -- [FIX] Floating panel uses dynamic ZIndex from this window's tier.
    local panel = Instance.new("Frame")
    panel.Name             = "DropPanel"
    panel.Size             = UDim2.new(0, dW, 0, 0)
    panel.BackgroundColor3 = theme.DropBg
    panel.BorderSizePixel  = 0
    panel.ZIndex           = Z.panel   -- tier-relative, not hardcoded
    panel.Visible          = false
    panel.ClipsDescendants = true
    panel.Parent           = self._lib._gui
    Utility.Corner(panel, 8)
    Utility.Stroke(panel, theme.Border1, 1)

    local panelLL = Instance.new("UIListLayout")
    panelLL.SortOrder = Enum.SortOrder.LayoutOrder
    panelLL.Padding   = UDim.new(0, 0)
    panelLL.Parent    = panel
    Utility.Pad(panel, 4, 4, 4, 4)

    local isOpen = false

    -- [FIX] Store the global UIS connection so we can Disconnect on Destroy.
    local conns = {}

    local function closePanel()
        isOpen = false
        Utility.Tween(panel,   TweenInfo.new(0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
            { Size = UDim2.new(0, dW, 0, 0) })
        Utility.Tween(chevron, TweenInfo.new(0.15), { Rotation = 0 })
        task.delay(0.2, function() panel.Visible = false end)
    end

    local function openPanel()
        isOpen = true
        panel.Visible = true
        local ap = dropBtn.AbsolutePosition
        local as = dropBtn.AbsoluteSize
        panel.Position = UDim2.new(0, ap.X, 0, ap.Y + as.Y + 4)
        local tH = math.min(#items * 32, 160) + 8
        Utility.Tween(panel,   TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            { Size = UDim2.new(0, dW, 0, tH) })
        Utility.Tween(chevron, TweenInfo.new(0.15), { Rotation = 180 })
    end

    local function buildPanel()
        for _, c in ipairs(panel:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        for i, item in ipairs(items) do
            local isSel = (item == selected)
            local optBtn = Instance.new("TextButton")
            optBtn.Size             = UDim2.new(1, 0, 0, 32)
            optBtn.BackgroundColor3 = theme.DropItemHover
            optBtn.BackgroundTransparency = isSel and 0.45 or 1
            optBtn.Text             = ""
            optBtn.BorderSizePixel  = 0
            optBtn.LayoutOrder      = i
            optBtn.ZIndex           = Z.panelOpt
            optBtn.Parent           = panel
            Utility.Corner(optBtn, 5)

            local optLbl = Instance.new("TextLabel")
            optLbl.Size            = UDim2.new(1, -28, 1, 0)
            optLbl.Position        = UDim2.new(0, 10, 0, 0)
            optLbl.BackgroundTransparency = 1
            optLbl.Text            = tostring(item)
            optLbl.TextColor3      = isSel and theme.Accent or theme.TextPrimary
            optLbl.TextSize        = 12
            optLbl.Font            = isSel and Enum.Font.GothamBold or Enum.Font.Gotham
            optLbl.TextXAlignment  = Enum.TextXAlignment.Left
            optLbl.ZIndex          = Z.panelLbl
            optLbl.Parent          = optBtn

            if isSel then
                local chk = Instance.new("TextLabel")
                chk.Size            = UDim2.new(0, 18, 1, 0)
                chk.Position        = UDim2.new(1, -20, 0, 0)
                chk.BackgroundTransparency = 1
                chk.Text            = "✓"
                chk.TextColor3      = theme.Accent
                chk.TextSize        = 12
                chk.Font            = Enum.Font.GothamBold
                chk.ZIndex          = Z.panelLbl
                chk.Parent          = optBtn
            end

            optBtn.MouseEnter:Connect(function()
                Utility.Tween(optBtn, TweenInfo.new(0.08), { BackgroundTransparency = 0.25 })
            end)
            optBtn.MouseLeave:Connect(function()
                Utility.Tween(optBtn, TweenInfo.new(0.08), {
                    BackgroundTransparency = isSel and 0.45 or 1
                })
            end)
            optBtn.MouseButton1Click:Connect(function()
                selected = item
                selLbl.Text = tostring(item)
                if flag then self._lib.Config:Set(flag, item) end
                Utility.SafeCall(cb, item)
                closePanel()
                buildPanel()
            end)
        end
    end
    buildPanel()

    proxy.MouseButton1Click:Connect(function()
        if isOpen then closePanel() else openPanel() end
    end)

    -- [FIX] "Click outside to close" — global UIS connection, stored for Disconnect.
    -- [FIX] Also handles Touch input for closing the panel on mobile.
    Utility.Connect(conns, UserInputService.InputBegan, function(inp)
        local isMouse = inp.UserInputType == Enum.UserInputType.MouseButton1
        local isTouch = inp.UserInputType == Enum.UserInputType.Touch
        if (not isMouse and not isTouch) or not isOpen then return end

        local mp = UserInputService:GetMouseLocation()
        local pp = panel.AbsolutePosition;  local ps = panel.AbsoluteSize
        local bp = dropBtn.AbsolutePosition; local bs = dropBtn.AbsoluteSize
        local inPanel = mp.X >= pp.X and mp.X <= pp.X+ps.X and mp.Y >= pp.Y and mp.Y <= pp.Y+ps.Y
        local inBtn   = mp.X >= bp.X and mp.X <= bp.X+bs.X and mp.Y >= bp.Y and mp.Y <= bp.Y+bs.Y
        if not inPanel and not inBtn then closePanel() end
    end)

    local el = { _row = row, _panel = panel, _connections = conns }

    function el:Set(v)
        selected = v; selLbl.Text = tostring(v)
        if flag then self._lib.Config:Set(flag, v) end
        Utility.SafeCall(cb, v); buildPanel()
    end
    function el:Get()          return selected end
    function el:AddItem(v)     table.insert(items, v); buildPanel() end
    function el:SetItems(t)    items = t; selected = t[1] or ""; selLbl.Text = tostring(selected); buildPanel() end
    function el:SetCallback(f) cb = f end
    -- [FIX] Disconnect global listeners and destroy floating panel.
    function el:Destroy()
        Utility.DisconnectAll(conns)
        panel:Destroy()
        row:Destroy()
    end
    table.insert(self._elements, el)
    return el
end

-- ================================================================
-- TEXTBOX
-- ================================================================
function Section:CreateTextbox(opts)
    opts = opts or {}
    local theme  = self._lib.Theme
    local Z      = self._win._Z
    local name   = opts.Name        or "Textbox"
    local desc   = opts.Description or ""
    local ph     = opts.Placeholder or "Enter text..."
    local def    = opts.Default     or ""
    local flag   = opts.Flag
    local cb     = opts.Callback
    local onFoc  = opts.OnFocus
    local onLost = opts.OnFocusLost

    if flag then self._lib.Config:Register(flag, def) end
    local value = flag and self._lib.Config:Get(flag) or def

    local row = makeRow(self, desc ~= "" and 48 or 42)
    row.LayoutOrder = #self._elements + 1
    placeLabels(row, name, desc, theme, Z)

    local bW = 155
    local boxFrame = Instance.new("Frame")
    boxFrame.Size             = UDim2.new(0, bW, 0, 28)
    boxFrame.Position         = UDim2.new(1, -bW, 0.5, -14)
    boxFrame.BackgroundColor3 = theme.InputBg
    boxFrame.BorderSizePixel  = 0
    boxFrame.ZIndex           = Z.ctrl
    boxFrame.Parent           = row
    Utility.Corner(boxFrame, 7)
    local boxStroke = Utility.Stroke(boxFrame, theme.InputBorder, 1)

    local box = Instance.new("TextBox")
    box.Size             = UDim2.new(1, -12, 1, 0)
    box.Position         = UDim2.new(0, 8, 0, 0)
    box.BackgroundTransparency = 1
    box.Text             = value
    box.PlaceholderText  = ph
    box.TextColor3       = theme.TextPrimary
    box.PlaceholderColor3= theme.TextMuted
    box.TextSize         = 12
    box.Font             = Enum.Font.Gotham
    box.TextXAlignment   = Enum.TextXAlignment.Left
    box.ClearTextOnFocus = false
    box.ZIndex           = Z.ctrl + 1
    box.Parent           = boxFrame

    -- TextBox events are local — no global UIS needed, no leak.
    box.Focused:Connect(function()
        Utility.Tween(boxStroke, TweenInfo.new(0.15), { Color = theme.InputBorderFocus })
        Utility.Tween(boxFrame,  TweenInfo.new(0.15), { BackgroundColor3 = theme.Surface3 })
        Utility.SafeCall(onFoc, box.Text)
    end)
    box.FocusLost:Connect(function(enter)
        Utility.Tween(boxStroke, TweenInfo.new(0.15), { Color = theme.InputBorder })
        Utility.Tween(boxFrame,  TweenInfo.new(0.15), { BackgroundColor3 = theme.InputBg })
        value = box.Text
        if flag then self._lib.Config:Set(flag, value) end
        Utility.SafeCall(cb, value, enter)
        Utility.SafeCall(onLost, value, enter)
    end)

    local el = { _row = row }
    function el:Set(v)         value = v; box.Text = v; if flag then self._lib.Config:Set(flag, v) end end
    function el:Get()          return box.Text end
    function el:SetCallback(f) cb = f end
    function el:Destroy()      row:Destroy() end
    table.insert(self._elements, el)
    return el
end

-- ================================================================
-- LABEL
-- ================================================================
function Section:CreateLabel(opts)
    opts = opts or {}
    local theme = self._lib.Theme
    local Z     = self._win._Z
    local text  = opts.Text  or opts.Name or ""
    local color = opts.Color or theme.TextSecondary
    local size  = opts.TextSize or 12

    local row = makeRow(self, 34)
    row.LayoutOrder = #self._elements + 1

    local lbl = Instance.new("TextLabel")
    lbl.Size            = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text            = text
    lbl.TextColor3      = color
    lbl.TextSize        = size
    lbl.Font            = Enum.Font.Gotham
    lbl.TextXAlignment  = Enum.TextXAlignment.Left
    lbl.TextWrapped     = true
    lbl.ZIndex          = Z.rowLbl
    lbl.Parent          = row

    local el = { _row = row }
    function el:Set(t)      lbl.Text       = t end
    function el:SetColor(c) lbl.TextColor3 = c end
    function el:Destroy()   row:Destroy()      end
    table.insert(self._elements, el)
    return el
end

-- ================================================================
-- KEYBIND
-- ================================================================
function Section:CreateKeybind(opts)
    opts = opts or {}
    local theme   = self._lib.Theme
    local Z       = self._win._Z
    local name    = opts.Name        or "Keybind"
    local desc    = opts.Description or ""
    local default = opts.Default     or Enum.KeyCode.Unknown
    local flag    = opts.Flag
    local cb      = opts.Callback

    if flag then self._lib.Config:Register(flag, default.Name) end
    local boundKey = default
    if flag then
        local sn = self._lib.Config:Get(flag)
        local ok, k = pcall(function() return Enum.KeyCode[sn] end)
        if ok and k then boundKey = k end
    end

    local listening = false
    local row = makeRow(self, desc ~= "" and 48 or 42)
    row.LayoutOrder = #self._elements + 1
    placeLabels(row, name, desc, theme, Z)

    local kW = 96
    local kFrame = Instance.new("Frame")
    kFrame.Size             = UDim2.new(0, kW, 0, 28)
    kFrame.Position         = UDim2.new(1, -kW, 0.5, -14)
    kFrame.BackgroundColor3 = theme.Surface3
    kFrame.BorderSizePixel  = 0
    kFrame.ZIndex           = Z.ctrl
    kFrame.Parent           = row
    Utility.Corner(kFrame, 7)
    local kStroke = Utility.Stroke(kFrame, theme.Border2, 1)

    local kLbl = Instance.new("TextLabel")
    kLbl.Size             = UDim2.new(1, -4, 1, 0)
    kLbl.BackgroundTransparency = 1
    kLbl.Text             = boundKey == Enum.KeyCode.Unknown and "None" or boundKey.Name
    kLbl.TextColor3       = theme.Accent
    kLbl.TextSize         = 11
    kLbl.Font             = Enum.Font.GothamBold
    kLbl.ZIndex           = Z.ctrl + 1
    kLbl.Parent           = kFrame

    local kBtn = Instance.new("TextButton")
    kBtn.Size             = UDim2.new(1, 0, 1, 0)
    kBtn.BackgroundTransparency = 1
    kBtn.Text             = ""
    kBtn.ZIndex           = Z.overlay
    kBtn.Parent           = kFrame

    -- [FIX] Two kinds of global UIS connections:
    --   1. listenConn  — temporary, only active while "listening" for a new key
    --   2. pressConns  — permanent for lifetime of element, fires the callback
    -- Both are stored and disconnected in :Destroy().
    local conns = {}
    local listenConn = nil  -- stored separately so it can be disconnected alone

    kBtn.MouseButton1Click:Connect(function()
        if listening then return end
        listening = true
        kLbl.Text       = "..."
        kLbl.TextColor3 = theme.TextSecondary
        Utility.Tween(kStroke, TweenInfo.new(0.12), { Color = theme.Accent })

        listenConn = UserInputService.InputBegan:Connect(function(inp, gp)
            if gp then return end
            if inp.UserInputType == Enum.UserInputType.Keyboard then
                boundKey = inp.KeyCode
                kLbl.Text       = boundKey.Name
                kLbl.TextColor3 = theme.Accent
                listening       = false
                Utility.Tween(kStroke, TweenInfo.new(0.12), { Color = theme.Border2 })
                if flag then self._lib.Config:Set(flag, boundKey.Name) end
                Utility.SafeCall(cb, boundKey)
                -- Disconnect the temporary listen connection
                if listenConn then listenConn:Disconnect(); listenConn = nil end
            end
        end)
        -- Store it so Destroy() can clean it up if the user destroys mid-listen
        table.insert(conns, listenConn)
    end)

    -- Permanent press-to-fire connection
    Utility.Connect(conns, UserInputService.InputBegan, function(inp, gp)
        if gp or listening then return end
        if inp.UserInputType == Enum.UserInputType.Keyboard
        and inp.KeyCode == boundKey then
            Utility.SafeCall(cb, boundKey)
        end
    end)

    local el = { _row = row, _connections = conns }
    function el:Get()          return boundKey end
    function el:Set(k)         boundKey = k; kLbl.Text = k.Name; if flag then self._lib.Config:Set(flag, k.Name) end end
    function el:SetCallback(f) cb = f end
    -- [FIX] Disconnect all UIS listeners before destroying the row.
    function el:Destroy()
        if listenConn then pcall(listenConn.Disconnect, listenConn) end
        Utility.DisconnectAll(conns)
        row:Destroy()
    end
    table.insert(self._elements, el)
    return el
end

-- ================================================================
-- SEPARATOR
-- ================================================================
function Section:CreateSeparator(opts)
    opts = opts or {}
    local theme = self._lib.Theme
    local label = opts.Label or ""

    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, 0, 0, 22)
    row.BackgroundTransparency = 1
    row.BorderSizePixel  = 0
    row.LayoutOrder      = #self._elements + 1
    row.Parent           = self._holder

    if label ~= "" then
        local lL = Instance.new("Frame")
        lL.Size             = UDim2.new(0.25, 0, 0, 1)
        lL.Position         = UDim2.new(0, 0, 0.5, 0)
        lL.BackgroundColor3 = theme.Separator
        lL.BorderSizePixel  = 0
        lL.Parent           = row

        local lbl = Instance.new("TextLabel")
        lbl.Size            = UDim2.new(0.48, 0, 1, 0)
        lbl.Position        = UDim2.new(0.26, 0, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text            = label
        lbl.TextColor3      = theme.TextMuted
        lbl.TextSize        = 10
        lbl.Font            = Enum.Font.Gotham
        lbl.Parent          = row

        local rL = Instance.new("Frame")
        rL.Size             = UDim2.new(0.25, 0, 0, 1)
        rL.Position         = UDim2.new(0.75, 0, 0.5, 0)
        rL.BackgroundColor3 = theme.Separator
        rL.BorderSizePixel  = 0
        rL.Parent           = row
    else
        local line = Instance.new("Frame")
        line.Size             = UDim2.new(1, -8, 0, 1)
        line.Position         = UDim2.new(0, 4, 0.5, 0)
        line.BackgroundColor3 = theme.Separator
        line.BorderSizePixel  = 0
        line.Parent           = row
    end

    local el = { _row = row }
    function el:Destroy() row:Destroy() end
    table.insert(self._elements, el)
    return el
end

-- ================================================================
-- NOTIFICATION SYSTEM
-- ================================================================
function XMCLib:Notify(opts)
    opts = opts or {}
    local title    = opts.Title    or "Notice"
    local msg      = opts.Message  or ""
    local duration = opts.Duration or 4
    local ntype    = opts.Type     or "info"
    local theme    = self.Theme

    local typeMap = {
        info    = { color = theme.Info,    icon = "ℹ" },
        success = { color = theme.Success, icon = "✓" },
        warning = { color = theme.Warning, icon = "⚠" },
        error   = { color = theme.Error,   icon = "✕" },
    }
    local t   = typeMap[ntype] or typeMap.info
    local col = t.color

    local nW, nH = 300, 80
    local margin  = 12
    local q       = self._notifQueue

    local baseY = 0
    for _, n in ipairs(q) do
        if n and n.Parent then baseY = baseY + nH + margin end
    end

    -- [FIX] Notifications use the dedicated high ZIndex tier, not a hardcoded 100.
    local NZ = ZIndexManager.NotifBase()

    local notif = Instance.new("Frame")
    notif.Name             = "XMCNotif"
    notif.Size             = UDim2.new(0, nW, 0, nH)
    notif.Position         = UDim2.new(1, 20, 1, -(baseY + nH + margin))
    notif.BackgroundColor3 = theme.Surface2
    notif.BorderSizePixel  = 0
    notif.ZIndex           = NZ
    notif.Parent           = self._gui
    Utility.Corner(notif, 10)
    Utility.Stroke(notif, col:Lerp(theme.Border1, 0.5), 1)

    local bar = Instance.new("Frame")
    bar.Size             = UDim2.new(0, 4, 1, -16)
    bar.Position         = UDim2.new(0, 6, 0, 8)
    bar.BackgroundColor3 = col
    bar.BorderSizePixel  = 0
    bar.ZIndex           = NZ + 1
    bar.Parent           = notif
    Utility.Corner(bar, 2)

    local iconBg = Instance.new("Frame")
    iconBg.Size             = UDim2.new(0, 30, 0, 30)
    iconBg.Position         = UDim2.new(0, 18, 0.5, -15)
    iconBg.BackgroundColor3 = col
    iconBg.BackgroundTransparency = 0.82
    iconBg.BorderSizePixel  = 0
    iconBg.ZIndex           = NZ + 1
    iconBg.Parent           = notif
    Utility.Corner(iconBg, 15)

    local iconLbl = Instance.new("TextLabel")
    iconLbl.Size            = UDim2.new(1, 0, 1, 0)
    iconLbl.BackgroundTransparency = 1
    iconLbl.Text            = t.icon
    iconLbl.TextColor3      = col
    iconLbl.TextSize        = 14
    iconLbl.Font            = Enum.Font.GothamBold
    iconLbl.ZIndex          = NZ + 2
    iconLbl.Parent          = iconBg

    local tLbl = Instance.new("TextLabel")
    tLbl.Size           = UDim2.new(1, -68, 0, 22)
    tLbl.Position       = UDim2.new(0, 58, 0, 12)
    tLbl.BackgroundTransparency = 1
    tLbl.Text           = title
    tLbl.TextColor3     = col
    tLbl.TextSize       = 13
    tLbl.Font           = Enum.Font.GothamBold
    tLbl.TextXAlignment = Enum.TextXAlignment.Left
    tLbl.ZIndex         = NZ + 1
    tLbl.Parent         = notif

    local mLbl = Instance.new("TextLabel")
    mLbl.Size           = UDim2.new(1, -68, 0, 28)
    mLbl.Position       = UDim2.new(0, 58, 0, 32)
    mLbl.BackgroundTransparency = 1
    mLbl.Text           = msg
    mLbl.TextColor3     = theme.TextSecondary
    mLbl.TextSize       = 11
    mLbl.Font           = Enum.Font.Gotham
    mLbl.TextXAlignment = Enum.TextXAlignment.Left
    mLbl.TextWrapped    = true
    mLbl.ZIndex         = NZ + 1
    mLbl.Parent         = notif

    local pgBg = Instance.new("Frame")
    pgBg.Size             = UDim2.new(1, -20, 0, 2)
    pgBg.Position         = UDim2.new(0, 10, 1, -6)
    pgBg.BackgroundColor3 = theme.Border1
    pgBg.BorderSizePixel  = 0
    pgBg.ZIndex           = NZ + 1
    pgBg.Parent           = notif
    Utility.Corner(pgBg, 1)

    local pgFill = Instance.new("Frame")
    pgFill.Size             = UDim2.new(1, 0, 1, 0)
    pgFill.BackgroundColor3 = col
    pgFill.BorderSizePixel  = 0
    pgFill.ZIndex           = NZ + 2
    pgFill.Parent           = pgBg
    Utility.Corner(pgFill, 1)

    table.insert(q, notif)

    Utility.Tween(notif, TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        { Position = UDim2.new(1, -(nW + margin), 1, -(baseY + nH + margin)) })
    Utility.Tween(pgFill, TweenInfo.new(duration, Enum.EasingStyle.Linear),
        { Size = UDim2.new(0, 0, 1, 0) })

    task.delay(duration, function()
        Utility.Tween(notif, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
            { Position = UDim2.new(1, 20, 1, -(baseY + nH + margin)) })
        local idx = table.find(q, notif)
        if idx then table.remove(q, idx) end
        task.delay(0.32, function()
            if notif and notif.Parent then notif:Destroy() end
        end)
    end)

    return notif
end

-- ================================================================
-- DESTROY
-- ================================================================
function XMCLib:Destroy()
    if self._gui then self._gui:Destroy() end
end

-- ================================================================
-- ENTRY POINT
-- ===============================================================
return XMCLib.new()
