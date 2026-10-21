-- The Photos app on found colour-screen phones (2026-10-12): 2-6 photos from the owner's last weeks: ordinary life in
-- late June, the outbreak's first days, and usually one last photo nobody meant to take. Each has a caption code
-- (Data/Messages.words.Photo: %1 a person, %2 the date) and, when the photo shoot has one, a real picture
-- (Data/StagedPhotos: several per code, picked by the photo's v). Pure Lua 5.1.
local Photos = {}

-- Before the news (June 20 - July 3), the first days (July 4 on), and the last one.
Photos.EARLY = { "birthday", "cookout", "dog", "lake", "car", "spiffos", "porch", "baby", "softball", "graduation" }
Photos.LATE = { "convoy", "grocery", "roadblock", "smoke", "boarded" }
Photos.OMINOUS = { "hallway", "window", "yard", "door", "bite", "pocket", "stairs", "crowd", "carwindow", "kitchen" }
-- How often the last photo is an ominous one (2026-10-20: pick up a zombie's phone and find a spooky photo).
Photos.OMINOUS_CHANCE = 0.75
-- Captions that name someone in the owner's life.
Photos.NAMED = { birthday = true, lake = true, spiffos = true, baby = true, graduation = true }
-- Screen families with a colour screen and a camera roll (2003 and later).
Photos.FAMILIES = { ColorFeature = true, Keyboard = true, Stylus = true, ModernAndroid = true, ModernPear = true }

function Photos.fits(model) return model ~= nil and Photos.FAMILIES[model.family] == true and (model.year or 0) >= 2003 end

local function take(rng, pool)
    return table.remove(pool, rng:int(1, #pool))
end

-- names: people in the owner's life ("Jenna", "Mom"). opts: { lastDay = the day they died (0 = July 9) }.
-- Returns { { code, day, name, v } } oldest first; the last is usually an ominous one taken on their last day. v
-- (1-997) picks one of the code's real pictures, the same one every time.
function Photos.roll(rng, names, opts)
    local lastDay = math.min(0, opts and opts.lastDay or 0)
    local early, late = {}, {}
    for i, c in ipairs(Photos.EARLY) do early[i] = c end
    for i, c in ipairs(Photos.LATE) do late[i] = c end
    local n = rng:int(2, 6)
    local ominous = rng:chance(Photos.OMINOUS_CHANCE)
    local out = {}
    for _ = 1, n - (ominous and 1 or 0) do
        local useLate = lastDay >= -5 and #late > 0 and rng:chance(0.35)
        local code = take(rng, useLate and late or early)
        local day = useLate and rng:int(-5, lastDay) or rng:int(-19, -6)
        out[#out + 1] = { code = code, day = day, name = Photos.NAMED[code] and rng:pick(names) or nil }
    end
    table.sort(out, function(a, b) return a.day < b.day end)
    if ominous then out[#out + 1] = { code = rng:pick(Photos.OMINOUS), day = lastDay } end
    for _, photo in ipairs(out) do photo.v = rng:int(1, 997) end
    return out
end

function Photos.isOminous(code)
    for _, c in ipairs(Photos.OMINOUS) do if c == code then return true end end
    return false
end

-- The calendar date of a story day (0 = July 9 1993): month (6 or 7) and day of the month.
function Photos.date(day)
    local d = 9 + day
    if d >= 1 then return 7, d end
    return 6, 30 + d
end

return Photos
