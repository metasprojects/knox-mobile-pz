-- 0.3.0: raid warnings. When a hostile group from the Bandits mod comes within reach of a player whose phone has
-- service, someone nearby who saw them texts a warning with the side they're coming from. Once per clan per few game
-- hours. Pure Lua 5.1; server/KnoxMobile/Raids.lua scans for them (Game/Bandits).
local Raids = {}

Raids.RADIUS = 120          -- squares: close enough that a neighbor would have seen them
Raids.COOLDOWN_HOURS = 6    -- per clan, per player

-- {dir}: the side they're on, as a word ("north", Raids.DIRS); {n}: how many, as a word.
Raids.LINES = {
    "[Saw|Just saw] {n} people with rifles on the road {dir} of you. Coming your way. Get inside",
    "Truck full of armed men just went by, headed your way from the {dir}. Lock up",
    "People with guns cutting through the yards {dir} of you. Not the army",
    "Don't open your door tonight. There's a group {dir} of you going house to house",
    "Whoever you are, there's a group coming from the {dir}. They took the Hendersons' truck",
}

Raids.DIRS = { n = "north", ne = "northeast", e = "east", se = "southeast", s = "south", sw = "southwest", w = "west",
    nw = "northwest" }
Raids.COUNTS = { "two", "three", "four", "five", "six" }

function Raids.countWord(n)
    if n <= 1 then return "a couple of" end
    return Raids.COUNTS[math.min(#Raids.COUNTS, n - 1)]
end

-- Group nearby hostile bandits by clan. bandits: { { cid, x, y } }; returns { cid = { n, x, y, d } } with the nearest
-- member's spot (d = distance) for each clan within RADIUS of (px, py).
function Raids.groups(bandits, px, py)
    local out = {}
    for _, b in ipairs(bandits) do
        local dx, dy = b.x - px, b.y - py
        local d = math.sqrt(dx * dx + dy * dy)
        if d <= Raids.RADIUS then
            local key = tostring(b.cid or "?")
            local g = out[key]
            if not g then g = { n = 0, x = b.x, y = b.y, d = d }; out[key] = g end
            g.n = g.n + 1
            if d < g.d then g.x, g.y, g.d = b.x, b.y, d end
        end
    end
    return out
end

-- Is it time to warn this player about this clan again? last: the world hour of the last warning, or nil.
function Raids.ready(last, nowHour) return last == nil or nowHour - last >= Raids.COOLDOWN_HOURS end

return Raids
