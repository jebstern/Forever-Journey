-- Forever Journey: single event frame, internal messages, timers and lifecycle.
local ADDON_NAME, FJ = ...

local frame = CreateFrame("Frame")
local handlers = {}
local messages = {}

frame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do
        list[i](event, ...)
    end
end)

-- Events whose registration is a protected action on 12.0-style clients. A pcall does not help:
-- the client still reports ADDON_ACTION_FORBIDDEN, so they must not be attempted at all.
local RESTRICTED = { COMBAT_LOG_EVENT_UNFILTERED = true }

-- Registers an event handler. Unknown events on this client are skipped silently.
function FJ:RegisterEvent(event, fn)
    if RESTRICTED[event] and FJ.RestrictedCombatLog then
        FJ.Debug("Event is restricted on this client:", event)
        return false
    end
    local list = handlers[event]
    if not list then
        local ok = pcall(frame.RegisterEvent, frame, event)
        if not ok then
            FJ.Debug("Event not available on this client:", event)
            return false
        end
        list = {}
        handlers[event] = list
    end
    list[#list + 1] = fn
    return true
end

function FJ:RegisterEvents(events, fn)
    for i = 1, #events do self:RegisterEvent(events[i], fn) end
end

function FJ:RegisterUnitEvent(event, unit, fn)
    local list = handlers[event]
    if not list then
        local ok = pcall(frame.RegisterUnitEvent, frame, event, unit)
        if not ok then ok = pcall(frame.RegisterEvent, frame, event) end
        if not ok then return false end
        list = {}
        handlers[event] = list
    end
    list[#list + 1] = fn
    return true
end

function FJ:IsEventRegistered(event)
    return handlers[event] ~= nil
end

-- Internal message bus (UI refreshes, cross-tracker notifications).
function FJ:RegisterMessage(msg, fn)
    local list = messages[msg]
    if not list then
        list = {}
        messages[msg] = list
    end
    list[#list + 1] = fn
end

function FJ:SendMessage(msg, ...)
    local list = messages[msg]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], msg, ...)
        if not ok then FJ.Error("message " .. msg .. ": " .. tostring(err)) end
    end
end

---------------------------------------------------------------------------
-- Timers
---------------------------------------------------------------------------
function FJ:After(delay, fn)
    C_Timer.After(delay, fn)
end

function FJ:NewTicker(interval, fn)
    return C_Timer.NewTicker(interval, fn)
end

local pending = {}
-- Runs fn once, delay seconds after the first call; further calls within the window are ignored.
function FJ:Debounce(key, delay, fn)
    if pending[key] then return end
    pending[key] = true
    C_Timer.After(delay, function()
        pending[key] = nil
        local ok, err = pcall(fn)
        if not ok then FJ.Error("debounced " .. key .. ": " .. tostring(err)) end
    end)
end

-- Tell the UI something changed. Coalesced so bursts of events cost one refresh.
function FJ:NotifyDataChanged()
    self:Debounce("data-changed", 0.5, function() FJ:SendMessage("FJ_DATA_CHANGED") end)
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
FJ:RegisterEvent("ADDON_LOADED", function(_, name)
    if name ~= ADDON_NAME then return end
    FJ:InitDB()
    FJ:CallModules("OnInit")
    FJ.initialized = true
end)

FJ:RegisterEvent("PLAYER_LOGIN", function()
    FJ:RefreshIdentity()
    FJ:CallModules("OnLogin")
end)

FJ:RegisterEvent("PLAYER_ENTERING_WORLD", function(_, isLogin, isReload)
    if not FJ.enabled then
        FJ.enabled = true
        FJ:CallModules("OnEnable", isLogin, isReload)
    end
    FJ:CallModules("OnEnteringWorld", isLogin, isReload)
end)

FJ:RegisterEvent("PLAYER_LOGOUT", function()
    FJ:CallModules("OnLogout")
    FJ:UpdateRoster()
    FJ:PruneDB()
end)
