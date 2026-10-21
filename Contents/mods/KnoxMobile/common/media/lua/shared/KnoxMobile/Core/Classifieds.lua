-- The Classifieds board: one server-wide list of short listings (category, title, text, the poster's number).
-- Pure Lua 5.1; times are in-game minutes. The server keeps the board in world ModData:
--   { posts = { { id, key, number, category, title, text, at, expires } }, nextId = 1, last = { [player key] = minutes } }
-- Player keys never leave the server: phones get public copies with `mine` set for their own posts.
local Mod = require "KnoxMobile/Core/Mod"
local Classifieds = {}

Classifieds.CATEGORIES = { "trade", "wanted", "services", "notices" }
Classifieds.MAX_TITLE = 40
Classifieds.MAX_TEXT = 200
Classifieds.MAX_ACTIVE = 3   -- live listings per player
Classifieds.POST_GAP = 60    -- in-game minutes between two listings by one player
Classifieds.MAX_BOARD = 60   -- listings on the board; a new one pushes out the oldest
Classifieds.LIST = 40        -- listings sent to a phone at once (newest first)

function Classifieds.new() return { posts = {}, nextId = 1, last = {} } end

function Classifieds.validCategory(c)
    for _, x in ipairs(Classifieds.CATEGORIES) do if x == c then return true end end
    return false
end

-- One line, trimmed, single-spaced; nil when empty or longer than max.
function Classifieds.clean(text, max)
    if type(text) ~= "string" then return nil end
    local s = text:gsub("%c", " "):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
    if #s == 0 or #s > max then return nil end
    return s
end

-- Drops listings past their end. Returns how many went.
function Classifieds.expire(board, now)
    local keep, gone = {}, 0
    for _, p in ipairs(board.posts) do
        if p.expires > now then keep[#keep + 1] = p else gone = gone + 1 end
    end
    board.posts = keep
    return gone
end

local function activeFor(board, key)
    local n = 0
    for _, p in ipairs(board.posts) do if p.key == key then n = n + 1 end end
    return n
end

-- p = { key, number, category, title, text }. days: how long it stays up.
-- Returns the listing, or nil plus a reason ("badCategory", "badTitle", "badText", "limit", "tooSoon") and,
-- for "tooSoon", the minutes left to wait.
function Classifieds.post(board, p, now, days)
    Classifieds.expire(board, now)
    if not Classifieds.validCategory(p.category) then return nil, "badCategory" end
    local title = Classifieds.clean(p.title, Classifieds.MAX_TITLE)
    if not title then return nil, "badTitle" end
    local text = Classifieds.clean(p.text, Classifieds.MAX_TEXT)
    if not text then return nil, "badText" end
    if activeFor(board, p.key) >= Classifieds.MAX_ACTIVE then return nil, "limit" end
    local last = board.last[p.key]
    if last and last <= now and now - last < Classifieds.POST_GAP then
        return nil, "tooSoon", math.ceil(Classifieds.POST_GAP - (now - last))
    end
    local post = { id = "c" .. board.nextId, key = p.key, number = p.number, category = p.category, title = title,
        text = text, at = now, expires = now + math.max(1, days or 7) * 1440 }
    board.nextId = board.nextId + 1
    board.posts[#board.posts + 1] = post
    while #board.posts > Classifieds.MAX_BOARD do table.remove(board.posts, 1) end
    board.last[p.key] = now
    return post
end

-- The poster or a moderator takes a listing down.
function Classifieds.remove(board, id, key, moderator)
    for i, p in ipairs(board.posts) do
        if p.id == id then
            if p.key ~= key and not moderator then return nil, "notYours" end
            table.remove(board.posts, i)
            return p
        end
    end
    return nil, "noPost"
end

-- Newest first, at most LIST, as copies a phone may see.
function Classifieds.list(board, now, viewerKey)
    local out = {}
    for i = #board.posts, 1, -1 do
        local p = board.posts[i]
        if p.expires > now and #out < Classifieds.LIST then
            out[#out + 1] = { id = p.id, category = p.category, title = p.title, text = p.text, number = p.number,
                at = p.at, expires = p.expires, mine = p.key == viewerKey or nil }
        end
    end
    return out
end

function Classifieds.count(posts, category)
    local n = 0
    for _, p in ipairs(posts) do if category == nil or p.category == category then n = n + 1 end end
    return n
end

function Classifieds.filter(posts, category)
    if category == nil then return posts end
    local out = {}
    for _, p in ipairs(posts) do if p.category == category then out[#out + 1] = p end end
    return out
end

-- Moves through n pages by delta, wrapping at both ends. Small screens show one listing per page.
function Classifieds.turn(page, n, delta)
    if n <= 0 then return 1 end
    return (Mod.floor((page - 1 + delta), n)) + 1
end

-- Command payload checks (registered with Core/Protocol by the server).
local function phoneId(args)
    if type(args.phoneId) ~= "number" then return false, "phoneId must be a number" end
    return true
end

Classifieds.validators = {
    boardList = phoneId,
    boardPost = function(args)
        if not Classifieds.validCategory(args.category) then return false, "unknown category" end
        if type(args.title) ~= "string" or #args.title < 1 or #args.title > Classifieds.MAX_TITLE then
            return false, "title must be 1-" .. Classifieds.MAX_TITLE .. " characters"
        end
        if type(args.text) ~= "string" or #args.text < 1 or #args.text > Classifieds.MAX_TEXT then
            return false, "text must be 1-" .. Classifieds.MAX_TEXT .. " characters"
        end
        return phoneId(args)
    end,
    boardRemove = function(args)
        if type(args.id) ~= "string" or #args.id < 1 or #args.id > 16 then return false, "id must be a short string" end
        return phoneId(args)
    end,
}

return Classifieds
