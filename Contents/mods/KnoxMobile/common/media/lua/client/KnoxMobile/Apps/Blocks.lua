-- Client: Brick Stack (0.3.0; the rules are Core/Blocks, unit tested). On every phone that runs games, beside Snake.
-- Left / right (4 6, A D) move, up (2, W) turns, down (8, S) falls faster, select drops. The character stands still
-- while a game runs (Snake's block); the best score is kept on the phone ("blocksScore").
local Blocks = require "KnoxMobile/Core/Blocks"
local Rng = require "KnoxMobile/Core/Rng"
local Phones = require "KnoxMobile/Game/Phones"
local Net = require "KnoxMobile/Game/Net"
local Util = require "KnoxMobile/Game/Util"
local Traits = require "KnoxMobile/Game/Traits"

local T = Util.text
local ICONS = "media/ui/KnoxMobile/apps/"
local MONO = { SegmentLCD = true, MonoLCD = true }
local LCD_BG, LCD_INK = { 0.62, 0.72, 0.56 }, { 0.08, 0.12, 0.08 }
local COLORS = { { 0.95, 0.8, 0.2 }, { 0.3, 0.8, 0.95 }, { 0.75, 0.4, 0.9 }, { 0.95, 0.55, 0.2 }, { 0.3, 0.45, 0.95 },
    { 0.4, 0.85, 0.4 }, { 0.95, 0.35, 0.35 } }
local KEYS = { left = "left", ["4"] = "left", right = "right", ["6"] = "right", up = "turn", ["2"] = "turn",
    down = "down", ["8"] = "down", select = "drop", ["5"] = "drop" }

local function families()
    local out = {}
    for _, f in ipairs(Phones.registry:families()) do
        if f.features and f.features.games then out[#out + 1] = f.id end
    end
    return out
end

local function block(player, on) if KnoxMobile.SnakeApp then KnoxMobile.SnakeApp.block(player, on) end end

local function best(ctx)
    local games = ctx.state.games
    return type(games) == "table" and tonumber(games.blocks) or 0
end

local function newGame(ctx, w, h)
    local d = ctx.data
    local lh = ctx:lineHeight()
    local cell = math.max(3, math.min(14, math.floor((h - lh - 6) / 18)))
    local cols = math.max(6, math.min(10, math.floor((w - 4) / cell)))
    local rows = math.floor((h - lh - 6) / cell)
    d.rng = Rng.new(tostring(getTimestampMs()) .. ":" .. tostring(ctx.phone:getID()))
    d.game, d.cell = Blocks.new(cols, rows, d.rng), cell
    d.mode, d.last, d.newRecord, d.keepBack = "play", getTimestampMs(), false, true
    d.playingSince = d.last
    block(ctx.player, true)
end

local function finish(ctx)
    local d = ctx.data
    d.mode, d.keepBack = "over", false
    block(ctx.player, false)
    -- A game passes the time (0.3.0; none for a Technophobe).
    if d.playingSince and KnoxMobile.Client then
        KnoxMobile.Client.relieve(Traits.gameRelief(ctx.player, (getTimestampMs() - d.playingSince) / 1000))
        d.playingSince = nil
    end
    local score = d.game and d.game.score or 0
    if score > 0 and score > (d.best or best(ctx)) then
        d.newRecord, d.best = true, score
        Net.toServer(ctx.player, "blocksScore", { phoneId = ctx.phone:getID(), score = score })
    end
end

local function advance(ctx)
    local d = ctx.data
    local g = d.game
    if d.mode ~= "play" or not g then return end
    local now = getTimestampMs()
    if now - d.last > 1500 then d.last = now end
    local steps = 0
    while now - d.last >= Blocks.interval(g) and steps < 3 do
        d.last, steps = d.last + Blocks.interval(g), steps + 1
        if Blocks.step(g, d.rng) == "over" then finish(ctx); return end
    end
end

KnoxMobile.Apps.register({
    id = "blocks", name = "Brick Stack", icon = ICONS .. "blocks.png", glyph = ICONS .. "blocks_glyph.png",
    label = function() return T("IGUI_KnoxMobile_AppBlocks", "Brick Stack") end,
    short = function() return T("IGUI_KnoxMobile_AppShortBlocks", "Bricks") end,
    families = families(), drain = "games", needsService = false, order = 66,
    onOpen = function(ctx) ctx.data.mode = "title"; ctx.data.best = best(ctx) end,
    render = function(ctx, x, y, w, h)
        local d = ctx.data
        local lh = ctx:lineHeight()
        if d.mode == "title" or d.mode == "over" then
            local lines = {}
            if d.mode == "over" then
                lines[#lines + 1] = T("IGUI_KnoxMobile_BlocksOver", "Game over")
                lines[#lines + 1] = T("IGUI_KnoxMobile_BlocksScore", "Score %1", d.game and d.game.score or 0)
                if d.newRecord then lines[#lines + 1] = T("IGUI_KnoxMobile_BlocksRecord", "New best!") end
            else
                lines[#lines + 1] = T("IGUI_KnoxMobile_AppBlocks", "Brick Stack")
                lines[#lines + 1] = T("IGUI_KnoxMobile_BlocksBest", "Best %1", d.best or 0)
            end
            lines[#lines + 1] = T("IGUI_KnoxMobile_BlocksStart", "Select to play")
            local top = y + math.floor((h - #lines * lh) / 2)
            for _, l in ipairs(lines) do ctx:text(l, x + w / 2, top, nil, nil, "center"); top = top + lh end
            return
        end
        advance(ctx)
        local g, cell = d.game, d.cell
        if not g then return end
        local mono = MONO[ctx.family] == true
        local bw, bh = g.cols * cell, g.rows * cell
        local bx, by = x + math.floor((w - bw) / 2), y + lh + 4
        ctx:rect(bx - 1, by - 1, bw + 2, bh + 2, mono and LCD_INK or { 0.6, 0.6, 0.65 }, 1)
        ctx:rect(bx, by, bw, bh, mono and LCD_BG or { 0.05, 0.05, 0.08 }, 1)
        for yy = 1, g.rows do
            for xx = 1, g.cols do
                local k = Blocks.cellAt(g, xx, yy)
                if k then
                    ctx:rect(bx + (xx - 1) * cell, by + (yy - 1) * cell, cell - 1, cell - 1, mono and LCD_INK or COLORS[k], 1)
                end
            end
        end
        ctx:text(T("IGUI_KnoxMobile_BlocksScore", "Score %1", g.score), x + 3, y + 1)
    end,
    onInput = function(ctx, ev)
        local d = ctx.data
        if ev.type ~= "key" then return true end
        if d.mode ~= "play" then
            if ev.key == "select" or ev.key == "5" then newGame(ctx, ctx.w or 120, ctx.h or 160) end
            return true
        end
        local act, g = KEYS[ev.key], d.game
        if ev.key == "back" then finish(ctx); return true end
        if act == "left" then Blocks.move(g, -1)
        elseif act == "right" then Blocks.move(g, 1)
        elseif act == "turn" then Blocks.rotate(g)
        elseif act == "down" then if Blocks.step(g, d.rng) == "over" then finish(ctx) end
        elseif act == "drop" then if Blocks.drop(g, d.rng) == "over" then finish(ctx) end end
        return true
    end,
    onClose = function(ctx) block(ctx.player, false); ctx.data.mode = "title" end,
})
