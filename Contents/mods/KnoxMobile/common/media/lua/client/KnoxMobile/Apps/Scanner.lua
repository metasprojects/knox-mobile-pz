-- Client: the Scanner app (0.3.0, server/Scanner.lua) on the old analog phones. Listen catches one fragment of what's
-- in range; the last few stay on the screen, newest first.
local Util = require "KnoxMobile/Game/Util"
local Net = require "KnoxMobile/Game/Net"
local Scanner = require "KnoxMobile/Core/Scanner"

local T = Util.text
local ICONS = "media/ui/KnoxMobile/apps/"

KnoxMobile.ScannerLog = KnoxMobile.ScannerLog or {}
Net.onClient("scan", function(args)
    local log = KnoxMobile.ScannerLog
    table.insert(log, 1, args)
    for i = #log, Scanner.KEEP + 1, -1 do log[i] = nil end
end)

local function label(f)
    if f.kind == "clan" then return f.label or T("IGUI_KnoxMobile_ScanVoices", "Voices") end
    if f.kind == "dispatch" then return T("IGUI_KnoxMobile_ScanDispatch", "Dispatch channel") end
    if f.kind == "call" then return T("IGUI_KnoxMobile_ScanCall", "A call nearby") end
    return T("IGUI_KnoxMobile_ScanStatic", "Nothing clear")
end

KnoxMobile.Apps.register({
    id = "scanner", name = "Scanner", icon = ICONS .. "scanner.png", glyph = ICONS .. "scanner_glyph.png",
    label = function() return T("IGUI_KnoxMobile_AppScanner", "Scanner") end,
    short = function() return T("IGUI_KnoxMobile_AppShortScanner", "Scan") end,
    families = { "SegmentLCD", "MonoLCD" }, drain = "audio", needsService = false, order = 45,
    available = function(model) return Scanner.fits(model) end,
    render = function(ctx, x, y, w, h)
        local lh = ctx:lineHeight()
        local rows = { { id = "listen", label = T("IGUI_KnoxMobile_ScanListen", "Listen") } }
        ctx:list(rows, x, y, w, lh + 4)
        local top = y + lh + 8
        for _, f in ipairs(KnoxMobile.ScannerLog) do
            if top > y + h - lh then break end
            ctx:text(label(f), x + 3, top, ctx.style.accent)
            top = top + lh
            for _, l in ipairs(ctx:wrap(f.text or "", w - 8)) do
                if top > y + h - lh then break end
                ctx:text(l, x + 6, top)
                top = top + lh
            end
        end
    end,
    onInput = function(ctx, ev)
        local i = ctx:listInput(ev, 1)
        if i == 1 then Net.toServer(ctx.player, "scan", { phoneId = ctx.phone:getID() }) end
        return true
    end,
})
