-- Client: the News app (0.3.0, Core/News has the wire). The station's headlines up to today, newest first, each with
-- its date. It needs service and a carrier still on the air; after that it keeps the last stories it had.
local Util = require "KnoxMobile/Game/Util"
local News = require "KnoxMobile/Core/News"
local Lang = require "KnoxMobile/Core/Lang"
local Photos = require "KnoxMobile/Core/Photos"
local WorldModel = require "KnoxMobile/Game/WorldModel"

local T = Util.text
local ICONS = "media/ui/KnoxMobile/apps/"
local MONTHS = { [6] = function() return T("IGUI_KnoxMobile_NewsJun", "Jun") end,
    [7] = function() return T("IGUI_KnoxMobile_NewsJul", "Jul") end }

-- The day the feed last updated, kept per session (the wire stops when the carrier does).
local lastDay = nil
-- Listeners' messages on the air (after 0.3.0, server/Wknx.lua), asked for when the app opens.
local onAir = {}
require("KnoxMobile/Game/Net").onClient("wknxBoard", function(args) onAir = args.messages or {} end)

local function stamp(day)
    local m, d = Photos.date(day)
    if day > 22 then m, d = 8, day - 22 end
    local month = MONTHS[m] and MONTHS[m]() or tostring(m)
    return month .. " " .. d
end

KnoxMobile.Apps.register({
    id = "news", name = "News", icon = ICONS .. "news.png", glyph = ICONS .. "news_glyph.png",
    label = function() return T("IGUI_KnoxMobile_AppNews", "News") end,
    short = function() return T("IGUI_KnoxMobile_AppShortNews", "News") end,
    families = { "Stylus", "ModernAndroid", "ModernPear" }, drain = "screen", needsService = false, order = 57,
    render = function(ctx, x, y, w, h)
        local lh = ctx:lineHeight()
        local day = math.floor(Util.sinceOutbreak())
        local live = WorldModel.carrierUp() and WorldModel.locatePlayer(ctx.player, ctx.model,
            ctx.player:getModData().KnoxMobilePasswords or {}).network ~= nil
        if live then lastDay = day end
        local top = y + 2
        ctx:text(News.STATION, x + 3, top, ctx.style.accent)
        top = top + lh + 2
        if not lastDay then
            for _, l in ipairs(ctx:wrap(T("IGUI_KnoxMobile_NewsNone", "No service: no stories yet"), w - 8)) do
                ctx:text(l, x + 3, top); top = top + lh
            end
            return
        end
        if not live then
            ctx:text(T("IGUI_KnoxMobile_NewsStale", "Not updating"), x + 3, top)
            top = top + lh + 2
        end
        if #onAir > 0 then
            for _, l in ipairs(ctx:wrap(T("IGUI_KnoxMobile_NewsOnAir", "On the air (call %1):", News.REQUEST_LINE), w - 6)) do
                ctx:text(l, x + 3, top, ctx.style.accent)
                top = top + lh
            end
            for i = #onAir, math.max(1, #onAir - 2), -1 do
                for _, l in ipairs(ctx:wrap(onAir[i].name .. ": " .. onAir[i].text, w - 10)) do
                    if top > y + h - lh then break end
                    ctx:text(l, x + 6, top)
                    top = top + lh
                end
            end
            top = top + 2
        end
        for _, it in ipairs(News.feed(lastDay, 8)) do
            if top > y + h - lh * 2 then break end
            ctx:text(stamp(it.day), x + 3, top, ctx.style.accent)
            top = top + lh
            for _, l in ipairs(ctx:wrap(Lang.t(it.text), w - 10)) do
                if top > y + h - lh then break end
                ctx:text(l, x + 6, top)
                top = top + lh
            end
            top = top + 2
        end
    end,
    onOpen = function(ctx) require("KnoxMobile/Game/Net").toServer(ctx.player, "wknxBoard", {}) end,
    onInput = function() return true end,
})
