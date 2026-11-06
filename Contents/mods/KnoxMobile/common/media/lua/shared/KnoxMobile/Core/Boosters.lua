-- 0.3.0: the home signal booster. Set down at a base and given power (the grid, or a generator's reach), it carries
-- the outside signal in: within RADIUS squares, on any floor, being indoors costs no bar. It makes no signal of its
-- own: with no tower in reach outside, there's nothing to carry in. Pure Lua 5.1; server/KnoxMobile/Boosters.lua
-- keeps them, and they reach clients with the world message (KnoxMobile.world.boosters).
local Boosters = {}

Boosters.RADIUS = 15

-- Is (x, y) inside a powered booster's reach? list: { { x, y, powered } }.
function Boosters.covers(list, x, y)
    for _, b in ipairs(list or {}) do
        if b.powered and math.abs(x - b.x) <= Boosters.RADIUS and math.abs(y - b.y) <= Boosters.RADIUS then
            return true
        end
    end
    return false
end

-- What clients get: where and whether it's on (no owner).
function Boosters.publicCopy(list)
    local out = {}
    for i, b in ipairs(list or {}) do out[i] = { id = b.id, x = b.x, y = b.y, z = b.z, powered = b.powered == true } end
    return out
end

return Boosters
