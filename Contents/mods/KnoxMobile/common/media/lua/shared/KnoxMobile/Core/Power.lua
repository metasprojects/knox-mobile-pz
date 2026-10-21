-- Battery drain, charging, wear and power sources (spec §6). Pure Lua 5.1; time is in-game minutes.
-- A battery is a plain table: { charge = 0..100, health = 0..100, cycles = n, cycleProgress = 0..100 }.
-- Calibration: each family's mixed-use hours (Registry, spec §6.1) under the MIXED_USE day below, and its
-- non-stop video hours where the spec gives them. Other activities use the relative rates of spec §6.2.

local Power = {}

-- Relative drain (spec §6.2). Video is calibrated per family from its video hours.
local RATES = { off = 0, idle = 1, screen = 4, audio = 3, games = 6, video = 8 }

-- The "mixed use" day the spec's battery hours refer to: shares of time in each state.
Power.MIXED_USE = {
    { state = "idle", share = 0.55 },
    { state = "screen", share = 0.28 },
    { state = "audio", share = 0.12 },
    { state = "games", share = 0.05 },
}
local MIXED_AVERAGE = 0
for _, slice in ipairs(Power.MIXED_USE) do MIXED_AVERAGE = MIXED_AVERAGE + slice.share * RATES[slice.state] end

local MODERN = { ModernAndroid = true, ModernPear = true }
local SAVER_BLOCKS = { video = true, clips = true, tv = true, camera = true }

-- Hours to charge a modern phone from empty to full (spec §6.5).
local SOURCE_HOURS = { wall = 2, car = 3, carBatteryClip = 3, powerBank = 3, solar = 8, aa = 12, crank = 30 }
-- Power banks and AA chargers hold "modern percent points": 100 points fill one modern phone.
-- Older, smaller batteries cost fewer points per percent.
local CAPACITY_UNITS = {
    SegmentLCD = 0.6, MonoLCD = 0.35, ColorFeature = 0.35, Keyboard = 0.4, Stylus = 0.45,
    ModernAndroid = 1.0, ModernPear = 0.9,
}

Power.WEAR_PER_CYCLE = 0.25 -- health % lost per full charge cycle when BatteryWear is on
Power.BOOT_MIN_CHARGE = 2   -- a dead phone boots again once it has this much charge

local function isModern(model) return MODERN[model.family] == true end

-- % per minute at 1x for this model.
local function baseRate(model)
    return 100 / (model.mixedUseHours * 60 * MIXED_AVERAGE)
end

local function videoMultiplier(model)
    if model.videoHours then return model.mixedUseHours * MIXED_AVERAGE / model.videoHours end
    return RATES.video
end

-- activity: { state = "off"|"idle"|"screen"|"audio"|"games"|"video", flashlight, noService, freezing, saver }
-- settings: { batteryLife = sandbox BatteryLifeMultiplier, flashlightDrain = sandbox FlashlightDrain }.
-- health: battery health %, default 100.
function Power.drainPerMinute(model, activity, settings, health)
    local state = activity.state or "idle"
    if state == "off" then return 0 end
    local mult
    if state == "video" then mult = videoMultiplier(model) else mult = RATES[state] or RATES.idle end
    if activity.flashlight then mult = mult + 3 * ((settings and settings.flashlightDrain) or 1) end
    if activity.noService then mult = mult + 1 end
    if activity.freezing then mult = mult * 1.5 end
    if activity.saver and isModern(model) then mult = mult * 0.5 end
    local life = (settings and settings.batteryLife) or 1
    local healthFactor = 100 / math.max(health or 100, 1)
    return baseRate(model) * mult / life * healthFactor
end

-- Drains the battery for some minutes. Returns events crossed: "low15", "low5", "shutdown".
function Power.drain(battery, model, activity, minutes, settings)
    local before = battery.charge
    local after = before - Power.drainPerMinute(model, activity, settings, battery.health) * minutes
    if after < 0 then after = 0 end
    battery.charge = after
    local events = {}
    if before > 15 and after <= 15 then events[#events + 1] = "low15" end
    if before > 5 and after <= 5 then events[#events + 1] = "low5" end
    if before > 0 and after == 0 then events[#events + 1] = "shutdown" end
    return events
end

function Power.canPowerOn(battery)
    return battery.charge >= Power.BOOT_MIN_CHARGE
end

function Power.blockedBySaver(app)
    return SAVER_BLOCKS[app] == true
end

function Power.isModern(model) return isModern(model) end

-- New power bank charge, in modern percent points (sandbox PowerBankCapacity = modern full charges).
function Power.newBankStore(settings)
    return ((settings and settings.powerBankCapacity) or 2.5) * 100
end

-- % per minute a source delivers right now (0 when it can't), before store limits.
-- info: { daylight, cloud = 0..1, cranking } for solar and crank.
function Power.chargePerMinute(source, info, settings)
    local hours = SOURCE_HOURS[source]
    if not hours then return nil end
    info = info or {}
    local rate = 100 / (hours * 60) * ((settings and settings.chargeSpeed) or 1)
    if source == "solar" then
        if not info.daylight then return 0 end
        rate = rate * (1 - 0.7 * math.min(math.max(info.cloud or 0, 0), 1))
    elseif source == "crank" then
        if not info.cranking then return 0 end
    end
    return rate
end

-- Charges the battery. info.bank / info.aa = { store = points } for power banks and AA chargers.
-- settings: { chargeSpeed, batteryWear (default true) }. Returns events: "full", "sourceEmpty", "noSource".
function Power.charge(battery, model, source, minutes, info, settings)
    local rate = Power.chargePerMinute(source, info, settings)
    if rate == nil then return { "noSource" } end
    local events = {}
    local gain = math.min(rate * minutes, 100 - battery.charge)
    if gain <= 0 then return events end

    local store = nil
    if source == "powerBank" then store = info and info.bank end
    if source == "aa" then store = info and info.aa end
    if source == "powerBank" or source == "aa" then
        local unitCost = CAPACITY_UNITS[model.family] or 1
        local available = store and store.store or 0
        if available <= 0 then return { "sourceEmpty" } end
        local affordable = available / unitCost
        local ranOut = false
        if affordable <= gain then gain, ranOut = affordable, true end
        store.store = math.max(0, available - gain * unitCost)
        if ranOut then store.store = 0 end
        battery.charge = battery.charge + gain
        Power.addCycles(battery, gain, settings)
        if battery.charge >= 100 then battery.charge = 100; events[#events + 1] = "full" end
        if ranOut then events[#events + 1] = "sourceEmpty" end
        return events
    end

    battery.charge = battery.charge + gain
    Power.addCycles(battery, gain, settings)
    if battery.charge >= 100 - 1e-9 then battery.charge = 100; events[#events + 1] = "full" end
    return events
end

-- Counts charged percent toward full cycles and wears the battery per cycle.
function Power.addCycles(battery, gained, settings)
    battery.cycleProgress = (battery.cycleProgress or 0) + gained
    while battery.cycleProgress >= 100 - 1e-9 do
        battery.cycleProgress = math.max(0, battery.cycleProgress - 100)
        battery.cycles = (battery.cycles or 0) + 1
        if not (settings and settings.batteryWear == false) then
            battery.health = math.max(0, (battery.health or 100) - Power.WEAR_PER_CYCLE)
        end
    end
end

return Power
