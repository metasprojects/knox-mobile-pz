-- Client: StartingPhone = PickAtCreation (spec §4.4). A small window lists the phones this world allows;
-- the player picks one and the server hands it over (once per character).
require "ISUI/ISPanelJoypad"
require "ISUI/ISButton"
local Phones = require "KnoxMobile/Game/Phones"
local ItemIds = require "KnoxMobile/ItemIds"
local Util = require "KnoxMobile/Game/Util"

local T = Util.text

KnoxMobilePickerPanel = ISPanelJoypad:derive("KnoxMobilePickerPanel")
local Picker = KnoxMobilePickerPanel

local ROW_H = 44
local WIDTH = 420

function Picker:new(models)
    local h = 70 + #models * (ROW_H + 4)
    local x = (getCore():getScreenWidth() - WIDTH) / 2
    local y = math.max(20, (getCore():getScreenHeight() - h) / 2)
    local o = ISPanelJoypad.new(self, x, y, WIDTH, h)
    o.models = models
    o.moveWithMouse = true
    o.backgroundColor = { r = 0.06, g = 0.07, b = 0.09, a = 0.95 }
    o.borderColor = { r = 0.4, g = 0.6, b = 0.8, a = 1 }
    o.buttons = {}
    return o
end

function Picker:createChildren()
    for i, id in ipairs(self.models) do
        local model = Phones.registry:getPhone(id)
        if model then
            local label = string.format("%s  (%d)", model.name, model.year)
            local b = ISButton:new(60, 40 + (i - 1) * (ROW_H + 4), WIDTH - 72, ROW_H, label, self, Picker.onPick)
            b.internal = id
            b:initialise()
            b:instantiate()
            self:addChild(b)
            self.buttons[#self.buttons + 1] = b
        end
    end
end

function Picker:prerender()
    ISPanelJoypad.prerender(self)
    self:drawTextCentre(T("IGUI_KnoxMobile_PickTitle", "Pick the phone you start with"), self.width / 2, 12, 1, 1, 1, 1, UIFont.Medium)
    for i, id in ipairs(self.models) do
        -- Icons are per color (Item_KnoxMobile_<id>_<Color>); the pick hands out the first color.
        local model = Phones.registry:getPhone(id)
        local tex = model and getTexture("Item_KnoxMobile_" .. ItemIds.phone(model, model.colors[1]))
        if tex then self:drawTextureScaled(tex, 12, 40 + (i - 1) * (ROW_H + 4) + 4, 36, 36, 1, 1, 1, 1) end
    end
end

function Picker:onPick(button)
    KnoxMobile.Client.pickPhone(button.internal)
    self:removeFromUIManager()
    KnoxMobile.UI.picker = nil
end

function Picker:onJoypadDown(button)
    if button == Joypad.AButton and self.buttons[1] then self:onPick(self.buttons[self.sel or 1]) end
end

function Picker:onJoypadDirDown() self.sel = math.min(#self.buttons, (self.sel or 1) + 1) end
function Picker:onJoypadDirUp() self.sel = math.max(1, (self.sel or 1) - 1) end

function KnoxMobile.UI.showPicker(models)
    if KnoxMobile.UI.picker or #models == 0 then return end
    local p = KnoxMobilePickerPanel:new(models)
    p:initialise()
    p:addToUIManager()
    p:setAlwaysOnTop(true)
    KnoxMobile.UI.picker = p
    local player = getPlayer()
    if player and JoypadState.players[player:getPlayerNum() + 1] then setJoypadFocus(player:getPlayerNum(), p) end
end
