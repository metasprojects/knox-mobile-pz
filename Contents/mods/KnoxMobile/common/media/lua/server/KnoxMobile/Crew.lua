-- Server: find my crew and the SOS button (Core/Crew).
-- Find my crew: a phone that opted in (Settings) sees every group member whose phone also opted in, as a rough
-- direction and distance band worked out from each phone's tower or repeater. Needs service on both ends; the
-- sandbox option FindMyCrew turns it off.
-- SOS: one distress text with the rough location (nearest town, direction, band) to your groups and contacts, and to
-- strangers' phones within SosRange tiles when SosToStrangers is on. The phone then rings out loud: the server makes
-- the noise at once, and the client keeps ringing through the usual noise path. Cooldown: Core/Crew.SOS_COOLDOWN.
local Crew = require "KnoxMobile/Core/Crew"
local Groups = require "KnoxMobile/Core/Groups"
local Protocol = require "KnoxMobile/Core/Protocol"
local TowerSites = require "KnoxMobile/Data/TowerSites"
local Phones = require "KnoxMobile/Game/Phones"
local Util = require "KnoxMobile/Game/Util"
local Net = require "KnoxMobile/Game/Net"
local SocialText = require "KnoxMobile/Game/SocialText"
local State = require "KnoxMobile/State"
local Messaging = require "KnoxMobile/Messaging"
local Social = require "KnoxMobile/SocialData"
local GroupChats = require "KnoxMobile/GroupChats"

local CrewServer = {}

Protocol.register(Crew.validators)

-- Where the network puts this player's phone. The error holds still for an in-game hour.
local function estimate(player, number, via)
    local seed = tostring(State.get().seed) .. ":crew:" .. number .. ":" .. math.floor(Util.nowMinutes() / 60)
    return Crew.estimate(player:getX(), player:getY(), via, seed)
end

-- Numbers in every group this phone is in (manual and automatic), without its own.
local function groupNumbers(player, number)
    local out, seen = {}, { [number] = true }
    GroupChats.syncAuto(player)
    for _, g in ipairs(Groups.forMember(Social.data().groups, number, Util.playerKey(player))) do
        for _, n in ipairs(Groups.recipients(g, number, Social.numberOf)) do
            if not seen[n] then seen[n] = true; out[#out + 1] = n end
        end
    end
    return out
end

Net.onServer("crewShare", function(player, args)
    local item, state = Social.phone(player, args)
    if not item then return end
    state.crewShare = args.on == true or nil
    Phones.save(item, player)
end)

Net.onServer("crewFind", function(player, args)
    local function reply(extra)
        local out = { phoneId = args.phoneId }
        for k, v in pairs(extra) do out[k] = v end
        Net.toClient(player, "crewList", out)
    end
    if not Social.throttle(player, "crewFind", 1000) then return end
    if not Util.settings().FindMyCrew then return reply({ error = "off" }) end
    local item, state, model = Social.phone(player, args)
    if not item then return reply({ error = state }) end
    if not state.crewShare then return reply({ error = "notSharing" }) end
    local located = Messaging.service(player, model)
    if not located.network then return reply({ error = "noService" }) end
    local me = state.sim.number
    local ax, ay = estimate(player, me, located.via)
    local list = {}
    for _, n in ipairs(groupNumbers(player, me)) do
        local p, _, st, m = Messaging.findNumber(n)
        if p and p ~= player and st.crewShare and #list < Crew.MAX_LIST then
            local theirs = Messaging.service(p, m)
            if theirs.network then
                local bx, by = estimate(p, n, theirs.via)
                local dir, band = Crew.between(ax, ay, bx, by)
                list[#list + 1] = { number = n, dir = dir, band = band }
            end
        end
    end
    -- Phones a Project A-Life robber took from this player (server/KnoxMobile/StolenPhones.lua): who has it and which
    -- way, while that NPC is alive. Phones keep pinging the network, so they show like a crew member.
    if KnoxMobile.StolenPhones then
        for _, s in ipairs(KnoxMobile.StolenPhones.takenFrom(player)) do
            if s.x and s.y and #list < Crew.MAX_LIST then
                local dir, band = Crew.between(ax, ay, s.x, s.y)
                list[#list + 1] = { stolenBy = s.byName or "?", dir = dir, band = band }
            end
        end
    end
    reply({ list = list })
end)

-- Strangers' phones within range: online players' working phones, nearest players first.
local function nearbyNumbers(player, range)
    local px, py = player:getX(), player:getY()
    local found = {}
    for _, p in ipairs(Util.players()) do
        if p ~= player then
            local dx, dy = p:getX() - px, p:getY() - py
            local d = math.sqrt(dx * dx + dy * dy)
            if d <= range then
                for _, item in ipairs(Phones.inventoryPhones(p)) do
                    local st = Phones.get(item)
                    if Messaging.usable(st) then found[#found + 1] = { n = st.sim.number, d = d } end
                end
            end
        end
    end
    table.sort(found, function(a, b) return a.d < b.d end)
    local out = {}
    for i, f in ipairs(found) do out[i] = f.n end
    return out
end

Net.onServer("sos", function(player, args)
    local function reply(extra)
        local out = { phoneId = args.phoneId }
        for k, v in pairs(extra) do out[k] = v end
        Net.toClient(player, "sosResult", out)
    end
    -- An SOS works from the lock screen, like an emergency call.
    local item, state, model = Social.phone(player, args, true)
    if not item then return reply({ status = "failed", reason = state }) end
    local key, now = Util.playerKey(player), Util.nowMinutes()
    local data = Social.data()
    local ready, wait = Crew.sosReady(data.sos[key], now)
    if not ready then return reply({ status = "failed", reason = "tooSoon", wait = wait }) end
    local located, net = Messaging.service(player, model)
    if not located.network then return reply({ status = "failed", reason = "noService" }) end
    local me = state.sim.number
    local where = Crew.where(TowerSites.sites, estimate(player, me, located.via))
    local known = Social.knownNumbers()
    local contacts = {}
    for _, c in ipairs(state.sim.contacts or {}) do if known[c.number] then contacts[#contacts + 1] = c.number end end
    local settings = Util.settings()
    local nearby = {}
    if settings.SosToStrangers and settings.SosRange > 0 then nearby = nearbyNumbers(player, settings.SosRange) end
    local body = SocialText.sos(where)
    local counts = { delivered = 0, queued = 0, failed = 0 }
    for _, r in ipairs(Crew.sosRecipients(me, { groups = groupNumbers(player, me), contacts = contacts, nearby = nearby })) do
        local status = Messaging.route({ from = me, to = r.number, body = body, sos = where }, net)
        counts[status] = (counts[status] or 0) + 1
    end
    data.sos[key] = now
    -- The trade-off: the phone shrieks. Zombies hear this one whatever the client does.
    local radius = Crew.sosRadius(settings.NoiseMultiplier)
    if radius >= 1 then
        addSound(player, math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ()), radius, radius)
    end
    Util.log("SOS from", key, "near", tostring(where.town), where.dir or "", where.band or "", ":", counts.delivered,
        "delivered,", counts.queued, "queued")
    reply({ status = "sent", delivered = counts.delivered, queued = counts.queued, radius = radius })
end)

return CrewServer
