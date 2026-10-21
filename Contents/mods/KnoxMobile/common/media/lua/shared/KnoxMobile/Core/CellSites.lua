-- Cell sites players can bring back with a generator. Pure Lua 5.1; distances in tiles, times in game minutes.
-- Each tower site (Data/TowerSites) has a hookup point at its coordinates. A vanilla generator on that square or
-- right next to it, connected from the site's right-click menu and running with fuel, keeps the tower on the air.
-- The server keeps one entry per connected site in world ModData (serialisable):
--   sites[site id] = { connected = true, untilMin = game minute the fuel runs out (nil: not running),
--                      lastCharge = game minute the radio load was last taken from the tank, by = player key }
-- While the site's chunk is not loaded the server can't see the generator, so the tower stays up until untilMin,
-- the moment the tank would run dry (vanilla catches the generator's own burn up when the chunk loads again).

local Mod = require "KnoxMobile/Core/Mod"
local Signal = require "KnoxMobile/Core/Signal"

local CellSites = {}

CellSites.HOOKUP_REACH = 1  -- the generator sits on the hookup point or on a square next to it
CellSites.MENU_RADIUS = 8   -- the site's right-click menu shows on squares this close to the hookup point
CellSites.TOWER_LOAD = 1    -- radio equipment load, in vanilla power units (a fridge-freezer is 0.13, an idle generator 0.02)
CellSites.RESEND_MINUTES = 30 -- clients get a new estimate when it moves by more than this
CellSites.MAX_MINUTES = 60 * 24 * 365

function CellSites.byId(sites, id)
    for _, s in ipairs(sites) do if s.id == id then return s end end
    return nil
end

function CellSites.byCode(sites, code)
    for _, s in ipairs(sites) do if s.code == code then return s end end
    return nil
end

function CellSites.distance(site, x, y) return Signal.distance(site.x + 0.5, site.y + 0.5, x, y) end

-- Is the square (x, y, z) part of the hookup point (the point or a square next to it, on the site's floor)?
function CellSites.inHookup(site, x, y, z)
    return math.floor(z or 0) == (site.z or 0) and math.abs(math.floor(x) - site.x) <= CellSites.HOOKUP_REACH
        and math.abs(math.floor(y) - site.y) <= CellSites.HOOKUP_REACH
end

-- The squares a generator may stand on, hookup point first.
function CellSites.hookupSquares(site)
    local out = { { x = site.x, y = site.y, z = site.z or 0 } }
    local r = CellSites.HOOKUP_REACH
    for dy = -r, r do
        for dx = -r, r do
            if dx ~= 0 or dy ~= 0 then out[#out + 1] = { x = site.x + dx, y = site.y + dy, z = site.z or 0 } end
        end
    end
    return out
end

-- The closest site, and its distance in tiles.
function CellSites.nearest(sites, x, y)
    local best, bestD = nil, math.huge
    for _, s in ipairs(sites) do
        local d = CellSites.distance(s, x, y)
        if d < bestD then best, bestD = s, d end
    end
    return best, bestD
end

-- The site whose menu shows at this spot, or nil.
function CellSites.at(sites, x, y, radius)
    local s, d = CellSites.nearest(sites, x, y)
    if s and d <= (radius or CellSites.MENU_RADIUS) then return s, d end
    return nil
end

-- Compass point from (fromX, fromY) toward (toX, toY): "n", "ne", "e", ... ("here" when on top of it).
-- The game's y grows southward.
local POINTS = { "e", "se", "s", "sw", "w", "nw", "n", "ne" }
function CellSites.compass(fromX, fromY, toX, toY)
    local dx, dy = toX - fromX, toY - fromY
    if math.abs(dx) < 1 and math.abs(dy) < 1 then return "here" end
    local a = math.atan2(dy, dx) * 180 / math.pi
    if a < 0 then a = a + 360 end
    return POINTS[Mod.floor(math.floor((a + 22.5) / 45), 8) + 1]
end

-- Fuel the radio equipment takes from the tank over some hours. fuelUse: sandbox TowerFuelUse;
-- consumption: vanilla sandbox GeneratorFuelConsumption, which scales every generator load the same way.
function CellSites.extraFuel(hours, fuelUse, consumption)
    return math.max(0, hours) * CellSites.TOWER_LOAD * (fuelUse or 1) * (consumption or 1)
end

-- Fuel per hour with the tower on it: the generator's own vanilla load (IsoGenerator.getTotalPowerUsing) plus radios.
function CellSites.burnPerHour(powerUsing, fuelUse, consumption)
    return ((powerUsing or 0) + CellSites.TOWER_LOAD * (fuelUse or 1)) * (consumption or 1)
end

function CellSites.minutesLeft(fuel, burnPerHour)
    if (fuel or 0) <= 0 then return 0 end
    if not burnPerHour or burnPerHour <= 0 then return CellSites.MAX_MINUTES end
    return math.min(CellSites.MAX_MINUTES, fuel / burnPerHour * 60)
end

-- Is this site on the air on generator power right now?
function CellSites.isUp(entry, now)
    return type(entry) == "table" and entry.connected == true and type(entry.untilMin) == "number" and now < entry.untilMin
end

-- One server look at a connected site. reading: nil while the chunk is not loaded, else
-- { present = a generator stands in the hookup area, running = activated with fuel, fuel, powerUsing }.
-- s = { fuelUse, consumption }. Updates the entry; returns { extra = fuel to take from the tank now,
-- lost = the generator is gone (the site disconnects), send = clients need the new state }.
function CellSites.step(entry, reading, now, s)
    if reading == nil then return { extra = 0, send = false } end
    local wasUp, wasUntil = CellSites.isUp(entry, now), entry.untilMin
    if not reading.present then
        entry.connected, entry.untilMin, entry.lastCharge = false, nil, nil
        return { extra = 0, lost = true, send = true }
    end
    local extra = 0
    if reading.running and (reading.fuel or 0) > 0 then
        if entry.lastCharge then extra = CellSites.extraFuel((now - entry.lastCharge) / 60, s.fuelUse, s.consumption) end
        extra = math.min(extra, reading.fuel)
        local fuel = reading.fuel - extra
        entry.lastCharge = now
        if fuel > 0 then
            entry.untilMin = now + CellSites.minutesLeft(fuel, CellSites.burnPerHour(reading.powerUsing, s.fuelUse, s.consumption))
        else
            entry.untilMin = nil
        end
    else
        entry.untilMin, entry.lastCharge = nil, nil
    end
    local isUp = CellSites.isUp(entry, now)
    local moved = isUp and wasUntil ~= nil and math.abs(entry.untilMin - wasUntil) > CellSites.RESEND_MINUTES
    return { extra = extra, send = (isUp ~= wasUp) or moved }
end

-- What clients get: only whether each connected site is up and until when.
function CellSites.publicCopy(entries)
    local out = {}
    for id, e in pairs(entries or {}) do
        if type(e) == "table" and e.connected then out[id] = { connected = true, untilMin = e.untilMin } end
    end
    return out
end

return CellSites
