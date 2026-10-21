-- Real places on the Build 42 map that strangers text about (spec §5.3). Every one is named in vanilla's own
-- town descriptions (media/lua/shared/Translate/EN/<Town>, KY.json). `name` reads mid-sentence ("Holed up at
-- Twiggy's Bar in West Point."); `town` lets a later feature find the building or put a marker on the map.
return {
    { name = "the Muldraugh motel", town = "Muldraugh" },
    { name = "Spiffo's in Muldraugh", town = "Muldraugh" },
    { name = "the lumberyard in Muldraugh", town = "Muldraugh" },
    { name = "the school in Muldraugh", town = "Muldraugh" },
    { name = "Twiggy's Bar in West Point", town = "West Point" },
    { name = "the West Point town hall", town = "West Point" },
    { name = "the Rosewood courthouse", town = "Rosewood" },
    { name = "the Rosewood fire station", town = "Rosewood" },
    { name = "the Rosewood police station", town = "Rosewood", site = "rosewood_police" }, -- also a stash site (Story/Sites)
    { name = "the prison in Rosewood", town = "Rosewood" },
    { name = "the West Maple Country Club", town = "Riverside" },
    { name = "the Star-E-Plex in March Ridge", town = "March Ridge" },
    { name = "the old bunker at March Ridge", town = "March Ridge" },
    { name = "the Irvington Speedway", town = "Irvington" },
    { name = "the gun store in Irvington", town = "Irvington" },
    { name = "the Brott cattle farm", town = "Irvington" },
    { name = "the Pondview Shopping Center in Brandenburg", town = "Brandenburg" },
    { name = "the steelworks in Ekron", town = "Ekron" },
    { name = "Crossroads Mall in Valley Station", town = "Valley Station" },
}
