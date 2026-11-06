-- Server: your answering machine (0.2.0). Any landline with power: record a greeting on it, and anyone who comes by
-- can leave a message on its tape, after the old one's. Play messages plays the house's own tape, then the greeting
-- and what was left since. Kept in the world's global ModData: machines["x,y,z"] = { greeting, messages }.
local Util = require "KnoxMobile/Game/Util"
local Net = require "KnoxMobile/Game/Net"
local Protocol = require "KnoxMobile/Core/Protocol"
local State = require "KnoxMobile/State"
local Messaging = require "KnoxMobile/Messaging"

local Machines = { KEEP = 12, REACH = 3 }
KnoxMobile.Machines = Machines

local function key(x, y, z) return math.floor(x) .. "," .. math.floor(y) .. "," .. math.floor(z) end

function Machines.get(x, y, z)
    local md = State.get()
    md.machines = md.machines or {}
    return md.machines[key(x, y, z)]
end

local function record(x, y, z)
    local md = State.get()
    md.machines = md.machines or {}
    local k = key(x, y, z)
    md.machines[k] = md.machines[k] or { messages = {} }
    return md.machines[k]
end

local function near(player, args)
    return math.abs(player:getX() - (args.x + 0.5)) <= Machines.REACH and math.abs(player:getY() - (args.y + 0.5)) <= Machines.REACH
        and math.floor(player:getZ()) == math.floor(args.z)
end

local function who(player)
    local desc = player.getDescriptor and player:getDescriptor()
    return desc and desc:getForename() or player:getUsername() or "Someone"
end

local function valid(args)
    if not (tonumber(args.x) and tonumber(args.y) and tonumber(args.z)) then return false, "x, y, z must be numbers" end
    if args.text ~= nil and (type(args.text) ~= "string" or #args.text < 1 or #args.text > 300) then
        return false, "text must be 1-300 characters"
    end
    return true
end
Protocol.register({ machineGet = valid, machineLeave = valid, machineGreeting = valid, machineLink = valid,
    machineRemote = function(args)
        if type(args.text) ~= "string" or #args.text < 1 or #args.text > 300 then return false, "text must be 1-300 characters" end
        return true
    end })

-- Your calls at home (after 0.3.0): "Take my calls here" links your number to this machine. A call to you that you
-- don't answer, or that can't reach you, plays its greeting and the caller leaves a message on its tape (still only
-- while the house has power). global ModData: machineFor[number] = { x, y, z, owner }.
local function links()
    local md = State.get()
    if type(md.machineFor) ~= "table" then md.machineFor = {} end
    return md.machineFor
end

function Machines.forNumber(number)
    local l = number and links()[number]
    if not l then return nil end
    local sq = getCell() and getCell():getGridSquare(l.x, l.y, l.z)
    if sq and not Util.powered(sq) then return nil end -- a loaded house with no power takes nothing
    return l
end

-- The caller reached the machine: the greeting, and a message may follow (machineRemote) for a few minutes.
Machines.pickups = {}
function Machines.pickUp(caller, number)
    local l = Machines.forNumber(number)
    if not (l and caller) then return false end
    local r = Machines.get(l.x, l.y, l.z) or {}
    Machines.pickups[Util.playerKey(caller)] = { to = number, at = Util.nowMinutes() }
    Net.toClient(caller, "machinePickup", { to = number, greeting = r.greeting and r.greeting.text or nil })
    return true
end

function Machines.leave(player, args)
    if not near(player, args) then return false end
    local r = record(args.x, args.y, args.z)
    local day, minute = Messaging.stamp()
    r.messages[#r.messages + 1] = { from = who(player), text = args.text, day = day, minute = minute }
    while #r.messages > Machines.KEEP do table.remove(r.messages, 1) end
    return true
end

function Machines.greet(player, args)
    if not near(player, args) then return false end
    record(args.x, args.y, args.z).greeting = { by = who(player), text = args.text }
    return true
end

Net.onServer("machineGet", function(player, args)
    local r = Machines.get(args.x, args.y, args.z) or {}
    Net.toClient(player, "machineData", { x = args.x, y = args.y, z = args.z, greeting = r.greeting, messages = r.messages or {} })
end)

Net.onServer("machineLeave", function(player, args)
    if args.text and Machines.leave(player, args) then Util.log("machine message left at", key(args.x, args.y, args.z)) end
end)

Net.onServer("machineGreeting", function(player, args)
    if args.text then Machines.greet(player, args) end
end)

Net.onServer("machineLink", function(player, args)
    if not near(player, args) then return end
    local item = require("KnoxMobile/Game/Phones").findById(player, tonumber(args.phoneId) or -1)
    local st = item and require("KnoxMobile/Game/Phones").get(item)
    local number = st and st.sim and st.sim.number
    if not number then return end
    local l = links()
    if args.off then
        if l[number] and l[number].owner == Util.playerKey(player) then l[number] = nil end
        Net.toClient(player, "notify", { kind = "machine", event = "unlinked", number = number })
        return
    end
    l[number] = { x = math.floor(args.x), y = math.floor(args.y), z = math.floor(args.z), owner = Util.playerKey(player) }
    record(args.x, args.y, args.z)
    Util.log("machine at", key(args.x, args.y, args.z), "takes calls for", number)
    Net.toClient(player, "notify", { kind = "machine", event = "linked", number = number })
end)

Net.onServer("machineRemote", function(player, args)
    local p = Machines.pickups[Util.playerKey(player)]
    Machines.pickups[Util.playerKey(player)] = nil
    if not p or Util.nowMinutes() - p.at > 10 then return end
    local l = Machines.forNumber(p.to)
    if not l then return end
    local r = record(l.x, l.y, l.z)
    local day, minute = Messaging.stamp()
    r.messages[#r.messages + 1] = { from = who(player), text = args.text, day = day, minute = minute, phoned = true }
    while #r.messages > Machines.KEEP do table.remove(r.messages, 1) end
    Util.log("machine message by phone for", p.to)
end)

return Machines
