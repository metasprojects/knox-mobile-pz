-- Server: the Classifieds board (Core/Classifieds). Reading and posting need service. A listing carries the poster's
-- number so others can text them; it ends after sandbox ClassifiedsDays in-game days. Three listings per player,
-- one an in-game hour; the poster or a moderator (Game/Access) takes one down.
local Classifieds = require "KnoxMobile/Core/Classifieds"
local Protocol = require "KnoxMobile/Core/Protocol"
local Util = require "KnoxMobile/Game/Util"
local Net = require "KnoxMobile/Game/Net"
local Access = require "KnoxMobile/Game/Access"
local Messaging = require "KnoxMobile/Messaging"
local Social = require "KnoxMobile/SocialData"

local Board = {}

Protocol.register(Classifieds.validators)

local function board() return Social.data().board end

-- The phone with service, or nil after telling the player why.
local function ready(player, args)
    local item, state, model = Social.phone(player, args)
    local why = state
    if item then
        local located = Messaging.service(player, model)
        if located.network then return item, state end
        why = "noService"
    end
    Net.toClient(player, "boardResult", { status = "failed", reason = why, phoneId = args.phoneId })
    return nil
end

function Board.sendList(player, item)
    local now = Util.nowMinutes()
    Classifieds.expire(board(), now)
    Net.toClient(player, "boardList", { phoneId = item:getID(), now = now, moderator = Access.canModerate(player) or nil,
        posts = Classifieds.list(board(), now, Util.playerKey(player)) })
end

Net.onServer("boardList", function(player, args)
    if not Social.throttle(player, "boardList", 500) then return end
    local item = ready(player, args)
    if item then Board.sendList(player, item) end
end)

Net.onServer("boardPost", function(player, args)
    local item, state = ready(player, args)
    if not item then return end
    local key = Util.playerKey(player)
    local post, why, wait = Classifieds.post(board(), { key = key, number = state.sim.number, category = args.category,
        title = args.title, text = args.text }, Util.nowMinutes(), Util.settings().ClassifiedsDays)
    if not post then
        Net.toClient(player, "boardResult", { status = "failed", reason = why, wait = wait, phoneId = args.phoneId })
        return
    end
    Util.log("classified", post.id, "posted by", key, "(" .. post.category .. "):", post.title)
    Net.toClient(player, "boardResult", { status = "posted", id = post.id, phoneId = args.phoneId })
    Board.sendList(player, item)
end)

Net.onServer("boardRemove", function(player, args)
    local item = ready(player, args)
    if not item then return end
    local key = Util.playerKey(player)
    local post, why = Classifieds.remove(board(), args.id, key, Access.canModerate(player))
    if not post then
        Net.toClient(player, "boardResult", { status = "failed", reason = why, phoneId = args.phoneId })
        return
    end
    Util.log("classified", post.id, "taken down by", key, post.key ~= key and "(moderator)" or "")
    Net.toClient(player, "boardResult", { status = "removed", id = post.id, phoneId = args.phoneId })
    Board.sendList(player, item)
end)

-- Listings past their end leave the board even when nobody looks.
Events.EveryTenMinutes.Add(Util.safe("classifieds expiry", function()
    if isClient() then return end
    Classifieds.expire(board(), Util.nowMinutes())
end))

return Board
