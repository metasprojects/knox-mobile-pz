-- The ringtone composer (0.2.0), the way the 2000-era Sisus did it: a tune typed as notes, "8e2 8d#2 4c2 8- 2a1".
-- Each note is [length][note][#][octave][.]: length 1 2 4 8 16 32 (a whole note to a 32nd, default 4), a note a-g or
-- "-" for a rest, # for sharp, octave 1-3 (default 2), a dot for half as long again. Pure Lua 5.1.
local Composer = {}

Composer.MAX_NOTES = 48
Composer.TEMPO = 125 -- quarter notes a minute
-- Beethoven's Für Elise, the opening: public domain, and on half the phones of 1999.
Composer.DEFAULT = "16e3 16d#3 16e3 16d#3 16e3 16b2 16d3 16c3 8a2 16- 16c2 16e2 16a2 8b2 16- 16e2 16g#2 16b2 8c3"

local SEMI = { c = 0, d = 2, e = 4, f = 5, g = 7, a = 9, b = 11 }
local NAMES = { "c", "cs", "d", "ds", "e", "f", "fs", "g", "gs", "a", "as", "b" }
local LENGTHS = { ["1"] = true, ["2"] = true, ["4"] = true, ["8"] = true, ["16"] = true, ["32"] = true }

-- The tune as { { sound (nil for a rest), ms } }, or nil and why ("empty", "tooLong", or the token that is wrong).
function Composer.parse(text)
    local out = {}
    for token in tostring(text or ""):lower():gmatch("%S+") do
        local len, name, sharp, octave, dot = token:match("^(%d*)([a-g%-])(#?)(%d?)(%.?)$")
        if not name or (len ~= "" and not LENGTHS[len]) or (octave ~= "" and (tonumber(octave) < 1 or tonumber(octave) > 3)) then
            return nil, token
        end
        if name == "-" and sharp ~= "" then return nil, token end
        local ms = 4 / tonumber(len ~= "" and len or "4") * 60000 / Composer.TEMPO
        if dot ~= "" then ms = ms * 1.5 end
        local sound
        if name ~= "-" then
            local semi = SEMI[name] + (sharp ~= "" and 1 or 0)
            local oct = tonumber(octave ~= "" and octave or "2")
            if semi == 12 then semi, oct = 0, oct + 1 end -- b# is the next c
            if oct > 3 then return nil, token end
            sound = "KnoxMobileNote_" .. NAMES[semi + 1] .. oct
        end
        out[#out + 1] = { sound = sound, ms = math.floor(ms + 0.5) }
        if #out > Composer.MAX_NOTES then return nil, "tooLong" end
    end
    if #out == 0 then return nil, "empty" end
    return out
end

-- How long the tune plays, in ms.
function Composer.length(notes)
    local total = 0
    for _, n in ipairs(notes) do total = total + n.ms end
    return total
end

return Composer
