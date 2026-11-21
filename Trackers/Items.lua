-- Forever Journey: notable loot (rare quality and above) and the things you made.
local ADDON_NAME, FJ = ...
local Items = FJ:NewModule("Items")

local patterns
local QUALITY_BY_HEX = {
    ["e6cc80"] = 6, ["ff8000"] = 5, ["a335ee"] = 4, ["0070dd"] = 3,
    ["1eff00"] = 2, ["ffffff"] = 1, ["9d9d9d"] = 0,
}

local function BuildPatterns()
    patterns = {}
    -- Specific (multiple) forms first so the count suffix is not captured as part of the link.
    for _, g in ipairs({
        "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "LOOT_ITEM_CREATED_SELF_MULTIPLE",
        "LOOT_ITEM_SELF", "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_CREATED_SELF",
    }) do
        local p = FJ.FormatToPattern(_G[g])
        if p then patterns[#patterns + 1] = p end
    end
end

-- "You create: [item]x2." and "You create: [item]." (multiple first, or the single form would
-- swallow the count). Crafting, cooking, smelting and conjuring all print these.
local createdPatterns
local function BuildCreatedPatterns()
    createdPatterns = {}
    for _, g in ipairs({ "LOOT_ITEM_CREATED_SELF_MULTIPLE", "LOOT_ITEM_CREATED_SELF" }) do
        local p = FJ.FormatToPattern(_G[g])
        if p then createdPatterns[#createdPatterns + 1] = p end
    end
end

local CRAFT_MILESTONES = { 100, 500, 1000, 2500, 5000, 10000, 25000, 50000 }

function Items:Quality(link)
    local hex = type(link) == "string" and link:match("|c%x%x(%x%x%x%x%x%x)")
    return hex and QUALITY_BY_HEX[hex:lower()]
end

function Items:RecordCreated(link, count)
    local id = tonumber(link:match("|Hitem:(%d+)"))
    if not id then return end
    count = math.max(1, math.floor(tonumber(count) or 1))
    local db = FJ.db
    local now = time()
    local c = db.crafted[id]
    if not c then
        c = { n = 0, first = now }
        db.crafted[id] = c
    end
    c.n = c.n + count
    c.l = link
    c.last = now
    local t = db.totals
    local before = t.crafted or 0
    t.crafted = before + count
    for _, m in ipairs(CRAFT_MILESTONES) do
        if before < m and t.crafted >= m then
            FJ.Timeline:Add("crafted", FJ.Timeline.PRIO.crafted, { a = m })
        end
    end
    FJ:NotifyDataChanged()
end

local rollPatterns
local function BuildRollPatterns()
    rollPatterns = {}
    for _, g in ipairs({ "LOOT_ROLL_YOU_WON", "LOOT_ROLL_YOU_WON_NO_SPAM_NEED", "LOOT_ROLL_YOU_WON_NO_SPAM_GREED", "LOOT_ROLL_YOU_WON_NO_SPAM_DE" }) do
        local p = FJ.FormatToPattern(_G[g])
        if p then rollPatterns[#rollPatterns + 1] = p end
    end
end

function Items:OnLoot(msg)
    if type(msg) ~= "string" or not FJ.canaccess(msg) then return end
    if not msg:find("|Hitem:", 1, true) then return end
    if not patterns then BuildPatterns() end
    if not rollPatterns then BuildRollPatterns() end
    if not createdPatterns then BuildCreatedPatterns() end
    for i = 1, #rollPatterns do
        if msg:match(rollPatterns[i]) then
            FJ.db.totals.rollsWon = (FJ.db.totals.rollsWon or 0) + 1
            FJ:NotifyDataChanged()
            return
        end
    end
    -- Counted for "Things you made", then still checked below as notable loot (a crafted epic).
    for i = 1, #createdPatterns do
        local made, count = msg:match(createdPatterns[i])
        if made and made:find("|Hitem:", 1, true) then
            self:RecordCreated(made, count)
            break
        end
    end
    local link
    for i = 1, #patterns do
        link = msg:match(patterns[i])
        if link then break end
    end
    if not link or not link:find("|Hitem:", 1, true) then return end

    local hex = link:match("|c%x%x(%x%x%x%x%x%x)")
    local quality = hex and QUALITY_BY_HEX[hex:lower()]
    if not quality then
        local _, _, q = FJ.API.GetItemInfo(link)
        quality = q
    end
    if not quality or quality < 3 then return end

    local db = FJ.db
    local t = db.totals
    if quality >= 4 then t.lootEpic = t.lootEpic + 1 else t.lootRare = t.lootRare + 1 end
    local mapID, zoneName = FJ.Zones:GetCurrent()
    FJ.PushCapped(db.items, { l = link, t = time(), z = mapID, zn = zoneName, q = quality, lvl = UnitLevel("player") }, FJ.CAPS.items)
    local P = FJ.Timeline.PRIO
    FJ.Timeline:Add("item", quality >= 4 and P.item_epic or P.item, { a = link, q = quality })
    FJ:NotifyDataChanged()
end

function Items:OnInit()
    BuildPatterns()
    BuildCreatedPatterns()
end

FJ:RegisterEvent("CHAT_MSG_LOOT", function(_, msg) Items:OnLoot(msg) end)
