-- Client: phone sounds, the zombie noise they make, the hidden radio that plays broadcasts and carries
-- calls, and the hearing penalty while earbuds or headphones play (spec §9.1, §9.2, §9.7; spikes 1.1-1.6).
local Noise = require "KnoxMobile/Core/Noise"
local Phones = require "KnoxMobile/Game/Phones"
local Util = require "KnoxMobile/Game/Util"
local Net = require "KnoxMobile/Game/Net"
local Tick = require "KnoxMobile/Game/Tick"
local Composer = require "KnoxMobile/Core/Composer"

local Audio = { ring = nil, proxy = nil, mode = nil, route = "speaker", nextPulse = 0 }
KnoxMobile.Audio = Audio

local PROXY = "KnoxMobile.PhoneAudio"
local HEADPHONE_TYPE = { headphones = 0, earbuds = 1, oneEarbud = 1 }

local function me() return getPlayer() end
local function now() return getTimestampMs() end

local function noiseSettings()
    local s = Util.settings()
    return { noiseMultiplier = s.NoiseMultiplier, hearingPenalty = s.HearingPenalty }
end

-- How loud a phone sounds to you from a bag (0.2.0): muffled through the canvas; a buzz in a bag is barely felt.
Audio.BAG_VOLUME, Audio.BAG_BUZZ = 0.35, 0.4

local function play(sound, inBag)
    local p = me()
    if not p then return nil end
    -- Vibration is a cue only the player feels (spec §8.6); everything else is a sound in the world.
    if sound == "KnoxMobileVibrate" then
        if inBag and ZombRand(100) >= Audio.BAG_BUZZ * 100 then return nil end
        return getSoundManager():playUISound(sound)
    end
    local emitter = p:getEmitter()
    local id = emitter:playSound(sound)
    if inBag and id and id ~= 0 then pcall(function() emitter:setVolume(id, Audio.BAG_VOLUME) end) end
    return id
end

-- Zombie noise is made by the server so every zombie nearby hears it, in multiplayer too.
local function pulse(radius)
    if radius and radius >= 1 then Net.toServer(me(), "noise", { radius = math.floor(radius + 0.5) }) end
end

local function look(phone)
    local state = phone and Phones.get(phone)
    local l = state and state.look or {}
    return l.soundMode or "ring", l.volume or 0.7, l.audioRoute or "speaker", l.ringtone or "classic"
end

-- Ringing ---------------------------------------------------------------------------------------
function Audio.startRing(phone)
    local mode, volume, _, tone = look(phone)
    if mode == "silent" then return end
    local inBag = phone ~= nil and Phones.inBag(me(), phone)
    Audio.ring = { mode = mode, radius = Noise.ringRadius(mode, volume, inBag, noiseSettings()), next = 0,
        untilMs = now() + 60000, sound = tone == "chiptune" and "KnoxMobileRingtone" or "KnoxMobileRing", inBag = inBag }
    -- Your own tune (the Composer app): played through, then again while it rings.
    local state = phone and Phones.get(phone)
    if tone == "custom" and state and state.look.tune then Audio.ring.tune = Composer.parse(state.look.tune) end
end

-- A tune, note by note (the Composer app, a custom ringtone). notes: Composer.parse's list.
function Audio.playTune(notes, inBag)
    Audio.melody = notes and { notes = notes, i = 1, at = now(), inBag = inBag } or nil
end

Tick.add("phone melody", function()
    local m = Audio.melody
    if not m then return end
    local t = now()
    while m.i <= #m.notes and t >= m.at do
        local n = m.notes[m.i]
        if n.sound then play(n.sound, m.inBag) end
        m.at, m.i = m.at + n.ms, m.i + 1
    end
    if m.i > #m.notes then Audio.melody = nil end
end, 30)

function Audio.stopRing()
    if Audio.ring and Audio.ring.tune then Audio.melody = nil end
    Audio.ring = nil
end

-- One beep (and one short noise pulse) for texts, low battery and the like.
function Audio.onNotify(args, phone)
    local mode, volume = look(phone)
    if mode == "silent" then return end
    local inBag = phone ~= nil and Phones.inBag(me(), phone)
    if mode == "vibrate" then play("KnoxMobileVibrate", inBag); return end
    if args.kind == "texts" then
        play("KnoxMobileText", inBag)
        pulse(Noise.ringRadius(mode, volume, inBag, noiseSettings()) * 0.6)
    elseif args.kind == "battery" and (args.event == "low15" or args.event == "low5") then
        -- The low-battery beep is a noise like any other (spec §6.6).
        play("KnoxMobileLowBattery", inBag)
        pulse(Noise.ringRadius(mode, volume, inBag, noiseSettings()) * 0.3)
    end
end

-- The hidden radio ------------------------------------------------------------------------------
-- A weightless radio item in the main inventory, tuned by Lua. Broadcasts use a vanilla channel;
-- calls use a private two-way channel far above any vanilla radio.
-- B42 airs broadcasts only to the radio in a hand (single player) or to radios the voice code finds
-- (multiplayer), so the hidden radio is also registered as a radio device: the game's device loop then
-- hands it each line, and the line shows over the player like any radio's.
-- The server makes and removes the radio item (inventories are the server's in multiplayer); in single
-- player that happens at once. Tuning waits until the item shows up.
local function findProxy()
    local p = me()
    return p and p:getInventory():getFirstTypeRecurse(PROXY) or nil
end

-- Temporary Hard of Hearing while earbuds or headphones play; a trait the character already had is never touched.
function Audio.setHearing(on)
    local p = me()
    if not p then return end
    local md = p:getModData()
    local ok, err = pcall(function()
        if on and not p:hasTrait(CharacterTrait.HARD_OF_HEARING) then
            p:getCharacterTraits():add(CharacterTrait.HARD_OF_HEARING)
            md.KnoxMobileAddedHoH = true
        elseif not on and md.KnoxMobileAddedHoH then
            p:getCharacterTraits():remove(CharacterTrait.HARD_OF_HEARING)
            md.KnoxMobileAddedHoH = nil
        end
    end)
    if not ok then Util.log("hearing penalty failed:", err) end
end

-- Device registration (single player: ZomboidRadio.DistributeTransmission walks its device list).
local function register(radio)
    if Audio.registered == radio then return end
    local zr = getZomboidRadio()
    if not zr then return end
    if Audio.registered then pcall(function() zr:UnRegisterDevice(Audio.registered) end) end
    local ok, err = pcall(function() zr:RegisterDevice(radio) end)
    Audio.registered = ok and radio or nil
    if not ok then Util.log("phone audio: could not register the radio:", err) end
end

local function unregister()
    local radio = Audio.registered
    Audio.registered = nil
    local zr = radio and getZomboidRadio()
    if zr then pcall(function() zr:UnRegisterDevice(radio) end) end
end

local function apply(radio, want)
    local dd = radio:getDeviceData()
    if not dd then Util.log("phone audio: no radio device data"); return false end
    local channel, twoWay, phone, mode = want.channel, want.twoWay, want.phone, want.mode
    local _, volume, route = look(phone)
    Audio.proxy, Audio.route = radio, route
    pcall(function() dd:setHasBattery(true) end)
    pcall(function() dd:setPower(1.0) end)
    pcall(function() dd:setIsTwoWay(twoWay) end)
    pcall(function() dd:setMicIsMuted(not twoWay) end)
    dd:setIsTurnedOn(true)
    dd:setChannel(channel)
    -- One earbud in: no hearing penalty, but quieter (spec §9.1).
    dd:setDeviceVolume(volume * Noise.audioQuality(route))
    pcall(function() dd:setHeadphoneType(HEADPHONE_TYPE[route] or -1) end)
    Audio.setHearing(Noise.hearingPenalty(route, noiseSettings()) ~= "none")
    register(radio)
    -- Multiplayer voice: the server routes radio voice by the frequencies this sends.
    local p = me()
    if p and isClient() then pcall(function() p:updateEquippedRadioFreq() end) end
    Util.log("phone audio", mode, "channel", channel, "route", route, "two-way", twoWay)
    return true
end

function Audio.tune(channel, twoWay, phone, mode)
    Audio.mode, Audio.phone = mode, phone
    Audio.pending = { channel = channel, twoWay = twoWay, phone = phone, mode = mode, sinceMs = now() }
    local radio = findProxy()
    if radio then
        Audio.pending = nil
        return apply(radio, { channel = channel, twoWay = twoWay, phone = phone, mode = mode })
    end
    Net.toServer(me(), "audioProxy", { on = true })
    radio = findProxy() -- single player: already there
    if radio then
        Audio.pending = nil
        return apply(radio, { channel = channel, twoWay = twoWay, phone = phone, mode = mode })
    end
    return true
end

function Audio.off()
    local radio = Audio.proxy or findProxy()
    if radio then
        local dd = radio:getDeviceData()
        if dd then pcall(function() dd:setIsTurnedOn(false) end) end
    end
    unregister()
    Audio.proxy, Audio.pending = nil, nil
    Net.toServer(me(), "audioProxy", { on = false })
    Audio.mode, Audio.phone = nil, nil
    Audio.setHearing(false)
end

function Audio.playRadio(phone, channel) return Audio.tune(channel, false, phone, "radio") end
function Audio.stopRadio() if Audio.mode == "radio" then Audio.off() end end
function Audio.startCall(channel, phone) if channel then Audio.tune(channel, true, phone, "call") end end
function Audio.endCall() if Audio.mode == "call" then Audio.off() end end

-- Pulses: ringing repeats its sound and noise; a speaker playing out loud makes noise too.
Tick.add("phone audio tick", function()
    local t = now()
    local want = Audio.pending
    if want then
        local radio = findProxy()
        if radio then Audio.pending = nil; apply(radio, want)
        elseif t - want.sinceMs > 5000 then Audio.pending = nil; Util.log("phone audio: the server never made the radio") end
    end
    local r = Audio.ring
    if r then
        if t > r.untilMs then Audio.ring = nil
        elseif t >= r.next then
            r.next = t + Noise.PULSE_SECONDS * 1000
            if r.tune and r.mode ~= "vibrate" then
                Audio.playTune(r.tune, r.inBag)
                r.next = t + math.max(Noise.PULSE_SECONDS * 1000, Composer.length(r.tune) + 700)
            else
                play(r.mode == "vibrate" and "KnoxMobileVibrate" or r.sound, r.inBag)
            end
            if r.mode == "ring" then pulse(r.radius) end
        end
    end
    -- Ringback: the caller hears the line ringing (only they hear it).
    local call = KnoxMobile.Client and KnoxMobile.Client.call
    if call and call.status == "outgoing" and t >= (Audio.nextRingback or 0) then
        Audio.nextRingback = t + Noise.PULSE_SECONDS * 1000
        getSoundManager():playUISound("KnoxMobileRingback")
    end
    if Audio.mode and t >= Audio.nextPulse then
        Audio.nextPulse = t + Noise.PULSE_SECONDS * 1000
        local _, volume = look(Audio.phone)
        local route = Audio.mode == "call" and Audio.route == "speaker" and "ear" or Audio.route
        pulse(Noise.radius({ route = route, volume = volume }, noiseSettings()))
    end
end, 100)

-- After a crash or quit the hidden radio and the borrowed trait are cleaned up.
Events.OnGameStart.Add(Util.safe("phone audio cleanup", function()
    Audio.proxy = nil
    unregister()
    if findProxy() then Net.toServer(me(), "audioProxy", { on = false }) end
    Audio.setHearing(false)
end))

return Audio
