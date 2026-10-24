-- Voicemails put together from parts (0.2.0, Meta 2026-10-21: "you could walk around in one city and ... read all
-- the voicemails"). A message is a greeting in the caller's voice, one or two things that happened (fitting the
-- day), a request and a sign-off, so every answering machine and every dead phone's mailbox says something of its
-- own. Pure Lua 5.1; Story.fill grammar ([a|b] picks one); slots {name} (who the message is for), {caller}, {town}.
-- Dark things stay implied (docs/lore/KNOX_LORE.md).
local Voicemail = {}

-- Greetings by who calls. Spoken, not typed.
Voicemail.GREET = {
    mom = { "Hi {name}, it's Mom.", "Honey, it's me.", "{name}, it's your mother.", "It's Mom. Pick up if you're there.",
        "Hi sweetheart, it's me.", "{name}? It's Mom. Are you there?" },
    dad = { "{name}, it's Dad.", "It's your father.", "Hey, it's Dad. Pick up.", "This is Dad.", "{name}. Dad." },
    grandma = { "{name}, this is Grandma. I hope I'm doing this right.", "It's Grandma, honey.",
        "Hello? {name}? It's your grandmother.", "Hi baby, it's Grandma." },
    sib = { "hey, it's me.", "{name}. it's me. pick up.", "it's me again.", "hey. it's your favorite sibling." },
    partner = { "It's me.", "Hey. It's me.", "Baby, it's me.", "{name}, it's me. Please pick up.", "Hi. It's me again." },
    friend = { "Hey {name}, it's {caller}.", "{name}! It's {caller}.", "It's {caller}. You there?", "Yo, it's {caller}.",
        "Hey, it's {caller}. Pick up, pick up." },
    work = { "{name}, this is {caller} at work.", "Message for {name}. This is {caller}.", "Hi, it's {caller} from work.",
        "{name}, {caller} here." },
    neighbor = { "Hi {name}, it's {caller} from next door.", "{name}, it's {caller}, your neighbor.",
        "Hey there, it's {caller} across the street." },
}

-- What happened, by when. Each message takes one, sometimes two.
Voicemail.BODY = {
    normal = {
        "The [heat|humidity] is something today. I hope you're keeping cool.",
        "Your [cousin|aunt] called asking about the Fourth. I said we'd do the usual.",
        "I found that [casserole dish|cooler] you were looking for. It was in the garage the whole time.",
        "The [car|truck] is making that noise again. I'm not touching it till Sunday.",
        "We're doing burgers Sunday after church. Nothing fancy.",
        "I saw your old teacher at the IGA. She asked about you. I said you're doing real good.",
        "The tomatoes are coming in. I've got more than I know what to do with.",
        "I paid the phone bill so don't worry about it this month.",
        "The [dog|cat] got into the trash again. Just so you know.",
        "We're thinking about the lake next weekend if the weather holds.",
        "Somebody said the plant's hiring for second shift. Thought of you.",
        "I'm making a run to {town} tomorrow if you need anything.",
        "The church needs help setting up for the supper Wednesday.",
        "Your [brother|sister] says hi. Well, sort of. They grunted.",
        "There's a sale on fans at the hardware. Might be worth it, this heat.",
        "I heard there's a flu going around Louisville. Wash your hands.",
        "The fireworks are at the river this year. We'll save you a spot.",
        "I left your mail on the kitchen table.",
    },
    news = {
        "Are you watching the news? I don't know what to make of it.",
        "They're saying the hospitals in Louisville are full. Full! Can you believe it?",
        "The IGA was out of [bottled water|bread] when I got there. People are buying everything.",
        "They cancelled the fireworks. Some people already left the river.",
        "The church opened its doors tonight for anybody who needs a place.",
        "There were sirens going all night. I didn't sleep a wink.",
        "Your father filled the tub and every pot we have, just in case.",
        "Somebody on the radio said stay inside tonight. So we're staying inside.",
        "I keep getting a busy signal. I don't know if this'll even go through.",
        "The man down the road said there was trouble at the gas station. Somebody got hurt.",
        "We saw Army trucks on the highway. A lot of them.",
        "The TV keeps saying don't panic. That's what's making me panic.",
        "Everybody's talking about the flu but nobody's saying what it really is.",
        "We're all right here. I just want to hear your voice.",
    },
    closure = {
        "They closed the roads this morning. Soldiers at the bridge, turning everybody around.",
        "The phone's been acting funny all day. If this cuts off, I love you.",
        "Nobody's going anywhere. They put a fence up out by the highway.",
        "We're staying at the church. There's room if you need it.",
        "The power keeps flickering. We've got the lamps out.",
        "There's a curfew now. After dark nobody's supposed to be out.",
        "The neighbors left last night. Just packed the car and went.",
        "I heard shooting by the school last night. It's probably nothing.",
        "We're running low on [milk|bread] but we'll make do.",
        "Some people are saying the Army will bring supplies. I'll believe it when I see it.",
        "I put your name on the list at the church so they know you're with us.",
        "If you can't get here, stay where you are. Lock the doors.",
    },
    after = {
        "I've been calling all day.",
        "I don't know if you're getting these.",
        "Your [car|truck] is still in the drive. I don't understand.",
        "Somebody said they saw you at the [gas station|IGA]. Was it you?",
        "I went by your place. The door was open. I didn't go in.",
        "I kept your dinner in the oven. I'll keep it there.",
        "The phone just rings and rings.",
        "Your [mother|father] is worried sick. So am I.",
        "We're at the church now. They have a list. Your name's not on it yet.",
        "I fed your [dog|cat]. Don't worry about that.",
        "It's getting dark again.",
        "I'm not mad. Whatever it is, I'm not mad.",
        "(a long pause) I'm still here.",
        "The power went out an hour ago. I'm calling while I can.",
        "I keep thinking you'll just walk in.",
        "They say not to go out after dark, so I'm going to wait for you here.",
    },
}

-- What a boss or coworker says instead (work talks shifts, not family).
Voicemail.WORK = {
    normal = {
        "We need someone to cover [Saturday|Sunday]. Time and a half.",
        "The schedule for next week is posted. You're on [mornings|nights].",
        "Your check is in the office if you want it before the weekend.",
        "The truck's coming early tomorrow. We need you at six.",
        "Somebody called in sick again. Can you come in tonight?",
        "Don't forget the safety meeting [Monday|Wednesday].",
    },
    news = {
        "We're closing early today. Don't come in after three.",
        "Corporate says keep the doors open, but I'm not making anybody come in.",
        "Half the crew didn't show up today. If you can come in, come in.",
        "They're saying stay home, so stay home. We'll sort out the hours later.",
    },
    closure = {
        "We're closed until further notice. Don't come in.",
        "Your last check is in the drop box. I'm sorry it's not more.",
        "I'm locking up for good. Take care of your family.",
        "If anybody asks, the keys are with me.",
    },
    after = {
        "You missed your shift. That's not like you.",
        "Nobody's heard from you. Just let us know you're okay.",
        "We kept your spot. Whenever you can.",
        "Your locker's still got your stuff in it.",
    },
}

-- What they ask, by when.
Voicemail.ASK = {
    normal = { "Call me back.", "Call me when you get this.", "No need to call back.", "Let me know.",
        "Call when you can." },
    news = { "Call me as soon as you get this.", "Stay inside tonight.", "Call me back, okay?", "Please call." },
    closure = { "If you get this, call. Please.", "Don't try the highway.", "Stay where you are.",
        "Call when you can, if you can." },
    after = { "Please. Just call.", "Just let me know you're okay.", "I'll keep trying.", "Please call me back.",
        "Just say anything." },
}

-- How they hang up.
Voicemail.BYE = {
    mom = { "Love you.", "Okay. Love you, honey. Bye.", "Bye-bye.", "I love you. Bye." },
    dad = { "Bye.", "Okay.", "Talk later.", "All right. Bye." },
    grandma = { "Love, Grandma. Oh, you don't say that on these. Bye now.", "Bye, honey.", "God bless. Bye." },
    sib = { "bye.", "later.", "love you, idiot.", "ok bye." },
    partner = { "I love you.", "Love you. Bye.", "Okay. I love you.", "Bye." },
    friend = { "Later.", "See ya.", "Bye.", "Talk soon." },
    work = { "Thanks.", "Thanks. Bye.", "Appreciate it." },
    neighbor = { "Take care now.", "Bye now.", "Okay, bye." },
}

-- The phases in order, by story day (day 0 = July 9 1993; Core/Story PHASES): before the news, the news, the closure.
function Voicemail.phaseFor(day)
    if day <= -6 then return "normal" elseif day <= -4 then return "news" end
    return "closure"
end

-- One message. fill(rng, template, ctx) is Story.fill. opts: { who, phase (normal/news/closure/after), name, caller,
-- town }. Returns the words.
function Voicemail.compose(rng, fill, opts)
    local who = Voicemail.GREET[opts.who] and opts.who or "friend"
    local phase = Voicemail.BODY[opts.phase] and opts.phase or "normal"
    local ctx = { name = opts.name or "", caller = opts.caller or "", town = opts.town or "Muldraugh" }
    local bodies = who == "work" and Voicemail.WORK[phase] or Voicemail.BODY[phase]
    local parts = { rng:pick(Voicemail.GREET[who]) }
    local first = rng:int(1, #bodies)
    parts[#parts + 1] = bodies[first]
    if rng:chance(0.5) then
        local second = rng:int(1, #bodies - 1)
        if second >= first then second = second + 1 end
        parts[#parts + 1] = bodies[second]
    end
    parts[#parts + 1] = rng:pick(Voicemail.ASK[phase])
    parts[#parts + 1] = rng:pick(Voicemail.BYE[who])
    return fill(rng, table.concat(parts, " "), ctx)
end

return Voicemail
