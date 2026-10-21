-- Server: calls from vanilla payphones (1993 hardware). The client asks ("payphoneCall" with the payphone's square
-- and a number); the server checks the payphone is there, the player stands at it, it has power (the square's own or
-- the grid's, as vanilla checks appliances), then rings the other phone through the normal call code. The caller
-- end needs no phone: the call drops when they walk away or the power goes.
local Mod = require "KnoxMobile/Core/Mod"
local Calls = require "KnoxMobile/Core/Calls"
local Payphone = require "KnoxMobile/Core/Payphone"
local Protocol = require "KnoxMobile/Core/Protocol"
local Sim = require "KnoxMobile/Core/Sim"
local Rng = require "KnoxMobile/Core/Rng"
local Util = require "KnoxMobile/Game/Util"
local Net = require "KnoxMobile/Game/Net"
local State = require "KnoxMobile/State"
local Messaging = require "KnoxMobile/Messaging"

local Payphones = {}

local function int(v) return type(v) == "number" and Mod.floor(v, 1) == 0 end

Protocol.register({
    payphoneCall = function(args)
        if not (int(args.x) and int(args.y) and int(args.z)) or args.z < 0 or args.z > 7 then return false, "bad square" end
        if type(args.to) ~= "string" or Sim.normalise(args.to) ~= args.to then return false, "to is not a normalised phone number" end
        return true
    end,
})

function Payphones.square(x, y, z)
    local cell = getCell()
    return cell and cell:getGridSquare(x, y, z) or nil
end

function Payphones.onSquare(sq)
    local objects = sq and sq:getObjects()
    if not objects then return nil end
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        local props = obj.getProperties and obj:getProperties()
        if props and Payphone.isPayphone(props:get("CustomName"), props:get("GroupName")) then return obj end
    end
    return nil
end

-- Like vanilla's appliance checks (ISVehicleMenu): a generator's power on the square, or the grid's.
function Payphones.powered(sq)
    return sq:haveElectricity() == true or sq:hasGridPower() == true
end

-- The payphone's own number, issued from the SIM registry the first time it is used.
function Payphones.numberFor(x, y, z)
    local md = State.get()
    if type(md.payphones) ~= "table" then md.payphones = {} end
    local key = Payphone.key(x, y, z)
    if not md.payphones[key] then
        md.payphones[key] = Sim.issueNumber(md.numbers, Rng.new(tostring(md.seed) .. ":payphone:" .. key))
    end
    return md.payphones[key]
end

-- Still at a working payphone (checked every game minute while the call lasts).
function Payphones.callerStillThere(player, spot)
    if not player or not spot then return false end
    local sq = Payphones.square(spot.x, spot.y, spot.z)
    return sq ~= nil and Payphones.powered(sq)
        and Payphone.near(player:getX(), player:getY(), player:getZ(), spot.x, spot.y, spot.z, Payphone.LEAVE)
end

Net.onServer("payphoneCall", function(player, args)
    local function fail(reason) Net.toClient(player, "callFailed", { reason = reason, to = args.to }) end
    local sq = Payphones.square(args.x, args.y, args.z)
    if not sq or not Payphones.onSquare(sq) then return end
    if not Payphone.near(player:getX(), player:getY(), player:getZ(), args.x, args.y, args.z, Payphone.REACH + 0.5) then return end
    if not Payphones.powered(sq) then return fail("noPower") end
    if not State.voiceEnabled() then return fail("noVoice") end
    local from = Payphones.numberFor(args.x, args.y, args.z)
    local rPlayer, rItem, _, rModel = Messaging.findNumber(args.to)
    if not rPlayer then return fail("unreachable") end
    if not Messaging.service(rPlayer, rModel).network then return fail("unreachable") end
    local call, why = Calls.start(State.calls, from, args.to, getTimestampMs() / 1000)
    if not call then return fail(why) end
    call.callerKey, call.calleeKey = Util.playerKey(player), Util.playerKey(rPlayer)
    call.calleePhone = rItem:getID()
    call.payphone = { x = args.x, y = args.y, z = args.z }
    call.calleeLog = Messaging.logCall(rPlayer, rItem, from, true)
    Net.toClient(player, "callRinging", { callId = call.id, to = args.to, payphone = true })
    Net.toClient(rPlayer, "incomingCall", { callId = call.id, from = from, phoneId = rItem:getID() })
end)

return Payphones
