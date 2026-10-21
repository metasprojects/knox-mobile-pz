-- Calendar helpers for the home-screen clock widgets. Pure Lua 5.1.
local Mod = require "KnoxMobile/Core/Mod"
local Calendar = {}

local OFFSETS = { 0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4 }

-- Day of the week for a date (month 1..12, day 1..31): 1 = Sunday ... 7 = Saturday.
function Calendar.weekday(year, month, day)
    local y = month < 3 and year - 1 or year
    local w = Mod.floor((y + math.floor(y / 4) - math.floor(y / 100) + math.floor(y / 400) + OFFSETS[month] + day), 7)
    return w + 1
end

return Calendar
