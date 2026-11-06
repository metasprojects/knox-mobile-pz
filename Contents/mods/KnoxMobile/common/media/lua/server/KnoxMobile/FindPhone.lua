-- Server: Find my phone (after 0.3.0). The phone tick notes where each SIM was last carried (lastSeen[number] =
-- { x, y, z, key, at }). Call one of your own numbers whose phone nobody carries now, and it rings where it was last
-- seen (the dead hear it, and anyone near), and your Map pins "Your phone" there for an hour. A phone that was off when
-- it left your hands stays quiet.
local Util = require "KnoxMobile/Game/Util"
local State = require "KnoxMobile/State"
local Net = require "KnoxMobile/Game/Net"

local FindPhone = { PIN_MINUTES = 60, HEAR = 45 }
KnoxMobile.FindPhone = FindPhone

local function seen()
    local md = State.get()
    if type(md.lastSeen) ~= "table" then md.lastSeen = {} end
    return md.lastSeen
end

-- From the phone tick: this player carries this SIM number here, now.
function FindPhone.note(player, number, on)
    if not number then return end
    seen()[number] = { x = math.floor(player:getX()), y = math.floor(player:getY()), z = math.floor(player:getZ()),
        key = Util.playerKey(player), at = math.floor(Util.nowMinutes()), on = on ~= false }
end

-- The SIM left its phone (ejected or snapped): no phone to ring, so forget where it was (PC test 22b).
function FindPhone.forget(number)
    if number then seen()[number] = nil end
end

-- It rings where it lies: everyone close hears it, and so do the dead.
local function ring(x, y, z)
    for _, p in ipairs(Util.players()) do
        if math.abs(p:getX() - x) <= FindPhone.HEAR and math.abs(p:getY() - y) <= FindPhone.HEAR then
            Net.toClient(p, "ringAt", { x = x, y = y, z = z, rings = 6 })
            if not isServer() then break end
        end
    end
    pcall(addSound, nil, x, y, z, 15, 15)
end

-- A call to `number` that no carried phone answered. True when it was the caller's own lost phone (it rang).
function FindPhone.tryRing(player, number)
    if KnoxMobile.Burners and KnoxMobile.Burners.retired(number) then return false end
    local s = seen()[number]
    if not (s and s.key == Util.playerKey(player) and s.on) then return false end
    ring(s.x, s.y, s.z)
    local md = State.get()
    if type(md.findPins) ~= "table" then md.findPins = {} end
    md.findPins[s.key] = { x = s.x, y = s.y, until_ = Util.nowMinutes() + FindPhone.PIN_MINUTES }
    local d = math.floor(math.sqrt((player:getX() - s.x) ^ 2 + (player:getY() - s.y) ^ 2))
    Net.toClient(player, "notify", { kind = "findPhone", event = "ringing", number = d })
    Util.log("find my phone:", number, "rings at", s.x, s.y, s.z)
    return true
end

-- The Map pin, while it lasts.
function FindPhone.placesFor(player)
    local md = State.get()
    local pin = type(md.findPins) == "table" and md.findPins[Util.playerKey(player)]
    if not pin or Util.nowMinutes() > pin.until_ then return {} end
    return { { kind = "myphone", name = "", x = pin.x, y = pin.y } }
end

return FindPhone
