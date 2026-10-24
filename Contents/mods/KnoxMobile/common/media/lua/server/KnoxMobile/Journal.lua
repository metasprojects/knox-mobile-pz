-- Server: your own phone keeps a journal (0.2.0), a note at the top of Notes on the phone with your SIM: the people
-- whose phones you turned on and the last thing they wrote, who you told, the towers you brought back, the phone a
-- robber took and got back, the raid you heard about. Written while your phone isn't on you, it waits and goes in
-- next time it is. And Notes > Write a note, on any phone: a phone left behind can carry a message for whoever finds it.
local Phones = require "KnoxMobile/Game/Phones"
local Util = require "KnoxMobile/Game/Util"
local Net = require "KnoxMobile/Game/Net"
local Tick = require "KnoxMobile/Game/Tick"
local Format = require "KnoxMobile/Core/Format"
local Protocol = require "KnoxMobile/Core/Protocol"
local State = require "KnoxMobile/State"
local Messaging = require "KnoxMobile/Messaging"

local Journal = { KEEP = 60, NOTES = 40, nextAt = 0, last = {} }
KnoxMobile.Journal = Journal

-- Game day 0 is July 9 1993 (Core/Machine).
local MONTHS = { { "Jul", 31 }, { "Aug", 31 }, { "Sep", 30 }, { "Oct", 31 }, { "Nov", 30 }, { "Dec", 31 } }
function Journal.date(day)
    local d = 9 + math.floor(day)
    for _, m in ipairs(MONTHS) do
        if d <= m[2] then return m[1] .. " " .. d end
        d = d - m[2]
    end
    return "Day " .. math.floor(day)
end

local function pending(key)
    local md = State.get()
    md.journal = md.journal or {}
    md.journal[key] = md.journal[key] or {}
    return md.journal[key]
end

-- The phone with this player's own SIM, on them: item, state.
local function ownPhone(player)
    local mine = State.get().players[Util.playerKey(player)]
    if not (mine and mine.number) then return nil end
    local item, state = Messaging.phoneWithNumber(player, mine.number)
    return item, state
end

-- Waiting entries into the journal note on the player's own phone.
function Journal.flush(player)
    local key = Util.playerKey(player)
    local list = State.get().journal and State.get().journal[key]
    if not (list and #list > 0) then return end
    local item, state = ownPhone(player)
    if not item then return end
    local notes = state.contents.notes
    local note
    for _, n in ipairs(notes) do if n.journal then note = n end end
    if not note then
        note = { journal = true, lines = {} }
        table.insert(notes, 1, note)
    end
    for _, line in ipairs(list) do note.lines[#note.lines + 1] = line end
    while #note.lines > Journal.KEEP do table.remove(note.lines, 1) end
    note.body = "Journal\n\n" .. table.concat(note.lines, "\n\n")
    State.get().journal[key] = {}
    Phones.save(item, player)
end

-- A dated line ("Jul 21: ...") for this player's journal.
function Journal.add(player, text)
    if not player or not text then return end
    local day = Messaging.stamp()
    local key = Util.playerKey(player)
    if Journal.last[key] == text then return end
    Journal.last[key] = text
    local list = pending(key)
    list[#list + 1] = Journal.date(day) .. ": " .. text
    while #list > Journal.KEEP do table.remove(list, 1) end
    Journal.flush(player)
end

-- A found phone turned on for the first time: who they were, and the last thing they wrote.
function Journal.foundPhone(player, state)
    local o = state.owner
    if not (o and o.first) then return end
    local last = state.story and state.story.draft
    if not last then
        for _, conv in ipairs(state.contents.texts or {}) do
            for _, m in ipairs(conv.messages or {}) do if not m.inbound and m.body then last = m.body end end
        end
    end
    -- A draft can still hold the story grammar's choices ("[a|b]"): the first one.
    if last then last = tostring(last):gsub("%[([^|%]]*)[^%]]*%]", "%1") end
    local who = o.first .. (o.last and (" " .. o.last) or "")
    local job = o.job and (" " .. o.job .. ".") or ""
    local said = last and (state.story and state.story.draft and " Never sent: \"" or " Last thing they wrote: \"")
        .. Format.ellipsis(last, 80) .. "\"" or ""
    Journal.add(player, "Turned on " .. who .. "'s phone." .. job .. said)
end

Protocol.register({
    writeNote = function(args)
        if type(args.body) ~= "string" or #args.body < 1 or #args.body > 600 then return false, "body must be 1-600 characters" end
        return true
    end,
})

Net.onServer("writeNote", function(player, args)
    local item = args.phoneId and Phones.findById(player, args.phoneId)
    if not item or not Phones.isPhone(item) then return end
    local state = Phones.get(item)
    if not state or state.security.locked or not (state.power and state.power.on) then return end
    local notes = state.contents.notes
    if #notes >= Journal.NOTES then return end
    local day, minute = Messaging.stamp()
    notes[#notes + 1] = { body = args.body, mine = true, day = day, minute = minute }
    Phones.save(item, player)
end)

Tick.add("journal", function()
    if isClient() then return end
    local t = getTimestampMs()
    if t < Journal.nextAt then return end
    Journal.nextAt = t + 30000
    local md = State.get()
    if not md.journal then return end
    for _, player in ipairs(Util.players()) do
        local list = md.journal[Util.playerKey(player)]
        if list and #list > 0 then Journal.flush(player) end
    end
end)

return Journal
