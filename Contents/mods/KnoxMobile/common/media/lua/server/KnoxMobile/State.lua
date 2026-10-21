-- The server's world data (spec §13.1, §13.4), saved in global ModData "KnoxMobileWorld":
-- world seed, phone-number registry, message queue, repeaters, family storylines.
local Sim = require "KnoxMobile/Core/Sim"
local MessageQueue = require "KnoxMobile/Core/MessageQueue"
local Calls = require "KnoxMobile/Core/Calls"
local Repeaters = require "KnoxMobile/Core/Repeaters"
local CellSites = require "KnoxMobile/Core/CellSites"

local State = {}
State.KEY = "KnoxMobileWorld"
State.calls = Calls.new() -- live calls are not saved

function State.get()
    local md = ModData.getOrCreate(State.KEY)
    if not md.seed then md.seed = ZombRand(1, 1000000000) end
    if type(md.numbers) ~= "table" then md.numbers = Sim.newRegistry() end
    if type(md.queue) ~= "table" then md.queue = MessageQueue.new() end
    if type(md.repeaters) ~= "table" then md.repeaters = {} end
    md.nextRepeater = md.nextRepeater or 1
    if type(md.story) ~= "table" then md.story = {} end      -- number -> { messages, next, family, hometown, hunt }
    if type(md.huntTaken) ~= "table" then md.huntTaken = {} end -- family hunt site id -> player key (Core/Hunt)
    if type(md.quests) ~= "table" then md.quests = {} end       -- "<player key>|<site id>" -> survivor stash (Quests.lua)
    if type(md.players) ~= "table" then md.players = {} end  -- playerKey -> { number, identity }
    if type(md.started) ~= "table" then md.started = {} end
    -- Phones left charging in the world: item id -> { x, y, z, last }.
    if type(md.worldChargers) ~= "table" then md.worldChargers = {} end  -- "account:character name" -> true
    md.storyShift = md.storyShift or 0
    if type(md.sites) ~= "table" then md.sites = {} end  -- tower site id -> generator hookup (Core/CellSites)
    KnoxMobile.world.seed = md.seed
    KnoxMobile.world.repeaters = md.repeaters
    KnoxMobile.world.debugTowers = md.debugTowers
    KnoxMobile.world.storyShift = md.storyShift
    KnoxMobile.world.sites = md.sites
    return md
end

-- Server voice chat (spec §9.7): calls need it. Single player has no VOIP but calls never happen there anyway.
function State.voiceEnabled()
    if not isServer() then return true end
    local ok, on = pcall(function() return getServerOptions():getBoolean("VoiceEnable") end)
    return not ok or on == true
end

-- What clients need to draw the network: sent on join and whenever repeaters or debug overrides change.
function State.worldMessage()
    local md = State.get()
    local reps = {}
    for i, rep in ipairs(md.repeaters) do reps[i] = Repeaters.publicCopy(rep) end -- no passwords to clients
    return { seed = md.seed, repeaters = reps, debugTowers = md.debugTowers, storyShift = md.storyShift,
        voice = State.voiceEnabled(), sites = CellSites.publicCopy(md.sites) }
end

return State
