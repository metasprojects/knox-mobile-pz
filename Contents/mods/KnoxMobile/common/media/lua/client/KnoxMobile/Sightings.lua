-- Client (on a server only): what this client sees that the server can't. A dedicated server keeps no zombie list,
-- so the client near a Knox Sentry counts the dead the unit sees ("sentrySeen", server/Sentry.lua), and a client
-- with the Bandits mod running says which hostile bandits are near its player ("hostilesSeen", server/Raids.lua:
-- raid warnings and the Scanner's clan chatter). In single player the server side reads the cell itself.
local Net = require "KnoxMobile/Game/Net"
local Tick = require "KnoxMobile/Game/Tick"
local Sentry = require "KnoxMobile/Core/Sentry"
local Raids = require "KnoxMobile/Core/Raids"
local Bandits = require "KnoxMobile/Game/Bandits"

local Sightings = { sentries = {}, nextAt = 0, banditsAt = 0, MAX_BANDITS = 40 }
KnoxMobile.Sightings = Sightings

Net.onClient("sentriesNear", function(args)
    Sightings.sentries = type(args.list) == "table" and args.list or {}
end)

local function me() return getSpecificPlayer(0) end

-- What each nearby unit sees: { [id] = { n = the dead, p = people (Bandits NPCs) } }; units seeing nothing are left out.
function Sightings.countSentries(list, zombies)
    local out = {}
    for i = 0, (zombies and zombies:size() or 0) - 1 do
        local z = zombies:get(i)
        if not z:isDead() then
            local field = Bandits.isBandit(z) and "p" or "n"
            for _, u in ipairs(list) do
                if Sentry.sees(u, z:getX(), z:getY(), z:getZ()) then
                    out[u.id] = out[u.id] or { n = 0, p = 0 }
                    out[u.id][field] = out[u.id][field] + 1
                end
            end
        end
    end
    return out
end

-- Hostile bandits within raid reach of (px, py): { { cid, clan, x, y } }, at most MAX_BANDITS.
function Sightings.hostiles(zombies, px, py)
    local out = {}
    for i = 0, (zombies and zombies:size() or 0) - 1 do
        local z = zombies:get(i)
        local info = Bandits.isBandit(z) and Bandits.info(z)
        if info and info.hostile and info.cid and math.abs(z:getX() - px) <= Raids.RADIUS
            and math.abs(z:getY() - py) <= Raids.RADIUS then
            out[#out + 1] = { cid = info.cid, clan = info.clan, x = math.floor(z:getX()), y = math.floor(z:getY()) }
            if #out >= Sightings.MAX_BANDITS then break end
        end
    end
    return out
end

Tick.add("sightings", function()
    if not isClient() then return end
    local t = getTimestampMs()
    if t < Sightings.nextAt then return end
    Sightings.nextAt = t + 5000
    local p = me()
    local zombies = p and getCell() and getCell():getZombieList()
    if not zombies then return end
    if #Sightings.sentries > 0 then
        for id, seen in pairs(Sightings.countSentries(Sightings.sentries, zombies)) do
            Net.toServer(p, "sentrySeen", { id = id, n = seen.n, p = seen.p })
        end
    end
    if Bandits.active() and t >= Sightings.banditsAt then
        Sightings.banditsAt = t + 15000
        local list = Sightings.hostiles(zombies, p:getX(), p:getY())
        if #list > 0 then Net.toServer(p, "hostilesSeen", { list = list }) end
    end
end, 1000)

return Sightings
