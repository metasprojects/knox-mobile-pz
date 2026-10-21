-- Which way can this phone charge right now? (spec §6.4, §6.5). Pure Lua 5.1.
-- The game adapter describes what the player has and where they are; this picks the best option.
--
-- items: list of accessory descriptors the player carries, each { id, kind, connector, source, setup }
--        (kinds from Data/Accessories: "charger", "cable", "usbSource"); plus counts:
-- env:   { squarePowered, inCar, carRunning, carHasBattery, outside, daylight, cloud, cranking,
--          hasCarBattery (a loose car battery item), aaCount, bankStore }
-- Returns { source, via = { item ids }, setup } or nil plus a reason code: "noFit" (nothing fits the phone) or the
-- source that fits but has no power here ("wall", "powerBank"...). The client words the codes (Data/Messages.words).

local Registry = require "KnoxMobile/Core/Registry"

local Charging = {}

-- Faster sources first; the first one that works wins.
local ORDER = { "wall", "car", "carBatteryClip", "powerBank", "solar", "aa", "crank" }

local function find(items, pred)
    for _, it in ipairs(items) do if pred(it) then return it end end
    return nil
end

local function sourceAvailable(source, env)
    if source == "wall" then return env.squarePowered == true end
    if source == "car" then return env.inCar == true and (env.carRunning == true or env.carHasBattery == true) end
    if source == "carBatteryClip" then return env.hasCarBattery == true end
    if source == "powerBank" then return (env.bankStore or 0) > 0 end
    if source == "solar" then return env.outside == true and env.daylight == true end
    if source == "aa" then return (env.aaCount or 0) > 0 end
    if source == "crank" then return env.cranking == true end
    return false
end

-- How the phone connects: a matching integrated charger for this source, or a matching cable plus a USB
-- source of this type, or (wall only) the multi-tip charger. exactChargers=false lets any plug fit.
local function connection(registry, connector, source, items, exactChargers)
    local opts = { exactChargers = exactChargers }
    local integrated = find(items, function(it)
        return it.kind == "charger" and it.source == source
            and registry:canCharge(connector, { kind = it.setup or "integrated", connector = it.connector }, opts)
    end)
    if integrated then return { kind = integrated.setup or "integrated", connector = integrated.connector }, { integrated.id } end
    if Registry.isUsbConnector(connector) or exactChargers == false then
        local cable = find(items, function(it)
            return it.kind == "cable" and registry:canCharge(connector, { kind = "cable", connector = it.connector }, opts)
        end)
        local usb = find(items, function(it) return it.kind == "usbSource" and it.source == source end)
        if cable and usb then return { kind = "cable", connector = cable.connector }, { cable.id, usb.id } end
    end
    return nil
end

-- only: one source to use (the crank action charges from the crank, never the best source around).
function Charging.choose(registry, model, items, env, settings, only)
    local exact = not (settings and settings.exactChargers == false)
    local why = nil
    for _, source in ipairs(only and { only } or ORDER) do
        local setup, via = connection(registry, model.connector, source, items, exact)
        if setup then
            if sourceAvailable(source, env) then return { source = source, via = via, setup = setup } end
            -- The fastest charger that fits explains why there's no charge.
            why = why or source
        end
    end
    if why then return nil, why end
    -- A USB phone with half a setup says which half is missing (second pass: "no charger or cable fits it" with the
    -- cable in the bag).
    if Registry.isUsbConnector(model.connector) then
        local opts = { exactChargers = exact }
        local cable = find(items, function(it)
            return it.kind == "cable" and registry:canCharge(model.connector, { kind = "cable", connector = it.connector }, opts)
        end)
        local usb = find(items, function(it) return it.kind == "usbSource" end)
        if cable and not usb then return nil, "needAdapter" end
        if usb and not cable then return nil, "needCable" end
    end
    return nil, "noFit"
end

-- Is a charge that already started still connected? (Walking away from the outlet unplugs it.)
-- When not, the reason code is "walkedAway", "powerOut" or the source that stopped ("powerBank", "solar"...).
function Charging.stillConnected(plug, env)
    if not plug then return false end
    if plug.source == "wall" then
        if env.distanceToPlug and env.distanceToPlug > 3 then return false, "walkedAway" end
        if env.squarePowered == true or env.plugSquarePowered == true then return true end
        return false, "powerOut"
    end
    local ok = sourceAvailable(plug.source, env)
    if not ok then return false, plug.source end
    return true
end

return Charging
