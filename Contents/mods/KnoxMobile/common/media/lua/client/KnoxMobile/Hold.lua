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

-- The arm pose's mask for a hand holding a phone (AnimSets maskingleft/right; the item scripts' primary and
-- secondary AnimMask): the phone Knox raised first, else any phone in one hand (equipped from the inventory).
-- Returns the variable, what Knox wants in it, what's in it now and the phone, or nil when no phone is in one hand.
local HANDS = {
    { var = "LeftHandMask", want = "knoxphonehold", left = true },
    { var = "RightHandMask", want = "knoxphoneholdright", left = false },
}
local function heldPhone(player, hand)
    local off, main = player:getSecondaryHandItem(), player:getPrimaryHandItem()
    local item, other = off, main
    if not hand.left then item, other = main, off end
    if item and item ~= other and Phones.isPhone(item) then return item end
    return nil
end
function Hold.mask(player)
    if not player then return nil end
    local pick
    for _, hand in ipairs(HANDS) do
        local item = heldPhone(player, hand)
        if item and (item == Hold.phone or not pick) then pick = { hand = hand, item = item } end
    end
    if not pick then return nil end
    local var = pick.hand.var
    return var, pick.hand.want, tostring(player:getVariableString(var) or ""):lower(), pick.item
end

-- 0.3.2 (DUSTY, Workshop 2026-11-11: "The character is not bringing the phone up to his face anymore", two days
-- after Project Zomboid 42.22 went stable). 42.22 made LeftHandMask and RightHandMask callback variables
-- (IsoGameCharacter.getSecondaryHandMask): when nothing has set one, an item with an arm mask in its script (every
-- phone) reads the flashlight's low hold, "HoldingTorchLeft"/"HoldingTorchRight" (HeldItemMaskKey.HOLDING_TORCH),
-- so a phone whose own mask got lost sits by the hip. Once a phone is up, a missing mask or that fallback is set to
-- Knox's own (any other mask, like RaiseHand while aiming, is left alone), and cleared again when the phone leaves that
-- hand so an empty hand doesn't keep the pose. What the game gave goes to console.txt once per raise. The call and
-- down variables are sent again every few seconds and to a new character, not only when they change.
local POSE_RESEND_MS = 3000
local FALLBACK = { [""] = true, holdingtorchleft = true, holdingtorchright = true }

-- 42.22 keeps a set mask in a field the game only clears when it rebuilds a hand's model; Knox hides the held model
-- at times (back camera, VR), so a phone put away then would leave its pose on the next thing in that hand.
local function giveBack(player)
    local set = Hold.maskSet
    if not set then return end
    Hold.maskSet = nil
    if set.player ~= player then return end
    for _, hand in ipairs(HANDS) do
        if hand.var == set.var and heldPhone(player, hand) then return end -- a phone still holds it
    end
    if tostring(player:getVariableString(set.var) or ""):lower() == set.want then
        player:clearVariable(set.var)
    end
end

local function pose(player)
    local var, want, now, item = Hold.mask(player)
    if Hold.maskSet and (Hold.maskSet.var ~= var or Hold.maskSet.player ~= player) then giveBack(player) end
    if not var then Hold.poseFor = nil; return end
    local key = tostring(item:getID()) .. var
    local got = now
    if FALLBACK[now] then
        player:setVariable(var, want)
        Hold.maskSet = { var = var, want = want, player = player }
        now = tostring(player:getVariableString(var) or ""):lower()
    end
    if key ~= Hold.poseFor then
        Hold.poseFor = key
        Util.log("Hold:", item:getType(), var, "=", got ~= "" and got or "(empty)",
            got == want and "ok" or ("-> " .. now), "down", tostring(Hold.wasDown), "call", tostring(Hold.wasOnCall))
    end
end

-- Ten times a second is plenty for the arm poses and the hold checks (0.2.1: was OnPlayerUpdate, every frame).
Tick.add("hold phone", function()
    local player = getPlayer()
    if not player then return end
    local t = getTimestampMs()
    if player ~= Hold.forPlayer or t >= (Hold.resendAt or 0) then
        Hold.forPlayer, Hold.resendAt = player, t + POSE_RESEND_MS
        Hold.wasOnCall, Hold.wasDown = nil, nil
    end
    local onCall = Hold.onCall()
    if onCall ~= Hold.wasOnCall then
        Hold.wasOnCall = onCall
        player:setVariable("KnoxPhoneCall", onCall)
    end
    -- Walking keeps the phone up; sprinting brings it down (2026-10-18).
    -- Debug > "Pretend to sprint" stands in for running (the test runner can't make a character sprint).
    -- The back camera in first person lowers it too (UI/Phone.lua: Hold.cameraDown), only while the phone is open.
    local camera = Hold.cameraDown == true and KnoxMobile.UI ~= nil and KnoxMobile.UI.panel ~= nil
    local down = player:isSprinting() or Hold.fakeSprint == true or camera
    if down ~= Hold.wasDown then
        Hold.wasDown = down
        player:setVariable("KnoxPhoneDown", down)
    end
    if t < Hold.nextCheck then return end
    Hold.nextCheck = t + CHECK_MS
    check(player)
    pose(player)
end, 100)

Events.OnPlayerDeath.Add(Util.safe("hold phone death", function(player)
    if player ~= getPlayer() then return end
    closePanel()
    setGlow(player, false)
    Hold.phone = nil
end))

return Hold
