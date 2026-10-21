-- Item ids for every Knox Mobile item, shared by the game code and the item-script generator.
local Registry = require "KnoxMobile/Core/Registry"
local Accessories = require "KnoxMobile/Data/Accessories"

local ItemIds = {}

ItemIds.MODULE = "KnoxMobile"

local function colorKey(color) return (color:gsub("[^%w]", "")) end

function ItemIds.phone(model, color) return model.id .. "_" .. colorKey(color) end
function ItemIds.box(model) return model.id .. "_Box" end
function ItemIds.manual(familyId) return "Manual_" .. familyId end
function ItemIds.full(id) return ItemIds.MODULE .. "." .. id end

-- Every item id (without module), in a stable order.
function ItemIds.all()
    local reg = Registry.withBundledPhones()
    local ids = {}
    for _, model in ipairs(reg:phones()) do
        for _, color in ipairs(model.colors) do ids[#ids + 1] = ItemIds.phone(model, color) end
        ids[#ids + 1] = ItemIds.box(model)
    end
    for _, family in ipairs(reg:families()) do ids[#ids + 1] = ItemIds.manual(family.id) end
    for _, a in ipairs(Accessories) do ids[#ids + 1] = a.id end
    return ids
end

-- Which phone model and color an item id belongs to, or nil for non-phone items.
function ItemIds.parsePhone(id, registry)
    local modelId, key = tostring(id):gsub("^KnoxMobile%.", ""):match("^([%w]+)_([%w]+)$")
    if not modelId or key == "Box" then return nil end
    local model = registry:getPhone(modelId)
    if not model then return nil end
    for _, color in ipairs(model.colors) do
        if colorKey(color) == key then return model, color end
    end
    return nil
end

return ItemIds
