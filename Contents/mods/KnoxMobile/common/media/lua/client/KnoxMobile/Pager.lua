-- Client: the Motormouth Bravo pager (1993 hardware). No screen of its own: a page shows as a toast ("PAGE 5550134 911")
-- with a beep (the low-battery beep, which the server also makes into zombie noise) or a buzz; right-click the pager
-- to switch it on, pick beep or vibrate, read its last pages, or put in an AA. The server checks and saves everything.
local Mod = require "KnoxMobile/Core/Mod"
local Pager = require "KnoxMobile/Core/Pager"
local Format = require "KnoxMobile/Core/Format"
local Phones = require "KnoxMobile/Game/Phones"
local Util = require "KnoxMobile/Game/Util"
local Net = require "KnoxMobile/Game/Net"

local T = Util.text
local TYPE = "KnoxMobile.Pager"

local Pagers = {}
KnoxMobile.Pager = Pagers

local function toast(text) if KnoxMobile.UI.toast then KnoxMobile.UI.toast(text, "pager") end end

local function state(item) return Pager.normalise(item:getModData()[Phones.KEY]) end

function Pagers.setting(player, item, key, value)
    Net.toServer(player, "pagerSetting", { pagerId = item:getID(), key = key, value = value })
end

-- One line per page, newest first: "4:12 PM  5550134 911".
function Pagers.lines(st, max)
    local out = {}
    for i = #st.pages, math.max(1, #st.pages - (max or 3) + 1), -1 do
        local p = st.pages[i]
        local m = math.floor(p.minute or 0)
        local clock = Format.clock(math.floor(m / 60), Mod.floor(m, 60))
        out[#out + 1] = T("IGUI_KnoxMobile_PageEntry", "%1  %2", clock, p.body or "")
    end
    return out
end

function Pagers.read(player, item)
    local st = state(item)
    if #st.pages == 0 then toast(T("IGUI_KnoxMobile_PagerEmpty", "No pages")); return end
    for _, line in ipairs(Pagers.lines(st, 3)) do toast(T("IGUI_KnoxMobile_PageToast", "PAGE %1", line)) end
    if Pager.unread(st) > 0 then Pagers.setting(player, item, "markRead", true) end
end

local function freshBattery(player)
    return player:getInventory():getFirstEvalRecurse(function(it)
        return it:getFullType() == "Base.Battery" and it:getCurrentUsesFloat() > 0
    end)
end

Net.onClient("page", function(args)
    local player = getPlayer()
    if args.dead then toast(T("IGUI_KnoxMobile_PagerDead", "Your pager's battery is dead")); return end
    if args.alert == "vibrate" then
        getSoundManager():playUISound("KnoxMobileVibrate")
    elseif player then
        player:getEmitter():playSound("KnoxMobileLowBattery")
    end
    toast(T("IGUI_KnoxMobile_PageToast", "PAGE %1", args.body or ""))
end)

Net.onClient("pagerState", function(args)
    local player = getPlayer()
    local item = player and Phones.findById(player, args.pagerId)
    if item and args.number then
        local ok, base = pcall(getItemNameFromFullType, TYPE)
        if not ok or type(base) ~= "string" or base == "" then base = "Motormouth Bravo Pager" end
        item:setName(T("IGUI_ItemWithDisplayName", "%1: %2", base, args.number))
    end
    if args.on and args.number then toast(T("IGUI_KnoxMobile_PagerOn", "Pager on: %1", args.number)) end
end)

local function option(menu, text, fn, reason)
    local o = menu:addOption(text, nil, fn)
    if reason then
        o.notAvailable = true
        local tip = ISInventoryPaneContextMenu.addToolTip()
        tip.description = reason
        o.toolTip = tip
    end
    return o
end

Events.OnFillInventoryObjectContextMenu.Add(Util.safe("pager menu", function(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    local item = ISInventoryPane.getActualItems(items)[1]
    if not player or not item or item:getFullType() ~= TYPE then return end
    if not Phones.findById(player, item:getID()) then return end
    local st = state(item)
    local root = context:addOption(T("IGUI_KnoxMobile_PagerMenu", "Pager"), nil, nil)
    local m = ISContextMenu:getNew(context)
    context:addSubMenu(root, m)
    local info = m:addOption(st.number and T("IGUI_KnoxMobile_PagerNumberIs", "Number: %1", st.number)
        or T("IGUI_KnoxMobile_PagerNoNumber", "No number until it's switched on"), nil, nil)
    info.notAvailable = true
    local charge = m:addOption(T("IGUI_KnoxMobile_PagerBattery", "Battery: %1 percent", math.floor(st.charge + 0.5)), nil, nil)
    charge.notAvailable = true
    if st.on then
        option(m, T("IGUI_KnoxMobile_PagerOff", "Switch off"), function() Pagers.setting(player, item, "on", false) end)
    else
        option(m, T("IGUI_KnoxMobile_PagerSwitchOn", "Switch on"), function() Pagers.setting(player, item, "on", true) end,
            st.charge <= 0 and T("IGUI_KnoxMobile_PagerNeedsAA", "It needs an AA battery") or nil)
    end
    if st.alert == "vibrate" then
        option(m, T("IGUI_KnoxMobile_PagerBeep", "Alert: beep"), function() Pagers.setting(player, item, "alert", "beep") end)
    else
        option(m, T("IGUI_KnoxMobile_PagerVibrate", "Alert: vibrate"), function() Pagers.setting(player, item, "alert", "vibrate") end)
    end
    local unread = Pager.unread(st)
    option(m, unread > 0 and T("IGUI_KnoxMobile_PagerReadNew", "Read pages (%1 new)", unread)
        or T("IGUI_KnoxMobile_PagerRead", "Read pages"), function() Pagers.read(player, item) end)
    local battery = freshBattery(player)
    option(m, T("IGUI_KnoxMobile_PagerInsertAA", "Put in a fresh AA battery"),
        function() if battery then Pagers.setting(player, item, "battery", battery:getID()) end end,
        not battery and T("IGUI_KnoxMobile_PagerNoAA", "You need a battery with some charge") or nil)
end))

return Pagers
