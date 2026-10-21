-- Client: Camera (docs/rounds/CAMERA_PLAN.md), on the camera phones, with the Java part (ZombieBuddy). The screen is a
-- live viewfinder of what the phone sees (the 3D phone in your hand mirrors it); Enter or a tap takes the photo, with
-- a flash in the dark that zombies notice. Left or right (or "Flip") switches to the selfie camera: your own face over
-- the world behind you (Camera.lua). Photos go to the phone's memory (CameraSpec: how many by phone) and show in Photos.
local CameraSpec = require "KnoxMobile/Core/CameraSpec"
local Photos = require "KnoxMobile/Core/Photos"
local Util = require "KnoxMobile/Game/Util"
require "KnoxMobile/Camera"

local T = Util.text
local ICONS = "media/ui/KnoxMobile/apps/"

local function count(ctx) return #(ctx.state.contents.photos or {}) end

KnoxMobile.Apps.register({
    id = "camera", name = "Camera", icon = ICONS .. "camera.png", glyph = ICONS .. "camera_glyph.png",
    label = function() return T("IGUI_KnoxMobile_AppCamera", "Camera") end,
    short = function() return T("IGUI_KnoxMobile_AppShortCamera", "Camera") end,
    families = { "ColorFeature", "Keyboard", "Stylus", "ModernAndroid", "ModernPear" },
    drain = "video", needsService = false, order = 54,
    available = function(model)
        return KnoxMobile.Camera ~= nil and KnoxMobile.Camera.available() and Photos.fits(model)
            and CameraSpec.forFamily(model.family) ~= nil
    end,
    render = function(ctx, x, y, w, h)
        local Camera = KnoxMobile.Camera
        local spec = CameraSpec.forFamily(ctx.family)
        local lh = ctx:lineHeight()
        if not (spec and Camera.available()) then
            -- Only listed with the Java part; if it went away, say so instead of failing.
            local why = T("IGUI_KnoxMobile_CameraNeedsLive", "The camera needs the live screen add-on (ZombieBuddy).")
            for i, l in ipairs(ctx:wrap(why, w - 8)) do
                ctx:text(l, x + 3, y + (i - 1) * lh + 2)
            end
            return
        end
        local vw, vh = w, math.floor(w * 3 / 4)
        if vh > h - lh - 4 then vh = h - lh - 4; vw = math.floor(vh * 4 / 3) end
        local vx = x + math.floor((w - vw) / 2)
        ctx:rect(vx, y, vw, vh, { 0, 0, 0 }, 1)
        local Live = KnoxMobile.Live
        local d = ctx.data
        local flashing = d.flashUntil and getTimestampMs() < d.flashUntil
        -- "Flip" in the viewfinder's corner on phones with a front camera: the selfie camera on or off (left and right
        -- do the same).
        local label = T("IGUI_KnoxMobile_CameraFlip", "Flip")
        local fw = ctx:measure(label) + 8
        d.flip = Camera.hasFront(spec) and { x = vx + vw - fw - 2, y = y + 2, w = fw, h = lh + 2 } or nil
        if Camera.front then
            -- The selfie: what you face here, your face drawn over it by the game's character renderer; the 3D phone's
            -- copy (drawn before the face exists in this frame) shows the last grabbed picture instead. The button and
            -- the flash go on after the grab (Camera.afterUI), so they are never in the photo.
            local tex = (Live and Live.capturing) and knoxLiveCameraTexture() or knoxLiveCameraBackgroundTexture()
            if tex then ctx.panel:drawTextureScaled(tex, ctx.sx + vx, ctx.sy + y, vw, vh, 1, 1, 1, 1) end
            local flip = d.flip and { x = ctx.sx + d.flip.x, y = ctx.sy + d.flip.y, w = d.flip.w, h = d.flip.h, label = label }
            Camera.selfieRect(ctx.panel, { x = ctx.sx + vx, y = ctx.sy + y, w = vw, h = vh }, spec,
                { flip = flip, flash = flashing })
        else
            Camera.request(spec)
            local tex = knoxLiveCameraTexture()
            if tex then ctx.panel:drawTextureScaled(tex, ctx.sx + vx, ctx.sy + y, vw, vh, 1, 1, 1, 1) end
            if flashing then ctx:rect(vx, y, vw, vh, { 1, 1, 1 }, 0.8) end
            if d.flip then
                ctx:rect(d.flip.x, d.flip.y, d.flip.w, d.flip.h, { 0, 0, 0 }, 0.45)
                ctx:text(label, d.flip.x + 4, d.flip.y + 1, { 1, 1, 1 })
            end
        end
        -- Third person: the viewfinder says how to get to first person (Camera.blocked).
        local blocked = Camera.blocked()
        if blocked then
            ctx:rect(vx, y, vw, vh, { 0, 0, 0 }, 0.6)
            local lines = ctx:wrap(blocked, vw - 10)
            local ty = y + math.floor((vh - #lines * lh) / 2)
            for i, l in ipairs(lines) do ctx:text(l, vx + vw / 2, ty + (i - 1) * lh, { 1, 1, 1 }, nil, "center") end
        end
        local full = count(ctx) >= spec.max
        local hint = full and T("IGUI_KnoxMobile_CameraFull", "Memory full (%1)", spec.max)
            or (Camera.front and T("IGUI_KnoxMobile_CameraSelfieHint", "Enter: selfie  %1/%2", count(ctx), spec.max))
            or T("IGUI_KnoxMobile_CameraHint", "Enter: photo  %1/%2", count(ctx), spec.max)
        ctx:text(hint, x + 3, y + h - lh - 2, ctx.style.accent)
    end,
    onInput = function(ctx, ev)
        local Camera = KnoxMobile.Camera
        local spec = CameraSpec.forFamily(ctx.family)
        if not (spec and Camera.available()) then return true end
        local f = ctx.data.flip
        local onFlip = ev.type == "tap" and f and ev.x >= f.x and ev.x <= f.x + f.w and ev.y >= f.y and ev.y <= f.y + f.h
        if Camera.hasFront(spec) and (onFlip or (ev.type == "key" and (ev.key == "left" or ev.key == "right"))) then
            Camera.setFront(ctx.player, spec, not Camera.front)
            return true
        end
        if (ev.type == "key" and ev.key == "select") or ev.type == "tap" then
            local blocked = Camera.blocked()
            if blocked then
                ctx:toast(blocked)
                return true
            end
            if count(ctx) >= spec.max then
                ctx:toast(T("IGUI_KnoxMobile_PhotoFull", "Memory full: delete photos in Photos"))
                return true
            end
            Camera.shoot(ctx.player, ctx.phone, spec)
            ctx.data.flashUntil = getTimestampMs() + 150
        end
        return true
    end,
})
