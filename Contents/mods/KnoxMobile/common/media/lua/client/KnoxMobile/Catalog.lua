-- Client: the Knox Mobile catalog (0.3.0), a dealer's handout with every phone in the county, 1993 to 2013. Read it
-- (right-click) to see the page: the same art as the Workshop's lineup (tools/workshop/lineup_030.py, in the game's
-- language). Reading it passes a little time, once an hour.
local Util = require "KnoxMobile/Game/Util"
local Lang = require "KnoxMobile/Core/Lang"

local T = Util.text
local Catalog = { panel = nil, ITEM = "KnoxMobile.Catalog" }
KnoxMobile.Catalog = Catalog

local PAGE = "media/ui/KnoxMobile/catalog/catalog_030%s.png"

KnoxMobileCatalogPanel = ISPanelJoypad:derive("KnoxMobileCatalogPanel")
local Panel = KnoxMobileCatalogPanel

function Panel:new(player, tex)
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local tw, th = tex and tex:getWidth() or 1600, tex and tex:getHeight() or 1075
    local scale = math.min(sw * 0.9 / tw, (sh * 0.9 - 30) / th, 1)
    local w, h = math.floor(tw * scale), math.floor(th * scale) + 30
    local o = ISPanelJoypad.new(self, (sw - w) / 2, (sh - h) / 2, w, h)
    o.player, o.tex, o.scale = player, tex, scale
    o.backgroundColor = { r = 0.07, g = 0.08, b = 0.1, a = 0.97 }
    o.borderColor = { r = 0.5, g = 0.5, b = 0.5, a = 1 }
    o.moveWithMouse = true
    return o
end

function Panel:prerender()
    ISPanelJoypad.prerender(self)
    if self.tex then
        self:drawTextureScaled(self.tex, 0, 0, self.width, self.height - 30, 1, 1, 1, 1)
    end
    self:drawTextCentre(T("IGUI_KnoxMobile_CatalogClose", "Click to close"), self.width / 2, self.height - 24, 0.7, 0.7, 0.7,
        1, UIFont.Small)
end

function Panel:close()
    self:removeFromUIManager()
    if Catalog.panel == self then Catalog.panel = nil end
end
function Panel:onMouseDown() self:close(); return true end
function Panel:onJoypadDown() self:close() end

function Catalog.read(player)
    if Catalog.panel then Catalog.panel:close() end
    local tex = getTexture(PAGE:format(Lang.code() == "es" and "_es" or "")) or getTexture(PAGE:format(""))
    local p = Panel:new(player, tex)
    p:initialise()
    p:addToUIManager()
    p:setAlwaysOnTop(true)
    Catalog.panel = p
    -- A little time passes pleasantly, once an hour of game time.
    local hour = math.floor(Util.nowMinutes() / 60)
    if Catalog.lastHour ~= hour and KnoxMobile.Client then
        Catalog.lastHour = hour
        KnoxMobile.Client.mood("BOREDOM", -6)
    end
    return p
end

Events.OnFillInventoryObjectContextMenu.Add(Util.safe("catalog menu", function(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    local item = ISInventoryPane.getActualItems(items)[1]
    if not (item and player and item:getFullType() == Catalog.ITEM) then return end
    context:addOption(T("IGUI_KnoxMobile_CatalogRead", "Read the catalog"), player, function() Catalog.read(player) end)
end))

return Catalog
