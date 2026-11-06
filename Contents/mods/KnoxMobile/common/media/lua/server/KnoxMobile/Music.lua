-- Server: music on the phones (0.3.0, Core/Music). "musicCopy" puts a song you carry (a True Moozic cassette, record
-- or disc) on a music phone. "musicState" says what a phone plays and how: on the speaker the server makes the noise
-- zombies hear (every few seconds) and tells nearby players, whose clients play it from the player ("musicRemote").
local Music = require "KnoxMobile/Core/Music"
local Noise = require "KnoxMobile/Core/Noise"
local Net = require "KnoxMobile/Game/Net"
local Util = require "KnoxMobile/Game/Util"
local Tick = require "KnoxMobile/Game/Tick"
local Phones = require "KnoxMobile/Game/Phones"
local Protocol = require "KnoxMobile/Core/Protocol"

local World = { playing = {}, nextAt = 0, PULSE_MS = 5000 }
KnoxMobile.MusicWorld = World

Protocol.register({
    musicCopy = function(args)
        if type(args.phoneId) ~= "number" or type(args.itemId) ~= "number" then return false, "ids must be numbers" end
        return true
    end,
    musicState = function(args)
        if type(args.phoneId) ~= "number" then return false, "phoneId must be a number" end
        if args.track ~= nil and (type(args.track) ~= "string" or #args.track > 80) then return false, "bad track" end
        if args.volume ~= nil and type(args.volume) ~= "number" then return false, "volume must be a number" end
        return true
    end,
})

local function tell(player, event, name) Net.toClient(player, "notify", { kind = "music", event = event, source = name }) end

-- The game's name for a song's item, or a tidy one from its type.
function World.nameOf(itemType)
    local ok, name = pcall(function()
        local script = getScriptManager():FindItem(itemType)
        return script and script:getDisplayName()
    end)
    if ok and type(name) == "string" and name ~= "" then return name end
    return Music.prettyName(itemType)
end

Net.onServer("musicCopy", function(player, args)
    local phone = Phones.findById(player, args.phoneId)
    local song = player:getInventory():getItemWithIDRecursiv(args.itemId)
    if not (phone and song and Phones.isPhone(phone) and Music.isTrack(song:getType())) then return end
    local state, model = Phones.get(phone)
    if not (state and state.power and state.power.on) then return end
    local name = song:getDisplayName()
    local result = Music.add(state, model, song:getType(), name)
    if result == "added" then Phones.save(phone, player) end
    tell(player, result, name)
end)

-- Who hears a speaker: the other players near this one.
local function nearby(player)
    local out = {}
    for _, p in ipairs(Util.players()) do
        if p ~= player and math.abs(p:getX() - player:getX()) <= Music.HEAR and math.abs(p:getY() - player:getY()) <= Music.HEAR then
            out[#out + 1] = p
        end
    end
    return out
end

local function relay(player, track)
    if not isServer() then return end
    local id = player:getOnlineID()
    for _, p in ipairs(nearby(player)) do Net.toClient(p, "musicRemote", { onlineId = id, track = track }) end
end

Net.onServer("musicState", function(player, args)
    local key = Util.playerKey(player)
    local was = World.playing[key]
    if not args.track then
        World.playing[key] = nil
        if was and was.speaker then relay(player, nil) end
        return
    end
    if not Music.isTrack(args.track) then return end
    local speaker = args.speaker == true
    World.playing[key] = { player = player, track = args.track, speaker = speaker,
        volume = math.max(0, math.min(1, args.volume or 0.7)), at = getTimestampMs() }
    if speaker and not (was and was.speaker and was.track == args.track) then relay(player, args.track)
    elseif was and was.speaker and not speaker then relay(player, nil) end
end)

-- Every few seconds: a speaker playing draws the dead (Noise.radius, like a ringing phone); a phone that stopped
-- saying it plays is forgotten.
Tick.add("phone music", function()
    if isClient() then return end
    local t = getTimestampMs()
    if t < World.nextAt then return end
    World.nextAt = t + World.PULSE_MS
    local settings = { noiseMultiplier = Util.settings().NoiseMultiplier }
    for key, m in pairs(World.playing) do
        if t - m.at > Music.EXPIRE_MS or m.player:isDead() then
            World.playing[key] = nil
            if m.speaker then relay(m.player, nil) end
        elseif m.speaker then
            local r = Noise.radius({ route = "speaker", volume = m.volume }, settings)
            local p = m.player
            if r >= 1 then addSound(p, math.floor(p:getX()), math.floor(p:getY()), math.floor(p:getZ()), r, r) end
        end
    end
end, 1000)

return World
