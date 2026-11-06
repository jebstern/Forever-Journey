-- Forever Journey: gear story (what you wore and for how long), hearthstone homes, first ride.
local ADDON_NAME, FJ = ...
local Gear = FJ:NewModule("Gear")

local SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }
Gear.SLOT_NAMES = {
    [1] = "Head", [2] = "Neck", [3] = "Shoulders", [5] = "Chest", [6] = "Waist", [7] = "Legs", [8] = "Feet",
    [9] = "Wrists", [10] = "Hands", [11] = "Ring", [12] = "Ring", [13] = "Trinket", [14] = "Trinket",
    [15] = "Back", [16] = "Main hand", [17] = "Off hand", [18] = "Ranged",
}

local function ItemID(link)
    return link and tonumber(link:match("item:(%d+)")) or nil
end

local function Current(slot)
    local link = GetInventoryItemLink("player", slot)
    if type(link) ~= "string" or not FJ.canaccess(link) then return nil end
    return link, ItemID(link)
end

local function Played()
    return FJ.Session:GetPlayed()
end

---------------------------------------------------------------------------
-- Equipment
---------------------------------------------------------------------------
-- initial: the first scan of a session records what is worn without counting a change.
function Gear:Scan(initial)
    local db = FJ.db
    db.gear = db.gear or {}
    db.gearHistory = db.gearHistory or {}
    local now, played = time(), Played()
    local changed = false
    for _, slot in ipairs(SLOTS) do
        local link, id = Current(slot)
        local prev = db.gear[slot]
        local prevID = prev and prev.id or nil
        if prevID ~= id then
            if prev and prevID then
                local worn = math.max(0, played - (prev.since or played))
                local h = db.gearHistory[prevID]
                if not h then
                    h = { link = prev.link, worn = 0, first = prev.t or now, slot = slot }
                    db.gearHistory[prevID] = h
                end
                h.worn = (h.worn or 0) + worn
                h.link = prev.link or h.link
                h.last = now
            end
            if id then
                db.gear[slot] = { id = id, link = link, since = played, t = now, lvl = UnitLevel("player") }
                if not initial then
                    db.totals.gearChanges = (db.totals.gearChanges or 0) + 1
                    local hex = link:match("|c%x%x(%x%x%x%x%x%x)")
                    hex = hex and hex:lower()
                    if (hex == "a335ee" or hex == "ff8000") and not db.gearHistory[id] then
                        FJ.Timeline:Add("gear", 55, { a = link })
                    end
                end
            else
                db.gear[slot] = nil
            end
            changed = true
        end
    end
    if FJ.CountKeys(db.gearHistory) > FJ.CAPS.gearHistory + 20 then FJ:PruneDB() end
    if changed then FJ:NotifyDataChanged() end
end

function Gear:AverageItemLevel()
    local total, n = 0, 0
    for _, slot in ipairs(SLOTS) do
        local g = FJ.db.gear and FJ.db.gear[slot]
        if g and g.link then
            local _, _, _, ilvl = FJ.API.GetItemInfo(g.link)
            if type(ilvl) == "number" and FJ.canaccess(ilvl) then total, n = total + ilvl, n + 1 end
        end
    end
    if n == 0 then return nil, 0 end
    return total / n, n
end

-- Worn time of an item, including the current stint if it is equipped.
local function WornTotal(id, played)
    local db = FJ.db
    local worn = (db.gearHistory[id] and db.gearHistory[id].worn) or 0
    for _, g in pairs(db.gear or {}) do
        if g.id == id then worn = worn + math.max(0, played - (g.since or played)) end
    end
    return worn
end

-- { link, worn, current } for the item worn longest, measured in played time.
function Gear:LongestWorn()
    local db = FJ.db
    local played = Played()
    local best, seen = nil, {}
    for id, h in pairs(db.gearHistory or {}) do
        seen[id] = true
        local worn = WornTotal(id, played)
        if not best or worn > best.worn then best = { link = h.link, worn = worn, id = id } end
    end
    for _, g in pairs(db.gear or {}) do
        if g.id and not seen[g.id] then
            seen[g.id] = true
            local worn = WornTotal(g.id, played)
            if not best or worn > best.worn then best = { link = g.link, worn = worn, id = g.id, current = true } end
        end
    end
    if best then
        for _, g in pairs(db.gear or {}) do
            if g.id == best.id then best.current = true end
        end
    end
    return best
end

-- Current items sorted by how long they have been worn.
function Gear:CurrentGear()
    local out = {}
    local played = Played()
    for slot, g in pairs(FJ.db.gear or {}) do
        out[#out + 1] = { slot = slot, slotName = Gear.SLOT_NAMES[slot] or tostring(slot), link = g.link, id = g.id, worn = WornTotal(g.id, played), lvl = g.lvl }
    end
    table.sort(out, function(a, b) return a.worn > b.worn end)
    return out
end

---------------------------------------------------------------------------
-- Homes (hearthstone binds)
---------------------------------------------------------------------------
local boundPattern
function Gear:CheckHome(forcedName)
    local db = FJ.db
    db.homes = db.homes or {}
    local name = forcedName
    if not name and GetBindLocation then
        local ok, loc = pcall(GetBindLocation)
        if ok and type(loc) == "string" and FJ.canaccess(loc) and loc ~= "" then name = loc end
    end
    if not name then return end
    local last = db.homes[#db.homes]
    if last and last.name == name then return end
    FJ.PushCapped(db.homes, { name = name, t = time(), lvl = UnitLevel("player") }, FJ.CAPS.homes)
    if last then FJ.Timeline:Add("home", 55, { a = name }) end
    FJ:NotifyDataChanged()
end

function Gear:OnSystemMessage(msg)
    if type(msg) ~= "string" or not FJ.canaccess(msg) then return end
    if boundPattern == nil then boundPattern = FJ.FormatToPattern(ERR_DEATHBIND_SUCCESS_S) or false end
    if not boundPattern then return end
    local name = msg:match(boundPattern)
    if name then self:CheckHome(name) end
end

function Gear:CurrentHome()
    local homes = FJ.db.homes or {}
    local last = homes[#homes]
    return last and last.name or nil, #homes
end

---------------------------------------------------------------------------
-- Riding
---------------------------------------------------------------------------
function Gear:OnTick(dt)
    if not IsMounted or not FJ.Bool(IsMounted()) then return end
    local db = FJ.db
    db.totals.mountedTime = (db.totals.mountedTime or 0) + dt
    if not db.flags.firstRide then
        db.flags.firstRide = time()
        FJ.Timeline:Add("ride", 60, {})
    end
end

---------------------------------------------------------------------------
-- Wiring
---------------------------------------------------------------------------
function Gear:OnEnable()
    FJ:After(4, function() Gear:Scan(true) end)
    FJ:After(8, function() Gear:CheckHome() end)
    FJ:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function()
        FJ:Debounce("gear-scan", 1, function() Gear:Scan(false) end)
    end)
    FJ:RegisterEvent("PLAYER_LEVEL_UP", function(_, level)
        FJ:After(2, function()
            local avg = Gear:AverageItemLevel()
            local L = FJ.db.levels[tonumber(level) or UnitLevel("player")]
            if L and avg then L.ilvl = FJ.Round(avg, 1) end
        end)
    end)
    FJ:RegisterEvent("HEARTHSTONE_BOUND", function() FJ:After(1, function() Gear:CheckHome() end) end)
    FJ:RegisterEvent("CHAT_MSG_SYSTEM", function(_, msg) Gear:OnSystemMessage(msg) end)
    FJ:RegisterMessage("FJ_TICK", function(_, dt) Gear:OnTick(dt) end)
end

function Gear:OnLogout()
    -- close the current stints so worn time survives the session
    local db = FJ.db
    if not db.gear then return end
    local played = Played()
    for slot, g in pairs(db.gear) do
        if g.id then
            local h = db.gearHistory[g.id]
            if not h then
                h = { link = g.link, worn = 0, first = g.t, slot = slot }
                db.gearHistory[g.id] = h
            end
            h.worn = (h.worn or 0) + math.max(0, played - (g.since or played))
            g.since = played
        end
    end
end
