-- Who may use the admin parts of the community features. Build 42 grants powers through roles and capabilities
-- (player:getRole():hasCapability(Capability.X)), not the old access-level names:
--   carrier messages: DisplayServerMessage, the capability behind the game's own /servermsg;
--   taking down anyone's Classifieds listing: the same, or KickUser (moderators).
-- In single player only debug mode counts. The server checks again before doing anything.
local Util = require "KnoxMobile/Game/Util"

local Access = {}

local function has(player, capability)
    local ok, yes = pcall(function() return player:getRole():hasCapability(capability) end)
    return ok and yes == true
end

local function capability(name)
    local ok, c = pcall(function() return Capability[name] end)
    return ok and c or nil
end

function Access.canBroadcast(player)
    if not player then return false end
    if Util.isSingleplayer() then return isDebugEnabled() end
    local c = capability("DisplayServerMessage")
    return c ~= nil and has(player, c)
end

function Access.canModerate(player)
    if not player then return false end
    if Access.canBroadcast(player) then return true end
    if Util.isSingleplayer() then return false end
    local c = capability("KickUser")
    return c ~= nil and has(player, c)
end

return Access
