-- Server: puts Knox Mobile items into the vanilla loot lists before the game merges them (spec §4.4),
-- then reports what landed and whether the repeater recipe loaded (one log line each).
local Loot = require "KnoxMobile/Core/Loot"
local Registry = require "KnoxMobile/Core/Registry"
local Sandbox = require "KnoxMobile/Core/Sandbox"
local Accessories = require "KnoxMobile/Data/Accessories"

local function inject()
    local sandbox = Sandbox.read(SandboxVars and SandboxVars.KnoxMobile)
    local entries = Loot.entries(Registry.withBundledPhones(), Accessories, sandbox)
    local added, missing = 0, {}
    for _, e in ipairs(entries) do
        local list = ProceduralDistributions.list[e.list]
        -- Glove boxes live in the vehicle distributions.
        if e.vehicle then list = VehicleDistributions and VehicleDistributions[e.list] end
        if list and list.items then
            table.insert(list.items, e.item)
            table.insert(list.items, e.weight)
            added = added + 1
        else
            missing[#missing + 1] = e.list
        end
    end
    local line = string.format("[KnoxMobile] loot: %d entries added to %d lists", added, #Loot.lists(entries))
    if #missing > 0 then line = line .. "; missing lists: " .. table.concat(missing, ", ", 1, math.min(#missing, 5)) end
    print(line)
end

local function check()
    local found = 0
    for _, list in pairs(ProceduralDistributions.list) do
        if type(list) == "table" and type(list.items) == "table" then
            for _, v in ipairs(list.items) do
                if type(v) == "string" and v:find("^KnoxMobile%.") then found = found + 1 end
            end
        end
    end
    local recipe = getScriptManager():getCraftRecipe("KnoxMobile.BuildCellRepeater")
        or getScriptManager():getCraftRecipe("BuildCellRepeater")
    print(string.format("[KnoxMobile] loot check: %d Knox entries after merge; repeater recipe %s",
        found, recipe and "loaded" or "MISSING"))
end

-- A modern phone found in a container often has its charging kit beside it: its own cable and a USB wall adapter
-- (second pass: the tester found no adapter in seven houses).
local Phones = require "KnoxMobile/Game/Phones"
local Rng = require "KnoxMobile/Core/Rng"
local function itemsOf(a)
    if a == nil or type(a) == "string" then return nil end
    local ok, items = pcall(function() return a:getItems() end)
    if ok and items and items.size then return items end
    return nil
end

-- 0.2.4: the phone years as they are now (Core/Loot.yearFilter), made again only when they change.
local years = { key = nil, outOfYears = nil }
local function outOfYearsNow()
    local sv = SandboxVars and SandboxVars.KnoxMobile or {}
    local key = tostring(sv.EraLimit) .. ":" .. tostring(sv.OldestPhoneYear) .. ":" .. tostring(sv.NewestPhoneYear)
    if years.key ~= key then
        years.key = key
        years.outOfYears = Loot.yearFilter(Registry.withBundledPhones(), Accessories, Sandbox.read(sv))
    end
    return years.outOfYears
end

-- Phones, boxes, manuals, spare batteries and car phone kits the phone years don't allow leave a container as the game
-- fills it. What the mod put there itself (a zombie's phone, a family member's, a clue) carries its data and stays.
local function untouched(item)
    for k in pairs(item:getModData()) do
        if tostring(k):sub(1, 10) == "KnoxMobile" then return false end
    end
    return true
end

local droppedLogged = false
local function dropOutOfYears(container, items)
    local outOfYears, drop = outOfYearsNow(), {}
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        local fullType = it:getFullType()
        if fullType:sub(1, 11) == "KnoxMobile." and outOfYears(fullType) and untouched(it) then drop[#drop + 1] = it end
    end
    for _, it in ipairs(drop) do container:Remove(it) end
    if #drop > 0 and not droppedLogged then
        droppedLogged = true
        print("[KnoxMobile] loot: took " .. #drop .. " items outside the phone years out of a container (first time only)")
    end
end

-- 0.2.2: and every locked found phone gets its way in (server/Clues.lua: on the body, in the house, in the glove box).
local ClueWorld = require "KnoxMobile/ClueWorld"
local function addKit(container)
    local items = itemsOf(container)
    if items then dropOutOfYears(container, items) end
    local phones, found = {}, {}
    for i = 0, (items and items:size() or 0) - 1 do
        local it = items:get(i)
        -- Every container the game fills comes through here: only Knox items get a closer look.
        local model = it:getFullType():sub(1, 11) == "KnoxMobile." and Phones.model(it)
        if model then
            phones[#phones + 1] = { it, model }
            if Registry.isUsbConnector(model.connector) then found[#found + 1] = { it, model } end
        end
    end
    for _, f in ipairs(found) do
        -- Once per phone: a body opened again or a container refilled (loot respawn) gets no second kit (0.2.2).
        local md = f[1]:getModData()
        if not md.KnoxMobileKit then
            md.KnoxMobileKit = true
            local rng = Rng.new("kit:" .. tostring(f[1]:getID()))
            if rng:int(1, 100) <= 60 then container:AddItem("KnoxMobile.Cable" .. f[2].connector) end
            if rng:int(1, 100) <= 50 then container:AddItem("KnoxMobile.UsbWallAdapter") end
        end
    end
    ClueWorld.onFill(container, phones)
end

if Events.OnFillContainer then
    -- Vanilla's own handler reads (room, container type, container), but Build 42 also passes the loot table's
    -- ItemPickerContainer there (third pass: "getItems of non-table", 32 times): use whichever argument is the
    -- container.
    Events.OnFillContainer.Add(function(...)
        local args = { ... }
        local container
        for i = 1, select("#", ...) do
            if itemsOf(args[i]) then container = args[i]; break end
        end
        if not container then return end
        local ok, err = pcall(addKit, container)
        if not ok then print("[KnoxMobile] phone kit failed: " .. tostring(err)) end
    end)
end

Events.OnPreDistributionMerge.Add(function()
    local ok, err = pcall(inject)
    if not ok then print("[KnoxMobile] loot failed: " .. tostring(err)) end
end)

Events.OnPostDistributionMerge.Add(function()
    local ok, err = pcall(check)
    if not ok then print("[KnoxMobile] loot check failed: " .. tostring(err)) end
end)
