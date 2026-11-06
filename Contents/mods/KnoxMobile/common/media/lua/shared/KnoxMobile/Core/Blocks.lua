-- 0.3.0: Brick Stack, the second game on the phones (Apps/Blocks.lua draws it). Pieces of four blocks fall into a
-- well; full rows clear and score; it speeds up every ten rows; a piece that can't enter ends the game. Pure Lua 5.1.
local Blocks = {}

-- Each piece: its four cells around (0, 0), y down.
Blocks.PIECES = {
    { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } },     -- square
    { { -1, 0 }, { 0, 0 }, { 1, 0 }, { 2, 0 } },    -- bar
    { { -1, 0 }, { 0, 0 }, { 1, 0 }, { 0, 1 } },    -- tee
    { { -1, 0 }, { 0, 0 }, { 1, 0 }, { 1, 1 } },    -- hook right
    { { -1, 0 }, { 0, 0 }, { 1, 0 }, { -1, 1 } },   -- hook left
    { { -1, 0 }, { 0, 0 }, { 0, 1 }, { 1, 1 } },    -- step right
    { { 0, 0 }, { 1, 0 }, { -1, 1 }, { 0, 1 } },    -- step left
}
Blocks.SCORE = { 40, 100, 300, 1200 } -- one to four rows at once, times the level

local function copy(cells)
    local out = {}
    for i, c in ipairs(cells) do out[i] = { c[1], c[2] } end
    return out
end

local function fits(g, cells, px, py)
    for _, c in ipairs(cells) do
        local x, y = px + c[1], py + c[2]
        if x < 1 or x > g.cols or y > g.rows then return false end
        if y >= 1 and g.grid[y][x] then return false end
    end
    return true
end

local function spawn(g, rng)
    local kind = rng:int(1, #Blocks.PIECES)
    g.piece = { kind = kind, cells = copy(Blocks.PIECES[kind]), x = math.floor(g.cols / 2), y = 1 }
    if not fits(g, g.piece.cells, g.piece.x, g.piece.y) then g.over = true end
end

function Blocks.new(cols, rows, rng)
    local g = { cols = math.max(6, cols), rows = math.max(10, rows), grid = {}, score = 0, lines = 0, level = 1 }
    for y = 1, g.rows do g.grid[y] = {} end
    spawn(g, rng)
    return g
end

function Blocks.move(g, dx)
    local p = g.piece
    if g.over or not p then return false end
    if fits(g, p.cells, p.x + dx, p.y) then p.x = p.x + dx; return true end
    return false
end

-- Turn a quarter clockwise; the square doesn't turn. A turn against a wall tries one step in, either way.
function Blocks.rotate(g)
    local p = g.piece
    if g.over or not p or p.kind == 1 then return false end
    local turned = {}
    for i, c in ipairs(p.cells) do turned[i] = { -c[2], c[1] } end
    for _, kick in ipairs({ 0, -1, 1 }) do
        if fits(g, turned, p.x + kick, p.y) then p.cells, p.x = turned, p.x + kick; return true end
    end
    return false
end

local function land(g, rng)
    local p = g.piece
    for _, c in ipairs(p.cells) do
        local y = p.y + c[2]
        if y < 1 then g.over = true; return "over" end
        g.grid[y][p.x + c[1]] = p.kind
    end
    local cleared, y = 0, g.rows
    while y >= 1 do
        local full = true
        for x = 1, g.cols do if not g.grid[y][x] then full = false; break end end
        if full then
            table.remove(g.grid, y)
            table.insert(g.grid, 1, {})
            cleared = cleared + 1
        else
            y = y - 1
        end
    end
    if cleared > 0 then
        g.score = g.score + Blocks.SCORE[math.min(4, cleared)] * g.level
        g.lines = g.lines + cleared
        g.level = 1 + math.floor(g.lines / 10)
    end
    spawn(g, rng)
    if g.over then return "over" end
    return cleared > 0 and "cleared" or "landed"
end

-- One fall step: down one row, or land. Returns "fell", "landed", "cleared" or "over".
function Blocks.step(g, rng)
    if g.over then return "over" end
    local p = g.piece
    if fits(g, p.cells, p.x, p.y + 1) then p.y = p.y + 1; return "fell" end
    return land(g, rng)
end

-- Straight down at once.
function Blocks.drop(g, rng)
    if g.over then return "over" end
    local p = g.piece
    while fits(g, p.cells, p.x, p.y + 1) do p.y = p.y + 1 end
    return land(g, rng)
end

-- Milliseconds between fall steps at this level.
function Blocks.interval(g) return math.max(90, 650 - (g.level - 1) * 60) end

-- What's drawn at (x, y): a piece kind or nil (the falling piece included).
function Blocks.cellAt(g, x, y)
    if g.grid[y] and g.grid[y][x] then return g.grid[y][x] end
    local p = g.piece
    if p and not g.over then
        for _, c in ipairs(p.cells) do if p.x + c[1] == x and p.y + c[2] == y then return p.kind end end
    end
    return nil
end

return Blocks
