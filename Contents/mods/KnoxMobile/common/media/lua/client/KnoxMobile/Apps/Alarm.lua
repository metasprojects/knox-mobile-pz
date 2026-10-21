-- Client: the Alarm app (spec §4.6, every family), the ringing screen, right-click options and the ring itself.
-- The server decides when an alarm rings (server/KnoxMobile/Alarms.lua): it rings in your pocket, in a bag or on
-- the floor where you dropped it, as loud as the phone's volume, even on silent. Every player nearby hears it,
-- and so does every zombie within the sandbox AlarmRadius. That makes a phone a lure: set it, drop it, walk away.
local Mod = require "KnoxMobile/Core/Mod"
local AlarmLogic = require "KnoxMobile/Core/Alarm"
local Format = require "KnoxMobile/Core/Format"
local Noise = require "KnoxMobile/Core/Noise"
local Phones = require "KnoxMobile/Game/Phones"
local Net = require "KnoxMobile/Game/Net"
local Util = require "KnoxMobile/Game/Util"

local T = Util.text
local ICONS = "media/ui/KnoxMobile/apps/"
local HEAR = 45 -- tiles: further away than this a client doesn't bother playing the ring

local App = { ringing = {}, nextPulse = 0 }
KnoxMobile.AlarmApp = App

local function families()
    local out = {}
    for _, f in ipairs(Phones.registry:families()) do
        if f.features and f.features.alarm then out[#out + 1] = f.id end
    end
    return out
end

local function clock(h, m) return Format.clock(h, m, KnoxMobile.Options.clock24()) end

local function nowClock()
    local gt = getGameTime()
    return gt:getHour(), gt:getMinutes()
end

-- "7 h 12 min", "45 min".
function App.duration(minutes)
    local h, m = math.floor(minutes / 60), Mod.floor(minutes, 60)
    if h == 0 then return T("IGUI_KnoxMobile_Minutes", "%1 min", m) end
    if m == 0 then return T("IGUI_KnoxMobile_Hours", "%1 h", h) end
    return T("IGUI_KnoxMobile_HoursMinutes", "%1 h %2 min", h, m)
end

-- How far zombies will hear this phone's alarm (out of a bag).
function App.radius(state)
    return AlarmLogic.radius(state.look.volume or 0.7, false, { alarmRadius = Util.settings().AlarmRadius })
end

function App.send(player, phone, action, hour, minute, once)
    Net.toServer(player, "alarm", { phoneId = phone:getID(), action = action, hour = hour, minute = minute, once = once })
end

local function alarmOf(state) return type(state.alarm) == "table" and state.alarm or nil end

-- The app -----------------------------------------------------------------------------------------------
local function draft(ctx)
    local d = ctx.data
    if not d.hour then
        local a = alarmOf(ctx.state)
        if a and a.hour then d.hour, d.minute = a.hour, a.minute or 0
        else
            local h = nowClock()
            d.hour, d.minute = Mod.floor((h + 1), 24), 0
        end
    end
    return d.hour, d.minute
end

-- The hour as the clock shows it: "06" (24-hour) or "6 AM".
local function hourLabel(h)
    if KnoxMobile.Options.clock24() then return string.format("%02d", h) end
    local h12 = Mod.floor(h, 12)
    if h12 == 0 then h12 = 12 end
    return h12 .. (h < 12 and " AM" or " PM")
end

local function rows(ctx)
    local a = alarmOf(ctx.state)
    local h, m = draft(ctx)
    local out = {
        { id = "hour", label = T("IGUI_KnoxMobile_AlarmHour", "Hour < %1 >", hourLabel(h)) },
        { id = "minute", label = T("IGUI_KnoxMobile_AlarmMinute", "Minute < %1 >", string.format("%02d", m)) },
    }
    if a and a.on and a.hour == h and a.minute == m then
        out[#out + 1] = { id = "off", label = T("IGUI_KnoxMobile_AlarmTurnOff", "Turn off") }
    else
        out[#out + 1] = { id = "set", label = T("IGUI_KnoxMobile_AlarmSet", "Set for %1", clock(h, m)) }
    end
    for _, q in ipairs(AlarmLogic.QUICK) do
        local label = q >= 60 and T("IGUI_KnoxMobile_AlarmRingInHour", "Ring in %1 h", math.floor(q / 60))
            or T("IGUI_KnoxMobile_AlarmRingInMin", "Ring in %1 min", q)
        out[#out + 1] = { id = "quick", minutes = q, label = label }
    end
    return out
end

local function adjust(ctx, row, dir)
    local d = ctx.data
    draft(ctx)
    if row.id == "hour" then d.hour = Mod.floor((d.hour + dir), 24)
    elseif row.id == "minute" then d.minute = Mod.floor((d.minute + dir), 60) end
end

local function setAlarm(ctx, h, m, once)
    App.send(ctx.player, ctx.phone, "set", h, m, once)
    ctx.data.hour, ctx.data.minute = h, m
end

KnoxMobile.Apps.register({
    id = "alarm", name = "Alarm", icon = ICONS .. "alarm.png", glyph = ICONS .. "alarm_glyph.png",
    label = function() return T("IGUI_KnoxMobile_AppAlarm", "Alarm") end,
    short = function() return T("IGUI_KnoxMobile_AppShortAlarm", "Alarm") end,
    families = families(), drain = "screen", needsService = false, order = 55,
    render = function(ctx, x, y, w, h)
        ctx:wantsDigits(true)
        local lh = ctx:lineHeight()
        local a = alarmOf(ctx.state)
        local on = a ~= nil and a.on == true
        local list = rows(ctx)
        local listH = #list * (lh + 4)
        local spare = h - listH
        local cy = y + 2
        local hh, mm = nowClock()
        local status = T("IGUI_KnoxMobile_AlarmIsOff", "Alarm is off")
        if on then
            status = T("IGUI_KnoxMobile_AlarmRingsIn", "Rings in %1", App.duration(AlarmLogic.minutesUntil(a.hour, a.minute, hh, mm)))
        end
        local largeH = KnoxMobile.UI.fontH(UIFont.Large)
        local dim = { 0.7, 0.74, 0.8 }
        if ctx.family == "SegmentLCD" or ctx.family == "MonoLCD" then dim = ctx.style.fg end
        if spare >= largeH + 3 * lh + 16 then
            -- Big screens: the alarm time, the countdown and the lure note above the controls.
            ctx:text(on and clock(a.hour, a.minute) or "--:--", x + w / 2, cy, on and ctx.style.accent or dim, UIFont.Large, "center")
            cy = cy + largeH
            ctx:text(status, x + w / 2, cy, dim, nil, "center")
            cy = cy + lh + 5
            -- The screen says it the way a phone would; what hears it is for the player to work out.
            local radius = math.floor(App.radius(ctx.state))
            local lure = radius > 0 and T("IGUI_KnoxMobile_AlarmCarries", "Rings even on silent. Anything within %1 m will hear it.",
                radius) or T("IGUI_KnoxMobile_AlarmEvenSilent", "Rings even on silent.")
            local lines = ctx:wrap(lure, w - 16)
            local fit = math.floor((y + h - listH - cy - 8) / lh)
            if fit < #lines then
                local short = radius > 0 and T("IGUI_KnoxMobile_AlarmCarriesShort", "Heard within %1 m, even on silent.", radius)
                    or T("IGUI_KnoxMobile_AlarmEvenSilent", "Rings even on silent.")
                lines = ctx:wrap(short, w - 16)
            end
            local room = math.min(#lines, fit)
            if room > 0 then
                ctx:rect(x + 4, cy - 2, w - 8, room * lh + 6, { 0.95, 0.5, 0.2 }, 0.18)
                for i = 1, room do ctx:text(lines[i], x + 8, cy + 1 + (i - 1) * lh, { 1, 0.65, 0.35 }) end
                cy = cy + room * lh + 8
            end
        elseif spare >= lh + 4 then
            -- Small screens: one status line.
            local line = on and T("IGUI_KnoxMobile_AlarmOnShort", "On: %1", clock(a.hour, a.minute)) or status
            ctx:text(line, x + 3, cy, on and ctx.style.accent or nil)
            cy = cy + lh + 3
        end
        ctx:list(list, x, cy, w, y + h - cy)
    end,
    onInput = function(ctx, ev)
        local d = ctx.data
        local list = rows(ctx)
        d.sel = math.max(1, math.min(d.sel or 1, #list))
        local row = list[d.sel]
        if ev.type == "key" and (ev.key == "left" or ev.key == "right") and row and (row.id == "hour" or row.id == "minute") then
            adjust(ctx, row, ev.key == "right" and 1 or -1)
            return true
        end
        -- Typing four digits sets the time (24-hour): 0630.
        if ev.type == "key" and ev.key:match("^%d$") then
            d.typed = ((d.typed or "") .. ev.key):sub(-4)
            if #d.typed == 4 then
                local h, m = tonumber(d.typed:sub(1, 2)), tonumber(d.typed:sub(3, 4))
                if AlarmLogic.valid(h, m) then d.hour, d.minute = h, m end
                d.typed = ""
            end
            return true
        end
        local chosen = ctx:listInput(ev, #list)
        row = chosen and list[chosen]
        if not row then return true end
        if row.id == "hour" or row.id == "minute" then
            -- Enter or a tap: forward one hour, or five minutes. Tapping the left of the row goes back.
            local back = ev.type == "tap" and ev.x < ctx.w / 3
            if row.id == "hour" then adjust(ctx, row, back and -1 or 1) else adjust(ctx, row, back and -5 or 5) end
            d.minute = d.minute - Mod.floor(d.minute, (row.id == "minute" and 5 or 1))
        elseif row.id == "set" then
            setAlarm(ctx, draft(ctx))
        elseif row.id == "off" then
            App.send(ctx.player, ctx.phone, "off")
        elseif row.id == "quick" then
            local h, m = nowClock()
            local ah, am = AlarmLogic.later(h, m, row.minutes)
            setAlarm(ctx, ah, am, true)
        end
        return true
    end,
})

-- The ringing screen: takes over the phone (even locked) until snoozed or stopped -----------------------
KnoxMobile.Screen.register({
    id = "alarmring", priority = 50,
    isAvailable = function(phone)
        local st = Phones.get(phone)
        return st ~= nil and st.power.on and alarmOf(st) ~= nil and st.alarm.ringing ~= nil
    end,
    render = function(ctx, x, y, w, h)
        local a = ctx.state.alarm
        local lh = ctx:lineHeight()
        local flash = Mod.floor(math.floor(getTimestampMs() / 500), 2) == 0
        local lcd = ctx.family == "SegmentLCD" or ctx.family == "MonoLCD"
        local bg = lcd and ctx.style.bg or (flash and { 0.75, 0.2, 0.15 } or { 0.45, 0.1, 0.08 })
        ctx:rect(x, y, w, h, bg)
        local fg = lcd and ctx.style.fg or { 1, 1, 1 }
        local time = clock(a.hour or 0, a.minute or 0)
        -- Tiny screens: one line, Enter snoozes, Backspace stops.
        if h < 5 * lh then
            App.split = h
            local line = (flash and "* " or "  ") .. T("IGUI_KnoxMobile_AlarmRingShort", "ALARM %1", time)
            ctx:text(line, x + w / 2, y + 2, fg, nil, "center")
            -- The keys on one line when it fits, else one per line ("Enter: snooze" first, as room allows).
            local keys = T("IGUI_KnoxMobile_AlarmKeys", "Enter: snooze  Back: stop")
            if h > 2 * lh and ctx:measure(keys) <= w - 4 then
                ctx:text(keys, x + w / 2, y + lh + 4, fg, nil, "center")
            elseif h > 2 * lh then
                ctx:text(T("IGUI_KnoxMobile_AlarmEnterSnooze", "Enter: snooze"), x + w / 2, y + lh + 4, fg, nil, "center")
                if h > 3 * lh + 4 then
                    ctx:text(T("IGUI_KnoxMobile_AlarmBackStop", "Back: stop"), x + w / 2, y + 2 * lh + 4, fg, nil, "center")
                end
            end
            return
        end
        local medH, largeH = KnoxMobile.UI.fontH(UIFont.Medium), KnoxMobile.UI.fontH(UIFont.Large)
        local snooze = T("IGUI_KnoxMobile_Snooze", "Snooze %1 min", AlarmLogic.SNOOZE_MINUTES)
        local stop = T("IGUI_KnoxMobile_StopAlarm", "Stop")
        if h < medH + largeH + 2 * (lh + 10) + 18 then
            -- Mid-size LCDs: the time and the two keys as text.
            App.split = math.floor(h / 2)
            local ty = y + 3
            local title = T("IGUI_KnoxMobile_AlarmRingShort", "ALARM %1", time)
            local f = KnoxMobile.UI.textW(title, UIFont.Medium) <= w - 4 and UIFont.Medium or UIFont.Small
            ctx:text(title, x + w / 2, ty, fg, f, "center")
            ty = ty + KnoxMobile.UI.fontH(f) + 2
            ctx:text(T("IGUI_KnoxMobile_AlarmEnterSnooze", "Enter: snooze"), x + w / 2, ty, fg, nil, "center")
            ctx:text(T("IGUI_KnoxMobile_AlarmBackStop", "Back: stop"), x + w / 2, ty + lh, fg, nil, "center")
            return
        end
        local cy = y + 8
        -- The bell, when the screen is tall.
        local glyph = getTexture(ICONS .. "alarm_glyph.png")
        local gs = math.min(56, math.floor(w * 0.3))
        if glyph and h > medH + largeH + 4 * lh + gs + 40 then
            local shake = flash and 2 or -2
            ctx.panel:drawTextureScaled(glyph, ctx.sx + x + math.floor((w - gs) / 2) + shake, ctx.sy + cy, gs, gs, 1, fg[1], fg[2], fg[3])
            cy = cy + gs + 4
        end
        ctx:text(T("IGUI_KnoxMobile_AlarmTitle", "Alarm"), x + w / 2, cy, fg, UIFont.Medium, "center")
        cy = cy + medH + 2
        ctx:text(time, x + w / 2, cy, fg, UIFont.Large, "center")
        cy = cy + largeH + 8
        -- Two big keys at the bottom: snooze above stop.
        local btnH = math.max(lh + 8, math.min(lh * 3, math.floor((y + h - cy - 14) / 2)))
        local stopY = y + h - 8 - btnH
        local snoozeY = stopY - 6 - btnH
        App.split = stopY - 3 -- screen sources get a fresh ctx each frame, so the split lives here
        if lcd then
            ctx:border(x + 6, snoozeY, w - 12, btnH, fg)
            ctx:border(x + 6, stopY, w - 12, btnH, fg)
        else
            ctx:rect(x + 6, snoozeY, w - 12, btnH, { 0.95, 0.65, 0.2 }, 0.95)
            ctx:rect(x + 6, stopY, w - 12, btnH, { 0.15, 0.15, 0.18 }, 0.95)
        end
        ctx:text(snooze, x + w / 2, snoozeY + math.floor((btnH - lh) / 2), fg, nil, "center")
        ctx:text(stop, x + w / 2, stopY + math.floor((btnH - lh) / 2), fg, nil, "center")
    end,
    onInput = function(ctx, ev)
        local snooze = (ev.type == "key" and ev.key == "select") or (ev.type == "tap" and ev.y < (App.split or ctx.h / 2))
        local stop = (ev.type == "key" and ev.key == "back") or (ev.type == "tap" and not snooze)
        if snooze then App.send(ctx.player, ctx.phone, "snooze") elseif stop then App.send(ctx.player, ctx.phone, "stop") end
    end,
})

-- Right-click a phone (in your bags or on the floor): stop, snooze or switch off its alarm --------------------
Events.OnFillInventoryObjectContextMenu.Add(Util.safe("alarm menu", function(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    local actual = ISInventoryPane.getActualItems(items)
    local item = actual[1]
    if not player or not item or not Phones.isPhone(item) then return end
    local st = Phones.get(item)
    local a = st and alarmOf(st)
    if not a then return end
    if a.ringing then
        context:addOption(T("IGUI_KnoxMobile_MenuStopAlarm", "Stop the alarm"), nil, function() App.send(player, item, "stop") end)
        context:addOption(T("IGUI_KnoxMobile_MenuSnooze", "Snooze the alarm"), nil, function() App.send(player, item, "snooze") end)
    elseif a.on then
        context:addOption(T("IGUI_KnoxMobile_MenuAlarmOff", "Turn off the alarm (%1)", clock(a.hour, a.minute)), nil,
            function() App.send(player, item, "off") end)
    end
end))

-- What the server says --------------------------------------------------------------------------------
Net.onClient("alarmNotify", function(args)
    local text
    if args.event == "set" then
        local h, m = nowClock()
        text = T("IGUI_KnoxMobile_AlarmSetFor", "Alarm set for %1 (in %2)", clock(args.hour, args.minute),
            App.duration(AlarmLogic.minutesUntil(args.hour, args.minute, h, m)))
    elseif args.event == "ringing" then
        text = T("IGUI_KnoxMobile_AlarmRinging", "Your phone's alarm is ringing!")
    elseif args.event == "off" then
        text = T("IGUI_KnoxMobile_AlarmOff", "Alarm off")
    elseif args.event == "snoozed" then
        text = T("IGUI_KnoxMobile_AlarmSnoozed", "Snoozed for %1 min", AlarmLogic.SNOOZE_MINUTES)
    elseif args.event == "phoneOff" then
        text = T("IGUI_KnoxMobile_AlarmNeedsPower", "Turn the phone on to set an alarm")
    end
    -- A ringing alarm pops up even with popups off, like a call.
    if text and KnoxMobile.Client then KnoxMobile.Client.toast(text, args.event == "ringing" and "call" or "alarm") end
end)

-- A ringing alarm anywhere nearby: every client plays it where the phone is.
Net.onClient("alarmRing", function(args)
    if type(args.id) == "string" then
        App.ringing[args.id] = args
        App.nextPulse = 0
    end
end)

Net.onClient("alarmQuiet", function(args)
    if type(args.id) == "string" then App.ringing[args.id] = nil end
end)

local function playRing(player, r)
    local mine = r.phoneId and Phones.findById(player, r.phoneId)
    if mine then
        player:getEmitter():playSound(r.sound or "KnoxMobileRing")
    else
        local emitter = getWorld():getFreeEmitter(r.x + 0.5, r.y + 0.5, r.z)
        if emitter then emitter:playSound(r.sound or "KnoxMobileRing") end
    end
    -- An alarm in your pocket, or one ringing close by, wakes you.
    if player:isAsleep() and (mine or (r.radius or 0) >= 1) then
        local dx, dy = player:getX() - r.x, player:getY() - r.y
        if mine or dx * dx + dy * dy <= (r.radius or 0) * (r.radius or 0) / 4 then player:forceAwake() end
    end
end

Events.OnTick.Add(Util.safe("alarm ring", function()
    if Util.isEmpty(App.ringing) then return end
    local t = getTimestampMs()
    if t < App.nextPulse then return end
    App.nextPulse = t + Noise.PULSE_SECONDS * 1000
    local player = getPlayer()
    if not player then return end
    local now = Util.nowMinutes()
    for id, r in pairs(App.ringing) do
        if (r.untilMinute or 0) < now then
            App.ringing[id] = nil
        else
            local dx, dy = player:getX() - r.x, player:getY() - r.y
            if dx * dx + dy * dy <= HEAR * HEAR and math.abs(player:getZ() - r.z) < 3 then playRing(player, r) end
        end
    end
end))

return App
