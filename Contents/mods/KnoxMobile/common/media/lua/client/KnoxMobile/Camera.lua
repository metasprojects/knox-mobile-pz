-- Client: the phone camera (docs/rounds/CAMERA_PLAN.md). Needs the Java part (ZombieBuddy). This module picks what the
-- picture shows in each view, asks the Java part for it, paces the photo's upload to the server in chunks, fetches
-- photos the phone lists but this computer doesn't have, fires the night flash, makes captions, and runs the selfie
-- camera.
--
-- The camera's rules: a photo is exactly what you see, never with UI and never with
-- your own character in it. The Java part (0.6, FrameHook) copies the finished picture as the game starts its UI pass.
-- Your character is hidden while the back camera is open; with Viewpoint the Camera goes to first person when it can
-- (Viewpoint only switches between the isometric view and your last 3D view) and puts the view back after. Selfies
-- only on phones that had a front camera (PearPhone 4, Supernova IV): your own character, drawn by the game's face
-- close-up renderer, over what you're facing.
local CameraSpec = require "KnoxMobile/Core/CameraSpec"
local Format = require "KnoxMobile/Core/Format"
local Machine = require "KnoxMobile/Core/Machine"
local Util = require "KnoxMobile/Game/Util"
local Net = require "KnoxMobile/Game/Net"

local T = Util.text
local Camera = { want = nil, uploads = {}, downloads = {}, asked = {}, nextSend = 0, frame = 0 }
-- Debug (Live screen menu), for the older copy from the world buffer (no FrameHook): a forced source ("world",
-- "worldScreen", "worldFull", "screen"; nil = by view) and a flip.
Camera.source, Camera.flip = nil, false
-- The selfie camera is on (the Camera app's left/right or "Flip", on front-camera phones).
Camera.front = false
-- The selfie's framing: the Make-up window's face close-up, pulled back to head and shoulders.
Camera.FACE = { zoom = 14, y = -0.78, x = 0.02 }
-- Debug switches for the night test (Live screen menu): the FrameHook copy, and hiding your character.
Camera.useHook, Camera.hideSelf = true, true
-- At night the shutter waits a few frames after the flash so the light is in the picture.
Camera.FLASH_FRAMES, Camera.FLASH_MS = 6, 600
-- After the Camera reaches first person, the shutter waits this long (ms) for the phone to hide and the arm to lower.
Camera.STEADY_MS = 900
KnoxMobile.Camera = Camera

local CHUNK = 4000

function Camera.available() return knoxLiveCameraFrame ~= nil and not KnoxMobile.pretendNoJava end

-- Third person draws your own character whatever a mod asks (fourth pass), and only the player can switch Viewpoint
-- to first person: the Camera says how and waits. Returns the hint, or nil when a photo can be taken.
function Camera.blocked()
    local VP = KnoxMobile.Viewpoint
    if VP and VP.view() == "third" then
        return T("IGUI_KnoxMobile_CameraNeedFirst", "Press %1 for first person to take a photo", VP.firstPersonKey())
    end
    -- Just in first person with the back camera: a moment for the phone to hide and the arm to come down.
    if Camera.fpSince and not Camera.front and getTimestampMs() - Camera.fpSince < Camera.STEADY_MS then
        return T("IGUI_KnoxMobile_CameraSteady", "Steady...")
    end
    return nil
end

-- The selfie camera: only phones that had one.
function Camera.hasFront(spec) return spec ~= nil and spec.front == true end

local function view()
    local VP = KnoxMobile.Viewpoint
    return VP and VP.view() or "isometric"
end

-- The finished picture through the Java part's FrameHook (0.6), once ZombieBuddy has applied the patch.
local function hooked()
    return Camera.useHook and knoxLiveCameraHooked ~= nil and knoxLiveCameraHooked() == true
end
Camera.hooked = hooked

-- The 4:3 piece of the picture to keep, as fractions from the top left: the middle in Viewpoint's views; in the
-- isometric view, what lies ahead of you.
function Camera.piece(player)
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local aspect = sw / math.max(1, sh)
    local cw, ch = math.min(1, (4 / 3) / aspect), math.min(1, aspect / (4 / 3))
    local cx, cy = (1 - cw) / 2, (1 - ch) / 2
    if view() == "isometric" then
        ch = 0.6
        cw = math.min(1, ch * (4 / 3) / aspect)
        local px, py = 0.5, 0.5
        if player then
            local ok, x, y = pcall(function()
                local f = player:getForwardDirection()
                local ax, ay = player:getX() + f:getX() * 4, player:getY() + f:getY() * 4
                local z = player:getZ()
                return isoToScreenX(player:getPlayerNum(), ax, ay, z) / sw, isoToScreenY(player:getPlayerNum(), ax, ay, z) / sh
            end)
            if ok and x and y then px, py = x, y end
        end
        cx = math.max(0, math.min(1 - cw, px - cw / 2))
        cy = math.max(0, math.min(1 - ch, py - ch / 2))
    end
    return cx, cy, cw, ch
end

-- The older copy (no FrameHook): the world buffer, which way up it is, and the piece.
function Camera.region(player)
    local iso = view() == "isometric"
    local source, topDown = iso and "world" or "worldScreen", iso
    if Camera.source then source = Camera.source end
    if Camera.flip then topDown = not topDown end
    return source, topDown, Camera.piece(player)
end

-- Asks for a copy of the picture: with FrameHook it is made as the next UI pass starts (done = false); otherwise now,
-- from the world buffer (done = true).
local function copyFrame(target, spec, player)
    if hooked() then
        knoxLiveCameraWant(target, spec.w, spec.h, Camera.piece(player))
        return false
    end
    if target == "background" then
        knoxLiveCameraBackground(spec.w, spec.h, Camera.region(player))
    else
        knoxLiveCameraFrame(spec.w, spec.h, Camera.region(player))
    end
    return true
end

-- The Camera app asks for a frame while it shows (the back camera).
function Camera.request(spec) Camera.want = spec end

-- The selfie's background: what you're facing, without the phone in your hand or your own character. Both hide for a
-- few frames, the picture is copied, they come back. Started when the selfie camera opens and at its shutter.
function Camera.refreshBackground(player, spec, shot)
    if Camera.bgJob then
        if shot then Camera.bgJob.shot = shot end
        return
    end
    Camera.bgJob = { player = player, spec = spec, frames = 0, shot = shot }
    Camera.hideHeld = true
end

local function endJob()
    Camera.bgJob, Camera.hideHeld = nil, nil
end

Events.OnPreUIDraw.Add(Util.safe("camera frame", function()
    Camera.frame = Camera.frame + 1
    local spec, shot = Camera.want, Camera.pendingShot
    Camera.want = nil
    local job = Camera.bgJob
    if not Camera.available() then Camera.pendingShot = nil; return end
    local player = getPlayer()
    if job then
        job.frames = job.frames + 1
        -- Two frames drawn without the phone and you, then the copy; with FrameHook it lands a frame later.
        if job.frames == 3 then job.done = copyFrame("background", job.spec, job.player) end
        if job.frames >= 4 or (job.frames == 3 and job.done) then
            endJob()
            -- A selfie waiting for its background: grabbed with your face in this frame's UI (Camera.afterUI).
            if job.shot then Camera.selfieShot = job.shot end
        end
    end
    spec = spec or (shot and shot.spec)
    local done = spec and copyFrame("camera", spec, player)
    if not shot then return end
    -- The shutter reads the copy made this frame (as the UI pass started, or just now). At night it waits for the
    -- flash's light to be in the picture.
    if (shot.frames or 0) > 0 then shot.frames = shot.frames - 1; return end
    Camera.pendingShot = nil
    if done or hooked() then knoxLiveShutter(shot.id, shot.spec.levels or 0) end
end))

-- The selfie camera's face: the game's own character renderer (ISUI3DModel, as in the Make-up window), facing the
-- lens, over the viewfinder. It only draws; taps go through to the phone.
local function faceElement(panel)
    if panel.selfieFace then return panel.selfieFace end
    local m = ISUI3DModel:new(0, 0, 16, 16)
    m:initialise()
    m:instantiate()
    m:setCharacter(panel.player)
    m:setIsometric(false)
    m:setDirection(IsoDirections.S)
    m:setState("idle")
    m:setZoom(Camera.FACE.zoom)
    m:setYOffset(Camera.FACE.y)
    m:setXOffset(Camera.FACE.x)
    pcall(function() m.javaObject:setConsumeMouseEvents(false) end)
    m.onMouseDown, m.onMouseMove, m.onMouseUp = function() return false end, function() end, function() end
    m.onMouseMoveOutside, m.onMouseUpOutside = function() end, function() end
    panel:addChild(m)
    panel.selfieFace = m
    return m
end

local function dropFace(panel)
    if panel and panel.selfieFace then
        panel:removeChild(panel.selfieFace)
        panel.selfieFace = nil
    end
end

-- The Camera app's selfie viewfinder this frame (panel coordinates), and what goes over it after the grab: the
-- "Flip" button and the shutter's white flash (third pass: both were in the photo).
function Camera.selfieRect(panel, rect, spec, overlay)
    panel.selfieRect, panel.selfieSpec, panel.selfieOverlay = rect, spec, overlay
    local m = faceElement(panel)
    m:setX(rect.x)
    m:setY(rect.y)
    m:setWidth(rect.w)
    m:setHeight(rect.h)
    m:setVisible(true)
end

-- After the phone and its children are drawn (Panel:render): the selfie picture is what the viewfinder shows now,
-- background and face, copied into the camera texture; a selfie waiting for it is taken from that. Then the
-- viewfinder's buttons and flash are drawn on top, after the copy.
function Camera.afterUI(panel)
    local selfie = panel.view == "app" and panel.appId == "camera" and Camera.front and Camera.available()
    if not selfie then
        dropFace(panel)
        return
    end
    local r, spec = panel.selfieRect, panel.selfieSpec
    if not (r and spec and knoxLiveCameraGrabUI) then return end
    knoxLiveCameraGrabUI(panel:getAbsoluteX() + r.x, panel:getAbsoluteY() + r.y, r.w, r.h, spec.w, spec.h)
    local shot = Camera.selfieShot
    if shot then
        Camera.selfieShot = nil
        knoxLiveShutter(shot.id, shot.spec.levels or 0)
    end
    local o = panel.selfieOverlay
    if not o then return end
    if o.flash then panel:drawRect(r.x, r.y, r.w, r.h, 0.8, 1, 1, 1) end
    if o.flip then
        local f = o.flip
        panel:drawRect(f.x, f.y, f.w, f.h, 0.45, 0, 0, 0)
        panel:drawText(f.label, f.x + 4, f.y + 1, 1, 1, 1, 1, UIFont.Small)
    end
end

-- The Camera app is open (and the phone is on it). Runs every tick.
local function cameraOpen()
    local p = KnoxMobile.UI and KnoxMobile.UI.panel
    if not (p and p.view == "app" and p.appId == "camera" and Camera.available()) then return nil end
    return p
end

-- With Viewpoint, the Camera goes to first person when it can and the view goes back when it closes. Viewpoint's
-- View.cycle goes from the isometric view to your last 3D view, from first person to third, from third to
-- isometric (third pass): from the isometric view one step reaches first person, or third person after third was
-- last (your character is hidden there too). In third person it stays. One step at a time, a moment apart.
local function steerView(p)
    local vp = Viewpoint and Viewpoint.View
    if not (vp and vp.cycle and vp.next and KnoxMobile.Viewpoint) then return end
    local now = getTimestampMs()
    if now < (Camera.nextCycle or 0) then return end
    local v = KnoxMobile.Viewpoint.view()
    local step = false
    if p then
        if Camera.restoreView == nil then Camera.restoreView = v end
        step = v == "isometric" and (Camera.steps or 0) < 1
    elseif Camera.restoreView then
        -- Closed in first person: stay there (release test: the way back to the isometric view goes through third
        -- person, which then became the "last 3D view" and the next Camera opened in third person).
        if v == "first" or v == Camera.restoreView or (Camera.steps or 0) >= 3 then
            Camera.restoreView = nil
        else
            step = true
        end
    end
    if not step then return end
    Camera.steps = (Camera.steps or 0) + 1
    pcall(vp.cycle)
    Camera.nextCycle = now + 350
end

Events.OnTick.Add(Util.safe("camera view", function()
    local p = cameraOpen()
    if (p ~= nil) ~= (Camera.wasOpen == true) then Camera.steps, Camera.wasOpen = 0, p ~= nil end
    steerView(p)
    -- When the open Camera got to first person (Camera.blocked waits a moment after it).
    if p and view() == "first" then
        Camera.fpSince = Camera.fpSince or getTimestampMs()
    else
        Camera.fpSince = nil
    end
    -- Your own character stays out of the picture: hidden while the back camera is open in the isometric view and
    -- third person (in first person the phone hides and the arm lowers, as in the third pass), and while a selfie
    -- catches its background.
    local player = getPlayer()
    local hide = p ~= nil and Camera.hideSelf and (not Camera.front or Camera.bgJob ~= nil) and view() ~= "first"
    if player and hide ~= (Camera.selfHidden == true) then
        pcall(function() player:setDoRender(not hide) end)
        -- The faction tag in front of the multiplayer name.
        pcall(function() player:setShowTag(not hide) end)
        Camera.selfHidden = hide or nil
    end
    -- Your own multiplayer name ("Meta") is drawn with the world, so it was in hosted photos even with the character
    -- hidden (showcase pass, 2026-10-20). IsoGameCharacter.updateUserName rereads Core.isShowYourUsername every frame
    -- for the local player, so it is off while the Camera is open and put back as it was when it closes.
    local core = getCore()
    if p and not Camera.nameWas and core:isShowYourUsername() then
        Camera.nameWas = true
        core:setShowYourUsername(false)
    elseif not p and Camera.nameWas then
        Camera.nameWas = nil
        core:setShowYourUsername(true)
    end
    if not p then
        endJob()
        Camera.front, Camera.selfieShot = false, nil
        if Camera.lastPanel then dropFace(Camera.lastPanel) end
    end
    Camera.lastPanel = p
end))

-- What the photo shows, in words: the town, the time, the weather, zombies in sight.
function Camera.caption(player)
    local x, y = player:getX(), player:getY()
    local parts = { Machine.town(x, y) }
    local gt = getGameTime()
    parts[#parts + 1] = Format.clock(gt:getHour(), gt:getMinutes(), KnoxMobile.Options.clock24())
    local climate = getClimateManager()
    if climate:getPrecipitationIntensity() > 0.1 then
        parts[#parts + 1] = climate:getPrecipitationIsSnow() and T("IGUI_KnoxMobile_PhotoSnow", "snow")
            or T("IGUI_KnoxMobile_PhotoRain", "rain")
    elseif climate:getDayLightStrength() < 0.3 then
        parts[#parts + 1] = T("IGUI_KnoxMobile_PhotoDark", "dark, grainy")
    end
    local n = 0
    local fx, fy = 1, 0
    pcall(function()
        local f = player:getForwardDirection()
        fx, fy = f:getX(), f:getY()
    end)
    local list = getCell():getZombieList()
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        local dx, dy = z:getX() - x, z:getY() - y
        local d = math.sqrt(dx * dx + dy * dy)
        -- In front of you (within about 40 degrees of where you face) and near enough to make out.
        if d > 0.5 and d < 15 and z:getZ() == player:getZ() and (dx * fx + dy * fy) / d > 0.75 then n = n + 1 end
    end
    if n == 1 then parts[#parts + 1] = T("IGUI_KnoxMobile_PhotoOneZombie", "one of them in the shot")
    elseif n > 1 then parts[#parts + 1] = T("IGUI_KnoxMobile_PhotoZombies", "%1 of them in the shot", n) end
    return table.concat(parts, ", ")
end

-- The flash: in the dark a bright burst at the player for a moment, which nearby zombies notice.
local flashes = {}
local function flash(player)
    if getClimateManager():getDayLightStrength() >= 0.4 then return false end
    local light = IsoLightSource.new(math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ()),
        1, 1, 0.95, 8)
    getCell():addLamppost(light)
    flashes[#flashes + 1] = { light = light, untilMs = getTimestampMs() + Camera.FLASH_MS }
    -- Zombies near enough to see a flash in the dark come to look (third pass: 8 tiles was too few to notice).
    Net.toServer(player, "noise", { radius = 14 })
    return true
end

-- Takes the photo with the phone's camera: the shutter in the next UI pass, the upload as soon as the JPEG is ready.
-- A selfie first catches the world behind you again, then takes the viewfinder with your face.
function Camera.shoot(player, phone, spec)
    local id = string.format("p%d-%d", math.floor(getTimestampMs()), ZombRand(100000))
    getSoundManager():playUISound("KnoxMobileButton")
    local flashed = flash(player)
    local caption = Camera.caption(player)
    if Camera.front and Camera.hasFront(spec) then
        Camera.refreshBackground(player, spec, { id = id, spec = spec })
        caption = T("IGUI_KnoxMobile_PhotoSelfie", "Selfie, %1", caption)
    else
        Camera.pendingShot = { id = id, spec = spec, frames = flashed and Camera.FLASH_FRAMES or 0 }
    end
    Camera.uploads[id] = { player = player, phoneId = phone:getID(), caption = caption, spec = spec,
        part = 0, since = getTimestampMs() }
    return id, flashed
end

-- The Camera app's left/right: the selfie camera on or off.
function Camera.setFront(player, spec, on)
    Camera.front = on == true and Camera.hasFront(spec)
    if Camera.front then
        -- The selfie needs the phone on screen: walking and looking goes back to using the phone.
        if KnoxMobile.UI and KnoxMobile.UI.walk then KnoxMobile.UI.walk = false end
        Camera.refreshBackground(player, spec)
    end
end

-- A photo this computer doesn't have yet: ask the server once (again after a while if nothing came).
function Camera.ensure(player, id)
    if not (Camera.available() and CameraSpec.validId(id)) or knoxLivePhotoData(id) then return end
    local asked = Camera.asked[id]
    if asked and getTimestampMs() - asked < 15000 then return end
    Camera.asked[id] = getTimestampMs()
    Net.toServer(player, "photoGet", { id = id })
end

Net.onClient("photoChunk", function(args)
    if not CameraSpec.validId(args.id) or type(args.data) ~= "string" then return end
    local d = Camera.downloads[args.id] or { parts = args.parts, got = 0, chunks = {} }
    Camera.downloads[args.id] = d
    if not d.chunks[args.part] then d.got = d.got + 1 end
    d.chunks[args.part] = args.data
    if d.got >= d.parts then
        Camera.downloads[args.id] = nil
        if Camera.available() then knoxLiveLoadPhoto(args.id, table.concat(d.chunks)) end
    end
end)

Net.onClient("photoSaved", function(args)
    if args.ok then
        KnoxMobile.Client.toast(T("IGUI_KnoxMobile_PhotoTaken", "Photo saved"))
    elseif args.reason == "write" then
        KnoxMobile.Client.toast(T("IGUI_KnoxMobile_PhotoNotSaved", "The photo couldn't be saved"))
    else
        KnoxMobile.Client.toast(T("IGUI_KnoxMobile_PhotoFull", "Memory full: delete photos in Photos"))
    end
end)

-- Uploads go a chunk at a time, a few per second, so they never trip the server's rate limit.
Events.OnTick.Add(Util.safe("camera upload", function()
    local t = getTimestampMs()
    for i = #flashes, 1, -1 do
        if t >= flashes[i].untilMs then
            getCell():removeLamppost(flashes[i].light)
            table.remove(flashes, i)
        end
    end
    if t < Camera.nextSend then return end
    for id, u in pairs(Camera.uploads) do
        local data = Camera.available() and knoxLivePhotoData(id)
        if data then
            local parts = math.ceil(#data / CHUNK)
            u.part = u.part + 1
            local args = { id = id, part = u.part, parts = parts, data = data:sub((u.part - 1) * CHUNK + 1, u.part * CHUNK) }
            if u.part == 1 then
                args.phoneId, args.caption, args.w, args.h = u.phoneId, u.caption, u.spec.w, u.spec.h
            end
            Net.toServer(u.player, "photoChunk", args)
            if u.part >= parts then Camera.uploads[id] = nil end
            Camera.nextSend = t + 120
            return
        elseif t - u.since > 10000 then
            Camera.uploads[id] = nil
            Util.log("camera: photo", id, "never came back from the shutter")
        end
    end
end))

return Camera
