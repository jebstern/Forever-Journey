-- Forever Journey: Journey page (the timeline).
local ADDON_NAME, FJ = ...
local T, W = FJ.Theme, FJ.Widgets

local PAD = 16
local ROW_H = 44
local HEADER_H = 34

local function GroupTitle(kind, entries)
    local n = #entries
    if kind == "death" then
        local byZone, order = {}, {}
        for _, e in ipairs(entries) do
            local z = e.zn or "somewhere"
            if not byZone[z] then
                byZone[z] = 0
                order[#order + 1] = z
            end
            byZone[z] = byZone[z] + 1
        end
        table.sort(order, function(a, b) return byZone[a] > byZone[b] end)
        local parts = {}
        for i = 1, math.min(3, #order) do
            local z = order[i]
            parts[#parts + 1] = byZone[z] > 1 and format("%s x%d", z, byZone[z]) or z
        end
        if #order > 3 then parts[#parts + 1] = "..." end
        return format("Died %d times", n), table.concat(parts, ", ")
    elseif kind == "taxi" then
        local parts = {}
        for i = 1, math.min(4, n) do parts[#parts + 1] = entries[i].a or entries[i].zn or "?" end
        if n > 4 then parts[#parts + 1] = "..." end
        return format("%d new flight paths", n), table.concat(parts, ", ")
    end
    return format("%d events", n), ""
end

local function BuildItems(filter)
    local list = FJ.db.timeline
    local items = {}
    local lastLevel
    local showDeaths = FJ.gdb.settings.showDeathsOnTimeline
    for _, e in ipairs(list) do
        local keep = true
        if filter == "highlights" and (e.p or 0) < 50 and e.k ~= "start" then keep = false end
        if not showDeaths and e.k == "death" then keep = false end
        if keep then
            local lvl = e.l or 0
            if lvl ~= lastLevel then
                items[#items + 1] = { type = "header", level = lvl, t = e.t }
                lastLevel = lvl
            end
            if e.k == "death" or e.k == "taxi" then
                local prev = items[#items]
                if prev and prev.type == "group" and prev.kind == e.k then
                    prev.entries[#prev.entries + 1] = e
                else
                    items[#items + 1] = { type = "group", kind = e.k, entries = { e } }
                end
            else
                items[#items + 1] = { type = "entry", e = e }
            end
        end
    end
    items[#items + 1] = { type = "now" }
    return items
end

local function Build(def, page)
    local width, height = FJ.UI:ContentSize()
    width = width - PAD * 2

    local bar = CreateFrame("Frame", nil, page)
    bar:SetPoint("TOPLEFT", PAD, -PAD)
    bar:SetSize(width, 26)
    page.title = W.Title(bar, 18, "Your journey so far")
    page.title:SetPoint("LEFT", 0, 0)
    page.count = W.Text(bar, 11, "", T.colors.dim)
    page.count:SetPoint("LEFT", page.title, "RIGHT", 12, -1)

    page.filter = "all"
    page.btnAll = W.FlatButton(bar, "Everything", 84, 22, function()
        page.filter = "all"
        page.btnAll:SetSelected(true)
        page.btnHi:SetSelected(false)
        page.autoScroll = true
        FJ.UI:Refresh()
    end)
    page.btnHi = W.FlatButton(bar, "Highlights", 84, 22, function()
        page.filter = "highlights"
        page.btnAll:SetSelected(false)
        page.btnHi:SetSelected(true)
        page.autoScroll = true
        FJ.UI:Refresh()
    end)
    page.btnTop = W.FlatButton(bar, "Jump to start", 92, 22, function() page.scroll:ScrollTo(0) end)
    page.btnNow = W.FlatButton(bar, "Jump to now", 92, 22, function() page.scroll:ScrollToBottom() end)
    page.btnNow:SetPoint("RIGHT", 0, 0)
    page.btnTop:SetPoint("RIGHT", page.btnNow, "LEFT", -6, 0)
    page.btnHi:SetPoint("RIGHT", page.btnTop, "LEFT", -18, 0)
    page.btnAll:SetPoint("RIGHT", page.btnHi, "LEFT", -6, 0)
    page.btnAll:SetSelected(true)

    local panel = W.Frame(page, width, height - PAD * 2 - 36, T.colors.panel, T.colors.borderDim)
    panel:SetPoint("TOPLEFT", PAD, -(PAD + 36))
    page.scroll = W.ScrollArea(panel)
    page.scroll:SetPoint("TOPLEFT", 8, -8)
    page.scroll:SetPoint("BOTTOMRIGHT", -16, 8)

    local content = page.scroll.content
    page.rows = W.Pool(function() return W.TimelineRow(content, width - 40) end)
    page.headers = W.Pool(function()
        local h = CreateFrame("Frame", nil, content)
        h:SetHeight(HEADER_H)
        h.dot = h:CreateTexture(nil, "ARTWORK")
        h.dot:SetSize(14, 14)
        h.dot:SetPoint("LEFT", 9, 0)
        W.SetColor(h.dot, T.colors.gold)
        h.lineTop = h:CreateTexture(nil, "BACKGROUND")
        h.lineTop:SetWidth(2)
        h.lineTop:SetPoint("TOP", h, "TOPLEFT", 16, 0)
        h.lineTop:SetPoint("BOTTOM", h, "LEFT", 16, 0)
        W.SetColor(h.lineTop, T.colors.borderDim)
        h.lineBottom = h:CreateTexture(nil, "BACKGROUND")
        h.lineBottom:SetWidth(2)
        h.lineBottom:SetPoint("TOP", h, "LEFT", 16, 0)
        h.lineBottom:SetPoint("BOTTOM", h, "BOTTOMLEFT", 16, 0)
        W.SetColor(h.lineBottom, T.colors.borderDim)
        h.text = W.Title(h, 15, "")
        h.text:SetPoint("LEFT", 34, 0)
        h.sub = W.Text(h, 10, "", T.colors.dim)
        h.sub:SetPoint("LEFT", h.text, "RIGHT", 10, -1)
        h.date = W.Text(h, 10, "", T.colors.dim)
        h.date:SetPoint("RIGHT", -6, 0)
        h.date:SetJustifyH("RIGHT")
        return h
    end)
    page.autoScroll = true
    page:SetScript("OnHide", function() page.autoScroll = true end)
end

local function Refresh(def, page)
    page.rows:ReleaseAll()
    page.headers:ReleaseAll()
    local content = page.scroll.content
    local items = BuildItems(page.filter)
    local y = 4
    local lvlNow = UnitLevel("player") or 1
    local entries = 0

    for idx, item in ipairs(items) do
        if item.type == "header" then
            local h = page.headers:Acquire()
            h:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
            h:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
            h.text:SetText(format("LEVEL %d", item.level))
            h.sub:SetText("")
            h.date:SetText(FJ.FormatDate(item.t))
            if idx == 1 then h.lineTop:Hide() else h.lineTop:Show() end
            h.lineBottom:Show()
            W.SetColor(h.dot, T.colors.gold)
            y = y + HEADER_H
        elseif item.type == "now" then
            local h = page.headers:Acquire()
            h:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
            h:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
            h.text:SetText(format("LEVEL %d  -  YOU ARE HERE", lvlNow))
            local _, zoneName = FJ.Zones:GetCurrent()
            h.sub:SetText((zoneName and ("in " .. zoneName .. ", ") or "") .. FJ.FormatDuration(FJ.Session:GetPlayed()) .. " played")
            h.date:SetText("")
            if idx == 1 then h.lineTop:Hide() else h.lineTop:Show() end
            h.lineBottom:Hide()
            local r, g, b = FJ.ClassColor()
            W.SetColor(h.dot, { r, g, b })
            y = y + HEADER_H
        else
            local row = page.rows:Acquire()
            row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
            local title, sub, icon, color, dateText
            if item.type == "group" and #item.entries > 1 then
                title, sub = GroupTitle(item.kind, item.entries)
                icon = FJ.Timeline.IconFor(item.kind)
                color = FJ.Timeline.ColorFor(item.kind)
                dateText = FJ.FormatDate(item.entries[#item.entries].t)
                entries = entries + #item.entries
                row.itemLink = nil
                row:SetScript("OnEnter", function(self)
                    local lines = {}
                    for i = #item.entries, math.max(1, #item.entries - 9), -1 do
                        local e = item.entries[i]
                        local tTitle, tSub = FJ.Timeline:Describe(e)
                        lines[#lines + 1] = { tTitle .. (tSub ~= "" and (" - " .. tSub) or ""), FJ.FormatDateTime(e.t) }
                    end
                    W.ShowTooltip(self, title, lines)
                end)
                row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            else
                local e = item.type == "group" and item.entries[1] or item.e
                title, sub, icon, color = FJ.Timeline:Describe(e)
                dateText = FJ.FormatDate(e.t)
                entries = entries + 1
                if e.k == "item" and e.a then
                    W.SetItemTooltip(row, e.a)
                else
                    row.itemLink = nil
                    row:SetScript("OnEnter", function(self)
                        W.ShowTooltip(self, title, { sub, FJ.FormatDateTime(e.t) })
                    end)
                    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
                end
            end
            row:Set(title, sub, icon, color, dateText, false, false)
            row.copyText = (dateText or "") .. ": " .. title .. ((sub and sub ~= "") and ("  -  " .. sub) or "")
            row:SetScript("OnClick", function(self) W.ShowCopyBox(W.Plain(self.copyText or ""), "Chapter") end)
            y = y + ROW_H
        end
    end
    page.scroll:SetContentHeight(y + 8)
    page.count:SetText(format("%d chapters", entries))
    if page.autoScroll then
        page.autoScroll = false
        page.scroll:ScrollToBottom()
    end
end

FJ.UI:RegisterPage("journey", {
    title = "Journey", icon = T.icons.journey, order = 2,
    build = Build, refresh = Refresh,
})
