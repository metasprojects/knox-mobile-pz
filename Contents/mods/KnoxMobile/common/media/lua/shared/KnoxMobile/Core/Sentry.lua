-- 0.3.0: the Knox Sentry, a cellular motion alarm. Set down at a base with a battery in it, it texts its owner's phone
-- when something moves near it: the dead shuffling past, or someone moving fast (another player). It has its own
-- number: the owner texts it STATUS, OFF or ON. It needs a tower where it stands, like any phone, and a battery
-- (Base.Battery) lasts it up to a month. Pure Lua 5.1; server/KnoxMobile/Sentry.lua runs it.
local Sentry = {}

Sentry.RADIUS = 6           -- squares from the unit that it sees
Sentry.FLOORS = 1           -- levels above or below it
Sentry.COOLDOWN = 30        -- world minutes between two motion texts from one unit
Sentry.BATTERY_DAYS = 30    -- a full battery
Sentry.LOW_DAYS = 2         -- the low-battery text, once
Sentry.NEAR = 70            -- squares: a client this close reports what moves near the unit (the server can't see)

-- Text lines. {name}: the unit ("Sentry 2"); {time}: the clock ("2:14"); {n}: how many; {days}: battery days left;
-- {state}: ARMED / OFF.
Sentry.ARMED = "KNOX SENTRY {name}: ARMED. THIS NUMBER TEXTS YOU WHEN SOMETHING MOVES. TEXT STATUS, OFF OR ON"
Sentry.ZOMBIE = {
    "KNOX SENTRY {name}: MOTION {time}. SLOW MOVEMENT, {n}",
    "KNOX SENTRY {name}: MOTION {time}. [SLOW|SHUFFLING], COUNT {n}",
}
Sentry.PERSON = {
    "KNOX SENTRY {name}: MOTION {time}. FAST MOVEMENT. [SOMEONE IS THERE|CHECK YOUR PROPERTY]",
    "KNOX SENTRY {name}: MOTION {time}. FAST, UPRIGHT. [SOMEONE IS THERE|CHECK YOUR PROPERTY]",
}
Sentry.LOW = "KNOX SENTRY {name}: LOW BATTERY. REPLACE WITHIN 48 HOURS"
Sentry.STATUS = "KNOX SENTRY {name}: {state}. BATTERY {days} DAYS"
Sentry.STATES = { armed = "ARMED", off = "OFF" }
Sentry.HELP = "KNOX SENTRY {name}: TEXT STATUS, OFF OR ON"

-- What a text to the unit asks for: "status", "off", "on", or "help" for anything else. English and Spanish words.
local WORDS = { status = "status", estado = "status", off = "off", disarm = "off", apagar = "off", desarmar = "off",
    on = "on", arm = "on", encender = "on", armar = "on" }
function Sentry.command(body)
    local word = tostring(body or ""):lower():match("^%s*(%a+)")
    return word and WORDS[word] or "help"
end

-- Does the unit see (x, y, z)?
function Sentry.sees(unit, x, y, z)
    return math.abs(x - unit.x) <= Sentry.RADIUS and math.abs(y - unit.y) <= Sentry.RADIUS
        and math.abs(math.floor(z or 0) - (unit.z or 0)) <= Sentry.FLOORS
end

-- Is a client at (x, y) close enough to watch over the unit?
function Sentry.watches(unit, x, y)
    return math.abs(x - unit.x) <= Sentry.NEAR and math.abs(y - unit.y) <= Sentry.NEAR
end

-- Battery days left at world minute `now` (it ran from unit.placedAt with unit.days of charge).
function Sentry.daysLeft(unit, now)
    local used = math.max(0, (now - (unit.placedAt or now)) / 1440)
    return math.max(0, (unit.days or 0) - used)
end

-- How many days a battery with `uses` (0..1) of its charge left gives.
function Sentry.daysFrom(uses)
    return math.floor(Sentry.BATTERY_DAYS * math.max(0, math.min(1, tonumber(uses) or 0)) + 0.5)
end

-- May the unit text about motion now?
function Sentry.ready(unit, now)
    return unit.armed ~= false and Sentry.daysLeft(unit, now) > 0
        and (unit.last == nil or now - unit.last >= Sentry.COOLDOWN)
end

-- "2:14" from a world minute.
function Sentry.clock(minute)
    local m = math.floor(minute) - math.floor(minute / 1440) * 1440
    local h = math.floor(m / 60)
    return string.format("%d:%02d", h, m - h * 60)
end

-- Count what it sees: zombies { {x,y,z} }, people { {x,y,z} }. Returns "person", 1 when someone is there (people
-- come first: they matter more), "zombie", n for the dead, or nil.
function Sentry.what(unit, zombies, people)
    for _, p in ipairs(people or {}) do
        if Sentry.sees(unit, p.x, p.y, p.z) then return "person", 1 end
    end
    local n = 0
    for _, z in ipairs(zombies or {}) do
        if Sentry.sees(unit, z.x, z.y, z.z) then n = n + 1 end
    end
    if n > 0 then return "zombie", n end
    return nil
end

return Sentry
