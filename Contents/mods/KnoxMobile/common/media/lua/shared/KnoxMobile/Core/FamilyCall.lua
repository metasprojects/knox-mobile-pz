-- Calls to numbers no player has (final test, second pass: "do a mix of all of this to add realism"). Your
-- family pick up now and then while they're still texting, ring out to their voicemail, or the lines are jammed;
-- once their story is over their phone mostly can't be reached (dead, off, out of range) or rings out. Other numbers
-- the world knows (contacts, story senders) ring out or can't be reached. Pure: no game calls.
local FamilyCall = {}

-- Which member a family number belongs to (plan.family = { mom = number, dad = ..., sib = ... }).
function FamilyCall.member(plan, number)
    for m, n in pairs(plan.family or {}) do
        if n == number then return m end
    end
    return nil
end

-- Where a member is by `now` (story days): the stage of their latest text so far ("worry" before any), the day of
-- their last text in the whole plan, and their fate ("dies", "rescued", "goodbye" or "silence").
function FamilyCall.status(plan, member, now)
    local stage, last, fate = nil, 0, "silence"
    for _, m in ipairs(plan.messages or {}) do
        if m.from == member then
            last = math.max(last, m.day)
            if m.day <= now then stage = m.stage end
            if m.stage == "dying" then fate = "dies"
            elseif m.stage == "rescued" then fate = "rescued"
            elseif m.stage == "goodbye" then fate = "goodbye" end
        end
    end
    return stage or "worry", last, fate
end

-- How a call goes, by where they are: weights.
FamilyCall.ODDS = {
    talking = { { "answer", 30 }, { "voicemail", 35 }, { "busy", 20 }, { "unreachable", 15 } },
    dies = { { "unreachable", 60 }, { "voicemail", 40 } },
    rescued = { { "unreachable", 60 }, { "voicemail", 20 }, { "busy", 20 } },
    goodbye = { { "unreachable", 50 }, { "voicemail", 50 } },
    silence = { { "voicemail", 50 }, { "unreachable", 40 }, { "busy", 10 } },
}
FamilyCall.OTHER = { { "voicemail", 45 }, { "unreachable", 45 }, { "busy", 10 } }

-- What they say when they pick up, by the stage of their latest text. " / " splits the call's captions.
-- {label}: their name on your phone (Mom); {first}: their own first name; {you}: your first name; {place}: where
-- the family is.
FamilyCall.ANSWER = {
    worry = {
        "{label}: {you}? Oh thank God. Where are you? / Hello? You're breaking up. / Text me. Texts get through.",
        "{label}: Are you okay? The TV says stay inside and lock the doors. / I can barely hear you. / I love you. Text me.",
        "{label}: I've been calling and calling. Don't go outside. / (the line crackles and goes dead)",
        "{label}: Hey, kiddo. We're okay. The power keeps going out. / Do you have food? Water? / Hello? ...",
        "{label}: Don't hang up! I don't know how long this line lasts. / Stay off the roads. They're blocked. / (static)",
        "{label}: Is that you? I can't hear a thing. / If you can hear me, we're all right. Text, don't call.",
        "{label}: {you}. Okay. Okay. You're alive. / Fill the bathtub while the water's on. / I have to go, the battery.",
        "{label}: Did you eat today? Don't lie to me. / There's soup in the pantry if you get home. / Love you. Bye.",
        "{label}: We heard shooting last night. Over by the school. / Keep your curtains shut at night. / (the call drops)",
        "{label}: I keep trying the house phone. Nothing. / This is the only thing that works now. Keep it charged.",
        "{label}: The neighbors left this morning. Just packed up and went. / Don't open the door for anybody. Promise me.",
        "{label}: Hold on, the dog's barking at something. / ... it's nothing. I think it's nothing. / Text me tonight.",
        "{label}: I went to the IGA. The shelves are empty, {you}. / We've got enough for a week. Then I don't know.",
        "{label}: Your cousin called from Louisville. They're not letting anybody out. / Stay where you are.",
        "{label}: I'm on the roof, it's the only place I get a bar. / Can you hear me? / Good. Good.",
        "{label}: The church opened its doors to anybody who needs it. / We might go there. I'll text you. / (static)",
    },
    gather = {
        "{label}: We're at {place}. Come when it's safe. / Don't call, the lines are jammed. Text.",
        "{label}: {you}! We made it to {place}. / Bring water if you can. Be careful out there.",
        "{label}: We're holed up at {place}. Doors locked. / Come at daylight, not after dark. / Knock and say your name.",
        "{label}: It's crowded at {place} but it's safe. Mostly. / There's room for you. Please come.",
        "{label}: {place}. Remember it. {place}. / Take the back roads. The highway's blocked.",
        "{label}: We moved to {place} last night. / Somebody's got a generator. We're okay. / Hurry if you can.",
        "{label}: I wrote it on the fridge for you too. {place}. / In case your phone dies. / Come find us.",
        "{label}: We're at {place}. Your father boarded the windows. / Bring your blankets. It gets cold at night.",
    },
    sick = {
        "{label}: (coughing) I'm okay, honey. Just a fever. / Don't come here yet. / I need to lie down.",
        "{label}: One of them scratched me. It's nothing. / I'm so tired. Call you tomorrow, okay?",
        "{label}: I'm burning up, {you}. It's just the flu. / Everybody's got it. / Don't worry about me.",
        "{label}: Sorry, I fell asleep. What day is it? / ... okay. Okay. I'll call you later.",
        "{label}: Don't come here. I mean it. / Stay where you are and keep the door locked. / I love you.",
        "{label}: My arm hurts but it's fine. I wrapped it. / Did you eat? / I'm going to rest a little.",
        "{label}: I can't keep anything down. / The others are staying in the other room. It's better. / Talk tomorrow.",
        "{label}: (a long breath) Hi, sweetheart. / I'm just tired. I'm so tired. / Tell me something nice.",
    },
    dying = {
        "{label}: (breathing hard) Don't... don't come here. / Remember the good stuff, okay? / (silence)",
        "{label}: {you}. I wanted to hear you. That's all. / Don't come. Promise. / (the line stays open, then nothing)",
        "{label}: I'm sitting by the window. It's a pretty night. / You were always my favorite. Don't tell. / (silence)",
        "{label}: Remember the lake? The summer you learned to swim? / Think about that, okay? Not this. / (silence)",
    },
    rescued = {
        "{label}: They've got us on a bus. The Army. I don't know where to. / I love you. Stay alive.",
        "{label}: Soldiers came. We're in a truck. They won't say where. / I'll find you. I swear I'll find you.",
        "{label}: We're out! They took us past the fence. / They wouldn't wait. I'm sorry, {you}. I'm so sorry.",
        "{label}: It's a camp. Cots and a tent. They check everybody. / Stay alive. They'll come back for more.",
    },
    goodbye = {
        "{label}: We're leaving. I left you a note at {place}. / I'm sorry. Find us.",
        "{label}: We couldn't wait any longer. There's food at {place}. / We love you. Come find us.",
        "{label}: I left the key where we always do. At {place}. / We had to go. Please understand.",
        "{label}: This is goodbye for now. Not forever. / Look for us. Don't stop looking.",
    },
}

FamilyCall.VOICEMAIL = {
    "Hi, you've reached {first}. I can't get to the phone. Leave a message. / (beep)",
    "This is {first}. Leave your name and number after the beep. / (beep)",
    "{first} here. Well, not here. You know what to do. / (beep)",
}
FamilyCall.GENERIC_VOICEMAIL = "The person you are calling is not available. Please leave a message after the tone. / (beep)"

function FamilyCall.roll(rng, odds)
    local total = 0
    for _, o in ipairs(odds) do total = total + o[2] end
    local r = rng:int(1, total)
    for _, o in ipairs(odds) do
        r = r - o[2]
        if r <= 0 then return o[1] end
    end
    return odds[#odds][1]
end

-- A line from a pool that nobody else in the family has said (plan.callLines: line -> member); once the pool is
-- used up, the member's own earlier lines again, but never the one they said last time (0.1.1: "Mom repeats the
-- same answer word for word"). Each member keeps one voicemail greeting.
local function pickLine(rng, pool, plan, member)
    plan.callLines = plan.callLines or {}
    plan.lastLine = plan.lastLine or {}
    local last = plan.lastLine[member]
    local fresh, own = {}, {}
    for _, line in ipairs(pool) do
        local who = plan.callLines[line]
        if who == nil then fresh[#fresh + 1] = line
        elseif who == member and line ~= last then own[#own + 1] = line end
    end
    local line = rng:pick((#fresh > 0 and fresh) or (#own > 0 and own) or pool)
    plan.callLines[line] = plan.callLines[line] or member
    if pool ~= FamilyCall.VOICEMAIL then plan.lastLine[member] = line end
    return line
end

-- A call to `member` now: kind ("answer", "voicemail", "busy", "unreachable") and, for answer and voicemail, the
-- call's captions. fill(s) puts the names and the place in. Remembers the lines used in plan.callLines.
-- The odds without "busy" (the network congestion option off).
function FamilyCall.withoutBusy(odds)
    local out = {}
    for _, o in ipairs(odds) do if o[1] ~= "busy" then out[#out + 1] = o end end
    return out
end

function FamilyCall.outcome(rng, plan, member, now, fill, noBusy)
    local stage, last, fate = FamilyCall.status(plan, member, now)
    local talking = now <= last + 0.5
    local odds = FamilyCall.ODDS[talking and "talking" or fate] or FamilyCall.ODDS.silence
    if noBusy then odds = FamilyCall.withoutBusy(odds) end
    local kind = FamilyCall.roll(rng, odds)
    if kind == "answer" then
        return kind, fill(pickLine(rng, FamilyCall.ANSWER[stage] or FamilyCall.ANSWER.worry, plan, member))
    elseif kind == "voicemail" then
        plan.greetings = plan.greetings or {}
        plan.greetings[member] = plan.greetings[member] or pickLine(rng, FamilyCall.VOICEMAIL, plan, member)
        return kind, fill(plan.greetings[member])
    end
    return kind, nil
end

return FamilyCall
