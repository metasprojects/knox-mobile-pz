-- Client: turn-by-turn guidance (after 0.3.0, Core/Nav). From a place on the Map: Enter, and the phone tells you which
-- way to go as you walk, a short notice whenever the turn changes (and every half minute), until you get there. Only
-- while some phone you carry is on.
local Nav = require "KnoxMobile/Core/Nav"
local Locate = require "KnoxMobile/Core/Locate"
local Phones = require "KnoxMobile/Game/Phones"
local Util = require "KnoxMobile/Game/Util"
local Tick = require "KnoxMobile/Game/Tick"

local T = Util.text
local Guide = { target = nil, place = nil, last = nil, lastAt = 0, REPEAT_MS = 30000 }
KnoxMobile.NavGuide = Guide

local WORDS = {
    ahead = function() return T("IGUI_KnoxMobile_NavAhead", "Straight ahead") end,
    left = function() return T("IGUI_KnoxMobile_NavLeft", "Turn left") end,
    right = function() return T("IGUI_KnoxMobile_NavRight", "Turn right") end,
    back = function() return T("IGUI_KnoxMobile_NavBack", "Turn around") end,
    here = function() return T("IGUI_KnoxMobile_NavHere", "You're there") end,
}

local function keyOf(p) return tostring(p.x) .. "," .. tostring(p.y) end

-- "Turn left, 340 m" for a place from where the player stands and faces; nil without a facing.
function Guide.say(player, p)
    local ok, f = pcall(function() return player:getForwardDirection() end)
    if not (ok and f) then return nil end
    local dx, dy = p.x - player:getX(), p.y - player:getY()
    local turn = Nav.turn(f:getX(), f:getY(), dx, dy)
    if turn == "here" then return WORDS.here(), turn end
    local m = math.floor(math.sqrt(dx * dx + dy * dy))
    return T("IGUI_KnoxMobile_NavLine", "%1, %2", WORDS[turn](), Locate.distance(m)), turn
end

function Guide.toggle(player, p)
    p.key = keyOf(p)
    if Guide.target == p.key then
        Guide.target, Guide.place = nil, nil
        return false
    end
    Guide.target, Guide.place, Guide.last, Guide.lastAt = p.key, p, nil, 0
    local text = Guide.say(player, p)
    if text and KnoxMobile.Client then KnoxMobile.Client.toast(text) end
    return true
end

local function phoneOn(player)
    for _, item in ipairs(Phones.inventoryPhones(player)) do
        local st = Phones.get(item)
        if st and st.power and st.power.on then return true end
    end
    return false
end

-- Every two seconds while guiding: a notice when the turn changes, or every half minute.
function Guide.step(player, nowMs)
    local p = Guide.place
    if not (p and player) then return nil end
    if not phoneOn(player) then Guide.target, Guide.place = nil, nil; return nil end
    local text, turn = Guide.say(player, p)
    if not text then return nil end
    if turn ~= Guide.last or nowMs - Guide.lastAt >= Guide.REPEAT_MS then
        Guide.last, Guide.lastAt = turn, nowMs
        if KnoxMobile.Client then KnoxMobile.Client.toast(text) end
        if turn == "here" then Guide.target, Guide.place = nil, nil end
        return text
    end
    return nil
end

Tick.add("nav guide", function()
    if Guide.place then Guide.step(getSpecificPlayer(0), getTimestampMs()) end
end, 2000)

return Guide
