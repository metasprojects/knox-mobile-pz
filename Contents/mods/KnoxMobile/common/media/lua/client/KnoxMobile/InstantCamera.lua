-- Client: the Pollux 600 instant camera (0.3.0, Core/Instant). Right-click it: Take a photo opens the viewfinder (a
-- window with the square live view; click to take the photo, right-click to put the camera away), Load film puts a
-- pack in. The photo slides out into your bags (server/InstantPrints.lua); right-click it to look at it. With the Java
-- part the viewfinder is live and the photo is the real picture (Camera.lua does the capture, as for phones); without
-- it the viewfinder is dark and the photo is its caption.
local Instant = require "KnoxMobile/Core/Instant"
local Util = require "KnoxMobile/Game/Util"
local Net = require "KnoxMobile/Game/Net"
require "KnoxMobile/Camera"

local T = Util.text
local State = { viewfinder = nil, viewer = nil }
KnoxMobile.Instant = State

local function toast(text) if KnoxMobile.Client then KnoxMobile.Client.toast(text) end end
local function camera() return KnoxMobile.Camera end
local function live() return camera() ~= nil and camera().available() end

local function fontH() return getTextManager():getFontHeight(UIFont.Small) end

local function wrap(text, width)
    local tm, lines, line = getTextManager(), {}, ""
    for word in tostring(text):gmatch("%S+") do
        local try = line == "" and word or (line .. " " .. word)
        if line == "" or tm:MeasureStringX(UIFont.Small, try) <= width then line = try
        else lines[#lines + 1] = line; line = word end
    end
    if line ~= "" then lines[#lines + 1] = line end
    return lines
end

local function carried(player, item)
    return item ~= nil and player:getInventory():getItemWithIDRecursiv(item:getID()) ~= nil
end

-- The viewfinder -----------------------------------------------------------------------------------------
local VF_W, VF_H, PAD = 340, 400, 14
KnoxMobileInstantViewfinder = ISPanelJoypad:derive("KnoxMobileInstantViewfinder")
local Viewfinder = KnoxMobileInstantViewfinder

function Viewfinder:new(player, item)
    local x = (getCore():getScreenWidth() - VF_W) / 2
    local o = ISPanelJoypad.new(self, x, math.max(40, (getCore():getScreenHeight() - VF_H) / 2 - 60), VF_W, VF_H)
    o.player, o.camera = player, item
    o.backgroundColor = { r = 0.12, g = 0.12, b = 0.13, a = 0.95 }
    o.borderColor = { r = 0.6, g = 0.6, b = 0.6, a = 1 }
    o.moveWithMouse = true
    return o
end

function Viewfinder:prerender()
    ISPanelJoypad.prerender(self)
    if not carried(self.player, self.camera) or self.player:isDead() then self:close(); return end
    local side = VF_W - PAD * 2
    local fx, fy = PAD, PAD + fontH() + 4
    self:drawText(T("IGUI_KnoxMobile_InstantTitle", "Pollux 600"), PAD, 6, 0.9, 0.9, 0.85, 1, UIFont.Small)
    self:drawRect(fx, fy, side, side, 1, 0.02, 0.02, 0.02)
    local C = camera()
    if live() then
        C.request(Instant.SPEC)
        local tex = knoxLiveCameraTexture()
        if tex then self:drawTextureScaled(tex, fx, fy, side, side, 1, 1, 1, 1) end
        local blocked = C.blocked()
        if blocked then
            self:drawRect(fx, fy, side, side, 0.6, 0, 0, 0)
            local lines = wrap(blocked, side - 20)
            local ty = fy + math.floor((side - #lines * fontH()) / 2)
            for i, l in ipairs(lines) do self:drawTextCentre(l, fx + side / 2, ty + (i - 1) * fontH(), 1, 1, 1, 1, UIFont.Small) end
        end
    else
        local lines = wrap(T("IGUI_KnoxMobile_InstantNoLive",
            "No live view without the live screen add-on (ZombieBuddy). The photo will be what you saw, in words."), side - 30)
        local ty = fy + math.floor((side - #lines * fontH()) / 2)
        for i, l in ipairs(lines) do self:drawTextCentre(l, fx + side / 2, ty + (i - 1) * fontH(), 0.7, 0.7, 0.7, 1, UIFont.Small) end
    end
    if self.flashUntil and getTimestampMs() < self.flashUntil then self:drawRect(fx, fy, side, side, 0.85, 1, 1, 1) end
    local left = Instant.shots(self.camera:getModData())
    local foot = left > 0 and T("IGUI_KnoxMobile_InstantHint", "Click: take the photo (%1 left). Right-click: put it away", left)
        or T("IGUI_KnoxMobile_InstantEmpty", "Out of film. Right-click: put it away")
    local lines = wrap(foot, VF_W - PAD * 2)
    for i, l in ipairs(lines) do self:drawText(l, PAD, fy + side + 6 + (i - 1) * fontH(), 0.8, 0.8, 0.75, 1, UIFont.Small) end
end

function Viewfinder:shoot()
    local player, item = self.player, self.camera
    if Instant.shots(item:getModData()) <= 0 then toast(T("IGUI_KnoxMobile_instant_empty", "Out of film")); return end
    local C = camera()
    local id, caption
    if live() then
        local blocked = C.blocked()
        if blocked then toast(blocked); return end
        id, _, caption = C.shoot(player, item, Instant.SPEC, { instant = true })
    else
        caption = C and C.caption(player) or ""
        pcall(function() getSoundManager():playUISound("KnoxMobileButton") end)
    end
    local name = T("IGUI_KnoxMobile_InstantPhotoName", "Photo: %1", caption)
    Net.toServer(player, "instantShot", { cameraId = item:getID(), id = id, caption = caption, name = name })
    self.flashUntil = getTimestampMs() + 150
end

function Viewfinder:close()
    self:removeFromUIManager()
    if State.viewfinder == self then State.viewfinder = nil end
end

function Viewfinder:onMouseDown() self:shoot(); return true end
function Viewfinder:onRightMouseDown() self:close(); return true end
function Viewfinder:onJoypadDown(button)
    if button == Joypad.AButton then self:shoot() elseif button == Joypad.BButton then self:close() end
end

function State.open(player, item)
    if State.viewfinder then State.viewfinder:close() end
    local p = Viewfinder:new(player, item)
    p:initialise()
    p:addToUIManager()
    p:setAlwaysOnTop(true)
    State.viewfinder = p
    if JoypadState and JoypadState.players[player:getPlayerNum() + 1] then setJoypadFocus(player:getPlayerNum(), p) end
    return p
end

-- A printed photo ----------------------------------------------------------------------------------------
local PH_W, PH_H = 300, 360
KnoxMobileInstantPhotoPanel = ISPanelJoypad:derive("KnoxMobileInstantPhotoPanel")
local Photo = KnoxMobileInstantPhotoPanel

function Photo:new(player, item)
    local x = (getCore():getScreenWidth() - PH_W) / 2
    local o = ISPanelJoypad.new(self, x, math.max(40, (getCore():getScreenHeight() - PH_H) / 2 - 60), PH_W, PH_H)
    o.player, o.item = player, item
    o.backgroundColor = { r = 0.95, g = 0.94, b = 0.9, a = 1 } -- the white border of instant film
    o.borderColor = { r = 0.7, g = 0.7, b = 0.65, a = 1 }
    o.moveWithMouse = true
    return o
end

-- One photo's picture in a square at x, y on a panel: the real picture with the Java part, else its caption. The
-- photo board (PhotoBoard.lua) draws its pinned photos with this too.
function State.drawPhoto(panel, data, x, y, side)
    panel:drawRect(x, y, side, side, 1, 0.16, 0.14, 0.12)
    local tex = nil
    if data.id and live() then
        camera().ensure(panel.player, data.id)
        tex = knoxLivePhotoTexture(data.id)
    end
    if tex then
        panel:drawTextureScaled(tex, x, y, side, side, 1, 1, 1, 1)
    elseif data.id and live() then
        panel:drawTextCentre(T("IGUI_KnoxMobile_InstantDeveloping", "Developing..."), x + side / 2, y + side / 2 - 8,
            0.8, 0.75, 0.65, 1, UIFont.Small)
    else
        local lines = wrap(data.caption or "", side - 30)
        local ty = y + math.floor((side - #lines * fontH()) / 2)
        for i, l in ipairs(lines) do panel:drawTextCentre(l, x + side / 2, ty + (i - 1) * fontH(), 0.85, 0.8, 0.7, 1, UIFont.Small) end
    end
end

function Photo:prerender()
    ISPanelJoypad.prerender(self)
    local data = self.item:getModData().KnoxMobilePhoto or {}
    local side = PH_W - 32
    State.drawPhoto(self, data, 16, 16, side)
    local lines = wrap(data.caption or "", PH_W - 32)
    for i = 1, math.min(2, #lines) do
        self:drawText(lines[i], 16, 16 + side + 6 + (i - 1) * fontH(), 0.15, 0.15, 0.2, 1, UIFont.Small)
    end
end

function Photo:close()
    self:removeFromUIManager()
    if State.viewer == self then State.viewer = nil end
end
function Photo:onMouseDown() self:close(); return true end
function Photo:onJoypadDown() self:close() end

function State.look(player, item)
    if State.viewer then State.viewer:close() end
    local p = Photo:new(player, item)
    p:initialise()
    p:addToUIManager()
    p:setAlwaysOnTop(true)
    State.viewer = p
    return p
end

-- Menus --------------------------------------------------------------------------------------------------
Events.OnFillInventoryObjectContextMenu.Add(Util.safe("instant camera menu", function(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    local actual = ISInventoryPane.getActualItems(items)
    local item = actual[1]
    if not (item and player) then return end
    if item:getFullType() == Instant.CAMERA then
        local left = Instant.shots(item:getModData())
        local take = context:addOption(T("IGUI_KnoxMobile_InstantTake", "Take a photo (%1 left)", left), player,
            function() State.open(player, item) end)
        if left == 0 then take.notAvailable = true end
        local hasFilm = player:getInventory():containsTypeRecurse(Instant.FILM)
        local load = context:addOption(T("IGUI_KnoxMobile_InstantLoad", "Load film"), player,
            function() Net.toServer(player, "loadFilm", { cameraId = item:getID() }) end)
        if left > 0 or not hasFilm then load.notAvailable = true end
    elseif item:getFullType() == Instant.PHOTO then
        context:addOption(T("IGUI_KnoxMobile_InstantLook", "Look at the photo"), player, function() State.look(player, item) end)
    end
end))

return State
