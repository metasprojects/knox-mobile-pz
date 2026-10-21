-- Signal bars from distance, antenna, walls and height (spec §7.1). Pure Lua 5.1; distances in tiles.

local Signal = {}

Signal.TOWER_RANGE = 2500   -- tiles a tower reaches with a 1.0 antenna
Signal.UNKNOWN_MAP_BARS = 2 -- unknown or modded maps get medium service everywhere

-- Height: every floor above ground stretches the phone's reach a little, and standing out on a roof (outside, above
-- ground) adds more and has no walls in the way. Scaled by sandbox RoofSignal (0 turns height off).
Signal.FLOOR_BONUS = 0.15   -- extra reach per floor above ground
Signal.ROOF_BONUS = 0.25    -- extra reach out on a roof, on top of the floors
Signal.MAX_FLOORS = 8       -- higher floors add nothing more

-- Reach multiplier (1 or more) for a phone z floors up; onRoof = outside above ground.
function Signal.heightBoost(z, onRoof, multiplier)
    local floors = math.min(math.max(0, math.floor(z or 0)), Signal.MAX_FLOORS)
    if floors == 0 then return 1 end
    local bonus = Signal.FLOOR_BONUS * floors
    if onRoof then bonus = bonus + Signal.ROOF_BONUS end
    return 1 + bonus * math.max(0, multiplier or 1)
end

-- Bars 0..4 at a distance from a source with the given range. A stronger antenna and height (boost, from
-- Signal.heightBoost) stretch the reach. Being indoors (or in a basement) costs one bar.
function Signal.barsAt(distance, range, antenna, indoors, boost)
    local reach = range * (antenna or 1) * (boost or 1)
    if reach <= 0 then return 0 end
    local f = distance / reach
    local bars
    if f < 0.25 then
        bars = 4
    elseif f < 0.5 then
        bars = 3
    elseif f < 0.75 then
        bars = 2
    elseif f <= 1 then
        bars = 1
    else
        bars = 0
    end
    if indoors and bars > 0 then bars = bars - 1 end
    return bars
end

function Signal.distance(x1, y1, x2, y2)
    local dx, dy = x1 - x2, y1 - y2
    return math.sqrt(dx * dx + dy * dy)
end

-- Best bars from a list of sources { id, x, y, range }. Returns bars, source id (nil when no signal).
function Signal.best(x, y, sources, antenna, indoors, boost)
    local bestBars, bestId = 0, nil
    for _, s in ipairs(sources) do
        local bars = Signal.barsAt(Signal.distance(x, y, s.x, s.y), s.range or Signal.TOWER_RANGE, antenna, indoors, boost)
        if bars > bestBars then bestBars, bestId = bars, s.id end
    end
    return bestBars, bestId
end

-- Should the phone suggest climbing? At 0-1 bars indoors, when a higher spot (out on a roof two floors up) would
-- give more bars. barsHigher is what the caller worked out for that spot.
function Signal.suggestHigher(bars, indoors, barsHigher)
    return indoors == true and (bars or 0) <= 1 and (barsHigher or 0) > (bars or 0)
end

return Signal
