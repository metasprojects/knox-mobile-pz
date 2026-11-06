-- Client: Map (R9 worklist, 2026-10-19; live map 0.1.1), on the touch and smart phones. The game's world map centred
-- on you (UI/MapView.lua), marked with what your phone knows: the places your family's and the survivors' texts named
-- (once those texts have reached you) and the nearest cell sites. Up and Down zoom; Enter lists the places with their
-- distance and direction, and Enter on one opens it in full. Where no world map can be made (tests, previews) the
-- app shows the list under a small dot map, as before.
local CellSites = require "KnoxMobile/Core/CellSites"
local TowerSites = require "KnoxMobile/Data/TowerSites"
local Net = require "KnoxMobile/Game/Net"
local Util = require "KnoxMobile/Game/Util"
local MapView = require "KnoxMobile/UI/MapView"
local Nav = require "KnoxMobile/Core/Nav"
local Lang = require "KnoxMobile/Core/Lang"

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
    -- After 0.3.0: what a search found comes first (Core/Nav).
    for _, p in ipairs(ctx.data.found or {}) do out[#out + 1] = { kind = "found", name = Lang.t(p.name), x = p.x, y = p.y } end
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

-- faction / raid: on a phone off a dead A-Life NPC (server FactionWire), its crew now and tonight's target.
-- camp (0.3.0): on a bandit clan's phone, where the clan camps.
local DOT = { family = { 1, 0.85, 0.2 }, stash = { 1, 0.45, 0.3 }, site = { 0.4, 0.7, 1 }, faction = { 0.75, 0.5, 1 },
    raid = { 1, 0.15, 0.15 }, home = { 0.55, 0.9, 0.55 },
    camp = { 0.95, 0.35, 0.65 }, job = { 1, 0.75, 0.35 },
    car = { 0.35, 0.95, 0.95 }, sentry = { 0.95, 0.95, 0.4 }, loc = { 0.4, 1, 0.5 },
    myphone = { 1, 1, 1 }, found = { 1, 1, 0.6 } }

local function drawMap(ctx, list, x, y, w, h, range)
    -- The phone in your hand is lit by the world: its copy is drawn brighter (PC re-check: dark at night).
    local held = KnoxMobile.Live ~= nil and KnoxMobile.Live.capturing == true
    ctx:rect(x, y, w, h, held and { 0.16, 0.27, 0.2 } or { 0.07, 0.12, 0.09 }, 1)
    ctx:border(x, y, w, h, held and ctx.style.fg or ctx.style.accent, 0.6)
    local cx, cy = x + w / 2, y + h / 2
    local px, py = ctx.player:getX(), ctx.player:getY()
    local r = range or RANGE
    local scale = math.min(w, h) / 2 / r
    -- Rings every 100 m, 500 m or 1 km, so distances read at a glance.
    local step = r <= 400 and 100 or (r <= 2500 and 500 or 1000)
    for d = step, r, step do
        local rr = math.floor(d * scale)
        ctx:border(cx - rr, cy - rr, rr * 2, rr * 2, held and ctx.style.fg or ctx.style.accent, held and 0.4 or 0.18)
    end
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

-- Literal keys, so tools/gen puts them in the translation files (0.3.0: before, Spanish showed these in English).
local LABELS = {
    family = function(n) return T("IGUI_KnoxMobile_MapFamily", "Family: %1", n) end,
    stash = function(n) return T("IGUI_KnoxMobile_MapStash", "Survivor: %1", n) end,
    site = function(n) return T("IGUI_KnoxMobile_MapSite", "Cell site %1", n) end,
    faction = function(n) return T("IGUI_KnoxMobile_MapFaction", "Their crew: %1", n) end,
    raid = function(n) return T("IGUI_KnoxMobile_MapRaid", "%1: tonight", n) end,
    home = function(n) return T("IGUI_KnoxMobile_MapHome", "Take home: %1's phone", n) end,
    camp = function(n) return T("IGUI_KnoxMobile_MapCamp", "Their camp: %1", n) end,
    job = function(n) return T("IGUI_KnoxMobile_MapJob", "Job for %1", n) end,
    car = function() return T("IGUI_KnoxMobile_MapCar", "Your car") end,
    sentry = function(n) return T("IGUI_KnoxMobile_MapSentry", "Your alarm %1", n) end,
    loc = function(n) return T("IGUI_KnoxMobile_MapLoc", "%1 was here", n) end,
    found = function(n) return n end,
    myphone = function() return T("IGUI_KnoxMobile_MapMyPhone", "Your phone") end,
}
local function label(p)
    local f = LABELS[p.kind]
    return f and f(p.name) or tostring(p.name)
end

-- One place in full: its name wrapped, how far and which way, and what to do.
local function drawPlace(ctx, p, x, y, w, h)
    local lh = ctx:lineHeight()
    local px, py = ctx.player:getX(), ctx.player:getY()
    local lines = ctx:wrap(label(p), w - 8)
    local where = KnoxMobile.Coverage and KnoxMobile.Coverage.where(p, px, py) or short(p, px, py)
    for _, l in ipairs(ctx:wrap(where, w - 8)) do lines[#lines + 1] = l end
    for i, l in ipairs(lines) do
        if i * lh > h - lh then break end
        ctx:text(l, x + 4, y + 2 + (i - 1) * lh, nil)
    end
    -- After 0.3.0: which way from where you face (Core/Nav), and Enter to be guided there with the phone away.
    local turn = KnoxMobile.NavGuide and KnoxMobile.NavGuide.say(ctx.player, p)
    -- The screen's text colour, not the accent: on the in-hand phone the dark blue accent read as black (PC test).
    if turn then ctx:text(turn, x + 4, y + h - lh * 3 - 3, ctx.style.fg) end
    local guiding = KnoxMobile.NavGuide and KnoxMobile.NavGuide.target == (tostring(p.x) .. "," .. tostring(p.y))
    ctx:text(guiding and T("IGUI_KnoxMobile_NavStop", "Enter: stop guiding") or T("IGUI_KnoxMobile_NavGo", "Enter: guide me there"),
        x + 4, y + h - lh * 2 - 2, ctx.style.fg)
    ctx:text(T("IGUI_KnoxMobile_MapBack", "Back: the list"), x + 4, y + h - lh - 1, ctx.style.fg)
end

KnoxMobile.Apps.register({
    id = "map", name = "Map", icon = ICONS .. "map.png", glyph = ICONS .. "map_glyph.png",
    label = function() return T("IGUI_KnoxMobile_AppMap", "Map") end,
    short = function() return T("IGUI_KnoxMobile_AppShortMap", "Map") end,
    families = FAMILIES, drain = "screen", needsService = false, order = 52,
    onOpen = function(ctx) Net.toServer(ctx.player, "mapPlaces", { phoneId = ctx.phone:getID() }) end,
    onClose = function(ctx) MapView.hide(ctx.panel) end,
    render = function(ctx, x, y, w, h)
        local list = places(ctx)
        local d = ctx.data
        if d.open and list[d.open] then MapView.hide(ctx.panel); drawPlace(ctx, list[d.open], x, y, w, h); return end
        d.open = nil
        local lh = ctx:lineHeight()
        -- The 3D phone in your hand (the live screen's copy): the game's world map draws outside the copy, so the
        -- held phone showed black and the map hung in the air (PC test 22a). The copy gets the app's own map, at the
        -- live map's zoom; the 2D phone keeps the world map.
        if not d.list and KnoxMobile.Live and KnoxMobile.Live.capturing then
            drawMap(ctx, list, x + 1, y, w - 2, h - lh - 3, MapView.range())
            local online = ctx.located ~= nil and ctx.located.network ~= nil and ctx.located.network ~= false
            if not online then
                ctx:text(T("IGUI_KnoxMobile_MapOffline", "No service: only places you've been"), x + 3, y + 1, ctx.style.accent)
            end
            d.live = true
            ctx:text(T("IGUI_KnoxMobile_MapKeys", "Up/Down: zoom  Enter: places"), x + 3, y + h - lh - 1, ctx.style.accent)
            return
        end
        -- The live map, unless the list was asked for (or there is no world map here).
        if not d.list then
            local marks = {}
            for _, p in ipairs(list) do marks[#marks + 1] = { x = p.x, y = p.y, color = DOT[p.kind] } end
            local service = ctx.located ~= nil and ctx.located.network ~= nil and ctx.located.network ~= false
            local note = not service and T("IGUI_KnoxMobile_MapOffline", "No service: only places you've been") or nil
            if MapView.show(ctx, x + 1, y, w - 2, h - lh - 3, marks, note, service) then
                d.live = true
                ctx:text(T("IGUI_KnoxMobile_MapKeys", "Up/Down: zoom  Enter: places"), x + 3, y + h - lh - 1, ctx.style.accent)
                return
            end
            d.live = false
        end
        MapView.hide(ctx.panel)
        local top = y
        if not d.live and h > 180 then
            local mh = math.floor(math.min(w, h * 0.45))
            drawMap(ctx, list, x + 2, y, w - 4, mh)
            top = y + mh + 4
        end
        local px, py = ctx.player:getX(), ctx.player:getY()
        local items = { { label = T("IGUI_KnoxMobile_NavSearch", "Search: pharmacy, gas, police, a town...") } }
        for _, p in ipairs(list) do items[#items + 1] = { label = label(p), value = short(p, px, py) } end
        if #items == 1 then items[2] = { label = T("IGUI_KnoxMobile_MapEmpty", "Nothing marked yet") } end
        ctx:list(items, x, top, w, y + h - top)
    end,
    onInput = function(ctx, ev)
        local d = ctx.data
        if d.open then
            if (ev.type == "key" and ev.key == "back") or ev.type == "tap" then d.open = nil; d.keepBack = d.live == true
            elseif ev.type == "key" and ev.key == "select" and KnoxMobile.NavGuide then
                local p = places(ctx)[d.open]
                if p then KnoxMobile.NavGuide.toggle(ctx.player, p) end
            end
            return true
        end
        -- On the live map: Up and Down zoom, Enter (or a tap) lists the places; Back leaves the app.
        if d.live and not d.list then
            if ev.type == "key" and ev.key == "up" then MapView.zoomBy(ctx.panel.knoxMapView or true, 0.5)
            elseif ev.type == "key" and ev.key == "down" then MapView.zoomBy(ctx.panel.knoxMapView or true, -0.5)
            elseif (ev.type == "key" and ev.key == "select") or ev.type == "tap" then d.list, d.keepBack = true, true end
            return true
        end
        -- The list: Back returns to the live map where there is one.
        if d.list and ev.type == "key" and ev.key == "back" then d.list, d.keepBack = nil, false; return true end
        local chosen = ctx:listInput(ev, #places(ctx) + 1)
        if chosen == 1 then
            ctx:askText(T("IGUI_KnoxMobile_NavSearchPrompt", "Search for:"), "", function(q)
                d.found = Nav.search(q, ctx.player:getX(), ctx.player:getY())
                if #d.found == 0 and KnoxMobile.Client then
                    KnoxMobile.Client.toast(T("IGUI_KnoxMobile_NavNone", "Nothing found for %1", q))
                end
            end, 40)
        elseif chosen then
            d.open, d.keepBack = chosen - 1, true
        end
        return true
    end,
})
