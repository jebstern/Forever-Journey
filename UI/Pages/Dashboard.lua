-- Forever Journey: Dashboard page.
local ADDON_NAME, FJ = ...
local T, W = FJ.Theme, FJ.Widgets

local PAD = 16
local GAP = 12

local function ClassIcon(tex, classFile)
    local coords = CLASS_ICON_TCOORDS and classFile and CLASS_ICON_TCOORDS[classFile]
    if coords then
        tex:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
        tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    else
        tex:SetTexture(T.icons.dashboard)
        tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end
end

local function Build(def, page)
    local width = FJ.UI:ContentSize() - PAD * 2

    -- Hero -----------------------------------------------------------------
    local hero = W.Frame(page, width, 112, T.colors.panel, T.colors.border)
    hero:SetPoint("TOPLEFT", PAD, -PAD)
    page.hero = hero

    hero.classIcon = hero:CreateTexture(nil, "ARTWORK")
    hero.classIcon:SetSize(44, 44)
    hero.classIcon:SetPoint("TOPLEFT", 14, -12)
    hero.name = W.Title(hero, 22, "")
    hero.name:SetPoint("TOPLEFT", 68, -12)
    hero.line = W.Text(hero, 12, "", T.colors.muted)
    hero.line:SetPoint("TOPLEFT", 68, -40)
    hero.played = W.Text(hero, 20, "", T.colors.text, "")
    hero.played:SetPoint("TOPRIGHT", -16, -12)
    hero.played:SetJustifyH("RIGHT")
    hero.playedLabel = W.Text(hero, 11, "", T.colors.muted)
    hero.playedLabel:SetPoint("TOPRIGHT", -16, -40)
    hero.playedLabel:SetJustifyH("RIGHT")
    hero.xp = W.ProgressBar(hero, width - 28, 14, T.colors.xp)
    hero.xp:SetPoint("BOTTOMLEFT", 14, 14)
    hero.xpLabel = W.Text(hero, 10, "", T.colors.dim)
    hero.xpLabel:SetPoint("BOTTOMLEFT", 14, 30)
    hero.xpRight = W.Text(hero, 10, "", T.colors.dim)
    hero.xpRight:SetPoint("BOTTOMRIGHT", -14, 30)
    hero.xpRight:SetJustifyH("RIGHT")

    -- Tiles ----------------------------------------------------------------
    local tileW = (width - GAP * 3) / 4
    local tileH = 62
    page.tiles = {}
    for i = 1, 8 do
        local tile = W.StatTile(page, tileW, tileH)
        local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
        tile:SetPoint("TOPLEFT", PAD + col * (tileW + GAP), -(PAD + 112 + GAP + row * (tileH + GAP)))
        page.tiles[i] = tile
    end

    -- Bottom cards ---------------------------------------------------------
    local top = PAD + 112 + GAP + tileH * 2 + GAP * 2
    local _, contentH = FJ.UI:ContentSize()
    local bottomH = contentH - top - PAD
    local halfW = (width - GAP) / 2

    local recent = W.Card(page, halfW, bottomH, "Recent chapters", T.icons.journey)
    recent:SetPoint("TOPLEFT", PAD, -top)
    page.recent = recent
    recent.rows = W.Pool(function()
        local r = W.TimelineRow(recent.content, halfW - 24)
        r:SetScript("OnClick", function() FJ.UI:ShowPage("journey") end)
        return r
    end)
    recent.empty = W.Text(recent.content, 11, "Your first chapters will appear here as you play.", T.colors.dim)
    recent.empty:SetPoint("TOPLEFT", 4, -8)
    recent.empty:SetWidth(halfW - 32)
    recent.empty:SetWordWrap(true)

    local sessionH = 104
    local session = W.Card(page, halfW, sessionH, "This session", T.icons.played)
    session:SetPoint("TOPLEFT", PAD + halfW + GAP, -top)
    page.session = session
    session.l1 = W.Text(session.content, 12, "", T.colors.text)
    session.l1:SetPoint("TOPLEFT", 2, -4)
    session.l1:SetPoint("RIGHT", -2, 0)
    session.l2 = W.Text(session.content, 11, "", T.colors.muted)
    session.l2:SetPoint("TOPLEFT", 2, -26)
    session.l2:SetPoint("RIGHT", -2, 0)
    session.l2:SetWordWrap(true)

    local profs = W.Card(page, halfW, bottomH - sessionH - GAP, "Professions", T.icons.professions)
    profs:SetPoint("TOPLEFT", PAD + halfW + GAP, -(top + sessionH + GAP))
    page.profs = profs
    profs.bars = W.HBars(profs.content, halfW - 28, 22)
    profs.bars:SetPoint("TOPLEFT", 2, -4)
    profs.empty = W.Text(profs.content, 11, "No professions learned yet.", T.colors.dim)
    profs.empty:SetPoint("TOPLEFT", 4, -8)
end

local function Refresh(def, page)
    local db = FJ.db
    local t = db.totals
    local S = FJ.Stats
    local hero = page.hero

    -- Hero
    local r, g, b = FJ.ClassColor()
    ClassIcon(hero.classIcon, FJ.playerClassFile)
    hero.name:SetText(FJ.playerName or "")
    hero.name:SetTextColor(r, g, b)
    local lvl = UnitLevel("player") or 1
    hero.line:SetText(format("Level %d %s %s", lvl, FJ.playerRace or "", FJ.playerClass or ""))
    hero.played:SetText(FJ.FormatDuration(S:Played(), "long"))
    local start, created = S:JourneyStart()
    hero.playedLabel:SetText((created and "played since creation on " or "played, recording since ") .. FJ.FormatDate(start))

    if S:IsMaxLevel() then
        hero.xp:Set(1, "Maximum level reached", T.colors.gold)
        hero.xpLabel:SetText(format("Level %d", lvl))
        hero.xpRight:SetText(FJ.FormatDuration(FJ.Session:GetLevelPlayed()) .. " at this level")
    else
        local xp, max, pct, rested = S:XPProgress()
        hero.xp:Set(pct, format("%s / %s XP  (%d%%)", FJ.FormatNumber(xp), FJ.FormatNumber(max), pct * 100), T.colors.xp, max > 0 and rested / max or 0)
        hero.xpLabel:SetText(format("Level %d  -  %s at this level", lvl, FJ.FormatDuration(FJ.Session:GetLevelPlayed())))
        local eta = S:EstimateTimeToLevel()
        local restedText = rested > 0 and (FJ.FormatNumber(rested) .. " rested") or ""
        hero.xpRight:SetText(restedText .. (eta and ((restedText ~= "" and "  -  " or "") .. "about " .. FJ.FormatDuration(eta) .. " to level " .. (lvl + 1)) or ""))
    end

    -- Tiles. Lifetime values come from the game's statistics when the client has them.
    local function Lines(...)
        local out = {}
        for i = 1, select("#", ...) do
            local v = select(i, ...)
            if v ~= nil then out[#out + 1] = v end
        end
        return out
    end
    local life = FJ.Lifetime
    local lifeDeaths, lifeKills, lifeGold, lifeFlights, lifeQuests =
        life:Value("deaths"), life:Value("kills"), life:Value("goldAcquired"), life:Value("flights"), life:Value("quests")
    local lifeEntered, lifeConquered = life:Value("dungeonsEntered"), life:DungeonsConquered()
    local questsTotal = FJ.Quests:GetTotal()
    local tiles = page.tiles
    tiles[1]:Set(FJ.FormatCompact(questsTotal), "quests completed", T.icons.quests, "Quests completed", Lines(
        { lifeQuests and "Lifetime (game statistic)" or "Lifetime (from the game)", FJ.FormatNumber(questsTotal) },
        (lifeQuests and t.questsAPI and t.questsAPI ~= lifeQuests) and { "Quest IDs flagged complete (incl. hidden)", FJ.FormatNumber(t.questsAPI) } or nil,
        life:Value("questsAbandoned") and { "Abandoned", FJ.FormatNumber(life:Value("questsAbandoned")) } or nil,
        { "Since recording began", FJ.FormatNumber(t.quests) }))
    tiles[2]:Set(FJ.FormatCompact(lifeEntered or t.dungeonRuns), lifeEntered and "dungeons entered" or "dungeon runs", T.icons.dungeons, "Dungeons", Lines(
        lifeEntered and { "Entered (lifetime)", FJ.FormatNumber(lifeEntered) } or nil,
        lifeConquered > 0 and { "Conquered (lifetime)", FJ.FormatNumber(lifeConquered) } or nil,
        { "Runs since recording began", FJ.FormatNumber(t.dungeonRuns) },
        { "Full clears since recording began", FJ.FormatNumber(t.dungeonsCompleted) },
        { "Bosses defeated since recording began", FJ.FormatNumber(S:BossesDefeated()) }))
    tiles[3]:Set(FJ.FormatCompact(lifeDeaths or t.deaths), "deaths", T.icons.deaths, "Deaths", Lines(
        lifeDeaths and { "Lifetime (from the game)", FJ.FormatNumber(lifeDeaths) } or nil,
        { "Since recording began", FJ.FormatNumber(t.deaths) },
        { "Time as a ghost", FJ.FormatDuration(t.ghostTime) }))
    tiles[4]:Set(FJ.FormatCompact(lifeKills or t.kills), "enemies slain", T.icons.kills, "Enemies slain", Lines(
        lifeKills and { "Lifetime (from the game)", FJ.FormatNumber(lifeKills) } or nil,
        { "Killing blows since recording began", FJ.FormatNumber(t.kills) }))
    tiles[5]:Set(FJ.FormatCompact(S:ZonesVisited()), "zones visited", T.icons.zones, "Zones visited", Lines(
        { "Visited", FJ.FormatNumber(S:ZonesVisited()) }, { "Known zones", FJ.FormatNumber(S:ZonesTotal()) },
        "Visits are recorded since recording began."))
    tiles[6]:Set(FJ.FormatCompact(FJ.Zones:KnownFlightPaths()), "flight paths", T.icons.taxi, "Flight paths", Lines(
        { "Known", FJ.FormatNumber(FJ.Zones:KnownFlightPaths()) },
        lifeFlights and { "Flights taken (lifetime)", FJ.FormatNumber(lifeFlights) } or nil,
        { "Flights taken since recording began", FJ.FormatNumber(t.flightsTaken) },
        "Known paths update whenever you open a flight master."))
    tiles[7]:Set(FJ.FormatCompact(t.discoveries), "areas discovered", T.icons.discoveries, "Discoveries", Lines(
        { "Areas discovered", FJ.FormatNumber(t.discoveries) }, { "Rare creatures met", FJ.FormatNumber(t.raresSeen) },
        "Since recording began."))
    tiles[8]:Set(FJ.FormatMoney(lifeGold or t.goldEarned, true), lifeGold and "gold acquired" or "gold earned", T.icons.gold, "Gold", Lines(
        lifeGold and { "Acquired in total (from the game)", FJ.FormatMoney(lifeGold) } or nil,
        { "Earned since recording began", FJ.FormatMoney(t.goldEarned) },
        { "Spent since recording began", FJ.FormatMoney(t.goldSpent) },
        { "Carrying now", FJ.FormatMoney(GetMoney() or 0) }))

    -- Recent chapters
    local recent = page.recent
    recent.rows:ReleaseAll()
    local last = FJ.Timeline:Last(5)
    if #last == 0 then
        recent.empty:Show()
    else
        recent.empty:Hide()
        local y = 0
        for i, e in ipairs(last) do
            local row = recent.rows:Acquire()
            row:SetPoint("TOPLEFT", recent.content, "TOPLEFT", 0, -y)
            local title, sub, icon, color = FJ.Timeline:Describe(e)
            row:Set(title, sub, icon, color, FJ.RelativeDay(e.t), i == 1, i == #last)
            y = y + 44
        end
    end

    -- Session
    local s = S:SessionNow()
    local session = page.session
    if s then
        local lvls = s.levels > 0 and format("  -  %d %s gained", s.levels, s.levels == 1 and "level" or "levels") or ""
        session.l1:SetText(format("Playing for %s%s", FJ.FormatDuration(s.duration), lvls))
        local parts = {}
        if s.xp > 0 then parts[#parts + 1] = format("%s XP (%s/h)", FJ.FormatNumber(s.xp), FJ.FormatCompact(s.xph)) end
        parts[#parts + 1] = s.quests .. (s.quests == 1 and " quest" or " quests")
        parts[#parts + 1] = s.kills .. (s.kills == 1 and " kill" or " kills")
        parts[#parts + 1] = s.deaths .. (s.deaths == 1 and " death" or " deaths")
        if s.gold ~= 0 then parts[#parts + 1] = (s.gold > 0 and "+" or "") .. FJ.FormatMoney(s.gold, true) end
        if s.discoveries > 0 then parts[#parts + 1] = s.discoveries .. " discovered" end
        session.l2:SetText(table.concat(parts, "  -  "))
    else
        session.l1:SetText("Session starting...")
        session.l2:SetText("")
    end

    -- Professions
    local profs = page.profs
    local list = S:Professions()
    if #list == 0 then
        profs.empty:Show()
        profs.bars:SetData({})
    else
        profs.empty:Hide()
        local rows = {}
        for i, p in ipairs(list) do
            if i > 6 then break end
            rows[#rows + 1] = {
                label = p.name, icon = p.icon,
                value = p.max > 0 and (p.rank / p.max * 100) or 0,
                text = format("%d / %d", p.rank, p.max),
                color = T.palette[(i - 1) % #T.palette + 1],
                tip = p.learned and { "Learned " .. FJ.FormatDate(p.learned) } or nil,
            }
        end
        profs.bars:SetData(rows, { max = 100, icons = true, labelWidth = 100, valueWidth = 70 })
    end
end

FJ.UI:RegisterPage("dashboard", {
    title = "Dashboard", icon = T.icons.dashboard, order = 1, live = true,
    build = Build, refresh = Refresh,
})
