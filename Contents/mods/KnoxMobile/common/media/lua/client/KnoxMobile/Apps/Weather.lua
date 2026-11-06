-- Client: the Weather app (0.3.0). With service, the carrier's three-day forecast (the game's own forecaster, from the
-- server: CarrierAlerts "weather"). The Kaiju Rockface's barometer works anywhere: no forecast, only whether the
-- pressure says a storm is coming. On the smartphones, the 5320 and the rugged phone.
local Util = require "KnoxMobile/Game/Util"
local Net = require "KnoxMobile/Game/Net"
local Registry = require "KnoxMobile/Core/Registry"
local WorldModel = require "KnoxMobile/Game/WorldModel"

local T = Util.text
local ICONS = "media/ui/KnoxMobile/apps/"

KnoxMobile.Weather = KnoxMobile.Weather or { days = nil }
Net.onClient("weather", function(args) KnoxMobile.Weather.days = type(args.days) == "table" and args.days or nil end)

local function sky(d)
    if not d then return T("IGUI_KnoxMobile_WeatherUnknown", "No forecast") end
    if d.blizzard then return T("IGUI_KnoxMobile_WeatherBlizzard", "Blizzard") end
    if d.tropical then return T("IGUI_KnoxMobile_WeatherTropical", "Tropical storm") end
    if d.storm then return T("IGUI_KnoxMobile_WeatherStorm", "Thunderstorms") end
    return T("IGUI_KnoxMobile_WeatherFair", "Fair")
end

-- Kentucky in 1993 reads Fahrenheit.
local function high(d)
    if not (d and d.maxTemp) then return "" end
    return T("IGUI_KnoxMobile_WeatherHigh", "high %1 F", math.floor(d.maxTemp * 9 / 5 + 32 + 0.5))
end

local DAYS = {
    function() return T("IGUI_KnoxMobile_WeatherToday", "Today") end,
    function() return T("IGUI_KnoxMobile_WeatherTomorrow", "Tomorrow") end,
    function() return T("IGUI_KnoxMobile_WeatherDayAfter", "Day after") end,
}

local function inService(ctx)
    local located = WorldModel.locatePlayer(ctx.player, ctx.model, ctx.player:getModData().KnoxMobilePasswords or {})
    return located and located.network ~= nil
end

KnoxMobile.Apps.register({
    id = "weather", name = "Weather", icon = ICONS .. "weather.png", glyph = ICONS .. "weather_glyph.png",
    label = function() return T("IGUI_KnoxMobile_AppWeather", "Weather") end,
    short = function() return T("IGUI_KnoxMobile_AppShortWeather", "Weather") end,
    families = { "ColorFeature", "Stylus", "ModernAndroid", "ModernPear" }, drain = "screen", needsService = false, order = 58,
    available = function(model)
        return Registry.hasExtra(model, "barometer") or model.family == "Stylus" or model.family == "ModernAndroid"
            or model.family == "ModernPear"
    end,
    onOpen = function(ctx) Net.toServer(ctx.player, "weather", {}) end,
    render = function(ctx, x, y, w, h)
        local lh = ctx:lineHeight()
        local days = KnoxMobile.Weather.days
        local top = y + 2
        if inService(ctx) and days then
            for i = 1, 3 do
                local d = days[i] or nil
                if d == false then d = nil end
                ctx:text(DAYS[i](), x + 3, top, ctx.style.accent)
                top = top + lh
                ctx:text(sky(d) .. (d and d.maxTemp and (", " .. high(d)) or ""), x + 8, top)
                top = top + lh + 3
                if top > y + h - lh then break end
            end
            return
        end
        if Registry.hasExtra(ctx.model, "barometer") then
            -- The barometer: the pressure falls ahead of a storm.
            local soon = days and ((days[1] and days[1].storm) or (days[2] and days[2].storm))
            ctx:text(T("IGUI_KnoxMobile_WeatherBarometer", "Barometer"), x + 3, top, ctx.style.accent)
            top = top + lh + 2
            local msg = soon and T("IGUI_KnoxMobile_WeatherFalling", "Pressure falling: a storm within a day")
                or T("IGUI_KnoxMobile_WeatherSteady", "Pressure steady")
            for _, l in ipairs(ctx:wrap(msg, w - 8)) do ctx:text(l, x + 3, top); top = top + lh end
            return
        end
        for _, l in ipairs(ctx:wrap(T("IGUI_KnoxMobile_WeatherNoService", "No service: no forecast"), w - 8)) do
            ctx:text(l, x + 3, top); top = top + lh
        end
    end,
    onInput = function() return true end,
})
