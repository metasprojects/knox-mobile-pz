-- Payphones (1993 hardware). Pure Lua 5.1.
-- Vanilla B42's payphone is a wall object: tiles street_decoration_01_38, _39, _46 and _47 with CustomName "Phones"
-- and GroupName "Pay" (media/newtiledefinitions.tiles.txt). A payphone dials out like a phone: the call rings the
-- other phone through the same call code. Its own number comes from the SIM registry, one per payphone square.
local Mod = require "KnoxMobile/Core/Mod"
local Payphone = {}

Payphone.REACH = 2.5        -- tiles from the payphone to use it
Payphone.LEAVE = 6          -- walk this far away and the call drops (you let go of the handset)
Payphone.COIN_CENTS = 25    -- what the sign says a call costs (flavour: nobody takes your money)

function Payphone.isPayphone(customName, groupName)
    return customName == "Phones" and (groupName == nil or groupName == "Pay")
end

function Payphone.key(x, y, z) return tostring(x) .. "," .. tostring(y) .. "," .. tostring(z) end

-- Within `reach` tiles of the payphone square's centre, on the same floor.
function Payphone.near(px, py, pz, x, y, z, reach)
    if math.floor(pz) ~= z then return false end
    local dx, dy = px - (x + 0.5), py - (y + 0.5)
    local r = reach or Payphone.REACH
    return dx * dx + dy * dy <= r * r
end

-- "Call a number (25 cents)": the price as the sign shows it.
function Payphone.priceText(cents)
    cents = cents or Payphone.COIN_CENTS
    if cents < 100 then return tostring(cents) end
    return string.format("%d.%02d", math.floor(cents / 100), Mod.floor(cents, 100))
end

return Payphone
