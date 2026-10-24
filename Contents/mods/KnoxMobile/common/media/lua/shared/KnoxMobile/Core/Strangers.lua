-- Strangers on the network (0.2.0): wrong numbers, and rumors forwarded from phone to phone. A wrong number is
-- someone texting the person who had your number before, or anybody at all; a rumor is a survivor stash text passed
-- along ("FWD:"), true or not (server Strangers.lua makes it a real stash, often a trap). Pure Lua 5.1.
local Strangers = {}

Strangers.WRONG = {
    "Is this Carl? Tell Carl the truck is at the quarry. He'll know.",
    "Mama it's Tisha. This is Darnell's phone. Mine died. Where are you",
    "Did you get the generator going? It's Bobby. Call me",
    "who is this. you called this number twice last night",
    "Sorry wrong number. If you're near Riverside don't take 31W.",
    "Dad? Is this still your number?",
    "This is for Pastor Jim. We have six at the house now. Can you take more?",
    "Rachel I'm at your mom's. Nobody's here. The door was open.",
    "hey is this the guy with the boat",
    "Marcy said you have insulin. I can trade batteries. Please.",
    "Kevin pick up your phone. KEVIN.",
    "Stop texting me. I don't know you. I don't know where your sister is.",
    "If anybody gets this. Two adults, one kid, Lime St. We're ok for now.",
    "is this 555-0190? the radio said to text this number to get on the list",
    "Wrong number probably. But hi. It's nice to send a text to somebody.",
    "Tell Ray I'm sorry about the truck",
    "Who has Dennis's phone? This is his brother.",
    "Uncle Pete it's me, we made it to Louisville. Don't come. The bridge is closed",
    "Did the army come by your street yet",
    "This is the Knox Mobile store on Main. We're closed. Don't come in for your phone.",
    "Grandma if you get this the pills are in the blue bag",
    "it's Shawna. new number. old phone got wet. tell everybody",
    "Is this the number for the shelter at the school?",
    "We're leaving tonight. If you want to come, be at the church at 6.",
}
Strangers.FWD = { "FWD: ", "FWD FWD: ", "pass it on: ", "got this from a friend: " }

function Strangers.wrong(rng) return rng:pick(Strangers.WRONG) end
function Strangers.forward(rng, body) return rng:pick(Strangers.FWD) .. body end

-- Chance in one game hour for a player, by game day: busy at first, quieter as the towers go.
function Strangers.hourly(day)
    if day < 7 then return 0.03, 0.012 end -- wrong number, rumor
    if day < 21 then return 0.02, 0.01 end
    return 0.008, 0.004
end

return Strangers
