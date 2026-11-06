-- 0.3.0: the Pollux 600 instant camera. A film pack is ten shots; each shot slides out as a photo you can keep, give
-- or set down (KnoxMobile.InstantPhoto). With the Java part (ZombieBuddy) the photo is the real picture, square like
-- the film; without it the photo is its caption ("Muldraugh, 2:14 PM, rain"). Pure data and helpers;
-- client/KnoxMobile/InstantCamera.lua is the viewfinder, server/KnoxMobile/InstantPrints.lua loads film and prints.
local Instant = {}

Instant.CAMERA = "KnoxMobile.InstantCamera"
Instant.FILM = "KnoxMobile.InstantFilm"
Instant.PHOTO = "KnoxMobile.InstantPhoto"
Instant.SHOTS = 10         -- a film pack
Instant.NAME_MAX = 80      -- characters of a printed photo's name
-- The picture: square, like the film (Camera.piece crops it to aspect 1).
Instant.SPEC = { w = 320, h = 320, levels = 0, aspect = 1 }

-- Shots left in a camera (its mod data), 0 when it has never had film.
function Instant.shots(md)
    local n = md and tonumber(md.KnoxMobileFilm) or 0
    return math.max(0, math.floor(n))
end

-- A printed photo's name, from what the client sent (its own language): one line, trimmed, never empty.
function Instant.cleanName(name, fallback)
    local s = tostring(name or ""):gsub("[%c]", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if s == "" then s = fallback or "Instant Photo" end
    return s:sub(1, Instant.NAME_MAX)
end

return Instant
