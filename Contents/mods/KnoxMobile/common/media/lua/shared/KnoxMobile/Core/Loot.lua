-- Where Knox Mobile items spawn (spec §4.4): which vanilla loot lists get which items, at what weight.
-- Pure Lua 5.1; the server adapter inserts the entries into ProceduralDistributions before the merge.

local ItemIds = require "KnoxMobile/ItemIds"
local AudioGear = require "KnoxMobile/Core/AudioGear"
local Power = require "KnoxMobile/Core/Power"

local Loot = {}

-- Base weight per rarity tier (spec §4.4: newer is rarer), scaled by sandbox RarityMultiplier.
Loot.RARITY_WEIGHT = { common = 8, uncommon = 4, rare = 1.5, veryrare = 0.6 }

-- Phones are a cool find, smartphones rare and exciting, a new phone in its box a legendary find (final test
-- second pass: 11 phones in 7 houses, all in dressers, was far too many; third pass: none in ~950 containers was too
-- few; the target is about one phone every 2-3 houses). PZ rolls each item about weight percent a roll (the second pass's
-- weights gave 1.6 phones a house, matching that), and these lists roll 4 times (KitchenRandom 2, glove boxes 1).
-- A house has about 2 dressers, 2 bedside tables, a living-room table and 2 kitchen counters: these budgets (the
-- total weight of all phones in a list) come to about 0.4 phones a house. They are shared between the models by
-- Loot.SHARE. 2026-10-19: of 10 phones found, 2 or 3 are smartphones; the 1993-2000 phones are the most
-- common, the 2003-2009 ones half as common.
Loot.SHARE = { common = 1, uncommon = 0.5, rare = 0.12, veryrare = 0.04, smart = 0.58 }
local SMART = { ModernAndroid = true, ModernPear = true }
-- Release test (2026-10-20): these budgets at a third of today's gave 1 phone in about 30 houses and 19 cars; the
-- second pass's old weights (16.75 a dresser list) gave 1.6 a house. Tripled to land near 1 in 2-3 houses.
Loot.LOOSE = {
    BedroomSidetable = 7.5, BedroomSidetableClassy = 7.5, BedroomSidetableRedneck = 6.0,
    BedroomDresser = 4.2, BedroomDresserClassy = 4.2, BedroomDresserRedneck = 3.6,
    LivingRoomSideTable = 3.6, LivingRoomSideTableClassy = 3.6, KitchenRandom = 1.5,
    OfficeDesk = 7.5, OfficeDeskHome = 6.0, OfficeDrawers = 3.6, DeskGeneric = 3.6,
}
-- New in its box: electronics stores only, a legendary find (about one in five store visits).
Loot.BOXED = { ElectronicStorePhones = 1.0, GigamartHouseElectronics = 0.4, CrateElectronics = 0.3 }
-- Vehicle glove boxes (VehicleDistributions, one roll): someone's phone left in the car, about one car in ten.
Loot.GLOVEBOX = 20
-- The expected phones in a typical house at these budgets (for the tests and the notes).
function Loot.perHouse(budgets)
    local b = budgets or Loot.LOOSE
    return (2 * b.BedroomDresser + 2 * b.BedroomSidetable + b.LivingRoomSideTable) * 4 / 100 + 2 * b.KitchenRandom * 2 / 100
end

-- A model's part of the found phones. sandbox.SmartphoneShare (percent, default 25) sets the smartphones' part of
-- all found phones among the models that can spawn; the others keep their ratios.
function Loot.share(model, sandbox, models)
    local want = sandbox and sandbox.SmartphoneShare
    if not SMART[model.family] then
        if want and want >= 100 then return 0 end
        return Loot.SHARE[model.rarity] or 0.5
    end
    if not (want and models) then return Loot.SHARE.smart end
    if want <= 0 then return 0 end
    local others, smart = 0, 0
    for _, m in ipairs(models) do
        if SMART[m.family] then smart = smart + 1 else others = others + (Loot.SHARE[m.rarity] or 0.5) end
    end
    if smart == 0 then return 0 end
    if others == 0 or want >= 100 then return 1 end
    local f = want / 100
    return f * others / (1 - f) / smart
end

function Loot.isSmart(model) return SMART[model.family] == true end

-- Vanilla ProceduralDistributions lists (read from the 42.21 files, see B42_FINDINGS.md §9).
local ACCESSORY_STORES = { "ElectronicStoreMisc", "CrateElectronics", "GigamartHouseElectronics" }
local HOUSE_DRAWERS = { "OfficeDrawers", "DeskGeneric", "BedroomDresser", "OfficeDeskHome" }
local CASE_STORES = { "ElectronicStoreMisc", "ElectronicStorePhones" }
local RADIO_STORES = { "ElectronicStoreHAMRadio", "ElectronicStoreMisc" }
-- Recipe magazines: bookstores and the electronics shops' magazine racks (vanilla's ElectronicsMag lists).
local MAGAZINE_STORES = { "ElectronicStoreMagazines", "BookstoreMisc", "BookstoreBlueCollar", "CrateMagazines" }

-- Accessories that did not exist in July 1993.
local MODERN_KINDS = { cable = true, usbSource = true, audioGear = true, protector = true }
local MODERN_CASES = { Battery = true, Waterproof = true }

-- Does this accessory fit at least one phone that can spawn? Loot never hands out a charger, cable, case or audio
-- gear that fits nothing (QA N12); those items start spawning when a later round adds phones they fit.
-- exactChargers: sandbox ExactChargersForOldPhones (off: any charger or cable fits any phone).
function Loot.fitsSomePhone(registry, a, phones, exactChargers)
    if a.loot == false then return false end
    for _, p in ipairs(phones) do
        if a.kind == "charger" then
            if registry:canCharge(p.connector, { kind = a.setup or "integrated", connector = a.connector },
                { exactChargers = exactChargers }) then return true end
        elseif a.kind == "cable" then
            if exactChargers == false or p.connector == a.connector then return true end
        elseif a.kind == "usbSource" then
            -- USB power needs the phone's USB cable, so it only helps phones with a USB socket.
            if exactChargers == false or registry.isUsbConnector(p.connector) then return true end
        elseif a.kind == "audioGear" then
            if a.plug == "dongle" then
                if not AudioGear.hasJack(p) and AudioGear.fits(p, "jack", { dongle = true }) then return true end
            elseif AudioGear.fits(p, a.plug) then return true end
        elseif a.kind == "case" then
            if p.caseSize == a.caseSize and (a.caseType ~= "Battery" or Power.isModern(p)) then return true end
        elseif a.kind == "spareBattery" then
            if p.family == a.family and p.removableBattery then return true end
        elseif a.kind == "batteryCharger" then
            if p.removableBattery then return true end
        else
            return true
        end
    end
    return false
end

local function add(out, lists, item, weight)
    if weight <= 0 then return end
    for _, list in ipairs(lists) do out[#out + 1] = { list = list, item = ItemIds.full(item), weight = weight } end
end

-- registry: Registry with the bundled phones. accessories: Data/Accessories. sandbox: Sandbox.read() result.
-- Returns { { list, item = full item type, weight } }.
function Loot.entries(registry, accessories, sandbox)
    local out = {}
    local mult = sandbox.RarityMultiplier or 1
    if mult <= 0 then return out end
    local only1993 = sandbox.EraLimit == "1993Only"

    local models, total = {}, 0
    for _, model in ipairs(registry:spawnable(sandbox.EraLimit)) do models[#models + 1] = model end
    for _, model in ipairs(models) do total = total + Loot.share(model, sandbox, models) end
    local houses, boxes = sandbox.HousePhones or 1, sandbox.BoxedPhones or 1
    for _, model in ipairs(models) do
        local part = Loot.share(model, sandbox, models) / math.max(total, 0.0001) * mult
        for list, budget in pairs(Loot.BOXED) do add(out, { list }, ItemIds.box(model), budget * part * boxes) end
        for list, budget in pairs(Loot.LOOSE) do
            for _, color in ipairs(model.colors) do
                add(out, { list }, ItemIds.phone(model, color), budget * part * houses / #model.colors)
            end
        end
        if Loot.GLOVEBOX * part * houses > 0 then
            for _, color in ipairs(model.colors) do
                out[#out + 1] = { list = "GloveBox", item = ItemIds.full(ItemIds.phone(model, color)),
                    weight = Loot.GLOVEBOX * part * houses / #model.colors, vehicle = true }
            end
        end
    end

    local families = {}
    for _, model in ipairs(registry:spawnable(sandbox.EraLimit)) do families[model.family] = true end
    for _, family in ipairs(registry:families()) do
        if families[family.id] then add(out, HOUSE_DRAWERS, ItemIds.manual(family.id), 1.5 * mult) end
    end

    local phones = registry:spawnable(sandbox.EraLimit)
    for _, a in ipairs(accessories) do
        local modern = MODERN_KINDS[a.kind] or (a.kind == "case" and MODERN_CASES[a.caseType])
        if not (only1993 and modern) and Loot.fitsSomePhone(registry, a, phones, sandbox.ExactChargersForOldPhones) then
            local w = (a.rarity == "rare" and 1 or 4) * mult
            if a.kind == "magazine" then
                add(out, MAGAZINE_STORES, a.id, w * 0.5)
            elseif a.kind == "case" or a.kind == "protector" then
                add(out, CASE_STORES, a.id, w * 0.5)
            elseif a.kind == "part" then
                if a.part == "transceiver" then add(out, RADIO_STORES, a.id, w) else add(out, ACCESSORY_STORES, a.id, w * 0.5) end
            elseif a.kind ~= "repeater" then
                add(out, ACCESSORY_STORES, a.id, w)
                local drawers = a.kind == "charger" or a.kind == "cable" or a.kind == "sim" or a.kind == "pager"
                if drawers then add(out, HOUSE_DRAWERS, a.id, w * 0.4) end
            end
        end
    end
    return out
end

-- Every vanilla list the entries touch (for the server's self-check).
function Loot.lists(entries)
    local seen, out = {}, {}
    for _, e in ipairs(entries) do
        if not seen[e.list] then seen[e.list] = true; out[#out + 1] = e.list end
    end
    table.sort(out)
    return out
end

return Loot
