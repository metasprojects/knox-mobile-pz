-- Client: the Composer app (0.2.0) on the phones with games (the Sisus from 2000 on): type a tune the old way,
-- "8e2 8d#2 4c2 8-", play it, and make it your ringtone (Core/Composer; the notes are the mod's own buzzer beeps).
local Util = require "KnoxMobile/Game/Util"
local Phones = require "KnoxMobile/Game/Phones"
local Composer = require "KnoxMobile/Core/Composer"
local Format = require "KnoxMobile/Core/Format"

local T = Util.text
local ICONS = "media/ui/KnoxMobile/apps/"

local function families()
    local out = {}
    for _, f in ipairs(Phones.registry:families()) do
        if f.features and f.features.games then out[#out + 1] = f.id end
    end
    return out
end

local function tune(ctx) return ctx.data.tune or ctx.state.look.tune or Composer.DEFAULT end

local function rows(ctx)
    local t = tune(ctx)
    local saved = ctx.state.look.ringtone == "custom" and ctx.state.look.tune == t
    return {
        { id = "tune", label = Format.ellipsis(t, math.max(8, math.floor(ctx.w / 7))) },
        { id = "write", label = T("IGUI_KnoxMobile_ComposerWrite", "Write a tune") },
        { id = "play", label = T("IGUI_KnoxMobile_ComposerPlay", "Play it") },
        { id = "save", label = saved and T("IGUI_KnoxMobile_ComposerSaved", "It's your ringtone")
            or T("IGUI_KnoxMobile_ComposerSave", "Make it my ringtone") },
    }
end

KnoxMobile.Apps.register({
    id = "composer", name = "Composer", icon = ICONS .. "composer.png", glyph = ICONS .. "composer_glyph.png",
    label = function() return T("IGUI_KnoxMobile_AppComposer", "Composer") end,
    short = function() return T("IGUI_KnoxMobile_AppShortComposer", "Tunes") end,
    families = families(), drain = "screen", needsService = false, order = 66,
    render = function(ctx, x, y, w, h) ctx:list(rows(ctx), x, y, w, h) end,
    onInput = function(ctx, ev)
        local list = rows(ctx)
        local i = ctx:listInput(ev, #list)
        local row = i and list[i]
        if not row then return true end
        if row.id == "write" or row.id == "tune" then
            ctx:askText(T("IGUI_KnoxMobile_ComposerPrompt", "Notes, like 8e2 4c2 8-:"), tune(ctx), function(text)
                local ok, why = Composer.parse(text)
                if ok then ctx.data.tune = text
                else ctx:toast(T("IGUI_KnoxMobile_ComposerBad", "Can't play that: %1", tostring(why))) end
            end, 240)
        elseif row.id == "play" and KnoxMobile.Audio then
            KnoxMobile.Audio.playTune(Composer.parse(tune(ctx)), Phones.inBag(ctx.player, ctx.phone))
        elseif row.id == "save" then
            ctx:setting("tune", tune(ctx))
        end
        return true
    end,
})
