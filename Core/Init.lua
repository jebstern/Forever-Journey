-- Forever Journey: shared namespace, client detection and small utilities.
local ADDON_NAME, FJ = ...
_G.ForeverJourney = FJ

FJ.name = ADDON_NAME

local function GetMeta(field)
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(ADDON_NAME, field)
    elseif GetAddOnMetadata then
        return GetAddOnMetadata(ADDON_NAME, field)
    end
end
-- The CurseForge packager replaces @project-version@ in the TOC with the git tag (v0.1.0).
-- Running from source leaves the keyword in place, which counts as a dev build.
do
    local version = GetMeta("Version")
    if type(version) ~= "string" or version == "" or version:find("@", 1, true) then
        version = "dev"
    end
    FJ.version = (version:gsub("^[vV]", ""))
end

do
    local _, build, _, toc = GetBuildInfo()
    FJ.build = tonumber(build) or 0
    FJ.toc = tonumber(toc) or 0
end
FJ.IsForever = FJ.toc >= 16000 and FJ.toc < 17000
FJ.HasRetailAPI = (WOW_PROJECT_ID ~= nil and WOW_PROJECT_MAINLINE ~= nil and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)

-- 12.0-style secret values. Both helpers exist on Forever; fall back to permissive stubs elsewhere.
FJ.canaccess = _G.canaccessvalue or function() return true end
FJ.issecret = _G.issecretvalue or function() return false end

-- Boolean test that tolerates secret values. Verified in-game (4 Oct 2026): unit-state predicates
-- such as UnitIsAFK("player") return a secret boolean in some contexts on Forever, and `if v then`
-- on one raises "attempt to perform boolean test on a secret boolean value". Returns true/false,
-- or `default` (nil unless given) when the value cannot be read.
function FJ.Bool(v, default)
    if not FJ.canaccess(v) then return default end
    return v and true or false
end

-- On Forever (as on Retail 12.0) registering COMBAT_LOG_EVENT_UNFILTERED is a protected action
-- and raises ADDON_ACTION_FORBIDDEN. Never attempt it there; chat and encounter events are used instead.
FJ.RestrictedCombatLog = FJ.IsForever or (_G.C_Secrets ~= nil)

FJ.debug = false

-- Keybinding strings (Bindings.xml)
BINDING_HEADER_FOREVERJOURNEY = "Forever Journey"
BINDING_NAME_FOREVERJOURNEY_TOGGLE = "Toggle Forever Journey"

---------------------------------------------------------------------------
-- Module registry
---------------------------------------------------------------------------
FJ.modules = {}
FJ.moduleList = {}

function FJ:NewModule(name)
    local m = { name = name }
    self.modules[name] = m
    self.moduleList[#self.moduleList + 1] = m
    self[name] = m
    return m
end

-- Calls method on every module that defines it. Errors in one module never stop the others.
function FJ:CallModules(method, ...)
    for i = 1, #self.moduleList do
        local m = self.moduleList[i]
        local fn = m[method]
        if fn then
            local ok, err = pcall(fn, m, ...)
            if not ok then FJ.Error(m.name .. ":" .. method .. " - " .. tostring(err)) end
        end
    end
end

---------------------------------------------------------------------------
-- Output
---------------------------------------------------------------------------
function FJ.Print(...)
    print("|cffffd200Forever Journey:|r", ...)
end

function FJ.Debug(...)
    if FJ.debug then print("|cff9999ffFJ debug:|r", ...) end
end

function FJ.Error(...)
    print("|cffff6060Forever Journey error:|r", ...)
end

---------------------------------------------------------------------------
-- Numbers and time
---------------------------------------------------------------------------
function FJ.Round(n, decimals)
    local m = 10 ^ (decimals or 0)
    return math.floor((n or 0) * m + 0.5) / m
end

function FJ.Clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
end

function FJ.FormatNumber(n)
    n = math.floor((tonumber(n) or 0) + 0.5)
    local s = tostring(math.abs(n))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    out = out:gsub("^,", "")
    return (n < 0 and "-" or "") .. out
end

-- Compact number: 1842 -> "1.8k" above 10k, otherwise thousands separators.
function FJ.FormatCompact(n)
    n = tonumber(n) or 0
    if math.abs(n) >= 1000000 then return format("%.1fm", n / 1000000) end
    if math.abs(n) >= 10000 then return format("%.1fk", n / 1000) end
    return FJ.FormatNumber(n)
end

-- style: nil/"short" -> "3d 14h", "14h 22m", "22m", "45s"; "long" adds one more unit; "hours" -> "42.5 h"
function FJ.FormatDuration(sec, style)
    sec = math.max(0, math.floor(tonumber(sec) or 0))
    if style == "hours" then return format("%.1f h", sec / 3600) end
    local d = math.floor(sec / 86400)
    local h = math.floor((sec % 86400) / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = sec % 60
    if d > 0 then
        if style == "long" then return format("%dd %dh %dm", d, h, m) end
        return format("%dd %dh", d, h)
    end
    if h > 0 then return format("%dh %dm", h, m) end
    if m > 0 then
        if style == "long" then return format("%dm %ds", m, s) end
        return format("%dm", m)
    end
    return format("%ds", s)
end

function FJ.FormatMoney(copper, compact)
    copper = math.floor(tonumber(copper) or 0)
    local neg = copper < 0
    copper = math.abs(copper)
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    local out
    if g > 0 then
        out = format("|cffffd700%sg|r", FJ.FormatNumber(g))
        if not compact then out = out .. format(" |cffc7c7cf%ds|r", s) end
    elseif s > 0 then
        out = format("|cffc7c7cf%ds|r", s)
        if not compact then out = out .. format(" |cffeda55f%dc|r", c) end
    else
        out = format("|cffeda55f%dc|r", c)
    end
    return (neg and "-" or "") .. out
end

function FJ.FormatDate(t)
    if not t or t == 0 then return "unknown" end
    return date("%d %b %Y", t)
end

function FJ.FormatDateTime(t)
    if not t or t == 0 then return "unknown" end
    return date("%d %b %Y, %H:%M", t)
end

function FJ.RelativeDay(t)
    if not t or t == 0 then return "unknown" end
    local now = time()
    local that = date("%Y-%m-%d", t)
    if date("%Y-%m-%d", now) == that then return "Today" end
    if date("%Y-%m-%d", now - 86400) == that then return "Yesterday" end
    local days = math.floor((now - t) / 86400)
    if days < 7 then return days .. " days ago" end
    return FJ.FormatDate(t)
end

function FJ.Percent(part, whole)
    if not whole or whole <= 0 then return 0 end
    return FJ.Clamp(part / whole, 0, 1)
end

function FJ.Ordinal(n)
    n = tonumber(n) or 0
    local tail = n % 100
    if tail >= 11 and tail <= 13 then return n .. "th" end
    local last = n % 10
    if last == 1 then return n .. "st" elseif last == 2 then return n .. "nd" elseif last == 3 then return n .. "rd" end
    return n .. "th"
end

---------------------------------------------------------------------------
-- Colours
---------------------------------------------------------------------------
function FJ.Hex(r, g, b)
    return format("ff%02x%02x%02x", FJ.Clamp(r, 0, 1) * 255, FJ.Clamp(g, 0, 1) * 255, FJ.Clamp(b, 0, 1) * 255)
end

function FJ.Colorize(text, hex)
    return "|c" .. hex .. tostring(text) .. "|r"
end

function FJ.ClassColor(classFile)
    classFile = classFile or FJ.playerClassFile
    local c = classFile and ((CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classFile]) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]))
    if c then
        return c.r, c.g, c.b, c.colorStr or FJ.Hex(c.r, c.g, c.b)
    end
    return 1, 0.82, 0.2, "ffffd200"
end

---------------------------------------------------------------------------
-- Strings
---------------------------------------------------------------------------
-- Turns a Blizzard format string ("Discovered %s: %d experience gained") into a Lua pattern.
function FJ.FormatToPattern(fmt)
    if type(fmt) ~= "string" then return nil end
    local p = fmt:gsub("%%%d%$", "%%")                       -- %1$s -> %s
    p = p:gsub("([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")          -- escape magic characters
    p = p:gsub("%%s", "(.-)")
    p = p:gsub("%%d", "(%%d+)")
    return "^" .. p .. "$"
end

function FJ.Trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

function FJ.NpcIDFromGUID(guid)
    if type(guid) ~= "string" then return nil end
    local unitType, _, _, _, _, npcID = strsplit("-", guid)
    if unitType == "Creature" or unitType == "Vehicle" then
        return tonumber(npcID)
    end
    return nil
end

function FJ.CountKeys(t)
    local n = 0
    if type(t) == "table" then for _ in pairs(t) do n = n + 1 end end
    return n
end

function FJ.PushCapped(list, item, cap)
    list[#list + 1] = item
    while #list > cap do table.remove(list, 1) end
end

-- Sorted array of {key = k, value = v} by numeric field, descending.
function FJ.TopN(tbl, field, n, filter)
    local out = {}
    for k, v in pairs(tbl or {}) do
        local val = field and (type(v) == "table" and v[field] or nil) or v
        if type(val) == "number" and val > 0 and (not filter or filter(k, v)) then
            out[#out + 1] = { key = k, value = val, data = v }
        end
    end
    table.sort(out, function(a, b) return a.value > b.value end)
    if n then while #out > n do out[#out] = nil end end
    return out
end

---------------------------------------------------------------------------
-- API compatibility wrappers
---------------------------------------------------------------------------
FJ.API = {}

function FJ.API.GetItemInfo(item)
    if C_Item and C_Item.GetItemInfo then return C_Item.GetItemInfo(item) end
    if GetItemInfo then return GetItemInfo(item) end
end

function FJ.API.GetItemIcon(item)
    if C_Item and C_Item.GetItemIconByID then return C_Item.GetItemIconByID(item) end
    if GetItemIcon then return GetItemIcon(item) end
end

function FJ.API.MaxLevel()
    if GetMaxPlayerLevel then
        local ok, v = pcall(GetMaxPlayerLevel)
        if ok and type(v) == "number" and v > 0 then return v end
    end
    return MAX_PLAYER_LEVEL or 60
end

function FJ.API.PlaySound(kit, fallback)
    if not PlaySound then return end
    local id = (SOUNDKIT and SOUNDKIT[kit]) or fallback
    if id then pcall(PlaySound, id) end
end

function FJ.API.MapInfo(mapID)
    if mapID and C_Map and C_Map.GetMapInfo then
        local ok, info = pcall(C_Map.GetMapInfo, mapID)
        if ok then return info end
    end
end
