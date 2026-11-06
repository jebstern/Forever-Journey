-- Forever Journey: "Next" page (gentle suggestions).
local ADDON_NAME, FJ = ...
local T, W = FJ.Theme, FJ.Widgets

local PAD = 16
local GAP = 10
local CARD_H = 74

local function Build(def, page)
    local width, height = FJ.UI:ContentSize()
    local inner = width - PAD * 2

    page.title = W.Title(page, 18, "Things you could continue with")
    page.title:SetPoint("TOPLEFT", PAD, -PAD)
    page.intro = W.Text(page, 11, "Loose ends and nearby opportunities, drawn from your own log and map. No pressure; your journey, your pace.", T.colors.muted)
    page.intro:SetPoint("TOPLEFT", PAD, -(PAD + 24))
    page.intro:SetWidth(inner)
    page.intro:SetWordWrap(true)

    page.scroll = W.ScrollArea(page)
    page.scroll:SetPoint("TOPLEFT", PAD, -(PAD + 52))
    page.scroll:SetPoint("BOTTOMRIGHT", -PAD - 10, PAD)
    local content = page.scroll.content
    local cardW = inner - 10

    page.cards = W.Pool(function()
        local c = W.Frame(content, cardW, CARD_H, T.colors.panel, T.colors.borderDim)
        c.icon = W.Icon(c, 32)
        c.icon:SetPoint("TOPLEFT", 14, -14)
        c.title = W.Text(c, 13, "", T.colors.gold, "")
        c.title:SetPoint("TOPLEFT", 58, -12)
        c.title:SetPoint("RIGHT", -150, 0)
        c.title:SetWordWrap(false)
        c.text = W.Text(c, 11, "", T.colors.text)
        c.text:SetPoint("TOPLEFT", 58, -32)
        c.text:SetPoint("RIGHT", -150, 0)
        c.text:SetWordWrap(true)
        c.text:SetJustifyV("TOP")
        c.text:SetHeight(30)
        c.note = W.Text(c, 10, "", T.colors.dim)
        c.note:SetPoint("BOTTOMLEFT", 58, 6)
        c.note:SetPoint("RIGHT", -150, 0)
        c.note:SetWordWrap(false)
        c.button = W.FlatButton(c, "", 120, 22, function(self) if self.action then self.action() end end)
        c.button:SetPoint("RIGHT", -14, 0)
        return c
    end)
    page.empty = W.Text(content, 12, "", T.colors.dim)
    page.empty:SetPoint("TOPLEFT", 4, -8)
end

local function Refresh(def, page)
    page.cards:ReleaseAll()
    local content = page.scroll.content
    local list = FJ.Suggestions:Build()
    local y = 0
    for _, s in ipairs(list) do
        local c = page.cards:Acquire()
        c:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
        c.icon:SetTexture(s.icon or T.icons.next)
        c.title:SetText(s.title or "")
        c.text:SetText(s.text or "")
        c.note:SetText(s.note or "")
        if s.action then
            c.button:Show()
            c.button.text:SetText(s.actionText or "Open")
            c.button.action = s.action
            c.text:SetPoint("RIGHT", -150, 0)
        else
            c.button:Hide()
            c.button.action = nil
            c.text:SetPoint("RIGHT", -14, 0)
        end
        y = y + CARD_H + GAP
    end
    page.scroll:SetContentHeight(math.max(1, y))
end

FJ.UI:RegisterPage("next", {
    title = "Next", icon = T.icons.next, order = 5,
    build = Build, refresh = Refresh,
})
