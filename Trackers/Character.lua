-- Forever Journey: levels, experience, gold and professions.
local ADDON_NAME, FJ = ...
local Character = FJ:NewModule("Character")

local lastXP, lastXPMax, lastLevel, lastMoney
local pendingQuestXP, pendingQuestAt = 0, 0
local pendingExploreXP, pendingExploreAt = 0, 0
local lastDeltaKill, lastDeltaAt = 0, 0
local PENDING_WINDOW = 3
local enabledAt = 0

local GOLD_MILESTONES = { 1, 10, 100, 1000, 10000 }

---------------------------------------------------------------------------
-- Level
---------------------------------------------------------------------------
function Character:OnLevelUp(level)
    level = tonumber(level) or UnitLevel("player")
    local db = FJ.db
    local played = FJ.Session:GetPlayed()
    local mapID = FJ.Zones:GetCurrent()
    local L = db.levels[level] or { time = 0, xp = 0, q = 0, k = 0, d = 0 }
    db.levels[level] = L
    L.t = time()
    L.played = played
    L.zone = mapID
    L.seeded = nil

    local P = FJ.Timeline.PRIO
    if level >= FJ.API.MaxLevel() then
        FJ.Timeline:Add("maxlevel", P.maxlevel, { a = level, b = played })
    else
        local prio = (level % 10 == 0) and P.level_big or ((level % 5 == 0) and P.level_mid or P.level)
        FJ.Timeline:Add("level", prio, { a = level, b = played })
    end
    local s = FJ.Session:Current()
    if s then s.lvl1 = level end
    db.char.level = level
    lastLevel = level
    FJ:After(2, function() FJ.Session:RequestPlayed() end)

    -- Chat recap of the level just finished.
    if FJ.gdb.settings.chatRecaps then
        local prev = db.levels[level - 1]
        local msg = format("Level %d after %s played.", level, FJ.FormatDuration(played))
        if prev then
            local took = (type(prev.played) == "number" and played >= prev.played) and (played - prev.played) or (prev.time or 0)
            local parts = {}
            if (prev.q or 0) > 0 then parts[#parts + 1] = prev.q .. (prev.q == 1 and " quest" or " quests") end
            if (prev.k or 0) > 0 then parts[#parts + 1] = FJ.FormatNumber(prev.k) .. " kills" end
            if (prev.d or 0) > 0 then parts[#parts + 1] = prev.d .. (prev.d == 1 and " death" or " deaths") end
            if took > 0 then
                msg = msg .. format(" Level %d took %s", level - 1, FJ.FormatDuration(took))
                msg = msg .. (#parts > 0 and (": " .. table.concat(parts, ", ") .. ".") or ".")
            end
        end
        local _, zoneName = FJ.Zones:GetCurrent()
        if zoneName then msg = msg .. " Reached in " .. zoneName .. "." end
        FJ.Print(msg)
    end
    FJ:NotifyDataChanged()
end

---------------------------------------------------------------------------
-- Experience
---------------------------------------------------------------------------
function Character:OnXPUpdate()
    local xp, max, lvl = UnitXP("player"), UnitXPMax("player"), UnitLevel("player")
    if not (xp and max and lvl) then return end
    if lastXP == nil then
        lastXP, lastXPMax, lastLevel = xp, max, lvl
        return
    end
    local delta
    if lvl == lastLevel then
        delta = xp - lastXP
    else
        delta = ((lastXPMax or 0) - (lastXP or 0)) + xp
    end
    lastXP, lastXPMax, lastLevel = xp, max, lvl
    if delta and delta > 0 then self:AddXP(delta) end
end

function Character:AddXP(delta)
    local db = FJ.db
    local t = db.totals
    local now = GetTime()
    t.xp = t.xp + delta

    if now - pendingQuestAt > PENDING_WINDOW then pendingQuestXP = 0 end
    if now - pendingExploreAt > PENDING_WINDOW then pendingExploreXP = 0 end

    local q = math.min(pendingQuestXP, delta)
    pendingQuestXP = pendingQuestXP - q
    local e = math.min(pendingExploreXP, delta - q)
    pendingExploreXP = pendingExploreXP - e
    local rest = delta - q - e

    t.xpQuest = t.xpQuest + q
    t.xpExplore = t.xpExplore + e
    if rest > 0 then
        t.xpKill = t.xpKill + rest
        lastDeltaKill, lastDeltaAt = rest, now
    end

    local L = db.levels[UnitLevel("player")]
    if L then L.xp = (L.xp or 0) + delta end
    FJ.Session:Bump("xp", delta)
    FJ:NotifyDataChanged()
end

-- Quest XP can arrive before or after the matching XP update; reconcile either order.
function Character:AddPendingQuestXP(n)
    n = tonumber(n) or 0
    if n <= 0 then return end
    local t = FJ.db.totals
    if GetTime() - lastDeltaAt < 1.5 and lastDeltaKill >= n then
        t.xpKill = t.xpKill - n
        t.xpQuest = t.xpQuest + n
        lastDeltaKill = lastDeltaKill - n
        return
    end
    pendingQuestXP = pendingQuestXP + n
    pendingQuestAt = GetTime()
end

function Character:AddPendingExploreXP(n)
    n = tonumber(n) or 0
    if n <= 0 then return end
    local t = FJ.db.totals
    if GetTime() - lastDeltaAt < 1.5 and lastDeltaKill >= n then
        t.xpKill = t.xpKill - n
        t.xpExplore = t.xpExplore + n
        lastDeltaKill = lastDeltaKill - n
        return
    end
    pendingExploreXP = pendingExploreXP + n
    pendingExploreAt = GetTime()
end

---------------------------------------------------------------------------
-- Gold. Every purse change fires PLAYER_MONEY, whatever caused it (quest rewards, loot,
-- vendors, repairs, auctions, mail, trades, flights). The open window or a pending quest
-- reward tells us the source; "other" is whatever we could not place.
---------------------------------------------------------------------------
local context, contextUntil = nil, 0          -- vendor / auction / mail / trade / taxi
local pendingQuestMoney, pendingQuestMoneyAt = 0, 0
local pendingLootMoney, pendingLootMoneyAt = 0, 0
local repairAt = 0
local lastGold = { amount = 0, bucket = nil, at = 0, earned = true }

local function SetContext(name)
    context, contextUntil = name, math.huge
end

local function ClearContext(name)
    if context == name then contextUntil = GetTime() + 2 end -- trades and flights settle just after closing
end

local function ActiveContext()
    if context and GetTime() <= contextUntil then return context end
    context = nil
    return nil
end

local function Bucket(d)
    local now = GetTime()
    local ctx = ActiveContext()
    if d > 0 then
        if pendingQuestMoney > 0 and now - pendingQuestMoneyAt < 3 then
            pendingQuestMoney = 0
            return "quest"
        end
        if pendingLootMoney > 0 and now - pendingLootMoneyAt < 3 then
            pendingLootMoney = 0
            return "loot"
        end
        if ctx == "vendor" or ctx == "auction" or ctx == "mail" or ctx == "trade" then return ctx end
        return "other"
    end
    if now - repairAt < 2 then return "repair" end
    if ctx then return ctx end
    return "other"
end

local function GoldTable()
    local db = FJ.db
    db.gold = db.gold or {}
    db.gold.earned = db.gold.earned or {}
    db.gold.spent = db.gold.spent or {}
    return db.gold
end

-- Moves the most recent delta to a better bucket when its explanation arrives late.
local function Reattribute(toBucket, amount, earned)
    if lastGold.bucket ~= "other" or lastGold.earned ~= earned then return false end
    if GetTime() - lastGold.at > 1.5 or lastGold.amount < amount then return false end
    local g = GoldTable()
    local side = earned and g.earned or g.spent
    side.other = math.max(0, (side.other or 0) - amount)
    side[toBucket] = (side[toBucket] or 0) + amount
    lastGold.amount = lastGold.amount - amount
    return true
end

function Character:OnMoney()
    local m = GetMoney()
    if not m then return end
    if lastMoney == nil then
        lastMoney = m
        return
    end
    local d = m - lastMoney
    -- Right after login the first reading can be stale; re-baseline instead of counting.
    if lastMoney == 0 and d > 0 and GetTime() - enabledAt < 20 then
        lastMoney = m
        return
    end
    lastMoney = m
    if d == 0 then return end

    local t = FJ.db.totals
    local g = GoldTable()
    local bucket = Bucket(d)
    if d > 0 then
        t.goldEarned = t.goldEarned + d
        g.earned[bucket] = (g.earned[bucket] or 0) + d
    else
        t.goldSpent = t.goldSpent - d
        g.spent[bucket] = (g.spent[bucket] or 0) - d
    end
    lastGold.amount, lastGold.bucket, lastGold.at, lastGold.earned = math.abs(d), bucket, GetTime(), d > 0
    if m > (t.peakGold or 0) then t.peakGold = m end
    local s = FJ.Session:Current()
    if s then
        s.g = (s.g or 0) + d
        s.gEnd = m
    end
    self:CheckGoldMilestones()
    FJ:NotifyDataChanged()
end

function Character:AddPendingQuestMoney(copper)
    copper = tonumber(copper) or 0
    if copper <= 0 then return end
    if Reattribute("quest", copper, true) then return end
    pendingQuestMoney, pendingQuestMoneyAt = pendingQuestMoney + copper, GetTime()
end

-- CHAT_MSG_MONEY: "You loot 5 Silver, 20 Copper" (also shared loot lines).
local lootMoneyPatterns
function Character:OnMoneyMessage(msg)
    if type(msg) ~= "string" or not FJ.canaccess(msg) then return end
    if not lootMoneyPatterns then
        lootMoneyPatterns = {}
        for _, g in ipairs({ "LOOT_MONEY", "YOU_LOOT_MONEY", "LOOT_MONEY_SPLIT" }) do
            local p = FJ.FormatToPattern(_G[g])
            if p then lootMoneyPatterns[#lootMoneyPatterns + 1] = p end
        end
    end
    local text
    for _, p in ipairs(lootMoneyPatterns) do
        text = msg:match(p)
        if text then break end
    end
    if not text then text = msg end
    local copper = 0
    local gold = text:match("(%d+)%s*" .. (GOLD_AMOUNT and GOLD_AMOUNT:gsub("%%d%s*", "") or "Gold"))
    local silver = text:match("(%d+)%s*" .. (SILVER_AMOUNT and SILVER_AMOUNT:gsub("%%d%s*", "") or "Silver"))
    local copperOnly = text:match("(%d+)%s*" .. (COPPER_AMOUNT and COPPER_AMOUNT:gsub("%%d%s*", "") or "Copper"))
    copper = (tonumber(gold) or 0) * 10000 + (tonumber(silver) or 0) * 100 + (tonumber(copperOnly) or 0)
    if copper <= 0 then return end
    if Reattribute("loot", copper, true) then return end
    pendingLootMoney, pendingLootMoneyAt = pendingLootMoney + copper, GetTime()
end

function Character:CheckGoldMilestones()
    local g = math.floor((FJ.db.totals.goldEarned or 0) / 10000)
    local flags = FJ.db.flags
    for _, m in ipairs(GOLD_MILESTONES) do
        if g >= m and (flags.goldMs or 0) < m then
            flags.goldMs = m
            FJ.Timeline:Add("gold", FJ.Timeline.PRIO.gold, { a = m })
        end
    end
end

---------------------------------------------------------------------------
-- Professions
---------------------------------------------------------------------------
local function Collect(...)
    local out = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if v then out[#out + 1] = v end
    end
    return out
end

local function ReadProfessions()
    local out = {}
    if GetProfessions and GetProfessionInfo then
        local ok, idxs = pcall(function() return Collect(GetProfessions()) end)
        if ok and idxs then
            for _, idx in ipairs(idxs) do
                local name, icon, rank, maxRank, _, _, skillLine = GetProfessionInfo(idx)
                if type(name) == "string" and FJ.canaccess(name) then
                    out[name] = { rank = tonumber(rank) or 0, max = tonumber(maxRank) or 0, icon = icon, line = skillLine }
                end
            end
            return out
        end
    end
    if GetNumSkillLines and GetSkillLineInfo then
        if ExpandSkillHeader then pcall(ExpandSkillHeader, 0) end
        local header
        for i = 1, GetNumSkillLines() do
            local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
            if isHeader then
                header = name
            elseif name and (header == TRADE_SKILLS or header == SECONDARY_SKILLS) then
                out[name] = { rank = tonumber(rank) or 0, max = tonumber(maxRank) or 0 }
            end
        end
    end
    return out
end

-- The first scan of a session only records state; later scans write timeline entries.
function Character:ScanProfessions()
    local initial = not self.profScanned
    self.profScanned = true
    local found = ReadProfessions()
    local db = FJ.db
    local now = time()
    local P = FJ.Timeline.PRIO
    local changed = false
    for name, info in pairs(found) do
        local p = db.professions[name]
        if not p then
            p = { rank = info.rank, max = info.max, icon = info.icon, ms = {}, seen = now }
            if not initial then
                p.learned = now
                FJ.Timeline:Add("prof", P.prof, { a = name })
            end
            db.professions[name] = p
            changed = true
        end
        p.ms = p.ms or {}
        local oldRank = p.rank or 0
        p.rank = info.rank or p.rank
        p.max = info.max or p.max
        p.icon = info.icon or p.icon
        p.unlearned = nil
        p.seen = now
        if p.rank ~= oldRank then changed = true end
        if not initial and p.rank and p.rank > oldRank then
            local oldStep, newStep = math.floor(oldRank / 75), math.floor(p.rank / 75)
            if newStep > oldStep then
                local ms = newStep * 75
                p.ms[ms] = now
                FJ.Timeline:Add("prof_ms", P.prof_ms, { a = name, b = ms })
            end
        end
    end
    for name, p in pairs(db.professions) do
        if not found[name] and not p.unlearned then
            p.unlearned = now
            changed = true
        end
    end
    if changed then FJ:NotifyDataChanged() end
end

---------------------------------------------------------------------------
-- Wiring
---------------------------------------------------------------------------
function Character:OnEnable()
    enabledAt = GetTime()
    lastXP, lastXPMax, lastLevel = UnitXP("player"), UnitXPMax("player"), UnitLevel("player")
    lastMoney = GetMoney()
    local t = FJ.db.totals
    if lastMoney and lastMoney > (t.peakGold or 0) then t.peakGold = lastMoney end
    GoldTable()
    FJ:After(4, function() Character:ScanProfessions() end)
    if RepairAllItems and not self.repairHooked then
        self.repairHooked = true
        hooksecurefunc("RepairAllItems", function() repairAt = GetTime() end)
    end
end

FJ:RegisterEvent("PLAYER_LEVEL_UP", function(_, level) Character:OnLevelUp(level) end)
FJ:RegisterEvent("PLAYER_XP_UPDATE", function() Character:OnXPUpdate() end)
FJ:RegisterEvent("PLAYER_MONEY", function() Character:OnMoney() end)
FJ:RegisterEvent("CHAT_MSG_MONEY", function(_, msg) Character:OnMoneyMessage(msg) end)

FJ:RegisterEvent("MERCHANT_SHOW", function() SetContext("vendor") end)
FJ:RegisterEvent("MERCHANT_CLOSED", function() ClearContext("vendor") end)
FJ:RegisterEvent("AUCTION_HOUSE_SHOW", function() SetContext("auction") end)
FJ:RegisterEvent("AUCTION_HOUSE_CLOSED", function() ClearContext("auction") end)
FJ:RegisterEvent("MAIL_SHOW", function() SetContext("mail") end)
FJ:RegisterEvent("MAIL_CLOSED", function() ClearContext("mail") end)
FJ:RegisterEvent("TRADE_SHOW", function() SetContext("trade") end)
FJ:RegisterEvent("TRADE_CLOSED", function() ClearContext("trade") end)
FJ:RegisterEvent("TAXIMAP_OPENED", function() SetContext("taxi") end)
FJ:RegisterEvent("TAXIMAP_CLOSED", function() ClearContext("taxi") end)
FJ:RegisterEvent("TRAINER_SHOW", function() SetContext("trainer") end)
FJ:RegisterEvent("TRAINER_CLOSED", function() ClearContext("trainer") end)

local function RescanSoon()
    FJ:Debounce("prof-scan", 2, function() Character:ScanProfessions() end)
end
FJ:RegisterEvent("SKILL_LINES_CHANGED", RescanSoon)
FJ:RegisterEvent("CHAT_MSG_SKILL", RescanSoon)
FJ:RegisterEvent("TRADE_SKILL_SHOW", RescanSoon)

-- Abilities learned (trainers, books, talents that teach spells)
local function OnSpellLearned()
    RescanSoon()
    local db = FJ.db
    if not db or not FJ.enabled then return end
    db.totals.spellsLearned = (db.totals.spellsLearned or 0) + 1
    local L = db.levels[UnitLevel("player")]
    if L then L.spells = (L.spells or 0) + 1 end
end
FJ:RegisterEvent("LEARNED_SPELL_IN_SKILL_LINE", OnSpellLearned)
FJ:RegisterEvent("LEARNED_SPELL_IN_TAB", OnSpellLearned)
