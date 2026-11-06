-- Server: home signal boosters (0.3.0, Core/Boosters has the rule). Saved in the world's global ModData:
-- boosters = { { id, x, y, z, owner, powered } }. Every ten minutes a loaded booster is checked: still there, and
-- powered or not; a change goes out to every client with the world message.
local Boosters = require "KnoxMobile/Core/Boosters"
local Net = require "KnoxMobile/Game/Net"
local Util = require "KnoxMobile/Game/Util"
local State = require "KnoxMobile/State"

local World = {}
KnoxMobile.BoosterWorld = World

local function list()
    local md = State.get()
    if type(md.boosters) ~= "table" then md.boosters = {} end
    return md.boosters
end
World.list = list

-- The server's own copy for its signal checks, and every client's.
function World.publish()
    KnoxMobile.world.boosters = Boosters.publicCopy(list())
    if isServer() then Net.toAll("world", State.worldMessage()) end
end

-- Set down by the placeBooster action (shared code, on the server).
function World.place(player, square)
    local md = State.get()
    md.nextBooster = (tonumber(md.nextBooster) or 1)
    local b = { id = "B" .. md.nextBooster, x = square:getX(), y = square:getY(), z = square:getZ(),
        owner = Util.playerKey(player), powered = Util.powered(square) }
    md.nextBooster = md.nextBooster + 1
    local all = list()
    all[#all + 1] = b
    Util.log("booster", b.id, "placed at", b.x, b.y, b.z, "powered", b.powered)
    World.publish()
    return b
end

local function stillThere(sq, id)
    local objects = sq:getWorldObjects()
    for i = 0, objects:size() - 1 do
        local item = objects:get(i).getItem and objects:get(i):getItem()
        if item and item:getFullType() == "KnoxMobile.SignalBooster" and item:getModData().KnoxMobileBoosterId == id then
            return true
        end
    end
    return false
end

-- Presence and power, for loaded squares. Returns true when anything changed.
function World.check()
    local keep, changed = {}, false
    for _, b in ipairs(list()) do
        local sq = getCell() and getCell():getGridSquare(b.x, b.y, b.z)
        if sq and not stillThere(sq, b.id) then
            Util.log("booster", b.id, "is gone")
            changed = true
        else
            if sq then
                local on = Util.powered(sq)
                if on ~= (b.powered == true) then b.powered, changed = on, true end
            end
            keep[#keep + 1] = b
        end
    end
    State.get().boosters = keep
    if changed then World.publish() end
    return changed
end

Events.EveryTenMinutes.Add(Util.safe("boosters", function()
    if isClient() or #list() == 0 then return end
    World.check()
end))

Events.OnInitGlobalModData.Add(Util.safe("boosters load", function()
    if isClient() then return end
    KnoxMobile.world.boosters = Boosters.publicCopy(list())
end))

return World
