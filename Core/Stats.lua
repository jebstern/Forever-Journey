-- Forever Journey: read-only derivations over the saved data. Nothing here writes.
local ADDON_NAME, FJ = ...
local Stats = FJ:NewModule("Stats")

local function db() return FJ.db end

---------------------------------------------------------------------------
-- Character
---------------------------------------------------------------------------
function Stats:XPProgress()
    local xp, max = UnitXP("player") or 0, UnitXPMax("player") or 1
    local rested = GetXPExhaustion and GetXPExhaustion() or 0
    return xp, max, FJ.Percent(xp, max), rested or 0
end

function Stats:IsMaxLevel()
    return (UnitLevel("player") or 1) >= FJ.API.MaxLevel()
end

function Stats:Played()
    return FJ.Session:GetPlayed()
end

function Stats:JourneyStart()
    local c = db().char
    if c.origin == "created" and c.created then return c.created, true end
    return c.firstSeen, false
end

---------------------------------------------------------------------------
-- Zones
---------------------------------------------------------------------------
function Stats:TopZones(field, n, excludeCities)
    return FJ.TopN(db().zones, field, n, function(id)
        return not (excludeCities and FJ.Data.Capitals[id])
    end)
end

function Stats:MostVisitedZone()
    local top = self:TopZones("time", 1, true)
    return top[1] and top[1].data, top[1] and top[1].value
end

function Stats:DeadliestZone()
    local top = self:TopZones("d", 1, false)
    return top[1] and top[1].data, top[1] and top[1].value
end

-- visited and total per continent, from the live map catalogue
function Stats:ContinentProgress()
    local out = {}
    local zones = db().zones
    for _, c in ipairs(FJ.Zones:GetCatalog()) do
        local visited, total = 0, #c.zones
        for _, z in ipairs(c.zones) do
            if zones[z.mapID] then visited = visited + 1 end
        end
        out[#out + 1] = { name = c.name, mapID = c.mapID, visited = visited, total = total }
    end
    return out
end

function Stats:ZonesVisited()
    return FJ.CountKeys(db().zones)
end

function Stats:ZonesTotal()
    local n = 0
    for _, c in ipairs(FJ.Zones:GetCatalog()) do
        if c.mapID ~= 0 then n = n + #c.zones end
    end
    return n
end

---------------------------------------------------------------------------
-- Dungeons, enemies
---------------------------------------------------------------------------
function Stats:FavoriteDungeon()
    local top = FJ.TopN(db().dungeons, "runs", 1)
    return top[1] and top[1].key, top[1] and top[1].value, top[1] and top[1].data
end

function Stats:Nemesis()
    local top = FJ.TopN(db().deathsByKiller, nil, 1)
    return top[1] and top[1].key, top[1] and top[1].value
end

function Stats:MostSlain()
    local top = FJ.TopN(db().killsByName, nil, 1)
    return top[1] and top[1].key, top[1] and top[1].value
end

function Stats:BossesDefeated()
    return FJ.CountKeys(db().bosses)
end

function Stats:DungeonsCleared()
    local n = 0
    for _, d in pairs(db().dungeons) do
        if (d.done or 0) > 0 then n = n + 1 end
    end
    return n
end

---------------------------------------------------------------------------
-- Time
---------------------------------------------------------------------------
function Stats:ActivitySplit()
    local T = FJ.Theme
    local out = {}
    local total = 0
    for key, secs in pairs(db().activity) do
        if secs and secs > 0 then
            local meta = T.activity[key] or { key, T.colors.muted }
            out[#out + 1] = { key = key, label = meta[1], value = secs, color = meta[2] }
            total = total + secs
        end
    end
    table.sort(out, function(a, b) return a.value > b.value end)
    return out, total
end

function Stats:SessionNow()
    local s = FJ.Session:Current()
    if not s then return nil end
    local dur = FJ.Session:Duration()
    local xph = dur > 0 and (s.xp or 0) / dur * 3600 or 0
    return {
        duration = dur, xp = s.xp or 0, xph = xph, quests = s.q or 0, kills = s.k or 0,
        deaths = s.dth or 0, gold = s.g or 0, discoveries = s.disc or 0,
        levels = (s.lvl1 or 0) - (s.lvl0 or 0),
    }
end

-- Level -> played seconds when reached, ascending by level, plus a trailing "now" point.
function Stats:LevelSeries()
    local out = {}
    for lvl, L in pairs(db().levels) do
        if type(L.played) == "number" then out[#out + 1] = { x = lvl, y = L.played } end
    end
    table.sort(out, function(a, b) return a.x < b.x end)
    if #out > 0 then
        local lvl = UnitLevel("player")
        local last = out[#out]
        if last.x <= lvl then
            local xp, max = UnitXP("player") or 0, UnitXPMax("player") or 1
            out[#out + 1] = { x = lvl + FJ.Percent(xp, max), y = FJ.Session:GetPlayed(), now = true }
        end
    end
    return out
end

function Stats:LevelBuckets()
    local out = {}
    for lvl, L in pairs(db().levels) do
        out[#out + 1] = { level = lvl, time = L.time or 0, xp = L.xp or 0, q = L.q or 0, k = L.k or 0, d = L.d or 0 }
    end
    table.sort(out, function(a, b) return a.level < b.level end)
    return out
end

function Stats:Sessions(n)
    local list = db().sessions
    local out = {}
    local from = math.max(1, #list - (n or 20) + 1)
    for i = from, #list do out[#out + 1] = list[i] end
    return out
end

function Stats:XPPerHourRecent()
    local xp, secs = 0, 0
    for _, s in ipairs(self:Sessions(3)) do
        xp, secs = xp + (s.xp or 0), secs + (s.d or 0)
    end
    local now = self:SessionNow()
    if now then xp, secs = xp + now.xp, secs + now.duration end
    if secs < 600 then return nil end
    return xp / secs * 3600
end

function Stats:EstimateTimeToLevel()
    if self:IsMaxLevel() then return nil end
    local rate = self:XPPerHourRecent()
    if not rate or rate <= 0 then return nil end
    local xp, max = UnitXP("player") or 0, UnitXPMax("player") or 1
    return (max - xp) / rate * 3600
end

---------------------------------------------------------------------------
-- Professions and records
---------------------------------------------------------------------------
function Stats:Professions()
    local out = {}
    for name, p in pairs(db().professions) do
        if not p.unlearned then
            out[#out + 1] = { name = name, rank = p.rank or 0, max = p.max or 0, icon = p.icon, learned = p.learned }
        end
    end
    table.sort(out, function(a, b) return a.rank > b.rank end)
    return out
end

function Stats:Records()
    local d = db()
    local out = {}
    local longest, mostXP, mostQ, mostK
    for _, s in ipairs(d.sessions) do
        if not longest or (s.d or 0) > (longest.d or 0) then longest = s end
        if not mostXP or (s.xp or 0) > (mostXP.xp or 0) then mostXP = s end
        if not mostQ or (s.q or 0) > (mostQ.q or 0) then mostQ = s end
        if not mostK or (s.k or 0) > (mostK.k or 0) then mostK = s end
    end
    if longest and (longest.d or 0) > 0 then
        out[#out + 1] = { label = "Longest session", value = FJ.FormatDuration(longest.d), sub = FJ.FormatDate(longest.s) }
    end
    if mostXP and (mostXP.xp or 0) > 0 then
        out[#out + 1] = { label = "Most XP in a session", value = FJ.FormatNumber(mostXP.xp), sub = FJ.FormatDate(mostXP.s) }
    end
    if mostQ and (mostQ.q or 0) > 0 then
        out[#out + 1] = { label = "Most quests in a session", value = tostring(mostQ.q), sub = FJ.FormatDate(mostQ.s) }
    end
    if mostK and (mostK.k or 0) > 0 then
        out[#out + 1] = { label = "Most kills in a session", value = FJ.FormatNumber(mostK.k), sub = FJ.FormatDate(mostK.s) }
    end
    local fastest
    for name, dg in pairs(d.dungeons) do
        if dg.best and (not fastest or dg.best < fastest.best) then fastest = { name = name, best = dg.best } end
    end
    if fastest then
        out[#out + 1] = { label = "Fastest dungeon clear", value = FJ.FormatDuration(fastest.best), sub = fastest.name }
    end
    local zone, deaths = self:DeadliestZone()
    if zone and deaths and deaths > 0 then
        out[#out + 1] = { label = "Deadliest zone", value = zone.name or "?", sub = deaths .. (deaths == 1 and " death" or " deaths") }
    end
    local nemesis, n = self:Nemesis()
    if nemesis and n and n >= 2 then
        out[#out + 1] = { label = "Nemesis", value = nemesis, sub = "killed you " .. n .. " times" }
    end
    if (d.totals.peakGold or 0) > 0 then
        out[#out + 1] = { label = "Richest moment", value = FJ.FormatMoney(d.totals.peakGold, true), sub = "most gold carried" }
    end
    return out
end

---------------------------------------------------------------------------
-- Levels, days, clock
---------------------------------------------------------------------------
-- Time spent at each recorded level. Exact where two consecutive /played anchors exist
-- (and for the current level, from the server's own time-at-level); otherwise tracked time.
function Stats:TimePerLevel()
    local d = db()
    local levels = {}
    for lvl in pairs(d.levels) do levels[#levels + 1] = lvl end
    table.sort(levels)
    local cur = UnitLevel("player") or 1
    local out = {}
    for _, lvl in ipairs(levels) do
        local L = d.levels[lvl]
        local nextL = d.levels[lvl + 1]
        local secs, exact
        if lvl == cur then
            secs, exact = FJ.Session:GetLevelPlayed(), true
        elseif nextL and type(nextL.played) == "number" and type(L.played) == "number" and nextL.played >= L.played then
            secs, exact = nextL.played - L.played, true
        else
            secs, exact = L.time or 0, false
        end
        out[#out + 1] = { level = lvl, time = secs, exact = exact, xp = L.xp or 0, q = L.q or 0, k = L.k or 0, d = L.d or 0 }
    end
    return out
end

function Stats:LevelPace()
    local rows = self:TimePerLevel()
    local cur = UnitLevel("player") or 1
    local total, n, fastest, slowest = 0, 0, nil, nil
    for _, r in ipairs(rows) do
        if r.level < cur and r.time > 0 then
            total, n = total + r.time, n + 1
            if not fastest or r.time < fastest.time then fastest = r end
            if not slowest or r.time > slowest.time then slowest = r end
        end
    end
    return { average = n > 0 and total / n or nil, count = n, fastest = fastest, slowest = slowest }
end

local function DayKeyToTime(key)
    local y, m, dd = tostring(key):match("^(%d%d%d%d)(%d%d)(%d%d)$")
    if not y then return nil end
    return time({ year = tonumber(y), month = tonumber(m), day = tonumber(dd), hour = 12 })
end

-- Distinct days played, current and longest streak of consecutive days, last 7 days, busiest day.
function Stats:Days()
    local days = db().days or {}
    local keys = {}
    for k in pairs(days) do keys[#keys + 1] = k end
    table.sort(keys)
    local longest, run, prevT = 0, 0, nil
    for _, k in ipairs(keys) do
        local tk = DayKeyToTime(k)
        if tk then
            if prevT and (tk - prevT) > 82800 and (tk - prevT) < 90000 then run = run + 1 else run = 1 end
            if run > longest then longest = run end
            prevT = tk
        end
    end
    local now = time()
    local current = 0
    if days[date("%Y%m%d", now)] or days[date("%Y%m%d", now - 86400)] then current = run end
    local week = 0
    for i = 0, 6 do week = week + (days[date("%Y%m%d", now - i * 86400)] or 0) end
    local busiest
    for k, secs in pairs(days) do
        if not busiest or secs > busiest.secs then busiest = { key = k, secs = secs, t = DayKeyToTime(k) } end
    end
    return { count = #keys, current = current, longest = longest, week = week, busiest = busiest }
end

function Stats:PlayClock()
    local clock = db().clock or {}
    local out = {}
    for h = 0, 23 do out[#out + 1] = { hour = h, value = clock[h] or 0 } end
    return out
end

local WEEKDAYS = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }
function Stats:Weekdays()
    local wd = db().weekday or {}
    local out = {}
    for i = 1, 7 do
        local idx = i % 7 -- Monday first, Sunday last
        out[#out + 1] = { label = WEEKDAYS[idx + 1], value = wd[idx] or 0 }
    end
    return out
end

function Stats:ExplorationSummary()
    local explored, total, zonesWithData, complete = 0, 0, 0, 0
    for mapID in pairs(db().zones) do
        local e, tt = FJ.Zones:Exploration(mapID)
        if e and tt and tt > 0 then
            explored, total, zonesWithData = explored + e, total + tt, zonesWithData + 1
            if e >= tt then complete = complete + 1 end
        end
    end
    return { explored = explored, total = total, zones = zonesWithData, complete = complete }
end

function Stats:AverageSession()
    local total, n = 0, 0
    for _, s in ipairs(db().sessions) do total, n = total + (s.d or 0), n + 1 end
    if n == 0 then return nil, 0 end
    return total / n, n
end

function Stats:DeathlessStreak()
    local t = db().totals
    local current = (t.tracked or 0) - (t.trackedAtLastDeath or 0)
    return current, math.max(t.longestNoDeath or 0, current)
end

function Stats:DeadliestLevel()
    local best
    for lvl, L in pairs(db().levels) do
        if (L.d or 0) > 0 and (not best or L.d > best.d) then best = { level = lvl, d = L.d } end
    end
    return best
end

---------------------------------------------------------------------------
-- Almanac: every number, grouped. Sections are { title, icon, rows = { {label, value, note} } }.
---------------------------------------------------------------------------
function Stats:Almanac()
    local d = db()
    local t = d.totals
    local life = FJ.Lifetime
    local icons = FJ.Theme.icons
    local function V(key) return life:Value(key) end
    local function N(v) if v and v > 0 then return FJ.FormatNumber(v) end end
    local function Dur(secs) if secs and secs > 0 then return FJ.FormatDuration(secs) end end
    local function Money(c) if c and c > 0 then return FJ.FormatMoney(c, true) end end
    local function Rate(v, h) if v and v > 0 and h and h >= 0.5 then return format("%.1f", v / h) end end
    local sections = {}
    local function section(title, icon)
        local s = { title = title, icon = icon, rows = {} }
        sections[#sections + 1] = s
        return function(label, value, note)
            if value ~= nil and value ~= "" then s.rows[#s.rows + 1] = { label, tostring(value), note } end
        end
    end
    local played = self:Played()
    local playedH = played / 3600
    local trackedH = (t.tracked or 0) / 3600
    local lvl = UnitLevel("player") or 1

    -- Character & time
    local add = section("Character & time", icons.played)
    add("Level", tostring(lvl))
    add("Time played", FJ.FormatDuration(played, "long"))
    add("At this level", Dur(FJ.Session:GetLevelPlayed()))
    local start, created = self:JourneyStart()
    add(created and "Journey began" or "Recording since", FJ.FormatDate(start))
    local pace = self:LevelPace()
    add("Levels gained since recording", pace.count > 0 and tostring(pace.count) or nil)
    add("Average time per level", Dur(pace.average), pace.count > 0 and ("over " .. pace.count .. " levels") or nil)
    if pace.fastest then add("Fastest level", format("level %d in %s", pace.fastest.level, FJ.FormatDuration(pace.fastest.time))) end
    if pace.slowest and pace.slowest ~= pace.fastest then add("Slowest level", format("level %d in %s", pace.slowest.level, FJ.FormatDuration(pace.slowest.time))) end
    local avgSession, nSessions = self:AverageSession()
    add("Sessions", tostring((t.sessions or 0) + 1), "including this one")
    add("Average session", Dur(avgSession))
    local days = self:Days()
    add("Days played", N(days.count))
    add("Days in a row", days.current > 0 and tostring(days.current) or nil, days.longest > 0 and ("longest " .. days.longest) or nil)
    add("Last 7 days", Dur(days.week))
    if days.busiest and days.busiest.t then add("Busiest day", FJ.FormatDate(days.busiest.t), FJ.FormatDuration(days.busiest.secs)) end
    add("Away from keyboard", Dur(d.activity.afk))
    add("Time as a ghost", Dur(t.ghostTime))

    -- Deaths
    add = section("Deaths", icons.deaths)
    local lifeDeaths = V("deaths")
    add("Deaths", N(lifeDeaths or t.deaths), lifeDeaths and "lifetime" or "since recording began")
    if lifeDeaths then add("Since recording began", tostring(t.deaths)) end
    add("Deaths per hour played", Rate(lifeDeaths or t.deaths, lifeDeaths and playedH or trackedH))
    local cur, longest = self:DeathlessStreak()
    add("Time since last death", Dur(cur), "tracked play time")
    add("Longest deathless stretch", Dur(longest))
    local worstHour, worstN = nil, 0
    for h, n in pairs(d.deathClock or {}) do
        if n > worstN then worstHour, worstN = h, n end
    end
    if worstHour then add("Deadliest hour", format("%02d:00 - %02d:59", worstHour, worstHour), worstN .. (worstN == 1 and " death" or " deaths")) end
    do
        local bands = {}
        for _, r in ipairs(self:TimePerLevel()) do
            local b = math.floor((r.level - 1) / 10)
            bands[b] = bands[b] or { time = 0, d = 0 }
            bands[b].time = bands[b].time + (r.time or 0)
            bands[b].d = bands[b].d + (r.d or 0)
        end
        local keys = {}
        for b in pairs(bands) do keys[#keys + 1] = b end
        table.sort(keys)
        for _, b in ipairs(keys) do
            local band = bands[b]
            if band.time >= 1800 then
                add(format("Deaths per hour, levels %d-%d", b * 10 + 1, b * 10 + 10), format("%.2f", band.d / (band.time / 3600)),
                    format("%d %s in %s", band.d, band.d == 1 and "death" or "deaths", FJ.FormatDuration(band.time)))
            end
        end
    end
    local dz, dzN = self:DeadliestZone()
    if dz and dzN and dzN > 0 then add("Deadliest zone", dz.name or "?", dzN .. (dzN == 1 and " death" or " deaths")) end
    local dl = self:DeadliestLevel()
    if dl then add("Deadliest level", "level " .. dl.level, dl.d .. (dl.d == 1 and " death" or " deaths")) end
    local nemesis, nN = self:Nemesis()
    if nemesis then add("Nemesis", nemesis, "killed you " .. nN .. (nN == 1 and " time" or " times")) end
    add("In dungeons and raids", N(V("instanceDeaths") or V("dungeonDeaths")))
    add("From falling", N(V("deathsFalling")))
    add("From drowning", N(V("deathsDrowning")))
    add("From fire and lava", N(V("deathsFire")))
    add("From fatigue", N(V("deathsFatigue")))
    add("From other players", N(V("deathsPlayers")))
    add("From Hogger", N(V("deathsHogger")))
    add("Resurrected by priests", N(V("resPriest")))
    add("Rebirthed by druids", N(V("resRebirth")))
    add("Revived by druids", N(V("resRevive")))
    add("Resurrected by shamans", N(V("resShaman")))
    add("Redeemed by paladins", N(V("resPaladin")))
    add("Soulstone resurrections", N(V("resSoulstone")))

    -- Combat
    add = section("Combat", icons.kills)
    add("Enemies slain", N(V("kills") or t.kills), V("kills") and "lifetime" or "since recording began")
    add("Killing blows", N(V("killingBlows")))
    add("Kills that granted XP or honor", N(V("killsXP")))
    add("Creatures killed", N(V("creatures")))
    add("Critters killed", N(V("critters")))
    local prey = life:Label("favouritePrey")
    if prey then add("Favourite prey", prey, N(V("favouritePrey")) .. " slain") end
    local cont = life:Label("killsContinent")
    if cont then add("Most killing blows on", cont, N(V("killsContinent"))) end
    add("Kills since recording began", N(t.kills))
    add("Kills per hour", Rate(t.kills, trackedH), "since recording began")
    local slain, slainN = self:MostSlain()
    if slain then add("Most slain", slain, slainN .. (slainN == 1 and " kill" or " kills")) end
    add("Honorable kills", N(V("honorableKills")))
    add("Largest hit dealt", N(V("largestHit")))
    add("Largest hit taken", N(V("largestHitTaken")))
    add("Total damage done", N(V("totalDamage")))
    add("Total healing done", N(V("totalHealing")))
    local dw, dlost = V("duelsWon") or 0, V("duelsLost") or 0
    if dw + dlost > 0 then add("Duels", format("%d won, %d lost", dw, dlost)) end
    local bgP, bgW = V("bgPlayed") or 0, V("bgWon") or 0
    if bgP > 0 then add("Battlegrounds", format("%d played, %d won", bgP, bgW)) end
    local bgMost = life:Label("bgMostPlayed")
    if bgMost then add("Battleground played most", bgMost, N(V("bgMostPlayed"))) end
    local dsB = V("darkspearBattles") or 0
    if dsB > 0 then add("Darkspear Islands", format("%d battles, %d won", dsB, V("darkspearWins") or 0), (V("darkspearDeaths") or 0) > 0 and (V("darkspearDeaths") .. " deaths") or nil) end

    -- Quests
    add = section("Quests", icons.quests)
    add("Quests completed", N(FJ.Quests:GetTotal()), "lifetime")
    add("Since recording began", N(t.quests))
    add("Accepted since recording began", N(t.questsAccepted))
    add("Abandoned", N(V("questsAbandoned")), "lifetime")
    add("Quests per hour", Rate(t.quests, trackedH), "since recording began")
    if pace.count > 0 and (t.quests or 0) > 0 then add("Quests per level", format("%.1f", t.quests / pace.count), "since recording began") end

    -- Travel & exploration
    add = section("Travel & exploration", icons.zones)
    add("Zones visited", format("%d of %d", self:ZonesVisited(), self:ZonesTotal()))
    add("Areas discovered", N(t.discoveries), "since recording began")
    local ex = self:ExplorationSummary()
    if ex.total > 0 then add("Map uncovered", format("%d%%", ex.explored / ex.total * 100), format("%d of %d areas across %d zones", ex.explored, ex.total, ex.zones)) end
    add("Fully explored zones", N(ex.complete))
    add("Flight paths known", N(FJ.Zones:KnownFlightPaths()))
    add("Flights taken", N(V("flights") or t.flightsTaken), V("flights") and "lifetime" or "since recording began")
    add("Time in the air", Dur(d.activity.travel))
    add("Hearthstone uses", N(V("hearths")))
    add("Mage portals taken", N(V("portals")))
    add("Summons accepted", N(V("summons")))
    if (t.distance or 0) > 0 then add("Distance travelled", format("%.1f km", t.distance * 0.0009144), "at least; straight lines between samples, flights excluded") end
    add("Jumps", N(t.jumps), "since recording began")
    add("Mounts owned", N(V("mounts")))
    add("Companion pets", N(V("pets")))
    add("Rare creatures met", N(t.raresSeen))
    local mv, mvT = self:MostVisitedZone()
    if mv then add("Most visited zone", mv.name or "?", Dur(mvT)) end

    -- Dungeons & raids
    add = section("Dungeons & raids", icons.dungeons)
    add("Dungeons entered", N(V("dungeonsEntered")), "lifetime")
    local conquered = life:DungeonsConquered()
    add("Dungeons conquered", N(conquered), "lifetime, by final boss")
    local bossTotal = 0
    for _, b in ipairs(life:BossKills()) do bossTotal = bossTotal + b.n end
    add("Final bosses slain", N(bossTotal))
    local raids = (V("raids10") or 0) + (V("raids20") or 0) + (V("raids40") or 0)
    add("Raids entered", N(raids))
    add("Runs since recording began", N(t.dungeonRuns))
    add("Full clears since recording began", N(t.dungeonsCompleted))
    add("Bosses since recording began", N(self:BossesDefeated()))
    local fastest
    for name, dg in pairs(d.dungeons) do
        if dg.best and (not fastest or dg.best < fastest.best) then fastest = { name = name, best = dg.best } end
    end
    if fastest then add("Fastest clear", FJ.FormatDuration(fastest.best), fastest.name) end
    add("Deaths in dungeons", N(V("dungeonDeaths")))
    local fav, favRuns = self:FavoriteDungeon()
    if fav then add("Most runs since recording", fav, favRuns .. (favRuns == 1 and " run" or " runs")) end

    -- Economy
    add = section("Economy", icons.gold)
    add("Gold acquired", Money(V("goldAcquired")), "lifetime")
    add("From quest rewards", Money(V("goldQuests")))
    add("Looted", Money(V("goldLooted")))
    add("From vendors", Money(V("goldVendors")))
    add("From auctions", Money(V("goldAuctions")))
    add("Most expensive sale", Money(V("auctionBest")))
    local ap, ab = V("auctionsPosted") or 0, V("auctionsBought") or 0
    if ap + ab > 0 then add("Auctions", format("%d posted, %d bought", ap, ab)) end
    add("Spent on flights", Money(V("goldTravel")))
    add("Spent on postage", Money(V("goldPostage")))
    add("Richest moment", Money(V("goldPeak") or t.peakGold))
    add("Average per day", Money(V("goldPerDay")))
    add("Carrying now", Money(GetMoney() or 0))
    add("Earned since recording began", Money(t.goldEarned))
    add("Spent since recording began", Money(t.goldSpent))
    if (t.goldEarned or 0) > 0 and trackedH >= 0.5 then add("Gold per hour", FJ.FormatMoney(t.goldEarned / trackedH, true), "since recording began") end

    -- Professions
    add = section("Professions & skills", icons.professions)
    for _, p in ipairs(self:Professions()) do add(p.name, format("%d / %d", p.rank, p.max)) end
    add("Professions learned", N(V("professionsLearned")))
    add("Weapon skills at maximum", N(V("weaponSkillsMax")))
    add("Cooking recipes known", N(V("cookingRecipes")))
    add("Alchemy recipes learned", N(V("alchemyRecipes")))
    add("First Aid manuals learned", N(V("firstAidManuals")))
    add("Fish caught", N(V("fish")))
    add("Talent respecs", N(V("respecs")))
    add("Factions encountered", N(V("factions")))
    add("Factions at Honored or better", N(V("mostHonored")))

    -- Consumables
    add = section("Consumables", "Interface\\Icons\\INV_Potion_54")
    add("Health potions", N(V("healthPotions")))
    add("Mana potions", N(V("manaPotions")))
    add("Elixirs", N(V("elixirs")))
    add("Flasks", N(V("flasks")))
    add("Food eaten", N(V("food")))
    add("Beverages", N(V("beverages")))
    add("Bandages used", N(V("bandages")), life:Label("bandageMost") and ("favourite: " .. life:Label("bandageMost")) or nil)
    local potions = (V("healthPotions") or 0) + (V("manaPotions") or 0)
    if potions > 0 and (lifeDeaths or 0) > 0 then add("Potions per death", format("%.1f", potions / lifeDeaths)) end

    -- Social & rest
    add = section("Social & rest", "Interface\\Icons\\INV_Misc_Toy_04")
    local emotes = FJ.Social:EmoteList()
    local emoteTotal = 0
    for _, e in ipairs(emotes) do emoteTotal = emoteTotal + e.value end
    add("Emotes", N(emoteTotal))
    if emotes[1] then add("Favourite emote", emotes[1].label, emotes[1].value .. (emotes[1].value == 1 and " time" or " times")) end
    add("Custom /e lines", N(FJ.Social:EmoteCount("EMOTE")))
    add("Hugs", N(V("hugs")))
    add("Cheers", N(V("cheers")))
    add("Waves", N(V("waves")))
    add("Laughs", N(V("lols")))
    add("Facepalms", N(V("facepalms")))
    add("Tiny violins", N(V("violin")))
    local pose, poseNow = FJ.Social:CurrentPose()
    add("Sat down", N(t.sitCount), (t.sitCount or 0) > 0 and ("times") or nil)
    add("Time sitting", Dur((t.sitTime or 0) + ((pose == "SIT") and poseNow or 0)), (t.sitLongest or 0) > 0 and ("longest " .. FJ.FormatDuration(t.sitLongest)) or nil)
    add("Time kneeling", Dur((t.kneelTime or 0) + ((pose == "KNEEL") and poseNow or 0)))
    add("Time sleeping", Dur((t.sleepTime or 0) + ((pose == "SLEEP") and poseNow or 0)))
    add("Camps", N(t.campCount), (t.campTime or 0) > 0 and (FJ.FormatDuration(t.campTime) .. " by the fire") or nil)
    local need, greed = V("needRolls") or 0, V("greedRolls") or 0
    if need + greed > 0 then add("Loot rolls", format("%d need, %d greed", need, greed)) end
    add("Epic items acquired", N(V("epicsAcquired") or t.lootEpic))
    add("Legendary items", N(V("legendaries")))

    -- Companions
    add = section("Companions", "Interface\\Icons\\Spell_Holy_PrayerOfHealing02")
    local companions = FJ.Companions:List(8)
    add("People grouped with", N(FJ.Companions:Count()), "since recording began")
    add("Time in a group", Dur(t.groupTime))
    for i, c in ipairs(companions) do
        local _, _, _, hex = FJ.ClassColor(c.class)
        add(i == 1 and "Most time with" or " ", "|c" .. hex .. c.name .. "|r", format("%s together, %d %s", FJ.FormatDuration(c.time), c.n, c.n == 1 and "time" or "times"))
    end

    -- Gear & home
    add = section("Gear & home", icons.epics)
    local avgIlvl, slots = FJ.Gear:AverageItemLevel()
    if avgIlvl then add("Average item level", format("%.1f", avgIlvl), slots .. " slots") end
    local longest = FJ.Gear:LongestWorn()
    if longest and longest.link and longest.worn > 0 then
        add("Worn the longest", longest.link, FJ.FormatDuration(longest.worn) .. (longest.current and ", still wearing it" or ""))
    end
    add("Gear changes", N(t.gearChanges), "since recording began")
    local home, homes = FJ.Gear:CurrentHome()
    if home then add("Home", home, homes > 1 and format("%d homes so far", homes) or nil) end
    add("Time in the saddle", Dur(t.mountedTime))

    -- Quest completion (QuestieDB)
    local qTotal, qDone, qUnob, qZones, qComplete = FJ.ZoneQuests:Summary()
    if qTotal and qTotal > 0 then
        add = section("Quest completion", icons.quests)
        local possible = qTotal - (qUnob or 0)
        add("World quests completed", format("%d of %d (%d%%)", qDone, possible, possible > 0 and qDone / possible * 100 or 0), "from QuestieDB, open-world zones")
        add("Zones fully quested", format("%d of %d", qComplete, qZones))
        add("Quests no longer obtainable", N(qUnob), "mutually exclusive choices already made")
    end

    -- Flight log
    local routes = FJ.Zones:TopRoutes(3)
    if #routes > 0 then
        add = section("Flight log", icons.taxi)
        add("Routes flown", N(FJ.CountKeys(d.flights or {})), "since recording began")
        for i, r in ipairs(routes) do
            add(i == 1 and "Most flown" or " ", r.key, format("%d %s, %s in the air", r.n, r.n == 1 and "time" or "times", FJ.FormatDuration(r.time)))
        end
        if (t.longestFlight or 0) > 0 then add("Longest flight", FJ.FormatDuration(t.longestFlight), t.longestFlightRoute) end
    end

    -- Badges
    local earned, remaining = FJ.Badges:List()
    if #earned > 0 or #remaining > 0 then
        add = section("Badges", "Interface\\Icons\\INV_Misc_Gem_Variety_02")
        add("Earned", format("%d of %d", #earned, #earned + #remaining))
        for i = #earned, math.max(1, #earned - 7), -1 do
            local e = earned[i]
            add(e.def.name, FJ.FormatDate(e.t), e.def.desc)
        end
        if remaining[1] then add("Still waiting", remaining[1].name, remaining[1].desc) end
    end

    -- Luck and oddments
    add = section("Luck & oddments", "Interface\\Icons\\INV_Misc_Dice_02")
    local rollsMade = (V("needRolls") or 0) + (V("greedRolls") or 0)
    if (t.rollsWon or 0) > 0 or rollsMade > 0 then
        add("Loot rolls won", tostring(t.rollsWon or 0), rollsMade > 0 and format("of %d rolls made in total", rollsMade) or "since recording began")
    end
    add("Abilities learned", N(t.spellsLearned), "since recording began")
    add("Azeroth sunrises witnessed", N(t.sunrises), (t.sunsets or 0) > 0 and (t.sunsets .. " sunsets") or nil)
    add("Jumps per hour", Rate(t.jumps, trackedH), "since recording began")

    local out = {}
    for _, s in ipairs(sections) do
        if #s.rows > 0 then out[#out + 1] = s end
    end
    return out
end

---------------------------------------------------------------------------
-- Journey summary (dashboard + wrapped)
---------------------------------------------------------------------------
function Stats:Summary()
    local d = db()
    local t = d.totals
    local zone, zoneTime = self:MostVisitedZone()
    local deadly, deadlyN = self:DeadliestZone()
    local favDungeon, favRuns = self:FavoriteDungeon()
    local nemesis, nemesisN = self:Nemesis()
    local slain, slainN = self:MostSlain()
    return {
        played = self:Played(),
        tracked = t.tracked,
        quests = FJ.Quests:GetTotal(),
        questsSince = t.quests,
        dungeonRuns = t.dungeonRuns,
        dungeonsCompleted = t.dungeonsCompleted,
        bosses = self:BossesDefeated(),
        deaths = t.deaths,
        kills = t.kills,
        zones = self:ZonesVisited(),
        discoveries = t.discoveries,
        flightPaths = FJ.Zones:KnownFlightPaths(),
        flightsTaken = t.flightsTaken,
        goldEarned = t.goldEarned,
        goldSpent = t.goldSpent,
        ghostTime = t.ghostTime,
        rares = t.raresSeen,
        epics = t.lootEpic,
        rareLoot = t.lootRare,
        mostVisited = zone and zone.name, mostVisitedTime = zoneTime,
        deadliest = deadly and deadly.name, deadliestDeaths = deadlyN,
        favoriteDungeon = favDungeon, favoriteRuns = favRuns,
        nemesis = nemesis, nemesisN = nemesisN,
        mostSlain = slain, mostSlainN = slainN,
        sessions = t.sessions,
        -- lifetime numbers from the game's statistics, nil when the client has none
        lifeDeaths = FJ.Lifetime:Value("deaths"),
        lifeKills = FJ.Lifetime:Value("kills"),
        lifeGold = FJ.Lifetime:Value("goldAcquired"),
        lifeFlights = FJ.Lifetime:Value("flights"),
        lifeQuests = FJ.Lifetime:Value("quests"),
    }
end
