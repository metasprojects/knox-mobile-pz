-- Server: the Knox Sentry motion alarm (0.3.0, Core/Sentry has the rules and the words). Saved in the world's global
-- ModData: sentries = { { id, name, x, y, z, owner, to, number, passwords, placedAt, days, armed, last, lowSent } }.
-- Who moves near a unit: other players from the server's own list; the dead from the cell's zombie list in single
-- player, and on a server (which keeps no zombie list) from the clients near the unit ("sentrySeen",
-- client/KnoxMobile/Sightings.lua), which the server tells where the units are ("sentriesNear").
local Sentry = require "KnoxMobile/Core/Sentry"
local Story = require "KnoxMobile/Core/Story"
local Sim = require "KnoxMobile/Core/Sim"
local Rng = require "KnoxMobile/Core/Rng"
local Net = require "KnoxMobile/Game/Net"
local Util = require "KnoxMobile/Game/Util"
local Tick = require "KnoxMobile/Game/Tick"
local State = require "KnoxMobile/State"
local Phones = require "KnoxMobile/Game/Phones"
local Protocol = require "KnoxMobile/Core/Protocol"
local WorldModel = require "KnoxMobile/Game/WorldModel"
local Messaging = require "KnoxMobile/Messaging"
local Bandits = require "KnoxMobile/Game/Bandits"

local World = { nextAt = 0, presenceAt = 0, reports = {}, sentNear = {} }
KnoxMobile.SentryWorld = World

Protocol.register({
    sentrySeen = function(args)
        if type(args.id) ~= "string" or #args.id > 12 then return false, "id must be a short string" end
        if type(args.n) ~= "number" or args.n < 0 or args.n > 200 then return false, "n must be 0..200" end
        if args.p ~= nil and (type(args.p) ~= "number" or args.p < 0 or args.p > 200) then return false, "p must be 0..200" end
        return true
    end,
    sentrySet = function(args)
        if type(args.id) ~= "string" or #args.id > 12 then return false, "id must be a short string" end
        return type(args.armed) == "boolean", "armed must be a boolean"
    end,
})

local function units()
    local md = State.get()
    if type(md.sentries) ~= "table" then md.sentries = {} end
    return md.sentries
end
World.units = units

function World.byId(id)
    for _, u in ipairs(units()) do if u.id == id then return u end end
    return nil
end

function World.byNumber(number)
    for _, u in ipairs(units()) do if u.number == number then return u end end
    return nil
end

-- The number a new unit texts: the owner's phone that is on with a SIM, else their own first number.
local function ownerNumber(player)
    for _, item in ipairs(Phones.inventoryPhones(player)) do
        local st = Phones.get(item)
        if st and st.power and st.power.on and st.sim and st.sim.number then return st.sim.number end
    end
    local mine = State.get().players[Util.playerKey(player)]
    return mine and mine.number or nil
end

local function copyPasswords(player)
    local out = {}
    for k, v in pairs(player:getModData().KnoxMobilePasswords or {}) do if v then out[k] = true end end
    return out
end

local function send(unit, body)
    if not unit.to then return end
    Messaging.queueStory(unit.number, unit.to, body, Util.nowMinutes())
end

local function fill(unit, template, slots)
    local md = State.get()
    local rng = Rng.new(tostring(md.seed) .. ":sentry:" .. unit.id .. ":" .. math.floor(Util.nowMinutes()))
    slots = slots or {}
    slots.name = unit.name
    return Story.fill(rng, rng:pick(type(template) == "table" and template or { template }), slots)
end

-- Set down by the placeSentry action (shared code, on the server). days: the battery's charge in days.
function World.place(player, square, days)
    local md = State.get()
    md.nextSentry = (tonumber(md.nextSentry) or 1)
    local n = md.nextSentry
    md.nextSentry = n + 1
    local unit = { id = "S" .. n, name = tostring(n), x = square:getX(), y = square:getY(), z = square:getZ(),
        owner = Util.playerKey(player), to = ownerNumber(player),
        number = Sim.issueNumber(md.numbers, Rng.new(tostring(md.seed) .. ":sentry:" .. n)),
        passwords = copyPasswords(player), placedAt = Util.nowMinutes(), days = days, armed = true }
    local list = units()
    list[#list + 1] = unit
    Util.log("sentry", unit.id, "placed at", unit.x, unit.y, unit.z, "texts", tostring(unit.to), "battery", days, "days")
    send(unit, fill(unit, Sentry.ARMED))
    return unit
end

-- Does the unit have a tower where it stands (indoors; the owner's repeater passwords from when it was set)?
function World.covered(unit)
    local located = WorldModel.locate(unit.x, unit.y, 1, true, unit.passwords or {}, Util.settings())
    return located ~= nil and located.network ~= nil
end

-- One motion text, if the unit may send one now. Returns true when sent.
function World.trip(unit, what, n)
    local now = Util.nowMinutes()
    if not what or not Sentry.ready(unit, now) or not World.covered(unit) then return false end
    unit.last = now
    local lines = what == "person" and Sentry.PERSON or Sentry.ZOMBIE
    send(unit, fill(unit, lines, { time = Sentry.clock(now), n = tostring(n or 1) }))
    Util.log("sentry", unit.id, "tripped by", what, n or 1)
    return true
end

-- What the server can see in the cell (single player): the dead { {x,y,z} }, and Bandits NPCs (people) apart.
local function cellZombies()
    local dead, npcs = {}, {}
    local list = getCell() and getCell():getZombieList()
    for i = 0, (list and list:size() or 0) - 1 do
        local z = list:get(i)
        if not z:isDead() then
            local into = Bandits.isBandit(z) and npcs or dead
            into[#into + 1] = { x = z:getX(), y = z:getY(), z = z:getZ() }
        end
    end
    return dead, npcs
end

local function peopleFor(unit, npcs)
    local out = {}
    for _, n in ipairs(npcs or {}) do out[#out + 1] = n end
    for _, p in ipairs(Util.players()) do
        if not p:isDead() and Util.playerKey(p) ~= unit.owner then
            out[#out + 1] = { x = p:getX(), y = p:getY(), z = p:getZ() }
        end
    end
    return out
end

local function stillThere(sq, id)
    local objects = sq:getWorldObjects()
    for i = 0, objects:size() - 1 do
        local item = objects:get(i).getItem and objects:get(i):getItem()
        if item and item:getFullType() == "KnoxMobile.SentryAlarm" and item:getModData().KnoxMobileSentryId == id then
            return true
        end
    end
    return false
end

-- Units whose square is loaded and empty were picked up (or burned): they stop.
function World.checkPresence()
    local keep = {}
    for _, u in ipairs(units()) do
        local sq = getCell() and getCell():getGridSquare(u.x, u.y, u.z)
        if sq and not stillThere(sq, u.id) then
            Util.log("sentry", u.id, "is gone")
        else
            keep[#keep + 1] = u
        end
    end
    State.get().sentries = keep
end

-- Every five seconds: what each unit sees, the low battery text, and (on a server) which units each client watches.
function World.step()
    local now = Util.nowMinutes()
    local zombies, npcs
    if not isServer() then zombies, npcs = cellZombies() end
    for _, u in ipairs(units()) do
        if Sentry.daysLeft(u, now) <= Sentry.LOW_DAYS and Sentry.daysLeft(u, now) > 0 and not u.lowSent and u.armed ~= false then
            u.lowSent = true
            send(u, fill(u, Sentry.LOW))
        end
        local what, n = Sentry.what(u, zombies, peopleFor(u, npcs))
        if not what and isServer() then
            local r = World.reports[u.id]
            if r and getTimestampMs() - r.at <= 15000 then
                if r.p > 0 then what, n = "person", r.p elseif r.n > 0 then what, n = "zombie", r.n end
            end
        end
        if what and World.trip(u, what, n) then World.reports[u.id] = nil end
    end
    if isServer() then
        for _, p in ipairs(Util.players()) do
            local near, ids = {}, {}
            for _, u in ipairs(units()) do
                if u.armed ~= false and Sentry.watches(u, p:getX(), p:getY()) then
                    near[#near + 1] = { id = u.id, x = u.x, y = u.y, z = u.z }
                    ids[#ids + 1] = u.id
                end
            end
            -- Sent when it changes, and once a minute anyway (a client that rejoined has none).
            local key, sig, t = Util.playerKey(p), table.concat(ids, ","), getTimestampMs()
            local last = World.sentNear[key]
            if not last or last.sig ~= sig or t - last.at >= 60000 then
                World.sentNear[key] = { sig = sig, at = t }
                Net.toClient(p, "sentriesNear", { list = near })
            end
        end
    end
end

Net.onServer("sentrySeen", function(player, args)
    local u = World.byId(args.id)
    if not u or not Sentry.watches(u, player:getX(), player:getY()) then return end
    World.reports[u.id] = { n = math.floor(args.n), p = math.floor(args.p or 0), at = getTimestampMs() }
end)

local function status(u)
    return fill(u, Sentry.STATUS, { state = Sentry.STATES[u.armed == false and "off" or "armed"],
        days = tostring(math.floor(Sentry.daysLeft(u, Util.nowMinutes()))) })
end

local function setArmed(u, armed)
    u.armed = armed
    if armed then u.last = nil end
end

-- The owner's menu on the unit itself.
Net.onServer("sentrySet", function(player, args)
    local u = World.byId(args.id)
    if not u or u.owner ~= Util.playerKey(player) then return end
    if math.abs(player:getX() - u.x) > 3 or math.abs(player:getY() - u.y) > 3 then return end
    setArmed(u, args.armed)
    Net.toClient(player, "notify", { kind = "sentry", event = args.armed and "on" or "off", source = u.name })
end)

-- A text to a unit's number (Messaging.textHooks): the owner's STATUS, OFF or ON is answered; anyone else's is
-- delivered and ignored. Returns true when the number is a unit's.
function World.onText(player, item, state, to, body)
    local u = World.byNumber(to)
    if not u then return false end
    Messaging.appendOwn(player, item, state, to, body, "delivered")
    if u.owner ~= Util.playerKey(player) or Sentry.daysLeft(u, Util.nowMinutes()) <= 0 then return true end
    local cmd = Sentry.command(body)
    if cmd == "off" then setArmed(u, false) elseif cmd == "on" then setArmed(u, true) end
    local reply = cmd == "help" and fill(u, Sentry.HELP) or status(u)
    Messaging.queueStory(u.number, state.sim.number, reply, Util.nowMinutes() + 1)
    return true
end
Messaging.textHooks[#Messaging.textHooks + 1] = World.onText

-- The owner's units, for the Map (Server.lua mapPlaces).
function World.placesFor(player)
    local out, key = {}, Util.playerKey(player)
    for _, u in ipairs(units()) do
        if u.owner == key then out[#out + 1] = { kind = "sentry", name = u.name, x = u.x, y = u.y } end
    end
    return out
end

Tick.add("sentries", function()
    if isClient() then return end
    local t = getTimestampMs()
    if t < World.nextAt then return end
    World.nextAt = t + 5000
    if #units() == 0 then return end
    if t >= World.presenceAt then
        World.presenceAt = t + 60000
        World.checkPresence()
    end
    World.step()
end, 1000)

return World
