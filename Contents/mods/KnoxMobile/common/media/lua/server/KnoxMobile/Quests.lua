-- Server: survivor stashes in the world (2026-10-12). A stranger's text points to a real pharmacy, gas station or
-- police station (Core/Quests decided what is there when the text was made); once that text has gone out, the stash
-- is set the first time the place's chunk loads (Scenes.lua: when, and why never twice). Quests live in the world's
-- global ModData: quests["<player key>|<site id>"] = { site, kind, name, x, y, trap, loot, outfits, player, state }.
local Quests = require "KnoxMobile/Core/Quests"
local Util = require "KnoxMobile/Game/Util"
local State = require "KnoxMobile/State"
local Scenes = require "KnoxMobile/Scenes"

local QuestsWorld = {}

-- Records a player's quest texts (from Core/Quests.make) and gives each text the quest's id.
function QuestsWorld.add(key, texts)
    local md = State.get()
    for _, m in ipairs(texts) do
        if m.quest then
            local id = key .. "|" .. m.quest.site
            local q = m.quest
            q.player, q.state = key, "waiting"
            md.quests[id] = q
            m.quest, m.questId = nil, id
        end
    end
end

-- The text is out: the stash waits for its chunk to load.
function QuestsWorld.arm(id)
    local q = State.get().quests[id]
    if q and q.state == "waiting" then
        q.state = "armed"
        Scenes.invalidate()
    end
end

function QuestsWorld.spawn(id)
    local q = State.get().quests[id]
    if not (q and q.state == "armed") then return false end
    local anchor = getCell():getGridSquare(q.x, q.y, 0)
    if not anchor then return false end
    q.state = "done" -- before anything is placed: never twice
    Scenes.invalidate()
    local stashSq = Scenes.freeInside(anchor, 0)
    local bag = instanceItem(Quests.BAG[q.kind])
    if bag then
        local inv = bag:getInventory()
        for _, t in ipairs(q.loot) do inv:AddItem(t) end
        stashSq:AddWorldInventoryItem(bag, 0.5, 0.5, 0)
    end
    if q.trap == "dead" then
        -- The survivor who sent it, dead by what is left of the stash.
        local body = createRandomDeadBody(Scenes.freeInside(anchor, 1), 10)
        if body and isServer() then body:transmitCompleteItemToClients() end
    end
    for i, outfit in ipairs(q.outfits) do
        local sq = Scenes.freeInside(anchor, 1 + i)
        addZombiesInOutfit(sq:getX(), sq:getY(), 0, 1, outfit, 50)
    end
    Util.log("survivor stash set at", q.name, "for", q.player, ":", #q.loot, "items,", #q.outfits, "zombies",
        q.trap and ("(trap: " .. q.trap .. ")") or "")
    return true
end

Scenes.register("quest", {
    armed = function()
        local out = {}
        for id, q in pairs(State.get().quests) do
            if q.state == "armed" then out[#out + 1] = { id = id, x = q.x, y = q.y } end
        end
        return out
    end,
    spawn = function(id) QuestsWorld.spawn(id) end,
})

return QuestsWorld
