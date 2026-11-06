-- Server: Find my car (0.3.0, client/FindMyCar.lua). Where each player last got out of a vehicle, in the world's
-- global ModData: cars[player key] = { x, y, at }. Server.lua's mapPlaces shows it as "Your car".
local Net = require "KnoxMobile/Game/Net"
local Util = require "KnoxMobile/Game/Util"
local State = require "KnoxMobile/State"
local Protocol = require "KnoxMobile/Core/Protocol"

local Cars = {}

Protocol.register({
    carParked = function(args)
        if type(args.x) ~= "number" or type(args.y) ~= "number" then return false, "x and y must be numbers" end
        return true
    end,
})

-- The player's car, or nil.
function Cars.of(player)
    local md = State.get()
    return type(md.cars) == "table" and md.cars[Util.playerKey(player)] or nil
end

Net.onServer("carParked", function(player, args)
    -- Only where the player is standing (a client can't park a car across the map).
    if math.abs(args.x - player:getX()) > 8 or math.abs(args.y - player:getY()) > 8 then return end
    local md = State.get()
    if type(md.cars) ~= "table" then md.cars = {} end
    md.cars[Util.playerKey(player)] = { x = math.floor(args.x), y = math.floor(args.y), at = Util.nowMinutes() }
end)

KnoxMobile.Cars = Cars
return Cars
