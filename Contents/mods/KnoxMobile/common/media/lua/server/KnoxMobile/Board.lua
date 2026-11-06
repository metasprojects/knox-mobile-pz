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

-- Bounties (after 0.3.0, Core/Classifieds.collect): a player killed by another player. The bounties on them close;
-- the poster and the killer each get a text from the CLASSIFIEDS line. The reward is between them.
local function names(p)
    local out = {}
    pcall(function()
        local d = p:getDescriptor()
        out[#out + 1] = tostring(d:getForename() or "") .. " " .. tostring(d:getSurname() or "")
        out[#out + 1] = tostring(d:getForename() or "")
    end)
    pcall(function() out[#out + 1] = p:getUsername() end)
    return out
end

function Board.bountyKill(victim, killer)
    local killerKey = Util.playerKey(killer)
    local got = Classifieds.collect(board(), names(victim), killerKey)
    if #got == 0 then return 0 end
    local who = names(killer)[1] or "?"
    local killerNumber = Social.track(killer) or Social.numberOf(killerKey)
    local now = Util.nowMinutes()
    for _, p in ipairs(got) do
        Messaging.queueStory("CLASSIFIEDS", p.number, "BOUNTY: " .. who .. " collected your bounty on " .. p.title
            .. ". Pay up: " .. p.text, now)
        if killerNumber then
            Messaging.queueStory("CLASSIFIEDS", killerNumber, "BOUNTY: you collected the bounty on " .. p.title
                .. ". Reward: " .. p.text .. " Text " .. tostring(p.number) .. " to collect.", now)
        end
        Util.log("bounty", p.id, "on", p.title, "collected by", killerKey)
    end
    if Messaging.deliverDue then Messaging.deliverDue() end
    return #got
end

Events.OnCharacterDeath.Add(Util.safe("bounties", function(victim)
    if isClient() or not instanceof(victim, "IsoPlayer") then return end
    local ok, killer = pcall(function() return victim:getAttackedBy() end)
    if ok and killer and killer ~= victim and instanceof(killer, "IsoPlayer") then Board.bountyKill(victim, killer) end
end))

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
