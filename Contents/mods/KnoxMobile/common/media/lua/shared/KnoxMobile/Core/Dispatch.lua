-- 0.3.0: the dispatcher. Darlene "Dee" Moss (docs/lore/KNOX_LORE.md: county dispatcher, Rosewood, calm, radio codes,
-- keeps dispatch running alone) texts every number on the tower list once 911 jams. Over the first twelve days she
-- warns, she passes on calls nobody else can answer (as jobs: Core/Jobs, server/Jobs.lua), and she asks for help
-- twice. Bring food to the station before her deadline and dispatch stays on the air to the end, with a last gift
-- from the evidence room; let it lapse and she signs off early. Pure Lua 5.1; server/KnoxMobile/Dispatch.lua runs it.
-- Days count from the outbreak (Util.sinceOutbreak); hours are the time of day. Darkness stays implied.
local Dispatch = {}

Dispatch.NAME = "Dee"
Dispatch.STATION = "rosewood_police" -- Story/Sites: the police station on North Main St in Rosewood

-- The arc, in order. kind "text": a text; "job": an offer in the Jobs app (job = { kind, need, site, days });
-- only = "helped" / "alone": sent only when the food run was done in time / wasn't. after: a beat id that must have
-- been sent first. end = true: Dee is off the air after this one.
Dispatch.BEATS = {
    { id = "hello", day = 0, hour = 19, kind = "text",
      body = "This is Rosewood dispatch. 911 is jammed, so I'm texting every number on the tower list. Stay inside tonight. Dee" },
    { id = "roads", day = 1, hour = 8, kind = "text",
      body = "Be advised: 31W and the bridges are closed. Do not try the checkpoints. They are turning everyone back" },
    { id = "calls", day = 1, hour = 18, kind = "text",
      body = "I have calls nobody can answer. If you're able, I'll pass some to you. Go if you can. Don't if you can't" },
    { id = "welfare", day = 1, hour = 19, kind = "job", job = { kind = "check", site = "family", days = 2 },
      body = "Welfare check at {place}. Elderly caller, no answer since this morning. Can you go by?" },
    { id = "batteries", day = 2, hour = 10, kind = "job", job = { kind = "deliver", need = "batteries", site = "station", days = 3 },
      body = "The radio room runs on batteries now. If you find some, bring them to {place}. Ask for Dee" },
    { id = "fort", day = 3, hour = 6, kind = "text",
      body = "Fort Knox stopped answering the radio at 2:10 this morning. I'm still here. 10-4" },
    { id = "medicine", day = 4, hour = 9, kind = "job", job = { kind = "deliver", need = "antibiotics", site = "family", days = 3 },
      body = "Caller at {place} says her husband needs antibiotics. I've got nobody else to send" },
    { id = "groups", day = 5, hour = 14, kind = "text",
      body = "Be advised: people on the roads in groups, armed. Don't stop for anyone flagging you down" },
    { id = "power", day = 6, hour = 20, kind = "text",
      body = "When the power goes, I'll keep the radio on as long as the generator runs. Charge everything tonight" },
    { id = "food", day = 7, hour = 9, kind = "job", job = { kind = "deliver", need = "food", site = "station", days = 2, key = true },
      body = "Generator's fine. Food isn't. Canned food to {place} and I can keep this going. Two days, then I'm out" },
    { id = "thanks", day = 9, hour = 12, kind = "text", only = "helped", reward = true,
      body = "You came. I'm 10-8 a while longer because of you. There's a bag from the evidence room at {place}. Take it" },
    { id = "rest", day = 9, hour = 12, kind = "text", only = "alone", ["end"] = true,
      body = "Nobody came. That's all right. I'm going to rest my eyes a while. Rosewood dispatch is 10-7" },
    { id = "school", day = 10, hour = 16, kind = "job", only = "helped", job = { kind = "check", site = "family", days = 2 },
      body = "Kids' voices on the radio from {place}. Then nothing. Please go look" },
    { id = "last", day = 12, hour = 21, kind = "text", only = "helped", ["end"] = true,
      body = "Generator's on its last can. Whoever's still out there, look after each other. Rosewood dispatch is 10-7. Dee" },
}

-- What she answers when one of her jobs is done.
Dispatch.ACK = "[Copy that|10-4|Received]. Thank you. Dee"

-- Beats more than this many hours late are skipped, not sent (a save that turns the dispatcher on mid-game, or a
-- player who joined late, doesn't get two weeks of texts at once).
Dispatch.LATE_HOURS = 30

-- The beats due now for one player's state { sent = { id = true }, helped = true/false/nil }. now: hours since the
-- outbreak. Returns { due = { beat... }, skipped = { beat... } } in order.
function Dispatch.due(state, now)
    local due, skipped = {}, {}
    if state.ended then return { due = due, skipped = skipped } end
    for _, b in ipairs(Dispatch.BEATS) do
        local at = b.day * 24 + b.hour
        local fits = b.only == nil or (b.only == "helped" and state.helped == true) or (b.only == "alone" and state.helped == false)
        if not state.sent[b.id] and fits and now >= at then
            if now - at > Dispatch.LATE_HOURS then skipped[#skipped + 1] = b else due[#due + 1] = b end
        end
    end
    return { due = due, skipped = skipped }
end

function Dispatch.beat(id)
    for _, b in ipairs(Dispatch.BEATS) do if b.id == id then return b end end
    return nil
end

return Dispatch
