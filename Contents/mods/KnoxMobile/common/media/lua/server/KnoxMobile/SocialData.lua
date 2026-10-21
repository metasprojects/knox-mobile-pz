-- Server: shared pieces of the community features (group chats, carrier messages, Classifieds, find my crew, SOS).
-- Their data lives in the world ModData (State, key "social"), as plain tables:
--   groups  = Core/Groups registry          numbers = { [player key] = the number they text from }
--   board   = Core/Classifieds board        carrier = Core/Carrier state       sos = { [player key] = minutes }
local Groups = require "KnoxMobile/Core/Groups"
local Classifieds = require "KnoxMobile/Core/Classifieds"
local Carrier = require "KnoxMobile/Core/Carrier"
local Phones = require "KnoxMobile/Game/Phones"
local Util = require "KnoxMobile/Game/Util"
local State = require "KnoxMobile/State"
local Messaging = require "KnoxMobile/Messaging"

local Social = {}

function Social.data()
    local md = State.get()
    local s = md.social
    if type(s) ~= "table" then s = {}; md.social = s end
    if type(s.groups) ~= "table" or type(s.groups.byId) ~= "table" then s.groups = Groups.newRegistry() end
    if type(s.numbers) ~= "table" then s.numbers = {} end
    if type(s.board) ~= "table" or type(s.board.posts) ~= "table" then s.board = Classifieds.new() end
    if type(s.board.last) ~= "table" then s.board.last = {} end
    if type(s.carrier) ~= "table" then s.carrier = Carrier.new() end
    if type(s.sos) ~= "table" then s.sos = {} end
    return s
end

-- Read requests (lists) at most once per `ms` real milliseconds per player and command, whatever a client sends.
local lastAsk = {}
function Social.throttle(player, command, ms)
    local key = Util.playerKey(player) .. ":" .. command
    local now = getTimestampMs()
    if lastAsk[key] and now >= lastAsk[key] and now - lastAsk[key] < ms then return false end
    lastAsk[key] = now
    return true
end

-- The phone a command names: in the player's inventory, on, with a SIM and battery, not broken, and unlocked unless
-- allowLocked (an SOS works from the lock screen). Returns item, state, model | nil, reason.
function Social.phone(player, args, allowLocked)
    local item = args and type(args.phoneId) == "number" and Phones.findById(player, args.phoneId)
    if not item or not Phones.isPhone(item) then return nil, "noPhone" end
    local state, model = Phones.get(item)
    if not (state and state.sim and state.sim.number) then return nil, "noSim" end
    if not Messaging.usable(state) then return nil, "phoneOff" end
    if state.security.locked and not allowLocked then return nil, "locked" end
    return item, state, model
end

-- Remembers which number this player texts from: their own SIM when it is in a working phone, else the first
-- working phone with a SIM. Automatic groups (faction, safehouse) reach players through it.
function Social.track(player)
    local key = Util.playerKey(player)
    local own = State.get().players[key]
    own = own and own.number
    local best = nil
    for _, item in ipairs(Phones.inventoryPhones(player)) do
        local st = Phones.get(item)
        if Messaging.usable(st) then
            if st.sim.number == own then best = own; break end
            best = best or st.sim.number
        end
    end
    if best then Social.data().numbers[key] = best end
    return best
end

function Social.numberOf(key)
    local n = Social.data().numbers[key]
    if n then return n end
    local p = State.get().players[key]
    return p and p.number or nil
end

-- Numbers that belong to players (not the story's family and survivors): seen in a working phone, or a
-- character's own SIM. SOS texts only go to these, so they never pile up in the queue for nobody.
function Social.knownNumbers()
    local set = {}
    for _, n in pairs(Social.data().numbers) do set[n] = true end
    for _, p in pairs(State.get().players) do if p.number then set[p.number] = true end end
    for _, p in ipairs(Util.players()) do
        for _, item in ipairs(Phones.inventoryPhones(p)) do
            local st = Phones.get(item)
            if st and st.sim and st.sim.number then set[st.sim.number] = true end
        end
    end
    return set
end

-- The game's faction and safehouse for this player, as Core/Groups.syncAuto wants them. Build 42: the owner is not
-- in getPlayers(), so both are listed. Nil outside multiplayer or without one.
local function members(owner, list)
    local keys = { owner }
    for i = 0, list:size() - 1 do keys[#keys + 1] = list:get(i) end
    return keys
end

function Social.faction(player)
    if Faction == nil then return nil end
    local ok, info = pcall(function()
        local f = Faction.getPlayerFaction(player)
        if not f then return nil end
        return { id = f:getName(), name = f:getName(), keys = members(f:getOwner(), f:getPlayers()) }
    end)
    return ok and info or nil
end

function Social.safehouse(player)
    if SafeHouse == nil then return nil end
    local ok, info = pcall(function()
        local h = SafeHouse.hasSafehouse(player)
        if not h then return nil end
        local title = h:getTitle()
        if not title or title == "" then title = "Safehouse" end
        return { id = h:getId(), name = title, keys = members(h:getOwner(), h:getPlayers()) }
    end)
    return ok and info or nil
end

return Social
