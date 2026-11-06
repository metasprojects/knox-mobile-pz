-- Server: a phone off a dead Project A-Life NPC keeps listening (0.2.0). While it is on and has service, its faction's
-- group chat goes on without its owner: the crew say what they are doing right now (A-Life's live NPC intents), a
-- member who stops answering is missed, and when A-Life's raid director sends that faction somewhere, the chat says
-- where before they go. Every 20 seconds; a line only when a member starts something new, at most one a phone per
-- half game hour. Without A-Life, or after an A-Life update that changes these, it does nothing.
local Phones = require "KnoxMobile/Game/Phones"
local Util = require "KnoxMobile/Game/Util"
local ALife = require "KnoxMobile/Game/ALife"
local Tick = require "KnoxMobile/Game/Tick"
local Rng = require "KnoxMobile/Core/Rng"
local Lang = require "KnoxMobile/Core/Lang"
local Machine = require "KnoxMobile/Core/Machine"
local Messaging = require "KnoxMobile/Messaging"
local State = require "KnoxMobile/State"

local Wire = { nextAt = 0, intent = {}, known = {} }
KnoxMobile.FactionWire = Wire

local CHECK_MS = 20000
local GAP = 30   -- game minutes between lines on one phone
local KEEP = 80  -- messages kept in the chat
local MEMBERS = 16

-- What a member says when A-Life starts them on something, asks after, warns of a raid (Data/WireLines).
local WireLines = require "KnoxMobile/Data/WireLines"
Wire.LINES, Wire.GONE, Wire.RAID, Wire.RAID_YOU = WireLines.LINES, WireLines.GONE, WireLines.RAID, WireLines.RAID_YOU

-- The faction phones this player carries, turned on and with service: { { item, state, model, alife } }.
local function phones(player)
    local out = {}
    for _, item in ipairs(Phones.inventoryPhones(player)) do
        local alife = item:getModData().KnoxMobileALife
        if type(alife) == "table" and alife.factionId then
            local state, model = Phones.get(item)
            if state and state.owner and state.power and state.power.on and state.battery.charge > 0
                and state.condition ~= "broken" then
                local located = Messaging.service(player, model)
                if located and located.network then out[#out + 1] = { item = item, state = state, model = model, alife = alife } end
            end
        end
    end
    return out
end
Wire.phones = phones

local function chatOf(state, alife)
    local chats = state.contents.groupChats or {}
    state.contents.groupChats = chats
    for _, c in ipairs(chats) do if c.name == alife.faction then return c end end
    local c = { name = alife.faction, messages = {} }
    table.insert(chats, 1, c)
    return c
end

-- One line into the phone's faction chat, unread, with the banner a text gets.
function Wire.say(player, p, from, body)
    local chat = chatOf(p.state, p.alife)
    local day, minute = Messaging.stamp()
    chat.messages[#chat.messages + 1] = { day = day, minute = minute, inbound = true, unread = true, from = from, body = body }
    while #chat.messages > KEEP do table.remove(chat.messages, 1) end
    p.alife.lastLine = Util.nowMinutes()
    Phones.save(p.item, player)
    Messaging.notifyTexts(player, p.item, p.state, { { group = true, groupName = p.alife.faction, from = from, body = body } })
end

-- A line in the story's language (Core/Lang).
local function fill(rng, list, slots)
    return Lang.tidy((Lang.t(rng:pick(list)):gsub("{(%a+)}", function(k) return slots[k] or ("{" .. k .. "}") end)))
end

-- What changed since the last look, faction by faction: { [factionId] = { lines = { { from, body } }, raid } }.
function Wire.news(factions)
    local out = {}
    local rng = Rng.new("wire:" .. tostring(Util.nowMinutes()))
    for factionId in pairs(factions) do
        local news = { lines = {} }
        out[factionId] = news
        local members = ALife.members(factionId, MEMBERS)
        local alive, names = {}, {}
        for _, m in ipairs(members) do alive[m.uid] = m; names[#names + 1] = m.name end
        for _, m in ipairs(members) do
            local was = Wire.intent[m.uid]
            Wire.intent[m.uid] = m.intent or false
            local lines = Wire.LINES[m.intent]
            -- A member seen for the first time says nothing: no flood when the phone first hears them.
            if was ~= nil and was ~= (m.intent or false) and lines then
                local others = {}
                for _, n in ipairs(names) do if n ~= m.name then others[#others + 1] = n end end
                local body = fill(rng, lines, { town = Machine.town(m.x, m.y), mate = others[1] and rng:pick(others) })
                if not body:find("{mate}", 1, true) then news.lines[#news.lines + 1] = { from = m.name, body = body } end
            end
        end
        -- Members heard before and gone now: dead, or A-Life let them go. Someone asks after them, once.
        local known = Wire.known[factionId] or {}
        Wire.known[factionId] = known
        for uid, name in pairs(known) do
            if not alive[uid] and #members > 0 then
                local interop, gone = ALife.interop(), true
                if interop and type(interop.actorOf) == "function" then
                    local ok, a = pcall(interop.actorOf, uid)
                    if ok and type(a) == "table" and a.lifecycle ~= "dead" then gone = false end
                end
                if gone then
                    known[uid] = nil
                    news.lines[#news.lines + 1] = { from = members[rng:int(1, #members)].name, body = fill(rng, Wire.GONE, { who = name }) }
                end
            end
        end
        for uid, m in pairs(alive) do known[uid] = m.name end
        local raid = ALife.raid()
        local told = State.get()
        told.wireRaids = told.wireRaids or {}
        if raid and raid.factionId == factionId and not told.wireRaids[raid.id] and #members > 0 then
            told.wireRaids[raid.id] = true
            local town = raid.x and raid.y and Machine.town(raid.x, raid.y) or "town"
            news.raid = { from = members[rng:int(1, #members)].name, target = raid.target, town = town,
                body = fill(rng, Wire.RAID, { town = town }) }
        end
    end
    return out
end

function Wire.run(players)
    local carried, factions, any = {}, {}, false
    for _, player in ipairs(players) do
        local list = phones(player)
        if #list > 0 then
            carried[#carried + 1] = { player = player, list = list }
            for _, p in ipairs(list) do factions[p.alife.factionId], any = true, true end
        end
    end
    if not any then return end
    local news = Wire.news(factions)
    local now = Util.nowMinutes()
    for _, c in ipairs(carried) do
        for _, p in ipairs(c.list) do
            local n = news[p.alife.factionId]
            local idx = p.item:getID()
            -- A raid warning always gets through; it says so when the raid is on the player carrying the phone.
            if n.raid then
                Wire.say(c.player, p, n.raid.from, n.raid.body)
                if KnoxMobile.Journal then
                    KnoxMobile.Journal.add(c.player,
                        Lang.f("Heard on {owner}'s phone: {faction} are going for a place near {town} tonight.",
                            { owner = p.state.owner.first, faction = p.alife.faction, town = n.raid.town }))
                end
                if n.raid.target and n.raid.target == c.player:getUsername() then
                    local rng = Rng.new("wire:you:" .. tostring(idx))
                    Wire.say(c.player, p, n.raid.from, fill(rng, Wire.RAID_YOU, { owner = p.state.owner.first }))
                end
            elseif #n.lines > 0 and now - (p.alife.lastLine or -GAP) >= GAP then
                local line = n.lines[#n.lines]
                if line.from ~= p.state.owner.first then Wire.say(c.player, p, line.from, line.body) end
            end
        end
    end
end

Tick.add("faction wire", function()
    if isClient() or not ALife.interop() then return end
    local t = getTimestampMs()
    if t < Wire.nextAt then return end
    Wire.nextAt = t + CHECK_MS
    local live = {}
    for _, player in ipairs(Util.players()) do if not player:isDead() then live[#live + 1] = player end end
    Wire.run(live)
end, 1000)

Wire.fill = fill
return Wire
