-- Forever Journey: hand-built UI widgets. Only plain frames, textures and font strings,
-- so the look is identical on every client flavour.
local ADDON_NAME, FJ = ...
local T = FJ.Theme
local W = {}
FJ.Widgets = W

local function SetColor(tex, c, a)
    tex:SetColorTexture(c[1], c[2], c[3], a or c[4] or 1)
end
W.SetColor = SetColor

---------------------------------------------------------------------------
-- Pools
---------------------------------------------------------------------------
function W.Pool(create)
    local pool = { active = {}, free = {} }
    function pool:Acquire()
        local f = table.remove(self.free)
        if not f then f = create() end
        self.active[#self.active + 1] = f
        f:Show()
        return f
    end
    function pool:ReleaseAll()
        for i = #self.active, 1, -1 do
            local f = self.active[i]
            f:Hide()
            f:ClearAllPoints()
            self.free[#self.free + 1] = f
            self.active[i] = nil
        end
    end
    function pool:Count() return #self.active end
    return pool
end

---------------------------------------------------------------------------
-- Primitives
---------------------------------------------------------------------------
-- A flat panel with a 1px border drawn from four textures.
function W.Frame(parent, w, h, bg, border)
    local f = CreateFrame("Frame", nil, parent)
    if w then f:SetSize(w, h or w) end
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    SetColor(f.bg, bg or T.colors.panel)
    if border ~= false then
        local edges = {}
        for i = 1, 4 do
            local e = f:CreateTexture(nil, "BORDER")
            edges[i] = e
        end
        edges[1]:SetPoint("TOPLEFT"); edges[1]:SetPoint("TOPRIGHT"); edges[1]:SetHeight(1)
        edges[2]:SetPoint("BOTTOMLEFT"); edges[2]:SetPoint("BOTTOMRIGHT"); edges[2]:SetHeight(1)
        edges[3]:SetPoint("TOPLEFT"); edges[3]:SetPoint("BOTTOMLEFT"); edges[3]:SetWidth(1)
        edges[4]:SetPoint("TOPRIGHT"); edges[4]:SetPoint("BOTTOMRIGHT"); edges[4]:SetWidth(1)
        f.edges = edges
        function f:SetBorderColor(c, a)
            for i = 1, 4 do SetColor(self.edges[i], c, a) end
        end
        f:SetBorderColor(border or T.colors.borderDim)
    end
    function f:SetBackgroundColor(c, a) SetColor(self.bg, c, a) end
    return f
end

function W.Text(parent, size, text, color, flags, kind)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    T.ApplyFont(fs, size or 12, flags or "", kind)
    color = color or T.colors.text
    fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    fs:SetText(text or "")
    fs:SetJustifyH("LEFT")
    return fs
end

function W.Title(parent, size, text, color)
    return W.Text(parent, size or 18, text, color or T.colors.gold, "", "title")
end

function W.Icon(parent, size, texture, layer)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetSize(size, size)
    if texture then t:SetTexture(texture) end
    t:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    return t
end

function W.Separator(parent)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetHeight(1)
    SetColor(t, T.colors.borderDim)
    return t
end

---------------------------------------------------------------------------
-- Tooltips
---------------------------------------------------------------------------
function W.ShowTooltip(owner, title, lines, anchor)
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    if title then GameTooltip:AddLine(title, 1, 0.82, 0.2) end
    if type(lines) == "table" then
        for _, l in ipairs(lines) do
            if type(l) == "table" then
                GameTooltip:AddDoubleLine(l[1], l[2], 0.85, 0.85, 0.85, 1, 1, 1)
            else
                GameTooltip:AddLine(l, 0.85, 0.85, 0.85, true)
            end
        end
    elseif type(lines) == "string" then
        GameTooltip:AddLine(lines, 0.85, 0.85, 0.85, true)
    end
    GameTooltip:Show()
end

function W.SetTooltip(frame, title, lines)
    frame:EnableMouse(true)
    frame.tipTitle, frame.tipLines = title, lines
    frame:SetScript("OnEnter", function(self)
        if self.tipTitle or self.tipLines then W.ShowTooltip(self, self.tipTitle, self.tipLines) end
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function W.SetItemTooltip(frame, link)
    frame:EnableMouse(true)
    frame.itemLink = link
    frame:SetScript("OnEnter", function(self)
        if self.itemLink then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            pcall(GameTooltip.SetHyperlink, GameTooltip, self.itemLink)
            GameTooltip:Show()
        end
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

---------------------------------------------------------------------------
-- Card
---------------------------------------------------------------------------
function W.Card(parent, w, h, title, icon)
    local c = W.Frame(parent, w, h, T.colors.panel, T.colors.borderDim)
    c.header = W.Text(c, 13, title or "", T.colors.gold, "")
    if icon then
        c.icon = W.Icon(c, 16, icon)
        c.icon:SetPoint("TOPLEFT", 12, -10)
        c.header:SetPoint("TOPLEFT", 34, -12)
    else
        c.header:SetPoint("TOPLEFT", 14, -12)
    end
    c.sub = W.Text(c, 11, "", T.colors.muted)
    c.sub:SetPoint("TOPRIGHT", -14, -13)
    c.sub:SetJustifyH("RIGHT")
    c.headerLine = W.Separator(c)
    c.headerLine:SetPoint("TOPLEFT", 12, -32)
    c.headerLine:SetPoint("TOPRIGHT", -12, -32)
    c.content = CreateFrame("Frame", nil, c)
    c.content:SetPoint("TOPLEFT", 12, -40)
    c.content:SetPoint("BOTTOMRIGHT", -12, 12)
    function c:SetTitle(t) self.header:SetText(t or "") end
    function c:SetSubtitle(t) self.sub:SetText(t or "") end
    return c
end

---------------------------------------------------------------------------
-- Stat tile
---------------------------------------------------------------------------
function W.StatTile(parent, w, h)
    local f = W.Frame(parent, w, h, T.colors.panel, T.colors.borderDim)
    f.icon = W.Icon(f, 22)
    f.icon:SetPoint("TOPLEFT", 12, -12)
    f.value = W.Text(f, 20, "0", T.colors.text, "")
    f.value:SetPoint("TOPLEFT", 42, -10)
    f.value:SetPoint("RIGHT", -8, 0)
    f.label = W.Text(f, 11, "", T.colors.muted)
    f.label:SetPoint("BOTTOMLEFT", 12, 10)
    f.label:SetPoint("BOTTOMRIGHT", -8, 10)
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(self)
        self:SetBackgroundColor(T.colors.panelHi)
        if self.tipTitle then W.ShowTooltip(self, self.tipTitle, self.tipLines) end
    end)
    f:SetScript("OnLeave", function(self)
        self:SetBackgroundColor(T.colors.panel)
        GameTooltip:Hide()
    end)
    function f:Set(value, label, icon, tipTitle, tipLines)
        self.value:SetText(value or "")
        self.label:SetText(label or "")
        if icon then self.icon:SetTexture(icon) end
        self.tipTitle, self.tipLines = tipTitle, tipLines
    end
    -- click copies "value label", e.g. "1,842 enemies slain"
    f:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            W.ShowCopyBox(W.Plain((self.value:GetText() or "") .. " " .. (self.label:GetText() or "")), self.tipTitle or "Copy")
        end
    end)
    return f
end

---------------------------------------------------------------------------
-- Progress bar
---------------------------------------------------------------------------
function W.ProgressBar(parent, w, h, color)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(w, h)
    f.w = w
    f.track = f:CreateTexture(nil, "BACKGROUND")
    f.track:SetAllPoints()
    SetColor(f.track, T.colors.track)
    f.fill = f:CreateTexture(nil, "ARTWORK")
    f.fill:SetPoint("TOPLEFT")
    f.fill:SetPoint("BOTTOMLEFT")
    f.fill:SetWidth(1)
    SetColor(f.fill, color or T.colors.gold)
    f.extra = f:CreateTexture(nil, "BORDER")
    f.extra:Hide()
    f.text = W.Text(f, 10, "", T.colors.text, "OUTLINE")
    f.text:SetPoint("CENTER")
    f.left = W.Text(f, 10, "", T.colors.text, "OUTLINE")
    f.left:SetPoint("LEFT", 4, 0)
    f.right = W.Text(f, 10, "", T.colors.text, "OUTLINE")
    f.right:SetPoint("RIGHT", -4, 0)
    f.right:SetJustifyH("RIGHT")

    function f:SetWidthValue(width)
        self.w = width
        self:SetWidth(width)
    end

    -- pct 0..1; extraPct is drawn after the fill (rested XP); extraColor optional
    function f:Set(pct, text, color, extraPct, extraColor)
        pct = FJ.Clamp(tonumber(pct) or 0, 0, 1)
        if pct <= 0 then
            self.fill:Hide()
        else
            self.fill:Show()
            self.fill:SetWidth(math.max(1, pct * self.w))
        end
        if color then SetColor(self.fill, color) end
        self.text:SetText(text or "")
        if extraPct and extraPct > 0 then
            local total = FJ.Clamp(pct + extraPct, 0, 1)
            if total > pct then
                self.extra:ClearAllPoints()
                self.extra:SetPoint("TOPLEFT", pct * self.w, 0)
                self.extra:SetPoint("BOTTOMLEFT", pct * self.w, 0)
                self.extra:SetWidth(math.max(1, (total - pct) * self.w))
                SetColor(self.extra, extraColor or T.colors.rested, 0.6)
                self.extra:Show()
            else
                self.extra:Hide()
            end
        else
            self.extra:Hide()
        end
    end
    return f
end

---------------------------------------------------------------------------
-- Buttons and rows
---------------------------------------------------------------------------
function W.Button(parent, text, w, h, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w or 100, h or 22)
    b:SetText(text or "")
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

function W.FlatButton(parent, text, w, h, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    SetColor(b.bg, T.colors.panelHi)
    b.text = W.Text(b, 11, text, T.colors.text)
    b.text:SetPoint("CENTER")
    b.text:SetJustifyH("CENTER")
    b:SetScript("OnEnter", function(self) if not self.selected then SetColor(self.bg, T.colors.border) end end)
    b:SetScript("OnLeave", function(self) if not self.selected then SetColor(self.bg, T.colors.panelHi) end end)
    if onClick then b:SetScript("OnClick", onClick) end
    function b:SetSelected(sel)
        self.selected = sel
        if sel then
            SetColor(self.bg, T.colors.goldDim)
            self.text:SetTextColor(0.08, 0.08, 0.08)
        else
            SetColor(self.bg, T.colors.panelHi)
            self.text:SetTextColor(T.RGB(T.colors.text))
        end
    end
    return b
end

function W.NavButton(parent, w, h, icon, label, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    SetColor(b.bg, T.colors.panelHi, 0)
    b.accent = b:CreateTexture(nil, "ARTWORK")
    b.accent:SetPoint("TOPLEFT")
    b.accent:SetPoint("BOTTOMLEFT")
    b.accent:SetWidth(3)
    SetColor(b.accent, T.colors.gold)
    b.accent:Hide()
    b.icon = W.Icon(b, 18, icon)
    b.icon:SetPoint("LEFT", 14, 0)
    b.label = W.Text(b, 12, label, T.colors.muted)
    b.label:SetPoint("LEFT", 40, 0)
    b:SetScript("OnEnter", function(self) if not self.selected then SetColor(self.bg, T.colors.panelHi, 1) end end)
    b:SetScript("OnLeave", function(self) if not self.selected then SetColor(self.bg, T.colors.panelHi, 0) end end)
    if onClick then b:SetScript("OnClick", onClick) end
    function b:SetSelected(sel)
        self.selected = sel
        if sel then
            SetColor(self.bg, T.colors.panelHi, 1)
            self.accent:Show()
            self.label:SetTextColor(T.RGB(T.colors.text))
        else
            SetColor(self.bg, T.colors.panelHi, 0)
            self.accent:Hide()
            self.label:SetTextColor(T.RGB(T.colors.muted))
        end
    end
    return b
end

function W.Row(parent, h)
    local r = CreateFrame("Button", nil, parent)
    r:SetHeight(h or 24)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    SetColor(r.bg, T.colors.panelHi, 0)
    r:SetScript("OnEnter", function(self)
        SetColor(self.bg, T.colors.panelHi, 1)
        if self.tipTitle or self.tipLines then W.ShowTooltip(self, self.tipTitle, self.tipLines) end
    end)
    r:SetScript("OnLeave", function(self)
        SetColor(self.bg, T.colors.panelHi, self.selected and 0.7 or 0)
        GameTooltip:Hide()
    end)
    function r:SetSelected(s)
        self.selected = s
        SetColor(self.bg, T.colors.panelHi, s and 0.7 or 0)
    end
    return r
end

---------------------------------------------------------------------------
-- Horizontal bars (label | bar | value)
---------------------------------------------------------------------------
function W.HBars(parent, w, rowH)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(w, 1)
    f.w = w
    f.rowH = rowH or 22
    f.pool = W.Pool(function()
        local r = CreateFrame("Frame", nil, f)
        r:SetHeight(f.rowH)
        r.icon = W.Icon(r, 14)
        r.icon:SetPoint("LEFT", 0, 0)
        r.label = W.Text(r, 11, "", T.colors.text)
        r.label:SetWordWrap(false)
        r.bar = W.ProgressBar(r, 10, 10)
        r.value = W.Text(r, 11, "", T.colors.muted)
        r.value:SetJustifyH("RIGHT")
        r:EnableMouse(true)
        r:SetScript("OnEnter", function(self)
            if self.tipTitle or self.tip then W.ShowTooltip(self, self.tipTitle, self.tip) end
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return r
    end)
    function f:SetWidthValue(width)
        self.w = width
        self:SetWidth(width)
    end
    -- rows: { label, value, text, color, icon, tip, tipTitle }
    -- opts: { max, labelWidth, valueWidth, icons, barHeight }
    function f:SetData(rows, opts)
        opts = opts or {}
        self.pool:ReleaseAll()
        local max = opts.max or 0
        if max == 0 then
            for _, r in ipairs(rows) do
                if (r.value or 0) > max then max = r.value end
            end
        end
        local labelW = opts.labelWidth or 110
        local valueW = opts.valueWidth or 70
        local iconW = opts.icons and 20 or 0
        local barX = iconW + labelW + 6
        local barW = math.max(10, self.w - barX - valueW - 6)
        local y = 0
        for i, r in ipairs(rows) do
            local row = self.pool:Acquire()
            row:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
            row:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -y)
            if opts.icons then
                row.icon:Show()
                row.icon:SetTexture(r.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            else
                row.icon:Hide()
            end
            row.label:ClearAllPoints()
            row.label:SetPoint("LEFT", iconW, 0)
            row.label:SetWidth(labelW)
            row.label:SetText(r.label or "")
            row.bar:ClearAllPoints()
            row.bar:SetPoint("LEFT", barX, 0)
            row.bar:SetWidthValue(barW)
            row.bar:SetHeight(opts.barHeight or 10)
            row.bar:Set(max > 0 and (r.value or 0) / max or 0, nil, r.color or T.palette[(i - 1) % #T.palette + 1])
            row.value:ClearAllPoints()
            row.value:SetPoint("RIGHT", 0, 0)
            row.value:SetWidth(valueW)
            row.value:SetText(r.text or FJ.FormatNumber(r.value or 0))
            row.tip, row.tipTitle = r.tip, r.tipTitle or r.label
            y = y + self.rowH
        end
        self:SetHeight(math.max(1, y))
        return y
    end
    return f
end

---------------------------------------------------------------------------
-- Vertical bars
---------------------------------------------------------------------------
function W.VBars(parent, w, h)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(w, h)
    f.w, f.h = w, h
    f.baseline = f:CreateTexture(nil, "ARTWORK")
    f.baseline:SetPoint("BOTTOMLEFT", 0, 14)
    f.baseline:SetPoint("BOTTOMRIGHT", 0, 14)
    f.baseline:SetHeight(1)
    SetColor(f.baseline, T.colors.borderDim)
    f.maxLabel = W.Text(f, 10, "", T.colors.dim)
    f.maxLabel:SetPoint("TOPLEFT", 0, 0)
    f.firstLabel = W.Text(f, 10, "", T.colors.dim)
    f.firstLabel:SetPoint("BOTTOMLEFT", 0, 0)
    f.lastLabel = W.Text(f, 10, "", T.colors.dim)
    f.lastLabel:SetPoint("BOTTOMRIGHT", 0, 0)
    f.lastLabel:SetJustifyH("RIGHT")
    f.empty = W.Text(f, 11, "Not enough data yet", T.colors.dim)
    f.empty:SetPoint("CENTER")
    f.empty:Hide()
    f.pool = W.Pool(function()
        local b = CreateFrame("Frame", nil, f)
        b.tex = b:CreateTexture(nil, "ARTWORK")
        b.tex:SetAllPoints()
        b:EnableMouse(true)
        b:SetScript("OnEnter", function(self)
            SetColor(self.tex, T.colors.text)
            if self.tip or self.tipTitle then W.ShowTooltip(self, self.tipTitle, self.tip, "ANCHOR_TOP") end
        end)
        b:SetScript("OnLeave", function(self)
            SetColor(self.tex, self.color, self.alpha)
            GameTooltip:Hide()
        end)
        return b
    end)
    -- points: { value, label, color, tip, tipTitle }; opts: { maxText, align }
    function f:SetData(points, opts)
        opts = opts or {}
        self.pool:ReleaseAll()
        local n = #points
        if n == 0 then
            self.empty:Show()
            self.maxLabel:SetText("")
            self.firstLabel:SetText("")
            self.lastLabel:SetText("")
            return
        end
        self.empty:Hide()
        local max = 0
        for _, p in ipairs(points) do
            if (p.value or 0) > max then max = p.value end
        end
        local areaH = self.h - 30
        local gap = 2
        local barW = math.max(2, (self.w - gap * (n - 1)) / n)
        if barW > 40 then barW = 40 end
        local totalW = barW * n + gap * (n - 1)
        local x0 = (opts.align == "right") and (self.w - totalW) or 0
        for i, p in ipairs(points) do
            local b = self.pool:Acquire()
            local v = p.value or 0
            local hgt = (max > 0 and v > 0) and math.max(2, v / max * areaH) or 2
            b:SetSize(barW, hgt)
            b:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", x0 + (i - 1) * (barW + gap), 15)
            b.color = p.color or T.colors.gold
            b.alpha = v > 0 and 1 or 0.25
            SetColor(b.tex, b.color, b.alpha)
            b.tip, b.tipTitle = p.tip, p.tipTitle or p.label
        end
        self.maxLabel:SetText(opts.maxText or FJ.FormatCompact(max))
        self.firstLabel:SetText(points[1].label or "")
        self.lastLabel:SetText(n > 1 and (points[n].label or "") or "")
    end
    return f
end

---------------------------------------------------------------------------
-- Line chart
---------------------------------------------------------------------------
function W.LineChart(parent, w, h)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(w, h)
    f.w, f.h = w, h
    f.padL, f.padR, f.padT, f.padB = 40, 10, 14, 16
    f.axisX = f:CreateTexture(nil, "ARTWORK")
    f.axisX:SetHeight(1)
    f.axisX:SetPoint("BOTTOMLEFT", f.padL, f.padB)
    f.axisX:SetPoint("BOTTOMRIGHT", -f.padR, f.padB)
    SetColor(f.axisX, T.colors.borderDim)
    f.axisY = f:CreateTexture(nil, "ARTWORK")
    f.axisY:SetWidth(1)
    f.axisY:SetPoint("BOTTOMLEFT", f.padL, f.padB)
    f.axisY:SetPoint("TOPLEFT", f.padL, -f.padT)
    SetColor(f.axisY, T.colors.borderDim)
    f.yMax = W.Text(f, 10, "", T.colors.dim)
    f.yMax:SetPoint("TOPLEFT", 0, -f.padT + 4)
    f.yMax:SetWidth(f.padL - 4)
    f.yMax:SetJustifyH("RIGHT")
    f.yMin = W.Text(f, 10, "", T.colors.dim)
    f.yMin:SetPoint("BOTTOMLEFT", 0, f.padB - 4)
    f.yMin:SetWidth(f.padL - 4)
    f.yMin:SetJustifyH("RIGHT")
    f.xMin = W.Text(f, 10, "", T.colors.dim)
    f.xMin:SetPoint("BOTTOMLEFT", f.padL, 0)
    f.xMax = W.Text(f, 10, "", T.colors.dim)
    f.xMax:SetPoint("BOTTOMRIGHT", -f.padR, 0)
    f.xMax:SetJustifyH("RIGHT")
    f.empty = W.Text(f, 11, "Not enough data yet", T.colors.dim)
    f.empty:SetPoint("CENTER")
    f.empty:Hide()
    f.hasLines = f.CreateLine ~= nil
    f.lines = W.Pool(function()
        local l = f:CreateLine(nil, "OVERLAY")
        l:SetThickness(2)
        return l
    end)
    f.dots = W.Pool(function()
        local d = CreateFrame("Frame", nil, f)
        d:SetSize(8, 8)
        d.tex = d:CreateTexture(nil, "OVERLAY", nil, 2)
        d.tex:SetPoint("CENTER")
        d.tex:SetSize(5, 5)
        d:EnableMouse(true)
        d:SetScript("OnEnter", function(self)
            self.tex:SetSize(8, 8)
            if self.tip or self.tipTitle then W.ShowTooltip(self, self.tipTitle, self.tip, "ANCHOR_TOP") end
        end)
        d:SetScript("OnLeave", function(self)
            self.tex:SetSize(5, 5)
            GameTooltip:Hide()
        end)
        return d
    end)

    -- points: { x, y, tip, tipTitle, now }; opts: { xFormat, yFormat, step, color, minY }
    function f:SetData(points, opts)
        opts = opts or {}
        self.lines:ReleaseAll()
        self.dots:ReleaseAll()
        if #points < 2 then
            self.empty:Show()
            self.yMax:SetText(""); self.yMin:SetText(""); self.xMin:SetText(""); self.xMax:SetText("")
            return
        end
        self.empty:Hide()
        local minX, maxX = points[1].x, points[1].x
        local minY, maxY = opts.minY or 0, points[1].y
        for _, p in ipairs(points) do
            if p.x < minX then minX = p.x end
            if p.x > maxX then maxX = p.x end
            if p.y > maxY then maxY = p.y end
            if opts.minY == nil and p.y < minY then minY = p.y end
        end
        if maxX <= minX then maxX = minX + 1 end
        if maxY <= minY then maxY = minY + 1 end
        local pw = self.w - self.padL - self.padR
        local ph = self.h - self.padT - self.padB
        local function px(x) return self.padL + (x - minX) / (maxX - minX) * pw end
        local function py(y) return self.padB + (y - minY) / (maxY - minY) * ph end
        local color = opts.color or T.colors.gold
        local xf = opts.xFormat or function(v) return tostring(FJ.Round(v)) end
        local yf = opts.yFormat or function(v) return FJ.FormatCompact(v) end

        if self.hasLines then
            for i = 2, #points do
                local a, b = points[i - 1], points[i]
                local x1, y1, x2, y2 = px(a.x), py(a.y), px(b.x), py(b.y)
                if opts.step then
                    local l1 = self.lines:Acquire()
                    l1:SetStartPoint("BOTTOMLEFT", self, x1, y1)
                    l1:SetEndPoint("BOTTOMLEFT", self, x2, y1)
                    l1:SetColorTexture(color[1], color[2], color[3], 0.9)
                    local l2 = self.lines:Acquire()
                    l2:SetStartPoint("BOTTOMLEFT", self, x2, y1)
                    l2:SetEndPoint("BOTTOMLEFT", self, x2, y2)
                    l2:SetColorTexture(color[1], color[2], color[3], 0.9)
                else
                    local l = self.lines:Acquire()
                    l:SetStartPoint("BOTTOMLEFT", self, x1, y1)
                    l:SetEndPoint("BOTTOMLEFT", self, x2, y2)
                    l:SetColorTexture(color[1], color[2], color[3], 0.9)
                end
            end
        end
        for _, p in ipairs(points) do
            local d = self.dots:Acquire()
            d:SetPoint("CENTER", self, "BOTTOMLEFT", px(p.x), py(p.y))
            if p.now then
                SetColor(d.tex, T.colors.text)
            else
                SetColor(d.tex, color)
            end
            d.tip = p.tip or { xf(p.x), yf(p.y) }
            d.tipTitle = p.tipTitle
        end
        self.yMax:SetText(yf(maxY))
        self.yMin:SetText(yf(minY))
        self.xMin:SetText(xf(minX))
        self.xMax:SetText(xf(maxX))
    end
    return f
end

---------------------------------------------------------------------------
-- Scroll area with a slim scrollbar
---------------------------------------------------------------------------
function W.ScrollArea(parent)
    local sf = CreateFrame("ScrollFrame", nil, parent)
    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(100, 100)
    sf:SetScrollChild(content)
    sf.content = content

    local bar = CreateFrame("Slider", nil, sf)
    bar:SetWidth(6)
    bar:SetPoint("TOPLEFT", sf, "TOPRIGHT", 4, 0)
    bar:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 4, 0)
    bar:SetOrientation("VERTICAL")
    bar.track = bar:CreateTexture(nil, "BACKGROUND")
    bar.track:SetAllPoints()
    SetColor(bar.track, T.colors.track)
    bar:SetThumbTexture(T.WHITE)
    local thumb = bar:GetThumbTexture()
    thumb:SetSize(6, 40)
    thumb:SetColorTexture(T.colors.goldDim[1], T.colors.goldDim[2], T.colors.goldDim[3], 1)
    bar:SetMinMaxValues(0, 0)
    bar:SetValue(0)
    bar:SetValueStep(1)
    bar:SetScript("OnValueChanged", function(_, v) sf:SetVerticalScroll(v) end)
    sf.bar = bar

    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local _, max = bar:GetMinMaxValues()
        bar:SetValue(FJ.Clamp(bar:GetValue() - delta * 48, 0, max))
    end)

    function sf:UpdateRange()
        local vis = self:GetHeight()
        local range = math.max(0, content:GetHeight() - vis)
        bar:SetMinMaxValues(0, range)
        if range <= 0 then
            bar:SetValue(0)
            bar:Hide()
        else
            bar:Show()
            if bar:GetValue() > range then bar:SetValue(range) end
            thumb:SetHeight(math.max(20, vis * vis / (vis + range)))
        end
    end
    function sf:SetContentHeight(h)
        content:SetWidth(self:GetWidth())
        content:SetHeight(math.max(1, h))
        self:UpdateRange()
    end
    function sf:ScrollTo(v)
        local _, max = bar:GetMinMaxValues()
        bar:SetValue(FJ.Clamp(v, 0, max))
    end
    function sf:ScrollToBottom()
        local _, max = bar:GetMinMaxValues()
        bar:SetValue(max)
    end
    sf:SetScript("OnSizeChanged", function(self, w)
        content:SetWidth(w)
        self:UpdateRange()
    end)
    return sf
end

---------------------------------------------------------------------------
-- Donut chart with legend. Wedges are drawn from many short radial line segments, which is
-- the only way to paint arbitrary arcs without custom texture files.
---------------------------------------------------------------------------
function W.Donut(parent, size, legendW)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size + (legendW or 0), size)
    f.size = size
    f.pie = CreateFrame("Frame", nil, f)
    f.pie:SetSize(size, size)
    f.pie:SetPoint("LEFT")
    f.hasLines = f.pie.CreateLine ~= nil
    f.lines = W.Pool(function() return f.pie:CreateLine(nil, "ARTWORK") end)
    f.segments = W.Pool(function()
        local t = f.pie:CreateTexture(nil, "ARTWORK")
        return t
    end)
    f.legend = W.Pool(function()
        local r = CreateFrame("Frame", nil, f)
        r:SetHeight(16)
        r.dot = r:CreateTexture(nil, "ARTWORK")
        r.dot:SetSize(8, 8)
        r.dot:SetPoint("LEFT", 0, 0)
        r.label = W.Text(r, 11, "", T.colors.text)
        r.label:SetPoint("LEFT", 14, 0)
        r.label:SetPoint("RIGHT", -70, 0)
        r.label:SetWordWrap(false)
        r.value = W.Text(r, 11, "", T.colors.muted)
        r.value:SetPoint("RIGHT", 0, 0)
        r.value:SetWidth(68)
        r.value:SetJustifyH("RIGHT")
        return r
    end)
    f.center = W.Text(f.pie, 16, "", T.colors.text, "")
    f.center:SetPoint("CENTER", 0, 6)
    f.center:SetJustifyH("CENTER")
    f.centerSub = W.Text(f.pie, 9, "", T.colors.dim)
    f.centerSub:SetPoint("CENTER", 0, -8)
    f.centerSub:SetJustifyH("CENTER")
    f.empty = W.Text(f, 11, "Nothing yet", T.colors.dim)
    f.empty:SetPoint("CENTER", f.pie)
    f.empty:Hide()

    -- slices: { label, value, color }; opts: { maxLegend, centerText, centerSub, steps }
    function f:SetData(slices, opts)
        opts = opts or {}
        self.lines:ReleaseAll()
        self.segments:ReleaseAll()
        self.legend:ReleaseAll()
        local total = 0
        for _, s in ipairs(slices) do total = total + (s.value or 0) end
        if total <= 0 then
            self.empty:Show()
            self.center:SetText("")
            self.centerSub:SetText("")
            return
        end
        self.empty:Hide()
        local r = self.size / 2
        local inner, outer = r * 0.46, r - 1
        local steps = opts.steps or 144
        local thickness = (2 * math.pi * outer / steps) * 1.3
        local angle = -math.pi / 2
        if self.hasLines then
            for i, s in ipairs(slices) do
                local frac = (s.value or 0) / total
                if frac > 0 then
                    local n = math.max(1, math.floor(frac * steps + 0.5))
                    local color = s.color or T.palette[(i - 1) % #T.palette + 1]
                    local step = (frac * 2 * math.pi) / n
                    for k = 0, n - 1 do
                        local a = angle + (k + 0.5) * step
                        local l = self.lines:Acquire()
                        l:SetThickness(thickness)
                        l:SetStartPoint("CENTER", self.pie, math.cos(a) * inner, -math.sin(a) * inner)
                        l:SetEndPoint("CENTER", self.pie, math.cos(a) * outer, -math.sin(a) * outer)
                        l:SetColorTexture(color[1], color[2], color[3], 1)
                    end
                    angle = angle + frac * 2 * math.pi
                end
            end
        else
            -- fallback: a stacked horizontal bar across the pie area
            local x = 0
            for i, s in ipairs(slices) do
                local w = (s.value or 0) / total * self.size
                if w > 0.5 then
                    local t = self.segments:Acquire()
                    t:SetSize(w, 14)
                    t:SetPoint("LEFT", self.pie, "LEFT", x, 0)
                    SetColor(t, s.color or T.palette[(i - 1) % #T.palette + 1])
                    x = x + w
                end
            end
        end
        self.center:SetText(opts.centerText or FJ.FormatCompact(total))
        self.centerSub:SetText(opts.centerSub or "")
        local y = 0
        for i, s in ipairs(slices) do
            if i > (opts.maxLegend or 8) then break end
            local row = self.legend:Acquire()
            row:SetPoint("TOPLEFT", self, "TOPLEFT", self.size + 14, -y)
            row:SetPoint("RIGHT", self, "RIGHT", 0, 0)
            SetColor(row.dot, s.color or T.palette[(i - 1) % #T.palette + 1])
            row.label:SetText(s.label or "?")
            row.value:SetText(format("%s  %d%%", FJ.FormatNumber(s.value or 0), math.floor((s.value or 0) / total * 100 + 0.5)))
            y = y + 16
        end
    end
    return f
end

---------------------------------------------------------------------------
-- Copy box. WoW gives addons no clipboard, so the text is shown selected for Ctrl+C.
---------------------------------------------------------------------------
-- Strips colour codes, textures and hyperlink wrappers from UI text.
function W.Plain(text)
    if type(text) ~= "string" then return tostring(text or "") end
    local s = text:gsub("|T.-|t", ""):gsub("|A.-|a", "")
    s = s:gsub("|H.-|h(.-)|h", "%1")
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return s
end

local copyFrame
function W.ShowCopyBox(text, title)
    if type(text) ~= "string" or text == "" then return end
    if not copyFrame then
        local f = W.Frame(UIParent, 540, 150, T.colors.bg, T.colors.border)
        _G.ForeverJourneyCopyBox = f
        f:SetFrameStrata("DIALOG")
        f:SetPoint("CENTER", 0, 120)
        f:SetClampedToScreen(true)
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function(self) self:StartMoving() end)
        f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        f.title = W.Text(f, 12, "Copy", T.colors.gold)
        f.title:SetPoint("TOPLEFT", 12, -10)
        f.hint = W.Text(f, 10, "Ctrl+C copies the selected text. Escape closes.", T.colors.dim)
        f.hint:SetPoint("TOPRIGHT", -30, -11)
        f.hint:SetJustifyH("RIGHT")
        local scroll = CreateFrame("ScrollFrame", nil, f)
        scroll:SetPoint("TOPLEFT", 12, -30)
        scroll:SetPoint("BOTTOMRIGHT", -12, 12)
        scroll:EnableMouseWheel(true)
        scroll:SetScript("OnMouseWheel", function(self, delta)
            self:SetVerticalScroll(FJ.Clamp(self:GetVerticalScroll() - delta * 30, 0, self:GetVerticalScrollRange()))
        end)
        f.inner = f:CreateTexture(nil, "BORDER")
        f.inner:SetPoint("TOPLEFT", scroll, -4, 4)
        f.inner:SetPoint("BOTTOMRIGHT", scroll, 4, -4)
        SetColor(f.inner, T.colors.track)
        local eb = CreateFrame("EditBox", nil, scroll)
        eb:SetMultiLine(true)
        eb:SetAutoFocus(false)
        eb:SetFontObject(ChatFontNormal)
        eb:SetWidth(508)
        eb:SetScript("OnEscapePressed", function() f:Hide() end)
        eb:SetScript("OnTextChanged", function(self, user)
            if user and self.fjText and self:GetText() ~= self.fjText then
                self:SetText(self.fjText)
                self:HighlightText()
            end
        end)
        eb:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        scroll:SetScrollChild(eb)
        f.eb = eb
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", 2, 2)
        close:SetScript("OnClick", function() f:Hide() end)
        tinsert(UISpecialFrames, "ForeverJourneyCopyBox")
        copyFrame = f
    end
    copyFrame.title:SetText(title or "Copy")
    local _, newlines = text:gsub("\n", "")
    copyFrame:SetHeight(FJ.Clamp(64 + (newlines + 1) * 14, 110, 380))
    copyFrame.eb.fjText = text
    copyFrame.eb:SetText(text)
    copyFrame:Show()
    copyFrame.eb:SetFocus()
    copyFrame.eb:HighlightText()
end

-- Left-clicking the frame opens the copy box with textFn(frame)'s result.
function W.MakeCopyable(frame, textFn, title)
    frame:EnableMouse(true)
    local script = (frame:GetObjectType() == "Button") and "OnClick" or "OnMouseUp"
    local handler = function(self, button)
        if button == nil or button == "LeftButton" then
            local text = textFn(self)
            if text and text ~= "" then W.ShowCopyBox(W.Plain(text), title) end
        end
    end
    if frame:GetScript(script) then
        frame:HookScript(script, handler)
    else
        frame:SetScript(script, handler)
    end
end

---------------------------------------------------------------------------
-- Timeline row
---------------------------------------------------------------------------
local function HexToRGB(hex)
    if type(hex) ~= "string" or #hex < 8 then return T.colors.gold end
    return {
        (tonumber(hex:sub(3, 4), 16) or 255) / 255,
        (tonumber(hex:sub(5, 6), 16) or 210) / 255,
        (tonumber(hex:sub(7, 8), 16) or 50) / 255,
    }
end
W.HexToRGB = HexToRGB

function W.TimelineRow(parent, w)
    local r = CreateFrame("Button", nil, parent)
    r:SetSize(w, 44)
    r.lineTop = r:CreateTexture(nil, "BACKGROUND")
    r.lineTop:SetWidth(2)
    r.lineTop:SetPoint("TOP", r, "TOPLEFT", 16, 0)
    r.lineTop:SetPoint("BOTTOM", r, "TOPLEFT", 16, -22)
    r.lineBottom = r:CreateTexture(nil, "BACKGROUND")
    r.lineBottom:SetWidth(2)
    r.lineBottom:SetPoint("TOP", r, "TOPLEFT", 16, -22)
    r.lineBottom:SetPoint("BOTTOM", r, "BOTTOMLEFT", 16, 0)
    SetColor(r.lineTop, T.colors.borderDim)
    SetColor(r.lineBottom, T.colors.borderDim)
    r.dot = r:CreateTexture(nil, "ARTWORK")
    r.dot:SetSize(10, 10)
    r.dot:SetPoint("CENTER", r, "TOPLEFT", 16, -22)
    r.icon = W.Icon(r, 26)
    r.icon:SetPoint("LEFT", 34, 0)
    r.title = W.Text(r, 12, "", T.colors.text)
    r.title:SetPoint("TOPLEFT", 68, -7)
    r.title:SetPoint("RIGHT", -96, 0)
    r.title:SetWordWrap(false)
    r.sub = W.Text(r, 10, "", T.colors.muted)
    r.sub:SetPoint("TOPLEFT", 68, -24)
    r.sub:SetPoint("RIGHT", -96, 0)
    r.sub:SetWordWrap(false)
    r.date = W.Text(r, 10, "", T.colors.dim)
    r.date:SetPoint("TOPRIGHT", -6, -9)
    r.date:SetWidth(88)
    r.date:SetJustifyH("RIGHT")
    r.hl = r:CreateTexture(nil, "HIGHLIGHT")
    r.hl:SetAllPoints()
    SetColor(r.hl, T.colors.panelHi, 0.6)
    function r:Set(title, sub, icon, colorHex, dateText, first, last)
        self.title:SetText(title or "")
        self.sub:SetText(sub or "")
        self.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        self.date:SetText(dateText or "")
        SetColor(self.dot, HexToRGB(colorHex))
        if first then self.lineTop:Hide() else self.lineTop:Show() end
        if last then self.lineBottom:Hide() else self.lineBottom:Show() end
    end
    return r
end
