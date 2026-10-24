-- Reading and writing Knox Mobile data on game items: phone state, SIM data, accessories (spec §4.3, §13.4).
-- State lives in item ModData under "KnoxMobile" as plain tables; the server syncs changes to the owner.
local Registry = require "KnoxMobile/Core/Registry"
local PhoneState = require "KnoxMobile/Core/PhoneState"
local Power = require "KnoxMobile/Core/Power"
local Rng = require "KnoxMobile/Core/Rng"
local Sim = require "KnoxMobile/Core/Sim"
local AudioGear = require "KnoxMobile/Core/AudioGear"
local ItemIds = require "KnoxMobile/ItemIds"
local Accessories = require "KnoxMobile/Data/Accessories"
local Util = require "KnoxMobile/Game/Util"

local Phones = {}
Phones.KEY = "KnoxMobile"
Phones.registry = Registry.withBundledPhones()

local accessoryById = {}
for _, a in ipairs(Accessories) do accessoryById[a.id] = a end

KnoxMobile = KnoxMobile or {}
KnoxMobile.world = KnoxMobile.world or { seed = 1, repeaters = {}, debugTowers = nil, storyShift = 0 }

function Phones.worldSeed() return KnoxMobile.world.seed or 1 end

local function localId(item)
    local id = item and item:getFullType():match("^KnoxMobile%.(.+)$")
    return id
end

-- The car phone's handset (1993 hardware) is a phone outside the registry (it never spawns): its own one-phone
-- registry fills in the family defaults the same way.
local carRegistry = Registry.new()
assert(carRegistry:addPhone(require("KnoxMobile/Phones/CarPhone")))
Phones.carPhone = carRegistry:getPhone("CarPhone")
local CAR_ITEM = "KnoxMobile.CarPhone"

function Phones.model(item)
    if not item then return nil end
    local fullType = item:getFullType()
    if fullType == CAR_ITEM then return Phones.carPhone, Phones.carPhone.colors[1] end
    return ItemIds.parsePhone(fullType, Phones.registry)
end

function Phones.isPhone(item) return Phones.model(item) ~= nil end

function Phones.accessory(item)
    local id = localId(item)
    return id and accessoryById[id] or nil
end

function Phones.isBox(item)
    local id = localId(item)
    return id ~= nil and id:match("^(%w+)_Box$") ~= nil, id and Phones.registry:getPhone(id:match("^(%w+)_Box$") or "")
end

function Phones.manualFamily(item)
    local id = localId(item)
    return id and id:match("^Manual_(%w+)$") or nil
end

-- The phone's state, created on first access (found phones get random charge, health, condition, a lock).
-- Returns the live ModData table: change it, then call Phones.save(item, player).
-- Sandbox "Phone PINs" (PinLocks). Read straight from SandboxVars: Phones.get runs often, Util.settings() is slow.
function Phones.pinsOn()
    local sv = SandboxVars and SandboxVars.KnoxMobile
    return not (sv and sv.PinLocks == false)
end

local function unlockIfPinsOff(state)
    local sec = state.security
    if sec and (sec.locked or sec.pin) and not Phones.pinsOn() then
        sec.locked, sec.pin, sec.failedAttempts, sec.lockoutUntil = false, nil, 0, nil
    end
    return state
end

function Phones.get(item)
    local model, color = Phones.model(item)
    if not model then return nil end
    local md = item:getModData()
    local raw = md[Phones.KEY]
    if type(raw) == "table" and raw.schema == PhoneState.SCHEMA and type(raw.battery) == "table" then
        return unlockIfPinsOff(raw), model
    end
    local state = raw and PhoneState.migrate(raw)
    if not state then
        local origin = md.KnoxMobileOrigin or "found"
        local rng = Rng.new(tostring(Phones.worldSeed()) .. ":" .. tostring(item:getID()))
        state = PhoneState.new(model, { origin = origin, rng = rng, sandbox = Util.settings(), color = color })
        state.lastTick = Util.nowMinutes()
    end
    md[Phones.KEY] = state
    return unlockIfPinsOff(state), model
end

-- Saves after a change. On a server the owner gets the new data.
function Phones.save(item, player)
    if isServer() and player then syncItemModData(player, item) end
end

-- SIM item data: { number, contacts, owner }.
function Phones.isSim(item) return item ~= nil and item:getFullType() == "KnoxMobile.SimCard" end

function Phones.simData(item)
    local md = item:getModData()
    if type(md[Phones.KEY]) ~= "table" then md[Phones.KEY] = Sim.newSim() end
    return md[Phones.KEY]
end

-- A SIM with a number is named the way vanilla names ID cards (IGUI_ItemWithDisplayName, "%1: %2"):
-- "SIM Card: (502) 555-0134".
function Phones.nameSim(item, number)
    if not number then return end
    local ok, base = pcall(getItemNameFromFullType, "KnoxMobile.SimCard")
    -- A server has no translations: there the game hands back the raw type (third pass: "KnoxMobile.SimCard: ...").
    if not ok or type(base) ~= "string" or base == "" or base:find("KnoxMobile%.") then base = "SIM Card" end
    item:setName(Util.text("IGUI_ItemWithDisplayName", "%1: %2", base, number))
end

-- Power bank charge points (spec §6.5), full when first found.
function Phones.bankStore(item)
    local md = item:getModData()
    if type(md.KnoxMobileStore) ~= "number" then md.KnoxMobileStore = Power.newBankStore(Util.powerSettings()) end
    return md.KnoxMobileStore
end

-- A spare battery's charge (0..100). Found spares get a random charge from the world seed.
function Phones.spareCharge(item)
    local md = item:getModData()
    if type(md.KnoxMobileCharge) ~= "number" then
        local rng = Rng.new(tostring(Phones.worldSeed()) .. ":spare:" .. tostring(item:getID()))
        md.KnoxMobileCharge, md.KnoxMobileHealth = rng:int(10, 100), rng:int(50, 100)
    end
    return md.KnoxMobileCharge
end

-- Audio gear the player carries, as Core/AudioGear entries { id, plug, route, item }, plus whether a
-- headphone dongle is among it.
function Phones.audioGear(player)
    local out, dongle = {}, false
    local list = player:getInventory():getAllEvalRecurse(function(it)
        local t = it:getFullType()
        return t == "Base.Earbuds" or t == "Base.Headphones" or (Phones.accessory(it) or {}).kind == "audioGear"
    end)
    for i = 0, list:size() - 1 do
        local it = list:get(i)
        local g = AudioGear.describe(it:getFullType(), Accessories)
        if g then out[#out + 1] = { id = it:getID(), plug = g.plug, route = g.route, item = it } end
        if it:getFullType() == "KnoxMobile.HeadphoneDongle" then dongle = true end
    end
    return out, dongle
end

-- All phones in a player's inventory, bags included.
function Phones.inventoryPhones(player)
    local out = {}
    local list = player:getInventory():getAllEvalRecurse(function(it) return Phones.isPhone(it) end)
    for i = 0, list:size() - 1 do out[#out + 1] = list:get(i) end
    return out
end

-- Charging gear the player carries, as Core/Charging descriptors (with the item attached).
function Phones.chargingGear(player)
    local out = {}
    local list = player:getInventory():getAllEvalRecurse(function(it)
        local a = Phones.accessory(it)
        return a ~= nil and (a.kind == "charger" or a.kind == "cable" or a.kind == "usbSource")
    end)
    for i = 0, list:size() - 1 do
        local it = list:get(i)
        local a = Phones.accessory(it)
        out[#out + 1] = { id = it:getID(), kind = a.kind, connector = a.connector, source = a.source, setup = a.setup, item = it }
    end
    return out
end

function Phones.findById(player, id)
    return player:getInventory():getItemWithIDRecursiv(id)
end

-- Any unbroken screwdriver: Build 42 tags them (Screwdriver, the old and improvised ones, Multitool, Handiknife).
-- ItemContainer's tag lookups take an ItemTag, not a string.
local function notBroken(it) return not it:isBroken() end
function Phones.hasScrewdriver(player)
    return player:getInventory():containsTagEvalRecurse(ItemTag.SCREWDRIVER, notBroken) == true
end

-- Is the item in a bag rather than loose in the main inventory (or in hand)?
function Phones.inBag(player, item)
    local c = item:getContainer()
    return c ~= nil and c ~= player:getInventory()
end

return Phones
