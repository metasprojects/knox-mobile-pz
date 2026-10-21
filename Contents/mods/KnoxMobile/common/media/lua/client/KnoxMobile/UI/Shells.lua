-- Client: one home-screen shell per screen family (spec §4.6, §8.4). Each shell draws the app list its own
-- way and turns input into "open this app".
--   Segment LCD   one-line text menu with two soft keys (1993 brick)
--   Mono LCD      one big item per page (Sisu 3301)
--   Color feature a 3 x 3 icon menu that scrolls, the selected app named underneath (Sisu 6606)
--   Keyboard      a five-across icon grid with a clock header when there is room (Bramble)
--   Stylus        a Start bar, a Today strip and the Start menu with icons, rows sized to fill the screen
--   Modern        wallpaper, a clock and status widget, an icon grid with pages and a four-icon dock. Both
--                 modern phones have their navigation keys on the frame (Supernova IV) or a home button
--                 (PearPhone 4), so the screen shows page dots instead of an on-screen key bar.
-- Arrow keys move between icons by position (left, right, up, down go where you'd expect on any layout).
local Mod = require "KnoxMobile/Core/Mod"
local Util = require "KnoxMobile/Game/Util"
local Format = require "KnoxMobile/Core/Format"
local Calendar = require "KnoxMobile/Core/Calendar"

local T = Util.text
local Shells = {}
KnoxMobile.Shells = Shells

local TILE_COLORS = {
    { 0.85, 0.3, 0.3 }, { 0.3, 0.7, 0.4 }, { 0.3, 0.5, 0.9 }, { 0.9, 0.65, 0.2 }, { 0.6, 0.4, 0.85 }, { 0.2, 0.7, 0.75 },
}
-- The dock on modern phones, in order. Everything else goes in the grid.
-- Dock candidates by priority; the first four a phone has sit in the dock (no FM tuner: Notes takes the Radio's place).
local DOCK = { phone = 1, messages = 2, radio = 3, notes = 4, settings = 5 }
local DOCK_SIZE = 4
Shells.DOCK = DOCK
local WHITE = { 1, 1, 1 }
local DIM = { 0.82, 0.85, 0.9 }

-- Wallpapers (tools/art/make_wallpapers.py): 288 x 512 pictures, cropped to cover each screen.
local WALLPAPER_DIR = "media/ui/KnoxMobile/wallpapers/"
Shells.WALLPAPER_SIZE = { w = 288, h = 512 }
Shells.WALLPAPERS = {
    { file = "dusk", name = function() return T("IGUI_KnoxMobile_WpDuskShort", "Dusk") end,
        fallback = { { 0.45, 0.15, 0.30 }, { 0.10, 0.03, 0.10 } } },
    { file = "aurora", name = function() return T("IGUI_KnoxMobile_WpAurora", "Aurora") end,
        fallback = { { 0.05, 0.40, 0.45 }, { 0.01, 0.08, 0.10 } } },
    { file = "logowall", name = function() return T("IGUI_KnoxMobile_WpLogoShort", "Logo") end,
        fallback = { { 0.10, 0.20, 0.45 }, { 0.02, 0.04, 0.10 } } },
    { file = "skyline", name = function() return T("IGUI_KnoxMobile_WpSkylineShort", "Skyline") end,
        fallback = { { 0.30, 0.30, 0.35 }, { 0.05, 0.05, 0.06 } } },
    { file = "bluegrass", name = function() return T("IGUI_KnoxMobile_WpBluegrassShort", "Bluegrass") end,
        fallback = { { 0.10, 0.35, 0.20 }, { 0.02, 0.08, 0.05 } } },
    { file = "rain", name = function() return T("IGUI_KnoxMobile_WpRainShort", "Rain") end,
        fallback = { { 0.55, 0.35, 0.10 }, { 0.15, 0.08, 0.02 } } },
}

function Shells.wallpaperName(index)
    local wp = Shells.WALLPAPERS[index or 0]
    if not wp then return T("IGUI_KnoxMobile_WpPlain", "Plain") end
    return wp.name()
end

-- Phone-screen text sizes (UI/Phone.lua: capped against the game's font size option).
local function fontH(f) return KnoxMobile.UI.fontH(f or UIFont.Small) end
local function textW(s, f) return KnoxMobile.UI.textW(s, f or UIFont.Small) end
local function lineH() return fontH(UIFont.Small) end
local function medH() return fontH(UIFont.Medium) end

-- The biggest UI font (Large, Medium, Small) that fits the text in maxW x maxH. (Massive is a display face, not
-- a phone's.)
local BIG_FONTS = { "Large", "Medium", "Small" }
local function fitFont(s, maxW, maxH)
    for _, name in ipairs(BIG_FONTS) do
        local f = UIFont[name]
        if f and fontH(f) <= maxH and textW(s, f) <= maxW then return f end
    end
    return UIFont.Small
end

-- Darker bands at the top and bottom of a wallpaper so the status bar, labels and dock stay readable.
local function shade(c, top, h)
    local bands = 6
    local topH = math.floor(h * 0.12)
    for i = 0, bands - 1 do
        c:rect(0, top + math.floor(i * topH / bands), c.w, math.ceil(topH / bands), { 0, 0, 0 }, 0.28 * (1 - i / bands))
    end
    local botH = math.floor(h * 0.3)
    local y0 = top + h - botH
    for i = 0, bands - 1 do
        c:rect(0, y0 + math.floor(i * botH / bands), c.w, math.ceil(botH / bands) + 1, { 0, 0, 0 }, 0.05 + 0.3 * (i / bands))
    end
end

-- Cover: crop the picture (tw x th pixels) to the screen's shape around its middle, then fill the screen with it.
local function cover(c, tex, tw, th, top)
    local w, h = c.w, c.h - top
    local scale = math.max(w / tw, h / th)
    local cw, ch = w / scale, h / scale
    c.panel:drawSubTexture(tex, (tw - cw) / 2, (th - ch) / 2, cw, ch, c.sx, c.sy + top, w, h, 1, 1, 1, 1)
end

-- One of the phone's own photos (Camera, with the Java part) as the wallpaper. False until the picture is here, so the
-- usual wallpaper shows meanwhile.
function Shells.photoWallpaper(c, tex, top)
    if not tex or tex:getWidth() < 1 or tex:getHeight() < 1 then return false end
    top = top or 0
    cover(c, tex, tex:getWidth(), tex:getHeight(), top)
    shade(c, top, c.h - top)
    return true
end

function Shells.wallpaper(c, index, top)
    local wp = Shells.WALLPAPERS[index or 0]
    if not wp then return false end
    top = top or 0
    local w, h = c.w, c.h - top
    local tex = getTexture(WALLPAPER_DIR .. wp.file .. ".png")
    if tex then
        local size = Shells.WALLPAPER_SIZE
        cover(c, tex, size.w, size.h, top)
    else
        local bands = 24
        local a, b = wp.fallback[1], wp.fallback[2]
        for i = 0, bands - 1 do
            local t = i / (bands - 1)
            c:rect(0, top + math.floor(i * h / bands), w, math.ceil(h / bands) + 1,
                { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t })
        end
    end
    shade(c, top, h)
    return true
end

-- App names are translated when they are drawn (an app may give `label`, a function returning its name).
function Shells.label(app)
    if type(app.label) == "function" then
        local ok, s = pcall(app.label)
        if ok and type(s) == "string" and s ~= "" then return s end
    end
    return app.name
end

-- The name under a home-screen icon: the app's `short` name (Texts, Calc, Light...), else its full name. Home
-- screens show it only when it fits whole; they never cut a name short.
function Shells.shortLabel(app)
    if type(app.short) == "function" then
        local ok, s = pcall(app.short)
        if ok and type(s) == "string" and s ~= "" then return s end
    end
    return Shells.label(app)
end

-- The text, shortened with ".." until it fits the width in pixels.
local function fitText(s, width, font)
    font = font or UIFont.Small
    if textW(s, font) <= width then return s end
    local cut = s
    while #cut > 1 and textW(cut .. "..", font) > width do cut = cut:sub(1, -2) end
    return (cut:gsub("%s+$", "")) .. ".."
end
Shells.fitText = fitText

-- Clock, date and phone status ------------------------------------------------------------------------
function Shells.clock()
    local gt = getGameTime()
    return Format.clock(gt:getHour(), gt:getMinutes(), KnoxMobile.Options.clock24())
end

local DAY_NAMES = {
    function() return T("IGUI_KnoxMobile_Sunday", "Sunday") end, function() return T("IGUI_KnoxMobile_Monday", "Monday") end,
    function() return T("IGUI_KnoxMobile_Tuesday", "Tuesday") end, function() return T("IGUI_KnoxMobile_Wednesday", "Wednesday") end,
    function() return T("IGUI_KnoxMobile_Thursday", "Thursday") end, function() return T("IGUI_KnoxMobile_Friday", "Friday") end,
    function() return T("IGUI_KnoxMobile_Saturday", "Saturday") end,
}
local MONTH_NAMES = {
    function() return T("IGUI_KnoxMobile_January", "January") end, function() return T("IGUI_KnoxMobile_February", "February") end,
    function() return T("IGUI_KnoxMobile_March", "March") end, function() return T("IGUI_KnoxMobile_April", "April") end,
    function() return T("IGUI_KnoxMobile_May", "May") end, function() return T("IGUI_KnoxMobile_June", "June") end,
    function() return T("IGUI_KnoxMobile_July", "July") end, function() return T("IGUI_KnoxMobile_August", "August") end,
    function() return T("IGUI_KnoxMobile_September", "September") end, function() return T("IGUI_KnoxMobile_October", "October") end,
    function() return T("IGUI_KnoxMobile_November", "November") end, function() return T("IGUI_KnoxMobile_December", "December") end,
}

-- "Wednesday, July 14" (long) or "Wed, Jul 14" (short). The game's month and day count from 0.
function Shells.date(short)
    local gt = getGameTime()
    local month, day, year = gt:getMonth() + 1, gt:getDay() + 1, gt:getYear()
    local dayName = DAY_NAMES[Calendar.weekday(year, month, day)]()
    local monthName = MONTH_NAMES[month]()
    if short then dayName, monthName = dayName:sub(1, 3), monthName:sub(1, 3) end
    return T("IGUI_KnoxMobile_DateLine", "%1, %2 %3", dayName, monthName, day)
end

-- What the home widgets show: carrier and bars, battery, unread texts, the alarm, the flashlight.
function Shells.info(panel)
    local state = panel:state()
    local loc = panel.located
    local unread = 0
    for _, conv in ipairs(state.contents.texts or {}) do
        for _, m in ipairs(conv.messages or {}) do if m.unread then unread = unread + 1 end end
    end
    local alarm = state.alarm
    local alarmText = nil
    if type(alarm) == "table" and alarm.on and alarm.hour then
        alarmText = Format.clock(alarm.hour, alarm.minute or 0, KnoxMobile.Options.clock24())
    end
    return {
        carrier = Format.network(loc, T), bars = loc and loc.network and loc.bars or 0,
        charge = state.battery.charge, plug = state.plug ~= nil, unread = unread, alarm = alarmText,
        torch = state.flashlight == true, power = state.power.on,
    }
end

local function bars(c, x, y, h, n, col)
    for i = 1, 4 do
        local bh = math.max(2, math.floor(h * i / 4))
        c:rect(x + (i - 1) * 4, y + h - bh, 3, bh, col, i <= n and 1 or 0.3)
    end
    return 16
end

local function batteryIcon(c, x, y, h, charge, col)
    local w = math.floor(h * 1.7)
    c:border(x, y, w, h, col, 0.9)
    c:rect(x + w, y + math.floor(h / 4), 2, math.max(2, h - 2 * math.floor(h / 4)), col, 0.9)
    local fill = math.floor((w - 2) * math.max(0, math.min(100, charge)) / 100)
    c:rect(x + 1, y + 1, fill, h - 2, charge <= 15 and { 0.95, 0.3, 0.25 } or col, 0.95)
    return w + 2
end

-- Tiles -----------------------------------------------------------------------------------------------
local function tile(panel, c, app, i, tx, ty, size, selected, accent)
    if selected then
        local pad = math.max(2, math.floor(size / 10))
        c:rect(tx - pad, ty - pad, size + 2 * pad, size + 2 * pad, accent or WHITE, 0.35)
        c:border(tx - pad, ty - pad, size + 2 * pad, size + 2 * pad, WHITE, 0.9)
    end
    local tex = app.icon and app.icon ~= "" and getTexture(app.icon) or nil
    if tex then
        panel:drawTextureScaled(tex, c.sx + tx, c.sy + ty, size, size, 1, 1, 1, 1)
    else
        local col = TILE_COLORS[Mod.floor((i - 1), #TILE_COLORS) + 1]
        c:rect(tx, ty, size, size, col, 0.95)
        c:rect(tx, ty, size, math.max(2, math.floor(size / 6)), WHITE, 0.12)
        c:text(Shells.label(app):sub(1, 1), tx + size / 2, ty + size / 2 - lineH() / 2, WHITE, nil, "center")
    end
end

local function clamp(sel, n) return math.max(1, math.min(sel or 1, math.max(1, n))) end

-- Arrow keys and the wheel move a selection through a list; returns the new index.
local function step(d, ev, n, cols)
    d.sel = clamp(d.sel, n)
    cols = cols or 1
    if ev.type == "key" then
        if ev.key == "left" then d.sel = d.sel > 1 and d.sel - 1 or n
        elseif ev.key == "right" then d.sel = d.sel < n and d.sel + 1 or 1
        elseif ev.key == "up" then d.sel = cols > 1 and math.max(1, d.sel - cols) or (d.sel > 1 and d.sel - 1 or n)
        elseif ev.key == "down" then d.sel = cols > 1 and math.min(n, d.sel + cols) or (d.sel < n and d.sel + 1 or 1) end
    elseif ev.type == "wheel" then
        d.sel = clamp(d.sel + (ev.delta > 0 and 1 or -1), n)
    end
    return d.sel
end

local function selectKey(ev) return ev.type == "key" and ev.key == "select" end
local function isArrow(ev) return ev.type == "key" and (ev.key == "left" or ev.key == "right" or ev.key == "up" or ev.key == "down") end

-- The nearest item in a direction (items: { cx, cy }); nil when there is none that way.
local function spatial(items, sel, dir)
    local cur = items[sel]
    if not cur then return nil end
    local best, bestScore = nil, nil
    for i, it in ipairs(items) do
        if i ~= sel then
            local dx, dy = it.cx - cur.cx, it.cy - cur.cy
            local along, across
            if dir == "left" then along, across = -dx, math.abs(dy)
            elseif dir == "right" then along, across = dx, math.abs(dy)
            elseif dir == "up" then along, across = -dy, math.abs(dx)
            else along, across = dy, math.abs(dx) end
            if along > 2 then
                local score = along + across * 2.5
                if not bestScore or score < bestScore then best, bestScore = i, score end
            end
        end
    end
    return best
end
Shells.spatial = spatial

local function indexOfKey(items, key)
    for i, it in ipairs(items) do if it.key == key then return i end end
    return nil
end

local function hit(items, x, y)
    for i, it in ipairs(items) do
        if x >= it.x and x <= it.x + it.w and y >= it.y and y <= it.y + it.h then return i end
    end
    return nil
end

-- Segment LCD: "< Messages >" and soft keys -------------------------------------------------------
Shells.SegmentLCD = {
    draw = function(_, c, top, apps, d)
        d.sel = clamp(d.sel, #apps)
        local app = apps[d.sel]
        local mid = top + math.floor((c.h - top - lineH()) / 2) - 2
        c:text("<", 2, mid)
        c:text(">", c.w - 2, mid, nil, nil, "right")
        if app then c:text(fitText(Shells.label(app):upper(), c.w - 24), c.w / 2, mid, nil, nil, "center") end
        d.softKeys = c.h - top > 2 * lineH() + 4
        if d.softKeys then
            c:text(T("IGUI_KnoxMobile_SoftSelect", "Select"), 2, c.h - lineH())
            c:text(T("IGUI_KnoxMobile_SoftExit", "Exit"), c.w - 2, c.h - lineH(), nil, nil, "right")
        end
    end,
    input = function(_, ev, apps, d, c)
        if ev.type == "tap" then
            -- The soft key labels do what they say: "Select" opens the app, "Exit" puts the phone away.
            if d.softKeys and ev.y > c.h - lineH() - 4 then
                if ev.x < c.w / 2 then return apps[clamp(d.sel, #apps)] end
                if KnoxMobile.UI.close then KnoxMobile.UI.close() end
                return nil
            end
            if ev.x < c.w / 4 then step(d, { type = "key", key = "left" }, #apps)
            elseif ev.x > c.w * 3 / 4 then step(d, { type = "key", key = "right" }, #apps)
            else return apps[clamp(d.sel, #apps)] end
            return nil
        end
        if selectKey(ev) then return apps[clamp(d.sel, #apps)] end
        step(d, ev, #apps)
        return nil
    end,
}

-- Mono LCD: one big item per page --------------------------------------------------------------------
Shells.MonoLCD = {
    draw = function(panel, c, top, apps, d)
        d.sel = clamp(d.sel, #apps)
        local app = apps[d.sel]
        if not app then return end
        local avail = c.h - top - lineH() - 4
        -- The name goes in Medium when it fits above the soft-key row, else Small (final test: at Small the name ran
        -- over "Select 1/9").
        local nameFont = (avail - medH() - 6 >= 24) and UIFont.Medium or UIFont.Small
        local nameH = nameFont == UIFont.Medium and medH() or lineH()
        local soft = function()
            c:text(T("IGUI_KnoxMobile_SoftSelect", "Select"), 3, c.h - lineH())
            c:text(d.sel .. "/" .. #apps, c.w - 3, c.h - lineH(), nil, nil, "right")
        end
        if avail - nameH - 6 < 12 then
            -- Too short for the picture: "< Messages >" on one line.
            local y = top + math.max(0, math.floor((avail - lineH()) / 2))
            c:text("<", 2, y)
            c:text(">", c.w - 2, y, nil, nil, "right")
            c:text(fitText(Shells.label(app), c.w - 16, UIFont.Small), c.w / 2, y, nil, UIFont.Small, "center")
            soft()
            return
        end
        local box = math.max(12, math.min(avail - nameH - 6, c.w - 30))
        local bx = math.floor((c.w - box) / 2)
        local by = top + 4
        c:border(bx, by, box, box, nil, 0.9)
        -- Paging arrows either side of the picture.
        local ay = by + math.floor(box / 2) - math.floor(lineH() / 2)
        c:text("<", math.max(2, bx - 12), ay, nil, nil)
        c:text(">", math.min(c.w - 2, bx + box + 12), ay, nil, nil, "right")
        -- The app's pictogram in the LCD's ink, or its first letter when it has none.
        local glyph = app.glyph and getTexture(app.glyph) or nil
        if glyph then
            local g = math.floor(box * 0.72)
            panel:drawTextureScaled(glyph, c.sx + bx + math.floor((box - g) / 2), c.sy + by + math.floor((box - g) / 2), g, g,
                1, c.style.fg[1], c.style.fg[2], c.style.fg[3])
        else
            local zoom = math.max(1, math.floor(box / (medH() + 4)))
            local letter = Shells.label(app):sub(1, 1)
            panel:drawTextZoomed(letter, c.sx + c.w / 2 - textW(letter, UIFont.Medium) * zoom / 2,
                c.sy + by + box / 2 - medH() * zoom / 2,
                zoom * KnoxMobile.UI.zoomFor(UIFont.Medium), c.style.fg[1], c.style.fg[2], c.style.fg[3], 1, UIFont.Medium)
        end
        local name = Shells.label(app)
        if textW(name, nameFont) > c.w - 4 then nameFont = UIFont.Small end
        c:text(fitText(name, c.w - 4, nameFont), c.w / 2, by + box + 2, nil, nameFont, "center")
        soft()
    end,
    input = function(_, ev, apps, d, c)
        if ev.type == "tap" then
            if ev.y > c.h - lineH() - 4 and ev.x > c.w / 2 then step(d, { type = "key", key = "right" }, #apps); return nil end
            return apps[clamp(d.sel, #apps)]
        end
        if selectKey(ev) then return apps[clamp(d.sel, #apps)] end
        step(d, ev, #apps)
        return nil
    end,
}

-- Icon grids (Color feature, Keyboard) ------------------------------------------------------------------
-- opts: cols, rows (the menu's shape; fewer rows when the screen is short), header (a clock above the grid
-- when there is room for it and every app still fits), maxTile.
local function grid(opts)
    local cols = opts.cols
    local function layout(c, top, n)
        local lh = lineH()
        local labelH = lh + 4
        local pad = math.max(3, math.floor(c.w / 40))
        local area = c.h - top - labelH
        local widthFit = math.floor((c.w - pad * (cols + 1)) / cols)
        local rowsNeed = math.max(1, math.ceil(n / cols))
        local rows = math.min(opts.rows or rowsNeed, rowsNeed)
        local function heightFit(r, h) return math.floor((h - pad * (r + 1)) / r) end
        -- Show as many rows as fit with tiles at least 22 px, up to the menu's shape.
        while rows > 1 and heightFit(rows, area) < 22 do rows = rows - 1 end
        local size = math.min(widthFit, heightFit(rows, area), opts.maxTile or 64)
        local headerH = 0
        if opts.header then
            local want = fontH(UIFont.Large) + lh + 8
            if rows >= rowsNeed and area - (rows * (size + pad) + pad) >= want then headerH = want end
        end
        local gridH = rows * (size + pad) + pad
        local gridTop = top + headerH + math.floor((area - headerH - gridH) / 2)
        local gridW = cols * size + (cols - 1) * pad
        local left = math.floor((c.w - gridW) / 2)
        return { size = size, pad = pad, rows = rows, labelH = labelH, top = gridTop, left = left, headerH = headerH }
    end
    return {
        draw = function(panel, c, top, apps, d)
            local n = #apps
            local L = layout(c, top, n)
            -- The selection is kept by app id, so it stays put when apps come and go.
            local sel = 1
            for i, app in ipairs(apps) do if app.id == d.selKey then sel = i end end
            d.selKey = apps[sel] and apps[sel].id
            local selRow = math.floor((sel - 1) / cols)
            d.firstRow = d.firstRow or 0
            if selRow < d.firstRow then d.firstRow = selRow end
            if selRow >= d.firstRow + L.rows then d.firstRow = selRow - L.rows + 1 end
            d.firstRow = math.max(0, math.min(d.firstRow, math.max(0, math.ceil(n / cols) - L.rows)))
            if L.headerH > 0 then
                local clock = Shells.clock()
                c:text(clock, 8, top + 4, WHITE, UIFont.Large)
                c:text(Shells.date(true), 8, top + 4 + fontH(UIFont.Large), DIM)
                local info = Shells.info(panel)
                if info.unread > 0 then
                    c:text(T("IGUI_KnoxMobile_UnreadCount", "%1 new", info.unread), c.w - 8, top + 4, c.style.accent, nil, "right")
                end
                if info.alarm then
                    local alarm = T("IGUI_KnoxMobile_AlarmShort", "Alarm %1", info.alarm)
                    c:text(alarm, c.w - 8, top + 4 + fontH(UIFont.Large), DIM, nil, "right")
                end
            end
            d.items = {}
            for i, app in ipairs(apps) do
                local row = math.floor((i - 1) / cols) - d.firstRow
                if row >= 0 and row < L.rows then
                    local col = Mod.floor((i - 1), cols)
                    local tx, ty = L.left + col * (L.size + L.pad), L.top + L.pad + row * (L.size + L.pad)
                    tile(panel, c, app, i, tx, ty, L.size, i == sel, c.style.accent)
                    d.items[#d.items + 1] = { key = app.id, app = app, x = tx, y = ty, w = L.size, h = L.size,
                        cx = tx + L.size / 2, cy = ty + L.size / 2, index = i }
                end
            end
            -- Scroll hint: more apps above or below.
            if d.firstRow > 0 then c:text("^", c.w - 6, L.top - 2, DIM, nil, "right") end
            if (d.firstRow + L.rows) * cols < n then c:text("v", c.w - 6, c.h - L.labelH - lineH(), DIM, nil, "right") end
            if apps[sel] then
                c:rect(0, c.h - L.labelH, c.w, L.labelH, c.style.accent, 0.92)
                c:text(fitText(Shells.label(apps[sel]), c.w - 8), c.w / 2, c.h - L.labelH + 2, WHITE, nil, "center")
            end
        end,
        input = function(_, ev, apps, d)
            local items = d.items or {}
            if ev.type == "tap" then
                local i = hit(items, ev.x, ev.y)
                if i then d.selKey = items[i].key; return items[i].app end
                return nil
            end
            local sel = 1
            for i, app in ipairs(apps) do if app.id == d.selKey then sel = i end end
            if selectKey(ev) then return apps[sel] end
            -- Grid moves: left/right step through the list, up/down a whole row (scrolling the menu).
            local s = { sel = sel }
            step(s, ev, #apps, cols)
            d.selKey = apps[s.sel] and apps[s.sel].id
            return nil
        end,
    }
end

Shells.ColorFeature = grid({ cols = 3, rows = 3, maxTile = 48 })
Shells.Keyboard = grid({ cols = 5, rows = 3, header = true, maxTile = 44 })

-- Stylus: Start bar, Today strip and the Start menu ------------------------------------------------------
Shells.Stylus = {
    draw = function(panel, c, top, apps, d)
        local lh = lineH()
        local barH = lh + 6
        c:rect(0, top, c.w, barH, c.style.accent, 0.95)
        -- A little round Sisu badge before "Start": a white disc with a dot of the accent color.
        local fx, fy = 5, top + math.floor((barH - 10) / 2)
        c:rect(fx + 2, fy, 5, 9, WHITE)
        c:rect(fx, fy + 2, 9, 5, WHITE)
        c:rect(fx + 1, fy + 1, 7, 7, WHITE)
        c:rect(fx + 3, fy + 3, 3, 3, c.style.accent)
        c:text(T("IGUI_KnoxMobile_Start", "Start"), 17, top + 3, WHITE)
        -- Today: the date, then unread texts and the alarm.
        local info = Shells.info(panel)
        local y = top + barH + 3
        local todayLines = {}
        todayLines[#todayLines + 1] = { Shells.date(c.w < 170), WHITE }
        if info.unread > 0 then
            local unread = info.unread == 1 and T("IGUI_KnoxMobile_UnreadText1", "1 new message")
                or T("IGUI_KnoxMobile_UnreadTexts", "%1 new messages", info.unread)
            todayLines[#todayLines + 1] = { unread, c.style.accent }
        end
        if info.alarm then todayLines[#todayLines + 1] = { T("IGUI_KnoxMobile_AlarmShort", "Alarm %1", info.alarm), DIM } end
        local rowMin = lh + 4
        local spare = c.h - y - #apps * rowMin
        local showToday = math.max(0, math.min(#todayLines, math.floor((spare - 6) / (lh + 1))))
        if showToday > 0 then
            c:rect(3, y - 1, c.w - 6, showToday * (lh + 1) + 4, { 0, 0, 0 }, 0.25)
            for i = 1, showToday do
                c:text(fitText(todayLines[i][1], c.w - 12), 7, y + 1 + (i - 1) * (lh + 1), todayLines[i][2])
            end
            y = y + showToday * (lh + 1) + 7
        end
        -- The Start menu: rows sized to fill the rest of the screen (big enough for a stylus).
        local listH = c.h - y - 2
        local rows = #apps
        local rowH = math.max(rowMin, math.min(lh + 18, math.floor(listH / math.max(1, rows))))
        local visible = math.max(1, math.floor(listH / rowH))
        d.sel = clamp(d.sel, #apps)
        d.scroll = d.scroll or 0
        if d.sel <= d.scroll then d.scroll = d.sel - 1 end
        if d.sel > d.scroll + visible then d.scroll = d.sel - visible end
        d.items = {}
        local longest = 0
        for _, app in ipairs(apps) do longest = math.max(longest, textW(Shells.label(app))) end
        local icon = math.min(rowH - 4, 28, c.w - 18 - longest)
        if icon < 10 then icon = 0 end
        for i = 1, visible do
            local idx = d.scroll + i
            local app = apps[idx]
            if not app then break end
            local ry = y + (i - 1) * rowH
            local selected = idx == d.sel
            if selected then c:rect(2, ry, c.w - 4, rowH - 1, c.style.accent, 0.85) end
            if i > 1 then c:rect(8, ry, c.w - 16, 1, WHITE, 0.08) end
            local tex = icon > 0 and app.icon and getTexture(app.icon) or nil
            if tex then
                panel:drawTextureScaled(tex, c.sx + 6, c.sy + ry + math.floor((rowH - icon) / 2), icon, icon, 1, 1, 1, 1)
            end
            c:text(fitText(Shells.label(app), c.w - icon - 18), icon + 12, ry + math.floor((rowH - lh) / 2), WHITE)
            d.items[#d.items + 1] = { app = app, x = 0, y = ry, w = c.w, h = rowH, index = idx }
        end
        if d.scroll + visible < #apps then c:text("v", c.w - 5, c.h - lh - 1, DIM, nil, "right") end
    end,
    input = function(_, ev, apps, d)
        if ev.type == "tap" then
            local i = hit(d.items or {}, ev.x, ev.y)
            if i then d.sel = d.items[i].index; return d.items[i].app end
            return nil
        end
        if selectKey(ev) then return apps[clamp(d.sel, #apps)] end
        if ev.type == "key" and (ev.key == "left" or ev.key == "right") then return nil end
        step(d, ev, #apps)
        return nil
    end,
}

-- Modern: clock widget, grid with pages, dock ----------------------------------------------------------
-- Layout from the top: status bar, widget (clock, date, carrier and battery, the flashlight quick toggle), a
-- messages card on the Supernova when there is room, the icon grid (pages when it overflows), page dots, dock.
local function modernLayout(c, top, nGrid, pear, hasTorch, dock)
    local lh = lineH()
    local w, h = c.w, c.h
    local cols = w >= 200 and 4 or 3
    local gap = math.max(6, math.floor(w / 26))
    local widthFit = math.floor((w - gap * (cols + 1)) / cols)
    local dockIcon = math.min(widthFit, math.floor((w - gap * 5) / 4), 52)
    local slotW = math.floor((w - gap) / math.max(4, #dock))
    local dockFits = pear
    for _, app in ipairs(dock) do if textW(Shells.shortLabel(app)) > slotW - 2 then dockFits = false end end
    local dockLabel = dockFits and lh or 0
    local dockH = dockIcon + 10 + dockLabel
    local dotsH = 8
    local bottom = h - dockH - 4
    local clockFull = fitFont(Shells.clock(), w - 16, math.floor(h * 0.14))
    local clockCompact = fitFont(Shells.clock(), w - 2 * (math.floor(lh * 1.5) + 12), math.floor(lh * 1.8))
    local widgets = {
        { mode = "full", clock = clockFull, h = 6 + fontH(clockFull) + 2 + lh + 4 + lh + 6 },
        { mode = "compact", clock = clockCompact, h = 4 + fontH(clockCompact) + lh + 6 },
    }
    local chosen
    for _, wd in ipairs(widgets) do
        local area = bottom - dotsH - (top + wd.h)
        local rowsNeed = math.max(1, math.ceil(nGrid / cols))
        local rows = rowsNeed
        while rows > 1 and math.floor((area - gap * (rows + 1)) / rows) - lh < 26 do rows = rows - 1 end
        local icon = math.min(widthFit, math.floor((area - gap * (rows + 1)) / rows) - lh, 56)
        chosen = { widget = wd, area = area, rows = rows, icon = icon, fits = rows >= rowsNeed and icon >= 26 }
        if chosen.fits then break end
    end
    local L = chosen
    L.cols, L.gap, L.lh, L.dockIcon, L.dockH, L.dockLabel, L.dotsH = cols, gap, lh, dockIcon, dockH, dockLabel, dotsH
    L.slotW = slotW
    L.widgetTop = top
    L.gridTop = top + L.widget.h
    L.dockY = h - dockH - 4
    L.perPage = cols * L.rows
    L.pages = math.max(1, math.ceil(nGrid / L.perPage))
    -- Spare height: a messages card on the Supernova, else wider spacing between rows.
    local used = L.rows * (L.icon + lh) + (L.rows + 1) * gap
    L.spare = math.max(0, L.area - used)
    L.card = 0
    if not pear and L.spare >= 2 * lh + 14 then
        L.card = math.min(L.spare - 6, 3 * (lh + 2) + 10)
        L.spare = L.spare - L.card
    end
    L.rowPitch = L.icon + lh + gap + math.floor(L.spare / math.max(1, L.rows + 1))
    L.torch = hasTorch and math.max(18, math.floor(lh * 1.5)) or 0
    return L
end

local function drawWidget(panel, c, L, info, d)
    local lh = L.lh
    local wd = L.widget
    local y = L.widgetTop + 4
    local clock = Shells.clock()
    if wd.mode == "full" then
        c:text(clock, c.w / 2, y, WHITE, wd.clock, "center")
        y = y + fontH(wd.clock) + 2
        local dateLine = Shells.date(false)
        if textW(dateLine) > c.w - 12 then dateLine = Shells.date(true) end
        c:text(dateLine, c.w / 2, y, DIM, nil, "center")
        y = y + lh + 4
        -- Carrier, signal and battery on one line, centred. A narrow screen drops the percent, then the carrier.
        local carrier = info.carrier
        local pct = Format.battery(info.charge) .. (info.plug and "+" or "")
        local iconW = math.floor((lh - 6) * 1.7) + 2
        local total = 16 + 5 + textW(carrier) + 10 + textW(pct) + 4 + iconW
        if total > c.w - 8 then pct, total = "", total - textW(pct) - 4 end
        if total > c.w - 8 then carrier, total = "", total - textW(carrier) - 10 end
        local x = math.floor((c.w - total) / 2)
        x = x + bars(c, x, y + 2, lh - 5, info.bars, WHITE) + 5
        if carrier ~= "" then
            c:text(carrier, x, y, WHITE)
            x = x + textW(carrier) + 10
        end
        if pct ~= "" then
            c:text(pct, x, y, info.charge <= 15 and { 1, 0.45, 0.4 } or WHITE)
            x = x + textW(pct) + 4
        end
        batteryIcon(c, x, y + 3, lh - 6, info.charge, WHITE)
    else
        c:text(clock, c.w / 2, y, WHITE, wd.clock, "center")
        local line = Shells.date(true)
        if info.alarm then
            local withAlarm = line .. "  " .. T("IGUI_KnoxMobile_AlarmShort", "Alarm %1", info.alarm)
            if textW(withAlarm) <= c.w - 12 then line = withAlarm end
        end
        c:text(line, c.w / 2, y + fontH(wd.clock), DIM, nil, "center")
    end
    -- Flashlight quick toggle, top right of the widget.
    d.items = d.items or {}
    if L.torch > 0 then
        local s = L.torch
        local tx, ty = c.w - s - 6, L.widgetTop + 4
        local on = info.torch
        c:rect(tx, ty, s, s, on and { 1, 0.85, 0.35 } or { 0, 0, 0 }, on and 0.9 or 0.35)
        c:border(tx, ty, s, s, WHITE, d.selKey == "torch" and 1 or 0.45)
        local g = getTexture("media/ui/KnoxMobile/apps/flashlight_glyph.png")
        if g then
            local gs = s - 4
            local ink = on and { 0.15, 0.12, 0.05 } or WHITE
            panel:drawTextureScaled(g, c.sx + tx + 2, c.sy + ty + 2, gs, gs, 1, ink[1], ink[2], ink[3])
        end
        d.items[#d.items + 1] = { key = "torch", kind = "torch", x = tx, y = ty, w = s, h = s, cx = tx + s / 2, cy = ty + s / 2 }
    end
end

-- The Supernova's messages card: the newest unread texts, or the next alarm and battery when there are none.
local function drawCard(panel, c, L, info)
    if L.card <= 0 then return end
    local lh = L.lh
    local x, y, w, h = L.gap, L.gridTop + 2, c.w - 2 * L.gap, L.card - 4
    c:rect(x, y, w, h, { 0, 0, 0 }, 0.4)
    c:border(x, y, w, h, WHITE, 0.12)
    local lines = {}
    for _, p in ipairs(panel:previews(3)) do lines[#lines + 1] = { p.name .. ": " .. p.body, WHITE } end
    if #lines == 0 then
        lines[#lines + 1] = { T("IGUI_KnoxMobile_NoNewMessages", "No new messages"), DIM }
        if info.alarm then lines[#lines + 1] = { T("IGUI_KnoxMobile_AlarmShort", "Alarm %1", info.alarm), DIM } end
    end
    local maxLines = math.max(1, math.floor((h - 6) / (lh + 2)))
    for i = 1, math.min(maxLines, #lines) do
        c:text(fitText(lines[i][1], w - 10), x + 5, y + 3 + (i - 1) * (lh + 2), lines[i][2])
    end
end

-- Half the screen's width, for "tap left / tap right" on the page dots.
local function halfWidth(panel) return math.floor(panel.screen.w / 2) end

local function modern(pear)
    return {
        draw = function(panel, c, top, apps, d)
            local main, dock = {}, {}
            for _, app in ipairs(apps) do
                if DOCK[app.id] then dock[#dock + 1] = app end
            end
            table.sort(dock, function(a, b) return DOCK[a.id] < DOCK[b.id] end)
            for i = #dock, DOCK_SIZE + 1, -1 do dock[i] = nil end
            local docked = {}
            for _, app in ipairs(dock) do docked[app] = true end
            for _, app in ipairs(apps) do if not docked[app] then main[#main + 1] = app end end
            local info = Shells.info(panel)
            local hasTorch = KnoxMobile.Flashlight ~= nil and KnoxMobile.Flashlight.supports(panel.item)
            local L = modernLayout(c, top, #main, pear, hasTorch, dock)
            d.layout = L
            d.items = {}
            drawWidget(panel, c, L, info, d)
            drawCard(panel, c, L, info)
            -- Default selection: the first app on the grid (or in the dock).
            d.page = math.max(1, math.min(d.page or 1, L.pages))
            local first = main[(d.page - 1) * L.perPage + 1] or dock[1]
            if not d.selKey then d.selKey = first and first.id end
            -- Grid: this page's apps.
            local lh = L.lh
            -- Equal columns across the screen, each icon centred in its column (labels get the column's width).
            local colW = math.floor((c.w - L.gap) / L.cols)
            local left = math.floor((c.w - colW * L.cols) / 2)
            local gridY = L.gridTop + L.card + L.gap + math.floor(L.spare / math.max(1, L.rows + 1))
            -- Short names under the icons, shown only when every one on the page fits whole.
            local showLabels = true
            for k = 1, L.perPage do
                local app = main[(d.page - 1) * L.perPage + k]
                if app and textW(Shells.shortLabel(app)) > colW - 4 then showLabels = false end
            end
            for k = 1, L.perPage do
                local idx = (d.page - 1) * L.perPage + k
                local app = main[idx]
                if not app then break end
                local col, row = Mod.floor((k - 1), L.cols), math.floor((k - 1) / L.cols)
                local tx, ty = left + col * colW + math.floor((colW - L.icon) / 2), gridY + row * L.rowPitch
                tile(panel, c, app, idx, tx, ty, L.icon, d.selKey == app.id, c.style.accent)
                if showLabels then
                    local label = Shells.shortLabel(app)
                    c:text(label, tx + L.icon / 2 + 1, ty + L.icon + 2, { 0, 0, 0 }, nil, "center")
                    c:text(label, tx + L.icon / 2, ty + L.icon + 1, WHITE, nil, "center")
                end
                d.items[#d.items + 1] = { key = app.id, app = app, x = tx, y = ty, w = L.icon, h = L.icon + lh,
                    cx = tx + L.icon / 2, cy = ty + L.icon / 2 }
            end
            -- Page dots.
            local dotsY = L.dockY - L.dotsH - 1
            local n = L.pages
            local dx = math.floor(c.w / 2 - (n * 9) / 2)
            for p = 1, n do
                c:rect(dx + (p - 1) * 9 + 2, dotsY + 2, 5, 5, WHITE, p == d.page and 0.95 or 0.35)
            end
            d.dots = { x = 0, y = dotsY - 4, w = c.w, h = L.dotsH + 6 }
            -- Dock: a frosted plate with four icons (named on the PearPhone when the names fit, like its dock).
            c:rect(L.gap / 2, L.dockY, c.w - L.gap, L.dockH, WHITE, pear and 0.2 or 0.12)
            c:rect(L.gap / 2, L.dockY, c.w - L.gap, 1, WHITE, 0.35)
            local slotW = L.slotW
            for j, app in ipairs(dock) do
                local tx = math.floor(L.gap / 2 + (j - 1) * slotW + (slotW - L.dockIcon) / 2)
                local ty = L.dockY + 5
                tile(panel, c, app, #main + j, tx, ty, L.dockIcon, d.selKey == app.id, c.style.accent)
                if L.dockLabel > 0 then
                    c:text(Shells.shortLabel(app), tx + L.dockIcon / 2, ty + L.dockIcon + 1, WHITE, nil, "center")
                end
                d.items[#d.items + 1] = { key = app.id, app = app, x = tx, y = ty, w = L.dockIcon, h = L.dockIcon + L.dockLabel,
                    cx = tx + L.dockIcon / 2, cy = ty + L.dockIcon / 2 }
            end
            d.main, d.dockApps = main, dock
            -- The selection may have scrolled off this page (it lives on another page): keep it valid.
            if not indexOfKey(d.items, d.selKey) and first then
                local onOtherPage = false
                for _, app in ipairs(main) do if app.id == d.selKey then onOtherPage = true end end
                if not onOtherPage then d.selKey = first.id end
            end
        end,
        input = function(panel, ev, _, d)
            local items = d.items or {}
            local L = d.layout
            local function activate(it)
                if not it then return nil end
                if it.kind == "torch" then
                    if KnoxMobile.Flashlight then KnoxMobile.Flashlight.toggle(panel.player, panel.item) end
                    return nil
                end
                return it.app
            end
            if ev.type == "tap" then
                local i = hit(items, ev.x, ev.y)
                if i then d.selKey = items[i].key; return activate(items[i]) end
                local dots = d.dots
                if L and L.pages > 1 and dots and ev.y >= dots.y and ev.y <= dots.y + dots.h then
                    d.page = ev.x < halfWidth(panel) and math.max(1, d.page - 1) or math.min(L.pages, d.page + 1)
                    d.selKey = nil
                end
                return nil
            end
            local sel = indexOfKey(items, d.selKey) or 1
            if selectKey(ev) then return activate(items[sel]) end
            if isArrow(ev) then
                local nextI = spatial(items, sel, ev.key)
                if nextI then
                    d.selKey = items[nextI].key
                elseif L and L.pages > 1 and (ev.key == "right" or ev.key == "left") then
                    -- Past the edge: the next or previous page.
                    local p = (d.page or 1) + (ev.key == "right" and 1 or -1)
                    if p >= 1 and p <= L.pages then
                        d.page = p
                        local app = d.main and d.main[(p - 1) * L.perPage + (ev.key == "right" and 1 or math.min(L.cols, L.perPage))]
                        d.selKey = app and app.id or nil
                    end
                end
                return nil
            end
            if ev.type == "wheel" then
                -- The wheel walks through every app in order, turning pages as it goes.
                local order = {}
                for _, app in ipairs(d.main or {}) do order[#order + 1] = app end
                for _, app in ipairs(d.dockApps or {}) do order[#order + 1] = app end
                local cur = 1
                for i, app in ipairs(order) do if app.id == d.selKey then cur = i end end
                cur = clamp(cur + (ev.delta > 0 and 1 or -1), #order)
                local app = order[cur]
                if app then
                    d.selKey = app.id
                    for i, a in ipairs(d.main or {}) do
                        if a == app and L then d.page = math.floor((i - 1) / L.perPage) + 1 end
                    end
                end
            end
            return nil
        end,
    }
end

Shells.ModernAndroid = modern(false)
Shells.ModernPear = modern(true)

function Shells.forFamily(family) return Shells[family] or Shells.ModernAndroid end

return Shells
