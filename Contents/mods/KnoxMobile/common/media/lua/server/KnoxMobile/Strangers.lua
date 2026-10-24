-- Server: strangers on the network (0.2.0; Core/Strangers has the words). Now and then a wrong number texts your own
-- SIM, and now and then a rumor arrives, forwarded from phone to phone: a survivor stash at a real place (Quests.lua),
-- true or picked over or a trap. Rolled once a game hour per player; story texts, so they always arrive in the end.
local Util = require "KnoxMobile/Game/Util"
local Tick = require "KnoxMobile/Game/Tick"
local Rng = require "KnoxMobile/Core/Rng"
local Sim = require "KnoxMobile/Core/Sim"
local Quests = require "KnoxMobile/Core/Quests"
local Strangers = require "KnoxMobile/Core/Strangers"
local State = require "KnoxMobile/State"
local Messaging = require "KnoxMobile/Messaging"
local QuestsWorld = require "KnoxMobile/Quests"

local World = { nextAt = 0, lastHour = {} }
KnoxMobile.Strangers = World

local function stranger(rng) return Sim.issueNumber(State.get().numbers, rng) end

-- A rumor: a stash text, forwarded. Traps are likelier than in a stranger's own text (sandbox QuestTrapChance, doubled).
function World.rumor(player, number, rng)
    local key = Util.playerKey(player)
    local used = {}
    for _, q in pairs(State.get().quests) do used[q.site] = true end
    local trap = math.min(100, (Util.settings().QuestTrapChance or 25) * 2)
    local list = Quests.make(rng, 1, { startDay = Util.nowDay(), endDay = Util.nowDay(), trapChance = trap, used = used })
    if not list[1] then return false end
    QuestsWorld.add(key, list)
    QuestsWorld.arm(list[1].questId)
    Messaging.queueStory(stranger(rng), number, Strangers.forward(rng, list[1].body))
    Util.log("rumor for", key, "about", list[1].place.name)
    return true
end

-- One game hour for one player: maybe a wrong number, maybe a rumor.
function World.hour(player, rng)
    local mine = State.get().players[Util.playerKey(player)]
    if not (mine and mine.number) then return end
    local wrong, rumor = Strangers.hourly(Util.nowDay())
    if rng:chance(wrong) then Messaging.queueStory(stranger(rng), mine.number, Strangers.wrong(rng)) end
    if rng:chance(rumor) then World.rumor(player, mine.number, rng) end
end

Tick.add("strangers", function()
    if isClient() then return end
    local t = getTimestampMs()
    if t < World.nextAt then return end
    World.nextAt = t + 15000
    local hour = math.floor(Util.nowMinutes() / 60)
    for _, player in ipairs(Util.players()) do
        local key = Util.playerKey(player)
        local last = World.lastHour[key]
        World.lastHour[key] = hour
        if last and not player:isDead() then
            for h = math.max(last + 1, hour - 2), hour do
                World.hour(player, Rng.new(tostring(State.get().seed) .. ":stranger:" .. key .. ":" .. h))
            end
        end
    end
end, 1000)

return World
