-- Forever Journey: the journal speaking up at the right moment. Chapter toasts, zone memory
-- banners, dungeon run recaps and the quiet line after a death. All togglable.
local ADDON_NAME, FJ = ...
local Moments = FJ:NewModule("Moments")

local SKIP_TOAST = { death = true, taxi = true, start = true }
local lastBanner = {}

local function RelativeLower(t)
    local r = FJ.RelativeDay(t)
    if r == "Today" or r == "Yesterday" then r = r:lower() end
    return r
end

function Moments:ChapterToast(e)
    local s = FJ.gdb.settings
    if not s.toasts or SKIP_TOAST[e.k] or (e.p or 0) < (s.toastMinPriority or 45) then return end
    if e.k == "badge" and FJ.Badges and FJ.Badges.quiet then return end
    local title, sub, icon, color = FJ.Timeline:Describe(e)
    local kicker = "NEW CHAPTER"
    if e.k == "badge" then kicker = "BADGE EARNED" elseif e.k == "pb" then kicker = "PERSONAL BEST" elseif e.k == "level" or e.k == "maxlevel" then kicker = "LEVEL UP" end
    FJ.Toast:Show({ kicker = kicker, title = title, text = sub, icon = icon, color = color })
end

function Moments:ZoneBanner(mapID, name, isInstance)
    if isInstance or not FJ.gdb.settings.zoneBanner or not name then return end
    local z = FJ.db.zones[mapID]
    if not z or (z.visits or 0) < 2 then return end -- a first visit already gets a chapter toast
    local now = time()
    if lastBanner[mapID] and now - lastBanner[mapID] < 600 then return end
    if z.prevLast and now - z.prevLast < 600 then return end -- just zone-hopping at a border
    lastBanner[mapID] = now
    local parts = {}
    if (z.time or 0) >= 60 then parts[#parts + 1] = FJ.FormatDuration(z.time) .. " here" end
    local pct, total, done, unob = FJ.ZoneQuests:Percent(mapID)
    if pct then
        parts[#parts + 1] = format("%d of %d quests", done, total - (unob or 0))
    elseif (z.q or 0) > 0 then
        parts[#parts + 1] = z.q .. (z.q == 1 and " quest" or " quests") .. " handed in"
    end
    if (z.d or 0) > 0 then parts[#parts + 1] = z.d .. (z.d == 1 and " death" or " deaths") end
    if #parts == 0 then return end
    FJ.Toast:Show({
        kicker = "BACK IN " .. name:upper(),
        title = table.concat(parts, "  -  "),
        text = z.prevLast and ("Last visit " .. RelativeLower(z.prevLast) .. ", first at level " .. tostring(z.lvl or 0)) or nil,
        icon = FJ.Theme.icons.zones, color = "ff7fd4ff", sound = false, duration = 5,
    })
end

function Moments:RunRecap(run, valid)
    if not run or not valid or not FJ.gdb.settings.runRecap then return end
    local parts = { FJ.FormatDuration(run.time or 0) }
    if (run.bosses or 0) > 0 then parts[#parts + 1] = run.bosses .. (run.bosses == 1 and " boss" or " bosses") end
    if (run.kills or 0) > 0 then parts[#parts + 1] = FJ.FormatNumber(run.kills) .. " kills" end
    parts[#parts + 1] = (run.deaths or 0) .. ((run.deaths or 0) == 1 and " death" or " deaths")
    local names = {}
    for n in pairs(run.party or {}) do names[#names + 1] = n:match("^([^%-]+)") or n end
    table.sort(names)
    local with = (#names > 0) and ("with " .. table.concat(names, ", ")) or "solo"
    local tail = run.pb and " New personal best!" or (run.completed and " Cleared." or "")
    FJ.Print(format("%s: %s, %s.%s", run.name or "Dungeon", table.concat(parts, ", "), with, tail))
    FJ.Toast:Show({
        kicker = run.pb and "PERSONAL BEST" or (run.completed and "DUNGEON CLEARED" or "RUN OVER"),
        title = (run.name or "Dungeon") .. "  -  " .. FJ.FormatDuration(run.time or 0),
        text = table.concat(parts, ", ", 2) .. ", " .. with,
        icon = FJ.Theme.icons.dungeons, color = "ffb48cff", duration = 6,
    })
end

function Moments:DeathLine(info)
    if not FJ.gdb.settings.deathLine or not info then return end
    local parts = {}
    if (info.streak or 0) >= 300 then parts[#parts + 1] = "Deathless streak ended at " .. FJ.FormatDuration(info.streak) end
    if info.killer and (info.killerCount or 0) > 1 then
        parts[#parts + 1] = format("%s has now killed you %d times", info.killer, info.killerCount)
    end
    if info.zoneDeaths and info.zoneName and info.zoneDeaths > 1 then
        parts[#parts + 1] = format("%s death in %s", FJ.Ordinal(info.zoneDeaths), info.zoneName)
    end
    if #parts == 0 then return end
    FJ.Print(table.concat(parts, ". ") .. ".")
end

function Moments:OnEnable()
    FJ:RegisterMessage("FJ_TIMELINE_ADDED", function(_, e) Moments:ChapterToast(e) end)
    FJ:RegisterMessage("FJ_ZONE_CHANGED", function(_, mapID, name, isInstance) Moments:ZoneBanner(mapID, name, isInstance) end)
    FJ:RegisterMessage("FJ_RUN_ENDED", function(_, run, valid) Moments:RunRecap(run, valid) end)
    FJ:RegisterMessage("FJ_PLAYER_DIED", function(_, info) Moments:DeathLine(info) end)
end
