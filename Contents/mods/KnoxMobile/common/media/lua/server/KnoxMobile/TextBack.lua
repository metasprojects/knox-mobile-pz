-- Server: texting back a found phone's people (0.2.0; Core/Replies decides who answers and what they say). The
-- player's SIM goes in the dead owner's phone; Messages then lets them answer Mom, the friend, work or a squad mate.
-- One answer for each text, after a while, and only while the phone is on and in service (it waits otherwise). A
-- family member who has let go can point to a bag they left at a real place: a survivor stash (Quests.lua), on the Map.
local Phones = require "KnoxMobile/Game/Phones"
local Util = require "KnoxMobile/Game/Util"
local Net = require "KnoxMobile/Game/Net"
local Tick = require "KnoxMobile/Game/Tick"
local Rng = require "KnoxMobile/Core/Rng"
local Replies = require "KnoxMobile/Core/Replies"
local Quests = require "KnoxMobile/Core/Quests"
local Protocol = require "KnoxMobile/Core/Protocol"
local State = require "KnoxMobile/State"
local Messaging = require "KnoxMobile/Messaging"
local QuestsWorld = require "KnoxMobile/Quests"
local Hunt = require "KnoxMobile/Core/Hunt"
local Sites = require "KnoxMobile/Story/Sites"

local TextBack = { nextAt = 0 }
KnoxMobile.TextBack = TextBack

local CHECK_MS = 5000

Protocol.register({
    textBack = function(args)
        if type(args.with) ~= "string" or not Replies.ROLES[args.with] then return false, "with must be a story thread" end
        if type(args.body) ~= "string" or #args.body < 1 or #args.body > Protocol.MAX_TEXT then
            return false, "body must be 1-" .. Protocol.MAX_TEXT .. " characters"
        end
        return true
    end,
})

local function threadOf(state, with)
    for _, c in ipairs(state.contents.texts or {}) do if c.with == with then return c end end
    return nil
end

local function inService(player, state, model)
    if not Messaging.usable(state) then return false end
    local located = Messaging.service(player, model)
    return located ~= nil and located.network ~= nil
end

-- The player's text into the thread; an answer is set for later. Returns status, reason (as sendText does).
function TextBack.send(player, item, with, body)
    local state, model = Phones.get(item)
    if not (state and state.owner and state.owner.kind == "generated" and state.story) then return "failed", "unreachable" end
    if not Messaging.usable(state) then return "failed", "phoneOff" end
    if state.security.locked then return "failed", "locked" end
    if not inService(player, state, model) then return "failed", "noService" end
    local conv = threadOf(state, with)
    if not conv then return "failed", "unreachable" end
    local day, minute = Messaging.stamp()
    conv.messages[#conv.messages + 1] = { day = day, minute = minute, inbound = false, body = body }
    state.story.replies = state.story.replies or {}
    local r = state.story.replies[with]
    if not r then
        local rng = Rng.new(tostring(item:getID()) .. ":reply:" .. with)
        r = { sent = 0, answered = 0, fate = Replies.fate(rng, with), stash = with ~= "mate" and rng:chance(0.5),
            home = Replies.HOME_ROLES[with] == true and rng:chance(Replies.HOME_CHANCE) }
        state.story.replies[with] = r
    end
    r.sent = r.sent + 1
    if r.fate == "bounce" then
        conv.messages[#conv.messages + 1] = { day = day, minute = minute, inbound = true, body = Replies.BOUNCE }
    elseif r.fate == "alive" and not r.done and not r.dueAt then
        r.dueAt = Util.nowMinutes() + Replies.delay(Rng.new(tostring(item:getID()) .. ":delay:" .. with .. r.sent), r.answered + 1)
    end
    Phones.save(item, player)
    return "delivered"
end

-- The bag a family member points to: a survivor stash for this player at a real place none of their texts named.
local function makeStash(player, rng)
    local key = Util.playerKey(player)
    local used = {}
    for _, q in pairs(State.get().quests) do used[q.site] = true end
    local list = Quests.make(rng, 1, { startDay = Util.nowDay(), endDay = Util.nowDay(), trapChance = 0, used = used })
    if not list[1] then return nil end
    QuestsWorld.add(key, list)
    return list[1].questId, list[1].place.name
end

-- Where the dead owner lived: a real house (Story/Sites), not one a player's family story uses.
local function pickHome(state, rng)
    local md = State.get()
    md.homesTaken = md.homesTaken or {}
    local taken = {}
    for id in pairs(md.huntTaken or {}) do taken[id] = true end
    for id in pairs(md.homesTaken) do taken[id] = true end
    local houses = {}
    for _, s in ipairs(Sites.family) do if s.kind == "house" then houses[#houses + 1] = s end end
    local site = Hunt.pickSite(rng, state.owner.hometown, taken, houses) or rng:pick(houses)
    if site then md.homesTaken[site.id] = true end
    return site
end

-- Answers that are due on this player's phones (on and in service).
function TextBack.deliver(player)
    local now = Util.nowMinutes()
    for _, item in ipairs(Phones.inventoryPhones(player)) do
        local state, model = Phones.get(item)
        local replies = state and state.story and state.story.replies
        if replies and inService(player, state, model) then
            local said = {}
            for with, r in pairs(replies) do
                if r.dueAt and r.dueAt <= now then
                    local conv = threadOf(state, with)
                    local n = r.answered + 1
                    local rng = Rng.new(tostring(item:getID()) .. ":say:" .. with .. ":" .. n)
                    if n == 4 and r.stash and not r.place then r.questId, r.place = makeStash(player, rng) end
                    local body, stash = Replies.next(rng, with, n, { owner = state.owner.first, place = r.place })
                    r.dueAt, r.answered = nil, n
                    if not body or not conv then
                        r.done = true
                    else
                        local day, minute = Messaging.stamp()
                        conv.messages[#conv.messages + 1] = { day = day, minute = minute, inbound = true, unread = true, body = body }
                        said[#said + 1] = { from = conv.name, body = body }
                        if stash and r.questId then
                            QuestsWorld.arm(r.questId)
                            if KnoxMobile.Journal then
                                KnoxMobile.Journal.add(player, conv.name .. " told me about a bag at " .. r.place .. ".")
                            end
                        end
                        -- Letting go, and where home was: the phone can go back there (Actions takeHome).
                        local site = n == 3 and r.home and not state.story.home and pickHome(state, rng)
                        if site then
                            state.story.home = { id = site.id, name = site.name, x = site.x, y = site.y, from = conv.name }
                            local home = Replies.home(rng, { home = site.name, owner = state.owner.first })
                            conv.messages[#conv.messages + 1] = { day = day, minute = minute, inbound = true, unread = true,
                                body = home }
                            said[#said + 1] = { from = conv.name, body = home }
                        end
                        if n == 3 and with ~= "mate" and KnoxMobile.Journal then
                            KnoxMobile.Journal.add(player, conv.name .. " knows about " .. state.owner.first .. " now. I told them."
                                .. (site and (" Home was " .. site.name .. ".") or ""))
                        elseif n == 1 and with == "mate" and KnoxMobile.Journal then
                            KnoxMobile.Journal.add(player, state.owner.first .. "'s crew know somebody has the phone.")
                        end
                        -- One answer per text: more waiting texts get the next one later.
                        if r.sent > r.answered then r.dueAt = now + Replies.delay(rng, n + 1) end
                    end
                end
            end
            if #said > 0 then
                Phones.save(item, player)
                Messaging.notifyTexts(player, item, state, said)
            end
        end
    end
end

-- The phone is home (Actions takeHome): a line in the journal, and how many have gone home so far.
function TextBack.returned(player, state)
    local md = State.get()
    md.returned = md.returned or {}
    local key = Util.playerKey(player)
    md.returned[key] = (md.returned[key] or 0) + 1
    local count = md.returned[key]
    local who = state.owner.first .. (state.owner.last and (" " .. state.owner.last) or "")
    Util.log("phone taken home:", who, "to", tostring(state.story.home.name), "by", key)
    if KnoxMobile.Journal then
        KnoxMobile.Journal.add(player, "Took " .. who .. "'s phone home to " .. state.story.home.name .. "."
            .. (count > 1 and (" That's " .. count .. " I've brought home.") or ""))
    end
end

Net.onServer("textBack", function(player, args)
    local item = args.phoneId and Phones.findById(player, args.phoneId)
    if not item or not Phones.isPhone(item) then return end
    local status, reason = TextBack.send(player, item, args.with, args.body)
    Net.toClient(player, "textResult", { status = status, reason = reason, to = args.with })
end)

Tick.add("text back", function()
    if isClient() then return end
    local t = getTimestampMs()
    if t < TextBack.nextAt then return end
    TextBack.nextAt = t + CHECK_MS
    for _, player in ipairs(Util.players()) do
        if not player:isDead() then TextBack.deliver(player) end
    end
end, 1000)

return TextBack
