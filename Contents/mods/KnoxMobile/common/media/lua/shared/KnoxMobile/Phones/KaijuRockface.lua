-- #19 Kaiju Rockface (inspired by rugged flips like the Casio G'zOne). 2008: waterproof, drop-proof, compass, barometer. 0.3.0.
return {
    id = "KaijuRockface", name = "Kaiju Rockface", brand = "Kaiju", year = 2008,
    form = "Rugged flip", family = "ColorFeature", connector = "MicroUSB",
    removableBattery = true, camera = "basic", extras = { "flashlight", "compass", "barometer", "vibrate" },
    toughness = 1.0, waterResistant = true, antenna = 1.1, weight = 0.17,
    colors = { "Olive", "Black", "Orange" }, caseSize = "L",
    loot = { lists = { CampingStoreGear = 1.5, CampingLockers = 1 } },
}
