-- Every non-phone item Knox Mobile adds (chargers, cables, cases, SIMs, parts, manuals...), as data.
-- tools/gen turns this into item scripts and English names. `icon` and `model` name vanilla art used as
-- placeholders until Knox Mobile's own art exists (spec §15); `kind` is what the game adapters look for.
-- Fields: id, name, kind, weight, icon, model (vanilla WorldStaticModel), tooltip, plus kind-specific data.
-- `art` (default: id) names the item's own art from tools/blender/make_items.py, which replaces icon and model.

-- `loot = false` keeps an item out of the loot tables (Core/Loot also skips anything that fits no spawnable phone).
local Registry = require "KnoxMobile/Core/Registry"
local Power = require "KnoxMobile/Core/Power"

local A = {}

local function add(def) A[#A + 1] = def end

-- "Fits: Sisu 3301, Sisu 6606." (four names and "and N more" past five) for the bundled phones that pass `pred`; nil when none do.
local REGISTRY = Registry.withBundledPhones()
local function fitsList(pred)
    local names = {}
    for _, p in ipairs(REGISTRY:phones()) do
        if pred(p) then names[#names + 1] = (p.name:gsub(' ".-"', "")) end
    end
    if #names == 0 then return nil end
    local shown = {}
    local limit = #names <= 5 and #names or 4
    for i = 1, limit do shown[i] = names[i] end
    local text = "Fits: " .. table.concat(shown, ", ")
    if #names > limit then text = text .. " and " .. (#names - limit) .. " more" end
    return text .. "."
end

-- SIM cards (spec §4.5) ------------------------------------------------------------------------
add({ id = "SimCard", name = "SIM Card", kind = "sim", weight = 0.01, icon = "IDcard", model = "IDcard",
    tooltip = "Holds a phone number and contacts. Move it between phones." })

-- Chargers with their own plug (spec §6.4) -----------------------------------------------------
for _, c in ipairs({ { "Pin", "pin" }, { "Flat", "flat" } }) do
    add({ id = "WallCharger" .. c[1], name = c[1] .. " Wall Charger", kind = "charger", setup = "integrated",
        connector = c[1], source = "wall", weight = 0.15, icon = "CordlessPhone", model = "CordlessPhone",
        tooltip = "All-in-one wall charger for phones with a " .. c[2] .. " socket. Needs a powered outlet." })
    add({ id = "CarCharger" .. c[1], name = c[1] .. " Car Charger", kind = "charger", setup = "integrated",
        connector = c[1], source = "car", weight = 0.1, icon = "CordlessPhone", model = "CordlessPhone",
        tooltip = "Plugs into a car's lighter socket. Charges phones with a " .. c[2] .. " socket." })
end
add({ id = "MultiTipCharger", name = "Universal Multi-Tip Charger", kind = "charger", setup = "multitip",
    source = "wall", weight = 0.25, icon = "CordlessPhone", model = "CordlessPhone", rarity = "rare",
    tooltip = "A wall charger with a bag of tips. Fits Pin and Flat phones." })

-- USB cables and USB power sources ---------------------------------------------------------------
for _, c in ipairs({ { "MicroUSB", "Micro-USB" }, { "PearPlug", "Pear Plug" }, { "USBC", "USB-C" } }) do
    add({ id = "Cable" .. c[1], name = c[2] .. " Cable", kind = "cable", connector = c[1], weight = 0.03,
        icon = "Wires_Multicolor", model = "ElectricWire", tooltip = "Connects a " .. c[2] .. " phone to any USB power source." })
end
add({ id = "UsbWallAdapter", name = "USB Wall Adapter", kind = "usbSource", source = "wall", weight = 0.05,
    icon = "Battery", model = "Battery", tooltip = "USB power from a powered outlet." })
add({ id = "UsbCarAdapter", name = "USB Car Adapter", kind = "usbSource", source = "car", weight = 0.04,
    icon = "Battery", model = "Battery", tooltip = "USB power from a car's lighter socket." })
add({ id = "PowerBank", name = "Power Bank", kind = "usbSource", source = "powerBank", weight = 0.25,
    icon = "CarBatteryCharger", model = "Battery",
    tooltip = "USB power in your pocket. Needs the phone's USB cable. Refill it at a wall outlet." })
add({ id = "SolarCharger", name = "Folding Solar Charger", kind = "usbSource", source = "solar", weight = 0.4,
    icon = "CarBatteryCharger", model = "Battery", rarity = "rare",
    tooltip = "USB power outdoors in daylight; slower under clouds. Needs the phone's USB cable." })
add({ id = "CrankCharger", name = "Hand-Crank Charger", kind = "usbSource", source = "crank", weight = 0.35,
    icon = "CarBatteryCharger", model = "Battery", rarity = "rare",
    tooltip = "USB power you crank by hand. Slow, and a little noisy. Needs the phone's USB cable." })
add({ id = "AAEmergencyCharger", name = "AA Emergency Charger", kind = "usbSource", source = "aa", weight = 0.12,
    icon = "Battery", model = "Battery",
    tooltip = "Turns AA batteries into a slow trickle of USB power. Needs the phone's USB cable." })
add({ id = "CarBatteryClip", name = "12V Clip Adapter", kind = "usbSource", source = "carBatteryClip", weight = 0.3,
    icon = "CarBatteryCharger", model = "Battery", tooltip = "USB power from a loose car battery. Needs the phone's USB cable." })
add({ id = "DesktopBatteryCharger", name = "Desktop Battery Charger", kind = "batteryCharger", source = "wall", weight = 0.3,
    icon = "CarBatteryCharger", model = "Battery", tooltip = "Charges spare removable phone batteries. Needs wall power." })

-- Spare batteries for families with removable batteries (spec §6.3) -----------------------------
for _, family in ipairs({ "SegmentLCD", "MonoLCD", "ColorFeature", "Keyboard", "Stylus", "ModernAndroid" }) do
    local fits = fitsList(function(p) return p.family == family and p.removableBattery end)
    add({ id = "SpareBattery" .. family, name = "Spare " .. REGISTRY:family(family).label .. " Battery",
        kind = "spareBattery", family = family, weight = 0.05, icon = "Battery", model = "Battery",
        tooltip = "A spare battery to swap in." .. (fits and (" " .. fits) or "") })
end

-- Repair parts and scrap (spec §9.5) ---------------------------------------------------------------
add({ id = "PhoneScreen", name = "Phone Screen", kind = "part", part = "screen", weight = 0.05,
    icon = "ElectronicsScrap", model = "ElectronicsScrap", tooltip = "Replacement screen. Needs a screwdriver; Electrical skill helps." })
add({ id = "PhoneBattery", name = "Phone Battery Cell", kind = "part", part = "battery", weight = 0.05,
    icon = "Battery", model = "Battery", tooltip = "Replacement battery cell. Restores battery health. Needs a screwdriver." })
add({ id = "TransceiverBoard", name = "Transceiver Board", kind = "part", part = "transceiver", weight = 0.2,
    icon = "Receiver", model = "RadioReceiver_Ground", rarity = "rare", tooltip = "The heart of a cell repeater." })
add({ id = "ScreenProtector", name = "Screen Protector", kind = "protector", weight = 0.01,
    icon = "IDcard", model = "IDcard", tooltip = "Absorbs the first crack." })

-- Cell repeater (spec §7.3) -------------------------------------------------------------------------
add({ id = "Repeater", name = "Cell Repeater", kind = "repeater", weight = 6, icon = "HamRadioCivilian", model = "RadioReceiver_Ground",
    tooltip = "Place it and give it power to bring back service nearby." })

-- Audio gear (spec §9.2) ------------------------------------------------------------------------------
add({ id = "PearEarbuds", name = "Pear Plug Earbuds", kind = "audioGear", plug = "PearPlug", route = "earbuds",
    weight = 0.05, icon = "Earbuds", model = "EarBuds", tooltip = "Earbuds with a Pear Plug. Fit any PearPhone." })
add({ id = "UsbcEarbuds", name = "USB-C Earbuds", kind = "audioGear", plug = "USBC", route = "earbuds",
    weight = 0.05, icon = "Earbuds", model = "EarBuds", tooltip = "Earbuds for the newest Android phones." })
add({ id = "WirelessEarbuds", name = "Wireless Earbuds", kind = "audioGear", plug = "wireless", route = "earbuds",
    weight = 0.06, icon = "Earbuds", model = "EarBuds", tooltip = "Bluetooth earbuds. Work with phones from 2004 on." })
add({ id = "HeadphoneDongle", name = "Headphone Dongle", kind = "audioGear", plug = "dongle", weight = 0.01,
    icon = "Wires_Multicolor", model = "ElectricWire", rarity = "rare", tooltip = "Adds a headphone jack to jackless phones." })
-- No phone can use the speaker yet (the "speaker" route is the phone's own), so it stays out of the loot.
add({ id = "BluetoothSpeaker", name = "Bluetooth Speaker", kind = "audioGear", plug = "wireless", route = "speaker",
    weight = 0.5, icon = "Speaker", model = "Speaker", loot = false,
    tooltip = "A portable Bluetooth speaker. No phone in Knox County can pair with it." })

-- Cases (spec §9.4): one item per type and size class ------------------------------------------------
for _, t in ipairs({ "Slim", "Rugged", "Waterproof", "Wallet", "Battery", "BeltHolster" }) do
    for _, size in ipairs({ "S", "M", "L", "XL" }) do
        local label = (t == "BeltHolster" and "Belt Holster") or (t .. " Case")
        -- Only sizes some phone wears: a case nothing fits is not made at all (PC test r5: "No phone fits it").
        local fits = fitsList(function(p) return p.caseSize == size and (t ~= "Battery" or Power.isModern(p)) end)
        if fits then
            add({ id = "Case" .. t .. size, art = "Case" .. t, name = label .. " (" .. size .. ")", kind = "case", caseType = t,
                caseSize = size, weight = (t == "Rugged" and 0.12) or 0.05, icon = "Wallet_01", model = "Wallet",
                tooltip = fits })
        end
    end
end

-- Pager (1993 hardware): numeric pages only, about a week on one AA. Its own art (tools/blender/make_items.py);
-- vanilla's pager icon and model are the fallback.
add({ id = "Pager", name = "Motormouth Bravo Pager", kind = "pager", weight = 0.1, icon = "Pager", model = "Pager",
    tooltip = "A numeric pager. Shows the number and code you were paged with. About a week on one AA battery." })

-- Car phone (1993 hardware): the kit mounts in a car (Core/CarPhone); while you sit in that car its handset is in your
-- hands, a phone with the car phone model (Phones/CarPhone.lua). The handset never spawns. Their own art (the
-- handset; the kit: handset in its cradle, coiled cord, transceiver) comes from tools/blender/make_items.py.
add({ id = "CarPhoneKit", name = "Car Phone Kit", kind = "carPhoneKit", weight = 2.5,
    icon = "CordlessPhone", model = "CordlessPhone", rarity = "rare",
    tooltip = "A car phone with its own number: handset, transceiver and roof antenna. Sit in a car to mount it. "
        .. "It runs off the car battery." })
add({ id = "CarPhone", name = "Car Phone Handset", kind = "carPhone", weight = 0.5,
    icon = "CordlessPhone", model = "CordlessPhone", loot = false,
    tooltip = "The car phone's handset. It stays with the car." })

-- Recipe magazines: B42 literature like vanilla's ElectronicsMag1-5 (reading one teaches `teaches`, the
-- craftRecipe names in scripts/KnoxMobile/KnoxMobile_Recipes.txt). Vanilla magazine art until their own exists.
add({ id = "CellularRepairMonthly1", name = "Cellular Repair Monthly, Issue 1", kind = "magazine", weight = 0.5,
    icon = "MagazineElectronics01", model = "MagazineElec1Ground", teaches = { "BuildCellRepeaterGuided" } })
add({ id = "CellularRepairMonthly2", name = "Cellular Repair Monthly, Issue 2", kind = "magazine", weight = 0.5,
    icon = "MagazineElectronics02", model = "MagazineElec4Ground", teaches = { "RebuildPhoneBatteryCell" } })

return A
