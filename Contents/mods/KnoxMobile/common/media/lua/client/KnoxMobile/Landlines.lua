-- Client: house phones that ring (after 0.3.0). Now and then a landline near you rings for a minute (the dead hear it;
-- server "landlineRang"). Walk up and right-click it: Answer the phone. While the county's lines still worked (Week
-- One's week before the outbreak) it's someone calling whoever lived there (Core/Voicemail, by the days); after the
-- lines went down (July 7-8), a dead line rings only at night, and nobody you can make out is on it.
-- Sandbox Stories > Ringing landlines.
local Machine = require "KnoxMobile/Core/Machine"
local Voicemail = require "KnoxMobile/Core/Voicemail"
local Story = require "KnoxMobile/Core/Story"
local Lang = require "KnoxMobile/Core/Lang"
local Rng = require "KnoxMobile/Core/Rng"
local Names = require "KnoxMobile/Story/Names"
local Util = require "KnoxMobile/Game/Util"
local Net = require "KnoxMobile/Game/Net"
local MachineUI = require "KnoxMobile/Machine"

local T = Util.text
local Landlines = { ringing = nil, nextAt = 0, CHECK_MS = 60000, REACH = 20, RING_MS = 45000,
    CHANCE_LIVE = 0.06, CHANCE_DEAD = 0.01 }
KnoxMobile.Landlines = Landlines

local function enabled()
    local sv = SandboxVars and SandboxVars.KnoxMobile
    return not (sv and sv.RingingLandlines == false)
end

-- A landline within reach of the player, one at random, or nil. Every square in reach is looked at (PC re-check R2:
-- 40 random squares of 1,681 found a house's one phone square about 2 % of the time, so a dead line rang about once
-- in 68 hours of night). It only runs when the dice already said "a ring now", once a real minute at most.
function Landlines.find(player, rng)
    local cell = getCell()
    if not cell then return nil end
    local px, py, pz = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())
    local R, found = Landlines.REACH, {}
    for x = px - R, px + R do
        for y = py - R, py + R do
            local sq = cell:getGridSquare(x, y, pz)
            if sq and MachineUI.phoneOn(sq) then found[#found + 1] = sq end
        end
    end
    if #found == 0 then return nil end
    return found[rng:int(1, #found)]
end

-- What the caller says when you answer, by the day.
function Landlines.words(rng, x, y, day)
    if day <= -2 then
        local who = rng:pick({ "mom", "dad", "friend", "friend" })
        local name = rng:pick(rng:chance(0.5) and Names.female or Names.male)
        return Lang.t("Hello?") .. " / " .. Voicemail.compose(rng, Story.fill, { who = who, phase = Voicemail.phaseFor(day),
            name = name, town = Machine.town(x, y) })
    end
    return Lang.t("Static. Something like breathing.") .. " / " .. Lang.t("Is anyone there?") .. " / "
        .. Lang.t("A click. The line is dead.")
end

function Landlines.ring(player, sq)
    Landlines.ringing = { x = sq:getX(), y = sq:getY(), z = sq:getZ(), untilMs = getTimestampMs() + Landlines.RING_MS }
    if KnoxMobile.Client then
        KnoxMobile.Client.ringsAt[#KnoxMobile.Client.ringsAt + 1] = { x = sq:getX(), y = sq:getY(), z = sq:getZ(),
            left = math.floor(Landlines.RING_MS / 3200), at = 0 }
    end
    Net.toServer(player, "landlineRang", { x = sq:getX(), y = sq:getY(), z = sq:getZ() })
    -- Once a game: how to answer it.
    if not Landlines.hinted and KnoxMobile.Client and KnoxMobile.Options then
        Landlines.hinted = true
        local key = KnoxMobile.Options.openKey()
        if KnoxMobile.Viewpoint then key = KnoxMobile.Viewpoint.phoneKey(key, KnoxMobile.Options.viewKey()) or key end
        local name = getKeyName and getKeyName(key) or "0"
        KnoxMobile.Client.toast(T("IGUI_KnoxMobile_LandlineHint",
            "A house phone is ringing. Walk up to it and press %1, or right-click it, to answer.", name), "hint")
    end
end

function Landlines.isRinging(sq)
    local r = Landlines.ringing
    return r ~= nil and getTimestampMs() <= r.untilMs and r.x == sq:getX() and r.y == sq:getY() and r.z == sq:getZ()
end

function Landlines.answer(sq)
    local r = Landlines.ringing
    Landlines.ringing = nil
    if KnoxMobile.Client then KnoxMobile.Client.ringsAt = {} end
    local day = math.floor(Util.sinceOutbreak())
    local rng = Rng.new("landline:" .. sq:getX() .. "," .. sq:getY() .. ":" .. math.floor(Util.nowMinutes()))
    local handler = Net.clientHandlers and Net.clientHandlers.callScripted
    if handler and r then
        local name = T("IGUI_KnoxMobile_Landline", "House phone")
        handler({ to = name, kind = "answer", name = name, lines = Landlines.words(rng, sq:getX(), sq:getY(), day) })
    end
end

-- The phone key answers a house phone ringing within two squares (first person: Viewpoint's crosshair menu has no
-- "Answer the phone", PC test 2026-11-06). True when it answered.
function Landlines.answerNear(player)
    local r = Landlines.ringing
    if not (r and player and getTimestampMs() <= r.untilMs) then return false end
    if math.floor(player:getZ()) ~= r.z or math.abs(player:getX() - r.x) > 2.5 or math.abs(player:getY() - r.y) > 2.5 then
        return false
    end
    local sq = getCell() and getCell():getGridSquare(r.x, r.y, r.z)
    if not sq or not Landlines.sameRoom(player:getCurrentSquare(), sq) then return false end
    Landlines.answer(sq)
    return true
end

-- In the phone's room (PC re-check: the living-room phone answered from the yard, through the wall).
function Landlines.sameRoom(here, phoneSq)
    if not (here and phoneSq) then return false end
    local ok, a, b = pcall(function() return phoneSq:getRoomID(), here:getRoomID() end)
    if ok and type(a) == "number" and type(b) == "number" then return a == -1 or a == b end
    local room = phoneSq.getRoom and phoneSq:getRoom()
    return room == nil or (here.getRoom and here:getRoom()) == room
end

-- How likely a ring is now: live lines in the week before; after that dead ones, and only at night by the clock
-- (PC test 22s: the hour came from hours since play began, so "night" fell around 5 AM to noon).
function Landlines.chanceNow(day, hour)
    if day <= -2 then return Landlines.CHANCE_LIVE end
    return (hour >= 22 or hour < 5) and Landlines.CHANCE_DEAD or 0
end

-- Every minute (real): maybe a landline nearby rings. Live lines in the week before; dead ones at night after.
function Landlines.check(player, rng)
    if not (player and enabled()) or Landlines.ringing then return nil end
    if not rng:chance(Landlines.chanceNow(Util.sinceOutbreak(), getGameTime():getHour())) then return nil end
    local sq = Landlines.find(player, rng)
    if sq then Landlines.ring(player, sq) end
    return sq
end

require("KnoxMobile/Game/Tick").add("landlines", function()
    local t = getTimestampMs()
    if t < Landlines.nextAt then return end
    Landlines.nextAt = t + Landlines.CHECK_MS
    local p = getSpecificPlayer(0)
    if p and not p:isDead() then Landlines.check(p, Rng.new("ll:" .. tostring(t))) end
end, 5000)

return Landlines
