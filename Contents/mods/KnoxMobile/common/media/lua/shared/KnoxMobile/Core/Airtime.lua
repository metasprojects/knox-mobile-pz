-- 0.3.0: prepaid airtime (the TracPhone, extra "prepaid"). The phone carries minutes: a call costs its minutes
-- (rounded up, the caller pays), a text costs one, 911 is always free. At zero it can't call or text until an airtime
-- card (AirtimeCard, 60 minutes) is loaded from the phone's right-click menu. Pure Lua 5.1.
local Airtime = {}

Airtime.CARD = 60          -- minutes on one card
Airtime.NEW = 60           -- a new phone in its box, or a starting phone
Airtime.FOUND_MAX = 90     -- a found one has 0 to this many left
Airtime.TEXT = 1           -- minutes a text costs
Airtime.LOW = 5            -- "minutes low" warning below this

function Airtime.isPrepaid(model)
    for _, e in ipairs(model and model.extras or {}) do if e == "prepaid" then return true end end
    return false
end

-- Minutes a new phone state starts with. origin: "start", "box", "found"...
function Airtime.starting(origin, rng)
    if origin == "found" then return rng:int(0, Airtime.FOUND_MAX) end
    return Airtime.NEW
end

function Airtime.minutes(state) return math.max(0, math.floor(tonumber(state and state.airtime) or 0)) end

-- Can this prepaid phone reach this number now? 911 always.
function Airtime.canUse(state, to) return to == "911" or Airtime.minutes(state) > 0 end

-- Take minutes off (never below zero). Returns what's left.
function Airtime.charge(state, minutes)
    state.airtime = math.max(0, Airtime.minutes(state) - math.max(0, math.ceil(minutes)))
    return state.airtime
end

-- A call of this many seconds costs its minutes, rounded up (a 10-second call is a minute).
function Airtime.callMinutes(seconds) return math.max(1, math.ceil((seconds or 0) / 60)) end

return Airtime
