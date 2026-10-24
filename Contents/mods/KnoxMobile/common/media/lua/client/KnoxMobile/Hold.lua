-- Client: holding the phone (spec §8.1, §9.3): raise it in the off-hand, put it away, stumble while
-- sprinting, drop it when grabbed or knocked down, pocket damage from falls, and a soft glow at night.
local Phones = require "KnoxMobile/Game/Phones"
local Util = require "KnoxMobile/Game/Util"
local Net = require "KnoxMobile/Game/Net"
local Tick = require "KnoxMobile/Game/Tick"

local Hold = { phone = nil, activity = nil, onFloor = false, light = nil, lightAt = nil, nextCheck = 0 }
KnoxMobile.Hold = Hold

local CHECK_MS = 500

local function twoHanded(item)
    local ok, yes = pcall(function() return item:isTwoHandWeapon() end)
    return ok and yes
end

-- Put the phone in the off hand, or the main hand when the player chose that (Options: Hold the phone in). A two-handed
-- weapon goes away first; a one-handed one stays (in the main hand, it goes to the off hand's place: the game's own
-- equip swaps it). A phone already in either hand stays where it is.
function Hold.raise(player, item)
    if player:getPrimaryHandItem() == item or player:getSecondaryHandItem() == item then
        Hold.phone = item
        return
    end
    ISInventoryPaneContextMenu.transferIfNeeded(player, item)
    local primary = player:getPrimaryHandItem()
    if primary and twoHanded(primary) then
        ISTimedActionQueue.add(ISUnequipAction:new(player, primary, 50))
    end
    local main = KnoxMobile.Options and KnoxMobile.Options.hand() == "main"
    -- Immersive first person reads the phone in your hand, and Viewpoint's first person only shows a main-hand hold
    -- (PC test 2026-10-23: an off-hand phone never came into view), so there it goes to the main hand.
    local VP, Live = KnoxMobile.Viewpoint, KnoxMobile.Live
    if not main and KnoxMobile.Options and KnoxMobile.Options.immersive() and VP and VP.view() == "first"
        and Live and Live.active() then
        main = true
    end
    if (main and player:getPrimaryHandItem() ~= item) or (not main and player:getSecondaryHandItem() ~= item) then
        ISTimedActionQueue.add(ISEquipWeaponAction:new(player, item, 20, main, false))
    end
    Hold.phone = item
end

function Hold.lower(player, item)
    -- A smartphone with its flashlight on stays in hand, lighting the way; only its screen closes.
    if item and player:isEquipped(item) and KnoxMobile.Flashlight and KnoxMobile.Flashlight.isOn(item) then
        Hold.phone = item
        Hold.report(player, nil)
        return
    end
    if item and player:isEquipped(item) then
        ISTimedActionQueue.add(ISUnequipAction:new(player, item, 20))
    end
    Hold.phone = nil
    Hold.report(player, nil)
end

-- Tell the server what the open phone is doing, so the battery drains the right amount.
function Hold.report(player, item, drain, noService, flashlight)
    local key = item and (item:getID() .. ":" .. tostring(drain) .. ":" .. tostring(noService) .. ":" .. tostring(flashlight)) or "closed"
    if key == Hold.activity then return end
    Hold.activity = key
    if item then
        Net.toServer(player, "activity", { phoneId = item:getID(), state = drain or "screen",
            noService = noService == true, flashlight = flashlight == true })
    else
        Net.toServer(player, "activity", { closed = true })
    end
end

local function closePanel()
    if KnoxMobile.UI.close then KnoxMobile.UI.close() end
end

local function dropPhone(player, item)
    closePanel()
    Net.toServer(player, "dropped", { phoneId = item:getID() })
    ISTimedActionQueue.clear(player)
    ISInventoryPaneContextMenu.dropItem(item, player:getPlayerNum())
    if KnoxMobile.Client then KnoxMobile.Client.toast(Util.text("IGUI_KnoxMobile_Dropped", "You dropped your phone!"), "damage") end
end

local function stumble(player)
    player:setBumpType("stagger")
    player:setVariable("BumpDone", false)
    player:setVariable("BumpFall", true)
    player:setVariable("BumpFallType", "pushedFront")
end

-- Build 42 has no "grabbed by" call for players (grapple is the corpse-dragging system). A zombie attack
-- shows as a hit reaction with a zombie as the attacker; being knocked down counts too.
local function grabbed(player)
    if player:isKnockedDown() then return true end
    local ok, hit = pcall(function()
        if not player:hasHitReaction() then return false end
        local by = player:getAttackedBy()
        return by ~= nil and by:isZombie()
    end)
    return ok and hit == true
end

-- Screen glow: a small light that follows the player while the screen is on in the dark.
local function setGlow(player, on)
    local cell = getCell()
    local x, y, z = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())
    local at = x .. "," .. y .. "," .. z
    if Hold.light and (not on or Hold.lightAt ~= at) then
        cell:removeLamppost(Hold.light)
        Hold.light, Hold.lightAt = nil, nil
    end
    if on and not Hold.light then
        Hold.light = IsoLightSource.new(x, y, z, 0.45, 0.55, 0.7, 2)
        Hold.lightAt = at
        cell:addLamppost(Hold.light)
    end
end

local function check(player)
    local item = Hold.phone
    local settings = Util.settings()
    local holding = item ~= nil and player:isEquipped(item)

    if holding and player:isSprinting() and ZombRand(1000) < settings.StumbleChance * 0.5 then
        stumble(player)
        if ZombRand(100) < settings.DropChance then dropPhone(player, item); holding = false end
    end
    -- Being grabbed always closes the phone; sometimes it hits the floor (spec §8.1).
    if holding and grabbed(player) then
        if ZombRand(100) < settings.DropChance then dropPhone(player, item) else closePanel() end
        holding = false
    end

    -- A fall or knockdown can hurt pocketed phones; lying down to sleep or sitting on the ground can't.
    local resting = player:isAsleep() or player:isSitOnGround()
    local floor = (player:isOnFloor() or player:isKnockedDown()) and not resting
    if floor and not Hold.onFloor then Net.toServer(player, "fell", {}) end
    Hold.onFloor = floor

    local state = holding and Phones.get(item)
    local dark = getClimateManager():getDayLightStrength() < 0.4
    setGlow(player, state and state.power.on and dark or false)
end

-- On a call (dialling or talking, not while it rings) the held phone goes to the ear: the left-arm pose in
-- media/AnimSets/player/maskingleft/KnoxMobile_PhoneEar.xml. The variable syncs to other players with the
-- character's animation state.
function Hold.onCall()
    local call = KnoxMobile.Client and KnoxMobile.Client.call
    return call ~= nil and call.status ~= "incoming"
end

-- Ten times a second is plenty for the arm poses and the hold checks (0.2.1: was OnPlayerUpdate, every frame).
Tick.add("hold phone", function()
    local player = getPlayer()
    if not player then return end
    local onCall = Hold.onCall()
    if onCall ~= Hold.wasOnCall then
        Hold.wasOnCall = onCall
        player:setVariable("KnoxPhoneCall", onCall)
    end
    -- Walking keeps the phone up; sprinting brings it down (2026-10-18).
    -- Debug > "Pretend to sprint" stands in for running (the test runner can't make a character sprint).
    -- The back camera in first person lowers it too (UI/Phone.lua: Hold.cameraDown).
    local down = player:isSprinting() or Hold.fakeSprint == true or Hold.cameraDown == true
    if down ~= Hold.wasDown then
        Hold.wasDown = down
        player:setVariable("KnoxPhoneDown", down)
    end
    local t = getTimestampMs()
    if t < Hold.nextCheck then return end
    Hold.nextCheck = t + CHECK_MS
    check(player)
end, 100)

Events.OnPlayerDeath.Add(Util.safe("hold phone death", function(player)
    if player ~= getPlayer() then return end
    closePanel()
    setGlow(player, false)
    Hold.phone = nil
end))

return Hold
