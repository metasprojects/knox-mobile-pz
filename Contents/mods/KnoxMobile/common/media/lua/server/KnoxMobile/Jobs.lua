-- Server: Jobs by text (0.3.0, Core/Jobs has the words). Once the outbreak is a day old, now and then a survivor texts
-- a player a request (sandbox Stories > Jobs by text). The Jobs app accepts or declines; a delivery is handed over at
-- the place from the app, a look-in completes by getting there. In time: a thank-you and, mostly, a stash at another
-- real place (Quests.lua sets it when its chunk loads). Late: they say never mind. Saved in the world's global ModData:
-- jobs[player key] = { nextId, list = { job } }, job = Core/Jobs.make's table plus id, state ("offered", "active",
-- "done", "expired", "declined", "lapsed"), number (the giver's), at (offered, world minutes), deadline.
local Jobs = require "KnoxMobile/Core/Jobs"
local Quests = require "KnoxMobile/Core/Quests"
local Util = require "KnoxMobile/Game/Util"
local Tick = require "KnoxMobile/Game/Tick"
local Rng = require "KnoxMobile/Core/Rng"
local Sim = require "KnoxMobile/Core/Sim"
local Net = require "KnoxMobile/Game/Net"
local State = require "KnoxMobile/State"
local Messaging = require "KnoxMobile/Messaging"
local QuestsWorld = require "KnoxMobile/Quests"

local World = { nextAt = 0, lastHour = {} }
KnoxMobile.JobsWorld = World

World.CHANCE_PER_HOUR = 0.05 -- about one offer a day while there's room for one

local function enabled()
    local sv = SandboxVars and SandboxVars.KnoxMobile
    return not (sv and sv.JobOffers == false)
end

local function book(key)
    local md = State.get()
    if type(md.jobs) ~= "table" then md.jobs = {} end
    local b = md.jobs[key]
    if type(b) ~= "table" then b = { nextId = 1, list = {} }; md.jobs[key] = b end
    return b
end

local function open(b)
    local n = 0
    for _, j in ipairs(b.list) do if j.state == "offered" or j.state == "active" then n = n + 1 end end
    return n
end

-- What the Jobs app shows: open jobs and the last few finished ones.
function World.publicList(key)
    local out = {}
    for _, j in ipairs(book(key).list) do
        if j.state == "offered" or j.state == "active" or j.state == "done" or j.state == "expired" then
            out[#out + 1] = { id = j.id, kind = j.kind, need = j.need, state = j.state, giver = j.giver,
                offer = j.offer, deadline = j.deadline, place = { name = j.place.name, x = j.place.x, y = j.place.y } }
        end
    end
    return out
end

function World.send(player)
    if player then Net.toClient(player, "jobs", { list = World.publicList(Util.playerKey(player)), now = Util.nowMinutes() }) end
end

local function usedSites(key)
    local used = {}
    for _, j in ipairs(book(key).list) do used[j.place.site] = true end
    for _, q in pairs(State.get().quests) do used[q.site] = true end
    return used
end

-- A new offer for this player now (also the debug menu's way to get one). kind (optional): "deliver" or "check".
-- spec (optional, the dispatcher's own jobs: server/Dispatch.lua): a ready job table (kind, need, types, place, giver,
-- offer, days, number, arc, beat); it ignores the open-jobs limit. Returns the job or nil.
function World.offer(player, rng, kind, spec)
    local key = Util.playerKey(player)
    local mine = State.get().players[key]
    if not (mine and mine.number) then return nil end
    local b = book(key)
    if not spec and open(b) >= Jobs.MAX_OPEN then return nil end
    local job = spec or Jobs.make(rng, usedSites(key), kind)
    if not job then return nil end
    job.id, job.state, job.at = b.nextId, "offered", Util.nowMinutes()
    job.number = job.number or Sim.issueNumber(State.get().numbers, rng)
    b.nextId = b.nextId + 1
    b.list[#b.list + 1] = job
    Messaging.queueStory(job.number, mine.number, job.offer, Util.nowMinutes() + rng:int(1, 30))
    Util.log("job offer for", key, ":", job.kind, job.need or "", "at", job.place.name)
    World.send(player)
    return job
end

local function find(player, id)
    for _, j in ipairs(book(Util.playerKey(player)).list) do
        if j.id == tonumber(id) then return j end
    end
    return nil
end

local function say(player, job, body, delay)
    local mine = State.get().players[Util.playerKey(player)]
    if mine and mine.number then Messaging.queueStory(job.number, mine.number, body, Util.nowMinutes() + (delay or 1)) end
end

-- An arc's job (the dispatcher) hears how it ended: "done", or "failed" (declined, lapsed or too late).
local function toArc(player, job, how)
    if job.arc == "dispatch" and KnoxMobile.Dispatch then KnoxMobile.Dispatch.jobEnded(player, job, how) end
end

-- Done: the thank-you, then (mostly) a stash at another real place, or nothing more. The dispatcher's jobs answer
-- through her own story instead.
function World.complete(player, job, rng)
    job.state = "done"
    if job.arc then
        toArc(player, job, "done")
        World.send(player)
        return
    end
    say(player, job, Jobs.doneText(rng, job), 2)
    local how = Jobs.reward(rng)
    job.reward = how
    if how == "stash" then
        local key = Util.playerKey(player)
        local list = Quests.make(rng, 1, { startDay = Util.nowDay(), endDay = Util.nowDay(), trapChance = 0,
            used = usedSites(key) })
        if list[1] then
            QuestsWorld.add(key, list)
            QuestsWorld.arm(list[1].questId)
            say(player, job, Jobs.rewardText(rng, list[1].place.name), rng:int(10, 40))
        end
    end
    Util.log("job done for", Util.playerKey(player), ":", job.kind, "reward", how)
    World.send(player)
end

local Protocol = require "KnoxMobile/Core/Protocol"
local function jobId(args)
    if type(args.id) ~= "number" or args.id < 1 or args.id ~= math.floor(args.id) then return false, "id must be a job number" end
    return true
end
Protocol.register({ jobAccept = jobId, jobDecline = jobId, jobHandOver = jobId })

Net.onServer("jobs", function(player) World.send(player) end)

Net.onServer("jobAccept", function(player, args)
    local job = find(player, args and args.id)
    if not job or job.state ~= "offered" then return end
    job.state = "active"
    job.deadline = Util.nowMinutes() + job.days * 1440
    World.send(player)
end)

Net.onServer("jobDecline", function(player, args)
    local job = find(player, args and args.id)
    if job and job.state == "offered" then job.state = "declined"; toArc(player, job, "failed"); World.send(player) end
end)

-- A delivery, handed over at the place from the Jobs app: one matching item leaves the player's inventory.
Net.onServer("jobHandOver", function(player, args)
    local job = find(player, args and args.id)
    if not job or job.state ~= "active" or job.kind ~= "deliver" then return end
    if not Jobs.near(job, player:getX(), player:getY()) then
        Net.toClient(player, "jobResult", { id = job.id, error = "far" })
        return
    end
    local inv = player:getInventory()
    local item = nil
    for _, t in ipairs(job.types or {}) do
        item = inv:getFirstTypeRecurse(t)
        if item then break end
    end
    if not item then
        Net.toClient(player, "jobResult", { id = job.id, error = "missing" })
        return
    end
    local from = item:getContainer() or inv
    from:Remove(item)
    if isServer() then sendRemoveItemFromContainer(from, item) end
    World.complete(player, job, Rng.new(tostring(State.get().seed) .. ":job:" .. Util.playerKey(player) .. ":" .. job.id))
    Net.toClient(player, "jobResult", { id = job.id, done = true })
end)

-- Every few seconds: arrivals for look-ins, deadlines, lapsed offers. Every game hour: maybe a new offer.
local function step(player, key, now, hour, offers)
    local b = book(key)
    local changed = false
    for _, job in ipairs(b.list) do
        if job.state == "active" and job.kind == "check" and Jobs.near(job, player:getX(), player:getY()) then
            World.complete(player, job, Rng.new(tostring(State.get().seed) .. ":job:" .. key .. ":" .. job.id))
        elseif job.state == "active" and job.deadline and now > job.deadline then
            job.state = "expired"
            if job.arc then toArc(player, job, "failed")
            else say(player, job, Jobs.expiredText(Rng.new(tostring(job.number) .. ":late")), 1) end
            changed = true
        elseif job.state == "offered" and now > job.at + Jobs.OFFER_DAYS * 1440 then
            job.state = "lapsed"
            toArc(player, job, "failed")
            changed = true
        end
    end
    if changed then World.send(player) end
    local last = World.lastHour[key]
    World.lastHour[key] = hour
    if offers and last and last ~= hour and Util.sinceOutbreak() >= 1 then
        local rng = Rng.new(tostring(State.get().seed) .. ":joboffer:" .. key .. ":" .. hour)
        if rng:chance(World.CHANCE_PER_HOUR) then World.offer(player, rng) end
    end
end

-- Jobs already taken keep running (deadlines, arrivals) even with new offers switched off: the dispatcher's jobs go
-- through here too.
Tick.add("jobs", function()
    if isClient() then return end
    local t = getTimestampMs()
    if t < World.nextAt then return end
    World.nextAt = t + 5000
    local now = Util.nowMinutes()
    local hour = math.floor(now / 60)
    for _, player in ipairs(Util.players()) do
        if not player:isDead() then step(player, Util.playerKey(player), now, hour, enabled()) end
    end
end, 1000)

return World
