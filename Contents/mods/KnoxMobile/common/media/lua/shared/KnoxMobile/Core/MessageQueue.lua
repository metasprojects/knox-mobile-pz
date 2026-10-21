-- Server-side message delivery and queue (spec §7.5, §5.2 backlog, §13.4 caps). Pure Lua 5.1.
-- A network descriptor is { id, world = true when on the world network, members = { repeater ids } }.
-- Messages reach only phones on the same network; others wait in the queue (sandbox QueueMessages).
-- A queued message is lost when every repeater of its network is gone; story messages always arrive.

local MessageQueue = {}

MessageQueue.CONVERSATION_CAP = 200

function MessageQueue.new()
    return { queued = {}, nextId = 1 }
end

function MessageQueue.save(q)
    return { queued = q.queued, nextId = q.nextId }
end

function MessageQueue.load(data)
    if type(data) ~= "table" then return MessageQueue.new() end
    return { queued = data.queued or {}, nextId = data.nextId or 1 }
end

local function snapshot(net)
    if not net then return { world = false, members = {} } end
    local members = {}
    for i, m in ipairs(net.members or {}) do members[i] = m end
    return { world = net.world == true, members = members }
end

local function reachable(via, net)
    if not net then return false end
    if via.world and net.world then return true end
    for _, a in ipairs(via.members) do
        for _, b in ipairs(net.members or {}) do
            if a == b then return true end
        end
    end
    return false
end

local function sameNetwork(a, b)
    return a ~= nil and b ~= nil and a.id == b.id
end

-- Optional fields a message carries to the recipient's phone: its group thread, a carrier text (arrives on any
-- phone that is on, even without service, until expiresAt), an SOS location, a group event ("added", "removed").
local EXTRA = { "group", "groupName", "carrier", "sos", "event", "expiresAt" }

-- msg = { from, to, body, story, and EXTRA fields }. Returns "delivered" | "queued" | "failed", then the record or a reason.
function MessageQueue.send(q, msg, senderNet, recipientNet, settings, now)
    local record = { id = q.nextId, from = msg.from, to = msg.to, body = msg.body, story = msg.story == true, sentAt = now }
    for _, k in ipairs(EXTRA) do record[k] = msg[k] end
    if record.story then
        q.nextId = q.nextId + 1
        if recipientNet then return "delivered", record end
        record.via = { world = false, members = {} }
        q.queued[#q.queued + 1] = record
        return "queued", record
    end
    if not senderNet then return "failed", "noService" end
    if sameNetwork(senderNet, recipientNet) then
        q.nextId = q.nextId + 1
        return "delivered", record
    end
    if settings and settings.queueMessages == false then return "failed", "unreachable" end
    q.nextId = q.nextId + 1
    record.via = snapshot(senderNet)
    q.queued[#q.queued + 1] = record
    return "queued", record
end

local function expired(rec, now)
    return rec.expiresAt ~= nil and now ~= nil and rec.expiresAt <= now
end

-- Removes and returns, oldest first, every queued message this number can receive on its current network
-- (recipientNet nil: no service, so only carrier texts). Messages past their expiresAt are dropped.
function MessageQueue.deliverFor(q, number, recipientNet, now)
    local out, keep = {}, {}
    for _, rec in ipairs(q.queued) do
        local mine = rec.to == number
        if mine and (rec.carrier or (recipientNet and (rec.story or reachable(rec.via, recipientNet)))) then
            if not expired(rec, now) then out[#out + 1] = rec end -- a stale one is dropped
        elseif not (mine and expired(rec, now)) then
            keep[#keep + 1] = rec
        end
    end
    q.queued = keep
    table.sort(out, function(a, b)
        if a.sentAt == b.sentAt then return a.id < b.id end
        return a.sentAt < b.sentAt
    end)
    return out
end

function MessageQueue.pendingFor(q, number)
    local n = 0
    for _, rec in ipairs(q.queued) do if rec.to == number then n = n + 1 end end
    return n
end

-- aliveRepeaters: set of repeater ids still standing and powered. worldAlive: any tower still up.
-- Removes and returns the messages that can never arrive.
function MessageQueue.purgeLost(q, aliveRepeaters, worldAlive)
    local lost, keep = {}, {}
    for _, rec in ipairs(q.queued) do
        local alive = rec.story or (rec.via.world and worldAlive)
        if not alive then
            for _, m in ipairs(rec.via.members) do
                if aliveRepeaters[m] then alive = true; break end
            end
        end
        if alive then keep[#keep + 1] = rec else lost[#lost + 1] = rec end
    end
    q.queued = keep
    return lost
end

-- Removes and returns the messages past their expiresAt (stale carrier texts).
function MessageQueue.purgeExpired(q, now)
    local gone, keep = {}, {}
    for _, rec in ipairs(q.queued) do
        if expired(rec, now) then gone[#gone + 1] = rec else keep[#keep + 1] = rec end
    end
    q.queued = keep
    return gone
end

-- Adds a message to a conversation list, dropping the oldest beyond the cap.
function MessageQueue.appendToConversation(conv, record, cap)
    cap = cap or MessageQueue.CONVERSATION_CAP
    conv[#conv + 1] = record
    while #conv > cap do table.remove(conv, 1) end
    return conv
end

return MessageQueue
