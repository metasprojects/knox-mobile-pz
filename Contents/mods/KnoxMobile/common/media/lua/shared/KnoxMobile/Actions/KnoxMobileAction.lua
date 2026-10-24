-- Every Knox Mobile timed action, as one class with many kinds (spec §4.5, §6.3-§6.5, §7.3, §9.3-§9.5).
-- Build 42 runs complete() on the server (or in single player) and perform() on the client. The server
-- rebuilds the action from the constructor arguments, so each argument is stored under its own name.
require "TimedActions/ISBaseTimedAction"
local Phones = require "KnoxMobile/Game/Phones"
local Util = require "KnoxMobile/Game/Util"
local Env = require "KnoxMobile/Game/Env"
local Net = require "KnoxMobile/Game/Net"
local Power = require "KnoxMobile/Core/Power"
local Charging = require "KnoxMobile/Core/Charging"
local Damage = require "KnoxMobile/Core/Damage"
local PhoneState = require "KnoxMobile/Core/PhoneState"
local Sim = require "KnoxMobile/Core/Sim"
local Rng = require "KnoxMobile/Core/Rng"
local ItemIds = require "KnoxMobile/ItemIds"
local Messages = require "KnoxMobile/Data/Messages"
local Replies = require "KnoxMobile/Core/Replies"

KnoxMobileAction = ISBaseTimedAction:derive("KnoxMobileAction")
local Kinds = {}
KnoxMobileAction.Kinds = Kinds

-- Helpers ---------------------------------------------------------------------------------------
local function carried(character, item)
    return item ~= nil and Phones.findById(character, item:getID()) ~= nil
end

local function removeItem(item)
    local c = item:getContainer()
    if c then
        c:Remove(item)
        sendRemoveItemFromContainer(c, item)
    end
end

-- setup(item) runs before the item is sent to the client, so its name and data arrive with it.
local function addItem(character, fullType, setup)
    local inv = character:getInventory()
    local item = inv:AddItem(fullType)
    if item then
        if setup then setup(item) end
        sendAddItemToContainer(inv, item)
    end
    return item
end

local function tell(character, args) Net.toClient(character, "notify", args) end

local function knownFamilies(character)
    local md = character:getModData()
    if type(md.KnoxMobileKnown) ~= "table" then md.KnoxMobileKnown = {} end
    return md.KnoxMobileKnown
end

local function rngFor(item, label)
    local minute = tostring(math.floor(Util.nowMinutes()))
    return Rng.new(tostring(Phones.worldSeed()) .. ":" .. label .. ":" .. tostring(item:getID()) .. ":" .. minute)
end

local function hasScrewdriver(character) return Phones.hasScrewdriver(character) end

-- The second item has to be what the kind needs: the server rebuilds actions from what a client sends.
local function isType(item, fullType) return item ~= nil and item:getFullType() == fullType end

local function electrical(character)
    local ok, level = pcall(function() return character:getPerkLevel(Perks.Electricity) end)
    return ok and level or 0
end

local function phoneOn(item)
    local state = Phones.get(item)
    return state ~= nil and state.power.on
end

-- Kinds: time (ticks or function), anim, valid(self), complete(self) on the server, done(self) on the client.
Kinds.powerOn = {
    time = 40,
    valid = function(self)
        local state = Phones.get(self.item)
        return state and not state.power.on and state.condition ~= "broken" and not state.rice
    end,
    complete = function(self)
        local state, model = Phones.get(self.item)
        if not Power.canPowerOn(state.battery) then
            tell(self.character, { kind = "battery", event = "dead", phoneId = self.item:getID() })
            return
        end
        if state.wetness == "waterDamaged" and rngFor(self.item, "short"):chance(0.5) then
            tell(self.character, { kind = "wet", event = "shortCircuit", phoneId = self.item:getID() })
            return
        end
        state.power.on = true
        if state.owner.pending and KnoxMobile.Server then KnoxMobile.Server.fillFoundPhone(self.item, state, model, self.character) end
        if KnoxMobile.Server then KnoxMobile.Server.deliverNow(self.character) end
    end,
}

Kinds.powerOff = {
    time = 20,
    valid = function(self) return phoneOn(self.item) end,
    complete = function(self) Phones.get(self.item).power.on = false end,
}

Kinds.insertSim = {
    time = 60,
    valid = function(self)
        local state = Phones.get(self.item)
        return state and not state.sim and Phones.isSim(self.other) and carried(self.character, self.other)
    end,
    complete = function(self)
        local state = Phones.get(self.item)
        local sim = PhoneState.copy(Phones.simData(self.other))
        if Sim.isBlank(sim) and KnoxMobile.Server then KnoxMobile.Server.activateSim(sim) end
        state.sim = sim
        removeItem(self.other)
        tell(self.character, { kind = "sim", event = "inserted", number = sim.number, phoneId = self.item:getID() })
        if KnoxMobile.Server then KnoxMobile.Server.deliverNow(self.character) end
    end,
}

Kinds.ejectSim = {
    time = 60,
    valid = function(self) local state = Phones.get(self.item); return state and state.sim ~= nil end,
    complete = function(self)
        local state = Phones.get(self.item)
        local sim = state.sim
        local simItem = addItem(self.character, "KnoxMobile.SimCard", function(it)
            it:getModData()[Phones.KEY] = sim
            Phones.nameSim(it, sim.number)
        end)
        if not simItem then return end
        state.sim = nil
    end,
}

Kinds.openBox = {
    time = 80,
    valid = function(self) return Phones.isBox(self.item) and carried(self.character, self.item) end,
    complete = function(self)
        local _, model = Phones.isBox(self.item)
        if not model then return end
        local rng = rngFor(self.item, "box")
        addItem(self.character, ItemIds.full(ItemIds.phone(model, rng:pick(model.colors))), function(phone)
            phone:getModData().KnoxMobileOrigin = "newInBox"
            Phones.get(phone)
        end)
        addItem(self.character, ItemIds.full(ItemIds.manual(model.family)))
        if rng:chance(0.6) then
            if model.connector == "Pin" or model.connector == "Flat" then
                addItem(self.character, "KnoxMobile.WallCharger" .. model.connector)
            else
                addItem(self.character, "KnoxMobile.Cable" .. model.connector)
                if rng:chance(0.7) then addItem(self.character, "KnoxMobile.UsbWallAdapter") end
            end
        end
        removeItem(self.item)
    end,
}

Kinds.readManual = {
    time = 300,
    anim = "Read",
    valid = function(self) return Phones.manualFamily(self.item) ~= nil and carried(self.character, self.item) end,
    complete = function(self)
        knownFamilies(self.character)[Phones.manualFamily(self.item)] = true
        tell(self.character, { kind = "manual", event = "read" })
    end,
    done = function(self)
        knownFamilies(self.character)[Phones.manualFamily(self.item)] = true
        pcall(function() self.character:getStats():remove(CharacterStat.BOREDOM, 10) end)
    end,
}

-- Picks the best charger the player carries for where they stand (or the one source `only`), and plugs the phone in.
local function plugIn(self, quiet, only)
    local state, model = Phones.get(self.item)
    local env = Env.snapshot(self.character)
    local plug, why = Charging.choose(Phones.registry, model, Phones.chargingGear(self.character), env,
        Util.powerSettings(), only)
    if not plug then
        if not quiet then tell(self.character, { kind = "charge", event = "cannot", reason = why, phoneId = self.item:getID() }) end
        return false
    end
    state.plug = { source = plug.source, via = plug.via, setup = plug.setup.kind, x = env.x, y = env.y, z = env.z }
    tell(self.character, { kind = "charge", event = "started", source = plug.source, phoneId = self.item:getID() })
    return true
end

Kinds.plug = {
    time = 30,
    valid = function(self) local state = Phones.get(self.item); return state and not state.plug end,
    complete = function(self) plugIn(self) end,
}

Kinds.unplug = {
    time = 15,
    valid = function(self) local state = Phones.get(self.item); return state and state.plug ~= nil end,
    complete = function(self) Phones.get(self.item).plug = nil end,
}

Kinds.wrap = {
    time = 50,
    valid = function(self)
        local state = Phones.get(self.item)
        return state and not state.wrapped and isType(self.other, "Base.Plasticbag") and carried(self.character, self.other)
    end,
    complete = function(self)
        if Damage.wrap(Phones.get(self.item)) then removeItem(self.other) end
    end,
}

Kinds.unwrap = {
    time = 40,
    valid = function(self) local state = Phones.get(self.item); return state and state.wrapped end,
    complete = function(self)
        if Damage.unwrap(Phones.get(self.item)) then addItem(self.character, "Base.Plasticbag") end
    end,
}

Kinds.fitCase = {
    time = 60,
    valid = function(self)
        local state, model = Phones.get(self.item)
        local a = Phones.accessory(self.other)
        return state and not state.look.case and a and a.kind == "case" and a.caseSize == model.caseSize
            and (a.caseType ~= "Battery" or Power.isModern(model)) and carried(self.character, self.other)
    end,
    complete = function(self)
        local state = Phones.get(self.item)
        local a = Phones.accessory(self.other)
        state.look.case, state.look.caseItem = a.caseType, self.other:getFullType()
        removeItem(self.other)
    end,
}

Kinds.removeCase = {
    time = 50,
    valid = function(self) local state = Phones.get(self.item); return state and state.look.case ~= nil end,
    complete = function(self)
        local state = Phones.get(self.item)
        if state.look.caseItem then addItem(self.character, state.look.caseItem) end
        state.look.case, state.look.caseItem = nil, nil
    end,
}

Kinds.fitProtector = {
    time = 60,
    valid = function(self)
        local state = Phones.get(self.item)
        return state and not state.look.protector and state.condition ~= "cracked" and state.condition ~= "broken"
            and isType(self.other, "KnoxMobile.ScreenProtector") and carried(self.character, self.other)
    end,
    complete = function(self)
        Phones.get(self.item).look.protector = true
        removeItem(self.other)
    end,
}

local REPAIR_PART = { screen = "KnoxMobile.PhoneScreen", battery = "KnoxMobile.PhoneBattery" }

Kinds.repair = {
    time = function(self) return math.max(150, 400 - 25 * electrical(self.character)) end,
    valid = function(self)
        local state = Phones.get(self.item)
        if not state or state.power.on or not hasScrewdriver(self.character) then return false end
        if REPAIR_PART[self.extra] then return isType(self.other, REPAIR_PART[self.extra]) and carried(self.character, self.other) end
        return self.extra == "water"
    end,
    complete = function(self)
        local state, model = Phones.get(self.item)
        local known = knownFamilies(self.character)[model.family] == true
        local result = Damage.attemptRepair(rngFor(self.item, "repair"), state, self.extra, electrical(self.character), known)
        if self.other and REPAIR_PART[self.extra] then removeItem(self.other) end
        pcall(function() addXp(self.character, Perks.Electricity, result == "fixed" and 4 or 2) end)
        tell(self.character, { kind = "repair", event = result, part = self.extra, phoneId = self.item:getID() })
    end,
}

Kinds.riceIn = {
    time = 40,
    valid = function(self)
        local state = Phones.get(self.item)
        return state and not state.rice and isType(self.other, "Base.Rice") and carried(self.character, self.other)
    end,
    complete = function(self)
        local state = Phones.get(self.item)
        state.power.on = false
        state.rice = { since = Util.nowMinutes() }
    end,
}

Kinds.riceOut = {
    time = 30,
    valid = function(self) local state = Phones.get(self.item); return state and state.rice ~= nil end,
    complete = function(self)
        local state = Phones.get(self.item)
        local result = Damage.rice(state, Util.nowMinutes() - state.rice.since, { riceTrick = Util.settings().RiceTrick })
        if result == "notYet" then
            tell(self.character, { kind = "rice", event = "notYet", phoneId = self.item:getID() })
        else
            state.rice = nil
            tell(self.character, { kind = "rice", event = result, phoneId = self.item:getID() })
        end
    end,
}

-- Hand crank (item = phone, other = crank charger): charging happens in the server's minute tick while
-- the cranking flag is set; stopping unplugs it on the next tick.
Kinds.crank = {
    time = 1800,
    anim = "Craft",
    valid = function(self)
        return Phones.get(self.item) ~= nil and isType(self.other, "KnoxMobile.CrankCharger") and carried(self.character, self.other)
    end,
    start = function(self)
        self.character:getModData().KnoxMobileCranking = true
        local state = Phones.get(self.item)
        -- Not quiet: a phone the crank can't reach (no fitting cable) says so instead of cranking for nothing.
        -- Cranking always charges from the crank, even in a car or with a power bank (PC test r5).
        if state.plug and state.plug.source ~= "crank" then state.plug = nil end
        if not state.plug and plugIn(self, false, "crank") then Phones.save(self.item, self.character) end
    end,
    finish = function(self) self.character:getModData().KnoxMobileCranking = nil end,
    complete = function() end,
}

Kinds.placeRepeater = {
    time = 200,
    anim = "Loot",
    valid = function(self)
        local sq = self.character:getCurrentSquare()
        return sq ~= nil and isType(self.item, "KnoxMobile.Repeater") and carried(self.character, self.item)
    end,
    complete = function(self)
        local sq = self.character:getCurrentSquare()
        local item = self.item
        -- Register first, so the placed item carries its repeater id to every client.
        local rep = KnoxMobile.Server and KnoxMobile.Server.placeRepeater(self.character, sq)
        if rep then item:getModData().KnoxMobileRepeaterId = rep.id end
        removeItem(item)
        -- AddWorldInventoryItem returns the item; its world object is item:getWorldItem().
        local placed = sq:AddWorldInventoryItem(item, 0.5, 0.5, 0, false)
        local wo = placed and placed:getWorldItem()
        if wo then
            wo:setIgnoreRemoveSandbox(true)
            wo:transmitCompleteItemToClients()
        end
        if rep then
            tell(self.character, { kind = "repeater", event = rep.powered and "placedPowered" or "placedUnpowered", id = rep.id })
        end
    end,
}

Kinds.scrap = {
    time = 200,
    valid = function(self)
        local state = Phones.get(self.item)
        return state and not state.power.on and hasScrewdriver(self.character)
    end,
    complete = function(self)
        local state = Phones.get(self.item)
        if KnoxMobile.PhotoStore then KnoxMobile.PhotoStore.release(state) end
        for _, part in ipairs(Damage.scrapYield(rngFor(self.item, "scrap"), state)) do
            local fullType = part.item == "ElectronicsScrap" and "Base.ElectronicsScrap" or ("KnoxMobile." .. part.item)
            for _ = 1, part.count do addItem(self.character, fullType) end
        end
        if state.sim then
            local sim = state.sim
            addItem(self.character, "KnoxMobile.SimCard", function(it)
                it:getModData()[Phones.KEY] = sim
                Phones.nameSim(it, sim.number)
            end)
        end
        removeItem(self.item)
        pcall(function() addXp(self.character, Perks.Electricity, 3) end)
    end,
    noSave = true,
}

-- Cracking a PIN: slow, better with Electrical skill; failure locks the phone out for an hour.
Kinds.crackPin = {
    time = function(self) return math.max(300, 1200 - 90 * electrical(self.character)) end,
    valid = function(self)
        local state = Phones.get(self.item)
        if not state or not state.security.locked or not state.power.on then return false end
        local until_ = state.security.lockoutUntil
        return not (until_ and Util.nowMinutes() < until_)
    end,
    complete = function(self)
        local state = Phones.get(self.item)
        local chance = math.min(0.9, 0.2 + 0.08 * electrical(self.character))
        if rngFor(self.item, "crack"):chance(chance) then
            state.security.locked, state.security.pin, state.security.failedAttempts = false, nil, 0
            tell(self.character, { kind = "crack", event = "ok", phoneId = self.item:getID() })
        else
            state.security.lockoutUntil = Util.nowMinutes() + 60
            tell(self.character, { kind = "crack", event = "failed", phoneId = self.item:getID() })
        end
        pcall(function() addXp(self.character, Perks.Electricity, 2) end)
    end,
}

-- Battery swap for families with removable batteries (spec §6.3). Spares keep their own charge.
Kinds.swapBattery = {
    -- Knowing the family from its manual makes the swap quicker (spec §4.4).
    time = function(self)
        local model = Phones.model(self.item)
        return model and knownFamilies(self.character)[model.family] and 30 or 60
    end,
    valid = function(self)
        local state, model = Phones.get(self.item)
        local a = Phones.accessory(self.other)
        return state and model.removableBattery and a and a.kind == "spareBattery" and a.family == model.family
            and carried(self.character, self.other)
    end,
    complete = function(self)
        local state = Phones.get(self.item)
        local md = self.other:getModData()
        local charge = Phones.spareCharge(self.other) -- same first value the tooltip shows
        local health = md.KnoxMobileHealth or 100
        md.KnoxMobileCharge, md.KnoxMobileHealth = state.battery.charge, state.battery.health
        state.battery.charge, state.battery.health = charge, health
        state.power.on = false
        Phones.save(self.other, self.character)
    end,
}

-- Power bank refills at a wall through a USB wall adapter (spec §6.5); the server's minute tick does the charging.
Kinds.plugBank = {
    time = 30,
    valid = function(self)
        local sq = self.character:getCurrentSquare()
        return self.item:getFullType() == "KnoxMobile.PowerBank" and not self.item:getModData().KnoxMobileBankPlug
            and self.character:getInventory():containsTypeRecurse("KnoxMobile.UsbWallAdapter") and sq ~= nil and Util.powered(sq)
    end,
    complete = function(self)
        self.item:getModData().KnoxMobileBankPlug = { x = self.character:getX(), y = self.character:getY(), z = self.character:getZ() }
        Phones.save(self.item, self.character)
        tell(self.character, { kind = "bank", event = "plugged" })
    end,
}

Kinds.unplugBank = {
    time = 15,
    valid = function(self) return self.item:getModData().KnoxMobileBankPlug ~= nil end,
    complete = function(self)
        self.item:getModData().KnoxMobileBankPlug = nil
        Phones.save(self.item, self.character)
    end,
}

-- Leave a phone charging on the floor of a powered building (spec §6.5 "placed on a surface"). The server
-- charges it on a slow timer (§13.7); anyone can pick it up (and in multiplayer, steal it).
-- Return the phone (0.2.0): a found phone left at the house its owner's family named (server TextBack). Your SIM
-- comes out first; the phone stays on the floor there, for whoever comes by.
Kinds.takeHome = {
    time = 80,
    anim = "Loot",
    valid = function(self)
        local state = Phones.get(self.item)
        local home = state and state.story and state.story.home
        return home ~= nil and not home.returned and state.sim == nil
            and Replies.nearHome(home, self.character:getX(), self.character:getY())
    end,
    complete = function(self)
        local state = Phones.get(self.item)
        state.story.home.returned = true
        if KnoxMobile.TextBack then KnoxMobile.TextBack.returned(self.character, state) end
        local sq = self.character:getCurrentSquare()
        Phones.save(self.item, self.character)
        removeItem(self.item)
        local placed = sq and sq:AddWorldInventoryItem(self.item, 0.5, 0.5, 0, false)
        local wo = placed and placed:getWorldItem()
        if wo then
            wo:setIgnoreRemoveSandbox(true)
            wo:transmitCompleteItemToClients()
        end
        tell(self.character, { kind = "returned", event = "home", source = state.owner.first, phoneId = self.item:getID() })
    end,
    noSave = true,
}

Kinds.leaveCharging = {
    time = 40,
    anim = "Loot",
    valid = function(self)
        local sq = self.character:getCurrentSquare()
        return Phones.get(self.item) ~= nil and sq ~= nil and Util.powered(sq)
    end,
    complete = function(self)
        local state = Phones.get(self.item)
        if not state.plug and not plugIn(self) then return end
        if state.plug.source ~= "wall" then
            tell(self.character, { kind = "charge", event = "cannot", reason = "wallOnly", phoneId = self.item:getID() })
            return
        end
        local sq = self.character:getCurrentSquare()
        Phones.save(self.item, self.character)
        removeItem(self.item)
        local placed = sq:AddWorldInventoryItem(self.item, 0.5, 0.5, 0, false)
        local wo = placed and placed:getWorldItem()
        if wo then
            wo:setIgnoreRemoveSandbox(true)
            wo:transmitCompleteItemToClients()
        end
        if KnoxMobile.Server then KnoxMobile.Server.worldCharge(self.item, sq) end
        tell(self.character, { kind = "charge", event = "leftCharging", phoneId = self.item:getID() })
    end,
    noSave = true,
}

-- "Wipe and set up" (spec §5.1): an unlocked found phone becomes yours; the dead owner's data is gone.
Kinds.wipe = {
    time = 120,
    valid = function(self)
        local state = Phones.get(self.item)
        return state and state.power.on and not state.security.locked and state.owner.kind == "generated"
    end,
    complete = function(self)
        local state = Phones.get(self.item)
        if KnoxMobile.PhotoStore then KnoxMobile.PhotoStore.release(state) end
        state.contents = { texts = {}, calls = {}, voicemails = {}, notes = {} }
        state.owner = { kind = "player" }
        state.story = nil
        state.security = { locked = false, pin = nil, failedAttempts = 0, lockoutUntil = nil }
        tell(self.character, { kind = "wipe", event = "done", phoneId = self.item:getID() })
    end,
}

local LABELS = Messages.jobs
for id, label in pairs(LABELS) do Kinds[id].label = label end

-- The action class ------------------------------------------------------------------------------
function KnoxMobileAction:kindDef() return Kinds[self.kind] end

function KnoxMobileAction:isValid()
    local def = self:kindDef()
    if not def or not self.item then return false end
    if not carried(self.character, self.item) then return false end
    local ok, valid = pcall(def.valid, self)
    return ok and valid == true
end

function KnoxMobileAction:waitToStart() return false end

function KnoxMobileAction:update()
    if self.item and self.item.setJobDelta then self.item:setJobDelta(self:getJobDelta()) end
end

function KnoxMobileAction:start()
    if isClient() then
        if self.item then self.item = Phones.findById(self.character, self.item:getID()) or self.item end
        if self.other then self.other = Phones.findById(self.character, self.other:getID()) or self.other end
    end
    local def = self:kindDef()
    if self.item and self.item.setJobType then
        self.item:setJobType(Util.text("IGUI_KnoxMobile_Job_" .. self.kind, def.label or self.kind))
    end
    if def.anim == "Read" then
        self:setAnimVariable("ReadType", "book")
        self:setActionAnim(CharacterActionAnims.Read)
    elseif def.anim then
        self:setActionAnim(def.anim)
    end
    if def.start and not isClient() then def.start(self) end
end

function KnoxMobileAction:serverStart()
    local def = self:kindDef()
    if def and def.start then def.start(self) end
end

local function finish(self)
    local def = self:kindDef()
    if def and def.finish then def.finish(self) end
end

function KnoxMobileAction:stop()
    if self.item and self.item.setJobDelta then self.item:setJobDelta(0) end
    if not isClient() then finish(self) end
    ISBaseTimedAction.stop(self)
end

function KnoxMobileAction:serverStop() finish(self) end

function KnoxMobileAction:perform()
    if self.item and self.item.setJobDelta then self.item:setJobDelta(0) end
    local def = self:kindDef()
    if def and def.done then def.done(self) end
    if KnoxMobile.UI and KnoxMobile.UI.refresh then KnoxMobile.UI.refresh() end
    ISBaseTimedAction.perform(self)
end

function KnoxMobileAction:complete()
    local def = self:kindDef()
    if not def then return false end
    local ok, err = pcall(def.complete, self)
    if not ok then Util.log("ERROR in action " .. tostring(self.kind) .. ": " .. tostring(err)) end
    finish(self)
    if not def.noSave and Phones.isPhone(self.item) then Phones.save(self.item, self.character) end
    return true
end

function KnoxMobileAction:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    local def = Kinds[self.kind]
    if not def then return 1 end
    if type(def.time) == "function" then return def.time(self) end
    return def.time
end

-- kind: a key of KnoxMobileAction.Kinds. item: the phone (or box, manual, repeater, crank charger).
-- other: a second item (SIM, case, part, plastic bag, rice, spare battery). extra: a string (repair kind).
function KnoxMobileAction:new(character, kind, item, other, extra)
    local o = ISBaseTimedAction.new(self, character)
    o.kind = kind
    o.item = item
    o.other = other
    o.extra = extra
    o.stopOnWalk = kind ~= "crank"
    o.stopOnRun = true
    o.maxTime = o:getDuration()
    return o
end

-- Queue an action from client code.
function KnoxMobileAction.queue(character, kind, item, other, extra)
    ISTimedActionQueue.add(KnoxMobileAction:new(character, kind, item, other, extra))
end
