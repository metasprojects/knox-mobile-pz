-- Server: trap texts (after 0.3.0, Core/Traps has the words). Between day 2 and 30 a "rescue" text may name a real
-- place; what waits there (set when its chunk loads, Quests.lua) is an ambush: the ones who set it, turned, among the
-- ones who fell for it, by a body. Sometimes a neighbor warns first; arrive anyway and the sender writes back.
-- Sandbox Stories > Trap texts. global ModData: traps[player key] = { sent, list = { { questId, number } } }.
local Traps = require "KnoxMobile/Core/Traps"
local Quests = require "KnoxMobile/Core/Quests"
local Rng = require "KnoxMobile/Core/Rng"
local Sim = require "KnoxMobile/Core/Sim"
local Util = require "KnoxMobile/Game/Util"
local Tick = require "KnoxMobile/Game/Tick"
local State = require "KnoxMobile/State"
local Messaging = require "KnoxMobile/Messaging"
local QuestsWorld = require "KnoxMobile/Quests"

local TrapTexts = { nextAt = 0, lastHour = {} }
KnoxMobile.TrapTexts = TrapTexts

local function enabled()
    local sv = SandboxVars and SandboxVars.KnoxMobile
    return not (sv and sv.TrapTexts == false)
end

local function book(key)
    local md = State.get()
    if type(md.traps) ~= "table" then md.traps = {} end
    md.traps[key] = md.traps[key] or { sent = 0, list = {} }
    return md.traps[key]
end

-- One trap for this player now (also the way tests and the debug menu get one). Returns the quest id or nil.
function TrapTexts.send(player, rng)
    local key = Util.playerKey(player)
    local mine = State.get().players[key]
    if not (mine and mine.number) then return nil end
    local used = {}
    for _, q in pairs(State.get().quests) do used[q.site] = true end
    local list = Quests.make(rng, 1, { startDay = Util.nowDay(), endDay = Util.nowDay(), trapChance = 0, used = used })
    local t = list[1]
    if not t then return nil end
    t.quest.trap, t.quest.loot, t.quest.outfits = "ambush", {}, Traps.outfits(rng)
    local number = Sim.issueNumber(State.get().numbers, rng)
    t.quest.number = number
    QuestsWorld.add(key, list)
    QuestsWorld.arm(t.questId)
    local now = Util.nowMinutes()
    Messaging.queueStory(number, mine.number, Traps.bait(rng, t.place.name), now + rng:int(1, 20))
    if rng:chance(Traps.WARN_CHANCE) then
        Messaging.queueStory(Sim.issueNumber(State.get().numbers, rng), mine.number, Traps.warning(rng, t.place.name),
            now + rng:int(60, 240))
    end
    local b = book(key)
    b.sent = b.sent + 1
    b.list[#b.list + 1] = { questId = t.questId, number = number }
    Util.log("trap text for", key, "to", t.place.name)
    return t.questId
end

-- From Quests.lua when an ambush is set: the sender writes back.
function TrapTexts.sprung(q)
    local mine = q.player and State.get().players[q.player]
    if not (mine and mine.number and q.number) then return end
    Messaging.queueStory(q.number, mine.number, Traps.after(Rng.new(tostring(q.number) .. ":after")), Util.nowMinutes() + 1)
end

Tick.add("trap texts", function()
    if isClient() or not enabled() then return end
    local t = getTimestampMs()
    if t < TrapTexts.nextAt then return end
    TrapTexts.nextAt = t + 5000
    local hour = math.floor(Util.nowMinutes() / 60)
    local day = Util.sinceOutbreak()
    for _, player in ipairs(Util.players()) do
        local key = Util.playerKey(player)
        local last = TrapTexts.lastHour[key]
        TrapTexts.lastHour[key] = hour
        if not player:isDead() and last and last ~= hour then
            local rng = Rng.new(tostring(State.get().seed) .. ":trap:" .. key .. ":" .. hour)
            if Traps.due(rng, day, book(key).sent) then TrapTexts.send(player, rng) end
        end
    end
end, 1000)

return TrapTexts
