-- Forever Journey: the milestone journal. Small entries, priorities, hard cap.
local ADDON_NAME, FJ = ...
local Timeline = FJ:NewModule("Timeline")

-- Priorities: higher survives pruning longer.
Timeline.PRIO = {
    start = 100, maxlevel = 100,
    level_big = 90, level_mid = 70, level = 40,
    city = 70, zone = 60,
    dungeon_first = 65, dungeon_done_first = 70, dungeon_done = 50,
    boss_final = 70, boss = 60,
    prof = 70, prof_ms = 60,
    taxi = 30,
    quest_first = 60, quests = 50,
    death = 20, death_ms = 50,
    item_epic = 70, item = 40,
    rare = 35,
    played = 60, kills = 50, gold = 55,
}

local ICONS = {
    start = "Interface\\Icons\\INV_Misc_Book_07",
    level = "Interface\\Icons\\Spell_Nature_WispSplode",
    maxlevel = "Interface\\Icons\\INV_Crown_01",
    zone = "Interface\\Icons\\INV_Misc_Map_01",
    city = "Interface\\Icons\\INV_Misc_Map02",
    dungeon_first = "Interface\\Icons\\INV_Misc_Key_03",
    dungeon_done = "Interface\\Icons\\INV_Misc_Gem_01",
    boss = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
    prof = "Interface\\Icons\\Trade_Engineering",
    prof_ms = "Interface\\Icons\\Trade_BlackSmithing",
    taxi = "Interface\\Icons\\Ability_Mount_Gryphon_01",
    quest_first = "Interface\\Icons\\INV_Misc_Note_02",
    quests = "Interface\\Icons\\INV_Misc_Note_01",
    death = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01",
    death_ms = "Interface\\Icons\\Spell_Shadow_DeathScream",
    item = "Interface\\Icons\\INV_Misc_Gift_01",
    rare = "Interface\\Icons\\Ability_Hunter_SniperShot",
    played = "Interface\\Icons\\INV_Misc_PocketWatch_01",
    kills = "Interface\\Icons\\Ability_Warrior_Cleave",
    gold = "Interface\\Icons\\INV_Misc_Coin_02",
    camp = "Interface\\Icons\\Spell_Fire_Fire",
    group = "Interface\\Icons\\Spell_Holy_PrayerOfHealing02",
    home = "Interface\\Icons\\INV_Misc_Rune_01",
    gear = "Interface\\Icons\\INV_Chest_Plate06",
    ride = "Interface\\Icons\\Ability_Mount_RidingHorse",
    badge = "Interface\\Icons\\INV_Misc_Gem_Variety_02",
    pb = "Interface\\Icons\\INV_Misc_PocketWatch_01",
    note = "Interface\\Icons\\INV_Misc_Note_03",
}

local COLORS = {
    start = "ffffd200", level = "ffffd200", maxlevel = "ffffd200",
    zone = "ff7fd4ff", city = "ff7fd4ff",
    dungeon_first = "ffb48cff", dungeon_done = "ffb48cff", boss = "ffff8c5a",
    prof = "ff9ad66b", prof_ms = "ff9ad66b",
    taxi = "ff8fd3d3", quest_first = "fff0d089", quests = "fff0d089",
    death = "ffff6060", death_ms = "ffff6060",
    item = "ffa335ee", rare = "ffff9f40", played = "ffcfcfcf", kills = "ffd9a066", gold = "ffffd700",
    camp = "ffff9a4d", group = "ff7fd4ff", home = "ff9ad66b", gear = "ffa335ee", ride = "ff8fd3d3",
    badge = "ffffd200", pb = "ffb48cff", note = "fff0d089",
}

-- entry fields: t time, k kind, p priority, l level, z zone mapID, zn zone name, a/b payload
function Timeline:Add(kind, prio, data)
    local db = FJ.db
    if not db then return end
    local e = { t = time(), k = kind, p = prio or 40, l = UnitLevel("player") }
    if data then
        for key, v in pairs(data) do e[key] = v end
    end
    if not e.z and FJ.Zones and FJ.Zones.GetCurrent then
        local mapID, name = FJ.Zones:GetCurrent()
        e.z, e.zn = mapID, name
    end
    local list = db.timeline
    list[#list + 1] = e
    if #list > FJ.CAPS.timeline + 20 then self:Prune() end
    FJ:NotifyDataChanged()
    return e
end

-- Removes the lowest priority (then oldest) entries until the cap is respected.
function Timeline:Prune()
    local list = FJ.db and FJ.db.timeline
    if not list then return end
    local cap = FJ.CAPS.timeline
    while #list > cap do
        local worst, worstIdx = math.huge, nil
        for i = 1, #list do
            local p = list[i].p or 40
            if p < worst and list[i].k ~= "start" then
                worst, worstIdx = p, i
            end
        end
        if not worstIdx then return end
        table.remove(list, worstIdx)
    end
end

function Timeline:Count()
    return FJ.db and #FJ.db.timeline or 0
end

function Timeline:Last(n)
    local list = FJ.db.timeline
    local out = {}
    for i = #list, math.max(1, #list - (n or 10) + 1), -1 do out[#out + 1] = list[i] end
    return out
end

function Timeline:HasKind(kind)
    for _, e in ipairs(FJ.db.timeline) do
        if e.k == kind then return true end
    end
    return false
end

local function Zone(e)
    return e.zn or (e.z and FJ.db.zones[e.z] and FJ.db.zones[e.z].name) or "the world"
end

-- Returns title, subtitle, icon, colour hex for an entry.
function Timeline:Describe(e)
    local k = e.k
    local icon = ICONS[k] or ICONS.start
    local color = COLORS[k] or "ffffffff"
    local title, sub

    if k == "start" then
        if e.a == "created" then
            title = "Your journey began"
            sub = "Started out in " .. Zone(e)
        else
            title = "Forever Journey started recording"
            sub = format("Level %d, in %s", e.l or 1, Zone(e))
            local behind = {}
            if e.b and e.b > 0 then behind[#behind + 1] = e.b .. " quests" end
            if e.d and e.d > 0 then behind[#behind + 1] = FJ.FormatNumber(e.d) .. " kills" end
            if e.c and e.c > 0 then behind[#behind + 1] = e.c .. (e.c == 1 and " death" or " deaths") end
            if #behind > 0 then sub = sub .. " - " .. table.concat(behind, ", ") .. " already behind you" end
        end
    elseif k == "level" then
        title = format("Reached level %d", e.a or e.l or 0)
        sub = "In " .. Zone(e)
        if e.b and e.b > 0 then sub = sub .. " - " .. FJ.FormatDuration(e.b) .. " played" end
    elseif k == "maxlevel" then
        title = format("Reached level %d - the summit", e.a or e.l or 0)
        sub = "In " .. Zone(e) .. (e.b and e.b > 0 and (" after " .. FJ.FormatDuration(e.b) .. " played") or "")
    elseif k == "zone" then
        title = "Discovered " .. (e.a or Zone(e))
        sub = format("First steps at level %d", e.l or 0)
    elseif k == "city" then
        title = "Arrived in " .. (e.a or Zone(e))
        sub = format("Level %d", e.l or 0)
    elseif k == "dungeon_first" then
        title = "First visit: " .. (e.a or "a dungeon")
        sub = format("Level %d", e.l or 0)
    elseif k == "dungeon_done" then
        title = "Completed " .. (e.a or "a dungeon")
        sub = (e.b and FJ.FormatDuration(e.b) or "") .. (e.c and (" - " .. e.c .. " bosses") or "")
    elseif k == "boss" then
        title = "Defeated " .. (e.a or "a boss")
        sub = e.b or Zone(e)
        if e.c then icon = ICONS.boss end
    elseif k == "prof" then
        title = "Learned " .. (e.a or "a profession")
        sub = format("Level %d", e.l or 0)
    elseif k == "prof_ms" then
        title = format("%s reached %d", e.a or "Profession", e.b or 0)
        sub = format("Level %d", e.l or 0)
    elseif k == "taxi" then
        title = "New flight path"
        sub = e.a or Zone(e)
    elseif k == "quest_first" then
        title = "First quest completed"
        sub = "In " .. Zone(e)
    elseif k == "quests" then
        title = format("%s quests completed", FJ.FormatNumber(e.a or 0))
        sub = format("Level %d, in %s", e.l or 0, Zone(e))
    elseif k == "death" then
        title = "Died in " .. Zone(e)
        sub = e.a and ("Killed by " .. e.a) or format("Level %d", e.l or 0)
    elseif k == "death_ms" then
        title = FJ.Ordinal(e.a or 0) .. " death"
        sub = "In " .. Zone(e) .. (e.b and (" - " .. e.b) or "")
    elseif k == "item" then
        title = "Obtained " .. (e.a or "an item")
        sub = "In " .. Zone(e)
        if e.a then
            local tex = FJ.API.GetItemIcon(e.a)
            if tex then icon = tex end
        end
    elseif k == "rare" then
        title = "Encountered " .. (e.a or "a rare")
        sub = "Rare creature in " .. Zone(e)
    elseif k == "played" then
        title = format("%d %s played", e.a or 0, (e.a == 1) and "day" or "days")
        sub = format("Level %d", e.l or 0)
    elseif k == "kills" then
        title = format("%s enemies slain", FJ.FormatNumber(e.a or 0))
        sub = format("Level %d, in %s", e.l or 0, Zone(e))
    elseif k == "gold" then
        title = "Earned " .. FJ.FormatMoney((e.a or 0) * 10000, true) .. " in total"
        sub = format("Level %d", e.l or 0)
    elseif k == "camp" then
        if (e.a or 1) == 1 then
            title = "First night by the campfire"
        else
            title = format("Camped for the %s time", FJ.Ordinal(e.a or 0))
        end
        sub = "In " .. Zone(e)
    elseif k == "group" then
        title = "First time in a group"
        sub = "In " .. Zone(e)
    elseif k == "home" then
        title = "Made " .. (e.a or "an inn") .. " your home"
        sub = format("Level %d", e.l or 0)
    elseif k == "gear" then
        title = "Equipped " .. (e.a or "something special")
        sub = "In " .. Zone(e)
        if e.a then
            local tex = FJ.API.GetItemIcon(e.a)
            if tex then icon = tex end
        end
    elseif k == "ride" then
        title = "First ride"
        sub = "Mounted up in " .. Zone(e)
    elseif k == "badge" then
        local def = FJ.Badges and FJ.Badges:Get(e.a)
        title = "Badge: " .. (def and def.name or tostring(e.a))
        sub = def and def.desc or ""
        if def and def.icon then icon = def.icon end
    elseif k == "pb" then
        title = "New best time in " .. (e.a or "a dungeon")
        sub = FJ.FormatDuration(e.b or 0) .. (e.c and (", was " .. FJ.FormatDuration(e.c)) or "")
    elseif k == "note" then
        title = e.a or "A note"
        sub = "Your own words, in " .. Zone(e)
    else
        title = tostring(k)
        sub = ""
    end
    return title, sub, icon, color
end

function Timeline.IconFor(kind)
    return ICONS[kind] or ICONS.start
end

function Timeline.ColorFor(kind)
    return COLORS[kind] or "ffffffff"
end
