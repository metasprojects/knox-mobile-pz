-- Slow upkeep math (spec §6.3, §6.5, §7.3): repeater power and wear, spare batteries on a desktop charger,
-- and power banks refilling at a wall. Pure Lua 5.1; time in in-game minutes.
local Upkeep = {}

Upkeep.CAR_BATTERY_HOURS = 24      -- a full car battery runs a repeater about a day ("short runtime")
Upkeep.WEAR_PER_DAY = 3            -- repeater condition lost per in-game day (100 lasts about a month)
Upkeep.MAINTAIN_AMOUNT = 50        -- condition restored by one maintenance
Upkeep.SPARE_FULL_MINUTES = 120    -- desktop charger: empty to full spare battery
Upkeep.BANK_FULL_MINUTES = 240     -- power bank: empty to full at a wall

-- Advances a repeater: { condition, battery = hours left on an attached car battery }.
-- gridPowered: the square has power (grid, generator or solar mod). Sets rep.powered.
-- Returns events: "batteryEmpty", "wornOut".
function Upkeep.repeaterTick(rep, minutes, gridPowered)
    local events = {}
    local before = rep.condition or 100
    rep.condition = math.max(0, before - Upkeep.WEAR_PER_DAY * minutes / 1440)
    if before > 0 and rep.condition <= 0 then events[#events + 1] = "wornOut" end
    if gridPowered then
        rep.powered = true
    elseif (rep.battery or 0) > 0 then
        rep.battery = math.max(0, rep.battery - minutes / 60)
        rep.powered = rep.battery > 0
        if rep.battery <= 0 then events[#events + 1] = "batteryEmpty" end
    else
        rep.powered = false
    end
    return events
end

function Upkeep.maintain(rep)
    rep.condition = math.min(100, (rep.condition or 100) + Upkeep.MAINTAIN_AMOUNT)
    return rep.condition
end

-- Car battery charge (0..1) to repeater hours, and back.
function Upkeep.batteryHours(charge) return math.max(0, math.min(1, charge)) * Upkeep.CAR_BATTERY_HOURS end
function Upkeep.batteryCharge(hours) return math.max(0, math.min(1, hours / Upkeep.CAR_BATTERY_HOURS)) end

-- A spare battery's charge (0..100) after some minutes on a powered desktop charger.
function Upkeep.spareCharge(charge, minutes, settings)
    local speed = (settings and settings.chargeSpeed) or 1
    return math.min(100, charge + 100 * speed * minutes / Upkeep.SPARE_FULL_MINUTES)
end

-- A power bank's store after some minutes plugged in at a wall.
function Upkeep.bankRefill(store, capacity, minutes, settings)
    local speed = (settings and settings.chargeSpeed) or 1
    return math.min(capacity, store + capacity * speed * minutes / Upkeep.BANK_FULL_MINUTES)
end

return Upkeep
