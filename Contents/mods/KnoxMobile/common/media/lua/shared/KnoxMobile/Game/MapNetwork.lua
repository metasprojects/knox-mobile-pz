-- 0.3.0: towers on every map. The server works out the extra sites once (Core/MapSites, from the game's spawn regions),
-- keeps them in its world data and sends them with the world message; server and clients both add them to
-- Data/TowerSites.sites, so everything that lists sites (coverage, the Map, generator restore, Find my crew) sees them.
local MapSites = require "KnoxMobile/Core/MapSites"
local TowerSites = require "KnoxMobile/Data/TowerSites"

local MapNetwork = {}
MapNetwork.areas = {}

-- Put this list of generated sites in place (replacing any applied before). gen: { sites, areas } or nil.
function MapNetwork.apply(gen)
    local keep = {}
    for _, s in ipairs(TowerSites.sites) do
        if not s.generated then keep[#keep + 1] = s end
    end
    for i = #TowerSites.sites, 1, -1 do TowerSites.sites[i] = nil end
    for i, s in ipairs(keep) do TowerSites.sites[i] = s end
    MapNetwork.areas = {}
    if type(gen) ~= "table" then return 0 end
    local added = 0
    for _, s in ipairs(gen.sites or {}) do
        if type(s) == "table" and s.id and s.code and tonumber(s.x) and tonumber(s.y) then
            TowerSites.sites[#TowerSites.sites + 1] = { id = s.id, code = s.code, town = s.town, x = tonumber(s.x),
                y = tonumber(s.y), rural = s.rural == true, generated = true }
            added = added + 1
        end
    end
    for _, a in ipairs(gen.areas or {}) do
        if type(a) == "table" and tonumber(a.minX) then MapNetwork.areas[#MapNetwork.areas + 1] = a end
    end
    return added
end

-- Work out the generated sites from spawn regions (server side). Vanilla sites are what's already in TowerSites.
function MapNetwork.build(regions)
    local vanilla = {}
    for _, s in ipairs(TowerSites.sites) do
        if not s.generated then vanilla[#vanilla + 1] = s end
    end
    return MapSites.generate(regions, vanilla)
end

-- Does Knox Mobile know this spot (vanilla Kentucky, or near a town of another map it found)?
function MapNetwork.knows(x, y)
    local b = TowerSites.bounds
    if x >= b.minX and x <= b.maxX and y >= b.minY and y <= b.maxY then return true end
    return MapSites.inAreas(MapNetwork.areas, x, y)
end

-- The game's spawn regions, when this side can read them (server, single player). nil if not.
function MapNetwork.regions()
    if not (SpawnRegionMgr and SpawnRegionMgr.getSpawnRegions) then return nil end
    return SpawnRegionMgr.getSpawnRegions()
end

return MapNetwork
