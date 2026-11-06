-- Server: voice memos (0.3.0, Core/Memos). "recordMemo" keeps one on the phone; "playMemo" plays one through the
-- speaker (a little noise near the player). Memos live in the phone's own state: contents.memos = { { body, day,
-- minute, mine } }.
local Memos = require "KnoxMobile/Core/Memos"
local Net = require "KnoxMobile/Game/Net"
local Phones = require "KnoxMobile/Game/Phones"
local Protocol = require "KnoxMobile/Core/Protocol"
local Messaging = require "KnoxMobile/Messaging"

Protocol.register({
    recordMemo = function(args)
        if type(args.phoneId) ~= "number" then return false, "phoneId must be a number" end
        if type(args.body) ~= "string" or #args.body < 1 or #args.body > Memos.MAX_LENGTH then
            return false, "body must be 1-" .. Memos.MAX_LENGTH .. " characters"
        end
        return true
    end,
    playMemo = function(args)
        if type(args.phoneId) ~= "number" then return false, "phoneId must be a number" end
        return true
    end,
})

local function usable(player, phoneId)
    local item = Phones.findById(player, phoneId)
    if not item or not Phones.isPhone(item) then return nil end
    local state, model = Phones.get(item)
    if not (state and state.power and state.power.on and Memos.fits(model)) or state.security.locked then return nil end
    return item, state
end

Net.onServer("recordMemo", function(player, args)
    local item, state = usable(player, args.phoneId)
    if not item then return end
    state.contents.memos = state.contents.memos or {}
    if #state.contents.memos >= Memos.MAX then table.remove(state.contents.memos, 1) end
    local day, minute = Messaging.stamp()
    table.insert(state.contents.memos, { body = args.body, mine = true, day = day, minute = minute })
    Phones.save(item, player)
end)

Net.onServer("playMemo", function(player, args)
    local item, state = usable(player, args.phoneId)
    if not item then return end
    if state.look and state.look.audioRoute and state.look.audioRoute ~= "speaker" then return end -- earbuds: private
    addSound(player, math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ()), Memos.PLAY_RADIUS,
        Memos.PLAY_RADIUS)
end)
