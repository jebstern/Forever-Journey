-- Forever Journey: lifetime numbers from the game's own statistics (GetStatistic).
-- These include everything the character did before the addon was installed.
-- IDs were read from this client's own catalogue (/journey statdump, build 70170, 2 Oct 2026).
local ADDON_NAME, FJ = ...
local Lifetime = FJ:NewModule("Lifetime")

Lifetime.IDS = {
    -- deaths
    deaths = 60, deathsDrowning = 112, deathsFatigue = 113, deathsFalling = 114, deathsFire = 115,
    deathsHogger = 594, deathsPlayers = 1501, instanceDeaths = 321, dungeonDeaths = 918,
    -- quests
    quests = 98, questsAbandoned = 94,
    -- kills
    kills = 1197, killsXP = 1198, creatures = 107, critters = 108, killingBlows = 1487, honorableKills = 588,
    -- wealth (money strings)
    goldAcquired = 328, goldQuests = 326, goldLooted = 333, goldVendors = 921, goldAuctions = 919,
    goldTravel = 1146, goldPostage = 1148, goldPeak = 334, auctionBest = 332,
    -- travel
    flights = 349, hearths = 353, portals = 350, summons = 2277,
    -- instances
    dungeonsEntered = 932, raids10 = 933, raids20 = 934, raids40 = 64184,
    -- consumables
    bandages = 344, healthPotions = 345, beverages = 346, food = 347, manaPotions = 922, elixirs = 923, flasks = 811,
    -- gear
    epicsLooted = 341, epicsAcquired = 342, legendaries = 336, needRolls = 1044, greedRolls = 1043,
    -- pvp and social
    duelsWon = 319, duelsLost = 320, bgPlayed = 839, bgWon = 840,
    hugs = 1042, cheers = 1045, facepalms = 1047, waves = 1065, lols = 1066, violin = 1067,
    -- misc
    factions = 931, mostHonored = 529, professionsLearned = 1199, weaponSkillsMax = 1202, respecs = 1149,
    largestHit = 193, totalDamage = 197, totalHealing = 198, largestHitTaken = 527,
    mounts = 339, pets = 338, fish = 1518, fishingSkill = 1519,
    auctionsPosted = 329, auctionsBought = 330, goldPerDay = 753,
    cookingRecipes = 1745, firstAidManuals = 1748, alchemyRecipes = 1729,
    resPriest = 796, resRebirth = 798, resShaman = 799, resPaladin = 800, resSoulstone = 801, resRevive = 1229,
    worldHK = 381, bgHK = 382, worldKB = 1488,
    darkspearWins = 64176, darkspearBattles = 64179, darkspearDeaths = 64182, darkspearHK = 64180, darkspearKB = 64181,
}

-- Statistics whose value carries a label: "282 (Humanoid)".
Lifetime.LABELLED = {
    favouritePrey = 1336,
    bandageMost = 1125,
    killsContinent = 1489,
    bgMostPlayed = 2396,
    bgMostWon = 2397,
}

-- Final-boss kill counters: { statisticID, boss name, dungeon as named in our catalogue }.
Lifetime.BOSSES = {
    { 15027, "Bazzalan", "Ragefire Chasm" },
    { 15028, "Mutanus the Devourer", "Wailing Caverns" },
    { 63570, "Edwin VanCleef", "The Deadmines" },
    { 1092, "Archmage Arugal", "Shadowfang Keep" },
    { 15029, "Bazil Thredd", "The Stockade" },
    { 6137, "Aku'mai", "Blackfathom Deeps" },
    { 63573, "Durgen Dirgehammer", "Hall of Thanes" },
    { 63571, "Rath'mael", "Ruins of Lordaeron" },
    { 63572, "Shade of the Archmage", "City of Dalaran" },
    { 63589, "Lyn the Ignored", "City of Dalaran" },
    { 6140, "Mekgineer Thermaplugg", "Gnomeregan" },
    { 6139, "Charlga Razorflank", "Razorfen Kraul" },
    { 1093, "Scarlet Commander Mograine", "Scarlet Monastery: Cathedral" },
    { 6786, "High Inquisitor Whitemane", "Scarlet Monastery: Cathedral" },
    { 6141, "Amnennar the Coldbringer", "Razorfen Downs" },
    { 6142, "Archaedas", "Uldaman" },
    { 1094, "Chief Ukorz Sandscalp", "Zul'Farrak" },
    { 6143, "Princess Theradras", "Maraudon" },
    { 6144, "Shade of Eranikus", "Temple of Atal'Hakkar" },
    { 1095, "Emperor Dagran Thaurissan", "Blackrock Depths" },
    { 6145, "Overlord Wyrmthalak", "Lower Blackrock Spire" },
    { 1096, "General Drakkisath", "Upper Blackrock Spire" },
    { 6146, "King Gordok", "Dire Maul: North" },
    { 15030, "Darkmaster Gandling", "Scholomance" },
    { 15031, "Baron Rivendare", "Stratholme" },
    { 1098, "Onyxia", "Onyxia's Lair" },
    { 63574, "Nanaya", "Shaper's Terrace" },
    { 63575, "Blazeroar", "Alcaz Prison" },
    { 63581, "Sonya Darkhallow", "Barrow Deeps" },
    { 63580, "The Wild King", "Hyjal Summit" },
}

function Lifetime:Available()
    return type(GetStatistic) == "function"
end

-- GetStatistic returns strings: "--" for nothing, digits (possibly with separators), a money
-- string with coin textures, or "123 (Label)". Returns number (copper for money) and label.
local function Parse(raw)
    if raw == nil then return nil end
    if type(raw) ~= "string" then raw = tostring(raw) end
    if raw == "" or raw == "--" then return nil end
    local lower = raw:lower()
    if lower:find("|t", 1, true) or lower:find("|a", 1, true) then
        local hasG = lower:find("gold", 1, true) ~= nil
        local hasS = lower:find("silver", 1, true) ~= nil
        local hasC = lower:find("copper", 1, true) ~= nil
        local clean = raw:gsub("|T.-|t", " "):gsub("|A.-|a", " "):gsub("(%d)[,%.](%d%d%d)", "%1%2")
        local nums = {}
        for n in clean:gmatch("%d+") do nums[#nums + 1] = tonumber(n) end
        local i, g, s, c = 1, 0, 0, 0
        if hasG then g = nums[i] or 0; i = i + 1 end
        if hasS then s = nums[i] or 0; i = i + 1 end
        if hasC then c = nums[i] or 0 end
        if not (hasG or hasS or hasC) then
            g, s, c = nums[1] or 0, nums[2] or 0, nums[3] or 0
        end
        return g * 10000 + s * 100 + c
    end
    local num, label = raw:match("^%s*([%d,%.]+)%s*%((.-)%)%s*$")
    if num then
        return tonumber((num:gsub("[^%d]", ""))), label
    end
    local digits = raw:gsub("[^%d]", "")
    return tonumber(digits)
end
Lifetime.Parse = Parse

function Lifetime:Get(id)
    if not self:Available() then return nil end
    local ok, raw = pcall(GetStatistic, id)
    if not ok or not FJ.canaccess(raw) then return nil end
    return Parse(raw)
end

function Lifetime:Refresh()
    if not self:Available() or not FJ.db then return end
    local db = FJ.db
    db.lifetime = db.lifetime or {}
    local L = db.lifetime
    L.bosses = L.bosses or {}
    local changed = false
    for key, id in pairs(self.IDS) do
        local v = self:Get(id)
        if v ~= nil and v ~= L[key] then
            L[key] = v
            changed = true
        end
    end
    for key, id in pairs(self.LABELLED) do
        local v, label = self:Get(id)
        if v ~= nil and (v ~= L[key] or label ~= L[key .. "Label"]) then
            L[key] = v
            L[key .. "Label"] = label
            changed = true
        end
    end
    for _, b in ipairs(self.BOSSES) do
        local v = self:Get(b[1])
        if v and v > 0 and v ~= L.bosses[b[1]] then
            L.bosses[b[1]] = v
            changed = true
        end
    end
    L.at = time()
    if changed then FJ:NotifyDataChanged() end
end

function Lifetime:Value(key)
    local L = FJ.db and FJ.db.lifetime
    return L and L[key] or nil
end

function Lifetime:Label(key)
    local L = FJ.db and FJ.db.lifetime
    return L and L[key .. "Label"] or nil
end

-- Final bosses killed in this character's lifetime: { id, name, dungeon, n }, most kills first.
function Lifetime:BossKills()
    local L = FJ.db and FJ.db.lifetime
    local out = {}
    if not L or not L.bosses then return out end
    for _, b in ipairs(self.BOSSES) do
        local n = L.bosses[b[1]]
        if n and n > 0 then out[#out + 1] = { id = b[1], name = b[2], dungeon = b[3], n = n } end
    end
    table.sort(out, function(a, b) return a.n > b.n end)
    return out
end

function Lifetime:DungeonDone(dungeonName)
    for _, b in ipairs(self:BossKills()) do
        if b.dungeon == dungeonName then return true, b.n end
    end
    return false
end

function Lifetime:DungeonsConquered()
    local seen, n = {}, 0
    for _, b in ipairs(self:BossKills()) do
        if not seen[b.dungeon] then
            seen[b.dungeon] = true
            n = n + 1
        end
    end
    return n
end

-- Enumerates every statistic the client knows and stores it account-wide so it can be read
-- from the SavedVariables file after a reload.
function Lifetime:Dump()
    if not (GetStatisticsCategoryList and GetCategoryNumAchievements and GetAchievementInfo and GetStatistic) then
        FJ.Print("This client does not expose the statistics catalogue.")
        return
    end
    local ok, cats = pcall(GetStatisticsCategoryList)
    if not ok or type(cats) ~= "table" then
        FJ.Print("GetStatisticsCategoryList failed.")
        return
    end
    local entries, n = {}, 0
    for _, cat in ipairs(cats) do
        local okC, catName, parent = pcall(GetCategoryInfo, cat)
        local okN, count = pcall(GetCategoryNumAchievements, cat)
        count = (okN and tonumber(count)) or 0
        for i = 1, count do
            local okA, id, name = pcall(GetAchievementInfo, cat, i)
            if okA and id then
                local okS, raw = pcall(GetStatistic, id)
                entries[#entries + 1] = {
                    id = id, cat = cat, catName = okC and catName or nil, parent = okC and parent or nil,
                    name = FJ.canaccess(name) and name or nil, raw = (okS and FJ.canaccess(raw)) and tostring(raw) or nil,
                }
                n = n + 1
            end
        end
    end
    FJ.gdb.statDump = { at = time(), build = FJ.build, char = FJ.charKey, entries = entries }
    FJ.Print(format("Saved %d statistics from %d categories. Type /reload to write them to disk.", n, #cats))
end

function Lifetime:OnEnable()
    FJ:After(5, function() Lifetime:Refresh() end)
    FJ:RegisterEvent("CRITERIA_UPDATE", function()
        FJ:Debounce("lifetime-refresh", 5, function() Lifetime:Refresh() end)
    end)
    FJ:RegisterMessage("FJ_DATA_CHANGED", function()
        FJ:Debounce("lifetime-refresh", 15, function() Lifetime:Refresh() end)
    end)
end
