-- On-screen words for group chats, the carrier, Classifieds, find my crew and SOS. Every string is a literal
-- T("IGUI_KnoxMobile_...", "English") so tools/gen finds it. The server uses it too, for the English fallback body
-- of an SOS text (phones draw their own translation from the message's sos field).
local Util = require "KnoxMobile/Game/Util"

local T = Util.text
local S = {}

local DIR = {
    N = function() return T("IGUI_KnoxMobile_DirN", "north") end,
    NE = function() return T("IGUI_KnoxMobile_DirNE", "northeast") end,
    E = function() return T("IGUI_KnoxMobile_DirE", "east") end,
    SE = function() return T("IGUI_KnoxMobile_DirSE", "southeast") end,
    S = function() return T("IGUI_KnoxMobile_DirS", "south") end,
    SW = function() return T("IGUI_KnoxMobile_DirSW", "southwest") end,
    W = function() return T("IGUI_KnoxMobile_DirW", "west") end,
    NW = function() return T("IGUI_KnoxMobile_DirNW", "northwest") end,
}
local DIR_SHORT = {
    N = function() return T("IGUI_KnoxMobile_DirShortN", "N") end,
    NE = function() return T("IGUI_KnoxMobile_DirShortNE", "NE") end,
    E = function() return T("IGUI_KnoxMobile_DirShortE", "E") end,
    SE = function() return T("IGUI_KnoxMobile_DirShortSE", "SE") end,
    S = function() return T("IGUI_KnoxMobile_DirShortS", "S") end,
    SW = function() return T("IGUI_KnoxMobile_DirShortSW", "SW") end,
    W = function() return T("IGUI_KnoxMobile_DirShortW", "W") end,
    NW = function() return T("IGUI_KnoxMobile_DirShortNW", "NW") end,
}
local BAND = {
    near = function() return T("IGUI_KnoxMobile_BandNear", "under 100 m") end,
    blocks = function() return T("IGUI_KnoxMobile_BandBlocks", "a few blocks") end,
    km = function() return T("IGUI_KnoxMobile_BandKm", "about a km") end,
    far = function() return T("IGUI_KnoxMobile_BandFar", "far") end,
}
local BAND_SHORT = {
    near = function() return T("IGUI_KnoxMobile_BandShortNear", "<100m") end,
    blocks = function() return T("IGUI_KnoxMobile_BandShortBlocks", "blocks") end,
    km = function() return T("IGUI_KnoxMobile_BandShortKm", "~1km") end,
    far = function() return T("IGUI_KnoxMobile_BandShortFar", "far") end,
}

function S.dir(d, short)
    local f = (short and DIR_SHORT or DIR)[d]
    return f and f() or "?"
end

function S.band(b, short)
    local f = (short and BAND_SHORT or BAND)[b]
    return f and f() or "?"
end

-- "SOS! I need help. I'm a few blocks northeast of Muldraugh." from { town, dir, band }.
function S.sos(where)
    where = type(where) == "table" and where or {}
    if not where.town then return T("IGUI_KnoxMobile_SosNoTown", "SOS! I need help. I'm out in the country.") end
    if where.band == "near" then return T("IGUI_KnoxMobile_SosIn", "SOS! I need help. I'm in %1.", where.town) end
    local how = {
        blocks = function()
            return T("IGUI_KnoxMobile_SosBlocks", "SOS! I need help. I'm a few blocks %1 of %2.", S.dir(where.dir), where.town)
        end,
        km = function() return T("IGUI_KnoxMobile_SosKm", "SOS! I need help. I'm about a km %1 of %2.", S.dir(where.dir), where.town) end,
        far = function() return T("IGUI_KnoxMobile_SosFar", "SOS! I need help. I'm far %1 of %2.", S.dir(where.dir), where.town) end,
    }
    local f = how[where.band] or how.far
    return f()
end

-- The same on a small LCD, in one short line: "SOS! Muldraugh NE blocks".
function S.sosShort(where)
    where = type(where) == "table" and where or {}
    if not where.town then return T("IGUI_KnoxMobile_SosShortNoTown", "SOS! Out of town") end
    if where.band == "near" then return T("IGUI_KnoxMobile_SosShortIn", "SOS! In %1", where.town) end
    return T("IGUI_KnoxMobile_SosShort", "SOS! %1 %2 %3", where.town, S.dir(where.dir, true), S.band(where.band, true))
end

-- Group thread headers: small LCDs say "Grp:Name".
function S.groupHeader(name, small)
    if small then return T("IGUI_KnoxMobile_GroupShort", "Grp:%1", name or "?") end
    return name or "?"
end

function S.carrier() return T("IGUI_KnoxMobile_Carrier", "KNOX MOBILE") end

-- A group event line in a thread ("Kate added you"). who: the sender's name on this phone.
function S.event(event, who, group)
    if event == "added" then return T("IGUI_KnoxMobile_GroupAdded", "%1 added you to %2", who, group or "") end
    if event == "removed" then return T("IGUI_KnoxMobile_GroupRemoved", "%1 took you out of %2", who, group or "") end
    if event == "created" then return T("IGUI_KnoxMobile_GroupCreated", "You started %1", group or "") end
    return ""
end

local CATEGORY = {
    trade = function() return T("IGUI_KnoxMobile_CatTrade", "For trade") end,
    wanted = function() return T("IGUI_KnoxMobile_CatWanted", "Wanted") end,
    services = function() return T("IGUI_KnoxMobile_CatServices", "Services") end,
    notices = function() return T("IGUI_KnoxMobile_CatNotices", "Notices") end,
}
function S.category(c)
    local f = CATEGORY[c]
    return f and f() or tostring(c)
end

-- Why something didn't work, for the result toasts.
local REASON = {
    noPhone = function() return T("IGUI_KnoxMobile_WhyNoPhone", "That phone isn't on you") end,
    phoneOff = function() return T("IGUI_KnoxMobile_WhyPhoneOff", "The phone is off") end,
    locked = function() return T("IGUI_KnoxMobile_WhyLocked", "The phone is locked") end,
    noService = function() return T("IGUI_KnoxMobile_NoService", "No service") end,
    noSim = function() return T("IGUI_KnoxMobile_NoSim", "No SIM card") end,
    badName = function() return T("IGUI_KnoxMobile_WhyBadName", "That name won't do") end,
    tooFew = function() return T("IGUI_KnoxMobile_WhyTooFew", "Pick at least one other person") end,
    tooMany = function() return T("IGUI_KnoxMobile_WhyTooMany", "A group holds at most 12 people") end,
    full = function() return T("IGUI_KnoxMobile_WhyTooMany", "A group holds at most 12 people") end,
    tooManyGroups = function() return T("IGUI_KnoxMobile_WhyTooManyGroups", "You're in too many groups already") end,
    theirLimit = function() return T("IGUI_KnoxMobile_WhyTheirLimit", "They're in too many groups already") end,
    noGroup = function() return T("IGUI_KnoxMobile_WhyNoGroup", "That group is gone") end,
    notMember = function() return T("IGUI_KnoxMobile_WhyNotMember", "Not in that group") end,
    already = function() return T("IGUI_KnoxMobile_WhyAlready", "Already in the group") end,
    notOwner = function() return T("IGUI_KnoxMobile_WhyNotOwner", "Only the group's owner can do that") end,
    auto = function() return T("IGUI_KnoxMobile_WhyAuto", "Faction and safehouse groups follow the game") end,
    notAllowed = function() return T("IGUI_KnoxMobile_WhyNotAllowed", "Admins only") end,
    badText = function() return T("IGUI_KnoxMobile_WhyBadText", "That text won't do") end,
    badTitle = function() return T("IGUI_KnoxMobile_WhyBadTitle", "That title won't do") end,
    badCategory = function() return T("IGUI_KnoxMobile_WhyBadCategory", "Pick a category") end,
    limit = function() return T("IGUI_KnoxMobile_WhyPostLimit", "You have 3 listings up already") end,
    notYours = function() return T("IGUI_KnoxMobile_WhyNotYours", "That isn't your listing") end,
    noPost = function() return T("IGUI_KnoxMobile_WhyNoPost", "That listing is gone") end,
    off = function() return T("IGUI_KnoxMobile_WhyCrewOff", "Find my crew is off on this server") end,
    notSharing = function() return T("IGUI_KnoxMobile_WhyNotSharing", "Turn on Find my crew in Settings first") end,
}

-- wait: minutes or seconds to wait, for "tooSoon", "cooldown", "hourly".
function S.reason(why, wait)
    if why == "tooSoon" then return T("IGUI_KnoxMobile_WhyTooSoon", "Too soon. Wait %1 more minutes.", wait or "?") end
    if why == "cooldown" or why == "hourly" then return T("IGUI_KnoxMobile_WhyCooldown", "Too soon. Wait %1 more seconds.", wait or "?") end
    local f = REASON[why]
    return f and f() or tostring(why)
end

return S
