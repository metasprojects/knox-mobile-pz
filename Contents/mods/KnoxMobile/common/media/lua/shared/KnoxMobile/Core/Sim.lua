-- SIM cards, phone numbers and contacts (spec §4.5, §4.7). Pure Lua 5.1.
-- The server owns the number registry (one per world); SIM data is a plain table saved on the SIM item.

local Sim = {}

Sim.MAX_CONTACTS = 100
-- Kentucky area codes in 1993 (270 and 859 came in 1999-2000). Decision (2026-10-19): most numbers are eastern
-- Kentucky's 606, with the odd Louisville 502. The 555 exchange keeps every number fictional.
local AREA_CODES = { "606", "606", "606", "502" }
local UNIQUE_CODES = 2

function Sim.newRegistry()
    return { issued = {}, count = 0 }
end

function Sim.saveRegistry(reg)
    local issued = {}
    for k, v in pairs(reg.issued) do issued[k] = v end
    return { issued = issued, count = reg.count }
end

function Sim.loadRegistry(data)
    local reg = Sim.newRegistry()
    if type(data) ~= "table" or type(data.issued) ~= "table" then return reg end
    for k, v in pairs(data.issued) do
        if v then reg.issued[k] = true; reg.count = reg.count + 1 end
    end
    return reg
end

function Sim.isIssued(reg, number) return reg.issued[number] == true end
function Sim.issuedCount(reg) return reg.count end

-- "(AAA) 555-NNNN" from any string holding 10 digits (or 7 digits, with area code 502).
-- Short numbers that dial (Core/Recordings): 911 and 411 directory assistance.
Sim.SHORT = { ["911"] = true, ["411"] = true }

-- A number the Phone app can dial: a normalised phone number or a short one; nil otherwise.
function Sim.dialable(text)
    local digits = tostring(text or ""):gsub("%D", "")
    if Sim.SHORT[digits] then return digits end
    return Sim.normalise(text)
end

function Sim.normalise(text)
    local digits = tostring(text or ""):gsub("%D", "")
    if #digits == 7 then digits = "502" .. digits end
    if #digits ~= 10 then return nil end
    return "(" .. digits:sub(1, 3) .. ") " .. digits:sub(4, 6) .. "-" .. digits:sub(7, 10)
end

-- Issues a number nobody in this world has. Server only.
function Sim.issueNumber(reg, rng)
    local capacity = UNIQUE_CODES * 10000
    if reg.count >= capacity then error("phone number space exhausted") end
    while true do
        local line = rng:int(0, 9999)
        local number = "(" .. rng:pick(AREA_CODES) .. ") 555-" .. string.format("%04d", line)
        -- 555-0100 to 0199 are Knox County's businesses and lines (Core/Recordings), never a SIM.
        if not reg.issued[number] and (line < 100 or line > 199) then
            reg.issued[number] = true
            reg.count = reg.count + 1
            return number
        end
    end
end

-- opts: { number, owner, contacts = { { name, number }, ... } }
function Sim.newSim(opts)
    opts = opts or {}
    local sim = { number = opts.number, owner = opts.owner, contacts = {} }
    for _, c in ipairs(opts.contacts or {}) do sim.contacts[#sim.contacts + 1] = { name = c.name, number = c.number } end
    return sim
end

function Sim.isBlank(sim) return sim.number == nil end

-- Gives a blank SIM its number the first time it is used; returns the SIM's number.
function Sim.activate(sim, reg, rng)
    if sim.number == nil then sim.number = Sim.issueNumber(reg, rng) end
    return sim.number
end

function Sim.findContact(sim, number)
    for _, c in ipairs(sim.contacts) do if c.number == number then return c end end
    return nil
end

function Sim.addContact(sim, name, number)
    if type(name) ~= "string" or #name == 0 or #name > 40 then return false, "name must be 1-40 characters" end
    if type(number) ~= "string" or #number == 0 then return false, "number required" end
    if Sim.findContact(sim, number) then return false, "already saved" end
    if #sim.contacts >= Sim.MAX_CONTACTS then return false, "contact list full" end
    sim.contacts[#sim.contacts + 1] = { name = name, number = number }
    return true
end

function Sim.removeContact(sim, number)
    for i, c in ipairs(sim.contacts) do
        if c.number == number then table.remove(sim.contacts, i); return true end
    end
    return false
end

-- Of several phones, only the one holding the SIM with this number rings (spec §4.7).
-- phones: list of { sim = { number } or nil, ... }.
function Sim.ringTarget(phones, number)
    for _, p in ipairs(phones) do
        if p.sim and p.sim.number == number then return p end
    end
    return nil
end

return Sim
