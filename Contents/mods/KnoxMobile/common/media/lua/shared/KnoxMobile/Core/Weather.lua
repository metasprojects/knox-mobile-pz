-- Weather and the network (after 0.3.0): a thunderstorm, a downpour or a blizzard costs a bar, and a thunderstorm
-- can drop a call. Sandbox Service > Weather hurts signal. Pure Lua 5.1.
-- w = { thunder = bool, precip = 0..1, snow = bool, wind = 0..1 } (Game/WorldModel.weather reads the game's climate).
local Weather = { HEAVY = 0.6, BLIZZARD_SNOW = 0.4, BLIZZARD_WIND = 0.6 }

-- "thunder", "downpour", "blizzard" or nil.
function Weather.storm(w)
    if not w then return nil end
    local precip = w.precip or 0
    if w.thunder then return "thunder" end
    if w.snow and precip >= Weather.BLIZZARD_SNOW and (w.wind or 0) >= Weather.BLIZZARD_WIND then return "blizzard" end
    if not w.snow and precip >= Weather.HEAVY then return "downpour" end
    return nil
end

function Weather.barsLost(w) return Weather.storm(w) and 1 or 0 end

-- Chance, every ten seconds, that a live call drops: thunder 2 percent, a downpour or blizzard half a percent.
Weather.DROP = { thunder = 0.02, downpour = 0.005, blizzard = 0.005 }
function Weather.dropChance(w)
    local s = Weather.storm(w)
    return s and Weather.DROP[s] or 0
end

-- The phone's bars after the weather: located loses a bar, and at none it has no service. Returns a new table.
function Weather.apply(located, w)
    local lost = Weather.barsLost(w)
    if lost == 0 or not located or not located.network then return located end
    local out = {}
    for k, v in pairs(located) do out[k] = v end
    out.storm = Weather.storm(w)
    out.bars = (located.bars or 0) - lost
    if out.bars <= 0 then out.network, out.bars, out.via = nil, 0, "storm" end
    return out
end

return Weather
