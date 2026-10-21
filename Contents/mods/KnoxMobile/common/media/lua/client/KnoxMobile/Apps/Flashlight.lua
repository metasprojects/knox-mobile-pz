-- Client: the smartphones' flashlight (PearPhone 4, Supernova IV): the Flashlight app, the quick toggle on the
-- home screen and in the right-click menu, and the light itself.
--
-- How the light works (studied against Build 42.21's code): a held item lights the world like a vanilla torch
-- when it "emits light" (InventoryItem.isEmittingLight: light strength above 0, and activated if it can be
-- activated). The game's lighting asks every player's hands for that, local and remote players alike
-- (LightingJNI.checkLights -> IsoPlayer.getActiveLightItems). So the phone item itself becomes the torch:
--   * its item script gives the beam's shape (TorchCone, TorchDot, LightDistance: tools/gen) with no strength,
--     so a phone never shines by itself;
--   * the server owns the switch (phone state `flashlight`, command "flashlight"), drains the battery while it is
--     on (sandbox FlashlightDrain) and switches it off when the battery dies, the phone goes off or leaves the hand;
--   * every client gives a phone in someone's hand its strength while that phone's state says on. The owner sees
--     their own state; other players' copies come with the server's "re-send the hands" (sendEquip) after a change,
--     which carries the item's data. So other players see the beam too.
-- The phone is not an "activated" item: vanilla's Turn On/Off menu and equip auto-on never touch it.
local Phones = require "KnoxMobile/Game/Phones"
local Net = require "KnoxMobile/Game/Net"
local Util = require "KnoxMobile/Game/Util"

local T = Util.text
local ICONS = "media/ui/KnoxMobile/apps/"
local SMART = { ModernAndroid = true, ModernPear = true }
local CHECK_MS = 200
local ASK_MS = 2000 -- ask the server to switch off at most this often per phone

local Flashlight = { STRENGTH = 1.2, DISTANCE = 9, wanted = {}, asked = {}, nextCheck = 0 }
KnoxMobile.Flashlight = Flashlight

function Flashlight.supports(item)
    local model = item and Phones.model(item)
    return model ~= nil and SMART[model.family] == true
end

local function works(state)
    return state ~= nil and state.power.on and state.battery.charge > 0 and state.condition ~= "broken"
end
Flashlight.works = works

-- A switch flipped here in the last few seconds (the server hasn't answered yet), or nil.
local function pending(id)
    local w = Flashlight.wanted[id]
    if w and getTimestampMs() - w.at < 3000 then return w end
    Flashlight.wanted[id] = nil
    return nil
end

-- On, as far as this client knows: a switch just flipped here counts before the server confirms it.
function Flashlight.isOn(item)
    local w = pending(item:getID())
    if w then return w.on end
    local state = Phones.get(item)
    return state ~= nil and state.flashlight == true
end

function Flashlight.request(player, item, on)
    Flashlight.wanted[item:getID()] = { on = on, at = getTimestampMs() }
    Net.toServer(player, "flashlight", { phoneId = item:getID(), on = on })
    Flashlight.nextCheck = 0
end

-- The quick toggle (home screen, app, right-click). The light shines from the hand, so switching it on raises
-- the phone; switching it off with the phone put away lowers it again.
function Flashlight.toggle(player, item)
    if not Flashlight.supports(item) then return end
    local on = not Flashlight.isOn(item)
    if on and not works(Phones.get(item)) then
        if KnoxMobile.Client then KnoxMobile.Client.toast(T("IGUI_KnoxMobile_TorchNeedsPower", "The phone has to be on")) end
        return
    end
    getSoundManager():playUISound("KnoxMobileButton")
    if on and not player:isEquipped(item) and KnoxMobile.Hold then KnoxMobile.Hold.raise(player, item) end
    Flashlight.request(player, item, on)
    local open = KnoxMobile.UI and KnoxMobile.UI.panel and KnoxMobile.UI.panel.item == item
    if not on and not open and player:isEquipped(item) and KnoxMobile.Hold then KnoxMobile.Hold.lower(player, item) end
end

-- Light strength on one copy of a phone (0 = dark).
local function shine(item, on)
    local want = on and Flashlight.STRENGTH or 0
    if math.abs(item:getLightStrength() - want) > 0.001 then
        item:setLightStrength(want)
        if on then
            item:setLightDistance(Flashlight.DISTANCE)
            item:setTorchCone(true)
        end
    end
end
Flashlight.shine = shine

local function handPhones(player)
    local out = {}
    local primary, secondary = player:getPrimaryHandItem(), player:getSecondaryHandItem()
    if primary and Flashlight.supports(primary) then out[#out + 1] = primary end
    if secondary and secondary ~= primary and Flashlight.supports(secondary) then out[#out + 1] = secondary end
    return out
end

local function askOff(player, item)
    local id = item:getID()
    local t = getTimestampMs()
    if t - (Flashlight.asked[id] or 0) < ASK_MS then return end
    Flashlight.asked[id] = t
    Net.toServer(player, "flashlight", { phoneId = id, on = false })
end

-- Our own phones: shine while on and working; a phone that died, went off or left the hand switches off.
local function checkLocal(player)
    for _, item in ipairs(handPhones(player)) do
        local state = Phones.get(item)
        local on = Flashlight.isOn(item) and works(state)
        shine(item, on)
        if state and state.flashlight and not works(state) then askOff(player, item) end
    end
    for _, item in ipairs(Phones.inventoryPhones(player)) do
        local state = Phones.get(item)
        if state and state.flashlight and not player:isEquipped(item) and not pending(item:getID()) then
            askOff(player, item)
            shine(item, false)
        end
    end
end

-- Other players' phones in hand (multiplayer): their copies carry the owner's phone state.
local function checkRemote()
    local list = getOnlinePlayers()
    for i = 0, list:size() - 1 do
        local p = list:get(i)
        if p and not p:isLocalPlayer() then
            for _, item in ipairs(handPhones(p)) do
                local state = Phones.get(item)
                shine(item, state ~= nil and state.flashlight == true and works(state))
            end
        end
    end
end

Events.OnTick.Add(Util.safe("flashlight", function()
    local t = getTimestampMs()
    if t < Flashlight.nextCheck then return end
    Flashlight.nextCheck = t + CHECK_MS
    for _, player in ipairs(Util.players()) do
        if not player:isDead() then checkLocal(player) end
    end
    if isClient() then checkRemote() end
end))

-- Server replies -------------------------------------------------------------------------------------
Net.onClient("flashlightResult", function(args)
    if args.phoneId then Flashlight.wanted[args.phoneId] = nil end
    if args.reason == "noPower" and KnoxMobile.Client then
        KnoxMobile.Client.toast(T("IGUI_KnoxMobile_TorchNeedsPower", "The phone has to be on"))
    end
    Flashlight.nextCheck = 0
end)

-- The app: one big switch -----------------------------------------------------------------------------
KnoxMobile.Apps.register({
    id = "flashlight", name = "Flashlight", icon = ICONS .. "flashlight.png", glyph = ICONS .. "flashlight_glyph.png",
    label = function() return T("IGUI_KnoxMobile_AppFlashlight", "Flashlight") end,
    short = function() return T("IGUI_KnoxMobile_AppShortFlashlight", "Light") end,
    families = { "ModernAndroid", "ModernPear" }, drain = "screen", needsService = false, order = 70,
    render = function(ctx, x, y, w, h)
        local on = Flashlight.isOn(ctx.phone)
        local lh = ctx:lineHeight()
        ctx:rect(x, y, w, h, on and { 0.16, 0.14, 0.08 } or { 0.03, 0.03, 0.05 })
        -- A round-ish switch in the middle, glowing when on.
        local s = math.floor(math.min(w * 0.5, h * 0.4))
        local sx, sy = x + math.floor((w - s) / 2), y + math.floor(h * 0.36 - s / 2)
        if on then
            for k = 3, 1, -1 do
                local g = k * math.floor(s / 10)
                ctx:rect(sx - g, sy - g, s + 2 * g, s + 2 * g, { 1, 0.85, 0.4 }, 0.08)
            end
        end
        ctx:rect(sx, sy, s, s, on and { 1, 0.86, 0.38 } or { 0.2, 0.21, 0.25 })
        ctx:border(sx, sy, s, s, { 1, 1, 1 }, on and 0.9 or 0.35)
        local glyph = getTexture(ICONS .. "flashlight_glyph.png")
        if glyph then
            local gs = math.floor(s * 0.7)
            local ink = on and { 0.2, 0.15, 0.05 } or { 0.85, 0.87, 0.92 }
            ctx.panel:drawTextureScaled(glyph, ctx.sx + sx + math.floor((s - gs) / 2), ctx.sy + sy + math.floor((s - gs) / 2), gs, gs,
                1, ink[1], ink[2], ink[3])
        end
        ctx:text(on and T("IGUI_KnoxMobile_TorchOn", "Flashlight on") or T("IGUI_KnoxMobile_TorchOff", "Flashlight off"),
            x + w / 2, sy + s + 10, on and { 1, 0.9, 0.55 } or { 0.85, 0.87, 0.92 }, UIFont.Medium, "center")
        local hint = T("IGUI_KnoxMobile_TorchHint", "Tap to switch. It stays lit in your hand when you close the phone.")
        local cy = sy + s + 14 + KnoxMobile.UI.fontH(UIFont.Medium)
        for _, l in ipairs(ctx:wrap(hint, w - 12)) do
            if cy + lh > y + h then break end
            ctx:text(l, x + w / 2, cy, { 0.6, 0.63, 0.7 }, nil, "center")
            cy = cy + lh
        end
    end,
    onInput = function(ctx, ev)
        if (ev.type == "key" and ev.key == "select") or ev.type == "tap" then Flashlight.toggle(ctx.player, ctx.phone) end
        return true
    end,
})

-- Right-click a smartphone: switch its flashlight without opening it.
Events.OnFillInventoryObjectContextMenu.Add(Util.safe("flashlight menu", function(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    local actual = ISInventoryPane.getActualItems(items)
    local item = actual[1]
    if not player or not item or not Flashlight.supports(item) then return end
    if not Phones.findById(player, item:getID()) then return end
    local on = Flashlight.isOn(item)
    local text = on and T("IGUI_KnoxMobile_MenuTorchOff", "Flashlight off") or T("IGUI_KnoxMobile_MenuTorchOn", "Flashlight on")
    context:addOption(text, nil, function() Flashlight.toggle(player, item) end)
end))

return Flashlight
