-- Stories on phones (spec §5): template grammar, identities, dead people's phones, the player's family
-- storyline and survivor texts. Pure Lua 5.1; everything comes from a seeded Rng, so the same seed always
-- tells the same story. Times are { day, minute } with day 0 = the day the game starts.

local Mod = require "KnoxMobile/Core/Mod"
local Names = require "KnoxMobile/Story/Names"
local Jobs = require "KnoxMobile/Story/Jobs"
local Templates = require "KnoxMobile/Story/Templates"
local Places = require "KnoxMobile/Story/Places"
local Photos = require "KnoxMobile/Core/Photos"

local Story = {}

local DAY = 1440

-- What each screen family can hold (spec §5.1 "era-appropriate depth").
local DEPTH = {
    SegmentLCD = { texts = false, notes = false, group = false },
    MonoLCD = { texts = true, notes = false, group = false },
    ColorFeature = { texts = true, notes = true, group = false },
    Keyboard = { texts = true, notes = true, group = false },
    Stylus = { texts = true, notes = true, group = false },
    ModernAndroid = { texts = true, notes = true, group = true },
    ModernPear = { texts = true, notes = true, group = true },
}

-- The outbreak, day by day (relative to game start, July 9 1993). Each phase adds a few messages. The Knox Event
-- timeline: news on July 4-5, the roads sealed on July 6 at 06:00, the zone's phone lines down on July 7-8.
local PHASES = {
    { key = "normal", from = -9, to = -6, min = 3, max = 5 },  -- June 30 - July 3
    { key = "news", from = -5, to = -4, min = 2, max = 4 },    -- July 4 - 5
    { key = "closure", from = -3, to = 0, min = 2, max = 3 },  -- July 6 - 9
}
Story.PHASES = PHASES

local FATES = {
    Mild = { { "rescued", 50 }, { "goodbye", 30 }, { "silence", 10 }, { "dies", 10 } },
    Standard = { { "rescued", 20 }, { "goodbye", 25 }, { "silence", 20 }, { "dies", 35 } },
    Grim = { { "rescued", 5 }, { "goodbye", 15 }, { "silence", 20 }, { "dies", 60 } },
}

local HINT_WORDS = { "key", "cabin", "lake house", "water at" }

-- Template grammar ------------------------------------------------------------------------------

-- Fills a template: each [a|b|c] picks one option (left to right), then each {slot} takes ctx[slot].
-- Unknown slots stay visible, e.g. {place} for the game to fill with a real building.
function Story.fill(rng, template, ctx)
    local text = template
    for _ = 1, 50 do
        local s, e, body = text:find("%[([^%[%]]*)%]")
        if not s then break end
        local options = {}
        for opt in (body .. "|"):gmatch("([^|]*)|") do options[#options + 1] = opt end
        text = text:sub(1, s - 1) .. rng:pick(options) .. text:sub(e + 1)
    end
    text = text:gsub("{(%w+)}", function(key)
        local v = ctx and ctx[key]
        if v == nil then return "{" .. key .. "}" end
        return tostring(v)
    end)
    return text
end

function Story.pin(rng)
    return string.format("%04d", rng:int(0, 9999))
end

-- Template entries (Story/Templates.lua) are plain strings or tables with a body and conditions.
local function bodyOf(entry) return type(entry) == "table" and entry.body or entry end
Story.bodyOf = bodyOf

-- Does a template's `jobs` group (Story/Jobs.lua groups) include this person's job?
function Story.fitsJob(entry, id)
    local group = type(entry) == "table" and entry.jobs
    if not group then return true end
    for _, key in ipairs(Jobs.groups[group] or {}) do if key == id.job.key then return true end end
    return false
end

-- Identities ------------------------------------------------------------------------------------

local function firstName(rng, female)
    return rng:pick(female and Names.female or Names.male)
end

-- opts: { name = "First Last" from the zombie's ID card, female, outfit = vanilla outfit name }
function Story.identity(rng, opts)
    opts = opts or {}
    local female = opts.female
    if female == nil then female = rng:chance(0.5) end
    local first, last
    if opts.name then first, last = opts.name:match("^(%S+)%s+(.+)$") end
    if not first then
        first = opts.name or firstName(rng, female)
        last = rng:pick(Names.surnames)
    end

    local jobKey = (opts.outfit and Jobs.byOutfit[opts.outfit]) or rng:pick(Jobs.civilian)
    local def = Jobs.list[jobKey]
    local job = { key = jobKey, title = def.title, place = def.place, group = def.group }
    if def.contact then
        job.contact = Story.fill(rng, def.contact, { firstA = firstName(rng, rng:chance(0.5)), surnameA = rng:pick(Names.surnames) })
    end

    -- Never your own name, or one that is a short form of it or the other way round (second pass: Scott texting
    -- Scotty Qualls).
    local mine = tostring(first):lower()
    local function clash(name)
        local n = tostring(name):lower()
        return n == mine or mine:sub(1, #n) == n or n:sub(1, #mine) == mine
    end
    local function relative(isFemale, surname)
        local name = firstName(rng, isFemale)
        local tries = 0
        while clash(name) and tries < 20 do name = firstName(rng, isFemale); tries = tries + 1 end
        return name, name .. " " .. surname
    end
    local momFirst = firstName(rng, true)
    local dadFirst = firstName(rng, false)
    local sibLabel, sibName = relative(rng:chance(0.5), last)
    local partnerLabel, partnerName = relative(not female, rng:pick(Names.surnames))
    local friendLabel, friendName = relative(rng:chance(0.5), rng:pick(Names.surnames))

    return {
        first = first, last = last, female = female,
        ageBand = rng:weighted({ { "18-25", 3 }, { "26-35", 3 }, { "36-50", 3 }, { "51-65", 2 } }),
        job = job,
        family = {
            mom = { label = rng:pick(Names.mom), name = momFirst .. " " .. last },
            dad = { label = rng:pick(Names.dad), name = dadFirst .. " " .. last },
            sib = { label = sibLabel, name = sibName },
            partner = { label = partnerLabel, name = partnerName },
        },
        friend = { label = friendLabel, name = friendName },
        hometown = rng:pick(Names.towns),
        pin = Story.pin(rng),
    }
end

-- Slot values for templates about this person.
function Story.context(id)
    return {
        first = id.first, last = id.last,
        mom = id.family.mom.label, dad = id.family.dad.label, sib = id.family.sib.label,
        partner = id.family.partner.label, friend = id.friend.label,
        work = id.job.contact or "Work", jobPlace = id.job.place, jobTitle = id.job.title,
        town = id.hometown, hometown = id.hometown,
    }
end

-- Dead people's phones --------------------------------------------------------------------------

local function senderLabel(id, key)
    if key == "work" then return id.job.contact end
    if key == "friend" then return id.friend.label end
    local member = id.family[key]
    return member and member.label
end

local function at(day, minute) return day * DAY + minute end

local function sortByTime(list)
    table.sort(list, function(a, b)
        local ta, tb = at(a.day, a.minute), at(b.day, b.minute)
        if ta == tb then return (a.seq or 0) < (b.seq or 0) end
        return ta < tb
    end)
end

-- opts: { family = screen family id, deathDay = day they died (may be before day 0),
--         foundAt = day * 1440 + clock minute the phone is found (optional): nothing in the story is later (r7) }
-- Returns { texts = { { with, name, messages } }, calls, voicemails, notes, groupChats, draft, lastApp, alarm,
--           photos, deathDay, deathMinute }.
function Story.deadPhone(rng, id, opts)
    local depth = DEPTH[opts.family] or DEPTH.MonoLCD
    local deathDay = opts.deathDay or 0
    local deathMinute = rng:int(8 * 60, 22 * 60)
    local deathAt = at(deathDay, deathMinute)
    -- They died at least an hour before the phone was found.
    local foundAt = opts.foundAt
    if foundAt and deathAt > foundAt - 60 then
        deathAt = foundAt - 60 - rng:int(0, 180)
        deathDay, deathMinute = math.floor(deathAt / DAY), Mod.floor(deathAt, DAY)
    end
    -- A time after the death, folded back before the moment the phone was found; nil when there is no room.
    local function afterDeath(when)
        if not foundAt or when < foundAt then return when end
        local span = foundAt - 1 - deathAt
        if span < 1 then return nil end
        return deathAt + 1 + Mod.floor(when - deathAt, span)
    end
    local ctx = Story.context(id)
    local events, seq = {}, 0

    local function add(day, minute, from, body, inbound, unread)
        seq = seq + 1
        events[#events + 1] = { day = day, minute = minute, from = from, body = body, inbound = inbound, unread = unread, seq = seq }
    end

    -- A template is used at most once per phone; nil when none is left that fits this person (their contacts and job).
    local used = {}
    local function pickTemplate(list)
        for _ = 1, 12 do
            local t = rng:pick(list)
            if not used[t] and Story.fitsJob(t, id) and (t.from == nil or t.from == "self" or senderLabel(id, t.from)) then
                used[t] = true
                return t
            end
        end
        return nil
    end

    for _, phase in ipairs(PHASES) do
        for _ = 1, rng:int(phase.min, phase.max) do
            local t = pickTemplate(Templates.deadPhone[phase.key])
            local day, minute = rng:int(phase.from, phase.to), rng:int(7 * 60, 23 * 60)
            if t and at(day, minute) < deathAt then
                add(day, minute, t.from, Story.fill(rng, t.body, ctx), t.from ~= "self", false)
            end
        end
    end
    -- Using it right before they died.
    for i = 1, rng:int(1, 2) do
        local t = pickTemplate(Templates.deadPhone.lastDay)
        if t then
            local minute = math.max(0, deathMinute - rng:int(5, 240) + i)
            add(deathDay, math.min(minute, deathMinute - 1), t.from, Story.fill(rng, t.body, ctx), t.from ~= "self", false)
        end
    end
    -- Missed messages after death; the first lands the next day.
    for i = 1, rng:int(2, 4) do
        local t = pickTemplate(Templates.deadPhone.afterDeath)
        if t then
            local when
            if i == 1 then when = at(deathDay + 1, rng:int(6 * 60, 20 * 60)) else when = deathAt + rng:int(30, 2 * DAY) end
            local body = Story.fill(rng, t.body, ctx)
            when = afterDeath(when)
            if when then add(math.floor(when / DAY), Mod.floor(when, DAY), t.from, body, true, true) end
        end
    end
    sortByTime(events)

    local content = {
        texts = {}, calls = {}, voicemails = {}, notes = {}, groupChats = {},
        deathDay = deathDay, deathMinute = deathMinute,
    }

    -- Calls: every phone has a call log. Calls after death are missed.
    for _, ev in ipairs(events) do
        if ev.from ~= "self" and rng:chance(ev.unread and 0.8 or 0.3) then
            content.calls[#content.calls + 1] = {
                with = ev.from, name = senderLabel(id, ev.from), day = ev.day, minute = ev.minute,
                inbound = true, missed = ev.unread or rng:chance(0.3),
            }
        end
    end
    if #content.calls == 0 then
        local after = afterDeath(deathAt + rng:int(60, DAY)) or deathAt
        content.calls[1] = {
            with = "mom", name = ctx.mom, day = math.floor(after / DAY), minute = Mod.floor(after, DAY), inbound = true, missed = true,
        }
    end
    for _ = 1, rng:int(1, 3) do
        local t = pickTemplate(Templates.deadPhone.voicemails)
        if t then
            local when = afterDeath(deathAt + rng:int(30, 2 * DAY))
            local body = Story.fill(rng, t.body, ctx)
            if when then
                content.voicemails[#content.voicemails + 1] = {
                    from = t.from, name = senderLabel(id, t.from), body = body,
                    day = math.floor(when / DAY), minute = Mod.floor(when, DAY),
                }
            end
        end
    end
    sortByTime(content.voicemails)

    if depth.texts then
        local partners = { "partner", "mom", "friend" }
        local byWith, order = {}, {}
        for _, ev in ipairs(events) do
            local with = ev.from
            if with == "self" then with = rng:pick(partners) end
            if not byWith[with] then
                byWith[with] = { with = with, name = senderLabel(id, with), messages = {} }
                order[#order + 1] = with
            end
            local msgs = byWith[with].messages
            msgs[#msgs + 1] = { day = ev.day, minute = ev.minute, inbound = ev.inbound, unread = ev.unread, body = ev.body }
        end
        table.sort(order)
        for _, with in ipairs(order) do content.texts[#content.texts + 1] = byWith[with] end
        content.draft = rng:pick(Templates.deadPhone.drafts)
    end

    if depth.notes then
        for _ = 1, rng:int(1, 3) do
            local t = pickTemplate(Templates.deadPhone.notes)
            if t then
                local body = Story.fill(rng, bodyOf(t), ctx)
                local hint = false
                for _, w in ipairs(HINT_WORDS) do if body:find(w, 1, true) then hint = true end end
                content.notes[#content.notes + 1] = { body = body, day = rng:int(-9, deathDay), hint = hint }
            end
        end
    end

    if depth.group and id.job.group then
        local chat = { name = id.job.group, messages = {} }
        for _ = 1, rng:int(2, 4) do
            local t = rng:pick(Templates.deadPhone.groupChat)
            local day = rng:int(-3, deathDay)
            local minute = rng:int(6 * 60, 23 * 60)
            if foundAt and at(day, minute) >= foundAt then minute = Mod.floor(foundAt - 1, DAY); day = math.floor((foundAt - 1) / DAY) end
            chat.messages[#chat.messages + 1] = {
                day = day, minute = minute, inbound = true,
                from = firstName(rng, rng:chance(0.5)), body = Story.fill(rng, t.body, ctx),
            }
        end
        sortByTime(chat.messages)
        content.groupChats[1] = chat
    end

    if depth.group then
        content.lastApp = rng:pick({ "texts", "camera", "map", "music" })
        if id.job.key ~= "unemployed" then content.alarm = { minute = rng:int(5 * 60, 7 * 60), label = "shift" } end
    end
    -- Colour screens (2003 on) keep a camera roll: captions only (Core/Photos, the Photos app).
    if Photos.FAMILIES[opts.family] then
        content.photos = Photos.roll(rng, { id.friend.label, id.family.sib.label, id.family.partner.label, "Mom", "Dad" },
            { lastDay = deathDay })
    end
    return content
end

-- The player's family storyline (spec §5.2) ----------------------------------------------------

-- How texts name another family member: parents are "Mom" and "Dad" whatever the phone calls them.
local OTHER_NAME = { mom = "Mom", dad = "Dad" }

-- Family templates that fit where the family is: entries with a `site` only go with that kind of place.
local function fitsSite(entry, group)
    local want = type(entry) == "table" and entry.site or nil
    return want == nil or want == group
end

-- me: the player's identity. opts: { darkness = "Mild"|"Standard"|"Grim", startDay, site = "house"|"shelter" }.
-- Returns { fates = { mom, dad, sib }, messages = { { day, from, stage, body, payoff } } sorted by day }.
-- A body may keep "{place}" (where they are); the game fills it (payoff = true). With `site` (the family hunt,
-- Core/Hunt) one member says early on where they all are ("gather"); without it the place is their house.
-- Every fate is rolled first, so a text about another member fits what happens to them: nobody is "bit" who
-- lives, and nobody "didn't make it" before their own last text.
function Story.familyPlan(rng, me, opts)
    local start = opts.startDay or 0
    local weights = FATES[opts.darkness or "Standard"] or FATES.Standard
    local members = { "mom", "dad", "sib" }
    local fates, messages = {}, {}
    local T = Templates.family
    local group = opts.site or "house"

    for _, member in ipairs(members) do fates[member] = rng:weighted(weights) end

    -- When each member texts, and from which stage's list.
    local slots = {}
    local function plan(member, day, stage) slots[#slots + 1] = { member = member, day = day, stage = stage } end
    if opts.site then plan(rng:pick(members), start + rng:range(0.2, 0.9), "gather") end
    for _, member in ipairs(members) do
        local fate = fates[member]
        plan(member, start + rng:range(0.1, 1.2), "worry")
        if fate == "dies" then
            plan(member, start + rng:range(1.3, 3), "sick")
            plan(member, start + rng:range(3.1, 5), "dying")
        elseif fate == "rescued" then
            plan(member, start + rng:range(2, 6), "rescued")
        elseif fate == "goodbye" then
            plan(member, start + rng:range(2, 5), "goodbye")
        else -- silence: one more worried text, then nothing
            plan(member, start + rng:range(1.3, 2.5), "worry")
        end
    end
    table.sort(slots, function(a, b) return a.day < b.day end)
    local lastDay = {}
    for _, s in ipairs(slots) do lastDay[s.member] = s.day end

    -- Members a text from `member` on `day` may call {other}, for the template's `other` rule.
    local function candidates(member, day, rule)
        local out = {}
        for _, m in ipairs(members) do
            if m ~= member then
                local ok
                if rule == "doomed" then ok = fates[m] == "dies"
                elseif rule == "dead" then ok = fates[m] == "dies" and lastDay[m] < day
                else ok = lastDay[m] >= day end -- "any": still texting, so still around
                if ok then out[#out + 1] = m end
            end
        end
        return out
    end

    -- A line is used once in the whole family's plan when the pool allows (r8: Mom and Ronnie sent the same text).
    local used = {}
    for _, s in ipairs(slots) do
        local list = {}
        for _, e in ipairs(T[s.stage]) do if fitsSite(e, group) then list[#list + 1] = e end end
        local entry = rng:pick(list)
        for _ = 1, 12 do
            if not used[entry] then break end
            entry = rng:pick(list)
        end
        used[entry] = true
        local ctx = Story.context(me)
        local body = bodyOf(entry)
        if type(entry) == "table" and entry.other then
            local who = candidates(s.member, s.day, entry.other)
            if #who > 0 then
                local m = rng:pick(who)
                ctx.other = OTHER_NAME[m] or me.family[m].label
            else
                body = entry.alt
            end
        end
        body = Story.fill(rng, body, ctx)
        messages[#messages + 1] = { day = s.day, from = s.member, stage = s.stage, body = body,
            payoff = body:find("{place}", 1, true) ~= nil }
    end
    return { fates = fates, messages = messages }
end

-- Strangers' texts about real places (spec §5.3). opts: { startDay, endDay }.
-- Returns { { day, body, kind, place = { name, town }, sender, payoff } } sorted by day. Each text names a different
-- place (Story/Places.lua), so nobody hears "it's safe" and "avoid it" about the same building. The game gives each
-- text its own number.
function Story.survivorTexts(rng, count, opts)
    local places = {}
    for i, p in ipairs(Places) do places[i] = p end
    local list, usedTemplate = {}, {}
    for _ = 1, math.min(count, #places) do
        local place = table.remove(places, rng:int(1, #places))
        local t = rng:pick(Templates.survivor)
        for _ = 1, 6 do
            if not usedTemplate[t] then break end
            t = rng:pick(Templates.survivor)
        end
        usedTemplate[t] = true
        local sender = firstName(rng, rng:chance(0.5))
        list[#list + 1] = {
            day = rng:range(opts.startDay, opts.endDay),
            body = Story.fill(rng, bodyOf(t), { place = place.name, sender = sender }),
            kind = t.kind, place = { name = place.name, town = place.town, site = place.site }, sender = sender, payoff = true,
        }
    end
    table.sort(list, function(a, b) return a.day < b.day end)
    return list
end

return Story
