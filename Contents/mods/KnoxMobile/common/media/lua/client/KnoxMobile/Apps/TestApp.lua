-- Client: a test app and a test screen source, registered only through the public API (spec §12.2,
-- Round 1 done criterion 9). The debug menu turns the test source on and off. Both exist only in debug mode
-- (-debug): players never see a test app on their phones.
local Mod = require "KnoxMobile/Core/Mod"
local Util = require "KnoxMobile/Game/Util"

KnoxMobile.TestScreen = { enabled = false }

if not isDebugEnabled() then return end

KnoxMobile.Apps.register({
    id = "knoxtest", name = "Test App", order = 95, drain = "screen", needsService = false,
    short = function() return "Test" end, -- debug only, so no translation
    -- icon: a 64 px tile for icon grids; glyph (optional): a white pictogram that mono LCDs tint.
    icon = "media/ui/KnoxMobile/apps/knoxtest.png", glyph = "media/ui/KnoxMobile/apps/knoxtest_glyph.png",
    families = { "SegmentLCD", "MonoLCD", "ColorFeature", "Keyboard", "Stylus", "ModernAndroid", "ModernPear" },
    onOpen = function(ctx) ctx.data.taps = 0; Util.log("test app opened on", ctx.model.id) end,
    render = function(ctx, x, y, _, h)
        local lh = ctx:lineHeight()
        ctx:text("Test app", x + 3, y + 2, ctx.style.accent)
        if h > 2 * lh then ctx:text(ctx.model.name, x + 3, y + 2 + lh) end
        if h > 3 * lh then ctx:text("Taps: " .. tostring(ctx.data.taps or 0), x + 3, y + 2 + 2 * lh) end
        if h > 4 * lh then ctx:text("Battery " .. math.floor(ctx.state.battery.charge) .. " / 100", x + 3, y + 2 + 3 * lh) end
    end,
    onInput = function(ctx, ev)
        if ev.type == "tap" or (ev.type == "key" and ev.key == "select") then ctx.data.taps = (ctx.data.taps or 0) + 1 end
        return true
    end,
    onClose = function(ctx) Util.log("test app closed after", ctx.data.taps or 0, "taps") end,
})

KnoxMobile.Screen.register({
    id = "knoxtestsource", priority = 10,
    isAvailable = function() return KnoxMobile.TestScreen.enabled end,
    render = function(ctx, x, y, w, h)
        local t = Mod.floor(math.floor(getTimestampMs() / 500), 2)
        ctx:rect(x, y, w, h, t == 0 and { 0.5, 0.1, 0.5 } or { 0.1, 0.4, 0.5 })
        ctx:text("TEST SOURCE", x + w / 2, y + h / 2 - ctx:lineHeight(), { 1, 1, 1 }, nil, "center")
    end,
    onInput = function(_, ev)
        if ev.type == "key" and ev.key == "back" then KnoxMobile.TestScreen.enabled = false end
    end,
})
