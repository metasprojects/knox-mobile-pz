-- Server: photo boards (after 0.3.0). A Photo Board set down at your base holds up to twelve instant photos
-- (KnoxMobile.InstantPhoto, Core/Instant). Pin one from your bags and the print leaves them; take one down and it
-- comes back. The photos stay with the board: pick it up and set it down elsewhere, they come along.
-- global ModData: photoBoards[id] = { id, x, y, z, photos = { { id, caption, day, minute, name } } }; the board item
-- keeps its id (KnoxMobilePhotoBoardId).
local Util = require "KnoxMobile/Game/Util"
local State = require "KnoxMobile/State"
local Net = require "KnoxMobile/Game/Net"
local Protocol = require "KnoxMobile/Core/Protocol"
local Instant = require "KnoxMobile/Core/Instant"

local Boards = { MAX = 12, REACH = 3 }
KnoxMobile.PhotoBoards = Boards

local function all()
    local md = State.get()
    if type(md.photoBoards) ~= "table" then md.photoBoards = {} end
    return md.photoBoards
end

function Boards.byId(id) return id and all()[id] or nil end

-- Set down at this square: the board's own id when it had one (its photos come along), else a new one.
function Boards.place(player, square, id)
    local list = all()
    local b = id and list[id]
    if not b then
        local md = State.get()
        md.nextPhotoBoard = (md.nextPhotoBoard or 0) + 1
        id = "B" .. md.nextPhotoBoard
        b = { id = id, photos = {} }
        list[id] = b
    end
    b.x, b.y, b.z = square:getX(), square:getY(), square:getZ()
    b.owner = b.owner or Util.playerKey(player)
    Util.log("photo board", id, "set down at", b.x, b.y, b.z, "with", #b.photos, "photos")
    return b
end

local function near(player, b)
    return b and b.x and math.abs(player:getX() - b.x) <= Boards.REACH and math.abs(player:getY() - b.y) <= Boards.REACH
        and math.floor(player:getZ()) == b.z
end

local function send(player, b)
    local photos = {}
    for i, p in ipairs(b.photos) do photos[i] = { id = p.id, caption = p.caption, name = p.name } end
    Net.toClient(player, "photoBoard", { board = b.id, photos = photos })
end

Protocol.register({
    photoBoardOpen = function(args)
        if type(args.board) ~= "string" then return false, "board" end
        return true
    end,
    pinPhoto = function(args)
        if type(args.board) ~= "string" or type(args.photoId) ~= "number" then return false, "board and photoId" end
        return true
    end,
    unpinPhoto = function(args)
        if type(args.board) ~= "string" or type(args.index) ~= "number" then return false, "board and index" end
        return true
    end,
})

Net.onServer("photoBoardOpen", function(player, args)
    local b = Boards.byId(args.board)
    if near(player, b) then send(player, b) end
end)

Net.onServer("pinPhoto", function(player, args)
    local b = Boards.byId(args.board)
    if not near(player, b) then return end
    if #b.photos >= Boards.MAX then
        Net.toClient(player, "notify", { kind = "photoBoard", event = "full", number = Boards.MAX })
        return send(player, b)
    end
    local inv = player:getInventory()
    local photo = inv:getItemWithIDRecursiv(args.photoId)
    if not photo or photo:getFullType() ~= Instant.PHOTO then return end
    local data = photo:getModData().KnoxMobilePhoto or {}
    b.photos[#b.photos + 1] = { id = data.id, caption = data.caption, day = data.day, minute = data.minute,
        name = photo:getName() }
    local from = photo:getContainer() or inv
    from:Remove(photo)
    if isServer() then sendRemoveItemFromContainer(from, photo) end
    send(player, b)
end)

Net.onServer("unpinPhoto", function(player, args)
    local b = Boards.byId(args.board)
    local p = b and b.photos[math.floor(args.index)]
    if not (p and near(player, b)) then return end
    local inv = player:getInventory()
    local photo = inv:AddItem(Instant.PHOTO)
    if not photo then return end
    table.remove(b.photos, math.floor(args.index))
    photo:getModData().KnoxMobilePhoto = { id = p.id, caption = p.caption, day = p.day, minute = p.minute }
    if p.name then
        pcall(function()
            photo:setName(p.name)
            photo:setCustomName(true)
        end)
    end
    if isServer() then sendAddItemToContainer(inv, photo) end
    send(player, b)
end)

return Boards
