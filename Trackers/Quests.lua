-- Forever Journey: quest turn-ins, lifetime completed count, quest log summary.
local ADDON_NAME, FJ = ...
local Quests = FJ:NewModule("Quests")

local MILESTONES = { 10, 25, 50, 100, 150, 200, 250, 300, 400, 500, 600, 700, 800, 900, 1000 }

function Quests:MilestoneFor(total)
    local best
    for _, m in ipairs(MILESTONES) do
        if total >= m then best = m end
    end
    if total >= 1000 then best = math.floor(total / 500) * 500 end
    return best
end

-- Lifetime completed quests from the game itself (includes everything before install).
function Quests:RefreshCompletedCount()
    local n
    if C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs then
        local ok, ids = pcall(C_QuestLog.GetAllCompletedQuestIDs)
        if ok and type(ids) == "table" then n = #ids end
    elseif GetQuestsCompleted then
        if QueryQuestsCompleted and not self.queried then
            self.queried = true
            FJ:RegisterEvent("QUEST_QUERY_COMPLETE", function() Quests:RefreshCompletedCount() end)
            pcall(QueryQuestsCompleted)
            return
        end
        local ok, t = pcall(GetQuestsCompleted)
        if ok and type(t) == "table" then n = FJ.CountKeys(t) end
    end
    if not n then return end
    local tot = FJ.db.totals
    tot.questsAPI = n
    tot.questsAPIAt = time()
    if tot.questsBaseline == nil then
        tot.questsBaseline = math.max(0, n - (tot.quests or 0))
        local ms = self:MilestoneFor(n)
        if ms and (FJ.db.flags.questMs or 0) < ms then FJ.db.flags.questMs = ms end
    end
    FJ:NotifyDataChanged()
end

-- The game's own "Quests completed" statistic is the headline number when the client has it;
-- the completed-ID list also contains hidden tracking quests and is kept for the tooltip.
function Quests:GetTotal()
    local life = FJ.Lifetime and FJ.Lifetime:Value("quests")
    if life then return life end
    local tot = FJ.db.totals
    if tot.questsAPI then return tot.questsAPI end
    return (tot.questsBaseline or 0) + (tot.quests or 0)
end

function Quests:OnTurnedIn(questID, xp, money)
    local db = FJ.db
    local tot = db.totals
    tot.quests = tot.quests + 1
    if tot.questsAPI then tot.questsAPI = tot.questsAPI + 1 end

    local mapID = FJ.Zones:GetCurrent()
    local z = mapID and db.zones[mapID]
    if z then z.q = (z.q or 0) + 1 end
    local L = db.levels[UnitLevel("player")]
    if L then L.q = (L.q or 0) + 1 end
    FJ.Session:Bump("q", 1)
    if type(xp) == "number" and xp > 0 then FJ.Character:AddPendingQuestXP(xp) end
    if type(money) == "number" and money > 0 then FJ.Character:AddPendingQuestMoney(money) end

    local total = self:GetTotal()
    local P = FJ.Timeline.PRIO
    if total == 1 and tot.quests == 1 then
        FJ.Timeline:Add("quest_first", P.quest_first)
    end
    local ms = self:MilestoneFor(total)
    if ms and (db.flags.questMs or 0) < ms then
        db.flags.questMs = ms
        FJ.Timeline:Add("quests", P.quests, { a = ms })
    end
    FJ:NotifyDataChanged()
end

function Quests:OnAccepted()
    local tot = FJ.db.totals
    tot.questsAccepted = (tot.questsAccepted or 0) + 1
end

-- Quest log grouped by header (zone). Collapsed headers are reported as such but their quests are hidden by the game.
function Quests:GetLogByZone()
    local groups, order = {}, {}
    local numEntries = 0
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
        numEntries = C_QuestLog.GetNumQuestLogEntries() or 0
    elseif GetNumQuestLogEntries then
        numEntries = GetNumQuestLogEntries() or 0
    end
    local header = "Other"
    for i = 1, numEntries do
        local title, level, isHeader, isComplete, questID
        if C_QuestLog and C_QuestLog.GetInfo then
            local info = C_QuestLog.GetInfo(i)
            if info then
                title, level, isHeader, questID = info.title, info.level, info.isHeader, info.questID
                if not isHeader and questID then
                    if C_QuestLog.ReadyForTurnIn then
                        isComplete = C_QuestLog.ReadyForTurnIn(questID)
                    elseif C_QuestLog.IsComplete then
                        isComplete = C_QuestLog.IsComplete(questID)
                    end
                end
            end
        elseif GetQuestLogTitle then
            local t, l, _, h, _, c, _, id = GetQuestLogTitle(i)
            title, level, isHeader, questID = t, l, h, id
            isComplete = (c == 1 or c == true)
        end
        if title and FJ.canaccess(title) then
            if isHeader then
                header = title
            else
                local g = groups[header]
                if not g then
                    g = { name = header, n = 0, complete = 0, quests = {} }
                    groups[header] = g
                    order[#order + 1] = g
                end
                g.n = g.n + 1
                if isComplete then g.complete = g.complete + 1 end
                g.quests[#g.quests + 1] = { title = title, level = level, complete = isComplete and true or false, id = questID }
            end
        end
    end
    return order
end

function Quests:OnEnable()
    FJ:After(3, function() Quests:RefreshCompletedCount() end)
end

FJ:RegisterEvent("QUEST_TURNED_IN", function(_, questID, xp, money) Quests:OnTurnedIn(questID, xp, money) end)
FJ:RegisterEvent("QUEST_ACCEPTED", function() Quests:OnAccepted() end)
