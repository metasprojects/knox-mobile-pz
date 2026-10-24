-- Client: the phone's own apps, registered through the same app slot other mods use (spec §8.6, §12.2).
-- Round 1 keeps them simple: Phone, Radio, Notes and Settings. Messages, Alarm, Calculator, Snake, Flashlight,
-- Classifieds and Crew live next to this file. App names are translated when drawn (`label`); `name` is the English fallback.
-- `short` is the name under a home-screen icon (Texts, Calc...): home screens never cut a name short.
local Mod = require "KnoxMobile/Core/Mod"
local Sim = require "KnoxMobile/Core/Sim"
local Format = require "KnoxMobile/Core/Format"
local Registry = require "KnoxMobile/Core/Registry"
local AudioGear = require "KnoxMobile/Core/AudioGear"
local Phones = require "KnoxMobile/Game/Phones"
local Net = require "KnoxMobile/Game/Net"
local Util = require "KnoxMobile/Game/Util"

local T = Util.text
local ALL = { "SegmentLCD", "MonoLCD", "ColorFeature", "Keyboard", "Stylus", "ModernAndroid", "ModernPear" }
local RADIO = { "ColorFeature", "Keyboard", "Stylus", "ModernAndroid", "ModernPear" } -- and only models with an FM tuner
local NOTES = { "Keyboard", "Stylus", "ModernAndroid", "ModernPear" }
local ICONS = "media/ui/KnoxMobile/apps/" -- tools/art/make_app_icons.py: <id>.png tiles, <id>_glyph.png for mono LCDs

-- A number, or a contact's name (the Messages app has its own copy in Apps/Messages.lua) ----------------
local function askNumber(ctx, prompt, onNumber)
    ctx:askText(prompt, "", function(text)
        local number = Sim.dialable(text)
        if not number and ctx.state.sim then
            -- A contact name works too.
            for _, c in ipairs(ctx.state.sim.contacts) do
                if c.name:lower() == text:lower() then number = c.number end
            end
        end
        if number then onNumber(number) else ctx:toast(T("IGUI_KnoxMobile_BadNumber", "That isn't a phone number")) end
    end, 20)
end

-- Phone: dial, contacts, the call log and voicemail (calls themselves are drawn by the shell) -----------
-- A found phone's call log and voicemails come from its owner's story (Core/Story.deadPhone); even a 1993 brick,
-- which holds no texts, has them.
local function entryTime(e)
    local m = math.floor(e.minute or 0)
    return Format.clock(math.floor(m / 60), Mod.floor(m, 60), KnoxMobile.Options.clock24())
end

-- A call log line: the contact's name, else the number (r8: every number that wasn't a contact showed as "?").
local function callLabel(call, sim)
    local name = call.name
    for _, c in ipairs(not name and sim and sim.contacts or {}) do
        if c.number == call.with then name = c.name end
    end
    name = name or call.with or "?"
    if call.failed then
        return T("IGUI_KnoxMobile_CallFailedLog", "Failed: %1", name), T("IGUI_KnoxMobile_CallFailedShort", "x %1", name)
    end
    if call.missed then return T("IGUI_KnoxMobile_CallMissed", "Missed: %1", name), T("IGUI_KnoxMobile_CallMissedShort", "! %1", name) end
    if call.inbound == false then
        return T("IGUI_KnoxMobile_CallOutgoing", "Called: %1", name), T("IGUI_KnoxMobile_CallOutgoingShort", "> %1", name)
    end
    return T("IGUI_KnoxMobile_CallReceived", "Received: %1", name), T("IGUI_KnoxMobile_CallReceivedShort", "< %1", name)
end

-- The rows above the contacts: Dial, then Recent calls and Voicemail when the phone has any.
local function phoneRows(ctx)
    local rows = { { id = "dial", label = T("IGUI_KnoxMobile_Dial", "Dial a number") } }
    if ctx.state.sim and #ctx.state.sim.contacts > 0 then
        rows[#rows + 1] = { id = "share", label = T("IGUI_KnoxMobile_ShareContact", "Share a contact") }
    end
    local c = ctx.state.contents or {}
    if c.calls and #c.calls > 0 then rows[#rows + 1] = { id = "calls", label = T("IGUI_KnoxMobile_RecentCalls", "Recent calls") } end
    if c.voicemails and #c.voicemails > 0 then
        rows[#rows + 1] = { id = "voicemail", label = T("IGUI_KnoxMobile_Voicemail", "Voicemail"), value = tostring(#c.voicemails) }
    end
    return rows
end

-- Newest first.
local function newestFirst(list, toItem)
    local items = {}
    for i = #list, 1, -1 do items[#items + 1] = toItem(list[i]) end
    return items
end

local function closeView(d) d.view, d.vm, d.keepBack, d.sel, d.scroll = nil, nil, false, 1, 0 end

KnoxMobile.Apps.register({
    id = "phone", name = "Phone", icon = ICONS .. "phone.png", glyph = ICONS .. "phone_glyph.png",
    label = function() return T("IGUI_KnoxMobile_AppPhone", "Phone") end,
    short = function() return T("IGUI_KnoxMobile_AppShortPhone", "Phone") end,
    families = ALL, drain = "screen", needsService = true, order = 20,
    render = function(ctx, x, y, w, h)
        if KnoxMobile.world.voice == false then
            for i, l in ipairs(ctx:wrap(T("IGUI_KnoxMobile_callFailed_noVoice", "Calls are turned off on this server"), w - 8)) do
                ctx:text(l, x + 4, y + 4 + (i - 1) * ctx:lineHeight())
            end
            return
        end
        local d, c, lh = ctx.data, ctx.state.contents or {}, ctx:lineHeight()
        if d.view == "calls" then
            ctx:list(newestFirst(c.calls or {}, function(e)
                -- Narrow screens keep the number and the time and drop the "Received:" word (final test: the time
                -- went first, then the number was cut).
                local label, who = callLabel(e, ctx.state.sim)
                return { label = label, short = who, value = entryTime(e), minor = true }
            end),
                x, y, w, h)
            return
        elseif d.view == "voicemail" then
            local vm = d.vm and (c.voicemails or {})[d.vm]
            if vm then
                ctx:text(Format.ellipsis(vm.name or "?", 24), x + 3, y, ctx.style.accent)
                for i, l in ipairs(ctx:wrap(vm.body or "", w - 8)) do
                    if (i + 1) * lh > h then break end
                    ctx:text(l, x + 3, y + i * lh)
                end
                return
            end
            ctx:list(newestFirst(c.voicemails or {}, function(e) return { label = e.name or "?", value = entryTime(e), minor = true } end),
                x, y, w, h)
            return
        end
        if d.view == "share" and ctx.state.sim then
            -- Share a contact: pick one, then the number to send it to (it goes as a contact card text).
            ctx:text(T("IGUI_KnoxMobile_ShareWhich", "Which contact?"), x + 3, y, ctx.style.accent)
            local items = {}
            for _, contact in ipairs(ctx.state.sim.contacts) do items[#items + 1] = { label = contact.name, sub = contact.number } end
            ctx:list(items, x, y + lh + 2, w, h - lh - 2)
            return
        end
        local items = phoneRows(ctx)
        local sim = ctx.state.sim
        if sim then
            for _, contact in ipairs(sim.contacts) do items[#items + 1] = { label = contact.name, sub = contact.number } end
            -- My number on one line when it fits, else "My number:" above the number.
            local mine = T("IGUI_KnoxMobile_MyNumber", "My number: %1", sim.number or "-")
            if ctx:measure(mine) <= w - 6 then
                ctx:text(mine, x + 3, y + h - lh - 2, ctx.style.accent)
                h = h - lh - 4
            else
                ctx:text(T("IGUI_KnoxMobile_MyNumberLabel", "My number:"), x + 3, y + h - 2 * lh - 2, ctx.style.accent)
                ctx:text(sim.number or "-", x + 3, y + h - lh - 2, ctx.style.accent)
                h = h - 2 * lh - 4
            end
        else
            items[#items + 1] = { label = T("IGUI_KnoxMobile_NoSim", "No SIM card") }
        end
        ctx:list(items, x, y, w, h)
    end,
    onInput = function(ctx, ev)
        if KnoxMobile.world.voice == false then return true end
        local d, c = ctx.data, ctx.state.contents or {}
        local back = ev.type == "key" and ev.key == "back"
        if d.view == "calls" then
            if back then closeView(d) else ctx:listInput(ev, #(c.calls or {})) end
            return true
        elseif d.view == "voicemail" then
            local count = #(c.voicemails or {})
            if d.vm then
                if back or ev.type == "tap" then d.vm = nil end
            elseif back then
                closeView(d)
            else
                local chosen = ctx:listInput(ev, count)
                if chosen then d.vm = count - chosen + 1 end
            end
            return true
        end
        local sim = ctx.state.sim
        if d.view == "share" then
            if back then closeView(d); return true end
            local pick = sim and ctx:listInput(ev, #sim.contacts)
            local contact = pick and sim.contacts[pick]
            if contact then
                askNumber(ctx, T("IGUI_KnoxMobile_ShareTo", "Send %1 to:", contact.name), function(number)
                    Net.toServer(ctx.player, "sendText", { phoneId = ctx.phone:getID(), to = number,
                        body = "Contact: " .. contact.name .. " " .. contact.number })
                end)
                closeView(d)
            end
            return true
        end
        local rows = phoneRows(ctx)
        local chosen = ctx:listInput(ev, #rows + (sim and #sim.contacts or 1))
        if not chosen then return true end
        local row = rows[chosen]
        if row and (row.id == "calls" or row.id == "voicemail" or row.id == "share") then
            d.view, d.keepBack, d.sel, d.scroll = row.id, true, 1, 0
            return true
        end
        if not sim then ctx:toast(T("IGUI_KnoxMobile_NoSim", "No SIM card")); return true end
        if row then
            askNumber(ctx, T("IGUI_KnoxMobile_Number", "Number:"), function(number) KnoxMobile.Client.placeCall(ctx.phone, number) end)
        elseif sim.contacts[chosen - #rows] then
            KnoxMobile.Client.placeCall(ctx.phone, sim.contacts[chosen - #rows].number)
        end
        return true
    end,
})

-- Radio: vanilla broadcasts through the hidden radio (spike 1.1) ----------------------------------
local STATIONS = {
    { name = "Hitz FM 89.4", channel = 89400 }, { name = "LBMW 93.2", channel = 93200 },
    { name = "NNR 98.0", channel = 98000 }, { name = "KnoxTalk 101.2", channel = 101200 },
}

KnoxMobile.Apps.register({
    id = "radio", name = "Radio", icon = ICONS .. "radio.png", glyph = ICONS .. "radio_glyph.png",
    label = function() return T("IGUI_KnoxMobile_AppRadio", "Radio") end,
    short = function() return T("IGUI_KnoxMobile_AppShortRadio", "Radio") end,
    families = RADIO, drain = "audio", needsService = false, order = 40,
    -- Only phones with an FM tuner (the Sisu 6606 and 5320 in Round 1); a PearPhone never had one.
    available = function(model) return Registry.hasExtra(model, "fmRadio") end,
    render = function(ctx, x, y, w, h)
        local items = {}
        local playing = KnoxMobile.Audio.mode == "radio" and ctx.data.playing
        for i, s in ipairs(STATIONS) do items[#items + 1] = { label = (playing == i and "> " or "") .. s.name } end
        items[#items + 1] = { label = T("IGUI_KnoxMobile_Stop", "Stop") }
        ctx:list(items, x, y, w, h)
    end,
    onInput = function(ctx, ev)
        local chosen = ctx:listInput(ev, #STATIONS + 1)
        if chosen and STATIONS[chosen] then
            if KnoxMobile.Audio.playRadio(ctx.phone, STATIONS[chosen].channel) then ctx.data.playing = chosen end
        elseif chosen then
            KnoxMobile.Audio.stopRadio()
            ctx.data.playing = nil
        end
        return true
    end,
    onClose = function() KnoxMobile.Audio.stopRadio() end,
})

-- Notes: what found phones' owners left behind, your journal (server Journal.lua) on your own phone, and notes you
-- write yourself: on any phone, so a phone left behind can carry a message for whoever finds it. Up/Down scroll.
KnoxMobile.Apps.register({
    id = "notes", name = "Notes", icon = ICONS .. "notes.png", glyph = ICONS .. "notes_glyph.png",
    label = function() return T("IGUI_KnoxMobile_AppNotes", "Notes") end,
    short = function() return T("IGUI_KnoxMobile_AppShortNotes", "Notes") end,
    families = NOTES, drain = "screen", needsService = false, order = 50,
    render = function(ctx, x, y, w, h)
        local notes = ctx.state.contents.notes or {}
        local d = ctx.data
        if d.open and notes[d.open] then
            local lh = ctx:lineHeight()
            local lines = ctx:wrap(notes[d.open].body, w - 8)
            local fits = math.max(1, math.floor(h / lh))
            d.top = math.max(0, math.min(d.top or 0, #lines - fits))
            for i = 1, fits do
                local l = lines[d.top + i]
                if l then ctx:text(l, x + 3, y + (i - 1) * lh) end
            end
            return
        end
        local items = {}
        for _, n in ipairs(notes) do items[#items + 1] = { label = Format.ellipsis((n.body or ""):match("^[^\n]*"), 30) } end
        if not ctx.state.security.locked then items[#items + 1] = { label = T("IGUI_KnoxMobile_WriteNote", "Write a note") } end
        ctx:list(items, x, y, w, h)
    end,
    onInput = function(ctx, ev)
        local d = ctx.data
        if d.open then
            if ev.type == "key" and ev.key == "up" then d.top = math.max(0, (d.top or 0) - 1)
            elseif (ev.type == "key" and ev.key == "down") or (ev.type == "wheel" and ev.delta > 0) then d.top = (d.top or 0) + 1
            elseif ev.type == "wheel" then d.top = math.max(0, (d.top or 0) - 1)
            elseif (ev.type == "key" and ev.key == "back") or ev.type == "tap" then d.open, d.keepBack = nil, false end
            return true
        end
        local notes = ctx.state.contents.notes or {}
        local writable = not ctx.state.security.locked
        local chosen = ctx:listInput(ev, #notes + (writable and 1 or 0))
        if chosen and chosen > #notes then
            ctx:askText(T("IGUI_KnoxMobile_NotePrompt", "Note:"), "", function(text)
                if text and text ~= "" then
                    Net.toServer(ctx.player, "writeNote", { phoneId = ctx.phone:getID(), body = text:sub(1, 600) })
                end
            end, 600)
        elseif chosen then
            d.open, d.keepBack, d.top = chosen, true, 0
        end
        return true
    end,
})

-- Settings -----------------------------------------------------------------------------------------
local SOUND_NEXT = { ring = "vibrate", vibrate = "silent", silent = "ring" }
local ROUTE_NEXT = { speaker = "earbuds", earbuds = "oneEarbud", oneEarbud = "headphones", headphones = "speaker" }
local VOLUMES = { 0.3, 0.5, 0.7, 1.0 }
local WALLPAPERS = 6 -- UI/Shells.lua pictures; the server accepts 0 (plain) to 6
local MODERN = { ModernAndroid = true, ModernPear = true }

-- The wallpaper on screen: modern phones show the first picture until one is chosen (they have no plain screen).
local function wallpaperShown(ctx)
    return ctx.state.look.wallpaper or (MODERN[ctx.family] and 1 or 0)
end

-- Can this phone use any earbuds or headphones at all? (The 1993 brick and the 2000 candybar can't.)
local function takesAudioGear(model)
    return model ~= nil and (AudioGear.fits(model, "jack", { dongle = true }) or AudioGear.fits(model, "wireless")
        or AudioGear.fits(model, model.connector))
end

-- Settings rows: a label, a value drawn whole at the right, and a short label for narrow screens (UI/Phone.lua list).
local function settingsRows(ctx)
    local st = ctx.state
    local family = Phones.registry:family(ctx.family)
    local onOff = function(on) return Util.word("Switch", on and "on" or "off") end
    local rows = {
        { id = "sound", label = T("IGUI_KnoxMobile_SetSound", "Sound"), value = Util.word("Sound", st.look.soundMode or "ring") },
        { id = "volume", label = T("IGUI_KnoxMobile_SetVolume", "Volume"),
            value = tostring(math.floor((st.look.volume or 0.7) * 100 + 0.5)) .. "%" },
    }
    if takesAudioGear(Phones.model(ctx.phone)) then
        rows[#rows + 1] = { id = "route", label = T("IGUI_KnoxMobile_SetAudio", "Audio"),
            value = Util.word("Route", st.look.audioRoute or "speaker") }
    end
    if ctx.family ~= "SegmentLCD" then
        rows[#rows + 1] = { id = "ringtone", label = T("IGUI_KnoxMobile_SetRingtone", "Ringtone"),
            short = T("IGUI_KnoxMobile_SetRingtoneShort", "Tone"), value = Util.word("Tone", st.look.ringtone or "classic") }
    end
    if family and family.wallpapers then
        local name = KnoxMobile.Shells and KnoxMobile.Shells.wallpaperName(wallpaperShown(ctx)) or tostring(st.look.wallpaper or "-")
        if st.look.wallpaperPhoto then name = T("IGUI_KnoxMobile_WpPhoto", "Photo") end
        rows[#rows + 1] = { id = "wallpaper", label = T("IGUI_KnoxMobile_SetWallpaper", "Wallpaper"),
            short = T("IGUI_KnoxMobile_SetWallpaperShort", "Wallp."), value = name }
    end
    if ctx.family == "ModernAndroid" or ctx.family == "ModernPear" then
        rows[#rows + 1] = { id = "saver", label = T("IGUI_KnoxMobile_SetSaver", "Battery saver"),
            short = T("IGUI_KnoxMobile_SetSaverShort", "Saver"), value = onOff(st.power.saver) }
    end
    -- Sandbox "Phone PINs" off: no PIN rows at all.
    if Phones.pinsOn() then
        if st.security.pin then
            rows[#rows + 1] = { id = "lock", label = T("IGUI_KnoxMobile_LockNow", "Lock now") }
            rows[#rows + 1] = { id = "clearPin", label = T("IGUI_KnoxMobile_RemovePin", "Remove PIN") }
        else
            rows[#rows + 1] = { id = "setPin", label = T("IGUI_KnoxMobile_SetPin", "Set a PIN") }
        end
    end
    rows[#rows + 1] = { id = "join", label = T("IGUI_KnoxMobile_JoinNetworkShort", "Join network") }
    if Util.settings().FindMyCrew and st.sim then
        rows[#rows + 1] = { id = "crew", label = T("IGUI_KnoxMobile_CrewSetting", "Find my crew: %1",
            st.crewShare and T("IGUI_KnoxMobile_On", "on") or T("IGUI_KnoxMobile_Off", "off")) }
    end
    if st.sim and #st.sim.contacts > 0 then
        rows[#rows + 1] = { id = "ice", label = T("IGUI_KnoxMobile_SetIce", "Emergency contact"),
            short = T("IGUI_KnoxMobile_SetIceShort", "ICE"),
            value = st.ice and st.ice.name or T("IGUI_KnoxMobile_None", "None") }
    end
    rows[#rows + 1] = { id = "info", label = T("IGUI_KnoxMobile_SetBatteryHealth", "Battery health"),
        short = T("IGUI_KnoxMobile_SetBatteryHealthShort", "Batt. health"), value = math.floor(st.battery.health) .. "%" }
    rows[#rows + 1] = { id = "size", label = T("IGUI_KnoxMobile_SetSize", "Phone size"), short = T("IGUI_KnoxMobile_SetSizeShort", "Size"),
        value = Util.word("Size", KnoxMobile.Options.size()) }
    rows[#rows + 1] = { id = "side", label = T("IGUI_KnoxMobile_SetSide", "Phone side"), short = T("IGUI_KnoxMobile_SetSideShort", "Side"),
        value = Util.word("Side", KnoxMobile.Options.side()) }
    return rows
end

KnoxMobile.Apps.register({
    id = "settings", name = "Settings", icon = ICONS .. "settings.png", glyph = ICONS .. "settings_glyph.png",
    label = function() return T("IGUI_KnoxMobile_AppSettings", "Settings") end,
    short = function() return T("IGUI_KnoxMobile_AppShortSettings", "Settings") end,
    families = ALL, drain = "screen", needsService = false, order = 90,
    render = function(ctx, x, y, w, h) ctx:list(settingsRows(ctx), x, y, w, h) end,
    onInput = function(ctx, ev)
        local rows = settingsRows(ctx)
        local chosen = ctx:listInput(ev, #rows)
        local row = chosen and rows[chosen]
        if not row then return true end
        local st = ctx.state
        if row.id == "sound" then ctx:setting("soundMode", SOUND_NEXT[st.look.soundMode] or "ring")
        elseif row.id == "volume" then
            local v, nextV = st.look.volume or 0.7, VOLUMES[1]
            for i, x in ipairs(VOLUMES) do if math.abs(x - v) < 0.01 then nextV = VOLUMES[Mod.floor(i, #VOLUMES) + 1] end end
            ctx:setting("volume", nextV)
        elseif row.id == "route" then ctx:setting("audioRoute", ROUTE_NEXT[st.look.audioRoute or "speaker"])
        elseif row.id == "ringtone" then
            local nextTone = { classic = "chiptune", chiptune = st.look.tune and "custom" or "classic", custom = "classic" }
            ctx:setting("ringtone", nextTone[st.look.ringtone or "classic"] or "classic")
        elseif row.id == "wallpaper" then
            local now = wallpaperShown(ctx)
            ctx:setting("wallpaper", MODERN[ctx.family] and (Mod.floor(now, WALLPAPERS) + 1) or (Mod.floor((now + 1), (WALLPAPERS + 1))))
        elseif row.id == "saver" then ctx:setting("saver", not st.power.saver)
        elseif row.id == "lock" then ctx:setting("lock", true)
        elseif row.id == "clearPin" then ctx:setting("setPin", "")
        elseif row.id == "setPin" then
            ctx:askText(T("IGUI_KnoxMobile_NewPin", "New 4-digit PIN:"), "", function(text)
                if text:match("^%d%d%d%d$") then ctx:setting("setPin", text)
                else ctx:toast(T("IGUI_KnoxMobile_PinDigits", "A PIN is 4 digits")) end
            end, 4, true)
        elseif row.id == "ice" then
            -- The next contact, then none: shown on the lock screen for whoever finds this phone.
            local contacts, nextNumber = st.sim and st.sim.contacts or {}, nil
            local at = 0
            for i, c in ipairs(contacts) do if st.ice and c.number == st.ice.number then at = i end end
            if contacts[at + 1] then nextNumber = contacts[at + 1].number end
            ctx:setting("ice", nextNumber)
        elseif row.id == "crew" then
            Net.toServer(ctx.player, "crewShare", { phoneId = ctx.phone:getID(), on = not st.crewShare })
        elseif row.id == "join" then
            ctx:askText(T("IGUI_KnoxMobile_RepPassword", "Network password"), "", function(text)
                if text ~= "" then Net.toServer(ctx.player, "joinRepeater", { password = text:sub(1, 32) }) end
            end, 32)
        elseif row.id == "size" then
            KnoxMobile.UI.cycleSize(ctx.panel.player, ctx.panel.item)
        elseif row.id == "side" then
            KnoxMobile.UI.flipSide(ctx.panel.player, ctx.panel.item)
        end
        return true
    end,
})