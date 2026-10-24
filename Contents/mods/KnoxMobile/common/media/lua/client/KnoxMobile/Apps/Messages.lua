-- Client: the Messages app (spec §8.6): threads with people, group chats, carrier messages, and a dead owner's
-- old group chats. Groups: start one from your contacts, add people, take them out (the owner), leave. Faction and
-- safehouse groups appear by themselves and follow the game. Small LCDs label group threads "Grp:Name".
-- Views (ctx.data.view): list (default), thread, info (a group's people), pick (choosing people for a new group).
local Sim = require "KnoxMobile/Core/Sim"
local Groups = require "KnoxMobile/Core/Groups"
local Net = require "KnoxMobile/Game/Net"
local Util = require "KnoxMobile/Game/Util"
local SocialText = require "KnoxMobile/Game/SocialText"
local CameraSpec = require "KnoxMobile/Core/CameraSpec"
local Format = require "KnoxMobile/Core/Format"
local Mod = require "KnoxMobile/Core/Mod"
local Replies = require "KnoxMobile/Core/Replies"

local T = Util.text
local ALL = { "SegmentLCD", "MonoLCD", "ColorFeature", "Keyboard", "Stylus", "ModernAndroid", "ModernPear" }
local ICONS = "media/ui/KnoxMobile/apps/"
local SMALL = { SegmentLCD = true, MonoLCD = true }

local function Social() return KnoxMobile.Social end
local function small(ctx) return SMALL[ctx.family] == true end

-- Cut to the pixel width, with "..." when it doesn't fit.
local function fit(ctx, s, width)
    if ctx:measure(s) <= width then return s end
    while #s > 1 and ctx:measure(s .. "...") > width do s = s:sub(1, #s - 1) end
    return s .. "..."
end

-- Threads ----------------------------------------------------------------------------------------
-- Every thread on this phone: its texts (people, groups, the carrier) and a dead owner's old group chats.
-- When a message was stamped (day * 1440 + clock minute), for ordering.
local function stampOf(m) return m and ((m.day or 0) * 1440 + (m.minute or 0)) or -1e9 end
local function lastStamp(conv)
    local list = conv.messages or {}
    return stampOf(list[#list])
end

-- The conversations, the one with the newest message first (r8: the list kept the order they were made in).
local function threads(ctx)
    local out = {}
    for _, c in ipairs(ctx.state.contents.texts or {}) do out[#out + 1] = { conv = c, key = c.with } end
    for i, g in ipairs(ctx.state.contents.groupChats or {}) do out[#out + 1] = { conv = g, key = "story:" .. i, story = true } end
    for i, t in ipairs(out) do t.order = i end
    table.sort(out, function(a, b)
        local sa, sb = lastStamp(a.conv), lastStamp(b.conv)
        if sa ~= sb then return sa > sb end
        return a.order < b.order
    end)
    return out
end

-- A message's time as a thread shows it: the clock today, "Yesterday" and the clock, else how many days ago.
local function stampText(m)
    local today = math.floor((math.floor(Util.nowMinutes()) + Util.clockMinute(0)) / 1440)
    local mi = math.floor(m.minute or 0)
    local clock = Format.clock(math.floor(mi / 60), Mod.floor(mi, 60), KnoxMobile.Options.clock24())
    local ago = today - (m.day or today)
    if ago <= 0 then return clock end
    if ago == 1 then return T("IGUI_KnoxMobile_Yesterday", "Yesterday %1", clock) end
    return T("IGUI_KnoxMobile_DaysAgo", "%1 days ago, %2", ago, clock)
end

local function findThread(ctx, key)
    for _, t in ipairs(threads(ctx)) do if t.key == key then return t end end
    return nil
end

local function isGroup(t) return t.story or t.conv.group ~= nil end

local function unreadCount(conv)
    local n = 0
    for _, m in ipairs(conv.messages or {}) do if m.unread then n = n + 1 end end
    return n
end

local function title(ctx, t)
    if t.conv.carrier then return SocialText.carrier() end
    local name = t.conv.name or t.conv.with or "?"
    if isGroup(t) then return SocialText.groupHeader(name, small(ctx)) end
    return name
end

-- The group behind a thread as the server last described it, while this phone is still in it.
local function liveGroup(ctx, t)
    if not (t and t.conv.group) then return nil end
    return Social().group(ctx.phone:getID(), t.conv.group)
end

-- A found phone's own people (Core/Replies, server TextBack): its dead owner's family, friend, work or squad mate.
local function storyThread(ctx, t)
    return not t.story and ctx.state.owner ~= nil and ctx.state.owner.kind == "generated" and Replies.ROLES[t.conv.with] == true
end

local function canReply(ctx, t)
    if not ctx.state.sim then return false end
    if t.conv.group then return liveGroup(ctx, t) ~= nil end
    if storyThread(ctx, t) then return true end
    return not t.story and not t.conv.carrier and Sim.normalise(t.conv.with) ~= nil
end

local function lineText(ctx, t, m)
    if m.event then
        local who = Social().nameFor(ctx.state, m.from)
        return "* " .. SocialText.event(m.event, who, t.conv.name) .. " *", true
    end
    local body = CameraSpec.shown(m.body or "")
    -- Short screens get the one-line SOS; the thread's header already says "SOS: name".
    if m.sos then body = (small(ctx) or ctx.h < 120) and SocialText.sosShort(m.sos) or SocialText.sos(m.sos) end
    if m.page then body = T("IGUI_KnoxMobile_PageLine", "Page: %1", body) end
    if not m.inbound then return "> " .. body, true end
    if isGroup(t) then
        local who = t.story and (m.from or "?") or Social().nameFor(ctx.state, m.from)
        return who .. ": " .. body, false
    end
    return body, false
end

-- Sending ----------------------------------------------------------------------------------------
local function sendText(ctx, to, body)
    if not body or body == "" then return end
    Net.toServer(ctx.player, "sendText", { phoneId = ctx.phone:getID(), to = to, body = body:sub(1, 320) })
end

local function sendGroup(ctx, groupId, body)
    if not body or body == "" then return end
    Social().request("groupText", ctx.phone, { group = groupId, body = body:sub(1, 320) })
end

-- A number, or a contact's name.
local function askNumber(ctx, prompt, onNumber)
    ctx:askText(prompt, "", function(text)
        local number = Sim.normalise(text)
        if not number and ctx.state.sim then
            for _, c in ipairs(ctx.state.sim.contacts) do
                if c.name:lower() == text:lower() then number = c.number end
            end
        end
        if number then onNumber(number) else ctx:toast(T("IGUI_KnoxMobile_BadNumber", "That isn't a phone number")) end
    end, 20)
end

-- Reading a dead person's messages adds unhappiness once per conversation, unless desensitized (spec §9.6).
local function readDeadThread(ctx, t)
    if not (ctx.state.owner and ctx.state.owner.kind == "generated") then return end
    local md = ctx.player:getModData()
    if type(md.KnoxMobileReadDead) ~= "table" then md.KnoxMobileReadDead = {} end
    local key = tostring(ctx.phone:getID()) .. ":" .. tostring(t.key)
    if md.KnoxMobileReadDead[key] then return end
    md.KnoxMobileReadDead[key] = true
    local ok, hardened = pcall(function() return ctx.player:hasTrait(CharacterTrait.DESENSITIZED) end)
    if not (ok and hardened) then KnoxMobile.Client.mood("UNHAPPINESS", 4) end
end

local function goTo(d, view, extra)
    d.view, d.sel, d.scroll, d.confirm = view, 1, 0, nil
    d.keepBack = view ~= nil
    for k, v in pairs(extra or {}) do d[k] = v end
end

-- List -------------------------------------------------------------------------------------------
local function listRows(ctx)
    local rows = { { id = "new", label = T("IGUI_KnoxMobile_NewMessage", "+ New message"),
        short = T("IGUI_KnoxMobile_NewMessageShort", "+ New") } }
    if ctx.state.sim then rows[#rows + 1] = { id = "group", label = T("IGUI_KnoxMobile_NewGroup", "+ New group") } end
    if ctx.state.sim then rows[#rows + 1] = { id = "page", label = T("IGUI_KnoxMobile_SendPage", "+ Send page") } end
    local list = threads(ctx)
    for _, t in ipairs(list) do
        local n = unreadCount(t.conv)
        local label = title(ctx, t) .. (n > 0 and (" (" .. n .. ")") or "")
        rows[#rows + 1] = { id = "thread", key = t.key, label = label }
    end
    if #list == 0 then rows[#rows + 1] = { id = "none", label = T("IGUI_KnoxMobile_NoMessages", "No messages") } end
    return rows
end

local function openThread(ctx, t)
    local d = ctx.data
    goTo(d, "thread", { thread = t.key, back = 0 })
    if unreadCount(t.conv) > 0 then ctx:setting("markRead", true) end
    readDeadThread(ctx, t)
end

-- Thread -----------------------------------------------------------------------------------------
local function drawThread(ctx, t, x, y, w, h)
    local d = ctx.data
    local lh = ctx:lineHeight()
    local head = title(ctx, t)
    local g = liveGroup(ctx, t)
    local newest = (t.conv.messages or {})[#(t.conv.messages or {})]
    if g and not small(ctx) then head = head .. "  " .. T("IGUI_KnoxMobile_GroupCount", "(%1)", #g.members)
    elseif newest and newest.sos and newest.inbound then head = T("IGUI_KnoxMobile_SosHeader", "SOS: %1", head) end
    ctx:rect(x, y, w, lh + 3, ctx.style.accent, 0.25)
    ctx:text(fit(ctx, head, w - 6), x + 3, y + 1, ctx.style.accent)
    -- Small LCDs skip the hint line: every row counts there.
    local bottom = small(ctx) and (y + h) or (y + h - lh - 4)
    -- Newest at the bottom, wrapped; scroll with up and down.
    -- On bigger screens a time line goes before a message that comes 30 minutes or more after the one before it,
    -- and messages have a little space between them (r8: no times, no gaps).
    local lines = {}
    local prev
    for _, m in ipairs(t.conv.messages or {}) do
        if not small(ctx) then
            if m.day and (not prev or stampOf(m) - stampOf(prev) >= 30) then
                lines[#lines + 1] = { text = stampText(m), time = true }
            elseif prev then
                lines[#lines + 1] = { text = "", gap = true }
            end
        end
        local text, accent = lineText(ctx, t, m)
        for _, l in ipairs(ctx:wrap(text, w - 14)) do lines[#lines + 1] = { text = l, accent = accent, out = not m.inbound } end
        prev = m
    end
    local top = y + lh + 6
    local rows = math.max(1, math.floor((bottom - top) / lh))
    d.back = math.max(0, math.min(d.back or 0, #lines - rows))
    local first = math.max(1, #lines - rows - d.back + 1)
    for i = 0, rows - 1 do
        local l = lines[first + i]
        if l and l.time then
            ctx:text(fit(ctx, l.text, w - 6), x + w / 2, top + i * lh, ctx.style.accent, nil, "center")
        elseif l then
            -- Incoming lines a little in from the edge too (final test: they touched it).
            ctx:text(l.text, x + (l.out and 10 or 5), top + i * lh, l.accent and ctx.style.accent or nil)
        end
    end
    if small(ctx) then return end
    local hint
    if g then
        hint = T("IGUI_KnoxMobile_GroupHint", "Enter: reply   Right: people")
        if ctx:measure(hint) > w - 6 then hint = T("IGUI_KnoxMobile_GroupHintShort", "Enter: reply  >: people") end
        if ctx:measure(hint) > w - 6 then hint = T("IGUI_KnoxMobile_Reply", "Enter: reply") end
    elseif canReply(ctx, t) and storyThread(ctx, t) then
        hint = T("IGUI_KnoxMobile_Reply", "Enter: reply")
    elseif storyThread(ctx, t) then
        hint = T("IGUI_KnoxMobile_TextBackSim", "Put a SIM in to text back")
    elseif canReply(ctx, t) then
        hint = T("IGUI_KnoxMobile_ReplyCall", "Enter: reply   Right: call")
        if ctx:measure(hint) > w - 6 then hint = T("IGUI_KnoxMobile_ReplyCallShort", "Enter: reply  >: call") end
        if ctx:measure(hint) > w - 6 then hint = T("IGUI_KnoxMobile_Reply", "Enter: reply") end
    else
        hint = T("IGUI_KnoxMobile_ReadOnly", "Read only")
    end
    ctx:text(fit(ctx, hint, w - 6), x + 3, bottom + 2, ctx.style.accent)
end

local function threadInput(ctx, t, ev)
    local d = ctx.data
    if ev.type == "key" and ev.key == "back" then goTo(d, nil); return end
    if ev.type == "key" and ev.key == "up" then d.back = (d.back or 0) + 1; return end
    if ev.type == "key" and ev.key == "down" then d.back = math.max(0, (d.back or 0) - 1); return end
    if ev.type == "wheel" then d.back = math.max(0, (d.back or 0) + (ev.delta < 0 and 1 or -1)); return end
    local g = liveGroup(ctx, t)
    local onHeader = ev.type == "tap" and ev.y <= ctx:lineHeight() + 3
    if g and ((ev.type == "key" and ev.key == "right") or onHeader) then goTo(d, "info", { thread = t.key }); return end
    -- A person's thread: Right (or a tap on their name) calls them back.
    if not g and canReply(ctx, t) and not storyThread(ctx, t) and t.conv and t.conv.with
        and ((ev.type == "key" and ev.key == "right") or onHeader) then
        if KnoxMobile.Client then KnoxMobile.Client.placeCall(ctx.phone, t.conv.with) end
        return
    end
    if (ev.type == "key" and ev.key == "select") or ev.type == "tap" then
        if not canReply(ctx, t) then return end
        ctx:askText(T("IGUI_KnoxMobile_TypeMessage", "Message:"), "", function(text)
            if g then
                sendGroup(ctx, g.id, text)
            elseif storyThread(ctx, t) then
                if text and text ~= "" then
                    Net.toServer(ctx.player, "textBack", { phoneId = ctx.phone:getID(), with = t.conv.with, body = text:sub(1, 320) })
                end
            else
                sendText(ctx, t.conv.with, text)
            end
        end, 320)
    end
end

-- A group's people -------------------------------------------------------------------------------
local function infoRows(ctx, g)
    local d = ctx.data
    local rows = {}
    if g.auto then
        rows[#rows + 1] = { id = "kind", label = g.auto == "faction" and T("IGUI_KnoxMobile_GroupFaction", "Your faction")
            or T("IGUI_KnoxMobile_GroupSafehouse", "Your safehouse") }
    else
        rows[#rows + 1] = { id = "add", label = T("IGUI_KnoxMobile_GroupAdd", "+ Add someone") }
    end
    for _, n in ipairs(g.members or {}) do
        local name = Social().nameFor(ctx.state, n)
        local label = name
        if d.confirm == n then label = T("IGUI_KnoxMobile_GroupConfirmRemove", "Take out %1? Select again", name)
        elseif n == g.owner then label = name .. " " .. T("IGUI_KnoxMobile_GroupOwnerTag", "(owner)") end
        rows[#rows + 1] = { id = "member", number = n, label = label }
    end
    if not g.auto then
        rows[#rows + 1] = { id = "leave", label = d.confirm == "leave" and T("IGUI_KnoxMobile_GroupConfirmLeave", "Leave? Select again")
            or T("IGUI_KnoxMobile_GroupLeaveRow", "Leave the group") }
    end
    return rows
end

local function drawInfo(ctx, g, x, y, w, h)
    local lh = ctx:lineHeight()
    ctx:rect(x, y, w, lh + 3, ctx.style.accent, 0.25)
    ctx:text(fit(ctx, SocialText.groupHeader(g.name, small(ctx)), w - 6), x + 3, y + 1, ctx.style.accent)
    ctx:list(infoRows(ctx, g), x, y + lh + 5, w, h - lh - 5)
end

local function infoInput(ctx, t, g, ev)
    local d = ctx.data
    if ev.type == "key" and (ev.key == "back" or ev.key == "left") then goTo(d, "thread", { thread = t.key }); return end
    local rows = infoRows(ctx, g)
    local row = rows[ctx:listInput(ev, #rows) or 0]
    if not row then return end
    local mine = ctx.state.sim and ctx.state.sim.number
    if row.id == "add" then
        askNumber(ctx, T("IGUI_KnoxMobile_GroupAddPrompt", "Add (number or contact):"), function(number)
            Social().request("groupAdd", ctx.phone, { group = g.id, number = number })
        end)
    elseif row.id == "member" and not g.auto and g.owner == mine and row.number ~= mine then
        if d.confirm == row.number then
            Social().request("groupRemove", ctx.phone, { group = g.id, number = row.number })
            d.confirm = nil
        else
            d.confirm = row.number
        end
    elseif row.id == "leave" then
        if d.confirm == "leave" then
            Social().request("groupLeave", ctx.phone, { group = g.id })
            goTo(d, nil)
        else
            d.confirm = "leave"
        end
    end
end

-- Choosing people for a new group ---------------------------------------------------------------
local function pickRows(ctx)
    local d = ctx.data
    d.picked = d.picked or {}
    local chosen = 0
    for _ in pairs(d.picked) do chosen = chosen + 1 end
    local rows = { { id = "done", label = T("IGUI_KnoxMobile_GroupDone", "Done (%1)", chosen) } }
    local listed = {}
    for _, c in ipairs(ctx.state.sim and ctx.state.sim.contacts or {}) do
        listed[c.number] = true
        rows[#rows + 1] = { id = "contact", number = c.number, label = (d.picked[c.number] and "[x] " or "[ ] ") .. c.name }
    end
    for number in pairs(d.picked) do
        if not listed[number] then rows[#rows + 1] = { id = "contact", number = number, label = "[x] " .. number } end
    end
    rows[#rows + 1] = { id = "typed", label = T("IGUI_KnoxMobile_GroupTypeNumber", "+ Type a number") }
    return rows, chosen
end

local function pickInput(ctx, ev)
    local d = ctx.data
    if ev.type == "key" and ev.key == "back" then goTo(d, nil); return end
    local rows, chosen = pickRows(ctx)
    local row = rows[ctx:listInput(ev, #rows) or 0]
    if not row then return end
    if row.id == "contact" then
        d.picked[row.number] = (not d.picked[row.number]) or nil
    elseif row.id == "typed" then
        askNumber(ctx, T("IGUI_KnoxMobile_Number", "Number:"), function(number)
            if number ~= (ctx.state.sim and ctx.state.sim.number) then d.picked[number] = true end
        end)
    elseif row.id == "done" then
        if chosen == 0 then ctx:toast(SocialText.reason("tooFew")); return end
        if chosen + 1 > Groups.MAX_MEMBERS then ctx:toast(SocialText.reason("tooMany")); return end
        ctx:askText(T("IGUI_KnoxMobile_GroupName", "Group name:"), "", function(text)
            local name = Groups.cleanName(text)
            if not name then ctx:toast(SocialText.reason("badName")); return end
            local members = {}
            for number in pairs(d.picked) do members[#members + 1] = number end
            table.sort(members)
            Social().request("groupCreate", ctx.phone, { name = name, members = members })
            goTo(d, nil, { picked = {} })
        end, Groups.MAX_NAME)
    end
end

-- The app ----------------------------------------------------------------------------------------
KnoxMobile.Apps.register({
    id = "messages", name = "Messages", icon = ICONS .. "messages.png", glyph = ICONS .. "messages_glyph.png",
    label = function() return T("IGUI_KnoxMobile_AppMessages", "Messages") end,
    short = function() return T("IGUI_KnoxMobile_AppShortMessages", "Texts") end,
    families = ALL, drain = "screen", needsService = false, order = 10,
    onOpen = function(ctx)
        if ctx.state.sim and ctx.state.sim.number and ctx.state.power.on then Social().request("groupList", ctx.phone) end
    end,
    render = function(ctx, x, y, w, h)
        local d = ctx.data
        local t = d.thread and findThread(ctx, d.thread)
        if d.view == "thread" or d.view == "info" then
            if not t then goTo(d, nil); return end
            local g = d.view == "info" and liveGroup(ctx, t)
            if g then drawInfo(ctx, g, x, y, w, h) else drawThread(ctx, t, x, y, w, h) end
            return
        end
        if d.view == "pick" then
            local lh = ctx:lineHeight()
            ctx:text(fit(ctx, T("IGUI_KnoxMobile_GroupPick", "Who's in the group?"), w - 6), x + 3, y + 1, ctx.style.accent)
            ctx:list((pickRows(ctx)), x, y + lh + 4, w, h - lh - 4)
            return
        end
        ctx:list(listRows(ctx), x, y, w, h)
    end,
    onInput = function(ctx, ev)
        local d = ctx.data
        local t = d.thread and findThread(ctx, d.thread)
        if d.view == "thread" and t then threadInput(ctx, t, ev); return true end
        if d.view == "info" and t then
            local g = liveGroup(ctx, t)
            if g then infoInput(ctx, t, g, ev) else goTo(d, "thread", { thread = t.key }) end
            return true
        end
        if d.view == "pick" then pickInput(ctx, ev); return true end
        if d.view then goTo(d, nil); return true end
        local rows = listRows(ctx)
        local row = rows[ctx:listInput(ev, #rows) or 0]
        if not row then return true end
        if row.id == "new" then
            if not ctx.state.sim then ctx:toast(T("IGUI_KnoxMobile_NoSim", "No SIM card")); return true end
            askNumber(ctx, T("IGUI_KnoxMobile_To", "To (number or contact):"), function(number)
                ctx:askText(T("IGUI_KnoxMobile_TypeMessage", "Message:"), "", function(text) sendText(ctx, number, text) end, 320)
            end)
        elseif row.id == "group" then
            goTo(d, "pick", { picked = {} })
        elseif row.id == "page" then
            -- A numeric page: your callback number is filled in; add a code (911 urgent, 411 news) after it.
            askNumber(ctx, T("IGUI_KnoxMobile_PagerNumber", "Pager number:"), function(number)
                local own = (ctx.state.sim.number or ""):gsub("%D", ""):sub(4)
                ctx:askText(T("IGUI_KnoxMobile_PageDigits", "Page (number and code):"), own .. " ", function(text)
                    if not text or text == "" then return end
                    Net.toServer(ctx.player, "sendText", { phoneId = ctx.phone:getID(), to = number, body = text:sub(1, 20), page = true })
                end, 20)
            end)
        elseif row.id == "thread" then
            local chosen = findThread(ctx, row.key)
            if chosen then openThread(ctx, chosen) end
        end
        return true
    end,
})

return { threads = threads, isGroup = isGroup }
