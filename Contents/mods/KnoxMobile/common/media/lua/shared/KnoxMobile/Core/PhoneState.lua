-- Per-phone state saved on the item (spec §4.3): plain tables only, no functions or metatables, so it lives in item ModData. Pure Lua 5.1.
local Version = require "KnoxMobile/Version"

local PhoneState = {}

PhoneState.SCHEMA = Version.schema
PhoneState.CONDITIONS = { "mint", "scratched", "cracked", "broken" }
PhoneState.WETNESS = { "dry", "damp", "waterDamaged" }
PhoneState.SOUND_MODES = { "ring", "vibrate", "silent" }

local function deepCopy(t)
    local out = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            out[k] = deepCopy(v)
        else
            out[k] = v
        end
    end
    return out
end

local function contains(list, value)
    for _, item in ipairs(list) do
        if item == value then
            return true
        end
    end
    return false
end

function PhoneState.new(model, opts)
    opts = opts or {}
    local rng = opts.rng
    local sandbox = opts.sandbox
    local origin = opts.origin
    local color = opts.color or (model and model.colors[1])

    local state = {
        schema = PhoneState.SCHEMA,
        model = model.id,
        color = color,
        battery = { charge = 0, health = 100, cycles = 0, cycleProgress = 0 },
        power = { on = false, saver = false },
        condition = "mint",
        wetness = "dry",
        wetMinutes = 0,
        look = { case = nil, protector = false, wallpaper = nil, ringtone = nil, soundMode = "ring" },
        security = { locked = false, pin = nil, failedAttempts = 0, lockoutUntil = nil },
        owner = { kind = "new" },
        contents = { texts = {}, calls = {}, voicemails = {}, notes = {} },
        sim = nil,
        wrapped = false,
    }

    if origin == "newInBox" then
        state.battery.charge = rng:int(20, 60)
    elseif origin == "found" then
        state.battery.charge = rng:int(sandbox.FoundPhoneChargeMin, sandbox.FoundPhoneChargeMax)
        state.battery.health = rng:int(sandbox.FoundPhoneHealthMin, sandbox.FoundPhoneHealthMax)
        state.condition = rng:weighted(PhoneState.foundOdds(PhoneState.foundKind(model), sandbox))
        state.security.locked = true
        state.owner = { kind = "generated", pending = true }
    elseif origin == "start" then
        state.battery.charge = rng:int(60, 100)
        state.battery.health = rng:int(85, 100)
        state.condition = rng:weighted({ { "mint", 70 }, { "scratched", 30 } })
        state.owner = { kind = "player" }
    end

    return state
end

-- How found phones turn up (2026-10-19: a pristine iPhone should make you freak out). The old bricks take a
-- beating; the 2003-2009 phones less so; a smartphone's glass is almost never whole: about 1 found phone in 100 is a
-- pristine smartphone. New in its box is a separate, store-only find.
PhoneState.FOUND_CONDITION = {
    old = { { "mint", 15 }, { "scratched", 50 }, { "cracked", 25 }, { "broken", 10 } },
    mid = { { "mint", 8 }, { "scratched", 47 }, { "cracked", 33 }, { "broken", 12 } },
    smart = { { "mint", 4 }, { "scratched", 34 }, { "cracked", 42 }, { "broken", 20 } },
}

local PRISTINE_OPTION = { old = "PristineOldPhones", mid = "PristineMidPhones", smart = "PristineSmartphones" }

-- The condition odds for a found phone of this kind, with the sandbox's pristine percent when it has one.
function PhoneState.foundOdds(kind, sandbox)
    local base = PhoneState.FOUND_CONDITION[kind]
    local want = sandbox and sandbox[PRISTINE_OPTION[kind]]
    if want == nil then return base end
    want = math.max(0, math.min(100, want))
    local rest = 0
    for _, w in ipairs(base) do if w[1] ~= "mint" then rest = rest + w[2] end end
    local out = { { "mint", want } }
    for _, w in ipairs(base) do
        if w[1] ~= "mint" then out[#out + 1] = { w[1], (100 - want) * w[2] / rest } end
    end
    return out
end

function PhoneState.foundKind(model)
    if not model then return "mid" end
    if model.family == "ModernAndroid" or model.family == "ModernPear" then return "smart" end
    if (model.year or 2000) <= 2001 then return "old" end
    return "mid"
end

function PhoneState.copy(state)
    return deepCopy(state)
end

function PhoneState.validate(state)
    local problems = {}
    local function need(cond, msg)
        if not cond then
            problems[#problems + 1] = msg
        end
    end

    need(type(state) == "table", "phone state must be a table")
    if type(state) ~= "table" then
        return false, problems
    end

    need(type(state.model) == "string" and state.model ~= "", "model must be a non-empty string")

    local b = state.battery
    need(type(b) == "table" and type(b.charge) == "number" and b.charge >= 0 and b.charge <= 100,
        "battery.charge must be a number 0..100")
    need(type(b) == "table" and type(b.health) == "number" and b.health >= 0 and b.health <= 100,
        "battery.health must be a number 0..100")

    need(contains(PhoneState.CONDITIONS, state.condition), "unknown condition " .. tostring(state.condition))
    need(contains(PhoneState.WETNESS, state.wetness), "unknown wetness " .. tostring(state.wetness))

    local look = state.look
    local soundMode = look and look.soundMode
    need(contains(PhoneState.SOUND_MODES, soundMode), "unknown sound mode " .. tostring(soundMode))

    need(state.schema == PhoneState.SCHEMA, "schema must be " .. PhoneState.SCHEMA)

    if #problems > 0 then
        return false, problems
    end
    return true
end

function PhoneState.migrate(data)
    if type(data) ~= "table" then
        return nil, "no phone data"
    end

    if data.schema ~= nil and data.schema > PhoneState.SCHEMA then
        return nil, "saved by a newer Knox Mobile"
    end

    local out = deepCopy(data)

    if out.schema == nil then
        out.battery = { charge = out.charge, health = (out.health or 100) }
        out.security = { locked = (out.locked == true), pin = out.pin }
        out.charge = nil
        out.health = nil
        out.locked = nil
        out.pin = nil
    end

    if type(out.model) ~= "string" or out.model == "" then
        return nil, "no model"
    end

    if type(out.battery) ~= "table" then out.battery = {} end
    if out.battery.charge == nil then out.battery.charge = 100 end
    if out.battery.health == nil then out.battery.health = 100 end
    if out.battery.cycles == nil then out.battery.cycles = 0 end
    if out.battery.cycleProgress == nil then out.battery.cycleProgress = 0 end

    if type(out.power) ~= "table" then out.power = {} end
    if out.power.on == nil then out.power.on = false end
    if out.power.saver == nil then out.power.saver = false end

    if out.condition == nil then out.condition = "mint" end
    if out.wetness == nil then out.wetness = "dry" end
    if out.wetMinutes == nil then out.wetMinutes = 0 end

    if type(out.look) ~= "table" then out.look = {} end
    if out.look.protector == nil then out.look.protector = false end
    if out.look.soundMode == nil then out.look.soundMode = "ring" end

    if type(out.security) ~= "table" then out.security = {} end
    if out.security.locked == nil then out.security.locked = false end
    if out.security.failedAttempts == nil then out.security.failedAttempts = 0 end

    if type(out.owner) ~= "table" then out.owner = {} end
    if out.owner.kind == nil then out.owner.kind = "new" end

    if type(out.contents) ~= "table" then out.contents = {} end
    if type(out.contents.texts) ~= "table" then out.contents.texts = {} end
    if type(out.contents.calls) ~= "table" then out.contents.calls = {} end
    if type(out.contents.voicemails) ~= "table" then out.contents.voicemails = {} end
    if type(out.contents.notes) ~= "table" then out.contents.notes = {} end

    if out.wrapped == nil then out.wrapped = false end

    out.schema = PhoneState.SCHEMA
    return out
end

return PhoneState