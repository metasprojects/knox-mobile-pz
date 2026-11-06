-- GPS search and directions (after 0.3.0) for the Map app. Search finds real places by kind or name (pharmacies, gas
-- stations, police, churches, schools, cell sites, towns); directions turn the place's bearing into "Turn left",
-- "Ahead" and so on from the way you face. Pure Lua 5.1. The world's x runs east and y south.
local Sites = require "KnoxMobile/Story/Sites"
local TowerSites = require "KnoxMobile/Data/TowerSites"

local Nav = { ARRIVE = 12, AHEAD = 25, BACK = 150, MAX = 8 }

-- Every searchable place: { kind, name, x, y, town }. Family houses stay out (they're the story's).
function Nav.places()
    local out = {}
    for _, s in ipairs(Sites.quests or {}) do out[#out + 1] = { kind = s.kind, name = s.name, x = s.x, y = s.y, town = s.town } end
    for _, s in ipairs(Sites.family or {}) do
        if s.kind ~= "house" then out[#out + 1] = { kind = s.kind, name = s.name, x = s.x, y = s.y, town = s.town } end
    end
    for _, s in ipairs(TowerSites.sites or {}) do
        out[#out + 1] = { kind = "tower", name = "cell site " .. s.code, x = s.x, y = s.y, town = s.town }
    end
    return out
end

-- Words people search with, by kind (English and Spanish).
Nav.WORDS = { pharmacy = { "pharmacy", "drug", "medicine", "meds", "farmacia", "medicina" },
    gas = { "gas", "fuel", "gasolina", "gasolinera" }, police = { "police", "sheriff", "cops", "policía", "policia" },
    church = { "church", "iglesia" }, school = { "school", "escuela" },
    tower = { "tower", "cell", "site", "torre", "antena" } }

local function matches(p, q)
    if tostring(p.name):lower():find(q, 1, true) or tostring(p.town or ""):lower():find(q, 1, true) then return true end
    for _, w in ipairs(Nav.WORDS[p.kind] or {}) do
        if w:find(q, 1, true) or q:find(w, 1, true) then return true end
    end
    return false
end

-- The nearest places matching the query (up to Nav.MAX), nearest first. list: Nav.places() or another list.
function Nav.search(query, px, py, list)
    local q = tostring(query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if q == "" then return {} end
    local found = {}
    for _, p in ipairs(list or Nav.places()) do
        if matches(p, q) then found[#found + 1] = { p = p, d = (p.x - px) ^ 2 + (p.y - py) ^ 2 } end
    end
    table.sort(found, function(a, b) return a.d < b.d end)
    local out = {}
    for i = 1, math.min(Nav.MAX, #found) do out[i] = found[i].p end
    return out
end

-- Which way to turn: facing (fx, fy), the place at (dx, dy) from you. "ahead", "left", "right", "back" or "here".
function Nav.turn(fx, fy, dx, dy)
    if dx * dx + dy * dy <= Nav.ARRIVE * Nav.ARRIVE then return "here" end
    local cross, dot = fx * dy - fy * dx, fx * dx + fy * dy
    local deg = math.deg(math.atan2(cross, dot))
    if math.abs(deg) <= Nav.AHEAD then return "ahead" end
    if math.abs(deg) >= Nav.BACK then return "back" end
    return deg > 0 and "right" or "left"
end

return Nav
