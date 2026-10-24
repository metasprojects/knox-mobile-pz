-- Server: ringing in the dark (0.2.0). In the first two weeks families keep calling, and some of the dead still carry
-- their phones: now and then one rings in a zombie's pocket somewhere near you, a few rings and then quiet. Follow it:
-- the dead it draws are around there, and the one you kill there has that phone, with the missed calls on it.
-- Multiplayer: the zombie is picked from the server's own list when it has one; a dedicated server may not keep one,
-- so then the player's client picks a zombie it can see near it and reports where it rang (Client "ringPick"). Either
-- way the server keeps where it rang: a zombie killed near there in the next hours carries the phone (Server's
-- OnZombieDead asks Ringing.claim). Everyone close enough hears the rings.
local Util = require "KnoxMobile/Game/Util"
local Net = require "KnoxMobile/Game/Net"
local Tick = require "KnoxMobile/Game/Tick"
local Rng = require "KnoxMobile/Core/Rng"
local Protocol = require "KnoxMobile/Core/Protocol"
local ALife = require "KnoxMobile/Game/ALife"

local Ringing = { nextAt = 0, CHECK_MS = 60000, NEAR = 6, FAR = 35, HEAR = 45, CLAIM = 14, KEEP_MINUTES = 360,
    recent = {}, asked = {} }
KnoxMobile.Ringing = Ringing

-- Chance a minute (real) that one rings near a player, by game day; none after two weeks.
function Ringing.chance(day)
    if day < 3 then return 0.2 elseif day < 7 then return 0.12 elseif day < 14 then return 0.06 end
    return 0
end

local function fit(z, px, py)
    local d = math.max(math.abs(z:getX() - px), math.abs(z:getY() - py))
    return d >= Ringing.NEAR and d <= Ringing.FAR and not z:isDead() and not ALife.isNPC(z)
        and z:getModData().KnoxMobileFamily == nil
end

-- A zombie between NEAR and FAR tiles from the player that isn't an A-Life NPC or a family member, from the cell's
-- list (the server's, or a client's): or nil.
function Ringing.pick(player, rng)
    local list = getCell() and getCell():getZombieList()
    if not list then return nil end
    local px, py = player:getX(), player:getY()
    local found = {}
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if fit(z, px, py) then found[#found + 1] = z end
    end
    return #found > 0 and rng:pick(found) or nil
end

-- It rang at x, y, z: the dead hear it, everyone close hears it, and the spot is kept for Ringing.claim.
function Ringing.rang(x, y, z, zombie)
    x, y, z = math.floor(x), math.floor(y), math.floor(z or 0)
    if zombie then
        local md = zombie:getModData()
        md.KnoxMobileRinging = (md.KnoxMobileRinging or 0) + 1
    end
    Ringing.recent[#Ringing.recent + 1] = { x = x, y = y, at = Util.nowMinutes(), zombie = zombie }
    while #Ringing.recent > 30 do table.remove(Ringing.recent, 1) end
    -- Single player has one client however many players share the screen: tell it once.
    for _, p in ipairs(Util.players()) do
        if math.abs(p:getX() - x) <= Ringing.HEAR and math.abs(p:getY() - y) <= Ringing.HEAR then
            Net.toClient(p, "ringAt", { x = x, y = y, z = z, rings = 4 })
            if not isServer() then break end
        end
    end
    -- The zombie is the sound's source when the server has it; a sound with no source otherwise.
    pcall(addSound, zombie, x, y, z, 15, 15)
end

-- One rings near this player: picked here when the server sees zombies, else the player's client picks one.
function Ringing.ring(player, rng)
    local ok, zombie = pcall(Ringing.pick, player, rng)
    if ok and zombie then return Ringing.rang(zombie:getX(), zombie:getY(), zombie:getZ(), zombie) end
    if isServer() then
        Ringing.asked[Util.playerKey(player)] = Util.nowMinutes()
        Net.toClient(player, "ringPick", {})
    end
end

-- The zombie just killed at (x, y): if a phone rang on one near there lately (or on this very one), how many times.
-- Each ring is claimed once.
function Ringing.claim(zombie, x, y)
    local zmd = zombie and zombie.getModData and zombie:getModData()
    local now = Util.nowMinutes()
    for i = #Ringing.recent, 1, -1 do
        local r = Ringing.recent[i]
        local mine = r.zombie ~= nil and r.zombie == zombie
        local close = math.abs(r.x - x) <= Ringing.CLAIM and math.abs(r.y - y) <= Ringing.CLAIM
        if now - r.at > Ringing.KEEP_MINUTES then
            table.remove(Ringing.recent, i)
        elseif mine or (r.zombie == nil and close) then
            table.remove(Ringing.recent, i)
            return (zmd and zmd.KnoxMobileRinging) or 1
        end
    end
    return zmd and zmd.KnoxMobileRinging or nil
end

Protocol.register({
    ringPicked = function(args)
        if not (tonumber(args.x) and tonumber(args.y) and tonumber(args.z)) then return false, "x, y, z must be numbers" end
        return true
    end,
})

-- A client picked the zombie (the server keeps no zombie list): only when asked, and only near that player.
Net.onServer("ringPicked", function(player, args)
    local key = Util.playerKey(player)
    local asked = Ringing.asked[key]
    Ringing.asked[key] = nil
    if not asked or Util.nowMinutes() - asked > 30 then return end
    if math.abs(player:getX() - args.x) > Ringing.FAR + 5 or math.abs(player:getY() - args.y) > Ringing.FAR + 5 then return end
    Ringing.rang(args.x, args.y, args.z, nil)
end)

Tick.add("ringing", function()
    if isClient() then return end
    local t = getTimestampMs()
    if t < Ringing.nextAt then return end
    Ringing.nextAt = t + Ringing.CHECK_MS
    local chance = Ringing.chance(Util.nowDay())
    if chance <= 0 then return end
    for _, player in ipairs(Util.players()) do
        local rng = Rng.new("ring:" .. Util.playerKey(player) .. ":" .. tostring(t))
        if not player:isDead() and rng:chance(chance) then Ringing.ring(player, rng) end
    end
end, 1000)

Ringing.fit = fit
return Ringing
