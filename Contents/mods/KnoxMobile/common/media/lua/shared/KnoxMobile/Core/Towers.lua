-- Cell towers dying after the grid goes down (spec §7.1, §7.2). Pure Lua 5.1; days are in-game days.
-- A tower's death day comes from the world seed and its id, so every client and the server agree,
-- and a mid-game install starts in the state that fits the current day (spec §13.5).

local Rng = require "KnoxMobile/Core/Rng"

local Towers = {}

-- settings: { serviceCollapse = "Never"|"WithGrid"|"DaysAfterGrid"|"FixedDay", serviceCollapseDays, gradualCollapse }
-- gridOffDay: the day the power grid shuts off, or nil if it never does. Returns nil if the tower never dies.
function Towers.deathDay(site, settings, worldSeed, gridOffDay)
    local mode = settings.serviceCollapse
    local days = settings.serviceCollapseDays or 7
    if mode == "Never" then return nil end
    local final, window
    if mode == "FixedDay" then
        final, window = days, math.min(days, 7)
    else
        if gridOffDay == nil then return nil end
        if mode == "WithGrid" then
            if not settings.gradualCollapse then return gridOffDay end
            final, window = gridOffDay + 1, 1
        else -- DaysAfterGrid
            final, window = gridOffDay + days, days
        end
    end
    if not settings.gradualCollapse then return final end
    -- Gradual: rural towers die in the first half of the window, town towers in the second half.
    local half = window / 2
    local start = final - window
    local roll = Rng.new(tostring(worldSeed) .. ":" .. tostring(site.id)):next()
    if site.rural then return start + roll * half end
    return start + half + roll * half
end

function Towers.isAlive(site, nowDay, settings, worldSeed, gridOffDay)
    local d = Towers.deathDay(site, settings, worldSeed, gridOffDay)
    return d == nil or nowDay < d
end

-- Early-outbreak "All circuits are busy" chance for a call (sandbox NetworkCongestion).
function Towers.congestionChance(nowDay, settings)
    if not settings.networkCongestion then return 0 end
    if nowDay < 3 then return 0.3 end
    if nowDay < 7 then return 0.15 end
    return 0.05
end

function Towers.callFails(rng, nowDay, settings)
    return rng:chance(Towers.congestionChance(nowDay, settings))
end

return Towers
