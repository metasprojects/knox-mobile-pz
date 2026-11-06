-- Knox Mobile's traits (0.3.0). Defined in scripts/KnoxMobile/KnoxMobile_Traits.txt and registered in
-- media/registries.lua (both written by tools/gen from Build.TRAITS):
--   Chatterbox   calls and texts with real people lift the mood twice as much; long calls ease stress too.
--   Tinkerer     phone work (cracking a PIN, repairs) as if three Electrical levels higher. The Cell Tower
--                Technician gets it free as tinkerer_prof.
--   Technophobe  phone work as if two levels lower, and phone games do nothing for boredom.
local Traits = {
    CHATTERBOX = "knoxmobile:chatterbox",
    TINKERER = "knoxmobile:tinkerer",
    TINKERER_PROF = "knoxmobile:tinkerer_prof",
    TECHNOPHOBE = "knoxmobile:technophobe",
    TINKERER_LEVELS = 3,
    TECHNOPHOBE_LEVELS = 2,
}

-- The game's CharacterTrait for an id, looked up once (false when this build has no such trait).
local found = {}
local function trait(id)
    if found[id] == nil then
        found[id] = false
        if CharacterTrait and CharacterTrait.get and ResourceLocation and ResourceLocation.of then
            local ok, t = pcall(function() return CharacterTrait.get(ResourceLocation.of(id)) end)
            if ok and t then found[id] = t end
        end
    end
    return found[id] or nil
end

function Traits.has(player, id)
    local t = player and trait(id)
    if not t then return false end
    local ok, has = pcall(function() return player:hasTrait(t) end)
    return ok and has == true
end

function Traits.tinkerer(player)
    return Traits.has(player, Traits.TINKERER) or Traits.has(player, Traits.TINKERER_PROF)
end

-- The Electrical level a player works on phones at, from their real level.
function Traits.phoneSkill(player, level)
    local l = tonumber(level) or 0
    if Traits.tinkerer(player) then
        l = l + Traits.TINKERER_LEVELS
    elseif Traits.has(player, Traits.TECHNOPHOBE) then
        l = l - Traits.TECHNOPHOBE_LEVELS
    end
    return math.max(0, math.min(10, l))
end

-- How much a mood lift counts: "talk" (calls and texts with people), "games" (Snake, Brick Stack).
function Traits.moodScale(player, source)
    if source == "talk" and Traits.has(player, Traits.CHATTERBOX) then return 2 end
    if source == "games" and Traits.has(player, Traits.TECHNOPHOBE) then return 0 end
    return 1
end

-- Mood lifts, as { stat = amount to take away } (Client.mood applies them): a call of `seconds` of real time,
-- and a game played for `seconds`.
function Traits.callRelief(player, seconds)
    local minutes = math.max(0, tonumber(seconds) or 0) / 60
    local scale = Traits.moodScale(player, "talk")
    local out = { BOREDOM = math.min(20, math.floor(minutes * 5 + 0.5)) * scale }
    out.UNHAPPINESS = math.floor(out.BOREDOM / 2)
    -- A Chatterbox on the phone a good while (two minutes or more) calms down.
    if scale > 1 and minutes >= 2 then out.STRESS = 0.1 end
    return out
end

function Traits.gameRelief(player, seconds)
    local minutes = math.max(0, tonumber(seconds) or 0) / 60
    return { BOREDOM = math.min(30, math.floor(minutes * 6 + 0.5)) * Traits.moodScale(player, "games") }
end

return Traits
