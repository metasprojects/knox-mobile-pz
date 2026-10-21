-- Group chats: named groups made from contacts, and automatic groups that follow a player's faction and
-- safehouse. Pure Lua 5.1; the server keeps the registry in world ModData (plain tables only).
--   registry = { byId = { [id] = group }, nextId = 1 }
--   made by players: { id = "g3", name, owner = number, members = { numbers, owner included } }
--   automatic:       { id = "f:<faction>" | "s:<safehouse id>", name, auto = "faction" | "safehouse", keys = { player keys } }
-- A text to a group goes to each member through the normal per-recipient path (server Messaging), so every member
-- needs coverage and texts wait in the queue while someone is out of reach.
local Groups = {}

Groups.MAX_NAME = 24       -- characters in a group name
Groups.MAX_MEMBERS = 12    -- people in a group made by players, the creator included
Groups.MAX_AUTO = 24       -- a text to a faction or safehouse group reaches at most this many members
Groups.MAX_PER_NUMBER = 8  -- groups made by players that one number can belong to
Groups.THREAD = "grp:"     -- conversation key prefix on the phone: "grp:<group id>"

function Groups.newRegistry() return { byId = {}, nextId = 1 } end

local function indexOf(list, value)
    for i, v in ipairs(list or {}) do if v == value then return i end end
    return nil
end

-- Trimmed, single-spaced, no control characters, at most MAX_NAME characters; nil when nothing is left.
function Groups.cleanName(name)
    if type(name) ~= "string" then return nil end
    local s = name:gsub("%c", " "):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
    if #s > Groups.MAX_NAME then s = s:sub(1, Groups.MAX_NAME):gsub(" $", "") end
    if #s == 0 then return nil end
    return s
end

function Groups.isMember(group, number, key)
    if not group then return false end
    if group.auto then return key ~= nil and indexOf(group.keys, key) ~= nil end
    return number ~= nil and indexOf(group.members, number) ~= nil
end

-- Groups made by players that this number belongs to.
function Groups.countFor(reg, number)
    local n = 0
    for _, g in pairs(reg.byId) do
        if not g.auto and indexOf(g.members, number) then n = n + 1 end
    end
    return n
end

-- Every group this number (or player key, for automatic groups) belongs to, sorted by name then id.
function Groups.forMember(reg, number, key)
    local out = {}
    for _, g in pairs(reg.byId) do
        if Groups.isMember(g, number, key) then out[#out + 1] = g end
    end
    table.sort(out, function(a, b)
        if a.name == b.name then return a.id < b.id end
        return a.name < b.name
    end)
    return out
end

-- A new group with the owner and the chosen numbers. Members already in too many groups are skipped and
-- returned as the third value. Returns group, nil, skipped | nil, reason.
function Groups.create(reg, owner, name, numbers)
    local clean = Groups.cleanName(name)
    if not clean then return nil, "badName" end
    if Groups.countFor(reg, owner) >= Groups.MAX_PER_NUMBER then return nil, "tooManyGroups" end
    local members, skipped = { owner }, {}
    for _, n in ipairs(numbers or {}) do
        if type(n) == "string" and not indexOf(members, n) and not indexOf(skipped, n) then
            if Groups.countFor(reg, n) >= Groups.MAX_PER_NUMBER then skipped[#skipped + 1] = n
            else members[#members + 1] = n end
        end
    end
    if #members < 2 then return nil, #skipped > 0 and "theirLimit" or "tooFew" end
    if #members > Groups.MAX_MEMBERS then return nil, "tooMany" end
    local group = { id = "g" .. reg.nextId, name = clean, owner = owner, members = members }
    reg.nextId = reg.nextId + 1
    reg.byId[group.id] = group
    return group, nil, skipped
end

-- Any member adds someone to a group made by players.
function Groups.add(reg, id, by, number)
    local g = reg.byId[id]
    if not g then return nil, "noGroup" end
    if g.auto then return nil, "auto" end
    if not indexOf(g.members, by) then return nil, "notMember" end
    if indexOf(g.members, number) then return nil, "already" end
    if #g.members >= Groups.MAX_MEMBERS then return nil, "full" end
    if Groups.countFor(reg, number) >= Groups.MAX_PER_NUMBER then return nil, "theirLimit" end
    g.members[#g.members + 1] = number
    return g
end

-- Leaving: the next member becomes owner when the owner leaves; an empty group is deleted (returns nil).
function Groups.leave(reg, id, number)
    local g = reg.byId[id]
    if not g then return nil, "noGroup" end
    if g.auto then return nil, "auto" end
    local i = indexOf(g.members, number)
    if not i then return nil, "notMember" end
    table.remove(g.members, i)
    if #g.members == 0 then
        reg.byId[id] = nil
        return nil
    end
    if g.owner == number then g.owner = g.members[1] end
    return g
end

-- Only the owner removes other people; removing yourself is leaving.
function Groups.remove(reg, id, by, number)
    local g = reg.byId[id]
    if not g then return nil, "noGroup" end
    if g.auto then return nil, "auto" end
    if by == number then return Groups.leave(reg, id, number) end
    if g.owner ~= by then return nil, "notOwner" end
    if not indexOf(g.members, number) then return nil, "notMember" end
    return Groups.leave(reg, id, number)
end

-- Keeps the automatic group of one kind in step with what the game says about this player.
-- info = nil (no faction or safehouse) or { id, name, keys = { player keys } }. Returns the ids that changed.
function Groups.syncAuto(reg, kind, key, info)
    local prefix = kind == "faction" and "f:" or "s:"
    local wanted = info and (prefix .. tostring(info.id)) or nil
    local changed = {}
    for id, g in pairs(reg.byId) do
        if g.auto == kind and id ~= wanted then
            local i = indexOf(g.keys, key)
            if i then
                table.remove(g.keys, i)
                if #g.keys == 0 then reg.byId[id] = nil end
                changed[#changed + 1] = id
            end
        end
    end
    if wanted then
        local keys = {}
        for _, k in ipairs(info.keys or {}) do
            if type(k) == "string" and k ~= "" and not indexOf(keys, k) then keys[#keys + 1] = k end
        end
        if not indexOf(keys, key) then keys[#keys + 1] = key end
        local name = Groups.cleanName(info.name) or (kind == "faction" and "Faction" or "Safehouse")
        local g = reg.byId[wanted]
        local same = g and g.name == name and #g.keys == #keys
        if same then
            for _, k in ipairs(keys) do if not indexOf(g.keys, k) then same = false end end
        end
        if not same then
            reg.byId[wanted] = { id = wanted, name = name, auto = kind, keys = keys }
            changed[#changed + 1] = wanted
        end
    end
    table.sort(changed)
    return changed
end

-- Every member's number except the sender's. numberOf(key) gives an automatic group member's number (or nil).
function Groups.numbers(group, numberOf)
    local out = {}
    if group.auto then
        for _, k in ipairs(group.keys or {}) do
            local n = numberOf and numberOf(k)
            if n and not indexOf(out, n) then out[#out + 1] = n end
        end
    else
        for _, n in ipairs(group.members or {}) do out[#out + 1] = n end
    end
    return out
end

function Groups.recipients(group, from, numberOf)
    local out = {}
    local cap = group.auto and Groups.MAX_AUTO or Groups.MAX_MEMBERS
    for _, n in ipairs(Groups.numbers(group, numberOf)) do
        if n ~= from and #out < cap then out[#out + 1] = n end
    end
    return out
end

-- What a phone is told about a group: no player keys (account names stay on the server).
function Groups.publicCopy(group, numberOf)
    return { id = group.id, name = group.name, auto = group.auto, owner = group.owner,
        members = Groups.numbers(group, numberOf) }
end

function Groups.thread(id) return Groups.THREAD .. tostring(id) end
function Groups.idFromThread(with)
    if type(with) ~= "string" then return nil end
    return with:match("^grp:(.+)$")
end

-- Command payload checks (registered with Core/Protocol by the server).
local function phoneId(args)
    if type(args.phoneId) ~= "number" then return false, "phoneId must be a number" end
    return true
end

local function groupId(args)
    if type(args.group) ~= "string" or #args.group < 1 or #args.group > 64 then return false, "group must be a short string" end
    return phoneId(args)
end

local function number(args, normalise)
    if type(args.number) ~= "string" or normalise(args.number) ~= args.number then
        return false, "number is not a normalised phone number"
    end
    return true
end

function Groups.validators(normalise, maxText)
    return {
        groupList = phoneId,
        groupCreate = function(args)
            if type(args.name) ~= "string" or #args.name < 1 or #args.name > 64 then return false, "name must be 1-64 characters" end
            if type(args.members) ~= "table" or #args.members < 1 or #args.members > Groups.MAX_MEMBERS then
                return false, "members must list 1-" .. Groups.MAX_MEMBERS .. " numbers"
            end
            for _, n in ipairs(args.members) do
                if type(n) ~= "string" or normalise(n) ~= n then return false, "members must be normalised numbers" end
            end
            return phoneId(args)
        end,
        groupAdd = function(args)
            local ok, why = groupId(args)
            if not ok then return ok, why end
            return number(args, normalise)
        end,
        groupRemove = function(args)
            local ok, why = groupId(args)
            if not ok then return ok, why end
            return number(args, normalise)
        end,
        groupLeave = groupId,
        groupText = function(args)
            local ok, why = groupId(args)
            if not ok then return ok, why end
            if type(args.body) ~= "string" or #args.body < 1 or #args.body > maxText then
                return false, "body must be 1-" .. maxText .. " characters"
            end
            return true
        end,
    }
end

return Groups
