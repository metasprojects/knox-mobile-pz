-- Server: dead towers brought back with a generator (Core/CellSites). The server decides everything: it finds the
-- generator at the site itself, takes the radio equipment's fuel from the tank, and tells every client which sites
-- are on the air (State.worldMessage "sites"). Clients only ask to connect or disconnect, from the site's menu.
--
-- How the generator is found (Build 42): vanilla IsoGenerator objects sit on a square (IsoGridSquare.getGenerator).
-- It powers squares itself (IsoGenerator.isPoweringSquare: sandbox GeneratorTileRange round it), burns
-- getTotalPowerUsing() x GeneratorFuelConsumption per game hour, catches up on missed hours when its chunk loads, and
-- makes its own zombie-attracting noise while running (IsoGenerator.update, WorldSoundManager). Here a generator counts
-- when it stands on the hookup point or next to it, is switched on (isActivated, which vanilla only allows once it
-- is connected) and has fuel. While nobody is near, the chunk unloads and the server keeps the tower up until the
-- tank would have run dry; the radio load for that time is taken when the chunk loads again.
local CellSites = require "KnoxMobile/Core/CellSites"
local Protocol = require "KnoxMobile/Core/Protocol"
local TowerSites = require "KnoxMobile/Data/TowerSites"
local Util = require "KnoxMobile/Game/Util"
local Net = require "KnoxMobile/Game/Net"
local State = require "KnoxMobile/State"

local SiteRestore = {}

local function validCode(args)
    if type(args.code) ~= "string" or not CellSites.byCode(TowerSites.sites, args.code) then
        return false, "code must name a cell site"
    end
    return true
end
Protocol.register({ siteConnect = validCode, siteDisconnect = validCode })

local function fuelSettings(settings)
    local c = SandboxVars and SandboxVars.GeneratorFuelConsumption
    return { fuelUse = (settings or Util.settings()).TowerFuelUse, consumption = type(c) == "number" and c or 0.1 }
end

-- The generator in the site's hookup area. nil while the site's chunk isn't loaded on this machine.
function SiteRestore.read(site)
    local cell = getCell()
    if not cell:getGridSquare(site.x, site.y, site.z or 0) then return nil end
    for _, p in ipairs(CellSites.hookupSquares(site)) do
        local sq = cell:getGridSquare(p.x, p.y, p.z)
        local gen = sq and sq:getGenerator()
        if gen then
            local fuel = gen:getFuel()
            return { present = true, running = gen:isActivated() and fuel > 0 and gen:getCondition() > 0, fuel = fuel,
                powerUsing = gen:getTotalPowerUsing(), gen = gen }
        end
    end
    return { present = false }
end

local function broadcast() Net.toAll("world", State.worldMessage()) end

-- One look at a connected site; takes the radio load from the tank. Returns CellSites.step's result.
local function check(site, entry, now, fs)
    local reading = SiteRestore.read(site)
    local r = CellSites.step(entry, reading, now, fs)
    if r.extra > 0 and reading and reading.gen then reading.gen:setFuel(math.max(0, reading.fuel - r.extra)) end
    if r.lost then Util.log("cell site", site.code, "lost its generator") end
    return r
end

-- Every ten game minutes: connected sites are checked; disconnected ones are forgotten.
function SiteRestore.tick()
    local md = State.get()
    local settings = Util.settings()
    local now, fs = Util.nowMinutes(), fuelSettings(settings)
    local send = false
    for id, entry in pairs(md.sites) do
        local site = CellSites.byId(TowerSites.sites, id)
        if site and type(entry) == "table" and entry.connected and settings.TowerRestore then
            if check(site, entry, now, fs).send then send = true end
        end
        if not site or type(entry) ~= "table" or not entry.connected then
            md.sites[id] = nil
            send = true
        end
    end
    if send then broadcast() end
end

local function nearSite(player, site)
    return math.floor(player:getZ()) == (site.z or 0)
        and CellSites.distance(site, player:getX(), player:getY()) <= CellSites.MENU_RADIUS + 2
end

local function tell(player, event, site)
    Net.toClient(player, "notify", { kind = "site", event = event, id = site.code })
end

Net.onServer("siteConnect", function(player, args)
    local site = CellSites.byCode(TowerSites.sites, args.code)
    if not site then return end
    if not Util.settings().TowerRestore then return tell(player, "notAllowed", site) end
    if not nearSite(player, site) then return tell(player, "tooFar", site) end
    local reading = SiteRestore.read(site)
    if not reading or not reading.present then return tell(player, "noGenerator", site) end
    local md = State.get()
    local entry = md.sites[site.id] or {}
    md.sites[site.id] = entry
    entry.connected, entry.by, entry.lastCharge = true, Util.playerKey(player), nil
    local now = Util.nowMinutes()
    CellSites.step(entry, reading, now, fuelSettings())
    local up = CellSites.isUp(entry, now)
    Util.log("cell site", site.code, "connected by", entry.by, up and "and on the air" or "(generator not running)")
    tell(player, up and "online" or "connectedOff", site)
    if up and KnoxMobile.Journal then KnoxMobile.Journal.add(player, "Got tower " .. site.code .. " back on the air.") end
    broadcast()
end)

Net.onServer("siteDisconnect", function(player, args)
    local site = CellSites.byCode(TowerSites.sites, args.code)
    if not site then return end
    if not nearSite(player, site) then return tell(player, "tooFar", site) end
    local md = State.get()
    if not md.sites[site.id] then return end
    md.sites[site.id] = nil
    Util.log("cell site", site.code, "disconnected by", Util.playerKey(player))
    tell(player, "disconnected", site)
    broadcast()
end)

Events.EveryTenMinutes.Add(Util.safe("cell sites", function()
    if isClient() then return end
    SiteRestore.tick()
end))

return SiteRestore
