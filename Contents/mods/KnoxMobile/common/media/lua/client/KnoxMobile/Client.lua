-- Client: what the server tells us (texts, calls, battery, charging), turned into notifications and sounds
-- (spec §8.4, §9.7, §13.2). Also says hello on join and asks for a new character's own SIM.
local Net = require "KnoxMobile/Game/Net"
local Util = require "KnoxMobile/Game/Util"
local Phones = require "KnoxMobile/Game/Phones"
local Messages = require "KnoxMobile/Data/Messages"

local Client = { call = nil, unlock = {}, knownPhones = {} }
KnoxMobile.Client = Client
KnoxMobile.UI = KnoxMobile.UI or {}

local T = Util.text

local function me() return getPlayer() end

local function refresh()
    if KnoxMobile.UI.refresh then KnoxMobile.UI.refresh() end
end

local function phoneById(id)
    local p = me()
    return p and id and Phones.findById(p, id) or nil
end

-- Notifications ---------------------------------------------------------------------------------
local MESSAGES = Messages.notify

-- Notifications whose %1 is a code to put into words (Data/Messages.words): { word group, argument }.
local WORDED = {
    charge_started = { "Source", "source" }, charge_cannot = { "NoCharge", "reason" }, audio_noGear = { "Gear", "route" },
}

function Client.describe(args)
    local group = MESSAGES[args.kind]
    if args.kind == "texts" then
        if (args.count or 1) > 1 then return T("IGUI_KnoxMobile_NewTexts", "%1 new messages", args.count) end
        local preview = require("KnoxMobile/Core/CameraSpec").shown(tostring(args.preview or ""))
        return T("IGUI_KnoxMobile_NewText", "%1: %2", args.from or "?", preview)
    elseif args.kind == "unplugged" then
        return T("IGUI_KnoxMobile_Unplugged", "Unplugged: %1", Util.word("Unplug", args.reason))
    end
    local text = group and group[args.event]
    if not text then return nil end
    local key = "IGUI_KnoxMobile_" .. args.kind .. "_" .. tostring(args.event)
    local worded = WORDED[args.kind .. "_" .. tostring(args.event)]
    if worded then return T(key, text, Util.word(worded[1], args[worded[2]])) end
    -- Repeaters are numbered for players: "R3" reads "#3".
    if args.kind == "repeater" then return T(key, text, (tostring(args.id or "?"):gsub("^R", ""))) end
    return T(key, text, args.source or args.reason or args.number or args.id or args.route or "")
end

-- Mood (spec §9.6). Stats belong to the client in multiplayer, so changes happen here.
function Client.mood(stat, amount)
    local p = me()
    if not p or not CharacterStat[stat] then return end
    pcall(function()
        if amount > 0 then p:getStats():add(CharacterStat[stat], amount) else p:getStats():remove(CharacterStat[stat], -amount) end
    end)
end

function Client.toast(text, kind)
    if text and KnoxMobile.UI.toast then KnoxMobile.UI.toast(text, kind) end
end

Net.onClient("notify", function(args)
    -- The same notice on several phones at once (a carrier alert reaches every SIM) shows once (r8).
    -- Two texts from one sender on the same phone are two notices (final test: the second banner never showed).
    local text, t = Client.describe(args), getTimestampMs()
    local same = text == Client.lastNotice and args.phoneId ~= Client.lastNoticePhone and t - (Client.lastNoticeAt or 0) <= 3000
    if not same then Client.toast(text, args.kind) end
    Client.lastNotice, Client.lastNoticeAt, Client.lastNoticePhone = text, t, args.phoneId
    -- A text from a real person is the best thing that happens all day.
    if args.kind == "texts" and args.fromPlayer then Client.mood("UNHAPPINESS", -8) end
    if KnoxMobile.Audio then KnoxMobile.Audio.onNotify(args, phoneById(args.phoneId)) end
    refresh()
end)

-- World and results ------------------------------------------------------------------------------
Net.onClient("world", function(args)
    KnoxMobile.world.seed = args.seed or KnoxMobile.world.seed
    KnoxMobile.world.repeaters = args.repeaters or {}
    KnoxMobile.world.debugTowers = args.debugTowers
    KnoxMobile.world.storyShift = args.storyShift or 0
    KnoxMobile.world.voice = args.voice ~= false
    KnoxMobile.world.sites = args.sites or {} -- cell sites on generator power (Core/CellSites)
    refresh()
end)

-- Private repeater passwords this character knows (the status bar needs them to show service).
Net.onClient("passwords", function(args)
    local p = me()
    if p and type(args.list) == "table" then p:getModData().KnoxMobilePasswords = args.list end
    refresh()
end)

Net.onClient("textResult", function(args)
    if args.status == "queued" then
        Client.toast(T("IGUI_KnoxMobile_TextQueued", "Queued. It will send when they have service."))
    elseif args.status == "failed" then
        Client.toast(T("IGUI_KnoxMobile_TextFailed", "Not sent: %1", Util.word("TextFail", args.reason)))
    elseif args.page then
        Client.toast(T("IGUI_KnoxMobile_PageSent", "Page sent"))
    end
    refresh()
end)

Net.onClient("unlockResult", function(args)
    Client.unlock[args.phoneId] = args.result
    if args.result == "lockedOut" then Client.toast(T("IGUI_KnoxMobile_LockedOut", "Too many tries. Locked for an hour.")) end
    refresh()
end)

Net.onClient("debugDone", function()
    -- With the phone open the "Done" banner only pushed away the notification the debug action caused (r8).
    if not (KnoxMobile.UI.isOpen and KnoxMobile.UI.isOpen()) then Client.toast(T("IGUI_KnoxMobile_DebugDone", "Done")) end
    refresh()
end)

-- Debug answers worth reading (admin only, English like the rest of the debug menu).
Net.onClient("debugInfo", function(args)
    for _, line in ipairs(type(args.lines) == "table" and args.lines or {}) do Client.toast(tostring(line)) end
end)

-- Calls ------------------------------------------------------------------------------------------
Net.onClient("incomingCall", function(args)
    Client.call = { id = args.callId, number = args.from, phoneId = args.phoneId, status = "incoming" }
    local phone = phoneById(args.phoneId)
    local state = phone and Phones.get(phone)
    local name = args.from
    if state and state.sim then
        for _, c in ipairs(state.sim.contacts or {}) do if c.number == args.from then name = c.name end end
    end
    Client.call.name = name
    Client.toast(T("IGUI_KnoxMobile_IncomingCall", "Incoming call: %1", name), "call")
    if KnoxMobile.Audio then KnoxMobile.Audio.startRing(phone) end
    refresh()
end)

Net.onClient("callRinging", function(args)
    -- From a payphone there is no phone in hand: the payphone's menu hangs up.
    Client.call = { id = args.callId, number = args.to, status = "outgoing", payphone = args.payphone == true,
        phoneId = not args.payphone and Client.dialingPhone or nil }
    -- The payphone side is kept apart: calling your own phone from a payphone replaces Client.call with the
    -- incoming call, and the payphone still has to hang up (r7).
    if args.payphone then
        Client.payphoneCall = { id = args.callId, number = args.to }
        Client.toast(T("IGUI_KnoxMobile_PayphoneRinging", "Ringing %1...", args.to), "call")
    end
    refresh()
end)

Net.onClient("callStart", function(args)
    if not Client.call or Client.call.id ~= args.callId then
        Client.call = { id = args.callId }
    end
    Client.call.status = "active"
    Client.call.channel = args.channel
    if KnoxMobile.Audio then
        KnoxMobile.Audio.stopRing()
        KnoxMobile.Audio.startCall(args.channel, phoneById(Client.call.phoneId))
    end
    refresh()
end)

Net.onClient("callEnd", function(args)
    if Client.payphoneCall and Client.payphoneCall.id == args.callId then Client.payphoneCall = nil end
    if KnoxMobile.Audio then KnoxMobile.Audio.stopRing(); KnoxMobile.Audio.endCall() end
    local wasIncoming = Client.call and Client.call.status == "incoming"
    Client.call = nil
    if args.reason == "missed" and wasIncoming then
        Client.toast(T("IGUI_KnoxMobile_MissedCall", "Missed call"), "call")
    else
        Client.toast(T("IGUI_KnoxMobile_CallEnded", "Call ended"), "call")
    end
    refresh()
end)

Net.onClient("callFailed", function(args)
    Client.call = nil
    local known = MESSAGES.callFailed[args.reason]
    Client.toast(known and T("IGUI_KnoxMobile_callFailed_" .. tostring(args.reason), known)
        or T("IGUI_KnoxMobile_CallFailed", "Call failed"), "call")
    -- Once a game: why a number can't be reached.
    if args.reason == "unreachable" and not Client.unreachableHinted then
        Client.unreachableHinted = true
        Client.toast(T("IGUI_KnoxMobile_UnreachableHint",
            "Their phone may be off, dead, or out of range. A text may still get through."), "call")
    end
    refresh()
end)

-- A call nobody plays (Server npcCall: your family, other known numbers, a payphone): it rings, then their voicemail
-- greeting or a few words from them show as the call's captions, one after another; then it ends. Hanging up ends it
-- at once. A payphone just rings.
Client.scripted = nil
Net.onClient("callScripted", function(args)
    local lines = {}
    for part in tostring(args.lines or ""):gmatch("[^/]+") do
        local l = part:match("^%s*(.-)%s*$")
        if l ~= "" then lines[#lines + 1] = l end
    end
    Client.call = { id = -2, number = args.to, name = args.name, status = "outgoing", scripted = true,
        phoneId = Client.dialingPhone }
    local t = getTimestampMs()
    local ring = args.kind == "answer" and (2500 + ZombRand(3000)) or (7000 + ZombRand(5000))
    Client.scripted = { connectAt = args.kind ~= "noAnswer" and t + ring or nil, endAt = args.kind == "noAnswer" and t + 25000 or nil,
        lines = lines, kind = args.kind }
    refresh()
end)

Events.OnTick.Add(Util.safe("scripted call", function()
    local s = Client.scripted
    if not s then return end
    if not (Client.call and Client.call.scripted) then Client.scripted, Client.callCaption = nil, nil; return end
    local t = getTimestampMs()
    if s.connectAt and t >= s.connectAt then
        s.connectAt, s.nextLine, s.line = nil, t, 0
        Client.call.status = "active"
        refresh()
    end
    if s.nextLine and t >= s.nextLine then
        s.line = s.line + 1
        local l = s.lines[s.line]
        Client.callCaption = l
        if l then
            Client.toast(l, "call")
            s.nextLine = t + math.max(2500, #l * 70)
        else
            s.nextLine, s.endAt = nil, t + 800
        end
    end
    if s.endAt and t >= s.endAt then
        Client.scripted, Client.call, Client.callCaption = nil, nil, nil
        Client.toast(s.kind == "noAnswer" and T("IGUI_KnoxMobile_NoAnswer", "No answer")
            or T("IGUI_KnoxMobile_CallEnded", "Call ended"), "call")
        refresh()
    end
end))

function Client.placeCall(phone, number)
    Client.dialingPhone = phone:getID()
    Net.toServer(me(), "placeCall", { phoneId = phone:getID(), to = number })
end

function Client.answer()
    if Client.call then Net.toServer(me(), "answerCall", { callId = Client.call.id }) end
end

-- Hang up the payphone's receiver (its menu); the phone's own side of the same call ends with it.
function Client.hangUpPayphone()
    local pc = Client.payphoneCall
    if not pc then return end
    Client.payphoneCall = nil
    Net.toServer(me(), "endCall", { callId = pc.id })
    if Client.call and Client.call.id == pc.id then
        if KnoxMobile.Audio then KnoxMobile.Audio.stopRing(); KnoxMobile.Audio.endCall() end
        Client.call = nil
    end
    refresh()
end

function Client.hangUp()
    if Client.call then
        if not Client.call.scripted then Net.toServer(me(), "endCall", { callId = Client.call.id }) end
        Client.scripted = nil
        if KnoxMobile.Audio then KnoxMobile.Audio.stopRing(); KnoxMobile.Audio.endCall() end
        Client.call = nil
        refresh()
    end
end

function Client.setting(phone, key, value)
    Net.toServer(me(), "phoneSetting", { phoneId = phone:getID(), key = key, value = value })
end

-- StartingPhone = PickAtCreation: the server asks which phone to start with (spec §4.4).
Net.onClient("pickPhone", function(args)
    if KnoxMobile.UI.showPicker then KnoxMobile.UI.showPicker(args.models or {}) end
end)

function Client.pickPhone(modelId, color)
    Net.toServer(me(), "pickPhone", { model = modelId, color = color })
end

-- Join, new characters and picked-up phones ------------------------------------------------------
local function hello()
    local p = me()
    if not p then return end
    Net.toServer(p, "hello", {})
    Net.toServer(p, "newCharacter", {})
end

Events.OnGameStart.Add(Util.safe("hello", hello))

-- One line in console.txt proving the client side loaded: apps per family and the UI pieces.
Events.OnGameBoot.Add(Util.safe("client ready", function()
    local counts = {}
    for _, f in ipairs({ "SegmentLCD", "ModernAndroid" }) do counts[#counts + 1] = f .. " " .. #KnoxMobile.Apps.forFamily(f) end
    Util.log("client ready; apps:", table.concat(counts, ", "), "; phone UI", KnoxMobilePhonePanel ~= nil,
        "; audio", KnoxMobile.Audio ~= nil, "; actions", KnoxMobileAction ~= nil)
end))
-- On a server the new character's inventory reaches the client a moment after it is created: the starting SIM
-- and phone are asked for a few seconds later there, so they land in an inventory the client has.
local newCharacterAt = nil
Events.OnCreatePlayer.Add(Util.safe("new player", function(_, player)
    if not (player and player == me()) then return end
    if isClient() then newCharacterAt = getTimestampMs() + 3000 else Net.toServer(player, "newCharacter", {}) end
end))
Events.OnTick.Add(Util.safe("new player (server)", function()
    if not newCharacterAt or getTimestampMs() < newCharacterAt then return end
    newCharacterAt = nil
    local p = me()
    if p then Net.toServer(p, "newCharacter", {}) end
end))

-- A phone that appears in our inventory catches up on the drain it missed while lying around.
Events.EveryOneMinute.Add(Util.safe("picked up phones", function()
    local p = me()
    if not p or p:isDead() then return end
    local seen = {}
    local any = false
    for _, item in ipairs(Phones.inventoryPhones(p)) do
        local id = item:getID()
        seen[id] = true
        any = true
        if not Client.knownPhones[id] then Net.toServer(p, "pickedUp", { phoneId = id }) end
    end
    Client.knownPhones = seen
    -- First phone this character ever carries: say how to use it.
    local md = p:getModData()
    if any and not md.KnoxMobileHinted then
        md.KnoxMobileHinted = true
        local key = getKeyName and getKeyName(KnoxMobile.Options.openKey()) or "K"
        Client.toast(T("IGUI_KnoxMobile_HintShort", "Press %1 for your phone. Right-click for more.", key))
    end
end))

return Client
