-- Phone models, screen families and charger connectors (spec §4, §6.1, §6.4, §12.3). Pure Lua 5.1.
-- A Registry instance holds validated phone definitions; Registry.withBundledPhones() loads the mod's own.

local Registry = {}
Registry.__index = Registry

-- Feature sets build up family by family, as in spec §4.6 ("Plus ...").
local function features(base, extra)
    local t = {}
    for k, v in pairs(base or {}) do t[k] = v end
    for _, k in ipairs(extra) do t[k] = true end
    return t
end

local SEGMENT = features(nil, { "calls", "texts", "alarm" })
local MONO = features(SEGMENT, { "games", "calculator" })
local COLOR = features(MONO, { "camera", "music", "polyphonic" })
local KEYBOARD = features(COLOR, { "fastTexting", "notes", "flashlight" })
local STYLUS = features(KEYBOARD, { "map", "video" })
local MODERN = features(STYLUS, { "clips", "tv" })

-- mixedUseHours: in-game hours of mixed use at multiplier 1 (spec §6.1 midpoints). videoHours: nonstop video.
-- label: the English name players see for the family (manuals, spare batteries).
local FAMILIES = {
    { id = "SegmentLCD", label = "Brick Phone", mixedUseHours = 48, videoHours = nil, wallpapers = false, features = SEGMENT },
    { id = "MonoLCD", label = "Basic Phone", mixedUseHours = 168, videoHours = nil, wallpapers = false, features = MONO },
    { id = "ColorFeature", label = "Color Screen Phone", mixedUseHours = 108, videoHours = 6, wallpapers = true,
        features = COLOR },
    { id = "Keyboard", label = "QWERTY Phone", mixedUseHours = 84, videoHours = 10, wallpapers = true, features = KEYBOARD },
    { id = "Stylus", label = "Stylus Phone", mixedUseHours = 48, videoHours = 8, wallpapers = true, features = STYLUS },
    { id = "ModernAndroid", label = "Touchscreen Phone", mixedUseHours = 60, videoHours = 20, wallpapers = true,
        features = MODERN },
    { id = "ModernPear", label = "PearPhone", mixedUseHours = 60, videoHours = 20, wallpapers = true, features = MODERN },
}

local CONNECTORS = { "Pin", "Flat", "MicroUSB", "PearPlug", "USBC" }
local USB = { MicroUSB = true, PearPlug = true, USBC = true }
local MULTITIP_FITS = { Pin = true, Flat = true }

local CAMERAS = { none = true, basic = true, good = true, great = true }
local RARITIES = { common = true, uncommon = true, rare = true, veryrare = true }
local EXTRAS = { fmRadio = true, flashlight = true, games = true, keyboard = true, outerScreen = true, stylus = true, gps = true }
local CASE_SIZES = { S = true, M = true, L = true, XL = true }

local familyById, connectorSet = {}, {}
for _, f in ipairs(FAMILIES) do familyById[f.id] = f end
for _, c in ipairs(CONNECTORS) do connectorSet[c] = true end

function Registry.rarityForYear(year)
    if year <= 2001 then return "common" end
    if year <= 2010 then return "uncommon" end
    if year <= 2019 then return "rare" end
    return "veryrare"
end

function Registry.isUsbConnector(connector)
    return USB[connector] == true
end

-- Returns true, or false plus a list of problems.
function Registry.validatePhone(def)
    local problems = {}
    local function need(cond, msg) if not cond then problems[#problems + 1] = msg end end
    need(type(def) == "table", "definition must be a table")
    if type(def) ~= "table" then return false, problems end
    need(type(def.id) == "string" and def.id:match("^[A-Za-z][A-Za-z0-9]*$") ~= nil, "id must be letters and digits")
    need(type(def.name) == "string" and #def.name > 0, "name is required")
    need(type(def.brand) == "string" and #def.brand > 0, "brand is required")
    need(type(def.year) == "number" and def.year >= 1993 and def.year <= 2026, "year must be 1993-2026")
    need(type(def.form) == "string" and #def.form > 0, "form is required")
    need(familyById[def.family] ~= nil, "unknown family " .. tostring(def.family))
    need(connectorSet[def.connector] == true, "unknown connector " .. tostring(def.connector))
    need(type(def.removableBattery) == "boolean", "removableBattery must be true or false")
    need(CAMERAS[def.camera] == true, "camera must be none, basic, good or great")
    need(type(def.toughness) == "number" and def.toughness >= 0 and def.toughness <= 1, "toughness must be 0-1")
    need(type(def.waterResistant) == "boolean", "waterResistant must be true or false")
    need(type(def.antenna) == "number" and def.antenna > 0 and def.antenna <= 3, "antenna must be above 0 and at most 3")
    need(type(def.weight) == "number" and def.weight > 0, "weight must be positive")
    need(type(def.colors) == "table" and #def.colors >= 2 and #def.colors <= 5, "2 to 5 colors")
    need(CASE_SIZES[def.caseSize] == true, "caseSize must be S, M, L or XL")
    need(def.rarity == nil or RARITIES[def.rarity] == true, "unknown rarity " .. tostring(def.rarity))
    need(def.mixedUseHours == nil or (type(def.mixedUseHours) == "number" and def.mixedUseHours > 0),
        "mixedUseHours must be positive")
    need(def.extras == nil or type(def.extras) == "table", "extras must be a list")
    if type(def.extras) == "table" then
        for _, e in ipairs(def.extras) do need(EXTRAS[e] == true, "unknown extra " .. tostring(e)) end
    end
    if #problems > 0 then return false, problems end
    return true
end

function Registry.new()
    return setmetatable({ byId = {}, list = {} }, Registry)
end

function Registry:addPhone(def)
    local ok, problems = Registry.validatePhone(def)
    if not ok then return false, (def and def.id or "?") .. ": " .. table.concat(problems, "; ") end
    if self.byId[def.id] then return false, def.id .. ": duplicate id" end
    local p = {}
    for k, v in pairs(def) do p[k] = v end
    p.extras = p.extras or {}
    p.rarity = p.rarity or Registry.rarityForYear(p.year)
    p.mixedUseHours = p.mixedUseHours or familyById[p.family].mixedUseHours
    p.videoHours = p.videoHours or familyById[p.family].videoHours
    self.byId[p.id] = p
    self.list[#self.list + 1] = p
    table.sort(self.list, function(a, b) return a.id < b.id end)
    return true
end

function Registry:getPhone(id) return self.byId[id] end
function Registry:phones() return self.list end
function Registry:families() return FAMILIES end
function Registry:family(id) return familyById[id] end

function Registry:connectors()
    local copy = {}
    for i, c in ipairs(CONNECTORS) do copy[i] = c end
    return copy
end

function Registry:byFamily(familyId)
    local out = {}
    for _, p in ipairs(self.list) do if p.family == familyId then out[#out + 1] = p end end
    return out
end

-- eraLimit: "All" or "1993Only" (sandbox EraLimit). In July 1993 only 1993 models existed.
function Registry:spawnable(eraLimit)
    if eraLimit ~= "1993Only" then return self.list end
    local out = {}
    for _, p in ipairs(self.list) do if p.year <= 1993 then out[#out + 1] = p end end
    return out
end

function Registry.hasExtra(phoneDef, extra)
    for _, e in ipairs(phoneDef.extras or {}) do if e == extra then return true end end
    return false
end

-- Can a phone with this connector take this charging setup?
-- setup.kind: "integrated" (wall or car charger with its own plug; setup.connector),
--             "cable" (USB cable; setup.connector), or "multitip" (universal multi-tip charger).
-- opts.exactChargers = false (sandbox ExactChargersForOldPhones off) lets any charger fit.
function Registry:canCharge(connector, setup, opts)
    local kind = setup and setup.kind
    if kind ~= "integrated" and kind ~= "cable" and kind ~= "multitip" then
        return false, "unknown charger kind " .. tostring(kind)
    end
    if opts and opts.exactChargers == false then return true end
    if kind == "multitip" then
        if MULTITIP_FITS[connector] then return true end
        return false, "the multi-tip charger has no " .. tostring(connector) .. " tip"
    end
    if setup.connector == connector then return true end
    return false, "wrong plug: " .. tostring(setup.connector) .. " does not fit " .. tostring(connector)
end

-- A registry with every phone that ships with the mod (KnoxMobile/Phones/Index).
function Registry.withBundledPhones()
    local r = Registry.new()
    for _, def in ipairs(require("KnoxMobile/Phones/Index")) do
        local ok, err = r:addPhone(def)
        if not ok then error("bad bundled phone " .. tostring(err)) end
    end
    return r
end

return Registry
