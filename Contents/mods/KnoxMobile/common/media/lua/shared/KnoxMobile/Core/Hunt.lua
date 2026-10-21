-- The family hunt (2026-10-12): the family storyline names one real building (Story/Sites.lua), and what the player
-- finds there follows each member's fate (Core/Story.familyPlan). Pure Lua 5.1: the server (server/KnoxMobile/Hunt.lua)
-- places it in the world.
local Names = require "KnoxMobile/Story/Names"
local Sites = require "KnoxMobile/Story/Sites"
local Templates = require "KnoxMobile/Story/Templates"

local Hunt = {}

local MEMBERS = { "mom", "dad", "sib" }
Hunt.MEMBERS = MEMBERS
Hunt.UNREAD_CAP = 30
-- A killed zombie this close to a set scene, in a member's clothes, is that member (when its tag was lost on reload).
Hunt.MATCH_RADIUS = 40

-- Families texting from a church or a school are at a shelter; Templates.family entries say which they fit.
function Hunt.siteGroup(kind) return kind == "house" and "house" or "shelter" end

-- The family's place: one in their hometown (or the town Sites.nearby names) that no other player's family has,
-- else any free one. taken: { [site id] = true }. Returns a Sites.family entry, or nil when all are taken.
function Hunt.pickSite(rng, hometown, taken, sites)
    sites = sites or Sites.family
    local town = Sites.nearby[hometown] or hometown
    local home, any = {}, {}
    for _, s in ipairs(sites) do
        if not (taken and taken[s.id]) then
            any[#any + 1] = s
            if s.town == town then home[#home + 1] = s end
        end
    end
    if #home > 0 then return rng:pick(home) end
    if #any > 0 then return rng:pick(any) end
    return nil
end

-- What is there, from the fates: every member who died turned there; those who said goodbye left a note and the
-- car; the rescued and the silent are simply gone. kind: "turned", "note" or "empty" (nobody, nothing).
function Hunt.outcome(fates)
    local turned, left = {}, {}
    for _, m in ipairs(MEMBERS) do
        if fates[m] == "dies" then turned[#turned + 1] = m elseif fates[m] == "goodbye" then left[#left + 1] = m end
    end
    local kind = (#turned > 0 and "turned") or (#left > 0 and "note") or "empty"
    return { turned = turned, left = left, kind = kind }
end

-- Mom is a woman, Dad a man; the sibling goes by their name.
function Hunt.isFemale(me, member)
    if member == "mom" then return true elseif member == "dad" then return false end
    local first = me.family.sib.label
    for _, n in ipairs(Names.female) do if n == first then return true end end
    return false
end

-- Vanilla outfits (media/clothing/clothing.xml, in both the female and male lists) for someone who stayed home
-- or sheltered with half the town.
local OUTFITS = {
    house = { parent = { "Generic01", "Generic02", "Generic03", "Bathrobe", "Bedroom" },
        young = { "Generic04", "Young", "Student", "Bedroom" } },
    shelter = { parent = { "Evacuee", "Generic01", "Generic05" }, young = { "Evacuee", "Young", "Student", "Varsity" } },
}
Hunt.OUTFITS = OUTFITS

function Hunt.outfit(rng, member, kind)
    local set = OUTFITS[Hunt.siteGroup(kind)]
    return rng:pick(member == "sib" and set.young or set.parent)
end

-- The family cars of 1993 (vanilla vehicle scripts, media/scripts/generated/vehicles).
Hunt.CARS = { "Base.CarStationWagon", "Base.CarNormal", "Base.PickUpTruck", "Base.SmallCar", "Base.Van" }

-- How the family writes each other's names: "Mom", "Dad", the sibling's first name.
function Hunt.callName(people, member)
    if member == "mom" then return "Mom" elseif member == "dad" then return "Dad" end
    return people[member] and people[member].first or "?"
end

-- Everything about the hunt, decided when the storyline is made so it never changes later.
-- me: the player's identity; plan: Story.familyPlan's result; numbers: { mom, dad, sib } phone numbers.
function Hunt.new(rng, site, me, plan, numbers, playerNumber)
    local people = {}
    for _, m in ipairs(MEMBERS) do
        local who = me.family[m]
        people[m] = { name = who.name, first = who.name:match("^(%S+)") or who.name, female = Hunt.isFemale(me, m),
            number = numbers[m], outfit = Hunt.outfit(rng, m, site.kind),
            draft = rng:pick(Templates.family.drafts) }
    end
    local outcome = Hunt.outcome(plan.fates)
    local hunt = {
        site = site.id, name = site.name, kind = site.kind, town = site.town, x = site.x, y = site.y, z = 0,
        state = "waiting", outcome = outcome, people = people, unread = {}, phones = {},
        player = { first = me.first, number = playerNumber },
    }
    if #outcome.left > 0 then
        hunt.note = { line = rng:int(1, 3), writer = outcome.left[1], lost = outcome.turned[1] }
        hunt.car = rng:pick(Hunt.CARS)
    end
    return hunt
end

-- A text the player sent to a family number: kept for that member's phone, where it waits unread.
function Hunt.recordSent(hunt, to, body, day, minute)
    for _, m in ipairs(MEMBERS) do
        local p = hunt.people[m]
        if p and p.number == to then
            hunt.unread[m] = hunt.unread[m] or {}
            local list = hunt.unread[m]
            list[#list + 1] = { day = day, minute = minute, body = body }
            while #list > Hunt.UNREAD_CAP do table.remove(list, 1) end
            return m
        end
    end
    return nil
end

-- The thread on a member's phone: what they sent the player (plan messages, {place} filled by fill) and the
-- player's texts they never read, oldest first. Returns a phone `texts` list.
function Hunt.memberTexts(hunt, member, messages, fill)
    local conv = { with = hunt.player.number, name = hunt.player.first, messages = {} }
    for _, m in ipairs(messages) do
        if m.from == member then
            local day = math.floor(m.day)
            conv.messages[#conv.messages + 1] = { day = day, minute = math.floor((m.day - day) * 1440), inbound = false,
                body = fill(m.body) }
        end
    end
    for _, u in ipairs(hunt.unread[member] or {}) do
        conv.messages[#conv.messages + 1] = { day = u.day, minute = u.minute, inbound = true, unread = true, body = u.body }
    end
    table.sort(conv.messages, function(a, b) return a.day * 1440 + a.minute < b.day * 1440 + b.minute end)
    return { conv }
end

-- Is a killed zombie (x, y, outfit, female) one of this set scene's turned members whose phone is still to find?
-- Returns the member or nil.
function Hunt.matchZombie(hunt, x, y, outfit, female)
    if hunt.state ~= "done" then return nil end
    local dx, dy = x - hunt.x, y - hunt.y
    if dx * dx + dy * dy > Hunt.MATCH_RADIUS * Hunt.MATCH_RADIUS then return nil end
    for _, m in ipairs(hunt.outcome.turned) do
        local p = hunt.people[m]
        if not hunt.phones[m] and p.outfit == outfit and p.female == female then return m end
    end
    return nil
end

return Hunt
