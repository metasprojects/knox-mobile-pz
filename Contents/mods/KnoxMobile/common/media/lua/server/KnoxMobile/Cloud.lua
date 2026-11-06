-- Server: Knox Cloud (0.3.0). While the carrier is on the air, a phone with service can back up its SIM's contacts and
-- its owner's own notes and voice memos ("cloudBackup", Settings), and a later phone of the same player (a new
-- character in single player, the same account on a server) can restore them ("cloudRestore"). When the carrier
-- dies, so does the cloud: what's in it can't be reached. Saved in the world's global ModData: cloud[account] =
-- { contacts, notes, memos, day }.
local Net = require "KnoxMobile/Game/Net"
local Util = require "KnoxMobile/Game/Util"
local State = require "KnoxMobile/State"
local Phones = require "KnoxMobile/Game/Phones"
local Protocol = require "KnoxMobile/Core/Protocol"
local Messaging = require "KnoxMobile/Messaging"
local WorldModel = require "KnoxMobile/Game/WorldModel"

local Cloud = {}
KnoxMobile.Cloud = Cloud

Protocol.register({
    cloudBackup = function(args) return type(args.phoneId) == "number", "phoneId must be a number" end,
    cloudRestore = function(args) return type(args.phoneId) == "number", "phoneId must be a number" end,
})

-- Who the cloud account belongs to: the player slot in single player (outlives each character), the account online.
function Cloud.account(player)
    if Util.isSingleplayer() then return "sp:" .. tostring(player:getPlayerNum()) end
    return "mp:" .. tostring(player:getUsername())
end

local function notify(player, event, n) Net.toClient(player, "notify", { kind = "cloud", event = event, number = n }) end

-- The phone, if it can reach the cloud now (service, a carrier on the air), else nil after telling the player why.
local function reachable(player, phoneId)
    local item = Phones.findById(player, phoneId)
    if not item or not Phones.isPhone(item) then return nil end
    local state, model = Phones.get(item)
    if not (state and state.power and state.power.on and state.sim) or state.security.locked then return nil end
    if not WorldModel.carrierUp() then notify(player, "down"); return nil end
    if not Messaging.service(player, model).network then notify(player, "noService"); return nil end
    return item, state
end

local function mine(list)
    local out = {}
    for _, e in ipairs(list or {}) do
        if e.mine then out[#out + 1] = { body = e.body, day = e.day, minute = e.minute, mine = true } end
    end
    return out
end

Net.onServer("cloudBackup", function(player, args)
    local item, state = reachable(player, args.phoneId)
    if not item then return end
    local md = State.get()
    if type(md.cloud) ~= "table" then md.cloud = {} end
    local contacts = {}
    for i, c in ipairs(state.sim.contacts or {}) do contacts[i] = { name = c.name, number = c.number } end
    md.cloud[Cloud.account(player)] = { contacts = contacts, notes = mine(state.contents.notes),
        memos = mine(state.contents.memos), day = (Messaging.stamp()) }
    notify(player, "saved", #contacts)
end)

Net.onServer("cloudRestore", function(player, args)
    local item, state = reachable(player, args.phoneId)
    if not item then return end
    local saved = type(State.get().cloud) == "table" and State.get().cloud[Cloud.account(player)]
    if not saved then notify(player, "empty"); return end
    local n = 0
    state.sim.contacts = state.sim.contacts or {}
    local have = {}
    for _, c in ipairs(state.sim.contacts) do have[c.number] = true end
    for _, c in ipairs(saved.contacts or {}) do
        if not have[c.number] then state.sim.contacts[#state.sim.contacts + 1] = { name = c.name, number = c.number }; n = n + 1 end
    end
    for _, key in ipairs({ "notes", "memos" }) do
        state.contents[key] = state.contents[key] or {}
        local bodies = {}
        for _, e in ipairs(state.contents[key]) do bodies[e.body or ""] = true end
        for _, e in ipairs(saved[key] or {}) do
            if not bodies[e.body or ""] then state.contents[key][#state.contents[key] + 1] = e; n = n + 1 end
        end
    end
    Phones.save(item, player)
    notify(player, "restored", n)
end)

return Cloud
