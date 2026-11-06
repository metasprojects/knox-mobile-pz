-- #12 Orbita 9505 satellite phone (inspired by Iridium handsets). 1999: no towers, open sky only. 0.3.0.
return {
    id = "Orbita9505", name = "Orbita 9505 Satellite Phone", brand = "Orbita", year = 1999,
    form = "Satellite handset", family = "MonoLCD", connector = "Flat", rarity = "veryrare",
    removableBattery = true, camera = "none", extras = { "satellite" }, mixedUseHours = 30,
    toughness = 0.9, waterResistant = true, antenna = 3.0, weight = 0.375,
    colors = { "Graphite", "Olive" }, caseSize = "XL",
    -- Army storage only: never in a house.
    loot = { only = true, lists = { ArmyStorageElectronics = 3, ArmyBunkerStorage = 1.5, ArmySurplusMisc = 0.6 } },
}
