-- Client: finding and restoring cell sites, and hunting for signal.
--   * Every Knox Mobile manual has the coverage map on its back page: right-click a manual for the list of sites,
--     each with a landmark note and how far and which way it is from you.
--   * At a site, right-click the ground near its hookup point: "Knox Mobile cell site KM-07". It shows the status
--     and where the hookup point is, and connects or disconnects a generator standing there. The server checks it.
--   * At 0-1 bars indoors the open phone suggests "Try higher ground" when a roof would do better.
local CellSites = require "KnoxMobile/Core/CellSites"
local TowerSites = require "KnoxMobile/Data/TowerSites"
local Phones = require "KnoxMobile/Game/Phones"
local WorldModel = require "KnoxMobile/Game/WorldModel"
local Util = require "KnoxMobile/Game/Util"
local Net = require "KnoxMobile/Game/Net"
local Tick = require "KnoxMobile/Game/Tick"

local T = Util.text
local Coverage = {}
KnoxMobile.Coverage = Coverage

-- Landmark notes, checked against the game's own map data (see Data/TowerSites.lua).
function Coverage.note(site)
    local notes = {
        muldraugh_n = T("IGUI_KnoxMobile_SiteNote_muldraugh_n", "Muldraugh North: empty lot off Harris St"),
        muldraugh_s = T("IGUI_KnoxMobile_SiteNote_muldraugh_s", "Muldraugh South: off Old Loop Road, east of the welding shop"),
        westpoint = T("IGUI_KnoxMobile_SiteNote_westpoint", "West Point: off Mulberry St, northeast of the corner store"),
        riverside = T("IGUI_KnoxMobile_SiteNote_riverside", "Riverside: off Rogers Av, south of the art gallery"),
        rosewood = T("IGUI_KnoxMobile_SiteNote_rosewood", "Rosewood: off Buck St, northeast of the fire station"),
        marchridge = T("IGUI_KnoxMobile_SiteNote_marchridge", "March Ridge: Adams Road, by the army family housing"),
        louisville_c = T("IGUI_KnoxMobile_SiteNote_louisville_c", "Louisville: Doffcap St, behind the hotel, south of the train station"),
        louisville_n = T("IGUI_KnoxMobile_SiteNote_louisville_n", "Louisville North: Trotter St, near the car dealership"),
        valleystation = T("IGUI_KnoxMobile_SiteNote_valleystation", "Valley Station: Esther Road, just west of the corner store"),
        brandenburg = T("IGUI_KnoxMobile_SiteNote_brandenburg", "Brandenburg: Lafayette Dr, a block northeast of the park"),
        irvington = T("IGUI_KnoxMobile_SiteNote_irvington", "Irvington: off N Carl St"),
        ekron = T("IGUI_KnoxMobile_SiteNote_ekron", "Ekron: West Alley St, northwest of the hunting store"),
        echocreek = T("IGUI_KnoxMobile_SiteNote_echocreek", "Echo Creek: Payne Road, behind the gas station"),
        fallaslake = T("IGUI_KnoxMobile_SiteNote_fallaslake", "Fallas Lake: Broadway St, north of the mechanic's garage"),
        hwy_west = T("IGUI_KnoxMobile_SiteNote_hwy_west", "West relay: a clearing by a trail in the woods, far west of Fallas Lake"),
        hwy_south = T("IGUI_KnoxMobile_SiteNote_hwy_south", "South relay: a clearing in the woods, far southwest of Rosewood"),
        hwy_east = T("IGUI_KnoxMobile_SiteNote_hwy_east", "East relay: a clearing in the woods east of Muldraugh, near a cabin"),
        hwy_north = T("IGUI_KnoxMobile_SiteNote_hwy_north", "North relay: open fields, far northwest of West Point"),
    }
    return notes[site.id] or site.town or site.id
end

local function direction(code)
    local words = {
        n = T("IGUI_KnoxMobile_Dir_n", "north"), ne = T("IGUI_KnoxMobile_Dir_ne", "northeast"),
        e = T("IGUI_KnoxMobile_Dir_e", "east"), se = T("IGUI_KnoxMobile_Dir_se", "southeast"),
        s = T("IGUI_KnoxMobile_Dir_s", "south"), sw = T("IGUI_KnoxMobile_Dir_sw", "southwest"),
        w = T("IGUI_KnoxMobile_Dir_w", "west"), nw = T("IGUI_KnoxMobile_Dir_nw", "northwest"),
    }
    return words[code] or code
end

-- "1.2 km northeast" (a tile is about a metre), or "here".
function Coverage.where(site, x, y)
    local code = CellSites.compass(x, y, site.x + 0.5, site.y + 0.5)
    if code == "here" then return T("IGUI_KnoxMobile_SiteHere", "right here") end
    local d = CellSites.distance(site, x, y)
    local dist
    if d < 1000 then
        dist = T("IGUI_KnoxMobile_DistM", "%1 m", math.floor(d / 10 + 0.5) * 10)
    else
        dist = T("IGUI_KnoxMobile_DistKm", "%1 km", string.format("%.1f", d / 1000))
    end
    return T("IGUI_KnoxMobile_SiteAway", "%1 %2", dist, direction(code))
end

-- "in service", "on generator power", "generator hooked up, not running", or "off the air".
function Coverage.status(site)
    if WorldModel.scheduledAlive(site) then return T("IGUI_KnoxMobile_SiteLive", "in service") end
    if WorldModel.restored(site) then return T("IGUI_KnoxMobile_SiteGenerator", "on generator power") end
    local e = (KnoxMobile.world.sites or {})[site.id]
    if e and e.connected then return T("IGUI_KnoxMobile_SiteHookedUp", "generator hooked up, not running") end
    return T("IGUI_KnoxMobile_SiteDead", "off the air")
end

local function sub(context, text)
    local root = context:addOption(text, nil, nil)
    local menu = ISContextMenu:getNew(context)
    context:addSubMenu(root, menu)
    return menu
end

local function info(menu, text, tip)
    local o = menu:addOption(text, nil, nil)
    o.notAvailable = true
    if tip then
        local t = ISInventoryPaneContextMenu.addToolTip()
        t.description = tip
        o.toolTip = t
    end
    return o
end

-- The coverage map on a manual's back page: every site, nearest first.
local function coverageMenu(player, context)
    local m = sub(context, T("IGUI_KnoxMobile_CoverageMap", "Coverage map (back page)"))
    local x, y = player:getX(), player:getY()
    local list = {}
    for _, s in ipairs(TowerSites.sites) do list[#list + 1] = s end
    table.sort(list, function(a, b) return CellSites.distance(a, x, y) < CellSites.distance(b, x, y) end)
    for _, s in ipairs(list) do
        info(m, T("IGUI_KnoxMobile_CoverageRow", "%1 %2 (%3)", s.code, Coverage.note(s), Coverage.where(s, x, y)),
            T("IGUI_KnoxMobile_CoverageTip",
                "A running generator at the site's hookup point brings a dead tower back. Right-click the ground there."))
    end
end

Events.OnFillInventoryObjectContextMenu.Add(Util.safe("coverage map", function(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    local item = ISInventoryPane.getActualItems(items)[1]
    if player and item and Phones.manualFamily(item) then coverageMenu(player, context) end
end))

-- The site menu ------------------------------------------------------------------------------------
local highlighted = nil

-- Lights the hookup point's floor for a few seconds (only on this screen).
local function showHookup(site)
    local sq = getCell():getGridSquare(site.x, site.y, site.z or 0)
    local floor = sq and sq:getFloor()
    if not floor then return end
    if highlighted and highlighted.floor then highlighted.floor:setHighlighted(false) end
    floor:setHighlightColor(0.2, 0.8, 1, 1)
    floor:setHighlighted(true)
    highlighted = { floor = floor, untilMs = getTimestampMs() + 8000 }
end

Tick.add("hookup highlight", function()
    if highlighted and getTimestampMs() >= highlighted.untilMs then
        highlighted.floor:setHighlighted(false)
        highlighted = nil
    end
end, 250)

-- Is a generator standing in the hookup area (as this client sees it)? The server checks again.
local function generatorHere(site)
    local cell = getCell()
    for _, p in ipairs(CellSites.hookupSquares(site)) do
        local sq = cell:getGridSquare(p.x, p.y, p.z)
        if sq and sq:getGenerator() then return true end
    end
    return false
end

function Coverage.siteMenu(player, context, site)
    local m = sub(context, T("IGUI_KnoxMobile_SiteTitle", "Knox Mobile cell site %1", site.code))
    info(m, Coverage.note(site))
    info(m, T("IGUI_KnoxMobile_SiteStatus", "Status: %1", Coverage.status(site)))
    info(m, T("IGUI_KnoxMobile_SiteHookup", "Equipment shelter hookup: %1", Coverage.where(site, player:getX(), player:getY())),
        T("IGUI_KnoxMobile_SiteHookupTip",
            "A running generator on the hookup point or next to it. The radios burn extra fuel, and the noise draws the dead."))
    m:addOption(T("IGUI_KnoxMobile_SiteShow", "Show the hookup point"), nil, function() showHookup(site) end)
    local entry = (KnoxMobile.world.sites or {})[site.id]
    if entry and entry.connected then
        m:addOption(T("IGUI_KnoxMobile_SiteDisconnect", "Unhook the generator"), nil, function()
            Net.toServer(player, "siteDisconnect", { code = site.code })
        end)
    else
        local o = m:addOption(T("IGUI_KnoxMobile_SiteConnect", "Hook up the generator"), nil, function()
            Net.toServer(player, "siteConnect", { code = site.code })
        end)
        local why = nil
        if not Util.settings().TowerRestore then
            why = T("IGUI_KnoxMobile_site_notAllowed", "Restoring cell sites is off on this server")
        elseif not generatorHere(site) then
            why = T("IGUI_KnoxMobile_SiteNeedGenerator", "Put a generator on the hookup point or right next to it first")
        end
        if why then
            o.notAvailable = true
            local t = ISInventoryPaneContextMenu.addToolTip()
            t.description = why
            o.toolTip = t
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(Util.safe("cell site menu", function(playerNum, context, worldobjects, test)
    if test then return end
    local player = getSpecificPlayer(playerNum)
    local obj = worldobjects and worldobjects[1]
    local sq = obj and obj.getSquare and obj:getSquare()
    if not player or not sq then return end
    local site = CellSites.at(TowerSites.sites, sq:getX() + 0.5, sq:getY() + 0.5)
    if site and sq:getZ() == (site.z or 0) then Coverage.siteMenu(player, context, site) end
end))

-- "Try higher ground" ------------------------------------------------------------------------------
local HINT_EVERY_MS = 120000
local nextHint = 0

-- Called by the open phone (UI/Phone.lua) after it works out the signal, about once a second.
function Coverage.signalHint(player, model, located)
    local now = getTimestampMs()
    if now < nextHint or not located or not located.indoors or (located.bars or 0) > 1 then return end
    if WorldModel.higherHelps(player, model, player:getModData().KnoxMobilePasswords or {}, located) then
        nextHint = now + HINT_EVERY_MS
        KnoxMobile.Client.toast(T("IGUI_KnoxMobile_TryHigher", "Weak signal. Try higher ground."))
    end
end

return Coverage
