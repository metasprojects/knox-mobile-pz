-- Server: story scenes set in the world the first time their place's chunk loads (2026-10-12): the family hunt
-- (Hunt.lua) and survivor stashes (Quests.lua).
--
-- How Build 42 spawns things on chunk load: vanilla fills a chunk in Java while it loads (IsoChunk.doLoadGridsquare:
-- randomized stories, zombies, loot), then fires the Lua events LoadGridsquare (each square) and LoadChunk. In
-- multiplayer the server loads chunks (ServerMap.ServerCell) and fires them; clients don't. So this listens to
-- LoadGridsquare on the server only, matches each armed scene's one anchor square by a number key (no work at all
-- while nothing is armed), and lets the scene set itself a few ticks later, once the chunk has finished loading, with
-- vanilla's server-side calls: addZombiesInOutfit (the zombies sync like any other), IsoGridSquare.
-- AddWorldInventoryItem (sent to clients), addVehicleDebug and createRandomDeadBody.
-- Idempotent: every scene's state lives in the world's global ModData and turns "done" before anything is placed,
-- so a scene never spawns twice through reloads, saves and players coming and going. A square that unloads before
-- the scene settles leaves it armed for the next load.
local Util = require "KnoxMobile/Game/Util"

local Scenes = { kinds = {}, order = {}, pending = {}, index = nil }
local KEY = 100000          -- anchor square key: x * KEY + y
local SETTLE_TICKS = 30     -- ticks after the anchor square loads before the scene is set

-- kind = { armed = function() -> { { id, x, y } } (scenes waiting for their chunk),
--          spawn = function(id) (sets it if still armed and its anchor square is loaded) }
function Scenes.register(name, kind)
    if not Scenes.kinds[name] then Scenes.order[#Scenes.order + 1] = name end
    Scenes.kinds[name] = kind
    Scenes.index = nil
end

-- Called when a scene is armed or set: the anchor index is rebuilt on the next square load.
function Scenes.invalidate() Scenes.index = nil end

function Scenes.rebuild()
    local index = {}
    for _, name in ipairs(Scenes.order) do
        for _, s in ipairs(Scenes.kinds[name].armed()) do
            local key = math.floor(s.x) * KEY + math.floor(s.y)
            index[key] = index[key] or {}
            table.insert(index[key], { name = name, id = s.id })
        end
    end
    Scenes.index = index
    return index
end

-- A ground-floor square inside the building, free to stand on, near the anchor; `skip` spreads several out.
function Scenes.freeInside(anchor, skip)
    local cell, x0, y0 = getCell(), anchor:getX(), anchor:getY()
    local n = 0
    for r = 0, 6 do
        for dx = -r, r do
            for dy = -r, r do
                if math.max(math.abs(dx), math.abs(dy)) == r then
                    local sq = cell:getGridSquare(x0 + dx, y0 + dy, 0)
                    if sq and sq:getRoom() and sq:isFree(false) then
                        n = n + 1
                        if n > skip then return sq end
                    end
                end
            end
        end
    end
    return anchor
end

-- Events (server and single player only) ---------------------------------------------------------------
local ready = false
Events.OnInitGlobalModData.Add(Util.safe("story scenes", function()
    ready = not isClient()
    Scenes.index = nil
end))

Events.LoadGridsquare.Add(Util.safe("story scene square", function(sq)
    if not ready then return end
    local index = Scenes.index or Scenes.rebuild()
    if Util.isEmpty(index) then return end
    local list = index[sq:getX() * KEY + sq:getY()]
    if not list or sq:getZ() ~= 0 then return end
    for _, s in ipairs(list) do
        local key = s.name .. "\t" .. tostring(s.id)
        if not Scenes.pending[key] then Scenes.pending[key] = { name = s.name, id = s.id, ticks = 0 } end
    end
end))

Events.OnTick.Add(Util.safe("story scene spawn", function()
    if Util.isEmpty(Scenes.pending) then return end
    for key, p in pairs(Scenes.pending) do
        if p.ticks < SETTLE_TICKS then
            p.ticks = p.ticks + 1
        else
            Scenes.pending[key] = nil
            local kind = Scenes.kinds[p.name]
            if kind then Util.safe("story scene " .. p.name, kind.spawn)(p.id) end
        end
    end
end))

return Scenes
