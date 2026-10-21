-- The app slot (spec §12.2): validated app registrations, listed per screen family. Pure Lua 5.1.
-- Other mods register apps through KnoxMobile.Apps.register(def); the base mod still enforces power,
-- noise and service rules whichever app is open.

local Registry = require "KnoxMobile/Core/Registry"

local Apps = {}
Apps.__index = Apps

local DRAINS = { idle = true, screen = true, audio = true, games = true, video = true }
local CALLBACKS = { "onOpen", "render", "onInput", "onClose" }

local familyIds = {}
for _, f in ipairs(Registry.new():families()) do familyIds[f.id] = true end

function Apps.new()
    return setmetatable({ byId = {}, list = {} }, Apps)
end

local function validate(def)
    if type(def) ~= "table" then return "app definition must be a table" end
    if type(def.id) ~= "string" or not def.id:match("^[%w_]+$") then return "id must be letters, digits or _" end
    if type(def.name) ~= "string" or #def.name == 0 then return def.id .. ": name required" end
    if type(def.icon) ~= "string" then return def.id .. ": icon path required" end
    -- glyph (optional): a white pictogram on transparency, tinted with the screen's ink on mono LCDs.
    if def.glyph ~= nil and type(def.glyph) ~= "string" then return def.id .. ": glyph must be a texture path" end
    if type(def.families) ~= "table" or #def.families == 0 then return def.id .. ": list at least one family" end
    for _, f in ipairs(def.families) do
        if not familyIds[f] then return def.id .. ": unknown family " .. tostring(f) end
    end
    if not DRAINS[def.drain] then return def.id .. ": drain must be idle, screen, audio, games or video" end
    if def.needsService ~= nil and type(def.needsService) ~= "boolean" then return def.id .. ": needsService must be true or false" end
    if type(def.render) ~= "function" then return def.id .. ": render function required" end
    -- available (optional): function(model) -> false hides the app on that model (the Radio needs an FM tuner).
    if def.available ~= nil and type(def.available) ~= "function" then return def.id .. ": available must be a function" end
    for _, name in ipairs(CALLBACKS) do
        if def[name] ~= nil and type(def[name]) ~= "function" then return def.id .. ": " .. name .. " must be a function" end
    end
    return nil
end

function Apps:register(def)
    local err = validate(def)
    if err then return false, err end
    if self.byId[def.id] then return false, def.id .. ": already registered" end
    self.byId[def.id] = def
    self.list[#self.list + 1] = def
    return true
end

function Apps:get(id) return self.byId[id] end

-- Apps that run on a family (and, given a phone model, are available on it), by `order` (default 100) then id.
function Apps:forFamily(familyId, model)
    local out = {}
    for _, a in ipairs(self.list) do
        for _, f in ipairs(a.families) do
            if f == familyId then
                if not (model and a.available) or a.available(model) ~= false then out[#out + 1] = a end
                break
            end
        end
    end
    table.sort(out, function(a, b)
        local oa, ob = a.order or 100, b.order or 100
        if oa == ob then return a.id < b.id end
        return oa < ob
    end)
    return out
end

-- Calls an app callback without letting its errors break the phone. Returns ok, result-or-error.
function Apps.safeCall(fn, ...)
    if fn == nil then return true end
    return pcall(fn, ...)
end

return Apps
