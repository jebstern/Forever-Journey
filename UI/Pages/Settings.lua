-- Forever Journey: Settings page. Every option in one place: the cog in the window header, the
-- sidebar, /journey settings, and the same controls again under the game's Options > AddOns.
-- Settings live in FJ.gdb.settings, so they are shared by every character on the account.
local ADDON_NAME, FJ = ...
local T, W = FJ.Theme, FJ.Widgets

local PAD, GAP = 16, 12
local CARD_HEAD, CARD_FOOT = 40, 12
local ROW_H = { toggle = 26, stepper = 26, choice = 26, edit = 28, buttons = 30, note = 30 }
local TWO_COLUMNS_FROM = 700 -- narrower than this (the Options panel), cards stack in one column

local function S() return FJ.gdb.settings end

local function Pct(v) return format("%d%%", FJ.Round(v * 100)) end

local function RefreshMap()
    if FJ.MapPins and FJ.MapPins.Refresh then FJ.MapPins:Refresh() end
end

-- A boolean in FJ.gdb.settings, with an optional side effect after it changes.
local function Flag(key, label, tip, after)
    return {
        kind = "toggle", label = label, tip = tip,
        get = function() return S()[key] and true or false end,
        set = function(v)
            S()[key] = v
            if after then after(v) end
        end,
    }
end

-- Banner thresholds on the chapter priority scale (Core/Timeline.lua PRIO).
local CHAPTERS = {
    { 0, "All", "Every chapter, including each level-up and rare kills." },
    { 45, "Most", "Skips plain level-ups and small finds. Every 5th level, new zones, bosses and milestones still get a banner. This is the default." },
    { 65, "Major", "Only the big moments: every 5th level, new cities, first dungeon visits and clears, final bosses, new professions, epics and badges." },
}

local function ChapterValue()
    local p = S().toastMinPriority or 45
    local best, dist
    for _, o in ipairs(CHAPTERS) do
        local d = math.abs(o[1] - p)
        if not dist or d < dist then best, dist = o[1], d end
    end
    return best
end

local CARDS = {
    {
        title = "Window", icon = T.icons.settings,
        rows = {
            {
                kind = "toggle", label = "Minimap button",
                tip = "Left-click opens the journal, right-click opens Wrapped, Shift-click opens these settings. Drag it to move it around the minimap.",
                get = function() return not S().minimap.hide end,
                set = function(v) FJ.Minimap:SetShown(v) end,
            },
            {
                kind = "stepper", label = "Window scale", tip = "Size of the journal window.",
                min = 0.6, max = 1.5, step = 0.05, format = Pct,
                get = function() return S().scale or 1 end,
                set = function(v) FJ.UI:SetScale(v) end,
            },
            { kind = "buttons", buttons = {
                { "Reset window position", 160, function() FJ.UI:ResetPosition() end, "Moves the journal back to the middle of the screen." },
            } },
        },
    },
    {
        title = "Banners", icon = T.icons.journey,
        rows = {
            Flag("toasts", "Chapter banners", "A banner when a new chapter is written: a new zone, a level, a boss, a badge."),
            {
                kind = "choice", label = "Chapters shown", tip = "Which chapters get a banner. Deaths and flight paths never do.",
                options = CHAPTERS, get = ChapterValue,
                set = function(v) S().toastMinPriority = v end,
            },
            Flag("zoneBanner", "Zone memory banners", "When you come back to a zone: your time there and the quests you have done. At most once every 10 minutes per zone."),
            {
                kind = "stepper", label = "Banner scale", tip = "Size of the banner. It stays where you dragged it.",
                min = 0.5, max = 2, step = 0.1, format = Pct,
                get = function() return S().toastScale or 1 end,
                set = function(v) FJ.Toast:SetScale(v) end,
            },
            { kind = "buttons", buttons = {
                { "Test banner", 100, function() FJ.Toast:Test() end, "Shows a sample banner. Drag it to where banners should appear." },
                { "Reset position", 110, function() FJ.Toast:ResetPosition() end, "Puts the banner back near the top of the screen." },
            } },
        },
    },
    {
        title = "Chat", icon = T.icons.quests,
        rows = {
            Flag("chatRecaps", "Level-up and welcome-back recaps", "When you level: time, quests, kills and deaths for the level you finished. At login: your last session, and what happened a week, a month or a year ago today."),
            Flag("runRecap", "Dungeon run recaps", "When a dungeon run ends: time, bosses, kills, deaths and who you ran with, in chat and as a banner."),
            Flag("deathLine", "A line after each death", "Your deathless streak, how often that enemy has killed you, and how many times you have died in that zone."),
            Flag("suppressPlayedChat", "Hide the journal's /played checks", "The journal asks the game for your /played time now and then. This keeps those replies out of chat. Typing /played yourself still shows it."),
        },
    },
    {
        title = "Journey and World Map", icon = T.icons.world,
        rows = {
            Flag("showDeathsOnTimeline", "Single deaths on the timeline", "Death milestones stay on the timeline either way.", function() FJ:NotifyDataChanged() end),
            Flag("mapDeaths", "Tombstones on the World Map", "A tombstone where each death happened.", RefreshMap),
            Flag("mapFootprints", "Footprints on the World Map", "One footprint per visited zone on continent and world maps, sized by time spent there.", RefreshMap),
        },
    },
    {
        title = "Camping", icon = T.icons.camp,
        rows = {
            {
                kind = "edit", label = "Camping buff",
                tip = "The buff that counts as camping. Type its exact name and press Enter.",
                get = function() return FJ.Social:CampBuffName() end,
                set = function(name)
                    S().campBuff = name
                    S().campSpellID = nil
                    FJ.Print("Camping buff set to \"" .. name .. "\".")
                    FJ.Social:CheckCamp(true)
                end,
            },
            { kind = "note", text = "Not sure of the name? /journey buffs lists the buffs you have right now." },
        },
    },
    {
        title = "Data", icon = T.icons.statistics,
        rows = {
            { kind = "buttons", buttons = {
                { "Erase this character's data", 190, function() StaticPopup_Show("FOREVERJOURNEY_RESET") end, "Starts this character's journal over. Asks first, then reloads the interface." },
            } },
            { kind = "note", text = "Type /journey help in chat for every command." },
        },
    },
}

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------
local function MakeRow(parent, w, row)
    local c
    if row.kind == "toggle" then
        c = W.Toggle(parent, w, row.label, row.tip, row.set)
        function c:Sync() self:SetChecked(row.get()) end
    elseif row.kind == "stepper" then
        c = W.Stepper(parent, w, row.label, row.tip, row, row.set)
        function c:Sync() self:SetValue(row.get()) end
    elseif row.kind == "choice" then
        c = W.Choice(parent, w, row.label, row.tip, row.options, row.set)
        function c:Sync() self:SetValue(row.get()) end
    elseif row.kind == "edit" then
        c = CreateFrame("Frame", nil, parent)
        c:SetSize(w, 24)
        c.label = W.Text(c, 12, row.label, T.colors.text)
        c.label:SetPoint("LEFT", 4, 0)
        if row.tip then
            local hit = CreateFrame("Frame", nil, c)
            hit:SetPoint("TOPLEFT")
            hit:SetPoint("BOTTOMRIGHT", c, "BOTTOMLEFT", 110, 0)
            W.SetTooltip(hit, row.label, row.tip)
        end
        c.box = W.EditBox(c, w - 120, 22)
        c.box:SetPoint("RIGHT", -4, 0)
        local e = c.box.edit
        e:SetScript("OnEnterPressed", function(self)
            local text = FJ.Trim(self:GetText() or "")
            if text ~= "" and text ~= row.get() then row.set(text) end
            self:ClearFocus()
        end)
        -- Leaving without Enter throws the edit away.
        e:HookScript("OnEditFocusLost", function(self) self:SetText(row.get() or "") end)
        function c:Sync()
            if not e:HasFocus() then e:SetText(row.get() or "") end
        end
    elseif row.kind == "buttons" then
        c = CreateFrame("Frame", nil, parent)
        c:SetSize(w, 26)
        local x = 4
        for _, spec in ipairs(row.buttons) do
            local b = W.FlatButton(c, spec[1], spec[2], 22, spec[3])
            b:SetPoint("LEFT", x, 0)
            if spec[4] then W.ButtonTooltip(b, spec[1], spec[4]) end
            x = x + spec[2] + 8
        end
    else -- note
        c = CreateFrame("Frame", nil, parent)
        c:SetSize(w, 26)
        c.text = W.Text(c, 11, row.text, T.colors.dim)
        c.text:SetPoint("TOPLEFT", 4, -4)
        c.text:SetPoint("RIGHT", -4, 0)
        c.text:SetWordWrap(true)
    end
    return c
end

-- Lays the cards out in one or two columns, each card going to the shorter column. Returns the
-- total height and a function that reads every control back from the saved settings.
local function BuildCards(content, width)
    local cols = (width >= TWO_COLUMNS_FROM) and 2 or 1
    local colW = math.floor((width - GAP * (cols - 1)) / cols)
    local heights, controls = {}, {}
    for i = 1, cols do heights[i] = 0 end
    for _, spec in ipairs(CARDS) do
        local col = 1
        for i = 2, cols do
            if heights[i] < heights[col] then col = i end
        end
        local h = CARD_HEAD + CARD_FOOT
        for _, row in ipairs(spec.rows) do h = h + ROW_H[row.kind] end
        local card = W.Card(content, colW, h, spec.title, spec.icon)
        card:SetPoint("TOPLEFT", content, "TOPLEFT", (col - 1) * (colW + GAP), -heights[col])
        local y = 0
        for _, row in ipairs(spec.rows) do
            local c = MakeRow(card.content, colW - 24, row)
            c:SetPoint("TOPLEFT", card.content, "TOPLEFT", 0, -y)
            if c.Sync then controls[#controls + 1] = c end
            y = y + ROW_H[row.kind]
        end
        heights[col] = heights[col] + h + GAP
    end
    local total = 0
    for i = 1, cols do total = math.max(total, heights[i] - GAP) end
    local function sync()
        for _, c in ipairs(controls) do c:Sync() end
    end
    return total, sync
end

---------------------------------------------------------------------------
-- Journal page
---------------------------------------------------------------------------
local function Build(def, page)
    local width = FJ.UI:ContentSize()
    page.title = W.Title(page, 18, "Settings")
    page.title:SetPoint("TOPLEFT", PAD, -PAD)
    page.intro = W.Text(page, 11, "Changes apply right away and count for every character on this account. Hover an option to see what it does.", T.colors.muted)
    page.intro:SetPoint("TOPLEFT", PAD, -(PAD + 24))
    page.scroll = W.ScrollArea(page)
    page.scroll:SetPoint("TOPLEFT", PAD, -(PAD + 48))
    page.scroll:SetPoint("BOTTOMRIGHT", -PAD - 10, PAD)
    page.height, page.sync = BuildCards(page.scroll.content, width - PAD * 2 - 10)
end

local function Refresh(def, page)
    page.sync()
    page.scroll:SetContentHeight(page.height)
end

FJ.UI:RegisterPage("settings", {
    title = "Settings", icon = T.icons.settings, order = 8.5, footer = true,
    build = Build, refresh = Refresh,
})

---------------------------------------------------------------------------
-- Options > AddOns > Forever Journey: the same cards, built the first time the panel is shown
-- (its width is only known then).
---------------------------------------------------------------------------
local Options = FJ:NewModule("Options")

local function BuildPanel(panel)
    local w = panel:GetWidth()
    if not w or w < 300 then w = 600 end
    panel.title = W.Title(panel, 20, "Forever Journey")
    panel.title:SetPoint("TOPLEFT", 16, -16)
    panel.intro = W.Text(panel, 11, "Changes apply right away and count for every character on this account. Open the journal with /journey or the minimap button.", T.colors.muted)
    panel.intro:SetPoint("TOPLEFT", 16, -46)
    panel.intro:SetPoint("RIGHT", -16, 0)
    panel.intro:SetWordWrap(true)
    panel.scroll = W.ScrollArea(panel)
    panel.scroll:SetPoint("TOPLEFT", 16, -80)
    panel.scroll:SetPoint("BOTTOMRIGHT", -26, 16)
    panel.height, panel.sync = BuildCards(panel.scroll.content, w - 42)
end

function Options:OnLogin()
    local modern = Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory
    if not modern and not InterfaceOptions_AddCategory then return end
    local panel = CreateFrame("Frame")
    panel.name = "Forever Journey"
    panel:Hide()
    panel:SetScript("OnShow", function(self)
        if not self.sync then
            local ok, err = pcall(BuildPanel, self)
            if not ok then
                FJ.Error("building the options panel: " .. tostring(err))
                return
            end
        end
        self.sync()
        self.scroll:SetContentHeight(self.height)
    end)
    if modern then
        local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, "Forever Journey")
        if ok and category then pcall(Settings.RegisterAddOnCategory, category) end
    else
        pcall(InterfaceOptions_AddCategory, panel)
    end
end
