-- 0.3.0: Jobs by text. A survivor texts a real request about a real place (Story/Sites: houses, churches, schools,
-- checked against the 42.21 map): bring something they need, or go and see if someone is all right. Accept it in the
-- Jobs app; the place goes on the Map with a deadline in game days. Done in time, they answer, and most pay with a bag
-- they hid at another real place (a survivor stash, Core/Quests); some only thank you, and a few were never honest.
-- Pure Lua 5.1; server/KnoxMobile/Jobs.lua runs them. Darkness stays implied (docs/lore/KNOX_LORE.md).
local Story = require "KnoxMobile/Core/Story"
local Sites = require "KnoxMobile/Story/Sites"
local Names = require "KnoxMobile/Story/Names"

local Jobs = {}

Jobs.KINDS = { "deliver", "check" }
Jobs.DEADLINE_DAYS = { deliver = 3, check = 2 }
Jobs.OFFER_DAYS = 1          -- an offer nobody accepts lapses after a day
Jobs.MAX_OPEN = 3            -- offers and active jobs a player has at once
Jobs.NEAR = { deliver = 6, check = 12 } -- squares from the place that count as "there"
Jobs.REWARD = { stash = 0.7, thanks = 0.2, lie = 0.1 }

-- What a delivery needs: any one item of these types (vanilla, media/scripts/generated/items) does it.
Jobs.NEEDS = {
    { id = "antibiotics", types = { "Base.Antibiotics" }, offers = {
        "It's {giver}. My boy cut his leg and now it's red and hot. If you find antibiotics, bring them to {place}",
        "Need antibiotics. Anything. We're at {place}. Knock three times so we know it's you",
        "Got your number off the board at the store. Do you have antibiotics? {place}. Please" } },
    { id = "painkillers", types = { "Base.Pills" }, offers = {
        "Mama's hip is bad and we're out of pills. Could you bring some to {place}? We'll make it worth it",
        "Anybody have painkillers? Bottle of anything. {place}, back door",
        "My husband can't sleep for the pain. If you find pills, we're at {place}" } },
    { id = "bandages", types = { "Base.Bandage", "Base.Bandaid" }, offers = {
        "Cut my hand open on a window getting in here. Got bandages? {place}",
        "We need bandages, as many as you can spare. {place}. Come round the side",
        "Ran out of clean rags two days ago. Bandages to {place} if you can" } },
    { id = "batteries", types = { "Base.Battery" }, offers = {
        "Our radio's dead and it's all we have for news. Batteries to {place}, if you have any",
        "Need batteries for the flashlight. Nights are long here. {place}",
        "Two batteries. That's all I'm asking. {place}" } },
    { id = "food", types = { "Base.TinnedSoup", "Base.TinnedBeans", "Base.CannedCorn", "Base.CannedChili" }, offers = {
        "The kids haven't eaten since yesterday. Anything in a can. {place}",
        "We're down to crackers. A can of anything would help. {place}",
        "If you have canned food to spare, we're at {place}. I can't go out, my knee's gone" } },
    { id = "sleep", types = { "Base.PillsSleepingTablets" }, offers = {
        "My wife hasn't slept in four days. Every noise wakes her. Sleeping pills, if you find them. {place}",
        "Sleeping pills to {place}. I'll trade whatever I have",
        "The baby sleeps. I don't. Anything to help me sleep, {place}" } },
    { id = "light", types = { "Base.Candle", "Base.Matches", "Base.Lighter" }, offers = {
        "We've been sitting in the dark since the power went. Candles or matches to {place}?",
        "Out of matches. Can't even light the stove. {place}, please",
        "A lighter, a box of matches, anything. {place}. The nights are the worst part" } },
    { id = "cigarettes", types = { "Base.CigarettePack" }, offers = {
        "I know it's dumb. A pack of cigarettes would keep me sane. {place}",
        "Grandpa's out of smokes and he's mean as a snake without them. {place}. Please",
        "Cigarettes. I'll pay in canned peaches. {place}" } },
    { id = "disinfectant", types = { "Base.Disinfectant", "Base.AlcoholWipes" }, offers = {
        "Need something to clean a wound with. Disinfectant, wipes, anything. {place}",
        "My daughter got cut on the fence. Not by one of them, the fence. I need to clean it. {place}",
        "Disinfectant or alcohol wipes to {place}. I'm more scared of infection than anything now" } },
    { id = "boards", types = { "Base.Nails", "Base.DuctTape" }, offers = {
        "We're boarding up the back windows and ran out of nails. {place}",
        "Duct tape or nails, whatever you have. The back door won't hold another night. {place}",
        "Need nails. A box. {place}. We have the boards, just not the nails" } },
    { id = "splint", types = { "Base.Splint" }, offers = {
        "My son fell off the shed roof. His arm's wrong. If you have a splint, {place}",
        "Twisted my ankle bad running from them. A splint would help. {place}",
        "Broke my wrist. Need a splint before it sets crooked. {place}" } },
}

Jobs.CHECK = {
    "My mother wouldn't leave {place}. Can you go see if she's all right? I can't get there",
    "My brother was holed up at {place}. He stopped answering Tuesday. Please just look",
    "We left my dad's dog at {place}. I know. Can you go see?",
    "Our friends were waiting for us at {place}. We never made it. Is anybody there?",
    "My sister's at {place} with her two girls. The phone just rings. Can you look?",
    "My grandmother lives alone at {place}. She doesn't have a phone. Please check on her",
    "There was a light on at {place} last night. Could be our neighbors. Could you see who it is?",
    "My husband went to {place} for supplies yesterday. He hasn't come back",
}

-- After a delivery: a thank-you. After a look: what they hear back, by what the player found (picked by the server).
Jobs.THANKS = {
    "You came. Thank you. I mean it",
    "Got it. God bless you, whoever you are",
    "He's already looking better. Thank you",
    "We won't forget this",
    "I didn't think anyone would come",
    "You're a good person. Stay that way",
}
Jobs.CHECKED = {
    "Thank you for going. Whatever you saw, don't tell me. Not yet",
    "Thank you. I needed somebody to look",
    "So nobody's there. Maybe they made it out. That's what I'm going to believe",
    "Thank you. At least I know now",
    "Thank you. I'll stop waiting by the phone now",
    "I owe you. I won't forget it",
}
Jobs.REWARD_TEXT = {
    "Like I said, it's worth it. We left a bag for you at {place}",
    "There's a bag we hid at {place} before all this. It's yours now",
    "Go to {place}. What's there is yours. We can't carry it anyway",
    "We buried a bag behind {place} before we left. Take it",
}
Jobs.EXPIRED = {
    "Never mind. It's too late",
    "Don't come. We're leaving",
    "Forget it. We managed",
    "You didn't come. It's all right. Nobody comes anymore",
    "It's handled. Don't come",
    "We had to move. Don't go there",
}

local function pick(rng, list) return list[rng:int(1, #list)] end

-- A new job offer for one player. used: { [site id] = true } (places already in this player's jobs and stashes).
-- Returns nil when no place is left. The job: { kind, need (id), types, place = { site, name, town, x, y }, giver,
-- offer (the text), days (deadline once accepted) }.
function Jobs.make(rng, used, kind)
    used = used or {}
    local pool = {}
    for _, s in ipairs(Sites.family) do if not used[s.id] then pool[#pool + 1] = s end end
    if #pool == 0 then return nil end
    local site = pool[rng:int(1, #pool)]
    kind = kind or Jobs.KINDS[rng:int(1, #Jobs.KINDS)]
    local giver = rng:chance(0.5) and pick(rng, Names.female) or pick(rng, Names.male)
    local job = { kind = kind, giver = giver, days = Jobs.DEADLINE_DAYS[kind],
        place = { site = site.id, name = site.name, town = site.town, x = site.x, y = site.y } }
    local slots = { place = site.name, giver = giver }
    if kind == "deliver" then
        local need = pick(rng, Jobs.NEEDS)
        job.need, job.types = need.id, need.types
        job.offer = Story.fill(rng, pick(rng, need.offers), slots)
    else
        job.offer = Story.fill(rng, pick(rng, Jobs.CHECK), slots)
    end
    return job
end

-- How it ends for the player, decided when it's done: "stash" (a bag at another place), "thanks" or "lie" (nothing,
-- and the number goes quiet).
function Jobs.reward(rng)
    local r = rng:next()
    if r < Jobs.REWARD.stash then return "stash" end
    if r < Jobs.REWARD.stash + Jobs.REWARD.thanks then return "thanks" end
    return "lie"
end

function Jobs.doneText(rng, job)
    return Story.fill(rng, pick(rng, job.kind == "check" and Jobs.CHECKED or Jobs.THANKS), { giver = job.giver })
end
function Jobs.rewardText(rng, placeName) return Story.fill(rng, pick(rng, Jobs.REWARD_TEXT), { place = placeName }) end
function Jobs.expiredText(rng) return Story.fill(rng, pick(rng, Jobs.EXPIRED), {}) end

-- Is (x, y) close enough to the job's place to count as being there?
function Jobs.near(job, x, y)
    local p = job and job.place
    if not p then return false end
    local r = Jobs.NEAR[job.kind] or 8
    return math.abs(x - p.x) <= r and math.abs(y - p.y) <= r
end

-- The first item in a list of item types (a container's types, as strings) that a delivery takes, or nil.
function Jobs.matches(job, itemType)
    for _, t in ipairs(job.types or {}) do if t == itemType then return true end end
    return false
end

return Jobs
