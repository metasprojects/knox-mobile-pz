-- Texting back (0.2.0): put a SIM in a found phone and you can answer its dead owner's people. Who is still out there
-- is decided once per person (from the phone and who they are): some answer, some never do, some numbers bounce. Those
-- who answer go from hope, to knowing, to letting go, and one in two then points you to a bag they had to leave at a
-- real place (a survivor stash, server TextBack.lua). A dead A-Life NPC's squad mate answers in another way. The darkest
-- part is never said. Pure Lua 5.1.
local Replies = {}

local function fill(text, ctx)
    return (text:gsub("{(%a+)}", function(k) return ctx[k] or k end))
end

-- The story threads that can be answered (Core/Story's family keys, the friend, work; FactionChatter's mate).
Replies.ROLES = { mom = true, dad = true, grandma = true, sib = true, partner = true, friend = true, work = true,
    mate = true, kid = true, grandpa = true }

Replies.BOUNCE = "KNOX MOBILE: Message not delivered. The number you are texting can't be reached."

Replies.FAMILY = {
    -- 1: hope
    { "{owner}?? Oh thank God. Where are you", "{owner} is that you? Call me. Please call me",
        "Oh my God. {owner}. Are you ok? Are you hurt?", "Finally. Where ARE you? Are you safe?",
        "{owner}! We've been texting for days. Where are you", "Is this {owner}? Please say it's you" },
    -- 2: knowing
    { "Why won't you call. This isn't {owner}, is it.", "Who is this. Why do you have {owner}'s phone.",
        "Please just tell me. Is {owner} alive?", "You're not {owner}. {owner} never writes like that.",
        "I need you to tell me the truth. Where did you find this phone." },
    -- 3: letting go
    { "Ok. Thank you for telling me. I think I knew.", "I'm not going to ask how. Please don't tell me how.",
        "Thank you for keeping it on. I needed to know.", "Ok. Ok. I'm going to sit down for a while.",
        "I knew when the texts stopped going through. Thank you for being honest." },
    -- 4+: someone to talk to
    { "Are you still there?", "Keep the phone charged if you can. I like seeing it go through.",
        "Tell me something about where you are. Anything.", "Still here. Still breathing. You?",
        "I read the old messages every night.", "Be careful out there. I mean it.",
        "Did you find anything of {owner}'s? You don't have to answer." },
}
Replies.WORK = { "{owner}? Is that you? Nobody's heard from anyone at work.",
    "{owner}, if you get this, don't come in. There's nothing left to come in to." }
Replies.MATE = {
    { "Who is this.", "That's not {owner}.", "Who's on {owner}'s phone." },
    { "Where'd you get that phone.", "That's {owner}'s phone. Where'd you get it.", "You were there when it happened?" },
    { "Keep it. We know what it sounds like when it rings.", "We'll find you.", "Don't text this number again." },
}
-- After letting go: the bag ({place}), said by family or the friend.
Replies.STASH = { "We left a bag at {place} on the way out. Take it. Somebody should have it.",
    "There's a bag at {place}. We couldn't carry it. It's yours.",
    "If you're near {place}, we hid a bag there. Take it. Don't be a hero about it." }

-- After letting go, family and the friend say where home was ({home}: a real house): leave the phone there.
Replies.HOME = { "Our house was {home}. If you ever pass it, would you leave the phone there? It should be home.",
    "{owner} lived at {home}. Leave the phone there if you can. I'd like to think of it there.",
    "If you're ever by {home}, that was ours. Put the phone inside. Please.",
    "One thing. {home}. That's home. If you're near it, take the phone back for me." }
Replies.HOME_ROLES = { mom = true, dad = true, grandma = true, grandpa = true, sib = true, partner = true, kid = true,
    friend = true }
Replies.HOME_RADIUS = 12 -- tiles from the house's point: anywhere inside or at the door
Replies.HOME_CHANCE = 0.15 -- rare: most who let go never say where home was

function Replies.nearHome(home, x, y)
    return type(home) == "table" and tonumber(home.x) ~= nil and math.abs(x - home.x) <= Replies.HOME_RADIUS
        and math.abs(y - home.y) <= Replies.HOME_RADIUS
end

function Replies.home(rng, ctx) return fill(rng:pick(Replies.HOME), ctx) end

-- Who is still out there for this thread: "alive", "silent" or "bounce". rng is seeded per phone and thread.
function Replies.fate(rng, with)
    if with == "mate" then return "alive" end
    local r = rng:int(1, 100)
    if r <= 45 then return "alive" elseif r <= 80 then return "silent" end
    return "bounce"
end


-- The reply to the player's n-th answered text (1-based), or nil when they have stopped answering.
-- ctx: { owner, place (optional: the stash's name) }. Returns body, stash (true when this one names the bag).
function Replies.next(rng, with, n, ctx)
    if with == "mate" then
        local step = Replies.MATE[n]
        return step and fill(rng:pick(step), ctx) or nil
    end
    if n == 1 and with == "work" then return fill(rng:pick(Replies.WORK), ctx) end
    if n <= 3 then return fill(rng:pick(Replies.FAMILY[n]), ctx) end
    if n == 4 and ctx.place then return fill(rng:pick(Replies.STASH), ctx), true end
    if n <= 7 then return fill(rng:pick(Replies.FAMILY[4]), ctx) end
    return nil
end

-- Game minutes before the answer: fast while there is hope, slower after.
function Replies.delay(rng, n)
    if n == 1 then return rng:int(2, 25) end
    return rng:int(10, 120)
end

return Replies
