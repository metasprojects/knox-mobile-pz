-- 0.3.0: the Scanner. 1990s analog phones could pick up other people's calls on their frequencies. On the old phones
-- (Scanner.fits) a listen catches fragments of what's near: a bandit clan's chatter (Core/ClanChatter), the
-- dispatcher on her channel (Core/Dispatch), two voices of a call nearby, or static. Never a whole message: words are
-- lost at both ends. Pure Lua 5.1; server/KnoxMobile/Scanner.lua listens.
local Scanner = {}

Scanner.LAST_YEAR = 1999    -- analog-era phones only
Scanner.RANGE = 300         -- squares a fragment carries
Scanner.KEEP = 6            -- fragments the app keeps

Scanner.NOISE = {
    "Static.",
    "Two voices, too faint to make out.",
    "A dial tone, then nothing.",
    "Somebody counting slowly, then static.",
    "A woman's voice, far away. The words break up.",
}

function Scanner.fits(model)
    return model ~= nil and (model.year or 9999) <= Scanner.LAST_YEAR
        and (model.family == "SegmentLCD" or model.family == "MonoLCD")
end

-- Words split on spaces; a fragment keeps the middle of the line (at least three words) with "..." where it was cut.
function Scanner.fragment(rng, line)
    local words = {}
    for w in tostring(line):gmatch("%S+") do words[#words + 1] = w end
    if #words <= 4 then return "..." .. table.concat(words, " ") .. "..." end
    local drop1 = rng:int(0, math.min(2, #words - 4))
    local drop2 = rng:int(0, math.min(2, #words - 3 - drop1))
    local kept = {}
    for i = 1 + drop1, #words - drop2 do kept[#kept + 1] = words[i] end
    local s = table.concat(kept, " ")
    return (drop1 > 0 and "..." or "") .. s .. (drop2 > 0 and "..." or "")
end

return Scanner
