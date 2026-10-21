-- Client/server command names, payload checks and per-player rate limits (spec §13.2). Pure Lua 5.1.
local Protocol = {}

Protocol.MODULE = "KnoxMobile"
Protocol.MAX_TEXT = 320
Protocol.MAX_PASSWORD = 32

local Mod = require "KnoxMobile/Core/Mod"
local Sim = require("KnoxMobile/Core/Sim")

function Protocol._validateSendText(args)
    if type(args.to) ~= "string" then return false, "to must be a string" end
    local normalised = Sim.normalise(args.to)
    if normalised == nil or normalised ~= args.to then
        return false, "to is not a normalised phone number"
    end
    if type(args.body) ~= "string" then return false, "body must be a string" end
    if #args.body < 1 or #args.body > Protocol.MAX_TEXT then
        return false, "body must be 1-" .. Protocol.MAX_TEXT .. " characters"
    end
    return true
end

function Protocol._validatePlaceCall(args)
    if type(args.to) ~= "string" then return false, "to must be a string" end
    local normalised = Sim.normalise(args.to)
    if normalised == nil or normalised ~= args.to then
        return false, "to is not a normalised phone number"
    end
    return true
end

function Protocol._validateEndCall(_)
    return true
end

function Protocol._validateActivateSim(args)
    if type(args.simId) ~= "string" or #args.simId == 0 then
        return false, "simId must be a non-empty string"
    end
    return true
end

function Protocol._validatePlaceRepeater(args)
    if type(args.x) ~= "number" or Mod.floor(args.x, 1) ~= 0 then
        return false, "x must be an integer"
    end
    if type(args.y) ~= "number" or Mod.floor(args.y, 1) ~= 0 then
        return false, "y must be an integer"
    end
    if type(args.z) ~= "number" or Mod.floor(args.z, 1) ~= 0 or args.z < 0 or args.z > 7 then
        return false, "z must be an integer 0..7"
    end
    return true
end

function Protocol._validateConfigureRepeater(args)
    if type(args.id) ~= "string" or #args.id == 0 then
        return false, "id must be a non-empty string"
    end
    if type(args.private) ~= "boolean" then
        return false, "private must be a boolean"
    end
    if args.private then
        if type(args.password) ~= "string" then
            return false, "password must be a string"
        end
        if #args.password < 1 or #args.password > Protocol.MAX_PASSWORD then
            return false, "password must be 1-" .. Protocol.MAX_PASSWORD .. " characters"
        end
    end
    return true
end

function Protocol._validateRequestSync(_)
    return true
end

Protocol.COMMANDS = {
    sendText = Protocol._validateSendText,
    placeCall = Protocol._validatePlaceCall,
    endCall = Protocol._validateEndCall,
    activateSim = Protocol._validateActivateSim,
    placeRepeater = Protocol._validatePlaceRepeater,
    configureRepeater = Protocol._validateConfigureRepeater,
    requestSync = Protocol._validateRequestSync,
}

-- Feature modules add their own checks (group chats, classifieds, carrier, crew): { command = validator(args) }.
function Protocol.register(validators)
    for command, fn in pairs(validators) do Protocol.COMMANDS[command] = fn end
end

function Protocol.validate(command, args)
    local validator = Protocol.COMMANDS[command]
    if validator == nil then
        return false, "unknown command " .. tostring(command)
    end
    if command ~= "endCall" and command ~= "requestSync" then
        if type(args) ~= "table" then
            return false, "arguments must be a table"
        end
    end
    return validator(args)
end

function Protocol.newLimiter(perMinute, burst)
    local limiter = {
        perMinute = perMinute,
        burst = burst,
        players = {},
    }
    setmetatable(limiter, {
        __index = {
            allow = function(self, playerId, nowSeconds)
                local player = self.players[playerId]
                if player == nil then
                    player = { tokens = self.burst, lastTime = nowSeconds }
                    self.players[playerId] = player
                end

                local elapsed = nowSeconds - player.lastTime
                if elapsed > 0 then
                    local refill = elapsed * self.perMinute / 60
                    player.tokens = math.min(player.tokens + refill, self.burst)
                    player.lastTime = nowSeconds
                end

                if player.tokens >= 1 then
                    player.tokens = player.tokens - 1
                    return true
                end
                return false
            end
        }
    })
    return limiter
end

return Protocol