-- Forever Journey: personal badges. Lightweight achievements computed from data we already keep.
-- Earned badges become chapters; nothing here is a checklist the player has to chase.
local ADDON_NAME, FJ = ...
local Badges = FJ:NewModule("Badges")

local I = "Interface\\Icons\\"
Badges.DEFS = {
    { id = "deathless_level", name = "Untouchable", desc = "Finish a level without dying", icon = I .. "Spell_Holy_DivineProtection", event = "level" },
    { id = "iron_will", name = "Iron Will", desc = "Ten hours of play without a death", icon = I .. "Spell_Holy_HolyProtection" },
    { id = "nine_lives", name = "Nine Lives", desc = "Die nine times", icon = I .. "INV_Misc_Bone_HumanSkull_01" },
    { id = "cartographer", name = "Cartographer", desc = "Uncover every area of a zone", icon = I .. "INV_Misc_Map02" },
    { id = "globetrotter", name = "Globetrotter", desc = "Visit 20 zones", icon = I .. "INV_Misc_Map_01" },
    { id = "world_traveler", name = "World Traveller", desc = "Visit 40 zones", icon = I .. "INV_Misc_Map_01" },
    { id = "explorer_50", name = "Pathfinder", desc = "Discover 50 areas", icon = I .. "INV_Misc_Spyglass_02" },
    { id = "marathon", name = "Marathon", desc = "A single session of six hours", icon = I .. "INV_Misc_PocketWatch_01" },
    { id = "night_owl", name = "Night Owl", desc = "Ten hours played between midnight and five", icon = I .. "Spell_Nature_Sleep" },
    { id = "early_bird", name = "Early Bird", desc = "Ten hours played between five and eight in the morning", icon = I .. "INV_Egg_01" },
    { id = "streak_7", name = "Habit", desc = "Play seven days in a row", icon = I .. "INV_Misc_PocketWatch_01" },
    { id = "devoted", name = "Devoted", desc = "100 hours played", icon = I .. "INV_Misc_PocketWatch_01" },
    { id = "veteran", name = "Veteran", desc = "Ten days played", icon = I .. "INV_Misc_PocketWatch_01" },
    { id = "frequent_flyer", name = "Frequent Flyer", desc = "Take 100 flights", icon = I .. "Ability_Mount_Gryphon_01" },
    { id = "hopper", name = "Hopper", desc = "Jump 1,000 times", icon = I .. "Ability_Rogue_Sprint" },
    { id = "jumper", name = "Spring-Heeled", desc = "Jump 10,000 times", icon = I .. "Ability_Rogue_Sprint" },
    { id = "wanderer", name = "Wanderer", desc = "Travel 100 km on foot or mount", icon = I .. "Ability_Hunter_Pathfinding" },
    { id = "nomad", name = "Nomad", desc = "Travel 1,000 km on foot or mount", icon = I .. "Ability_Hunter_Pathfinding" },
    { id = "camper", name = "Happy Camper", desc = "Camp 50 times", icon = I .. "Spell_Fire_Fire" },
    { id = "sitter", name = "Take a Seat", desc = "Spend an hour sitting down", icon = I .. "Spell_Nature_Sleep" },
    { id = "homebody", name = "Many Homes", desc = "Bind your hearthstone in three different inns", icon = I .. "INV_Misc_Rune_01" },
    { id = "centurion", name = "Centurion", desc = "Hand in 100 quests since recording began", icon = I .. "INV_Misc_Note_01" },
    { id = "questmaster", name = "Quest Master", desc = "500 quests completed", icon = I .. "INV_Misc_Note_02" },
    { id = "slayer", name = "Slayer", desc = "1,000 enemies slain", icon = I .. "Ability_Warrior_Cleave" },
    { id = "reaper", name = "Reaper", desc = "10,000 enemies slain", icon = I .. "Ability_Warrior_Cleave" },
    { id = "boss_slayer", name = "Boss Slayer", desc = "Defeat 25 bosses", icon = I .. "INV_Misc_Head_Dragon_01" },
    { id = "delver", name = "Delver", desc = "Ten dungeon runs", icon = I .. "INV_Misc_Key_03" },
    { id = "dungeon_master", name = "Dungeon Master", desc = "Conquer ten different dungeons", icon = I .. "INV_Misc_Head_Dragon_01" },
    { id = "collector", name = "Collector", desc = "Loot ten rare or epic items", icon = I .. "INV_Misc_Gem_01" },
    { id = "socialite", name = "Socialite", desc = "Use 100 emotes", icon = I .. "INV_Misc_Toy_04" },
    { id = "hugger", name = "Hugger", desc = "Give 50 hugs", icon = I .. "Spell_Holy_PrayerOfHealing02" },
    { id = "friendly", name = "Good Company", desc = "Group with ten different people", icon = I .. "Spell_Holy_PrayerOfHealing02" },
    { id = "party_animal", name = "Party Animal", desc = "Group with 50 different people", icon = I .. "Spell_Holy_PrayerOfHealing02" },
    { id = "rich", name = "Comfortable", desc = "Acquire 100 gold in total", icon = I .. "INV_Misc_Coin_02" },
    { id = "tycoon", name = "Tycoon", desc = "Acquire 1,000 gold in total", icon = I .. "INV_Misc_Coin_02" },
    { id = "max_level", name = "The Summit", desc = "Reach the maximum level", icon = I .. "INV_Crown_01" },
}

local byID = {}
for _, def in ipairs(Badges.DEFS) do byID[def.id] = def end

local function life(key) return FJ.Lifetime:Value(key) end
local function km(db) return (db.totals.distance or 0) * 0.0009144 end

local checks = {
    deathless_level = function(ctx) return ctx.event == "level" and ctx.prevLevel ~= nil and (ctx.prevLevel.d or 0) == 0 and (ctx.prevTime or 0) >= 600 end,
    iron_will = function() local _, longest = FJ.Stats:DeathlessStreak() return longest >= 36000 end,
    nine_lives = function(_, db) return (life("deaths") or db.totals.deaths or 0) >= 9 end,
    cartographer = function() return FJ.Stats:ExplorationSummary().complete >= 1 end,
    globetrotter = function() return FJ.Stats:ZonesVisited() >= 20 end,
    world_traveler = function() return FJ.Stats:ZonesVisited() >= 40 end,
    explorer_50 = function(_, db) return (db.totals.discoveries or 0) >= 50 end,
    marathon = function(_, db)
        if FJ.Session:Duration() >= 21600 then return true end
        for _, s in ipairs(db.sessions) do if (s.d or 0) >= 21600 then return true end end
        return false
    end,
    night_owl = function(_, db) local c = db.clock or {} return ((c[0] or 0) + (c[1] or 0) + (c[2] or 0) + (c[3] or 0) + (c[4] or 0)) >= 36000 end,
    early_bird = function(_, db) local c = db.clock or {} return ((c[5] or 0) + (c[6] or 0) + (c[7] or 0)) >= 36000 end,
    streak_7 = function() local d = FJ.Stats:Days() return d.current >= 7 or d.longest >= 7 end,
    devoted = function() return FJ.Session:GetPlayed() >= 360000 end,
    veteran = function() return FJ.Session:GetPlayed() >= 864000 end,
    frequent_flyer = function(_, db) return (life("flights") or db.totals.flightsTaken or 0) >= 100 end,
    hopper = function(_, db) return (db.totals.jumps or 0) >= 1000 end,
    jumper = function(_, db) return (db.totals.jumps or 0) >= 10000 end,
    wanderer = function(_, db) return km(db) >= 100 end,
    nomad = function(_, db) return km(db) >= 1000 end,
    camper = function(_, db) return (db.totals.campCount or 0) >= 50 end,
    sitter = function(_, db) return (db.totals.sitTime or 0) >= 3600 end,
    homebody = function(_, db) return #(db.homes or {}) >= 3 end,
    centurion = function(_, db) return (db.totals.quests or 0) >= 100 end,
    questmaster = function() return FJ.Quests:GetTotal() >= 500 end,
    slayer = function(_, db) return (life("kills") or db.totals.kills or 0) >= 1000 end,
    reaper = function(_, db) return (life("kills") or db.totals.kills or 0) >= 10000 end,
    boss_slayer = function(_, db)
        local n = 0
        for _, b in ipairs(FJ.Lifetime:BossKills()) do n = n + b.n end
        return math.max(n, db.totals.bossKills or 0) >= 25
    end,
    delver = function(_, db) return (life("dungeonsEntered") or db.totals.dungeonRuns or 0) >= 10 end,
    dungeon_master = function() return math.max(FJ.Lifetime:DungeonsConquered(), FJ.Stats:DungeonsCleared()) >= 10 end,
    collector = function(_, db) return ((db.totals.lootRare or 0) + (db.totals.lootEpic or 0)) >= 10 end,
    socialite = function(_, db) return (db.totals.emotes or 0) >= 100 end,
    hugger = function() return (life("hugs") or FJ.Social:EmoteCount("HUG")) >= 50 end,
    friendly = function() return FJ.Companions:Count() >= 10 end,
    party_animal = function() return FJ.Companions:Count() >= 50 end,
    rich = function(_, db) return (life("goldAcquired") or db.totals.goldEarned or 0) >= 100 * 10000 end,
    tycoon = function(_, db) return (life("goldAcquired") or db.totals.goldEarned or 0) >= 1000 * 10000 end,
    max_level = function() return (UnitLevel("player") or 1) >= FJ.API.MaxLevel() end,
}

function Badges:Get(id)
    return byID[id]
end

function Badges:Award(def)
    FJ.db.badges = FJ.db.badges or {}
    FJ.db.badges[def.id] = time()
    FJ.Timeline:Add("badge", 65, { a = def.id })
end

-- ctx.event = "level" with prevLevel/prevTime enables the per-level checks.
function Badges:Evaluate(ctx)
    local db = FJ.db
    if not db then return end
    db.badges = db.badges or {}
    ctx = ctx or {}
    for _, def in ipairs(self.DEFS) do
        if not db.badges[def.id] and (not def.event or def.event == ctx.event) then
            local check = checks[def.id]
            if check then
                local ok, res = pcall(check, ctx, db)
                if ok and res then self:Award(def) end
            end
        end
    end
end

-- earned: { def, t } sorted by time; remaining: array of defs not yet earned
function Badges:List()
    local earned, remaining = {}, {}
    local have = (FJ.db and FJ.db.badges) or {}
    for _, def in ipairs(self.DEFS) do
        if have[def.id] then earned[#earned + 1] = { def = def, t = have[def.id] } else remaining[#remaining + 1] = def end
    end
    table.sort(earned, function(a, b) return a.t < b.t end)
    return earned, remaining
end

function Badges:Count()
    local earned = self:List()
    return #earned, #self.DEFS
end

function Badges:OnEnable()
    -- The first pass after login awards anything already true without banners.
    FJ:After(30, function()
        Badges.quiet = true
        Badges:Evaluate()
        Badges.quiet = false
    end)
    FJ:RegisterMessage("FJ_DATA_CHANGED", function()
        FJ:Debounce("badges", 8, function() Badges:Evaluate() end)
    end)
    FJ:RegisterEvent("PLAYER_LEVEL_UP", function(_, level)
        FJ:After(3, function()
            level = tonumber(level) or UnitLevel("player")
            local prevTime
            for _, r in ipairs(FJ.Stats:TimePerLevel()) do
                if r.level == level - 1 then prevTime = r.time end
            end
            Badges:Evaluate({ event = "level", prevLevel = FJ.db.levels[level - 1], prevTime = prevTime })
        end)
    end)
end
