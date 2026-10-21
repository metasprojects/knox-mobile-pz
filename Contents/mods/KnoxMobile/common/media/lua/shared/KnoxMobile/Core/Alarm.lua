-- Alarm: a phone's daily alarm (spec §4.6 "alarm" on every family). Pure Lua 5.1. The server decides when an
-- alarm rings (server/KnoxMobile/Alarms.lua, from PhoneTick); this module holds the rules.
-- An alarm is a plain table saved in the phone's state:
--   { on = true, hour = 6, minute = 30, ringing = <world minute it started>, snoozeUntil = <world minute>,
--     checkedAt = <world minute of the last check>, firedAt = <world minute it last rang> }
-- Times: "now" is the world age in minutes (monotonic); hour and minute are the in-game clock.
local Mod = require "KnoxMobile/Core/Mod"
local Alarm = {}

Alarm.RING_MINUTES = 30   -- an unanswered alarm rings this long (vanilla alarm clocks ring half an hour)
Alarm.SNOOZE_MINUTES = 9  -- the classic snooze
Alarm.LATE_LIMIT = 10     -- a check that comes late (server hiccup, fast-forward) still rings up to this late
Alarm.MAX_RADIUS = 75
Alarm.QUICK = { 5, 15, 60 } -- "ring in ..." presets in minutes: the zombie lure

local DAY = 1440

function Alarm.valid(hour, minute)
    return type(hour) == "number" and type(minute) == "number" and Mod.floor(hour, 1) == 0 and Mod.floor(minute, 1) == 0
        and hour >= 0 and hour <= 23 and minute >= 0 and minute <= 59
end

-- Minutes from the clock time now until the alarm time: 1..1440 (an alarm set for this very minute is a day away).
function Alarm.minutesUntil(hour, minute, nowHour, nowMinute)
    local d = Mod.floor(((hour * 60 + minute) - (nowHour * 60 + nowMinute)), DAY)
    if d == 0 then d = DAY end
    return d
end

-- The clock time `plus` minutes after hour:minute.
function Alarm.later(hour, minute, plus)
    local t = Mod.floor((hour * 60 + minute + math.floor(plus)), DAY)
    return math.floor(t / 60), Mod.floor(t, 60)
end

-- Sets (and switches on) the alarm. Returns the alarm table (a new one when `alarm` is nil). once: a timer ("Ring in
-- 5 min") that switches itself off after it rings, instead of ringing again every day.
function Alarm.set(alarm, hour, minute, now, once)
    alarm = alarm or {}
    alarm.on, alarm.hour, alarm.minute = true, hour, minute
    alarm.once = once == true or nil
    alarm.ringing, alarm.snoozeUntil, alarm.firedAt = nil, nil, nil
    alarm.checkedAt = now and math.floor(now) or alarm.checkedAt
    return alarm
end

function Alarm.off(alarm)
    if not alarm then return nil end
    alarm.on, alarm.ringing, alarm.snoozeUntil = false, nil, nil
    return alarm
end

-- Stop ringing; the alarm stays set for tomorrow.
function Alarm.stop(alarm)
    if not alarm then return nil end
    alarm.ringing, alarm.snoozeUntil = nil, nil
    return alarm
end

function Alarm.snooze(alarm, now)
    if not alarm then return nil end
    alarm.ringing = nil
    alarm.snoozeUntil = math.floor(now) + Alarm.SNOOZE_MINUTES
    return alarm
end

-- Is anything pending (set, ringing or snoozed)? The server only tracks phones whose alarm is active.
function Alarm.active(alarm)
    return type(alarm) == "table" and (alarm.on == true or alarm.ringing ~= nil or alarm.snoozeUntil ~= nil)
end

-- Advances the alarm to `now` (world minutes) with the clock at hour:minute. Returns "ring" when it starts
-- ringing, "timeout" when an unanswered ring ends, or nil.
function Alarm.check(alarm, now, hour, minute)
    if type(alarm) ~= "table" then return nil end
    now = math.floor(now)
    local last = alarm.checkedAt
    alarm.checkedAt = now
    if alarm.ringing then
        if now - alarm.ringing >= Alarm.RING_MINUTES then
            alarm.ringing = nil
            return "timeout"
        end
        return nil
    end
    if alarm.snoozeUntil then
        if now >= alarm.snoozeUntil then
            alarm.snoozeUntil, alarm.ringing, alarm.firedAt = nil, now, now
            return "ring"
        end
        return nil
    end
    if not alarm.on or not Alarm.valid(alarm.hour, alarm.minute) then return nil end
    -- Did the alarm's clock time pass since the last check? (Checks come every minute, sometimes late.)
    local elapsed = last and math.max(1, now - last) or 1
    local since = Mod.floor(((hour * 60 + minute) - (alarm.hour * 60 + alarm.minute)), DAY) -- minutes since it was due
    if since < elapsed and since <= Alarm.LATE_LIMIT and not (alarm.firedAt and now - alarm.firedAt < 60) then
        alarm.ringing, alarm.firedAt = now, now
        if alarm.once then alarm.on, alarm.once = false, nil end
        return "ring"
    end
    return nil
end

-- World minute the current ring stops by itself.
function Alarm.ringsUntil(alarm)
    return alarm and alarm.ringing and (alarm.ringing + Alarm.RING_MINUTES) or nil
end

-- How far zombies hear it, in tiles. volume 0..1 (the phone's volume setting); muffled: in a bag or a container.
-- settings.alarmRadius: sandbox AlarmRadius (tiles at full volume, 0 = zombies never hear alarms).
function Alarm.radius(volume, muffled, settings)
    local full = (settings and settings.alarmRadius) or 30
    local r = full * (0.5 + 0.5 * math.max(0, math.min(1, volume or 0.7)))
    if muffled then r = r / 2 end
    return math.floor(math.min(Alarm.MAX_RADIUS, math.max(0, r)))
end

return Alarm
