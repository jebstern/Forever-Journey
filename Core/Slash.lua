-- Forever Journey: slash commands and diagnostics.
local ADDON_NAME, FJ = ...

SLASH_FOREVERJOURNEY1 = "/journey"
SLASH_FOREVERJOURNEY2 = "/fjourney"
SLASH_FOREVERJOURNEY3 = "/fjy"

StaticPopupDialogs["FOREVERJOURNEY_RESET"] = {
    text = "Erase this character's Forever Journey data? This cannot be undone and the interface will reload.",
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        FJ:ResetCharacterData()
        ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function yes(v) return v and "|cff60ff60yes|r" or "|cffff6060no|r" end

-- Prints what this client exposes, so unknowns about Forever can be settled in one paste.
local function Probe()
    local P = FJ.Print
    P("Probe for build " .. FJ.build .. " (interface " .. FJ.toc .. ")")
    P("  Forever client: " .. yes(FJ.IsForever) .. "   WOW_PROJECT_ID: " .. tostring(WOW_PROJECT_ID) .. "   combat log restricted: " .. yes(FJ.RestrictedCombatLog))
    do
        local okQ, ids = pcall(function() return C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs and C_QuestLog.GetAllCompletedQuestIDs() end)
        P("  Completed quest IDs from the API: " .. ((okQ and type(ids) == "table") and tostring(#ids) or "n/a"))
        local L = FJ.db.lifetime
        if L then
            P(format("  Lifetime statistics parsed: deaths=%s quests=%s kills=%s gold acquired=%s flights=%s hearths=%s dungeons entered=%s final bosses=%d",
                tostring(L.deaths), tostring(L.quests), tostring(L.kills), L.goldAcquired and FJ.FormatMoney(L.goldAcquired) or "nil",
                tostring(L.flights), tostring(L.hearths), tostring(L.dungeonsEntered), #FJ.Lifetime:BossKills()))
        end
        P("  Statistics catalogue API: " .. yes(_G.GetStatisticsCategoryList ~= nil) .. "  (use /journey statdump to save the full list)")
    end
    P("  canaccessvalue: " .. yes(_G.canaccessvalue ~= nil) .. "   issecretvalue: " .. yes(_G.issecretvalue ~= nil) .. "   C_Secrets: " .. yes(_G.C_Secrets ~= nil))
    local c = FJ.Combat:ProbeReport()
    P("  Combat log registered: " .. yes(c.cleuRegistered) .. (FJ.RestrictedCombatLog and "  (restricted on this client, chat fallbacks in use)" or ""))
    P(format("  Combat log events seen: %d, of which secret: %d", c.cleuEvents or 0, c.cleuSecret or 0))
    P("  C_QuestLog.GetAllCompletedQuestIDs: " .. yes(C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs ~= nil) .. "   GetQuestsCompleted: " .. yes(_G.GetQuestsCompleted ~= nil))
    P("  C_QuestLog.GetInfo: " .. yes(C_QuestLog and C_QuestLog.GetInfo ~= nil) .. "   ReadyForTurnIn: " .. yes(C_QuestLog and C_QuestLog.ReadyForTurnIn ~= nil))
    P("  GetProfessions: " .. yes(_G.GetProfessions ~= nil) .. "   GetSkillLineInfo: " .. yes(_G.GetSkillLineInfo ~= nil))
    P("  C_MapExplorationInfo: " .. yes(_G.C_MapExplorationInfo ~= nil) .. "   GetMapChildrenInfo: " .. yes(C_Map and C_Map.GetMapChildrenInfo ~= nil))
    P("  CreateLine: " .. yes(UIParent.CreateLine ~= nil) .. "   ChatFrame_DisplayTimePlayed: " .. yes(_G.ChatFrame_DisplayTimePlayed ~= nil))
    P("  TaxiNodeGetType: " .. yes(_G.TaxiNodeGetType ~= nil) .. "   GetXPExhaustion: " .. yes(_G.GetXPExhaustion ~= nil))
    local mapID, name, inst = FJ.Zones:GetCurrent()
    P(format("  Zone: %s (%s)%s", tostring(name), tostring(mapID), inst and " [instance]" or ""))
    local ok, best = pcall(C_Map.GetBestMapForUnit, "player")
    if ok and best then
        local info = FJ.API.MapInfo(best)
        P(format("  Best map: %d  type %s  parent %s", best, tostring(info and info.mapType), tostring(info and info.parentMapID)))
    end
    local explored, total = FJ.Zones:Exploration(mapID)
    P("  Exploration here: " .. (explored and (explored .. " / " .. total) or "no data"))
    if GetStatistic then
        local stats = { { 60, "deaths" }, { 98, "quests" }, { 1197, "kills" }, { 334, "gold" }, { 349, "flights" } }
        local parts = {}
        for _, s in ipairs(stats) do
            local okS, v = pcall(GetStatistic, s[1])
            parts[#parts + 1] = s[2] .. "=" .. (okS and tostring(v) or "err")
        end
        P("  GetStatistic: " .. table.concat(parts, "  "))
    else
        P("  GetStatistic: not available")
    end
    local t = FJ.db.totals
    P(format("  Recorded: %s tracked, %d quests, %d kills, %d deaths, %d timeline entries", FJ.FormatDuration(t.tracked), t.quests, t.kills, t.deaths, #FJ.db.timeline))
end

local function Help()
    local function head(text) print("|cffffd200" .. text .. "|r") end
    local function line(cmd, desc)
        print("  |cffffffff/journey" .. (cmd ~= "" and (" " .. cmd) or "") .. "|r - " .. desc)
    end
    FJ.Print("Commands. Every option is also on the Settings page, behind the cog at the top of the window.")
    head("Open")
    line("", "open or close the journal")
    line("settings", "all options in one place")
    line("dashboard | journey | world | stats | almanac | characters | next | wrapped", "open a page")
    line("help", "this list")
    head("Options")
    line("minimap", "show or hide the minimap button")
    line("scale <0.6-1.5>", "window scale")
    line("toasts", "chapter banners on or off")
    line("banner", "zone memory banners on or off")
    line("runrecap", "dungeon run recaps on or off")
    line("deathline", "the line after a death on or off")
    line("toast", "show a test banner so you can drag it into place")
    line("bannerscale <0.5-2>", "banner scale")
    line("recaps", "level-up and welcome-back recaps in chat on or off")
    line("deaths", "single deaths on the timeline on or off")
    line("map", "World Map tombstones and footprints on or off")
    line("played", "hide or show the journal's own /played checks in chat")
    line("campbuff <name>", "the buff that counts as camping")
    head("Tools")
    line("badges", "list earned and remaining badges")
    line("buffs", "list your current buffs (to find the camping buff name)")
    line("zonequests", "status of the Questie quest totals per zone")
    line("probe", "print client capabilities for a bug report")
    line("statdump", "save the game's full statistics list to SavedVariables")
    line("reset", "erase this character's data")
end

SlashCmdList.FOREVERJOURNEY = function(msg)
    local raw = FJ.Trim(msg or "")
    msg = raw:lower()
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    if cmd == "" or cmd == "show" or cmd == "toggle" then
        FJ.UI:Toggle()
    elseif cmd == "help" or cmd == "?" or cmd == "commands" then
        Help()
    elseif cmd == "settings" or cmd == "options" or cmd == "config" then
        FJ.UI:Show("settings")
    elseif cmd == "wrapped" then
        FJ.UI:Toggle("wrapped")
    elseif cmd == "journey" or cmd == "timeline" then
        FJ.UI:Show("journey")
    elseif cmd == "world" or cmd == "zones" then
        FJ.UI:Show("world")
    elseif cmd == "stats" or cmd == "statistics" then
        FJ.UI:Show("statistics")
    elseif cmd == "next" or cmd == "goals" then
        FJ.UI:Show("next")
    elseif cmd == "dashboard" then
        FJ.UI:Show("dashboard")
    elseif cmd == "minimap" then
        local show = FJ.gdb.settings.minimap.hide
        FJ.Minimap:SetShown(show)
        FJ.Print(show and "Minimap button shown." or "Minimap button hidden.")
    elseif cmd == "scale" then
        local v = tonumber(rest)
        if v and v >= 0.6 and v <= 1.5 then
            FJ.UI:SetScale(v)
            FJ.Print("Window scale set to " .. v)
        else
            FJ.Print("Usage: /journey scale 0.6-1.5")
        end
    elseif cmd == "deaths" then
        local s = FJ.gdb.settings
        s.showDeathsOnTimeline = not s.showDeathsOnTimeline
        FJ.Print(s.showDeathsOnTimeline and "Single deaths are shown on the timeline." or "Single deaths are hidden on the timeline (milestones stay).")
        FJ:NotifyDataChanged()
    elseif cmd == "played" then
        local s = FJ.gdb.settings
        s.suppressPlayedChat = not s.suppressPlayedChat
        FJ.Print(s.suppressPlayedChat and "Our own /played requests stay out of chat." or "Our /played requests will show in chat.")
    elseif cmd == "reset" then
        StaticPopup_Show("FOREVERJOURNEY_RESET")
    elseif cmd == "probe" then
        Probe()
    elseif cmd == "statdump" then
        FJ.Lifetime:Dump()
    elseif cmd == "buffs" then
        FJ.Social:PrintBuffs()
    elseif cmd == "map" then
        local s = FJ.gdb.settings
        local on = not (s.mapDeaths and s.mapFootprints)
        s.mapDeaths, s.mapFootprints = on, on
        FJ.Print(on and "World Map tombstones and footprints shown." or "World Map tombstones and footprints hidden.")
        if FJ.MapPins and FJ.MapPins.Refresh then FJ.MapPins:Refresh() end
    elseif cmd == "recaps" then
        local s = FJ.gdb.settings
        s.chatRecaps = not s.chatRecaps
        FJ.Print(s.chatRecaps and "Level-up and welcome-back recaps in chat are on." or "Chat recaps are off.")
    elseif cmd == "toasts" then
        local s = FJ.gdb.settings
        s.toasts = not s.toasts
        FJ.Print(s.toasts and "Chapter banners are on." or "Chapter banners are off.")
    elseif cmd == "toast" then
        FJ.Toast:Test()
    elseif cmd == "bannerscale" or cmd == "toastscale" then
        local v = tonumber(rest)
        if v and v >= 0.5 and v <= 2 then
            FJ.Toast:SetScale(v)
            FJ.Print("Banner scale set to " .. v)
        else
            FJ.Print("Usage: /journey bannerscale 0.5-2 (now " .. (FJ.gdb.settings.toastScale or 1) .. ")")
        end
    elseif cmd == "banner" then
        local s = FJ.gdb.settings
        s.zoneBanner = not s.zoneBanner
        FJ.Print(s.zoneBanner and "Zone memory banners are on." or "Zone memory banners are off.")
    elseif cmd == "deathline" then
        local s = FJ.gdb.settings
        s.deathLine = not s.deathLine
        FJ.Print(s.deathLine and "The line after a death is on." or "The line after a death is off.")
    elseif cmd == "runrecap" then
        local s = FJ.gdb.settings
        s.runRecap = not s.runRecap
        FJ.Print(s.runRecap and "Dungeon run recaps are on." or "Dungeon run recaps are off.")
    elseif cmd == "badges" then
        local earned, remaining = FJ.Badges:List()
        FJ.Print(format("Badges: %d of %d earned.", #earned, #earned + #remaining))
        for _, e in ipairs(earned) do FJ.Print(format("  |cff60ff60%s|r - %s (%s)", e.def.name, e.def.desc, FJ.FormatDate(e.t))) end
        for _, def in ipairs(remaining) do FJ.Print(format("  |cff8a8a8a%s - %s|r", def.name, def.desc)) end
    elseif cmd == "characters" or cmd == "alts" then
        FJ.UI:Show("characters")
    elseif cmd == "almanac" then
        FJ.UI:Show("almanac")
    elseif cmd == "zonequests" then
        local state = FJ.ZoneQuests:State()
        local total, done, unob, zones, complete = FJ.ZoneQuests:Summary()
        FJ.Print(format("Zone quest data: %s. %d quests in %d zones, %d done, %d unobtainable, %d zones complete.", state, total or 0, zones or 0, done or 0, unob or 0, complete or 0))
        if state == "idle" or state == "unavailable" then FJ.ZoneQuests:Start() end
    elseif cmd == "campbuff" then
        local name = FJ.Trim(raw:match("^%S+%s+(.-)$") or "")
        if name == "" then
            FJ.Print("Tracking the camping buff named \"" .. FJ.Social:CampBuffName() .. "\". Usage: /journey campbuff <exact buff name>")
        else
            FJ.gdb.settings.campBuff = name
            FJ.gdb.settings.campSpellID = nil
            FJ.Print("Camping buff set to \"" .. name .. "\".")
            FJ.Social:CheckCamp(true)
        end
    elseif cmd == "debug" then
        FJ.debug = not FJ.debug
        FJ.Print("Debug output " .. (FJ.debug and "on" or "off"))
    else
        FJ.Print("Unknown command \"" .. cmd .. "\".")
        Help()
    end
    -- A toggle typed while the Settings page is open should show up there at once.
    if FJ.UI:IsShown() and FJ.UI.current == "settings" then FJ.UI:Refresh() end
end
