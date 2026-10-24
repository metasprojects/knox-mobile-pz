-- Client: item tooltips that show live phone state (spec §4.4, §6.6): condition, wetness and SIM as text, and the
-- charge as green fill bars under the text (phones, power banks, spare batteries; 2026-10-18: bars, not
-- "NN percent"). The right charger shows only once the player has read that family's manual.
local Phones = require "KnoxMobile/Game/Phones"
local Registry = require "KnoxMobile/Core/Registry"
local Power = require "KnoxMobile/Core/Power"
local Util = require "KnoxMobile/Game/Util"
local Tick = require "KnoxMobile/Game/Tick"

local T = Util.text
local Tooltip = { nextMs = 0 }
KnoxMobile.Tooltip = Tooltip

local REFRESH_MS = 2000

local CONNECTOR_NAMES = { Pin = "Pin", Flat = "Flat", MicroUSB = "Micro-USB", PearPlug = "Pear Plug", USBC = "USB-C" }

local function knows(player, family)
    local md = player:getModData()
    return type(md.KnoxMobileKnown) == "table" and md.KnoxMobileKnown[family] == true
end

function Tooltip.chargerHint(model)
    local c = CONNECTOR_NAMES[model.connector] or model.connector
    if Registry.isUsbConnector(model.connector) then
        return T("IGUI_KnoxMobile_TipUsbSource", "Charges with a %1 cable and any USB power source", c)
    end
    return T("IGUI_KnoxMobile_TipPlug", "Charges with a %1 charger (wall or car)", c)
end

function Tooltip.phoneText(player, item)
    local state, model = Phones.get(item)
    if not state then return nil end
    local parts = {}
    if state.owner and state.owner.pending then
        -- Short, and without the charger line: the long one ran past its box (r8).
        return T("IGUI_KnoxMobile_TipUnknownShort", "Somebody's phone. Battery unknown.")
    elseif state.plug then
        parts[#parts + 1] = T("IGUI_KnoxMobile_TipPhoneCharging", "Charging")
    end
    if state.condition ~= "mint" then parts[#parts + 1] = Util.word("Condition", state.condition) end
    if state.wetness ~= "dry" then parts[#parts + 1] = Util.word("Wet", state.wetness) end
    if state.wrapped then parts[#parts + 1] = T("IGUI_KnoxMobile_TipWrapped", "in a plastic bag") end
    if state.look.case then parts[#parts + 1] = T("IGUI_KnoxMobile_TipInCase", "in a %1", Util.word("Case", state.look.case)) end
    if state.sim then
        parts[#parts + 1] = state.sim.number and T("IGUI_KnoxMobile_TipSim", "SIM %1", state.sim.number)
            or T("IGUI_KnoxMobile_BlankSim", "blank SIM")
    end
    if state.security.locked then parts[#parts + 1] = T("IGUI_KnoxMobile_TipLocked", "locked") end
    local text = #parts > 0 and (table.concat(parts, ", ") .. ".") or ""
    if text ~= "" then text = text:sub(1, 1):upper() .. text:sub(2) .. " " end
    if knows(player, model.family) then
        text = text .. Tooltip.chargerHint(model) .. "."
    else
        text = text .. T("IGUI_KnoxMobile_TipNoManual", "Read its manual to learn what charges it.")
    end
    return text
end

-- The fill bars for an item: { { label, fraction 0..1, kind } }, or nil for items without a charge.
function Tooltip.bars(item)
    if not item then return nil end
    local state = Phones.isPhone(item) and Phones.get(item)
    if state then
        if state.owner and state.owner.pending then return nil end
        return {
            { label = T("IGUI_KnoxMobile_BarBattery", "Battery"), fraction = state.battery.charge / 100, kind = "charge" },
            { label = T("IGUI_KnoxMobile_BarHealth", "Health"), fraction = state.battery.health / 100, kind = "health" },
        }
    end
    if item:getFullType() == "KnoxMobile.PowerBank" then
        local cap = Power.newBankStore(Util.powerSettings())
        return { { label = T("IGUI_KnoxMobile_BarCharge", "Charge"), fraction = Phones.bankStore(item) / cap, kind = "charge" } }
    end
    if (Phones.accessory(item) or {}).kind == "spareBattery" then
        return { { label = T("IGUI_KnoxMobile_BarCharge", "Charge"), fraction = Phones.spareCharge(item) / 100, kind = "charge" } }
    end
    return nil
end

local ROW_H, BAR_H = 16, 8
local function barColor(bar)
    local f = bar.fraction
    if bar.kind == "health" and f < 0.6 then
        if f >= 0.3 then return 0.9, 0.75, 0.2 end
        return 0.9, 0.3, 0.25
    end
    if f <= 0.15 then return 0.9, 0.3, 0.25 end
    return 0.3, 0.82, 0.35
end

-- Drawn under the game's own tooltip box, in its colors.
function Tooltip.drawBars(tip)
    local bars = Tooltip.bars(tip.item)
    if not bars then return end
    local tm = getTextManager()
    local labelW = 0
    for _, b in ipairs(bars) do labelW = math.max(labelW, tm:MeasureStringX(UIFont.Small, b.label)) end
    local w = math.max(tip.width, labelW + 110)
    local y0, h = tip.height, #bars * ROW_H + 6
    local bg, border = tip.backgroundColor, tip.borderColor
    tip:drawRect(0, y0, w, h, bg.a, bg.r, bg.g, bg.b)
    tip:drawRectBorder(0, y0 - 1, w, h + 1, border.a, border.r, border.g, border.b)
    local fh = tm:getFontHeight(UIFont.Small)
    for i, b in ipairs(bars) do
        local y = y0 + 3 + (i - 1) * ROW_H
        tip:drawText(b.label, 6, y + math.floor((ROW_H - fh) / 2), 0.85, 0.85, 0.85, 1, UIFont.Small)
        local bx, bw, by = 6 + labelW + 8, w - (6 + labelW + 8) - 8, y + math.floor((ROW_H - BAR_H) / 2)
        local f = math.max(0, math.min(1, b.fraction))
        tip:drawRect(bx, by, bw, BAR_H, 0.9, 0.12, 0.12, 0.12)
        local r, g, bl = barColor(b)
        if f > 0 then tip:drawRect(bx, by, math.max(1, math.floor(bw * f + 0.5)), BAR_H, 1, r, g, bl) end
        tip:drawRectBorder(bx, by, bw, BAR_H, 0.6, 0.5, 0.5, 0.5)
    end
end

-- The game's inventory tooltip draws the item's text; the bars go right under it.
function Tooltip.hook()
    if Tooltip.hooked or not ISToolTipInv then return end
    Tooltip.hooked = true
    local render = ISToolTipInv.render
    function ISToolTipInv:render()
        render(self)
        if ISContextMenu.instance and ISContextMenu.instance.visibleCheck then return end
        local ok, err = pcall(Tooltip.drawBars, self)
        if not ok and not Tooltip.failed then
            Tooltip.failed = true
            Util.log("tooltip bars failed:", err)
        end
    end
end
Tooltip.hook()
Events.OnGameBoot.Add(Util.safe("tooltip hook", Tooltip.hook))

local function refresh(player)
    local inv = player:getInventory()
    for _, item in ipairs(Phones.inventoryPhones(player)) do
        local text = Tooltip.phoneText(player, item)
        if text then item:setTooltip(text) end
    end
    local banks = inv:getAllTypeRecurse("KnoxMobile.PowerBank")
    for i = 0, banks:size() - 1 do
        local b = banks:get(i)
        local plugged = b:getModData().KnoxMobileBankPlug
        b:setTooltip(plugged and (T("IGUI_KnoxMobile_TipPhoneCharging", "Charging") .. ".")
            or T("IGUI_KnoxMobile_TipBankUse", "Charges a phone from its own cable."))
    end
    local spares = inv:getAllEvalRecurse(function(it) return (Phones.accessory(it) or {}).kind == "spareBattery" end)
    for i = 0, spares:size() - 1 do
        local s = spares:get(i)
        Phones.spareCharge(s) -- a found spare gets its charge now, so the bar shows one
        s:setTooltip(s:getScriptItem():getTooltip()) -- older builds wrote "Spare battery NN percent" here
    end
end

Tick.add("phone tooltips", function()
    local t = getTimestampMs()
    if t < Tooltip.nextMs then return end
    Tooltip.nextMs = t + REFRESH_MS
    local player = getPlayer()
    if player then refresh(player) end
end)

return Tooltip
