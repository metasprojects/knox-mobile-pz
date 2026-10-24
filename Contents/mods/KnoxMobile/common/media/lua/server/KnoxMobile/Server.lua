-- Server: command handlers, timers, repeaters, calls, new characters, phones on zombies (spec §7, §9.7, §13).
-- Runs on a dedicated server and in single player.
local Calls = require "KnoxMobile/Core/Calls"
local Sim = require "KnoxMobile/Core/Sim"
local MessageQueue = require "KnoxMobile/Core/MessageQueue"
local Repeaters = require "KnoxMobile/Core/Repeaters"
local Rng = require "KnoxMobile/Core/Rng"
local Loot = require "KnoxMobile/Core/Loot"
local Story = require "KnoxMobile/Core/Story"
local FamilyCall = require "KnoxMobile/Core/FamilyCall"
local Damage = require "KnoxMobile/Core/Damage"
local AudioGear = require "KnoxMobile/Core/AudioGear"
local Upkeep = require "KnoxMobile/Core/Upkeep"
local Power = require "KnoxMobile/Core/Power"
local ItemIds = require "KnoxMobile/ItemIds"
local Accessories = require "KnoxMobile/Data/Accessories"
local Phones = require "KnoxMobile/Game/Phones"
local WorldModel = require "KnoxMobile/Game/WorldModel"
local Util = require "KnoxMobile/Game/Util"
local ALife = require "KnoxMobile/Game/ALife"
local FactionChatter = require "KnoxMobile/Core/FactionChatter"
local Names = require "KnoxMobile/Story/Names"
local PhoneState = require "KnoxMobile/Core/PhoneState"
local Net = require "KnoxMobile/Game/Net"
local State = require "KnoxMobile/State"
local Messaging = require "KnoxMobile/Messaging"
local CameraSpec = require "KnoxMobile/Core/CameraSpec"
local PhoneTick = require "KnoxMobile/PhoneTick"
local HuntWorld = require "KnoxMobile/Hunt"
local Pagers = require "KnoxMobile/Pagers"
local Tick = require "KnoxMobile/Game/Tick"
local Recordings = require "KnoxMobile/Core/Recordings"
local Mod = require "KnoxMobile/Core/Mod"
local Machine = require "KnoxMobile/Core/Machine"
local Payphones = require "KnoxMobile/Payphones"

local Server = {}
KnoxMobile.Server = Server

local function phoneOf(player, args)
    local item = args and args.phoneId and Phones.findById(player, args.phoneId)
    if not item or not Phones.isPhone(item) then return nil end
    local state, model = Phones.get(item)
    return item, state, model
end

local function broadcastWorld() Net.toAll("world", State.worldMessage()) end

-- setup(item) runs before the item is sent to the client, so its name and data arrive with it.
local function addItem(player, fullType, setup)
    local inv = player:getInventory()
    local item = inv:AddItem(fullType)
    if item then
        if setup then setup(item) end
        if isServer() then sendAddItemToContainer(inv, item) end
    end
    return item
end
Server.addItem = addItem

-- Into the character's wallet when they carry one (spec §4.5, "starts with their own SIM in their wallet").
local function addToWallet(player, fullType, setup)
    local wallet = player:getInventory():getFirstEvalRecurse(function(it)
        return tostring(it:getFullType()):find("^Base%.Wallet") ~= nil and it.getInventory ~= nil
    end)
    -- On a server the new character's wallet may not be on the client yet, and an item put in it never arrived
    -- (second pass: the hosted character had no SIM): there it goes in the main inventory.
    if not wallet or isServer() then return addItem(player, fullType, setup) end
    local inv = wallet:getInventory()
    local item = inv:AddItem(fullType)
    if item then
        if setup then setup(item) end
        if isServer() then sendAddItemToContainer(inv, item) end
    end
    return item
end

-- A phone of your own comes with your own SIM already in it: the SIM you carry (in your wallet or bag)
-- moves into the phone. A phone that already has a SIM, or a player with no SIM of their own, is left alone.
local function fitOwnSim(player, phone)
    local state = Phones.get(phone)
    if not state or state.sim then return end
    local key = Util.playerKey(player)
    local simItem = player:getInventory():getFirstEvalRecurse(function(it)
        return Phones.isSim(it) and Phones.simData(it).owner == key
    end)
    if not simItem then return end
    state.sim = PhoneState.copy(Phones.simData(simItem))
    local c = simItem:getContainer()
    if c then
        c:Remove(simItem)
        sendRemoveItemFromContainer(c, simItem)
    end
end
Server.fitOwnSim = fitOwnSim

-- Single player, once per character: an older build keyed this character by "Bob", its username or its player number
-- (Util.playerKey). The own SIMs it carries under one of those keys become its own again, with what was keyed the
-- same way: its number and identity, its family hunt site, its repeaters and its Classifieds listings (r8: an r7 save
-- got a third own SIM). Keys no SIM it carries uses are left alone: they may be a dead character's.
function Server.adoptLegacy(player)
    local md = player:getModData()
    local legacy = md.KnoxMobileLegacy
    md.KnoxMobileLegacy = nil
    if type(legacy) ~= "table" then return end
    local key = Util.playerKey(player)
    local old, found = {}, {}
    for _, k in pairs(legacy) do
        if type(k) == "string" and k ~= "" and k ~= key then old[k] = true end
    end
    local function take(sim)
        if type(sim) == "table" and sim.owner and old[sim.owner] then
            found[sim.owner] = true
            sim.owner = key
            return true
        end
        return false
    end
    local loose = player:getInventory():getAllEvalRecurse(function(it) return Phones.isSim(it) end)
    for i = 0, loose:size() - 1 do take(Phones.simData(loose:get(i))) end
    for _, phone in ipairs(Phones.inventoryPhones(player)) do
        local state = Phones.get(phone)
        if state and take(state.sim) then Phones.save(phone, player) end
    end
    if Util.isEmpty(found) then return end
    local st = State.get()
    local board = require("KnoxMobile/SocialData").data().board
    for k in pairs(found) do
        if st.players[k] ~= nil and st.players[key] == nil then st.players[key] = st.players[k] end
        st.players[k] = nil
        for site, v in pairs(st.huntTaken) do if v == k then st.huntTaken[site] = key end end
        for _, rep in ipairs(st.repeaters) do if rep.owner == k then rep.owner = key end end
        if board then
            for _, post in ipairs(board.posts or {}) do if post.key == k then post.key = key end end
        end
        Util.log("adopted what an older build keyed as", k, "for", key)
    end
end

Events.OnGameStart.Add(Util.safe("adopt older keys", function()
    if not Util.isSingleplayer() then return end
    for _, p in ipairs(Util.players()) do Util.playerKey(p); Server.adoptLegacy(p) end
end))

local function giveStartingPhone(player, model, rng, color)
    if not model then return end
    color = color or (rng and rng:pick(model.colors)) or model.colors[1]
    addItem(player, ItemIds.full(ItemIds.phone(model, color)), function(phone)
        phone:getModData().KnoxMobileOrigin = "start"
        Phones.get(phone)
        fitOwnSim(player, phone)
    end)
end

-- Join -----------------------------------------------------------------------------------------
Net.onServer("hello", function(player)
    -- Nobody is cranking on join. A save or disconnect mid-crank leaves the flag on, and it would charge forever.
    player:getModData().KnoxMobileCranking = nil
    Net.toClient(player, "world", State.worldMessage())
    local passwords = player:getModData().KnoxMobilePasswords
    if type(passwords) == "table" then Net.toClient(player, "passwords", { list = passwords }) end
    Messaging.deliverTo(player)
end)

-- Multiplayer: everyone hears whose phone screen is on, for the glow others see (client/KnoxMobile/Glow.lua).
local function tellGlow(player, on)
    if not isServer() then return end
    local id = player:getOnlineID()
    for _, p in ipairs(Util.players()) do
        if p ~= player then Net.toClient(p, "screenGlow", { id = id, on = on }) end
    end
end

Net.onServer("activity", function(player, args)
    local key = Util.playerKey(player)
    if args.closed then
        if PhoneTick.activity[key] then tellGlow(player, false) end
        PhoneTick.activity[key] = nil
        return
    end
    if not PhoneTick.activity[key] then tellGlow(player, true) end
    local allowed = { idle = true, screen = true, audio = true, games = true, video = true }
    PhoneTick.activity[key] = {
        phoneId = args.phoneId, state = allowed[args.state] and args.state or "screen",
        flashlight = args.flashlight == true, noService = args.noService == true,
    }
end)

Net.onServer("pickedUp", function(player, args)
    local item = args.phoneId and Phones.findById(player, args.phoneId)
    if item and Phones.isPhone(item) then
        PhoneTick.catchUp(player, item)
        Messaging.deliverTo(player)
    end
end)

-- Texts ----------------------------------------------------------------------------------------
Net.onServer("sendText", function(player, args)
    local item = phoneOf(player, args)
    if not item then return end
    -- A pager number (or the Messages app's "Send page") goes to the pager path: numbers only.
    if args.page == true or Pagers.isPagerNumber(args.to) then
        local status, reason = Pagers.send(player, item, args.to, args.body)
        Net.toClient(player, "textResult", { status = status, reason = reason, to = args.to, page = true })
        return
    end
    local status, reason = Messaging.sendText(player, item, args.to, args.body)
    Net.toClient(player, "textResult", { status = status, reason = reason, to = args.to })
end)

-- Phone settings: battery saver, sound mode, PIN set and unlock (spec §6.2, §8.5) ------------------
local SOUND_MODES = { ring = true, vibrate = true, silent = true }
local AUDIO_ROUTES = { speaker = true, earbuds = true, oneEarbud = true, headphones = true }
local RINGTONES = { classic = true, chiptune = true, custom = true }
local Composer = require "KnoxMobile/Core/Composer"
local WALLPAPERS = 6

Net.onServer("phoneSetting", function(player, args)
    local item, state, model = phoneOf(player, args)
    if not item then return end
    local now = Util.nowMinutes()
    if args.key == "saver" then
        state.power.saver = args.value == true and (model.family == "ModernAndroid" or model.family == "ModernPear")
    elseif args.key == "soundMode" and SOUND_MODES[args.value] then
        state.look.soundMode = args.value
    elseif args.key == "setPin" then
        if state.security.locked or not Phones.pinsOn() then return end
        if args.value == nil or args.value == "" then
            state.security.pin = nil
        elseif type(args.value) == "string" and args.value:match("^%d%d%d%d$") then
            state.security.pin = args.value
        end
    elseif args.key == "lock" then
        if state.security.pin and Phones.pinsOn() then state.security.locked = true end
    elseif args.key == "unlock" then
        -- The PIN pad only shows on a running phone. An off found phone has no PIN yet, so "unlock" would skip it.
        if not state.power.on then return end
        local sec = state.security
        local result
        if sec.lockoutUntil and now < sec.lockoutUntil then
            result = "lockedOut"
        elseif not sec.pin or args.value == sec.pin then
            sec.locked, sec.failedAttempts = false, 0
            result = "ok"
        else
            sec.failedAttempts = (sec.failedAttempts or 0) + 1
            if sec.failedAttempts >= 5 then sec.lockoutUntil, sec.failedAttempts = now + 60, 0 end
            result = "wrong"
        end
        Net.toClient(player, "unlockResult", { phoneId = item:getID(), result = result })
    elseif args.key == "photo" and type(args.value) == "string" and #args.value > 0 and #args.value <= 160 then
        -- A photo of your own without the Java part (Photos: + Take a photo): its caption, kept on the phone, as
        -- many as the phone's memory holds (Core/CameraSpec).
        state.contents.photos = state.contents.photos or {}
        local spec = CameraSpec.forFamily(model.family)
        local full = #state.contents.photos >= (spec and spec.max or 50)
        Net.toClient(player, "photoSaved", { ok = not full, phoneId = item:getID() })
        if full then return end
        local day, minute = Messaging.stamp()
        table.insert(state.contents.photos, { text = args.value, day = day, minute = minute })
    elseif args.key == "audioRoute" and AUDIO_ROUTES[args.value] then
        -- The gear has to fit this phone's plug (spec §9.2): 3.5 mm until about 2016, Pear plug, USB-C, wireless.
        local gear, dongle = Phones.audioGear(player)
        if AudioGear.choose(model, gear, args.value, { dongle = dongle }) then
            state.look.audioRoute = args.value
        else
            Net.toClient(player, "notify", { kind = "audio", event = "noGear", route = args.value, phoneId = item:getID() })
            return
        end
    elseif args.key == "ringtone" and RINGTONES[args.value] then
        if args.value == "chiptune" and model.family == "SegmentLCD" then return end
        if args.value == "custom" and not state.look.tune then return end
        state.look.ringtone = args.value
    elseif args.key == "tune" and type(args.value) == "string" and #args.value <= 240 then
        -- The ringtone composer (Core/Composer): a tune that parses becomes this phone's ringtone.
        if not Composer.parse(args.value) then return end
        state.look.tune, state.look.ringtone = args.value, "custom"
    elseif args.key == "wallpaper" and tonumber(args.value) then
        local family = Phones.registry:family(model.family)
        local n = math.floor(tonumber(args.value))
        if not (family and family.wallpapers) or n < 0 or n > WALLPAPERS then return end
        state.look.wallpaper = n > 0 and n or nil
        state.look.wallpaperPhoto = nil
    elseif args.key == "wallpaperPhoto" and CameraSpec.validId(args.value) then
        -- One of the phone's own photos as its wallpaper (Photos: Set as wallpaper).
        local family = Phones.registry:family(model.family)
        local have = false
        for _, p in ipairs(state.contents.photos or {}) do if p.id == args.value then have = true end end
        if not (family and family.wallpapers and have) then return end
        state.look.wallpaperPhoto = args.value
    elseif args.key == "volume" and tonumber(args.value) then
        state.look.volume = math.max(0, math.min(1, tonumber(args.value)))
    elseif args.key == "ice" then
        -- In case of emergency (0.2.0): one of the SIM's contacts, shown on the lock screen for whoever finds the phone.
        state.ice = nil
        for _, c in ipairs(state.sim and state.sim.contacts or {}) do
            if c.number == args.value then state.ice = { name = c.name, number = c.number } end
        end
    elseif args.key == "markRead" then
        for _, conv in ipairs(state.contents.texts) do
            for _, m in ipairs(conv.messages) do m.unread = nil end
        end
    else
        return
    end
    Phones.save(item, player)
end)

-- Calls (spec §9.7) ----------------------------------------------------------------------------

local function contactName(state, number)
    for _, c in ipairs(state.sim and state.sim.contacts or {}) do
        if c.number == number then return c.name end
    end
    return nil
end

local function payphoneNumber(md, number)
    for _, n in pairs(md.payphones or {}) do
        if n == number then return true end
    end
    return false
end

-- A number no player has (Core/FamilyCall): your family pick up now and then, ring out to voicemail, or can't be
-- reached; other numbers the world knows ring out or can't be reached; a payphone rings with nobody there; a number
-- nobody was ever given isn't in service. A call that rings goes to the phone as captions ("callScripted").
local function npcCall(player, item, state, to, fail)
    local md = State.get()
    local now = Util.nowDay() + (md.storyShift or 0)
    local rng = Rng.new(tostring(md.seed) .. ":ring:" .. tostring(to) .. ":" .. Util.nowMinutes())
    local plan = md.story[state.sim.number]
    local member = plan and FamilyCall.member(plan, to)
    local label = contactName(state, to)
    local kind, lines
    if member then
        local person = plan.hunt and plan.hunt.people and plan.hunt.people[member]
        local first = person and person.first or label or "me"
        local you = plan.hunt and plan.hunt.player and plan.hunt.player.first or "honey"
        local place = Messaging.familyPlace(plan)
        local function fill(s)
            s = s:gsub("{label}", function() return label or first end)
            s = s:gsub("{first}", function() return first end)
            s = s:gsub("{you}", function() return you end)
            s = s:gsub("{place}", function() return place end)
            return s
        end
        kind, lines = FamilyCall.outcome(rng, plan, member, now, fill, Util.settings().NetworkCongestion == false)
    elseif payphoneNumber(md, to) then
        kind = "noAnswer"
    elseif md.numbers.issued[to] then
        local odds = FamilyCall.OTHER
        if Util.settings().NetworkCongestion == false then odds = FamilyCall.withoutBusy(odds) end
        kind = FamilyCall.roll(rng, odds)
        if kind == "voicemail" then lines = FamilyCall.GENERIC_VOICEMAIL end
    else
        return fail("notInService")
    end
    if kind == "busy" then return fail("circuitsBusy") end
    if kind == "unreachable" then return fail("unreachable") end
    Messaging.logCall(player, item, to, false)
    Util.log("call from", state.sim.number, "to", to, ":", kind)
    Net.toClient(player, "callScripted", { to = to, kind = kind, lines = lines, name = label })
end

-- 911, the state's line, 411 and Knox County's businesses (Core/Recordings): a recording, by the day. 411 reads out the
-- nearest town's numbers, and the journal keeps them.
local function recordingCall(player, item, to, rec, fail)
    if rec.kind == "notInService" then return fail("notInService") end
    Messaging.logCall(player, item, to, false)
    Util.log("call to", to, ":", rec.kind, "(recording)")
    Net.toClient(player, "callScripted", { to = to, kind = rec.kind, lines = rec.lines, name = rec.name })
    if rec.listings and KnoxMobile.Journal then
        local parts = {}
        for _, b in ipairs(rec.listings) do parts[#parts + 1] = b.name .. " " .. b.number end
        KnoxMobile.Journal.add(player, "411 gave me: " .. table.concat(parts, ", ") .. ".")
    end
end

Net.onServer("placeCall", function(player, args)
    local item, state, model = phoneOf(player, args)
    local function fail(reason)
        local from = state and state.sim and state.sim.number
        Util.log("call from", tostring(from or (model and model.id)), "to", tostring(args.to), "failed:", reason)
        -- A call that got as far as dialling goes in the phone's Recent calls as failed (r8: it wasn't listed).
        if from and reason ~= "phoneOff" then Messaging.logCall(player, item, args.to, false, true) end
        Net.toClient(player, "callFailed", { reason = reason, to = args.to })
    end
    if not item then return fail("noPhone") end
    if not state.sim or not state.sim.number then return fail("noSim") end
    if not state.power.on then return fail("phoneOff") end
    if not State.voiceEnabled() then return fail("noVoice") end
    local located = Messaging.service(player, model)
    if not located.network then return fail("noService") end
    local rec = Recordings.call(args.to, Util.nowDay(), Machine.town(player:getX(), player:getY()),
        Rng.new(tostring(State.get().seed) .. ":rec:" .. args.to .. ":" .. math.floor(Util.nowDay())))
    if rec then return recordingCall(player, item, args.to, rec, fail) end
    if WorldModel.callFails(Rng.new(Util.nowMinutes() .. ":" .. state.sim.number)) then return fail("circuitsBusy") end
    local rPlayer, rItem, _, rModel = Messaging.findNumber(args.to)
    if not rPlayer then return npcCall(player, item, state, args.to, fail) end
    local rLocated = Messaging.service(rPlayer, rModel)
    if rLocated.network ~= located.network then return fail("unreachable") end
    local call, why = Calls.start(State.calls, state.sim.number, args.to, getTimestampMs() / 1000)
    if not call then return fail(why) end
    call.callerKey, call.calleeKey = Util.playerKey(player), Util.playerKey(rPlayer)
    call.callerPhone, call.calleePhone = item:getID(), rItem:getID()
    Messaging.logCall(player, item, args.to, false)
    call.calleeLog = Messaging.logCall(rPlayer, rItem, state.sim.number, true)
    Net.toClient(player, "callRinging", { callId = call.id, to = args.to })
    Net.toClient(rPlayer, "incomingCall", { callId = call.id, from = state.sim.number, phoneId = rItem:getID() })
end)

local function playerByKey(key)
    for _, p in ipairs(Util.players()) do if Util.playerKey(p) == key then return p end end
    return nil
end

local function endCall(call, reason)
    for _, key in ipairs({ call.callerKey, call.calleeKey }) do
        local p = playerByKey(key)
        if p then Net.toClient(p, "callEnd", { callId = call.id, reason = reason }) end
    end
end

-- The first week's jammed network (sandbox Network congestion): a call between players can drop mid-word.
Server.dropCheckAt = 0
function Server.dropCalls(rng)
    if not Util.settings().NetworkCongestion then return end
    local day = Util.nowDay()
    if day >= 7 then return end
    for _, call in pairs(State.calls.byId) do
        if call.status == "active" and rng:chance(day < 3 and 0.05 or 0.025) then
            Calls.hangUp(State.calls, call.id, call.from)
            Util.log("call from", tostring(call.from), "to", tostring(call.to), "dropped (congestion)")
            endCall(call, "dropped")
        end
    end
end

Tick.add("dropped calls", function()
    if isClient() then return end
    local t = getTimestampMs()
    if t < Server.dropCheckAt then return end
    Server.dropCheckAt = t + 10000
    Server.dropCalls(Rng.new("drop:" .. tostring(t)))
end, 1000)

Net.onServer("answerCall", function(player, args)
    local key = Util.playerKey(player)
    local call = State.calls.byId[args.callId]
    if not call or call.calleeKey ~= key then return end
    Calls.answer(State.calls, call.id, call.to)
    if call.calleeLog then call.calleeLog.missed = false end
    Util.log("call from", tostring(call.from), "to", tostring(call.to), "connected")
    for _, k in ipairs({ call.callerKey, call.calleeKey }) do
        local p = playerByKey(k)
        if p then Net.toClient(p, "callStart", { callId = call.id, channel = call.channel }) end
    end
end)

Net.onServer("endCall", function(player, args)
    local call = args.callId and State.calls.byId[args.callId]
    if not call then return end
    local key = Util.playerKey(player)
    if key ~= call.callerKey and key ~= call.calleeKey then return end
    local number = key == call.callerKey and call.from or call.to
    Calls.hangUp(State.calls, call.id, number)
    endCall(call, "hungUp")
end)

-- Repeaters (spec §7.3) -------------------------------------------------------------------------
function Server.placeRepeater(player, square)
    local md = State.get()
    local id = "R" .. md.nextRepeater
    md.nextRepeater = md.nextRepeater + 1
    local grid = Util.powered(square)
    local rep = { id = id, x = square:getX(), y = square:getY(), z = square:getZ(), powered = grid, grid = grid,
        owner = Util.playerKey(player), private = false, condition = 100, battery = 0 }
    md.repeaters[#md.repeaters + 1] = rep
    Util.log("repeater", id, "placed at", rep.x, rep.y, rep.z, "powered", rep.powered)
    broadcastWorld()
    return rep
end

-- Called from timed actions (shared code) when they complete on the server -------------------------
-- A SIM going into a working phone, or a phone powering on, gets its waiting messages at once (spec §5.2 backlog).
function Server.deliverNow(player)
    Messaging.deliverTo(player)
end

function Server.activateSim(sim)
    local md = State.get()
    Sim.activate(sim, md.numbers, Rng.new(tostring(md.seed) .. ":sim:" .. tostring(Sim.issuedCount(md.numbers))))
    Util.log("activated SIM", sim.number)
end

-- A found phone's dead owner, made the first time it powers on (spec §5.1). The name comes from the
-- ID card the zombie carried when there was one. player (optional): who turned it on, for their journal.
function Server.fillFoundPhone(item, state, model, player)
    local md = item:getModData()
    local rng = Rng.new(tostring(State.get().seed) .. ":owner:" .. tostring(item:getID()))
    -- A birth date on their ID card (a PIN clue) sets how old they were.
    local born = tonumber(md.KnoxMobileBorn)
    local id = Story.identity(rng, { name = md.KnoxMobileOwnerName, female = md.KnoxMobileFemale, outfit = md.KnoxMobileOutfit,
        ageBand = born and Story.bandFor(93 - born) or nil })
    local nowDay, nowMinute = Messaging.stamp()
    local alife = type(md.KnoxMobileALife) == "table" and md.KnoxMobileALife or nil
    -- An A-Life NPC died just now, after weeks in the zone; an ordinary found phone's owner died around day 0.
    local deathDay = alife and math.max(0, nowDay) or rng:int(-3, 0)
    local dead = Story.deadPhone(rng, id, { family = model.family, deathDay = deathDay,
        foundAt = nowDay * 1440 + nowMinute })
    if alife then
        local extra = FactionChatter.build(rng, Story.fill, Names.male, { faction = alife.faction, owner = id.first,
            mates = alife.mates, firstDay = math.max(0, deathDay - 6), deathDay = dead.deathDay,
            deathMinute = dead.deathMinute, foundAt = nowDay * 1440 + nowMinute })
        dead.groupChats = dead.groupChats or {}
        table.insert(dead.groupChats, 1, extra.chat)
        dead.texts = dead.texts or {}
        for _, conv in ipairs(extra.texts) do table.insert(dead.texts, 1, conv) end
    end
    state.contents.texts = dead.texts or {}
    state.contents.calls = dead.calls or {}
    -- Its phone rang in its pocket (Ringing.lua): the calls nobody answered, just now, from the one who kept trying.
    if tonumber(md.KnoxMobileMissed) then
        local caller = dead.texts and dead.texts[1]
        for i = 1, math.min(20, md.KnoxMobileMissed * rng:int(2, 4)) do
            local at = math.max(0, nowDay * 1440 + nowMinute - i * rng:int(10, 40))
            table.insert(state.contents.calls, 1, { with = caller and caller.with or "mom", name = caller and caller.name or "Mom",
                day = math.floor(at / 1440), minute = Mod.floor(at, 1440), inbound = true, missed = true })
        end
    end
    state.contents.voicemails = dead.voicemails or {}
    state.contents.notes = dead.notes or {}
    -- A number to call (Core/Recordings): a local place's, written down the way people did.
    if rng:chance(0.4) then
        local b = rng:pick(Recordings.listings(id.hometown))
        local how = rng:pick({ "%s %s", "call %s %s", "%s - %s (ask for Dee)", "%s %s after 5", "refill: %s %s" })
        table.insert(state.contents.notes, { body = string.format(how, b.name, b.number) })
    end
    state.contents.groupChats = dead.groupChats
    state.owner = { kind = "generated", first = id.first, last = id.last, job = id.job.title, hometown = id.hometown,
        fromIdCard = md.KnoxMobileOwnerName ~= nil }
    state.story = { draft = dead.draft, lastApp = dead.lastApp, alarm = dead.alarm, photos = dead.photos, deathDay = dead.deathDay }
    if state.security.locked then state.security.pin = md.KnoxMobilePin or id.pin end
    Util.log("found phone owner:", id.first, id.last, "-", id.job.title, md.KnoxMobileOwnerName and "(from ID card)" or "")
    if player and KnoxMobile.Journal then KnoxMobile.Journal.foundPhone(player, state) end
end

-- Phones left charging in the world (spec §6.5, §13.7) --------------------------------------------------
function Server.worldCharge(item, square)
    State.get().worldChargers[tostring(item:getID())] = {
        x = square:getX(), y = square:getY(), z = square:getZ(), last = Util.nowMinutes(),
    }
end

local function worldItemOn(sq, id)
    local list = sq:getWorldObjects()
    for i = 0, list:size() - 1 do
        local item = list:get(i):getItem()
        if item and tostring(item:getID()) == id then return item, list:get(i) end
    end
    return nil
end

-- Every ten minutes: loaded squares charge their phones for the time since the last check (while the square
-- has power). A phone that is no longer there was picked up, and it drops off the list.
local function tickWorldChargers()
    local md = State.get()
    local ps = Util.powerSettings()
    local now = Util.nowMinutes()
    for id, entry in pairs(md.worldChargers) do
        local sq = getCell():getGridSquare(entry.x, entry.y, entry.z)
        if sq then
            local item, wo = worldItemOn(sq, id)
            if not item then
                md.worldChargers[id] = nil
            else
                local state, model = Phones.get(item)
                local minutes = math.max(0, math.min(now - (entry.last or now), 60 * 24 * 7))
                entry.last = now
                local changed = false
                if state and state.plug and Util.powered(sq) and minutes > 0 then
                    if state.power.on then Power.drain(state.battery, model, { state = "idle" }, minutes, ps) end
                    Power.charge(state.battery, model, "wall", minutes, {}, ps)
                    state.lastTick = now
                    changed = true
                end
                -- A phone left in the world keeps receiving texts while it has service (spec §4.7).
                if state and Messaging.deliverToItem(state, model, entry.x, entry.y) then changed = true end
                if changed and isServer() and wo.transmitCompleteItemToClients then wo:transmitCompleteItemToClients() end
            end
        end
    end
end

-- Noise from a ringing or playing phone. The server makes it, so every zombie nearby hears it.
local lastNoise = {}
Net.onServer("noise", function(player, args)
    local r = tonumber(args.radius)
    if not r or r <= 0 then return end
    -- At most one pulse a second per player (pulses come every few seconds), whatever a client sends.
    local key, now = Util.playerKey(player), getTimestampMs()
    if lastNoise[key] and now - lastNoise[key] < 1000 then return end
    lastNoise[key] = now
    r = math.min(r, 40)
    addSound(player, math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ()), r, r)
end)

-- The hidden radio behind phone audio (client Audio.lua): the server owns inventories, so it makes and
-- removes the item; the client tunes it.
Net.onServer("audioProxy", function(player, args)
    local inv = player:getInventory()
    local list = inv:getAllTypeRecurse("KnoxMobile.PhoneAudio")
    if args.on then
        if list:size() == 0 then addItem(player, "KnoxMobile.PhoneAudio") end
        return
    end
    for i = list:size() - 1, 0, -1 do
        local it = list:get(i)
        local c = it:getContainer()
        if c then
            c:Remove(it)
            if isServer() then sendRemoveItemFromContainer(c, it) end
        end
    end
end)

-- The Map app (client/KnoxMobile/Apps/Map.lua): the places this player's story has named so far.
Net.onServer("mapPlaces", function(player, args)
    local md = State.get()
    local key = Util.playerKey(player)
    local places = {}
    local mine = md.players[key]
    local plan = mine and md.story[mine.number]
    local h = plan and plan.hunt
    -- As soon as a text has named the place (second pass: it waited for the scene to be set).
    if h and (h.state ~= "waiting" or plan.placeTold) then
        places[#places + 1] = { kind = "family", name = h.name, x = h.x, y = h.y }
    end
    for _, q in pairs(md.quests) do
        if q.player == key and q.state ~= "waiting" then
            places[#places + 1] = { kind = "stash", name = q.name, x = q.x, y = q.y }
        end
    end
    -- Found phones on you whose family said where home was (TextBack): take them back.
    for _, it in ipairs(Phones.inventoryPhones(player)) do
        local st = Phones.get(it)
        local home = st and st.story and st.story.home
        if home and not home.returned and st.owner then
            places[#places + 1] = { kind = "home", name = st.owner.first, x = home.x, y = home.y }
        end
    end
    -- A phone off a dead A-Life NPC, on and in service (FactionWire): where its faction's people are, and where they
    -- are going tonight when a raid is on.
    local item = args and args.phoneId and Phones.findById(player, args.phoneId)
    if item and KnoxMobile.FactionWire then
        for _, p in ipairs(KnoxMobile.FactionWire.phones(player)) do
            if p.item == item then
                for _, m in ipairs(ALife.members(p.alife.factionId, 6)) do
                    places[#places + 1] = { kind = "faction", name = m.name, x = m.x, y = m.y }
                end
                local raid = ALife.raid()
                if raid and raid.factionId == p.alife.factionId and raid.x and raid.y then
                    places[#places + 1] = { kind = "raid", name = p.alife.faction, x = raid.x, y = raid.y }
                end
            end
        end
    end
    Net.toClient(player, "mapPlaces", { places = places })
end)

-- Drops and falls (spec §9.3) --------------------------------------------------------------------
local function damageSettings() return { damageMultiplier = Util.settings().DamageMultiplier } end

Net.onServer("dropped", function(player, args)
    local item, state, model = phoneOf(player, args)
    if not item then return end
    local result = Damage.rollDrop(Rng.new(tostring(item:getID()) .. ":drop:" .. Util.nowMinutes()), model, state, damageSettings())
    if result ~= "none" then Net.toClient(player, "notify", { kind = "damage", event = result, phoneId = item:getID() }) end
    Phones.save(item, player)
end)

Net.onServer("fell", function(player)
    for _, item in ipairs(Phones.inventoryPhones(player)) do
        local state, model = Phones.get(item)
        if state then
            local rng = Rng.new(tostring(item:getID()) .. ":fall:" .. Util.nowMinutes())
            local result = Damage.rollFall(rng, model, state, damageSettings(), Phones.inBag(player, item))
            if result ~= "none" then
                Net.toClient(player, "notify", { kind = "damage", event = result, phoneId = item:getID() })
                Phones.save(item, player)
            end
        end
    end
end)

-- Repeater upkeep from the world right-click menu (spec §7.3) ------------------------------------------
local REPEATER_REACH = 3

local function repeaterById(id)
    for _, rep in ipairs(State.get().repeaters) do if rep.id == id then return rep end end
    return nil
end

local function nearRepeater(player, rep)
    return math.abs(player:getX() - rep.x) <= REPEATER_REACH + 1 and math.abs(player:getY() - rep.y) <= REPEATER_REACH + 1
        and math.floor(player:getZ()) == rep.z
end

local function takeItem(item)
    local c = item:getContainer()
    if c then
        c:Remove(item)
        if isServer() then sendRemoveItemFromContainer(c, item) end
    end
end

Net.onServer("configureRepeater", function(player, args)
    local rep = repeaterById(args.id)
    if not rep or rep.owner ~= Util.playerKey(player) then return end
    if args.private and not Util.settings().AllowPrivateRepeaters then return end
    rep.private = args.private == true
    rep.password = rep.private and args.password or nil
    if rep.private then
        -- The owner always knows their own password.
        local md = player:getModData()
        if type(md.KnoxMobilePasswords) ~= "table" then md.KnoxMobilePasswords = {} end
        md.KnoxMobilePasswords[args.password] = true
        Net.toClient(player, "passwords", { list = md.KnoxMobilePasswords })
    end
    broadcastWorld()
end)

-- A loose car battery powers a repeater for a while (spec §7.3, "short runtime").
Net.onServer("repeaterBattery", function(player, args)
    local rep = repeaterById(args.id)
    if not rep or not nearRepeater(player, rep) then return end
    if args.attach then
        if (rep.battery or 0) > 0 then return end
        local b = Phones.findById(player, args.itemId)
        if not b or not tostring(b:getFullType()):find("^Base%.CarBattery") then return end
        rep.battery, rep.batteryType = Upkeep.batteryHours(b:getCurrentUsesFloat()), b:getFullType()
        takeItem(b)
        Net.toClient(player, "notify", { kind = "repeater", event = "batteryOn", id = rep.id, hours = math.floor(rep.battery) })
    elseif (rep.battery or 0) > 0 or rep.batteryType then
        local hours = rep.battery or 0
        addItem(player, rep.batteryType or "Base.CarBattery1", function(b) b:setCurrentUsesFloat(Upkeep.batteryCharge(hours)) end)
        rep.battery, rep.batteryType = 0, nil
    end
    local sq = getCell():getGridSquare(rep.x, rep.y, rep.z)
    Upkeep.repeaterTick(rep, 0, sq ~= nil and Util.powered(sq))
    broadcastWorld()
end)

-- Maintenance: electronics scrap and a screwdriver restore half the repeater's condition.
Net.onServer("maintainRepeater", function(player, args)
    local rep = repeaterById(args.id)
    if not rep or not nearRepeater(player, rep) then return end
    local inv = player:getInventory()
    local scrap = inv:getFirstTypeRecurse("Base.ElectronicsScrap")
    if not scrap or not Phones.hasScrewdriver(player) then return end
    takeItem(scrap)
    Upkeep.maintain(rep)
    pcall(function() addXp(player, Perks.Electricity, 3) end)
    Net.toClient(player, "notify", { kind = "repeater", event = "maintained", id = rep.id })
    broadcastWorld()
end)

local MAX_PASSWORDS = 50 -- known network passwords per character (saved with the player and sent on every join)

local function knownPasswordCount(list)
    local n = 0
    for _ in pairs(list) do n = n + 1 end
    return n
end

Net.onServer("joinRepeater", function(player, args)
    if type(args.password) ~= "string" or #args.password == 0 or #args.password > 32 then return end
    local md = player:getModData()
    if type(md.KnoxMobilePasswords) ~= "table" then md.KnoxMobilePasswords = {} end
    if not md.KnoxMobilePasswords[args.password] and knownPasswordCount(md.KnoxMobilePasswords) >= MAX_PASSWORDS then return end
    md.KnoxMobilePasswords[args.password] = true
    -- The client draws its own status bar, so it needs the passwords too.
    Net.toClient(player, "passwords", { list = md.KnoxMobilePasswords })
end)

local function repeaterStillThere(sq, id)
    local objects = sq:getWorldObjects()
    for i = 0, objects:size() - 1 do
        local o = objects:get(i)
        local item = o.getItem and o:getItem()
        if item and item:getFullType() == "KnoxMobile.Repeater" then
            local placed = item:getModData().KnoxMobileRepeaterId
            if placed == nil or placed == id then return true end
        end
    end
    return false
end

-- Every ten minutes: presence, power and wear (Core/Upkeep). Loaded squares are checked directly; an
-- unloaded repeater keeps its last grid state, but an attached car battery still runs down.
local function checkRepeaters(minutes)
    local md = State.get()
    local changed, keep = false, {}
    for _, rep in ipairs(md.repeaters) do
        local sq = getCell():getGridSquare(rep.x, rep.y, rep.z)
        local wasActive = Repeaters.isActive(rep)
        if sq and not repeaterStillThere(sq, rep.id) then
            rep.destroyed = true
            Util.log("repeater", rep.id, "is gone")
        else
            if sq then rep.grid = Util.powered(sq) end
            for _, e in ipairs(Upkeep.repeaterTick(rep, minutes, rep.grid == true)) do Util.log("repeater", rep.id, e) end
        end
        if Repeaters.isActive(rep) ~= wasActive or rep.destroyed then changed = true end
        if not rep.destroyed then keep[#keep + 1] = rep end
    end
    md.repeaters = keep
    if changed then broadcastWorld() end
end

local function purgeLost()
    local md = State.get()
    local alive = {}
    for _, rep in ipairs(md.repeaters) do if Repeaters.isActive(rep) then alive[rep.id] = true end end
    local lost = MessageQueue.purgeLost(md.queue, alive, #WorldModel.liveTowers() > 0)
    if #lost > 0 then Util.log(#lost, "queued messages lost with their network") end
end

-- New characters: their own SIM, and a phone if the sandbox says so (spec §4.4, §4.5) --------------
Net.onServer("newCharacter", function(player)
    local md = player:getModData()
    -- The flag lives on the character and in the world data (by account and character name), so a
    -- reconnect never hands out a second SIM.
    local who = Util.playerKey(player) .. ":" .. tostring(Messaging.fullName(player))
    local started = State.get().started
    if md.KnoxMobileStarted or started[who] then return end
    md.KnoxMobileStarted, started[who] = true, true
    local settings = Util.settings()
    if settings.StartWithOwnSim then
        addToWallet(player, "KnoxMobile.SimCard", function(simItem)
            local sim = Phones.simData(simItem)
            Messaging.setupOwnSim(player, sim)
            Phones.nameSim(simItem, sim.number)
        end)
    end
    if settings.StartingPhone == "Random" then
        local list = Phones.registry:spawnable(settings.EraLimit)
        local rng = Rng.new(State.get().seed .. ":start:" .. Util.playerKey(player))
        giveStartingPhone(player, rng:pick(list), rng)
    elseif settings.StartingPhone == "PickAtCreation" then
        -- The client shows a picker; the choice comes back as "pickPhone" (spec §4.4).
        md.KnoxMobilePickPending = true
        local list = {}
        for _, m in ipairs(Phones.registry:spawnable(settings.EraLimit)) do list[#list + 1] = m.id end
        Net.toClient(player, "pickPhone", { models = list })
    end
end)

Net.onServer("pickPhone", function(player, args)
    local md = player:getModData()
    if not md.KnoxMobilePickPending or Util.settings().StartingPhone ~= "PickAtCreation" then return end
    local model = type(args.model) == "string" and Phones.registry:getPhone(args.model)
    if not model then return end
    local allowed = false
    for _, m in ipairs(Phones.registry:spawnable(Util.settings().EraLimit)) do if m == model then allowed = true end end
    if not allowed then return end
    local color = model.colors[1]
    for _, c in ipairs(model.colors) do if c == args.color then color = c end end
    md.KnoxMobilePickPending = nil
    giveStartingPhone(player, model, nil, color)
end)

-- Phones on zombies (spec §4.4, §5.1): the owner's name comes from the ID card they carry ---------
-- Build 42 names cards in Java with IGUI_ItemWithDisplayName, "%1: %2": "ID Card: Forename Surname".
local ID_TYPES = { ["Base.IDcard"] = true, ["Base.IDcard_Female"] = true, ["Base.IDcard_Male"] = true }

function Server.nameFromIdCard(cardName)
    -- "ID Card: Dana Price (born 03/14/61)": the birth date is a PIN clue (Story.pinClue), not part of the name.
    local person = cardName and tostring(cardName):gsub("%s*%(born [^)]*%)%s*$", ""):match(":%s*(.-)%s*$")
    if person and person:match("%S") then return person end
    return nil
end

local function idCardName(inv)
    local list = inv:getAllEvalRecurse(function(it) return ID_TYPES[it:getFullType()] == true end)
    for i = 0, list:size() - 1 do
        local person = Server.nameFromIdCard(list:get(i):getName())
        if person then return person, list:get(i) end
    end
    return nil
end

-- The PIN's clue on the body (Story.pinClue): the birth date on the ID card, or the digits on a scrap of paper in the
-- wallet. The phone keeps the PIN for when it is first turned on.
local function placePinClue(inv, phone, rng)
    if not Phones.pinsOn() then return end
    local clue = Story.pinClue(rng)
    phone:getModData().KnoxMobilePin = clue.pin
    if clue.kind == "birthday" then
        local _, card = idCardName(inv)
        if card then
            phone:getModData().KnoxMobileBorn = tonumber(clue.born:sub(7, 8))
            card:setName(card:getName() .. " (born " .. clue.born .. ")")
            card:setCustomName(true)
        end
    elseif clue.kind == "note" then
        local wallet = inv:getFirstEvalRecurse(function(it) return tostring(it:getFullType()):find("^Base%.Wallet") ~= nil end)
        local into = wallet and wallet.getInventory and wallet:getInventory() or inv
        local scrap = into:AddItem("Base.Note")
        if scrap then
            scrap:setName("Scrap of paper: " .. clue.pin)
            scrap:setCustomName(true)
        end
    end
end

-- A zombie with a phone but no ID gets a wallet with one (spec §5.1), so the phone's owner has a name to match.
local function giveWallet(inv, female)
    local wallet = inv:AddItem(female and "Base.Wallet_Female" or "Base.Wallet_Male")
    local into = wallet and wallet.getInventory and wallet:getInventory() or inv
    into:AddItem(female and "Base.IDcard_Female" or "Base.IDcard_Male")
end

local ZOMBIE_CHANCE = 0.06
local zombieDeaths = 0

Events.OnZombieDead.Add(Util.safe("zombie phone", function(zombie)
    if isClient() then return end
    -- A Project A-Life NPC's body is that mod's: no found phone, wallet or ID card, and never a family member.
    if ALife.isNPC(zombie) then return end
    -- A family member from the family hunt carries their own phone instead.
    if HuntWorld.onZombieDead(zombie) then return end
    local settings = Util.settings()
    -- Every death gets its own roll. (The online id is -1 for every zombie in single player, so it alone made all
    -- zombies killed in the same minute share one roll: phones came in all-or-nothing clumps.)
    zombieDeaths = zombieDeaths + 1
    local rng = Rng.new(tostring(State.get().seed) .. ":z:" .. tostring(zombie:getOnlineID()) .. ":" .. tostring(Util.nowMinutes())
        .. ":" .. math.floor(zombie:getX()) .. "," .. math.floor(zombie:getY()) .. ":" .. zombieDeaths)
    local chance = (settings.ZombiePhoneChance and settings.ZombiePhoneChance / 100 or ZOMBIE_CHANCE)
    -- One whose phone rang in its pocket, or one killed where a phone rang lately (Ringing.lua), always has it.
    local rang = KnoxMobile.Ringing and KnoxMobile.Ringing.claim(zombie, zombie:getX(), zombie:getY())
    if not rang and not rng:chance(chance * (settings.RarityMultiplier or 1)) then return end
    local inv = zombie:getInventory()
    local item = Server.addFoundPhone(inv, rng, settings)
    if not item then return end
    local md = item:getModData()
    if not idCardName(inv) then pcall(giveWallet, inv, zombie:isFemale()) end
    md.KnoxMobileOwnerName = idCardName(inv)
    md.KnoxMobileOutfit = zombie.getOutfitName and zombie:getOutfitName() or nil
    md.KnoxMobileFemale = zombie:isFemale()
    md.KnoxMobileMissed = rang
    pcall(placePinClue, inv, item, rng)
end))

-- A found phone in a container: the same model mix as the houses (Loot.share: 2 or 3 smartphones in 10). Returns the
-- item, or nil.
function Server.addFoundPhone(inv, rng, settings)
    local list = Phones.registry:spawnable(settings.EraLimit)
    local weights = {}
    for _, m in ipairs(list) do weights[#weights + 1] = { m, Loot.share(m, settings, list) } end
    local model = rng:weighted(weights)
    if not model then return nil end
    local item = inv:AddItem(ItemIds.full(ItemIds.phone(model, rng:pick(model.colors))))
    if item then item:getModData().KnoxMobileOrigin = "found" end
    return item
end

-- Project A-Life NPCs carry phones of their own (0.2.0): when A-Life has put its loot on a dead NPC it calls the
-- "loot.corpse" hook of its interop layer (docs/research/ALIFE_INTEROP.md), and some of those bodies get a phone
-- that remembers who it was: the NPC's name, faction and squad mates. Server.fillFoundPhone tells the story.
local ALIFE_PHONE_CHANCE = 0.35
function Server.onALifeLoot(shell, actor)
    if isClient() or type(actor) ~= "table" or not shell then return end
    local settings = Util.settings()
    local rng = Rng.new(tostring(State.get().seed) .. ":alife:" .. tostring(actor.uid) .. ":" .. tostring(actor.generation))
    if not rng:chance(ALIFE_PHONE_CHANCE * (settings.RarityMultiplier or 1)) then return end
    local ok, inv = pcall(function() return shell:getInventory() end)
    if not ok or not inv then return end
    local item = Server.addFoundPhone(inv, rng, settings)
    if not item then return end
    local md = item:getModData()
    md.KnoxMobileOwnerName = ALife.name(actor)
    md.KnoxMobileALife = { uid = tostring(actor.uid), factionId = actor.factionId,
        faction = ALife.factionName(actor.factionId) or "The crew", mates = ALife.mates(actor, 5) }
    Util.log("A-Life phone for", tostring(md.KnoxMobileOwnerName), "of", md.KnoxMobileALife.faction)
end

local function hookALife()
    local interop = ALife.interop()
    if interop then pcall(interop.on, "loot.corpse", Server.onALifeLoot) end
end
Events.OnGameStart.Add(Util.safe("a-life hook", hookALife))
Events.OnServerStarted.Add(Util.safe("a-life hook", hookALife))

-- Debug (spec §16.1): admins and debug mode only ---------------------------------------------------
Net.onServer("debug", function(player, args)
    if not Util.debugAllowed(player) then return end
    local md = State.get()
    if args.action == "towers" then
        md.debugTowers = (args.mode == "dead" or args.mode == "alive") and args.mode or nil
        broadcastWorld()
    elseif args.action == "storyForward" then
        md.storyShift = (md.storyShift or 0) + (tonumber(args.days) or 1)
        Messaging.releaseStory()
        for _, p in ipairs(Util.players()) do Messaging.deliverTo(p) end
        broadcastWorld()
    elseif args.action == "storyPlaces" then
        -- Where this player's story points: the family hunt (and "arm" sets it up now, for testing).
        local lines = {}
        local mine = md.players[Util.playerKey(player)]
        local plan = mine and md.story[mine.number]
        local h = plan and plan.hunt
        if h then
            if args.arm == true and h.state == "waiting" then HuntWorld.arm(h) end
            lines[#lines + 1] = string.format("Family: %s (%d,%d): %s, %s", h.name, h.x, h.y, h.outcome.kind, h.state)
        end
        local key = Util.playerKey(player)
        for _, q in pairs(md.quests) do
            if q.player == key then
                lines[#lines + 1] = string.format("Stash: %s (%d,%d): %s, %s", q.name, q.x, q.y, q.trap and ("trap " .. q.trap) or "stash",
                    q.state)
            end
        end
        if #lines == 0 then lines[1] = "No story places for you (FamilyHunt and survivor texts off, or no SIM of your own)" end
        for _, l in ipairs(lines) do Util.log("story places:", l) end
        Net.toClient(player, "debugInfo", { lines = lines })
    elseif args.action == "textMe" then
        local item, state = phoneOf(player, args)
        if item and state.sim and state.sim.number then
            Messaging.queueStory("(502) 555-0100", state.sim.number, args.body or "Test message from the debug menu.")
            Messaging.deliverTo(player)
        end
    elseif args.action == "setPhone" then
        local item, state = phoneOf(player, args)
        if not item then return end
        if tonumber(args.battery) then
            state.battery.charge = math.max(0, math.min(100, tonumber(args.battery)))
            if state.battery.charge <= 0 then state.power.on = false end -- a flat battery switches the phone off
        end
        if args.condition then state.condition = args.condition end
        if args.wetness then
            -- Exposure minutes to match, or the next minute's tick dries a "damp" phone at once (wetMinutes 0).
            state.wetness = args.wetness
            state.wetMinutes = args.wetness == "dry" and 0 or Damage.DAMP_AFTER + Damage.SOAK_AFTER - 1
            state.waterDamageMinutes = 0
        end
        if args.health then state.battery.health = tonumber(args.health) or state.battery.health end
        if args.riceDone and state.rice then state.rice.since = Util.nowMinutes() - 24 * 60 end
        Phones.save(item, player)
    elseif args.action == "giveAll" then
        for _, id in ipairs(ItemIds.all()) do addItem(player, ItemIds.full(id)) end
    elseif args.action == "ownSim" then
        -- Your own SIM into the held phone (else the newest one you carry): a loose one of yours, the one in
        -- another of your phones, or a new number with its family when you have none (for call tests).
        local held = player:getSecondaryHandItem()
        if not (held and Phones.isPhone(held)) then held = player:getPrimaryHandItem() end
        if not (held and Phones.isPhone(held)) then
            local list = Phones.inventoryPhones(player)
            held = list[#list]
        end
        local state = held and Phones.get(held)
        local key = Util.playerKey(player)
        if state and not (state.sim and state.sim.owner == key) then
            local moved = false
            if not state.sim then fitOwnSim(player, held); moved = state.sim ~= nil end
            for _, other in ipairs(Phones.inventoryPhones(player)) do
                local os = other ~= held and Phones.get(other)
                if not moved and os and os.sim and os.sim.owner == key and not state.sim then
                    state.sim, os.sim = os.sim, nil
                    Phones.save(other, player)
                    moved = true
                end
            end
            if not moved and not state.sim then
                local sim = Sim.newSim()
                Messaging.setupOwnSim(player, sim)
                state.sim = sim
            end
            Phones.save(held, player)
        end
    elseif args.action == "textBackNow" then
        -- Every thread texted back on the held phone answers now, as one who answers, and will say where home is
        -- and leave a bag (both rare in play).
        local item, state = phoneOf(player, args)
        for _, r in pairs(item and state.story and state.story.replies or {}) do
            r.fate, r.done = "alive", nil
            r.home, r.stash = true, true
            if r.sent > r.answered then r.dueAt = 0 end
        end
        if KnoxMobile.TextBack then KnoxMobile.TextBack.deliver(player) end
    elseif args.action == "ringNow" then
        if KnoxMobile.Ringing then KnoxMobile.Ringing.ring(player, Rng.new("debug:" .. getTimestampMs())) end
    elseif args.action == "strangersNow" then
        local mine = State.get().players[Util.playerKey(player)]
        if mine and mine.number and KnoxMobile.Strangers then
            local rng = Rng.new("debug:" .. getTimestampMs())
            Messaging.queueStory(Sim.issueNumber(State.get().numbers, rng), mine.number, require("KnoxMobile/Core/Strangers").wrong(rng))
            KnoxMobile.Strangers.rumor(player, mine.number, rng)
            Messaging.deliverTo(player)
        end
    elseif args.action == "night" then
        getGameTime():setTimeOfDay(22.5)
        Util.log("debug: time set to 22:30")
    elseif args.action == "congestion" then
        -- Until the game restarts (the saved sandbox setting is not changed): test calls without
        -- "All circuits are busy" (r7: 5 of 7 early calls failed).
        SandboxVars.KnoxMobile = SandboxVars.KnoxMobile or {}
        local on = not Util.settings().NetworkCongestion
        SandboxVars.KnoxMobile.NetworkCongestion = on
        Util.log("debug: network congestion", on and "on" or "off")
        Net.toClient(player, "debugInfo", { lines = { "Network congestion " .. (on and "on" or "off") .. " (until restart)" } })
    elseif args.action == "give" and type(args.item) == "string" then
        -- Phones: origin "start" is a new phone of your own (unlocked); "found" is a dead owner's phone (PIN,
        -- owner made on first power-on), with enough charge and a screen that works, so it boots for the test.
        local origin = (args.origin == "start" or args.origin == "found") and args.origin or nil
        addItem(player, args.item, origin and function(phone)
            if not Phones.isPhone(phone) then return end
            phone:getModData().KnoxMobileOrigin = origin
            local state = Phones.get(phone)
            if origin == "found" then
                state.battery.charge = math.max(state.battery.charge, 30)
                if state.condition == "broken" then state.condition = "cracked" end
            else
                -- "New, yours" means new: never scratched or cracked (r8).
                state.condition = "mint"
                fitOwnSim(player, phone)
            end
        end)
    end
    Net.toClient(player, "debugDone", { action = args.action })
end)

-- Timers -----------------------------------------------------------------------------------------
Events.OnInitGlobalModData.Add(Util.safe("init world data", function() State.get() end))

-- A call ends when either side leaves the game or their phone stops working (dead battery, broken, off).
local function phoneWorks(player, phoneId)
    local item = player and phoneId and Phones.findById(player, phoneId)
    local state = item and Phones.get(item)
    return state ~= nil and state.power.on and state.battery.charge > 0 and state.condition ~= "broken"
end

local function checkCalls()
    local ended = {}
    for _, call in pairs(State.calls.byId) do
        local caller, callee = playerByKey(call.callerKey), playerByKey(call.calleeKey)
        -- A payphone caller has no phone: they must stay at a powered payphone.
        local callerOk
        if call.payphone then callerOk = Payphones.callerStillThere(caller, call.payphone)
        else callerOk = phoneWorks(caller, call.callerPhone) end
        if not callerOk or not phoneWorks(callee, call.calleePhone) then
            ended[#ended + 1] = call
        end
    end
    for _, call in ipairs(ended) do
        Calls.hangUp(State.calls, call.id, call.from)
        endCall(call, "dropped")
    end
end

Events.EveryOneMinute.Add(Util.safe("every minute", function()
    if isClient() then return end
    PhoneTick.run()
    for _, call in ipairs(Calls.expire(State.calls, getTimestampMs() / 1000)) do endCall(call, "missed") end
    checkCalls()
end))

Events.EveryTenMinutes.Add(Util.safe("every ten minutes", function()
    if isClient() then return end
    checkRepeaters(10)
    tickWorldChargers()
    Messaging.releaseStory()
    for _, p in ipairs(Util.players()) do Messaging.deliverTo(p) end
    purgeLost()
end))

local accessoryCount = #Accessories
Util.log("server ready;", accessoryCount, "accessory types;", Sim.MAX_CONTACTS, "contacts per SIM")

return Server
