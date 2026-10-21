-- The phone cameras (docs/rounds/CAMERA_PLAN.md, 2026-10-19: era-accurate). Pure data and helpers, shared by
-- the client (Camera app, Photos) and the server (storage limits, photos arriving by text).
local CameraSpec = {}

-- By screen family: picture size, how many photos the phone holds, colours per channel (0 = full colour), and a
-- front camera for selfies (only the phones that really had one).
-- The brick and mono phones have no camera.
CameraSpec.FAMILIES = {
    ColorFeature = { w = 160, h = 120, max = 20, levels = 16 },  -- Sisu 6606 "Soapbar", 2003: a VGA-era toy
    Keyboard = { w = 320, h = 240, max = 50, levels = 32 },      -- Bramble Bend 2580
    Stylus = { w = 320, h = 240, max = 100, levels = 0 },        -- Sisu 5320 XpressoMusic, 2009
    ModernPear = { w = 640, h = 480, max = 200, levels = 0, front = true },    -- PearPhone 4
    ModernAndroid = { w = 640, h = 480, max = 200, levels = 0, front = true }, -- Daebak Supernova IV
}

function CameraSpec.forFamily(family) return CameraSpec.FAMILIES[family] end

-- A photo id: letters, digits and dashes, short (it travels in text bodies and file names).
function CameraSpec.validId(id) return type(id) == "string" and #id > 0 and #id <= 48 and id:match("^[%w%-]+$") ~= nil end

-- A text carrying a photo: "[Photo:<id>] caption". Returns id, caption (or nil when it isn't one).
function CameraSpec.parseText(body)
    local id, caption = tostring(body or ""):match("^%[Photo:([%w%-]+)%] ?(.*)$")
    if id and CameraSpec.validId(id) then return id, caption end
    return nil
end

function CameraSpec.text(id, caption) return "[Photo:" .. id .. "] " .. tostring(caption or "") end

-- What a thread shows for it: "[Photo] caption".
function CameraSpec.shown(body)
    local id, caption = CameraSpec.parseText(body)
    if not id then return body end
    return "[Photo] " .. caption
end

return CameraSpec
