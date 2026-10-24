-- Client: vanilla payphones (1993 hardware). Right-click one (or the wall it hangs on): Use payphone → "Call a number
-- (25 cents)" asks for a number and the server rings that phone like any call (the coins are flavour); while the call
-- lasts the same menu offers "Hang up". Greyed without power. Walking away drops the call (the server checks).
local Payphone = require "KnoxMobile/Core/Payphone"
local Sim = require "KnoxMobile/Core/Sim"
local Util = require "KnoxMobile/Game/Util"
local Net = require "KnoxMobile/Game/Net"
local Tick = require "KnoxMobile/Game/Tick"

local T = Util.text

local P = { pending = nil }
KnoxMobile.Payphone = P

function P.onSquare(sq)
    local objects = sq and sq:getObjects()
    if not objects then return nil end
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        local props = obj.getProperties and obj:getProperties()
        if props and Payphone.isPayphone(props:get("CustomName"), props:get("GroupName")) then return obj end
    end
    return nil
end

function P.powered(sq) return sq:haveElectricity() == true or sq:hasGridPower() == true end

local function near(player, sq)
    return Payphone.near(player:getX(), player:getY(), player:getZ(), sq:getX(), sq:getY(), sq:getZ())
end

function P.dial(player, sq, text)
    local number = Sim.normalise(text)
    if not number then
        if KnoxMobile.UI.toast then KnoxMobile.UI.toast(T("IGUI_KnoxMobile_BadNumber", "That isn't a phone number"), "call") end
        return
    end
    if KnoxMobile.Client then KnoxMobile.Client.dialingPhone = nil end
    Net.toServer(player, "payphoneCall", { x = sq:getX(), y = sq:getY(), z = sq:getZ(), to = number })
end

function P.ask(player, sq)
    local w, h = 320, 140
    local box = ISTextBox:new((getCore():getScreenWidth() - w) / 2, (getCore():getScreenHeight() - h) / 2, w, h,
        T("IGUI_KnoxMobile_PayphoneDial", "Dial a number:"), "", nil, function(_, button)
            if button.internal == "OK" then P.dial(player, sq, button.parent.entry:getText()) end
        end)
    box:initialise()
    box:addToUIManager()
end

-- From the menu: walk up to the payphone first.
function P.use(player, sq)
    if near(player, sq) then return P.ask(player, sq) end
    if luautils and luautils.walkAdj then luautils.walkAdj(player, sq, true) end
    P.pending = { player = player, sq = sq, untilMs = getTimestampMs() + 15000 }
end

Tick.add("payphone walk", function()
    local p = P.pending
    if not p then return end
    if near(p.player, p.sq) then P.pending = nil; P.ask(p.player, p.sq)
    elseif getTimestampMs() > p.untilMs then P.pending = nil end
end)

Events.OnFillWorldObjectContextMenu.Add(Util.safe("payphone menu", function(playerNum, context, worldobjects, test)
    if test then return end
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    local phone
    for _, obj in ipairs(worldobjects or {}) do
        local sq = obj.getSquare and obj:getSquare()
        phone = sq and P.onSquare(sq)
        if phone then break end
    end
    if not phone then return end
    local sq = phone:getSquare()
    local root = context:addOption(T("IGUI_KnoxMobile_PayphoneUse", "Use payphone"), nil, nil)
    local m = ISContextMenu:getNew(context)
    context:addSubMenu(root, m)
    if KnoxMobile.Client and KnoxMobile.Client.payphoneCall then
        m:addOption(T("IGUI_KnoxMobile_PayphoneHangUp", "Hang up"), nil, function() KnoxMobile.Client.hangUpPayphone() end)
        return
    end
    local option = m:addOption(T("IGUI_KnoxMobile_PayphoneCall", "Call a number (%1 cents)", Payphone.priceText()), nil,
        function() P.use(player, sq) end)
    if not P.powered(sq) then
        option.notAvailable = true
        local tip = ISInventoryPaneContextMenu.addToolTip()
        tip.description = T("IGUI_KnoxMobile_callFailed_noPower", "The payphone is dead. No power.")
        option.toolTip = tip
    end
end))

return P
