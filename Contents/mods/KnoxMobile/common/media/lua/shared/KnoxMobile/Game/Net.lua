-- Client/server messages that also work in single player (spec §13.2).
-- In single player the game's sendClientCommand/sendServerCommand do nothing, so handlers are called directly.
local Protocol = require "KnoxMobile/Core/Protocol"
local Util = require "KnoxMobile/Game/Util"

local Net = { serverHandlers = {}, clientHandlers = {} }

local limiter = Protocol.newLimiter(40, 15)
-- Ring noise pulses every few seconds, activity on every app change, hello once per join, pickedUp once per
-- phone. They get their own, much larger budget, so they can't crowd out texts and calls, but a crafted client
-- still can't spam the ones that do real work (pickedUp and hello scan inventories and sync items).
-- The community apps' read requests (groups, the Classifieds board, find my crew) come on every app open; they use the
-- cheap budget too, and each handler has its own short per-player throttle (server/KnoxMobile/SocialData.lua).
local CHEAP = { activity = true, noise = true, hello = true, pickedUp = true, groupList = true, boardList = true, crewFind = true }
local cheapLimiter = Protocol.newLimiter(240, 60)
-- A photo goes up in chunks (client Camera.lua: one every 120 ms, about 20 for a PearPhone photo); its own budget, so
-- an upload neither trips the limit nor uses up the one texts and calls share. The server caps uploads per player.
local BULK = { photoChunk = true }
local bulkLimiter = Protocol.newLimiter(600, 80)

-- Server side: handler(player, args).
function Net.onServer(command, handler) Net.serverHandlers[command] = handler end
-- Client side: handler(args).
function Net.onClient(command, handler) Net.clientHandlers[command] = handler end

local limitedLogged = {} -- one "rate limited" line per burst, so a spamming client can't flood the console

local function runServer(player, command, args)
    local handler = Net.serverHandlers[command]
    if not handler then return end
    -- The limit comes first: rejected payloads cost a log line, and they count against the sender too.
    -- Cheap, frequent reports use their own budget, so they can't crowd out texts and calls.
    if isServer() then
        local key = Util.playerKey(player)
        local budget = (BULK[command] and bulkLimiter) or (CHEAP[command] and cheapLimiter) or limiter
        if not budget:allow(key, getTimestampMs() / 1000) then
            if not limitedLogged[key] then Util.log("rate limited", command, "from", key) end
            limitedLogged[key] = true
            return
        end
        limitedLogged[key] = nil
    end
    -- A character from an older save takes over what older builds keyed by its name or player number (once).
    local adopt = KnoxMobile.Server and KnoxMobile.Server.adoptLegacy
    if adopt and player and player:getModData().KnoxMobileLegacy then adopt(player) end
    if Protocol.COMMANDS[command] then
        local ok, why = Protocol.validate(command, args)
        if not ok then Util.log("rejected", command, "from", Util.playerKey(player), ":", why); return end
    end
    Util.safe("server " .. command, handler)(player, args or {})
end

local function runClient(command, args)
    local handler = Net.clientHandlers[command]
    if handler then Util.safe("client " .. command, handler)(args or {}) end
end

-- From a client (or single player) to the server.
function Net.toServer(player, command, args)
    if isClient() then
        sendClientCommand(player, Protocol.MODULE, command, args or {})
    else
        runServer(player, command, args)
    end
end

-- From the server (or single player) to one player.
function Net.toClient(player, command, args)
    if isServer() then
        sendServerCommand(player, Protocol.MODULE, command, args or {})
    else
        runClient(command, args)
    end
end

-- From the server to everyone.
function Net.toAll(command, args)
    if isServer() then
        sendServerCommand(Protocol.MODULE, command, args or {})
    else
        runClient(command, args)
    end
end

Events.OnClientCommand.Add(function(module, command, player, args)
    if module == Protocol.MODULE then runServer(player, command, args) end
end)

Events.OnServerCommand.Add(function(module, command, args)
    if module == Protocol.MODULE then runClient(command, args) end
end)

return Net
