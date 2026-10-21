-- Server: carrier messages. A server admin (Build 42 capability DisplayServerMessage, see Game/Access) sends one
-- text to every phone; it arrives from "KNOX MOBILE" and can't be answered. Restart warnings and events.
-- Carrier texts reach any phone that is on, with or without service (the carrier knows where its phones are);
-- a phone that is off, or an offline player's own SIM, gets it when it comes on, for one in-game day.
-- Rate-limited server-wide (Core/Carrier) and every one is written to the server console.
local Carrier = require "KnoxMobile/Core/Carrier"
local Protocol = require "KnoxMobile/Core/Protocol"
local MessageQueue = require "KnoxMobile/Core/MessageQueue"
local Phones = require "KnoxMobile/Game/Phones"
local Util = require "KnoxMobile/Game/Util"
local Net = require "KnoxMobile/Game/Net"
local Access = require "KnoxMobile/Game/Access"
local State = require "KnoxMobile/State"
local Messaging = require "KnoxMobile/Messaging"
local Social = require "KnoxMobile/SocialData"

local CarrierBroadcast = {}

Protocol.register({ carrierBroadcast = Carrier.validate })

local function queue(number, body, now)
    MessageQueue.send(State.get().queue, { from = Carrier.FROM, to = number, body = body, story = true, carrier = true,
        expiresAt = now + Carrier.TTL }, nil, nil, { queueMessages = true }, now)
end

-- Sends the text to every phone. Returns how many got it at once and how many wait for their phone.
function CarrierBroadcast.send(body)
    local now = Util.nowMinutes()
    local seen, delivered, waiting = {}, 0, 0
    for _, p in ipairs(Util.players()) do
        Social.track(p)
        for _, item in ipairs(Phones.inventoryPhones(p)) do
            local st = Phones.get(item)
            local number = st and st.sim and st.sim.number
            if number and not seen[number] then
                seen[number] = true
                if Messaging.usable(st) then
                    local day, minute = Messaging.stamp()
                    Messaging.appendRecord(st, { from = Carrier.FROM, body = body, carrier = true }, day, minute)
                    Phones.save(item, p)
                    Messaging.notifyTexts(p, item, st, { { from = Carrier.FROM, body = body } })
                    delivered = delivered + 1
                else
                    queue(number, body, now)
                    waiting = waiting + 1
                end
            end
        end
    end
    -- Offline players: their own SIM, wherever it is now.
    for _, info in pairs(State.get().players) do
        if info.number and not seen[info.number] then
            seen[info.number] = true
            queue(info.number, body, now)
            waiting = waiting + 1
        end
    end
    return delivered, waiting
end

Net.onServer("carrierBroadcast", function(player, args)
    local key = Util.playerKey(player)
    local function reply(status, extra)
        local out = { status = status }
        for k, v in pairs(extra or {}) do out[k] = v end
        Net.toClient(player, "carrierResult", out)
    end
    if not Access.canBroadcast(player) then
        Util.log("carrier message refused for", key, "(no DisplayServerMessage capability)")
        return reply("failed", { reason = "notAllowed" })
    end
    local body = Carrier.clean(args.body)
    if not body then return reply("failed", { reason = "badText" }) end
    local c = Social.data().carrier
    local now = getTimestampMs() / 1000
    local ok, why, wait = Carrier.allow(c, now)
    if not ok then return reply("failed", { reason = why, wait = wait }) end
    Carrier.record(c, now, key, body)
    local delivered, waiting = CarrierBroadcast.send(body)
    Util.log("CARRIER MESSAGE from", key, "to", delivered, "phones now,", waiting, "waiting:", body)
    reply("sent", { delivered = delivered, waiting = waiting })
end)

-- Stale carrier texts leave the queue (a restart warning from yesterday helps nobody).
Events.EveryTenMinutes.Add(Util.safe("carrier expiry", function()
    if isClient() then return end
    MessageQueue.purgeExpired(State.get().queue, Util.nowMinutes())
end))

return CarrierBroadcast
