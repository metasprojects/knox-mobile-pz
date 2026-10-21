-- Find my crew and the SOS button: rough positions from the network, never exact. Pure Lua 5.1.
-- A phone's position is what the towers or a repeater can work out: the true spot plus an error that depends on
-- the source (towers are coarse, a nearby repeater is better) and changes once an in-game hour. Directions are
-- 8-point compass names on the game map (north is -y), distances are bands.
local Mod = require "KnoxMobile/Core/Mod"
local Rng = require "KnoxMobile/Core/Rng"

local Crew = {}

Crew.ACCURACY = { tower = 60, repeater = 25, unknown = 150 } -- tiles of error, each way
Crew.BANDS = { { max = 100, id = "near" }, { max = 500, id = "blocks" }, { max = 2000, id = "km" }, { id = "far" } }
Crew.DIRS = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }
Crew.MAX_LIST = 24

Crew.SOS_COOLDOWN = 60        -- in-game minutes between SOS texts from one player
Crew.SOS_MAX = 40             -- phones one SOS reaches at most
Crew.SOS_RADIUS = 40          -- tiles zombies hear the SOS ring at phone noise x1 (the most the noise path allows)
Crew.SOS_RING_SECONDS = 12    -- how long the phone keeps ringing out loud after an SOS

-- What gave the phone its service: a repeater ("R12"), a tower, or medium service on an unknown map.
function Crew.sourceKind(via)
    if type(via) == "string" and via:match("^R%d+$") then return "repeater" end
    if via == "unknownMap" or via == nil then return "unknown" end
    return "tower"
end

-- The network's idea of where this phone is. seed: world seed, number and hour, so it holds still for an hour.
function Crew.estimate(x, y, via, seed)
    local acc = Crew.ACCURACY[Crew.sourceKind(via)]
    local rng = Rng.new(tostring(seed))
    return x + (rng:next() * 2 - 1) * acc, y + (rng:next() * 2 - 1) * acc
end

function Crew.compass(dx, dy)
    local deg = math.deg(math.atan2(dx, -dy)) -- 0 = north, 90 = east
    if deg < 0 then deg = deg + 360 end
    return Crew.DIRS[Mod.floor(math.floor((deg + 22.5) / 45), 8) + 1]
end

function Crew.band(distance)
    for _, b in ipairs(Crew.BANDS) do
        if b.max == nil or distance < b.max then return b.id end
    end
end

-- Direction and band from (ax, ay) to (bx, by).
function Crew.between(ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local d = math.sqrt(dx * dx + dy * dy)
    return Crew.compass(dx, dy), Crew.band(d), d
end

-- The nearest town tower site (highway towers have no town). Returns the site or nil.
function Crew.nearestTown(sites, x, y)
    local best, bestD = nil, nil
    for _, s in ipairs(sites) do
        if s.town and s.town ~= "Highway" then
            local dx, dy = x - s.x, y - s.y
            local d = dx * dx + dy * dy
            if not bestD or d < bestD then best, bestD = s, d end
        end
    end
    return best
end

-- Where an SOS says you are: { town, dir, band }, the direction and band measured from the town's tower.
function Crew.where(sites, x, y)
    local site = Crew.nearestTown(sites, x, y)
    if not site then return { band = "far" } end
    local dir, band = Crew.between(site.x, site.y, x, y)
    return { town = site.town, dir = dir, band = band }
end

-- Returns true, or false and the in-game minutes left.
function Crew.sosReady(last, now)
    if type(last) ~= "number" or last > now then return true end
    local left = Crew.SOS_COOLDOWN - (now - last)
    if left <= 0 then return true end
    return false, math.ceil(left)
end

-- Who gets an SOS: group members first, then contacts, then nearby strangers; no repeats, never yourself.
-- lists = { groups = { numbers }, contacts = { numbers }, nearby = { numbers } }. Returns { { number, why } }.
function Crew.sosRecipients(self, lists, cap)
    local out, seen = {}, { [self] = true }
    for _, why in ipairs({ "groups", "contacts", "nearby" }) do
        for _, n in ipairs(lists[why] or {}) do
            if type(n) == "string" and not seen[n] and #out < (cap or Crew.SOS_MAX) then
                seen[n] = true
                out[#out + 1] = { number = n, why = why }
            end
        end
    end
    return out
end

-- How far zombies hear the SOS ring (sandbox NoiseMultiplier scales it like every other phone noise).
function Crew.sosRadius(noiseMultiplier)
    return Crew.SOS_RADIUS * (noiseMultiplier or 1)
end

-- Command payload checks (registered with Core/Protocol by the server).
local function phoneId(args)
    if type(args.phoneId) ~= "number" then return false, "phoneId must be a number" end
    return true
end

Crew.validators = {
    crewShare = function(args)
        if type(args.on) ~= "boolean" then return false, "on must be a boolean" end
        return phoneId(args)
    end,
    crewFind = phoneId,
    sos = phoneId,
}

return Crew
