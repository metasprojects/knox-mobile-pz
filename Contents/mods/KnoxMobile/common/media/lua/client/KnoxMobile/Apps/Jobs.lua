-- Client: the Jobs app (0.3.0, server/Jobs.lua). What survivors have asked of you: new offers to accept or decline,
-- the jobs you took with the days left, and how the last ones ended. A delivery is handed over from here once you're
-- at the place; a look-in counts as soon as you get there. The places are on the Map.
local Util = require "KnoxMobile/Game/Util"
local Net = require "KnoxMobile/Game/Net"
local Lang = require "KnoxMobile/Core/Lang"

local T = Util.text
local ICONS = "media/ui/KnoxMobile/apps/"
local ALL = { "SegmentLCD", "MonoLCD", "ColorFeature", "Keyboard", "Stylus", "ModernAndroid", "ModernPear" }

KnoxMobile.JobsList = KnoxMobile.JobsList or { list = {} }
Net.onClient("jobs", function(args) KnoxMobile.JobsList = { list = type(args.list) == "table" and args.list or {} } end)
Net.onClient("jobResult", function(args)
    local toast = KnoxMobile.Client and KnoxMobile.Client.toast
    if not toast then return end
    if args.error == "far" then toast(T("IGUI_KnoxMobile_JobFar", "Not here. Go to the place first."))
    elseif args.error == "missing" then toast(T("IGUI_KnoxMobile_JobMissing", "You don't have what they asked for."))
    elseif args.done then toast(T("IGUI_KnoxMobile_JobHandedOver", "Handed over.")) end
end)

local NEED = {
    antibiotics = function() return T("IGUI_KnoxMobile_JobNeedAntibiotics", "antibiotics") end,
    painkillers = function() return T("IGUI_KnoxMobile_JobNeedPainkillers", "painkillers") end,
    bandages = function() return T("IGUI_KnoxMobile_JobNeedBandages", "bandages") end,
    batteries = function() return T("IGUI_KnoxMobile_JobNeedBatteries", "batteries") end,
    food = function() return T("IGUI_KnoxMobile_JobNeedFood", "canned food") end,
    sleep = function() return T("IGUI_KnoxMobile_JobNeedSleep", "sleeping pills") end,
    light = function() return T("IGUI_KnoxMobile_JobNeedLight", "candles or matches") end,
    cigarettes = function() return T("IGUI_KnoxMobile_JobNeedCigarettes", "cigarettes") end,
    disinfectant = function() return T("IGUI_KnoxMobile_JobNeedDisinfectant", "disinfectant") end,
    boards = function() return T("IGUI_KnoxMobile_JobNeedBoards", "nails or duct tape") end,
    splint = function() return T("IGUI_KnoxMobile_JobNeedSplint", "a splint") end,
}

local function summary(job)
    local place = Lang.t(job.place and job.place.name or "")
    if job.kind == "deliver" then
        local need = NEED[job.need] and NEED[job.need]() or tostring(job.need)
        return T("IGUI_KnoxMobile_JobDeliver", "Bring %1 to %2", need, place)
    end
    return T("IGUI_KnoxMobile_JobCheck", "Look in at %1", place)
end

local function status(job)
    if job.state == "offered" then return T("IGUI_KnoxMobile_JobNew", "New") end
    if job.state == "done" then return T("IGUI_KnoxMobile_JobDone", "Done") end
    if job.state == "expired" then return T("IGUI_KnoxMobile_JobLate", "Too late") end
    local left = math.max(0, math.ceil(((job.deadline or 0) - Util.nowMinutes()) / 1440))
    if left <= 1 then return T("IGUI_KnoxMobile_JobToday", "Due today") end
    return T("IGUI_KnoxMobile_JobDaysLeft", "%1 days left", left)
end

local ORDER = { offered = 1, active = 2, done = 3, expired = 4 }
local function jobs()
    local list = {}
    for _, j in ipairs(KnoxMobile.JobsList.list or {}) do list[#list + 1] = j end
    table.sort(list, function(a, b)
        if ORDER[a.state] ~= ORDER[b.state] then return (ORDER[a.state] or 9) < (ORDER[b.state] or 9) end
        return (a.id or 0) > (b.id or 0)
    end)
    return list
end

local function byId(id)
    for _, j in ipairs(KnoxMobile.JobsList.list or {}) do if j.id == id then return j end end
    return nil
end

local function listRows()
    local out = {}
    for _, j in ipairs(jobs()) do out[#out + 1] = { id = j.id, label = status(j) .. ": " .. summary(j) } end
    if #out == 0 then out[1] = { id = "none", label = T("IGUI_KnoxMobile_JobNone", "Nobody has asked you for anything yet") } end
    return out
end

local function actionRows(job)
    local out = {}
    if job.state == "offered" then
        out[#out + 1] = { id = "accept", label = T("IGUI_KnoxMobile_JobAccept", "Accept") }
        out[#out + 1] = { id = "decline", label = T("IGUI_KnoxMobile_JobDecline", "Decline") }
    elseif job.state == "active" and job.kind == "deliver" then
        out[#out + 1] = { id = "hand", label = T("IGUI_KnoxMobile_JobHandOver", "Hand it over (at the place)") }
    elseif job.state == "active" then
        out[#out + 1] = { id = "info", label = T("IGUI_KnoxMobile_JobGoThere", "Go there: it counts when you arrive") }
    end
    out[#out + 1] = { id = "back", label = T("IGUI_KnoxMobile_JobBack", "Back") }
    return out
end

KnoxMobile.Apps.register({
    id = "jobs", name = "Jobs", icon = ICONS .. "jobs.png", glyph = ICONS .. "jobs_glyph.png",
    label = function() return T("IGUI_KnoxMobile_AppJobs", "Jobs") end,
    short = function() return T("IGUI_KnoxMobile_AppShortJobs", "Jobs") end,
    families = ALL, drain = "screen", needsService = false, order = 62,
    onOpen = function(ctx)
        ctx.data.view = nil
        Net.toServer(ctx.player, "jobs", {})
    end,
    render = function(ctx, x, y, w, h)
        local lh = ctx:lineHeight()
        local job = ctx.data.view and byId(ctx.data.view)
        if not job then
            ctx:list(listRows(), x, y, w, h)
            return
        end
        local top = y + 2
        ctx:text(summary(job), x + 3, top, ctx.style.accent)
        top = top + lh + 2
        local maxLines = math.max(1, math.floor((h - lh * 3) / lh) - 1)
        for i, l in ipairs(ctx:wrap(job.offer or "", w - 8)) do
            if i > maxLines then break end
            ctx:text(l, x + 3, top)
            top = top + lh
        end
        ctx:list(actionRows(job), x, top + 4, w, h - (top + 4 - y))
    end,
    onInput = function(ctx, ev)
        local d = ctx.data
        local job = d.view and byId(d.view)
        if not job then
            d.view = nil
            local rows = listRows()
            local i = ctx:listInput(ev, #rows)
            local row = i and rows[i]
            if row and row.id ~= "none" then d.view = row.id end
            return true
        end
        local rows = actionRows(job)
        local i = ctx:listInput(ev, #rows)
        local row = i and rows[i]
        if not row then return true end
        if row.id == "accept" then Net.toServer(ctx.player, "jobAccept", { id = job.id })
        elseif row.id == "decline" then Net.toServer(ctx.player, "jobDecline", { id = job.id }); d.view = nil
        elseif row.id == "hand" then Net.toServer(ctx.player, "jobHandOver", { id = job.id })
        elseif row.id == "back" then d.view = nil end
        return true
    end,
})
