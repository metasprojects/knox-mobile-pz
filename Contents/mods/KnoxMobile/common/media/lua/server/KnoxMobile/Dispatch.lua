-- Server: the dispatcher (0.3.0, Core/Dispatch has the beats and her words). Each player with a number hears from Dee
-- on her schedule, counted from the outbreak; her jobs go through server/Jobs.lua with her as the giver. Whether the
-- food run (the beat marked key) is done in time decides her ending. Sandbox: Stories > The dispatcher (on).
-- Saved in the world's global ModData: dispatch[player key] = { number, sent = { beat id = true }, helped, ended }.
local Dispatch = require "KnoxMobile/Core/Dispatch"
local Jobs = require "KnoxMobile/Core/Jobs"
local Quests = require "KnoxMobile/Core/Quests"
local Story = require "KnoxMobile/Core/Story"
local Sites = require "KnoxMobile/Story/Sites"
local Util = require "KnoxMobile/Game/Util"
local Tick = require "KnoxMobile/Game/Tick"
local Rng = require "KnoxMobile/Core/Rng"
local Sim = require "KnoxMobile/Core/Sim"
local State = require "KnoxMobile/State"
local Messaging = require "KnoxMobile/Messaging"
local QuestsWorld = require "KnoxMobile/Quests"

local World = { nextAt = 0 }
KnoxMobile.Dispatch = World

local function enabled()
    local sv = SandboxVars and SandboxVars.KnoxMobile
    return not (sv and sv.Dispatcher == false)
end

local function siteById(list, id)
    for _, s in ipairs(list) do if s.id == id then return s end end
    return nil
end

local function stateOf(key)
    local md = State.get()
    if type(md.dispatch) ~= "table" then md.dispatch = {} end
    local s = md.dispatch[key]
    if type(s) ~= "table" then
        -- Her number: one more number on the network, the same for this whole world.
        if not md.dispatchNumber then md.dispatchNumber = Sim.issueNumber(md.numbers, Rng.new(tostring(md.seed) .. ":dee")) end
        s = { number = md.dispatchNumber, sent = {} }
        md.dispatch[key] = s
    end
    return s
end

-- A place for one of her jobs: the station, or a house, church or school nobody else sent this player to.
local function placeFor(rng, key, site)
    if site == "station" then return siteById(Sites.quests, Dispatch.STATION) end
    local used = {}
    local md = State.get()
    local b = type(md.jobs) == "table" and md.jobs[key]
    for _, j in ipairs(b and b.list or {}) do used[j.place.site] = true end
    local pool = {}
    for _, s in ipairs(Sites.family) do if not used[s.id] then pool[#pool + 1] = s end end
    if #pool == 0 then return nil end
    return pool[rng:int(1, #pool)]
end

local function needTypes(id)
    for _, n in ipairs(Jobs.NEEDS) do if n.id == id then return n.types end end
    return nil
end

-- The evidence-room bag: a police station's stash (Core/Quests), never a trap.
local function evidenceBag(player, rng)
    local key = Util.playerKey(player)
    local used = {}
    for _, s in ipairs(Sites.quests) do if s.kind ~= "police" or s.id == Dispatch.STATION then used[s.id] = true end end
    for _, q in pairs(State.get().quests) do used[q.site] = true end
    local list = Quests.make(rng, 1, { startDay = Util.nowDay(), endDay = Util.nowDay(), trapChance = 0, used = used })
    if not list[1] then return nil end
    QuestsWorld.add(key, list)
    QuestsWorld.arm(list[1].questId)
    return list[1].place.name
end

-- The station itself, when no police bag is left to give.
local function fallbackPlace()
    local s = siteById(Sites.quests, Dispatch.STATION)
    return s and s.name or ""
end

-- Send one beat to one player now.
function World.send(player, s, beat, rng)
    local key = Util.playerKey(player)
    local mine = State.get().players[key]
    if not (mine and mine.number) then return false end
    s.sent[beat.id] = true
    if beat.kind == "job" then
        local site = placeFor(rng, key, beat.job.site)
        if not site then return false end
        local spec = { kind = beat.job.kind, need = beat.job.need, types = beat.job.need and needTypes(beat.job.need) or nil,
            giver = Dispatch.NAME, days = beat.job.days, number = s.number, arc = "dispatch", beat = beat.id,
            place = { site = site.id, name = site.name, town = site.town, x = site.x, y = site.y },
            offer = Story.fill(rng, beat.body, { place = site.name }) }
        KnoxMobile.JobsWorld.offer(player, rng, nil, spec)
    else
        local place = beat.reward and evidenceBag(player, rng) or nil
        local body = Story.fill(rng, beat.body, { place = place or fallbackPlace() })
        Messaging.queueStory(s.number, mine.number, body, Util.nowMinutes() + rng:int(1, 20))
    end
    if beat["end"] then s.ended = true end
    Util.log("dispatch:", beat.id, "for", key)
    return true
end

-- server/Jobs.lua reports how her jobs ended. The food run (key) decides the ending.
function World.jobEnded(player, job, how)
    local beat = Dispatch.beat(job.beat)
    local s = stateOf(Util.playerKey(player))
    if beat and beat.job and beat.job.key then s.helped = (how == "done") end
    local mine = State.get().players[Util.playerKey(player)]
    if how == "done" and mine and mine.number then
        Messaging.queueStory(s.number, mine.number, Story.fill(Rng.new(tostring(job.number) .. ":" .. tostring(job.beat)),
            Dispatch.ACK, {}), Util.nowMinutes() + 2)
    end
end

function World.step(player)
    local key = Util.playerKey(player)
    local s = stateOf(key)
    local hours = Util.sinceOutbreak() * 24
    local plan = Dispatch.due(s, hours)
    for _, b in ipairs(plan.skipped) do s.sent[b.id] = true end
    for _, b in ipairs(plan.due) do
        World.send(player, s, b, Rng.new(tostring(State.get().seed) .. ":dee:" .. key .. ":" .. b.id))
        if s.ended then break end
    end
end

Tick.add("dispatch", function()
    if isClient() or not enabled() then return end
    local t = getTimestampMs()
    if t < World.nextAt then return end
    World.nextAt = t + 10000
    for _, player in ipairs(Util.players()) do
        if not player:isDead() then World.step(player) end
    end
end, 1000)

return World
