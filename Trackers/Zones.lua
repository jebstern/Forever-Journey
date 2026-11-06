-- Forever Journey: current zone, visits, time per zone, discoveries, flight paths, map catalogue.
local ADDON_NAME, FJ = ...
local Zones = FJ:NewModule("Zones")

local UIMapType = Enum and Enum.UIMapType or {}
local TYPE_CONTINENT = UIMapType.Continent or 2
local TYPE_ZONE = UIMapType.Zone or 3
local TYPE_DUNGEON = UIMapType.Dungeon or 4

local currentMapID, currentName, currentIsInstance
local pExplored, pExploredXP
local catalog

---------------------------------------------------------------------------
-- Resolution
---------------------------------------------------------------------------
-- Returns mapID, name, isInstance for the zone-level map the player is in.
function Zones:Resolve()
    if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
    local ok, best = pcall(C_Map.GetBestMapForUnit, "player")
    if not ok or not best then return nil end
    local info = FJ.API.MapInfo(best)
    local guard = 0
    while info and guard < 10 do
        guard = guard + 1
        local mt = info.mapType
        if mt == TYPE_DUNGEON then
            return info.mapID, info.name, true
        elseif mt == TYPE_ZONE then
            return info.mapID, info.name, false
        elseif mt == nil or mt <= TYPE_CONTINENT then
            return nil, info.name, false
        end
        info = FJ.API.MapInfo(info.parentMapID)
    end
    return nil
end

function Zones:Update()
    local mapID, name, isInstance = self:Resolve()
    if not mapID then
        FJ:Debounce("zone-retry", 2, function() Zones:Update() end)
        return
    end
    if isInstance then
        if currentMapID ~= mapID or not currentIsInstance then
            currentMapID, currentName, currentIsInstance = mapID, name, true
            FJ:SendMessage("FJ_ZONE_CHANGED", mapID, name, true)
        end
        return
    end
    currentIsInstance = false
    if mapID ~= currentMapID then
        currentMapID, currentName = mapID, name
        self:Visit(mapID, name)
        FJ:SendMessage("FJ_ZONE_CHANGED", mapID, name, false)
    end
end

function Zones:Visit(mapID, name)
    local db = FJ.db
    local z = db.zones[mapID]
    if not z then
        z = { name = name, first = time(), lvl = UnitLevel("player"), time = 0, q = 0, k = 0, d = 0, disc = 0, visits = 0 }
        db.zones[mapID] = z
        catalog = nil
        -- The very first zone of a fresh install is covered by the "start" entry.
        if db.flags.startRecorded or not db.flags.freshInstall then
            local kind = FJ.Data.Capitals[mapID] and "city" or "zone"
            FJ.Timeline:Add(kind, FJ.Timeline.PRIO[kind], { a = name, z = mapID, zn = name })
        end
    end
    if name then z.name = name end
    z.visits = (z.visits or 0) + 1
    z.prevLast = z.last
    z.last = time()
    FJ:NotifyDataChanged()
end

function Zones:AddTime(dt)
    if currentMapID and not currentIsInstance then
        local z = FJ.db.zones[currentMapID]
        if z then z.time = (z.time or 0) + dt end
    end
end

function Zones:GetCurrent()
    return currentMapID, currentName, currentIsInstance
end

function Zones:VisitedCount()
    return FJ.CountKeys(FJ.db.zones)
end

---------------------------------------------------------------------------
-- Discoveries and flight paths
---------------------------------------------------------------------------
local function BuildPatterns()
    pExplored = FJ.FormatToPattern(ERR_ZONE_EXPLORED)
    pExploredXP = FJ.FormatToPattern(ERR_ZONE_EXPLORED_XP)
end

function Zones:OnInfoMessage(id, msg)
    if type(msg) ~= "string" or not FJ.canaccess(msg) then return end
    if ERR_NEWTAXIPATH and msg == ERR_NEWTAXIPATH then
        self:OnNewTaxiPath()
        return
    end
    local area, xp
    if pExploredXP then area, xp = msg:match(pExploredXP) end
    if not area and pExplored then area = msg:match(pExplored) end
    if area then self:OnDiscovery(area, tonumber(xp)) end
end

function Zones:OnDiscovery(area, xp)
    local db = FJ.db
    db.totals.discoveries = db.totals.discoveries + 1
    local z = currentMapID and not currentIsInstance and db.zones[currentMapID]
    if z then
        z.disc = (z.disc or 0) + 1
        z.discNames = z.discNames or {}
        if #z.discNames < FJ.CAPS.discNames then z.discNames[#z.discNames + 1] = area end
    end
    FJ.Session:Bump("disc", 1)
    if xp and xp > 0 then FJ.Character:AddPendingExploreXP(xp) end
    FJ:NotifyDataChanged()
end

function Zones:OnNewTaxiPath()
    local t = FJ.db.totals
    t.flightPathsFound = (t.flightPathsFound or 0) + 1
    FJ.Timeline:Add("taxi", FJ.Timeline.PRIO.taxi, { a = currentName })
end

function Zones:OnTaxiMapOpened()
    if not (NumTaxiNodes and TaxiNodeGetType and TaxiNodeName) then return end
    local db = FJ.db
    local now = time()
    local added = 0
    local ok, n = pcall(NumTaxiNodes)
    if not ok or type(n) ~= "number" then return end
    for i = 1, n do
        local nodeType = TaxiNodeGetType(i)
        if FJ.canaccess(nodeType) and nodeType ~= "NONE" then
            local name = TaxiNodeName(i)
            if type(name) == "string" and FJ.canaccess(name) and name ~= "" and not db.taxi[name] then
                db.taxi[name] = now
                added = added + 1
            end
        end
    end
    db.flags.taxiScanned = now
    if added > 0 then FJ:NotifyDataChanged() end
end

function Zones:KnownFlightPaths()
    return FJ.CountKeys(FJ.db.taxi)
end

-- Flight path names are "Place, Zone"; returns the known nodes whose zone part matches.
function Zones:FlightPathsInZone(zoneName)
    local out = {}
    if not zoneName then return out end
    for node in pairs(FJ.db.taxi) do
        local zonePart = node:match(",%s*(.+)$")
        if zonePart and zonePart == zoneName then out[#out + 1] = node end
    end
    table.sort(out)
    return out
end

---------------------------------------------------------------------------
-- Flight log: route (from the flight master's node list) and duration (control lost/gained).
---------------------------------------------------------------------------
local pendingRoute, flightStart

local function ShortNode(n)
    return n and (n:match("^([^,]+)") or n) or "?"
end

local function CurrentNodeName()
    if not (NumTaxiNodes and TaxiNodeGetType and TaxiNodeName) then return nil end
    local ok, n = pcall(NumTaxiNodes)
    if not ok or type(n) ~= "number" then return nil end
    for i = 1, n do
        if TaxiNodeGetType(i) == "CURRENT" then
            local name = TaxiNodeName(i)
            if type(name) == "string" and FJ.canaccess(name) then return name end
        end
    end
end

function Zones:OnTakeTaxi(index)
    if not TaxiNodeName then return end
    local ok, dest = pcall(TaxiNodeName, index)
    if not ok or type(dest) ~= "string" or not FJ.canaccess(dest) then return end
    pendingRoute = { from = ShortNode(CurrentNodeName()), to = ShortNode(dest), at = GetTime() }
end

function Zones:OnFlightStart()
    if flightStart then return end
    flightStart = GetTime()
end

function Zones:OnFlightEnd()
    if not flightStart then return end
    local dur = GetTime() - flightStart
    flightStart = nil
    if dur < 5 then return end
    local db = FJ.db
    db.flights = db.flights or {}
    local route = (pendingRoute and (GetTime() - pendingRoute.at) < 7200) and pendingRoute or nil
    local key = route and (route.from .. " > " .. route.to) or "Unknown route"
    local f = db.flights[key]
    if not f then
        f = { n = 0, time = 0, from = route and route.from or nil, to = route and route.to or nil }
        db.flights[key] = f
    end
    f.n = f.n + 1
    f.time = f.time + dur
    f.last = time()
    if dur > (f.longest or 0) then f.longest = dur end
    local t = db.totals
    if dur > (t.longestFlight or 0) then
        t.longestFlight = dur
        t.longestFlightRoute = key
    end
    pendingRoute = nil
    if FJ.CountKeys(db.flights) > 120 then FJ:PruneDB() end
    FJ:NotifyDataChanged()
end

function Zones:IsFlying()
    return flightStart ~= nil
end

-- Routes sorted by times flown: { key, n, time, longest }
function Zones:TopRoutes(n)
    local out = {}
    for key, f in pairs(FJ.db.flights or {}) do
        out[#out + 1] = { key = key, n = f.n or 0, time = f.time or 0, longest = f.longest or 0 }
    end
    table.sort(out, function(a, b) return a.n > b.n end)
    if n then while #out > n do out[#out] = nil end end
    return out
end

---------------------------------------------------------------------------
-- Distance travelled: straight-line distance between heartbeat samples of the player's
-- world position. A lower bound, in yards; flights, teleports and instances are skipped.
---------------------------------------------------------------------------
local lastPos
function Zones:SampleDistance(onTaxi)
    if onTaxi or currentIsInstance or not currentMapID then
        lastPos = nil
        return
    end
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition and C_Map.GetWorldPosFromMapPos) then return end
    local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
    if not ok or not mapID then lastPos = nil return end
    local okP, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
    if not okP or not pos then lastPos = nil return end
    local okW, continent, world = pcall(C_Map.GetWorldPosFromMapPos, mapID, pos)
    if not okW or not world then lastPos = nil return end
    local x, y = world.x, world.y
    if type(x) ~= "number" or type(y) ~= "number" or not FJ.canaccess(x) or not FJ.canaccess(y) then lastPos = nil return end
    if lastPos and lastPos.c == continent then
        local d = math.sqrt((x - lastPos.x) ^ 2 + (y - lastPos.y) ^ 2)
        -- below 900 yards per sample excludes hearthstones, portals and summons
        if d > 0.5 and d < 900 then
            local t = FJ.db.totals
            t.distance = (t.distance or 0) + d
        end
    end
    lastPos = { c = continent, x = x, y = y }
end

---------------------------------------------------------------------------
-- Exploration (needs the per-zone overlay totals in Data/Zones.lua)
---------------------------------------------------------------------------
function Zones:Exploration(mapID)
    local data = FJ.Data.Explore and FJ.Data.Explore[mapID]
    if not data or not (C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures) then return nil end
    local ok, textures = pcall(C_MapExplorationInfo.GetExploredMapTextures, mapID)
    if not ok or type(textures) ~= "table" then return nil end
    local explored = #textures
    return math.min(explored, data.total), data.total
end

---------------------------------------------------------------------------
-- Catalogue of continents and zones (built from the map API, cached per session)
---------------------------------------------------------------------------
function Zones:GetCatalog()
    if catalog then return catalog end
    catalog = {}
    local conts
    if C_Map and C_Map.GetMapChildrenInfo then
        local ok, res = pcall(C_Map.GetMapChildrenInfo, FJ.Data.WorldMapID, TYPE_CONTINENT, false)
        if ok and type(res) == "table" and #res > 0 then conts = res end
    end
    if not conts then
        conts = {}
        for _, id in ipairs(FJ.Data.ContinentFallback) do
            local info = FJ.API.MapInfo(id)
            if info then conts[#conts + 1] = info end
        end
    end
    local known = {}
    for _, c in ipairs(conts) do
        local zones = {}
        if C_Map and C_Map.GetMapChildrenInfo then
            local ok, res = pcall(C_Map.GetMapChildrenInfo, c.mapID, TYPE_ZONE, false)
            if ok and type(res) == "table" then
                for _, z in ipairs(res) do
                    if z.name and z.name ~= "" then
                        zones[#zones + 1] = { mapID = z.mapID, name = z.name }
                        known[z.mapID] = true
                    end
                end
            end
        end
        table.sort(zones, function(a, b) return a.name < b.name end)
        catalog[#catalog + 1] = { mapID = c.mapID, name = c.name or "?", zones = zones }
    end
    table.sort(catalog, function(a, b) return a.name < b.name end)

    local other = {}
    for id, z in pairs(FJ.db.zones) do
        if not known[id] then other[#other + 1] = { mapID = id, name = z.name or ("Map " .. id) } end
    end
    if #other > 0 then
        table.sort(other, function(a, b) return a.name < b.name end)
        catalog[#catalog + 1] = { mapID = 0, name = "Elsewhere", zones = other }
    end
    return catalog
end

function Zones:InvalidateCatalog()
    catalog = nil
end

---------------------------------------------------------------------------
-- Wiring
---------------------------------------------------------------------------
function Zones:OnInit()
    BuildPatterns()
end

function Zones:OnEnable()
    if TakeTaxiNode and not self.taxiHooked then
        self.taxiHooked = true
        hooksecurefunc("TakeTaxiNode", function(index) Zones:OnTakeTaxi(index) end)
    end
    -- Flights begin with control lost and end with control regained; the heartbeat is the fallback.
    -- UnitOnTaxi can return a secret boolean; when it does, do nothing and let the heartbeat decide.
    FJ:RegisterEvent("PLAYER_CONTROL_LOST", function()
        FJ:After(0.5, function() if FJ.Bool(UnitOnTaxi("player")) == true then Zones:OnFlightStart() end end)
    end)
    FJ:RegisterEvent("PLAYER_CONTROL_GAINED", function()
        FJ:After(0.5, function() if FJ.Bool(UnitOnTaxi("player")) == false then Zones:OnFlightEnd() end end)
    end)
end

function Zones:OnEnteringWorld()
    FJ:After(1, function() Zones:Update() end)
end

local function OnZoneEvent()
    FJ:Debounce("zone-update", 0.5, function() Zones:Update() end)
end
FJ:RegisterEvent("ZONE_CHANGED_NEW_AREA", OnZoneEvent)
FJ:RegisterEvent("ZONE_CHANGED", OnZoneEvent)
FJ:RegisterEvent("ZONE_CHANGED_INDOORS", OnZoneEvent)
FJ:RegisterEvent("UI_INFO_MESSAGE", function(_, id, msg) Zones:OnInfoMessage(id, msg) end)
FJ:RegisterEvent("TAXIMAP_OPENED", function() FJ:After(0.5, function() Zones:OnTaxiMapOpened() end) end)
