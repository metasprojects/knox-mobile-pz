-- Client: right-click menus for phones, SIMs, boxes, manuals, chargers and repeaters (spec §4.5, §6, §7.3,
-- §8.1, §9.3-§9.5). Every change runs as a KnoxMobileAction so it is checked and saved by the server.
local Phones = require "KnoxMobile/Game/Phones"
local Util = require "KnoxMobile/Game/Util"
local Net = require "KnoxMobile/Game/Net"

local T = Util.text

local function queue(player, kind, item, other, extra)
    ISInventoryPaneContextMenu.transferIfNeeded(player, item)
    if other then ISInventoryPaneContextMenu.transferIfNeeded(player, other) end
    KnoxMobileAction.queue(player, kind, item, other, extra)
end

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

local function sub(context, text)
    local root = context:addOption(text, nil, nil)
    local menu = ISContextMenu:getNew(context)
    context:addSubMenu(root, menu)
    return menu
end

local function findAll(player, pred)
    local out = {}
    local list = player:getInventory():getAllEvalRecurse(pred)
    for i = 0, list:size() - 1 do out[#out + 1] = list:get(i) end
    return out
end

local function first(player, fullType)
    return player:getInventory():getFirstTypeRecurse(fullType)
end

local function hasScrewdriver(player) return Phones.hasScrewdriver(player) end

local function phoneMenu(player, context, item)
    local state, model = Phones.get(item)
    if not state then return end
    context:addOption(T("IGUI_KnoxMobile_UsePhone", "Use phone"), nil, function() KnoxMobile.UI.open(player, item) end)
    local m = sub(context, model.name)

    if state.power.on then
        option(m, T("IGUI_KnoxMobile_PowerOff", "Power off"), function() queue(player, "powerOff", item) end)
    else
        local why = nil
        if state.condition == "broken" then why = T("IGUI_KnoxMobile_WhyBroken", "It's broken")
        elseif state.rice then why = T("IGUI_KnoxMobile_WhyRice", "It's in rice") end
        option(m, T("IGUI_KnoxMobile_PowerOn", "Power on"), function() queue(player, "powerOn", item) end, why)
    end

    -- SIM cards.
    if state.sim then
        local label = state.sim.number and T("IGUI_KnoxMobile_EjectSimNumber", "Remove SIM: %1", state.sim.number)
            or T("IGUI_KnoxMobile_EjectBlankSim", "Remove blank SIM")
        option(m, label, function() queue(player, "ejectSim", item) end)
    else
        local sims = findAll(player, function(it) return Phones.isSim(it) end)
        if #sims == 0 then
            option(m, T("IGUI_KnoxMobile_InsertSim", "Insert SIM"), nil, T("IGUI_KnoxMobile_NeedSim", "You need a SIM card"))
        else
            local sm = sub(m, T("IGUI_KnoxMobile_InsertSim", "Insert SIM"))
            local blanks = 0
            for _, sim in ipairs(sims) do
                local data = sim:getModData()[Phones.KEY]
                local label = data and data.number
                -- Blank SIMs are numbered so the list doesn't read "blank SIM" three times (r8).
                if not label then
                    blanks = blanks + 1
                    label = T("IGUI_KnoxMobile_BlankSimN", "blank SIM %1", blanks)
                end
                option(sm, label, function() queue(player, "insertSim", item, sim) end)
            end
        end
    end

    -- Charging.
    if state.plug then
        option(m, T("IGUI_KnoxMobile_UnplugFrom", "Unplug from %1", Util.word("Source", state.plug.source)),
            function() queue(player, "unplug", item) end)
    else
        option(m, T("IGUI_KnoxMobile_Plug", "Plug in to charge"), function() queue(player, "plug", item) end)
    end
    local here = player:getCurrentSquare()
    option(m, T("IGUI_KnoxMobile_LeaveCharging", "Leave it here charging"), function() queue(player, "leaveCharging", item) end,
        not (here and Util.powered(here)) and T("IGUI_KnoxMobile_NeedPower", "There's no power here") or nil)
    local crank = first(player, "KnoxMobile.CrankCharger")
    if crank then option(m, T("IGUI_KnoxMobile_Crank", "Crank to charge"), function() queue(player, "crank", item, crank) end) end
    if model.removableBattery then
        local spares = findAll(player, function(it)
            local a = Phones.accessory(it)
            return a ~= nil and a.kind == "spareBattery" and a.family == model.family
        end)
        if #spares > 0 then
            option(m, T("IGUI_KnoxMobile_SwapBattery", "Swap battery"), function() queue(player, "swapBattery", item, spares[1]) end)
        end
    end

    -- Protection.
    if state.wrapped then
        option(m, T("IGUI_KnoxMobile_Unwrap", "Unwrap plastic bag"), function() queue(player, "unwrap", item) end)
    else
        local bag = first(player, "Base.Plasticbag")
        option(m, T("IGUI_KnoxMobile_Wrap", "Wrap in plastic bag"), function() queue(player, "wrap", item, bag) end,
            not bag and T("IGUI_KnoxMobile_NeedBag", "You need a plastic bag") or nil)
    end
    if state.look.case then
        option(m, T("IGUI_KnoxMobile_RemoveCase", "Remove case"), function() queue(player, "removeCase", item) end)
    else
        local cases = findAll(player, function(it)
            local a = Phones.accessory(it)
            return a ~= nil and a.kind == "case" and a.caseSize == model.caseSize
        end)
        if #cases > 0 then
            local cm = sub(m, T("IGUI_KnoxMobile_FitCase", "Fit case"))
            for _, c in ipairs(cases) do option(cm, c:getDisplayName(), function() queue(player, "fitCase", item, c) end) end
        end
    end
    if not state.look.protector then
        local prot = first(player, "KnoxMobile.ScreenProtector")
        if prot then
            option(m, T("IGUI_KnoxMobile_FitProtector", "Fit screen protector"), function() queue(player, "fitProtector", item, prot) end)
        end
    end

    -- Repairs need a screwdriver and the phone off.
    local rm = sub(m, T("IGUI_KnoxMobile_Repair", "Repair"))
    local why = nil
    if not hasScrewdriver(player) then why = T("IGUI_KnoxMobile_NeedScrewdriver", "You need a screwdriver")
    elseif state.power.on then why = T("IGUI_KnoxMobile_TurnOff", "Turn it off first") end
    local screen = first(player, "KnoxMobile.PhoneScreen")
    local cell = first(player, "KnoxMobile.PhoneBattery")
    option(rm, T("IGUI_KnoxMobile_RepairScreen", "Replace screen"), function() queue(player, "repair", item, screen, "screen") end,
        why or (not screen and T("IGUI_KnoxMobile_NeedScreen", "You need a phone screen")) or nil)
    option(rm, T("IGUI_KnoxMobile_RepairBattery", "Replace battery cell"), function() queue(player, "repair", item, cell, "battery") end,
        why or (not cell and T("IGUI_KnoxMobile_NeedCell", "You need a phone battery cell")) or nil)
    option(rm, T("IGUI_KnoxMobile_RepairWater", "Open up and dry the insides"), function() queue(player, "repair", item, nil, "water") end,
        why or (state.wetness == "dry" and T("IGUI_KnoxMobile_NotWet", "It isn't wet")) or nil)
    -- Scrapping destroys the phone, so it sits on its own, not among the repairs.
    option(m, T("IGUI_KnoxMobile_Scrap", "Scrap for parts"), function() queue(player, "scrap", item) end, why)

    -- Rice.
    if state.rice then
        option(m, T("IGUI_KnoxMobile_RiceOut", "Take out of rice"), function() queue(player, "riceOut", item) end)
    elseif state.wetness ~= "dry" then
        local rice = first(player, "Base.Rice")
        option(m, T("IGUI_KnoxMobile_RiceIn", "Bury in rice"), function() queue(player, "riceIn", item, rice) end,
            not rice and T("IGUI_KnoxMobile_NeedRice", "You need a bag of rice") or nil)
    end

    -- Somebody else's locked phone (not one of yours: you know its PIN).
    if state.security.locked and state.power.on and not (state.owner and state.owner.kind == "player") then
        option(m, T("IGUI_KnoxMobile_CrackPin", "Try to crack the PIN"), function() queue(player, "crackPin", item) end)
    end
    -- A dead owner's phone you got into: make it yours (spec §5.1).
    if state.owner.kind == "generated" and not state.security.locked and state.power.on then
        option(m, T("IGUI_KnoxMobile_Wipe", "Wipe and set up as yours"), function() queue(player, "wipe", item) end)
    end
end

local function bankMenu(player, context, item)
    if item:getModData().KnoxMobileBankPlug then
        context:addOption(T("IGUI_KnoxMobile_UnplugBank", "Unplug power bank"), nil, function() queue(player, "unplugBank", item) end)
        return
    end
    local why = nil
    local sq = player:getCurrentSquare()
    if not player:getInventory():containsTypeRecurse("KnoxMobile.UsbWallAdapter") then
        why = T("IGUI_KnoxMobile_NeedAdapter", "You need a USB wall adapter")
    elseif not (sq and Util.powered(sq)) then
        why = T("IGUI_KnoxMobile_NeedPower", "There's no power here")
    end
    option(context, T("IGUI_KnoxMobile_PlugBank", "Charge power bank at the wall"), function() queue(player, "plugBank", item) end, why)
end

Events.OnFillInventoryObjectContextMenu.Add(Util.safe("phone menu", function(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    local actual = ISInventoryPane.getActualItems(items)
    local item = actual[1]
    if not item or not player then return end
    if Phones.isPhone(item) then
        phoneMenu(player, context, item)
    elseif Phones.isBox(item) then
        context:addOption(T("IGUI_KnoxMobile_OpenBox", "Open box"), nil, function() queue(player, "openBox", item) end)
    elseif Phones.manualFamily(item) then
        context:addOption(T("IGUI_KnoxMobile_ReadManual", "Read manual"), nil, function() queue(player, "readManual", item) end)
    elseif item:getFullType() == "KnoxMobile.Repeater" then
        local text = T("IGUI_KnoxMobile_PlaceRepeater", "Place repeater here")
        context:addOption(text, nil, function() queue(player, "placeRepeater", item) end)
    elseif item:getFullType() == "KnoxMobile.PowerBank" then
        bankMenu(player, context, item)
    elseif Phones.isSim(item) then
        local data = item:getModData()[Phones.KEY]
        local o = context:addOption(data and data.number and T("IGUI_KnoxMobile_SimNumber", "SIM number: %1", data.number)
            or T("IGUI_KnoxMobile_BlankSim", "blank SIM"), nil, nil)
        o.notAvailable = true
    end
end))

-- Placed repeaters: right-click the ground next to one (spec §7.3) ------------------------------------
local function askText(title, onText)
    local w, h = 300, 140
    local box = ISTextBox:new((getCore():getScreenWidth() - w) / 2, (getCore():getScreenHeight() - h) / 2, w, h, title, "", nil,
        function(_, button)
            if button.internal == "OK" then
                local text = button.parent.entry:getText()
                if text and text ~= "" then onText(text:sub(1, 32)) end
            end
        end)
    box:initialise()
    box:addToUIManager()
end

local function repeaterStatus(rep)
    if (rep.condition or 100) <= 0 then return T("IGUI_KnoxMobile_RepWorn", "worn out") end
    if not rep.powered then return T("IGUI_KnoxMobile_RepNoPower", "no power") end
    if rep.grid then return T("IGUI_KnoxMobile_RepGridPowered", "powered") end
    return T("IGUI_KnoxMobile_RepBattery", "on car battery, %1 h left", math.floor(rep.battery or 0))
end

local function placedRepeaters(worldobjects)
    local out, seenSquares = {}, {}
    for _, obj in ipairs(worldobjects) do
        local sq = obj.getSquare and obj:getSquare()
        if sq and not seenSquares[sq] then
            seenSquares[sq] = true
            local list = sq:getWorldObjects()
            for i = 0, list:size() - 1 do
                local item = list:get(i):getItem()
                if item and item:getFullType() == "KnoxMobile.Repeater" then
                    local id = item:getModData().KnoxMobileRepeaterId
                    for _, rep in ipairs(KnoxMobile.world.repeaters or {}) do
                        if rep.id == id then out[#out + 1] = rep end
                    end
                end
            end
        end
    end
    return out
end

local function repeaterMenu(player, context, rep)
    local m = sub(context, T("IGUI_KnoxMobile_RepTitleNumber", "Cell Repeater R%1 (%2)", (tostring(rep.id):gsub("^R", "")),
        repeaterStatus(rep)))
    local info = m:addOption(T("IGUI_KnoxMobile_RepCondition", "Condition %1 / 100", math.floor(rep.condition or 100)), nil, nil)
    info.notAvailable = true
    local mine = rep.owner == Util.playerKey(player)
    if mine and Util.settings().AllowPrivateRepeaters then
        if rep.private then
            option(m, T("IGUI_KnoxMobile_RepOpen", "Make it open to everyone"), function()
                Net.toServer(player, "configureRepeater", { id = rep.id, private = false })
            end)
        else
            option(m, T("IGUI_KnoxMobile_RepPrivate", "Make it private (set a password)"), function()
                askText(T("IGUI_KnoxMobile_RepPassword", "Network password"), function(pw)
                    Net.toServer(player, "configureRepeater", { id = rep.id, private = true, password = pw })
                end)
            end)
        end
    elseif rep.private then
        option(m, T("IGUI_KnoxMobile_RepJoin", "Enter the network password"), function()
            askText(T("IGUI_KnoxMobile_RepPassword", "Network password"), function(pw)
                Net.toServer(player, "joinRepeater", { password = pw })
            end)
        end)
    end
    if (rep.battery or 0) > 0 or rep.batteryType then
        option(m, T("IGUI_KnoxMobile_RepDetach", "Take off the car battery"), function()
            Net.toServer(player, "repeaterBattery", { id = rep.id, attach = false })
        end)
    else
        local battery = player:getInventory():getFirstEvalRecurse(function(it)
            return tostring(it:getFullType()):find("^Base%.CarBattery") ~= nil and it:getCurrentUsesFloat() > 0.01
        end)
        option(m, T("IGUI_KnoxMobile_RepAttach", "Attach a car battery"), function()
            Net.toServer(player, "repeaterBattery", { id = rep.id, attach = true, itemId = battery:getID() })
        end, not battery and T("IGUI_KnoxMobile_NeedCarBattery", "You need a charged car battery") or nil)
    end
    local why = nil
    if not player:getInventory():containsTypeRecurse("Base.ElectronicsScrap") then
        why = T("IGUI_KnoxMobile_NeedScrap", "You need electronics scrap")
    elseif not hasScrewdriver(player) then
        why = T("IGUI_KnoxMobile_NeedScrewdriver", "You need a screwdriver")
    end
    option(m, T("IGUI_KnoxMobile_RepMaintain", "Service it"), function()
        Net.toServer(player, "maintainRepeater", { id = rep.id })
    end, why)
end

Events.OnFillWorldObjectContextMenu.Add(Util.safe("repeater menu", function(playerNum, context, worldobjects, test)
    if test then return end
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    for _, rep in ipairs(placedRepeaters(worldobjects)) do repeaterMenu(player, context, rep) end
end))