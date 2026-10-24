-- Client: Photos (2026-10-12), the camera roll on colour-screen phones from 2003 on. Found phones bring their owner's
-- roll (Core/Story.deadPhone), as captions (or one of the staged pictures for its code, Data/StagedPhotos, when there
-- are any). Your own photos are real pictures with the Java part (Camera.lua, docs/rounds/CAMERA_PLAN.md):
-- open one to see it, send it by text, make it the wallpaper or delete it. Without the Java part they are captions.
local Photos = require "KnoxMobile/Core/Photos"
local Staged = require "KnoxMobile/Data/StagedPhotos"
local Mod = require "KnoxMobile/Core/Mod"
local CameraSpec = require "KnoxMobile/Core/CameraSpec"
local Format = require "KnoxMobile/Core/Format"
local Sim = require "KnoxMobile/Core/Sim"
local Messages = require "KnoxMobile/Data/Messages"
local Phones = require "KnoxMobile/Game/Phones"
local Net = require "KnoxMobile/Game/Net"
local Util = require "KnoxMobile/Game/Util"
require "KnoxMobile/Camera"

local T = Util.text
local ICONS = "media/ui/KnoxMobile/apps/"
local STAGED = "media/ui/KnoxMobile/photos/"
local FAMILIES = { "ColorFeature", "Keyboard", "Stylus", "ModernAndroid", "ModernPear" }

-- The owner's roll (found phones), then your own photos (contents.photos: { id, text, day, minute, w, h }), newest
-- first like Messages (second pass). Each entry knows where it came from: own = its index in contents.photos.
local function roll(ctx)
    local out = {}
    local p = ctx.state.story and ctx.state.story.photos
    for _, photo in ipairs(type(p) == "table" and p or {}) do out[#out + 1] = { photo = photo } end -- older saves kept a count
    for i, photo in ipairs(ctx.state.contents.photos or {}) do out[#out + 1] = { photo = photo, own = i } end
    local newest = {}
    for i = #out, 1, -1 do newest[#newest + 1] = out[i] end
    return newest
end

local function camera() return KnoxMobile.Camera ~= nil and KnoxMobile.Camera.available() end

local function date(day)
    local month, d = Photos.date(day)
    if month == 6 then return T("IGUI_KnoxMobile_PhotoJune", "June %1", d) end
    return T("IGUI_KnoxMobile_PhotoJuly", "July %1", d)
end

-- "Jenna's birthday, June 30"; "[dark, blurry] something in the hallway".
local function caption(photo)
    if photo.text then return photo.text end
    local english = Messages.words.Photo[photo.code] or photo.code
    return T("IGUI_KnoxMobile_Word_Photo_" .. tostring(photo.code), english, photo.name or "", date(photo.day))
end

-- The picture for a photo, when there is one: a real photo (asked from the server the first time) or a staged one.
-- Returns texture, or nil and whether it is on its way.
local function picture(ctx, photo)
    if photo.id and camera() then
        local tex = knoxLivePhotoTexture(photo.id)
        if not tex then KnoxMobile.Camera.ensure(ctx.player, photo.id) end
        return tex, tex == nil
    end
    -- A dead owner's photo: one of the staged pictures for its caption (tools/art/staged_photos.py, from the photo
    -- shoots), chosen by the photo's v so it never changes; the 2003 Soapbar's in its own low-colour version.
    local count = photo.code and Staged[photo.code]
    if count and count > 0 then
        local n = Mod.floor((tonumber(photo.v) or 1) - 1, count) + 1
        local base = STAGED .. tostring(photo.code) .. (n > 1 and ("_" .. n) or "")
        local tex = ctx.family == "ColorFeature" and getTexture(base .. "_ColorFeature.png") or nil
        return tex or getTexture(base .. ".png"), false
    end
    return nil, false
end

-- Your own caption-only photo (no Java part): a click and the caption from what's around.
local function snapshot(ctx)
    getSoundManager():playUISound("KnoxMobileButton")
    ctx:setting("photo", KnoxMobile.Camera and KnoxMobile.Camera.caption(ctx.player) or "")
end

-- The things you can do with an open photo of your own.
local function actions(ctx, entry)
    local out = {}
    if not entry.own then return out end
    local id = entry.photo.id
    if id then
        out[#out + 1] = { id = "send", label = T("IGUI_KnoxMobile_PhotoSend", "Send by text") }
        local family = Phones.registry:family(ctx.family)
        if family and family.wallpapers then
            out[#out + 1] = { id = "wallpaper", label = T("IGUI_KnoxMobile_PhotoWallpaper", "Set as wallpaper") }
        end
    end
    out[#out + 1] = { id = "delete", label = T("IGUI_KnoxMobile_PhotoDelete", "Delete") }
    return out
end

local function askNumber(ctx, prompt, onNumber)
    ctx:askText(prompt, "", function(text)
        local number = Sim.normalise(text)
        if not number and ctx.state.sim then
            for _, c in ipairs(ctx.state.sim.contacts) do
                if c.name:lower() == text:lower() then number = c.number end
            end
        end
        if number then onNumber(number) else ctx:toast(T("IGUI_KnoxMobile_BadNumber", "That isn't a phone number")) end
    end, 20)
end

local function act(ctx, entry, what)
    local d, photo = ctx.data, entry.photo
    if what == "send" then
        askNumber(ctx, T("IGUI_KnoxMobile_To", "To (number or contact):"), function(number)
            Net.toServer(ctx.player, "sendText", { phoneId = ctx.phone:getID(), to = number,
                body = CameraSpec.text(photo.id, (photo.text or ""):sub(1, 160)) })
            ctx:toast(T("IGUI_KnoxMobile_PhotoSent", "Photo sent"))
        end)
    elseif what == "wallpaper" then
        ctx:setting("wallpaperPhoto", photo.id)
        ctx:toast(T("IGUI_KnoxMobile_PhotoWallpaperSet", "Wallpaper set"))
    elseif what == "delete" then
        Net.toServer(ctx.player, "photoDelete", { phoneId = ctx.phone:getID(), index = entry.own, id = photo.id })
        if photo.id and camera() then knoxLiveForgetPhoto(photo.id) end
        d.open, d.menu, d.keepBack = nil, nil, false
        ctx:toast(T("IGUI_KnoxMobile_PhotoDeleted", "Photo deleted"))
    end
end

local function drawPhoto(ctx, entry, n, total, x, y, w, h)
    local lh, d = ctx:lineHeight(), ctx.data
    ctx:text(T("IGUI_KnoxMobile_PhotoOf", "Photo %1 of %2", n, total), x + 3, y, ctx.style.accent)
    local top = y + lh + 2
    local tex, loading = picture(ctx, entry.photo)
    local hint = #actions(ctx, entry) > 0 and T("IGUI_KnoxMobile_PhotoOptions", "Select: options") or nil
    local room = h - (top - y) - (hint and lh + 2 or 0)
    -- A caption-only photo says what it is ("Photo: ..."); under a picture the caption is enough.
    local words = (tex or loading) and caption(entry.photo)
        or T("IGUI_KnoxMobile_PhotoCaption", "Photo: %1", caption(entry.photo))
    local lines = ctx:wrap(words, w - 8)
    if tex or loading then
        -- The picture, as big as fits (4:3 unless it says otherwise), with room under it for the caption: up to four
        -- lines (0.1.1: the Soapbar's small screen cut captions after two).
        local pw, ph = entry.photo.w or 4, entry.photo.h or 3
        if tex and tex:getWidth() > 0 then pw, ph = tex:getWidth(), tex:getHeight() end
        local maxH = math.max(lh, room - lh * math.min(4, math.max(2, #lines)) - 4)
        local iw = w - 4
        local ih = math.floor(iw * ph / pw)
        if ih > maxH then ih = maxH; iw = math.floor(ih * pw / ph) end
        local ix = x + math.floor((w - iw) / 2)
        ctx:rect(ix, top, iw, ih, { 0, 0, 0 }, 1)
        if tex then
            ctx.panel:drawTextureScaled(tex, ctx.sx + ix, ctx.sy + top, iw, ih, 1, 1, 1, 1)
        else
            ctx:text(T("IGUI_KnoxMobile_PhotoLoading", "Loading..."), ix + iw / 2, top + ih / 2 - lh / 2, { 0.8, 0.8, 0.8 },
                nil, "center")
        end
        room = room - ih - 4
        top = top + ih + 4
    end
    local fit = math.max(1, math.floor(room / lh))
    for i, l in ipairs(lines) do
        if i > fit then break end
        if i == fit and #lines > fit then l = l .. "..." end
        ctx:text(l, x + 3, top + (i - 1) * lh)
    end
    if hint then ctx:text(hint, x + 3, y + h - lh - 1, ctx.style.accent) end
    if d.menu then
        local list = actions(ctx, entry)
        local rowH = lh + 4
        local mh = rowH * #list
        ctx:rect(x + 4, y + h - mh - 6, w - 8, mh + 4, ctx.style.bg, 0.95)
        ctx:border(x + 4, y + h - mh - 6, w - 8, mh + 4, ctx.style.accent, 1)
        -- The menu keeps its own selection (the roll's stays where it was).
        local sel, scroll = d.sel, d.scroll
        d.sel, d.scroll = d.menuSel or 1, 0
        ctx:list(list, x + 6, y + h - mh - 4, w - 12, mh)
        d.menuSel, d.sel, d.scroll = d.sel, sel, scroll
    end
end

KnoxMobile.Apps.register({
    id = "photos", name = "Photos", icon = ICONS .. "photos.png", glyph = ICONS .. "photos_glyph.png",
    label = function() return T("IGUI_KnoxMobile_AppPhotos", "Photos") end,
    short = function() return T("IGUI_KnoxMobile_AppShortPhotos", "Photos") end,
    families = FAMILIES, drain = "screen", needsService = false, order = 55,
    available = function(model) return Photos.fits(model) end,
    render = function(ctx, x, y, w, h)
        local list, d = roll(ctx), ctx.data
        if d.open and list[d.open] then
            drawPhoto(ctx, list[d.open], d.open, #list, x, y, w, h)
            return
        end
        d.open, d.menu = nil, nil
        local spec = CameraSpec.forFamily(ctx.family)
        local mine = #(ctx.state.contents.photos or {})
        local take = T("IGUI_KnoxMobile_TakePhoto", "+ Take a photo")
        local items = { { label = take, value = spec and (mine .. "/" .. spec.max) or nil, minor = true } }
        for _, e in ipairs(list) do
            local mark = (e.photo.id and camera()) and "[*] " or ""
            items[#items + 1] = { label = mark .. Format.ellipsis(caption(e.photo), 34) }
        end
        ctx:list(items, x, y, w, h)
    end,
    onInput = function(ctx, ev)
        local d = ctx.data
        local list = roll(ctx)
        if d.open and list[d.open] then
            local entry = list[d.open]
            local acts = actions(ctx, entry)
            local back = ev.type == "key" and ev.key == "back"
            if d.menu then
                if back then d.menu = nil; return true end
                local saved = d.sel
                d.sel = d.menuSel or 1
                local chosen = ctx:listInput(ev, #acts)
                d.menuSel, d.sel = d.sel, saved
                if chosen then d.menu = nil; act(ctx, entry, acts[chosen].id) end
                return true
            end
            if back then
                d.open, d.keepBack = nil, false
            elseif #acts > 0 and ((ev.type == "key" and ev.key == "select") or ev.type == "tap") then
                d.menu, d.menuSel = true, 1
            elseif ev.type == "tap" then
                d.open, d.keepBack = nil, false
            elseif ev.type == "key" and (ev.key == "left" or ev.key == "up") and d.open > 1 then
                d.open = d.open - 1
            elseif ev.type == "key" and (ev.key == "right" or ev.key == "down") and d.open < #list then
                d.open = d.open + 1
            end
            return true
        end
        local chosen = ctx:listInput(ev, #list + 1)
        if chosen == 1 then
            local spec = CameraSpec.forFamily(ctx.family)
            if camera() and spec then
                ctx:open("camera")
            elseif spec and #(ctx.state.contents.photos or {}) >= spec.max then
                ctx:toast(T("IGUI_KnoxMobile_PhotoFull", "Memory full: delete photos in Photos"))
            else
                snapshot(ctx)
            end
        elseif chosen then
            d.open, d.keepBack = chosen - 1, true
        end
        return true
    end,
})
