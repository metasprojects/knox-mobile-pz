-- 0.3.0: past the cordon. Knox Mobile's towers only reach the county, and the zone's landlines are dead (lore: July 7),
-- so only the Orbita 9505 satellite phone, under open sky, can call out. Three numbers answer, by the day (counted from
-- the outbreak), the way Core/Recordings does: a military line that won't say where it is, the federal health line,
-- and the sister of the phone's last owner. Anything else outside: the satellite network's recording. The numbers are
-- on a note in every found sat phone. Pure Lua 5.1; lines split on " / " (client/KnoxMobile/Client.lua callScripted).
local Lang = require "KnoxMobile/Core/Lang"

local Cordon = {}

Cordon.LOCAL = { ["502"] = true, ["606"] = true } -- Knox County's area codes: those calls stay on the towers

Cordon.NUMBERS = {
    ["(703) 555-0142"] = { name = "Restricted line", script = {
        { to = 3, kind = "answer", lines = "This line is restricted. State your name and unit. / ... / You're calling from inside the zone? Stay where you are. Do not approach the fence. This call is being recorded." },
        { to = 8, kind = "answer", lines = "Restricted line. / Inside the zone? Listen. Nobody is coming in yet. Stay off the roads, keep your head down. / I'm sorry. I have to clear this line." },
        { to = 14, kind = "answer", lines = "... / Whoever this is, they told us to stop answering. / I'm not supposed to say that. Good luck." },
    } },
    ["(800) 555-0110"] = { name = "Federal health line", script = {
        { to = 6, kind = "answer", lines = "You have reached the federal health information line. / If you are inside a quarantine zone, remain indoors and wait for instructions. / Do not attempt to leave. Do not approach anyone who is sick." },
        { to = 20, kind = "answer", lines = "You have reached the federal health information line. / All quarantine zones remain closed until further notice. / This message will not be updated." },
    } },
    ["(614) 555-0187"] = { name = "Carol", script = {
        { to = 4, kind = "answer", lines = "Hello? / Is that you? It's so faint. Are you okay? Is Mom with you? / I'm trying every day, they won't let anybody near the fence. Please call again." },
        { to = 10, kind = "voicemail", lines = "Hi, you've reached Carol. / If this is about my family in Kentucky, please, please leave a message. I check it every hour." },
        { to = 999, kind = "voicemail", lines = "Hi, you've reached Carol. Leave a message. / ... / I still check it." },
    } },
    -- A newsroom in Ohio that wants the story, and a ham radio operator in Indiana who has been listening.
    ["(513) 555-0164"] = { name = "Newsroom", script = {
        { to = 5, kind = "answer", lines = "Newsroom. / You're inside? Inside Knox County? Hold on. Can I record this? / What can you see from where you are? ... Hello? We lost you. Call back. Ask for Dana." },
        { to = 12, kind = "answer", lines = "Newsroom, this is Dana. / If you're the one calling from inside: they pulled our story. Nobody here is allowed to run it. / I kept your number. I'm not giving up." },
        { to = 999, kind = "voicemail", lines = "You've reached the newsroom. / Leave your name and a number where we can reach you." },
    } },
    ["(812) 555-0129"] = { name = "Walt", script = {
        { to = 9, kind = "answer", lines = "This is Walt. / I've been listening to you folks on the shortwave every night. You're not alone, whatever they say out here. / Save your battery for the bad nights." },
        { to = 30, kind = "answer", lines = "Walt here. / The shortwave's gone quiet from your side. Two nights now. / If you hear this, key the radio once. Just once. I'll know." },
    } },
}
Cordon.ROUTING = "Your satellite call cannot be completed as dialed. / Please check the number and try again."

-- The note in a found sat phone: the numbers its last owner kept.
Cordon.NOTE = "Hotline (800) 555-0110. Carol (614) 555-0187. Newsroom (513) 555-0164, ask for Dana. Walt (812) 555-0129. Don't call the 703 number unless it's bad"

-- Is this number outside Knox County (a 10-digit number with another area code)?
function Cordon.isOutside(number)
    local area = tostring(number or ""):match("^%((%d%d%d)%)")
    return area ~= nil and not Cordon.LOCAL[area]
end

-- What answers on this day: { kind, lines, name }.
function Cordon.call(number, day)
    local n = Cordon.NUMBERS[number]
    if not n then return { kind = "answer", lines = Lang.t(Cordon.ROUTING), name = Lang.t("Satellite network") } end
    for _, e in ipairs(n.script) do
        if day < e.to then return { kind = e.kind, lines = Lang.t(e.lines), name = Lang.t(n.name) } end
    end
    return { kind = "noAnswer", name = Lang.t(n.name) }
end

return Cordon
