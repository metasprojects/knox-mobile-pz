-- Client: the music phones' player (0.3.0, Core/Music). It plays a phone's songs on your character's own sound, at
-- the phone's volume and through its audio route (Settings): with earbuds or headphones only you hear it (and you
-- hear the world less, like a call); on the speaker the server makes the noise and nearby players hear it too
-- (server/Music.lua, "musicRemote"). It goes on to the next song by itself, and stops when the phone is off, dead or
-- no longer on you.
local Music = require "KnoxMobile/Core/Music"
local Noise = require "KnoxMobile/Core/Noise"
local Phones = require "KnoxMobile/Game/Phones"
local Util = require "KnoxMobile/Game/Util"
local Net = require "KnoxMobile/Game/Net"
local Tick = require "KnoxMobile/Game/Tick"

local Player = { now = nil, remote = {} }
KnoxMobile.MusicPlayer = Player

local function me() return getPlayer() end

local function route(phone)
    local st = phone and Phones.get(phone)
    local l = st and st.look or {}
    return l.audioRoute or "speaker", l.volume or 0.7
end

local function songs(phone)
    local st = phone and Phones.get(phone)
    return st and st.contents and st.contents.music or {}
end

local function tellServer(p, phone, track, speaker, volume)
    Net.toServer(p, "musicState", { phoneId = phone:getID(), track = track, speaker = speaker, volume = volume })
end

function Player.stop(quiet)
    local n = Player.now
    if not n then return end
    Player.now = nil
    pcall(function() n.emitter:stopSound(n.soundId) end)
    if n.private and KnoxMobile.Audio and KnoxMobile.Audio.mode == nil then KnoxMobile.Audio.setHearing(false) end
    local p = me()
    if p and not quiet then tellServer(p, n.phone, nil) end
end

-- Plays song `index` of the phone's music. Returns true when it started.
function Player.play(phone, index)
    local p = me()
    local list = songs(phone)
    local song = list[index]
    if not (p and song) then return false end
    Player.stop(true)
    local how, volume = route(phone)
    local private = Noise.radius({ route = how, volume = volume }, {}) == 0
    local emitter = p:getEmitter()
    local id = emitter:playSound(song.track)
    if not id or id == 0 then return false end
    pcall(function() emitter:setVolume(id, volume * Noise.audioQuality(how)) end)
    if private and KnoxMobile.Audio then
        KnoxMobile.Audio.setHearing(Noise.hearingPenalty(how, { hearingPenalty = Util.settings().HearingPenalty }) ~= "none")
    end
    Player.now = { phone = phone, index = index, track = song.track, name = song.name, soundId = id, emitter = emitter,
        private = private, startedAt = getTimestampMs(), toldAt = getTimestampMs() }
    tellServer(p, phone, song.track, not private, volume)
    return true
end

function Player.skip(dir)
    local n = Player.now
    if not n then return end
    local nextIndex = Music.step(n.index, dir, #songs(n.phone))
    if nextIndex then Player.play(n.phone, nextIndex) end
end

-- Is this phone playing, and which song?
function Player.playing(phone)
    local n = Player.now
    if n and phone and n.phone:getID() == phone:getID() then return n.index, n.name end
    return nil
end

Tick.add("phone music", function()
    local n = Player.now
    if not n then return end
    local p = me()
    local st = n.phone and Phones.get(n.phone)
    local carried = p and p:getInventory():getItemWithIDRecursiv(n.phone:getID()) ~= nil
    if not (p and carried and st and st.power and st.power.on) or p:isDead() then Player.stop(); return end
    local ok, still = pcall(function() return n.emitter:isPlaying(n.soundId) end)
    -- A moment after it starts, a song that has ended goes on to the next.
    if ok and not still and getTimestampMs() - n.startedAt > 2000 then
        if #songs(n.phone) > 1 then Player.skip(1) else Player.stop() end
        return
    end
    if getTimestampMs() - n.toldAt >= Music.KEEPALIVE_MS then
        n.toldAt = getTimestampMs()
        local _, volume = route(n.phone)
        tellServer(p, n.phone, n.track, not n.private, volume)
    end
end, 1000)

-- Another player's phone on the speaker, near you: played from them, so it moves with them.
Net.onClient("musicRemote", function(args)
    local id = tonumber(args.onlineId)
    if not id then return end
    local was = Player.remote[id]
    if was then pcall(function() was.emitter:stopSound(was.soundId) end) end
    Player.remote[id] = nil
    if type(args.track) ~= "string" or not Music.isTrack(args.track) then return end
    local other = getPlayerByOnlineID and getPlayerByOnlineID(id)
    if not other or other == me() then return end
    local emitter = other:getEmitter()
    local soundId = emitter:playSound(args.track)
    if soundId and soundId ~= 0 then Player.remote[id] = { emitter = emitter, soundId = soundId } end
end)

return Player
