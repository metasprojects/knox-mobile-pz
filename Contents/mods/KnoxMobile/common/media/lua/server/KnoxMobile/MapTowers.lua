-- Server: towers on every map (0.3.0, Game/MapNetwork). When the world data is ready, the game's spawn regions are read
-- and every town of a map that isn't vanilla Kentucky gets a cell site; the list is saved in the world data and sent
-- to clients with the world message. The game also hands its regions over in OnSpawnRegionsLoaded (character
-- creation, server start); a list that arrives after the world data is up replaces the saved one.
local MapNetwork = require "KnoxMobile/Game/MapNetwork"
local State = require "KnoxMobile/State"
local Net = require "KnoxMobile/Game/Net"
local Util = require "KnoxMobile/Game/Util"

local MapTowers = {}
local pendingRegions = nil
local ready = false

local function enabled()
    local sv = SandboxVars and SandboxVars.KnoxMobile
    return not (sv and sv.MapTowers == false)
end

local function count(list)
    local n = 0
    for _ in pairs(list or {}) do n = n + 1 end
    return n
end

-- Work out, save and apply the generated sites. regions: the game's spawn regions, or nil to use the saved list.
function MapTowers.refresh(regions)
    local md = State.get()
    if not enabled() then
        md.mapSites = nil
        MapNetwork.apply(nil)
        return 0
    end
    if regions then md.mapSites = MapNetwork.build(regions) end
    local added = MapNetwork.apply(md.mapSites)
    if added > 0 then
        Util.log("map towers:", added, "cell sites on maps beyond vanilla Kentucky (" .. count(md.mapSites.areas) .. " towns)")
    end
    return added
end

local function start()
    ready = true
    local regions = pendingRegions or MapNetwork.regions()
    pendingRegions = nil
    MapTowers.refresh(regions)
end

Events.OnInitGlobalModData.Add(Util.safe("map towers", start))

if Events.OnSpawnRegionsLoaded then
    Events.OnSpawnRegionsLoaded.Add(Util.safe("map towers regions", function(regions)
        if type(regions) ~= "table" then return end
        if not ready then pendingRegions = regions; return end
        MapTowers.refresh(regions)
        if isServer() then Net.toAll("world", State.worldMessage()) end
    end))
end

KnoxMobile.MapTowers = MapTowers
return MapTowers
