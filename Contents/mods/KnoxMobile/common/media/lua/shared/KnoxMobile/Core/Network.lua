-- Where a phone gets service right now: live towers (the "world" network) or a repeater network (spec §7).
-- Pure Lua 5.1. The game adapter builds the world table; this module only decides.

local Signal = require "KnoxMobile/Core/Signal"
local Repeaters = require "KnoxMobile/Core/Repeaters"

local Network = {}

-- world = {
--   towers = { { id, x, y, range } }  -- live towers only
--   repeaters = { ... }, settings = { repeaterRange, allowPrivateRepeaters },
--   knownMap = false when no tower sites cover this map; towersAlive = is service still up there?
-- }
-- boost: the phone's height bonus (Signal.heightBoost), 1 or nil on the ground.
-- Returns { network = "world" | repeater network id | nil, bars = 0..4, via = tower or repeater id }.
function Network.locate(world, x, y, antenna, indoors, knownPasswords, boost)
    local settings = world.settings or {}
    local best = { network = nil, bars = 0, via = nil }

    if world.knownMap == false then
        if world.towersAlive then
            best = { network = "world", bars = Signal.UNKNOWN_MAP_BARS, via = "unknownMap" }
        end
    else
        local bars, via = Signal.best(x, y, world.towers or {}, antenna, indoors, boost)
        if bars > 0 then best = { network = "world", bars = bars, via = via } end
    end

    local reps = world.repeaters or {}
    if #reps > 0 then
        local nets = Repeaters.networks(reps, settings, world.towers)
        for _, rep in ipairs(reps) do
            if Repeaters.isActive(rep) and Repeaters.canUse(rep, settings, knownPasswords) then
                local d = Signal.distance(x, y, rep.x, rep.y)
                local bars = Signal.barsAt(d, Repeaters.range(rep, settings), antenna, indoors, boost)
                if bars > best.bars then
                    local net = Repeaters.networkOf(rep.id, nets)
                    best = { network = (net.bridged and "world") or net.id, bars = bars, via = rep.id }
                end
            end
        end
    end
    return best
end

return Network
