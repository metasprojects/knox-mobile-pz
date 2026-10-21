-- Client: car phones (1993 hardware). Right-click the Car Phone Kit while sitting in a car: "Mount car phone". From
-- then on, sitting in that car puts the handset in your hands (a phone: right-click → Use phone, like any other);
-- right-click the handset → "Take out the car phone" gives the kit back. The server does the work (CarPhones.lua).
local CarPhone = require "KnoxMobile/Core/CarPhone"
local Phones = require "KnoxMobile/Game/Phones"
local Util = require "KnoxMobile/Game/Util"
local Net = require "KnoxMobile/Game/Net"

local T = Util.text

local EVENTS = {
    mounted = function()
        return T("IGUI_KnoxMobile_CarPhoneMounted", "Car phone mounted. Its handset is yours while you sit in this car.")
    end,
    already = function() return T("IGUI_KnoxMobile_CarPhoneAlready", "This car already has a car phone") end,
    notInCar = function() return T("IGUI_KnoxMobile_CarPhoneNotInCar", "Sit in a car to mount it") end,
    removed = function() return T("IGUI_KnoxMobile_CarPhoneRemoved", "Car phone taken out. The kit keeps its number.") end,
    inUse = function() return T("IGUI_KnoxMobile_CarPhoneInUse", "Someone else in the car has the handset") end,
}

Net.onClient("carPhone", function(args)
    local text = EVENTS[args.event]
    if text and KnoxMobile.UI.toast then KnoxMobile.UI.toast(text()) end
end)

Events.OnFillInventoryObjectContextMenu.Add(Util.safe("car phone menu", function(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    local item = ISInventoryPane.getActualItems(items)[1]
    if not player or not item or not Phones.findById(player, item:getID()) then return end
    local fullType = item:getFullType()
    if fullType == CarPhone.KIT then
        local o = context:addOption(T("IGUI_KnoxMobile_CarPhoneMount", "Mount car phone"), nil, function()
            Net.toServer(player, "mountCarPhone", { kitId = item:getID() })
        end)
        if not player:getVehicle() then
            o.notAvailable = true
            local tip = ISInventoryPaneContextMenu.addToolTip()
            tip.description = T("IGUI_KnoxMobile_CarPhoneNotInCar", "Sit in a car to mount it")
            o.toolTip = tip
        end
    elseif fullType == CarPhone.ITEM then
        context:addOption(T("IGUI_KnoxMobile_CarPhoneUnmount", "Take out the car phone"), nil, function()
            Net.toServer(player, "unmountCarPhone", {})
        end)
    end
end))
