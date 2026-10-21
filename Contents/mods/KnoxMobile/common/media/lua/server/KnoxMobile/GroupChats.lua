-- Server: group chats. Named groups made from contacts (add, remove, leave) and automatic groups for the player's
-- faction and safehouse (Build 42 Faction and SafeHouse). A group text goes to each member through Messaging's
-- normal per-recipient path, so every member needs coverage and texts queue while someone is out of reach.
-- Every command is checked here: the phone is the sender's, on, unlocked, with a SIM and service; sizes and limits.
local Groups = require "KnoxMobile/Core/Groups"
local Protocol = require "KnoxMobile/Core/Protocol"
local Sim = require "KnoxMobile/Core/Sim"
local Phones = require "KnoxMobile/Game/Phones"
local Util = require "KnoxMobile/Game/Util"
local Net = require "KnoxMobile/Game/Net"
local SocialText = require "KnoxMobile/Game/SocialText"
local Messaging = require "KnoxMobile/Messaging"
local Social = require "KnoxMobile/SocialData"

local GroupChats = {}

Protocol.register(Groups.validators(Sim.normalise, Protocol.MAX_TEXT))

local function reg() return Social.data().groups end

-- Brings this player's faction and safehouse groups up to date. Returns the group ids that changed.
function GroupChats.syncAuto(player)
    local key = Util.playerKey(player)
    Social.track(player)
    local changed = {}
    for _, id in ipairs(Groups.syncAuto(reg(), "faction", key, Social.faction(player))) do changed[#changed + 1] = id end
    for _, id in ipairs(Groups.syncAuto(reg(), "safehouse", key, Social.safehouse(player))) do changed[#changed + 1] = id end
    return changed
end

-- The groups one phone belongs to, as the phone sees them.
function GroupChats.listFor(player, number)
    local out = {}
    for _, g in ipairs(Groups.forMember(reg(), number, Util.playerKey(player))) do
        out[#out + 1] = Groups.publicCopy(g, Social.numberOf)
    end
    return out
end

function GroupChats.sendList(player, item, state)
    Net.toClient(player, "groupList", { phoneId = item:getID(), groups = GroupChats.listFor(player, state.sim.number) })
end

-- After a change: every online member's phones get the new list (groups that are gone drop out of it).
function GroupChats.push(ids)
    if #ids == 0 then return end
    local wanted = {}
    for _, id in ipairs(ids) do wanted[id] = true end
    for _, p in ipairs(Util.players()) do
        for _, item in ipairs(Phones.inventoryPhones(p)) do
            local st = Phones.get(item)
            if st and st.sim and st.sim.number then
                -- Members now, and anyone whose thread still names a changed group (they may have just left it).
                local touched = false
                for _, g in ipairs(Groups.forMember(reg(), st.sim.number, Util.playerKey(p))) do
                    if wanted[g.id] then touched = true end
                end
                for _, conv in ipairs(st.contents.texts or {}) do
                    if conv.group and wanted[conv.group] then touched = true end
                end
                if touched then GroupChats.sendList(p, item, st) end
            end
        end
    end
end

local function result(player, args, status, extra)
    local out = { status = status, group = args.group, phoneId = args.phoneId }
    for k, v in pairs(extra or {}) do out[k] = v end
    Net.toClient(player, "groupResult", out)
end

-- The phone, its service and its sender network; nil (after telling the player why) when it can't be used.
local function ready(player, args, needService)
    local item, state, model = Social.phone(player, args)
    if not item then result(player, args, "failed", { reason = state }); return nil end
    local located, net = Messaging.service(player, model)
    if needService and not located.network then result(player, args, "failed", { reason = "noService" }); return nil end
    return item, state, model, net
end

-- A short notice in each new member's group thread ("Kate added you to Muldraugh Crew"), by the normal path.
local function notice(group, from, to, event, senderNet)
    Messaging.route({ from = from, to = to, body = SocialText.event(event, from, group.name), group = group.id,
        groupName = group.name, event = event }, senderNet)
end

Net.onServer("groupList", function(player, args)
    if not Social.throttle(player, "groupList", 500) then return end
    local item, state = Social.phone(player, args)
    if not item then return end
    GroupChats.push(GroupChats.syncAuto(player))
    GroupChats.sendList(player, item, state)
end)

Net.onServer("groupCreate", function(player, args)
    local item, state, _, net = ready(player, args, true)
    if not item then return end
    local me = state.sim.number
    local group, why, skipped = Groups.create(reg(), me, args.name, args.members)
    if not group then return result(player, args, "failed", { reason = why }) end
    Util.log("group", group.id, "made by", Util.playerKey(player), "with", #group.members, "members")
    Messaging.appendOwn(player, item, state, Groups.thread(group.id), SocialText.event("created", "", group.name), "delivered",
        { name = group.name, group = group.id }, "created")
    for _, n in ipairs(group.members) do
        if n ~= me then notice(group, me, n, "added", net) end
    end
    result(player, args, "created", { group = group.id, name = group.name, skipped = #skipped })
    GroupChats.push({ group.id })
end)

Net.onServer("groupAdd", function(player, args)
    local item, state, _, net = ready(player, args, true)
    if not item then return end
    local group, why = Groups.add(reg(), args.group, state.sim.number, args.number)
    if not group then return result(player, args, "failed", { reason = why }) end
    notice(group, state.sim.number, args.number, "added", net)
    result(player, args, "added", { number = args.number })
    GroupChats.push({ group.id })
end)

Net.onServer("groupRemove", function(player, args)
    local item, state, _, net = ready(player, args, true)
    if not item then return end
    local before = reg().byId[args.group]
    local name = before and before.name
    local group, why = Groups.remove(reg(), args.group, state.sim.number, args.number)
    if not group and why then return result(player, args, "failed", { reason = why }) end
    if args.number ~= state.sim.number and before then
        notice({ id = args.group, name = name }, state.sim.number, args.number, "removed", net)
    end
    result(player, args, "removed", { number = args.number })
    GroupChats.push({ args.group })
end)

Net.onServer("groupLeave", function(player, args)
    local item, state = ready(player, args, false)
    if not item then return end
    local group, why = Groups.leave(reg(), args.group, state.sim.number)
    if not group and why then return result(player, args, "failed", { reason = why }) end
    result(player, args, "left")
    GroupChats.push({ args.group })
end)

-- A text to everyone in the group. The sender's thread gets one line; the result says how many got it now.
Net.onServer("groupText", function(player, args)
    local item, state, _, net = ready(player, args, true)
    if not item then return end
    GroupChats.syncAuto(player)
    local me = state.sim.number
    local group = reg().byId[args.group]
    if not group then return result(player, args, "failed", { reason = "noGroup" }) end
    if not Groups.isMember(group, me, Util.playerKey(player)) then return result(player, args, "failed", { reason = "notMember" }) end
    local counts = { delivered = 0, queued = 0, failed = 0 }
    for _, n in ipairs(Groups.recipients(group, me, Social.numberOf)) do
        local status = Messaging.route({ from = me, to = n, body = args.body, group = group.id, groupName = group.name }, net)
        counts[status] = (counts[status] or 0) + 1
    end
    local status = counts.queued > 0 and "queued" or "delivered"
    Messaging.appendOwn(player, item, state, Groups.thread(group.id), args.body, status, { name = group.name, group = group.id })
    result(player, args, "sent", counts)
end)

-- Every ten minutes: faction and safehouse changes made in the game's own menus reach the groups.
Events.EveryTenMinutes.Add(Util.safe("group sync", function()
    if isClient() then return end
    local changed = {}
    for _, p in ipairs(Util.players()) do
        for _, id in ipairs(GroupChats.syncAuto(p)) do changed[#changed + 1] = id end
    end
    GroupChats.push(changed)
end))

return GroupChats
