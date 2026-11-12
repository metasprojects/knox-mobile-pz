-- Client: PZVR (Workshop 3816830877; VR on top of Project Viewpoint and ZombieBuddy). 0.3.0 made the phone large and
-- its text big in VR. 0.3.1, from a VR player's report (2026-11-06: the floating phone works, the one in your hand is
-- a dead brick; with PZVR Survivor and Knox Inventory it never opened at all), puts the phone's screen on your hand:
--   PZVR Survivor: its window rule for mods (zone "wrist"), so the phone rides your off hand.
--   PZVR alone (or with Emmrsed): PZVR's palm page while your off-hand palm faces you; otherwise it floats as before.
-- While a headset is on, the phone never goes into Viewpoint's walk-and-look mode (that left the flat phone blank:
-- nothing to see or click), never takes the mouse (PZVR clicks by pointing), isn't raised into a hand (its screen is
-- on the palm), and the 3D phone in a hand hides while the screen is open (UI/Phone.lua, panel.vr).
-- Built without a headset from the VR mods' own Lua (docs/research/PZVR_INTEROP.md); every call into them is guarded,
-- and the console says what was done ("[KnoxMobile] VR:" lines) for VR players' reports.
local Util = require "KnoxMobile/Game/Util"

local Vr = { cached = nil, PALM_SCALE = 0.6 }
KnoxMobile.Vr = Vr

-- Is PZVR in the active mods? (B42 lists some ids with a leading backslash.)
function Vr.active()
    if Vr.cached ~= nil then return Vr.cached end
    local found = false
    pcall(function()
        local mods = getActivatedMods()
        for i = 0, mods:size() - 1 do
            local id = tostring(mods:get(i)):gsub("^\\", ""):upper()
            if id == "PZVR" then found = true end
        end
    end)
    Vr.cached = found
    return found
end

-- Is a headset session live right now? PZVR's own test; its VrApi exists only when its Java part loaded.
function Vr.running()
    if VrApi == nil then return false end
    local ok, status = pcall(function() return VrApi.status() end)
    return ok and tostring(status) == "VR_ACTIVE"
end

-- The hand that holds the phone's screen: the one that isn't pointing. PZVR numbers hands 0 = left, 1 = right, and
-- points with the dominant one.
function Vr.offHand()
    local ok, h = pcall(function() return VrApi.dominantHandIndex() end)
    return (ok and tonumber(h) == 0) and 1 or 0
end

-- The phone's window type for PZVR Survivor. Survivor seems to draw windows whose type starts with "Knox" on the Knox
-- Inventory screen (its "Knox" plane), so in VR with Survivor the phone goes by a name of its own.
Vr.SURVIVOR_TYPE = "MobilePhonePanelKM"

local function survivorRules()
    if not (PZVRSurvivor and PZVRSurvivor.registerWindow) then return end
    for _, kind in ipairs({ Vr.SURVIVOR_TYPE, "KnoxMobilePhonePanel" }) do
        local ok, err = pcall(PZVRSurvivor.registerWindow, kind, { zone = "wrist", scale = 0.7, force = true })
        if not ok then Util.log("VR: PZVR Survivor window rule failed: " .. tostring(err)) end
    end
end

-- The open phone while a headset is on.
local function vrPhone()
    local UI = KnoxMobile.UI
    local p = UI and UI.panel
    if p and p.vr and p:isVisible() then return p end
    return nil
end

-- PZVR without Survivor: while the off-hand palm faces you, the phone is PZVR's palm page (PZVR's own pages stand
-- aside) and doesn't float; with the palm turned away it floats as before. Wraps PZVR's hand UI tick.
local wrapped = false
local function wrapPalm()
    if wrapped or PZVRSurvivor ~= nil or not (PZVRHandUI and type(PZVRHandUI.tick) == "function") then return end
    wrapped = true
    local tick = PZVRHandUI.tick
    PZVRHandUI.tick = function(p, active, ...)
        local phone, palm = vrPhone(), false
        if phone then
            local ok, yes = pcall(function() return VrApi.palmVisible() and not VrApi.fullHud() end)
            palm = ok and yes == true
            if PZVRHandUI.baseline then PZVRHandUI.baseline[phone.javaObject] = palm or nil end
            if palm then PZVRHandUI.dismissed = true end
        end
        tick(p, active, ...)
        if palm then
            local ok, err = pcall(function()
                VrApi.palmScale(Vr.PALM_SCALE)
                VrApi.palmPage(phone.javaObject, phone:getAbsoluteX(), phone:getAbsoluteY(), phone:getWidth(),
                    phone:getHeight())
            end)
            if not ok and not Vr.palmFailed then
                Vr.palmFailed = true
                Util.log("VR: palm page failed: " .. tostring(err))
            end
        end
    end
end

-- UI.open: the phone panel, opened with a headset on.
function Vr.opened(panel)
    if not panel.vr then return end
    if PZVRSurvivor ~= nil then panel.Type = Vr.SURVIVOR_TYPE end
    Util.log("VR: phone open (" .. (PZVRSurvivor ~= nil and "PZVR Survivor, off hand" or "PZVR palm page")
        .. ", hand " .. Vr.offHand() .. ")")
end

Events.OnGameStart.Add(Util.safe("vr setup", function()
    if not Vr.active() then return end
    survivorRules()
    wrapPalm()
    Util.log("VR: PZVR " .. (VrApi ~= nil and "loaded" or "enabled, Java part not loaded")
        .. (PZVRSurvivor ~= nil and ", PZVR Survivor" or "")
        .. (EmmrsedVR ~= nil and ", Emmrsed" or "") .. (wrapped and ", palm page ready" or ""))
end))

return Vr
