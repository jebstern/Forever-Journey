-- Forever Journey: Characters page. Every character on the account that has run the addon,
-- side by side, plus account totals.
local ADDON_NAME, FJ = ...
local T, W = FJ.Theme, FJ.Widgets

local PAD = 16
local GAP = 12
local ROW_H = 26

local COLUMNS = {
    { key = "name", label = "Character", w = 150, align = "LEFT" },
    { key = "level", label = "Level", w = 44 },
    { key = "played", label = "Played", w = 84 },
    { key = "quests", label = "Quests", w = 62 },
    { key = "deaths", label = "Deaths", w = 56 },
    { key = "kills", label = "Kills", w = 70 },
    { key = "zones", label = "Zones", w = 50 },
    { key = "dungeons", label = "Dungeons", w = 70 },
    { key = "lastSeen", label = "Last seen", w = 90 },
}

local function Rows()
    local out = {}
    for key, r in pairs(FJ.gdb.roster or {}) do
        out[#out + 1] = { key = key, data = r, current = key == FJ.charKey }
    end
    table.sort(out, function(a, b)
        if a.current ~= b.current then return a.current end
        return (a.data.played or 0) > (b.data.played or 0)
    end)
    return out
end

local function Totals(rows)
    local t = { chars = 0, played = 0, quests = 0, deaths = 0, kills = 0, dungeons = 0, badges = 0, maxLevel = 0, gold = 0, levels = 0 }
    for _, r in ipairs(rows) do
        local d = r.data
        t.chars = t.chars + 1
        t.played = t.played + (d.played or 0)
        t.quests = t.quests + (d.quests or 0)
        t.deaths = t.deaths + (d.deaths or 0)
        t.kills = t.kills + (d.kills or 0)
        t.dungeons = t.dungeons + (d.dungeons or 0)
        t.badges = t.badges + (d.badges or 0)
        t.gold = t.gold + (d.gold or 0)
        t.levels = t.levels + (d.level or 0)
        if (d.level or 0) > t.maxLevel then t.maxLevel = d.level end
    end
    return t
end
FJ.AccountTotals = Totals
function FJ.AccountSummary()
    return Totals(Rows())
end

local function Build(def, page)
    local width, height = FJ.UI:ContentSize()
    local inner = width - PAD * 2

    page.title = W.Title(page, 18, "Your characters")
    page.title:SetPoint("TOPLEFT", PAD, -PAD)
    page.intro = W.Text(page, 11, "Everyone on this account who has played with Forever Journey installed. Rows update when a character logs out.", T.colors.muted)
    page.intro:SetPoint("TOPLEFT", PAD, -(PAD + 24))
    page.intro:SetWidth(inner)

    -- account totals
    local tileW = (inner - GAP * 3) / 4
    page.tiles = {}
    for i = 1, 4 do
        local tile = W.StatTile(page, tileW, 56)
        tile:SetPoint("TOPLEFT", PAD + (i - 1) * (tileW + GAP), -(PAD + 50))
        page.tiles[i] = tile
    end

    local top = PAD + 50 + 56 + GAP
    local panel = W.Frame(page, inner, height - top - PAD, T.colors.panel, T.colors.borderDim)
    panel:SetPoint("TOPLEFT", PAD, -top)
    page.panel = panel

    -- header row
    local x = 12
    page.headers = {}
    for _, col in ipairs(COLUMNS) do
        local h = W.Text(panel, 10, col.label, T.colors.dim)
        h:SetPoint("TOPLEFT", x, -10)
        h:SetWidth(col.w)
        h:SetJustifyH(col.align or "RIGHT")
        page.headers[#page.headers + 1] = h
        x = x + col.w + 6
    end
    local line = W.Separator(panel)
    line:SetPoint("TOPLEFT", 10, -26)
    line:SetPoint("TOPRIGHT", -10, -26)

    page.scroll = W.ScrollArea(panel)
    page.scroll:SetPoint("TOPLEFT", 8, -30)
    page.scroll:SetPoint("BOTTOMRIGHT", -16, 8)
    local content = page.scroll.content
    page.rows = W.Pool(function()
        local r = W.Row(content, ROW_H)
        r.cells = {}
        local cx = 4
        for i, col in ipairs(COLUMNS) do
            local fs = W.Text(r, 11, "", T.colors.text)
            fs:SetPoint("LEFT", cx, 0)
            fs:SetWidth(col.w)
            fs:SetJustifyH(col.align or "RIGHT")
            fs:SetWordWrap(false)
            r.cells[i] = fs
            cx = cx + col.w + 6
        end
        W.MakeCopyable(r, function(self) return self.copyText end, "Character")
        return r
    end)
    page.empty = W.Text(content, 11, "No other characters yet. Log in with an alt once and it will appear here.", T.colors.dim)
    page.empty:SetPoint("TOPLEFT", 6, -8)
end

local function Refresh(def, page)
    FJ:UpdateRoster()
    local rows = Rows()
    local t = Totals(rows)
    page.tiles[1]:Set(tostring(t.chars), t.chars == 1 and "character" or "characters", T.icons.dashboard, "Characters", { { "Highest level", tostring(t.maxLevel) }, { "Levels combined", tostring(t.levels) } })
    page.tiles[2]:Set(FJ.FormatDuration(t.played), "played across the account", T.icons.played)
    page.tiles[3]:Set(FJ.FormatCompact(t.quests), "quests, all characters", T.icons.quests, "Account totals", { { "Deaths", FJ.FormatNumber(t.deaths) }, { "Kills", FJ.FormatNumber(t.kills) }, { "Dungeons entered", FJ.FormatNumber(t.dungeons) } })
    page.tiles[4]:Set(FJ.FormatCompact(t.deaths), "deaths, all characters", T.icons.deaths, "Account totals", { { "Gold acquired", FJ.FormatMoney(t.gold, true) }, { "Badges", FJ.FormatNumber(t.badges) } })

    page.rows:ReleaseAll()
    local content = page.scroll.content
    local y = 0
    for _, entry in ipairs(rows) do
        local d = entry.data
        local r = page.rows:Acquire()
        r:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
        r:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
        local _, _, _, hex = FJ.ClassColor(d.classFile)
        local name = (d.name or "?") .. (d.realm and d.realm ~= FJ.realm and ("-" .. d.realm) or "")
        local values = {
            "|c" .. hex .. name .. "|r" .. (entry.current and "  |cff8a8a8a(you)|r" or ""),
            tostring(d.level or 0),
            FJ.FormatDuration(d.played or 0),
            FJ.FormatNumber(d.quests or 0),
            FJ.FormatNumber(d.deaths or 0),
            FJ.FormatCompact(d.kills or 0),
            tostring(d.zones or 0),
            FJ.FormatNumber(d.dungeons or 0),
            entry.current and "now" or FJ.RelativeDay(d.lastSeen),
        }
        for i, v in ipairs(values) do r.cells[i]:SetText(v) end
        r.copyText = format("%s: level %d, %s played, %d quests, %d deaths, %d kills, %d zones, %d dungeons",
            name, d.level or 0, FJ.FormatDuration(d.played or 0), d.quests or 0, d.deaths or 0, d.kills or 0, d.zones or 0, d.dungeons or 0)
        r:SetSelected(entry.current)
        y = y + ROW_H
    end
    if #rows <= 1 then page.empty:Show() else page.empty:Hide() end
    page.scroll:SetContentHeight(math.max(1, y + 30))
end

FJ.UI:RegisterPage("characters", {
    title = "Characters", icon = "Interface\\Icons\\INV_Misc_Head_Human_01",
    order = 4.7, build = Build, refresh = Refresh,
})
