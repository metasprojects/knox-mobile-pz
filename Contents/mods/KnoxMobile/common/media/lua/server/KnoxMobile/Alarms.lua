-- Server: phone alarms (client/KnoxMobile/Apps/Alarm.lua is the app; Core/Alarm the rules). The server decides
-- when an alarm rings, so it rings wherever the phone is: in a pocket, in a bag, in a crate, or on the floor
-- where its owner dropped it and walked away. While it rings:
--   * zombies hear it (addSound at the phone, every few seconds, radius from sandbox AlarmRadius and the volume;
--     half that from inside a bag or a container), the same way a ringing call draws them;
--   * every client is told where it rings and plays it there, so everyone nearby hears it;
--   * whoever carries it gets a notification, and the phone shows the alarm screen (snooze or stop).
-- Phones with an active alarm are tracked by item id. The live item is kept in memory; its last known square is
-- saved in the world data ("alarms"), so a phone on the floor is found again after a restart.
local AlarmLogic = require "KnoxMobile/Core/Alarm"
local Noise = require "KnoxMobile/Core/Noise"
local Phones = require "KnoxMobile/Game/Phones"
local Util = require "KnoxMobile/Game/Util"
local Net = require "KnoxMobile/Game/Net"
local State = require "KnoxMobile/State"

local Alarms = { items = {}, ringing = {}, nextPulse = 0 }
KnoxMobile.Alarms = Alarms

local REACH = 3      -- tiles: stop or snooze a phone lying this close
local LOST_AFTER = 1440 -- minutes a tracked phone can be missing (unloaded area, destroyed) before we forget it

local function key(id) return tostring(id) end

local function tracked()
    local md = State.get()
    if type(md.alarms) ~= "table" then md.alarms = {} end
    return md.alarms
end

function Alarms.track(item)
    local k = key(item:getID())
    Alarms.items[k] = item
    local list = tracked()
    list[k] = list[k] or {}
    list[k].id = item:getID()
end

local function settings() return { alarmRadius = Util.settings().AlarmRadius } end

-- Where a phone is now: x, y, z, the player carrying it (or nil), its world object when on the floor, whether it
-- is muffled (in a bag or a container), and the live item.
function Alarms.locate(item)
    local id = item:getID()
    for _, p in ipairs(Util.players()) do
        local found = Phones.findById(p, id)
        if found then
            return math.floor(p:getX()), math.floor(p:getY()), math.floor(p:getZ()), p, nil, Phones.inBag(p, found), found
        end
    end
    local wo = item:getWorldItem()
    local sq = wo and wo:getSquare()
    if sq then return sq:getX(), sq:getY(), sq:getZ(), nil, wo, false, item end
    local c = item:getOutermostContainer()
    if not c then return nil end
    local parent = c:getParent()
    if parent then
        return math.floor(parent:getX()), math.floor(parent:getY()), math.floor(parent:getZ()), nil, nil, true, item
    end
    local holder = c:getContainingItem()
    local hw = holder and holder:getWorldItem()
    local hsq = hw and hw:getSquare()
    if hsq then return hsq:getX(), hsq:getY(), hsq:getZ(), nil, hw, true, item end
    local grid = c:getSourceGrid()
    if grid then return grid:getX(), grid:getY(), grid:getZ(), nil, nil, true, item end
    return nil
end

-- After a restart (or when the chunk reloads), look for the phone where it was last seen.
local function refind(entry)
    if not entry.x then return nil end
    for dx = -1, 1 do
        for dy = -1, 1 do
            local sq = getCell():getGridSquare(entry.x + dx, entry.y + dy, entry.z)
            if sq then
                local list = sq:getWorldObjects()
                for i = 0, list:size() - 1 do
                    local it = list:get(i):getItem()
                    if it and it:getID() == entry.id then return it end
                end
            end
        end
    end
    return nil
end

-- Saves a phone's state to whoever can see it: its carrier, or every client for one on the floor.
local function save(item, holder, wo)
    if holder then Phones.save(item, holder)
    elseif wo and isServer() and wo.transmitCompleteItemToClients then wo:transmitCompleteItemToClients() end
end

local function tone(state)
    return state.look.ringtone == "chiptune" and "KnoxMobileRingtone" or "KnoxMobileRing"
end

local function quiet(k)
    if Alarms.ringing[k] then
        Alarms.ringing[k] = nil
        Net.toAll("alarmQuiet", { id = k })
    end
end

-- Zombies hear it: one pulse now, then every few seconds from OnTick.
local function pulse(r)
    if r.radius >= 1 then addSound(r.source, r.x, r.y, r.z, r.radius, r.radius) end
end

local function ring(k, item, state, x, y, z, holder, wo, muffled)
    local r = Alarms.ringing[k] or {}
    r.x, r.y, r.z, r.source = x, y, z, holder or wo
    r.radius = AlarmLogic.radius(state.look.volume or 0.7, muffled, settings())
    local fresh = Alarms.ringing[k] == nil
    Alarms.ringing[k] = r
    Net.toAll("alarmRing", { id = k, phoneId = item:getID(), x = x, y = y, z = z, sound = tone(state),
        untilMinute = AlarmLogic.ringsUntil(state.alarm), radius = r.radius })
    if fresh then pulse(r) end
end

-- Every game minute (from PhoneTick): find each tracked phone, ring it when its time comes, end unanswered rings.
function Alarms.tick()
    local now = Util.nowMinutes()
    local gt = getGameTime()
    local hour, minute = gt:getHour(), gt:getMinutes()
    local list = tracked()
    for k, entry in pairs(list) do
        local item = Alarms.items[k]
        local x, y, z, holder, wo, muffled, live
        if item then x, y, z, holder, wo, muffled, live = Alarms.locate(item) end
        if not x then
            item = refind(entry)
            if item then x, y, z, holder, wo, muffled, live = Alarms.locate(item) end
        end
        if not x then
            entry.lost = (entry.lost or 0) + 1
            Alarms.items[k] = nil
            quiet(k)
            if entry.lost > LOST_AFTER then list[k] = nil end
        else
            item = live or item
            Alarms.items[k] = item
            entry.x, entry.y, entry.z, entry.lost = x, y, z, nil
            local state = Phones.get(item)
            if not state or not AlarmLogic.active(state.alarm) then
                list[k], Alarms.items[k] = nil, nil
                quiet(k)
            else
                local works = state.power.on and state.battery.charge > 0 and state.condition ~= "broken"
                local event
                if works then
                    event = AlarmLogic.check(state.alarm, now, hour, minute)
                elseif state.alarm.ringing then
                    AlarmLogic.stop(state.alarm) -- a dead or switched-off phone falls silent
                    event = "timeout"
                end
                if event == "ring" then
                    ring(k, item, state, x, y, z, holder, wo, muffled)
                    if holder then Net.toClient(holder, "alarmNotify", { event = "ringing", phoneId = item:getID() }) end
                    Util.log("alarm ringing on phone", k, "at", x, y, z, holder and ("carried by " .. Util.playerKey(holder)) or "")
                    save(item, holder, wo)
                elseif event == "timeout" then
                    quiet(k)
                    save(item, holder, wo)
                elseif state.alarm.ringing then
                    ring(k, item, state, x, y, z, holder, wo, muffled) -- it may have moved
                elseif not AlarmLogic.active(state.alarm) then
                    list[k], Alarms.items[k] = nil, nil
                end
            end
        end
    end
end

-- Noise pulses between minute ticks, on the real-time cadence a ringing call uses.
function Alarms.pulse()
    if Util.isEmpty(Alarms.ringing) then return end
    local t = getTimestampMs()
    if t < Alarms.nextPulse then return end
    Alarms.nextPulse = t + Noise.PULSE_SECONDS * 1000
    for _, r in pairs(Alarms.ringing) do pulse(r) end
end

-- The phone a command is about: in the player's inventory, or (to stop or snooze it) a tracked phone lying
-- within reach.
local function phoneFor(player, args, allowNearby)
    if type(args.phoneId) ~= "number" then return nil end
    local item = Phones.findById(player, args.phoneId)
    if item then
        if not Phones.isPhone(item) then return nil end
        return item, player, nil
    end
    if not allowNearby then return nil end
    local tr = Alarms.items[key(args.phoneId)]
    if not tr then return nil end
    local x, y, z, holder, wo, _, live = Alarms.locate(tr)
    if not x or holder then return nil end
    if math.abs(x - player:getX()) > REACH + 1 or math.abs(y - player:getY()) > REACH + 1 or z ~= math.floor(player:getZ()) then
        return nil
    end
    return live or tr, nil, wo
end

local ACTIONS = { set = true, off = true, snooze = true, stop = true }

Net.onServer("alarm", function(player, args)
    if not ACTIONS[args.action] then return end
    local item, holder, wo = phoneFor(player, args, args.action ~= "set")
    if not item then return end
    local state = Phones.get(item)
    if not state then return end
    local now = Util.nowMinutes()
    local k = key(item:getID())
    local reply
    if args.action == "set" then
        if not AlarmLogic.valid(args.hour, args.minute) then return end
        if not state.power.on then Net.toClient(player, "alarmNotify", { event = "phoneOff" }); return end
        state.alarm = AlarmLogic.set(type(state.alarm) == "table" and state.alarm or nil, args.hour, args.minute, now,
            args.once == true)
        Alarms.track(item)
        quiet(k)
        reply = { event = "set", hour = args.hour, minute = args.minute }
    elseif type(state.alarm) ~= "table" then
        return
    elseif args.action == "off" then
        AlarmLogic.off(state.alarm)
        quiet(k)
        reply = { event = "off" }
    elseif args.action == "snooze" then
        if not state.alarm.ringing then return end
        AlarmLogic.snooze(state.alarm, now)
        quiet(k)
        reply = { event = "snoozed" }
    else
        AlarmLogic.stop(state.alarm)
        quiet(k)
    end
    save(item, holder, wo)
    if reply then reply.phoneId = item:getID(); Net.toClient(player, "alarmNotify", reply) end
end)

Events.OnTick.Add(Util.safe("alarm pulses", function()
    if isClient() then return end
    Alarms.pulse()
end))

return Alarms
