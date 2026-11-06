-- 0.3.0: a bandit clan's phone (the Bandits NPC mod, Game/Bandits). The same shape as Core/FactionChatter, so
-- FactionChatter.build writes it (opts.lines = ClanChatter): the clan's group chat while the owner was alive, the
-- unread ones after, and one clan mate's own texts. They take what they want and they don't trade; what they do to
-- people stays between the lines (docs/lore/KNOX_LORE.md). Slots: {mate}, {mate2}, {owner}.
local ClanChatter = {}

ClanChatter.GROUP = {
    "Everybody back at camp by dark. {mate}, that means you",
    "Saw a car on the [highway|county road|bridge]. Somebody's still driving. Find out who",
    "House with the [blue|green] shutters has people in it. We go in [tomorrow|Sunday|tonight]",
    "{mate} wants to trade with them. We don't trade",
    "Ammo count tonight. Nobody wastes a bullet on the dead, use the bat",
    "If they've got a generator they've got fuel. Take both",
    "Stay off the radio. Phones only. Anybody can listen to a radio",
    "Leave the old man alone. He told us where the store was",
    "New rule: you take it, you share it",
    "Two of them at the gas station. Let them fill up first",
    "{mate2} is asking too many questions. Watch that",
    "Burn the truck. They'll know it was us",
    "Somebody keeps leaving food out by the road. Find them",
    "Gate stays chained. Knock twice, then once",
    "They've got lights on in the [church|school|farmhouse]. That's ours by Friday",
    "Nobody touches the medicine. That's for camp",
    "{mate}, quit texting your girl. She's not answering",
    "We move camp if anybody follows you back",
    "Saw smoke [north|east|past the creek]. Somebody's cooking. Go see what",
    "Don't wave at anybody. Don't let them see your face",
    "Count the cans before anybody eats. We're short again",
    "{mate} found a pharmacy nobody's hit. Keep it quiet",
    "The sheriff's car on 31W has a shotgun rack. Empty it",
    "Rain tonight. Good. Nobody hears us coming",
    "Somebody's been in the [barn|garage|cellar] since we left. Check the locks",
    "We take the farm on [Sunday|Monday|the weekend]. The family's got a dog. Bring meat",
    "No fires at camp. Smoke carries",
    "{mate2} let one get in through the fence. Again",
    "The boss wants a head count by morning",
    "There's a woman at the [library|post office|motel] trading eggs. Take the chickens",
    "Found a pickup with half a tank. {mate}, you drive",
    "Anyone sees the army, you don't run. You hide",
    "Siphon every car on the street. Every one",
    "Whoever took the good knife, put it back",
    "The cops' radios still work. Bring me one",
    "Water's low. Two buckets each from the creek before dark",
    "That house paid once. It'll pay again",
    "Stay in pairs. Anybody alone is anybody's",
    "We're not monsters. We just eat first",
    "Mark the doors we've done with a red X",
}

ClanChatter.AFTER = {
    "{owner}, answer. Where'd you go",
    "{owner} went to the house with the shutters and didn't come back",
    "If somebody's reading this, we know where you are",
    "Nobody goes after {owner}. We wait",
    "Whoever has {owner}'s phone: bring it back to camp",
    "Stop texting {owner}. Not coming back",
    "Somebody took {owner}'s things. Find out who",
    "Pack up {owner}'s stuff",
    "Saw {owner}'s jacket on the road. Nobody go out there",
    "{owner}, if you're hurt, flash a light from the water tower",
    "We're moving camp. If {owner} talked, they know where we were",
    "Last chance, {owner}. After tonight you're one of them to us",
    "Whoever's got this phone: we'll find you",
}

ClanChatter.MATE = {
    alive = { "you take watch or me", "dont tell the boss about the cigarettes", "need batteries for the flashlight",
        "my turn to sleep. wake me at 2", "you still got the keys to the van", "that last house had nothing. waste of a day",
        "did u eat my beans", "boss is in a mood. stay out of the trailer", "found smokes. half for you",
        "my feet are killing me", "whose turn on the generator", "cant sleep. too quiet" },
    after = { "where r you", "boss says ur gone", "i hid ur stuff", "come back man", "they think somebody got you",
        "answer me", "i covered for u", "they took ur bunk", "pick up please", "i kept ur knife", "its not the same here" },
}

return ClanChatter
