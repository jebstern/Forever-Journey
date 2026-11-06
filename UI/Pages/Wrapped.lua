-- Forever Journey: "Forever Wrapped" summary page.
local ADDON_NAME, FJ = ...
local T, W = FJ.Theme, FJ.Widgets

local PAD = 16
local GAP = 12
local FACT_H = 84
local MAX_FACTS = 14

local function Plural(n, one, many)
    return n == 1 and one or many
end

local function BigNumber(parent, w, h)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(w, h)
    f.value = W.Title(f, 26, "")
    f.value:SetPoint("TOP", 0, -8)
    f.value:SetJustifyH("CENTER")
    f.label = W.Text(f, 11, "", T.colors.muted)
    f.label:SetPoint("TOP", f.value, "BOTTOM", 0, -4)
    f.label:SetJustifyH("CENTER")
    function f:Set(v, l)
        self.value:SetText(v)
        self.label:SetText(l)
    end
    return f
end

local function Fact(parent, w, h)
    local f = W.Frame(parent, w, h, T.colors.panel, T.colors.borderDim)
    f.label = W.Text(f, 11, "", T.colors.muted)
    f.label:SetPoint("TOPLEFT", 14, -12)
    f.value = W.Title(f, 17, "")
    f.value:SetPoint("TOPLEFT", 14, -30)
    f.value:SetPoint("RIGHT", -14, 0)
    f.value:SetWordWrap(false)
    f.sub = W.Text(f, 11, "", T.colors.text)
    f.sub:SetPoint("TOPLEFT", 14, -54)
    f.sub:SetPoint("RIGHT", -14, 0)
    f.sub:SetWordWrap(false)
    function f:Set(label, value, sub)
        self.label:SetText(label or "")
        self.value:SetText(value or "")
        self.sub:SetText(sub or "")
        self.copyText = (label or "") .. ": " .. W.Plain(value or "") .. (sub and sub ~= "" and ("  (" .. sub .. ")") or "")
    end
    W.MakeCopyable(f, function(self) return self.copyText end, "Forever Wrapped")
    return f
end

-- Builds the list of { label, value, sub } facts from whatever data exists.
local function BuildFacts(s)
    local life = FJ.Lifetime
    local F = {}
    local function add(label, value, sub)
        if value ~= nil and value ~= "" then F[#F + 1] = { label, tostring(value), sub } end
    end
    local function n(key) return life:Value(key) or 0 end

    add("Most visited zone", s.mostVisited, s.mostVisitedTime and (FJ.FormatDuration(s.mostVisitedTime) .. " spent there"))
    add("Most dangerous zone", s.deadliest, s.deadliestDeaths and format("%d %s there", s.deadliestDeaths, Plural(s.deadliestDeaths, "death", "deaths")))

    local bosses = life:BossKills()
    if bosses[1] then
        add("Most conquered dungeon", bosses[1].dungeon, format("%s slain %d %s", bosses[1].name, bosses[1].n, Plural(bosses[1].n, "time", "times")))
    elseif s.favoriteDungeon then
        add("Favourite dungeon", s.favoriteDungeon, s.favoriteRuns and format("%d %s", s.favoriteRuns, Plural(s.favoriteRuns, "run", "runs")))
    end

    add("Your nemesis", s.nemesis, s.nemesisN and format("killed you %d %s", s.nemesisN, Plural(s.nemesisN, "time", "times")))

    local preyLabel = life:Label("favouritePrey")
    if preyLabel then
        add("Favourite prey", preyLabel, FJ.FormatNumber(n("favouritePrey")) .. " of them slain")
    elseif s.mostSlain then
        add("Most slain", s.mostSlain, s.mostSlainN and format("%d %s", s.mostSlainN, Plural(s.mostSlainN, "kill", "kills")))
    end

    local gold = s.lifeGold or ((s.goldEarned or 0) > 0 and s.goldEarned) or nil
    local peak = life:Value("goldPeak")
    add("Gold acquired", gold and FJ.FormatMoney(gold, true), peak and ("richest moment: " .. FJ.FormatMoney(peak, true)))

    if n("hearths") > 0 or (s.lifeFlights or 0) > 0 then
        add("Hearthed home", n("hearths") > 0 and (n("hearths") .. " " .. Plural(n("hearths"), "time", "times")) or "never",
            (s.lifeFlights or 0) > 0 and format("%d %s taken", s.lifeFlights, Plural(s.lifeFlights, "flight", "flights")) or nil)
    end

    local potions = n("healthPotions") + n("manaPotions") + n("elixirs") + n("flasks")
    if potions > 0 or n("bandages") > 0 then
        add("Potions and elixirs drunk", potions > 0 and FJ.FormatNumber(potions) or "none",
            n("bandages") > 0 and (n("bandages") .. " bandages used") or (n("food") > 0 and (n("food") .. " meals eaten") or nil))
    end

    local falls, drown, fire, fatigue = n("deathsFalling"), n("deathsDrowning"), n("deathsFire"), n("deathsFatigue")
    local worldDeaths = falls + drown + fire + fatigue
    if worldDeaths > 0 then
        local parts = {}
        if falls > 0 then parts[#parts + 1] = falls .. " falling" end
        if drown > 0 then parts[#parts + 1] = drown .. " drowning" end
        if fire > 0 then parts[#parts + 1] = fire .. " in fire or lava" end
        if fatigue > 0 then parts[#parts + 1] = fatigue .. " from fatigue" end
        add("Deaths the world itself caused", tostring(worldDeaths), table.concat(parts, ", "))
    end
    if n("deathsHogger") > 0 then
        add("Hogger", n("deathsHogger") .. " " .. Plural(n("deathsHogger"), "death", "deaths"), "a Westfall classic")
    end
    if s.ghostTime and s.ghostTime > 0 then
        add("Time spent as a ghost", FJ.FormatDuration(s.ghostTime), "walking back to your body")
    end

    local won, lost = n("duelsWon"), n("duelsLost")
    if won + lost > 0 then add("Duels", format("%d won, %d lost", won, lost), nil) end
    if n("honorableKills") > 0 then
        add("Honorable kills", FJ.FormatNumber(n("honorableKills")), n("bgPlayed") > 0 and format("%d battlegrounds, %d won", n("bgPlayed"), n("bgWon")) or nil)
    end

    local social = { { "hugs", "hugs" }, { "cheers", "cheers" }, { "waves", "waves" }, { "lols", "laughs" }, { "facepalms", "facepalms" }, { "violin", "tiny violins" } }
    local socialParts, socialTotal = {}, 0
    for _, e in ipairs(social) do
        local v = n(e[1])
        if v > 0 then
            socialParts[#socialParts + 1] = v .. " " .. e[2]
            socialTotal = socialTotal + v
        end
    end
    if socialTotal > 0 then add("Emotes that mattered", FJ.FormatNumber(socialTotal), table.concat(socialParts, ", ")) end

    local epics = (n("epicsAcquired") > 0 and n("epicsAcquired")) or s.epics or 0
    if epics > 0 or n("legendaries") > 0 then
        add("Epic items", tostring(epics), n("legendaries") > 0 and (n("legendaries") .. " legendary") or nil)
    end
    local emotes = FJ.Social:EmoteList()
    if emotes[1] then
        local total = 0
        for _, e in ipairs(emotes) do total = total + e.value end
        add("Favourite emote", emotes[1].label, format("%d %s, %s emotes in all", emotes[1].value, Plural(emotes[1].value, "time", "times"), FJ.FormatNumber(total)))
    end
    local t = FJ.db.totals
    if (t.campCount or 0) > 0 then
        add("Nights by the campfire", tostring(t.campCount), (t.campTime or 0) > 0 and (FJ.FormatDuration(t.campTime) .. " camping in total") or nil)
    end
    if (t.sitTime or 0) >= 60 then
        add("Time spent sitting", FJ.FormatDuration(t.sitTime), format("sat down %d %s", t.sitCount or 0, (t.sitCount or 0) == 1 and "time" or "times"))
    end
    if (t.distance or 0) > 1000 then
        add("Distance on foot and mount", format("%.1f km", t.distance * 0.0009144), (t.jumps or 0) > 0 and format("and %s jumps along the way", FJ.FormatNumber(t.jumps)) or "at least, as the crow flies")
    elseif (t.jumps or 0) > 0 then
        add("Jumps", FJ.FormatNumber(t.jumps), "since recording began")
    end
    local pace = FJ.Stats:LevelPace()
    if pace.fastest then
        add("Fastest level", format("Level %d", pace.fastest.level), "in " .. FJ.FormatDuration(pace.fastest.time) .. (pace.average and (", average " .. FJ.FormatDuration(pace.average)) or ""))
    end
    local daysInfo = FJ.Stats:Days()
    if daysInfo.longest >= 2 then
        add("Longest run of days", format("%d days in a row", daysInfo.longest), daysInfo.count .. " days played in all")
    end
    local companion = FJ.Companions:List(1)[1]
    if companion and companion.time >= 600 then
        local _, _, _, hex = FJ.ClassColor(companion.class)
        add("Favourite companion", "|c" .. hex .. companion.name .. "|r", format("%s together over %d %s", FJ.FormatDuration(companion.time), companion.n, Plural(companion.n, "outing", "outings")))
    end
    local worn = FJ.Gear:LongestWorn()
    if worn and worn.link and worn.worn >= 3600 then
        add("Worn the longest", worn.link, FJ.FormatDuration(worn.worn) .. (worn.current and ", and still on" or ""))
    end
    local home, homes = FJ.Gear:CurrentHome()
    if home and homes >= 2 then
        add("Places called home", tostring(homes), "currently " .. home)
    end
    local badgesEarned, badgesTotal = FJ.Badges:Count()
    if badgesEarned > 0 then
        local earned = FJ.Badges:List()
        local last = earned[#earned]
        add("Badges earned", format("%d of %d", badgesEarned, badgesTotal), last and ("latest: " .. last.def.name) or nil)
    end
    if FJ.AccountSummary then
        local acct = FJ.AccountSummary()
        if acct.chars > 1 then
            add("Across all your characters", format("%d characters", acct.chars),
                format("%s played, %s quests, %s deaths", FJ.FormatDuration(acct.played), FJ.FormatNumber(acct.quests), FJ.FormatNumber(acct.deaths)))
        end
    end
    if (s.rares or 0) > 0 then add("Rare creatures met", tostring(s.rares), nil) end
    if n("factions") > 0 then add("Factions encountered", tostring(n("factions")), nil) end
    if (s.flightPaths or 0) > 0 then add("Flight paths known", tostring(s.flightPaths), nil) end

    while #F > MAX_FACTS do F[#F] = nil end
    return F
end

local function Build(def, page)
    local width = FJ.UI:ContentSize()
    local inner = width - PAD * 2 - 10
    page.inner = inner

    page.scroll = W.ScrollArea(page)
    page.scroll:SetPoint("TOPLEFT", PAD, -PAD)
    page.scroll:SetPoint("BOTTOMRIGHT", -PAD - 10, PAD)
    local content = page.scroll.content

    local hero = W.Frame(content, inner, 124, T.colors.panel, T.colors.border)
    hero:SetPoint("TOPLEFT")
    page.hero = hero
    hero.kicker = W.Text(hero, 11, "F O R E V E R   W R A P P E D", T.colors.goldDim)
    hero.kicker:SetPoint("TOP", 0, -16)
    hero.kicker:SetJustifyH("CENTER")
    hero.title = W.Title(hero, 28, "")
    hero.title:SetPoint("TOP", 0, -34)
    hero.title:SetJustifyH("CENTER")
    hero.sub = W.Text(hero, 12, "", T.colors.muted)
    hero.sub:SetPoint("TOP", 0, -74)
    hero.sub:SetJustifyH("CENTER")
    hero.played = W.Text(hero, 13, "", T.colors.text)
    hero.played:SetPoint("TOP", 0, -94)
    hero.played:SetJustifyH("CENTER")

    local numbers = W.Frame(content, inner, 158, T.colors.panel, T.colors.borderDim)
    numbers:SetPoint("TOPLEFT", 0, -(124 + GAP))
    page.numbers = {}
    local nw = inner / 3
    for i = 1, 6 do
        local b = BigNumber(numbers, nw, 72)
        local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
        b:SetPoint("TOPLEFT", col * nw, -(6 + row * 74))
        page.numbers[i] = b
    end

    page.factsTop = 124 + GAP + 158 + GAP
    page.facts = W.Pool(function() return Fact(content, (inner - GAP) / 2, FACT_H) end)

    page.footer = W.Text(content, 10, "", T.colors.dim)
    page.footer:SetWidth(inner)
    page.footer:SetJustifyH("CENTER")

    page.copyAll = W.FlatButton(hero, "Copy", 60, 20, function()
        if page.allText then W.ShowCopyBox(page.allText, "Forever Wrapped") end
    end)
    page.copyAll:SetPoint("TOPRIGHT", -10, -10)
end

local function Refresh(def, page)
    local s = FJ.Stats:Summary()
    local life = FJ.Lifetime
    local hero = page.hero
    local r, g, b = FJ.ClassColor()
    hero.title:SetText((FJ.playerName or "Your") .. "'s Forever Journey")
    hero.title:SetTextColor(r, g, b)
    hero.sub:SetText(format("Level %d %s %s", UnitLevel("player") or 1, FJ.playerRace or "", FJ.playerClass or ""))
    hero.played:SetText(FJ.FormatDuration(s.played, "long") .. " adventuring")

    local num = page.numbers
    local deaths, kills = s.lifeDeaths or s.deaths, s.lifeKills or s.kills
    local conquered = life:DungeonsConquered()
    if conquered == 0 then conquered = s.dungeonsCompleted end
    num[1]:Set(FJ.FormatNumber(s.quests), Plural(s.quests, "quest completed", "quests completed"))
    num[2]:Set(FJ.FormatNumber(conquered), Plural(conquered, "dungeon conquered", "dungeons conquered"))
    num[3]:Set(FJ.FormatNumber(deaths), Plural(deaths, "death", "deaths"))
    num[4]:Set(FJ.FormatNumber(kills), Plural(kills, "enemy defeated", "enemies defeated"))
    num[5]:Set(FJ.FormatNumber(s.zones), Plural(s.zones, "zone explored", "zones explored"))
    num[6]:Set(FJ.FormatNumber(s.discoveries), Plural(s.discoveries, "place discovered", "places discovered"))

    page.facts:ReleaseAll()
    local facts = BuildFacts(s)
    local fw = (page.inner - GAP) / 2
    local content = page.scroll.content
    for i, fact in ipairs(facts) do
        local f = page.facts:Acquire()
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        f:SetPoint("TOPLEFT", content, "TOPLEFT", col * (fw + GAP), -(page.factsTop + row * (FACT_H + GAP)))
        f:Set(fact[1], fact[2], fact[3])
    end
    local all = { (FJ.playerName or "Your") .. "'s Forever Journey - " .. hero.sub:GetText(), hero.played:GetText(), "" }
    for i = 1, 6 do all[#all + 1] = W.Plain(num[i].value:GetText() or "") .. " " .. (num[i].label:GetText() or "") end
    all[#all + 1] = ""
    for _, fact in ipairs(facts) do
        all[#all + 1] = fact[1] .. ": " .. W.Plain(fact[2]) .. (fact[3] and ("  (" .. fact[3] .. ")") or "")
    end
    page.allText = table.concat(all, "\n")

    local rows = math.ceil(#facts / 2)
    local footerY = page.factsTop + rows * (FACT_H + GAP) + 6
    page.footer:ClearAllPoints()
    page.footer:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -footerY)

    local start, created = FJ.Stats:JourneyStart()
    page.footer:SetText((created and "Recorded from the very first step on " or "Recorded by Forever Journey since ")
        .. FJ.FormatDate(start) .. ". Lifetime numbers come from the game's own statistics; the rest was observed while recording.")
    page.scroll:SetContentHeight(footerY + 40)
end

FJ.UI:RegisterPage("wrapped", {
    title = "Wrapped", icon = T.icons.wrapped, order = 9, footer = true,
    build = Build, refresh = Refresh,
})
