-- Live towers, repeaters and where a player's phone gets service (spec §7). Same answer on client and server:
-- towers come from the world seed and the day; repeaters come from the server's list.
local Towers = require "KnoxMobile/Core/Towers"
local Network = require "KnoxMobile/Core/Network"
local Repeaters = require "KnoxMobile/Core/Repeaters"
local Signal = require "KnoxMobile/Core/Signal"
local TowerSites = require "KnoxMobile/Data/TowerSites"
local CellSites = require "KnoxMobile/Core/CellSites"
local Util = require "KnoxMobile/Game/Util"

local WorldModel = {}

local function collapseSettings(s)
    return {
        serviceCollapse = s.ServiceCollapse, serviceCollapseDays = s.ServiceCollapseDays,
        gradualCollapse = s.GradualCollapse, networkCongestion = s.NetworkCongestion,
    }
end

function WorldModel.knownMap(x, y)
    local b = TowerSites.bounds
    return x >= b.minX and x <= b.maxX and y >= b.minY and y <= b.maxY
end

-- Is this tower up on its own schedule (grid, backup batteries, the collapse)? The debug menu can force all
-- towers dead or alive.
function WorldModel.scheduledAlive(site, settings)
    local forced = KnoxMobile.world.debugTowers
    if forced == "dead" then return false end
    if forced == "alive" then return true end
    return Towers.isAlive(site, Util.nowDay(), collapseSettings(settings or Util.settings()), KnoxMobile.world.seed or 1,
        Util.gridOffDay())
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

function WorldModel.locatePlayer(player, model, knownPasswords)
    local settings = Util.settings()
    local spot = WorldModel.spot(player)
    local boost = Signal.heightBoost(spot.z, spot.onRoof, settings.RoofSignal)
    local located, descriptor = WorldModel.locate(player:getX(), player:getY(), model and model.antenna or 1, spot.indoors,
        knownPasswords, settings, boost)
    located.indoors = spot.indoors
    return located, descriptor
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
    return Towers.callFails(rng, Util.nowDay(), collapseSettings(settings))
end

return WorldModel
