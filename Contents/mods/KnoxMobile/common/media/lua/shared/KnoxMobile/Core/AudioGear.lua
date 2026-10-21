-- Which audio gear works with which phone (spec §9.2). Pure Lua 5.1.
-- Gear: { plug = "jack" | "PearPlug" | "USBC" | "wireless", route = "earbuds" | "headphones" | "speaker" }.
local AudioGear = {}

-- Vanilla items count as wired 3.5 mm gear; Knox Mobile's own come from Data/Accessories.
local VANILLA = {
    ["Base.Earbuds"] = { plug = "jack", route = "earbuds" },
    ["Base.Headphones"] = { plug = "jack", route = "headphones" },
}

local BLUETOOTH_YEAR = 2004

-- 3.5 mm jack: phones up to about 2016; PearPhones lost it in 2016. Bricks and mono-screen candybars never had one.
local NO_JACK = { SegmentLCD = true, MonoLCD = true }
function AudioGear.hasJack(model)
    if NO_JACK[model.family] then return false end
    if model.family == "ModernPear" and model.year >= 2016 then return false end
    return model.year <= 2016
end

-- Gear description for an item full type, or nil. accessories: the Data/Accessories list (optional).
function AudioGear.describe(fullType, accessories)
    if VANILLA[fullType] then return { plug = VANILLA[fullType].plug, route = VANILLA[fullType].route } end
    local id = tostring(fullType):match("^KnoxMobile%.(.+)$")
    for _, a in ipairs(accessories or {}) do
        if a.id == id and a.kind == "audioGear" and a.plug ~= "dongle" then return { plug = a.plug, route = a.route } end
    end
    return nil
end

-- Does gear with this plug work on this phone? opts.dongle: the player carries a headphone dongle.
function AudioGear.fits(model, plug, opts)
    if plug == "jack" then
        if AudioGear.hasJack(model) then return true end
        return opts ~= nil and opts.dongle == true and (model.connector == "PearPlug" or model.connector == "USBC")
    end
    if plug == "PearPlug" or plug == "USBC" then return model.connector == plug end
    if plug == "wireless" then return model.year >= BLUETOOTH_YEAR end
    return false
end

-- The gear to use for an audio route, from the gear the player carries: { id, plug, route } entries.
-- "speaker" needs nothing (returns true); "oneEarbud" uses earbuds. Returns nil when nothing fits.
function AudioGear.choose(model, gear, route, opts)
    if route == "speaker" then return true end
    local want = route == "oneEarbud" and "earbuds" or route
    for _, g in ipairs(gear) do
        if g.route == want and AudioGear.fits(model, g.plug, opts) then return g end
    end
    return nil
end

return AudioGear
