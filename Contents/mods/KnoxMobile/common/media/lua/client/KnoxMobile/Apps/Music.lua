-- Client: Music (0.3.0, Core/Music) on the music phones, when a music mod (True Moozic or one built the same way) is
-- running. The songs copied onto the phone (right-click the phone: Add music), what's playing, Enter to play or stop,
-- Left and Right to skip. It keeps playing with the phone put away (client/MusicPlayer.lua).
local Music = require "KnoxMobile/Core/Music"
local Util = require "KnoxMobile/Game/Util"
require "KnoxMobile/MusicPlayer"

local T = Util.text
local ICONS = "media/ui/KnoxMobile/apps/"

local function list(ctx) return ctx.state.contents.music or {} end

KnoxMobile.Apps.register({
    id = "music", name = "Music", icon = ICONS .. "music.png", glyph = ICONS .. "music_glyph.png",
    label = function() return T("IGUI_KnoxMobile_AppMusic", "Music") end,
    short = function() return T("IGUI_KnoxMobile_AppShortMusic", "Music") end,
    families = { "Stylus", "ModernPear", "ModernAndroid" },
    drain = "audio", needsService = false, order = 56,
    available = function(model) return Music.capacity(model) ~= nil and Music.available() end,
    render = function(ctx, x, y, w, h)
        local P = KnoxMobile.MusicPlayer
        local songs = list(ctx)
        local lh = ctx:lineHeight()
        local index, name = P.playing(ctx.phone)
        local head = index and T("IGUI_KnoxMobile_MusicPlaying", "Playing: %1", name)
            or T("IGUI_KnoxMobile_MusicStopped", "Stopped")
        ctx:text(head, x + 3, y + 1, ctx.style.accent)
        if #songs == 0 then
            local lines = ctx:wrap(T("IGUI_KnoxMobile_MusicEmpty",
                "No songs yet. Right-click the phone with a cassette or record in your bags: Add music."), w - 8)
            for i, l in ipairs(lines) do ctx:text(l, x + 3, y + 3 + i * lh) end
            return
        end
        local rows = {}
        for i, s in ipairs(songs) do rows[i] = { label = (i == index and "> " or "") .. s.name } end
        ctx:list(rows, x, y + lh + 3, w, h - lh * 2 - 6)
        ctx:text(T("IGUI_KnoxMobile_MusicHint", "Enter: play/stop  Left/Right: skip  %1/%2", #songs,
            Music.capacity(ctx.model) or 0), x + 3, y + h - lh - 2, ctx.style.accent)
    end,
    onInput = function(ctx, ev)
        local P = KnoxMobile.MusicPlayer
        local songs = list(ctx)
        if ev.type == "key" and (ev.key == "left" or ev.key == "right") then
            if P.playing(ctx.phone) then P.skip(ev.key == "left" and -1 or 1) end
            return true
        end
        local i = ctx:listInput(ev, #songs)
        if i and songs[i] then
            if P.playing(ctx.phone) == i then P.stop() else P.play(ctx.phone, i) end
        end
        return true
    end,
})
