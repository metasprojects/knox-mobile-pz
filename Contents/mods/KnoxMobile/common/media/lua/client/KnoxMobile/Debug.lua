-- Client: the debug menu (spec §16.1, plan task 4.8). Right-click the ground in debug mode (-debug) only, so
-- server admins in a normal game never see it (Meta, 2026-10-21). On a server you must also be an admin there;
-- the server checks access again before doing anything.
local Phones = require "KnoxMobile/Game/Phones"
local Net = require "KnoxMobile/Game/Net"
local Util = require "KnoxMobile/Game/Util"
local ItemIds = require "KnoxMobile/ItemIds"
local Calls = require "KnoxMobile/Core/Calls"
local Tick = require "KnoxMobile/Game/Tick"

local function debug(player, args) Net.toServer(player, "debug", args) end

local function targetPhone(player)
    local held = player:getSecondaryHandItem()
    if held and Phones.isPhone(held) then return held end
    return Phones.inventoryPhones(player)[1]
end

-- The pretend call "connects" after 4 s (the hidden radio comes up on a call channel, as in a real call)
-- and ends by itself (or with the phone's hang up, which clears it).
local fakeCallUntil, fakeConnectAt = nil, nil
Tick.add("fake call", function()
    if not fakeCallUntil then return end
    local t = getTimestampMs()
    local call = KnoxMobile.Client and KnoxMobile.Client.call
    if not (call and call.fake) then fakeCallUntil, fakeConnectAt = nil, nil; return end
    if fakeConnectAt and t >= fakeConnectAt then
        fakeConnectAt = nil
        call.status, call.channel = "active", Calls.FIRST_CHANNEL
        if KnoxMobile.Audio then KnoxMobile.Audio.startCall(call.channel, targetPhone(getPlayer())) end
    end
    if t < fakeCallUntil then return end
    fakeCallUntil = nil
    KnoxMobile.Client.call = nil
    if KnoxMobile.Audio then KnoxMobile.Audio.endCall() end
end, 100)

local function phoneWithSim(player)
    for _, it in ipairs(Phones.inventoryPhones(player)) do
        local st = Phones.get(it)
        if st and st.sim and st.sim.number then return it end
    end
    return nil
end

local function sub(menu, text)
    local root = menu:addOption(text, nil, nil)
    local m = ISContextMenu:getNew(menu)
    menu:addSubMenu(root, m)
    return m
end

local function setPhone(player, args)
    local phone = targetPhone(player)
    if not phone then Util.log("debug: no phone"); return end
    args.action, args.phoneId = "setPhone", phone:getID()
    debug(player, args)
end

local function showOwners(player)
    local lines = {}
    for _, it in ipairs(Phones.inventoryPhones(player)) do
        local st, model = Phones.get(it)
        local o = st.owner or {}
        local text
        if o.kind == "generated" and not o.pending then
            text = string.format("%s: %s %s, %s from %s%s; PIN %s", model.name, tostring(o.first), tostring(o.last),
                tostring(o.job), tostring(o.hometown), o.fromIdCard and " (ID card)" or "", tostring(st.security.pin))
        elseif o.pending then
            text = model.name .. ": owner made on first power-on"
        else
            text = model.name .. ": " .. tostring(o.kind) .. (st.sim and (" " .. tostring(st.sim.number)) or "")
        end
        Util.log("debug owner:", text)
        lines[#lines + 1] = text
    end
    -- The held phone's owner in the popup (a popup shows two lines, r7: one long list was cut after two phones);
    -- every phone is in console.txt.
    local held = targetPhone(player)
    for i, it in ipairs(Phones.inventoryPhones(player)) do
        if it == held and i > 1 then table.insert(lines, 1, table.remove(lines, i)) end
    end
    if #lines > 0 then KnoxMobile.Client.toast(lines[1]) end
    if #lines > 1 then KnoxMobile.Client.toast((#lines - 1) .. " more phones: the full list is in console.txt") end
end

Events.OnFillWorldObjectContextMenu.Add(Util.safe("debug menu", function(playerNum, context, _, test)
    if test then return end
    local player = getSpecificPlayer(playerNum)
    if not player or not isDebugEnabled() or not Util.debugAllowed(player) then return end
    local m = sub(context, "Knox Mobile (admin)")

    -- Results go to console.txt as "[KnoxMobile] SELFTEST ..." lines (client/KnoxMobile/SelfTest.lua).
    m:addOption("Run all tests", nil, function() KnoxMobile.SelfTest.run(player) end)
    m:addOption("Give every Knox Mobile item", nil, function() debug(player, { action = "giveAll" }) end)
    m:addOption("Put your SIM in the held phone", nil, function() debug(player, { action = "ownSim" }) end)
    m:addOption("Set the time to night (22:30)", nil, function() debug(player, { action = "night" }) end)
    m:addOption("Network congestion on/off (\"All circuits are busy\")", nil, function() debug(player, { action = "congestion" }) end)
    -- The plain game's paths (still screen pictures, caption-only photos, no Camera) with ZombieBuddy loaded: the
    -- game's launch file loads it on every launch (final test, question 3).
    m:addOption(KnoxMobile.pretendNoJava and "Act as if ZombieBuddy is missing: turn off" or "Act as if ZombieBuddy is missing",
        nil, function()
            KnoxMobile.pretendNoJava = not KnoxMobile.pretendNoJava or nil
            if KnoxMobile.UI.panel then KnoxMobile.UI.reopen(player, KnoxMobile.UI.panel.item) end
            KnoxMobile.Client.toast(KnoxMobile.pretendNoJava and "Acting as if ZombieBuddy is missing" or "ZombieBuddy part back on")
        end)
    m:addOption(KnoxMobile.Hold.fakeSprint and "Pretend to sprint: turn off" or "Pretend to sprint (phone arm down)", nil, function()
        KnoxMobile.Hold.fakeSprint = not KnoxMobile.Hold.fakeSprint or nil
    end)
    -- 0.2.1: how much Knox Mobile asks of the game, every 5 s in console.txt ("load: N calls/s ... busiest: ...").
    m:addOption(Tick.stats and "Knox Mobile load readout: turn off" or "Knox Mobile load readout (console.txt, every 5 s)", nil,
        function()
            Tick.setStats(not Tick.stats)
            KnoxMobile.Client.toast(Tick.stats and "Load readout on: see console.txt" or "Load readout off")
        end)
    -- A pretend outgoing call for 30 s, to see the phone-to-ear pose without anyone to call (no network involved).
    m:addOption("Fake a call for 30 seconds (ear pose)", nil, function()
        if not KnoxMobile.UI.panel then KnoxMobile.UI.toggle(player) end
        KnoxMobile.Client.call = { id = -1, number = "(502) 555-0100", status = "outgoing", fake = true }
        fakeCallUntil, fakeConnectAt = getTimestampMs() + 30000, getTimestampMs() + 4000
    end)
    -- A new phone of your own (unlocked, no owner story) or a dead owner's phone (locked with a PIN).
    local giveNew = sub(m, "Give phone (new, yours)")
    local giveFound = sub(m, "Give found phone (owner, PIN)")
    for _, model in ipairs(Phones.registry:phones()) do
        local id = ItemIds.full(ItemIds.phone(model, model.colors[1]))
        giveNew:addOption(model.name, nil, function() debug(player, { action = "give", item = id, origin = "start" }) end)
        giveFound:addOption(model.name, nil, function() debug(player, { action = "give", item = id, origin = "found" }) end)
    end
    local give = sub(m, "Give tools and parts")
    give:addOption("SIM card (blank)", nil, function() debug(player, { action = "give", item = "KnoxMobile.SimCard" }) end)
    give:addOption("Cell repeater", nil, function() debug(player, { action = "give", item = "KnoxMobile.Repeater" }) end)
    give:addOption("Test tools (rice, plastic bag, screwdriver, earbuds, headphones)", nil, function()
        for _, t in ipairs({ "Base.Rice", "Base.Plasticbag", "Base.Screwdriver", "Base.Earbuds", "Base.Headphones" }) do
            debug(player, { action = "give", item = t })
        end
    end)
    give:addOption("Charging kit for the held phone", nil, function()
        local phone = targetPhone(player)
        local model = phone and Phones.model(phone)
        if not model then return end
        if model.connector == "Pin" or model.connector == "Flat" then
            debug(player, { action = "give", item = "KnoxMobile.WallCharger" .. model.connector })
        else
            debug(player, { action = "give", item = "KnoxMobile.Cable" .. model.connector })
            debug(player, { action = "give", item = "KnoxMobile.UsbWallAdapter" })
            debug(player, { action = "give", item = "KnoxMobile.PowerBank" })
        end
    end)

    -- Admins can see the network map (spec §13.3): live towers, repeaters and where this phone connects.
    m:addOption("Show the network", nil, function()
        local WorldModel = require "KnoxMobile/Game/WorldModel"
        local live = WorldModel.liveTowers()
        local towns = {}
        for _, t in ipairs(live) do towns[#towns + 1] = t.town or t.id end
        -- Whole town names up to about 120 characters, then "..." (final test: a cut name ended in a comma).
        -- Each town once, with how many towers it has (second pass: "Muldraugh, Muldraugh").
        local counts, order = {}, {}
        for _, town in ipairs(towns) do
            if not counts[town] then order[#order + 1] = town end
            counts[town] = (counts[town] or 0) + 1
        end
        for i, town in ipairs(order) do
            if counts[town] > 1 then order[i] = town .. " x" .. counts[town] end
        end
        towns = order
        local shown, len = {}, 0
        for _, town in ipairs(towns) do
            if len + #town > 110 then shown[#shown + 1] = "..."; break end
            shown[#shown + 1] = town
            len = len + #town + 2
        end
        KnoxMobile.Client.toast(#live == 0 and "Towers up: none"
            or string.format("Towers up: %d (%s)", #live, table.concat(shown, ", ")))
        for _, rep in ipairs(KnoxMobile.world.repeaters or {}) do
            local line = string.format("%s at %d,%d,%d: %s, condition %d, %s%s", rep.id, rep.x, rep.y, rep.z,
                rep.powered and "on" or "off", math.floor(rep.condition or 100), rep.private and "private" or "open",
                (rep.battery or 0) > 0 and (", battery " .. math.floor(rep.battery) .. " h") or "")
            Util.log("network:", line)
            KnoxMobile.Client.toast(line)
        end
        local phone = targetPhone(player)
        if phone then
            local located = WorldModel.locatePlayer(player, Phones.model(phone), player:getModData().KnoxMobilePasswords or {})
            local bars = located.bars or 0
            local Format = require "KnoxMobile/Core/Format"
            local net = located.network and Format.network(located, Util.text) or "no service"
            KnoxMobile.Client.toast(string.format("This phone: %s, %d %s%s", tostring(net),
                bars, bars == 1 and "bar" or "bars", located.indoors and " (indoors)" or ""))
        end
        -- Cell sites: generator-powered ones with the time their fuel runs out, and the nearest site.
        local CellSites = require "KnoxMobile/Core/CellSites"
        local TowerSites = require "KnoxMobile/Data/TowerSites"
        for id, e in pairs(KnoxMobile.world.sites or {}) do
            local site = CellSites.byId(TowerSites.sites, id)
            if site then
                local left = e.untilMin and (e.untilMin - Util.nowMinutes()) / 60 or 0
                local line = string.format("Site %s (%s) at %d,%d: %s", site.code, site.town, site.x, site.y,
                    left > 0 and string.format("on generator, fuel for %.1f h", left) or "generator hooked up, not running")
                Util.log("network:", line)
                KnoxMobile.Client.toast(line)
            end
        end
        local near, d = CellSites.nearest(TowerSites.sites, player:getX(), player:getY())
        if near then
            local line = string.format("Nearest site %s at %d,%d: %s, %s", near.code, near.x, near.y,
                KnoxMobile.Coverage and KnoxMobile.Coverage.where(near, player:getX(), player:getY()) or math.floor(d),
                KnoxMobile.Coverage and KnoxMobile.Coverage.status(near) or "")
            Util.log("network:", line)
            KnoxMobile.Client.toast(line)
        end
    end)

    local towers = sub(m, "Towers")
    towers:addOption("Kill all towers", nil, function() debug(player, { action = "towers", mode = "dead" }) end)
    towers:addOption("Revive all towers", nil, function() debug(player, { action = "towers", mode = "alive" }) end)
    towers:addOption("Back to the schedule", nil, function() debug(player, { action = "towers", mode = "normal" }) end)
    towers:addOption("Carrier alerts: send every alert to my phones", nil, function() Net.toServer(player, "debugAlerts", {}) end)

    -- r7: the open phone is held low at the hip. Is the look pose playing? (The tracks need the Java part.)
    m:addOption("Log the hold pose", nil, function()
        local text = string.format("LeftHandMask=%s RightHandMask=%s KnoxPhoneCall=%s",
            tostring(player:getVariableString("LeftHandMask")), tostring(player:getVariableString("RightHandMask")),
            tostring(player:getVariableBoolean("KnoxPhoneCall")))
        if knoxLiveAnimTracks then text = text .. " | tracks: " .. knoxLiveAnimTracks(player) end
        Util.log("hold pose:", text)
        KnoxMobile.Client.toast(text)
    end)
    -- The optional Java part (ZombieBuddy): the live-screen spike (client/KnoxMobile/Live.lua).
    local Live = KnoxMobile.Live
    local live = sub(m, "Live screen (ZombieBuddy)")
    if not (Live and Live.available()) then
        live:addOption("ZombieBuddy part not loaded", nil, nil).notAvailable = true
    else
        live:addOption("Describe the hand models (log)", nil, function()
            local text = Live.describe(player)
            Util.log("live screen:", text)
            KnoxMobile.Client.toast(text)
        end)
        live:addOption((Live.testTexture and "Test texture on the held phone: turn off" or "Test texture on the held phone"),
            nil, function()
                local ok = Live.setTest(player, not Live.testTexture)
                KnoxMobile.Client.toast(ok and "Test texture set" or "No held phone model")
            end)
        live:addOption((Live.capture and "Capture the phone screen: turn off" or "Capture the phone screen"), nil,
            function() Live.setCapture(player, not Live.capture) end)
        local Camera = KnoxMobile.Camera
        if Camera and knoxLiveCameraSource then
            -- nil = by view (Viewpoint: worldScreen; isometric: world), then each source in turn.
            local NEXT = { auto = "world", world = "worldScreen", worldScreen = "worldFull", worldFull = "screen", screen = "auto" }
            local now = Camera.source or "auto"
            live:addOption("Camera picture from (without FrameHook): " .. now .. " (next: " .. NEXT[now] .. ")", nil, function()
                local nxt = NEXT[now]
                Camera.source = nxt ~= "auto" and nxt or nil
                KnoxMobile.Client.toast("Camera picture from " .. nxt)
            end)
            live:addOption(Camera.flip and "Camera: flip the picture: turn off" or "Camera: flip the picture", nil, function()
                Camera.flip = not Camera.flip
            end)
            local active = knoxLiveCameraHooked and knoxLiveCameraHooked() == true
            live:addOption("Camera: copies the finished picture (FrameHook): " .. tostring(active and Camera.useHook)
                .. (active and " (switch)" or " (not applied)"), nil, function()
                Camera.useHook = not Camera.useHook
                KnoxMobile.Client.toast("FrameHook copy " .. (Camera.useHook and "on" or "off (older copy)"))
            end)
            live:addOption(Camera.hideSelf and "Camera: hide your character while it's open: turn off"
                or "Camera: hide your character while it's open", nil, function()
                Camera.hideSelf = not Camera.hideSelf
            end)
            live:addOption("Camera: what the last copy read (log)", nil, function()
                local text = "camera frame from: " .. tostring(knoxLiveCameraSource())
                Util.log(text)
                KnoxMobile.Client.toast(text)
            end)
        end
    end
    local story = sub(m, "Story")
    -- 0.2.0 depth features, for the PC test: what is rare or slow, now.
    story:addOption("Text back: answer now, and say where home is", nil, function()
        local phone = targetPhone(player)
        if phone then debug(player, { action = "textBackNow", phoneId = phone:getID() }) end
    end)
    story:addOption("Ring a phone in a zombie's pocket nearby", nil, function() debug(player, { action = "ringNow" }) end)
    story:addOption("A wrong number and a rumor, now", nil, function() debug(player, { action = "strangersNow" }) end)
    story:addOption("Fast-forward 1 day", nil, function() debug(player, { action = "storyForward", days = 1 }) end)
    story:addOption("Fast-forward 7 days", nil, function() debug(player, { action = "storyForward", days = 7 }) end)
    story:addOption("Text me (phone with a SIM)", nil, function()
        local phone = phoneWithSim(player)
        if phone then
            debug(player, { action = "textMe", phoneId = phone:getID() })
        else
            KnoxMobile.Client.toast("No phone you carry has a SIM. Try \"Put your SIM in the held phone\" first.")
        end
    end)
    story:addOption("Show phone owners", nil, function() showOwners(player) end)
    story:addOption("Show story places", nil, function() debug(player, { action = "storyPlaces" }) end)
    story:addOption("Family hunt: arm it now (set on the next chunk load)", nil, function()
        debug(player, { action = "storyPlaces", arm = true })
    end)

    local ps = sub(m, "Phone state (held or first phone)")
    -- Just above the warning thresholds, so the low-battery beeps come within a game minute or two.
    for _, v in ipairs({ { 0, "0 (dead)" }, { 5.05, "just above 5 (critical warning)" }, { 15.05, "just above 15 (low warning)" },
        { 50, "50" }, { 100, "100" } }) do
        ps:addOption("Battery " .. v[2], nil, function() setPhone(player, { battery = v[1] }) end)
    end
    for _, c in ipairs({ "mint", "scratched", "cracked", "broken" }) do
        ps:addOption("Condition: " .. c, nil, function() setPhone(player, { condition = c }) end)
    end
    for _, w in ipairs({ "dry", "damp", "waterDamaged" }) do
        ps:addOption("Wetness: " .. w, nil, function() setPhone(player, { wetness = w }) end)
    end
    ps:addOption("Battery health 40", nil, function() setPhone(player, { health = 40 }) end)
    ps:addOption("Rice: skip the day of drying", nil, function() setPhone(player, { riceDone = true }) end)

    m:addOption((KnoxMobile.TestScreen.enabled and "Turn off" or "Turn on") .. " test screen source", nil, function()
        KnoxMobile.TestScreen.enabled = not KnoxMobile.TestScreen.enabled
    end)
end))
