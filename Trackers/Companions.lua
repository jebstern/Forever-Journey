-- Forever Journey: adventuring companions. Who you grouped with, how often and for how long.
-- Names can be secret inside instances on this client; those ticks are simply skipped, so
-- the time counted is the open-world time around runs plus whatever the client allows.
local ADDON_NAME, FJ = ...
local Companions = FJ:NewModule("Companions")

local roster = {}        -- names seen in the current group snapshot
local inGroup = false

local function GroupUnits()
    local units = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do units[#units + 1] = "raid" .. i end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do units[#units + 1] = "party" .. i end
    end
    return units
end

local function UnitDisplayName(unit)
    local name, realm
    if GetUnitName then
        name = GetUnitName(unit, true)
    else
        name, realm = UnitName(unit)
        if name and realm and realm ~= "" then name = name .. "-" .. realm end
    end
    if type(name) ~= "string" or not FJ.canaccess(name) or name == "" or name == UNKNOWNOBJECT then return nil end
    if name == FJ.playerName or name == FJ.charKey then return nil end
    return name
end

-- Called on roster changes: notes new members as a new "time grouped together".
function Companions:OnRoster()
    local db = FJ.db
    db.companions = db.companions or {}
    local now = time()
    local seen = {}
    local units = GroupUnits()
    for _, unit in ipairs(units) do
        if FJ.Bool(UnitExists(unit)) and FJ.Bool(UnitIsPlayer(unit)) then
            local name = UnitDisplayName(unit)
            if name then
                seen[name] = true
                local c = db.companions[name]
                if not c then
                    c = { time = 0, n = 0, first = now }
                    db.companions[name] = c
                    if FJ.CountKeys(db.companions) > FJ.CAPS.companions + 20 then FJ:PruneDB() end
                end
                if not roster[name] then c.n = (c.n or 0) + 1 end
                local _, classFile = UnitClass(unit)
                if classFile and FJ.canaccess(classFile) then c.class = classFile end
                c.last = now
            end
        end
    end
    roster = seen
    local was = inGroup
    inGroup = next(seen) ~= nil
    if inGroup and not was and not db.flags.firstGroup then
        db.flags.firstGroup = now
        FJ.Timeline:Add("group", 50, {})
    end
    FJ:NotifyDataChanged()
end

-- Heartbeat: time together.
function Companions:OnTick(dt)
    if not inGroup then return end
    local db = FJ.db
    for _, unit in ipairs(GroupUnits()) do
        if FJ.Bool(UnitExists(unit)) and FJ.Bool(UnitIsPlayer(unit)) then
            local name = UnitDisplayName(unit)
            local c = name and db.companions[name]
            if c then
                c.time = (c.time or 0) + dt
                c.last = time()
            end
        end
    end
    db.totals.groupTime = (db.totals.groupTime or 0) + dt
end

-- Names of the people currently in your group (that the client lets us read).
function Companions:CurrentNames()
    local out = {}
    for _, unit in ipairs(GroupUnits()) do
        if FJ.Bool(UnitExists(unit)) and FJ.Bool(UnitIsPlayer(unit)) then
            local name = UnitDisplayName(unit)
            if name then out[#out + 1] = name end
        end
    end
    return out
end

-- Sorted list { name, time, n, class, first, last }
function Companions:List(n)
    local out = {}
    for name, c in pairs(FJ.db.companions or {}) do
        out[#out + 1] = { name = name, time = c.time or 0, n = c.n or 0, class = c.class, first = c.first, last = c.last }
    end
    table.sort(out, function(a, b) return a.time > b.time end)
    if n then while #out > n do out[#out] = nil end end
    return out
end

function Companions:Count()
    return FJ.CountKeys(FJ.db.companions or {})
end

function Companions:OnEnable()
    FJ:RegisterEvent("GROUP_ROSTER_UPDATE", function() FJ:Debounce("roster", 1, function() Companions:OnRoster() end) end)
    FJ:RegisterEvent("GROUP_JOINED", function() FJ:Debounce("roster", 1, function() Companions:OnRoster() end) end)
    FJ:RegisterEvent("GROUP_LEFT", function() FJ:Debounce("roster", 1, function() Companions:OnRoster() end) end)
    FJ:RegisterMessage("FJ_TICK", function(_, dt) Companions:OnTick(dt) end)
    FJ:After(5, function() Companions:OnRoster() end)
end
