-- Your family answers your texts (0.2.3, Meta: "if you were to text your mom at the start of the outbreak she should at
-- least reply for the first couple hours two days"). For the first two days, while a member is still texting you,
-- they answer a few minutes to an hour later: a word on what you said, then a line from where their story is. Texts
-- sent before they answer get one answer. After that your texts wait, unread, on their phone (the family hunt).
-- Pure: no game calls.
local FamilyCall = require "KnoxMobile/Core/FamilyCall"
local Story = require "KnoxMobile/Core/Story"

local FamilyText = {}

FamilyText.DAYS = 2 -- story days after the family's storyline starts
FamilyText.MAX_ASK = 320 -- characters of your texts kept for the answer

-- The day the storyline started: saved on new plans (plan.start); older ones, just before their first text.
function FamilyText.start(plan)
    if plan.start then return plan.start end
    local first
    for _, m in ipairs(plan.messages or {}) do first = math.min(first or m.day, m.day) end
    return (first or 0) - 0.1
end

-- Whether `member` answers a text sent `now` (story days): in the first two days, while they're still texting
-- (like a call's "talking", Core/FamilyCall), and not once their story has turned (dying, rescued, gone).
local ANSWERING = { worry = true, gather = true, sick = true }
function FamilyText.answers(plan, member, now)
    local stage, last = FamilyCall.status(plan, member, now)
    return ANSWERING[stage] == true and now < FamilyText.start(plan) + FamilyText.DAYS and now <= last + 0.5
end

-- How long they take, in story days: minutes at first, up to an hour once the lines are jammed.
function FamilyText.delay(rng, sinceStart)
    local minutes = sinceStart < 0.5 and rng:int(5, 20) or rng:int(15, 60)
    return minutes / 1440
end

-- A text from you to `member` at `now`. Returns true when they'll answer it (plan.asked[member]: { body, due }).
function FamilyText.ask(rng, plan, member, body, now)
    if not (member and FamilyText.answers(plan, member, now)) then return false end
    plan.asked = plan.asked or {}
    local a = plan.asked[member]
    if a then
        a.body = (a.body .. " " .. tostring(body)):sub(-FamilyText.MAX_ASK)
    else
        plan.asked[member] = { body = tostring(body):sub(1, FamilyText.MAX_ASK),
            due = now + FamilyText.delay(rng, now - FamilyText.start(plan)) }
    end
    return true
end

-- A word on what you said, by the words in your texts; the first group that matches answers. needs: one of these
-- words too; unless: none of these. `where` has two lists: before the family has named its place, and after
-- ({place}, filled by the game).
FamilyText.ABOUT = {
    { id = "hurt", words = { "bitten", "bite", "scratched", "scratch", "hurt", "bleeding", "blood", "injured" },
        lines = {
        "Hurt where?? Wash it right now. Hot water and soap, and wrap it tight",
        "What happened? Is it a bite? Tell me it's not a bite",
    } },
    { id = "help", words = { "help", "scared", "afraid", "terrified", "trapped", "panic" }, lines = {
        "Breathe. Get somewhere with a door that locks and stay quiet",
        "I'm right here. Stay away from the windows and keep the lights off",
    } },
    { id = "where", words = { "where", "wya" }, lines = {
        "Still home. [We're not going anywhere till this calms down|The roads are a mess]",
        "Home, with the doors locked. Where else would we be",
    }, told = {
        "We're at {place}. Come in daylight, not after dark",
        "Still at {place}. Knock and say your name",
    } },
    { id = "coming", words = { "coming", "omw", "heading", "driving", "walking" }, lines = {
        "Not in the dark. Wait for daylight and take the back roads",
        "Only if it's safe. Don't you dare take the highway",
    } },
    -- "I'm not okay": the bad news.
    { id = "notOkay", words = { "safe", "ok", "okay", "fine", "alright", "good" }, onlyIfNegated = true, lines = {
        "What's wrong? Talk to me",
        "Not okay how? Are you hurt? Tell me the truth",
    } },
    -- "You okay?": asking about them, not saying you are.
    { id = "askThem", words = { "safe", "ok", "okay", "fine", "alive", "alright" },
        needs = { "you", "u", "yall", "guys", "everyone" }, unless = { "i", "im", "me" }, lines = {
        "We're okay. Scared, but okay",
        "We're fine for now. Are YOU okay? That's what matters",
    } },
    { id = "safe", words = { "safe", "ok", "okay", "fine", "alive", "alright", "good" }, notIfNegated = true, lines = {
        "Oh thank God. I've been sick with worry",
        "Okay. Okay. That's the best thing I've heard all day",
        "Good. Stay that way. Don't take chances",
    } },
    { id = "love", words = { "love", "luv", "miss" }, lines = {
        "Love you too. So much",
        "Miss you like crazy. We'll be together soon",
    } },
    { id = "food", words = { "food", "water", "hungry", "eat", "starving", "thirsty" }, lines = {
        "Eat what you've got and fill every pot with water while it still runs",
        "There's canned stuff in every house. Don't be proud about it",
    } },
}

-- Then a line from where their story is (the stage of their latest text). Parents and the sibling talk differently.
FamilyText.LINES = {
    worry = {
        "Are you somewhere safe? Lock every door",
        "The TV just says stay inside. Nobody knows anything",
        "Keep your phone charged. Text me every few hours, okay?",
        "We're trying to get the radio working",
        "Don't go outside after dark. Please",
        "I keep hearing sirens. [It won't stop|All night]",
        "Calls won't go through. Texts are better",
        "Did you eat today? Don't lie to me",
        "We've got water and canned stuff. We're okay for now",
        "The neighbors aren't answering their door",
        "Stay off the main roads. They're saying the highway's blocked",
        "Fill the tub while the water's still on",
        "Text me when you wake up. I love you",
        "Is anyone with you? Don't be alone if you can help it",
        "The power flickered again. [Writing this by candle|Saving the battery]",
        "Please be careful. I can't lose you",
    },
    sibWorry = {
        "This is insane. Are you seeing the news?",
        "Mom keeps calling me. Text her too ok",
        "Stay inside. I mean it. People are losing it out there",
        "Phone's almost dead. Saving it. Text me later",
        "I saw one up close. Can't stop shaking",
        "Don't do anything stupid. I need you around",
        "Lines are jammed. Texting is the only thing that works",
        "Remember when we thought the end of the world would be cool? It isn't",
    },
    gather = {
        "We're at {place}. Come when it's light",
        "Still at {place}. We're okay here. Bring water if you can",
        "{place}. Remember it. Take the back roads",
    },
    sick = {
        "Sorry, slept all day. The fever's bad. Don't worry",
        "I'm okay. Just tired. So tired",
        "Don't come here yet. I don't want you catching this",
        "My arm's swollen where it got me. Wrapped it. It's fine",
        "Can't keep anything down. Talk tomorrow ok?",
    },
}

local function wordsOf(text)
    local set = {}
    for w in tostring(text):lower():gmatch("%a+") do set[w] = true end
    return set
end

-- A line from a pool, not one this family has already sent when another is left (plan.textLines).
local function pick(rng, pool, plan)
    plan.textLines = plan.textLines or {}
    local fresh = {}
    for _, line in ipairs(pool) do if not plan.textLines[line] then fresh[#fresh + 1] = line end end
    local line = rng:pick(#fresh > 0 and fresh or pool)
    plan.textLines[line] = true
    return line
end

-- "not okay", "isn't safe", "no good": not the good news.
local NEGATIONS = { "not", "no", "isn", "aren", "never", "nothing", "don", "can", "cant" }

-- The answer from `member` to what you sent (asked), at `now`. Keeps "{place}" for the game to fill.
function FamilyText.reply(rng, plan, member, asked, now)
    local stage = FamilyCall.status(plan, member, now)
    local words, about = wordsOf(asked), nil
    local negated = false
    for _, w in ipairs(NEGATIONS) do if words[w] then negated = true end end
    local function any(list)
        for _, w in ipairs(list) do if words[w] then return true end end
        return false
    end
    for _, group in ipairs(FamilyText.ABOUT) do
        local fits = not (group.notIfNegated and negated) and not (group.onlyIfNegated and not negated)
            and (group.needs == nil or any(group.needs)) and not (group.unless and any(group.unless))
        if fits and any(group.words) then about = group; break end
    end
    local parts = {}
    if about then parts[1] = pick(rng, plan.placeTold and about.told or about.lines, plan) end
    -- A word on what you said, and often more; or just how things are.
    if not about or rng:chance(0.6) then
        local pool = FamilyText.LINES.worry
        if stage == "sick" then pool = FamilyText.LINES.sick
        elseif plan.placeTold and (stage == "gather" or rng:chance(0.3)) then pool = FamilyText.LINES.gather
        elseif member == "sib" then pool = FamilyText.LINES.sibWorry end
        parts[#parts + 1] = pick(rng, pool, plan)
    end
    for i, p in ipairs(parts) do
        p = Story.fill(rng, p, {})
        if i < #parts and not p:find("[%.%?!]$") then p = p .. "." end
        parts[i] = p
    end
    return table.concat(parts, " ")
end

-- Answers due by `now`: { { member, body } }, oldest first; they're no longer pending.
function FamilyText.due(rng, plan, now)
    local out = {}
    for member, a in pairs(plan.asked or {}) do
        if a.due <= now then out[#out + 1] = { member = member, due = a.due, asked = a.body } end
    end
    table.sort(out, function(x, y) return x.due < y.due end)
    for _, r in ipairs(out) do
        plan.asked[r.member] = nil
        r.body = FamilyText.reply(rng, plan, r.member, r.asked, now)
    end
    return out
end

return FamilyText
