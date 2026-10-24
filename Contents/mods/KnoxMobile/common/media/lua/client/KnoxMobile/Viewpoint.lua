-- Client: Project Viewpoint (Workshop 3809306528, first- and third-person views) support, through its public Lua
-- API only. Viewpoint stops mouse-look while a modal UI is up (UIManager.isModalVisible: a visible element with
-- capture), so the open phone captures the mouse in Viewpoint's views and the cursor is free to tap its screen and
-- keys; in the vanilla isometric view the phone never captures, and clicks around it still reach the world.
-- The held phone itself is the character's own model (item StaticModel, hand attachments and arm poses), which
-- Viewpoint renders like any held item.
local Tick = require "KnoxMobile/Game/Tick"
local Compat = {}
KnoxMobile.Viewpoint = Compat

-- "isometric", "first" or "third". Viewpoint.View.next() names the view a cycle goes to: from the isometric view your
-- last 3D view ("first" or "third"), from first person "third", from third person "isometric" (final test, third
-- pass). So "third" is either first person or the isometric view after third person; the change that led there
-- tells them apart (watched every few ticks from the start, see below).
local track = { next = nil, view = "isometric", swapAt = nil }
function Compat.view()
    local v = Viewpoint and Viewpoint.View
    if not v or not v.next then return "isometric" end
    local ok, n = pcall(v.next)
    if not ok then return "isometric" end
    if n ~= track.next then
        if n == "isometric" then track.view = "third"
        elseif n == "first" then track.view = "isometric"
        elseif n == "third" then
            -- From "first": the isometric view cycled into first person. From "isometric": third person went to
            -- first person (Viewpoint's "First or third person" key, just pressed: fourth pass) or to the isometric
            -- view. Not seen yet: the isometric view (the game starts there).
            local swapped = track.swapAt and getTimestampMs() - track.swapAt < 3000
            if track.next == "first" or (track.next == "isometric" and swapped) then track.view = "first"
            else track.view = "isometric" end
            track.swapAt = nil
        end
        track.next = n
    end
    return track.view
end

-- Viewpoint's "First or third person" key (keys.thirdPerson, Shift+O unless rebound): its name for hints, and a
-- press noted so the change it makes is read right.
local function keyText()
    local k = Viewpoint and Viewpoint.Keys
    if not (k and k.get) then return nil end
    local ok, text = pcall(k.get, "keys.thirdPerson")
    if ok and type(text) == "string" and text ~= "" then return text end
    return nil
end

function Compat.firstPersonKey()
    local text = keyText() or "SHIFT+O"
    -- "SHIFT+O" -> "Shift+O", without gsub captures: Kahlua passes nil for an empty capture (release test: the single
    -- letter "O" crashed the Camera app every frame).
    local parts = {}
    for word in text:gmatch("[^+]+") do parts[#parts + 1] = word:sub(1, 1):upper() .. word:sub(2):lower() end
    return table.concat(parts, "+")
end

-- The key read straight from the keyboard every tick (release test: with the phone open, key events never reached
-- an OnKeyPressed handler, so Shift+O went unseen and the Camera shot with the phone in hand). The binding's text
-- ("SHIFT+O") names the key and its modifiers.
local swapKey = { text = nil, code = nil, mods = nil, wasDown = false }
local function swapBinding()
    local text = (keyText() or "SHIFT+O"):upper()
    if text == swapKey.text then return swapKey end
    swapKey.text, swapKey.mods, swapKey.code = text, {}, nil
    for word in text:gmatch("[^+]+") do
        if word == "SHIFT" or word == "LSHIFT" or word == "RSHIFT" then swapKey.mods.shift = true
        elseif word == "CTRL" or word == "CONTROL" then swapKey.mods.ctrl = true
        elseif word == "ALT" then swapKey.mods.alt = true
        else swapKey.code = Keyboard["KEY_" .. word] end
    end
    swapKey.code = swapKey.code or Keyboard.KEY_O
    return swapKey
end

local function swapPressed()
    local b = swapBinding()
    local down = isKeyDown(b.code)
        and (not b.mods.shift or isShiftKeyDown())
        and (not b.mods.ctrl or isKeyDown(Keyboard.KEY_LCONTROL) or isKeyDown(Keyboard.KEY_RCONTROL))
        and (not b.mods.alt or isKeyDown(Keyboard.KEY_LMENU) or isKeyDown(Keyboard.KEY_RMENU))
    local pressed = down and not b.wasDown
    b.wasDown = down
    return pressed
end

-- Every tick: Viewpoint's first/third key; every few ticks: View.next(), so no change of view goes unseen.
local tick = 0
Tick.add("viewpoint keys", function()
    if Viewpoint and Viewpoint.View then
        local ok, pressed = pcall(swapPressed)
        if ok and pressed then
            track.swapAt = getTimestampMs()
            -- Within the 3D view it swaps first and third person at once: no need to wait for View.next().
            if track.view == "first" then track.view = "third" elseif track.view == "third" then track.view = "first" end
        end
    end
    tick = tick + 1
    if tick >= 5 then
        tick = 0
        pcall(Compat.view)
    end
end)

-- Is Viewpoint showing its own view (first or third person)?
function Compat.active() return Compat.view() ~= "isometric" end

-- Viewpoint Interface (Workshop 3812616893) opens its build list with its own key in Viewpoint's views, K by
-- default: the phone's key too. Its key, from the game's keybinds (VPUI_Build), or nil without that mod.
function Compat.interfaceKey()
    if not ViewpointUI then return nil end
    local ok, key = pcall(function() return getCore():getKey("VPUI_Build") end)
    if ok then return key end
    return nil
end

-- The key that opens the phone right now: the "first person" key in Viewpoint's views when one is set, else the
-- phone key, unless Viewpoint Interface builds with that same key there (nil: the phone leaves it alone).
function Compat.phoneKey(openKey, viewKey)
    if not Compat.active() then return openKey end
    if viewKey and viewKey ~= 0 and viewKey ~= Keyboard.KEY_NONE then return viewKey end
    if Compat.interfaceKey() == openKey then return nil end
    return openKey
end

return Compat
