-- Texts put together from parts (0.2.0, Meta 2026-10-21: "a lot more messages ... volume over polish"). A text is
-- something that happened (fitting the day) and sometimes a short tag, in the sender's voice: parents and work write
-- sentences, siblings, friends and young partners write lowercase with no full stops. Pure Lua 5.1; Story.fill
-- grammar ([a|b] picks one); slots {town}. Dark things stay implied (docs/lore/KNOX_LORE.md).
local Texts = {}

Texts.SAY = {
    normal = {
        "It's [97|98|99] on the bank sign", "The AC's out again", "Mowed the yard. Finally",
        "Your [cousin|aunt] is coming for the Fourth", "Got off early today", "The [truck|car] won't start again",
        "Cookout Sunday after church", "Found your [sunglasses|keys] in my car", "Paid the phone bill",
        "The tomatoes are coming in", "Heard there's a flu going around Louisville", "Ran into your old [teacher|coach] at the IGA",
        "Gas went up again", "There's a sale on fans at the hardware", "The [dog|cat] got out again. Found it",
        "Watching the ballgame", "Got the overtime", "Fireworks at the river this year", "The power blinked during the storm",
        "Church supper is Wednesday", "Washed your car. You're welcome", "Grandma wants us all there Sunday",
        "The sitter cancelled", "Bought a new [mattress|lawnmower]. Don't ask what it cost",
    },
    news = {
        "Turn on channel 3", "The hospital in Louisville is full", "They cancelled the fireworks",
        "The IGA is out of [water|bread|batteries]", "Sirens all night", "Church is open for anybody",
        "Filled the tub just in case", "Somebody got bit at the gas station", "Army trucks on the highway",
        "Can't get through to anybody. All circuits busy", "The radio says stay inside", "School's a shelter now",
        "They're saying it's a flu. It's not a flu", "Your [uncle|cousin] in Louisville won't answer", "Got the last case of water",
        "Lines at every gas station", "The news lady looked scared", "Nobody at work knows anything",
        "Saw a man walking down the middle of the road. Something wrong with him", "Stay off 31W",
    },
    closure = {
        "They closed the roads at 6 this morning", "Soldiers at the bridge", "The house phone is dead",
        "This is the only thing that works now", "Curfew at dark", "Fence going up by the highway",
        "Neighbors left last night", "Heard shooting by the school", "Power keeps flickering", "We're at the church",
        "Running low on [milk|bread|everything]", "On the roof for one bar", "Charging the phone in the truck",
        "The water tastes funny", "Boarded the back windows", "Somebody's knocking on doors down the street",
        "They won't let anybody out of {town}", "Lock your doors", "Nobody's seen the mailman in two days",
        "The Army says supplies are coming. Sure",
    },
    after = {
        "Where are you", "Please answer", "Call me", "Are you ok", "I'm worried", "Your [car|truck] is still out front",
        "I went by your place", "Nobody's heard from you", "Just one word", "Mom keeps asking",
        "The church has a list. You're not on it", "I'm not mad", "It's getting dark", "I'll keep trying",
        "Text me back", "I fed your [dog|cat]", "Come home", "We're still here",
    },
}

Texts.WORK = {
    normal = { "Can you cover [Saturday|Sunday]", "Schedule's posted", "Your check is in the office",
        "Truck comes at six tomorrow", "Somebody called in sick again", "Safety meeting [Monday|Wednesday]" },
    news = { "Closing early today", "Half the crew didn't show", "Corporate says stay open", "Don't come in after three",
        "Stay home if you can" },
    closure = { "Closed until further notice", "Don't come in", "Your last check is in the drop box",
        "Locking up for good", "Take care of your family" },
    after = { "You didn't come in today", "Nobody's heard from you", "We kept your spot", "Just let us know you're ok" },
}

-- Short tags, by when.
Texts.TAG = {
    normal = { "Call me", "Love you", "Just saying", "Ha", "Talk later" },
    news = { "Call me", "Be careful", "Stay inside", "Please call", "Love you" },
    closure = { "Be careful", "Stay put", "Text don't call", "Love you", "Please" },
    after = { "Please", "Anything", "Love you", "Call me" },
}

-- Who writes how: "proper" (capital, full stop between parts) or "casual" (lowercase, no full stops).
local VOICE = { mom = "proper", dad = "proper", work = "proper", partner = "casual", sib = "casual", friend = "casual" }

-- One text. fill(rng, template, ctx) is Story.fill. opts: { who (mom/dad/sib/partner/friend/work), phase
-- (normal/news/closure/after), town, young (the owner is 18-25: their partner writes casually too) }.
function Texts.compose(rng, fill, opts)
    local phase = Texts.SAY[opts.phase] and opts.phase or "normal"
    local pool = opts.who == "work" and Texts.WORK[phase] or Texts.SAY[phase]
    local text = fill(rng, rng:pick(pool), { town = opts.town or "Muldraugh" })
    if opts.who ~= "work" and rng:chance(0.4) then text = text .. ". " .. rng:pick(Texts.TAG[phase]) end
    local voice = VOICE[opts.who] or "casual"
    if opts.who == "partner" and not opts.young then voice = "proper" end
    if voice == "casual" then
        text = text:lower():gsub("%.", "")
    end
    return text
end

return Texts
