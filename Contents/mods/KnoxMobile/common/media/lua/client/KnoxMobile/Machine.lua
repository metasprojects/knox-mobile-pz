-- Client: answering machines on house phones (2026-10-12). Right-click a landline (vanilla's desk phones: tiles
-- whose CustomName is "Phone", the rotary and modern sets in location_business_office_generic_02) and "Play
-- messages": the tape Core/Machine makes from the phone's square, played back in a small window with the machine's
-- beep (the mod's own sounds) before each message. Nothing goes to the server and nothing is saved: the tape comes
-- from the square, so everyone hears the same one. The machine needs power, like the real thing.
require "ISUI/ISPanelJoypad"
local Mod = require "KnoxMobile/Core/Mod"
local Machine = require "KnoxMobile/Core/Machine"
local Messages = require "KnoxMobile/Data/Messages"
local Util = require "KnoxMobile/Game/Util"

local T = Util.text

local M = { pending = nil }
KnoxMobile.Machine = M

local WEEKDAYS = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }
local FIRST_MS = 1500   -- "You have 2 new messages", then the first beep
local GAP_MS = 5000     -- between messages
local WIDTH, HEIGHT = 440, 330
local REACH = 2.5       -- tiles from the phone to work the machine

local function clock(minute)
    local h, mi = math.floor(minute / 60), string.format("%02d", Mod.floor(minute, 60))
    local h12 = (Mod.floor(h, 12) == 0) and 12 or Mod.floor(h, 12)
    if h < 12 then return T("IGUI_KnoxMobile_MachineAM", "%1:%2 AM", h12, mi) end
    return T("IGUI_KnoxMobile_MachinePM", "%1:%2 PM", h12, mi)
end

-- What the machine says, in order: the count, each message (a header and its words), the end.
function M.lines(tape)
    local n = #tape.messages
    local out = { { text = n == 1 and T("IGUI_KnoxMobile_MachineOne", "You have one new message.")
        or T("IGUI_KnoxMobile_MachineMany", "You have %1 new messages.", n) } }
    -- Oldest first, each with its date (r8: weekdays alone read out of order across the two weeks).
    local list = {}
    for _, m in ipairs(tape.messages) do list[#list + 1] = m end
    table.sort(list, function(a, b) return a.day * 1440 + a.minute < b.day * 1440 + b.minute end)
    for i, m in ipairs(list) do
        local wd = WEEKDAYS[m.weekday + 1]
        local day = T("IGUI_KnoxMobile_Word_Weekday_" .. wd, Messages.words.Weekday[wd])
        -- Day 0 is July 9, 1993; the tapes reach back into June.
        local date = m.day >= -8 and T("IGUI_KnoxMobile_MachineJuly", "July %1", 9 + m.day)
            or T("IGUI_KnoxMobile_MachineJune", "June %1", 39 + m.day)
        out[#out + 1] = { beep = true, header = T("IGUI_KnoxMobile_MachineHeaderDate", "Message %1. %2, %3, %4.", i, day, date,
            clock(m.minute)),
            text = T("IGUI_KnoxMobile_Word_Machine_" .. m.code, Messages.words.Machine[m.code], m.args[1], m.args[2], m.args[3]) }
    end
    out[#out + 1] = { beep = true, text = T("IGUI_KnoxMobile_MachineEnd", "End of messages.") }
    return out
end

-- The landline on a square, if there is one.
function M.phoneOn(sq)
    local objects = sq and sq:getObjects()
    if not objects then return nil end
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        local props = obj.getProperties and obj:getProperties()
        if props and Machine.isPhone(props:get("CustomName")) then return obj end
    end
    return nil
end

local function near(player, sq)
    local dx, dy = player:getX() - (sq:getX() + 0.5), player:getY() - (sq:getY() + 0.5)
    return dx * dx + dy * dy <= REACH * REACH and math.floor(player:getZ()) == sq:getZ()
end

-- The window --------------------------------------------------------------------------------------------
KnoxMobileMachinePanel = ISPanelJoypad:derive("KnoxMobileMachinePanel")
local Panel = KnoxMobileMachinePanel

function Panel:new(player, sq, tape)
    local x = (getCore():getScreenWidth() - WIDTH) / 2
    local o = ISPanelJoypad.new(self, x, 140, WIDTH, HEIGHT)
    o.player, o.sq, o.items, o.shown = player, sq, M.lines(tape), 0
    o.started = getTimestampMs()
    o.backgroundColor = { r = 0.05, g = 0.05, b = 0.06, a = 0.92 }
    o.borderColor = { r = 0.55, g = 0.5, b = 0.4, a = 1 }
    o.moveWithMouse = true
    return o
end

-- How many lines have played by now; each new message starts with the machine's beep.
function Panel:advance(now)
    local due = 1 + math.max(0, math.floor((now - self.started - FIRST_MS) / GAP_MS) + 1)
    if now - self.started < FIRST_MS then due = 1 end
    due = math.min(due, #self.items)
    while self.shown < due do
        self.shown = self.shown + 1
        local item = self.items[self.shown]
        local sound = self.shown == 1 and "KnoxMobileCrackle" or (item.beep and "KnoxMobileLowBattery" or nil)
        if sound then pcall(function() self.player:getEmitter():playSound(sound) end) end
    end
    return self.shown
end

local function wrap(text, width)
    local tm, lines, line = getTextManager(), {}, ""
    for word in tostring(text):gmatch("%S+") do
        local try = line == "" and word or (line .. " " .. word)
        if line == "" or tm:MeasureStringX(UIFont.Small, try) <= width then line = try
        else lines[#lines + 1] = line; line = word end
    end
    if line ~= "" then lines[#lines + 1] = line end
    return lines
end

function Panel:prerender()
    ISPanelJoypad.prerender(self)
    if not near(self.player, self.sq) then self:close(); return end
    local shown = self:advance(getTimestampMs())
    local fontH = getTextManager():getFontHeight(UIFont.Small)
    self:drawText(T("IGUI_KnoxMobile_MachineTitle", "Answering machine"), 12, 8, 0.9, 0.85, 0.7, 1, UIFont.Medium)
    local y = 38
    for i = 1, shown do
        local item = self.items[i]
        if item.header then
            self:drawText(item.header, 12, y, 0.7, 0.75, 0.8, 1, UIFont.Small)
            y = y + fontH
        end
        for _, l in ipairs(wrap(item.text, WIDTH - 24)) do
            self:drawText(l, 12, y, 1, 1, 1, 1, UIFont.Small)
            y = y + fontH
        end
        y = y + 6
    end
    self:drawText(T("IGUI_KnoxMobile_MachineClose", "Click to close"), 12, HEIGHT - fontH - 6, 0.6, 0.6, 0.6, 1, UIFont.Small)
end

function Panel:close()
    self:removeFromUIManager()
    if M.panel == self then M.panel = nil end
end

function Panel:onMouseDown() self:close(); return true end
function Panel:onJoypadDown() self:close() end

-- Playing -----------------------------------------------------------------------------------------------
function M.open(player, sq)
    if M.panel then M.panel:close() end
    local tape = Machine.tape(sq:getX(), sq:getY(), sq:getZ())
    local p = KnoxMobileMachinePanel:new(player, sq, tape)
    p:initialise()
    p:addToUIManager()
    p:setAlwaysOnTop(true)
    M.panel = p
    if JoypadState.players[player:getPlayerNum() + 1] then setJoypadFocus(player:getPlayerNum(), p) end
    -- Strangers' voices on a dead house's tape: a little unhappiness, once per tape.
    local md = player:getModData()
    if type(md.KnoxMobileTapes) ~= "table" then md.KnoxMobileTapes = {} end
    local key = sq:getX() .. "," .. sq:getY() .. "," .. sq:getZ()
    if not md.KnoxMobileTapes[key] then
        md.KnoxMobileTapes[key] = true
        KnoxMobile.Client.mood("UNHAPPINESS", 2)
    end
    return p
end

-- From the menu: walk up to the phone first, then play.
function M.play(player, sq)
    if near(player, sq) then return M.open(player, sq) end
    if luautils and luautils.walkAdj then luautils.walkAdj(player, sq, true) end
    M.pending = { player = player, sq = sq, untilMs = getTimestampMs() + 15000 }
end

Events.OnTick.Add(Util.safe("answering machine walk", function()
    local p = M.pending
    if not p then return end
    if near(p.player, p.sq) then M.pending = nil; M.open(p.player, p.sq)
    elseif getTimestampMs() > p.untilMs then M.pending = nil end
end))

Events.OnFillWorldObjectContextMenu.Add(Util.safe("answering machine menu", function(playerNum, context, worldobjects, test)
    if test then return end
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    local phone
    for _, obj in ipairs(worldobjects or {}) do
        local sq = obj.getSquare and obj:getSquare()
        phone = sq and M.phoneOn(sq)
        if phone then break end
    end
    if not phone then return end
    local sq = phone:getSquare()
    local option = context:addOption(T("IGUI_KnoxMobile_MachinePlay", "Play messages"), nil, function() M.play(player, sq) end)
    if not Util.powered(sq) then
        option.notAvailable = true
        local tip = ISInventoryPaneContextMenu.addToolTip()
        tip.description = T("IGUI_KnoxMobile_MachineNoPower", "No power. The answering machine needs electricity.")
        option.toolTip = tip
    end
end))

return M
