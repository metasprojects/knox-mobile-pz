-- Client: the phone on screen (spec §8): the held frame art with a live screen inside it, the status bar,
-- lock screen and PIN, home screen per family, calls, banners, and the apps from the app slot.
-- The game never pauses; mouse, wheel, keys and controller all work.
require "ISUI/ISPanelJoypad"
require "ISUI/ISTextEntryBox"
local Mod = require "KnoxMobile/Core/Mod"
local Phones = require "KnoxMobile/Game/Phones"
local WorldModel = require "KnoxMobile/Game/WorldModel"
local Util = require "KnoxMobile/Game/Util"
local Format = require "KnoxMobile/Core/Format"
local Power = require "KnoxMobile/Core/Power"
local Frames = require "KnoxMobile/Data/Frames"
local Tick = require "KnoxMobile/Game/Tick"

local T = Util.text

KnoxMobilePhonePanel = ISPanelJoypad:derive("KnoxMobilePhonePanel")
local Panel = KnoxMobilePhonePanel

local UI = KnoxMobile.UI or {}
KnoxMobile.UI = UI

local SCALES = { S = 0.55, M = 0.75, L = 1.0 }
local ZOOM_H = 70 -- tiny LCDs get a magnified copy of their screen above the phone
local CLOSE = 20 -- the close button's size, top right of the phone area

local STYLES = {
    -- The 1993 brick's red LED readout (matches its 3D model and the DoorStop ads).
    SegmentLCD = { bg = { 0.07, 0.02, 0.02 }, fg = { 1, 0.24, 0.16 }, accent = { 0.42, 0.07, 0.05 }, layout = "list" },
    MonoLCD = { bg = { 0.62, 0.72, 0.56 }, fg = { 0.08, 0.12, 0.08 }, accent = { 0.28, 0.36, 0.25 }, layout = "list" },
    ColorFeature = { bg = { 0.08, 0.16, 0.38 }, fg = { 1, 1, 1 }, accent = { 0.95, 0.6, 0.15 }, layout = "list" },
    Keyboard = { bg = { 0.07, 0.08, 0.1 }, fg = { 0.92, 0.92, 0.95 }, accent = { 0.2, 0.5, 0.95 }, layout = "list" },
    Stylus = { bg = { 0.12, 0.18, 0.28 }, fg = { 1, 1, 1 }, accent = { 0.4, 0.75, 0.95 }, layout = "grid", cols = 3 },
    ModernAndroid = { bg = { 0.04, 0.06, 0.12 }, fg = { 1, 1, 1 }, accent = { 0.25, 0.75, 0.55 }, layout = "grid", cols = 4 },
    ModernPear = { bg = { 0.08, 0.08, 0.1 }, fg = { 1, 1, 1 }, accent = { 0.2, 0.55, 1 }, layout = "grid", cols = 4 },
}
UI.STYLES = STYLES

-- Keypad phones beep on every key press (spec §4.6 "beeps").
local KEYPAD = { SegmentLCD = true, MonoLCD = true, ColorFeature = true, Keyboard = true }
-- Case edge colors, light enough to see on a dark frame and a dark world (r7: the near-black ones vanished).
local CASE_COLORS = {
    Slim = { 0.25, 0.45, 0.8 }, Rugged = { 0.45, 0.5, 0.36 }, Waterproof = { 0.95, 0.75, 0.15 }, Wallet = { 0.6, 0.38, 0.2 },
    Battery = { 0.42, 0.44, 0.48 }, BeltHolster = { 0.55, 0.4, 0.26 },
}
-- Keypads too small to read in the frame art get crisp printed keys (r7: the Soapbar at M, the DoorStop at
-- every size). The key face color is the art's own (median of its keys).
local KEY_FACES = require "KnoxMobile/UI/KeyFaces"
local FRAME_BODIES = require "KnoxMobile/UI/FrameBodies"
-- What each printed key says: a digit with its letters, a function key's name, or a mark drawn in place.
local KEY_PRINT = {
    FRCL = "RCL", FSTO = "STO", FCLR = "CLR", FSND = "SND", FEND = "END", FFCN = "FCN", BPWR = "PWR", BVOL = "VOL",
    BLOCK = "LOCK", C = "C", Navi = "Menu",
}
local KEY_MARK = { Call = "handset", End = "handset", Soft1 = "dash", Soft2 = "dash", Rocker = "updown" }
-- The DoorStop is a narrow brick: drawn half as large again so its keys are big enough to read and click (r8).
local MODEL_SCALE = { DoorStop8000 = 1.5 }
local KEY_LETTERS = { Key2 = "abc", Key3 = "def", Key4 = "ghi", Key5 = "jkl", Key6 = "mno", Key7 = "pqrs", Key8 = "tuv",
    Key9 = "wxyz" }
-- What a front button is called, shown while the mouse rests on it.
local KEY_NAMES = {
    FRCL = "RCL (up)", FSTO = "STO (down)", FCLR = "CLR (back)", FSND = "SND (select / call)", FEND = "END (back / hang up)",
    FFCN = "FCN (select)", BPWR = "PWR (power)", BVOL = "VOL (sound mode)", BLOCK = "LOCK (lock the phone)", Call = "Call / select",
    End = "End / back", Soft1 = "Select", Soft2 = "Back", Joy = "Joystick", Navi = "Navi (select)", Rocker = "Up / down",
    C = "C (back)", Fn1 = "Select", Fn2 = "Home", Fn3 = "Back", Fn4 = "Back", Trackpad = "Select", Menu = "Menu (home)",
    Home = "Home", Back = "Back",
}
local CRACK_MISS = 15 -- percent of taps a cracked screen swallows (spec §9.3)

local function font() return UIFont.Small end
-- The game's font size option makes UIFont.Small and the rest bigger too (r8: at 38 px the clock ran over the battery
-- and one row of icons fitted). Text on the phone's screen keeps at most these line heights: bigger fonts are drawn
-- scaled down to them. At the usual sizes nothing changes.
local MAX_LINE = { Small = 20, Medium = 26, Large = 32 }
-- At the Large size (and in first person) the screen's text goes up one font size with the screen (r8: Large made a
-- tall screen of small text).
local BUMP = nil
local function face(f)
    f = f or UIFont.Small
    if not (UI.panel and UI.panel.bigText) then return f end
    BUMP = BUMP or { [UIFont.Small] = UIFont.Medium, [UIFont.Medium] = UIFont.Large }
    return BUMP[f] or f
end
-- Text measuring calls into the game's Java for every string, every frame the phone is open, and a word wrap measures
-- word by word (0.2.1). Font heights and string widths are kept (UI.resetText empties them when the phone opens, so a
-- changed font size is picked up), and wrapped lines too.
local FONT_H, WIDTHS, WRAPS, counted = {}, {}, {}, 0
function UI.resetText() FONT_H, WIDTHS, WRAPS, counted = {}, {}, {}, 0 end
local function heightOf(f)
    local h = FONT_H[f]
    if not h then h = getTextManager():getFontHeight(f); FONT_H[f] = h end
    return h
end
local function widthOf(f, s)
    local byFont = WIDTHS[f]
    if not byFont then byFont = {}; WIDTHS[f] = byFont end
    local w = byFont[s]
    if not w then
        if counted > 4000 then UI.resetText(); byFont = {}; WIDTHS[f] = byFont end
        w = getTextManager():MeasureStringX(f, s)
        byFont[s], counted = w, counted + 1
    end
    return w
end
local function zoomFor(f)
    f = face(f)
    local cap = (f == UIFont.Medium and MAX_LINE.Medium) or (f == UIFont.Large and MAX_LINE.Large) or MAX_LINE.Small
    return math.min(1, cap / heightOf(f))
end
local function fontH(f) return math.floor(heightOf(face(f)) * zoomFor(f)) end
local function lineH() return fontH(UIFont.Small) end
local function textW(s, f) return widthOf(face(f), s) * zoomFor(f) end
UI.zoomFor, UI.fontH, UI.textW = zoomFor, fontH, textW

local wrapLines

-- Word wrap to a pixel width. Callers get their own copy of the kept lines (some add to them).
function UI.wrap(text, width, f)
    local key = tostring(text) .. "\1" .. width .. "\1" .. tostring(face(f))
    local kept = WRAPS[key]
    if not kept then
        if counted > 4000 then UI.resetText() end
        kept = wrapLines(text, width, f)
        WRAPS[key], counted = kept, counted + 1
    end
    local out = {}
    for i = 1, #kept do out[i] = kept[i] end
    return out
end

wrapLines = function(text, width, f)
    -- A little room to spare: zoomed text draws a few pixels wider than it measures (final test: "batteries" lost
    -- its last letter on the Cinderblock).
    width = width - math.max(3, math.floor(width * 0.04))
    -- Line breaks start a new line; an empty line stays empty (a journal's days, a note's paragraphs).
    local lines = {}
    for para in (tostring(text) .. "\n"):gmatch("(.-)\n") do
        local line = ""
        for word in para:gmatch("%S+") do
            local try = line == "" and word or (line .. " " .. word)
            if textW(try, f) <= width or line == "" then line = try
            else lines[#lines + 1] = line; line = word end
        end
        lines[#lines + 1] = line
    end
    while #lines > 1 and lines[#lines] == "" do lines[#lines] = nil end
    if #lines == 1 and lines[1] == "" then return {} end
    return lines
end

-- The context apps draw with (see API.lua) -------------------------------------------------------
local Ctx = {}
Ctx.__index = Ctx

local function color(c, default) return c or default end

function Ctx:text(s, x, y, c, f, align)
    c = color(c, self.style.fg)
    local p = self.panel
    local base = f or font()
    local z, drawFont = zoomFor(base), face(base)
    local px = self.sx + x
    if align == "center" then px = px - textW(s, base) / 2 elseif align == "right" then px = px - textW(s, base) end
    if z < 1 then
        p:drawTextZoomed(s, px, self.sy + y, z, c[1], c[2], c[3], 1, drawFont)
    else
        p:drawText(s, px, self.sy + y, c[1], c[2], c[3], 1, drawFont)
    end
end

function Ctx:rect(x, y, w, h, c, a)
    c = color(c, self.style.fg)
    self.panel:drawRect(self.sx + x, self.sy + y, w, h, a or 1, c[1], c[2], c[3])
end

function Ctx:border(x, y, w, h, c, a)
    c = color(c, self.style.fg)
    self.panel:drawRectBorder(self.sx + x, self.sy + y, w, h, a or 1, c[1], c[2], c[3])
end

function Ctx:lineHeight() return lineH() end
function Ctx:measure(s) return textW(s) end
function Ctx:wrap(s, width) return UI.wrap(s, width) end

-- A selectable list. items: strings or { label, sub, value, short, minor }. Selection lives in self.data.sel.
-- `value` (a setting's state, a time) is drawn at the right edge. When the row is too narrow the label gives way
-- first: its `short` form, then "..."; a `minor` value is dropped instead.
function Ctx:list(items, x, y, w, h)
    local rowH = lineH() + 4
    local rows = math.max(1, math.floor(h / rowH))
    local d = self.data
    d.sel = math.max(1, math.min(d.sel or 1, math.max(1, #items)))
    d.scroll = d.scroll or 0
    if d.sel <= d.scroll then d.scroll = d.sel - 1 end
    if d.sel > d.scroll + rows then d.scroll = d.sel - rows end
    for i = 1, rows do
        local idx = d.scroll + i
        local it = items[idx]
        if not it then break end
        local label = type(it) == "table" and it.label or tostring(it)
        local sub = type(it) == "table" and it.sub or nil
        local ry = y + (i - 1) * rowH
        local fg = self.style.fg
        if idx == d.sel then
            self:rect(x, ry, w, rowH, self.style.accent, 0.85)
            fg = { 1, 1, 1 }
            if self.family == "SegmentLCD" or self.family == "MonoLCD" then fg = self.style.bg end
        end
        local text = Format.ellipsis(label, 40)
        local value = type(it) == "table" and it.value or nil
        if value then
            value = tostring(value)
            local room = w - 6 - textW(value) - 6
            -- Too long beside its value: the short label first; then, for a minor value, the label alone.
            if textW(text) > room and it.short and textW(it.short) <= room then
                text = it.short
            elseif textW(text) > room and it.minor then
                value, room = nil, w - 6
                if textW(text) > room and it.short then text = it.short end
            elseif textW(text) > room and it.short then
                text = it.short
            end
            if value then self:text(value, x + w - 3, ry + 2, fg, nil, "right") end
            while textW(text) > room and #text > 4 do text = text:sub(1, #text - 4) .. "..." end
        else
            if sub then text = text .. "  " .. sub end
            if textW(text) > w - 6 and type(it) == "table" and it.short then text = it.short end
            while textW(text) > w - 6 and #text > 4 do text = text:sub(1, #text - 4) .. "..." end
        end
        self:text(text, x + 3, ry + 2, fg)
    end
    d.listRect = { x = x, y = y, w = w, h = h, rowH = rowH }
    return rowH
end

-- Moves the list selection; returns the chosen index on select or tap.
function Ctx:listInput(ev, count)
    local d = self.data
    d.sel = d.sel or 1
    if count == 0 then return nil end
    if ev.type == "key" then
        if ev.key == "up" then d.sel = d.sel > 1 and d.sel - 1 or count
        elseif ev.key == "down" then d.sel = d.sel < count and d.sel + 1 or 1
        elseif ev.key == "select" then return d.sel end
    elseif ev.type == "wheel" then
        d.sel = math.max(1, math.min(count, d.sel + (ev.delta > 0 and 1 or -1)))
    elseif ev.type == "tap" and d.listRect then
        local r = d.listRect
        if ev.x >= r.x and ev.x <= r.x + r.w and ev.y >= r.y and ev.y <= r.y + r.h then
            local idx = (d.scroll or 0) + math.floor((ev.y - r.y) / r.rowH) + 1
            if idx >= 1 and idx <= count then d.sel = idx; return idx end
        end
    end
    return nil
end

function Ctx:back() self.panel:goHome() end
function Ctx:open(appId) self.panel:openApp(appId) end
function Ctx:toast(s) if KnoxMobile.Client then KnoxMobile.Client.toast(s) end end
function Ctx:setting(key, value) KnoxMobile.Client.setting(self.phone, key, value) end
function Ctx:askText(prompt, initial, onDone, maxLen, masked) self.panel:askText(prompt, initial, onDone, maxLen, masked) end
function Ctx:wantsDigits(on) self.panel.digits = on end
-- WASD as arrow keys while the app wants them (Snake); like digits, asked for again every frame.
function Ctx:wantsWasd(on) self.panel.wasd = on end

-- The panel ------------------------------------------------------------------------------------------
local function artIdOf(model) return model.look or model.id end

function Panel:new(player, item)
    local model, colorName = Phones.model(item)
    -- A phone without art of its own borrows another's (the car phone looks like the DoorStop 8000).
    local artId = model.look or model.id
    local frame = Frames[artId] or { width = 270, height = 512, screen = { x = 19, y = 39, w = 232, h = 411 } }
    local Options = KnoxMobile.Options
    local scale = (SCALES[Options.size()] or 0.75) * (MODEL_SCALE[artIdOf(model)] or 1)
    -- In Project Viewpoint's first person the phone is held up in front of you: at least the large size, low and
    -- toward the holding side, the way a phone fills the bottom of your view.
    local firstPerson = KnoxMobile.Viewpoint ~= nil and KnoxMobile.Viewpoint.view() == "first"
    if firstPerson then scale = math.max(scale, SCALES.L) end
    local fw, fh = math.floor(frame.width * scale), math.floor(frame.height * scale)
    local scr = frame.screen
    local zoom = scr.h * scale < 48
    local w = math.max(fw, zoom and 240 or 0)
    local h = fh + (zoom and ZOOM_H or 0)
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    -- Just the phone, in a bottom corner (no hand art: in the world the character holds the phone's 3D model).
    -- On the left it clears the game's column of HUD buttons (r7: the phones and the DoorStop's LCD strip covered it).
    local x = Options.side() == "left" and 72 or (sw - w - 30)
    local y = math.max(10, sh - h - 120)
    if firstPerson then
        -- Held toward the side of the hand that holds it (Options: Hold the phone in).
        local cx = Options.hand() == "main" and sw * 0.66 or sw * 0.34
        x = math.floor(math.max(10, math.min(sw - w - 10, cx - w / 2)))
        y = math.max(10, sh - h - 24)
    end
    local o = ISPanelJoypad.new(self, x, y, w, h)
    o.firstPerson = firstPerson
    o.bigText = Options.bigText() or scale / (MODEL_SCALE[artIdOf(model)] or 1) >= SCALES.L
    o.player, o.item, o.model = player, item, model
    o.family = model.family
    o.style = STYLES[model.family] or STYLES.ModernAndroid
    -- High-contrast screens (Options): white on black with a yellow highlight, whatever the phone.
    if Options.highContrast() then
        o.style = { bg = { 0, 0, 0 }, fg = { 1, 1, 1 }, accent = { 1, 0.85, 0.15 }, layout = o.style.layout, cols = o.style.cols }
    end
    -- Each color has its own frame art (a phone without per-color art can ship one <id>.png).
    local colorKey = colorName and tostring(colorName):gsub("[^%w]", "") or ""
    o.frameTex = getTexture("media/ui/KnoxMobile/frames/" .. artId .. "_" .. colorKey .. ".png")
        or getTexture("media/ui/KnoxMobile/frames/" .. artId .. ".png")
    local fx = math.floor((w - fw) / 2)
    local fy = zoom and ZOOM_H or 0
    o.frameRect = { x = fx, y = fy, w = fw, h = fh }
    o.frameArt = frame
    -- The phone's physical front buttons, in panel pixels: the mouse presses them like the real keys.
    o.keyRects = {}
    for _, k in ipairs(frame.keys or {}) do
        o.keyRects[#o.keyRects + 1] = { id = k.id, x = fx + math.floor(k.x * scale), y = fy + math.floor(k.y * scale),
            w = math.max(8, math.floor(k.w * scale)), h = math.max(8, math.floor(k.h * scale)) }
    end
    if zoom then
        o.screen = { x = 0, y = 0, w = w, h = ZOOM_H - 6 }
        o.lcdRect = { x = fx + math.floor(scr.x * scale), y = fy + math.floor(scr.y * scale),
            w = math.floor(scr.w * scale), h = math.floor(scr.h * scale) }
    else
        o.screen = { x = fx + math.floor(scr.x * scale), y = fy + math.floor(scr.y * scale),
            w = math.floor(scr.w * scale), h = math.floor(scr.h * scale) }
    end
    o.background = false
    o.moveWithMouse = true
    o.view, o.appId, o.appData, o.homeData = "home", nil, {}, {}
    o.pin = ""
    o.located, o.nextLocate = nil, 0
    o.digits = false
    return o
end

function Panel:initialise()
    ISPanelJoypad.initialise(self)
    self:setWantKeyEvents(true)
end

function Panel:state() return Phones.get(self.item) end

function Panel:ctx(x, y, w, h, data)
    local state = self:state()
    return setmetatable({
        panel = self, sx = self.screen.x + x, sy = self.screen.y + y, w = w, h = h,
        phone = self.item, state = state, model = self.model, family = self.family, style = self.style,
        located = self.located, data = data, player = self.player,
    }, Ctx)
end

function Panel:goHome()
    self:cancelText()
    self:closeApp()
    self.view = "home"
end

function Panel:openApp(id)
    local app = KnoxMobile.Apps.get(id)
    if not app then return end
    self:cancelText()
    self:closeApp()
    self.view, self.appId, self.appData = "app", id, {}
    KnoxMobile.Apps.safeCall(app.onOpen, self:ctx(0, 0, self.screen.w, self.screen.h, self.appData))
end

function Panel:closeApp()
    if self.view == "app" and self.appId then
        local app = KnoxMobile.Apps.get(self.appId)
        if app then KnoxMobile.Apps.safeCall(app.onClose, self:ctx(0, 0, self.screen.w, self.screen.h, self.appData)) end
    end
    self.appId = nil
end

-- A box's real text: a masked box's getText() is its stars (final test 2026-10-19: no phone could set a PIN).
local function boxText(box)
    if box.getInternalText then
        local ok, s = pcall(box.getInternalText, box)
        if ok and type(s) == "string" then return s end
    end
    return box:getText() or ""
end

-- A text box over the bottom of the screen; Enter sends, Escape cancels.
function Panel:askText(prompt, initial, onDone, maxLen, masked)
    self:cancelText()
    local s = self.screen
    local boxH = lineH() + 8
    local box = ISTextEntryBox:new(initial or "", s.x + 2, s.y + s.h - boxH - 2, s.w - 4, boxH)
    box:initialise()
    box:instantiate()
    if maxLen then pcall(function() box:setMaxTextLength(maxLen) end) end
    -- A new PIN shows as stars (r8: it showed the digits).
    if masked then pcall(function() box:setMasked(true) end) end
    box.knoxMaxLen = maxLen
    local panel = self
    box.onCommandEntered = function(b)
        local text = boxText(b)
        panel:cancelText()
        -- Enter's key release reaches the phone after the box is gone; it must not select the row again (PC test r5).
        panel.ignoreEnterUntil = getTimestampMs() + 400
        if onDone then onDone(text) end
    end
    -- A focused box takes Escape itself, so the phone's own key handler never sees it.
    box.onOtherKey = function(_, key)
        if key == Keyboard.KEY_ESCAPE then
            pcall(function() Core.UnfocusActiveTextEntryBox() end)
            panel:cancelText()
        end
    end
    self:addChild(box)
    -- Another focused box (the debug console) kept the keys (r7, twice in 15 boxes): unfocus it first, and check
    -- again a moment later in case the key that opened this box handed focus back.
    pcall(function() Core.UnfocusActiveTextEntryBox() end)
    box:focus()
    self.textBox, self.textPrompt = box, prompt
    self.refocusAt = getTimestampMs() + 150
end

function Panel:keepTextFocus()
    if not self.refocusAt or not self.textBox or getTimestampMs() < self.refocusAt then return end
    self.refocusAt = nil
    local box = self.textBox
    local ok, focused = pcall(function() return box:isFocused() end)
    if ok and not focused then
        pcall(function() Core.UnfocusActiveTextEntryBox() end)
        box:focus()
        Util.log("text box had lost the keyboard; focused again")
    end
end

function Panel:cancelText()
    if self.textBox then
        self.textBox:unfocus()
        self:removeChild(self.textBox)
        self.textBox, self.textPrompt = nil, nil
    end
end

-- Drawing ----------------------------------------------------------------------------------------
local function clock()
    local gt = getGameTime()
    return Format.clock(gt:getHour(), gt:getMinutes(), KnoxMobile.Options.clock24())
end

-- Status bar glyphs (spec §8.3), 7 x 5 pixels, drawn in the screen's ink: silent (a speaker with an x), vibrate (a
-- phone between buzz lines) and earbuds or headphones. Battery saver tints the battery instead.
local GLYPHS = {
    silent = { "..#....", ".##.#.#", "###..#.", ".##.#.#", "..#...." },
    vibrate = { "..###..", "#.#.#.#", "#.#.#.#", "#.#.#.#", "..###.." },
    audio = { ".#####.", "#.....#", "#.....#", "##...##", "##...##" },
}
local GLYPH_W = 7

-- Draws a glyph with its right edge at `right`; returns its width.
local function drawGlyph(c, name, right, y, px)
    local rows = GLYPHS[name]
    local x0 = right - GLYPH_W * px
    for r, row in ipairs(rows) do
        local col = 1
        while col <= #row do
            if row:sub(col, col) == "#" then
                local run = col
                while run < #row and row:sub(run + 1, run + 1) == "#" do run = run + 1 end
                c:rect(x0 + (col - 1) * px, y + (r - 1) * px, (run - col + 1) * px, px)
                col = run + 1
            else
                col = col + 1
            end
        end
    end
    return GLYPH_W * px
end

function Panel:drawStatusBar(c, state)
    local h = lineH()
    local w = c.w
    c:rect(0, 0, w, h + 2, { 0, 0, 0 }, 0.25)
    -- Battery: outline, fill and percent.
    local bx = w - 22
    c:border(bx, 3, 16, h - 5)
    c:rect(bx + 16, 5, 2, h - 9)
    local fill = math.floor(14 * state.battery.charge / 100)
    local low = state.battery.charge <= 15
    c:rect(bx + 1, 4, fill, h - 7, (low and { 0.9, 0.2, 0.2 }) or (state.power.saver and { 0.95, 0.75, 0.2 }) or nil)
    local right = bx - 4
    if w > 120 then
        local pct = Format.battery(state.battery.charge)
        c:text(pct, right, 1, nil, nil, "right")
        right = right - textW(pct) - 4
    end
    if state.plug then c:text("+", right, 1, { 0.95, 0.85, 0.2 }, nil, "right"); right = right - textW("+") - 3 end
    local glyphs = {}
    if state.look.soundMode == "silent" or state.look.soundMode == "vibrate" then glyphs[#glyphs + 1] = state.look.soundMode end
    local route = state.look.audioRoute
    if route == "earbuds" or route == "oneEarbud" or route == "headphones" then glyphs[#glyphs + 1] = "audio" end
    local px = math.max(1, math.floor(h / 10))
    for _, g in ipairs(glyphs) do right = right - drawGlyph(c, g, right, math.floor((h + 2 - 5 * px) / 2), px) - 4 end
    -- The clock, then the signal bars and the network name when there is room. A narrow screen (the Cinderblock at
    -- Small, final test) drops AM/PM first, then the bars, so nothing runs into the battery.
    local time = clock()
    if textW(time) + 8 + 16 > right then time = time:gsub("%s*[AaPp]%.?[Mm]%.?$", "") end
    c:text(time, 3, 1)
    local loc = self.located
    local bars = loc and loc.network and loc.bars or 0
    local sx = textW(time) + 8
    if sx + 16 > right then sx = textW(time) + 5 end
    if sx + 15 > right + 2 then return h + 3 end
    for i = 1, 4 do
        local bh = math.floor((h - 4) * i / 4)
        c:rect(sx + (i - 1) * 4, h - bh, 3, bh, nil, i <= bars and 1 or 0.25)
    end
    if w > 150 then
        local name = Format.network(loc, T)
        local avail = right - (sx + 20)
        if textW(name) <= avail then c:text(name, sx + 20, 1) end
    end
    return h + 3
end

-- The newest notification as a banner over the top of the screen, like a real phone's, for 3 seconds. It covers
-- the app's top row, so a tap on it (or any key) puts it away at once (r7).
local BANNER_MS = 3000
function Panel:drawBanner(c, top)
    self.banner = nil
    local queue = KnoxMobile.Toasts and KnoxMobile.Toasts.banners
    if not queue then return end
    local t = getTimestampMs()
    local toast = queue[1]
    while toast and (toast.dismissed or (toast.shownAt and t - toast.shownAt > BANNER_MS)) do
        table.remove(queue, 1)
        toast = queue[1]
    end
    if not toast then return end
    toast.shownAt = toast.shownAt or t
    -- A solid card with a border and an accent stripe, so it reads over any app (r8: it looked like bare text).
    local lines = UI.wrap(toast.text, c.w - 16)
    local h = math.min(#lines, 3) * lineH() + 8
    c:rect(2, top, c.w - 4, h, { 0.12, 0.13, 0.16 }, 1)
    c:rect(2, top, 3, h, self.style.accent, 1)
    c:border(2, top, c.w - 4, h, { 0.75, 0.78, 0.85 }, 0.9)
    for i = 1, math.min(#lines, 3) do c:text(lines[i], 9, top + 4 + (i - 1) * lineH(), { 1, 1, 1 }) end
    if #queue > 1 then c:text("+" .. tostring(#queue - 1), c.w - 6, top + h - lineH() - 2, { 0.7, 0.75, 0.85 }, nil, "right") end
    self.banner = { toast = toast, y = top, h = h }
end

-- True when the event only put the banner away (a tap on it); keys put it away and still work.
function Panel:dismissBanner(ev)
    local b = self.banner
    if not b then return false end
    if ev.type == "key" then b.toast.dismissed = true; self.banner = nil; return false end
    if ev.type == "tap" and ev.y >= b.y and ev.y <= b.y + b.h then
        b.toast.dismissed = true
        self.banner = nil
        return true
    end
    return false
end

-- Home screens come from UI/Shells.lua, one shell per screen family.
function Panel:drawHome(c, top)
    local apps = KnoxMobile.Apps.forFamily(self.family, self.model)
    self.homeApps = apps
    KnoxMobile.Shells.forFamily(self.family).draw(self, c, top, apps, self.homeData)
end

function Panel:homeInput(ev)
    local apps = self.homeApps or KnoxMobile.Apps.forFamily(self.family, self.model)
    if #apps == 0 then return end
    local c = self:ctx(0, 0, self.screen.w, self.screen.h, self.homeData)
    local app = KnoxMobile.Shells.forFamily(self.family).input(self, ev, apps, self.homeData, c)
    if app then self:openApp(app.id) end
end

function Panel:drawLock(c, top)
    local result = KnoxMobile.Client.unlock[self.item:getID()]
    local msg = T("IGUI_KnoxMobile_EnterPin", "Enter PIN")
    if result == "wrong" then msg = T("IGUI_KnoxMobile_WrongPin", "Wrong PIN")
    elseif result == "lockedOut" then msg = T("IGUI_KnoxMobile_LockedOutShort", "Locked out") end
    self.digits = true
    self.keypad = nil
    local state = self:state()
    -- The first locked dead person's phone this character tries: the whole PIN system in a real popup (UI.pinHelp).
    if state.owner and state.owner.kind == "generated" then UI.wantPinHelp(self.player) end
    -- Small LCDs: one line, "PIN **__" (number keys type it).
    if c.h - top < 4 * lineH() + 8 then
        local line = (result == "wrong" or result == "lockedOut") and msg
            or T("IGUI_KnoxMobile_PinLine", "PIN %1", Format.pinMask(#self.pin, 4))
        c:text(line, c.w / 2, top + math.floor((c.h - top - lineH()) / 2), nil, nil, "center")
        return
    end
    local cy = top + 6
    c:text(clock(), c.w / 2, cy, nil, c.h > 150 and UIFont.Medium or nil, "center")
    cy = cy + fontH(c.h > 150 and UIFont.Medium or UIFont.Small) + 4
    c:text(msg, c.w / 2, cy, nil, nil, "center")
    cy = cy + lineH() + 2
    -- Four fixed slots, so the row doesn't grow as you type (r8).
    local slotW = math.max(textW("*", UIFont.Medium), textW("_", UIFont.Medium)) + 6
    for i = 1, 4 do
        c:text(i <= #self.pin and "*" or "_", c.w / 2 + (i - 2.5) * slotW, cy, nil, UIFont.Medium, "center")
    end
    cy = cy + fontH(UIFont.Medium) + 6
    -- In case of emergency (Settings): who to tell, for whoever finds this phone.
    local ice = state.ice
    if ice then
        c:text(Format.ellipsis(T("IGUI_KnoxMobile_IceLine", "ICE: %1 %2", ice.name, ice.number), math.max(8, math.floor((c.w - 8) / 7))),
            c.w / 2, cy, nil, nil, "center")
        cy = cy + lineH() + 4
    elseif state.owner and state.owner.kind == "generated" then
        -- A dead owner's phone: the way in, spelled out (Workshop: "is there a way to open them?"; Meta: "players
        -- don't understand how the PIN system works"). Wrapped, never cut (PC test: "Their wallet may ho...").
        for i, line in ipairs(UI.wrap(T("IGUI_KnoxMobile_LockHint", "PIN clue: their wallet"), c.w - 8)) do
            if i > 2 then break end
            c:text(line, c.w / 2, cy, nil, nil, "center")
            cy = cy + lineH()
        end
        cy = cy + 4
    end
    -- The keypad sits at the bottom of the screen; previews of the newest unread texts (spec §8.5) only use the room
    -- left between the PIN line and the keypad (PC test r5: they were drawn over its top row).
    local rowH = lineH() + 6
    local keysH = math.min(c.h - cy - 4, 4 * (lineH() + 14))
    local keysTop = c.h - 4 - keysH
    local room = (keysH >= 4 * rowH) and (keysTop - cy) or (c.h - cy)
    for _, p in ipairs(self:previews(math.max(0, math.floor(room / rowH)))) do
        c:rect(6, cy, c.w - 12, lineH() + 4, { 0, 0, 0 }, 0.35)
        local text = Format.ellipsis(p.name .. ": " .. p.body, math.max(8, math.floor((c.w - 16) / 7)))
        c:text(text, 9, cy + 2, { 1, 1, 1 })
        cy = cy + rowH
    end
    if keysH >= 4 * rowH then
        local kw, kh = math.floor((c.w - 16) / 3), math.floor(keysH / 4)
        local labels = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "<", "0", "OK" }
        self.keypad = { x = 8, y = keysTop, kw = kw, kh = kh, labels = labels }
        for i, l in ipairs(labels) do
            local col, row = Mod.floor((i - 1), 3), math.floor((i - 1) / 3)
            local kx, ky = 8 + col * kw, keysTop + row * kh
            c:border(kx + 2, ky + 2, kw - 4, kh - 4, nil, 0.6)
            c:text(l, kx + kw / 2, ky + kh / 2 - lineH() / 2, nil, nil, "center")
        end
    else
        self.keypad = nil
    end
end

-- The newest unread messages, newest first: { name, body }.
function Panel:previews(max)
    local out = {}
    local state = self:state()
    for _, conv in ipairs(state.contents.texts or {}) do
        for i = #conv.messages, 1, -1 do
            local m = conv.messages[i]
            if m.unread then
                out[#out + 1] = { name = conv.name or conv.with, body = m.body, at = (m.day or 0) * 1440 + (m.minute or 0) }
                break
            end
        end
    end
    table.sort(out, function(a, b) return a.at > b.at end)
    while #out > max do table.remove(out) end
    return out
end

function Panel:pinKey(k)
    if k == "<" or k == "back" then self.pin = self.pin:sub(1, -2); return end
    if k == "OK" or k == "select" then
        if #self.pin == 4 then
            KnoxMobile.Client.setting(self.item, "unlock", self.pin)
            self.pin = ""
        end
        return
    end
    if k:match("^%d$") and #self.pin < 4 then
        -- A new try clears "Wrong PIN" (r8: it stayed while the next PIN was typed).
        if KnoxMobile.Client.unlock[self.item:getID()] == "wrong" then KnoxMobile.Client.unlock[self.item:getID()] = nil end
        self.pin = self.pin .. k
        if #self.pin == 4 then self:pinKey("OK") end
    end
end

function Panel:lockInput(ev)
    if ev.type == "key" then self:pinKey(ev.key)
    elseif ev.type == "tap" and self.keypad then
        local k = self.keypad
        local col = math.floor((ev.x - k.x) / k.kw)
        local row = math.floor((ev.y - k.y) / k.kh)
        if col >= 0 and col < 3 and row >= 0 and row < 4 then self:pinKey(k.labels[row * 3 + col + 1]) end
    end
end

function Panel:drawCall(c, top)
    local call = KnoxMobile.Client.call
    local status = { incoming = T("IGUI_KnoxMobile_CallIncoming", "Incoming call"),
        outgoing = T("IGUI_KnoxMobile_CallCalling", "Calling..."), active = T("IGUI_KnoxMobile_CallActive", "On call") }
    -- Small LCDs: the caller on one line; Enter answers, Backspace declines or hangs up.
    if c.h - top < 5 * lineH() then
        self.callSplit = c.h
        local who = Format.ellipsis(call.name or call.number or "", math.max(6, math.floor(c.w / 8)))
        c:text(call.status == "incoming" and T("IGUI_KnoxMobile_CallLine", "CALL %1", who) or who, c.w / 2, top + 2, nil, nil, "center")
        if c.h - top > 2 * lineH() then c:text(status[call.status] or "", c.w / 2, top + lineH() + 4, nil, nil, "center") end
        return
    end
    local cy = top + 10
    c:text(status[call.status] or "", c.w / 2, cy, nil, nil, "center")
    cy = cy + lineH() + 6
    c:text(call.name or call.number or "", c.w / 2, cy, nil, UIFont.Medium, "center")
    cy = cy + fontH(UIFont.Medium) + 10
    local half = (c.h - cy) / 2
    if call.status == "incoming" then
        c:rect(6, cy, c.w - 12, half - 6, { 0.2, 0.7, 0.3 }, 0.9)
        c:text(T("IGUI_KnoxMobile_Answer", "Answer"), c.w / 2, cy + half / 2 - lineH(), { 1, 1, 1 }, nil, "center")
        c:rect(6, cy + half, c.w - 12, half - 6, { 0.8, 0.2, 0.2 }, 0.9)
        c:text(T("IGUI_KnoxMobile_Decline", "Decline"), c.w / 2, cy + half * 1.5 - lineH(), { 1, 1, 1 }, nil, "center")
    else
        c:rect(6, cy + half, c.w - 12, half - 6, { 0.8, 0.2, 0.2 }, 0.9)
        c:text(T("IGUI_KnoxMobile_HangUp", "Hang up"), c.w / 2, cy + half * 1.5 - lineH(), { 1, 1, 1 }, nil, "center")
    end
    self.callSplit = cy + half
end

function Panel:callInput(ev)
    local call = KnoxMobile.Client.call
    local answer = (ev.type == "key" and ev.key == "select") or (ev.type == "tap" and ev.y < (self.callSplit or 0))
    if call.status == "incoming" and answer then KnoxMobile.Client.answer()
    elseif (ev.type == "key" and (ev.key == "back" or ev.key == "select")) or ev.type == "tap" then KnoxMobile.Client.hangUp() end
end

function Panel:callForMe()
    local call = KnoxMobile.Client and KnoxMobile.Client.call
    if not call then return nil end
    if call.phoneId and call.phoneId ~= self.item:getID() then return nil end
    return call
end

function Panel:mode(state)
    if state.condition == "broken" then return "broken" end
    if state.rice then return "rice" end
    if not state.power.on then return "off" end
    if self:callForMe() then return "call" end
    if state.security.locked then return "lock" end
    return self.view
end

function Panel:drawScreen()
    local s = self.screen
    local state = self:state()
    local c = self:ctx(0, 0, s.w, s.h, {})
    self:setStencilRect(s.x, s.y, s.w, s.h)
    local mode = self:mode(state)
    self.currentMode = mode
    self.digits, self.wasd = false, false
    if mode == "off" or mode == "broken" or mode == "rice" then
        self:drawRect(s.x, s.y, s.w, s.h, 1, 0.02, 0.02, 0.03)
        -- A phone with its own power key says to press it (r8: the DoorStop brick said "Tap").
        local msg = T("IGUI_KnoxMobile_TapToTurnOn", "Tap or press Enter to turn on")
        for _, r in ipairs(self.keyRects) do
            if r.id == "BPWR" then msg = T("IGUI_KnoxMobile_PressPwr", "Press PWR to turn on") end
        end
        if mode == "broken" then msg = T("IGUI_KnoxMobile_NoDisplay", "No display")
        elseif mode == "rice" then msg = T("IGUI_KnoxMobile_InRice", "In a bag of rice")
        elseif state.plug then msg = Format.battery(state.battery.charge) .. " +" end
        local grey = { 0.55, 0.55, 0.6 }
        for i, l in ipairs(UI.wrap(msg, s.w - 8)) do c:text(l, s.w / 2, s.h / 2 - lineH() + (i - 1) * lineH(), grey, nil, "center") end
        self:clearStencilRect()
        return
    end
    local source = KnoxMobile.Screen.active(self.item)
    if source.id ~= "shell" then
        self.source = source
        local ok, err = pcall(source.render, c, 0, 0, s.w, s.h)
        if not ok then Util.log("screen source", source.id, "failed:", err) end
        self:clearStencilRect()
        return
    end
    self.source = nil
    -- Water damage: the screen drops out now and then, with a crackle (spec §9.3).
    if state.wetness == "waterDamaged" and self:flicker() then
        self:drawRect(s.x, s.y, s.w, s.h, 1, 0, 0, 0)
        self:clearStencilRect()
        return
    end
    c:rect(0, 0, s.w, s.h, self.style.bg)
    local family = Phones.registry:family(self.family)
    if family and family.wallpapers and (mode == "home" or mode == "lock") then
        local modern = self.family == "ModernAndroid" or self.family == "ModernPear"
        local photo = state.look.wallpaperPhoto
        local cam = photo and KnoxMobile.Camera
        local tex = cam and cam.available() and knoxLivePhotoTexture(photo)
        if cam and cam.available() and not tex then cam.ensure(self.player, photo) end
        if not KnoxMobile.Shells.photoWallpaper(c, tex) then
            KnoxMobile.Shells.wallpaper(c, state.look.wallpaper or (modern and 1 or nil))
        end
    end
    local top = self:drawStatusBar(c, state)
    self.contentTop = top
    if mode == "call" then self:drawCall(c, top)
    elseif mode == "lock" then self:drawLock(c, top)
    elseif mode == "app" then
        local app = KnoxMobile.Apps.get(self.appId)
        local ac = self:ctx(0, top, s.w, s.h - top, self.appData)
        if not app then self:goHome()
        elseif app.needsService and not (self.located and self.located.network) then
            ac:text(T("IGUI_KnoxMobile_NoService", "No service"), s.w / 2, (s.h - top) / 2 - lineH(), nil, nil, "center")
        elseif state.power.saver and Power.blockedBySaver(app.id) then
            ac:text(T("IGUI_KnoxMobile_SaverOn", "Battery saver is on"), s.w / 2, (s.h - top) / 2 - lineH(), nil, nil, "center")
        else
            local ok, err = KnoxMobile.Apps.safeCall(app.render, ac, 0, 0, s.w, s.h - top)
            if not ok then
                for i, l in ipairs(UI.wrap(T("IGUI_KnoxMobile_AppError", "This app stopped working."), s.w - 8)) do
                    ac:text(l, 4, 4 + (i - 1) * lineH())
                end
                Util.log("app", app.id, "failed:", err)
            end
        end
    else
        self:drawHome(c, top)
    end
    if self.textBox then
        -- Typing: the screen clears behind the box (second pass: on the Cinderblock the settings rows and a thread's
        -- "Enter: reply" showed through), the prompt sits just above it.
        c:rect(0, 0, s.w, s.h, self.style.bg, 1)
        -- The prompt wraps upward from just above the box (r8: "Who's in the gro..." was cut on the Cinderblock).
        local promptLines = UI.wrap(self.textPrompt or "", s.w - 8)
        for i, l in ipairs(promptLines) do
            c:text(l, 4, s.h - (#promptLines - i + 2) * lineH() - 13, self.style.fg)
        end
    end
    self:drawBanner(c, top)
    self:drawCracks(c, state)
    self:clearStencilRect()
end

-- A thin line from small squares (the vanilla drawLine2 is a nil-texture quad that draws nothing, r7).
function Panel:line(x1, y1, x2, y2, size, a, r, g, b)
    local dx, dy = x2 - x1, y2 - y1
    local n = math.max(1, math.floor(math.max(math.abs(dx), math.abs(dy)) / size))
    for i = 0, n do
        self:drawRect(math.floor(x1 + dx * i / n), math.floor(y1 + dy * i / n), size, size, a, r, g, b)
    end
end

-- Scratches and cracks drawn over the screen; the pattern is fixed per phone (from its item id). Each line has a
-- dark edge so it shows on light screens too.
function Panel:drawCracks(c, state)
    if state.condition ~= "scratched" and state.condition ~= "cracked" then return end
    local seed = Mod.floor((self.item:getID() * 7919), 2147483647)
    local function rand(n)
        seed = Mod.floor((seed * 16807), 2147483647)
        return Mod.floor(seed, n)
    end
    local w, h = c.w, c.h
    if state.condition == "scratched" then
        for _ = 1, 3 do
            local x, y = rand(w), rand(h)
            local x2, y2 = x + rand(30) - 15, y + rand(20) - 10
            self:line(c.sx + x + 1, c.sy + y + 1, c.sx + x2 + 1, c.sy + y2 + 1, 1, 0.3, 0, 0, 0)
            self:line(c.sx + x, c.sy + y, c.sx + x2, c.sy + y2, 1, 0.45, 1, 1, 1)
        end
        return
    end
    local cx, cy = w * 0.2 + rand(math.max(1, math.floor(w * 0.6))), h * 0.2 + rand(math.max(1, math.floor(h * 0.6)))
    for _ = 1, 7 do
        local x, y = cx, cy
        local dx, dy = rand(41) - 20, rand(41) - 20
        for _ = 1, 4 do
            local nx, ny = x + dx + rand(15) - 7, y + dy + rand(15) - 7
            self:line(c.sx + x + 1, c.sy + y + 1, c.sx + nx + 1, c.sy + ny + 1, 1, 0.45, 0, 0, 0)
            self:line(c.sx + x, c.sy + y, c.sx + nx, c.sy + ny, 1, 0.8, 0.9, 0.95, 1)
            x, y = nx, ny
        end
    end
end

function Panel:flicker()
    local t = getTimestampMs()
    if t >= (self.nextFlicker or 0) then
        self.flickerUntil = t + 150
        self.nextFlicker = t + 1500 + ZombRand(2500)
        if ZombRand(3) == 0 then getSoundManager():playUISound("KnoxMobileCrackle") end
    end
    return t < (self.flickerUntil or 0)
end

-- In Project Viewpoint's first- and third-person views the open phone captures the mouse, which makes Viewpoint
-- free the cursor (client/KnoxMobile/Viewpoint.lua). Checked a few times a second, so switching views works.
function Panel:followView()
    local t = getTimestampMs()
    if t < (self.nextViewCheck or 0) then return end
    self.nextViewCheck = t + 250
    local VP = KnoxMobile.Viewpoint
    -- First person has two modes (2026-10-18): using the phone (cursor free) and walking and looking
    -- (mouse-look; the numpad and arrows drive the phone). The middle mouse button switches.
    local want = VP ~= nil and VP.active() and not (self.firstPerson and UI.walk)
    if want ~= (self.captured == true) then
        self.captured = want
        self:setCapture(want)
    end
    -- Into or out of first person: the phone takes the other place on the next tick (held up, or in the corner).
    if VP and (VP.view() == "first") ~= (self.firstPerson == true) then UI.relayout = true end
end

-- The PIN system, explained once per character the first time they try a locked found phone (Meta, 2026-10-23: "needs
-- a popup first time you try"). Opened from the game tick, not from inside the phone's draw. It takes the mouse so its
-- OK works in Viewpoint's views too, then hands the mouse back to the phone.
function UI.wantPinHelp(player)
    if UI.pinHelp or not player then return end
    local md = player:getModData()
    if md.KnoxMobilePinHelp then return end
    md.KnoxMobilePinHelp = true
    UI.pinHelp = { player = player }
end

local function pinHelpText()
    local lines = {
        "<SIZE:medium> " .. T("IGUI_KnoxMobile_PinHelpTitle", "A dead person's phone") .. " <LINE> <SIZE:small> ",
        T("IGUI_KnoxMobile_PinHelp1", "It's locked with the owner's 4-digit PIN. Look for it on their body:") .. " <LINE> ",
        T("IGUI_KnoxMobile_PinHelp2", "- Their ID card may show a birthday: 'born 03/14/61' means the PIN is 0314 (month, day)."),
        T("IGUI_KnoxMobile_PinHelp3", "- Or their wallet holds a scrap of paper with the 4 digits.") .. " <LINE> ",
        T("IGUI_KnoxMobile_PinHelp4", "No clue? Right-click the phone: Try to crack the PIN."),
        T("IGUI_KnoxMobile_PinHelp5", "Electrical skill helps; a fail locks it for an hour."),
        T("IGUI_KnoxMobile_PinHelp6", "A dead phone needs charging and turning on first."),
    }
    return table.concat(lines, " <LINE> ")
end

Tick.add("pin help popup", function()
    local want = UI.pinHelp
    if not want or want.shown then return end
    want.shown = true
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local box = ISModalRichText:new(sw / 2 - 260, sh / 2 - 120, 520, 240, pinHelpText(), false, nil, function()
        -- OK: the game already removed the window; let go of the mouse too, so nothing invisible keeps it.
        if UI.pinHelpBox then UI.pinHelpBox:setCapture(false) end
        UI.pinHelpBox = nil
        UI.pinHelp = nil
        local p = UI.panel
        if p then p.captured = nil; p.nextViewCheck = 0 end
    end, want.player:getPlayerNum())
    box:initialise()
    box.chatText:paginate()
    box:setHeightToContents()
    box:setY(sh / 2 - box:getHeight() / 2)
    box:setAlwaysOnTop(true)
    box:addToUIManager()
    box:bringToTop()
    box:setCapture(true)
    UI.pinHelpBox = box
end, 100)

-- The middle mouse button switches first person between using the phone and walking and looking.
UI.walk = false
Tick.add("phone walk mode", function()
    local down = isMouseButtonDown(2)
    local pressed = down and not UI.middleWasDown
    UI.middleWasDown = down
    local p = UI.panel
    if not (pressed and p and p.firstPerson) then return end
    UI.walk = not UI.walk
    p.nextViewCheck = 0
    KnoxMobile.Client.toast(UI.walk
        and T("IGUI_KnoxMobile_WalkMode", "Walk and look: numpad 8 4 6 2 move, 5 opens, 0 goes back. Middle mouse: use the phone.")
        or T("IGUI_KnoxMobile_UseMode", "Using the phone. Middle mouse: walk and look."))
end, 30)

-- Walking and looking, the arrows and Enter drive the phone too, read straight from the keyboard (final test: they
-- never reached the phone there; the numpad did).
local WALK_KEYS = nil
local function walkKeys()
    WALK_KEYS = WALK_KEYS or { [Keyboard.KEY_UP] = "up", [Keyboard.KEY_DOWN] = "down", [Keyboard.KEY_LEFT] = "left",
        [Keyboard.KEY_RIGHT] = "right", [Keyboard.KEY_RETURN] = "select" }
    return WALK_KEYS
end
Tick.add("phone walk keys", function()
    local p = UI.panel
    if not (p and UI.walk and p.firstPerson) or p.textBox then UI.walkHeld = nil; return end
    local held = UI.walkHeld or {}
    UI.walkHeld = held
    for key, dir in pairs(walkKeys()) do
        local down = isKeyDown(key)
        -- The first tick only notes what is already down (the key that switched modes).
        if down and held[key] == false then
            if isDebugEnabled() then Util.log("walk key", key, "->", dir, "(arrows)") end
            p:input({ type = "key", key = dir })
        end
        held[key] = down
    end
end, 30)

Tick.add("phone relayout", function()
    if not UI.relayout then return end
    UI.relayout = false
    local p = UI.panel
    if p then UI.reopen(p.player, p.item) end
end, 100)

-- First person on a call (the phone at the ear): a small call bar instead of the phone.
function Panel:fpCall()
    local call = KnoxMobile.Client and KnoxMobile.Client.call
    return self.firstPerson == true and call ~= nil and call.status ~= "incoming"
end

-- First person, walking and looking, with the Camera open: the phone is out of sight (Live.hide), so the screen
-- shows the photo's corners and the count. This is UI, never in the photo (the camera copies the world before it).
function Panel:drawCameraMarks()
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local cw, ch = sw, sh
    if cw * 3 > ch * 4 then cw = math.floor(ch * 4 / 3) else ch = math.floor(cw * 3 / 4) end
    local ox, oy = math.floor((sw - cw) / 2) - self:getAbsoluteX(), math.floor((sh - ch) / 2) - self:getAbsoluteY()
    local len, t = math.floor(math.min(cw, ch) / 14), 3
    for _, c in ipairs({ { 0, 0, 1, 1 }, { cw, 0, -1, 1 }, { 0, ch, 1, -1 }, { cw, ch, -1, -1 } }) do
        local x, y = ox + c[1], oy + c[2]
        self:drawRect(c[3] > 0 and x or x - len, c[4] > 0 and y or y - t, len, t, 0.85, 1, 1, 1)
        self:drawRect(c[3] > 0 and x or x - t, c[4] > 0 and y or y - len, t, len, 0.85, 1, 1, 1)
    end
    local spec = require("KnoxMobile/Core/CameraSpec").forFamily(self.family)
    local state = self:state()
    local n = state and #(state.contents.photos or {}) or 0
    local text = (KnoxMobile.Camera and KnoxMobile.Camera.blocked())
        or spec and n >= spec.max and T("IGUI_KnoxMobile_CameraFull", "Memory full (%1)", spec.max)
        or T("IGUI_KnoxMobile_CameraWalkHint2", "Enter or numpad 5: photo   %1/%2   Left/Right: selfie", n,
            spec and spec.max or 0)
    local tw = getTextManager():MeasureStringX(UIFont.Medium, text)
    local lh = getTextManager():getFontHeight(UIFont.Medium)
    -- At the top of the picture: the hotbar covers the bottom (second pass).
    self:drawRect(ox + cw / 2 - tw / 2 - 8, oy + 18, tw + 16, lh + 8, 0.5, 0, 0, 0)
    self:drawText(text, ox + cw / 2 - tw / 2, oy + 22, 1, 1, 1, 1, UIFont.Medium)
end

-- First person, walking and looking, with the live screen on the 3D phone: no 2D phone at all (vision #1).
function Panel:hiddenInWalk()
    local Live = KnoxMobile.Live
    return self.firstPerson == true and UI.walk == true and Live ~= nil and Live.active()
end

function Panel:drawCallBar()
    local call = KnoxMobile.Client.call
    local lh = getTextManager():getFontHeight(UIFont.Small)
    local w, h = math.min(self.width, 320), lh * 2 + 16
    local x, y = math.floor((self.width - w) / 2), self.height - h - 4
    -- What the other side just said (a family call's captions), above the bar.
    local caption = KnoxMobile.Client.callCaption
    if caption and caption ~= "" then
        local lines = UI.wrap(caption, math.max(w, 420) - 16)
        local cw = math.max(w, 420)
        local cx = math.floor((self.width - cw) / 2)
        local ch = math.min(#lines, 3) * lh + 10
        self:drawRect(cx, y - ch - 6, cw, ch, 0.8, 0.04, 0.05, 0.07)
        for i = 1, math.min(#lines, 3) do self:drawText(lines[i], cx + 8, y - ch - 6 + 5 + (i - 1) * lh, 1, 1, 1, 1, UIFont.Small) end
    end
    self:drawRect(x, y, w, h, 0.88, 0.06, 0.07, 0.09)
    self:drawRectBorder(x, y, w, h, 0.9, 0.5, 0.55, 0.62)
    local who = call.name or call.number or ""
    local status = call.status == "outgoing" and T("IGUI_KnoxMobile_CallingWho", "Calling %1...", who)
        or T("IGUI_KnoxMobile_OnCallWho", "On a call: %1", who)
    self:drawText(status, x + 8, y + 5, 1, 1, 1, 1, UIFont.Small)
    local label = T("IGUI_KnoxMobile_HangUp", "Hang up")
    local bw = getTextManager():MeasureStringX(UIFont.Small, label) + 18
    local b = { x = x + w - bw - 6, y = y + h - lh - 9, w = bw, h = lh + 4 }
    self:drawRect(b.x, b.y, b.w, b.h, 1, 0.75, 0.15, 0.12)
    self:drawText(label, b.x + 9, b.y + 2, 1, 1, 1, 1, UIFont.Small)
    self:drawText(T("IGUI_KnoxMobile_HangUpKeys", "or Backspace"), x + 8, b.y + 2, 0.7, 0.72, 0.78, 1, UIFont.Small)
    self.callBarHang = b
end

-- An outline with rounded corners: straight sides, and quarter circles stepped in small squares.
function Panel:roundedEdge(x, y, w, h, r, t, a, col)
    r = math.max(t, math.min(r, math.floor(math.min(w, h) / 2)))
    self:drawRect(x + r, y, w - 2 * r, t, a, col[1], col[2], col[3])
    self:drawRect(x + r, y + h - t, w - 2 * r, t, a, col[1], col[2], col[3])
    self:drawRect(x, y + r, t, h - 2 * r, a, col[1], col[2], col[3])
    self:drawRect(x + w - t, y + r, t, h - 2 * r, a, col[1], col[2], col[3])
    local steps = math.max(6, math.floor(r / 1.5))
    local rr = r - t / 2
    for i = 0, steps do
        local ang = (i / steps) * math.pi / 2
        local dx, dy = math.cos(ang) * rr, math.sin(ang) * rr
        for _, c in ipairs({ { x + r - dx, y + r - dy }, { x + w - r + dx, y + r - dy },
                { x + r - dx, y + h - r + dy }, { x + w - r + dx, y + h - r + dy } }) do
            self:drawRect(math.floor(c[1] - t / 2), math.floor(c[2] - t / 2), t, t, a, col[1], col[2], col[3])
        end
    end
end

function Panel:drawFrame()
    self:followView()
    self:watchLostClicks()
    self.callBarHang = nil
    if self:fpCall() or self:hiddenInWalk() then return end
    local f = self.frameRect
    if self.frameTex then
        self:drawTextureScaled(self.frameTex, f.x, f.y, f.w, f.h, 1, 1, 1, 1)
    else
        self:drawRect(f.x, f.y, f.w, f.h, 1, 0.12, 0.12, 0.14)
    end
    if self.lcdRect then
        local l = self.lcdRect
        self:drawRect(l.x, l.y, l.w, l.h, 1, self.style.bg[1], self.style.bg[2], self.style.bg[3])
        self:drawRectBorder(0, 0, self.width, ZOOM_H - 6, 1, 0.2, 0.2, 0.22)
        -- The phone's own little LCD shows what the magnified strip shows (final test: it stayed blank), from the live
        -- screen's copy (stored bottom-up; drawTextureAllPoint takes screen coordinates).
        local Live = KnoxMobile.Live
        local shot = Live and Live.active() and Live.texture()
        if shot then
            local x0, y0 = self:getAbsoluteX() + l.x, self:getAbsoluteY() + l.y
            self:drawTextureAllPoint(shot, x0, y0 + l.h, x0 + l.w, y0 + l.h, x0 + l.w, y0, x0, y0, 1, 1, 1, 1)
        end
    end
    -- A fitted case shows as a colored edge around the phone (spec §8.2).
    local state = self:state()
    local case = state and state.look.case
    local col = case and CASE_COLORS[case]
    if col then
        -- Around the phone's body with rounded corners (FrameBodies.lua; r8: a square box left gaps at the corners),
        -- and a light outer line so even a dark case shows against a dark world.
        local body = FRAME_BODIES[artIdOf(self.model)]
        local sx, sy = f.w / self.frameArt.width, f.h / self.frameArt.height
        local bx, by = f.x + (body and body.x or 0) * sx, f.y + (body and body.y or 0) * sy
        local bw, bh = (body and body.w or self.frameArt.width) * sx, (body and body.h or self.frameArt.height) * sy
        local r = (body and body.r or 0) * sx
        self:roundedEdge(bx - 4, by - 4, bw + 8, bh + 8, r + 4, 1, 0.6, { 0.85, 0.85, 0.82 })
        self:roundedEdge(bx - 3, by - 3, bw + 6, bh + 6, r + 3, 3, 0.95, col)
    end
    self:drawKeyFaces()
end

-- Text drawn at a given pixel height whatever the game's font size option says (labels on the phone's own keys).
local function keyText(self, str, x, y, px, col)
    local z = px / getTextManager():getFontHeight(UIFont.Small)
    self:drawTextZoomed(str, x, y, z, col[1], col[2], col[3], 1, UIFont.Small)
end
local function keyTextW(str, px)
    return getTextManager():MeasureStringX(UIFont.Small, str) * px / getTextManager():getFontHeight(UIFont.Small)
end

-- Small marks for keys without text: a handset (call and end), a dash (soft keys), up and down arrows (the rocker).
local function keyMark(self, mark, r, col)
    local cx, cy = r.x + r.w / 2, r.y + r.h / 2
    local u = math.max(1, math.floor(math.min(r.w, r.h) / 9))
    if mark == "handset" then
        self:drawRect(cx - 4 * u, cy - u, 8 * u, u, 1, col[1], col[2], col[3])
        self:drawRect(cx - 4 * u, cy, 2 * u, 2 * u, 1, col[1], col[2], col[3])
        self:drawRect(cx + 2 * u, cy, 2 * u, 2 * u, 1, col[1], col[2], col[3])
    elseif mark == "dash" then
        self:drawRect(cx - 3 * u, cy - math.floor(u / 2), 6 * u, u, 1, col[1], col[2], col[3])
    elseif mark == "updown" then
        for i = 0, 2 do
            self:drawRect(cx - i * u, r.y + r.h * 0.2 + i * u, (2 * i + 1) * u, u, 1, col[1], col[2], col[3])
            self:drawRect(cx - i * u, r.y + r.h * 0.8 - (i + 1) * u, (2 * i + 1) * u, u, 1, col[1], col[2], col[3])
        end
    end
end

-- The keypad phones' front keys, printed over the frame art in each key's own color (KeyFaces.lua, from the art):
-- digits with their letters, function key names and marks, sized to the key (r8: blank or smudged keys).
function Panel:drawKeyFaces()
    local faces = KEY_FACES[artIdOf(self.model)]
    if not faces then return end
    local _, colorName = Phones.model(self.item)
    local byColor = faces[(tostring(colorName or ""):gsub("[^%w]", ""))]
    if not byColor then for _, f in pairs(faces) do byColor = byColor or f end end
    faces = byColor
    for _, r in ipairs(self.keyRects) do
        local keyFace = faces[r.id]
        local digit = r.id:match("^Key(.)$")
        local mark = KEY_MARK[r.id]
        local word = KEY_PRINT[r.id]
        if keyFace and (digit or mark or word) then
            local ink = (keyFace[1] + keyFace[2] + keyFace[3]) / 3 > 0.55 and { 0.1, 0.1, 0.12 } or { 0.97, 0.97, 0.97 }
            local inset = math.max(1, math.floor(math.min(r.w, r.h) * 0.14))
            self:drawRect(r.x + inset, r.y + inset, r.w - 2 * inset, r.h - 2 * inset, 1, keyFace[1], keyFace[2], keyFace[3])
            if digit then
                local letters = KEY_LETTERS[r.id]
                local pxD = math.max(7, math.floor(r.h * 0.8))
                local pxL = math.max(6, math.floor(r.h * 0.55))
                local dw = keyTextW(digit, pxD)
                local lw = letters and keyTextW(letters, pxL) or 0
                local dim = { ink[1] * 0.6 + keyFace[1] * 0.4, ink[2] * 0.6 + keyFace[2] * 0.4, ink[3] * 0.6 + keyFace[3] * 0.4 }
                if letters and dw + 3 + lw <= r.w - 2 * inset - 2 then
                    local gx = r.x + math.floor((r.w - (dw + 3 + lw)) / 2)
                    keyText(self, digit, gx, r.y + (r.h - pxD) / 2, pxD, ink)
                    keyText(self, letters, gx + dw + 3, r.y + (r.h - pxL) / 2 + 1, pxL, dim)
                elseif letters and r.h >= 26 then
                    pxD, pxL = math.floor(r.h * 0.55), math.floor(r.h * 0.4)
                    keyText(self, digit, r.x + (r.w - keyTextW(digit, pxD)) / 2, r.y + 1, pxD, ink)
                    keyText(self, letters, r.x + (r.w - keyTextW(letters, pxL)) / 2, r.y + 1 + pxD * 0.85, pxL, dim)
                else
                    keyText(self, digit, r.x + (r.w - dw) / 2, r.y + (r.h - pxD) / 2, pxD, ink)
                end
            elseif word then
                local px = math.max(6, math.floor(r.h * 0.65))
                local w = keyTextW(word, px)
                if w > r.w - 2 * inset then
                    px = math.max(6, math.floor(px * (r.w - 2 * inset) / w))
                    w = keyTextW(word, px)
                end
                keyText(self, word, r.x + (r.w - w) / 2, r.y + (r.h - px) / 2, px, ink)
            else
                keyMark(self, mark, r, (r.id == "Call" and { 0.15, 0.55, 0.2 }) or (r.id == "End" and { 0.75, 0.15, 0.12 })
                    or ink)
            end
        end
    end
end

-- The name of the front button under the mouse, in a small box above it.
function Panel:drawKeyName()
    if not self:isMouseOver() then return end
    local mx, my = self:getMouseX(), self:getMouseY()
    for _, r in ipairs(self.keyRects) do
        local name = KEY_NAMES[r.id]
        if name and mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h then
            local w, h = textW(name) + 8, lineH() + 4
            local x = math.floor(math.max(0, math.min(self.width - w, r.x + r.w / 2 - w / 2)))
            local y = math.max(0, r.y - h - 2)
            self:drawRect(x, y, w, h, 0.85, 0, 0, 0)
            self:drawText(name, x + 4, y + 2, 1, 1, 1, 1, font())
            return
        end
    end
end

function Panel:drawAll()
    local player = self.player
    if not player or player:isDead() or not Phones.findById(player, self.item:getID()) then
        UI.close()
        return
    end
    local t = getTimestampMs()
    if t >= self.nextLocate then
        self.nextLocate = t + 1000
        local md = player:getModData()
        self.located = WorldModel.locatePlayer(player, self.model, md.KnoxMobilePasswords or {})
        if KnoxMobile.Coverage then KnoxMobile.Coverage.signalHint(player, self.model, self.located) end
        self:reportActivity()
    end
    -- The live screen (ZombieBuddy): the screen drawn once more into a texture for the held 3D phone.
    local Live = KnoxMobile.Live
    if Live and Live.active() then
        local s = self.screen
        if Live.begin(self:getAbsoluteX() + s.x, self:getAbsoluteY() + s.y, s.w, s.h) then
            self:drawScreen()
            Live.finish()
            Live.composite(self)
        end
    end
    local camera = self.view == "app" and self.appId == "camera"
    local Camera = KnoxMobile.Camera
    local selfie = Camera ~= nil and Camera.front == true
    -- The back camera in first person: no phone in the picture, and the empty arm down out of view (second
    -- pass). The selfie camera keeps the phone up, facing you; it only hides while the camera glances back.
    -- First person as soon as the view tracker sees it (release test: after Shift+O the phone waited for the
    -- panel's relayout and was in the photo).
    local VP = KnoxMobile.Viewpoint
    local fp = self.firstPerson == true or (VP ~= nil and VP.view() == "first")
    local backFP = camera and fp and not selfie and not self:fpCall()
    KnoxMobile.Hold.cameraDown = backFP or nil
    if Live then
        Live.hide(self, backFP or (camera and Camera ~= nil and Camera.hideHeld == true))
        Live.picture(self)
    end
    -- First person: on a call only a small bar shows; walking and looking with the live 3D screen, nothing (the phone
    -- in the hand is the screen), or with the Camera open the photo's corners.
    if self:fpCall() then self:drawCallBar(); return end
    if self:hiddenInWalk() then
        if camera then self:drawCameraMarks() end
        return
    end
    self:drawScreen()
    self:keepTextFocus()
    -- The button the mouse just pressed lights up briefly.
    local p = self.pressed
    if p then
        if t < p.untilMs then self:drawRect(p.r.x, p.r.y, p.r.w, p.r.h, 0.35, 1, 1, 1) else self.pressed = nil end
    end
    self:drawKeyName()
    -- Close button at the top right of the phone area: vanilla's window close icon on a dark square
    -- (onMouseDown uses the same square).
    local cy = self.lcdRect and ZOOM_H or 0
    local tex = getTexture("media/ui/inventoryPanes/Button_Close.png")
    self:drawRect(self.width - CLOSE, cy, CLOSE, CLOSE, 0.55, 0, 0, 0)
    if tex then
        self:drawTextureScaled(tex, self.width - CLOSE + 3, cy + 3, CLOSE - 6, CLOSE - 6, 0.95, 1, 1, 1)
    else
        self:drawTextCentre("x", self.width - CLOSE / 2, cy + 2, 0.95, 0.95, 0.95, 1, UIFont.Small)
    end
    -- Live-screen spike: the captured texture at half size beside the phone, in a magenta frame.
    local liveTex = Live and Live.showCopy() and Live.texture()
    if liveTex then
        local s = self.screen
        local pw, ph = math.floor(s.w / 2), math.floor(s.h / 2)
        local px = KnoxMobile.Options.side() == "left" and (self.width + 8) or (-pw - 8)
        self:drawRect(px - 2, -2, pw + 4, ph + 4, 1, 1, 0, 1)
        -- The capture is stored bottom-up (r8: the copy showed upside down): its corners are drawn flipped, in screen
        -- coordinates (final test: drawn at the panel's own, it landed off the frame and showed solid magenta).
        local ax, ay = self:getAbsoluteX() + px, self:getAbsoluteY()
        self:drawTextureAllPoint(liveTex, ax, ay + ph, ax + pw, ay + ph, ax + pw, ay, ax, ay, 1, 1, 1, 1)
    end
end

-- A drawing error would repeat every frame; instead it is logged once (with the phone and screen) and the
-- phone closes with a short message.
local function guarded(self, fn)
    local ok, err = pcall(fn, self)
    if ok then return end
    pcall(function() self:clearStencilRect() end) -- an error mid-screen must not leave the clip on for other UI
    Util.log("ERROR drawing the phone (" .. tostring(self.model and self.model.id) .. ", " .. tostring(self.currentMode) .. "): "
        .. tostring(err))
    if KnoxMobile.Client then KnoxMobile.Client.toast(T("IGUI_KnoxMobile_PhoneFroze", "Your phone froze. Open it again.")) end
    UI.close()
end

-- Everything is drawn in prerender: the game draws a panel's children (the text box) after prerender and before
-- render, so drawing the screen in render covered whatever was being typed (PC test, the Dial prompt).
function Panel:prerender()
    guarded(self, Panel.drawFrame)
    if UI.panel ~= self then return end
    guarded(self, Panel.drawAll)
    self.drawnAt = getTimestampMs()
end

-- A bare render() (tests, previews) draws the phone here; in the game prerender already did. After the children
-- (the selfie camera's face) are drawn, the selfie picture is grabbed (Camera.afterUI).
function Panel:render()
    if KnoxMobile.Camera then guarded(self, KnoxMobile.Camera.afterUI) end
    if self.drawnAt and getTimestampMs() - self.drawnAt < 100 then return end
    guarded(self, Panel.drawAll)
end

function Panel:reportActivity()
    local state = self:state()
    local now = self:mode(state)
    -- A phone that died, broke or went into rice with the radio app open stops playing (and the earbuds'
    -- hearing penalty ends). Calls end on the server, which drops them when a phone stops working.
    if (now == "off" or now == "broken" or now == "rice") and KnoxMobile.Audio then KnoxMobile.Audio.stopRadio() end
    if not state.power.on then KnoxMobile.Hold.report(self.player, self.item, "idle"); return end
    local drain = "screen"
    local mode = self.currentMode
    if mode == "call" or (KnoxMobile.Audio and KnoxMobile.Audio.mode) then drain = "audio"
    elseif mode == "app" then
        local app = KnoxMobile.Apps.get(self.appId)
        drain = app and app.drain or "screen"
    end
    KnoxMobile.Hold.report(self.player, self.item, drain, not (self.located and self.located.network), self.appData.flashlight)
end

-- Input --------------------------------------------------------------------------------------------
function Panel:input(ev)
    if self:dismissBanner(ev) then return end
    -- A key typed on the keyboard lights the phone's own key for it too (and on the 3D phone: Live.keyLights).
    if ev.type == "key" and not (self.pressed and getTimestampMs() < self.pressed.untilMs) then
        for _, r in ipairs(self.keyRects) do
            if r.id == "Key" .. ev.key or (UI.BUTTON_KEYS and UI.BUTTON_KEYS[r.id] == ev.key) then
                self.pressed = { r = r, untilMs = getTimestampMs() + 150 }
                break
            end
        end
    end
    local state = self:state()
    local mode = self:mode(state)
    if ev.type == "tap" and state.condition == "cracked" and ZombRand(100) < CRACK_MISS then
        if isDebugEnabled() then Util.log("tap swallowed by the cracked screen") end
        return
    end
    if ev.type == "key" and KEYPAD[self.family] and state.power.on and state.look.soundMode ~= "silent" then
        getSoundManager():playUISound("KnoxMobileButton")
    end
    if mode == "off" then
        if (ev.type == "key" and ev.key == "select") or ev.type == "tap" then
            KnoxMobileAction.queue(self.player, "powerOn", self.item)
        elseif ev.type == "key" and ev.key == "back" then UI.close() end
        return
    end
    if mode == "broken" or mode == "rice" then
        if ev.type == "key" and ev.key == "back" then UI.close() end
        return
    end
    if self.source then
        if self.source.onInput then
            local c = self:ctx(0, 0, self.screen.w, self.screen.h, {})
            pcall(self.source.onInput, c, ev)
        end
        return
    end
    if mode == "call" then
        self:callInput(ev)
    elseif mode == "lock" then
        self:lockInput(ev)
    elseif mode == "app" then
        if ev.type == "key" and ev.key == "back" and not self.appData.keepBack then self:goHome(); return end
        local app = KnoxMobile.Apps.get(self.appId)
        if app and app.onInput then
            local top = self.contentTop or 0
            if ev.type == "tap" then ev.y = ev.y - top end
            local ac = self:ctx(0, top, self.screen.w, self.screen.h - top, self.appData)
            local ok, handled = KnoxMobile.Apps.safeCall(app.onInput, ac, ev)
            if ok and handled == "back" then self:goHome() end
        end
    else
        if ev.type == "key" and ev.key == "back" then UI.close(); return end
        self:homeInput(ev)
    end
end

-- What each physical front button does (ids from tools/blender/make_phone.py --keys). Phones name their keys
-- differently; all of them map onto the same few phone keys the keyboard also sends.
local BUTTON_KEYS = {
    Call = "select", FSND = "select", Fn1 = "select", Soft1 = "select", Navi = "select", Trackpad = "select",
    FFCN = "select",
    End = "back", FEND = "back", Fn4 = "back", Fn3 = "back", Soft2 = "back", C = "back", Back = "back", FCLR = "back",
    Home = "home", Menu = "home", Fn2 = "home",
    FRCL = "up", FSTO = "down",
}
local SOUND_NEXT = { ring = "vibrate", vibrate = "silent", silent = "ring" }
UI.BUTTON_KEYS = BUTTON_KEYS

local function inside(r, x, y) return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end

-- A click on a physical button: the key it stands for (joystick and rocker by where they are pressed).
function Panel:buttonKey(r, x, y)
    local digit = r.id:match("^Key(.)$")
    if digit then return digit end
    if r.id == "Rocker" then return y < r.y + r.h / 2 and "up" or "down" end
    if r.id == "Joy" then
        local dx, dy = (x - r.x) / r.w - 0.5, (y - r.y) / r.h - 0.5
        if math.abs(dx) < 0.17 and math.abs(dy) < 0.17 then return "select" end
        if math.abs(dx) > math.abs(dy) then return dx < 0 and "left" or "right" end
        return dy < 0 and "up" or "down"
    end
    return BUTTON_KEYS[r.id] or r.id
end

-- With a text box open, the phone's own keys type into it (r8: the Cinderblock's keys couldn't set a PIN): digits
-- add, back (C, CLR, End) deletes, select (OK, SND, Call) sends. The box keeps the keyboard.
function Panel:keyIntoText(key)
    local box = self.textBox
    local text = boxText(box)
    if key:match("^[%d%*#]$") then
        if not box.knoxMaxLen or #text < box.knoxMaxLen then box:setText(text .. key) end
    elseif key == "back" then
        box:setText(text:sub(1, -2))
    elseif key == "select" then
        if box.onCommandEntered then box.onCommandEntered(box) end
        return
    end
    pcall(function() box:focus() end)
end

function Panel:pressButton(r, x, y)
    self.pressed = { r = r, untilMs = getTimestampMs() + 150 }
    local key = self:buttonKey(r, x, y)
    if self.textBox then self:keyIntoText(key); return end
    local state = self:state()
    if key == "BPWR" then
        KnoxMobileAction.queue(self.player, state.power.on and "powerOff" or "powerOn", self.item)
    elseif key == "BLOCK" then
        if state.power.on then KnoxMobile.Client.setting(self.item, "lock", true) end
    elseif key == "BVOL" then
        if state.power.on then
            KnoxMobile.Client.setting(self.item, "soundMode", SOUND_NEXT[state.look.soundMode] or "ring")
        end
    elseif key == "home" then
        if self:mode(state) == "app" then self:goHome() end
    else
        self:input({ type = "key", key = key })
    end
end

-- Debug mode: one log line per click on the phone, so a click that lands wrong shows where it went.
local function logClick(self, x, y, target)
    if not isDebugEnabled() then return end
    local s = self.screen
    Util.log(string.format("click %d,%d on a %dx%d phone at %d,%d (screen %d,%d %dx%d, %s view, mode %s): %s",
        math.floor(x), math.floor(y), self.width, self.height, math.floor(self.x or 0), math.floor(self.y or 0),
        s.x, s.y, s.w, s.h, self.captured and "captured" or "plain", tostring(self.currentMode), target))
end

-- Debug mode: a press over the phone that never reaches onMouseDown is logged with every UI element under the mouse
-- (top first), to name whatever lies over the phone and takes its clicks.
function Panel:watchLostClicks()
    if not isDebugEnabled() then return end
    local down = isMouseButtonDown(0)
    if down and not self.mouseWasDown then
        self.pressAt = getTimestampMs()
        self.lostCheckAt = self.pressAt + 100
        self.lostX, self.lostY = getMouseX(), getMouseY()
    end
    self.mouseWasDown = down
    if not self.lostCheckAt or getTimestampMs() < self.lostCheckAt then return end
    self.lostCheckAt = nil
    local mx, my = self.lostX, self.lostY
    local ax, ay = self:getAbsoluteX(), self:getAbsoluteY()
    -- Arrived: onMouseDown ran for this press (it can run a frame before this draw sees the button go down).
    if (self.arrivedAt or 0) >= self.pressAt - 250 then return end
    if mx < ax or my < ay or mx > ax + self.width or my > ay + self.height then return end
    local over = {}
    local ok = pcall(function()
        local list = UIManager.getUI()
        for i = list:size() - 1, 0, -1 do
            local e = list:get(i)
            if e:isVisible() and mx >= e:getAbsoluteX() and my >= e:getAbsoluteY()
                and mx < e:getAbsoluteX() + e:getWidth() and my < e:getAbsoluteY() + e:getHeight() then
                local t = e.getTable and e:getTable()
                local name = t and (t == self and "KnoxMobilePhonePanel" or t.Type) or tostring(e)
                over[#over + 1] = string.format("%s %dx%d at %d,%d", tostring(name), math.floor(e:getWidth()),
                    math.floor(e:getHeight()), math.floor(e:getAbsoluteX()), math.floor(e:getAbsoluteY()))
            end
        end
    end)
    Util.log("click " .. math.floor(mx - ax) .. "," .. math.floor(my - ay) .. " on the phone never arrived; under the mouse, top first: "
        .. (ok and table.concat(over, " | ") or "(UI list not readable)"))
end

function Panel:onMouseDown(x, y)
    self.arrivedAt = getTimestampMs()
    local hang = self.callBarHang
    if hang and x >= hang.x and x <= hang.x + hang.w and y >= hang.y and y <= hang.y + hang.h then
        KnoxMobile.Client.hangUp()
        return true
    end
    -- While capturing (Viewpoint's views) clicks off the phone arrive here too: they do nothing.
    if self.captured and (x < 0 or y < 0 or x > self.width or y > self.height) then
        logClick(self, x, y, "off the phone")
        return true
    end
    local cy = self.lcdRect and ZOOM_H or 0
    -- The close button, with a little slack around it (the phone's rounded corner below it is transparent anyway).
    if x > self.width - CLOSE - 6 and y >= cy - 2 and y < cy + CLOSE + 6 then
        logClick(self, x, y, "close button")
        UI.close()
        return true
    end
    local s = self.screen
    if inside(s, x, y) then
        local before = tostring(self.currentMode) .. tostring(self.appId)
        self:input({ type = "tap", x = x - s.x, y = y - s.y })
        logClick(self, x, y, "screen tap " .. math.floor(x - s.x) .. "," .. math.floor(y - s.y)
            .. (UI.panel == self and before ~= (tostring(self.currentMode) .. tostring(self.appId)) and " (changed screen)" or ""))
        return true
    end
    for _, r in ipairs(self.keyRects) do
        if inside(r, x, y) then
            logClick(self, x, y, "key " .. r.id)
            self:pressButton(r, x, y)
            return true
        end
    end
    logClick(self, x, y, "frame (drag)")
    return ISPanelJoypad.onMouseDown(self, x, y)
end

function Panel:onMouseWheel(del)
    if self.getMouseX then logClick(self, self:getMouseX(), self:getMouseY(), "wheel " .. tostring(del)) end
    self:input({ type = "wheel", delta = del })
    return true
end

local KEYS = nil
local function keyMap()
    if KEYS then return KEYS end
    KEYS = {
        [Keyboard.KEY_UP] = "up", [Keyboard.KEY_DOWN] = "down", [Keyboard.KEY_LEFT] = "left", [Keyboard.KEY_RIGHT] = "right",
        [Keyboard.KEY_RETURN] = "select", [Keyboard.KEY_NUMPADENTER] = "select", [Keyboard.KEY_BACK] = "back",
        [Keyboard.KEY_ESCAPE] = "back",
    }
    local digits = { Keyboard.KEY_0, Keyboard.KEY_1, Keyboard.KEY_2, Keyboard.KEY_3, Keyboard.KEY_4, Keyboard.KEY_5,
        Keyboard.KEY_6, Keyboard.KEY_7, Keyboard.KEY_8, Keyboard.KEY_9 }
    local pad = { Keyboard.KEY_NUMPAD0, Keyboard.KEY_NUMPAD1, Keyboard.KEY_NUMPAD2, Keyboard.KEY_NUMPAD3, Keyboard.KEY_NUMPAD4,
        Keyboard.KEY_NUMPAD5, Keyboard.KEY_NUMPAD6, Keyboard.KEY_NUMPAD7, Keyboard.KEY_NUMPAD8, Keyboard.KEY_NUMPAD9 }
    for i = 0, 9 do KEYS[digits[i + 1]] = tostring(i); KEYS[pad[i + 1]] = tostring(i) end
    -- With digits (the calculator): + - * / . = from the numpad or the main keys.
    KEYS[Keyboard.KEY_ADD], KEYS[Keyboard.KEY_SUBTRACT], KEYS[Keyboard.KEY_MINUS] = "+", "-", "-"
    KEYS[Keyboard.KEY_MULTIPLY], KEYS[Keyboard.KEY_DIVIDE], KEYS[Keyboard.KEY_SLASH] = "*", "/", "/"
    KEYS[Keyboard.KEY_DECIMAL], KEYS[Keyboard.KEY_PERIOD], KEYS[Keyboard.KEY_EQUALS] = ".", ".", "="
    KEYS[Keyboard.KEY_W], KEYS[Keyboard.KEY_A], KEYS[Keyboard.KEY_S], KEYS[Keyboard.KEY_D] = "w", "a", "s", "d"
    return KEYS
end

local TYPED = { ["+"] = true, ["-"] = true, ["*"] = true, ["/"] = true, ["."] = true, ["="] = true }
local WASD = { w = "up", a = "left", s = "down", d = "right" }

-- First person, walking and looking: the numpad drives the phone (8 4 6 2 move, 5 opens, 0 goes back), whatever the
-- app wants digits for; the top-row digits still type.
local WALK_PAD = nil
local function walkPad(panel)
    if not (UI.walk and panel.firstPerson) or panel.textBox then return nil end
    WALK_PAD = WALK_PAD or {
        [Keyboard.KEY_NUMPAD8] = "up", [Keyboard.KEY_NUMPAD2] = "down", [Keyboard.KEY_NUMPAD4] = "left",
        [Keyboard.KEY_NUMPAD6] = "right", [Keyboard.KEY_NUMPAD5] = "select", [Keyboard.KEY_NUMPAD0] = "back",
    }
    return WALK_PAD
end

-- The phone key always closes the phone, even where digits are typed (r7: on the lock screen 0 typed a PIN digit);
-- the numpad and the screen's own keypad still type its digit.
local function isPhoneKey(key) return KnoxMobile.Options ~= nil and key == KnoxMobile.Options.openKey() end

-- The phone keeps arrows, Enter, Backspace and Escape while it is open; digits (and + - * / . =) only when it
-- needs them, WASD only while an app steers with them.
function Panel:isKeyConsumed(key)
    if self.textBox then return false end
    if isPhoneKey(key) then return false end
    local pad = walkPad(self)
    if pad and pad[key] then return true end
    local k = keyMap()[key]
    if not k then return false end
    if k:match("^%d$") or TYPED[k] then return self.digits end
    if WASD[k] then return self.wasd == true end
    return true
end

function Panel:onKeyRelease(key)
    if self.textBox then
        if key == Keyboard.KEY_ESCAPE then self:cancelText() end
        return
    end
    if (key == Keyboard.KEY_RETURN or key == Keyboard.KEY_NUMPADENTER) and self.ignoreEnterUntil
        and getTimestampMs() < self.ignoreEnterUntil then
        self.ignoreEnterUntil = nil
        return
    end
    if isPhoneKey(key) then return end
    local pad = walkPad(self)
    -- Walking and looking, arrows and Enter come from the keyboard poll above.
    if pad and walkKeys()[key] then return end
    if pad and pad[key] then
        -- r8: numpad 6 and 2 didn't move the selection; this shows what arrives.
        if isDebugEnabled() then Util.log("walk key", key, "->", pad[key], "in", tostring(self.appId or self.view)) end
        self:input({ type = "key", key = pad[key] })
        return
    end
    local k = keyMap()[key]
    if not k then return end
    if (k:match("^%d$") or TYPED[k]) and not self.digits then return end
    if WASD[k] then
        if not self.wasd then return end
        k = WASD[k]
    end
    -- Shift + = is "+" and Shift + 8 is "*" on most keyboards.
    if self.digits and isShiftKeyDown() then
        if k == "=" then k = "+" elseif k == "8" then k = "*" end
    end
    self:input({ type = "key", key = k })
end

function Panel:onJoypadDown(button)
    if button == Joypad.AButton then self:input({ type = "key", key = "select" })
    elseif button == Joypad.BButton then self:input({ type = "key", key = "back" }) end
end

function Panel:onJoypadDirUp() self:input({ type = "key", key = "up" }) end
function Panel:onJoypadDirDown() self:input({ type = "key", key = "down" }) end
function Panel:onJoypadDirLeft() self:input({ type = "key", key = "left" }) end
function Panel:onJoypadDirRight() self:input({ type = "key", key = "right" }) end

-- Opening and closing ------------------------------------------------------------------------------
function UI.isOpen() return UI.panel ~= nil end

-- keepHold: reopening (new size or side) with the phone already in hand.
function UI.open(player, item, keepHold)
    if UI.panel then UI.close(keepHold) end
    UI.resetText()
    if keepHold then KnoxMobile.Hold.phone = item else KnoxMobile.Hold.raise(player, item) end
    local p = KnoxMobilePhonePanel:new(player, item)
    p:initialise()
    p:addToUIManager()
    p:bringToTop() -- above every other window, so its screen and keys get the clicks
    UI.panel = p
    -- Immersive first person (Options): open straight into walking and looking, where the live 3D phone is the only
    -- phone on screen. Without the live screen (no ZombieBuddy), or with the phone in the off hand (out of Viewpoint's
    -- first-person view), the on-screen phone stays.
    local Live = KnoxMobile.Live
    if p.firstPerson and KnoxMobile.Options.immersive() and Live and Live.active() and not UI.walk
        and player:getSecondaryHandItem() ~= item then
        UI.walk = true
        p.nextViewCheck = 0
        if not UI.immersiveHinted then
            UI.immersiveHinted = true
            KnoxMobile.Client.toast(T("IGUI_KnoxMobile_WalkMode",
                "Walk and look: numpad 8 4 6 2 move, 5 opens, 0 goes back. Middle mouse: use the phone."))
        end
    end
    local joypad = JoypadState.players[player:getPlayerNum() + 1]
    if joypad then setJoypadFocus(player:getPlayerNum(), p) end
end

function UI.close(keepHold)
    local p = UI.panel
    if not p then return end
    UI.panel = nil
    KnoxMobile.Hold.cameraDown = nil
    p:cancelText()
    p:closeApp()
    if p.captured then p:setCapture(false) end
    p:removeFromUIManager()
    if KnoxMobile.Live then
        KnoxMobile.Live.release(p.player)
        KnoxMobile.Live.unpicture(p.player, p.item)
    end
    if KnoxMobile.Audio then KnoxMobile.Audio.stopRadio() end
    local joypad = JoypadState.players[p.player:getPlayerNum() + 1]
    if joypad then setJoypadFocus(p.player:getPlayerNum(), nil) end
    if not keepHold then KnoxMobile.Hold.lower(p.player, p.item) end
end

function UI.refresh() end -- the panel redraws every frame from the synced item data

-- The phone to open: the one in hand, else a working one that is on, else a working one, else any
-- (r7: the phone key opened a broken phone over a working one).
function UI.pickPhone(player)
    local held = player:getSecondaryHandItem()
    if held and Phones.isPhone(held) then return held end
    held = player:getPrimaryHandItem()
    if held and Phones.isPhone(held) then return held end
    local phones = Phones.inventoryPhones(player)
    local function score(it)
        local st = Phones.get(it)
        if not st then return 0 end
        local works = st.condition ~= "broken" and not st.rice
        if works and st.power.on and st.battery.charge > 0 then return 3 end
        if works then return 2 end
        return 1
    end
    local best, bestScore = phones[1], -1
    for _, it in ipairs(phones) do
        local sc = score(it)
        if sc > bestScore then best, bestScore = it, sc end
    end
    return best
end

-- Reopens the phone (new size, side or view) on the app that was open, with its selection (it used to land home).
function UI.reopen(player, item)
    local old = UI.panel
    local appId = old and old.view == "app" and old.appId or nil
    local appData = old and old.appData
    UI.open(player, item, true)
    if appId and UI.panel then
        UI.panel:openApp(appId)
        if appData then UI.panel.appData = appData end
    end
end

-- Settings > Phone size: S, M, L in turn, saved in the mod options, and the phone reopens at the new size.
function UI.cycleSize(player, item)
    local opts = PZAPI and PZAPI.ModOptions and PZAPI.ModOptions:getOptions("KnoxMobile")
    local o = opts and opts:getOption("size")
    if not o then return end
    o:setValue(Mod.floor(o:getValue(), 3) + 1)
    PZAPI.ModOptions:save()
    UI.reopen(player, item)
end

-- Settings > Phone side: right or left, saved in the mod options.
function UI.flipSide(player, item)
    local opts = PZAPI and PZAPI.ModOptions and PZAPI.ModOptions:getOptions("KnoxMobile")
    local o = opts and opts:getOption("side")
    if not o then return end
    o:setValue(o:getValue() == 1 and 2 or 1)
    PZAPI.ModOptions:save()
    UI.reopen(player, item)
end

function UI.toggle(player)
    if UI.panel then UI.close(); return end
    local phone = UI.pickPhone(player)
    if phone then UI.open(player, phone) end
end

Events.OnKeyPressed.Add(Util.safe("phone key", function(key)
    local player = getPlayer()
    if not player or player:isDead() then return end
    local Options, VP = KnoxMobile.Options, KnoxMobile.Viewpoint
    local openKey = Options.openKey()
    local want = openKey
    if VP then want = VP.phoneKey(openKey, Options.viewKey()) end
    if want and key == want then UI.toggle(player); return end
    -- In Viewpoint's views the phone key may belong to Viewpoint Interface's build list: say once how to set one.
    if not want and key == openKey and not UI.viewKeyHinted then
        UI.viewKeyHinted = true
        local name = getKeyName and getKeyName(openKey) or "K"
        KnoxMobile.Client.toast(T("IGUI_KnoxMobile_ViewKeyHint",
            "Viewpoint Interface builds with %1 in first person. Set a phone key for it: Options > Mods > Knox Mobile.",
            name))
    end
end))

return UI
