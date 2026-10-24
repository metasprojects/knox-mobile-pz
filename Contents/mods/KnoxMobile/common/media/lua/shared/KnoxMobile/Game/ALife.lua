-- Project A-Life (Workshop 3803984183, mod id ProjectALifeNPCs) builds its NPCs on zombies and marks every one with
-- zombie:getModData().ProjectALifeOwned == true, so other mods can leave them alone. Knox Mobile does: no random found
-- phone, wallet or ID card goes on an A-Life body, an NPC is never taken for a family member, and photos don't count
-- NPCs as zombies (0.1.1, a Workshop request). From 0.2.0 an A-Life NPC can carry a phone of its own (its name, its
-- squad, its faction's chatter) through A-Life's public interop layer (ProjectALife.Interop, VERSION 1; notes in
-- docs/research/ALIFE_INTEROP.md). Every call is guarded: an A-Life update that changes these switches the feature
-- off, it never breaks Knox Mobile.
local ALife = {}

function ALife.isNPC(zombie)
    if not zombie then return false end
    local ok, yes = pcall(function()
        local md = zombie:getModData()
        return md ~= nil and md.ProjectALifeOwned == true
    end)
    return ok and yes == true
end

-- A-Life's interop layer, when the version Knox was written against is loaded; nil otherwise.
function ALife.interop()
    local pal = ProjectALife
    local interop = type(pal) == "table" and pal.Interop or nil
    if type(interop) == "table" and interop.VERSION == 1 and type(interop.on) == "function" then return interop end
    return nil
end

-- The NPC's first and last name from its record (memory.personFirst/personLast, or personName); nil when unknown.
function ALife.name(actor)
    local mem = type(actor) == "table" and actor.memory or nil
    if type(mem) ~= "table" then return nil end
    local first, last = mem.personFirst, mem.personLast
    if type(first) == "string" and first ~= "" then
        return (type(last) == "string" and last ~= "") and (first .. " " .. last) or first
    end
    if type(mem.personName) == "string" and mem.personName ~= "" then return mem.personName end
    return nil
end

-- A faction's name for people to read: its catalog entry's name or label, else its id made readable.
function ALife.factionName(factionId)
    if type(factionId) ~= "string" or factionId == "" then return nil end
    local ok, name = pcall(function()
        local faction = ProjectALife.Catalog.faction(factionId)
        if type(faction) ~= "table" then return nil end
        local g = type(faction.general) == "table" and faction.general or {}
        for _, v in ipairs({ g.name, g.label, g.displayName, faction.name, faction.label }) do
            if type(v) == "string" and v ~= "" then return v end
        end
        return nil
    end)
    if ok and name then return name end
    local readable = factionId:gsub("[_%-]", " "):gsub("(%a)([%w]*)", function(a, b) return a:upper() .. b end)
    return readable
end

-- Up to `max` first names of the NPC's squad mates (same group or squad, still around), from A-Life's NPC list.
function ALife.mates(actor, max)
    local interop = ALife.interop()
    local mem = type(actor) == "table" and type(actor.memory) == "table" and actor.memory or nil
    if not (interop and mem and type(interop.forEachNpc) == "function") then return {} end
    local group, squad = mem.groupId, mem.squadId
    if group == nil and squad == nil then return {} end
    local out = {}
    pcall(interop.forEachNpc, function(other)
        if #out >= max or type(other) ~= "table" or other.uid == actor.uid then return end
        local om = type(other.memory) == "table" and other.memory or {}
        if (group ~= nil and om.groupId == group) or (squad ~= nil and om.squadId == squad) then
            local first = om.personFirst
            if type(first) == "string" and first ~= "" then out[#out + 1] = first end
        end
    end)
    return out
end

-- Up to `max` living members of a faction right now: { { uid, name (first), x, y, intent, activity } } (server side;
-- A-Life keeps its NPC records there).
function ALife.members(factionId, max)
    local interop = ALife.interop()
    if not (interop and factionId and type(interop.forEachNpc) == "function") then return {} end
    local out = {}
    pcall(interop.forEachNpc, function(a)
        if #out >= max or type(a) ~= "table" or a.factionId ~= factionId or a.lifecycle == "dead" then return end
        local mem = type(a.memory) == "table" and a.memory or {}
        local pos = type(a.worldPosition) == "table" and a.worldPosition or {}
        if tonumber(pos.x) and tonumber(pos.y) then
            out[#out + 1] = { uid = tostring(a.uid), name = mem.personFirst or ALife.name(a) or "?", x = pos.x, y = pos.y,
                intent = a.intent, activity = a.activity }
        end
    end)
    return out
end

-- A-Life's raid in progress, if any (its RaidDirector keeps one at a time): { id, factionId, target (username), x, y }.
-- Internal to A-Life, so read carefully: nil when it isn't there or looks different.
function ALife.raid()
    local ok, r = pcall(function()
        local s = ProjectALife.RaidDirector.state
        if type(s) ~= "table" or s.raidId == nil or type(s.factionId) ~= "string" then return nil end
        return { id = tostring(s.raidId), factionId = s.factionId, target = s.targetUsername,
            x = tonumber(s.objectiveX), y = tonumber(s.objectiveY) }
    end)
    return ok and r or nil
end

return ALife
