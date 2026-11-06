-- Server: a phone left on gives you away (after 0.3.0). With the Bandits mod, a hostile clan near a player whose phone
-- is on with service (and not a burner SIM, server/Burners.lua) may lock onto it: a text from the clan, then for two
-- in-game hours the phone chirps every ten minutes, a noise that carries, until it's switched off or the SIM is a
-- burner. Sandbox Stories > Clans track phones. Hostiles near a player come from Raids (KnoxMobile.Raids.near).
local Bandits = require "KnoxMobile/Game/Bandits"
local Phones = require "KnoxMobile/Game/Phones"
local Util = require "KnoxMobile/Game/Util"
local Tick = require "KnoxMobile/Game/Tick"
local Rng = require "KnoxMobile/Core/Rng"
local Sim = require "KnoxMobile/Core/Sim"
local Story = require "KnoxMobile/Core/Story"
local State = require "KnoxMobile/State"
local Messaging = require "KnoxMobile/Messaging"
local Net = require "KnoxMobile/Game/Net"

local ClanTrace = { nextAt = 0, lastHour = {}, tracked = {}, CHANCE = 0.25, HOURS = 2, EVERY = 10, NOISE = 25 }
KnoxMobile.ClanTrace = ClanTrace

ClanTrace.LINES = require("KnoxMobile/Core/Traps").TRACE

local function enabled()
    local sv = SandboxVars and SandboxVars.KnoxMobile
    return not (sv and sv.ClanTracking == false)
end

-- The phone that gives this player away: on, with service, not a burner. Returns item, state or nil.
function ClanTrace.loudPhone(player)
    for _, item in ipairs(Phones.inventoryPhones(player)) do
        local st, model = Phones.get(item)
        if st and Messaging.usable(st) and st.sim and st.sim.number and not st.sim.burner
            and Messaging.service(player, model).network then
            return item, st
        end
    end
    return nil
end

-- A clan locks on: the text, and the chirping starts.
function ClanTrace.lock(player, rng, clan)
    local item, st = ClanTrace.loudPhone(player)
    if not item then return false end
    local key = Util.playerKey(player)
    local from = Sim.issueNumber(State.get().numbers, rng)
    local body = Story.fill(rng, rng:pick(ClanTrace.LINES), {})
    Messaging.queueStory(from, st.sim.number, body, Util.nowMinutes())
    ClanTrace.tracked[key] = { untilMin = Util.nowMinutes() + ClanTrace.HOURS * 60, nextChirp = Util.nowMinutes(),
        clan = clan }
    Util.log("clan", tostring(clan), "tracks the phone of", key)
    return true
end

-- Every check: tracked players' loud phones chirp; switched off or a burner, it stops.
function ClanTrace.chirp(player, now)
    local key = Util.playerKey(player)
    local t = ClanTrace.tracked[key]
    if not t then return false end
    if now > t.untilMin or not ClanTrace.loudPhone(player) then ClanTrace.tracked[key] = nil; return false end
    if now < t.nextChirp then return false end
    t.nextChirp = now + ClanTrace.EVERY
    local x, y, z = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())
    pcall(addSound, player, x, y, z, ClanTrace.NOISE, ClanTrace.NOISE)
    Net.toClient(player, "ringAt", { x = x, y = y, z = z, rings = 1 })
    return true
end

Tick.add("clan trace", function()
    if isClient() or not (enabled() and Bandits.active()) then return end
    local t = getTimestampMs()
    if t < ClanTrace.nextAt then return end
    ClanTrace.nextAt = t + 5000
    local now = Util.nowMinutes()
    local hour = math.floor(now / 60)
    for _, player in ipairs(Util.players()) do
        if not player:isDead() then
            local key = Util.playerKey(player)
            ClanTrace.chirp(player, now)
            local last = ClanTrace.lastHour[key]
            ClanTrace.lastHour[key] = hour
            if last and last ~= hour and not ClanTrace.tracked[key] and KnoxMobile.Raids then
                local near = KnoxMobile.Raids.near(player)
                local rng = Rng.new(tostring(State.get().seed) .. ":trace:" .. key .. ":" .. hour)
                if #near > 0 and rng:chance(ClanTrace.CHANCE) then ClanTrace.lock(player, rng, near[1].clan) end
            end
        end
    end
end, 1000)

return ClanTrace
