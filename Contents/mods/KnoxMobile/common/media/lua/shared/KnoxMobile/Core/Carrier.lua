-- Carrier messages: a server admin's text to every phone, from "KNOX MOBILE" (restart warnings, events).
-- Pure Lua 5.1. The server keeps the state in world ModData: { sent = { real seconds }, log = { { at, by, body } } }.
local Carrier = {}

Carrier.FROM = "KNOX MOBILE" -- the sender shown on every phone; never a dialable number, so it can't be answered
-- The automatic alerts' own thread (Core/Alerts, server/KnoxMobile/CarrierAlerts.lua): shutoffs, helicopter, weather,
-- news. Unlike admin texts they need service, so they never wait in the queue. Not flagged carrier on the phone, so
-- the Messages app titles the thread with its own name and it never merges with this one.
Carrier.ALERT_FROM = "KNOX MOBILE ALERT"
Carrier.MAX_TEXT = 160       -- one carrier text
Carrier.COOLDOWN = 30        -- real seconds between carrier texts, server-wide
Carrier.PER_HOUR = 10        -- carrier texts per real hour, server-wide
Carrier.TTL = 1440           -- in-game minutes a carrier text waits for a phone that is off (then it's stale)
Carrier.LOG = 20             -- recent carrier texts kept in the world data

function Carrier.new() return { sent = {}, log = {} } end

-- One line, trimmed, single-spaced; nil when empty or too long.
function Carrier.clean(body)
    if type(body) ~= "string" then return nil end
    local s = body:gsub("%c", " "):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
    if #s == 0 or #s > Carrier.MAX_TEXT then return nil end
    return s
end

-- Times from before a restart can lie in the future when the clock changed; they no longer count.
local function recent(c, now)
    local keep = {}
    for _, t in ipairs(c.sent or {}) do
        if type(t) == "number" and t <= now and now - t < 3600 then keep[#keep + 1] = t end
    end
    c.sent = keep
    return keep
end

-- Returns true, or false plus "cooldown" or "hourly" and the seconds to wait.
function Carrier.allow(c, now)
    local list = recent(c, now)
    local last = list[#list]
    if last and now - last < Carrier.COOLDOWN then return false, "cooldown", math.ceil(Carrier.COOLDOWN - (now - last)) end
    if #list >= Carrier.PER_HOUR then return false, "hourly", math.ceil(3600 - (now - list[1])) end
    return true
end

function Carrier.record(c, now, by, body)
    recent(c, now)
    c.sent[#c.sent + 1] = now
    c.log = c.log or {}
    c.log[#c.log + 1] = { at = now, by = by, body = body }
    while #c.log > Carrier.LOG do table.remove(c.log, 1) end
end

function Carrier.validate(args)
    if type(args.body) ~= "string" or #args.body < 1 or #args.body > Carrier.MAX_TEXT then
        return false, "body must be 1-" .. Carrier.MAX_TEXT .. " characters"
    end
    return true
end

return Carrier
