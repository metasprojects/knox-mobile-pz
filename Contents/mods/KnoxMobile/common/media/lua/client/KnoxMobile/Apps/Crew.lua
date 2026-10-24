-- Client: the Crew app. Find my crew: group members whose phones opted in (Settings), as a rough direction and
-- distance from the towers or a repeater, never exact. And the SOS button: a distress text with your rough location
-- to your groups and contacts (and nearby phones, if the server allows it). The phone then rings out loud.
local Util = require "KnoxMobile/Game/Util"
local SocialText = require "KnoxMobile/Game/SocialText"

local T = Util.text
local ALL = { "SegmentLCD", "MonoLCD", "ColorFeature", "Keyboard", "Stylus", "ModernAndroid", "ModernPear" }
local ICONS = "media/ui/KnoxMobile/apps/"
local SMALL = { SegmentLCD = true, MonoLCD = true }

local function Social() return KnoxMobile.Social end
local function small(ctx) return SMALL[ctx.family] == true end

local function find(ctx)
    if Util.settings().FindMyCrew and ctx.state.crewShare then Social().request("crewFind", ctx.phone) end
end

local function rows(ctx)
    local d = ctx.data
    local out = {}
    local result = Social().crew[ctx.phone:getID()]
    if not Util.settings().FindMyCrew then
        out[#out + 1] = { id = "info", label = SocialText.reason("off") }
    elseif not ctx.state.crewShare then
        out[#out + 1] = { id = "share", label = T("IGUI_KnoxMobile_CrewTurnOn", "Sharing is off: turn it on") }
    elseif result and result.error then
        out[#out + 1] = { id = "refresh", label = SocialText.reason(result.error) }
    elseif not result then
        out[#out + 1] = { id = "refresh", label = T("IGUI_KnoxMobile_CrewLooking", "Looking...") }
    else
        for _, r in ipairs(result.list or {}) do
            -- A phone an A-Life robber took (server StolenPhones): "Your phone (Vic)".
            local name = r.stolenBy and T("IGUI_KnoxMobile_CrewStolen", "Your phone (%1)", r.stolenBy)
                or Social().nameFor(ctx.state, r.number)
            -- The longest wording that fits the row: "Rob: northeast, a few blocks", "Rob: NE, a few blocks", "Rob NE blocks".
            local label = T("IGUI_KnoxMobile_CrewLine", "%1: %2, %3", name, SocialText.dir(r.dir), SocialText.band(r.band))
            if small(ctx) or ctx:measure(label) > ctx.w - 10 then
                label = T("IGUI_KnoxMobile_CrewLine", "%1: %2, %3", name, SocialText.dir(r.dir, true), SocialText.band(r.band))
            end
            if small(ctx) or ctx:measure(label) > ctx.w - 10 then
                label = name .. " " .. SocialText.dir(r.dir, true) .. " " .. SocialText.band(r.band, true)
            end
            out[#out + 1] = { id = "member", label = label }
        end
        if #(result.list or {}) == 0 then
            out[#out + 1] = { id = "refresh", label = T("IGUI_KnoxMobile_CrewNobody", "Nobody is sharing yet") }
        end
        out[#out + 1] = { id = "refresh", label = T("IGUI_KnoxMobile_CrewRefresh", "Look again") }
    end
    out[#out + 1] = { id = "sos", label = d.confirm and T("IGUI_KnoxMobile_CrewSosConfirm", "SOS: select again to send")
        or T("IGUI_KnoxMobile_CrewSos", "Send SOS") }
    return out
end

KnoxMobile.Apps.register({
    id = "crew", name = "Find my crew", icon = ICONS .. "crew.png", glyph = ICONS .. "crew_glyph.png",
    label = function() return T("IGUI_KnoxMobile_AppCrew", "Find my crew") end,
    short = function() return T("IGUI_KnoxMobile_AppShortCrew", "Crew") end,
    families = ALL, drain = "screen", needsService = true, order = 65,
    onOpen = function(ctx) find(ctx) end,
    render = function(ctx, x, y, w, h)
        local lh = ctx:lineHeight()
        local top = y
        local titleText = T("IGUI_KnoxMobile_CrewTitle", "Your groups, roughly:")
        if not small(ctx) and ctx:measure(titleText) <= w - 6 then
            ctx:text(titleText, x + 3, y + 1, ctx.style.accent)
            top = y + lh + 4
        end
        ctx:list(rows(ctx), x, top, w, h - (top - y))
    end,
    onInput = function(ctx, ev)
        local d = ctx.data
        local list = rows(ctx)
        local i = ctx:listInput(ev, #list)
        local row = i and list[i]
        if not row then return true end
        if row.id ~= "sos" then d.confirm = nil end
        if row.id == "share" then
            Social().request("crewShare", ctx.phone, { on = true })
            Social().request("crewFind", ctx.phone)
        elseif row.id == "refresh" then
            find(ctx)
        elseif row.id == "sos" then
            if d.confirm then
                d.confirm = nil
                Social().sendSos(ctx.phone)
            else
                d.confirm = true
            end
        end
        return true
    end,
})
