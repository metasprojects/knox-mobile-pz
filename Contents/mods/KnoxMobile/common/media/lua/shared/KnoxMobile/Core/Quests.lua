-- Survivor text quests (2026-10-12): some strangers' texts point to a stash at a real pharmacy, gas station or police
-- station (Story/Sites quests) with a short story. What is really there is decided with the text: a small bag of what
-- the text says plus a few zombies, or a trap (sandbox QuestTrapChance): many more of them, or the survivor dead by a
-- picked-over bag. Pure Lua 5.1; server/KnoxMobile/Quests.lua places it when the place's chunk loads.
local Sites = require "KnoxMobile/Story/Sites"
local Names = require "KnoxMobile/Story/Names"
local Templates = require "KnoxMobile/Story/Templates"
local Story = require "KnoxMobile/Core/Story"

local Quests = {}

-- Vanilla items (media/scripts/generated/items) with weights; nothing that needs filling with a fluid.
Quests.LOOT = {
    pharmacy = { { "Base.Pills", 3 }, { "Base.PillsAntiDep", 2 }, { "Base.PillsBeta", 2 }, { "Base.PillsVitamins", 2 },
        { "Base.PillsSleepingTablets", 1 }, { "Base.Antibiotics", 2 }, { "Base.Bandage", 3 }, { "Base.Bandaid", 3 } },
    gas = { { "Base.TinnedBeans", 3 }, { "Base.TinnedSoup", 3 }, { "Base.CannedChili", 2 }, { "Base.CannedCorn", 2 },
        { "Base.BeefJerky", 2 }, { "Base.Crisps", 2 }, { "Base.Battery", 3 }, { "Base.Matches", 1 }, { "Base.Lighter", 1 } },
    police = { { "Base.ShotgunShells", 4 }, { "Base.Bullets9mmBox", 3 }, { "Base.Bullets38Box", 2 }, { "Base.Bandage", 2 },
        { "Base.Pistol", 1 }, { "Base.Vest_BulletPolice", 1 } },
}
-- The bag the texts talk about.
Quests.BAG = { pharmacy = "Base.Bag_Satchel", gas = "Base.Bag_DuffelBag", police = "Base.Bag_Police" }
-- Who is still there (vanilla outfits in both clothing lists): staff, and passers-by.
Quests.OUTFITS = {
    pharmacy = { "Pharmacist", "Pharmacist", "Generic02", "Generic03" },
    gas = { "Gas2Go", "Fossoil", "Generic01", "Generic05" },
    police = { "Police", "Police", "Generic01", "Evacuee" },
}

-- n quest texts for one player, each about a different site not in `used` ({ [site id] = true }, the places their
-- other survivor texts name). opts: { startDay, endDay, trapChance = 0..100 }. Returns survivor-text entries
-- ({ day, body, kind = "quest", place, sender, payoff, quest }) with quest = { site, kind, name, town, x, y, trap,
-- loot = { item types }, outfits = { one per zombie } }; trap is nil, "horde" or "dead".
function Quests.make(rng, n, opts)
    local used = opts.used or {}
    local pool = {}
    for _, s in ipairs(Sites.quests) do if not used[s.id] then pool[#pool + 1] = s end end
    local out = {}
    for _ = 1, math.min(n, #pool) do
        local site = table.remove(pool, rng:int(1, #pool))
        local sender = rng:pick(rng:chance(0.5) and Names.female or Names.male)
        local body = Story.fill(rng, rng:pick(Templates.quest[site.kind]), { place = site.name, sender = sender })
        local trap = nil
        if rng:chance((opts.trapChance or 0) / 100) then trap = rng:chance(0.5) and "horde" or "dead" end
        local loot = {}
        for _ = 1, (trap == "dead" and rng:int(1, 2) or rng:int(3, 5)) do loot[#loot + 1] = rng:weighted(Quests.LOOT[site.kind]) end
        local outfits = {}
        for _ = 1, (trap == "horde" and rng:int(6, 9) or rng:int(2, 3)) do outfits[#outfits + 1] = rng:pick(Quests.OUTFITS[site.kind]) end
        out[#out + 1] = {
            day = rng:range(opts.startDay, opts.endDay), body = body, kind = "quest", sender = sender, payoff = true,
            place = { name = site.name, town = site.town, site = site.id },
            quest = { site = site.id, kind = site.kind, name = site.name, town = site.town, x = site.x, y = site.y,
                trap = trap, loot = loot, outfits = outfits },
        }
    end
    return out
end

return Quests
