-- A Project A-Life NPC's phone (0.2.0): their faction's group chat and their squad mates' texts, from the days after
-- the outbreak up to the moment they died, and the messages nobody answered after. Pure Lua 5.1; Story.fill grammar
-- ([a|b] picks one); slots {faction}, {mate}, {mate2}, {owner}. Never names A-Life's real plans: it reads like a crew
-- talking. Dark things stay implied (docs/lore/KNOX_LORE.md).
local Mod = require "KnoxMobile/Core/Mod"

local FactionChatter = {}

-- The faction's group chat while the owner was alive.
FactionChatter.GROUP = {
    "Patrol leaves at [dawn|first light|dusk]. {mate}, you're on point",
    "Supply run to the [pharmacy|gas station|IGA] tomorrow. Bring every bag you have",
    "Saw [three|a few|a lot] of them by the [creek|tracks|highway]. Stay off that road",
    "{mate} has watch tonight. Nobody else goes past the fence",
    "Somebody's been in the stash. Count everything",
    "Strangers on the west road. Armed. Don't start anything",
    "Trade meet at the [bridge|church|old school] at noon. Ammo, not cash",
    "{mate2} got scratched. Says it's nothing. Keep an eye on them",
    "Generator stays off after dark. They hear it",
    "Two new faces asking to join. We vote tonight",
    "Water's low. Whoever's near the creek, fill the jugs",
    "Radio's dead again. Use these phones while the towers last",
    "Nobody goes out alone. I mean it",
    "Found a car with half a tank on Main. {mate} is siphoning it",
    "The house past the creek has lights at night. Somebody's living there",
    "If anybody sees a [red|white] pickup, that's not us. Hide",
    "We're moving the stash tomorrow. Don't ask where yet",
    "Good haul today. Canned peaches. Don't eat them all, {mate}",
    "Fire on the ridge last night. Not ours",
    "Boards on every downstairs window by tonight",
    "{mate} found a dog. We're keeping it apparently",
    "Somebody left the gate open. Again",
    "Heard engines on the highway. Army or worse. Stay low",
    "Meeting at the fire after dark. Everybody",
}

-- The group chat after the owner stopped answering.
FactionChatter.AFTER = {
    "{owner}, where are you? You were supposed to be back by dark",
    "Anybody seen {owner}?",
    "{owner} went out [this morning|before noon] and didn't come back",
    "{mate}, take {owner}'s watch tonight",
    "Don't go looking for {owner} alone",
    "If {owner} is out there, [the gate's unlocked|we left the porch light on]",
    "We'll go out for {owner} at first light",
    "Stop texting {owner}. Please",
}

-- A squad mate texting the owner directly.
FactionChatter.MATE = {
    alive = { "u on watch tonight or me", "bring the good flashlight", "dont tell the others about the peaches",
        "meet me by the fence after", "you see that pickup earlier?", "save me a spot by the fire",
        "my feet are killing me. trade boots?", "we good after this morning?" },
    after = { "where are you", "come back. we'll figure it out", "they're saying you're gone. tell me they're wrong",
        "i kept your stuff", "answer me", "i'm sorry about what i said" },
}

-- opts: { faction (name), owner (first name), mates (first names, may be empty), firstDay, deathDay, deathMinute,
-- foundAt (minutes, optional) }. Returns { chat = { name, messages }, texts = { { with, name, messages } } }.
function FactionChatter.build(rng, fill, names, opts)
    local mates = opts.mates or {}
    -- A crew member other than the given ones (the speaker, the first mate named): never "Ricardo: Ricardo got
    -- scratched" (PC test 2026-10-23).
    local function mate(skip, skip2)
        local list = #mates > 0 and mates or names
        for _ = 1, 12 do
            local m = rng:pick(list)
            if m ~= skip and m ~= skip2 then return m end
        end
        for _, m in ipairs(list) do if m ~= skip and m ~= skip2 then return m end end
        return rng:pick(list)
    end
    local deathAt = opts.deathDay * 1440 + opts.deathMinute
    local stop = opts.foundAt or (deathAt + 2 * 1440)
    local function ctx(m)
        local first = mate(m)
        return { faction = opts.faction, owner = opts.owner, mate = first, mate2 = mate(m, first) }
    end
    local chat = { name = opts.faction, messages = {} }
    local used = {}
    local function pickFresh(list)
        for _ = 1, 10 do
            local i = rng:int(1, #list)
            if not used[list[i]] then used[list[i]] = true; return list[i] end
        end
        return nil
    end
    -- While they were alive: four to eight messages from the crew, some from the owner.
    for _ = 1, rng:int(4, 8) do
        local t = pickFresh(FactionChatter.GROUP)
        local when = opts.firstDay * 1440 + rng:int(0, math.max(1, deathAt - opts.firstDay * 1440 - 30))
        if t and when < deathAt then
            local from = rng:chance(0.2) and "self" or mate()
            chat.messages[#chat.messages + 1] = { day = math.floor(when / 1440), minute = Mod.floor(when, 1440),
                inbound = from ~= "self", from = from ~= "self" and from or nil, body = fill(rng, t, ctx(from)) }
        end
    end
    -- After: two to four unread.
    for _ = 1, rng:int(2, 4) do
        local t = pickFresh(FactionChatter.AFTER)
        local when = deathAt + rng:int(30, 2 * 1440)
        if t and when < stop then
            local from = mate()
            chat.messages[#chat.messages + 1] = { day = math.floor(when / 1440), minute = Mod.floor(when, 1440),
                inbound = true, unread = true, from = from, body = fill(rng, t, ctx(from)) }
        end
    end
    table.sort(chat.messages, function(a, b) return a.day * 1440 + a.minute < b.day * 1440 + b.minute end)
    -- One squad mate's own conversation with the owner.
    local texts = {}
    if #mates > 0 then
        local who = rng:pick(mates)
        local conv = { with = "mate", name = who, messages = {} }
        for _ = 1, rng:int(2, 4) do
            local when = opts.firstDay * 1440 + rng:int(0, math.max(1, deathAt - opts.firstDay * 1440 - 30))
            if when < deathAt then
                local mine = rng:chance(0.4)
                conv.messages[#conv.messages + 1] = { day = math.floor(when / 1440), minute = Mod.floor(when, 1440),
                    inbound = not mine, body = rng:pick(FactionChatter.MATE.alive) }
            end
        end
        for _ = 1, rng:int(1, 3) do
            local when = deathAt + rng:int(20, 2 * 1440)
            if when < stop then
                conv.messages[#conv.messages + 1] = { day = math.floor(when / 1440), minute = Mod.floor(when, 1440),
                    inbound = true, unread = true, body = rng:pick(FactionChatter.MATE.after) }
            end
        end
        table.sort(conv.messages, function(a, b) return a.day * 1440 + a.minute < b.day * 1440 + b.minute end)
        if #conv.messages > 0 then texts[1] = conv end
    end
    return { chat = chat, texts = texts }
end

return FactionChatter
