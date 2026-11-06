-- Live towers, repeaters and where a player's phone gets service (spec §7). Same answer on client and server:
-- towers come from the world seed and the day; repeaters come from the server's list.
local Towers = require "KnoxMobile/Core/Towers"
local Network = require "KnoxMobile/Core/Network"
local Repeaters = require "KnoxMobile/Core/Repeaters"
local Signal = require "KnoxMobile/Core/Signal"
local TowerSites = require "KnoxMobile/Data/TowerSites"
local CellSites = require "KnoxMobile/Core/CellSites"
local Util = require "KnoxMobile/Game/Util"
local Registry = require "KnoxMobile/Core/Registry"
local Boosters = require "KnoxMobile/Core/Boosters"
local Weather = require "KnoxMobile/Core/Weather"

local WorldModel = {}

local function collapseSettings(s)
    return {
        serviceCollapse = s.ServiceCollapse, serviceCollapseDays = s.ServiceCollapseDays,
        gradualCollapse = s.GradualCollapse, networkCongestion = s.NetworkCongestion,
    }
end

-- Vanilla Kentucky, or near a town of another map (0.3.0: Game/MapNetwork). Off both: medium service, as before.
local MapNetwork = require "KnoxMobile/Game/MapNetwork"
function WorldModel.knownMap(x, y)
    return MapNetwork.knows(x, y)
end

-- Is this tower up on its own schedule (grid, backup batteries, the collapse)? The debug menu can force all
-- towers dead or alive.
function WorldModel.scheduledAlive(site, settings)
    local forced = KnoxMobile.world.debugTowers
    if forced == "dead" then return false end
    if forced == "alive" then return true end
    return Towers.isAlive(site, Util.sinceOutbreak(), collapseSettings(settings or Util.settings()), KnoxMobile.world.seed or 1,
        Util.gridOffSinceOutbreak())
end

-- Is this site on the air on a player's generator (server/KnoxMobile/SiteRestore.lua)?
function WorldModel.restored(site, settings)
    settings = settings or Util.settings()
    if not settings.TowerRestore then return false end
    return CellSites.isUp((KnoxMobile.world.sites or {})[site.id], Util.nowMinutes())
end

-- Live tower sites right now: on schedule, or brought back with a generator (that works even with the debug menu's
-- "kill all towers", which only stops the schedule). restored = true marks the generator sites.
function WorldModel.liveTowers(settings)
    settings = settings or Util.settings()
    local out = {}
    for _, site in ipairs(TowerSites.sites) do
        local scheduled = WorldModel.scheduledAlive(site, settings)
        if scheduled or WorldModel.restored(site, settings) then
            out[#out + 1] = { id = site.id, x = site.x, y = site.y, range = site.range or Signal.TOWER_RANGE, town = site.town,
                code = site.code, restored = not scheduled }
        end
    end
    return out
end

-- Does the carrier itself still run? True while any tower is up on its own schedule (generator sites don't count).
function WorldModel.carrierUp(settings)
    for _, site in ipairs(TowerSites.sites) do
        if WorldModel.scheduledAlive(site, settings) then return true end
    end
    return false
end

function WorldModel.world(settings)
    settings = settings or Util.settings()
    local live = WorldModel.liveTowers(settings)
    return {
        towers = live, repeaters = KnoxMobile.world.repeaters or {},
        settings = { repeaterRange = settings.RepeaterRange, allowPrivateRepeaters = settings.AllowPrivateRepeaters },
        knownMap = true, towersAlive = #live > 0,
    }
end

-- Where a phone at this spot gets service. boost: the height bonus (Signal.heightBoost; nil on the ground).
-- Returns { network, bars, via } (Core/Network) plus a MessageQueue descriptor { id, world, members }.
function WorldModel.locate(x, y, antenna, indoors, knownPasswords, settings, boost)
    local world = WorldModel.world(settings)
    world.knownMap = WorldModel.knownMap(x, y)
    local located = Network.locate(world, x, y, antenna, indoors, knownPasswords, boost)
    local descriptor = nil
    if located.network then
        -- Repeater ids are "R<number>"; when service comes through a repeater, its network's members
        -- decide where queued messages can still arrive (spec §7.5).
        local members = {}
        if located.via and tostring(located.via):match("^R%d+$") then
            local nets = Repeaters.networks(world.repeaters, world.settings, world.towers)
            local net = Repeaters.networkOf(located.via, nets)
            if net then members = net.members end
        end
        descriptor = { id = located.network, world = located.network == "world", members = members }
    end
    return located, descriptor
end

-- Where this player stands for signal: indoors (or in a basement), floors up, out on a roof.
function WorldModel.spot(player)
    local sq = player:getCurrentSquare()
    local z = player:getZ()
    local outside = sq ~= nil and sq:isOutside()
    -- Indoors and basements (below ground) cost a bar (spec §7.1); height stretches the reach.
    return { indoors = (sq ~= nil and not outside) or z < 0, z = z, onRoof = outside and z >= 1 }
end

-- 0.3.0: a mag-mount antenna on the car roof (KnoxMobile.MagMountAntenna, carried) gives any phone more reach while
-- you sit in a vehicle.
WorldModel.MAG_MOUNT = 1.5
function WorldModel.antenna(player, model)
    local a = model and model.antenna or 1
    local ok, inCar = pcall(function() return player:getVehicle() ~= nil end)
    if ok and inCar and player:getInventory():containsTypeRecurse("KnoxMobile.MagMountAntenna") then
        a = a + WorldModel.MAG_MOUNT
    end
    return a
end

-- The weather now, for the network (Core/Weather). The game's climate is the same everywhere.
function WorldModel.weather()
    if KnoxMobile.debugStorm then return { thunder = true, precip = 0.8, wind = 0.7 } end -- debug menu
    local ok, w = pcall(function()
        local c = getClimateManager()
        return { thunder = c:getIsThunderStorming(), precip = c:getPrecipitationIntensity(),
            snow = c:getPrecipitationIsSnow(), wind = c:getWindIntensity() }
    end)
    return ok and w or nil
end

function WorldModel.weatherOn(settings) return (settings or Util.settings()).WeatherSignal ~= false end

function WorldModel.locatePlayer(player, model, knownPasswords)
    local settings = Util.settings()
    local spot = WorldModel.spot(player)
    -- 0.3.0: a powered signal booster nearby carries the outside signal in (Core/Boosters).
    if spot.indoors and Boosters.covers(KnoxMobile.world.boosters, player:getX(), player:getY()) then
        spot.indoors, spot.boosted = false, true
    end
    local boost = Signal.heightBoost(spot.z, spot.onRoof, settings.RoofSignal)
    local located, descriptor = WorldModel.locate(player:getX(), player:getY(), WorldModel.antenna(player, model),
        spot.indoors, knownPasswords, settings, boost)
    located.indoors = spot.indoors
    -- 0.3.0: a satellite phone needs no tower, only open sky. Indoors it finds no satellite, towers or not.
    if model and Registry.hasExtra(model, "satellite") then
        located, descriptor = WorldModel.satellite(located, descriptor, spot.indoors)
    end
    -- Storms cost a bar, satellites too (rain fade).
    if WorldModel.weatherOn(settings) then
        located = Weather.apply(located, WorldModel.weather())
        if not located.network then descriptor = nil end
    end
    return located, descriptor
end

-- The satellite phone's service: the world network from anywhere under open sky (two bars: a slow, narrow link),
-- nothing indoors. A tower's own bars are better, so a tower in reach wins outdoors.
WorldModel.SATELLITE_BARS = 2
function WorldModel.satellite(located, descriptor, indoors)
    if indoors then
        return { network = nil, bars = 0, via = "satelliteSky", indoors = true }, nil
    end
    if located.network == "world" and (located.bars or 0) >= WorldModel.SATELLITE_BARS then return located, descriptor end
    return { network = "world", bars = WorldModel.SATELLITE_BARS, via = "satellite", indoors = false },
        { id = "world", world = true, members = {} }
end

-- At 0-1 bars indoors: would two floors up, out on a roof, do better? (the phone's "Try higher ground" hint)
function WorldModel.higherHelps(player, model, knownPasswords, located)
    if not located or not located.indoors or (located.bars or 0) > 1 then return false end
    local settings = Util.settings()
    local z = math.max(0, math.floor(player:getZ())) + 2
    local up = WorldModel.locate(player:getX(), player:getY(), model and model.antenna or 1, false, knownPasswords, settings,
        Signal.heightBoost(z, true, settings.RoofSignal))
    return Signal.suggestHigher(located.bars, located.indoors, up.bars)
end

function WorldModel.callFails(rng, settings)
    settings = settings or Util.settings()
    return Towers.callFails(rng, Util.sinceOutbreak(), collapseSettings(settings))
end

return WorldModel
