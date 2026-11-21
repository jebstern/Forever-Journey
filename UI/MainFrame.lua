-- Forever Journey: the main window, sidebar navigation and page lifecycle.
local ADDON_NAME, FJ = ...
local T, W = FJ.Theme, FJ.Widgets
local UI = FJ:NewModule("UI")

UI.pages = {}
UI.pageOrder = {}

local WIDTH, HEIGHT = 960, 640
local HEADER = 56
local SIDEBAR = 170
local frame

-- def: { title, icon, order, footer, live, build = function(def, page), refresh = function(def, page) }
function UI:RegisterPage(key, def)
    def.key = key
    self.pages[key] = def
    self.pageOrder[#self.pageOrder + 1] = def
    table.sort(self.pageOrder, function(a, b) return (a.order or 99) < (b.order or 99) end)
end

local function SavePosition()
    local point, _, relPoint, x, y = frame:GetPoint()
    FJ.gdb.settings.window = { point = point, relPoint = relPoint, x = x, y = y }
end

local function ApplyPosition()
    local pos = FJ.gdb.settings.window
    frame:ClearAllPoints()
    if pos and pos.point then
        frame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    else
        frame:SetPoint("CENTER")
    end
end

function UI:Build()
    if frame then return frame end
    frame = W.Frame(UIParent, WIDTH, HEIGHT, T.colors.bg, T.colors.border)
    _G.ForeverJourneyFrame = frame
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)
    ApplyPosition()
    frame:SetScale(FJ.gdb.settings.scale or 1)
    frame:Hide()
    frame:SetScript("OnShow", function() FJ.API.PlaySound("IG_MAINMENU_OPEN", 850) end)
    frame:SetScript("OnHide", function() FJ.API.PlaySound("IG_MAINMENU_CLOSE", 851) end)

    -- Header
    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(HEADER)
    header.bg = header:CreateTexture(nil, "BACKGROUND")
    header.bg:SetAllPoints()
    W.SetColor(header.bg, T.colors.bgLight)
    header.line = W.Separator(header)
    header.line:SetPoint("BOTTOMLEFT")
    header.line:SetPoint("BOTTOMRIGHT")
    W.SetColor(header.line, T.colors.border)

    frame.logo = W.Icon(header, 28, T.icons.dashboard)
    frame.logo:SetPoint("LEFT", 16, 0)
    frame.title = W.Title(header, 22, "Forever Journey")
    frame.title:SetPoint("LEFT", 54, 1)
    frame.tagline = W.Text(header, 11, "your character's story", T.colors.dim)
    frame.tagline:SetPoint("LEFT", frame.title, "RIGHT", 12, -2)
    frame.charLine = W.Text(header, 12, "", T.colors.text)
    frame.charLine:SetPoint("RIGHT", -64, 0)
    frame.charLine:SetJustifyH("RIGHT")

    local close = CreateFrame("Button", nil, header, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() UI:Hide() end)

    -- Settings cog next to the close button: grey until hovered or while Settings is open.
    local cog = CreateFrame("Button", nil, header)
    cog:SetSize(22, 22)
    cog:SetPoint("RIGHT", close, "LEFT", 2, 0)
    cog.icon = W.Icon(cog, 18, T.icons.settings)
    cog.icon:SetPoint("CENTER")
    function cog:SetSelected(sel)
        self.selected = sel
        self.icon:SetDesaturated(not sel)
        self.icon:SetAlpha(sel and 1 or 0.7)
    end
    cog:SetScript("OnEnter", function(self)
        self.icon:SetDesaturated(false)
        self.icon:SetAlpha(1)
        W.ShowTooltip(self, "Settings", "Banners, chat lines, map pins, window and banner size.", "ANCHOR_BOTTOMLEFT")
    end)
    cog:SetScript("OnLeave", function(self)
        self:SetSelected(self.selected)
        GameTooltip:Hide()
    end)
    cog:SetScript("OnClick", function() UI:ToggleSettings() end)
    cog:SetSelected(false)
    frame.cog = cog

    -- Sidebar
    local side = CreateFrame("Frame", nil, frame)
    side:SetPoint("TOPLEFT", 0, -HEADER)
    side:SetPoint("BOTTOMLEFT")
    side:SetWidth(SIDEBAR)
    side.bg = side:CreateTexture(nil, "BACKGROUND")
    side.bg:SetAllPoints()
    W.SetColor(side.bg, T.colors.bgLight, 0.6)
    side.line = side:CreateTexture(nil, "BORDER")
    side.line:SetWidth(1)
    side.line:SetPoint("TOPRIGHT")
    side.line:SetPoint("BOTTOMRIGHT")
    W.SetColor(side.line, T.colors.borderDim)

    frame.nav = {}
    local y = -12
    for _, def in ipairs(self.pageOrder) do
        if not def.footer then
            local b = W.NavButton(side, SIDEBAR - 1, 36, def.icon, def.title, function() UI:ShowPage(def.key) end)
            b:SetPoint("TOPLEFT", 0, y)
            frame.nav[def.key] = b
            y = y - 36
        end
    end
    local fy = 48
    for _, def in ipairs(self.pageOrder) do
        if def.footer then
            local b = W.NavButton(side, SIDEBAR - 1, 36, def.icon, def.title, function() UI:ShowPage(def.key) end)
            b:SetPoint("BOTTOMLEFT", 0, fy)
            frame.nav[def.key] = b
            fy = fy + 36
        end
    end
    frame.recording = W.Text(side, 10, "", T.colors.dim)
    frame.recording:SetPoint("BOTTOMLEFT", 14, 26)
    frame.recording:SetWidth(SIDEBAR - 24)
    frame.recording:SetWordWrap(false)
    frame.version = W.Text(side, 10, "v" .. tostring(FJ.version), T.colors.dim)
    frame.version:SetPoint("BOTTOMLEFT", 14, 12)

    -- Content
    frame.content = CreateFrame("Frame", nil, frame)
    frame.content:SetPoint("TOPLEFT", SIDEBAR + 1, -(HEADER + 1))
    frame.content:SetPoint("BOTTOMRIGHT", -1, 1)

    tinsert(UISpecialFrames, "ForeverJourneyFrame")

    FJ:RegisterMessage("FJ_DATA_CHANGED", function()
        if frame:IsShown() then UI:Refresh() end
    end)
    FJ:RegisterMessage("FJ_TICK", function()
        local def = UI.current and UI.pages[UI.current]
        if frame:IsShown() and def and def.live then UI:Refresh() end
    end)
    return frame
end

function UI:GetPage(key)
    local def = self.pages[key]
    if not def then return nil end
    if not def.frame then
        local p = CreateFrame("Frame", nil, frame.content)
        p:SetAllPoints()
        p:Hide()
        p.def = def
        def.frame = p
        local ok, err = pcall(def.build, def, p)
        if not ok then FJ.Error("building page " .. key .. ": " .. tostring(err)) end
    end
    return def
end

function UI:ShowPage(key)
    self:Build()
    local def = self:GetPage(key) or self:GetPage(self.pageOrder[1].key)
    if not def then return end
    if self.current and self.current ~= def.key then
        local prev = self.pages[self.current]
        if prev and prev.frame then prev.frame:Hide() end
        if frame.nav[self.current] then frame.nav[self.current]:SetSelected(false) end
        self.previous = self.current
    end
    self.current = def.key
    def.frame:Show()
    if frame.nav[def.key] then frame.nav[def.key]:SetSelected(true) end
    frame.cog:SetSelected(def.key == "settings")
    self:Refresh()
end

-- The cog: opens Settings, or goes back to the page you came from when Settings is open.
function UI:ToggleSettings()
    if self:IsShown() and self.current == "settings" then
        local back = (self.previous and self.previous ~= "settings") and self.previous or self.pageOrder[1].key
        self:ShowPage(back)
    else
        self:Show("settings")
    end
end

-- Rescales the window and keeps it where it was dragged (offsets are in its own scaled units).
function UI:SetScale(v)
    local s = FJ.gdb.settings
    local old, pos = s.scale or 1, s.window
    if pos and pos.point then
        pos.x, pos.y = (pos.x or 0) * old / v, (pos.y or 0) * old / v
    end
    s.scale = v
    if frame then
        frame:SetScale(v)
        ApplyPosition()
    end
end

function UI:ResetPosition()
    FJ.gdb.settings.window = {}
    if frame then ApplyPosition() end
end

function UI:Refresh()
    if not frame or not frame:IsShown() then return end
    local _, _, _, hex = FJ.ClassColor()
    frame.charLine:SetText(format("|c%s%s|r  -  Level %d %s %s", hex, FJ.playerName or "", UnitLevel("player") or 1, FJ.playerRace or "", FJ.playerClass or ""))
    local start, created = FJ.Stats:JourneyStart()
    frame.recording:SetText((created and "Journey began " or "Recording since ") .. FJ.FormatDate(start))
    local def = self.pages[self.current]
    if def and def.frame and def.refresh then
        local ok, err = pcall(def.refresh, def, def.frame)
        if not ok then FJ.Error("refreshing page " .. tostring(def.key) .. ": " .. tostring(err)) end
    end
end

function UI:Show(page)
    self:Build()
    frame:Show()
    self:ShowPage(page or self.current or (self.pageOrder[1] and self.pageOrder[1].key))
end

function UI:Hide()
    if frame then frame:Hide() end
end

function UI:Toggle(page)
    if frame and frame:IsShown() and (not page or page == self.current) then
        self:Hide()
    else
        self:Show(page)
    end
end

function UI:IsShown()
    return frame ~= nil and frame:IsShown()
end

function UI:ContentSize()
    return WIDTH - SIDEBAR - 2, HEIGHT - HEADER - 2
end

-- Addon compartment (retail-style addon menu on the minimap)
function _G.ForeverJourney_OnAddonCompartmentClick()
    UI:Toggle()
end
