-- Forever Journey: gentle "what could I do next" suggestions from the data we own.
local ADDON_NAME, FJ = ...
local Suggestions = FJ:NewModule("Suggestions")

local ICON = {
    quest = "Interface\\Icons\\INV_Misc_Note_01",
    dungeon = "Interface\\Icons\\INV_Misc_Key_03",
    zone = "Interface\\Icons\\INV_Misc_Map_01",
    explore = "Interface\\Icons\\INV_Misc_Spyglass_02",
    prof = "Interface\\Icons\\Trade_Engineering",
    level = "Interface\\Icons\\Spell_Nature_WispSplode",
    taxi = "Interface\\Icons\\Ability_Mount_Gryphon_01",
    rest = "Interface\\Icons\\Spell_Nature_Sleep",
    milestone = "Interface\\Icons\\INV_Misc_PocketWatch_01",
}

local function FactionOK(f)
    return f == nil or f == FJ.playerFaction
end

local function DungeonDone(name)
    if FJ.Lifetime:DungeonDone(name) then return true end
    local d = FJ.db.dungeons[name]
    if d and (d.done or 0) > 0 then return true end
    for npcID, rec in pairs(FJ.db.bosses) do
        local boss = FJ.Data.Bosses[npcID]
        if boss and boss.f and boss.d == name and (rec.n or 0) > 0 then return true end
    end
    return false
end

function Suggestions:Build()
    local out = {}
    local db = FJ.db
    local lvl = UnitLevel("player") or 1
    local maxLevel = FJ.API.MaxLevel()

    -- 1. Quest log by zone
    local groups = FJ.Quests:GetLogByZone()
    table.sort(groups, function(a, b)
        if a.complete ~= b.complete then return a.complete > b.complete end
        return a.n > b.n
    end)
    for i = 1, math.min(3, #groups) do
        local g = groups[i]
        local text
        if g.complete > 0 then
            text = format("%d %s in your log for %s, %d ready to hand in.", g.n, g.n == 1 and "quest" or "quests", g.name, g.complete)
        else
            text = format("%d unfinished %s in your log for %s.", g.n, g.n == 1 and "quest" or "quests", g.name)
        end
        out[#out + 1] = { icon = ICON.quest, title = "Quests in " .. g.name, text = text, kind = "quest" }
    end

    -- 1b. Zones almost fully quested (needs QuestieDB)
    if FJ.ZoneQuests:State() == "ready" then
        local near = {}
        for mapID, z in pairs(db.zones) do
            local pct, total, done, unob = FJ.ZoneQuests:Percent(mapID)
            if pct and total and total >= 5 and pct >= 0.75 and pct < 1 then
                near[#near + 1] = { name = z.name, pct = pct, left = total - (unob or 0) - done }
            end
        end
        table.sort(near, function(a, b) return a.pct > b.pct end)
        for i = 1, math.min(2, #near) do
            local z = near[i]
            out[#out + 1] = {
                icon = ICON.quest, kind = "zonequests", title = z.name .. " is almost done",
                text = format("%d%% of its quests are behind you; %d %s left.", z.pct * 100, z.left, z.left == 1 and "quest" or "quests"),
                note = "Quest totals from QuestieDB.",
            }
        end
    end

    -- 2. Dungeons for your level you have not finished
    local dungeons = 0
    for _, d in ipairs(FJ.Data.Dungeons) do
        local name, minL, maxL, faction, isRaid = d[1], d[2], d[3], d[4], d[5]
        if minL and maxL and not isRaid and FactionOK(faction) and lvl >= minL - 1 and lvl <= maxL + 3 and not DungeonDone(name) then
            local visited = db.dungeons[name] ~= nil
            out[#out + 1] = {
                icon = ICON.dungeon, kind = "dungeon",
                title = (visited and "Finish " or "Try ") .. name,
                text = visited
                    and format("You have been inside %s but never beaten its final boss. Levels %d-%d.", name, minL, maxL)
                    or format("%s suits levels %d-%d and you have not set foot in it yet.", name, minL, maxL),
                action = _G.ForeverDungeonJournal_Toggle and function() _G.ForeverDungeonJournal_Toggle() end or nil,
                actionText = _G.ForeverDungeonJournal_Toggle and "Dungeon Journal" or nil,
            }
            dungeons = dungeons + 1
            if dungeons >= 3 then break end
        end
    end

    -- 3. Zones for your level you have never visited
    local candidates = {}
    for mapID, z in pairs(FJ.Data.ZoneLevels) do
        if FactionOK(z[3]) and lvl >= z[1] and lvl <= z[2] and not db.zones[mapID] then
            local info = FJ.API.MapInfo(mapID)
            if info and info.name then candidates[#candidates + 1] = { name = info.name, min = z[1], max = z[2] } end
        end
    end
    table.sort(candidates, function(a, b) return a.min < b.min end)
    for i = 1, math.min(3, #candidates) do
        local c = candidates[i]
        out[#out + 1] = {
            icon = ICON.zone, kind = "zone", title = "Discover " .. c.name,
            text = format("%s is made for levels %d-%d and your map there is still blank.", c.name, c.min, c.max),
        }
    end

    -- 4. Visited zones at your level with little explored
    local partial = {}
    for mapID, z in pairs(db.zones) do
        local range = FJ.Data.ZoneLevels[mapID]
        if range and lvl >= range[1] - 2 and lvl <= range[2] + 2 then
            local explored, total = FJ.Zones:Exploration(mapID)
            if explored and total and total > 0 and explored < total and explored / total < 0.6 then
                partial[#partial + 1] = { name = z.name, explored = explored, total = total, pct = explored / total }
            end
        end
    end
    table.sort(partial, function(a, b) return a.pct < b.pct end)
    for i = 1, math.min(2, #partial) do
        local p = partial[i]
        out[#out + 1] = {
            icon = ICON.explore, kind = "explore", title = "Explore more of " .. p.name,
            text = format("You have uncovered %d of %d areas of %s.", p.explored, p.total, p.name),
        }
    end

    -- 5. Flight paths missing in zones you visited
    if db.flags.taxiScanned then
        local missing = 0
        for mapID, z in pairs(db.zones) do
            local range = FJ.Data.ZoneLevels[mapID]
            if range and not FJ.Data.Capitals[mapID] and z.name and #FJ.Zones:FlightPathsInZone(z.name) == 0 then
                if lvl >= range[1] - 2 and lvl <= range[2] + 8 then
                    out[#out + 1] = {
                        icon = ICON.taxi, kind = "taxi", title = "Flight path in " .. z.name,
                        text = format("You have visited %s but know no flight path there yet.", z.name),
                        note = "Based on the flight masters you have talked to.",
                    }
                    missing = missing + 1
                    if missing >= 2 then break end
                end
            end
        end
    end

    -- 6. Professions close to their cap
    for name, p in pairs(db.professions) do
        if not p.unlearned and p.max and p.max > 0 and p.rank and p.rank >= p.max - 10 and p.max < 300 then
            out[#out + 1] = {
                icon = p.icon or ICON.prof, kind = "prof", title = name .. " is near its cap",
                text = format("%s is %d/%d. A trainer can raise the cap before you waste skill-ups.", name, p.rank, p.max),
            }
        end
    end

    -- 7. Close to a level or a milestone
    if lvl < maxLevel then
        local xp, max, pct = FJ.Stats:XPProgress()
        if pct >= 0.85 then
            local eta = FJ.Stats:EstimateTimeToLevel()
            out[#out + 1] = {
                icon = ICON.level, kind = "level", title = format("Level %d is close", lvl + 1),
                text = format("Only %s XP to go%s.", FJ.FormatNumber(max - xp), eta and (", about " .. FJ.FormatDuration(eta) .. " at your recent pace") or ""),
            }
        end
        local rested = GetXPExhaustion and GetXPExhaustion() or 0
        if rested and max > 0 and rested >= max * 0.3 then
            out[#out + 1] = {
                icon = ICON.rest, kind = "rest", title = "Rested and ready",
                text = format("%s rested XP is waiting. Kills are worth double until it runs out.", FJ.FormatNumber(rested)),
            }
        end
    end
    local total = FJ.Quests:GetTotal()
    local nextMs
    for _, m in ipairs({ 10, 25, 50, 100, 150, 200, 250, 300, 400, 500, 600, 700, 800, 900, 1000 }) do
        if total < m then nextMs = m break end
    end
    if not nextMs then nextMs = (math.floor(total / 500) + 1) * 500 end
    if nextMs - total <= math.max(3, nextMs * 0.05) then
        local left = nextMs - total
        out[#out + 1] = {
            icon = ICON.milestone, kind = "milestone", title = format("%d quests within reach", nextMs),
            text = format("%d more %s and you hit %d completed quests.", left, left == 1 and "quest" or "quests", nextMs),
        }
    end

    if #out == 0 then
        out[1] = {
            icon = ICON.zone, kind = "none", title = "Nothing pressing",
            text = "No loose ends we can see. Pick a direction and wander; the journal will keep up.",
        }
    end
    return out
end
