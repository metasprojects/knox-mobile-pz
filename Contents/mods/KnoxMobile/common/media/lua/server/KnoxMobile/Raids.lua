-- Server: raid warnings (0.3.0, Core/Raids has the words). With the Bandits mod running, every twenty seconds each
-- player's surroundings are checked for hostile bandits; a clan within reach gets a neighbor's warning text to a
-- player whose phone is on and has service (it arrives now or not at all). Sandbox: Stories > Raid warnings (on).
-- Saved in the world's global ModData: raids[player key] = { number, last = { clan id = world hour } }.
local Raids = require "KnoxMobile/Core/Raids"
local Bandits = require "KnoxMobile/Game/Bandits"
local CellSites = require "KnoxMobile/Core/CellSites"
local Story = require "KnoxMobile/Core/Story"
local Util = require "KnoxMobile/Game/Util"
local Tick = require "KnoxMobile/Game/Tick"
local Rng = require "KnoxMobile/Core/Rng"
local Sim = require "KnoxMobile/Core/Sim"
local State = require "KnoxMobile/State"
local Phones = require "KnoxMobile/Game/Phones"
local WorldModel = require "KnoxMobile/Game/WorldModel"
local Messaging = require "KnoxMobile/Messaging"

local Net = require "KnoxMobile/Game/Net"
local Protocol = require "KnoxMobile/Core/Protocol"

-- seen[player key] = { at, list }: on a server, what that player's client last saw (client/Sightings.lua): a
-- dedicated server keeps no zombie list of its own.
local World = { nextAt = 0, seen = {}, SEEN_MS = 60000 }
KnoxMobile.Raids = World

Protocol.register({
    hostilesSeen = function(args)
        if type(args.list) ~= "table" or #args.list > 60 then return false, "list must be a table of at most 60" end
        return true
    end,
})

Net.onServer("hostilesSeen", function(player, args)
    local px, py, list = player:getX(), player:getY(), {}
    for _, b in ipairs(args.list) do
        if type(b) == "table" and tonumber(b.x) and tonumber(b.y) and b.cid ~= nil
            and math.abs(b.x - px) <= Raids.RADIUS + 20 and math.abs(b.y - py) <= Raids.RADIUS + 20 then
            local clan = type(b.clan) == "string" and b.clan:sub(1, 40) or nil
            list[#list + 1] = { cid = tostring(b.cid):sub(1, 20), clan = clan, x = tonumber(b.x), y = tonumber(b.y) }
        end
    end
    World.seen[Util.playerKey(player)] = { at = getTimestampMs(), list = list }
end)

local function enabled()
    local sv = SandboxVars and SandboxVars.KnoxMobile
    return not (sv and sv.RaidWarnings == false)
end

-- A phone of this player's that is on, or nil.
local function phoneOn(player)
    for _, item in ipairs(Phones.inventoryPhones(player)) do
        local st, model = Phones.get(item)
        if st and st.power and st.power.on and st.sim then return item, st, model end
    end
    return nil
end

-- The hostile bandits in the loaded world: { { cid, x, y } }.
function World.hostiles()
    local out = {}
    local cell = getCell()
    local list = cell and cell:getZombieList()
    if not list then return out end
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        local info = Bandits.isBandit(z) and Bandits.info(z)
        if info and info.hostile then out[#out + 1] = { cid = info.cid, clan = info.clan, x = z:getX(), y = z:getY() } end
    end
    return out
end

-- The hostile bandits near a player: on a server, from that player's client (fresh for a minute); else the cell's.
function World.near(player)
    if isServer() then
        local s = World.seen[Util.playerKey(player)]
        if s and getTimestampMs() - s.at <= World.SEEN_MS then return s.list end
        return {}
    end
    return World.hostiles()
end

function World.check(player, hostiles, nowHour)
    local key = Util.playerKey(player)
    local mine = State.get().players[key]
    if not (mine and mine.number) then return 0 end
    local _, _, model = phoneOn(player)
    if not model then return 0 end
    local located = WorldModel.locatePlayer(player, model, player:getModData().KnoxMobilePasswords or {})
    if not (located and located.network) then return 0 end
    local md = State.get()
    if type(md.raids) ~= "table" then md.raids = {} end
    local mineR = md.raids[key]
    if type(mineR) ~= "table" then
        mineR = { number = Sim.issueNumber(md.numbers, Rng.new(tostring(md.seed) .. ":raid:" .. key)), last = {} }
        md.raids[key] = mineR
    end
    local sent = 0
    local px, py = player:getX(), player:getY()
    for cid, g in pairs(Raids.groups(hostiles, px, py)) do
        if Raids.ready(mineR.last[cid], nowHour) then
            mineR.last[cid] = nowHour
            local rng = Rng.new(tostring(md.seed) .. ":raid:" .. key .. ":" .. cid .. ":" .. nowHour)
            local dir = Raids.DIRS[CellSites.compass(px, py, g.x, g.y)] or "north"
            local body = Story.fill(rng, rng:pick(Raids.LINES), { dir = dir, n = Raids.countWord(g.n) })
            Messaging.queueStory(mineR.number, mine.number, body, Util.nowMinutes())
            Util.log("raid warning for", key, ":", g.n, "of clan", cid, dir)
            sent = sent + 1
        end
    end
    return sent
end

Tick.add("raids", function()
    if isClient() or not enabled() or not Bandits.active() then return end
    local t = getTimestampMs()
    if t < World.nextAt then return end
    World.nextAt = t + 20000
    local nowHour = math.floor(Util.nowMinutes() / 60)
    local cell = not isServer() and World.hostiles() or nil
    for _, player in ipairs(Util.players()) do
        local hostiles = cell or World.near(player)
        if #hostiles > 0 and not player:isDead() then World.check(player, hostiles, nowHour) end
    end
end, 1000)

return World
