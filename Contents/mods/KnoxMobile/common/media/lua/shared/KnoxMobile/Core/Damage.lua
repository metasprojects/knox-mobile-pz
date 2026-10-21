-- Damage, wetness, cases, repair, rice and scrapping rules (spec §9.3-§9.5). Pure Lua 5.1.
-- Works on a PhoneState table; time is in-game minutes. Rain never kills a phone outright:
-- it goes damp first, then water damaged only after long exposure, then dies if left untreated.

local Damage = {}

Damage.DAMP_AFTER = 10             -- minutes of exposure before a phone turns damp
Damage.SOAK_AFTER = 120            -- further exposure before damp becomes water damaged
Damage.WATER_DEATH_AFTER = 1440    -- untreated water damage kills the phone after a day
Damage.MINOR_WATER_DAMAGE = 720    -- rice still saves water damage younger than this (the clock stops in rice)
Damage.RICE_MINUTES = 1440         -- one in-game day sealed in rice

-- Chance multipliers for each case type (lower protects more).
local CASE_FACTOR = { Slim = 0.8, Rugged = 0.3, Waterproof = 0.6, Wallet = 0.7, Battery = 0.85, BeltHolster = 0.9 }
local NEXT_STAGE = { mint = "scratched", scratched = "cracked", cracked = "broken", broken = "broken" }
local REPAIR_BASE = { screen = 0.35, battery = 0.45, water = 0.25 }

local function clamp01(x) return math.max(0, math.min(1, x)) end

local function caseFactor(case) return CASE_FACTOR[case] or 1 end

-- Chance that a drop (grabbed, stumble) damages the phone.
function Damage.dropChance(model, case, settings)
    local mult = (settings and settings.damageMultiplier) or 1
    return clamp01(0.6 * (1 - model.toughness) * mult * caseFactor(case))
end

-- Chance that a fall or knockdown damages a pocketed phone. Phones in bags are safer.
function Damage.fallChance(model, case, settings, inBag)
    local mult = (settings and settings.damageMultiplier) or 1
    return clamp01(0.25 * (1 - model.toughness) * mult * caseFactor(case) * (inBag and 0.4 or 1))
end

-- severity "light" scratches; "heavy" cracks (or breaks a cracked phone). A screen protector absorbs
-- the first heavy hit. Returns the new condition, "protectorCracked", or "none".
function Damage.applyHit(state, severity)
    local c = state.condition
    if severity == "heavy" then
        if state.look and state.look.protector and (c == "mint" or c == "scratched") then
            state.look.protector = false
            return "protectorCracked"
        end
        if c == "mint" or c == "scratched" then state.condition = "cracked"
        elseif c == "cracked" then state.condition = "broken"
        else return "none" end
        return state.condition
    end
    if c == "mint" then state.condition = "scratched"; return "scratched" end
    return "none"
end

local function roll(rng, chance, state)
    if not rng:chance(chance) then return "none" end
    return Damage.applyHit(state, rng:chance(0.35) and "heavy" or "light")
end

function Damage.rollDrop(rng, model, state, settings)
    return roll(rng, Damage.dropChance(model, state.look and state.look.case, settings), state)
end

function Damage.rollFall(rng, model, state, settings, inBag)
    return roll(rng, Damage.fallChance(model, state.look and state.look.case, settings, inBag), state)
end

-- Advances wetness. env: { exposed = phone out in rain or a soaked pocket, inBag, indoors }.
-- Returns events: "damp", "waterDamaged", "dried", "died".
-- A phone sealed in rice is out of the rain and its wet clock stops: the rice decides when it comes out (Damage.rice).
function Damage.wetTick(state, model, minutes, env, settings)
    local events = {}
    if state.rice then return events end
    local protected = model.waterResistant or state.wrapped or (state.look and state.look.case == "Waterproof") or env.inBag
    state.wetMinutes = state.wetMinutes or 0
    state.waterDamageMinutes = state.waterDamageMinutes or 0

    if state.wetness == "waterDamaged" then
        state.waterDamageMinutes = state.waterDamageMinutes + minutes
        if state.waterDamageMinutes >= Damage.WATER_DEATH_AFTER and state.condition ~= "broken" then
            state.condition = "broken"
            events[#events + 1] = "died"
        end
        return events
    end

    if env.exposed and not protected then
        state.wetMinutes = state.wetMinutes + minutes
        if state.wetness == "dry" and state.wetMinutes >= Damage.DAMP_AFTER then
            state.wetness = "damp"
            events[#events + 1] = "damp"
        end
        if state.wetness == "damp" and settings.waterDamage ~= false
            and state.wetMinutes >= Damage.DAMP_AFTER + Damage.SOAK_AFTER then
            state.wetness = "waterDamaged"
            events[#events + 1] = "waterDamaged"
        end
    elseif state.wetness == "damp" then
        state.wetMinutes = state.wetMinutes - minutes * (env.indoors and 1 or 0.5)
        if state.wetMinutes <= 0 then
            state.wetMinutes = 0
            state.wetness = "dry"
            events[#events + 1] = "dried"
        end
    else
        state.wetMinutes = math.max(0, state.wetMinutes - minutes)
    end
    return events
end

-- A phone sealed in vanilla rice. Returns "dried", "notYet", "tooFarGone" or "noEffect".
function Damage.rice(state, minutesInRice, settings)
    if settings and settings.riceTrick == false then return "noEffect" end
    if minutesInRice < Damage.RICE_MINUTES then return "notYet" end
    if state.wetness == "damp" or (state.wetness == "waterDamaged"
        and (state.waterDamageMinutes or 0) <= Damage.MINOR_WATER_DAMAGE) then
        state.wetness, state.wetMinutes, state.waterDamageMinutes = "dry", 0, 0
        return "dried"
    end
    if state.wetness == "waterDamaged" then return "tooFarGone" end
    return "noEffect"
end

-- kind: "screen", "battery" or "water". skill: Electrical level. A manual for the family helps.
function Damage.repairChance(kind, skill, hasManual)
    local chance = (REPAIR_BASE[kind] or 0.3) + 0.07 * (skill or 0) + (hasManual and 0.2 or 0)
    return math.max(0.05, math.min(0.95, chance))
end

-- Applies a successful repair. Returns "fixed".
function Damage.applyRepair(state, kind)
    if kind == "screen" then
        if state.condition == "cracked" or state.condition == "broken" then state.condition = "scratched" end
    elseif kind == "battery" then
        state.battery.health, state.battery.cycles, state.battery.cycleProgress = 100, 0, 0
    elseif kind == "water" then
        state.wetness, state.wetMinutes, state.waterDamageMinutes = "dry", 0, 0
    end
    return "fixed"
end

-- Rolls a repair. Low skill can make things worse. Returns "fixed", "worse" or "failed".
function Damage.attemptRepair(rng, state, kind, skill, hasManual)
    if rng:chance(Damage.repairChance(kind, skill, hasManual)) then return Damage.applyRepair(state, kind) end
    if rng:chance(0.4) then
        state.condition = NEXT_STAGE[state.condition] or state.condition
        return "worse"
    end
    return "failed"
end

-- Parts from scrapping a phone: electronics scrap, plus the screen and battery when they're usable.
function Damage.scrapYield(rng, state)
    local parts = { { item = "ElectronicsScrap", count = rng:int(1, 2) } }
    if state.condition ~= "cracked" and not state.screenCracked then parts[#parts + 1] = { item = "PhoneScreen", count = 1 } end
    if state.battery and state.battery.health >= 30 then parts[#parts + 1] = { item = "PhoneBattery", count = 1 } end
    return parts
end

-- "Wrap in plastic bag": the phone stays usable and dry; unwrapping returns the bag.
function Damage.wrap(state)
    if state.wrapped then return false end
    state.wrapped = true
    return true
end

function Damage.unwrap(state)
    if not state.wrapped then return false end
    state.wrapped = false
    return true
end

return Damage
