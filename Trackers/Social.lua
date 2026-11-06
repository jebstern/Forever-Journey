-- Forever Journey: emotes, sitting and camping.
-- Emotes come from a hook on DoEmote (every slash emote passes through it) so the exact
-- token is known. Camping is detected from the buff itself appearing on the player.
-- Sitting/kneeling/sleeping starts with the emote and ends with anything that makes a
-- character stand: moving, jumping, casting, combat, NPC windows, death, loading screens.
local ADDON_NAME, FJ = ...
local Social = FJ:NewModule("Social")

local CUSTOM = "EMOTE" -- bucket for free-text /e lines
local campActive, campStart = false, 0
local lastAuraCheck = 0

---------------------------------------------------------------------------
-- Poses (sit / kneel / sleep)
---------------------------------------------------------------------------
local POSES = { SIT = "sitTime", KNEEL = "kneelTime", SLEEP = "sleepTime" }
-- Animated emotes that make a sitting character stand up first.
local STANDING_EMOTES = {
    STAND = true, DANCE = true, WAVE = true, BOW = true, CHEER = true, LAUGH = true, POINT = true,
    SALUTE = true, ROAR = true, FLEX = true, KISS = true, CRY = true, APPLAUD = true, CLAP = true,
    CHICKEN = true, TALK = true, SHY = true, RUDE = true, BEG = true, TRAIN = true, KNEEL = false,
    EAT = true, DRINK = true, SHRUG = true, NO = true, YES = true, GREET = true, HELLO = true,
}
local pose, poseStart = nil, 0

local function EndPose()
    if not pose then return end
    local dur = math.max(0, GetTime() - poseStart)
    local t = FJ.db.totals
    local key = POSES[pose]
    t[key] = (t[key] or 0) + dur
    if pose == "SIT" and dur > (t.sitLongest or 0) then t.sitLongest = dur end
    pose = nil
    FJ:NotifyDataChanged()
end

local function StartPose(p)
    if pose == p then return end
    if pose then EndPose() end
    pose, poseStart = p, GetTime()
    local t = FJ.db.totals
    if p == "SIT" then t.sitCount = (t.sitCount or 0) + 1 end
end

function Social:CurrentPose()
    if not pose then return nil, 0 end
    return pose, GetTime() - poseStart
end

-- The sit/stand key toggles; we cannot read the real stance, so mirror the toggle.
local function OnSitStandKey()
    if pose then EndPose() else StartPose("SIT") end
end

---------------------------------------------------------------------------
-- Emotes
---------------------------------------------------------------------------
function Social:OnEmote(token)
    if type(token) ~= "string" or not FJ.canaccess(token) or token == "" then return end
    token = token:upper()
    local db = FJ.db
    db.emotes = db.emotes or {}
    db.emotes[token] = (db.emotes[token] or 0) + 1
    db.totals.emotes = (db.totals.emotes or 0) + 1
    db.lastEmote = token
    if POSES[token] then
        StartPose(token)
    elseif STANDING_EMOTES[token] then
        EndPose()
    end
    FJ:NotifyDataChanged()
end

-- Display name for a token: "DANCE" -> "/dance", custom text -> "/e custom".
function Social.EmoteName(token)
    if token == CUSTOM then return "/e custom" end
    return "/" .. tostring(token):lower()
end

-- Statistics the game keeps for life, keyed by emote token.
local LIFETIME_EMOTES = { HUG = "hugs", CHEER = "cheers", WAVE = "waves", LAUGH = "lols", FACEPALM = "facepalms", VIOLIN = "violin" }

-- Sorted { token, label, value } list; lifetime statistics win where they are larger.
function Social:EmoteList()
    local db = FJ.db
    local merged = {}
    for token, n in pairs(db.emotes or {}) do merged[token] = n end
    for token, key in pairs(LIFETIME_EMOTES) do
        local life = FJ.Lifetime:Value(key)
        if life and life > (merged[token] or 0) then merged[token] = life end
    end
    local out = {}
    for token, n in pairs(merged) do
        if n > 0 then out[#out + 1] = { token = token, label = Social.EmoteName(token), value = n } end
    end
    table.sort(out, function(a, b)
        if a.value ~= b.value then return a.value > b.value end
        return a.token < b.token
    end)
    return out
end

function Social:EmoteCount(token)
    return (FJ.db.emotes and FJ.db.emotes[token]) or 0
end

---------------------------------------------------------------------------
-- Camping
---------------------------------------------------------------------------
function Social:CampBuffName()
    return FJ.gdb.settings.campBuff or "Camping"
end

-- true/false, or nil when the client will not let us look right now.
function Social:PlayerHasCampBuff()
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        local ok, secret = pcall(C_Secrets.ShouldAurasBeSecret)
        if ok and secret then return nil end
    end
    local wanted = self:CampBuffName()
    local wantedID = FJ.gdb.settings.campSpellID
    if C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then
        for i = 1, 80 do
            local ok, a = pcall(C_UnitAuras.GetBuffDataByIndex, "player", i)
            if not ok or not a then break end
            local name, id = a.name, a.spellId
            if (FJ.canaccess(name) and name == wanted) or (wantedID and FJ.canaccess(id) and id == wantedID) then
                return true, id
            end
        end
        return false
    elseif UnitAura then
        for i = 1, 80 do
            local name, _, _, _, _, _, _, _, _, id = UnitAura("player", i, "HELPFUL")
            if not name then break end
            if name == wanted or (wantedID and id == wantedID) then return true, id end
        end
        return false
    end
    return nil
end

local function FinishCamp(now)
    if not campActive then return end
    campActive = false
    local dur = math.max(0, now - campStart)
    local t = FJ.db.totals
    t.campTime = (t.campTime or 0) + dur
    if dur > (t.campLongest or 0) then t.campLongest = dur end
    FJ.db.campActive = nil
    FJ:NotifyDataChanged()
end

function Social:CheckCamp(force)
    if not FJ.db then return end
    -- Combat state can be a secret boolean; treat "unreadable" as "in combat" and wait for the next check.
    if not force and FJ.Bool(UnitAffectingCombat("player"), true) then return end
    local has, spellID = self:PlayerHasCampBuff()
    if has == nil then return end
    local now = time()
    if has and not campActive then
        campActive, campStart = true, now
        local db = FJ.db
        local t = db.totals
        t.campCount = (t.campCount or 0) + 1
        t.campLast = now
        if spellID and FJ.canaccess(spellID) then FJ.gdb.settings.campSpellID = spellID end
        local mapID = FJ.Zones:GetCurrent()
        local z = mapID and db.zones[mapID]
        if z then z.camps = (z.camps or 0) + 1 end
        db.campActive = { start = now, zone = mapID }
        if t.campCount == 1 then
            FJ.Timeline:Add("camp", 45, { a = 1 })
        elseif t.campCount % 10 == 0 then
            FJ.Timeline:Add("camp", 30, { a = t.campCount })
        end
        FJ:NotifyDataChanged()
    elseif not has and campActive then
        FinishCamp(now)
    end
end

function Social:IsCamping()
    return campActive, campActive and (time() - campStart) or 0
end

-- Prints the player's current buffs so the camping buff name can be confirmed in-game.
function Social:PrintBuffs()
    if C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() then
        FJ.Print("Auras are secret right now; try again out of combat and outside instances.")
        return
    end
    local n = 0
    if C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then
        for i = 1, 80 do
            local ok, a = pcall(C_UnitAuras.GetBuffDataByIndex, "player", i)
            if not ok or not a then break end
            if FJ.canaccess(a.name) then
                FJ.Print(format("  buff %d: %s (spell %s)", i, tostring(a.name), tostring(FJ.canaccess(a.spellId) and a.spellId or "?")))
                n = n + 1
            end
        end
    elseif UnitAura then
        for i = 1, 80 do
            local name, _, _, _, _, _, _, _, _, id = UnitAura("player", i, "HELPFUL")
            if not name then break end
            FJ.Print(format("  buff %d: %s (spell %s)", i, name, tostring(id)))
            n = n + 1
        end
    end
    FJ.Print(format("%d buffs. Tracking camping as \"%s\"%s.", n, self:CampBuffName(), FJ.gdb.settings.campSpellID and (" / spell " .. FJ.gdb.settings.campSpellID) or ""))
end

---------------------------------------------------------------------------
-- Wiring
---------------------------------------------------------------------------
function Social:OnEnable()
    if DoEmote and not self.hooked then
        self.hooked = true
        hooksecurefunc("DoEmote", function(token) Social:OnEmote(token) end)
    end
    if SendChatMessage and not self.chatHooked then
        self.chatHooked = true
        hooksecurefunc("SendChatMessage", function(_, chatType)
            if FJ.canaccess(chatType) and chatType == "EMOTE" then Social:OnEmote(CUSTOM) end
        end)
    end
    if not self.poseHooked then
        self.poseHooked = true
        if SitStandOrDescendStart then hooksecurefunc("SitStandOrDescendStart", OnSitStandKey) end
        if JumpOrAscendStart then
            hooksecurefunc("JumpOrAscendStart", function()
                EndPose()
                local t = FJ.db and FJ.db.totals
                if t then t.jumps = (t.jumps or 0) + 1 end
            end)
        end
    end

    -- Resume a camp that was active at the last logout or reload if the buff is still up.
    local prev = FJ.db.campActive
    if prev and prev.start and (time() - prev.start) < 3600 then
        local has = self:PlayerHasCampBuff()
        if has then
            campActive, campStart = true, prev.start
        else
            FJ.db.campActive = nil
        end
    end

    FJ:RegisterUnitEvent("UNIT_AURA", "player", function()
        local now = GetTime()
        if now - lastAuraCheck < 0.5 then
            FJ:Debounce("camp-check", 0.6, function() Social:CheckCamp() end)
            return
        end
        lastAuraCheck = now
        Social:CheckCamp()
    end)
    FJ:RegisterEvent("PLAYER_REGEN_ENABLED", function() Social:CheckCamp() end)
    FJ:After(6, function() Social:CheckCamp(true) end)

    -- Anything that makes a character stand up ends the current pose.
    FJ:RegisterEvents({
        "PLAYER_STARTED_MOVING", "PLAYER_REGEN_DISABLED", "PLAYER_DEAD", "PLAYER_ENTERING_WORLD",
        "GOSSIP_SHOW", "MERCHANT_SHOW", "QUEST_DETAIL", "QUEST_GREETING", "TAXIMAP_OPENED",
        "MAIL_SHOW", "BANKFRAME_OPENED", "TRAINER_SHOW", "AUCTION_HOUSE_SHOW", "TRADE_SHOW",
        "PLAYER_CONTROL_LOST", "UNIT_ENTERED_VEHICLE",
    }, EndPose)
    FJ:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player", EndPose)
    -- Fallback for clients without movement events: speed check on the heartbeat.
    FJ:RegisterMessage("FJ_TICK", function()
        if pose and GetUnitSpeed and (GetUnitSpeed("player") or 0) > 0 then EndPose() end
    end)
end

function Social:OnLogout()
    EndPose()
    if campActive then
        local now = time()
        local t = FJ.db.totals
        t.campTime = (t.campTime or 0) + math.max(0, now - campStart)
        FJ.db.campActive = { start = now, zone = FJ.Zones:GetCurrent() }
    end
end
