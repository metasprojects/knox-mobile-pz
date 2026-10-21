-- Knox Mobile's public API for other mods (spec §12.2): the app slot and the screen slot.
--
--   KnoxMobile.Apps.register{ id, name, icon, families = { "ModernAndroid", ... }, drain = "screen",
--       needsService = false, order = 50, onOpen = fn(ctx), render = fn(ctx, x, y, w, h),
--       onInput = fn(ctx, ev), onClose = fn(ctx) }
--   KnoxMobile.ScreenSource.register{ id, priority, isAvailable = fn(phone), render = fn(ctx, x, y, w, h), onInput = fn(ctx, ev) }
--
--   KnoxMobile.PhoneModels.register{ id, name, family, connector, year, colors, ... } (see Phones/*.lua)
--
-- ctx (client only) draws with ctx:text, ctx:rect, ctx:list and knows ctx.phone, ctx.state, ctx.model, ctx.style.
-- ev is { type = "key", key = "up"|"down"|"left"|"right"|"select"|"back"|"0".."9" } or
-- { type = "tap", x, y } (screen pixels) or { type = "wheel", delta }.
local Apps = require "KnoxMobile/Core/Apps"
local ScreenSource = require "KnoxMobile/Core/ScreenSource"
local Util = require "KnoxMobile/Game/Util"
local Phones = require "KnoxMobile/Game/Phones"

KnoxMobile = KnoxMobile or {}

local apps = Apps.new()
local screens = ScreenSource.new()

KnoxMobile.Apps = {
    register = function(def)
        local ok, err = apps:register(def)
        if not ok then Util.log("app not registered:", err) end
        return ok, err
    end,
    get = function(id) return apps:get(id) end,
    forFamily = function(familyId, model) return apps:forFamily(familyId, model) end,
    safeCall = Apps.safeCall,
}

KnoxMobile.ScreenSource = {
    register = function(def)
        local ok, err = screens:register(def)
        if not ok then Util.log("screen source not registered:", err) end
        return ok, err
    end,
    active = function(phone) return screens:active(phone) end,
}
KnoxMobile.Screen = KnoxMobile.ScreenSource -- short name used inside the mod

-- Other mods can add phone models (spec §12.2, §12.3). They also ship the item scripts, one item per
-- color named "<module>.<id>_<color without spaces>", and their frame art.
KnoxMobile.PhoneModels = {
    register = function(def)
        local ok, err = Phones.registry:addPhone(def)
        if not ok then Util.log("phone model not registered:", err) end
        return ok, err
    end,
    get = function(id) return Phones.registry:getPhone(id) end,
}

return KnoxMobile
