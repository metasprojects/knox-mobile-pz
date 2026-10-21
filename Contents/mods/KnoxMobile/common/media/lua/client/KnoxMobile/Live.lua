-- Client: the optional Java part (ZombieBuddy, tools/live): a live phone screen on the held 3D phone (R7 plan,
-- phone-in-hand vision). Without ZombieBuddy none of the knoxLive* functions exist and everything here is a no-op.
-- Step one is a spike the PC test checks: what the hand models are, a test texture on the held phone, and the
-- phone's screen captured into a texture (shown beside the phone and put on the held phone).
local Util = require "KnoxMobile/Game/Util"
local Phones = require "KnoxMobile/Game/Phones"
local ScreenUV = require "KnoxMobile/UI/ScreenUV"

-- capture: nil follows the mod option (Live screen on the phone in your hand); the debug menu forces true or false.
local Live = { capture = nil, testTexture = false }
KnoxMobile.Live = Live

Live.TEST_TEXTURE = "media/textures/KnoxMobile/live_test.png"
Live.TEX_W, Live.TEX_H = 256, 512

-- Debug > "Act as if ZombieBuddy is missing" (KnoxMobile.pretendNoJava) tests the plain-game paths with it loaded.
function Live.available() return knoxLiveVersion ~= nil and not KnoxMobile.pretendNoJava end
function Live.version() return Live.available() and knoxLiveVersion() or nil end

-- The phone sits in the secondary hand (Hold.raise); the primary is tried too.
local function setHeld(player, path)
    if not Live.available() then return false end
    local ok = knoxLiveSetHeldTexture(player, true, path)
    if not ok then ok = knoxLiveSetHeldTexture(player, false, path) end
    return ok
end

function Live.describe(player)
    if not Live.available() then return "ZombieBuddy part not loaded" end
    return knoxLiveDescribe(player)
end

function Live.setTest(player, on)
    Live.testTexture = on
    local ok = setHeld(player, on and Live.TEST_TEXTURE or "")
    Util.log("live screen: test texture", on and "on" or "off", ok and "(held phone model found)" or "(no held model)")
    return ok
end

function Live.setCapture(player, on)
    -- Off means back to the option (second pass: "turn off" left the live screen off for the whole session).
    Live.capture = on and true or nil
    if not on then setHeld(player, "") end
    Util.log("live screen: capture", on and "on" or "off")
end

-- Is the live screen running: the Java part is there and the option (or the debug menu) wants it.
function Live.active()
    if not Live.available() or Live.testTexture then return false end
    if Live.capture ~= nil then return Live.capture end
    return KnoxMobile.Options == nil or KnoxMobile.Options.liveScreen()
end

-- The phone was put away or closed: its model gets its own texture back.
function Live.release(player)
    if Live.available() and player then setHeld(player, "") end
end

-- Called by the phone panel around its screen drawing: rect in screen pixels.
function Live.begin(x, y, w, h)
    if not Live.active() then return false end
    knoxLiveBeginCapture(x, y, w, h, Live.TEX_W, Live.TEX_H)
    -- Apps can tell the 3D phone's copy from the panel's own draw (the selfie viewfinder draws differently).
    Live.capturing = true
    return true
end

function Live.finish()
    Live.capturing = nil
    knoxLiveEndCapture()
end

-- The phone model's own texture (make_phone.py: textures/KnoxMobile/<art>_<Color>.png).
local function modelTexture(item)
    local model, colorName = Phones.model(item)
    local art = model and (model.look or model.id)
    if not art then return nil, nil end
    local key = tostring(colorName or ""):gsub("[^%w]", "")
    return getTexture("media/textures/KnoxMobile/" .. art .. "_" .. key .. ".png")
        or getTexture("media/textures/KnoxMobile/" .. art .. ".png"), art
end

-- The held phone's texture with the live screen in its screen's place (UI/ScreenUV.lua, from the model's UVs), put
-- on the held model. Texture rows in the off-screen target are read bottom-up, so the model's texture is drawn
-- upside down there; the captured screen, already upside down, is drawn as it is (r8: the copy showed upside down).
function Live.composite(panel)
    if not Live.active() then return end
    local atlas, art = modelTexture(panel.item)
    local uv = art and ScreenUV[art]
    local shot = knoxLiveCaptureTexture()
    if not (atlas and uv and shot and knoxLiveBeginComposite) then
        setHeld(panel.player, "capture")
        return
    end
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local ax, ay = panel:getAbsoluteX(), panel:getAbsoluteY()
    knoxLiveBeginComposite(atlas:getWidth(), atlas:getHeight())
    -- drawTextureAllPoint takes screen coordinates (UIElement.DrawTexture adds no element offset, unlike
    -- drawTextureScaled): with the panel's offset taken off, the body shifted under the screen (final test: the 3D
    -- Soapbar's screen hung past its edge).
    panel:drawTextureAllPoint(atlas, 0, sh, sw, sh, sw, 0, 0, 0, 1, 1, 1, 1)
    local x0, x1 = uv.tl[1] * sw, uv.tr[1] * sw
    local y0, y1 = (1 - uv.bl[2]) * sh, (1 - uv.tl[2]) * sh
    panel:drawTextureScaled(shot, x0 - ax, y0 - ay, x1 - x0, y1 - y0, 1, 1, 1, 1)
    Live.keyLights(panel, uv, sw, sh, ax, ay)
    knoxLiveEndComposite()
    -- The model can be rebuilt (equip, clothes), so the texture goes back on every frame.
    setHeld(panel.player, "composite")
end

-- The keypad on the 3D phone: a soft backlight on the number keys while the screen is on, and the
-- key just pressed (on the 2D phone or by the keyboard) lit up bright. Key rects come from ScreenUV (the frame art's
-- keys mapped onto the model); drawn flipped like the rest of the composite.
local BACKLIGHT = { SegmentLCD = { 1, 0.45, 0.2 }, MonoLCD = { 0.55, 1, 0.45 }, ColorFeature = { 0.7, 0.85, 1 } }
function Live.keyLights(panel, uv, sw, sh, ax, ay)
    if not uv.keys then return end
    local state = panel:state()
    if not (state and state.power.on and state.battery.charge > 0) then return end
    local glow = BACKLIGHT[panel.family] or { 0.85, 0.9, 1 }
    local pressed = panel.pressed and getTimestampMs() < panel.pressed.untilMs and panel.pressed.r.id or nil
    for id, r in pairs(uv.keys) do
        local lit = id == pressed
        if lit or id:match("^Key") then
            local x, y = r[1] * sw - ax, (1 - r[4]) * sh - ay
            panel:drawRect(x, y, (r[3] - r[1]) * sw, (r[4] - r[2]) * sh, lit and 0.75 or 0.22, glow[1], glow[2], glow[3])
        end
    end
end

-- Without the live screen (no ZombieBuddy, or the option off): the held phone shows a still of what its screen shows
-- (tools/art/screen_pictures.py: home, messages, a call, Snake), by swapping its model to "<model>_<state>" while
-- open (InventoryItem.setStaticModel, then the hands' models are rebuilt). Its own model comes back when it closes.
local GAME_APPS = { snake = true }
local function pictureState(panel)
    local state = panel:state()
    local mode = panel.currentMode
    if not (state and state.power.on) or mode == "off" or mode == "broken" or mode == "rice" then return nil end
    if mode == "call" then return "call" end
    if panel.view == "app" and panel.appId == "messages" then return "messages" end
    if panel.view == "app" and GAME_APPS[panel.appId] then return "game" end
    return "home"
end

local function hasModel(name)
    local sm = getScriptManager()
    return sm:getModelScript(name) ~= nil or sm:getModelScript("KnoxMobile." .. name) ~= nil
end

local function setModel(player, item, name)
    if item:getStaticModel() == name then return end
    item:setStaticModel(name)
    if player then player:resetEquippedHandsModels() end
end

-- First person with the Camera open (final test 2026-10-19: the phone in your hand was in its own photos): the held
-- phone takes its invisible model ("<model>_hidden", tools/gen/Build.lua) until the Camera closes. A phone's camera
-- doesn't see the phone.
function Live.hide(panel, on)
    local item = panel.item
    if on then
        if panel.heldHidden then return end
        local md = item:getModData()
        md.KnoxMobileBaseModel = md.KnoxMobileBaseModel or item:getStaticModel()
        local name = tostring(md.KnoxMobileBaseModel) .. "_hidden"
        if hasModel(name) then
            setModel(panel.player, item, name)
            panel.heldHidden = true
        end
    elseif panel.heldHidden then
        panel.heldHidden = nil
        Live.unpicture(panel.player, item)
    end
end

function Live.picture(panel)
    if panel.heldHidden then return end
    if Live.active() or (KnoxMobile.Options and not KnoxMobile.Options.liveScreen()) then return end
    local item = panel.item
    local md = item:getModData()
    md.KnoxMobileBaseModel = md.KnoxMobileBaseModel or item:getStaticModel()
    local base = md.KnoxMobileBaseModel
    if type(base) ~= "string" or base == "" then return end
    local st = pictureState(panel)
    local want = st and (base .. "_" .. st) or base
    if want ~= base and want ~= item:getStaticModel() and not hasModel(want) then want = base end
    setModel(panel.player, item, want)
end

function Live.unpicture(player, item)
    local base = item and item:getModData().KnoxMobileBaseModel
    if type(base) == "string" and base ~= "" then setModel(player, item, base) end
end

-- A save made while a phone was open keeps the picture model: put every carried phone's own model back on load.
Events.OnGameStart.Add(Util.safe("phone pictures", function()
    local player = getPlayer()
    if not player then return end
    for _, item in ipairs(Phones.inventoryPhones(player)) do Live.unpicture(player, item) end
end))

function Live.texture() return Live.available() and knoxLiveCaptureTexture() or nil end
-- The magenta-framed copy beside the phone: only when the debug menu turned the capture on.
function Live.showCopy() return Live.capture == true and Live.available() end

Events.OnGameStart.Add(Util.safe("live screen", function()
    if Live.available() then Util.log("live screen: Java part", Live.version(), "loaded") end
end))

return Live
