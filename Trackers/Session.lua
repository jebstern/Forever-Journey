-- Forever Journey: sessions, /played, heartbeat and time attribution.
local ADDON_NAME, FJ = ...
local Session = FJ:NewModule("Session")

local HEARTBEAT = 15        -- seconds between ticks
local RESUME_WINDOW = 300   -- a reload or quick relog continues the same session
local MIN_SESSION = 60      -- shorter sessions are not stored

local cur                   -- the active session table (also stored as FJ.db.session)
local ticker
local suppressPlayed = false
local lastOnTaxi = false

local function Now() return time() end

---------------------------------------------------------------------------
-- /played
---------------------------------------------------------------------------
function Session:OnInit()
    -- Hide the chat line produced by our own /played requests.
    if type(ChatFrame_DisplayTimePlayed) == "function" and not Session.hooked then
        Session.hooked = true
        local orig = ChatFrame_DisplayTimePlayed
        ChatFrame_DisplayTimePlayed = function(...)
            if suppressPlayed then
                suppressPlayed = false
                return
            end
            return orig(...)
        end
    end
end

function Session:RequestPlayed()
    if not RequestTimePlayed then return end
    if FJ.gdb.settings.suppressPlayedChat then
        suppressPlayed = true
        FJ:After(5, function() suppressPlayed = false end)
    end
    pcall(RequestTimePlayed)
end

function Session:OnTimePlayed(total, levelTime)
    if type(total) ~= "number" then return end
    local db = FJ.db
    local t = db.totals
    local now = Now()
    t.played = total
    t.playedAt = now
    t.levelPlayed = tonumber(levelTime) or 0

    -- Seed the current level's row from the server's own "time at this level".
    local lvl = UnitLevel("player")
    local L = db.levels[lvl]
    if L and L.seeded and t.levelPlayed > 0 then
        L.t = now - t.levelPlayed
        L.played = math.max(0, total - t.levelPlayed)
        L.seeded = nil
    end

    -- Played-days milestones. The first report only sets the baseline.
    local days = math.floor(total / 86400)
    local flags = db.flags
    if flags.playedDays == nil then
        flags.playedDays = days
    elseif days > flags.playedDays then
        flags.playedDays = days
        FJ.Timeline:Add("played", FJ.Timeline.PRIO.played, { a = days })
    end

    -- A level 1 character with under ten minutes played was created with the addon running.
    if db.flags.freshInstall and (db.char.firstSeenLevel or 99) == 1 and total < 600 then
        db.char.origin = "created"
        db.char.created = now - total
        for _, e in ipairs(db.timeline) do
            if e.k == "start" then e.a = "created" end
        end
    end
    FJ:NotifyDataChanged()
end

-- Best estimate of total /played right now.
function Session:GetPlayed()
    local t = FJ.db.totals
    if t.playedAt and t.playedAt > 0 then
        return t.played + (Now() - t.playedAt)
    end
    return t.tracked
end

function Session:GetLevelPlayed()
    local t = FJ.db.totals
    if t.playedAt and t.playedAt > 0 then
        return t.levelPlayed + (Now() - t.playedAt)
    end
    local L = FJ.db.levels[UnitLevel("player")]
    return L and L.time or 0
end

---------------------------------------------------------------------------
-- Session lifecycle
---------------------------------------------------------------------------
local function NewSession(now)
    local lvl = UnitLevel("player")
    return {
        s = now, last = now, d = 0,
        xp = 0, q = 0, k = 0, dth = 0, g = 0, disc = 0,
        money0 = GetMoney() or 0, gEnd = GetMoney() or 0,
        lvl0 = lvl, lvl1 = lvl,
    }
end

function Session:Finalize(s)
    if not s then return end
    local db = FJ.db
    if (s.d or 0) >= MIN_SESSION then
        FJ.PushCapped(db.sessions, {
            s = s.s, d = s.d, xp = s.xp, q = s.q, k = s.k, dth = s.dth,
            g = s.g, gEnd = s.gEnd, lvl0 = s.lvl0, lvl1 = s.lvl1, disc = s.disc,
        }, FJ.CAPS.sessions)
        db.totals.sessions = (db.totals.sessions or 0) + 1
    end
end

function Session:OnEnable(isLogin, isReload)
    local db = FJ.db
    local now = Now()
    local prev = db.session
    local lastFinished
    if prev and prev.last and (now - prev.last) <= RESUME_WINDOW then
        cur = prev
        cur.last = now
    else
        if prev then
            self:Finalize(prev)
            lastFinished = prev
        end
        cur = NewSession(now)
        db.session = cur
    end
    if isLogin and not isReload then
        lastFinished = lastFinished or db.sessions[#db.sessions]
        FJ:After(10, function() Session:PrintWelcome(lastFinished) end)
    end

    local lvl = UnitLevel("player")
    if not db.levels[lvl] then
        db.levels[lvl] = { t = now, seeded = true, time = 0, xp = 0, q = 0, k = 0, d = 0 }
    end

    lastOnTaxi = FJ.Bool(UnitOnTaxi("player"), false)
    if not ticker then
        ticker = FJ:NewTicker(HEARTBEAT, function() Session:Tick() end)
    end

    FJ:After(3, function() Session:RequestPlayed() end)

    if db.flags.freshInstall and not db.flags.startRecorded then
        FJ:After(6, function() Session:RecordStart() end)
    end
end

function Session:RecordStart()
    local db = FJ.db
    if db.flags.startRecorded then return end
    db.flags.startRecorded = true
    local played = db.totals.played or 0
    local origin = ((db.char.firstSeenLevel or 99) == 1 and played < 600) and "created" or "install"
    db.char.origin = origin
    if origin == "created" then db.char.created = Now() - played end
    local life = FJ.Lifetime
    FJ.Timeline:Add("start", FJ.Timeline.PRIO.start, {
        a = origin,
        b = life:Value("quests") or db.totals.questsBaseline or 0,
        c = life:Value("deaths"),
        d = life:Value("kills"),
    })
    if not FJ.gdb.settings.welcomeShown then
        FJ.gdb.settings.welcomeShown = true
        FJ.Print("Recording your journey from here on. Type |cffffffff/journey|r to open your story.")
    end
end

-- Chat recap of the previous session, plus "on this day" chapters from a week, a month or a year ago.
local ANNIVERSARIES = { { 7 * 86400, "A week ago today" }, { 30 * 86400, "A month ago today" }, { 365 * 86400, "A year ago today" } }
local RECAP_KINDS = { zone = true, city = true, level = true, maxlevel = true, dungeon_done = true, boss = true, prof = true, start = true, home = true, ride = true }

function Session:PrintWelcome(last)
    if not (FJ.gdb.settings.chatRecaps and FJ.db) then return end
    if last and last.s and (last.d or 0) >= 60 then
        local parts = { FJ.FormatDuration(last.d) }
        if (last.q or 0) > 0 then parts[#parts + 1] = last.q .. (last.q == 1 and " quest" or " quests") end
        if (last.k or 0) > 0 then parts[#parts + 1] = FJ.FormatNumber(last.k) .. " kills" end
        if (last.dth or 0) > 0 then parts[#parts + 1] = last.dth .. (last.dth == 1 and " death" or " deaths") end
        if (last.lvl1 or 0) > (last.lvl0 or 0) then parts[#parts + 1] = format("level %d to %d", last.lvl0, last.lvl1) end
        local when = FJ.RelativeDay(last.s + (last.d or 0))
        if when == "Today" or when == "Yesterday" then when = when:lower() end
        FJ.Print(format("Welcome back, %s. Last time (%s): %s.", FJ.playerName or "", when, table.concat(parts, ", ")))
    end
    local now = Now()
    local shown = 0
    for _, e in ipairs(FJ.db.timeline) do
        if RECAP_KINDS[e.k] and e.t then
            for _, a in ipairs(ANNIVERSARIES) do
                if math.abs((now - e.t) - a[1]) < 43200 then
                    local title = FJ.Timeline:Describe(e)
                    FJ.Print(a[2] .. ": " .. title .. ".")
                    shown = shown + 1
                    break
                end
            end
        end
        if shown >= 3 then break end
    end
end

function Session:OnLogout()
    if cur then
        cur.last = Now()
        cur.gEnd = GetMoney() or cur.gEnd
    end
    FJ.db.flags.freshInstall = nil
end

---------------------------------------------------------------------------
-- Heartbeat
---------------------------------------------------------------------------
-- Unit-state predicates can return secret booleans on Forever; an unreadable state counts as "no".
function Session:ClassifyActivity()
    local Bool = FJ.Bool
    if Bool(UnitIsAFK("player")) then return "afk" end
    if Bool(UnitIsDeadOrGhost("player")) then return "dead" end
    local inInst, instType = IsInInstance()
    if inInst then
        if instType == "party" or instType == "raid" then return "dungeon" end
        if instType == "pvp" or instType == "arena" then return "pvp" end
    end
    if Bool(UnitOnTaxi("player")) then return "travel" end
    if Bool(IsResting()) then return "rest" end
    return "adventure"
end

function Session:Tick()
    if not cur or not FJ.db then return end
    local now = Now()
    local dt = now - (cur.last or now)
    cur.last = now
    if dt <= 0 then return end
    if dt > 120 then dt = HEARTBEAT end -- clock jump or long hitch: count a single interval

    local db = FJ.db
    local t = db.totals
    t.tracked = t.tracked + dt
    cur.d = (cur.d or 0) + dt

    local act = self:ClassifyActivity()
    db.activity[act] = (db.activity[act] or 0) + dt
    if act == "dead" then t.ghostTime = t.ghostTime + dt end

    local L = db.levels[UnitLevel("player")]
    if L then L.time = (L.time or 0) + dt end

    if act == "dungeon" or act == "pvp" then
        if FJ.Dungeons then FJ.Dungeons:AddTime(dt, now) end
    elseif FJ.Zones then
        FJ.Zones:AddTime(dt)
    end

    -- If the taxi state is secret this tick, keep the previous state so a flight is not counted twice.
    local onTaxi = FJ.Bool(UnitOnTaxi("player"), lastOnTaxi)
    if onTaxi and not lastOnTaxi then
        t.flightsTaken = t.flightsTaken + 1
        if FJ.Zones and FJ.Zones.OnFlightStart then FJ.Zones:OnFlightStart() end
    elseif lastOnTaxi and not onTaxi then
        if FJ.Zones and FJ.Zones.OnFlightEnd then FJ.Zones:OnFlightEnd() end
    end
    lastOnTaxi = onTaxi

    -- Azeroth sunrises and sunsets (the sky follows realm time)
    if GetGameTime then
        local gh = GetGameTime()
        if type(gh) == "number" then
            if self.lastGameHour and gh ~= self.lastGameHour then
                if gh == 6 then t.sunrises = (t.sunrises or 0) + 1 end
                if gh == 18 then t.sunsets = (t.sunsets or 0) + 1 end
            end
            self.lastGameHour = gh
        end
    end

    -- When you play: by calendar day, hour of day and weekday.
    db.days = db.days or {}
    db.clock = db.clock or {}
    db.weekday = db.weekday or {}
    local dayKey = date("%Y%m%d", now)
    db.days[dayKey] = (db.days[dayKey] or 0) + dt
    local hour = tonumber(date("%H", now)) or 0
    db.clock[hour] = (db.clock[hour] or 0) + dt
    local wday = tonumber(date("%w", now)) or 0
    db.weekday[wday] = (db.weekday[wday] or 0) + dt

    if FJ.Zones and FJ.Zones.SampleDistance then FJ.Zones:SampleDistance(onTaxi) end

    FJ:SendMessage("FJ_TICK", dt)
end

---------------------------------------------------------------------------
-- Accessors
---------------------------------------------------------------------------
function Session:Current() return cur end

function Session:Duration()
    if not cur then return 0 end
    return (cur.d or 0) + math.max(0, Now() - (cur.last or Now()))
end

function Session:Bump(field, n)
    if cur then cur[field] = (cur[field] or 0) + (n or 1) end
end

FJ:RegisterEvent("TIME_PLAYED_MSG", function(_, total, level)
    Session:OnTimePlayed(total, level)
end)
