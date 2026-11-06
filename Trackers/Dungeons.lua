-- Forever Journey: dungeon and raid runs.
local ADDON_NAME, FJ = ...
local Dungeons = FJ:NewModule("Dungeons")

local RESUME_WINDOW = 1800 -- a relog inside the same instance continues the run
local MIN_RUN = 120        -- shorter visits without a boss kill are ignored

local cur

function Dungeons:Check()
    local db = FJ.db
    if not cur and db.run then cur = db.run end
    local inInst, instType = IsInInstance()
    if inInst and (instType == "party" or instType == "raid") then
        local name = GetInstanceInfo()
        if not (FJ.canaccess(name) and type(name) == "string") then name = "Instance" end
        if cur then
            if cur.name == name and (time() - (cur.last or 0)) <= RESUME_WINDOW then
                cur.last = time()
                return
            end
            self:EndRun()
        end
        self:StartRun(name, instType)
    elseif cur then
        self:EndRun()
    end
end

function Dungeons:StartRun(name, instType)
    local db = FJ.db
    local now = time()
    cur = {
        name = name, type = instType, start = now, last = now, time = 0,
        bosses = 0, deaths = 0, kills = 0, lvl = UnitLevel("player"), completed = false,
    }
    db.run = cur
    if not db.dungeons[name] then
        db.dungeons[name] = { runs = 0, done = 0, time = 0, bosses = 0, first = now, raid = (instType == "raid") or nil }
        FJ.Timeline:Add("dungeon_first", FJ.Timeline.PRIO.dungeon_first, { a = name, zn = name })
    end
    FJ:SendMessage("FJ_RUN_STARTED", cur)
    FJ:NotifyDataChanged()
end

function Dungeons:AddTime(dt, now)
    if cur then
        cur.time = (cur.time or 0) + dt
        cur.last = now or time()
        -- who is along for the run
        if FJ.Companions and FJ.Companions.CurrentNames then
            cur.party = cur.party or {}
            for _, name in ipairs(FJ.Companions:CurrentNames()) do cur.party[name] = true end
        end
    end
end

function Dungeons:OnDeath()
    if cur then cur.deaths = (cur.deaths or 0) + 1 end
end

function Dungeons:OnKill()
    if cur then cur.kills = (cur.kills or 0) + 1 end
end

function Dungeons:OnBossKilled(npcID, boss, name)
    if not cur then return end
    cur.bosses = (cur.bosses or 0) + 1
    local d = FJ.db.dungeons[cur.name]
    if d then d.bosses = (d.bosses or 0) + 1 end
    if boss.f and not cur.completed then
        cur.completed = true
        cur.completedAt = time()
        self:RecordCompletion()
    end
end

function Dungeons:RecordCompletion()
    local db = FJ.db
    local d = db.dungeons[cur.name]
    if not d then return end
    local dur = (cur.time and cur.time > 0) and cur.time or (time() - cur.start)
    d.done = (d.done or 0) + 1
    db.totals.dungeonsCompleted = db.totals.dungeonsCompleted + 1
    local prevBest = d.best
    if not d.best or dur < d.best then d.best = dur end
    local P = FJ.Timeline.PRIO
    FJ.Timeline:Add("dungeon_done", (d.done == 1) and P.dungeon_done_first or P.dungeon_done,
        { a = cur.name, b = dur, c = cur.bosses, zn = cur.name })
    if prevBest and dur < prevBest then
        cur.pb = true
        FJ.Timeline:Add("pb", 55, { a = cur.name, b = dur, c = prevBest, zn = cur.name })
    end
    FJ:NotifyDataChanged()
end

function Dungeons:EndRun()
    if not cur then return end
    local db = FJ.db
    local now = time()
    local dur = cur.time or 0
    local d = db.dungeons[cur.name]
    local valid = d ~= nil and (dur >= MIN_RUN or (cur.bosses or 0) > 0)
    if valid then
        d.runs = (d.runs or 0) + 1
        d.time = (d.time or 0) + dur
        d.last = now
        db.totals.dungeonRuns = db.totals.dungeonRuns + 1
        local party
        if cur.party and next(cur.party) then
            party = {}
            for name in pairs(cur.party) do party[#party + 1] = name end
            table.sort(party)
        end
        FJ.PushCapped(db.runs, {
            n = cur.name, s = cur.start, d = dur, b = cur.bosses, dth = cur.deaths,
            k = cur.kills, done = cur.completed or nil, pb = cur.pb or nil, lvl = cur.lvl,
            raid = (cur.type == "raid") or nil, party = party,
        }, FJ.CAPS.runs)
    end
    local finished = cur
    cur = nil
    db.run = nil
    FJ:SendMessage("FJ_RUN_ENDED", finished, valid)
    FJ:NotifyDataChanged()
end

function Dungeons:Current()
    return cur
end

function Dungeons:OnEnteringWorld()
    FJ:After(1.5, function() Dungeons:Check() end)
end

function Dungeons:OnLogout()
    if cur then cur.last = time() end
end

function Dungeons:OnEnable()
    FJ:RegisterEvent("ZONE_CHANGED_NEW_AREA", function()
        FJ:Debounce("dungeon-check", 1, function() Dungeons:Check() end)
    end)
    FJ:RegisterMessage("FJ_BOSS_KILLED", function(_, npcID, boss, name)
        Dungeons:OnBossKilled(npcID, boss, name)
    end)
end
