-- Server: puts each locked found phone's way in where a player can find it (0.2.2; Core/Clues decides which).
--
-- Bodies. Build 42 fills a dead zombie's inventory (wallet, ID card, badge...) the first time someone opens the body,
-- after OnZombieDead (IsoZombie.onKilled fires OnZombieDead, then ISInventoryPage fills the unexplored container, or
-- the server does on requestServerItemsForContainer). 0.2.0 put its own wallet and ID card on at death, and then the
-- game added its own: two wallets, two names, and the birthday on the wrong card. So the zombie hook only marks the
-- phone, and the clue goes on here when the body fills: on the body's own ID cards and wallet, and only when it has
-- none, one wallet with one ID card from Knox.
-- Houses. A phone rolled into a house's container gets a note in the same house: in another container of that room
-- when one fills in the same moment (the game fills a building's containers together as it loads), else in another
-- room's, else in the phone's own. Glove boxes get the note beside the phone.
-- Everything is decided once per phone (KnoxMobileClue on the phone): never a second note, card or wallet.
local Clues = require "KnoxMobile/Core/Clues"
local Rng = require "KnoxMobile/Core/Rng"
local Names = require "KnoxMobile/Story/Names"
local Phones = require "KnoxMobile/Game/Phones"
local Util = require "KnoxMobile/Game/Util"
local Tick = require "KnoxMobile/Game/Tick"
local State = require "KnoxMobile/State"

local ClueWorld = {}
KnoxMobile.ClueWorld = ClueWorld

local T = Util.text
local ID_TYPES = { ["Base.IDcard"] = true, ["Base.IDcard_Female"] = true, ["Base.IDcard_Male"] = true }

local function isWallet(it) return tostring(it:getFullType()):find("^Base%.Wallet") ~= nil end
local function isDogTags(it) return tostring(it:getFullType()):find("^Base%.Necklace_DogTag") ~= nil end
local function isBadge(it) return it:getFullType() == "Base.Badge" end

local function all(inv, pred)
    local out = {}
    local list = inv:getAllEvalRecurse(function(it) return pred(it) == true end)
    for i = 0, list:size() - 1 do out[#out + 1] = list:get(i) end
    return out
end

local function seed(phone, what) return tostring(State.get().seed) .. ":clue:" .. what .. ":" .. tostring(phone:getID()) end

local function itemName(fullType, fallback)
    local ok, base = pcall(getItemNameFromFullType, fullType)
    -- A server has no translations: there the game hands back the raw type.
    if not ok or type(base) ~= "string" or base == "" or base:find("^Base%.") then base = fallback end
    return base
end

-- Does this phone still need its way in? Found phones only (not a starting, family or boxed one), while PINs are on.
local function needsClue(phone)
    local md = phone:getModData()
    if type(md.KnoxMobileClue) == "table" then return false end
    local origin = md.KnoxMobileOrigin
    if origin ~= nil and origin ~= "found" then return false end
    local raw = md[Phones.KEY]
    if type(raw) == "table" and type(raw.security) == "table" and not raw.security.locked then return false end
    return true
end

local function record(phone, clue, where)
    local md = phone:getModData()
    md.KnoxMobilePin = clue.pin
    md.KnoxMobileClue = { kind = clue.kind, pin = clue.pin, where = where, tags = clue.tags }
end

-- A sheet of paper the game's Read opens (and Knox's "Read the note"), locked so nobody writes over it. pin: the code
-- it gives away (nil for a note that only points to the ID card).
local function makeNote(name, text, phone, pin)
    local note = instanceItem("Base.SheetPaper2")
    if not note then return nil end
    note:addPage(1, text)
    note:setLockedBy("KnoxMobile")
    note:setName(name)
    note:setCustomName(true)
    local md = note:getModData()
    md.KnoxMobileCluePhone = tostring(phone:getID())
    md.KnoxMobileCluePin = pin
    md.KnoxMobileClueText = text
    return note
end

local function newOwner(phone, rng)
    local md = phone:getModData()
    local female = md.KnoxMobileFemale
    if female == nil then female = rng:chance(0.5) end
    local first = rng:pick(female and Names.female or Names.male)
    md.KnoxMobileOwnerName = first .. " " .. rng:pick(Names.surnames)
    md.KnoxMobileFemale = female
    return first
end

local function hometown(phone)
    local ok, id = pcall(function() return KnoxMobile.Server.ownerIdentity(phone) end)
    return ok and id and id.hometown or nil
end

-- A zombie's body, as the game fills it.
function ClueWorld.onBody(inv, phone, model)
    local md = phone:getModData()
    md.KnoxMobileCluePending = nil
    local rng = Rng.new(seed(phone, "body"))
    local tagItem = all(inv, function(it) return isDogTags(it) or isBadge(it) end)[1]
    local clue = Clues.pick(rng, "body", { family = model.family,
        tags = tagItem and (isBadge(tagItem) and "badge" or "dogtags") or nil })
    record(phone, clue, "body")
    md.KnoxMobileBorn = tonumber(clue.born:sub(7, 8))
    local female = md.KnoxMobileFemale == true
    local cards = all(inv, function(it) return ID_TYPES[it:getFullType()] end)
    -- The owner is the zombie (its descriptor's name, the one the game prints on its ID cards), else the card's.
    local owner = md.KnoxMobileOwnerName
    if not owner and cards[1] and KnoxMobile.Server then owner = KnoxMobile.Server.nameFromIdCard(cards[1]:getName()) end
    if owner then md.KnoxMobileOwnerName = owner else newOwner(phone, rng); owner = md.KnoxMobileOwnerName end

    local wallet = all(inv, isWallet)[1]
    local into = wallet and wallet.getInventory and wallet:getInventory() or nil
    if #cards == 0 then
        if not wallet then
            wallet = inv:AddItem(female and "Base.Wallet_Female" or "Base.Wallet_Male")
            into = wallet and wallet.getInventory and wallet:getInventory() or nil
            -- Knox fills its own wallet here, so the game never rolls a second ID card into it.
            if into then
                into:setExplored(true)
                for _ = 1, rng:int(0, 2) do into:AddItem("Base.Money") end
            end
        end
        local card = (into or inv):AddItem(female and "Base.IDcard_Female" or "Base.IDcard_Male")
        if card then cards[1] = card end
    end
    local home = hometown(phone)
    for _, card in ipairs(cards) do
        card:setName(T("IGUI_ItemWithDisplayName", "%1: %2", itemName(card:getFullType(), "ID Card"), owner)
            .. " (born " .. clue.born .. ")")
        card:setCustomName(true)
        local cmd = card:getModData()
        cmd.KnoxMobileOwner, cmd.KnoxMobileBornDate, cmd.KnoxMobileHome = owner, clue.born, home
        cmd.KnoxMobileCluePhone = tostring(phone:getID())
    end
    if tagItem then
        local tmd = tagItem:getModData()
        tmd.KnoxMobileOwner, tmd.KnoxMobileTagNumber, tmd.KnoxMobileTagKind = owner, clue.number, clue.tags
        tmd.KnoxMobileCluePhone = tostring(phone:getID())
    end
    local pocket = into or inv
    local note
    if clue.kind == "note" then
        note = makeNote(T("IGUI_KnoxMobile_NoteFolded", "Folded note"), Clues.noteText(rng, "note", clue.pin), phone, clue.pin)
    elseif clue.kind == "birthday" and rng:chance(Clues.BIRTHDAY_NOTE) then
        note = makeNote(T("IGUI_KnoxMobile_NoteFolded", "Folded note"), Clues.noteText(rng, "birthday", clue.pin), phone, nil)
    end
    if note then pocket:AddItem(note) end
    Util.log("phone clue on a body:", clue.kind, "for", owner)
end

function ClueWorld.onCar(container, phone)
    local rng = Rng.new(seed(phone, "car"))
    local clue = Clues.pick(rng, "car")
    record(phone, clue, "car")
    local first = newOwner(phone, rng)
    local note = makeNote(T("IGUI_KnoxMobile_NoteReceipt", "Note on a gas receipt"), Clues.noteText(rng, "car", clue.pin, first),
        phone, clue.pin)
    if note then container:AddItem(note) end
end

-- House notes waiting for another container of the same building to fill: building id -> list of
-- { note, home = the phone's container, room, at, candidate = another room's container }.
local pending, waiting = {}, 0
local SKIP = { stove = true, microwave = true, toaster = true, clothingdryer = true, clothingwasher = true,
    barbecue = true, fireplace = true, woodstove = true, toilet = true }

local function squareOf(container)
    local ok, sq = pcall(function()
        local parent = container:getParent()
        return parent and parent:getSquare() or container:getSourceGrid()
    end)
    return ok and sq or nil
end

function ClueWorld.onHouse(container, phone)
    local rng = Rng.new(seed(phone, "house"))
    local clue = Clues.pick(rng, "house")
    record(phone, clue, "house")
    -- The note names the owner, so the owner is decided now (Server.fillFoundPhone takes this name).
    local first = newOwner(phone, rng)
    local note = makeNote(T("IGUI_KnoxMobile_NoteHouse", "Handwritten note"), Clues.noteText(rng, "house", clue.pin, first),
        phone, clue.pin)
    if not note then return end
    local sq = squareOf(container)
    local def = sq and sq:getBuildingDef()
    if not def then container:AddItem(note); return end
    local key = def:getIDString()
    pending[key] = pending[key] or {}
    table.insert(pending[key], { note = note, home = container, room = sq:getRoomIDString(), at = getTimestampMs() })
    waiting = waiting + 1
end

-- Any other container filling: it may take a waiting house note.
function ClueWorld.onOtherFill(container)
    if waiting == 0 then return end
    if container:isCorpse() or container:getVehiclePart() or SKIP[tostring(container:getType())] then return end
    local sq = squareOf(container)
    local def = sq and sq:getBuildingDef()
    local list = def and pending[def:getIDString()]
    if not list then return end
    local room = sq:getRoomIDString()
    for i, p in ipairs(list) do
        if p.home ~= container then
            if p.room == room then
                container:AddItem(p.note) -- one note per container
                table.remove(list, i)
                waiting = waiting - 1
                break
            elseif not p.candidate then
                p.candidate = container
            end
        end
    end
    if #list == 0 then pending[def:getIDString()] = nil end
end

-- The containers the game just filled. phones: { { item, model } } of the Knox phones in it.
function ClueWorld.onFill(container, phones)
    if Phones.pinsOn() then
        for _, p in ipairs(phones) do
            local phone, model = p[1], p[2]
            if needsClue(phone) then
                if container:isCorpse() then
                    if phone:getModData().KnoxMobileCluePending then ClueWorld.onBody(container, phone, model) end
                elseif container:getVehiclePart() then
                    ClueWorld.onCar(container, phone)
                else
                    ClueWorld.onHouse(container, phone)
                end
            end
        end
    end
    ClueWorld.onOtherFill(container)
end

-- A house note nobody else took within a moment goes in another room's container, else beside the phone.
Tick.add("phone clues", function()
    if waiting == 0 then return end
    local now = getTimestampMs()
    for key, list in pairs(pending) do
        for i = #list, 1, -1 do
            local p = list[i]
            if now - p.at > 1500 then
                local into = p.candidate or p.home
                pcall(function()
                    into:AddItem(p.note)
                    if isServer() then sendAddItemToContainer(into, p.note) end
                end)
                table.remove(list, i)
                waiting = waiting - 1
            end
        end
        if #list == 0 then pending[key] = nil end
    end
end, 500)

-- An A-Life NPC's phone: nothing is added to that mod's bodies, so the way in is on the phone or a lucky guess.
function ClueWorld.forALife(phone, model)
    if not Phones.pinsOn() then return end
    record(phone, Clues.pick(Rng.new(seed(phone, "alife")), "alife", { family = model.family }), "alife")
end

-- Every other locked found phone (a container the clue code never saw, phones from before 0.2.2): the code is on its
-- back. pin: the PIN it already has, if any. Returns the clue.
function ClueWorld.ensure(phone, pin)
    local md = phone:getModData()
    if type(md.KnoxMobileClue) == "table" then return md.KnoxMobileClue end
    md.KnoxMobileCluePending = nil
    local clue = Clues.pick(Rng.new(seed(phone, "phone")), "phone")
    clue.pin = pin or md.KnoxMobilePin or clue.pin
    record(phone, clue, "phone")
    return md.KnoxMobileClue
end

function ClueWorld.tapeText(phone, pin)
    return Clues.tapeText(Rng.new(seed(phone, "tape")), pin)
end

return ClueWorld
