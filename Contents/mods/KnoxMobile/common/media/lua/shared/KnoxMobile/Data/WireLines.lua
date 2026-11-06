-- What a dead A-Life NPC's faction says in its group chat while the phone listens (server FactionWire, 0.2.0). Moved
-- here from the server file in 0.2.5 so the story language check (tools/gen/StoryStrings) can read them.
-- {town}: the nearest town; {mate}: another member; {who}: a member gone quiet; {owner}: the phone's dead owner.
local SUPPLIES = { "Out for supplies near {town}.", "Hitting houses by {town}. Back before dark.",
    "Supply run, {town}. Keep the radio on.", "Going through a street by {town}. Slim pickings." }
local FORTIFY = { "Boarding up the windows here.", "Nailing up the back. Need more boards.",
    "Doing the doors now. Bring nails if you've got them." }
local WATCH = { "Watching the road out of {town}.", "Quiet out here.", "On watch. Nothing moving yet.",
    "Eyes on the road by {town}." }
local AVOID = { "Too many of them by {town}. Going around.", "Got company. Moving.",
    "Whole crowd of them near {town}. Stay clear." }
local REST = { "Taking five.", "Need a breather.", "Sitting down for a minute. Feet are done." }

return {
    -- By A-Life's intent: what a member says when they start something new.
    LINES = {
        collect_supplies = SUPPLIES, search_container = SUPPLIES, wait_for_scavenge_crew = SUPPLIES,
        deposit_supplies = { "Back with a bag. Somebody count it.", "Dropped the haul at the house.",
            "Brought back what I could carry." },
        haven_arrived = { "Made it back.", "I'm in. Door's shut.", "Home. Somebody put the coffee on." },
        boarding_window = FORTIFY, fortify_opening = FORTIFY,
        scan = WATCH, search_post = WATCH, cqb_look = WATCH, standoff_post = WATCH,
        avoid_zombies = AVOID, alerted = AVOID,
        radio_call = { "Anybody on? Check in.", "Roll call. Answer when you can.", "Everybody check in before dark." },
        treat_groupmate = { "{mate} got hurt. Patching them up.", "Need the med bag. {mate}'s bleeding." },
        robbery_pending = { "Stopped somebody on the road by {town}. They're handing it over.",
            "Got a stranger by {town}. Easy, nobody's shooting." },
        standoff_pending = { "Standoff by {town}. Nobody move yet." }, standoff_hold = { "Holding. They haven't backed off." },
        rest_after_scavenge = REST, recover_endurance = REST, warming = { "Got a fire going.", "Warming up a minute." },
    },
    GONE = { "Anybody heard from {who}?", "{who} isn't answering.", "{who}, check in.", "Still nothing from {who}." },
    RAID = { "Everybody in. We go for the place near {town} tonight.", "Tonight. The place by {town}. Bring everything.",
        "We hit {town} after dark. Be at the house by then." },
    RAID_YOU = { "Whoever has {owner}'s phone, we know.", "{owner}'s phone is still on. Funny, that." },
}
