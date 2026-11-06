-- Client: Find my car (0.3.0). Getting out of a vehicle (the game's OnExitVehicle, ISExitVehicle) tells the server
-- where it was left; the Map shows "Your car" there on phones with a map (server mapPlaces, server/Cars.lua).
-- The game adds OnExitVehicle in its own client Lua (ISVehicleDashboard.lua), which may load after this file: hook it
-- now if it's there, else when the game starts.
local Net = require "KnoxMobile/Game/Net"
local Util = require "KnoxMobile/Game/Util"

local hooked = false
local function onExit(character)
    if not (character and character.isLocalPlayer and character:isLocalPlayer()) then return end
    Net.toServer(character, "carParked", { x = math.floor(character:getX()), y = math.floor(character:getY()) })
end

local function hook()
    if hooked or not Events.OnExitVehicle then return end
    hooked = true
    Events.OnExitVehicle.Add(Util.safe("find my car", onExit))
end

hook()
Events.OnGameStart.Add(hook)
