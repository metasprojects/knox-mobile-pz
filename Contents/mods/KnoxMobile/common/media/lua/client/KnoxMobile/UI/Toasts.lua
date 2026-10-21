-- Client: notification popups near the moodles while the phone is put away (spec §8.4). With the phone
-- open, the newest one shows as a banner on its screen instead (the phone panel reads Toasts.latest).
require "ISUI/ISUIElement"

KnoxMobileToasts = ISUIElement:derive("KnoxMobileToasts")

local Toasts = { list = {}, element = nil }
KnoxMobile.Toasts = Toasts
KnoxMobile.UI = KnoxMobile.UI or {}

local SHOW_MS = 7000
local MAX = 4
local WIDTH = 340
local MAX_LINES = 2

-- Word wrap to the popup's text width, at most two lines (the second ends in "..." when cut).
local function wrap(text, width, font)
    local tm = getTextManager()
    local lines, line = {}, ""
    for word in tostring(text):gmatch("%S+") do
        local try = line == "" and word or (line .. " " .. word)
        if tm:MeasureStringX(font, try) <= width or line == "" then line = try
        else lines[#lines + 1] = line; line = word end
    end
    if line ~= "" then lines[#lines + 1] = line end
    if #lines > MAX_LINES then
        local last = lines[MAX_LINES]
        while #last > 1 and tm:MeasureStringX(font, last .. "...") > width do last = last:sub(1, #last - 1) end
        lines[MAX_LINES] = last .. "..."
        for i = #lines, MAX_LINES + 1, -1 do lines[i] = nil end
    end
    return lines
end
Toasts.wrap = wrap

function KnoxMobileToasts:render()
    local t = getTimestampMs()
    local font = UIFont.Small
    local fontH = getTextManager():getFontHeight(font)
    local y = 0
    for _, toast in ipairs(Toasts.list) do
        local age = t - toast.at
        if age < SHOW_MS and not toast.onScreen then
            local a = age > SHOW_MS - 1000 and (SHOW_MS - age) / 1000 or 1
            toast.lines = toast.lines or wrap(toast.text, WIDTH - 16, font)
            local rowH = #toast.lines * fontH + 10
            self:drawRect(0, y, WIDTH, rowH - 2, 0.75 * a, 0.05, 0.06, 0.08)
            self:drawRectBorder(0, y, WIDTH, rowH - 2, 0.8 * a, 0.35, 0.55, 0.75)
            for i, l in ipairs(toast.lines) do self:drawText(l, 8, y + 4 + (i - 1) * fontH, 1, 1, 1, a, font) end
            y = y + rowH
        end
    end
    -- Only as tall as the popups showing, and hidden when none are: an always-on-top box over the screen corner
    -- took the clicks meant for the phone below it (PC test 2026-10-15: icons and the close button did nothing).
    self:setHeight(math.max(1, y))
    if y == 0 then self:setVisible(false) end
end

function KnoxMobileToasts:new()
    local x = getCore():getScreenWidth() - WIDTH - 90
    local o = ISUIElement.new(self, x, 120, WIDTH, 320)
    o:setWantMouseEvents(false)
    return o
end

local function ensureElement()
    if Toasts.element then return end
    Toasts.element = KnoxMobileToasts:new()
    Toasts.element:initialise()
    Toasts.element:addToUIManager()
    Toasts.element:setAlwaysOnTop(true)
end

function KnoxMobile.UI.toast(text, kind)
    if not text or text == "" then return end
    local Options = KnoxMobile.Options
    local phoneOpen = KnoxMobile.UI.isOpen and KnoxMobile.UI.isOpen()
    local popup = not phoneOpen and (not Options or Options.popups() or kind == "call" or kind == "pager")
    -- onScreen: shown on the phone (or popups are off), so the HUD skips it.
    local toast = { text = text, kind = kind, at = getTimestampMs(), onScreen = not popup }
    table.insert(Toasts.list, 1, toast)
    while #Toasts.list > MAX do table.remove(Toasts.list) end
    Toasts.latest = toast
    -- With the phone open, notifications queue up and show on its screen one after another (r8: only the newest
    -- showed, so a text's banner was replaced at once).
    if toast.onScreen then
        Toasts.banners = Toasts.banners or {}
        table.insert(Toasts.banners, toast)
        while #Toasts.banners > 5 do table.remove(Toasts.banners, 1) end
    end
    if popup then
        ensureElement()
        Toasts.element:setVisible(true)
    end
end

return Toasts
