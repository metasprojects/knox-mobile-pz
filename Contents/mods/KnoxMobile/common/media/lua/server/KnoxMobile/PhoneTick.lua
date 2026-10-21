-- Server: once per in-game minute, every carried phone drains, charges and gets wet (spec Â§6, Â§9.3, Â§13.7).
-- Also the slow gear: power banks refilling at a wall and spare batteries on a desktop charger.
-- The server is the authority; clients only report which phone is open and what it is doing.
local Power = require "KnoxMobile/Core/Power"
local Charging = require "KnoxMobile/Core/Charging"
local Damage = require "KnoxMobile/Core/Damage"
local Upkeep = require "KnoxMobile/Core/Upkeep"
local Phones = require "KnoxMobile/Game/Phones"
local Env = require "KnoxMobile/Game/Env"
local Util = require "KnoxMobile/Game/Util"
local Net = require "KnoxMobile/Game/Net"
local Alarm = require "KnoxMobile/Core/Alarm"
local Alarms = require "KnoxMobile/Alarms"
local Flashlight = require "KnoxMobile/Flashlight"

local PhoneTick = {}

-- playerKey -> { phoneId, state = "idle"|"screen"|"audio"|"games"|"video", flashlight }
PhoneTick.activity = {}

local AA_POINTS = 15        -- one full AA battery holds this many modern percent points
local CAR_POINTS = 600      -- a car battery holds about six modern charges
local BATTERY_CASE = 1.5    -- a battery case gives modern phones half again the battery life (spec Â§9.4)
local PLUG_REACH = 3        -- tiles from the outlet before the cable pulls out

local function distance(env, plug)
    if not plug.x then return 0 end
    local dx, dy = env.x - plug.x, env.y - plug.y
    return math.sqrt(dx * dx + dy * dy) + math.abs((env.z or 0) - (plug.z or 0)) * 3
end

local function plugSquarePowered(plug)
    if not plug.x then return false end
    local sq = getCell():getGridSquare(math.floor(plug.x), math.floor(plug.y), math.floor(plug.z or 0))
    return sq ~= nil and Util.powered(sq)
end

local function chargeInfo(env, plug)
    local info = { daylight = env.daylight, cloud = env.cloud, cranking = env.cranking }
    if plug.source == "powerBank" and env.bankItem then info.bank = { store = Phones.bankStore(env.bankItem) } end
    if plug.source == "aa" then
        local points = 0
        for _, b in ipairs(env.aaItems) do points = points + b:getCurrentUsesFloat() * AA_POINTS end
        info.aa = { store = points }
    end
    return info
end

-- Spend what the charge used from banks, AA batteries, car batteries and the car.
local function settleStores(player, env, plug, info, gained)
    if plug.source == "powerBank" and env.bankItem and info.bank then
        env.bankItem:getModData().KnoxMobileStore = info.bank.store
        Phones.save(env.bankItem, player)
    elseif plug.source == "aa" and info.aa then
        local left = info.aa.store / AA_POINTS
        for _, b in ipairs(env.aaItems) do
            local take = math.min(b:getCurrentUsesFloat(), left)
            b:setCurrentUsesFloat(take)
            left = left - take
            if isServer() then syncItemFields(player, b) end
        end
    elseif plug.source == "carBatteryClip" and env.carBatteryItem then
        local b = env.carBatteryItem
        b:setCurrentUsesFloat(math.max(0, b:getCurrentUsesFloat() - gained / CAR_POINTS))
        if isServer() then syncItemFields(player, b) end
    elseif plug.source == "car" and env.vehicle and not env.carRunning then
        -- With the engine off the phone runs the car's own battery down (spec Â§6.5).
        local part = env.vehicle:getBattery()
        local b = part and part:getInventoryItem()
        if b then
            b:setCurrentUsesFloat(math.max(0, b:getCurrentUsesFloat() - gained / CAR_POINTS))
            env.vehicle:transmitPartUsedDelta(part)
        end
    end
end

local function powerSettingsFor(state, model, ps)
    if state.look.case ~= "Battery" or not Power.isModern(model) then return ps end
    local out = {}
    for k, v in pairs(ps) do out[k] = v end
    out.batteryLife = (ps.batteryLife or 1) * BATTERY_CASE
    return out
end

-- What the owner's screen shows. The server syncs a phone's data only when this changes: syncing every minute
-- sent the whole phone (texts and all) every couple of seconds, and far more often while sleeping.
local function visible(state)
    local plug = state.plug
    return table.concat({ math.floor(state.battery.charge), tostring(state.power.on), plug and plug.source or "-",
        tostring(plug and plug.saidFull), state.wetness or "", state.condition or "" }, "|")
end

local function tickPhone(player, item, env, settings, ps, minutes)
    local state, model = Phones.get(item)
    if not state then return end
    local shown = visible(state)
    local changed = false
    local key = Util.playerKey(player)
    ps = powerSettingsFor(state, model, ps)

    -- Drain: the open phone uses its app's activity; other phones that are on sit idle.
    if state.power.on and state.condition ~= "broken" then
        local act = PhoneTick.activity[key]
        local activity = { state = "idle", freezing = env.freezing, saver = state.power.saver }
        if act and act.phoneId == item:getID() then
            activity.state = act.state or "screen"
            activity.noService = act.noService
        end
        -- The flashlight is the server's own switch (Flashlight.lua), and shines with the screen closed too.
        activity.flashlight = state.flashlight == true
        local events = Power.drain(state.battery, model, activity, minutes, ps)
        for _, e in ipairs(events) do
            if e == "shutdown" then state.power.on = false end
            Net.toClient(player, "notify", { kind = "battery", event = e, phoneId = item:getID() })
            changed = true
        end
    end

    -- Charge while plugged in, until the plug stops working (walking away, power out, sunset...).
    if state.plug then
        local plug = state.plug
        env.distanceToPlug = distance(env, plug)
        env.plugSquarePowered = plugSquarePowered(plug)
        local ok, why = Charging.stillConnected(plug, env)
        if not ok then
            state.plug = nil
            Net.toClient(player, "notify", { kind = "unplugged", reason = why, phoneId = item:getID() })
        else
            local info = chargeInfo(env, plug)
            local before = state.battery.charge
            local events = Power.charge(state.battery, model, plug.source, minutes, info, ps)
            settleStores(player, env, plug, info, state.battery.charge - before)
            -- An on phone drains a little each minute and tops back up, so "full" is said once per charge.
            for _, e in ipairs(events) do
                if (e == "full" and not plug.saidFull) or e == "sourceEmpty" then
                    Net.toClient(player, "notify", { kind = "charge", event = e, phoneId = item:getID() })
                end
                if e == "full" then plug.saidFull = true end
                if e == "sourceEmpty" then state.plug = nil end
            end
            if plug.saidFull and state.battery.charge < 95 then plug.saidFull = nil end
        end
    end

    -- Rain on a phone in hand or a soaked pocket; bags, plastic wrap and waterproof cases keep it dry.
    local exposed = (player:isEquipped(item) and env.raining and env.outside and not env.inCar)
        or (env.wetness > 60 and not Phones.inBag(player, item))
    if exposed or state.wetness ~= "dry" then
        local events = Damage.wetTick(state, model, minutes,
            { exposed = exposed, inBag = Phones.inBag(player, item), indoors = not env.outside },
            { waterDamage = settings.WaterDamage })
        for _, e in ipairs(events) do
            Net.toClient(player, "notify", { kind = "wet", event = e, phoneId = item:getID() })
            if e == "died" then state.power.on = false end
            changed = true
        end
    end

    -- The flashlight goes out with the phone or when it leaves the hand; armed alarms are followed (Alarms.lua).
    Flashlight.check(player, item, state)
    if Alarm.active(state.alarm) then Alarms.track(item) end

    state.lastTick = Util.nowMinutes()
    if changed or visible(state) ~= shown then Phones.save(item, player) end
end

-- The whole percent a tooltip shows (client Tooltip.lua rounds the same way).
local function shownPercent(value, full) return math.floor(100 * value / full + 0.5) end

-- Power banks plugged in at a wall refill; walking away or a power cut unplugs them.
local function tickBanks(player, env, ps, minutes)
    local banks = player:getInventory():getAllTypeRecurse("KnoxMobile.PowerBank")
    for i = 0, banks:size() - 1 do
        local bank = banks:get(i)
        local md = bank:getModData()
        local plug = md.KnoxMobileBankPlug
        if type(plug) == "table" then
            local here = distance(env, plug) <= PLUG_REACH and (env.squarePowered or plugSquarePowered(plug))
            local capacity = Power.newBankStore(ps)
            local before = Phones.bankStore(bank)
            local unplugged = false
            if not here then
                md.KnoxMobileBankPlug, unplugged = nil, true
                Net.toClient(player, "notify", { kind = "bank", event = "unplugged" })
            else
                md.KnoxMobileStore = Upkeep.bankRefill(before, capacity, minutes, ps)
                -- Also a bank that was full when plugged in: it says so and unplugs instead of "charging" forever.
                if md.KnoxMobileStore >= capacity then
                    md.KnoxMobileBankPlug, unplugged = nil, true
                    Net.toClient(player, "notify", { kind = "bank", event = "full" })
                end
            end
            -- Synced when the plug or the tooltip's whole percent changes, not every game minute (many times a
            -- second while sleeping).
            if unplugged or shownPercent(before, capacity) ~= shownPercent(md.KnoxMobileStore, capacity) then
                Phones.save(bank, player)
            end
        end
    end
end

-- Spare batteries charge on a carried desktop charger while the player stands in a powered building.
local function tickSpares(player, env, ps, minutes)
    if not env.squarePowered then return end
    local inv = player:getInventory()
    if not inv:containsTypeRecurse("KnoxMobile.DesktopBatteryCharger") then return end
    local spares = inv:getAllEvalRecurse(function(it)
        local a = Phones.accessory(it)
        return a ~= nil and a.kind == "spareBattery"
    end)
    for i = 0, spares:size() - 1 do
        local spare = spares:get(i)
        local charge = Phones.spareCharge(spare)
        if charge < 100 then
            local after = Upkeep.spareCharge(charge, minutes, ps)
            spare:getModData().KnoxMobileCharge = after
            if shownPercent(charge, 100) ~= shownPercent(after, 100) then Phones.save(spare, player) end
        end
    end
end

function PhoneTick.run()
    local settings = Util.settings()
    local ps = Util.powerSettings(settings)
    for _, player in ipairs(Util.players()) do
        if not player:isDead() then
            local phones = Phones.inventoryPhones(player)
            local env = Env.snapshot(player)
            for _, item in ipairs(phones) do
                Util.safe("phone tick", tickPhone)(player, item, env, settings, ps, 1)
            end
            Util.safe("power bank tick", tickBanks)(player, env, ps, 1)
            Util.safe("spare battery tick", tickSpares)(player, env, ps, 1)
        end
    end
    -- Alarms ring wherever their phone is: carried, in a bag, or left on the floor as a lure.
    Util.safe("alarms", Alarms.tick)()
end

-- A phone that sat in the world catches up on idle drain when someone picks it up (spec Â§13.7).
function PhoneTick.catchUp(player, item)
    local state, model = Phones.get(item)
    if not state or not state.lastTick then return end
    local away = Util.nowMinutes() - state.lastTick
    if away > 2 and state.power.on then
        local events = Power.drain(state.battery, model, { state = "idle" }, math.min(away, 60 * 24 * 30),
            powerSettingsFor(state, model, Util.powerSettings()))
        for _, e in ipairs(events) do if e == "shutdown" then state.power.on = false end end
    end
    state.lastTick = Util.nowMinutes()
    Phones.save(item, player)
end

return PhoneTick
