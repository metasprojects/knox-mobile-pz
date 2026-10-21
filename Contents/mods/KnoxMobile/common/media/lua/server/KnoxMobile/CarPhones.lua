-- Server: car phones (1993 hardware, see Core/CarPhone). "mountCarPhone" (from the kit, sitting in a car) stores the
-- car phone's record in the car's ModData; every game minute each seated player in such a car gets the handset (one
-- player per car), powered by the car battery; leaving the car puts the handset's state back in the car and takes
-- the handset away. "unmountCarPhone" gives the kit back with the record on it, so the number and texts move along.
local CarPhone = require "KnoxMobile/Core/CarPhone"
local Protocol = require "KnoxMobile/Core/Protocol"
local Sim = require "KnoxMobile/Core/Sim"
local Rng = require "KnoxMobile/Core/Rng"
local Phones = require "KnoxMobile/Game/Phones"
local Util = require "KnoxMobile/Game/Util"
local Net = require "KnoxMobile/Game/Net"
local State = require "KnoxMobile/State"

local CarPhones = {}
local held = {} -- player key -> { vehicle, item }: who has which car's handset right now

Protocol.register({
    mountCarPhone = function(args)
        if type(args.kitId) ~= "number" then return false, "kitId must be a number" end
        return true
    end,
    unmountCarPhone = function() return true end,
})

local function record(vehicle)
    local r = vehicle and vehicle:getModData()[CarPhone.KEY]
    return type(r) == "table" and r or nil
end

local function addItem(player, fullType, setup)
    local inv = player:getInventory()
    local item = inv:AddItem(fullType)
    if item then
        if setup then setup(item) end
        if isServer() then sendAddItemToContainer(inv, item) end
    end
    return item
end

local function removeItem(item)
    local c = item:getContainer()
    if not c then return end
    c:Remove(item)
    if isServer() then sendRemoveItemFromContainer(c, item) end
end

local function handsets(player)
    local out = {}
    local list = player:getInventory():getAllTypeRecurse(CarPhone.ITEM)
    for i = 0, list:size() - 1 do out[#out + 1] = list:get(i) end
    return out
end

local function seatedIn(key, vehicle)
    for _, p in ipairs(Util.players()) do
        if Util.playerKey(p) == key then return p:getVehicle() == vehicle end
    end
    return false
end

local function tell(player, event) Net.toClient(player, "carPhone", { event = event }) end

-- The handset's state goes back into the car, and the handset leaves the player's hands.
local function putBack(key, h)
    local r = record(h.vehicle)
    if r then
        r.state = h.item:getModData()[Phones.KEY]
        if r.holder == key then r.holder = nil end
    end
    removeItem(h.item)
    held[key] = nil
end

-- A new car phone's handset: on, its own number, full from the car.
local function setUp(item, r)
    local md = item:getModData()
    md.KnoxMobileCarToken = r.token
    if r.state then md[Phones.KEY] = r.state; return end
    md.KnoxMobileOrigin = "newInBox"
    local st = Phones.get(item)
    st.sim = Sim.newSim({ number = r.number })
    st.power.on, st.battery.charge, st.owner = true, 100, { kind = "player" }
end

-- Runs every game minute for each player (and right after mounting): hands out, powers and takes back handsets.
function CarPhones.sync(player, minutes)
    local key = Util.playerKey(player)
    local vehicle = player:getVehicle()
    local r = record(vehicle)
    local h = held[key]
    if h and (h.vehicle ~= vehicle or not r or not player:getInventory():containsID(h.item:getID())) then
        putBack(key, h)
        h = nil
    end
    -- Handsets the table doesn't know (a reload in the seat) are kept when they belong to this car; others go.
    for _, it in ipairs(handsets(player)) do
        if not (h and it == h.item) then
            if not h and r and it:getModData().KnoxMobileCarToken == r.token then
                h = { vehicle = vehicle, item = it }
                held[key], r.holder = h, key
            else
                removeItem(it)
            end
        end
    end
    if not r then return end
    if not h then
        local holderSeated = r.holder ~= nil and r.holder ~= key and seatedIn(r.holder, vehicle)
        if not CarPhone.mayHold(r, key, holderSeated) then return end
        local item = addItem(player, CarPhone.ITEM, function(it) setUp(it, r) end)
        if not item then return end
        h = { vehicle = vehicle, item = item }
        held[key], r.holder = h, key
    end
    local st = Phones.get(h.item)
    local part = vehicle:getBattery()
    local battery = part and part:getInventoryItem()
    local uses = battery and battery:getCurrentUsesFloat() or 0
    local charge, after = CarPhone.power(vehicle:hasLiveBattery(), vehicle:isEngineRunning(), st.power.on, uses, minutes)
    st.battery.charge = charge
    if charge <= 0 then st.power.on = false end
    if battery and after ~= uses then
        battery:setCurrentUsesFloat(after)
        vehicle:transmitPartUsedDelta(part)
    end
    r.state = st
    Phones.save(h.item, player)
end

Net.onServer("mountCarPhone", function(player, args)
    local kit = Phones.findById(player, args.kitId)
    if not kit or kit:getFullType() ~= CarPhone.KIT then return end
    local vehicle = player:getVehicle()
    if not vehicle then return tell(player, "notInCar") end
    if record(vehicle) then return tell(player, "already") end
    -- A kit taken out of another car brings its record (number, texts) along.
    local r = kit:getModData()[CarPhone.KEY]
    if type(r) ~= "table" or not r.token or not r.number then
        local md = State.get()
        local token = tostring(md.seed) .. ":car:" .. tostring(kit:getID()) .. ":" .. tostring(math.floor(Util.nowMinutes()))
        r = { token = token, number = Sim.issueNumber(md.numbers, Rng.new(token)) }
    end
    r.holder = nil
    removeItem(kit)
    vehicle:getModData()[CarPhone.KEY] = r
    tell(player, "mounted")
    CarPhones.sync(player, 0)
end)

Net.onServer("unmountCarPhone", function(player)
    local vehicle = player:getVehicle()
    local r = record(vehicle)
    if not r then return end
    local key = Util.playerKey(player)
    if r.holder and r.holder ~= key and seatedIn(r.holder, vehicle) then return tell(player, "inUse") end
    local h = held[key]
    if h then putBack(key, h) end
    vehicle:getModData()[CarPhone.KEY] = nil
    r.holder = nil
    addItem(player, CarPhone.KIT, function(kit) kit:getModData()[CarPhone.KEY] = r end)
    tell(player, "removed")
end)

Events.EveryOneMinute.Add(Util.safe("car phones", function()
    if isClient() then return end
    for _, p in ipairs(Util.players()) do CarPhones.sync(p, 1) end
end))

return CarPhones
