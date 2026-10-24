-- Client, multiplayer: other players' phone screens light their faces in the dark (others see a
-- glow; only you see your own live screen). The server says whose screen is on (Server.lua "activity" ->
-- "screenGlow"); each client keeps a small light at those players and moves it with them. Your own glow is
-- Hold.lua's.
local Net = require "KnoxMobile/Game/Net"
local Tick = require "KnoxMobile/Game/Tick"

local Glow = { on = {}, lights = {}, nextMs = 0 }
KnoxMobile.Glow = Glow

Net.onClient("screenGlow", function(args)
    if type(args.id) ~= "number" then return end
    Glow.on[args.id] = args.on == true or nil
end)

local function drop(id)
    local l = Glow.lights[id]
    if l then
        getCell():removeLamppost(l.light)
        Glow.lights[id] = nil
    end
end

Tick.add("screen glow", function()
    local t = getTimestampMs()
    if t < Glow.nextMs or not isClient() then return end
    Glow.nextMs = t + 500
    local dark = getClimateManager():getDayLightStrength() < 0.4
    local me = getPlayer()
    for id in pairs(Glow.lights) do
        if not Glow.on[id] or not dark then drop(id) end
    end
    if not dark then return end
    for id in pairs(Glow.on) do
        local p = getPlayerByOnlineID(id)
        if not p or p == me or p:isDead() then
            drop(id)
        else
            local x, y, z = math.floor(p:getX()), math.floor(p:getY()), math.floor(p:getZ())
            local l = Glow.lights[id]
            if l and (l.x ~= x or l.y ~= y or l.z ~= z) then drop(id); l = nil end
            if not l then
                local light = IsoLightSource.new(x, y, z, 0.45, 0.55, 0.7, 2)
                getCell():addLamppost(light)
                Glow.lights[id] = { light = light, x = x, y = y, z = z }
            end
        end
    end
end, 500)

return Glow
