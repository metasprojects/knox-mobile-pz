-- Client: the in-game self-test (-debug only: debug menu → Knox Mobile (admin) → Run all tests). It runs the mod against the
-- real game, which the fake game in tests/smoke cannot stand in for: every item script, icon, frame texture,
-- sandbox option and translation, then every phone opened and drawn for a moment. Each check writes one line,
-- "[KnoxMobile] SELFTEST PASS|FAIL <check>: <detail>", to console.txt, and a summary shows on screen.
-- Single player only: it adds and removes items in the player's own inventory.
local Phones = require "KnoxMobile/Game/Phones"
local Util = require "KnoxMobile/Game/Util"
local ItemIds = require "KnoxMobile/ItemIds"
local Sandbox = require "KnoxMobile/Core/Sandbox"
local Frames = require "KnoxMobile/Data/Frames"
local Tick = require "KnoxMobile/Game/Tick"

local SelfTest = {}
KnoxMobile.SelfTest = SelfTest

local passed, failed = 0, 0
-- One line per check; okDetail is shown on a pass, failDetail on a failure.
local function result(ok, name, okDetail, failDetail)
    if ok then passed = passed + 1 else failed = failed + 1 end
    local detail = failDetail
    if ok then detail = okDetail end
    Util.log("SELFTEST " .. (ok and "PASS " or "FAIL ") .. name .. (detail and (": " .. detail) or ""))
end

-- Up to 8 names, then a count, so one line stays readable.
local function names(list)
    local shown = {}
    for i = 1, math.min(8, #list) do shown[i] = list[i] end
    local s = table.concat(shown, ", ")
    if #list > 8 then s = s .. " and " .. (#list - 8) .. " more" end
    return s
end

local function wait(ticks) for _ = 1, ticks do coroutine.yield() end end

-- Waits until done() is true or the ticks run out; true when it happened.
local function waitFor(done, ticks)
    for _ = 1, ticks do
        if done() then return true end
        coroutine.yield()
    end
    return done()
end

local function heldBy(player, item)
    if player:getSecondaryHandItem() == item then return "off hand" end
    if player:getPrimaryHandItem() == item then return "main hand" end
    return nil
end

local function checkItems()
    local missing, noIcon, noName = {}, {}, {}
    local ids = ItemIds.all()
    for _, id in ipairs(ids) do
        local full = ItemIds.full(id)
        local ok, item = pcall(instanceItem, full)
        if not ok or not item then
            missing[#missing + 1] = id
        else
            local tex = item:getTex()
            if not tex or tostring(tex:getName()):find("Question") then noIcon[#noIcon + 1] = id end
            local display = tostring(item:getDisplayName())
            if display == "" or display:find("^KnoxMobile%.") or display == id then noName[#noName + 1] = id end
        end
    end
    result(#missing == 0, "item scripts", #ids .. " items", "not in the game: " .. names(missing))
    result(#noIcon == 0, "item icons", nil, "no icon: " .. names(noIcon))
    result(#noName == 0, "item names", nil, "untranslated: " .. names(noName))
end

local function checkTextures()
    local missing, count = {}, 0
    for _, model in ipairs(Phones.registry:phones()) do
        local artId = model.look or model.id
        if Frames[artId] then
            for _, color in ipairs(model.colors) do
                local path = "media/ui/KnoxMobile/frames/" .. artId .. "_" .. tostring(color):gsub("[^%w]", "") .. ".png"
                count = count + 1
                if not getTexture(path) and not getTexture("media/ui/KnoxMobile/frames/" .. artId .. ".png") then
                    missing[#missing + 1] = artId .. "/" .. tostring(color)
                end
            end
        end
    end
    result(#missing == 0, "phone frame textures", count .. " frames", "missing: " .. names(missing))
end

local function checkSandbox()
    local vars = SandboxVars and SandboxVars.KnoxMobile
    local missing = {}
    for _, opt in ipairs(Sandbox.OPTIONS) do
        if not vars or vars[opt.name] == nil then missing[#missing + 1] = opt.name end
    end
    result(#missing == 0, "sandbox options", #Sandbox.OPTIONS .. " options", "not loaded: " .. names(missing))
end

local function checkTranslations()
    local keys = { "IGUI_KnoxMobile_EnterPin", "IGUI_KnoxMobile_WrongPin", "IGUI_KnoxMobile_LockNow",
        "IGUI_KnoxMobile_OptOpenKey", "IGUI_KnoxMobile_PhoneFroze" }
    local missing = {}
    for _, k in ipairs(keys) do if not getTextOrNull(k) then missing[#missing + 1] = k end end
    result(#missing == 0, "translations", nil, "missing: " .. names(missing))
end

-- What the game resolves for a phone's in-hand model: the model script, its mesh and the hand attachment.
local function heldModel(item)
    local name = item:getStaticModel()
    if not name or name == "" then return false, "no StaticModel" end
    local script = getScriptManager():getModelScript(name)
        or getScriptManager():getModelScript("KnoxMobile." .. tostring(name))
    if not script then return false, "model script " .. tostring(name) .. " not found" end
    local prop2 = script:getAttachmentById("Bip01_Prop2")
    return prop2 ~= nil, "model " .. tostring(script:getName()) .. ", mesh " .. tostring(script:getMeshName())
        .. ", texture " .. tostring(script:getTextureName()) .. ", hand attachment " .. (prop2 and "yes" or "MISSING")
end

-- Every phone: added, switched on, opened and drawn for a second, held, a key pressed, closed and removed.
local function checkPhones(player)
    local inv = player:getInventory()
    for _, model in ipairs(Phones.registry:phones()) do
        local full = ItemIds.full(ItemIds.phone(model, model.colors[1]))
        local item = inv:AddItem(full)
        if not item then
            result(false, "phone " .. model.id, nil, "could not be created")
        else
            item:getModData().KnoxMobileOrigin = "start"
            local state = Phones.get(item)
            state.power.on, state.battery.charge = true, 80
            KnoxMobile.UI.open(player, item)
            -- Raising the phone is a timed action (it can wait behind putting the last one away): up to 10 s.
            waitFor(function() return heldBy(player, item) ~= nil end, 600)
            local inHand = heldBy(player, item)
            local modelOk, modelInfo = heldModel(item)
            result(inHand ~= nil and modelOk, "held " .. model.id, (inHand or "") .. "; " .. modelInfo,
                (inHand and (inHand .. "; ") or "NOT in a hand; ") .. modelInfo)
            local panel = KnoxMobile.UI.panel
            local open = panel ~= nil and panel.item == item
            if open then
                panel:input({ type = "key", key = "down" })
                panel:input({ type = "key", key = "select" })
                wait(15)
                open = KnoxMobile.UI.panel ~= nil
            end
            result(open, "phone " .. model.id, "opens, draws and takes keys", "closed itself (see ERROR lines above)")
            -- The arm pose: the item's hand mask reaches the animation variables (AnimSets maskingleft/right).
            if inHand then
                local var = inHand == "off hand" and "LeftHandMask" or "RightHandMask"
                local want = inHand == "off hand" and "knoxphonehold" or "knoxphoneholdright"
                local mask = tostring(player:getVariableString(var)):lower()
                result(mask == want, "pose " .. model.id, var .. " = " .. mask, var .. " is " .. mask .. ", not " .. want)
            end
            -- Every app on this phone opens and draws.
            panel = KnoxMobile.UI.panel
            if open and panel and KnoxMobile.Apps and KnoxMobile.Apps.forFamily then
                local apps, broke = KnoxMobile.Apps.forFamily(panel.family, panel.model), nil
                for _, app in ipairs(apps) do
                    KnoxMobile.UI.panel:openApp(app.id)
                    wait(3)
                    if not KnoxMobile.UI.panel then broke = app.id; break end
                    KnoxMobile.UI.panel:goHome()
                end
                result(broke == nil, "apps " .. model.id, #apps .. " apps open", "the " .. tostring(broke) .. " app closed the phone")
                if broke then KnoxMobile.UI.open(player, item) end
            end
            KnoxMobile.UI.close()
            -- Put away (a timed action too) before the test phone is removed.
            waitFor(function() return heldBy(player, item) == nil end, 600)
            wait(5)
            if item:getContainer() then item:getContainer():Remove(item) end
        end
    end
end

local function checkHandlers()
    local broken = {}
    for name, count in pairs(Util.failures()) do broken[#broken + 1] = name .. " (" .. count .. ")" end
    table.sort(broken)
    result(#broken == 0, "event handlers", "no errors since the game started", "errored: " .. names(broken))
end

-- The call pose: during a call the KnoxPhoneCall animation variable is on (AnimSets KnoxMobile_PhoneEar).
local function checkCallPose(player)
    local Client = KnoxMobile.Client
    if not Client or Client.call then return end
    Client.call = { status = "outgoing" }
    wait(5)
    local on = player:getVariableBoolean("KnoxPhoneCall")
    Client.call = nil
    wait(5)
    local off = not player:getVariableBoolean("KnoxPhoneCall")
    result(on and off, "call pose", "KnoxPhoneCall on during a call, off after", "KnoxPhoneCall was " .. tostring(on)
        .. " on a call and " .. tostring(not off) .. " after")
end

-- Project Viewpoint, live: switch to a 3D view, open a phone (cursor freed; held up large in first person), switch
-- back. Viewpoint's public API only cycles isometric and the last 3D view used, which is third person after a launch;
-- first and third are swapped by its own key (Shift+O), so the test checks whichever 3D view it reaches (r8).
local function checkViewpointLive(player)
    local VP = KnoxMobile.Viewpoint
    if not Viewpoint or not VP or not Viewpoint.View then return end
    if not VP.active() then
        Viewpoint.View.cycle()
        waitFor(function() return VP.active() end, 180)
    end
    if not VP.active() then
        result(false, "viewpoint 3D view", nil, "could not leave the isometric view (finish Viewpoint's setup window first)")
    else
        local view = VP.view()
        local item = player:getInventory():AddItem("KnoxMobile.SupernovaIV_BlackMist")
        item:getModData().KnoxMobileOrigin = "start"
        local state = Phones.get(item)
        state.power.on, state.battery.charge = true, 80
        KnoxMobile.UI.open(player, item)
        waitFor(function() return heldBy(player, item) ~= nil end, 600)
        wait(30)
        local panel = KnoxMobile.UI.panel
        local layoutOk = panel ~= nil and (panel.firstPerson == true) == (view == "first")
        local ok = panel ~= nil and panel.captured == true and layoutOk
        result(ok, "viewpoint " .. view .. " person", "phone open, cursor freed" .. (view == "first" and ", held up large" or "")
            .. " (" .. tostring(heldBy(player, item)) .. ")" .. (view == "first" and ""
                or "; first person is reached with Viewpoint's Shift+O, not its API"),
            "panel " .. tostring(panel ~= nil) .. ", cursor freed " .. tostring(panel and panel.captured)
                .. ", layout for " .. view .. " " .. tostring(layoutOk))
        KnoxMobile.UI.close()
        waitFor(function() return heldBy(player, item) == nil end, 600)
        if item:getContainer() then item:getContainer():Remove(item) end
    end
    if VP.active() then
        Viewpoint.View.cycle()
        waitFor(function() return not VP.active() end, 180)
    end
    result(VP.view() == "isometric", "viewpoint back to isometric", nil, "still in " .. VP.view() .. " (press O)")
end

-- Project Viewpoint (client/KnoxMobile/Viewpoint.lua): on or not, the view now, and the phone key in its views.
local function checkViewpoint()
    local VP = KnoxMobile.Viewpoint
    if not Viewpoint or not VP then
        result(true, "viewpoint", "not installed (the isometric view only)")
        return
    end
    local Options = KnoxMobile.Options
    local openKey, viewKey = Options.openKey(), Options.viewKey()
    local fpKey = viewKey
    if not fpKey or fpKey == 0 or fpKey == Keyboard.KEY_NONE then
        fpKey = VP.interfaceKey() ~= openKey and openKey or nil
    end
    local function name(k) return k and (getKeyName and getKeyName(k) or tostring(k)) or "none" end
    result(true, "viewpoint", "on, view " .. VP.view() .. ", Viewpoint Interface " .. (ViewpointUI and "on" or "off")
        .. ", phone key: " .. name(openKey) .. " (isometric), " .. name(fpKey) .. " (first/third person)")
end

local running = nil

function SelfTest.run(player)
    if running then return end
    if not Util.isSingleplayer() then
        if KnoxMobile.Client then KnoxMobile.Client.toast("The self-test runs in single player only.") end
        return
    end
    passed, failed = 0, 0
    Util.log("SELFTEST START")
    running = coroutine.create(function()
        checkItems()
        checkTextures()
        checkSandbox()
        checkTranslations()
        checkPhones(player)
        checkCallPose(player)
        checkViewpoint()
        checkViewpointLive(player)
        checkHandlers()
    end)
end

-- Knox-Run-All-Tests.cmd leaves "run" in Zomboid/Lua/knox_autotest.txt: the tests start by themselves shortly
-- after a game loads, and the file is set to "done".
local AUTO_FILE = "knox_autotest.txt"
local autoAt = nil
Events.OnGameStart.Add(Util.safe("self-test auto", function()
    local ok, line = pcall(function()
        local r = getFileReader(AUTO_FILE, false)
        if not r then return nil end
        local l = r:readLine()
        r:close()
        return l
    end)
    if not ok or line ~= "run" then return end
    pcall(function()
        local w = getFileWriter(AUTO_FILE, true, false)
        w:write("done")
        w:close()
    end)
    autoAt = getTimestampMs() + 15000
    if KnoxMobile.Client then KnoxMobile.Client.toast("Knox Mobile tests start in 15 seconds. Hands off for a minute.") end
end))

Tick.add("self-test", function()
    if autoAt and getTimestampMs() >= autoAt then
        autoAt = nil
        SelfTest.run(getPlayer())
    end
    if not running then return end
    local ok, err = coroutine.resume(running)
    if not ok then result(false, "self-test", nil, "crashed: " .. tostring(err)) end
    if not ok or coroutine.status(running) == "dead" then
        running = nil
        local summary = "Knox Mobile self-test: " .. passed .. " passed, " .. failed .. " failed"
        Util.log("SELFTEST DONE " .. passed .. " passed, " .. failed .. " failed")
        if KnoxMobile.Client then KnoxMobile.Client.toast(summary) end
    end
end)

return SelfTest
