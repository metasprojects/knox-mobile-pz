-- Player-built repeaters and the networks they form (spec §7.3). Pure Lua 5.1; distances in tiles.
-- A repeater: { id, x, y, z (floor), powered, destroyed, private, password, condition (0-100, worn out at 0) }.
-- Repeaters whose coverage circles overlap join one network (connected components).

local Signal = require "KnoxMobile/Core/Signal"
local Rng = require "KnoxMobile/Core/Rng"

local Repeaters = {}

Repeaters.FLOOR_BONUS = 0.15 -- extra range per floor above ground

function Repeaters.range(rep, settings)
    return (settings.repeaterRange or 300) * (1 + Repeaters.FLOOR_BONUS * math.max(0, rep.z or 0))
end

function Repeaters.isActive(rep)
    return rep.powered == true and not rep.destroyed and (rep.condition == nil or rep.condition > 0)
end

local function touchesTower(rep, liveTowers)
    for _, t in ipairs(liveTowers or {}) do
        if Signal.distance(rep.x, rep.y, t.x, t.y) <= (t.range or Signal.TOWER_RANGE) then return true end
    end
    return false
end

-- Returns networks { id = lowest member id, members = { sorted ids }, bridged = touches a live tower }.
-- liveTowers: optional list of { x, y, range }; a network touching a live tower reaches the world network.
function Repeaters.networks(reps, settings, liveTowers)
    local active = {}
    for _, r in ipairs(reps) do if Repeaters.isActive(r) then active[#active + 1] = r end end
    local seen, nets = {}, {}
    for i = 1, #active do
        if not seen[i] then
            seen[i] = true
            local queue, ids, bridged = { i }, {}, false
            while #queue > 0 do
                local a = table.remove(queue)
                local ra = active[a]
                ids[#ids + 1] = ra.id
                if touchesTower(ra, liveTowers) then bridged = true end
                local rangeA = Repeaters.range(ra, settings)
                for b = 1, #active do
                    if not seen[b] then
                        local rb = active[b]
                        if Signal.distance(ra.x, ra.y, rb.x, rb.y) <= rangeA + Repeaters.range(rb, settings) then
                            seen[b] = true
                            queue[#queue + 1] = b
                        end
                    end
                end
            end
            table.sort(ids)
            nets[#nets + 1] = { id = ids[1], members = ids, bridged = bridged }
        end
    end
    return nets
end

function Repeaters.networkOf(repId, nets)
    for _, n in ipairs(nets) do
        for _, id in ipairs(n.members) do if id == repId then return n end end
    end
    return nil
end

-- Clients never get the password itself, only this hash of it (spec §13.3 privacy).
function Repeaters.hashPassword(password)
    return "h" .. tostring(Rng.hash("knox-repeater:" .. tostring(password)))
end

-- The copy sent to clients: everything but the password.
function Repeaters.publicCopy(rep)
    local out = {}
    for k, v in pairs(rep) do if k ~= "password" then out[k] = v end end
    if rep.private and rep.password then out.passwordHash = Repeaters.hashPassword(rep.password) end
    return out
end

-- May this phone use this repeater? knownPasswords: set of passwords the phone knows. Works on the server's
-- copy (plain password) and on a client's copy (hash only).
function Repeaters.canUse(rep, settings, knownPasswords)
    if not rep.private or settings.allowPrivateRepeaters == false then return true end
    if knownPasswords == nil then return false end
    if rep.password ~= nil then return knownPasswords[rep.password] == true end
    if rep.passwordHash ~= nil then
        for pw, known in pairs(knownPasswords) do
            if known and Repeaters.hashPassword(pw) == rep.passwordHash then return true end
        end
    end
    return false
end

return Repeaters
