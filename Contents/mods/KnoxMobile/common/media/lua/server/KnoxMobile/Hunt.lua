-- Server: the family hunt in the world (2026-10-12). The family's texts name one real building (Story/Sites.lua);
-- once their last text is out, the scene is set there the first time that chunk loads (Scenes.lua says how, and how
-- it never spawns twice; Core/Hunt decides what is there).
local Hunt = require "KnoxMobile/Core/Hunt"
local Rng = require "KnoxMobile/Core/Rng"
local Sim = require "KnoxMobile/Core/Sim"
local Loot = require "KnoxMobile/Core/Loot"
local Photos = require "KnoxMobile/Core/Photos"
local ItemIds = require "KnoxMobile/ItemIds"
local Phones = require "KnoxMobile/Game/Phones"
local Util = require "KnoxMobile/Game/Util"
local State = require "KnoxMobile/State"
local Scenes = require "KnoxMobile/Scenes"

local HuntWorld = {}
local freeInside = Scenes.freeInside

local function seedFor(number, what) return tostring(State.get().seed) .. ":hunt:" .. tostring(number) .. ":" .. what end

function HuntWorld.arm(hunt)
    hunt.state = "armed"
    Scenes.invalidate()
    Util.log("family hunt armed:", hunt.name, hunt.outcome.kind)
end

-- Open ground outside the building with room for a car facing north (3 x 5 squares clear).
local function carSquare(anchor)
    local cell, x0, y0 = getCell(), anchor:getX(), anchor:getY()
    local function clear(x, y)
        local sq = cell:getGridSquare(x, y, 0)
        return sq ~= nil and sq:isOutside() and not sq:getRoom() and sq:isFree(false)
    end
    for r = 4, 18 do
        for dx = -r, r do
            for dy = -r, r do
                if math.max(math.abs(dx), math.abs(dy)) == r then
                    local ok = true
                    for ox = -1, 1 do
                        for oy = -2, 2 do if ok and not clear(x0 + dx + ox, y0 + dy + oy) then ok = false end end
                    end
                    if ok then return cell:getGridSquare(x0 + dx, y0 + dy, 0) end
                end
            end
        end
    end
    return nil
end

-- The note: written to the player by the first who left, naming the first who turned. A sheet of paper the
-- vanilla "Read note" menu opens (locked, so nobody can write over it).
local function noteText(hunt)
    local n, p, me = hunt.note, hunt.people, hunt.player.first
    local text
    if n.line == 1 then
        text = Util.text("IGUI_KnoxMobile_HuntNote1",
            "%1, we waited as long as we could. Soldiers are taking people to the camp by the fence and we're going with them.", me)
    elseif n.line == 2 then
        text = Util.text("IGUI_KnoxMobile_HuntNote2",
            "%1, if you find this, we went with the convoy. Don't stay here after dark. They come at night.", me)
    else
        text = Util.text("IGUI_KnoxMobile_HuntNote3",
            "%1, I'm sorry. We couldn't wait any longer. We're heading north on foot with the neighbors.", me)
    end
    if n.lost then
        text = text .. " " .. Util.text("IGUI_KnoxMobile_HuntNoteLost", "%1 didn't make it. I couldn't stay.", Hunt.callName(p, n.lost))
    end
    if hunt.car then
        text = text .. " " .. Util.text("IGUI_KnoxMobile_HuntNoteCar", "The roads are blocked, so we left the car. The keys are here.")
    end
    return text .. " " .. Util.text("IGUI_KnoxMobile_HuntNoteSign", "Love you. %1", Hunt.callName(p, n.writer))
end

local function placeNote(hunt, sq)
    local note = instanceItem("Base.SheetPaper2")
    if not note then return nil end
    note:addPage(1, noteText(hunt))
    note:setLockedBy("KnoxMobile")
    note:setName(Util.text("IGUI_KnoxMobile_HuntNoteName", "Note for %1", hunt.player.first))
    note:setCustomName(true)
    sq:AddWorldInventoryItem(note, 0.5, 0.5, 0)
    return note
end

local function placeCar(hunt, anchor, noteSq)
    local sq = carSquare(anchor)
    if not sq then Util.log("family hunt: no room for the car at", hunt.name); return nil end
    local car = addVehicleDebug(hunt.car, IsoDirections.N, nil, sq)
    if car and noteSq then
        local key = car:createVehicleKey()
        if key then noteSq:AddWorldInventoryItem(key, 0.3, 0.6, 0) end
    end
    return car
end

-- Sets the scene. Returns true once it is set (or there is nothing to set).
function HuntWorld.spawn(number, hunt)
    if hunt.state ~= "armed" then return false end
    local anchor = getCell():getGridSquare(hunt.x, hunt.y, 0)
    if not anchor then return false end -- unloaded again before it settled: the next load tries again
    hunt.state = "done"                 -- before anything is placed: never twice
    Scenes.invalidate()
    local placed = {}
    for i, member in ipairs(hunt.outcome.turned) do
        local p = hunt.people[member]
        local sq = freeInside(anchor, (i - 1) * 3)
        local list = addZombiesInOutfit(sq:getX(), sq:getY(), 0, 1, p.outfit, p.female and 100 or 0)
        local z = list and list:size() > 0 and list:get(0) or nil
        if z then z:getModData().KnoxMobileFamily = number .. "|" .. member end
        placed[#placed + 1] = member .. " (" .. p.outfit .. ")"
    end
    if hunt.note then
        local noteSq = freeInside(anchor, 1)
        placeNote(hunt, noteSq)
        placed[#placed + 1] = "note"
        if hunt.car and placeCar(hunt, anchor, noteSq) then placed[#placed + 1] = "car" end
    end
    Util.log("family hunt set at", hunt.name, ":", #placed > 0 and table.concat(placed, ", ") or "nobody there")
    return true
end

-- The member's own phone: their texts to the player and the player's texts they never read, unlocked, nearly flat.
local function familyPhone(inv, number, hunt, member)
    local plan = State.get().story[number]
    local p = hunt.people[member]
    local rng = Rng.new(seedFor(number, member))
    local weights = {}
    for _, m in ipairs(Phones.registry:spawnable(Util.settings().EraLimit)) do
        if m.family ~= "SegmentLCD" then weights[#weights + 1] = { m, Loot.share(m, Util.settings(), Phones.registry:phones()) } end
    end
    local model = rng:weighted(weights) or Phones.registry:spawnable(Util.settings().EraLimit)[1]
    if not model then return nil end
    local item = inv:AddItem(ItemIds.full(ItemIds.phone(model, rng:pick(model.colors))))
    if not item then return nil end
    item:getModData().KnoxMobileOrigin = "family"
    local state = Phones.get(item)
    state.battery.charge, state.battery.health = rng:int(6, 30), rng:int(60, 95)
    state.condition = rng:weighted({ { "scratched", 60 }, { "cracked", 40 } })
    state.power.on, state.security.locked = false, false
    local last = p.name:match("%s(.+)$") or ""
    state.owner = { kind = "generated", first = p.first, last = last, family = member, hometown = hunt.town }
    local contacts = { { name = hunt.player.first, number = hunt.player.number } }
    for _, other in ipairs(Hunt.MEMBERS) do
        if other ~= member then
            contacts[#contacts + 1] = { name = Hunt.callName(hunt.people, other), number = hunt.people[other].number }
        end
    end
    state.sim = Sim.newSim({ number = p.number, contacts = contacts })
    state.contents.texts = Hunt.memberTexts(hunt, member, plan and plan.messages or {}, function(body)
        return (body:gsub("{place}", (hunt.name:gsub("%%", "%%%%"))))
    end)
    state.story = { draft = p.draft }
    -- A colour phone keeps their camera roll, the player in it (Photos app).
    if Photos.fits(model) then
        state.story.photos = Photos.roll(rng, { hunt.player.first, Hunt.callName(hunt.people, member == "sib" and "mom" or "sib") },
            { lastDay = 0 })
    end
    -- Texts still queued for this number are on the phone now; drop them so they don't arrive twice.
    local q = State.get().queue
    local keep = {}
    for _, rec in ipairs(q.queued) do if rec.to ~= p.number then keep[#keep + 1] = rec end end
    q.queued = keep
    return item
end

local function idCard(inv, p)
    local fullType = p.female and "Base.IDcard_Female" or "Base.IDcard_Male"
    local card = inv:AddItem(fullType)
    if not card then return end
    local ok, base = pcall(getItemNameFromFullType, fullType)
    if not ok or type(base) ~= "string" or base == "" then base = "ID Card" end
    card:setName(Util.text("IGUI_ItemWithDisplayName", "%1: %2", base, p.name))
    card:setCustomName(true)
end

-- A family member killed: their phone and ID card go on the body. Their tag is on the zombie while it stays loaded;
-- after a reload, a zombie in their clothes near the scene is them. Returns true when it was family.
function HuntWorld.onZombieDead(zombie)
    local md = State.get()
    local number, member
    local zmd = zombie.getModData and zombie:getModData()
    local tag = zmd and zmd.KnoxMobileFamily
    if type(tag) == "string" then number, member = tag:match("^(.-)|(%a+)$") end
    local plan = number and md.story[number]
    if not (plan and plan.hunt) then
        number, member, plan = nil, nil, nil
        local x, y, female = zombie:getX(), zombie:getY(), zombie:isFemale()
        local outfit = zombie.getOutfitName and zombie:getOutfitName() or nil
        for n, pl in pairs(md.story) do
            local m = pl.hunt and Hunt.matchZombie(pl.hunt, x, y, outfit, female)
            if m then number, member, plan = n, m, pl; break end
        end
    end
    if not plan then return false end
    local hunt = plan.hunt
    if hunt.phones[member] then return true end
    hunt.phones[member] = true
    local inv = zombie:getInventory()
    familyPhone(inv, number, hunt, member)
    idCard(inv, hunt.people[member])
    Util.log("family hunt:", member, "found at", hunt.name)
    return true
end

-- The scene machinery (Scenes.lua): armed hunts by their anchor square, set while FamilyHunt is on.
Scenes.register("family", {
    armed = function()
        local out = {}
        for number, plan in pairs(State.get().story) do
            local h = plan.hunt
            if h and h.state == "armed" then out[#out + 1] = { id = number, x = h.x, y = h.y } end
        end
        return out
    end,
    spawn = function(number)
        local plan = State.get().story[number]
        if plan and plan.hunt and Util.settings().FamilyHunt then HuntWorld.spawn(number, plan.hunt) end
    end,
})

return HuntWorld
