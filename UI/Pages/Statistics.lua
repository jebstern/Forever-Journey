-- Forever Journey: Statistics page (charts and records).
local ADDON_NAME, FJ = ...
local T, W = FJ.Theme, FJ.Widgets

local PAD = 16
local GAP = 12
local CARD_H = 212

local function Build(def, page)
    local width, height = FJ.UI:ContentSize()
    local inner = width - PAD * 2

    page.scroll = W.ScrollArea(page)
    page.scroll:SetPoint("TOPLEFT", PAD, -PAD)
    page.scroll:SetPoint("BOTTOMRIGHT", -PAD - 10, PAD)
    local content = page.scroll.content
    local colW = (inner - 10 - GAP) / 2
    local chartW, chartH = colW - 28, CARD_H - 60

    -- Display order of the cards (logical index -> grid slot), so related charts sit together.
    local SLOT = {
        [1] = 1, [13] = 2, [5] = 3, [14] = 4, [15] = 5, [2] = 6, [3] = 7, [4] = 8,
        [16] = 9, [17] = 10, [6] = 11, [9] = 12, [10] = 13, [7] = 14, [11] = 15, [12] = 16, [8] = 17,
    }
    page.cardCount = 17
    local function card(index, title, icon)
        local c = W.Card(content, colW, CARD_H, title, icon)
        local slot = SLOT[index] or index
        local col, row = (slot - 1) % 2, math.floor((slot - 1) / 2)
        c:SetPoint("TOPLEFT", content, "TOPLEFT", col * (colW + GAP), -(row * (CARD_H + GAP)))
        return c
    end

    page.levelCard = card(1, "Level over time played", T.icons.played)
    page.levelChart = W.LineChart(page.levelCard.content, chartW, chartH)
    page.levelChart:SetPoint("TOPLEFT", 0, -2)

    page.xpCard = card(2, "XP per session", T.icons.statistics)
    page.xpChart = W.VBars(page.xpCard.content, chartW, chartH)
    page.xpChart:SetPoint("TOPLEFT", 0, -2)

    page.actCard = card(3, "How you spend your time", T.icons.played)
    page.actBars = W.HBars(page.actCard.content, chartW, 21)
    page.actBars:SetPoint("TOPLEFT", 0, -2)

    page.zoneCard = card(4, "Where you spend your time", T.icons.zones)
    page.zoneBars = W.HBars(page.zoneCard.content, chartW, 21)
    page.zoneBars:SetPoint("TOPLEFT", 0, -2)

    page.deathCard = card(5, "Deaths per level", T.icons.deaths)
    page.deathChart = W.VBars(page.deathCard.content, chartW, chartH)
    page.deathChart:SetPoint("TOPLEFT", 0, -2)

    page.goldCard = card(6, "Gold over sessions", T.icons.gold)
    page.goldChart = W.LineChart(page.goldCard.content, chartW, chartH)
    page.goldChart:SetPoint("TOPLEFT", 0, -2)

    page.srcCard = card(7, "Where your XP came from", T.icons.statistics)
    page.srcBars = W.HBars(page.srcCard.content, chartW, 21)
    page.srcBars:SetPoint("TOPLEFT", 0, -2)
    page.srcNote = W.Text(page.srcCard.content, 10, "Quest and discovery XP are exact; the rest is kills and bonuses.", T.colors.dim)
    page.srcNote:SetPoint("BOTTOMLEFT", 0, 0)

    page.recCard = card(8, "Records", T.icons.epics)
    page.recRows = W.Pool(function()
        local r = CreateFrame("Frame", nil, page.recCard.content)
        r:SetHeight(18)
        r.label = W.Text(r, 11, "", T.colors.muted)
        r.label:SetPoint("LEFT", 0, 0)
        r.value = W.Text(r, 11, "", T.colors.text)
        r.value:SetPoint("RIGHT", 0, 0)
        r.value:SetJustifyH("RIGHT")
        W.MakeCopyable(r, function(self) return (self.label:GetText() or "") .. ": " .. (self.value:GetText() or "") end, "Record")
        return r
    end)
    page.recEmpty = W.Text(page.recCard.content, 11, "Records appear after your first full session.", T.colors.dim)
    page.recEmpty:SetPoint("TOPLEFT", 2, -6)

    page.goldInCard = card(9, "Where your gold came from", T.icons.gold)
    page.goldInBars = W.HBars(page.goldInCard.content, chartW, 21)
    page.goldInBars:SetPoint("TOPLEFT", 0, -2)
    page.goldInEmpty = W.Text(page.goldInCard.content, 11, "No gold recorded yet.", T.colors.dim)
    page.goldInEmpty:SetPoint("TOPLEFT", 2, -6)

    page.goldOutCard = card(10, "Where your gold went", T.icons.gold)
    page.goldOutBars = W.HBars(page.goldOutCard.content, chartW, 21)
    page.goldOutBars:SetPoint("TOPLEFT", 0, -2)
    page.goldOutEmpty = W.Text(page.goldOutCard.content, 11, "Nothing spent since recording began.", T.colors.dim)
    page.goldOutEmpty:SetPoint("TOPLEFT", 2, -6)

    page.emoteCard = card(11, "Emotes", "Interface\\Icons\\INV_Misc_Toy_04")
    page.emoteDonut = W.Donut(page.emoteCard.content, 140, chartW - 140)
    page.emoteDonut:SetPoint("TOPLEFT", 0, -4)

    page.campCard = card(12, "Camping & sitting", "Interface\\Icons\\Spell_Fire_Fire")
    page.campLines = {}
    for i = 1, 7 do
        local fs = W.Text(page.campCard.content, 11, "", T.colors.text)
        fs:SetPoint("TOPLEFT", 2, -(2 + (i - 1) * 19))
        fs:SetPoint("RIGHT", -2, 0)
        fs:SetWordWrap(false)
        page.campLines[i] = fs
    end

    page.timeLevelCard = card(13, "Time per level", T.icons.played)
    page.timeLevelChart = W.VBars(page.timeLevelCard.content, chartW, chartH)
    page.timeLevelChart:SetPoint("TOPLEFT", 0, -2)

    page.questLevelCard = card(14, "Quests per level", T.icons.quests)
    page.questLevelChart = W.VBars(page.questLevelCard.content, chartW, chartH)
    page.questLevelChart:SetPoint("TOPLEFT", 0, -2)

    page.killLevelCard = card(15, "Kills per level", T.icons.kills)
    page.killLevelChart = W.VBars(page.killLevelCard.content, chartW, chartH)
    page.killLevelChart:SetPoint("TOPLEFT", 0, -2)

    page.clockCard = card(16, "When you play", T.icons.played)
    page.clockChart = W.VBars(page.clockCard.content, chartW, chartH)
    page.clockChart:SetPoint("TOPLEFT", 0, -2)

    page.weekCard = card(17, "Days of the week", T.icons.played)
    page.weekChart = W.VBars(page.weekCard.content, chartW, chartH)
    page.weekChart:SetPoint("TOPLEFT", 0, -2)

    page.cardCount = 18
    page.compCard = card(18, "Adventuring companions", "Interface\\Icons\\Spell_Holy_PrayerOfHealing02")
    page.compBars = W.HBars(page.compCard.content, chartW, 21)
    page.compBars:SetPoint("TOPLEFT", 0, -2)
    page.compEmpty = W.Text(page.compCard.content, 11, "Group up and the people you travel with will appear here.", T.colors.dim)
    page.compEmpty:SetPoint("TOPLEFT", 2, -6)
    page.compEmpty:SetWidth(chartW)
    page.compEmpty:SetWordWrap(true)

    page.scroll:SetContentHeight(math.ceil(page.cardCount / 2) * (CARD_H + GAP))
end

local GOLD_IN_LABELS = { quest = "Quest rewards", loot = "Looted", vendor = "Sold to vendors", auction = "Auction house", mail = "Mail", trade = "Trades", other = "Other" }
local GOLD_OUT_LABELS = { vendor = "Vendors", repair = "Repairs", auction = "Auction house", mail = "Mail & postage", trade = "Trades", taxi = "Flights", trainer = "Trainers", other = "Other" }

local function GoldRows(tbl, labels)
    local rows = {}
    for key, v in pairs(tbl or {}) do
        if v and v > 0 then
            rows[#rows + 1] = { label = labels[key] or key, value = v, text = FJ.FormatMoney(v, true) }
        end
    end
    table.sort(rows, function(a, b) return a.value > b.value end)
    for i, r in ipairs(rows) do r.color = T.palette[(i - 1) % #T.palette + 1] end
    return rows
end

local function ShortDate(t)
    return date("%d %b", t)
end

local function Refresh(def, page)
    local S = FJ.Stats
    local db = FJ.db

    -- Level over played
    local series = S:LevelSeries()
    page.levelChart:SetData(series, {
        xFormat = function(v) return "Lv " .. math.floor(v + 0.5) end,
        yFormat = function(v) return FJ.FormatDuration(v, "hours") end,
        color = T.colors.gold, minY = 0,
    })
    for _, p in ipairs(series) do
        p.tip = { { p.now and "Now" or ("Level " .. p.x), FJ.FormatDuration(p.y) .. " played" } }
    end
    page.levelCard:SetSubtitle(#series >= 2 and format("%d levels recorded", #series - 1) or "Levels are recorded as you gain them")

    -- XP per session
    local sessions = S:Sessions(19)
    local pts = {}
    for _, s in ipairs(sessions) do
        pts[#pts + 1] = {
            value = s.xp or 0, label = ShortDate(s.s), color = T.colors.xp, tipTitle = FJ.FormatDate(s.s),
            tip = { { "Length", FJ.FormatDuration(s.d or 0) }, { "XP", FJ.FormatNumber(s.xp or 0) }, { "Quests", tostring(s.q or 0) }, { "Kills", tostring(s.k or 0) }, { "Deaths", tostring(s.dth or 0) } },
        }
    end
    local now = S:SessionNow()
    if now then
        pts[#pts + 1] = { value = now.xp, label = "now", color = T.colors.gold, tipTitle = "This session",
            tip = { { "Length", FJ.FormatDuration(now.duration) }, { "XP", FJ.FormatNumber(now.xp) }, { "XP per hour", FJ.FormatNumber(now.xph) } } }
    end
    page.xpChart:SetData(pts, { align = "right" })
    page.xpCard:SetSubtitle(#sessions > 0 and format("last %d sessions", #sessions + (now and 1 or 0)) or "")

    -- Activity split
    local acts, total = S:ActivitySplit()
    local rows = {}
    for _, a in ipairs(acts) do
        rows[#rows + 1] = { label = a.label, value = a.value, color = a.color,
            text = format("%s  %d%%", FJ.FormatDuration(a.value), total > 0 and a.value / total * 100 or 0) }
    end
    page.actBars:SetData(rows, { labelWidth = 120, valueWidth = 90 })
    page.actCard:SetSubtitle(total > 0 and (FJ.FormatDuration(total) .. " observed") or "")

    -- Time per zone
    rows = {}
    for i, z in ipairs(S:TopZones("time", 7, false)) do
        rows[#rows + 1] = { label = z.data.name or "?", value = z.value, text = FJ.FormatDuration(z.value),
            color = T.palette[(i - 1) % #T.palette + 1] }
    end
    page.zoneBars:SetData(rows, { labelWidth = 130, valueWidth = 70 })

    -- Deaths per level
    pts = {}
    local buckets = S:LevelBuckets()
    for _, b in ipairs(buckets) do
        pts[#pts + 1] = { value = b.d, label = "Lv " .. b.level, color = T.colors.red, tipTitle = "Level " .. b.level,
            tip = { { "Deaths", tostring(b.d) }, { "Time at level", FJ.FormatDuration(b.time) }, { "Quests", tostring(b.q) }, { "Kills", FJ.FormatNumber(b.k) } } }
    end
    page.deathChart:SetData(pts)
    page.deathCard:SetSubtitle(format("%d deaths in total", db.totals.deaths))

    -- Gold over sessions
    pts = {}
    local goldSessions = S:Sessions(30)
    for i, s in ipairs(goldSessions) do
        if s.gEnd then pts[#pts + 1] = { x = i, y = s.gEnd, tipTitle = FJ.FormatDate(s.s), tip = { { "Carrying", FJ.FormatMoney(s.gEnd) } } } end
    end
    pts[#pts + 1] = { x = #goldSessions + 1, y = GetMoney() or 0, now = true, tipTitle = "Now", tip = { { "Carrying", FJ.FormatMoney(GetMoney() or 0) } } }
    page.goldChart:SetData(pts, {
        xFormat = function(v) return v >= #goldSessions + 1 and "now" or ("session " .. math.floor(v)) end,
        yFormat = function(v) return FJ.FormatMoney(v, true) end,
        color = T.colors.gold, minY = 0,
    })

    -- XP sources
    local t = db.totals
    rows = {
        { label = "Quests", value = t.xpQuest, color = T.colors.gold, text = FJ.FormatCompact(t.xpQuest) },
        { label = "Kills & bonuses", value = t.xpKill, color = T.colors.red, text = FJ.FormatCompact(t.xpKill) },
        { label = "Discovery", value = t.xpExplore, color = T.colors.teal, text = FJ.FormatCompact(t.xpExplore) },
    }
    page.srcBars:SetData(rows, { labelWidth = 110, valueWidth = 70 })
    page.srcCard:SetSubtitle(t.xp > 0 and (FJ.FormatNumber(t.xp) .. " XP recorded") or "")

    -- Gold in: the game's lifetime wealth statistics when available, otherwise our own buckets.
    local life = FJ.Lifetime
    local acquired = life:Value("goldAcquired")
    local inRows
    if acquired and acquired > 0 then
        local parts = {
            quest = life:Value("goldQuests") or 0, loot = life:Value("goldLooted") or 0,
            vendor = life:Value("goldVendors") or 0, auction = life:Value("goldAuctions") or 0,
        }
        local known = parts.quest + parts.loot + parts.vendor + parts.auction
        parts.other = math.max(0, acquired - known)
        inRows = GoldRows(parts, GOLD_IN_LABELS)
        page.goldInCard:SetSubtitle(FJ.FormatMoney(acquired, true) .. " acquired in total")
    else
        inRows = GoldRows(db.gold and db.gold.earned, GOLD_IN_LABELS)
        page.goldInCard:SetSubtitle(t.goldEarned > 0 and (FJ.FormatMoney(t.goldEarned, true) .. " since recording began") or "")
    end
    page.goldInBars:SetData(inRows, { labelWidth = 120, valueWidth = 90 })
    if #inRows == 0 then page.goldInEmpty:Show() else page.goldInEmpty:Hide() end

    -- Gold out: our own attribution since recording began (the game only tracks travel and postage).
    local outRows = GoldRows(db.gold and db.gold.spent, GOLD_OUT_LABELS)
    page.goldOutBars:SetData(outRows, { labelWidth = 120, valueWidth = 90 })
    local travel, postage = life:Value("goldTravel"), life:Value("goldPostage")
    local outSub = t.goldSpent > 0 and (FJ.FormatMoney(t.goldSpent, true) .. " since recording began") or ""
    if (travel and travel > 0) or (postage and postage > 0) then
        outSub = outSub .. (outSub ~= "" and "  -  " or "") .. "lifetime: " .. FJ.FormatMoney(travel or 0, true) .. " flights, " .. FJ.FormatMoney(postage or 0, true) .. " postage"
    end
    page.goldOutCard:SetSubtitle(outSub)
    if #outRows == 0 then page.goldOutEmpty:Show() else page.goldOutEmpty:Hide() end

    -- Emotes
    local emotes = FJ.Social:EmoteList()
    local slices, rest = {}, 0
    for i, e in ipairs(emotes) do
        if i <= 7 then
            slices[#slices + 1] = { label = e.label, value = e.value, color = T.palette[(i - 1) % #T.palette + 1] }
        else
            rest = rest + e.value
        end
    end
    if rest > 0 then slices[#slices + 1] = { label = "others", value = rest, color = T.colors.dim } end
    local emoteTotal = 0
    for _, e in ipairs(emotes) do emoteTotal = emoteTotal + e.value end
    page.emoteDonut:SetData(slices, { centerText = FJ.FormatCompact(emoteTotal), centerSub = "emotes" })
    page.emoteCard:SetSubtitle(#emotes > 0 and format("%d different", #emotes) or "")

    -- Camping
    local camps = t.campCount or 0
    local campLines = page.campLines
    local camping, campNow = FJ.Social:IsCamping()
    local pose, poseNow = FJ.Social:CurrentPose()
    local sitTime = (t.sitTime or 0) + ((pose == "SIT") and poseNow or 0)
    local kneelTime = (t.kneelTime or 0) + ((pose == "KNEEL") and poseNow or 0)
    local sleepTime = (t.sleepTime or 0) + ((pose == "SLEEP") and poseNow or 0)
    campLines[1]:SetText(camps > 0
        and format("Camped %d %s, %s by the fire%s", camps, camps == 1 and "time" or "times",
            FJ.FormatDuration((t.campTime or 0) + (camping and campNow or 0)),
            (t.campLongest or 0) > 0 and (" (longest " .. FJ.FormatDuration(t.campLongest) .. ")") or "")
        or "No camping buff seen yet.")
    campLines[2]:SetText(t.campLast and ("Last camped: " .. FJ.RelativeDay(t.campLast)) or "")
    campLines[3]:SetText((t.sitCount or 0) > 0
        and format("Sat down %d %s, %s sitting in total%s", t.sitCount, t.sitCount == 1 and "time" or "times",
            FJ.FormatDuration(sitTime), (t.sitLongest or 0) > 0 and (" (longest " .. FJ.FormatDuration(t.sitLongest) .. ")") or "")
        or "Not sat down since recording began.")
    campLines[4]:SetText((kneelTime + sleepTime) > 0
        and format("Kneeling %s, sleeping %s", FJ.FormatDuration(kneelTime), FJ.FormatDuration(sleepTime)) or "")
    local sit, kneel, sleep = FJ.Social:EmoteCount("SIT"), FJ.Social:EmoteCount("KNEEL"), FJ.Social:EmoteCount("SLEEP")
    campLines[5]:SetText((sit + kneel + sleep) > 0 and format("/sit %d   /kneel %d   /sleep %d", sit, kneel, sleep) or "")
    campLines[6]:SetText("Sitting ends when you move, jump, cast, fight or talk to someone.")
    campLines[6]:SetTextColor(T.RGB(T.colors.dim))
    local status
    if camping then
        status = "|cff60ff60Camping right now.|r"
    elseif pose then
        status = format("|cff60ff60%s right now (%s).|r", pose == "SIT" and "Sitting" or pose == "KNEEL" and "Kneeling" or "Sleeping", FJ.FormatDuration(poseNow))
    else
        status = "Watching for the \"" .. FJ.Social:CampBuffName() .. "\" buff."
    end
    campLines[7]:SetText(status)
    page.campCard:SetSubtitle(camping and "by the fire" or (pose and "resting" or ""))

    -- Per-level charts (time, quests, kills)
    local perLevel = S:TimePerLevel()
    local timePts, questPts, killPts = {}, {}, {}
    local curLevel = UnitLevel("player") or 1
    for _, r in ipairs(perLevel) do
        local label = "Lv " .. r.level
        local tipTitle = "Level " .. r.level .. (r.level == curLevel and " (current)" or "")
        local tip = {
            { "Time at level", FJ.FormatDuration(r.time) .. (r.exact and "" or " (tracked only)") },
            { "XP", FJ.FormatNumber(r.xp) }, { "Quests", tostring(r.q) }, { "Kills", FJ.FormatNumber(r.k) }, { "Deaths", tostring(r.d) },
        }
        timePts[#timePts + 1] = { value = r.time, label = label, color = r.level == curLevel and T.colors.text or T.colors.gold, tipTitle = tipTitle, tip = tip }
        questPts[#questPts + 1] = { value = r.q, label = label, color = T.colors.gold, tipTitle = tipTitle, tip = tip }
        killPts[#killPts + 1] = { value = r.k, label = label, color = T.colors.orange, tipTitle = tipTitle, tip = tip }
    end
    local maxTime = 0
    for _, p in ipairs(timePts) do if p.value > maxTime then maxTime = p.value end end
    page.timeLevelChart:SetData(timePts, { maxText = FJ.FormatDuration(maxTime) })
    local pace = S:LevelPace()
    page.timeLevelCard:SetSubtitle(pace.average and ("average " .. FJ.FormatDuration(pace.average) .. " per level") or "levels are timed as you gain them")
    page.questLevelChart:SetData(questPts)
    page.questLevelCard:SetSubtitle(format("%d since recording began", t.quests or 0))
    page.killLevelChart:SetData(killPts)
    page.killLevelCard:SetSubtitle(format("%s since recording began", FJ.FormatNumber(t.kills or 0)))

    -- When you play
    local clockPts, clockMax = {}, 0
    for _, c in ipairs(S:PlayClock()) do
        if c.value > clockMax then clockMax = c.value end
        clockPts[#clockPts + 1] = { value = c.value, label = format("%02d", c.hour), color = T.colors.blue,
            tipTitle = format("%02d:00 - %02d:59", c.hour, c.hour), tip = { { "Played", FJ.FormatDuration(c.value) } } }
    end
    page.clockChart:SetData(clockPts, { maxText = FJ.FormatDuration(clockMax) })
    local days = S:Days()
    page.clockCard:SetSubtitle(days.count > 0 and format("%d %s played", days.count, days.count == 1 and "day" or "days") or "")
    local weekPts, weekMax = {}, 0
    for _, w in ipairs(S:Weekdays()) do
        if w.value > weekMax then weekMax = w.value end
        weekPts[#weekPts + 1] = { value = w.value, label = w.label, color = T.colors.teal, tipTitle = w.label, tip = { { "Played", FJ.FormatDuration(w.value) } } }
    end
    page.weekChart:SetData(weekPts, { maxText = FJ.FormatDuration(weekMax) })
    page.weekCard:SetSubtitle(days.current > 1 and format("%d days in a row", days.current) or "")

    -- Companions
    local companions = FJ.Companions:List(7)
    local compRows = {}
    for i, c in ipairs(companions) do
        local r, g, b = FJ.ClassColor(c.class)
        compRows[#compRows + 1] = { label = c.name, value = c.time, text = FJ.FormatDuration(c.time), color = { r, g, b },
            tipTitle = c.name, tip = { { "Time together", FJ.FormatDuration(c.time) }, { "Times grouped", tostring(c.n) }, { "First met", FJ.FormatDate(c.first) }, { "Last seen", FJ.RelativeDay(c.last) } } }
    end
    page.compBars:SetData(compRows, { labelWidth = 120, valueWidth = 70 })
    if #compRows == 0 then page.compEmpty:Show() else page.compEmpty:Hide() end
    page.compCard:SetSubtitle(FJ.Companions:Count() > 0 and format("%d people, %s together", FJ.Companions:Count(), FJ.FormatDuration(t.groupTime or 0)) or "")

    -- Records
    page.recRows:ReleaseAll()
    local records = S:Records()
    if #records == 0 then
        page.recEmpty:Show()
    else
        page.recEmpty:Hide()
        local y = 2
        for i, rec in ipairs(records) do
            if i > 8 then break end
            local r = page.recRows:Acquire()
            r:SetPoint("TOPLEFT", page.recCard.content, "TOPLEFT", 0, -y)
            r:SetPoint("TOPRIGHT", page.recCard.content, "TOPRIGHT", 0, -y)
            r.label:SetText(rec.label)
            r.value:SetText(rec.value .. (rec.sub and ("  |cff8a8a8a" .. rec.sub .. "|r") or ""))
            y = y + 18
        end
    end
end

FJ.UI:RegisterPage("statistics", {
    title = "Statistics", icon = T.icons.statistics, order = 4, live = true,
    build = Build, refresh = Refresh,
})
