-- Snake: the game logic behind the Snake app (client/KnoxMobile/Apps/Snake.lua). Pure Lua 5.1: the board,
-- the snake, food, score and levels. Randomness comes in as an Rng (Core/Rng) and time as "step" calls, so the
-- same game plays the same in unit tests.
--
--   local g = Snake.new(20, 12, rng, { wrap = true })   -- classic Sisu rules: the snake wraps at the edges
--   Snake.turn(g, "up")                                 -- queued, applied on the next step
--   local event = Snake.step(g, rng)                    -- "moved", "ate", "levelUp", "died" or "won"
--   Snake.interval(g)                                   -- milliseconds until the next step
local Mod = require "KnoxMobile/Core/Mod"
local Snake = {}

Snake.START_LENGTH = 4
Snake.FOOD_PER_LEVEL = 5
Snake.MAX_LEVEL = 9
Snake.MAX_QUEUE = 2 -- turns typed faster than the snake moves wait here (two is enough for a quick U-turn)

local DIRS = { up = { 0, -1 }, down = { 0, 1 }, left = { -1, 0 }, right = { 1, 0 } }
local OPPOSITE = { up = "down", down = "up", left = "right", right = "left" }

Snake.DIRS = DIRS

local function key(x, y) return x * 1000 + y end

local function occupied(g)
    local set = {}
    for _, c in ipairs(g.body) do set[key(c.x, c.y)] = true end
    return set
end

-- A free cell for the food, picked uniformly; nil when the snake fills the board.
function Snake.placeFood(g, rng)
    local taken = occupied(g)
    local free = g.cols * g.rows - #g.body
    if free <= 0 then g.food = nil; return nil end
    local pick = rng:int(1, free)
    for y = 1, g.rows do
        for x = 1, g.cols do
            if not taken[key(x, y)] then
                pick = pick - 1
                if pick == 0 then g.food = { x = x, y = y }; return g.food end
            end
        end
    end
    g.food = nil
    return nil
end

-- cols, rows: board size in cells (at least 6 x 4). opts.wrap: walls wrap around (classic) instead of killing.
function Snake.new(cols, rows, rng, opts)
    opts = opts or {}
    cols = math.max(6, math.floor(cols))
    rows = math.max(4, math.floor(rows))
    local g = { cols = cols, rows = rows, wrap = opts.wrap == true, dir = "right", queue = {}, body = {},
        score = 0, level = 1, eaten = 0, grow = 0, state = "play", steps = 0 }
    local length = math.min(opts.length or Snake.START_LENGTH, cols - 2)
    local y = math.floor((rows + 1) / 2)
    local headX = math.floor(cols / 2) + 1
    for i = 0, length - 1 do g.body[#g.body + 1] = { x = headX - i, y = y } end
    Snake.placeFood(g, rng)
    return g
end

-- Queues a turn. A turn back onto the snake's own neck, or a repeat of the current heading, is ignored.
-- Returns true when the turn was queued.
function Snake.turn(g, dir)
    if not DIRS[dir] or g.state ~= "play" then return false end
    local last = g.queue[#g.queue] or g.dir
    if dir == last or dir == OPPOSITE[last] then return false end
    if #g.queue >= Snake.MAX_QUEUE then return false end
    g.queue[#g.queue + 1] = dir
    return true
end

-- Moves one cell. Returns what happened: "moved", "ate", "levelUp", "died", "won" (board full), or nil when
-- the game is not being played.
function Snake.step(g, rng)
    if g.state ~= "play" then return nil end
    if #g.queue > 0 then g.dir = table.remove(g.queue, 1) end
    local d = DIRS[g.dir]
    local head = g.body[1]
    local nx, ny = head.x + d[1], head.y + d[2]
    if g.wrap then
        nx = Mod.floor((nx - 1), g.cols) + 1
        ny = Mod.floor((ny - 1), g.rows) + 1
    elseif nx < 1 or nx > g.cols or ny < 1 or ny > g.rows then
        g.state = "over"
        return "died"
    end
    local eating = g.food ~= nil and g.food.x == nx and g.food.y == ny
    -- The tail moves out of the way this step unless the snake is growing.
    local growing = g.grow > 0 or eating
    local last = #g.body
    for i, c in ipairs(g.body) do
        if c.x == nx and c.y == ny and not (i == last and not growing) then
            g.state = "over"
            return "died"
        end
    end
    table.insert(g.body, 1, { x = nx, y = ny })
    if g.grow > 0 then
        g.grow = g.grow - 1
    elseif not eating then
        table.remove(g.body)
    end
    g.steps = g.steps + 1
    if not eating then return "moved" end
    g.eaten = g.eaten + 1
    g.score = g.score + g.level
    local event = "ate"
    if Mod.floor(g.eaten, Snake.FOOD_PER_LEVEL) == 0 and g.level < Snake.MAX_LEVEL then
        g.level = g.level + 1
        event = "levelUp"
    end
    if not Snake.placeFood(g, rng) then
        g.state = "won"
        return "won"
    end
    return event
end

-- Milliseconds between steps: brisk at level 1, frantic at level 9.
function Snake.interval(g)
    return math.max(70, 230 - (g.level - 1) * 20)
end

function Snake.length(g) return #g.body end

-- Is the cell part of the snake? Returns "head", "body" or nil (for drawing).
function Snake.cellAt(g, x, y)
    for i, c in ipairs(g.body) do
        if c.x == x and c.y == y then return i == 1 and "head" or "body" end
    end
    return nil
end

-- A finished game's score beats the stored best?
function Snake.isRecord(score, best) return (score or 0) > 0 and (score or 0) > (best or 0) end

return Snake
