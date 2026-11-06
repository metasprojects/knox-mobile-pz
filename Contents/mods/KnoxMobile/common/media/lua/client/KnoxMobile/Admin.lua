-- Client: the admin menu (after 0.3.0). Server admins right-click the world: Knox Mobile admin > text every phone,
-- the towers (all on air, all dead, back to normal), network congestion, and give a phone to any online player
-- (server/Admin.lua). The server checks every request again. In single player the debug menu has all of this.
local Util = require "KnoxMobile/Game/Util"
local Net = require "KnoxMobile/Game/Net"
local Phones = require "KnoxMobile/Game/Phones"

local T = Util.text

local function sub(menu, text)
    local root = menu:addOption(text, nil, nil)
    local m = ISContextMenu:getNew(menu)
    menu:addSubMenu(root, m)
    return m
end

local function nameOf(p)
    local ok, name = pcall(function() return p:getUsername() end)
    if ok and type(name) == "string" and name ~= "" then return name end
    local ok2, fore = pcall(function() return p:getDescriptor():getForename() end)
    return ok2 and tostring(fore) or "?"
end

local function onlinePlayers()
    local out = {}
    local list = getOnlinePlayers and getOnlinePlayers()
    if list then
        for i = 0, list:size() - 1 do out[#out + 1] = list:get(i) end
    else
        out[1] = getSpecificPlayer(0)
    end
    return out
end

Events.OnFillWorldObjectContextMenu.Add(Util.safe("admin menu", function(playerNum, context, _, test)
    if test or not (isClient() or isServer()) then return end
    local player = getSpecificPlayer(playerNum)
    if not (player and Util.debugAllowed(player)) then return end
    local m = sub(context, T("IGUI_KnoxMobile_AdminMenu", "Knox Mobile admin"))
    m:addOption(T("IGUI_KnoxMobile_AdminText", "Text every phone (from KNOX MOBILE)"), nil, function()
        if KnoxMobile.Social and KnoxMobile.Social.askBroadcast then KnoxMobile.Social.askBroadcast() end
    end)
    local towers = sub(m, T("IGUI_KnoxMobile_AdminTowers", "Towers"))
    towers:addOption(T("IGUI_KnoxMobile_AdminTowersAlive", "Every tower on the air"), nil,
        function() Net.toServer(player, "debug", { action = "towers", mode = "alive" }) end)
    towers:addOption(T("IGUI_KnoxMobile_AdminTowersDead", "Every tower dead"), nil,
        function() Net.toServer(player, "debug", { action = "towers", mode = "dead" }) end)
    towers:addOption(T("IGUI_KnoxMobile_AdminTowersNormal", "Back to normal (the sandbox's timeline)"), nil,
        function() Net.toServer(player, "debug", { action = "towers", mode = "normal" }) end)
    m:addOption(T("IGUI_KnoxMobile_AdminCongestion", "Network congestion on/off until restart"), nil,
        function() Net.toServer(player, "debug", { action = "congestion" }) end)
    local give = sub(m, T("IGUI_KnoxMobile_AdminGive", "Give a phone to"))
    for _, p in ipairs(onlinePlayers()) do
        local who = nameOf(p)
        local models = sub(give, who)
        for _, model in ipairs(Phones.registry:phones()) do
            if not model.hidden then
                models:addOption(model.name, nil, function()
                    Net.toServer(player, "adminGivePhone", { target = who, model = model.id })
                end)
            end
        end
    end
end))
