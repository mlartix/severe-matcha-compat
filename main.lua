--[[
    Dual-Compatibility Header — Severe + Matcha (v2)
    =================================================

    Usage from another script:

        local C = loadstring(game:HttpGet("https://raw.githubusercontent.com/.../dual_compat.lua"))()
        C.Notify("loaded", "success")
        local v = C.Mem.readf32(part, 0x130)
        local screen, visible = C.WorldToScreen(part.Position)

    Detection is by feature, not name. Severe exposes `memory.readu8` as a
    function on a `memory` table; Matcha exposes `memory_read` as a global
    function. We test for both and bail if neither is present.

    What this header gives you (all under the returned table):
        IS_SEVERE, IS_MATCHA       -- booleans
        Mem.read*  / Mem.write*    -- typed memory access (instance, offset)
        Mem.identity(inst)         -- stable table-key for an Instance
        Notify(msg, level?)        -- "success" / "info" / "error" / "warning"
        IsMouse1Pressed / IsMouse2Pressed
        GetMousePosition()         -- Vector2
        JsonDecode / JsonEncode
        Now()                      -- monotonic seconds
        IsRobloxActive / SetClipboard
        HttpGet(url) / HttpPost(url, data)    -- HttpPost is Severe-only; errors on Matcha
        WorldToScreen(worldPos)    -- (Vector2, boolean), unified shape
        Connect(signal, fn)        -- handles :connect vs :Connect
        Wait(signal)               -- handles :wait vs :Wait
        Once(signal, fn)           -- handles :once vs :Once
        Draw.new(class, props?)    -- creates a drawing with props translated
        Draw.clear()               -- Severe only; no-op on Matcha
]]

----------------------------------------------------- Executor detection

local IS_SEVERE = type(memory) == "table" and type(memory.readu8) == "function"
local IS_MATCHA = type(memory_read) == "function"

if not IS_SEVERE and not IS_MATCHA then
    error("Dual-compat header: neither Severe (memory.*) nor Matcha (memory_*) APIs found")
end

print("[DUAL] Executor:", IS_SEVERE and "Severe" or "Matcha")

----------------------------------------------------- Memory adapter

local Mem = {}

if IS_SEVERE then
    function Mem.readu8(instance, offset)  return memory.readu8(instance, offset)  end
    function Mem.readu16(instance, offset) return memory.readu16(instance, offset) end
    function Mem.readu32(instance, offset) return memory.readu32(instance, offset) end
    function Mem.readu64(instance, offset) return memory.readu64(instance, offset) end
    function Mem.readi8(instance, offset)  return memory.readi8(instance, offset)  end
    function Mem.readi16(instance, offset) return memory.readi16(instance, offset) end
    function Mem.readi32(instance, offset) return memory.readi32(instance, offset) end
    function Mem.readi64(instance, offset) return memory.readi64(instance, offset) end
    function Mem.readf32(instance, offset) return memory.readf32(instance, offset) end
    function Mem.readf64(instance, offset) return memory.readf64(instance, offset) end

    function Mem.readstring(addressOrInstance, offset)
        if offset then
            return memory.readstring(addressOrInstance, offset)
        else
            return memory.readstring(addressOrInstance)
        end
    end

    function Mem.writeu8(instance, offset, value)  memory.writeu8(instance, offset, value)  end
    function Mem.writeu16(instance, offset, value) memory.writeu16(instance, offset, value) end
    function Mem.writeu32(instance, offset, value) memory.writeu32(instance, offset, value) end
    function Mem.writeu64(instance, offset, value) memory.writeu64(instance, offset, value) end
    function Mem.writei8(instance, offset, value)  memory.writei8(instance, offset, value)  end
    function Mem.writei16(instance, offset, value) memory.writei16(instance, offset, value) end
    function Mem.writei32(instance, offset, value) memory.writei32(instance, offset, value) end
    function Mem.writef32(instance, offset, value) memory.writef32(instance, offset, value) end
    function Mem.writef64(instance, offset, value) memory.writef64(instance, offset, value) end

    function Mem.identity(instance)
        return instance
    end

else
    -- Matcha branch: instance.Address + offset -> absolute address.
    local function resolve(instance, offset)
        local addr = instance and instance.Address
        if not addr or addr == 0 then return nil end
        return addr + offset
    end

    function Mem.readu8(instance, offset)
        local a = resolve(instance, offset); if not a then return nil end
        return memory_read("byte", a)
    end
    function Mem.readi8(instance, offset)
        local a = resolve(instance, offset); if not a then return nil end
        local v = memory_read("byte", a)
        if v and v >= 128 then v = v - 256 end
        return v
    end
    function Mem.readu16(instance, offset)
        local a = resolve(instance, offset); if not a then return nil end
        return memory_read("int", a) % 0x10000
    end
    function Mem.readi16(instance, offset)
        local a = resolve(instance, offset); if not a then return nil end
        local v = memory_read("int", a) % 0x10000
        if v >= 0x8000 then v = v - 0x10000 end
        return v
    end
    function Mem.readu32(instance, offset)
        local a = resolve(instance, offset); if not a then return nil end
        return memory_read("int", a)
    end
    function Mem.readi32(instance, offset)
        local a = resolve(instance, offset); if not a then return nil end
        return memory_read("int", a)
    end
    function Mem.readu64(instance, offset)
        local a = resolve(instance, offset); if not a then return nil end
        return memory_read("uintptr_t", a)
    end
    function Mem.readi64(instance, offset)
        local a = resolve(instance, offset); if not a then return nil end
        return memory_read("uintptr_t", a)
    end
    function Mem.readf32(instance, offset)
        local a = resolve(instance, offset); if not a then return nil end
        return memory_read("float", a)
    end
    function Mem.readf64(instance, offset)
        local a = resolve(instance, offset); if not a then return nil end
        return memory_read("double", a)
    end

    function Mem.readstring(addressOrInstance, offset)
        if offset then
            local a = resolve(addressOrInstance, offset); if not a then return nil end
            return memory_read("string", a)
        else
            return memory_read("string", addressOrInstance)
        end
    end

    function Mem.writeu8(instance, offset, value)
        local a = resolve(instance, offset); if not a then return end
        memory_write("byte", a, value)
    end
    function Mem.writei8(instance, offset, value)
        local a = resolve(instance, offset); if not a then return end
        if value < 0 then value = value + 256 end
        memory_write("byte", a, value)
    end
    function Mem.writeu16(instance, offset, value)
        local a = resolve(instance, offset); if not a then return end
        memory_write("int", a, value)
    end
    function Mem.writei16(instance, offset, value)
        local a = resolve(instance, offset); if not a then return end
        memory_write("int", a, value)
    end
    function Mem.writeu32(instance, offset, value)
        local a = resolve(instance, offset); if not a then return end
        memory_write("int", a, value)
    end
    function Mem.writei32(instance, offset, value)
        local a = resolve(instance, offset); if not a then return end
        memory_write("int", a, value)
    end
    function Mem.writeu64(instance, offset, value)
        local a = resolve(instance, offset); if not a then return end
        memory_write("uintptr_t", a, value)
    end
    function Mem.writef32(instance, offset, value)
        local a = resolve(instance, offset); if not a then return end
        memory_write("float", a, value)
    end
    function Mem.writef64(instance, offset, value)
        local a = resolve(instance, offset); if not a then return end
        memory_write("double", a, value)
    end

    function Mem.identity(instance)
        return instance and instance.Address
    end
end

----------------------------------------------------- Notifications

local function Notify(message, level)
    if IS_SEVERE then
        if level then send_notification(message, level)
        else          send_notification(message) end
    else
        local title
        if     level == "error"   then title = "Error"
        elseif level == "warning" then title = "Warning"
        elseif level == "success" then title = "Success"
        elseif level == "info"    then title = "Info"
        else                           title = "Notice"
        end
        notify(message, title, 3)
    end
end

----------------------------------------------------- Mouse / Input

local UserInputService = game:GetService("UserInputService")

local function IsMouse1Pressed()
    if IS_SEVERE then return isleftpressed() end
    return ismouse1pressed()
end

local function IsMouse2Pressed()
    if IS_SEVERE then return isrightpressed() end
    return ismouse2pressed()
end

-- Capture Matcha's mouse handle once at startup. On Severe we use UIS.
local _matchaMouse = nil
if IS_MATCHA then
    local ok, m = pcall(function() return game.Players.LocalPlayer:GetMouse() end)
    if ok then _matchaMouse = m end
end

local function GetMousePosition()
    if IS_SEVERE then
        return UserInputService:GetMouseLocation()
    elseif _matchaMouse then
        return Vector2.new(_matchaMouse.X, _matchaMouse.Y)
    else
        return Vector2.new(0, 0)
    end
end

----------------------------------------------------- JSON

local function JsonDecode(jsonString)
    if IS_SEVERE then
        return crypt.json.decode(jsonString)
    else
        return game:GetService("HttpService"):JSONDecode(jsonString)
    end
end

local function JsonEncode(tbl)
    if IS_SEVERE then
        return crypt.json.encode(tbl)
    else
        return game:GetService("HttpService"):JSONEncode(tbl)
    end
end

----------------------------------------------------- Time

local function Now()
    if tick then return tick() end
    return os.clock()
end

----------------------------------------------------- Misc passthroughs

local function IsRobloxActive() return isrbxactive() end
local function SetClipboard(str) return setclipboard(str) end

----------------------------------------------------- HTTP

-- Both expose game:HttpGet(url). Matcha's docs show a 2nd `content` arg
-- but the single-arg form works on both. We ignore the 2nd arg here.
local function HttpGet(url)
    return game:HttpGet(url)
end

-- HttpPost is Severe-only per the docs. Error loudly on Matcha so the
-- caller knows to use a different transport rather than getting silent nils.
local function HttpPost(url, data)
    if IS_SEVERE then
        return game:HttpPost(url, data)
    else
        error("HttpPost is not available on Matcha")
    end
end

----------------------------------------------------- WorldToScreen

-- Severe: workspace.CurrentCamera:WorldToScreenPoint(pos) -> (Vector3, bool)
--   where the Vector3's X/Y are screen coords and Z is depth.
-- Matcha: WorldToScreen(pos) global -> (Vector2, bool).
-- Unify on (Vector2, boolean).
local _matchaW2S = WorldToScreen  -- capture before we shadow the name
local function WorldToScreenUnified(worldPos)
    if IS_SEVERE then
        local v, visible = workspace.CurrentCamera:WorldToScreenPoint(worldPos)
        return Vector2.new(v.X, v.Y), visible
    else
        return _matchaW2S(worldPos)
    end
end

----------------------------------------------------- Signal helpers

-- Severe Signals use lowercase :connect / :fire / :wait / :once.
-- Matcha (Roblox-style) uses PascalCase :Connect / :Wait / :Once.
-- These helpers pick whichever the signal exposes.

local function Connect(signal, fn)
    if signal.connect then return signal:connect(fn) end
    return signal:Connect(fn)
end

local function Wait(signal)
    if signal.wait then return signal:wait() end
    return signal:Wait()
end

local function Once(signal, fn)
    if signal.once then return signal:once(fn) end
    if signal.Once then return signal:Once(fn) end
    -- Fallback: connect then disconnect on first fire.
    local conn
    conn = Connect(signal, function(...)
        if conn.disconnect then conn:disconnect()
        elseif conn.Disconnect then conn:Disconnect() end
        fn(...)
    end)
    return conn
end

----------------------------------------------------- Drawing wrapper

-- Both executors share Drawing.new(class) and these classes:
--   "Square", "Line", "Circle", "Text", "Triangle"
-- Severe additionally has "Image" and "Polyline".
--
-- Property differences:
--   Severe Text.Font = number index (0..31)
--   Matcha Text.Font = Drawing.Fonts.X enum-ish
--   Severe common: Opacity (0..1)
--   Matcha common: Transparency (0..1, but semantics described as "transparency")
--
-- We accept a generic prop bag and translate. Pass `Font` as a string name
-- ("UI", "System", "Monospace", etc.) and we map it for each executor.

-- Severe font-name -> font index. The Severe doc says Font is in [0,31] but
-- doesn't publish the mapping; we keep this table for forward-compat and
-- default to 0 if the name isn't known. Override these constants in your
-- script if you discover the real indices.
local SEVERE_FONT_INDEX = {
    UI = 0, System = 0, SystemBold = 0,
    Monospace = 0, Pixel = 0, Minecraft = 0, Fortnite = 0, Tamzen = 0,
}

local function _matchaFont(name)
    -- Matcha exposes Drawing.Fonts.X. Fall back to UI if unknown.
    local fonts = Drawing.Fonts or {}
    return fonts[name] or fonts.UI
end

-- Translate a generic prop bag onto a real drawing object.
local function _applyProps(obj, class, props)
    if not props then return obj end

    for k, v in pairs(props) do
        if k == "Font" and class == "Text" then
            if IS_SEVERE then
                if type(v) == "string" then
                    obj.Font = SEVERE_FONT_INDEX[v] or 0
                else
                    obj.Font = v  -- caller passed a number directly
                end
            else
                if type(v) == "string" then
                    obj.Font = _matchaFont(v)
                else
                    obj.Font = v
                end
            end

        elseif k == "Opacity" or k == "Transparency" then
            -- Severe uses Opacity, Matcha uses Transparency.
            -- Treat both inputs as the same scalar (caller's choice of name).
            if IS_SEVERE then
                obj.Opacity = v
            else
                obj.Transparency = v
            end

        else
            obj[k] = v
        end
    end
    return obj
end

local Draw = {}

function Draw.new(class, props)
    -- Guard against Severe-only classes used on Matcha.
    if IS_MATCHA and (class == "Image" or class == "Polyline") then
        error(("Drawing class '%s' is Severe-only; not available on Matcha"):format(class))
    end
    local obj = Drawing.new(class)
    return _applyProps(obj, class, props)
end

-- Drawing.clear() exists on Severe; Matcha's docs don't expose it. No-op there.
function Draw.clear()
    if IS_SEVERE and Drawing.clear then
        Drawing.clear()
    end
end

----------------------------------------------------- Return surface

-- Publishing strategy:
--
-- Both Severe and Matcha sandbox `_G` away from loadstring'd chunks, AND
-- Matcha's loadstring drops the chunk's return value. So neither
-- `local C = loadstring(...)()` nor `_G.DualCompat` works portably.
--
-- The trick: walk up the call stack with getfenv and inject the table
-- into the *caller's* environment as `DualCompat`. After loadstring()()
-- runs, the caller can just reference `DualCompat` as if it were a local.
--
-- We also try a few other publishing channels as belt-and-suspenders:
--   - getgenv() if the executor exposes it (most do)
--   - shared (Roblox-standard cross-script table)
--   - return value (works on Severe, ignored by Matcha)

local API = {
    -- Detection
    IS_SEVERE = IS_SEVERE,
    IS_MATCHA = IS_MATCHA,

    -- Memory
    Mem = Mem,

    -- Notifications
    Notify = Notify,

    -- Input
    IsMouse1Pressed  = IsMouse1Pressed,
    IsMouse2Pressed  = IsMouse2Pressed,
    GetMousePosition = GetMousePosition,

    -- JSON
    JsonDecode = JsonDecode,
    JsonEncode = JsonEncode,

    -- Time / misc
    Now            = Now,
    IsRobloxActive = IsRobloxActive,
    SetClipboard   = SetClipboard,

    -- HTTP
    HttpGet  = HttpGet,
    HttpPost = HttpPost,

    -- World <-> screen
    WorldToScreen = WorldToScreenUnified,

    -- Signals
    Connect = Connect,
    Wait    = Wait,
    Once    = Once,

    -- Drawing
    Draw = Draw,
}

-- 1) getfenv injection: walk up until we find a different env than ours,
--    that's the caller. Plant `DualCompat` there.
do
    local myEnv = getfenv(1)
    local level = 2
    while true do
        local ok, env = pcall(getfenv, level)
        if not ok or not env then break end
        if env ~= myEnv then
            env.DualCompat = API
            break
        end
        level = level + 1
        if level > 10 then break end  -- safety cap
    end
end

-- 2) getgenv() — many executors expose this for cross-script globals.
if type(getgenv) == "function" then
    local ok, genv = pcall(getgenv)
    if ok and type(genv) == "table" then
        genv.DualCompat = API
    end
end

-- 3) shared — Roblox-standard cross-script table. Lowest priority because
--    it's a shared namespace, but it's a useful fallback.
if type(shared) == "table" then
    shared.DualCompat = API
end

-- 4) _G — keep trying, doesn't hurt.
if type(_G) == "table" then
    _G.DualCompat = API
end

print("[DUAL] Compatibility header loaded")

return API
