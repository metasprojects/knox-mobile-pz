-- Client: the Classifieds app. One server-wide board of short listings (For trade, Wanted, Services, Notices):
-- browse, text or call the poster, post your own (it carries your number), take yours down. Needs service.
-- Small LCDs get a paged text view: one listing at a time, up/down scrolls it, left/right turns the page.
-- Views (ctx.data.view): categories (default), list, post (one listing), actions (small LCDs), newcat.
local Classifieds = require "KnoxMobile/Core/Classifieds"
local Format = require "KnoxMobile/Core/Format"
local Net = require "KnoxMobile/Game/Net"
local Util = require "KnoxMobile/Game/Util"
local SocialText = require "KnoxMobile/Game/SocialText"

local T = Util.text
local ALL = { "SegmentLCD", "MonoLCD", "ColorFeature", "Keyboard", "Stylus", "ModernAndroid", "ModernPear" }
local ICONS = "media/ui/KnoxMobile/apps/"
local SMALL = { SegmentLCD = true, MonoLCD = true }

local function Social() return KnoxMobile.Social end
local function small(ctx) return SMALL[ctx.family] == true end
-- One listing at a time, as pages of text: small LCDs, and any screen too short for a listing and its buttons.
local function paged(ctx) return small(ctx) or ctx.h < 200 end
local function board(ctx) return Social().board[ctx.phone:getID()] end
local function refreshBoard(ctx) Social().request("boardList", ctx.phone) end

local function goTo(d, view, extra)
    d.view, d.sel, d.scroll, d.line = view, 1, 0, 0
    d.keepBack = view ~= nil
    for k, v in pairs(extra or {}) do d[k] = v end
end

local function posts(ctx)
    local b = board(ctx)
    return Classifieds.filter(b and b.posts or {}, ctx.data.cat)
end

local function current(ctx)
    for _, p in ipairs(posts(ctx)) do if p.id == ctx.data.post then return p end end
    return nil
end

-- "Ends in 3 days", "Ends today".
local function ends(ctx, p)
    local b = board(ctx)
    local days = math.floor(((p.expires or 0) - (b and b.now or 0)) / 1440)
    if days < 1 then return T("IGUI_KnoxMobile_BoardEndsToday", "Ends today") end
    return T("IGUI_KnoxMobile_BoardEnds", "Ends in %1 days", days)
end

local function canRemove(ctx, p)
    local b = board(ctx)
    return p.mine or (b and b.moderator)
end

local function actionRows(ctx, p)
    -- Your own listing offers only taking it down (r8: it offered to text and call yourself).
    local rows = {}
    if not p.mine then
        rows[1] = { id = "text", label = T("IGUI_KnoxMobile_BoardText", "Text them") }
        if KnoxMobile.world.voice ~= false then rows[2] = { id = "call", label = T("IGUI_KnoxMobile_BoardCall", "Call them") } end
    end
    if canRemove(ctx, p) then
        local label = ctx.data.confirm and T("IGUI_KnoxMobile_BoardConfirmRemove", "Take it down? Select again")
            or T("IGUI_KnoxMobile_BoardRemove", "Take it down")
        rows[#rows + 1] = { id = "remove", label = label }
    end
    return rows
end

local function act(ctx, p, row)
    if row.id == "text" then
        if p.number == (ctx.state.sim and ctx.state.sim.number) then
            ctx:toast(T("IGUI_KnoxMobile_BoardYours", "That's your own listing"))
            return
        end
        ctx:askText(T("IGUI_KnoxMobile_TypeMessage", "Message:"), "", function(text)
            if text == "" then return end
            Net.toServer(ctx.player, "sendText", { phoneId = ctx.phone:getID(), to = p.number, body = text:sub(1, 320) })
        end, 320)
    elseif row.id == "call" then
        KnoxMobile.Client.placeCall(ctx.phone, p.number)
    elseif row.id == "remove" then
        if ctx.data.confirm then
            Social().request("boardRemove", ctx.phone, { id = p.id })
            goTo(ctx.data, "list")
        else
            ctx.data.confirm = true
        end
    end
end

-- Categories -------------------------------------------------------------------------------------
local function categoryRows(ctx)
    local all = board(ctx) and board(ctx).posts or {}
    local rows = { { id = "post", label = T("IGUI_KnoxMobile_BoardNew", "+ Post a listing") },
        { id = "cat", label = T("IGUI_KnoxMobile_BoardAll", "All (%1)", #all) } }
    for _, c in ipairs(Classifieds.CATEGORIES) do
        rows[#rows + 1] = { id = "cat", cat = c, label = SocialText.category(c) .. " (" .. Classifieds.count(all, c) .. ")" }
    end
    return rows
end

-- One listing as lines of text (the paged view on small LCDs, the top of the listing view elsewhere).
local function postLines(ctx, p, w, index, count)
    local lines = {}
    local head = SocialText.category(p.category)
    if index then head = index .. "/" .. count .. " " .. head end
    lines[#lines + 1] = { head, ctx.style.accent }
    -- Lines are drawn 3 px in, so they wrap a little narrower (r8: "batterie" lost its last letter on the Cinderblock).
    for _, l in ipairs(ctx:wrap(p.title, w - 8)) do lines[#lines + 1] = { l } end
    for _, l in ipairs(ctx:wrap(p.text, w - 8)) do lines[#lines + 1] = { l } end
    lines[#lines + 1] = { p.number, ctx.style.accent }
    lines[#lines + 1] = { ends(ctx, p), ctx.style.accent }
    return lines
end

local function drawLines(ctx, lines, x, y, h, first)
    local lh = ctx:lineHeight()
    local rows = math.max(1, math.floor(h / lh))
    for i = 0, rows - 1 do
        local l = lines[first + i]
        if l then ctx:text(Format.ellipsis(l[1], 40), x + 3, y + i * lh, l[2]) end
    end
    return rows
end

-- Drawing ----------------------------------------------------------------------------------------
local function drawStatus(ctx, text, x, y, w)
    for i, l in ipairs(ctx:wrap(text, w - 8)) do ctx:text(l, x + 4, y + 2 + (i - 1) * ctx:lineHeight()) end
end

local function render(ctx, x, y, w, h)
    local d = ctx.data
    local b = board(ctx)
    if not b then drawStatus(ctx, T("IGUI_KnoxMobile_BoardLoading", "Loading the board..."), x, y, w); return end
    if b.error then drawStatus(ctx, SocialText.reason(b.error), x, y, w); return end
    local lh = ctx:lineHeight()
    if d.view == "newcat" then
        ctx:text(T("IGUI_KnoxMobile_BoardPick", "What kind of listing?"), x + 3, y + 1, ctx.style.accent)
        local rows = {}
        for _, c in ipairs(Classifieds.CATEGORIES) do rows[#rows + 1] = { label = SocialText.category(c) } end
        ctx:list(rows, x, y + lh + 4, w, h - lh - 4)
        return
    end
    if d.view == "list" then
        local list = posts(ctx)
        if paged(ctx) then
            if #list == 0 then drawStatus(ctx, T("IGUI_KnoxMobile_BoardEmpty", "Nothing here yet"), x, y, w); return end
            d.page = math.max(1, math.min(d.page or 1, #list))
            local lines = postLines(ctx, list[d.page], w - 6, d.page, #list)
            local rows = math.max(1, math.floor(h / lh))
            d.line = math.max(0, math.min(d.line or 0, #lines - rows))
            drawLines(ctx, lines, x, y, h, d.line + 1)
            return
        end
        local rows = {}
        for _, p in ipairs(list) do
            rows[#rows + 1] = { label = p.title, sub = p.mine and T("IGUI_KnoxMobile_BoardMine", "(yours)") or nil }
        end
        if #rows == 0 then rows[1] = { label = T("IGUI_KnoxMobile_BoardEmpty", "Nothing here yet") } end
        ctx:list(rows, x, y, w, h)
        return
    end
    if d.view == "post" or d.view == "actions" then
        local p = current(ctx)
        if not p then goTo(d, "list"); return end
        local actions = actionRows(ctx, p)
        if d.view == "actions" then ctx:list(actions, x, y, w, h); return end
        local listH = #actions * (lh + 4)
        local lines = postLines(ctx, p, w - 6)
        drawLines(ctx, lines, x, y, h - listH - 4, 1)
        ctx:rect(x + 2, y + h - listH - 3, w - 4, 1, ctx.style.accent, 0.6)
        ctx:list(actions, x, y + h - listH, w, listH)
        return
    end
    ctx:list(categoryRows(ctx), x, y, w, h)
end

-- Input ------------------------------------------------------------------------------------------
local function newListing(ctx, category)
    ctx:askText(T("IGUI_KnoxMobile_BoardTitle", "Title:"), "", function(title)
        if title == "" then return end
        ctx:askText(T("IGUI_KnoxMobile_BoardTextPrompt", "Listing text:"), "", function(text)
            if text == "" then return end
            Social().request("boardPost", ctx.phone, { category = category, title = title:sub(1, Classifieds.MAX_TITLE),
                text = text:sub(1, Classifieds.MAX_TEXT) })
        end, Classifieds.MAX_TEXT)
    end, Classifieds.MAX_TITLE)
    goTo(ctx.data, nil)
end

local function onInput(ctx, ev)
    local d = ctx.data
    local b = board(ctx)
    local isBack = ev.type == "key" and ev.key == "back"
    if not b or b.error then
        if (ev.type == "key" and ev.key == "select") or ev.type == "tap" then refreshBoard(ctx) end
        return true
    end
    if d.view == "newcat" then
        if isBack then goTo(d, nil); return true end
        local i = ctx:listInput(ev, #Classifieds.CATEGORIES)
        if i then newListing(ctx, Classifieds.CATEGORIES[i]) end
        return true
    end
    if d.view == "list" then
        if isBack then goTo(d, nil); d.cat = nil; return true end
        local list = posts(ctx)
        if paged(ctx) then
            if #list == 0 then return true end
            if ev.type == "key" and ev.key == "up" then d.line = math.max(0, (d.line or 0) - 1)
            elseif ev.type == "key" and ev.key == "down" then d.line = (d.line or 0) + 1
            elseif (ev.type == "key" and (ev.key == "left" or ev.key == "right")) or ev.type == "wheel" then
                local delta = (ev.key == "left" or (ev.type == "wheel" and ev.delta < 0)) and -1 or 1
                d.page, d.line = Classifieds.turn(d.page or 1, #list, delta), 0
            elseif (ev.type == "key" and ev.key == "select") or ev.type == "tap" then
                local p = list[d.page or 1]
                if p then goTo(d, "actions", { post = p.id, confirm = nil }) end
            end
            return true
        end
        local i = ctx:listInput(ev, #list)
        if i and list[i] then goTo(d, "post", { post = list[i].id, confirm = nil }) end
        return true
    end
    if d.view == "post" or d.view == "actions" then
        if isBack then goTo(d, "list", { page = d.page }); return true end
        local p = current(ctx)
        if not p then return true end
        local rows = actionRows(ctx, p)
        local i = ctx:listInput(ev, #rows)
        if i and rows[i] then act(ctx, p, rows[i]) end
        return true
    end
    local rows = categoryRows(ctx)
    local i = ctx:listInput(ev, #rows)
    local row = i and rows[i]
    if not row then return true end
    if row.id == "post" then
        if not (ctx.state.sim and ctx.state.sim.number) then ctx:toast(T("IGUI_KnoxMobile_NoSim", "No SIM card")); return true end
        goTo(d, "newcat")
    else
        goTo(d, "list", { page = 1 })
        d.cat = row.cat
        refreshBoard(ctx)
    end
    return true
end

KnoxMobile.Apps.register({
    id = "classifieds", name = "Classifieds", icon = ICONS .. "classifieds.png", glyph = ICONS .. "classifieds_glyph.png",
    label = function() return T("IGUI_KnoxMobile_AppClassifieds", "Classifieds") end,
    short = function() return T("IGUI_KnoxMobile_AppShortClassifieds", "Ads") end,
    families = ALL, drain = "screen", needsService = true, order = 60,
    onOpen = function(ctx) refreshBoard(ctx) end,
    render = render,
    onInput = onInput,
})
