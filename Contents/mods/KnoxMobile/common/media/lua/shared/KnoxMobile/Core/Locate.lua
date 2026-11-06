-- 0.3.0: "Share my location" in Messages. The phone sends "[Loc]"; the server writes where the sender really stands
-- into it ("[Loc:x,y]", so nobody can fake a spot); the thread shows how far and which way it is from you now, and
-- the Map pins the sender there for KEEP_HOURS. Squares are about a metre. Pure Lua 5.1.
local CellSites = require "KnoxMobile/Core/CellSites"

local Locate = {}

Locate.ASK = "[Loc]"   -- what a phone sends
Locate.KEEP_HOURS = 12 -- how long the Map shows a shared spot

-- Is this the phone's ask (or a text that starts with it)? Returns the rest of the text (a note) or nil.
function Locate.isAsk(body)
    local rest = tostring(body or ""):match("^%[Loc%] ?(.*)$")
    return rest
end

-- The text the server sends on: "[Loc:x,y] note".
function Locate.text(x, y, note)
    local s = "[Loc:" .. math.floor(x) .. "," .. math.floor(y) .. "]"
    if note and note ~= "" then s = s .. " " .. note end
    return s
end

-- x, y, note from a shared-location text, or nil.
function Locate.parse(body)
    local x, y, note = tostring(body or ""):match("^%[Loc:(%-?%d+),(%-?%d+)%] ?(.*)$")
    if not x then return nil end
    return tonumber(x), tonumber(y), note
end

-- Distance and direction from (fromX, fromY) to (x, y): metres (whole), and "n", "ne", ... or "here".
function Locate.from(fromX, fromY, x, y)
    local dx, dy = x - fromX, y - fromY
    local m = math.floor(math.sqrt(dx * dx + dy * dy) + 0.5)
    if m < 5 then return m, "here" end
    return m, CellSites.compass(fromX, fromY, x, y)
end

-- "350 m" or "1.2 km".
function Locate.distance(m)
    if m < 1000 then return tostring(math.floor(m / 10 + 0.5) * 10) .. " m" end
    return string.format("%.1f km", m / 1000)
end

-- Is a text from (day, minute) still on the Map at world (day, minute) now?
function Locate.fresh(day, minute, nowDay, nowMinute)
    local age = (nowDay * 1440 + nowMinute) - ((day or 0) * 1440 + (minute or 0))
    return age >= 0 and age <= Locate.KEEP_HOURS * 60
end

return Locate
