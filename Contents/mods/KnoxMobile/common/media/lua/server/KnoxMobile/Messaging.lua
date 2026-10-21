-- Server: texts, delivery, the family storyline and survivor texts (spec §5.2, §5.3, §7.5).
local Mod = require "KnoxMobile/Core/Mod"
local MessageQueue = require "KnoxMobile/Core/MessageQueue"
local Sim = require "KnoxMobile/Core/Sim"
local Story = require "KnoxMobile/Core/Story"
local Rng = require "KnoxMobile/Core/Rng"
local Format = require "KnoxMobile/Core/Format"
local Groups = require "KnoxMobile/Core/Groups"
local Carrier = require "KnoxMobile/Core/Carrier"
local Hunt = require "KnoxMobile/Core/Hunt"
local CameraSpec = require "KnoxMobile/Core/CameraSpec"
local HuntWorld = require "KnoxMobile/Hunt"
local Quests = require "KnoxMobile/Core/Quests"
local QuestsWorld = require "KnoxMobile/Quests"
local Phones = require "KnoxMobile/Game/Phones"
local WorldModel = require "KnoxMobile/Game/WorldModel"
local Util = require "KnoxMobile/Game/Util"
local Net = require "KnoxMobile/Game/Net"
local State = require "KnoxMobile/State"

local Messaging = {}

-- day, minute: the minute is the time of day on the clock (like story texts, voicemails and machine tapes), so every
-- stamp shows as it is. World-age minutes shifted by the start hour (the clock minute at world age 0) make days run
-- midnight to midnight: day 0 is the calendar day play began (r7: a 6 AM text sorted before the day before's 8 AM).
local function stamp()
    local shifted = math.floor(Util.nowMinutes()) + Util.clockMinute(0)
    return math.floor(shifted / 1440), Mod.floor(shifted, 1440)
end
Messaging.stamp = stamp

-- A call in a phone's own call log (the Phone app's Recent): { with, day, minute, inbound, missed }. Returns the entry
-- (the callee's stays "missed" until answered). Before this only the found phones' stories had call logs (PC test r7).
function Messaging.logCall(player, item, with, inbound, failed)
    local state = item and Phones.get(item)
    if not state then return nil end
    state.contents.calls = state.contents.calls or {}
    local day, minute = stamp()
    local entry = { with = with, day = day, minute = minute, inbound = inbound == true, missed = inbound == true,
        failed = failed or nil }
    table.insert(state.contents.calls, entry)
    while #state.contents.calls > 50 do table.remove(state.contents.calls, 1) end
    Phones.save(item, player)
    return entry
end

local function passwords(player)
    local md = player:getModData()
    if type(md.KnoxMobilePasswords) ~= "table" then md.KnoxMobilePasswords = {} end
    return md.KnoxMobilePasswords
end

-- A powered-on phone with a SIM and some battery.
local function usable(state)
    return state and state.sim and state.sim.number and state.power and state.power.on
        and state.battery.charge > 0 and state.condition ~= "broken"
end
Messaging.usable = usable

-- The phone holding this SIM number in the player's inventory.
function Messaging.phoneWithNumber(player, number)
    for _, item in ipairs(Phones.inventoryPhones(player)) do
        local state, model = Phones.get(item)
        if state and state.sim and state.sim.number == number then return item, state, model end
    end
    return nil
end

-- Online player whose powered phone holds this number.
function Messaging.findNumber(number)
    for _, p in ipairs(Util.players()) do
        local item, state, model = Messaging.phoneWithNumber(p, number)
        if item and usable(state) then return p, item, state, model end
    end
    return nil
end

function Messaging.service(player, model)
    return WorldModel.locatePlayer(player, model, passwords(player))
end

function Messaging.contactName(state, number)
    if state.sim then
        local c = Sim.findContact(state.sim, number)
        if c then return c.name end
    end
    return number
end

-- Adds an entry to the conversation keyed `with` (a number, "grp:<id>" or the carrier). meta: { name, group,
-- carrier } for threads that aren't a contact; a group's name follows renames and faction changes.
function Messaging.appendTo(state, with, entry, meta)
    local texts = state.contents.texts
    local conv = nil
    for _, c in ipairs(texts) do if c.with == with then conv = c; break end end
    if not conv then
        conv = { with = with, name = (meta and meta.name) or Messaging.contactName(state, with), messages = {} }
        texts[#texts + 1] = conv
    end
    if meta then
        if meta.name then conv.name = meta.name end
        conv.group, conv.carrier = meta.group or conv.group, meta.carrier or conv.carrier
    end
    MessageQueue.appendToConversation(conv.messages, entry)
    return conv
end

function Messaging.append(state, number, entry) return Messaging.appendTo(state, number, entry) end

-- A delivered message into the right thread: its group, the carrier's, or the sender's.
function Messaging.appendRecord(state, rec, day, minute)
    -- A contact card ("Contact: Eddie (606) 555-0177", Phone > Share a contact) saves itself into the contacts; the
    -- phone's banner shows the card text as for any text.
    local name, number = tostring(rec.body or ""):match("^Contact: (.-) (%(%d%d%d%) 555%-%d%d%d%d)$")
    if name and state.sim and number ~= state.sim.number then Sim.addContact(state.sim, name, number) end
    -- A photo sent by text ("[Photo:<id>] caption") goes into a camera phone's Photos too, while it has room.
    local photoId, caption = CameraSpec.parseText(rec.body)
    local model = photoId and Phones.registry:getPhone(state.model or "")
    local spec = model and CameraSpec.forFamily(model.family)
    if spec then
        state.contents.photos = state.contents.photos or {}
        local have = false
        for _, p in ipairs(state.contents.photos) do if p.id == photoId then have = true end end
        if not have and #state.contents.photos < spec.max then
            table.insert(state.contents.photos, { id = photoId, text = caption, day = day, minute = minute, from = rec.from })
        end
    end
    local entry = { day = day, minute = minute, inbound = true, unread = true, body = rec.body, from = rec.from,
        story = rec.story, sos = rec.sos, event = rec.event }
    if rec.group then
        return Messaging.appendTo(state, Groups.thread(rec.group), entry, { name = rec.groupName, group = rec.group })
    elseif rec.carrier then
        entry.story = nil
        return Messaging.appendTo(state, Carrier.FROM, entry, { name = Carrier.FROM, carrier = true })
    end
    return Messaging.appendTo(state, rec.from, entry)
end

-- The banner: "Muldraugh Crew: Kate: on my way", "KNOX MOBILE: restart in 10 minutes", "Mom: call me".
local function banner(state, rec)
    if rec.group then return rec.groupName or "?", Messaging.contactName(state, rec.from) .. ": " .. rec.body end
    return Messaging.contactName(state, rec.from), rec.body
end

local function notifyTexts(player, item, state, delivered, fromPlayer)
    local from, body = banner(state, delivered[#delivered])
    Net.toClient(player, "notify", {
        kind = "texts", count = #delivered, phoneId = item:getID(), fromPlayer = fromPlayer == true,
        from = from, preview = Format.ellipsis(body, 48),
    })
end
Messaging.notifyTexts = notifyTexts

-- Hand queued messages to every reachable phone this player carries.
function Messaging.deliverTo(player)
    local q = State.get().queue
    for _, item in ipairs(Phones.inventoryPhones(player)) do
        local state, model = Phones.get(item)
        if usable(state) and MessageQueue.pendingFor(q, state.sim.number) > 0 then
            local _, descriptor = Messaging.service(player, model)
            local delivered = MessageQueue.deliverFor(q, state.sim.number, descriptor, Util.nowMinutes())
            if #delivered > 0 then
                local day, minute = stamp()
                for _, rec in ipairs(delivered) do Messaging.appendRecord(state, rec, day, minute) end
                Phones.save(item, player)
                notifyTexts(player, item, state, delivered)
            end
        end
    end
end

-- A phone lying in the world (left charging): queued texts arrive if it is on and has service there.
-- Returns true when something arrived. Nobody is holding it, so there is no notification.
function Messaging.deliverToItem(state, model, x, y)
    if not usable(state) then return false end
    local q = State.get().queue
    if MessageQueue.pendingFor(q, state.sim.number) == 0 then return false end
    local _, descriptor = WorldModel.locate(x, y, model.antenna or 1, true, {})
    local delivered = MessageQueue.deliverFor(q, state.sim.number, descriptor, Util.nowMinutes())
    if #delivered == 0 then return false end
    local day, minute = stamp()
    for _, rec in ipairs(delivered) do Messaging.appendRecord(state, rec, day, minute) end
    return true
end

-- One message to one number through the normal per-recipient path: straight onto the recipient's phone when it is
-- on the sender's network, else into the queue (sandbox QueueMessages). msg = { from, to, body, and the queue's
-- optional fields: group, groupName, sos, event }. Returns "delivered" | "queued" | "failed", then the record or a reason.
function Messaging.route(msg, senderNet)
    local q = State.get().queue
    local recipientNet = nil
    local rPlayer, rItem, rState, rModel = Messaging.findNumber(msg.to)
    if rPlayer then recipientNet = select(2, Messaging.service(rPlayer, rModel)) end
    local status, rec = MessageQueue.send(q, msg, senderNet, recipientNet,
        { queueMessages = Util.settings().QueueMessages }, Util.nowMinutes())
    if status == "delivered" then
        local day, minute = stamp()
        Messaging.appendRecord(rState, rec, day, minute)
        Phones.save(rItem, rPlayer)
        notifyTexts(rPlayer, rItem, rState, { rec }, true)
    end
    return status, rec
end

-- A line in the sender's own thread.
function Messaging.appendOwn(player, item, state, with, body, status, meta, event)
    local day, minute = stamp()
    Messaging.appendTo(state, with, { day = day, minute = minute, inbound = false, body = body, status = status, event = event }, meta)
    Phones.save(item, player)
end

-- A player sends a text from one of their phones. Returns "delivered", "queued" or "failed" plus a reason.
function Messaging.sendText(player, item, to, body)
    local state, model = Phones.get(item)
    if not usable(state) then return "failed", "phoneOff" end
    if state.security.locked then return "failed", "locked" end
    local located, senderNet = Messaging.service(player, model)
    if not located.network then return "failed", "noService" end
    -- Your family's phones are out there (Core/FamilyCall): a text to them goes out, it never waits in the queue.
    local plan = State.get().story[state.sim.number]
    if plan and plan.family and not Messaging.findNumber(to) then
        for _, n in pairs(plan.family) do
            if n == to then
                Messaging.appendOwn(player, item, state, to, body, "delivered")
                if plan.hunt then
                    local day, minute = stamp()
                    Hunt.recordSent(plan.hunt, to, body, day, minute)
                end
                return "delivered"
            end
        end
    end
    local status, rec = Messaging.route({ from = state.sim.number, to = to, body = body }, senderNet)
    if status == "failed" then return status, rec end
    Messaging.appendOwn(player, item, state, to, body, status)
    -- A text to your own family waits, unread, on their phone (the family hunt).
    if plan and plan.hunt then
        local day, minute = stamp()
        Hunt.recordSent(plan.hunt, to, body, day, minute)
    end
    return status
end

-- Story and system messages enter the queue as story messages: they always arrive, on any network.
function Messaging.queueStory(from, to, body)
    MessageQueue.send(State.get().queue, { from = from, to = to, body = body, story = true }, nil, nil,
        { queueMessages = true }, Util.nowMinutes())
end

local function fullName(player)
    local ok, name = pcall(function()
        local d = player:getDescriptor()
        return d:getForename() .. " " .. d:getSurname()
    end)
    return ok and name or nil
end
Messaging.fullName = fullName

-- A new character's own SIM: their number, family contacts, and their family storyline (spec §4.5, §5.2).
function Messaging.setupOwnSim(player, sim)
    local md = State.get()
    local key = Util.playerKey(player)
    local rng = Rng.new(tostring(md.seed) .. ":family:" .. key)
    sim.owner = key
    Sim.activate(sim, md.numbers, rng)
    local me = Story.identity(rng, { name = fullName(player) })
    local family = {}
    for _, member in ipairs({ "mom", "dad", "sib" }) do
        local number = Sim.issueNumber(md.numbers, rng)
        family[member] = number
        Sim.addContact(sim, me.family[member].label, number)
    end
    Sim.addContact(sim, me.friend.label, Sim.issueNumber(md.numbers, rng))
    local settings = Util.settings()
    if settings.FamilyStoryline then
        -- The family hunt: the texts name a real building no other player's family has (Core/Hunt).
        local site = settings.FamilyHunt and Hunt.pickSite(rng, me.hometown, md.huntTaken) or nil
        local plan = Story.familyPlan(rng, me, { darkness = settings.StoryDarkness, startDay = Util.nowDay(),
            site = site and Hunt.siteGroup(site.kind) or nil })
        md.story[sim.number] = { messages = plan.messages, next = 1, family = family, hometown = me.hometown }
        if site then
            md.huntTaken[site.id] = key
            md.story[sim.number].hunt = Hunt.new(rng, site, me, plan, family, sim.number)
            Util.log("family hunt for", key, "at", site.name, "(" .. site.x .. "," .. site.y .. "):",
                md.story[sim.number].hunt.outcome.kind)
        end
    end
    if settings.SurvivorTexts then
        local list = Story.survivorTexts(rng, rng:int(2, 4), { startDay = Util.nowDay() + 1, endDay = Util.nowDay() + 20 })
        -- One or two point to a stash (Core/Quests), never at a place another of this player's texts names.
        local used = {}
        for _, m in ipairs(list) do if m.place.site then used[m.place.site] = true end end
        local quests = Quests.make(rng, rng:int(1, 2), { startDay = Util.nowDay() + 1, endDay = Util.nowDay() + 20,
            trapChance = settings.QuestTrapChance, used = used })
        for _, q in ipairs(quests) do list[#list + 1] = q end
        table.sort(list, function(a, b) return a.day < b.day end)
        QuestsWorld.add(key, list)
        -- Every stranger texts from their own number.
        for _, m in ipairs(list) do m.from = Sim.issueNumber(md.numbers, rng) end
        md.players[key] = { number = sim.number, survivors = list, nextSurvivor = 1 }
    else
        md.players[key] = { number = sim.number }
    end
    Util.log("own SIM for", key, "number", sim.number)
end

-- Family texts say where they are: the family hunt's building (Core/Hunt), or the family house in their hometown.
-- Survivor texts name their place when they are made; this only fills plans saved before that.
local function fillPlace(body, place)
    return (body:gsub("{place}", (tostring(place):gsub("%%", "%%%%"))))
end

function Messaging.familyPlace(plan)
    if plan.hunt then return plan.hunt.name end
    return "the house in " .. tostring(plan.hometown or "town")
end

function Messaging.fillFamily(plan, body) return fillPlace(body, Messaging.familyPlace(plan)) end

-- Moves due family and survivor messages into the queue. Debug "fast-forward story" shifts the clock.
-- Once a family's last text is out, their hunt is armed: the scene is set the next time its chunk loads.
function Messaging.releaseStory()
    local md = State.get()
    local now = Util.nowDay() + (md.storyShift or 0)
    for number, plan in pairs(md.story) do
        while plan.next <= #plan.messages and plan.messages[plan.next].day <= now do
            local m = plan.messages[plan.next]
            Messaging.queueStory(plan.family[m.from] or "(502) 555-0000", number, Messaging.fillFamily(plan, m.body))
            -- The Map shows the family's place from the text that names it on.
            if tostring(m.body):find("{place}", 1, true) then plan.placeTold = true end
            plan.next = plan.next + 1
        end
        if plan.hunt and plan.hunt.state == "waiting" and plan.next > #plan.messages then HuntWorld.arm(plan.hunt) end
    end
    for _, p in pairs(md.players) do
        if p.survivors then
            while p.nextSurvivor <= #p.survivors and p.survivors[p.nextSurvivor].day <= now do
                local m = p.survivors[p.nextSurvivor]
                Messaging.queueStory(m.from or "(502) 555-0199", p.number, fillPlace(m.body, "the Muldraugh motel"))
                if m.questId then QuestsWorld.arm(m.questId) end
                p.nextSurvivor = p.nextSurvivor + 1
            end
        end
    end
end

return Messaging
