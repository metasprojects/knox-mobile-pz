-- Story templates (spec §5). Round 1 set; Round 3 writes the full library.
-- Timeline (Core/Story PHASES): normal June 30-July 3, news July 4-5, closure from July 6 (the roads sealed at
-- 06:00, fences and checkpoints by 11:00), game start July 9. Nobody gets out once the zone is sealed.
--
-- Grammar: [a|b|c] picks one option; {slot} takes a value. Slots: {first} {mom} {dad} {sib} {partner} {friend}
-- {work} {jobPlace} {jobTitle} {town} {hometown}; family texts add {other} and {place}; survivor texts add
-- {place} and {sender}. {jobPlace} starts with a lowercase "the", so it never starts a sentence.
--
-- An entry is a plain string (just a body) or a table:
--   body    the text
--   from    dead phones: who sends it, "self" (the phone's owner) or a contact: mom, dad, sib, partner, friend, work
--   jobs    dead phones: only for owners whose job is in this Story/Jobs group (emergency, shifts, business, retail)
--   other   family: who {other} may be. "any": a member still around; "doomed": one who will die;
--           "dead": one who died before this text. {other} is never the sender.
--   alt     family: the line to use when no member fits `other`
--   site    family: only when the family is at a "house" or a "shelter" (church, school; Core/Hunt)
--   kind    survivor: what it says about {place}: "safe", "need", "danger" or "rumor"
-- Family texts can come from any family member, so they never say "your dad" (use {other}), and they end without
-- a full stop. Drafts are used as written: no [a|b] or {slots} in them.
return {
    -- Dead people's phones: texts that follow the outbreak day by day (spec §5.1).
    deadPhone = {
        normal = {
            { from = "mom", body = "[Don't forget|Remember] Sunday dinner [hun|sweetie]. Bring {partner}" },
            { from = "mom", body = "Cookout Sunday for the 4th. Bring {partner}" },
            { from = "friend", body = "[u coming out friday|you still on for friday]? [Twiggy's|Spiffo's] at 9" },
            { from = "friend", body = "fireworks at the river on the 4th?" },
            { from = "self", body = "[running late|stuck in traffic] be there in 20" },
            { from = "work", jobs = "shifts", body = "Can you cover [Thursday|Saturday] at {jobPlace}?" },
            { from = "partner", body = "[pick up milk|grab some bread] on the way home?" },
            { from = "sib", body = "[did u call mom back|mom says call her]" },
            { from = "dad", body = "[Truck's fixed.|Got the truck running.] [Come get your tools|Your tools are in the shed]" },
            { from = "mom", body = "[Your aunt called.|Grandma called.] [Call her back|She wants to hear from you]" },
            { from = "friend", body = "[we still on for saturday?|you coming saturday?] [i got tickets|bring cash]" },
            { from = "self", body = "[cant make it tonight|gonna skip tonight], [sorry|rain check]" },
            { from = "partner", body = "[dinner at 7? i'll cook|want to get takeout? my treat]" },
            { from = "work", body = "Heads up: [staff|safety] meeting [Monday|Wednesday] at {jobPlace}" },
            { from = "work", jobs = "retail", body = "Reminder: inventory [Monday|Wednesday]. Don't be late" },
            { from = "sib", body = "[happy birthday!!|happy bday!!] [call me later|love ya]" },
            { from = "dad", body = "[Mowed your yard.|Fixed the porch light.] You owe me [a beer|lunch]" },
        },
        news = {
            { from = "friend", body = "did you see the news?? [people biting people|they keep saying its the flu]" },
            { from = "mom", body = "Are you watching WBLN? Call me" },
            { from = "self", body = "[probably nothing|its just the flu thing] dont worry" },
            { from = "work", jobs = "emergency", body = "All staff report to {jobPlace} [early|at 6]. No exceptions." },
            { from = "partner", body = "theres army trucks on [the highway|31W]" },
            { from = "sib", body = "[the pool's closed|they cancelled the game]. whats going on" },
            { from = "dad", body = "[Fill up the car.|Get gas while you can.] [Lines are long already.|Prices are going up.]" },
            { from = "friend", body = "[my cousin says|heard from my cousin] the hospital in Louisville is [packed|turning people away]" },
            { from = "work", jobs = "business",
                body = "[Due to current events|Because of the situation], we're [closing early today|on reduced hours]." },
            { from = "self", body = "[grocery store is a zoo|no bread left anywhere]. [got what i could|got canned stuff]" },
            { from = "mom", body = "[Wash your hands|Don't let anyone in] and stay away from sick people" },
            { from = "sib", body = "[did you hear sirens last night|helicopters all night]?" },
        },
        closure = {
            { from = "friend", body = "they closed the bridge. [we cant get out|nobody in or out]" },
            { from = "friend", body = "house phone's dead. knox telecom wont say why" },
            { from = "mom", body = "They say stay inside. Where are you???" },
            { from = "self", body = "[cant get through to anyone|phones are jammed] im ok" },
            { from = "work", jobs = "business", body = "We're closed until further notice. [Stay home.|Stay safe.]" },
            { from = "work", jobs = "emergency", body = "All leave is cancelled. [Report to {jobPlace} now.|Every shift is mandatory.]" },
            { from = "partner", body = "[i love you|be careful]. come home now" },
            { from = "dad", body = "[Roads are blocked.|Army has the roads.] Don't try to drive out" },
            { from = "friend", body = "[going to my uncles|heading to the farm]. [u should come|room for u]" },
            { from = "self", body = "[power keeps flickering|lights keep going out]. [battery at 20|need to charge]" },
            { from = "sib", body = "[mom wont answer|cant reach dad]. have u heard from them" },
        },
        lastDay = {
            { from = "self", body = "[got bit|it bit me] its not bad" },
            { from = "self", body = "going to [the gas station|the store] for [supplies|water]. back soon" },
            { from = "partner", body = "where are you" },
            { from = "friend", body = "[answer ur phone|pick up]" },
            { from = "self", body = "[theres one in the yard|something in the yard]. [staying quiet|lights off]" },
            { from = "mom", body = "[Are you eating?|Do you have water?] Call me" },
            { from = "self", body = "[fever|so cold]. [going to lie down|just need sleep]" },
            { from = "sib", body = "[where r u|whats happening there]" },
        },
        afterDeath = {
            { from = "mom", body = "Please call me back" },
            { from = "mom", body = "[{first} please|Baby please answer]" },
            { from = "mom", body = "Your father drove by your place. Your car's still there. Call us" },
            { from = "partner", body = "[are you ok|please be ok]" },
            { from = "partner", body = "[forget the fight|i'm not mad anymore]. just come home" },
            { from = "friend", body = "[{first}??|hello?]" },
            { from = "friend", body = "[went by ur place|knocked on ur door]. nobody home?" },
            { from = "dad", body = "[Call your mother.|Your mother is worried sick.]" },
            { from = "dad", body = "Radio says stay off the roads. Stay where you are." },
            { from = "sib", body = "[please answer|pick up pick up pick up]" },
            { from = "sib", body = "mom wont stop crying. just call" },
            { from = "partner", body = "[i'm at home waiting|i left the door unlocked for you]" },
            { from = "friend", body = "[we're leaving tomorrow|leaving at dawn]. [hope ur ok|find us]" },
            { from = "mom", body = "[I keep calling.|Your phone just rings.] Please." },
            { from = "work", jobs = "emergency", body = "{first}, you missed your shift. We need everyone. Call in." },
        },
        drafts = { "im at the gas sta", "tell mom i", "dont come h", "if u find this", "im sorry for", "the kids are w",
            "dont open the", "love yo" },
        notes = {
            "milk, eggs, [AMMO??|bullets], insulin for dad",
            "[spare key under the mat|key is under the flowerpot]",
            "[supplies at the cabin|we keep water at the lake house] near {hometown}",
            "[Garage code|Safe combo]: [1987|4412|0629]",
            "Day [2|3]. [Power still on.|No TV now.] Waiting for {partner}.",
            "Call {mom} back. [Tell her we're ok.|Don't scare her.]",
            "[Boil it first.|Bleach: 8 drops a gallon.]",
            "[Shells in the truck.|Flashlight in the glovebox.]",
            { jobs = "shifts", body = "Shifts: [Mon Wed Fri|Tue Thu Sat] at {jobPlace}" },
        },
        voicemails = {
            { from = "mom", body = "Hey, it's me. Call me back when you get this, okay?" },
            { from = "work", jobs = "shifts", body = "This is {work}. We need you at {jobPlace} as soon as you can." },
            { from = "friend", body = "[Dude|Hey], where are you? Call me." },
            { from = "mom", body = "{first}, please call me. I don't know what's happening." },
            { from = "dad", body = "It's Dad. [Call your mother.|We're okay.] Stay where you are." },
            { from = "partner", body = "Hey, it's me. [I'm on my way.|I'm stuck at work.] I love you." },
            { from = "sib", body = "[Where are you?|Are you okay?] Mom's freaking out. Call us." },
        },
        groupChat = {
            { body = "[anyone else seeing this|is anyone ok]?" },
            { body = "[stay home|lock your doors] everyone" },
            { body = "[{jobPlace} is a mess|we're overwhelmed here]" },
            { body = "[roll call|everyone check in] please" },
            { body = "[my power's out|no water pressure here]. anyone else?" },
            { body = "[heading out at dawn|we're leaving]. [who's coming|meet at the church]" },
        },
    },

    -- Your own family's texts over the first days (spec §5.2). One list per stage of a member's fate.
    -- {place} is where they are: a real building (Story/Sites.lua, Core/Hunt), or "the house in <hometown>" when the
    -- family hunt is off. `site` limits an entry to a "house" or a "shelter" (church, school).
    family = {
        -- Where the family is holed up: one text early on, so the player knows where to look (Core/Hunt).
        gather = {
            { site = "house", body = "We're all at {place}. [Doors locked, curtains shut|Plenty of canned food]. Come if you can" },
            { site = "house", body = "[Staying put|Sitting tight] at {place} till this blows over. [Come find us|Come when it's safe]" },
            { site = "shelter", body = "They opened {place} as a shelter. We're there. [Come if you can|Bring blankets]" },
            { site = "shelter", body = "We're at {place} with half the town. [They have cots and water|They're letting everyone in]" },
        },
        worry = {
            "Are you safe? [They're saying stay inside|Call me when you can]",
            "[Hey|Hey you], the news is scary. Where are you?",
            "We're [okay|fine] here. [Lock the doors|Stay put]",
            "[Do you have food?|Did you get groceries?] [We have extra|Come get some]",
            { site = "house", other = "any", body = "{other} is [boarding up the windows|filling the bathtub]. Call us",
                alt = "We're [boarding up the windows|filling the bathtub]. Call us" },
            { site = "shelter", other = "any", body = "{other} is [helping with the cots|handing out water]. Call us",
                alt = "We're [helping with the cots|handing out water]. Call us" },
            "[The phone lines are so bad.|Can't get through on the house phone.] Text back",
        },
        sick = {
            { other = "doomed", body = "{other} has a fever. Probably nothing", alt = "Grandpa has a fever. Probably nothing" },
            "I don't feel so good. [Lying down|Gonna rest]",
            "[Got scratched|Something grabbed me] at the store. It's fine",
            "[Running a fever.|Up sick all night.] Don't come over",
            { other = "doomed", body = "{other} got bit by the neighbor. [It looks bad|They say it's fine]",
                alt = "The neighbor's boy got bit. [It looks bad|They say it's fine]" },
        },
        dying = {
            "[It's getting worse.|I can't get up.] I love you",
            { other = "dead", body = "{other} didn't make it. Please come home", alt = "Grandma didn't make it. Please come home" },
            "[If you get this|When you get this], we're at {place}",
            "[Can't stop shaking.|Everything hurts.] [Don't come|Stay away from here]",
            { other = "dead", body = "{other} isn't right anymore. [I locked the door|I'm scared]",
                alt = "The neighbor isn't right anymore. [I locked the door|I'm scared]" },
        },
        goodbye = {
            "[We're leaving town.|Heading north.] Don't come here. I love you",
            "[Phone's dying.|Battery's almost gone.] Stay safe. Love you",
            "[The radio says go north.|We're following the convoy.] [Love you always|I'll find you]",
            "Left you a note at {place}. Don't wait for us",
        },
        -- "Rescued" inside a sealed zone means the army camp by the fence (it falls July 14-15). They left {place}.
        rescued = {
            "We made it to the camp by the fence. Safe for now",
            "[The army took us to the camp by the fence.|We're at the camp by the fence.] Come find us there",
            "[A truck came for us at {place}.|Soldiers came by {place}.] They're taking us to the camp by the fence",
            "[They say buses are coming for us.|Soldiers say we'll be out soon.] [Will call when I can|Stay put]",
        },
        -- Unsent texts left on a family member's phone (Core/Hunt). Used as written, like dead phones' drafts.
        drafts = { "please dont come here", "im so sorry baby", "i love you so mu", "the door is lock", "if you find this" },
    },

    -- Strangers texting about real places (spec §5.3). Each comes from its own number and names a different place.
    survivor = {
        { kind = "safe", body = "Holed up at {place}. [We have food.|Plenty of water.] [Knock three times.|Come at noon.]" },
        { kind = "safe", body = "[If anyone gets this|To anyone out there]: {place} is safe. [Bring meds.|We trade.]" },
        { kind = "safe", body = "[Anyone on this network?|Is anybody out there?|This is {sender}.] "
            .. "[We're at {place}.|Holed up at {place}.] [Bring batteries.|Trade for fuel.]" },
        { kind = "safe", body = "[Signal fire tonight at {place}.|Lights on at {place} after dark.] [Come if you can.|We'll wait.]" },
        { kind = "safe",
            body = "[On the roof of|Upstairs at] {place}. [We're friendly. Don't shoot.|Stairs are blocked. Bring a ladder.]" },
        { kind = "need", body = "[Six of us at {place}.|Three of us at {place}.] [Looking for a doctor.|Need antibiotics.]" },
        { kind = "need", body = "It's {sender}. [Mom and me|Me and my brother] are at {place}. No food for two days." },
        { kind = "need", body = "[Need insulin.|Need baby formula.] Will trade. Back door of {place}." },
        { kind = "rumor", body = "[Radio says|Heard on the radio] {place} still has power. [Anyone know?|Is it true?]" },
        { kind = "danger", body = "[Don't go to|AVOID] {place}. [Too many of them.|It's overrun.]" },
        { kind = "danger",
            body = "[Do NOT trust the people at|Stay away from the guys at] {place}. [They shoot first.|They took our stuff.]" },
        { kind = "danger", body = "Heard shooting at {place} last night. [Stay away.|Don't go there.] - {sender}" },
    },

    -- Survivors pointing to a stash at a real pharmacy, gas station or police station (Story/Sites quests,
    -- Core/Quests). One list per kind of place. The stash is a bag; some are traps, so no text promises it's safe.
    quest = {
        pharmacy = {
            "It's {sender}. We got into the back of {place} before they did. Left a bag of meds behind the counter. "
                .. "Can't go back for it.",
            "[My husband|My brother] died at {place} getting [insulin|antibiotics] for me. The bag's still by the counter. "
                .. "Please use it.",
            "We hid what we found in the back room at {place}. [Two of them got in after us.|The front door won't lock.] "
                .. "Be careful.",
        },
        gas = {
            "Left canned food and batteries in a bag at {place}. Truck's dead, we're on foot now. Take it. - {sender}",
            "Holed up at {place} three days. [Gone now.|Moving on.] There's a bag of food in the back if you need it.",
            "[Don't let it go to waste.|Somebody should have it.] Food in a duffel in the back office at {place}. "
                .. "We couldn't carry it all.",
        },
        police = {
            "It's {sender}. [We lost the station.|The station's gone.] Ammo in a bag in the locker room at {place}. "
                .. "Don't let it rot there.",
            "There's a police bag with shells in it at {place}. [Last locker on the left.|By the cells.] We're not going back.",
            "Grabbed what we could from {place}. Left a bag inside, too heavy. [Go in quiet.|They come when you make noise.]",
        },
    },
}
