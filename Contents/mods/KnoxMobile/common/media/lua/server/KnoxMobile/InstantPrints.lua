-- Server: the instant camera (0.3.0, Core/Instant). "loadFilm" puts a film pack in; "instantShot" takes one shot and
-- prints the photo into the taker's bags (KnoxMobile.InstantPhoto: mod data KnoxMobilePhoto = { id, caption, day,
-- minute }). With the Java part the picture itself arrives after, through the usual photo upload (PhotoStore), and the
-- printed photo counts as one place that shows it.
local Instant = require "KnoxMobile/Core/Instant"
local CameraSpec = require "KnoxMobile/Core/CameraSpec"
local Net = require "KnoxMobile/Game/Net"
local Util = require "KnoxMobile/Game/Util"
local Protocol = require "KnoxMobile/Core/Protocol"
local State = require "KnoxMobile/State"

local World = {}
KnoxMobile.InstantWorld = World

Protocol.register({
    loadFilm = function(args) return type(args.cameraId) == "number", "cameraId must be a number" end,
    instantShot = function(args)
        if type(args.cameraId) ~= "number" then return false, "cameraId must be a number" end
        if args.id ~= nil and not CameraSpec.validId(args.id) then return false, "bad photo id" end
        return true
    end,
})

local function tell(player, event, n) Net.toClient(player, "notify", { kind = "instant", event = event, number = n }) end

local function find(player, id, fullType)
    local item = player:getInventory():getItemWithIDRecursiv(id)
    if item and item:getFullType() == fullType then return item end
    return nil
end

local function sync(player, item)
    if isServer() then syncItemModData(player, item) end
end

Net.onServer("loadFilm", function(player, args)
    local camera = find(player, args.cameraId, Instant.CAMERA)
    if not camera then return end
    if Instant.shots(camera:getModData()) > 0 then tell(player, "notEmpty", Instant.shots(camera:getModData())); return end
    local film = player:getInventory():getFirstTypeRecurse(Instant.FILM)
    if not film then tell(player, "noFilm"); return end
    local c = film:getContainer()
    if c then c:Remove(film) end
    if isServer() and c then sendRemoveItemFromContainer(c, film) end
    camera:getModData().KnoxMobileFilm = Instant.SHOTS
    sync(player, camera)
    tell(player, "loaded", Instant.SHOTS)
end)

-- One shot: a frame of film used, a photo in the bags. Returns the photo item, or nil (no camera, no film).
function World.shoot(player, args)
    local camera = find(player, args.cameraId, Instant.CAMERA)
    if not camera then return nil end
    local md = camera:getModData()
    local left = Instant.shots(md)
    if left <= 0 then tell(player, "empty"); return nil end
    md.KnoxMobileFilm = left - 1
    sync(player, camera)
    local inv = player:getInventory()
    local photo = inv:AddItem(Instant.PHOTO)
    if not photo then return nil end
    local day, minute = require("KnoxMobile/Messaging").stamp()
    local caption = Instant.cleanName(args.caption, "")
    photo:getModData().KnoxMobilePhoto = { id = args.id, caption = caption, day = day, minute = minute }
    local name = Instant.cleanName(args.name, nil)
    pcall(function()
        photo:setName(name)
        photo:setCustomName(true)
    end)
    if args.id then
        -- The printed photo shows the picture: it counts, so the file is kept (PhotoStore.ref).
        local md2 = State.get()
        if type(md2.photoRefs) ~= "table" then md2.photoRefs = {} end
        md2.photoRefs[args.id] = (md2.photoRefs[args.id] or 0) + 1
    end
    if isServer() then sendAddItemToContainer(inv, photo) end
    Util.log("instant photo", tostring(args.id), "printed;", md.KnoxMobileFilm, "shots left")
    tell(player, "printed", md.KnoxMobileFilm)
    return photo
end

Net.onServer("instantShot", function(player, args) World.shoot(player, args) end)

return World
