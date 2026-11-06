-- Forever Journey: World page (continents -> zones -> zone detail).
local ADDON_NAME, FJ = ...
local T, W = FJ.Theme, FJ.Widgets

local PAD = 16
local GAP = 12
local LIST_W = 300
local HEADER_H = 44
local ROW_H = 24

local function Build(def, page)
    local width, height = FJ.UI:ContentSize()
    local innerH = height - PAD * 2

    -- Left: list ------------------------------------------------------------
    local list = W.Frame(page, LIST_W, innerH, T.colors.panel, T.colors.borderDim)
    list:SetPoint("TOPLEFT", PAD, -PAD)
    page.listTitle = W.Title(list, 15, "Where you have been")
    page.listTitle:SetPoint("TOPLEFT", 12, -10)
    page.listSummary = W.Text(list, 10, "", T.colors.dim)
    page.listSummary:SetPoint("TOPLEFT", 12, -30)
    page.scroll = W.ScrollArea(list)
    page.scroll:SetPoint("TOPLEFT", 6, -46)
    page.scroll:SetPoint("BOTTOMRIGHT", -14, 6)
    local content = page.scroll.content

    page.headers = W.Pool(function()
        local h = CreateFrame("Frame", nil, content)
        h:SetHeight(HEADER_H)
        h.name = W.Text(h, 12, "", T.colors.gold, "")
        h.name:SetPoint("TOPLEFT", 6, -6)
        h.frac = W.Text(h, 10, "", T.colors.muted)
        h.frac:SetPoint("TOPRIGHT", -6, -7)
        h.frac:SetJustifyH("RIGHT")
        h.bar = W.ProgressBar(h, LIST_W - 40, 6, T.colors.gold)
        h.bar:SetPoint("BOTTOMLEFT", 6, 8)
        return h
    end)
    page.rows = W.Pool(function()
        local r = W.Row(content, ROW_H)
        r.dot = r:CreateTexture(nil, "ARTWORK")
        r.dot:SetSize(6, 6)
        r.dot:SetPoint("LEFT", 10, 0)
        r.name = W.Text(r, 11, "", T.colors.text)
        r.name:SetPoint("LEFT", 22, 0)
        r.name:SetWidth(150)
        r.name:SetWordWrap(false)
        r.stat = W.Text(r, 10, "", T.colors.dim)
        r.stat:SetPoint("RIGHT", -6, 0)
        r.stat:SetJustifyH("RIGHT")
        r:SetScript("OnClick", function(self)
            page.selected = self.mapID
            FJ.UI:Refresh()
        end)
        return r
    end)

    -- Right: detail -----------------------------------------------------------
    local detailW = width - PAD * 2 - LIST_W - GAP
    local detail = W.Frame(page, detailW, innerH, T.colors.panel, T.colors.borderDim)
    detail:SetPoint("TOPLEFT", PAD + LIST_W + GAP, -PAD)
    page.detail = detail
    detail.icon = W.Icon(detail, 26, T.icons.zones)
    detail.icon:SetPoint("TOPLEFT", 14, -12)
    detail.name = W.Title(detail, 20, "")
    detail.name:SetPoint("TOPLEFT", 48, -12)
    detail.sub = W.Text(detail, 11, "", T.colors.muted)
    detail.sub:SetPoint("TOPLEFT", 48, -38)
    detail.sub:SetPoint("RIGHT", -14, 0)
    detail.sub:SetWordWrap(false)

    detail.exploreLabel = W.Text(detail, 11, "", T.colors.text)
    detail.exploreLabel:SetPoint("TOPLEFT", 14, -60)
    detail.explore = W.ProgressBar(detail, detailW - 28, 12, T.colors.teal)
    detail.explore:SetPoint("TOPLEFT", 14, -76)
    detail.questLabel = W.Text(detail, 11, "", T.colors.text)
    detail.questLabel:SetPoint("TOPLEFT", 14, -94)
    detail.quests = W.ProgressBar(detail, detailW - 28, 12, T.colors.gold)
    detail.quests:SetPoint("TOPLEFT", 14, -110)

    local tileW = (detailW - 28 - GAP * 2) / 3
    detail.tiles = {}
    for i = 1, 6 do
        local tile = W.StatTile(detail, tileW, 50)
        local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
        tile:SetPoint("TOPLEFT", 14 + col * (tileW + GAP), -(132 + row * (50 + 6)))
        detail.tiles[i] = tile
    end

    detail.fpTitle = W.Text(detail, 12, "Flight paths you know here", T.colors.gold)
    detail.fpTitle:SetPoint("TOPLEFT", 14, -250)
    detail.fp = W.Text(detail, 11, "", T.colors.text)
    detail.fp:SetPoint("TOPLEFT", 14, -268)
    detail.fp:SetPoint("RIGHT", -14, 0)
    detail.fp:SetWordWrap(true)
    detail.fp:SetJustifyV("TOP")
    detail.fp:SetHeight(32)

    detail.discTitle = W.Text(detail, 12, "Places discovered", T.colors.gold)
    detail.discTitle:SetPoint("TOPLEFT", 14, -308)
    detail.disc = W.Text(detail, 11, "", T.colors.text)
    detail.disc:SetPoint("TOPLEFT", 14, -326)
    detail.disc:SetPoint("RIGHT", -14, 0)
    detail.disc:SetWordWrap(true)
    detail.disc:SetJustifyV("TOP")
    detail.disc:SetHeight(64)

    detail.deathTitle = W.Text(detail, 12, "Deaths here", T.colors.gold)
    detail.deathTitle:SetPoint("TOPLEFT", 14, -400)
    detail.deaths = W.Text(detail, 11, "", T.colors.text)
    detail.deaths:SetPoint("TOPLEFT", 14, -418)
    detail.deaths:SetPoint("RIGHT", -14, 0)
    detail.deaths:SetPoint("BOTTOM", 0, 12)
    detail.deaths:SetWordWrap(true)
    detail.deaths:SetJustifyV("TOP")

    detail.empty = W.Text(detail, 12, "Pick a zone on the left to see your history there.", T.colors.dim)
    detail.empty:SetPoint("CENTER")
end

local function RefreshList(page)
    page.headers:ReleaseAll()
    page.rows:ReleaseAll()
    local content = page.scroll.content
    local zones = FJ.db.zones
    local catalog = FJ.Zones:GetCatalog()
    local y = 0
    local visitedTotal, allTotal = 0, 0
    local firstVisited
    for _, c in ipairs(catalog) do
        local visited = 0
        for _, z in ipairs(c.zones) do
            if zones[z.mapID] then visited = visited + 1 end
        end
        if c.mapID ~= 0 then
            visitedTotal = visitedTotal + visited
            allTotal = allTotal + #c.zones
        end
        local h = page.headers:Acquire()
        h:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
        h:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
        h.name:SetText(c.name)
        h.frac:SetText(format("%d / %d", visited, #c.zones))
        h.bar:SetWidthValue(math.max(10, (content:GetWidth() or 0) - 12))
        h.bar:Set(FJ.Percent(visited, #c.zones), nil, T.colors.gold)
        y = y + HEADER_H
        for _, z in ipairs(c.zones) do
            local r = page.rows:Acquire()
            r:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
            r:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
            r.mapID = z.mapID
            r.name:SetText(z.name)
            local data = zones[z.mapID]
            if data then
                firstVisited = firstVisited or z.mapID
                r.name:SetTextColor(T.RGB(T.colors.text))
                W.SetColor(r.dot, FJ.Data.Capitals[z.mapID] and T.colors.blue or T.colors.green)
                local parts = {}
                if (data.time or 0) >= 60 then parts[#parts + 1] = FJ.FormatDuration(data.time) end
                local qPct, qTotal, qDone, qUnob = FJ.ZoneQuests:Percent(z.mapID)
                if qPct then
                    local cr, cg, cb = T.RatioColor(qPct)
                    parts[#parts + 1] = format("|c%s%d/%d|r", FJ.Hex(cr, cg, cb), qDone, qTotal - (qUnob or 0))
                elseif (data.q or 0) > 0 then
                    parts[#parts + 1] = data.q .. "q"
                end
                if (data.d or 0) > 0 then parts[#parts + 1] = data.d .. "d" end
                r.stat:SetText(table.concat(parts, "  "))
            else
                r.name:SetTextColor(T.RGB(T.colors.dim))
                W.SetColor(r.dot, T.colors.track)
                r.stat:SetText("")
            end
            r:SetSelected(page.selected == z.mapID)
            y = y + ROW_H
        end
        y = y + 6
    end
    page.scroll:SetContentHeight(y)
    page.listSummary:SetText(format("%d of %d zones visited", visitedTotal, allTotal))
    if not page.selected then
        local cur = FJ.Zones:GetCurrent()
        page.selected = (cur and zones[cur] and cur) or firstVisited
    end
end

local function RefreshDetail(page)
    local d = page.detail
    local mapID = page.selected
    local z = mapID and FJ.db.zones[mapID]
    local info = mapID and FJ.API.MapInfo(mapID)
    local name = (z and z.name) or (info and info.name)
    local show = name ~= nil
    for _, region in ipairs({ d.icon, d.name, d.sub, d.exploreLabel, d.explore, d.questLabel, d.quests, d.fpTitle, d.fp, d.discTitle, d.disc, d.deathTitle, d.deaths }) do
        if show then region:Show() else region:Hide() end
    end
    for _, tile in ipairs(d.tiles) do
        if show then tile:Show() else tile:Hide() end
    end
    if show then d.empty:Hide() else d.empty:Show() return end

    d.name:SetText(name)
    local range = FJ.Data.ZoneLevels[mapID]
    local rangeText = range and format("Levels %d-%d", range[1], range[2]) or (FJ.Data.Capitals[mapID] and "Capital city" or "")
    if z then
        d.sub:SetText(format("First visited %s at level %d%s", FJ.FormatDate(z.first), z.lvl or 0, rangeText ~= "" and ("  -  " .. rangeText) or ""))
    else
        d.sub:SetText("Not visited yet" .. (rangeText ~= "" and ("  -  " .. rangeText) or ""))
    end

    local explored, total = FJ.Zones:Exploration(mapID)
    if explored and total and total > 0 then
        d.exploreLabel:SetText("Map explored")
        d.explore:Set(explored / total, format("%d / %d areas  (%d%%)", explored, total, explored / total * 100), T.colors.teal)
    else
        d.exploreLabel:SetText("Map exploration")
        d.explore:Set(0, "No exploration data for this zone", T.colors.teal)
    end

    local qPct, qTotal, qDone, qUnob = FJ.ZoneQuests:Percent(mapID)
    if qPct then
        d.questLabel:SetText("Quests completed")
        local text = format("%d / %d  (%d%%)", qDone, qTotal - (qUnob or 0), qPct * 100)
        if (qUnob or 0) > 0 then text = text .. format("  -  %d no longer obtainable", qUnob) end
        d.quests:Set(qPct, text, T.colors.gold)
    else
        d.questLabel:SetText("Quests completed")
        local state = FJ.ZoneQuests:State()
        local hint = (state == "building" or state == "waiting") and "Counting quests with QuestieDB..." or
            (state == "unavailable" and "Install Questie for quest totals per zone" or "No quest data for this zone")
        d.quests:Set(0, hint, T.colors.gold)
    end

    local t = d.tiles
    t[1]:Set(z and FJ.FormatDuration(z.time or 0) or "-", "time spent", T.icons.played)
    t[2]:Set(z and tostring(z.q or 0) or "-", "quests turned in", T.icons.quests, "Quests", "Quests handed in while you were in this zone.")
    t[3]:Set(z and FJ.FormatCompact(z.k or 0) or "-", "enemies slain", T.icons.kills)
    t[4]:Set(z and tostring(z.d or 0) or "-", "deaths", T.icons.deaths)
    t[5]:Set(z and tostring(z.disc or 0) or "-", "areas discovered", T.icons.discoveries, "Discoveries", "Discovered while recording. The exploration bar above uses the map itself.")
    t[6]:Set(z and tostring(z.visits or 0) or "-", "visits", T.icons.zones)

    local fps = FJ.Zones:FlightPathsInZone(name)
    if #fps > 0 then
        local names = {}
        for _, n in ipairs(fps) do names[#names + 1] = n:match("^(.-),") or n end
        d.fp:SetText(table.concat(names, ", "))
    else
        d.fp:SetText(FJ.db.flags.taxiScanned and "None known yet." or "Open a flight master once and known paths will show here.")
    end

    if z and z.discNames and #z.discNames > 0 then
        d.disc:SetText(table.concat(z.discNames, ", "))
    else
        d.disc:SetText(z and "Nothing recorded yet." or "-")
    end

    local lines = {}
    for i = #FJ.db.deaths, 1, -1 do
        local death = FJ.db.deaths[i]
        if death.z == mapID then
            lines[#lines + 1] = format("%s  -  level %d%s", FJ.FormatDate(death.t), death.l or 0, death.k and (", killed by " .. death.k) or "")
            if #lines >= 6 then break end
        end
    end
    if #lines > 0 then
        d.deaths:SetText(table.concat(lines, "\n"))
    else
        d.deaths:SetText(z and ((z.d or 0) > 0 and "Older deaths are only kept as a count." or "You have never died here. Keep it that way.") or "-")
    end
end

local function Refresh(def, page)
    RefreshList(page)
    RefreshDetail(page)
end

FJ.UI:RegisterPage("world", {
    title = "World", icon = T.icons.world, order = 3,
    build = Build, refresh = Refresh,
})
