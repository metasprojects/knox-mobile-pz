-- Numeric pagers (1993 hardware): the Motormouth Bravo. Pure Lua 5.1.
-- A pager has a number from the same registry as SIM cards, receives numeric pages only (a callback number and a
-- code such as 911 or 411), keeps the last few, and runs about a week on one AA battery.
-- State (item ModData "KnoxMobile"): { number, on, alert = "beep" | "vibrate", charge 0..100, lastTick, pages }.
local Pager = {}

Pager.MAX_DIGITS = 20      -- characters a numeric page may hold (digits, spaces, dashes, * and #)
Pager.MAX_PAGES = 16       -- pages kept; the oldest scrolls off
Pager.WEEK_MINUTES = 7 * 24 * 60
Pager.ANTENNA = 1.3        -- paging receivers heard the carrier's transmitters a little better than a phone
Pager.BEEP_RADIUS = 8      -- zombie noise of the beep, before the sandbox noise multiplier (a phone ring is 5-25)

function Pager.newState()
    return { on = false, alert = "beep", charge = 0, pages = {} }
end

-- A stored table made safe to use (old or hand-edited data).
function Pager.normalise(state)
    if type(state) ~= "table" then return Pager.newState() end
    if type(state.pages) ~= "table" then state.pages = {} end
    if state.alert ~= "vibrate" then state.alert = "beep" end
    state.charge = math.max(0, math.min(100, tonumber(state.charge) or 0))
    state.on = state.on == true and state.charge > 0
    return state
end

-- A numeric page body: 1-20 characters of digits, spaces, dashes, * and #, with at least one digit. Returns the
-- trimmed body, or nil and the reason ("notNumeric", "tooLong", "empty").
function Pager.cleanPage(body)
    if type(body) ~= "string" then return nil, "empty" end
    local text = body:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
    if text == "" then return nil, "empty" end
    if text:find("[^%d%s%-%*#]") then return nil, "notNumeric" end
    if not text:find("%d") then return nil, "notNumeric" end
    if #text > Pager.MAX_DIGITS then return nil, "tooLong" end
    return text
end

function Pager.canReceive(state)
    return state ~= nil and state.on == true and state.charge > 0 and state.number ~= nil
end

-- Charge (0..100) after `minutes` switched on: a full AA lasts a week.
function Pager.drain(state, minutes)
    if not state.on or minutes <= 0 then return state.charge end
    state.charge = math.max(0, state.charge - minutes * 100 / Pager.WEEK_MINUTES)
    if state.charge <= 0 then state.on = false end
    return state.charge
end

-- Catches the pager up to `now` (minutes) since its last tick. Returns true when it just went dead.
function Pager.tick(state, now)
    local last = state.lastTick or now
    state.lastTick = now
    local wasOn = state.on
    Pager.drain(state, now - last)
    return wasOn and not state.on
end

-- A fresh AA: `fraction` is the battery's own charge (0..1). Returns false for a flat one.
function Pager.insertBattery(state, fraction)
    fraction = tonumber(fraction) or 0
    if fraction <= 0 then return false end
    state.charge = math.min(100, fraction * 100)
    return true
end

function Pager.addPage(state, from, body, day, minute)
    local pages = state.pages
    pages[#pages + 1] = { from = from, body = body, day = day, minute = minute, unread = true }
    while #pages > Pager.MAX_PAGES do table.remove(pages, 1) end
    return pages[#pages]
end

function Pager.unread(state)
    local n = 0
    for _, p in ipairs(state.pages) do if p.unread then n = n + 1 end end
    return n
end

function Pager.markRead(state)
    for _, p in ipairs(state.pages) do p.unread = nil end
end

-- Zombie noise radius for one alert: none on vibrate, half from inside a bag.
function Pager.alertRadius(state, inBag, noiseMultiplier)
    if state.alert == "vibrate" then return 0 end
    local r = Pager.BEEP_RADIUS * (noiseMultiplier or 1)
    if inBag then r = r / 2 end
    return r
end

return Pager
