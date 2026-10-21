-- Server: the smartphones' flashlight switch (client/KnoxMobile/Apps/Flashlight.lua explains how the light is
-- drawn). The phone's state holds the switch (`flashlight`). PhoneTick drains the battery faster while it is on
-- (sandbox FlashlightDrain) and calls Flashlight.check every minute, which switches it off when the phone dies,
-- is switched off or broken, or has left the hand. After every change the server re-sends the player's hands
-- (sendEquip) so other players' copies of the phone carry the new state and light up (or go dark) too.
local Phones = require "KnoxMobile/Game/Phones"
local Util = require "KnoxMobile/Game/Util"
local Net = require "KnoxMobile/Game/Net"

local Flashlight = {}
KnoxMobile.FlashlightServer = Flashlight

local SMART = { ModernAndroid = true, ModernPear = true }
local GRACE = 2 -- minutes a phone switched on may take to reach the hand (the equip action)

function Flashlight.works(state)
    return state.power.on and state.battery.charge > 0 and state.condition ~= "broken"
end

-- Switches the light; returns true when it changed.
function Flashlight.set(player, item, state, on)
    on = on == true
    if (state.flashlight == true) == on then return false end
    state.flashlight = on or nil
    state.flashlightSince = on and math.floor(Util.nowMinutes()) or nil
    Phones.save(item, player)
    if isServer() and player:isEquipped(item) then sendEquip(player) end
    return true
end

Net.onServer("flashlight", function(player, args)
    if type(args.phoneId) ~= "number" or type(args.on) ~= "boolean" then return end
    local item = Phones.findById(player, args.phoneId)
    if not item or not Phones.isPhone(item) then return end
    local state, model = Phones.get(item)
    if not state or not SMART[model.family] then return end
    local reason = nil
    if args.on and not Flashlight.works(state) then
        reason = "noPower"
    else
        Flashlight.set(player, item, state, args.on)
    end
    Net.toClient(player, "flashlightResult", { phoneId = item:getID(), on = state.flashlight == true, reason = reason })
end)

-- Every minute for each carried phone (PhoneTick).
function Flashlight.check(player, item, state)
    if not state.flashlight then return end
    if not Flashlight.works(state) then
        Flashlight.set(player, item, state, false)
        return
    end
    local since = state.flashlightSince or 0
    if not player:isEquipped(item) and Util.nowMinutes() - since >= GRACE then Flashlight.set(player, item, state, false) end
end

return Flashlight
