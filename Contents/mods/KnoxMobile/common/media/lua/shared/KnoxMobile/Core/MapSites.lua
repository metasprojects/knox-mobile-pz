-- 0.3.0: cell sites for maps Knox Mobile wasn't drawn for. Data/TowerSites holds the 18 hand-placed vanilla sites; on
-- any other map (a standalone one like Lost Province, or one added beside Kentucky like Big Bear Lake) the towns come
-- from the map's own spawn points (the game's SpawnRegionMgr, the same lists the character screen uses): points close
-- together are one town, and each town gets a site near its middle. Pure Lua 5.1; Game/MapNetwork applies the result.
local MapSites = {}

-- The vanilla spawn regions (media/maps folders). Their towns already have hand-placed sites.
MapSites.VANILLA = {
    ["Muldraugh, KY"] = true, ["West Point, KY"] = true, ["Riverside, KY"] = true, ["Rosewood, KY"] = true,
    ["March Ridge, KY"] = true, ["Louisville, KY"] = true, ["Valley Station, KY"] = true, ["Brandenburg, KY"] = true,
    ["Irvington, KY"] = true, ["Ekron, KY"] = true, ["Echo Creek, KY"] = true, ["Fallas Lake, KY"] = true,
    ["challengemaps"] = true,
}

MapSites.TOWN_GAP = 350      -- spawn points closer than this (squares) are the same town
MapSites.URBAN_POINTS = 12   -- a town with this many spawn points is urban (its site dies later in a gradual collapse)
MapSites.BIG_TOWN = 1400     -- a town wider than this gets a second site at its far end
MapSites.MIN_SPACING = 900   -- no new site closer than this to any other site
MapSites.AREA_MARGIN = 900   -- the map counts as "known" this far around its towns
MapSites.MAX_SITES = 40      -- per map: a safety cap for maps with odd spawn files
MapSites.B41_CELL = 300      -- old-style spawn points give a cell (worldX/worldY) and a spot in it (posX/posY)

-- One point from a spawn file entry: Build 42 files give absolute posX/posY; Build 41-style ones a cell and an offset.
function MapSites.point(p)
    if type(p) ~= "table" then return nil end
    local x, y = tonumber(p.posX or p.x), tonumber(p.posY or p.y)
    if not x or not y then return nil end
    if tonumber(p.worldX) and tonumber(p.worldY) then
        x = tonumber(p.worldX) * MapSites.B41_CELL + x
        y = tonumber(p.worldY) * MapSites.B41_CELL + y
    end
    return { x = math.floor(x), y = math.floor(y) }
end

-- Every point of a region (all professions), without repeats, in a fixed order.
function MapSites.regionPoints(region)
    local out, seen, keys = {}, {}, {}
    if type(region) ~= "table" or type(region.points) ~= "table" then return out end
    for k in pairs(region.points) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local list = region.points[k]
        if type(list) == "table" then
            for _, raw in ipairs(list) do
                local p = MapSites.point(raw)
                if p then
                    local key = p.x .. ":" .. p.y
                    if not seen[key] then seen[key] = true; out[#out + 1] = p end
                end
            end
        end
    end
    table.sort(out, function(a, b) if a.x ~= b.x then return a.x < b.x end return a.y < b.y end)
    return out
end

-- Points within `gap` of each other (through any chain) are one cluster. Grid buckets keep it fast on big maps.
function MapSites.cluster(points, gap)
    gap = gap or MapSites.TOWN_GAP
    local parent = {}
    for i = 1, #points do parent[i] = i end
    local function find(i)
        while parent[i] ~= i do parent[i] = parent[parent[i]]; i = parent[i] end
        return i
    end
    local buckets = {}
    local function key(bx, by) return bx .. ":" .. by end
    for i, p in ipairs(points) do
        local bx, by = math.floor(p.x / gap), math.floor(p.y / gap)
        for dx = -1, 1 do
            for dy = -1, 1 do
                local b = buckets[key(bx + dx, by + dy)]
                if b then
                    for _, j in ipairs(b) do
                        local q = points[j]
                        local ddx, ddy = p.x - q.x, p.y - q.y
                        if ddx * ddx + ddy * ddy <= gap * gap then
                            local ri, rj = find(i), find(j)
                            if ri ~= rj then parent[ri] = rj end
                        end
                    end
                end
            end
        end
        local k = key(bx, by)
        buckets[k] = buckets[k] or {}
        table.insert(buckets[k], i)
    end
    local groups, order = {}, {}
    for i = 1, #points do
        local r = find(i)
        if not groups[r] then groups[r] = {}; order[#order + 1] = r end
        table.insert(groups[r], points[i])
    end
    local out = {}
    for _, r in ipairs(order) do out[#out + 1] = groups[r] end
    return out
end

-- A cluster's box and the spawn point nearest its middle (a real spot in the town, not an empty field or a river).
local function describe(group)
    local minX, minY, maxX, maxY, sx, sy = math.huge, math.huge, -math.huge, -math.huge, 0, 0
    for _, p in ipairs(group) do
        if p.x < minX then minX = p.x end
        if p.y < minY then minY = p.y end
        if p.x > maxX then maxX = p.x end
        if p.y > maxY then maxY = p.y end
        sx, sy = sx + p.x, sy + p.y
    end
    local cx, cy = sx / #group, sy / #group
    local best, bestD = group[1], math.huge
    for _, p in ipairs(group) do
        local d = (p.x - cx) * (p.x - cx) + (p.y - cy) * (p.y - cy)
        if d < bestD then best, bestD = p, d end
    end
    return { minX = minX, minY = minY, maxX = maxX, maxY = maxY, center = best, count = #group }
end

-- The point of the group farthest from `from` (a big town's second site).
local function farthest(group, from)
    local best, bestD = nil, -1
    for _, p in ipairs(group) do
        local d = (p.x - from.x) * (p.x - from.x) + (p.y - from.y) * (p.y - from.y)
        if d > bestD then best, bestD = p, d end
    end
    return best
end

local function clear(sites, x, y, spacing)
    for _, s in ipairs(sites) do
        local dx, dy = s.x - x, s.y - y
        if dx * dx + dy * dy < spacing * spacing then return false end
    end
    return true
end

-- A short, readable town name from a map folder ("BBL_b42" stays as is; "Lost Province, PE" -> "Lost Province").
function MapSites.townName(region)
    local name = tostring(region and region.name or "Unknown")
    local short = name:match("^([^,]+),") or name
    return short
end

-- regions: SpawnRegionMgr.getSpawnRegions() (each { name, points }). existing: the sites already on the map (vanilla).
-- Returns { sites = { ... }, areas = { { minX, minY, maxX, maxY }, ... } } for every region that isn't vanilla.
-- Same input, same output: the server's list and a client's agree.
function MapSites.generate(regions, existing, opts)
    opts = opts or {}
    local spacing = opts.spacing or MapSites.MIN_SPACING
    local placed = {}
    for _, s in ipairs(existing or {}) do placed[#placed + 1] = { x = s.x, y = s.y } end
    local sites, areas = {}, {}
    local names = {}
    for _, r in ipairs(regions or {}) do
        if type(r) == "table" and r.name and not MapSites.VANILLA[r.name] then names[#names + 1] = r end
    end
    table.sort(names, function(a, b) return tostring(a.name) < tostring(b.name) end)
    local n = 0
    for _, region in ipairs(names) do
        local groups = MapSites.cluster(MapSites.regionPoints(region), opts.gap)
        local described = {}
        for i, g in ipairs(groups) do described[i] = { info = describe(g), group = g } end
        -- Biggest towns first, so they get their sites before small ones crowd them out.
        table.sort(described, function(a, b)
            if a.info.count ~= b.info.count then return a.info.count > b.info.count end
            if a.info.center.x ~= b.info.center.x then return a.info.center.x < b.info.center.x end
            return a.info.center.y < b.info.center.y
        end)
        local perMap = 0
        for _, d in ipairs(described) do
            local info = d.info
            areas[#areas + 1] = { minX = info.minX - MapSites.AREA_MARGIN, minY = info.minY - MapSites.AREA_MARGIN,
                maxX = info.maxX + MapSites.AREA_MARGIN, maxY = info.maxY + MapSites.AREA_MARGIN }
            local spots = { info.center }
            local width = math.max(info.maxX - info.minX, info.maxY - info.minY)
            if width > MapSites.BIG_TOWN then spots[#spots + 1] = farthest(d.group, info.center) end
            for _, spot in ipairs(spots) do
                if perMap < MapSites.MAX_SITES and clear(placed, spot.x, spot.y, spacing) then
                    n, perMap = n + 1, perMap + 1
                    local site = { id = "map_" .. n, code = string.format("KX-%02d", n), town = MapSites.townName(region),
                        x = spot.x, y = spot.y, rural = info.count < MapSites.URBAN_POINTS, generated = true }
                    sites[#sites + 1] = site
                    placed[#placed + 1] = { x = spot.x, y = spot.y }
                end
            end
        end
    end
    return { sites = sites, areas = areas }
end

-- Is (x, y) inside any of the areas?
function MapSites.inAreas(areas, x, y)
    for _, a in ipairs(areas or {}) do
        if x >= a.minX and x <= a.maxX and y >= a.minY and y <= a.maxY then return true end
    end
    return false
end

return MapSites
