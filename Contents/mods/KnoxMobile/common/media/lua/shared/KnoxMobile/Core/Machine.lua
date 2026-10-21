-- Answering machines on house phones (2026-10-12): 1-3 messages left for the people who lived there, between
-- June 30 and July 7 1993 (the zone's phone lines went down on July 7-8). Pure Lua 5.1 and deterministic from the
-- phone's square alone, so every player hears the same tape in multiplayer and nothing is stored. The words are
-- translation codes (Data/Messages.words.Machine); the client says them (client/KnoxMobile/Machine.lua).
local Mod = require "KnoxMobile/Core/Mod"
local Rng = require "KnoxMobile/Core/Rng"
local Names = require "KnoxMobile/Story/Names"
local TowerSites = require "KnoxMobile/Data/TowerSites"

local Machine = {}

-- Message codes by the days they fit (day 0 = July 9 1993, the game's first day). Each takes %1 the resident's
-- first name, %2 who called, %3 the nearest town. `who` says who calls: family ("Mom", "Dad", "Grandma"), a
-- friend (a first name), or nobody (an automated line).
Machine.LINES = {
    { code = "dinner", from = -9, to = -6, who = "family" }, { code = "dentist", from = -9, to = -6, who = "friend" },
    { code = "dish", from = -9, to = -6, who = "friend" }, { code = "car", from = -9, to = -6, who = "friend" },
    { code = "birthday", from = -9, to = -6, who = "family" }, { code = "lake", from = -9, to = -6, who = "friend" },
    { code = "bill", from = -9, to = -6, who = "friend" },
    { code = "news", from = -5, to = -4, who = "family" }, { code = "fireworks", from = -5, to = -4, who = "friend" },
    { code = "stayHome", from = -5, to = -4, who = "family" }, { code = "school", from = -5, to = -4, who = "friend" },
    { code = "bridge", from = -3, to = -2, who = "family" }, { code = "busy", from = -3, to = -2, who = "friend" },
    { code = "soldiers", from = -3, to = -2, who = "family" }, { code = "county", from = -3, to = -2, who = "none" },
    { code = "scratched", from = -3, to = -2, who = "friend" },
}

Machine.FAMILY = { "Mom", "Dad", "Grandma" }
Machine.START_WEEKDAY = 5 -- July 9 1993 was a Friday (0 = Sunday)

function Machine.weekday(day) return Mod.floor((Machine.START_WEEKDAY + day), 7) end

-- The nearest real town to a point (the tower sites' towns, not the highway relays).
function Machine.town(x, y)
    local best, bestD = "Muldraugh", nil
    for _, s in ipairs(TowerSites.sites) do
        if s.town ~= "Highway" then
            local d = (s.x - x) ^ 2 + (s.y - y) ^ 2
            if not bestD or d < bestD then best, bestD = s.town, d end
        end
    end
    return best
end

-- The tape on the phone at (x, y, z). Returns { resident, messages = { { code, day, minute, weekday, args } } },
-- oldest first; args = { resident's first name, caller, town }.
function Machine.tape(x, y, z)
    local rng = Rng.new("machine:" .. tostring(x) .. "," .. tostring(y) .. "," .. tostring(z or 0))
    local female = rng:chance(0.5)
    local resident = rng:pick(female and Names.female or Names.male)
    local town = Machine.town(x, y)
    local n = rng:weighted({ { 1, 4 }, { 2, 4 }, { 3, 2 } })
    local pool = {}
    for i, l in ipairs(Machine.LINES) do pool[i] = l end
    local out = {}
    for _ = 1, n do
        local line = table.remove(pool, rng:int(1, #pool))
        local caller
        if line.who == "family" then caller = rng:pick(Machine.FAMILY)
        elseif line.who == "friend" then
            caller = rng:pick(rng:chance(0.5) and Names.female or Names.male)
            while caller == resident do caller = rng:pick(Names.male) end
        else caller = "" end
        local day = rng:int(line.from, line.to)
        -- The last day: the lines went down that morning.
        local minute = day == -2 and rng:int(6 * 60, 11 * 60 - 1) or rng:int(8 * 60, 22 * 60)
        out[#out + 1] = { code = line.code, day = day, minute = minute, weekday = Machine.weekday(day),
            args = { resident, caller, town } }
    end
    table.sort(out, function(a, b) return a.day * 1440 + a.minute < b.day * 1440 + b.minute end)
    return { resident = resident, messages = out }
end

-- Is this world object a landline phone? props: its sprite properties' CustomName.
function Machine.isPhone(customName) return customName == "Phone" end

return Machine
