-- Forever Journey: Almanac page. Every number we know, grouped into cards.
local ADDON_NAME, FJ = ...
local T, W = FJ.Theme, FJ.Widgets

local PAD = 16
local GAP = 12
local ROW_H = 18
local HEADER_H = 42
local FOOTER = 12

local function Build(def, page)
    local width = FJ.UI:ContentSize()
    local inner = width - PAD * 2 - 10

    page.title = W.Title(page, 18, "Almanac")
    page.title:SetPoint("TOPLEFT", PAD, -PAD)
    page.intro = W.Text(page, 11, "Everything the journal knows about this character. Lifetime numbers come from the game's own statistics; the rest was observed since recording began.", T.colors.muted)
    page.intro:SetPoint("TOPLEFT", PAD, -(PAD + 24))
    page.intro:SetWidth(inner)
    page.intro:SetWordWrap(true)

    page.scroll = W.ScrollArea(page)
    page.scroll:SetPoint("TOPLEFT", PAD, -(PAD + 52))
    page.scroll:SetPoint("BOTTOMRIGHT", -PAD - 10, PAD)
    local content = page.scroll.content
    page.inner = inner

    page.cards = W.Pool(function()
        local c = W.Card(content, inner, 100, "", nil)
        c.icon = W.Icon(c, 16)
        c.icon:SetPoint("TOPLEFT", 12, -10)
        c.header:ClearAllPoints()
        c.header:SetPoint("TOPLEFT", 34, -12)
        return c
    end)
    page.rows = W.Pool(function()
        local r = CreateFrame("Frame", nil, content)
        r:SetHeight(ROW_H)
        r.label = W.Text(r, 11, "", T.colors.muted)
        r.label:SetPoint("LEFT", 0, 0)
        r.label:SetPoint("RIGHT", r, "CENTER", -4, 0)
        r.label:SetWordWrap(false)
        r.value = W.Text(r, 11, "", T.colors.text)
        r.value:SetPoint("LEFT", r, "CENTER", 4, 0)
        r.value:SetPoint("RIGHT", 0, 0)
        r.value:SetJustifyH("RIGHT")
        r.value:SetWordWrap(false)
        r:EnableMouse(true)
        r:SetScript("OnEnter", function(self)
            if self.note then W.ShowTooltip(self, self.tipTitle, self.note) end
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        W.MakeCopyable(r, function(self) return self.copyText end, "Almanac")
        return r
    end)
    page.copyAll = W.FlatButton(page, "Copy all", 84, 22, function()
        if page.allText then W.ShowCopyBox(page.allText, "Almanac") end
    end)
    page.copyAll:SetPoint("TOPRIGHT", -PAD - 10, -PAD)
    page.copyHint = W.Text(page, 10, "click any line to copy it", T.colors.dim)
    page.copyHint:SetPoint("RIGHT", page.copyAll, "LEFT", -8, 0)
end

local function Refresh(def, page)
    page.cards:ReleaseAll()
    page.rows:ReleaseAll()
    local content = page.scroll.content
    local sections = FJ.Stats:Almanac()
    local inner = page.inner
    local colW = (inner - 24 - GAP) / 2
    local y = 0
    local total = 0
    local all = { format("%s - Forever Journey almanac, %s", FJ.playerName or "", FJ.FormatDate(time())) }
    for _, s in ipairs(sections) do
        local perCol = math.ceil(#s.rows / 2)
        local height = HEADER_H + perCol * ROW_H + FOOTER
        local c = page.cards:Acquire()
        c:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
        c:SetSize(inner, height)
        c:SetTitle(s.title)
        c:SetSubtitle(#s.rows .. (#s.rows == 1 and " entry" or " entries"))
        c.icon:SetTexture(s.icon or T.icons.statistics)
        all[#all + 1] = ""
        all[#all + 1] = "== " .. s.title .. " =="
        for i, row in ipairs(s.rows) do
            local r = page.rows:Acquire()
            local col = (i <= perCol) and 0 or 1
            local idx = (col == 0) and (i - 1) or (i - perCol - 1)
            r:SetSize(colW, ROW_H)
            r:SetPoint("TOPLEFT", c, "TOPLEFT", 12 + col * (colW + GAP), -(HEADER_H + idx * ROW_H))
            r.label:SetText(row[1])
            r.value:SetText(row[2])
            r.note = row[3]
            r.tipTitle = row[1]
            local line = (FJ.Trim(row[1]) ~= "" and (row[1] .. ": ") or "") .. W.Plain(row[2]) .. (row[3] and ("  (" .. row[3] .. ")") or "")
            r.copyText = line
            all[#all + 1] = line
            total = total + 1
        end
        y = y + height + GAP
    end
    page.allText = table.concat(all, "\n")
    page.scroll:SetContentHeight(math.max(1, y))
    page.title:SetText(format("Almanac  |cff8a8a8a%d entries|r", total))
end

FJ.UI:RegisterPage("almanac", {
    title = "Almanac", icon = "Interface\\Icons\\INV_Misc_Book_09", order = 4.5, live = true,
    build = Build, refresh = Refresh,
})
