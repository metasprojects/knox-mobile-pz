-- The way into a dead person's locked phone (0.2.2). Workshop, 2026-10-24: "the ID cards aren't readable in my game
-- (it just says 'Nothing interesting to read')"; Meta: every locked phone needs a way in that players can find, read
-- and understand. Pure Lua 5.1.
--
-- A clue is { kind, pin, born = "MM/DD/YY" (on a body), number = text (dog tags, badge), tags = "dogtags"/"badge" }:
--   birthday  the PIN is the month and day of the birth date on their ID card ("born 03/14/61" is 0314)
--   note      a note in their wallet (or pocket) with the four digits, in their own words
--   tags      the last four digits of the number on their dog tags, or their badge number
--   tape      the code on the back of the phone: tape, a sticker, scratched into the cover
--   easy      an easy code: 1234, 0000, 1111 or 2580
--   factory   the maker's code from the phone's manual, never changed
--   house     a note somewhere in the house the phone was found in
--   car       a note in the glove box it was found in
--   none      nothing: crack it
-- where: "body" (a zombie), "alife" (an A-Life NPC: nothing is added to that mod's bodies), "house", "car", or
-- "phone" (anything else, and phones from before 0.2.2: the code is on the back).
local Clues = {}

-- Four, so five tries before the lockout cover them all.
Clues.EASY = { "1234", "0000", "1111", "2580" }

-- The makers' codes, printed in their manuals: Motormouth's bricks 0000, Sisu's phones 1234.
Clues.FACTORY = { SegmentLCD = "0000", MonoLCD = "1234", ColorFeature = "1234" }

function Clues.weights(where, opts)
    opts = opts or {}
    if where == "house" then return { { "house", 1 } } end
    if where == "car" then return { { "car", 1 } } end
    if where == "phone" then return { { "tape", 1 } } end
    local factory = Clues.FACTORY[opts.family] ~= nil
    if where == "alife" then
        return { { "tape", 55 }, { "easy", factory and 15 or 25 }, { "factory", factory and 10 or 0 }, { "none", 20 } }
    end
    local tags = opts.tags ~= nil
    return {
        { "birthday", tags and 15 or 35 }, { "tags", tags and 20 or 0 }, { "note", 35 }, { "tape", 10 },
        { "easy", factory and 5 or 10 }, { "factory", factory and 5 or 0 }, { "none", 10 },
    }
end

local function digits(rng) return string.format("%04d", rng:int(0, 9999)) end

-- opts: { family = the phone's screen family, tags = "dogtags"/"badge" when the body wears or carries them }.
function Clues.pick(rng, where, opts)
    opts = opts or {}
    local entries = {}
    for _, e in ipairs(Clues.weights(where, opts)) do if e[2] > 0 then entries[#entries + 1] = e end end
    local kind = rng:weighted(entries) or "none"
    local clue = { kind = kind, pin = digits(rng) }
    if where == "body" then
        -- Everyone on a body has a birth date: it's printed on their ID card whatever the PIN is.
        local month, day, year = rng:int(1, 12), rng:int(1, 28), rng:int(38, 75)
        clue.born = string.format("%02d/%02d/%02d", month, day, year)
        if kind == "birthday" then clue.pin = string.format("%02d%02d", month, day) end
    end
    if kind == "easy" then clue.pin = rng:pick(Clues.EASY) end
    if kind == "factory" then clue.pin = Clues.FACTORY[opts.family] or clue.pin end
    if opts.tags then
        clue.tags = opts.tags
        local last4 = kind == "tags" and clue.pin or digits(rng)
        if opts.tags == "badge" then
            clue.number = last4
        else
            -- 1993 dog tags carry the Social Security number.
            clue.number = string.format("%03d-%02d-%s", rng:int(400, 409), rng:int(10, 99), last4)
        end
    end
    return clue
end

-- What the four digits are, in the words of whoever wrote them down. %1 is the code, %2 the owner's first name.
Clues.NOTES = {
    note = {
        "phone %1",
        "new phone code: %1",
        "PIN %1 - don't lose this one",
        "cell %1 (NOT the bank card)",
        "code for the phone is %1, same as the garage",
        "%1 phone. remember it this time",
    },
    -- On a body whose PIN is their birthday, sometimes: the note points at the ID card.
    birthday = {
        "phone code = my birthday (month, day)",
        "PIN is my bday. month then day",
    },
    house = {
        "%2 - your new phone code is %1. Write it somewhere that ISN'T the fridge.",
        "%2's cell: %1",
        "phone PIN %1 (don't tell your brother)",
        "%2, the code for the phone is %1. Love you.",
        "cell code %1 - same as the alarm",
        "new phone - %1",
    },
    car = {
        "phone %1",
        "cell PIN %1 - leave this in the glove box",
        "%2's phone code %1",
    },
}

Clues.TAPE = {
    "A strip of masking tape on the back, in marker: %1",
    "Scratched into the battery cover: %1",
    "A label on the back: PIN %1",
    "Written on the back in nail polish: %1",
}

function Clues.noteText(rng, kind, pin, first)
    local list = Clues.NOTES[kind] or Clues.NOTES.note
    local text = rng:pick(list)
    return (text:gsub("%%1", pin):gsub("%%2", first or "Hon"))
end

function Clues.tapeText(rng, pin)
    return (rng:pick(Clues.TAPE):gsub("%%1", pin))
end

-- On a body with a birthday PIN, one in three also carries a note that points to the ID card.
Clues.BIRTHDAY_NOTE = 1 / 3

-- The code a clue gives away once a player has read it: { pin, label } (label: what the right-click menu names it
-- by), or nil. From an ID card the birthday is only a guess; it is the PIN when the clue is "birthday".
function Clues.codeFromBorn(born)
    local m, d = tostring(born or ""):match("^(%d%d)/(%d%d)/")
    return m and (m .. d) or nil
end

-- Cracking it the hard way (Actions "crackPin"): the chance with this Electrical level. The right-click menu shows it.
function Clues.crackChance(electrical)
    return math.min(0.9, 0.2 + 0.08 * (tonumber(electrical) or 0))
end

function Clues.codeFromNumber(number)
    return tostring(number or ""):match("(%d%d%d%d)$")
end

return Clues
