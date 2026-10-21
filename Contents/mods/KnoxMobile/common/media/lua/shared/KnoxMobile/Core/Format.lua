-- Text for the phone's status bar, lock screen and notifications (spec §8.3, §8.5). Pure Lua 5.1.
local Mod = require "KnoxMobile/Core/Mod"

local Format = {}

-- 24h "14:05" or 12h "2:05 PM".
function Format.clock(hour, minute, use24)
    hour, minute = Mod.floor(math.floor(hour), 24), Mod.floor(math.floor(minute), 60)
    if use24 then return string.format("%02d:%02d", hour, minute) end
    local h = Mod.floor(hour, 12)
    if h == 0 then h = 12 end
    return string.format("%d:%02d %s", h, minute, hour < 12 and "AM" or "PM")
end

function Format.battery(charge)
    return tostring(math.floor(math.max(0, math.min(100, charge)) + 0.5)) .. "%"
end

-- 0..4 segments for a battery icon.
function Format.batteryLevel(charge)
    if charge <= 0 then return 0 end
    return math.max(1, math.min(4, math.ceil(charge / 25)))
end

-- Network name for the status bar: the carrier, or Knox Mobile+ (survivors added the plus) on player-built repeaters (before and after the
-- collapse; which repeater shows in Settings, not here). text: Util.text, for translation (plain English without it).
function Format.network(located, text)
    text = text or function(_, english) return english end
    if not located or not located.network then return text("IGUI_KnoxMobile_NoService", "No service") end
    if located.network == "world" then
        if located.via and located.via ~= "unknownMap" and tostring(located.via):sub(1, 1) == "R" then
            return text("IGUI_KnoxMobile_NetRelay", "Knox Mobile+")
        end
        return text("IGUI_KnoxMobile_NetCarrier", "Knox Mobile")
    end
    return text("IGUI_KnoxMobile_NetRelay", "Knox Mobile+")
end

-- "now", "5m", "3h", "2d" since a message.
function Format.ago(minutes)
    if minutes < 1 then return "now" end
    if minutes < 60 then return math.floor(minutes) .. "m" end
    if minutes < 1440 then return math.floor(minutes / 60) .. "h" end
    return math.floor(minutes / 1440) .. "d"
end

-- Shorten text to fit a line, adding "..." when cut.
function Format.ellipsis(text, maxChars)
    text = tostring(text or "")
    if #text <= maxChars then return text end
    if maxChars <= 3 then return text:sub(1, maxChars) end
    return text:sub(1, maxChars - 3) .. "..."
end

-- A 4-digit PIN with the first `typed` digits shown as dots: "**__".
function Format.pinMask(typed, length)
    length = length or 4
    return string.rep("*", math.min(typed, length)) .. string.rep("_", math.max(0, length - typed))
end

return Format
