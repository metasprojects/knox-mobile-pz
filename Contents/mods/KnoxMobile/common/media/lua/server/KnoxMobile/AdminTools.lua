-- Server: admin tools (after 0.3.0). For server admins (Util.debugAllowed: admin access, or debug mode): hand a working
-- phone to any online player (a phone of the model asked for, a blank SIM and a charger that fits it). The admin menu
-- (client/KnoxMobile/Admin.lua; named apart so the two never share a module path) also texts every phone
-- (CarrierBroadcast) and sets the towers (Server.lua "debug").
local Protocol = require "KnoxMobile/Core/Protocol"
local ItemIds = require "KnoxMobile/ItemIds"
local Phones = require "KnoxMobile/Game/Phones"
local Util = require "KnoxMobile/Game/Util"
local Net = require "KnoxMobile/Game/Net"

local Admin = {}
KnoxMobile.Admin = Admin

Protocol.register({ adminGivePhone = function(args)
    if type(args.target) ~= "string" or type(args.model) ~= "string" then return false, "target and model" end
    return true
end })

local function add(player, fullType, setup)
    local inv = player:getInventory()
    local item = inv:AddItem(fullType)
    if item then
        if setup then setup(item) end
        if isServer() then sendAddItemToContainer(inv, item) end
    end
    return item
end

-- Online players by name, for the menu and the target: the account name on a server, the character in single player.
function Admin.nameOf(p)
    local ok, name = pcall(function() return p:getUsername() end)
    if ok and type(name) == "string" and name ~= "" then return name end
    local ok2, fore = pcall(function() return p:getDescriptor():getForename() end)
    return ok2 and tostring(fore) or "?"
end

function Admin.givePhone(target, model)
    local phone = add(target, ItemIds.full(ItemIds.phone(model, model.colors[1])), function(it)
        it:getModData().KnoxMobileOrigin = "newInBox"
        local st = Phones.get(it)
        if st then st.condition, st.battery.charge = "mint", 100 end
    end)
    add(target, "KnoxMobile.SimCard")
    if model.connector == "Pin" or model.connector == "Flat" then add(target, "KnoxMobile.WallCharger" .. model.connector)
    elseif model.connector then add(target, "KnoxMobile.Cable" .. model.connector) end
    return phone
end

Net.onServer("adminGivePhone", function(player, args)
    if not Util.debugAllowed(player) then return end
    local model = Phones.registry:getPhone(args.model)
    if not model then return end
    for _, p in ipairs(Util.players()) do
        if Admin.nameOf(p) == args.target then
            Admin.givePhone(p, model)
            Util.log("admin", Admin.nameOf(player), "gave a", model.id, "to", args.target)
            Net.toClient(p, "notify", { kind = "admin", event = "gotPhone", number = model.name })
            if p ~= player then Net.toClient(player, "notify", { kind = "admin", event = "gave", number = args.target }) end
            return
        end
    end
end)

return Admin
