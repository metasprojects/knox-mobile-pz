-- Client: Calculator (spec §4.6 "calculator" from the mono LCD phones up). The arithmetic is Core/Calculator
-- (unit tested); this draws the display and keypad. Type digits and + - * / . = on the keyboard (the numpad works),
-- or move over the keypad with the arrows and press Enter, or tap. Backspace deletes a digit, then leaves.
-- Tall screens get a 4 x 5 keypad, wide ones (the Bramble) 5 x 4, and the tiny Sisu 3301 a row of operators.
local Mod = require "KnoxMobile/Core/Mod"
local CalculatorLogic = require "KnoxMobile/Core/Calculator"
local Phones = require "KnoxMobile/Game/Phones"
local Util = require "KnoxMobile/Game/Util"

local T = Util.text
local ICONS = "media/ui/KnoxMobile/apps/"
local LCD = { MonoLCD = true, SegmentLCD = true }

-- Keypads: { label, key }. "neg" is +/-, "back" deletes a digit.
local PORTRAIT = {
    cols = 4,
    keys = { { "C", "C" }, { "+/-", "neg" }, { "%", "%" }, { "/", "/" }, { "7", "7" }, { "8", "8" }, { "9", "9" }, { "x", "*" },
        { "4", "4" }, { "5", "5" }, { "6", "6" }, { "-", "-" }, { "1", "1" }, { "2", "2" }, { "3", "3" }, { "+", "+" },
        { "0", "0" }, { ".", "." }, { "<", "back" }, { "=", "=" } },
}
local LANDSCAPE = {
    cols = 5,
    keys = { { "7", "7" }, { "8", "8" }, { "9", "9" }, { "/", "/" }, { "C", "C" }, { "4", "4" }, { "5", "5" }, { "6", "6" },
        { "x", "*" }, { "<", "back" }, { "1", "1" }, { "2", "2" }, { "3", "3" }, { "-", "-" }, { "%", "%" }, { "0", "0" },
        { ".", "." }, { "=", "=" }, { "+", "+" }, { "+/-", "neg" } },
}
local COMPACT = { cols = 5, keys = { { "+", "+" }, { "-", "-" }, { "x", "*" }, { "/", "/" }, { "=", "=" } } }
local OPERATOR = { ["+"] = true, ["-"] = true, ["*"] = true, ["/"] = true, ["%"] = true, neg = true }
local TYPED = { ["+"] = true, ["-"] = true, ["*"] = true, ["/"] = true, ["."] = true, ["="] = true }

local function families()
    local out = {}
    for _, f in ipairs(Phones.registry:families()) do
        if f.features and f.features.calculator then out[#out + 1] = f.id end
    end
    return out
end

local function calc(ctx)
    local d = ctx.data
    if not d.calc then d.calc = CalculatorLogic.new(LCD[ctx.family] and 8 or 10) end
    return d.calc
end

-- Backspace deletes while there is something to delete (a result clears); on a clear "0" it leaves the app.
local function updateBack(ctx)
    local c = calc(ctx)
    ctx.data.keepBack = c.error or c.op ~= nil or c.entry ~= "0"
end

local function press(ctx, key)
    local c = calc(ctx)
    if key == "back" and (c.error or c.fresh) then
        CalculatorLogic.press(c, "C")
    else
        CalculatorLogic.press(c, key)
    end
    updateBack(ctx)
end

local function pickPad(w, h, displayH)
    local rest = h - displayH
    if rest >= 5 * 14 and w <= rest * 1.3 then return PORTRAIT end
    if rest >= 4 * 12 then return LANDSCAPE end
    return COMPACT
end

KnoxMobile.Apps.register({
    id = "calculator", name = "Calculator", icon = ICONS .. "calculator.png", glyph = ICONS .. "calculator_glyph.png",
    label = function() return T("IGUI_KnoxMobile_AppCalculator", "Calculator") end,
    short = function() return T("IGUI_KnoxMobile_AppShortCalculator", "Calc") end,
    families = families(), drain = "screen", needsService = false, order = 60,
    onOpen = function(ctx) ctx.data.sel = 1; calc(ctx); updateBack(ctx) end,
    render = function(ctx, x, y, w, h)
        local d = ctx.data
        local c = calc(ctx)
        ctx:wantsDigits(true)
        local lcd = LCD[ctx.family] == true
        local lh = ctx:lineHeight()
        local fg = ctx.style.fg
        -- Display: the pending operation small, the number big, right-aligned.
        local text = CalculatorLogic.display(c)
        if c.error then text = T("IGUI_KnoxMobile_CalcError", "Error") end
        local font = UIFont.Small
        for _, f in ipairs({ UIFont.Large, UIFont.Medium }) do
            if KnoxMobile.UI.fontH(f) <= math.max(lh, math.floor(h * 0.22))
                and KnoxMobile.UI.textW(text, f) <= w - 12 then font = f; break end
        end
        local numH = KnoxMobile.UI.fontH(font)
        local displayH = lh + numH + 6
        local pad = pickPad(w, h, displayH)
        if pad == COMPACT and h < displayH + lh + 4 then displayH = numH + 4 end -- no room for the pending line
        -- Keys up to about two lines tall; a tall screen gives the rest to the display, like a real calculator.
        local rows = math.ceil(#pad.keys / pad.cols)
        local gap = (pad == COMPACT or h - displayH < 80) and 2 or 3
        local kh = math.max(10, math.min(math.floor((h - displayH - 2 - gap * rows) / rows), lh * 2 + 10))
        if pad ~= COMPACT then displayH = math.max(displayH, h - rows * (kh + gap) - 2) end
        if lcd then
            ctx:border(x + 2, y + 1, w - 4, displayH - 2, fg, 0.8)
        else
            ctx:rect(x + 2, y + 1, w - 4, displayH - 2, { 0, 0, 0 }, 0.35)
        end
        if displayH > numH + 4 then
            ctx:text(CalculatorLogic.pending(c), x + w - 6, y + displayH - numH - lh - 2, ctx.style.accent, nil, "right")
        end
        ctx:text(text, x + w - 6, y + displayH - numH - 2, c.error and { 0.95, 0.35, 0.3 } or fg, font, "right")
        -- Keypad.
        local top = y + displayH + 2
        local kw = math.floor((w - gap * (pad.cols + 1)) / pad.cols)
        d.sel = math.max(1, math.min(d.sel or 1, #pad.keys))
        d.pad, d.keys = pad, {}
        for i, k in ipairs(pad.keys) do
            local col, row = Mod.floor((i - 1), pad.cols), math.floor((i - 1) / pad.cols)
            local kx, ky = x + gap + col * (kw + gap), top + row * (kh + gap)
            local selected = i == d.sel
            if lcd then
                if selected then ctx:rect(kx, ky, kw, kh, fg) else ctx:border(kx, ky, kw, kh, fg, 0.7) end
            else
                local col3 = OPERATOR[k[2]] and { 0.95, 0.6, 0.2 } or { 0.24, 0.26, 0.3 }
                if k[2] == "=" then col3 = ctx.style.accent end
                if k[2] == "C" then col3 = { 0.75, 0.25, 0.22 } end
                ctx:rect(kx, ky, kw, kh, col3, 0.92)
                if selected then ctx:border(kx - 1, ky - 1, kw + 2, kh + 2, { 1, 1, 1 }) end
            end
            local ink = lcd and (selected and ctx.style.bg or fg) or { 1, 1, 1 }
            ctx:text(k[1], kx + kw / 2, ky + math.floor((kh - lh) / 2), ink, nil, "center")
            d.keys[i] = { x = kx - x, y = ky - y, w = kw, h = kh, key = k[2] }
        end
        if pad == COMPACT and y + h - (top + kh) > lh then
            local hint = T("IGUI_KnoxMobile_CalcDigits", "Type numbers on the keypad")
            ctx:text(hint, x + w / 2, top + kh + 2, ctx.style.accent, nil, "center")
        end
    end,
    onInput = function(ctx, ev)
        local d = ctx.data
        local pad = d.pad or PORTRAIT
        if ev.type == "key" then
            local k = ev.key
            if k:match("^%d$") or TYPED[k] then press(ctx, k); return true end
            if k == "back" then press(ctx, "back"); return true end
            if k == "select" then
                local key = pad.keys[d.sel or 1]
                if key then press(ctx, key[2]) end
                return true
            end
            local n, cols = #pad.keys, pad.cols
            local sel = d.sel or 1
            if k == "left" then sel = sel > 1 and sel - 1 or n
            elseif k == "right" then sel = sel < n and sel + 1 or 1
            elseif k == "up" then sel = sel - cols >= 1 and sel - cols or sel
            elseif k == "down" then sel = sel + cols <= n and sel + cols or sel end
            d.sel = sel
            return true
        end
        if ev.type == "tap" then
            for i, kk in ipairs(d.keys or {}) do
                if ev.x >= kk.x and ev.x <= kk.x + kk.w and ev.y >= kk.y and ev.y <= kk.y + kk.h then
                    d.sel = i
                    press(ctx, kk.key)
                    return true
                end
            end
        end
        return true
    end,
})
