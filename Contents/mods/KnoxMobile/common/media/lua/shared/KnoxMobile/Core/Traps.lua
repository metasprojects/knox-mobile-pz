-- Trap texts (after 0.3.0): a "rescue" text that leads to an ambush. The words carry tells (come alone, bring what you
-- can carry, tell no one) for the careful; now and then a neighbor warns. Pure Lua 5.1; Story.fill grammar.
local Story = require "KnoxMobile/Core/Story"

local Traps = { FIRST_DAY = 2, LAST_DAY = 30, MAX = 2, CHANCE_PER_HOUR = 0.02, WARN_CHANCE = 0.4 }

Traps.BAIT = {
    "This is the [Knox|Kentucky] relief convoy. Food, medicine, beds. Pickup at {place} [tonight|at first light]. Come "
        .. "alone and bring what you can carry, we can't feed people who show up with nothing.",
    "Survivor camp taking people in. Our truck stops at {place} [tonight|tomorrow morning]. Tell no one, we don't have "
        .. "room for everyone.",
    "National Guard volunteers. Evac point at {place}, [one trip only|last run]. Bring your guns and supplies, everything "
        .. "gets pooled at the camp.",
    "[We saw your light last night.|Got your number off a board in town.] We have a doctor and a generator. Meet at "
        .. "{place}. Come alone the first time, you understand why.",
}

Traps.WARN = {
    "Don't go to {place}. That convoy text is a setup. They took everything Mike had and left him there.",
    "If you got a text about a rescue at {place}, it's a trap. Nobody is coming. Stay away.",
    "Whoever is texting about {place}: my brother went. He never came back. Don't.",
}

Traps.AFTER = { "Thanks for coming.", "[Should've|Shouldn't have] come alone.", "You came. Good." }

-- A clan that locked onto a phone left on (server/ClanTrace.lua).
Traps.TRACE = { "Found you.", "Your phone talks too much.", "[Nice|Cute] little phone. We can hear it from here.",
    "Stay where you are. We're coming to you." }

-- Who waits there: the ones who set it (and turned) among the ones who fell for it before you.
Traps.TRAPPERS = { "Bandit", "Bandit_Mid", "Redneck", "Biker" }
Traps.VICTIMS = { "Evacuee", "Generic01", "Generic02", "Generic05" }

function Traps.bait(rng, place) return Story.fill(rng, rng:pick(Traps.BAIT), { place = place }) end
function Traps.warning(rng, place) return Story.fill(rng, rng:pick(Traps.WARN), { place = place }) end
function Traps.after(rng) return Story.fill(rng, rng:pick(Traps.AFTER), {}) end

function Traps.outfits(rng)
    local out = {}
    for _ = 1, rng:int(3, 4) do out[#out + 1] = rng:pick(Traps.TRAPPERS) end
    for _ = 1, rng:int(2, 3) do out[#out + 1] = rng:pick(Traps.VICTIMS) end
    return out
end

-- May one come this hour? day: days since the outbreak; sent: how many this player has had.
function Traps.due(rng, day, sent)
    return day >= Traps.FIRST_DAY and day <= Traps.LAST_DAY and (sent or 0) < Traps.MAX and rng:chance(Traps.CHANCE_PER_HOUR)
end

return Traps
