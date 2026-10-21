-- Voice calls on the server (spec §9.7): who is calling whom, and the private radio channel each call uses.
-- Pure Lua 5.1. Channels sit far above any vanilla radio range, so no vanilla radio can listen in.
local Mod = require "KnoxMobile/Core/Mod"

local Calls = {}

Calls.FIRST_CHANNEL = 400000
Calls.CHANNEL_STEP = 10
-- Real seconds before an unanswered call gives up. A person has to hear it, open the phone and answer, so this
-- is not game time: two game minutes were 5 to 11 real seconds at the usual day lengths.
Calls.RING_SECONDS = 30

function Calls.new()
    return { nextId = 1, byId = {}, byNumber = {} }
end

local function busy(state, number) return state.byNumber[number] ~= nil end

-- Returns the call, or nil plus "busy" / "self". now: real time in seconds.
function Calls.start(state, from, to, now)
    if from == to then return nil, "self" end
    if busy(state, from) or busy(state, to) then return nil, "busy" end
    local id = state.nextId
    state.nextId = id + 1
    local call = { id = id, from = from, to = to, status = "ringing", startedAt = now,
        channel = Calls.FIRST_CHANNEL + (Mod.floor(id, 9000)) * Calls.CHANNEL_STEP }
    state.byId[id] = call
    state.byNumber[from], state.byNumber[to] = id, id
    return call
end

function Calls.answer(state, id, number)
    local call = state.byId[id]
    if not call or call.to ~= number or call.status ~= "ringing" then return nil end
    call.status = "active"
    return call
end

-- Either side hangs up (or the callee declines). Returns the ended call.
function Calls.hangUp(state, id, number)
    local call = state.byId[id]
    if not call or (call.from ~= number and call.to ~= number) then return nil end
    call.status = "ended"
    state.byId[id] = nil
    state.byNumber[call.from], state.byNumber[call.to] = nil, nil
    return call
end

-- Calls still ringing after RING_SECONDS end as "missed". Returns the missed calls. now: real time in seconds.
function Calls.expire(state, now)
    local missed = {}
    for id, call in pairs(state.byId) do
        if call.status == "ringing" and now - call.startedAt >= Calls.RING_SECONDS then
            missed[#missed + 1] = call
            Calls.hangUp(state, id, call.from)
            call.status = "missed"
        end
    end
    table.sort(missed, function(a, b) return a.id < b.id end)
    return missed
end

function Calls.forNumber(state, number)
    local id = state.byNumber[number]
    return id and state.byId[id] or nil
end

return Calls
