-- Cell tower sites on the vanilla Build 42 map (spec §7.1). Town sites started from each town's own
-- spawnpoints.lua in the 42.21 game files; Louisville and the four relay sites are placed by hand.
-- Each x, y is the site's hookup point (Core/CellSites): checked against the game's own world map data
-- (media/maps/Muldraugh, KY/worldmap.xml, worldmap-forest.xml and streets.xml, 2026-10-12) to be open ground: not in a
-- building, water, road or dense forest. Points that fell inside a house or the woods moved to the nearest open spot.
-- code is the site's name for players ("KM-07"); client/KnoxMobile/Coverage.lua has the landmark notes.
-- rural = true towers die first in a gradual collapse. Range is Signal.TOWER_RANGE unless set.
return {
    bounds = { minX = 0, minY = 0, maxX = 15000, maxY = 15600 }, -- vanilla Kentucky; outside = unknown map
    sites = {
        { id = "muldraugh_n", code = "KM-01", town = "Muldraugh", x = 10750, y = 9500, rural = false },
        { id = "muldraugh_s", code = "KM-02", town = "Muldraugh", x = 10850, y = 10400, rural = false },
        { id = "westpoint", code = "KM-03", town = "West Point", x = 11582, y = 6859, rural = false },
        { id = "riverside", code = "KM-04", town = "Riverside", x = 6360, y = 5430, rural = false },
        { id = "rosewood", code = "KM-05", town = "Rosewood", x = 8170, y = 11690, rural = false },
        { id = "marchridge", code = "KM-06", town = "March Ridge", x = 9878, y = 12807, rural = false },
        { id = "louisville_c", code = "KM-07", town = "Louisville", x = 12700, y = 2300, rural = false },
        { id = "louisville_n", code = "KM-08", town = "Louisville", x = 13294, y = 1300, rural = false },
        { id = "valleystation", code = "KM-09", town = "Valley Station", x = 12601, y = 5330, rural = false },
        { id = "brandenburg", code = "KM-10", town = "Brandenburg", x = 2146, y = 6090, rural = false },
        { id = "irvington", code = "KM-11", town = "Irvington", x = 1910, y = 14379, rural = false },
        { id = "ekron", code = "KM-12", town = "Ekron", x = 406, y = 9760, rural = true },
        { id = "echocreek", code = "KM-13", town = "Echo Creek", x = 3577, y = 10908, rural = true },
        { id = "fallaslake", code = "KM-14", town = "Fallas Lake", x = 7210, y = 8293, rural = true },
        { id = "hwy_west", code = "KM-15", town = "Highway", x = 4530, y = 8014, rural = true },
        { id = "hwy_south", code = "KM-16", town = "Highway", x = 5662, y = 13106, rural = true },
        { id = "hwy_east", code = "KM-17", town = "Highway", x = 12836, y = 8906, rural = true },
        { id = "hwy_north", code = "KM-18", town = "Highway", x = 9300, y = 3800, rural = true },
    },
}
