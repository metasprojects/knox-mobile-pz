-- Client: Snake (spec §4.6 "games" from the mono LCD phones up). The rules are Core/Snake (unit tested); this
-- draws the board and steers. The Sisu phones get the classic: black blocks on a green LCD that wrap at the
-- edges. The Bramble, ExpressoMusic and smartphones get a color version with walls.
-- Steer with the arrows, WASD or 2 4 6 8. While a game runs the character stands still (WASD steers the snake),
-- but the world doesn't wait: zombies keep walking, and a grab knocks the phone out of your hand.
-- The best score is saved on the phone (server command "snakeScore").
local SnakeGame = require "KnoxMobile/Core/Snake"
local Rng = require "KnoxMobile/Core/Rng"
local Phones = require "KnoxMobile/Game/Phones"
local Net = require "KnoxMobile/Game/Net"
local Util = require "KnoxMobile/Game/Util"
local Tick = require "KnoxMobile/Game/Tick"

local T = Util.text
local ICONS = "media/ui/KnoxMobile/apps/"
local CLASSIC = { MonoLCD = true, ColorFeature = true } -- the Sisu phones
local LCD_BG, LCD_INK = { 0.62, 0.72, 0.56 }, { 0.08, 0.12, 0.08 }
local DIGIT_DIRS = { ["2"] = "up", ["8"] = "down", ["4"] = "left", ["6"] = "right" }

local App = { blocked = nil }
KnoxMobile.SnakeApp = App

local function families()
    local out = {}
    for _, f in ipairs(Phones.registry:families()) do
        if f.features and f.features.games then out[#out + 1] = f.id end
    end
    return out
end

-- The character stands still while a game runs; any way out of the game lets them move again.
local function block(player, on)
    if on then
        if App.blocked ~= player then
            pcall(function() player:setBlockMovement(true) end)
            App.blocked = player
        end
    elseif App.blocked then
        local p = App.blocked
        App.blocked = nil
        pcall(function() p:setBlockMovement(false) end)
    end
end
App.block = block

local function best(ctx)
    local games = ctx.state.games
    return type(games) == "table" and tonumber(games.snake) or 0
end

local function newGame(ctx, w, h)
    local d = ctx.data
    local lh = ctx:lineHeight()
    local classic = CLASSIC[ctx.family] == true
    local cell = math.max(3, math.min(12, math.floor(w / (classic and 22 or 18))))
    local cols = math.floor((w - 4) / cell)
    local rows = math.floor((h - lh - 6) / cell)
    d.rng = Rng.new(tostring(getTimestampMs()) .. ":" .. tostring(ctx.phone:getID()))
    d.game = SnakeGame.new(cols, rows, d.rng, { wrap = classic })
    d.mode, d.last, d.newRecord = "play", getTimestampMs(), false
    d.keepBack = true
end

local function finish(ctx)
    local d = ctx.data
    d.mode, d.keepBack = "over", false
    block(ctx.player, false)
    local score = d.game and d.game.score or 0
    if SnakeGame.isRecord(score, d.best or best(ctx)) then
        d.newRecord, d.best = true, score
        Net.toServer(ctx.player, "snakeScore", { phoneId = ctx.phone:getID(), score = score })
    end
end

-- Advances the game by real time (the game runs while the phone is on screen).
local function advance(ctx)
    local d = ctx.data
    local g = d.game
    if d.mode ~= "play" or not g then return end
    local now = getTimestampMs()
    if now - d.last > 1500 then d.last = now end -- a long hitch (or a paused game) doesn't fast-forward the snake
    local steps = 0
    while now - d.last >= SnakeGame.interval(g) and steps < 3 do
        d.last = d.last + SnakeGame.interval(g)
        steps = steps + 1
        local event = SnakeGame.step(g, d.rng)
        if event == "died" or event == "won" then finish(ctx); return end
    end
end

local function centered(ctx, lines, x, y, w, h, color)
    local lh = ctx:lineHeight()
    local total = 0
    for _, l in ipairs(lines) do total = total + (l.big and (ctx:lineHeight() + 6) or lh) end
    local cy = y + math.floor((h - total) / 2)
    for _, l in ipairs(lines) do
        ctx:text(l.text, x + w / 2, cy, l.color or color, l.big and UIFont.Medium or nil, "center")
        cy = cy + (l.big and (lh + 6) or lh)
    end
end

local function drawBoard(ctx, x, y, w, h)
    local d = ctx.data
    local g = d.game
    local classic = CLASSIC[ctx.family] == true
    local cell = math.max(2, math.min(math.floor((w - 4) / g.cols), math.floor((h - 4) / g.rows)))
    local bw, bh = g.cols * cell, g.rows * cell
    local bx, by = x + math.floor((w - bw) / 2), y + math.floor((h - bh) / 2)
    local ink = classic and LCD_INK or { 0.45, 0.95, 0.4 }
    if classic then
        ctx:rect(bx - 2, by - 2, bw + 4, bh + 4, LCD_BG)
        ctx:border(bx - 2, by - 2, bw + 4, bh + 4, LCD_INK)
    else
        ctx:rect(bx - 2, by - 2, bw + 4, bh + 4, { 0.03, 0.06, 0.04 }, 0.95)
        for row = 1, g.rows, 2 do ctx:rect(bx, by + (row - 1) * cell, bw, cell, { 0.2, 0.4, 0.25 }, 0.12) end
        ctx:border(bx - 2, by - 2, bw + 4, bh + 4, ctx.style.accent, 0.9)
    end
    local gap = cell >= 4 and 1 or 0
    for i = #g.body, 1, -1 do
        local c = g.body[i]
        local cx, cy = bx + (c.x - 1) * cell, by + (c.y - 1) * cell
        if classic then
            ctx:rect(cx, cy, cell - gap, cell - gap, ink)
        else
            local t = 1 - (i - 1) / math.max(1, #g.body)
            ctx:rect(cx, cy, cell - gap, cell - gap, { 0.2 + 0.25 * t, 0.55 + 0.4 * t, 0.2 + 0.15 * t })
        end
    end
    -- Eyes on the head when cells are big enough.
    local head = g.body[1]
    if head and cell >= 6 then
        local hx, hy = bx + (head.x - 1) * cell, by + (head.y - 1) * cell
        local eye = classic and LCD_BG or { 0.02, 0.05, 0.02 }
        local e = math.max(1, math.floor(cell / 5))
        ctx:rect(hx + math.floor(cell / 2) - e, hy + math.floor(cell / 3), e, e, eye)
    end
    d.board = { x = bx, y = by, cell = cell }
    if g.food then
        local fx, fy = bx + (g.food.x - 1) * cell, by + (g.food.y - 1) * cell
        if classic then
            local m = math.floor(cell / 2)
            ctx:rect(fx + m - 1, fy, 2, cell - gap, ink)
            ctx:rect(fx, fy + m - 1, cell - gap, 2, ink)
        else
            ctx:rect(fx + 1, fy + 1, cell - 2, cell - 2, { 0.9, 0.2, 0.2 })
            ctx:rect(fx + 1, fy + 1, math.max(1, math.floor(cell / 3)), math.max(1, math.floor(cell / 3)), { 1, 0.7, 0.7 })
        end
    end
    return bx, by, bw, bh, cell
end

KnoxMobile.Apps.register({
    id = "snake", name = "Snake", icon = ICONS .. "snake.png", glyph = ICONS .. "snake_glyph.png",
    label = function() return T("IGUI_KnoxMobile_AppSnake", "Snake") end,
    short = function() return T("IGUI_KnoxMobile_AppShortSnake", "Snake") end,
    families = families(), drain = "games", needsService = false, order = 65,
    onOpen = function(ctx) ctx.data.mode = "title"; ctx.data.best = best(ctx) end,
    render = function(ctx, x, y, w, h)
        local d = ctx.data
        d.mode = d.mode or "title"
        d.best = math.max(d.best or 0, best(ctx))
        -- Off screen for a moment (a call, the lock screen)? The game waits.
        local now = getTimestampMs()
        if d.mode == "play" and App.lastRender and now - App.lastRender > 600 then d.mode, d.keepBack = "paused", false end
        App.lastRender = now
        ctx:wantsDigits(true)
        if ctx.wantsWasd then ctx:wantsWasd(d.mode == "play") end
        block(ctx.player, d.mode == "play")
        advance(ctx)
        local classic = CLASSIC[ctx.family] == true
        local fg = classic and LCD_INK or ctx.style.fg
        local lh = ctx:lineHeight()
        if d.mode == "title" then
            if classic then ctx:rect(x, y, w, h, LCD_BG) end
            local lines = { { text = T("IGUI_KnoxMobile_SnakeTitle", "SNAKE"), big = true } }
            if h > 3 * lh then lines[#lines + 1] = { text = T("IGUI_KnoxMobile_SnakeBest", "Best: %1", d.best) } end
            lines[#lines + 1] = { text = T("IGUI_KnoxMobile_SnakePlay", "Enter: play") }
            if h > 6 * lh then
                local keys = T("IGUI_KnoxMobile_SnakeKeys", "Arrows, WASD or 2 4 6 8 steer. You stand still while you play.")
                for _, l in ipairs(ctx:wrap(keys, w - 8)) do
                    lines[#lines + 1] = { text = l, color = classic and LCD_INK or { 0.7, 0.75, 0.8 } }
                end
            end
            centered(ctx, lines, x, y, w, h, fg)
            return
        end
        local g = d.game
        if not g then d.mode = "title"; return end
        -- Score line.
        if classic then ctx:rect(x, y, w, lh + 2, LCD_BG) end
        ctx:text(T("IGUI_KnoxMobile_SnakeScore", "Score %1", g.score), x + 3, y + 1, fg)
        local right = (w > 120) and T("IGUI_KnoxMobile_SnakeLevelBest", "Lv %1  Best %2", g.level, d.best)
            or T("IGUI_KnoxMobile_SnakeLevel", "Lv %1", g.level)
        ctx:text(right, x + w - 3, y + 1, fg, nil, "right")
        local bx, by, bw, bh = drawBoard(ctx, x, y + lh + 2, w, h - lh - 2)
        if d.mode == "paused" or d.mode == "over" then
            local lines
            if d.mode == "paused" then
                lines = { { text = T("IGUI_KnoxMobile_SnakePaused", "Paused"), big = true },
                    { text = T("IGUI_KnoxMobile_SnakeResume", "Enter: resume") } }
            else
                lines = { { text = T("IGUI_KnoxMobile_SnakeOver", "Game over"), big = true },
                    { text = T("IGUI_KnoxMobile_SnakeFinal", "Score %1", g.score) } }
                if d.newRecord then lines[#lines + 1] = { text = T("IGUI_KnoxMobile_SnakeRecord", "New best!") } end
                lines[#lines + 1] = { text = T("IGUI_KnoxMobile_SnakeAgain", "Enter: play again") }
            end
            local boxH = math.min(bh, (#lines + 1) * lh + 8)
            local boxY = by + math.floor((bh - boxH) / 2)
            ctx:rect(bx, boxY, bw, boxH, classic and LCD_BG or { 0, 0, 0 }, classic and 1 or 0.75)
            if classic then ctx:border(bx, boxY, bw, boxH, LCD_INK) end
            centered(ctx, lines, bx, boxY, bw, boxH, classic and LCD_INK or { 1, 1, 1 })
        end
    end,
    onInput = function(ctx, ev)
        local d = ctx.data
        local mode = d.mode or "title"
        local pressed = (ev.type == "key" and ev.key == "select") or ev.type == "tap"
        if mode == "title" or mode == "over" then
            if pressed then
                local s = ctx.panel.screen
                newGame(ctx, s.w, s.h - (ctx.panel.contentTop or 0))
            end
            return true
        end
        if mode == "paused" then
            if pressed then d.mode, d.last, d.keepBack = "play", getTimestampMs(), true end
            return true
        end
        -- Playing.
        local g = d.game
        if ev.type == "key" then
            if ev.key == "back" or ev.key == "select" or ev.key == "5" then
                d.mode, d.keepBack = "paused", false
                block(ctx.player, false)
            elseif SnakeGame.DIRS[ev.key] then
                SnakeGame.turn(g, ev.key)
            elseif DIGIT_DIRS[ev.key] then
                SnakeGame.turn(g, DIGIT_DIRS[ev.key])
            end
        elseif ev.type == "tap" and g and g.body[1] and d.board then
            -- Touch: tap on the side of the head you want to go.
            local b = d.board
            local hx = b.x + (g.body[1].x - 0.5) * b.cell
            local hy = b.y + (g.body[1].y - 0.5) * b.cell
            local dx, dy = ev.x - hx, ev.y - hy
            if math.abs(dx) > math.abs(dy) then SnakeGame.turn(g, dx > 0 and "right" or "left")
            else SnakeGame.turn(g, dy > 0 and "down" or "up") end
        end
        return true
    end,
    onClose = function(ctx)
        block(ctx.player, false)
        ctx.data.mode = "title"
    end,
})

-- The safety net: if the phone closes or the app changes without onClose (an error), the character can move.
Tick.add("snake movement", function()
    if not App.blocked then return end
    local panel = KnoxMobile.UI and KnoxMobile.UI.panel
    local playing = panel and panel.view == "app" and panel.appId == "snake" and panel.appData and panel.appData.mode == "play"
    if not playing or getTimestampMs() - (App.lastRender or 0) > 600 then block(nil, false) end
end)

Events.OnPlayerDeath.Add(Util.safe("snake death", function() block(nil, false) end))

return App
