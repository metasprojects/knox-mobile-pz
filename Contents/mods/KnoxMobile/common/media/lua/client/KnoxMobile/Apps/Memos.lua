-- Client: the Memos app (0.3.0, Core/Memos). The phone's voice memos, newest first: select one to play it (its words
-- on the screen, the crackle of a voice through the speaker); Record a memo types what you say into it.
local Util = require "KnoxMobile/Game/Util"
local Net = require "KnoxMobile/Game/Net"
local Lang = require "KnoxMobile/Core/Lang"
local Memos = require "KnoxMobile/Core/Memos"
local Format = require "KnoxMobile/Core/Format"

local T = Util.text
local ICONS = "media/ui/KnoxMobile/apps/"

local function list(ctx)
    local out = {}
    local memos = ctx.state.contents.memos or {}
    for i = #memos, 1, -1 do out[#out + 1] = memos[i] end
    return out
end

local function text(m) return m.mine and m.body or Lang.t(m.body) end

KnoxMobile.Apps.register({
    id = "memos", name = "Memos", icon = ICONS .. "memos.png", glyph = ICONS .. "memos_glyph.png",
    label = function() return T("IGUI_KnoxMobile_AppMemos", "Voice memos") end,
    short = function() return T("IGUI_KnoxMobile_AppShortMemos", "Memos") end,
    families = { "ColorFeature", "Keyboard", "Stylus", "ModernAndroid", "ModernPear" }, drain = "audio",
    needsService = false, order = 52,
    available = function(model) return Memos.fits(model) end,
    render = function(ctx, x, y, w, h)
        local d = ctx.data
        local memos = list(ctx)
        if d.open and memos[d.open] then
            local lh = ctx:lineHeight()
            ctx:text(T("IGUI_KnoxMobile_MemoPlaying", "Playing..."), x + 3, y + 2, ctx.style.accent)
            local top = y + lh + 6
            for _, l in ipairs(ctx:wrap(text(memos[d.open]), w - 8)) do
                if top > y + h - lh then break end
                ctx:text(l, x + 3, top)
                top = top + lh
            end
            return
        end
        local rows = {}
        for _, m in ipairs(memos) do rows[#rows + 1] = { label = Format.ellipsis(text(m), 28) } end
        if not ctx.state.security.locked then rows[#rows + 1] = { label = T("IGUI_KnoxMobile_MemoRecord", "Record a memo") } end
        if #rows == 0 then rows[1] = { label = T("IGUI_KnoxMobile_MemoNone", "No memos") } end
        ctx:list(rows, x, y, w, h)
    end,
    onInput = function(ctx, ev)
        local d = ctx.data
        if d.open then
            if ev.type == "tap" or (ev.type == "key" and (ev.key == "back" or ev.key == "select")) then d.open = nil end
            return true
        end
        local memos = list(ctx)
        local writable = not ctx.state.security.locked
        local chosen = ctx:listInput(ev, #memos + (writable and 1 or 0))
        if chosen and chosen > #memos then
            ctx:askText(T("IGUI_KnoxMobile_MemoPrompt", "Say:"), "", function(said)
                if said and said ~= "" then
                    Net.toServer(ctx.player, "recordMemo", { phoneId = ctx.phone:getID(), body = said:sub(1, Memos.MAX_LENGTH) })
                end
            end, Memos.MAX_LENGTH)
        elseif chosen then
            d.open = chosen
            if KnoxMobile.Audio and KnoxMobile.Audio.playSound then KnoxMobile.Audio.playSound("KnoxMobileCrackle") end
            Net.toServer(ctx.player, "playMemo", { phoneId = ctx.phone:getID() })
        end
        return true
    end,
})
