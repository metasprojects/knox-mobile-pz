-- Server: conference calls (after 0.3.0). "Call the group" in a group chat rings every member who is online with
-- service; everyone who answers talks on one shared channel, above the two-person calls' range. Hang up and the
-- others carry on; the last one left is hung up. Calls ids are "c<n>" so the usual answer and hang-up reach here
-- (Server.lua answerCall / endCall). Kept in memory only: a restart ends every call anyway.
local Groups = require "KnoxMobile/Core/Groups"
local Protocol = require "KnoxMobile/Core/Protocol"
local Calls = require "KnoxMobile/Core/Calls"
local Util = require "KnoxMobile/Game/Util"
local Mod = require "KnoxMobile/Core/Mod"
local Net = require "KnoxMobile/Game/Net"
local Tick = require "KnoxMobile/Game/Tick"
local State = require "KnoxMobile/State"
local Messaging = require "KnoxMobile/Messaging"
local Social = require "KnoxMobile/SocialData"
local Burners = require "KnoxMobile/Burners"

local Conference = { byId = {}, nextId = 1, FIRST_CHANNEL = 495000, MAX = 8 }
KnoxMobile.Conference = Conference

Protocol.register({ groupCall = function(args)
    if type(args.phoneId) ~= "number" or type(args.group) ~= "string" then return false, "phoneId and group" end
    return true
end })

function Conference.isId(id) return type(id) == "string" and id:sub(1, 1) == "c" end

local function playerByKey(key)
    for _, p in ipairs(Util.players()) do if Util.playerKey(p) == key then return p end end
    return nil
end

local function count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

local function hangUpFor(conf, key, reason)
    local p = playerByKey(key)
    if p then Net.toClient(p, "callEnd", { callId = conf.id, reason = reason }) end
end

-- Nobody left to talk to: the last one is hung up and the call is gone.
local function settle(conf)
    if count(conf.invites) > 0 or count(conf.members) > 1 then return end
    for key in pairs(conf.members) do hangUpFor(conf, key, "hungUp") end
    Conference.byId[conf.id] = nil
    Util.log("conference", conf.id, "ended")
end

Net.onServer("groupCall", function(player, args)
    local function fail(reason) Net.toClient(player, "callFailed", { reason = reason }) end
    if not State.voiceEnabled() then return fail("noVoice") end
    local item, state, model = Social.phone(player, args)
    if not item then return fail(state) end
    if not Messaging.service(player, model).network then return fail("noService") end
    local number = state.sim.number
    local g = Social.data().groups.byId[args.group]
    if not (g and Groups.isMember(g, number, Burners.key(player, number))) then return fail("unreachable") end
    local id = "c" .. Conference.nextId
    local conf = { id = id, name = g.name, members = {}, invites = {},
        channel = Conference.FIRST_CHANNEL + Mod.floor(Conference.nextId, 900) * Calls.CHANNEL_STEP }
    Conference.nextId = Conference.nextId + 1
    local now = getTimestampMs() / 1000
    for _, n in ipairs(Groups.recipients(g, number, Social.numberOf)) do
        local p, it, _, m = Messaging.findNumber(n)
        if p and p ~= player and count(conf.invites) < Conference.MAX - 1 and Messaging.service(p, m).network then
            conf.invites[Util.playerKey(p)] = { number = n, at = now }
            Net.toClient(p, "incomingCall", { callId = id, from = g.name, phoneId = it:getID() })
        end
    end
    if count(conf.invites) == 0 then return fail("unreachable") end
    conf.members[Util.playerKey(player)] = number
    Conference.byId[id] = conf
    Util.log("conference", id, "for", g.name, "rings", count(conf.invites), "phones")
    Net.toClient(player, "callRinging", { callId = id, to = g.name })
    Net.toClient(player, "callStart", { callId = id, channel = conf.channel, partner = -1, quality = 0.75 })
end)

-- From Server.lua's answerCall.
function Conference.answer(player, args)
    local conf = Conference.byId[args.callId]
    local key = Util.playerKey(player)
    local invite = conf and conf.invites[key]
    if not invite then return end
    conf.invites[key] = nil
    conf.members[key] = invite.number
    Net.toClient(player, "callStart", { callId = conf.id, channel = conf.channel, partner = -1, quality = 0.75 })
end

-- From Server.lua's endCall: a member hangs up, or an invited phone declines.
function Conference.hangUp(player, args)
    local conf = Conference.byId[args.callId]
    if not conf then return end
    local key = Util.playerKey(player)
    if not (conf.members[key] or conf.invites[key]) then return end
    conf.members[key], conf.invites[key] = nil, nil
    hangUpFor(conf, key, "hungUp")
    settle(conf)
end

-- Phones that didn't answer in time stop ringing.
function Conference.expire(now)
    for _, conf in pairs(Conference.byId) do
        for key, inv in pairs(conf.invites) do
            if now - inv.at > Calls.RING_SECONDS then
                conf.invites[key] = nil
                hangUpFor(conf, key, "missed")
            end
        end
        settle(conf)
    end
end

Tick.add("conference calls", function()
    if isClient() then return end
    Conference.expire(getTimestampMs() / 1000)
end, 1000)

return Conference
