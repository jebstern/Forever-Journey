-- Forever Journey: quest completion per zone, using QuestieDB when Questie is installed.
-- Questie's own zone-to-quest map is built inside a coroutine so the client never hitches,
-- and completion comes from the game's quest flags. Repeatable quests are excluded; quests made
-- impossible by a completed mutually exclusive quest are counted as unobtainable.
local ADDON_NAME, FJ = ...
local ZQ = FJ:NewModule("ZoneQuests")

local state = "idle"   -- idle | waiting | building | ready | unavailable
local byMap = {}       -- [uiMapID] = { ids = {...}, total, done, unob }
local questZone = {}   -- [questId] = uiMapID
local co, ticker, attempts = nil, nil, 0

local function Modules()
    if not (QuestieLoader and QuestieLoader.ImportModule and Questie and Questie.started) then return nil end
    local ok, ZoneDB, QuestieDB = pcall(function()
        return QuestieLoader:ImportModule("ZoneDB"), QuestieLoader:ImportModule("QuestieDB")
    end)
    if not ok then return nil end
    if not (ZoneDB and ZoneDB.GetZonesWithQuests and ZoneDB.GetUiMapIdByAreaId
        and QuestieDB and QuestieDB.IsRepeatable and QuestieDB.QueryQuestSingle) then
        return nil
    end
    return ZoneDB, QuestieDB
end

function ZQ:Available() return Modules() ~= nil end
function ZQ:State() return state end

local function IsCompleted(questId)
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, questId)
        return ok and done or false
    end
    if Questie and Questie.db and Questie.db.char and Questie.db.char.complete then
        return Questie.db.char.complete[questId] and true or false
    end
    return false
end

local function RecountEntry(QuestieDB, mapID, e)
    if not e then return end
    local done, unob = 0, 0
    for _, id in ipairs(e.ids) do
        if IsCompleted(id) then
            done = done + 1
        else
            local okE, ex = pcall(QuestieDB.QueryQuestSingle, id, "exclusiveTo")
            if okE and type(ex) == "table" then
                for _, other in ipairs(ex) do
                    if IsCompleted(other) then
                        unob = unob + 1
                        break
                    end
                end
            end
        end
    end
    e.total, e.done, e.unob = #e.ids, done, unob
    FJ.db.zoneQuests = FJ.db.zoneQuests or {}
    FJ.db.zoneQuests[mapID] = { t = e.total, d = done, u = unob, at = time() }
end

local function BuildBody()
    local ZoneDB, QuestieDB = Modules()
    local zoneMap = ZoneDB.GetZonesWithQuests(true) -- yields every few hundred quests
    local result, zoneOf = {}, {}
    local count = 0
    for areaId, quests in pairs(zoneMap) do
        local uiMapID
        if type(areaId) == "number" and areaId > 0 then
            local ok, id = pcall(ZoneDB.GetUiMapIdByAreaId, ZoneDB, areaId)
            if ok then uiMapID = id end
        end
        if uiMapID then
            local e = result[uiMapID] or { ids = {} }
            result[uiMapID] = e
            for questId in pairs(quests) do
                local okR, rep = pcall(QuestieDB.IsRepeatable, questId)
                if not (okR and rep) then
                    e.ids[#e.ids + 1] = questId
                    zoneOf[questId] = uiMapID
                end
                count = count + 1
                if count % 300 == 0 then coroutine.yield() end
            end
        end
    end
    for mapID, e in pairs(result) do
        RecountEntry(QuestieDB, mapID, e)
        coroutine.yield()
    end
    return result, zoneOf
end

local function Step()
    if not co then return end
    local ok, a, b = coroutine.resume(co)
    if not ok then
        FJ.Debug("ZoneQuests build failed:", tostring(a))
        state = "unavailable"
        co = nil
        if ticker then ticker:Cancel() ticker = nil end
        return
    end
    if coroutine.status(co) == "dead" then
        byMap, questZone = a or {}, b or {}
        co = nil
        if ticker then ticker:Cancel() ticker = nil end
        state = "ready"
        FJ:NotifyDataChanged()
    end
end

function ZQ:Start()
    if state == "building" or state == "ready" then return end
    if not self:Available() then
        attempts = attempts + 1
        if attempts < 12 and (QuestieLoader or Questie) then
            state = "waiting"
            FJ:After(10, function() ZQ:Start() end)
        else
            state = "unavailable"
        end
        return
    end
    state = "building"
    co = coroutine.create(BuildBody)
    ticker = FJ:NewTicker(0.03, Step)
end

-- total, done, unobtainable, live (false when served from the cached copy)
function ZQ:Get(mapID)
    local e = byMap[mapID]
    if e and e.total then return e.total, e.done, e.unob or 0, true end
    local c = FJ.db.zoneQuests and FJ.db.zoneQuests[mapID]
    if c then return c.t, c.d, c.u or 0, false end
    return nil
end

function ZQ:Percent(mapID)
    local total, done, unob = self:Get(mapID)
    if not total then return nil end
    local possible = total - (unob or 0)
    if possible <= 0 then return 1, total, done, unob end
    return math.min(1, done / possible), total, done, unob
end

function ZQ:OnTurnedIn(questId)
    local mapID = questZone[questId]
    if not mapID then return end
    FJ:Debounce("zq-recount-" .. mapID, 2, function()
        local _, QuestieDB = Modules()
        if QuestieDB and byMap[mapID] then
            RecountEntry(QuestieDB, mapID, byMap[mapID])
            FJ:NotifyDataChanged()
        end
    end)
end

-- Across open-world zones only: total, done, unobtainable, zones with data, zones complete.
function ZQ:Summary()
    local ZoneType = (Enum and Enum.UIMapType and Enum.UIMapType.Zone) or 3
    local total, done, unob, zones, complete = 0, 0, 0, 0, 0
    local source = (state == "ready") and byMap or (FJ.db.zoneQuests or {})
    for mapID, e in pairs(source) do
        local info = FJ.API.MapInfo(mapID)
        local t = e.total or e.t
        local d = e.done or e.d
        local u = e.unob or e.u or 0
        if info and info.mapType == ZoneType and t and t > 0 then
            total, done, unob, zones = total + t, done + d, unob + u, zones + 1
            if d >= t - u then complete = complete + 1 end
        end
    end
    return total, done, unob, zones, complete
end

function ZQ:OnEnable()
    FJ:After(15, function() ZQ:Start() end)
    FJ:RegisterEvent("QUEST_TURNED_IN", function(_, questId) ZQ:OnTurnedIn(questId) end)
end
