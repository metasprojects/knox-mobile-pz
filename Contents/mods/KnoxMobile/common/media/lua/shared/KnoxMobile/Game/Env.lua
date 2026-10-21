-- A snapshot of what a player has and where they are, for charging, wetness and signal (spec §6.5, §9.3).
local Util = require "KnoxMobile/Game/Util"
local Phones = require "KnoxMobile/Game/Phones"

local Env = {}

local function carBattery(player)
    for _, t in ipairs({ "Base.CarBattery1", "Base.CarBattery2", "Base.CarBattery3" }) do
        local list = player:getInventory():getAllTypeRecurse(t)
        for i = 0, list:size() - 1 do
            local b = list:get(i)
            if b.getCurrentUsesFloat and b:getCurrentUsesFloat() > 0.01 then return b end
        end
    end
    return nil
end

local function aaBatteries(player)
    local out = {}
    local list = player:getInventory():getAllTypeRecurse("Base.Battery")
    for i = 0, list:size() - 1 do
        local b = list:get(i)
        if b:getCurrentUsesFloat() > 0.001 then out[#out + 1] = b end
    end
    return out
end

local function powerBank(player)
    local list = player:getInventory():getAllTypeRecurse("KnoxMobile.PowerBank")
    for i = 0, list:size() - 1 do
        local b = list:get(i)
        if Phones.bankStore(b) > 0 then return b end
    end
    return nil
end

function Env.snapshot(player)
    local sq = player:getCurrentSquare()
    local climate = getClimateManager()
    local veh = player:getVehicle()
    local aa = aaBatteries(player)
    local bank = powerBank(player)
    local carBat = carBattery(player)
    local env = {
        x = player:getX(), y = player:getY(), z = player:getZ(),
        squarePowered = sq ~= nil and Util.powered(sq) or false,
        outside = sq ~= nil and sq:isOutside() or false,
        inCar = veh ~= nil, vehicle = veh,
        carRunning = veh ~= nil and veh:isEngineRunning() or false,
        carHasBattery = veh ~= nil and veh:hasLiveBattery() or false,
        daylight = climate:getDayLightStrength() > 0.35,
        cloud = climate:getCloudIntensity(),
        raining = climate:isRaining() and climate:getRainIntensity() > 0.05,
        freezing = climate:getTemperature() < 0,
        cranking = player:getModData().KnoxMobileCranking == true,
        hasCarBattery = carBat ~= nil, carBatteryItem = carBat,
        aaCount = #aa, aaItems = aa,
        bankStore = bank and Phones.bankStore(bank) or 0, bankItem = bank,
        wetness = player:getStats():get(CharacterStat.WETNESS) or 0,
    }
    return env
end

return Env
