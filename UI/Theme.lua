-- Forever Journey: colours, fonts and shared visual constants.
local ADDON_NAME, FJ = ...
local T = {}
FJ.Theme = T

T.WHITE = "Interface\\Buttons\\WHITE8X8"

T.colors = {
    bg        = { 0.055, 0.055, 0.070, 0.97 },
    bgLight   = { 0.095, 0.095, 0.115, 1.00 },
    panel     = { 0.115, 0.115, 0.140, 0.96 },
    panelHi   = { 0.165, 0.165, 0.195, 1.00 },
    border    = { 0.30, 0.26, 0.19, 1.00 },
    borderDim = { 0.17, 0.16, 0.14, 1.00 },
    gold      = { 1.00, 0.82, 0.20 },
    goldDim   = { 0.75, 0.62, 0.22 },
    text      = { 0.95, 0.93, 0.88 },
    muted     = { 0.64, 0.62, 0.57 },
    dim       = { 0.42, 0.41, 0.38 },
    green     = { 0.45, 0.80, 0.35 },
    red       = { 0.95, 0.38, 0.35 },
    blue      = { 0.45, 0.70, 1.00 },
    purple    = { 0.72, 0.52, 1.00 },
    orange    = { 1.00, 0.62, 0.30 },
    teal      = { 0.40, 0.85, 0.80 },
    pink      = { 0.95, 0.55, 0.75 },
    grey      = { 0.60, 0.60, 0.62 },
    xp        = { 0.58, 0.24, 0.82 },
    rested    = { 0.30, 0.50, 0.90 },
    track     = { 0.18, 0.18, 0.21, 1.00 },
}

T.palette = {
    T.colors.gold, T.colors.blue, T.colors.green, T.colors.purple,
    T.colors.orange, T.colors.teal, T.colors.pink, T.colors.grey,
}

T.activity = {
    adventure = { "Adventuring", T.colors.gold },
    dungeon   = { "Dungeons & raids", T.colors.purple },
    pvp       = { "Battlegrounds", T.colors.red },
    rest      = { "Cities & inns", T.colors.blue },
    travel    = { "In the air", T.colors.teal },
    dead      = { "Walking as a ghost", T.colors.grey },
    afk       = { "Away from keyboard", T.colors.dim },
}

T.icons = {
    dashboard = "Interface\\Icons\\INV_Misc_Book_07",
    journey = "Interface\\Icons\\INV_Misc_Map_01",
    world = "Interface\\Icons\\INV_Misc_Map02",
    statistics = "Interface\\Icons\\INV_Misc_Note_02",
    next = "Interface\\Icons\\Ability_Hunter_Pathfinding",
    wrapped = "Interface\\Icons\\INV_Misc_Gift_01",
    quests = "Interface\\Icons\\INV_Misc_Note_01",
    dungeons = "Interface\\Icons\\INV_Misc_Key_03",
    deaths = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01",
    kills = "Interface\\Icons\\Ability_Warrior_Cleave",
    zones = "Interface\\Icons\\INV_Misc_Map_01",
    taxi = "Interface\\Icons\\Ability_Mount_Gryphon_01",
    discoveries = "Interface\\Icons\\INV_Misc_Spyglass_02",
    gold = "Interface\\Icons\\INV_Misc_Coin_02",
    played = "Interface\\Icons\\INV_Misc_PocketWatch_01",
    bosses = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
    professions = "Interface\\Icons\\Trade_Engineering",
    rares = "Interface\\Icons\\Ability_Hunter_SniperShot",
    epics = "Interface\\Icons\\INV_Misc_Gem_01",
    ghost = "Interface\\Icons\\Spell_Shadow_RaiseDead",
}

---------------------------------------------------------------------------
-- Fonts
---------------------------------------------------------------------------
local locale = GetLocale and GetLocale() or "enUS"
local cjk = (locale == "koKR" or locale == "zhCN" or locale == "zhTW" or locale == "ruRU")

T.fontBody = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
T.fontTitle = T.fontBody
if not cjk and QuestFont_Huge and QuestFont_Huge.GetFont then
    local path = QuestFont_Huge:GetFont()
    if type(path) == "string" and path ~= "" then T.fontTitle = path end
end

function T.ApplyFont(fs, size, flags, kind)
    local path = (kind == "title") and T.fontTitle or T.fontBody
    fs:SetFont(path, size or 12, flags or "")
end

function T.RGB(c)
    return c[1], c[2], c[3], c[4] or 1
end

function T.Hex(c)
    return FJ.Hex(c[1], c[2], c[3])
end

function T.ClassRGB()
    local r, g, b = FJ.ClassColor()
    return r, g, b
end

-- Readable colour for a 0..1 ratio (red -> yellow -> green).
function T.RatioColor(ratio)
    ratio = FJ.Clamp(ratio or 0, 0, 1)
    if ratio < 0.5 then
        return 0.95, 0.35 + ratio * 1.1, 0.30
    end
    return 0.95 - (ratio - 0.5) * 1.1, 0.85, 0.30
end
