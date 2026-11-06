-- Forever Journey: SavedVariables schema, defaults, identity, pruning.
local ADDON_NAME, FJ = ...

local DB_VERSION = 1

FJ.CAPS = {
    timeline = 300,
    sessions = 150,
    deaths = 100,
    runs = 40,
    items = 50,
    discNames = 60,
    killsByName = 300,
    deathsByKiller = 100,
    companions = 200,
    gearHistory = 150,
    homes = 30,
}

local CHAR_DEFAULTS = {
    version = DB_VERSION,
    char = {},
    totals = {
        tracked = 0,        -- seconds observed by the addon
        sessions = 0,
        played = 0,         -- last /played total reported by the server
        playedAt = 0,       -- when that value was received
        levelPlayed = 0,    -- /played at current level when last reported
        xp = 0, xpQuest = 0, xpKill = 0, xpExplore = 0,
        quests = 0,         -- turn-ins observed since install
        questsAccepted = 0,
        kills = 0,
        deaths = 0,
        goldEarned = 0, goldSpent = 0, peakGold = 0,
        discoveries = 0,
        flightsTaken = 0,
        dungeonRuns = 0, dungeonsCompleted = 0, bossKills = 0,
        raresSeen = 0,
        lootRare = 0, lootEpic = 0,
        ghostTime = 0,
        emotes = 0,
        campCount = 0, campTime = 0, campLongest = 0,
        sitCount = 0, sitTime = 0, sitLongest = 0, kneelTime = 0, sleepTime = 0,
        jumps = 0, distance = 0,
        trackedAtLastDeath = 0, longestNoDeath = 0,
    },
    emotes = {},
    clock = {},     -- [hour 0-23] = seconds played
    weekday = {},   -- [weekday 0-6, Sunday = 0] = seconds played
    days = {},      -- ["YYYYMMDD"] = seconds played
    companions = {},  -- [name] = { time, n, first, last, class }
    gear = {},        -- [slot] = { id, link, since (played seconds), t }
    gearHistory = {}, -- [itemID] = { link, worn (played seconds), first, slot }
    homes = {},       -- list of { name, t, lvl }
    zoneQuests = {},  -- [uiMapID] = { t = total, d = done, u = unobtainable } from QuestieDB
    levels = {},
    zones = {},
    taxi = {},
    professions = {},
    bosses = {},
    dungeons = {},
    runs = {},
    deaths = {},
    sessions = {},
    timeline = {},
    items = {},
    rares = {},
    killsByName = {},
    deathsByKiller = {},
    activity = { adventure = 0, dungeon = 0, pvp = 0, rest = 0, travel = 0, dead = 0, afk = 0 },
    flags = {},
}

local GLOBAL_DEFAULTS = {
    version = DB_VERSION,
    settings = {
        minimap = { hide = false, angle = 220 },
        window = {},
        scale = 1,
        showDeathsOnTimeline = true,
        suppressPlayedChat = true,
        welcomeShown = false,
        mapDeaths = true,
        mapFootprints = true,
        chatRecaps = true,
        toasts = true,
        toastMinPriority = 45,
        toastPos = {},
        zoneBanner = true,
        deathLine = true,
        runRecap = true,
    },
    roster = {},
}

local function CopyDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

function FJ:InitDB()
    if type(ForeverJourneyDB) ~= "table" then ForeverJourneyDB = {} end
    if type(ForeverJourneyCharDB) ~= "table" then ForeverJourneyCharDB = {} end
    self.gdb = ForeverJourneyDB
    self.db = ForeverJourneyCharDB
    CopyDefaults(self.gdb, GLOBAL_DEFAULTS)
    CopyDefaults(self.db, CHAR_DEFAULTS)
    self:MigrateDB()
    self:RefreshIdentity()

    local c = self.db.char
    if not c.firstSeen then
        c.firstSeen = time()
        c.firstSeenLevel = UnitLevel("player") or 1
        self.db.flags.freshInstall = true
    end
    self.db.version = DB_VERSION
    self.gdb.version = DB_VERSION
end

function FJ:MigrateDB()
    local db = self.db
    db.gold = db.gold or {}
    db.gold.earned = db.gold.earned or {}
    db.gold.spent = db.gold.spent or {}
    -- 0.1.0 logged professions that existed at install as "learned" at install time.
    if not db.flags.fixInstallProfs then
        db.flags.fixInstallProfs = true
        local first = db.char.firstSeen or 0
        if first > 0 then
            for _, p in pairs(db.professions) do
                if p.learned and math.abs(p.learned - first) < 60 then p.learned = nil end
            end
            for i = #db.timeline, 1, -1 do
                local e = db.timeline[i]
                if (e.k == "prof" or e.k == "prof_ms") and math.abs((e.t or 0) - first) < 60 then
                    table.remove(db.timeline, i)
                end
            end
        end
    end
end

function FJ:RefreshIdentity()
    local name = UnitName("player")
    local realm = GetRealmName()
    local className, classFile = UnitClass("player")
    local raceName, raceFile = UnitRace("player")
    self.playerName = name
    self.realm = realm
    self.playerClass = className
    self.playerClassFile = classFile
    self.playerRace = raceName
    self.playerRaceFile = raceFile
    self.playerFaction = UnitFactionGroup("player")
    self.playerGUID = UnitGUID("player")
    self.charKey = (name or "?") .. "-" .. (realm or "?")

    local c = self.db and self.db.char
    if c then
        c.name, c.realm = name, realm
        c.class, c.classFile = className, classFile
        c.race, c.raceFile = raceName, raceFile
        c.faction = self.playerFaction
        c.guid = self.playerGUID
        c.level = UnitLevel("player")
    end
end

-- Small per-character summary kept account-wide (future "all characters" view).
function FJ:UpdateRoster()
    if not (self.gdb and self.db and self.charKey) then return end
    local t = self.db.totals
    local life = self.Lifetime
    local function L(key) return life and life.Value and life:Value(key) or nil end
    self.gdb.roster[self.charKey] = {
        name = self.playerName,
        realm = self.realm,
        classFile = self.playerClassFile,
        race = self.playerRace,
        faction = self.playerFaction,
        level = UnitLevel("player"),
        played = (self.Session and self.Session.GetPlayed and self.Session:GetPlayed()) or t.played,
        deaths = L("deaths") or t.deaths,
        quests = (self.Quests and self.Quests.GetTotal and self.Quests:GetTotal()) or t.quests,
        kills = L("kills") or t.kills,
        gold = L("goldAcquired") or t.goldEarned,
        zones = FJ.CountKeys(self.db.zones),
        dungeons = L("dungeonsEntered") or t.dungeonRuns,
        flights = L("flights") or t.flightsTaken,
        badges = FJ.CountKeys(self.db.badges or {}),
        firstSeen = self.db.char.firstSeen,
        lastSeen = time(),
    }
end

-- Keep the current character's roster row fresh while playing (the others update at their logout).
FJ:RegisterMessage("FJ_DATA_CHANGED", function()
    FJ:Debounce("roster-refresh", 120, function() FJ:UpdateRoster() end)
end)

local function CapList(list, cap)
    while #list > cap do table.remove(list, 1) end
end

-- Keeps a name->count table under cap by dropping the smallest counts first.
-- With a field name, entries are tables and that numeric field is compared.
local function CapCounter(tbl, cap, field)
    local n = FJ.CountKeys(tbl)
    if n <= cap then return end
    local arr = {}
    for k, v in pairs(tbl) do
        local val = field and (type(v) == "table" and (v[field] or 0) or 0) or v
        arr[#arr + 1] = { k, val }
    end
    table.sort(arr, function(a, b) return a[2] < b[2] end)
    local toRemove = n - cap
    for i = 1, toRemove do tbl[arr[i][1]] = nil end
end

function FJ:PruneDB()
    local db = self.db
    if not db then return end
    CapList(db.sessions, self.CAPS.sessions)
    CapList(db.deaths, self.CAPS.deaths)
    CapList(db.runs, self.CAPS.runs)
    CapList(db.items, self.CAPS.items)
    CapCounter(db.killsByName, self.CAPS.killsByName)
    CapCounter(db.deathsByKiller, self.CAPS.deathsByKiller)
    if db.companions then CapCounter(db.companions, self.CAPS.companions, "time") end
    if db.gearHistory then CapCounter(db.gearHistory, self.CAPS.gearHistory, "worn") end
    if db.flights then CapCounter(db.flights, 100, "n") end
    -- one entry per day played; keep roughly the last two years
    if db.days and FJ.CountKeys(db.days) > 730 then
        local keys = {}
        for k in pairs(db.days) do keys[#keys + 1] = k end
        table.sort(keys)
        for i = 1, #keys - 730 do db.days[keys[i]] = nil end
    end
    if self.Timeline and self.Timeline.Prune then self.Timeline:Prune() end
end

-- Wipes this character's journey. The caller should /reload afterwards.
function FJ:ResetCharacterData()
    local db = self.db
    for k in pairs(db) do db[k] = nil end
    CopyDefaults(db, CHAR_DEFAULTS)
    db.char.firstSeen = time()
    db.char.firstSeenLevel = UnitLevel("player") or 1
    db.flags.freshInstall = true
    self:RefreshIdentity()
end
