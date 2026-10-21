-- Client: Map (R9 worklist, 2026-10-19), on the touch and smart phones. An offline map of what your phone knows: the
-- places your family's and the survivors' texts named (once those texts have reached you) and the nearest cell sites,
-- each with its distance and direction. A small dot map on top where the screen has room. Each row keeps its
-- distance and compass point (the name gives way); Enter opens the place in full (final test: names were cut, the
-- distance dropped and Enter did nothing).
local CellSites = require "KnoxMobile/Core/CellSites"
local TowerSites = require "KnoxMobile/Data/TowerSites"
local Net = require "KnoxMobile/Game/Net"
local Util = require "KnoxMobile/Game/Util"

local T = Util.text
local ICONS = "media/ui/KnoxMobile/apps/"
local FAMILIES = { "Stylus", "ModernAndroid", "ModernPear" }
local RANGE = 2500 -- tiles from the centre to the map's edge

-- The server answers what the player's story has revealed (Server.lua "mapPlaces").
Net.onClient("mapPlaces", function(args)
    KnoxMobile.Map = { places = type(args.places) == "table" and args.places or {}, at = getTimestampMs() }
end)

local function places(ctx)
    local out = {}
    for _, p in ipairs(KnoxMobile.Map and KnoxMobile.Map.places or {}) do
        out[#out + 1] = { kind = p.kind, name = p.name, x = p.x, y = p.y }
    end
    -- The three nearest cell sites, with their state.
    local px, py = ctx.player:getX(), ctx.player:getY()
    local sites = {}
    for _, s in ipairs(TowerSites.sites) do sites[#sites + 1] = s end
    table.sort(sites, function(a, b) return CellSites.distance(a, px, py) < CellSites.distance(b, px, py) end)
    for i = 1, math.min(3, #sites) do
        local s = sites[i]
        out[#out + 1] = { kind = "site", name = s.code .. " " .. (KnoxMobile.Coverage and KnoxMobile.Coverage.status(s) or ""),
            x = s.x, y = s.y }
    end
    return out
end

local LABEL = { family = "IGUI_KnoxMobile_MapFamily", stash = "IGUI_KnoxMobile_MapStash", site = "IGUI_KnoxMobile_MapSite" }
local ENGLISH = { family = "Family: %1", stash = "Survivor: %1", site = "Cell site %1" }
local DOT = { family = { 1, 0.85, 0.2 }, stash = { 1, 0.45, 0.3 }, site = { 0.4, 0.7, 1 } }

local function drawMap(ctx, list, x, y, w, h)
    ctx:rect(x, y, w, h, { 0.07, 0.12, 0.09 }, 1)
    ctx:border(x, y, w, h, ctx.style.accent, 0.6)
    local cx, cy = x + w / 2, y + h / 2
    local px, py = ctx.player:getX(), ctx.player:getY()
    local scale = math.min(w, h) / 2 / RANGE
    for _, p in ipairs(list) do
        local dx, dy = (p.x - px) * scale, (p.y - py) * scale
        local edge = math.min(w / 2 - 3, h / 2 - 3)
        local far = math.max(math.abs(dx), math.abs(dy))
        if far > edge then dx, dy = dx * edge / far, dy * edge / far end
        local c = DOT[p.kind] or { 1, 1, 1 }
        ctx:rect(cx + dx - 2, cy + dy - 2, 5, 5, c, far > edge and 0.5 or 1)
    end
    ctx:rect(cx - 2, cy - 2, 5, 5, { 1, 1, 1 }, 1)
    ctx:text("N", cx, y + 1, ctx.style.accent, nil, "center")
end

-- "1.2 km NE", "340 m S", "here".
local function short(p, px, py)
    local code = CellSites.compass(px, py, p.x + 0.5, p.y + 0.5)
    if code == "here" then return T("IGUI_KnoxMobile_SiteHere", "right here") end
    local d = CellSites.distance(p, px, py)
    local dist = d < 1000 and T("IGUI_KnoxMobile_DistM", "%1 m", math.floor(d / 10 + 0.5) * 10)
        or T("IGUI_KnoxMobile_DistKm", "%1 km", string.format("%.1f", d / 1000))
    return dist .. " " .. code:upper()
end

local function label(p) return T(LABEL[p.kind], ENGLISH[p.kind], p.name) end

-- One place in full: its name wrapped, how far and which way, and what to do.
local function drawPlace(ctx, p, x, y, w, h)
    local lh = ctx:lineHeight()
    local px, py = ctx.player:getX(), ctx.player:getY()
    local lines = ctx:wrap(label(p), w - 8)
    local nameN = #lines
    local where = KnoxMobile.Coverage and KnoxMobile.Coverage.where(p, px, py) or short(p, px, py)
    for _, l in ipairs(ctx:wrap(where, w - 8)) do lines[#lines + 1] = l end
    for i, l in ipairs(lines) do
        if i * lh > h - lh then break end
        ctx:text(l, x + 4, y + 2 + (i - 1) * lh, i > nameN and ctx.style.accent or nil)
    end
    ctx:text(T("IGUI_KnoxMobile_MapBack", "Back: the list"), x + 4, y + h - lh - 1, ctx.style.accent)
end

KnoxMobile.Apps.register({
    id = "map", name = "Map", icon = ICONS .. "map.png", glyph = ICONS .. "map_glyph.png",
    label = function() return T("IGUI_KnoxMobile_AppMap", "Map") end,
    short = function() return T("IGUI_KnoxMobile_AppShortMap", "Map") end,
    families = FAMILIES, drain = "screen", needsService = false, order = 52,
    onOpen = function(ctx) Net.toServer(ctx.player, "mapPlaces", { phoneId = ctx.phone:getID() }) end,
    render = function(ctx, x, y, w, h)
        local list = places(ctx)
        local d = ctx.data
        if d.open and list[d.open] then drawPlace(ctx, list[d.open], x, y, w, h); return end
        d.open = nil
        local top = y
        if h > 180 then
            local mh = math.floor(math.min(w, h * 0.45))
            drawMap(ctx, list, x + 2, y, w - 4, mh)
            top = y + mh + 4
        end
        local px, py = ctx.player:getX(), ctx.player:getY()
        local items = {}
        for _, p in ipairs(list) do items[#items + 1] = { label = label(p), value = short(p, px, py) } end
        if #items == 0 then items[1] = { label = T("IGUI_KnoxMobile_MapEmpty", "Nothing marked yet") } end
        ctx:list(items, x, top, w, y + h - top)
    end,
    onInput = function(ctx, ev)
        local d = ctx.data
        if d.open then
            if (ev.type == "key" and ev.key == "back") or ev.type == "tap" then d.open, d.keepBack = nil, false end
            return true
        end
        local chosen = ctx:listInput(ev, #places(ctx))
        if chosen then d.open, d.keepBack = chosen, true end
        return true
    end,
})
