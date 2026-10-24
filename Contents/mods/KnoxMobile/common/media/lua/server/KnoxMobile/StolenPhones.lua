-- Server: Knox phones taken by Project A-Life robbers come back as themselves (0.2.0; docs/rounds/
-- ALIFE_STOLEN_PHONE_PLAN.md). A-Life keeps a stolen item as its type and condition only, so a recovered phone would be
-- blank: no SIM, contacts, texts or photos. Every couple of seconds the server notes each player's phones; when one
-- leaves a player while an A-Life NPC nearby is robbing them, a copy of its state is kept with who took it. When a phone
-- of that model turns up again with no state of its own (A-Life made a new one), it gets the old state back.
local Phones = require "KnoxMobile/Game/Phones"
local Util = require "KnoxMobile/Game/Util"
local ALife = require "KnoxMobile/Game/ALife"
local Tick = require "KnoxMobile/Game/Tick"
local State = require "KnoxMobile/State"

local Stolen = { nextAt = 0, seen = {} }
KnoxMobile.StolenPhones = Stolen

local CHECK_MS = 2000
local NEAR = 8 -- tiles

local function copy(v, depth)
    if type(v) ~= "table" or (depth or 0) > 12 then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = copy(x, (depth or 0) + 1) end
    return out
end

-- The A-Life NPC robbing this player right now, close by: its record (a copy), or nil.
function Stolen.robber(player)
    local interop = ALife.interop()
    if not (interop and type(interop.forEachNpc) == "function") then return nil end
    local name = player:getUsername()
    local px, py = player:getX(), player:getY()
    local found
    pcall(interop.forEachNpc, function(actor)
        if found or type(actor) ~= "table" then return end
        local mem = type(actor.memory) == "table" and actor.memory or {}
        local pos = type(actor.worldPosition) == "table" and actor.worldPosition or {}
        local robbing = mem.robbery ~= nil or (name ~= nil and mem.targetUsername == name)
        if robbing and tonumber(pos.x) and tonumber(pos.y) and math.abs(pos.x - px) <= NEAR and math.abs(pos.y - py) <= NEAR then
            found = actor
        end
    end)
    return found
end

local function records()
    local md = State.get()
    md.stolenPhones = md.stolenPhones or {}
    return md.stolenPhones
end

-- One player: phones that left them during a robbery are written down; a blank phone of a stolen model gets its state.
function Stolen.check(player)
    local key = Util.playerKey(player)
    local now = {}
    for _, item in ipairs(Phones.inventoryPhones(player)) do
        now[tostring(item:getID())] = item
        local md = item:getModData()
        if md[Phones.KEY] == nil then
            local list = records()
            -- Only the robbed player's own records: an untouched phone from house loot looks the same as one A-Life
            -- made again, so a stranger never gets someone else's phone, and the owner gets theirs back.
            for i, r in ipairs(list) do
                if r.owner == key and r.fullType == item:getFullType() then
                    md[Phones.KEY] = r.state
                    md.KnoxMobileOrigin = "recovered"
                    table.remove(list, i)
                    Phones.save(item, player)
                    Util.log("stolen phone recovered:", r.fullType, "taken by", tostring(r.byName))
                    if KnoxMobile.Journal then
                        KnoxMobile.Journal.add(player, "Got my phone back from " .. tostring(r.byName or "them") .. ".")
                    end
                    break
                end
            end
        end
    end
    local before = Stolen.seen[key]
    if before then
        for id, item in pairs(before) do
            if not now[id] then
                local robber = Stolen.robber(player)
                local state = item:getModData()[Phones.KEY]
                if robber and type(state) == "table" then
                    local list = records()
                    list[#list + 1] = { owner = key, fullType = item:getFullType(), state = copy(state), by = tostring(robber.uid),
                        byName = ALife.name(robber), at = Util.nowMinutes() }
                    Util.log("phone taken by an A-Life robber:", item:getFullType(), tostring(ALife.name(robber)))
                    if KnoxMobile.Journal then
                        KnoxMobile.Journal.add(player, tostring(ALife.name(robber) or "Somebody") .. " took one of my phones.")
                    end
                end
            end
        end
    end
    Stolen.seen[key] = now
end

-- Who took this player's phones and where that NPC is now (for Find My Crew): { { byName, x, y } }.
function Stolen.takenFrom(player)
    local key, out = Util.playerKey(player), {}
    local interop = ALife.interop()
    for _, r in ipairs(records()) do
        if r.owner == key then
            local pos
            if interop and type(interop.actorOf) == "function" then
                local ok, actor = pcall(interop.actorOf, r.by)
                if ok and type(actor) == "table" and actor.lifecycle ~= "dead" then pos = actor.worldPosition end
            end
            out[#out + 1] = { byName = r.byName, x = pos and pos.x, y = pos and pos.y }
        end
    end
    return out
end

Tick.add("stolen phones", function()
    if isClient() or not ALife.interop() then return end
    local t = getTimestampMs()
    if t < Stolen.nextAt then return end
    Stolen.nextAt = t + CHECK_MS
    for _, player in ipairs(Util.players()) do
        if not player:isDead() then Stolen.check(player) end
    end
end, 1000)

return Stolen
