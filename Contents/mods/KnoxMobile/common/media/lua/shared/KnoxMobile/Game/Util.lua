-- Small game-side helpers shared by client and server: logging, safe event handlers, players, clock, settings.
local Sandbox = require "KnoxMobile/Core/Sandbox"
local Mod = require "KnoxMobile/Core/Mod"

local Util = {}

function Util.log(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    print("[KnoxMobile] " .. table.concat(parts, " "))
end

-- Power at a square: a generator (haveElectricity) or the town grid while it is still on (hasGridPower). Build 42
-- reports a lit house on the grid only through hasGridPower (PC test r5: charging said "no power" in lit houses).
function Util.powered(sq)
    if not sq then return false end
    if sq:haveElectricity() == true then return true end
    -- hasGridPower is true on every square while the grid is on (grass, forest, a car: PC test r7), so the grid only
    -- counts inside a building's rooms, where the outlets are.
    return sq.hasGridPower ~= nil and sq:hasGridPower() == true and sq:getRoom() ~= nil
end

-- True when a table has no keys. The game's Lua has no next().
function Util.isEmpty(t)
    for _ in pairs(t) do return false end -- luacheck: ignore 512
    return true
end

-- Wraps an event handler so an error is logged instead of breaking the game. The game also dumps a stack
-- trace for every caught error, so a handler that keeps failing is switched off: a bug in a per-tick or
-- per-square handler must never flood the log or stutter the game.
local MAX_ERRORS = 3
local failures = {}
function Util.safe(name, fn)
    return function(...)
        local count = failures[name] or 0
        if count >= MAX_ERRORS then return nil end
        local ok, err = pcall(fn, ...)
        if not ok then
            count = count + 1
            failures[name] = count
            Util.log("ERROR in " .. name .. ": " .. tostring(err))
            if count >= MAX_ERRORS then Util.log("switched off after " .. count .. " errors: " .. name) end
        end
        return ok and err or nil
    end
end

-- Error counts by handler name (the in-game self-test reports them).
function Util.failures() return failures end

-- Single player: no network, both "client" and "server" code run here.
function Util.isSingleplayer() return not isClient() and not isServer() end

-- Every player this machine is responsible for (all online players on a server, local players otherwise).
function Util.players()
    local out = {}
    if isServer() then
        local list = getOnlinePlayers()
        for i = 0, list:size() - 1 do out[#out + 1] = list:get(i) end
    else
        for n = 0, 3 do
            local p = getSpecificPlayer(n)
            if p then out[#out + 1] = p end
        end
    end
    return out
end

-- Who owns a SIM, a family story, a hunt site: the account name on a server; in single player an id saved in the
-- character's own mod data, made the first time it is asked for. The username reads "Bob" when play starts (r7), and
-- the player number is the same for the next character after a death (r8), so neither can be the key there.
-- Older builds used those, so a character from an older save remembers them for the server to adopt (Server.adoptLegacy).
function Util.playerKey(player)
    if Util.isSingleplayer() then
        local md = player:getModData()
        if type(md.KnoxMobileKey) ~= "string" then
            -- The name, the world minute it was first asked for and the player number: one id per character.
            local name = ""
            pcall(function()
                local d = player:getDescriptor()
                name = tostring(d:getForename() or "") .. tostring(d:getSurname() or "")
            end)
            md.KnoxMobileKey = "sp:" .. name:gsub("[^%w]", "") .. ":" .. tostring(math.floor(Util.nowMinutes())) .. ":"
                .. tostring(player:getPlayerNum())
            md.KnoxMobileLegacy = { "Bob", "player" .. tostring(player:getPlayerNum()), tostring(player:getUsername() or "") }
        end
        return md.KnoxMobileKey
    end
    local name = player:getUsername()
    if name and name ~= "" then return name end
    return "player" .. tostring(player:getPlayerNum())
end

-- In-game time.
function Util.nowMinutes() return getGameTime():getWorldAgeHours() * 60 end

-- The time of day (minutes after midnight) at a world-age minute (0 = the moment play began, not midnight).
-- Messaging stamps texts, pages and calls with it, so all stored minutes are clock minutes (PC test r5/r6).
function Util.clockMinute(stampMinute)
    local gt = getGameTime()
    local offset = Mod.floor((gt:getHour() * 60 + gt:getMinutes()) - Mod.floor(math.floor(Util.nowMinutes()), 1440), 1440)
    return Mod.floor(math.floor(stampMinute or 0) + offset, 1440)
end
function Util.nowDay() return getGameTime():getWorldAgeHours() / 24 end

-- Days the outbreak had run when play began: sandbox "time since the apocalypse" (1 = 0 months), as the game's
-- GameTime.getWorldAgeDaysSinceBegin adds it.
function Util.sinceBegin()
    local t = SandboxVars and SandboxVars.TimeSinceApo
    if type(t) ~= "number" or t < 1 then return 0 end
    return (math.floor(t) - 1) * 30
end

-- The world-age day the power grid shuts off, or nil if it never does. Vanilla keeps the grid on while the days
-- since the outbreak began are at most ElecShutModifier (SandboxOptions.doesPowerGridExist); "Never" is a huge number.
function Util.gridOffDay()
    local m = SandboxVars and SandboxVars.ElecShutModifier
    if type(m) ~= "number" then return 14 end
    if m >= 1000000 then return nil end
    return math.max(0, m - Util.sinceBegin())
end

function Util.settings()
    return Sandbox.read(SandboxVars and SandboxVars.KnoxMobile)
end

-- Power and wear settings in the shape Core/Power expects.
function Util.powerSettings(s)
    s = s or Util.settings()
    return {
        batteryLife = s.BatteryLifeMultiplier, chargeSpeed = s.ChargeSpeedMultiplier, batteryWear = s.BatteryWear,
        powerBankCapacity = s.PowerBankCapacity, exactChargers = s.ExactChargersForOldPhones,
        flashlightDrain = s.FlashlightDrain,
    }
end

-- Translated text with an English fallback; %1, %2... are filled from the extra arguments.
-- The game's getTextOrNull formats at once and logs a stack trace when a placeholder has no argument, so the
-- arguments always go with it (as strings: a Lua number would print as "3.0").
function Util.text(key, fallback, ...)
    local n = select("#", ...)
    local args = {}
    for i = 1, n do args[i] = tostring((select(i, ...))) end
    if n > 4 then error("Util.text takes at most 4 arguments: " .. tostring(key)) end
    local s = getTextOrNull(key, args[1], args[2], args[3], args[4])
    if s ~= nil and s ~= key then return s end
    s = fallback or key
    for i = 1, n do
        s = s:gsub("%%" .. i, (args[i]:gsub("%%", "%%%%")))
    end
    return s
end

-- The words for a code the server or the phone state uses (Data/Messages.words), translated: "the power bank" for
-- Util.word("Source", "powerBank"). An unknown code comes back as it is.
function Util.word(group, code)
    local words = require("KnoxMobile/Data/Messages").words[group]
    local english = words and code ~= nil and words[code]
    if not english then return tostring(code or "") end
    return Util.text("IGUI_KnoxMobile_Word_" .. group .. "_" .. tostring(code), english)
end

-- The debug menu: debug mode, or a server admin (not moderators, overseers, GMs or observers).
function Util.debugAllowed(player)
    if isDebugEnabled() then return true end
    if isClient() or isServer() then
        local level = player and player.getAccessLevel and player:getAccessLevel()
        return level ~= nil and tostring(level):lower() == "admin"
    end
    return false
end

return Util
