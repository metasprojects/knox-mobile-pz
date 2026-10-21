-- Server: Motormouth Bravo pagers (1993 hardware). Numbers come from the SIM registry; pages ride the phones' text
-- path (a phone's "sendText" to a pager number, or the Messages app's "Send page"), through the same queue.
-- The client only asks ("pagerSetting"); the server checks the pager is in the player's inventory and does the rest.
local Pager = require "KnoxMobile/Core/Pager"
local Sim = require "KnoxMobile/Core/Sim"
local Rng = require "KnoxMobile/Core/Rng"
local MessageQueue = require "KnoxMobile/Core/MessageQueue"
local Protocol = require "KnoxMobile/Core/Protocol"
local Phones = require "KnoxMobile/Game/Phones"
local Util = require "KnoxMobile/Game/Util"
local Net = require "KnoxMobile/Game/Net"
local State = require "KnoxMobile/State"
local Messaging = require "KnoxMobile/Messaging"

local Pagers = {}
Pagers.TYPE = "KnoxMobile.Pager"
Pagers.MODEL = { antenna = Pager.ANTENNA } -- what WorldModel.locatePlayer needs to place a pager on the network

local KEYS = { on = true, alert = true, markRead = true, battery = true }
Protocol.register({
    pagerSetting = function(args)
        if type(args.pagerId) ~= "number" then return false, "pagerId must be a number" end
        if not KEYS[args.key] then return false, "unknown pager setting" end
        if args.key == "alert" and args.value ~= "beep" and args.value ~= "vibrate" then return false, "alert is beep or vibrate" end
        if args.key == "battery" and type(args.value) ~= "number" then return false, "battery must be an item id" end
        return true
    end,
})

local function registry()
    local md = State.get()
    if type(md.pagers) ~= "table" then md.pagers = {} end -- pager number -> true
    return md.pagers
end

function Pagers.isPagerNumber(number) return number ~= nil and registry()[number] == true end

function Pagers.state(item)
    local md = item:getModData()
    md[Phones.KEY] = Pager.normalise(md[Phones.KEY])
    return md[Phones.KEY]
end

-- "Motormouth Bravo Pager: (502) 555-0134", the way SIM cards are named.
local function nameIt(item, number)
    local ok, base = pcall(getItemNameFromFullType, Pagers.TYPE)
    if not ok or type(base) ~= "string" or base == "" then base = "Motormouth Bravo Pager" end
    item:setName(Util.text("IGUI_ItemWithDisplayName", "%1: %2", base, number))
end

-- Gives a pager its number the first time it is switched on.
function Pagers.activate(item)
    local st = Pagers.state(item)
    if st.number then return st.number end
    local rng = Rng.new(tostring(State.get().seed) .. ":pager:" .. tostring(item:getID()) .. ":" .. tostring(Util.nowMinutes()))
    st.number = Sim.issueNumber(State.get().numbers, rng)
    registry()[st.number] = true
    nameIt(item, st.number)
    return st.number
end

local function pagersOf(player)
    local out = {}
    local list = player:getInventory():getAllTypeRecurse(Pagers.TYPE)
    for i = 0, list:size() - 1 do out[#out + 1] = list:get(i) end
    return out
end

-- The online player carrying a working pager with this number.
local function findPager(number)
    for _, p in ipairs(Util.players()) do
        for _, item in ipairs(pagersOf(p)) do
            local st = Pagers.state(item)
            if st.number == number and Pager.canReceive(st) then return p, item, st end
        end
    end
    return nil
end

-- One page onto the pager in a player's hands: stored, saved, a beep the zombies hear (or a buzz), and the display.
local function arrive(player, item, st, rec)
    local day, minute = Messaging.stamp()
    Pager.addPage(st, rec.from, rec.body, day, minute)
    Phones.save(item, player)
    local radius = Pager.alertRadius(st, Phones.inBag(player, item), Util.settings().NoiseMultiplier)
    if radius >= 1 then
        addSound(player, math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ()), radius, radius)
    end
    Net.toClient(player, "page", { pagerId = item:getID(), body = rec.body, alert = st.alert, unread = Pager.unread(st) })
end

-- A phone pages a pager number. Returns "delivered" | "queued" | "failed", then a reason on failure.
function Pagers.send(player, phone, to, body)
    if not Pagers.isPagerNumber(to) then return "failed", "notPager" end
    local state, model = Phones.get(phone)
    if not Messaging.usable(state) then return "failed", "phoneOff" end
    if state.security.locked then return "failed", "locked" end
    local clean, why = Pager.cleanPage(body)
    if not clean then return "failed", why end
    local located, senderNet = Messaging.service(player, model)
    if not located.network then return "failed", "noService" end
    local rPlayer, rItem, rState = findPager(to)
    local recipientNet = rPlayer and select(2, Messaging.service(rPlayer, Pagers.MODEL)) or nil
    local status, rec = MessageQueue.send(State.get().queue, { from = state.sim.number, to = to, body = clean },
        senderNet, recipientNet, { queueMessages = Util.settings().QueueMessages }, Util.nowMinutes())
    if status == "failed" then return status, rec end
    if status == "delivered" then arrive(rPlayer, rItem, rState, rec) end
    local day, minute = Messaging.stamp()
    Messaging.appendTo(state, to, { day = day, minute = minute, inbound = false, body = clean, status = status, page = true })
    Phones.save(phone, player)
    return status
end

-- Queued pages reach a player's pagers once they are on and on the sender's network; dead batteries switch off.
function Pagers.tickPlayer(player, now)
    local q = State.get().queue
    for _, item in ipairs(pagersOf(player)) do
        local st = Pagers.state(item)
        if Pager.tick(st, now) then
            Phones.save(item, player)
            Net.toClient(player, "page", { pagerId = item:getID(), dead = true })
        elseif Pager.canReceive(st) and MessageQueue.pendingFor(q, st.number) > 0 then
            local _, net = Messaging.service(player, Pagers.MODEL)
            for _, rec in ipairs(MessageQueue.deliverFor(q, st.number, net, now)) do arrive(player, item, st, rec) end
        end
    end
end

Net.onServer("pagerSetting", function(player, args)
    local item = Phones.findById(player, args.pagerId)
    if not item or item:getFullType() ~= Pagers.TYPE then return end
    local st = Pagers.state(item)
    Pager.tick(st, Util.nowMinutes())
    if args.key == "on" then
        if args.value == true then
            if st.charge <= 0 then Net.toClient(player, "page", { pagerId = item:getID(), dead = true }); return end
            Pagers.activate(item)
            st.on = true
        else
            st.on = false
        end
    elseif args.key == "alert" then
        st.alert = args.value
    elseif args.key == "markRead" then
        Pager.markRead(st)
    elseif args.key == "battery" then
        local battery = Phones.findById(player, args.value)
        if not battery or battery:getFullType() ~= "Base.Battery" then return end
        if not Pager.insertBattery(st, battery:getCurrentUsesFloat()) then return end
        local c = battery:getContainer()
        if c then
            c:Remove(battery)
            if isServer() then sendRemoveItemFromContainer(c, battery) end
        end
    end
    Phones.save(item, player)
    Net.toClient(player, "pagerState", { pagerId = item:getID(), number = st.number, on = st.on })
end)

Events.EveryTenMinutes.Add(Util.safe("pagers", function()
    local now = Util.nowMinutes()
    for _, p in ipairs(Util.players()) do Pagers.tickPlayer(p, now) end
end))

return Pagers
