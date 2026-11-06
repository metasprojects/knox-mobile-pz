-- Client: player options in the game's Mods options page (spec §8.1, §8.4): the open-phone key, phone
-- size and side, and HUD popups.
local Options = {}
KnoxMobile.Options = Options

local Util = require "KnoxMobile/Game/Util"

local T = Util.text
local SIZES = { "S", "M", "L" }
local SIDES = { "right", "left" }
local HANDS = { "off", "main" }

local opts = nil
if PZAPI and PZAPI.ModOptions then
    opts = PZAPI.ModOptions:create("KnoxMobile", "Knox Mobile")
    -- K: free in vanilla Build 42 (P opens the clothing protection panel).
    -- 0, not a letter: vanilla Build 42 binds every letter (K is Display FPS), and Viewpoint Interface builds with K.
    -- A new id ("phoneKey", was "openKey") so a saved K from older builds does not hold on to the old default.
    opts:addKeyBind("phoneKey", T("IGUI_KnoxMobile_OptOpenKey", "Open phone"), Keyboard.KEY_0,
        T("IGUI_KnoxMobile_OptOpenKeyTip", "Opens or closes the phone you hold or carry."))
    -- Project Viewpoint's first and third person (client/KnoxMobile/Viewpoint.lua): Viewpoint Interface builds with K.
    opts:addKeyBind("viewKey", T("IGUI_KnoxMobile_OptViewKey", "Open phone in first person"), Keyboard.KEY_NONE,
        T("IGUI_KnoxMobile_OptViewKeyTip",
            "For Project Viewpoint's views. None: the Open phone key, unless Viewpoint Interface uses that key there."))
    local size = opts:addComboBox("size", T("IGUI_KnoxMobile_OptSize", "Phone size"))
    for _, s in ipairs(SIZES) do size:addItem(Util.word("Size", s), s == "M") end
    local side = opts:addComboBox("side", T("IGUI_KnoxMobile_OptSide", "Phone side"))
    for _, s in ipairs(SIDES) do side:addItem(Util.word("Side", s), s == "right") end
    opts:addTickBox("popups", T("IGUI_KnoxMobile_OptPopups", "Notification popups"), true,
        T("IGUI_KnoxMobile_OptPopupsTip", "Show texts and alerts near the moodles when the phone is put away."))
    opts:addTickBox("clock24", T("IGUI_KnoxMobile_OptClock24", "24-hour clock"), false)
    -- The phone in the hand (R9 worklist): which hand holds it, the live screen on its 3D model (ZombieBuddy), and
    -- easier reading.
    local hand = opts:addComboBox("hand", T("IGUI_KnoxMobile_OptHand", "Hold the phone in"))
    hand:addItem(T("IGUI_KnoxMobile_OptHandOff", "Off hand (left)"), true)
    hand:addItem(T("IGUI_KnoxMobile_OptHandMain", "Main hand (right)"), false)
    opts:addTickBox("liveScreen", T("IGUI_KnoxMobile_OptLive", "Live screen on the phone in your hand"), true,
        T("IGUI_KnoxMobile_OptLiveTip", "The 3D phone in your hand shows what its screen shows. Needs ZombieBuddy."))
    -- Immersion (Meta, 2026-10-23): in first person, read the phone in your hand, with no on-screen phone.
    opts:addTickBox("immersive", T("IGUI_KnoxMobile_OptImmersive", "First person: read the phone in your hand"), true,
        T("IGUI_KnoxMobile_OptImmersiveTip",
            "Viewpoint first person: no on-screen phone; read the one in your main hand. Middle mouse switches. Needs ZombieBuddy."))
    -- 0.3.0: hands-free calls (the Java part's HandsFree): on Push to talk, the talk key counts as held during a call.
    opts:addTickBox("handsFree", T("IGUI_KnoxMobile_OptHandsFree", "Hands-free calls"), true,
        T("IGUI_KnoxMobile_OptHandsFreeTip",
            "With voice chat on Push to talk, just talk during a call: no key to hold. Needs ZombieBuddy."))
    opts:addTickBox("phoneLine", T("IGUI_KnoxMobile_OptPhoneLine", "Phone-line voice on calls"), true,
        T("IGUI_KnoxMobile_OptPhoneLineTip",
            "The other caller sounds like a 1990s cell line: narrow, and gritty when the signal is weak. Needs ZombieBuddy."))
    opts:addTickBox("bigText", T("IGUI_KnoxMobile_OptBigText", "Bigger text on phone screens"), false)
    opts:addTickBox("hud", T("IGUI_KnoxMobile_OptHud", "Phone status on screen"), true,
        T("IGUI_KnoxMobile_OptHudTip", "With the phone put away: new texts, bars and battery, small, top right."))
    opts:addTickBox("highContrast", T("IGUI_KnoxMobile_OptContrast", "High-contrast phone screens"), false,
        T("IGUI_KnoxMobile_OptContrastTip", "White on black, for the small LCD phones especially."))
end

local function value(id, default)
    local o = opts and opts:getOption(id)
    if not o then return default end
    return o:getValue()
end

function Options.openKey() return value("phoneKey", Keyboard.KEY_0) end
function Options.viewKey() return value("viewKey", Keyboard.KEY_NONE) end
-- After 0.3.0: in VR (client/KnoxMobile/Vr.lua) the medium default reads as large; a small phone picked on purpose stays.
local function vr() return KnoxMobile.Vr and KnoxMobile.Vr.active() end
function Options.size()
    local s = SIZES[value("size", 2)] or "M"
    if s == "M" and vr() then return "L" end
    return s
end
function Options.side() return SIDES[value("side", 1)] or "right" end
function Options.popups() return value("popups", true) end
function Options.clock24() return value("clock24", false) end
function Options.hand() return HANDS[value("hand", 1)] or "off" end
function Options.liveScreen() return value("liveScreen", true) end
function Options.immersive() return value("immersive", true) end
function Options.bigText() return value("bigText", false) or vr() == true end
function Options.handsFree() return value("handsFree", true) end
function Options.phoneLine() return value("phoneLine", true) end
function Options.highContrast() return value("highContrast", false) end
function Options.hud() return value("hud", true) end

return Options
