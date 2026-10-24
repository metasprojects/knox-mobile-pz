-- Server: photos (docs/rounds/CAMERA_PLAN.md). A photo is a base64 JPEG that the taker's client uploads in chunks;
-- the server keeps it as a text file (Lua/KnoxMobile/photos/<id>.txt, so servers need no Java part) and puts its
-- details on the phone ({ id, text, day, minute, w, h } in contents.photos, within the phone's storage limit).
-- Anyone whose phone lists a photo asks for it by id and gets it back in chunks.
local CameraSpec = require "KnoxMobile/Core/CameraSpec"
local Phones = require "KnoxMobile/Game/Phones"
local Util = require "KnoxMobile/Game/Util"
local Net = require "KnoxMobile/Game/Net"
local State = require "KnoxMobile/State"

local PhotoStore = {}
KnoxMobile.PhotoStore = PhotoStore

local CHUNK, MAX_PARTS, MAX_PENDING = 4000, 200, 3
local DIR = "KnoxMobile/photos/"
local uploads = {} -- id -> { key, parts, got, chunks, meta }

-- Build 42's getFileWriter only opens some extensions (.txt .json .ini .log .cfg; .b64 gave nil: second pass of the
-- final test, every photo "could not be written").
local function path(id) return DIR .. id .. ".txt" end

function PhotoStore.write(id, data)
    local w = getFileWriter(path(id), true, false)
    if not w then return false end
    w:write(data)
    w:close()
    return true
end

function PhotoStore.read(id)
    local r = getFileReader(path(id), false)
    if not r then return nil end
    local parts, line = {}, r:readLine()
    while line do
        parts[#parts + 1] = line
        line = r:readLine()
    end
    r:close()
    local s = table.concat(parts)
    return s ~= "" and s or nil
end

-- How many places show each photo (0.2.1): entries in a phone's Photos and texts that carry it, on every phone. At
-- zero the file is emptied, so deleted photos stop taking disk space on the server. Only photos taken since 0.2.1 are
-- counted (they start at 0 when written); older ones may be shown in places nobody counted and are never freed.
local function refs()
    local md = State.get()
    if type(md.photoRefs) ~= "table" then md.photoRefs = {} end
    return md.photoRefs
end

function PhotoStore.ref(id, delta)
    local r = id and refs()
    local n = r and r[id]
    if n == nil then return end
    n = n + delta
    if n > 0 then r[id] = n; return end
    r[id] = nil
    PhotoStore.write(id, "")
    Util.log("photo", id, "freed: nothing shows it any more")
end

-- Every photo a phone shows, once per place: its Photos list (a wallpaper is one of those) and its photo texts.
function PhotoStore.idsOn(state)
    local out = {}
    local contents = state and state.contents or {}
    for _, p in ipairs(contents.photos or {}) do if p.id then out[#out + 1] = p.id end end
    for _, conv in ipairs(contents.texts or {}) do
        for _, m in ipairs(conv.messages or {}) do
            local id = CameraSpec.parseText(m.body)
            if id then out[#out + 1] = id end
        end
    end
    return out
end

-- A phone wiped or scrapped: everything it showed stops counting.
function PhotoStore.release(state)
    for _, id in ipairs(PhotoStore.idsOn(state)) do PhotoStore.ref(id, -1) end
end

-- A photo entry on a phone: false when the phone has no camera or its memory is full.
function PhotoStore.add(state, model, entry)
    local spec = CameraSpec.forFamily(model.family)
    if not spec then return false end
    state.contents.photos = state.contents.photos or {}
    if #state.contents.photos >= spec.max then return false end
    for _, p in ipairs(state.contents.photos) do if p.id == entry.id then return true end end
    table.insert(state.contents.photos, entry)
    PhotoStore.ref(entry.id, 1)
    return true
end

local function pending(key)
    local n = 0
    for _, u in pairs(uploads) do if u.key == key then n = n + 1 end end
    return n
end

Net.onServer("photoChunk", function(player, args)
    if not CameraSpec.validId(args.id) or type(args.data) ~= "string" or #args.data > CHUNK then return end
    local part, parts = tonumber(args.part), tonumber(args.parts)
    if not part or not parts or parts < 1 or parts > MAX_PARTS or part < 1 or part > parts then return end
    local key = Util.playerKey(player)
    local u = uploads[args.id]
    if not u then
        if pending(key) >= MAX_PENDING then return end
        u = { key = key, parts = parts, got = 0, chunks = {}, meta = {} }
        uploads[args.id] = u
    end
    if u.key ~= key or u.parts ~= parts then return end
    if part == 1 then
        u.meta = { phoneId = args.phoneId, text = type(args.caption) == "string" and args.caption:sub(1, 160) or "",
            w = tonumber(args.w), h = tonumber(args.h) }
    end
    if not u.chunks[part] then u.got = u.got + 1 end
    u.chunks[part] = args.data
    if u.got < parts then return end
    uploads[args.id] = nil
    local data = table.concat(u.chunks)
    if not PhotoStore.write(args.id, data) then
        Util.log("photo", args.id, "could not be written")
        Net.toClient(player, "photoSaved", { id = args.id, ok = false, reason = "write", phoneId = u.meta.phoneId })
        return
    end
    refs()[args.id] = refs()[args.id] or 0 -- counted from now on
    local item = u.meta.phoneId and Phones.findById(player, u.meta.phoneId)
    local state, model = item and Phones.get(item), item and Phones.model(item)
    local day, minute = require("KnoxMobile/Messaging").stamp()
    local ok = state and model and PhotoStore.add(state, model, { id = args.id, text = u.meta.text, day = day, minute = minute,
        w = u.meta.w, h = u.meta.h })
    if ok then Phones.save(item, player) else PhotoStore.ref(args.id, 0) end -- on no phone: freed at once
    Util.log("photo", args.id, "saved", #data, "chars,", ok and "on the phone" or "phone full or gone")
    Net.toClient(player, "photoSaved", { id = args.id, ok = ok == true, phoneId = u.meta.phoneId })
end)

Net.onServer("photoGet", function(player, args)
    if not CameraSpec.validId(args.id) then return end
    local data = PhotoStore.read(args.id)
    if not data then Net.toClient(player, "photoMissing", { id = args.id }); return end
    local parts = math.ceil(#data / CHUNK)
    for i = 1, parts do
        Net.toClient(player, "photoChunk", { id = args.id, part = i, parts = parts,
            data = data:sub((i - 1) * CHUNK + 1, i * CHUNK) })
    end
end)

-- Deleting a photo takes it off this phone; the file stays while other phones and texts still show it.
Net.onServer("photoDelete", function(player, args)
    local item = Phones.findById(player, args.phoneId)
    local state = item and Phones.get(item)
    local list = state and state.contents.photos
    local i = tonumber(args.index)
    if not (list and i and list[i]) or (args.id and list[i].id ~= args.id) then return end
    local id = list[i].id
    if id and state.look.wallpaperPhoto == id then state.look.wallpaperPhoto = nil end
    table.remove(list, i)
    PhotoStore.ref(id, -1)
    Phones.save(item, player)
end)

return PhotoStore
