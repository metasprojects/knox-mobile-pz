-- Client: the Compass app (0.3.0) on the Kaiju Rockface and the phones with GPS. Which way you face, and the way to
-- the nearest job you took (Apps/Jobs.lua): a direction and a distance, never a route. Needs no service.
local Util = require "KnoxMobile/Game/Util"
local Registry = require "KnoxMobile/Core/Registry"
local CellSites = require "KnoxMobile/Core/CellSites"
local SocialText = require "KnoxMobile/Game/SocialText"

local T = Util.text
local ICONS = "media/ui/KnoxMobile/apps/"

-- CellSites.compass says "ne"; SocialText's words are keyed "NE" ("here" has no word: show the nearest).
local function word(code, short)
    if code == "here" then return T("IGUI_KnoxMobile_CompassHere", "here") end
    return SocialText.dir(string.upper(code), short)
end

local function distance(d)
    if d < 1000 then return T("IGUI_KnoxMobile_DistM", "%1 m", math.floor(d / 10 + 0.5) * 10) end
    return T("IGUI_KnoxMobile_DistKm", "%1 km", string.format("%.1f", d / 1000))
end

local function nearestJob(px, py)
    local best, bestD = nil, math.huge
    for _, j in ipairs(KnoxMobile.JobsList and KnoxMobile.JobsList.list or {}) do
        if j.state == "active" and j.place then
            local dx, dy = j.place.x - px, j.place.y - py
            local d = math.sqrt(dx * dx + dy * dy)
            if d < bestD then best, bestD = j, d end
        end
    end
    return best, bestD
end

KnoxMobile.Apps.register({
    id = "compass", name = "Compass", icon = ICONS .. "compass.png", glyph = ICONS .. "compass_glyph.png",
    label = function() return T("IGUI_KnoxMobile_AppCompass", "Compass") end,
    short = function() return T("IGUI_KnoxMobile_AppShortCompass", "Compass") end,
    families = { "ColorFeature", "Stylus", "ModernAndroid", "ModernPear" }, drain = "screen", needsService = false, order = 59,
    available = function(model) return Registry.hasExtra(model, "compass") or Registry.hasExtra(model, "gps") end,
    render = function(ctx, x, y)
        local lh = ctx:lineHeight()
        local p = ctx.player
        local f = p:getForwardDirection()
        local px, py = p:getX(), p:getY()
        local facing = CellSites.compass(px, py, px + f:getX() * 10, py + f:getY() * 10)
        local top = y + 2
        ctx:text(T("IGUI_KnoxMobile_CompassFacing", "Facing"), x + 3, top, ctx.style.accent)
        top = top + lh
        ctx:text(word(facing), x + 8, top)
        top = top + lh + 4
        local job, d = nearestJob(px, py)
        if job then
            ctx:text(T("IGUI_KnoxMobile_CompassJob", "Nearest job"), x + 3, top, ctx.style.accent)
            top = top + lh
            local where = word(CellSites.compass(px, py, job.place.x, job.place.y), true) .. ", " .. distance(d)
            ctx:text(where, x + 8, top)
        end
    end,
    onInput = function() return true end,
})
