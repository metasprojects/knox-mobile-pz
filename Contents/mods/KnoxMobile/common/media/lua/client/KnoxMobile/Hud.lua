-- Client: the phone's status on screen (after 0.3.0; Survivor PDA's players like a HUD, docs/research/
-- SURVIVOR_PDA_STUDY.md). While the phone is put away: unread texts, bars and battery of the phone you'd pick up, top
-- right, small. Options > Mods > Knox Mobile > Phone status on screen.
local Phones = require "KnoxMobile/Game/Phones"
local Util = require "KnoxMobile/Game/Util"
local WorldModel = require "KnoxMobile/Game/WorldModel"

local T = Util.text
local Hud = { panel = nil, data = nil, nextAt = 0, EVERY_MS = 2000 }
KnoxMobile.Hud = Hud

-- What to show for this player: { unread, bars, battery } of their first working phone with a SIM, or nil.
function Hud.read(player)
    for _, item in ipairs(Phones.inventoryPhones(player)) do
        local st, model = Phones.get(item)
        if st and st.power and st.power.on and st.sim then
            local unread = 0
            for _, c in ipairs(st.contents.texts or {}) do
                for _, m in ipairs(c.messages or {}) do if m.unread then unread = unread + 1 end end
            end
            local located = WorldModel.locatePlayer(player, model, player:getModData().KnoxMobilePasswords or {})
            return { unread = unread, bars = located.network and (located.bars or 0) or 0,
                battery = math.floor(st.battery.charge or 0) }
        end
    end
    return nil
end

function Hud.text(d)
    if not d then return nil end
    local parts = {}
    if d.unread > 0 then parts[#parts + 1] = T("IGUI_KnoxMobile_HudUnread", "%1 new", d.unread) end
    parts[#parts + 1] = d.bars > 0 and string.rep("|", d.bars) or T("IGUI_KnoxMobile_HudNoService", "No service")
    parts[#parts + 1] = d.battery .. "%"
    return table.concat(parts, "  ")
end

KnoxMobileHudPanel = ISUIElement:derive("KnoxMobileHudPanel")
local Panel = KnoxMobileHudPanel

function Panel:render()
    local text = Hud.text(Hud.data)
    if not text or (KnoxMobile.UI and KnoxMobile.UI.isOpen()) then return end
    local w = getTextManager():MeasureStringX(UIFont.Small, text) + 12
    local x = self.width - w
    self:drawRect(x, 0, w, 18, 0.45, 0, 0, 0)
    local unread = Hud.data and Hud.data.unread > 0
    self:drawText(text, x + 6, 2, unread and 1 or 0.85, unread and 0.85 or 0.85, unread and 0.3 or 0.85, 1, UIFont.Small)
end

-- Where the line goes (its top-left for a panel w wide): left of the single-player speed buttons when they show
-- (PC test 22t: 90 px from the right it covered them), else the top right, clear of the moodles.
function Hud.anchor(w)
    local ok, x, y = pcall(function()
        if isClient() then return nil end
        local sc = UIManager.getSpeedControls()
        if not (sc and sc:isVisible()) then return nil end
        return sc:getX(), sc:getY()
    end)
    if ok and type(x) == "number" and type(y) == "number" and x > w + 8 then return math.floor(x - w - 8), math.floor(y) end
    return getCore():getScreenWidth() - w - 90, 12
end

local function on()
    return KnoxMobile.Options and KnoxMobile.Options.hud and KnoxMobile.Options.hud()
end

require("KnoxMobile/Game/Tick").add("phone hud", function()
    local t = getTimestampMs()
    if t < Hud.nextAt then return end
    Hud.nextAt = t + Hud.EVERY_MS
    local p = getSpecificPlayer(0)
    Hud.data = (on() and p and not p:isDead()) and Hud.read(p) or nil
    if Hud.data and not Hud.panel then
        local w = 260
        local x, y = Hud.anchor(w)
        Hud.panel = Panel:new(x, y, w, 20)
        Hud.panel:initialise()
        Hud.panel:addToUIManager()
    elseif Hud.data and Hud.panel then
        -- The speed buttons move with the screen size (and come and go): follow them.
        local x, y = Hud.anchor(Hud.panel.width)
        if Hud.panel.x ~= x or Hud.panel.y ~= y then Hud.panel:setX(x); Hud.panel:setY(y) end
    elseif not Hud.data and Hud.panel then
        Hud.panel:removeFromUIManager()
        Hud.panel = nil
    end
end, 500)

return Hud
