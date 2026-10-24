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
Protocol.register({ machineGet = valid, machineLeave = valid, machineGreeting = valid })

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

return Machines
