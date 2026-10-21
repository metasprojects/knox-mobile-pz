-- Knox Mobile carrier alerts: short texts from "KNOX MOBILE ALERT" tied to the game's own schedule. Pure Lua 5.1.
-- The server gathers the facts (server/KnoxMobile/CarrierAlerts.lua) and hands each phone with service the alerts it
-- has not had yet. Days are world-age days (getWorldAgeHours / 24); the game's own shutoff checks add the sandbox's
-- "time since the outbreak" months to that (GameTime.getWorldAgeDaysSinceBegin).
--
-- ctx = {
--   day          world-age day, fractional
--   hour         time of day, 0..24
--   calendarDay  whole day number that changes at midnight (for weather alert ids)
--   sinceBegin   days the outbreak had already run when the game started ((TimeSinceApo - 1) * 30)
--   elecOff      world-age day the grid goes off (nil: never); waterOff: the same for water
--   heli         { day = GameTime helicopter day, nights = nights survived, endHour } or nil when the event is off
--   forecast     { [0] = today, [1] = tomorrow }, each { storm, tropical, blizzard, maxTemp } (nil when unknown)
--   carrierUp    some scheduled tower still works (generator-restored sites don't count)
-- }
-- Alerts.due(ctx) returns the alerts live right now: { id = unique key, kind = text kind, when = "today"/"tomorrow" }.

local Carrier = require "KnoxMobile/Core/Carrier"

local Alerts = {}

-- The thread every alert goes to (Core/Carrier keeps both carrier senders); not a number, so it can't be answered.
Alerts.FROM = Carrier.ALERT_FROM
Alerts.HEAT_C = 34                 -- a forecast high this hot (Celsius, about 93 F) gets a heat advisory

-- First-days news: { kind, from day, to day }. Only when the game starts at the outbreak (sinceBegin 0).
Alerts.NEWS = {
    { "news1", 0.02, 1.5 },
    { "news2", 1, 2.5 },
    { "news3", 2, 4 },
    { "news4", 4, 6.5 },
}

local function add(out, id, kind, when) out[#out + 1] = { id = id, kind = kind, when = when } end

local function weatherKind(f, heatC)
    if type(f) ~= "table" then return nil end
    if f.tropical then return "tropical" end
    if f.storm then return "storm" end
    if f.blizzard then return "blizzard" end
    if type(f.maxTemp) == "number" and f.maxTemp >= heatC then return "heat" end
    return nil
end

function Alerts.due(ctx)
    local out = {}
    if not ctx or not ctx.carrierUp then return out end
    local day = ctx.day or 0

    if (ctx.sinceBegin or 0) == 0 then
        for _, n in ipairs(Alerts.NEWS) do
            if day >= n[2] and day < n[3] then add(out, n[1], n[1]) end
        end
    end

    -- A day's warning before the grid and the water go off; then the grid-down notice. Skipped when they go off at
    -- the very start (nothing to warn about) or never.
    local elec = ctx.elecOff
    if elec and elec >= 1 and day >= elec - 1 and day < elec then add(out, "powerWarn", "powerWarn") end
    if elec and day >= elec and day < elec + 2 then add(out, "powerOut", "powerOut") end
    local water = ctx.waterOff
    if water and water >= 1 and day >= water - 1 and day < water then add(out, "waterWarn", "waterWarn") end

    -- The helicopter: on its day, until its time window closes. Every new helicopter day is a new alert.
    local h = ctx.heli
    if h and (h.day or 0) > 0 and h.nights == h.day and (ctx.hour or 0) < (h.endHour or 24) then
        add(out, "heli:" .. h.day, "heli")
    end

    -- Severe weather today, or tomorrow from noon on. One alert per kind and calendar day.
    local fc = ctx.forecast or {}
    for offset = 0, 1 do
        if offset == 0 or (ctx.hour or 0) >= 12 then
            local kind = weatherKind(fc[offset], Alerts.HEAT_C)
            if kind then
                add(out, "wx:" .. kind .. ":" .. tostring((ctx.calendarDay or 0) + offset), kind,
                    offset == 0 and "today" or "tomorrow")
            end
        end
    end
    return out
end

-- The due alerts this phone hasn't had. seen: the phone's own { [id] = true }.
function Alerts.unseen(seen, due)
    local out = {}
    for _, a in ipairs(due) do
        if not (seen and seen[a.id]) then out[#out + 1] = a end
    end
    return out
end

-- The calendar day for a world age in hours: world age 0 is 7 AM on the first day (GameTime.getWorldAgeHours).
function Alerts.calendarDay(worldAgeHours) return math.floor((worldAgeHours + 7) / 24) end

-- World-age day a vanilla shutoff happens: the sandbox modifier counts from the outbreak's start, the game clock
-- from day one of play. nil when it never happens. Power stays on while days-since-begin <= the modifier
-- (SandboxOptions.doesPowerGridExist); water while it is below it (IsoObject water checks).
function Alerts.shutoffDay(modifier, sinceBegin)
    if type(modifier) ~= "number" or modifier >= 1000000 then return nil end
    return math.max(0, modifier - (sinceBegin or 0))
end

return Alerts
