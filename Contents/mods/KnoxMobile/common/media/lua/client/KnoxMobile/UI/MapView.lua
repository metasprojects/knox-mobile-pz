-- Client: the Map app's live map (0.1.1). The game's own world map (the renderer its minimap uses) drawn over the
-- phone's screen, centred on you, with the places the phone knows marked on it. With service the whole map loads;
-- with none it shows only where you've been (HideUnvisited), so the map gets worse as the towers die. Meta,
-- 2026-10-21: the old dot map "doesn't actually function and if it does, it's not great".
--
-- The view is a child of the phone panel, made on first use and kept hidden while the Map isn't on screen: it hides
-- itself when the app stops drawing it (a call screen, the home screen, the phone closing).
local Util = require "KnoxMobile/Game/Util"

local MapView = { level = 17.5 }
KnoxMobile.MapView = MapView

local MIN_ZOOM, MAX_ZOOM = 13, 20
local STALE_MS = 200

local Class -- made on first use: tests and previews have no world map
local function class()
    if Class then return Class end
    Class = ISUIElement:derive("KnoxMobileMapView")

    function Class:instantiate()
        self.javaObject = UIWorldMap.new(self)
        self.mapAPI = self.javaObject:getAPIv3()
        self.mapAPI:setMapItem(MapItem.getSingleton())
        self.mapAPI:setMaxZoom(MAX_ZOOM)
        self.javaObject:setX(self.x)
        self.javaObject:setY(self.y)
        self.javaObject:setWidth(self.width)
        self.javaObject:setHeight(self.height)
        MapUtils.initDefaultMapData(self)
        self.mapAPI:setBoundsFromWorld()
        MapUtils.initDefaultStyleV1(self)
        self.mapAPI:setBoolean("ImagePyramid", false)
        self.mapAPI:setBoolean("Players", true)
        self.mapAPI:setBoolean("Symbols", false)
        self.mapAPI:setBoolean("MiniMapSymbols", true)
        self.mapAPI:setZoom(MapView.level)
    end

    function Class:prerender()
        if getTimestampMs() - (self.shownAt or 0) > STALE_MS then self:setVisible(false); return end
        local p = getPlayer()
        if not p then return end
        local at = p:getVehicle() or p
        self.mapAPI:centerOn(at:getX(), at:getY())
    end

    -- The places the phone knows, on top of the map: a dark-edged dot, held at the edge when off the map.
    function Class:render()
        local api = self.mapAPI
        for _, p in ipairs(self.places or {}) do
            local wx, wy = p.x + 0.5, p.y + 0.5
            local ux = math.max(4, math.min(self.width - 5, api:worldToUIX(wx, wy)))
            local uy = math.max(4, math.min(self.height - 5, api:worldToUIY(wx, wy)))
            local c = p.color or { 1, 1, 1 }
            self:drawRect(ux - 4, uy - 4, 9, 9, 0.9, 0.05, 0.05, 0.05)
            self:drawRect(ux - 3, uy - 3, 7, 7, 1, c[1], c[2], c[3])
        end
        if self.note and self.note ~= "" then
            local lh = getTextManager():getFontHeight(UIFont.Small)
            self:drawRect(0, 0, self.width, lh + 2, 0.7, 0, 0, 0)
            self:drawText(self.note, 3, 1, 1, 0.85, 0.5, 1, UIFont.Small)
        end
    end

    function Class:onMouseWheel(del)
        MapView.zoomBy(self, -del * 0.5)
        return true
    end

    -- A click on the map stays on the map (it would otherwise start dragging the phone).
    function Class:onMouseDown() return true end
    function Class:onMouseUp() return true end

    return Class
end

function MapView.zoomBy(view, step)
    if not (view and view.mapAPI) then return end
    MapView.level = math.max(MIN_ZOOM, math.min(MAX_ZOOM, MapView.level + step))
    view.mapAPI:setZoom(MapView.level)
end

-- Shows the map over the screen rect (x, y, w, h in the app's own coordinates). places: { x, y, color }; note: a line
-- across the top, or nil; service: whether the phone can load map data. Returns the view, or nil where no world map
-- can be made (the app then falls back to its list).
function MapView.show(ctx, x, y, w, h, places, note, service)
    local panel = ctx.panel
    local view = panel.knoxMapView
    if view == false then return nil end
    if not view then
        local ok, made = pcall(function()
            local v = class():new(ctx.sx + x, ctx.sy + y, w, h)
            v:initialise()
            v:instantiate()
            panel:addChild(v)
            return v
        end)
        if not ok then
            Util.log("map: the world map isn't available here:", tostring(made))
            panel.knoxMapView = false
            return nil
        end
        view = made
        panel.knoxMapView = view
    end
    local px, py = ctx.sx + x, ctx.sy + y
    if view.x ~= px or view.y ~= py or view.width ~= w or view.height ~= h then
        view:setX(px); view:setY(py); view:setWidth(w); view:setHeight(h)
    end
    view.shownAt = getTimestampMs()
    view.places, view.note = places, note
    if view.service ~= service then
        view.service = service
        view.mapAPI:setBoolean("HideUnvisited", not service)
    end
    if not view:isVisible() then view:setVisible(true) end
    return view
end

function MapView.hide(panel)
    local view = panel and panel.knoxMapView
    if view then view:setVisible(false) end
end

return MapView
