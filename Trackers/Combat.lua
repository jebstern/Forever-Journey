-- Forever Journey: kills, deaths, boss kills and rare encounters.
-- Every combat-log value is checked with canaccessvalue before it is compared or indexed,
-- so secret values inside instances are skipped rather than erroring.
local ADDON_NAME, FJ = ...
local Combat = FJ:NewModule("Combat")

local canaccess = FJ.canaccess
local playerGUID, petGUID
local lastAttacker, lastAttackerAt
local lastBossKill = {}
local killNameCount = 0

Combat.cleuEvents = 0
Combat.cleuSecret = 0

local DAMAGE = {
    SWING_DAMAGE = true, RANGE_DAMAGE = true, SPELL_DAMAGE = true,
    SPELL_PERIODIC_DAMAGE = true, ENVIRONMENTAL_DAMAGE = true, SPELL_BUILDING_DAMAGE = true,
}
local ENV = { Falling = "Falling", Drowning = "Drowning", Fatigue = "Fatigue", Fire = "Fire", Lava = "Lava", Slime = "Slime" }
local KILL_MILESTONES = { 100, 500, 1000, 2500, 5000, 10000, 25000, 50000, 100000 }
local DEATH_MILESTONES = { 1, 10, 25, 50, 100, 200, 300, 500 }

---------------------------------------------------------------------------
-- Combat log
---------------------------------------------------------------------------
local function OnCLEU()
    local _, sub, _, srcGUID, srcName, _, _, dstGUID, dstName = CombatLogGetCurrentEventInfo()
    Combat.cleuEvents = Combat.cleuEvents + 1
    if not canaccess(sub) then
        Combat.cleuSecret = Combat.cleuSecret + 1
        return
    end
    if sub == "PARTY_KILL" then
        if canaccess(srcGUID) and (srcGUID == playerGUID or (petGUID and srcGUID == petGUID)) then
            Combat:OnKill(canaccess(dstName) and dstName or nil)
        end
    elseif sub == "UNIT_DIED" then
        if canaccess(dstGUID) then
            local npcID = FJ.NpcIDFromGUID(dstGUID)
            if npcID then Combat:OnUnitDied(npcID, canaccess(dstName) and dstName or nil) end
        end
    elseif DAMAGE[sub] then
        if canaccess(dstGUID) and dstGUID == playerGUID then
            if sub == "ENVIRONMENTAL_DAMAGE" then
                local envType = select(12, CombatLogGetCurrentEventInfo())
                if canaccess(envType) and type(envType) == "string" then
                    lastAttacker = ENV[envType] or envType
                else
                    lastAttacker = "the environment"
                end
            else
                lastAttacker = (canaccess(srcName) and type(srcName) == "string") and srcName or nil
            end
            lastAttackerAt = GetTime()
        end
    end
end

---------------------------------------------------------------------------
-- Kills
---------------------------------------------------------------------------
local lastKillAt, lastKillName = 0, nil

-- Chat fallbacks for clients where the combat log is secret (Forever behaves like Retail 12.0
-- here): "You have slain X!" and "X dies, you gain N experience." Deduplicated against the
-- combat log within a short window.
local slainPattern, xpKillPattern
local function KillFromChat(name)
    local now = GetTime()
    if now - lastKillAt < 1.0 and (lastKillName == nil or lastKillName == name or name == nil) then return end
    Combat:OnKill(name)
end

function Combat:OnHostileDeathChat(msg)
    if type(msg) ~= "string" or not canaccess(msg) then return end
    if not slainPattern then slainPattern = FJ.FormatToPattern(SELFKILLOTHER) end
    if slainPattern then
        local name = msg:match(slainPattern)
        if name then
            KillFromChat(name)
            return
        end
    end
    self:OnHostileDeathMessage(msg)
end

function Combat:OnXPGainChat(msg)
    if type(msg) ~= "string" or not canaccess(msg) then return end
    if xpKillPattern == nil then
        local fmt = COMBATLOG_XPGAIN_FIRSTPERSON
        if type(fmt) == "string" then
            -- "%s dies, you gain %d experience." Keep only the prefix so bonus suffixes still match.
            local prefix = fmt:match("^(.-%%d)") or fmt
            local p = FJ.FormatToPattern(prefix)
            if p then p = p:gsub("%$$", "") end
            xpKillPattern = p or false
        else
            xpKillPattern = false
        end
    end
    if not xpKillPattern then return end
    local name = msg:match(xpKillPattern)
    if name then KillFromChat(name) end
end

function Combat:OnKill(name)
    local db = FJ.db
    local t = db.totals
    t.kills = t.kills + 1
    lastKillAt, lastKillName = GetTime(), name

    local mapID = FJ.Zones:GetCurrent()
    local z = mapID and db.zones[mapID]
    if z then z.k = (z.k or 0) + 1 end
    local L = db.levels[UnitLevel("player")]
    if L then L.k = (L.k or 0) + 1 end
    FJ.Session:Bump("k", 1)
    if FJ.Dungeons then FJ.Dungeons:OnKill() end

    if name then
        local kb = db.killsByName
        if not kb[name] then
            killNameCount = killNameCount + 1
            if killNameCount > FJ.CAPS.killsByName + 50 then
                FJ:PruneDB()
                killNameCount = FJ.CountKeys(kb)
            end
        end
        kb[name] = (kb[name] or 0) + 1
    end

    local flags = db.flags
    for _, m in ipairs(KILL_MILESTONES) do
        if t.kills >= m and (flags.killMs or 0) < m then
            flags.killMs = m
            FJ.Timeline:Add("kills", FJ.Timeline.PRIO.kills, { a = m })
        end
    end
    FJ:NotifyDataChanged()
end

---------------------------------------------------------------------------
-- Bosses and rares
---------------------------------------------------------------------------
function Combat:OnUnitDied(npcID, name)
    local boss = FJ.Data.Bosses[npcID]
    if boss then self:OnBossKilled(npcID, boss, name) end
    local rare = FJ.db.rares[npcID]
    if rare and not rare.killed then
        rare.killed = time()
        FJ:NotifyDataChanged()
    end
end

function Combat:OnBossKilled(npcID, boss, name)
    local now = GetTime()
    if lastBossKill[npcID] and now - lastBossKill[npcID] < 10 then return end
    lastBossKill[npcID] = now

    local db = FJ.db
    db.totals.bossKills = db.totals.bossKills + 1
    local rec = db.bosses[npcID]
    local first = rec == nil
    if not rec then
        rec = { n = 0, first = time(), name = name or boss.n }
        db.bosses[npcID] = rec
    end
    rec.n = rec.n + 1
    rec.last = time()
    if name then rec.name = name end
    if first then
        local P = FJ.Timeline.PRIO
        FJ.Timeline:Add("boss", boss.f and P.boss_final or P.boss, { a = rec.name, b = boss.d, c = boss.f })
    end
    FJ:SendMessage("FJ_BOSS_KILLED", npcID, boss, rec.name, first)
    FJ:NotifyDataChanged()
end

-- Fallback when the combat log is unavailable: "%s dies." chat messages.
local diesPattern
function Combat:OnHostileDeathMessage(msg)
    if type(msg) ~= "string" or not canaccess(msg) then return end
    if not diesPattern then diesPattern = FJ.FormatToPattern(UNITDIESOTHER) end
    if not diesPattern then return end
    local name = msg:match(diesPattern)
    if not name then return end
    local npcID, boss = FJ.Data.BossByName(name)
    if npcID then self:OnBossKilled(npcID, boss, name) end
end

local lastHostileName, lastHostileAt = nil, 0

function Combat:OnTargetChanged()
    -- Target predicates can be secret booleans (instances); an unreadable target is skipped.
    if not FJ.Bool(UnitExists("target")) or FJ.Bool(UnitIsPlayer("target"), true) then return end
    if not FJ.Bool(UnitCanAttack("player", "target")) then return end
    -- Remembered as the probable killer when the combat log cannot tell us.
    local tname = UnitName("target")
    if canaccess(tname) and type(tname) == "string" then
        lastHostileName, lastHostileAt = tname, GetTime()
    end
    local cls = UnitClassification("target")
    if not canaccess(cls) or (cls ~= "rare" and cls ~= "rareelite") then return end
    local guid = UnitGUID("target")
    if not canaccess(guid) then return end
    local npcID = FJ.NpcIDFromGUID(guid)
    if not npcID then return end
    local db = FJ.db
    if db.rares[npcID] then return end
    local name = UnitName("target")
    if not (canaccess(name) and type(name) == "string") then name = "a rare creature" end
    local lvl = UnitLevel("target")
    if not canaccess(lvl) then lvl = nil end
    local mapID, zoneName = FJ.Zones:GetCurrent()
    db.rares[npcID] = { name = name, t = time(), z = mapID, zn = zoneName, lvl = lvl }
    db.totals.raresSeen = db.totals.raresSeen + 1
    FJ.Timeline:Add("rare", FJ.Timeline.PRIO.rare, { a = name })
    FJ:NotifyDataChanged()
end

---------------------------------------------------------------------------
-- Deaths
---------------------------------------------------------------------------
function Combat:OnPlayerDead()
    local db = FJ.db
    local t = db.totals
    t.deaths = t.deaths + 1

    -- Deathless streak, measured in tracked play time.
    local streak = (t.tracked or 0) - (t.trackedAtLastDeath or 0)
    if streak > (t.longestNoDeath or 0) then t.longestNoDeath = streak end
    t.trackedAtLastDeath = t.tracked or 0
    t.lastDeathAt = time()

    local killer
    if lastAttackerAt and GetTime() - lastAttackerAt < 15 then killer = lastAttacker end
    if not killer and lastHostileName and GetTime() - lastHostileAt < 30 then killer = lastHostileName end

    local mapID, zoneName, isInst = FJ.Zones:GetCurrent()
    local z = mapID and (not isInst) and db.zones[mapID]
    if z then z.d = (z.d or 0) + 1 end
    local lvl = UnitLevel("player")
    local L = db.levels[lvl]
    if L then L.d = (L.d or 0) + 1 end
    FJ.Session:Bump("dth", 1)
    if FJ.Dungeons then FJ.Dungeons:OnDeath() end
    if killer then db.deathsByKiller[killer] = (db.deathsByKiller[killer] or 0) + 1 end

    -- Position for the World Map tombstones (nil inside instances or where the map has no position).
    local pm, px, py
    if C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition then
        local okM, best = pcall(C_Map.GetBestMapForUnit, "player")
        if okM and best then
            local okP, pos = pcall(C_Map.GetPlayerMapPosition, best, "player")
            if okP and pos and type(pos.x) == "number" and canaccess(pos.x) and canaccess(pos.y) then
                pm, px, py = best, FJ.Round(pos.x, 4), FJ.Round(pos.y, 4)
            end
        end
    end
    FJ.PushCapped(db.deaths, { t = time(), l = lvl, z = mapID, zn = zoneName, k = killer, m = pm, x = px, y = py }, FJ.CAPS.deaths)

    -- deaths by hour of day (for "deadliest hour")
    db.deathClock = db.deathClock or {}
    local hour = tonumber(date("%H")) or 0
    db.deathClock[hour] = (db.deathClock[hour] or 0) + 1

    local n = t.deaths
    local milestone = false
    for _, m in ipairs(DEATH_MILESTONES) do
        if n == m then milestone = true end
    end
    if not milestone and n > 500 and n % 100 == 0 then milestone = true end
    local P = FJ.Timeline.PRIO
    if milestone then
        FJ.Timeline:Add("death_ms", P.death_ms, { a = n, b = killer and ("killed by " .. killer) or nil })
    else
        FJ.Timeline:Add("death", P.death, { a = killer })
    end
    FJ:SendMessage("FJ_PLAYER_DIED", {
        killer = killer,
        killerCount = killer and db.deathsByKiller[killer] or nil,
        streak = streak,
        zoneDeaths = z and z.d or nil,
        zoneName = zoneName,
        total = n,
    })
    FJ:NotifyDataChanged()
end

---------------------------------------------------------------------------
-- Wiring
---------------------------------------------------------------------------
function Combat:OnEnable()
    playerGUID = UnitGUID("player")
    petGUID = UnitGUID("pet")
    killNameCount = FJ.CountKeys(FJ.db.killsByName)
    FJ.Data.MergeExternalBosses()
    -- The combat log is a protected resource on Forever; FJ:RegisterEvent refuses it there.
    self.cleuRegistered = FJ:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", OnCLEU) or false
    FJ:RegisterEvent("PLAYER_DEAD", function() Combat:OnPlayerDead() end)
    FJ:RegisterEvent("PLAYER_TARGET_CHANGED", function() Combat:OnTargetChanged() end)
    FJ:RegisterUnitEvent("UNIT_PET", "player", function() petGUID = UnitGUID("pet") end)
    FJ:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH", function(_, msg) Combat:OnHostileDeathChat(msg) end)
    FJ:RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN", function(_, msg) Combat:OnXPGainChat(msg) end)
    -- Encounter events, if this client scripts dungeon bosses as encounters.
    FJ:RegisterEvent("ENCOUNTER_END", function(_, encounterID, name, _, _, success)
        if success == 1 or success == true then Combat:OnEncounterEnd(encounterID, name) end
    end)
    FJ:RegisterEvent("BOSS_KILL", function(_, encounterID, name) Combat:OnEncounterEnd(encounterID, name) end)
end

function Combat:OnEncounterEnd(encounterID, name)
    if not (canaccess(name) and type(name) == "string") then return end
    local npcID, boss = FJ.Data.BossByName(name)
    if not npcID then
        local instName = GetInstanceInfo()
        npcID = "e" .. tostring(encounterID or name)
        boss = { n = name, d = (canaccess(instName) and instName) or "an instance" }
    end
    self:OnBossKilled(npcID, boss, name)
end

-- Diagnostic summary for /journey probe.
function Combat:ProbeReport()
    return {
        cleuRegistered = self.cleuRegistered or false,
        cleuEvents = self.cleuEvents,
        cleuSecret = self.cleuSecret,
        hasCanAccess = _G.canaccessvalue ~= nil,
        hasSecrets = _G.C_Secrets ~= nil,
    }
end
