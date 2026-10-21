-- Server: KNOX MOBILE ALERT texts (Core/Alerts) tied to the game's own schedule: shutoff warnings from the sandbox
-- shutoff days, the helicopter day from GameTime, severe weather from the ClimateManager's forecaster, and the news
-- of the first days. Every ten game minutes each carried phone that is on, has a SIM and has service on the carrier's
-- network ("world": a tower, or a repeater bridged to one) gets the live alerts it hasn't had. A phone without
-- service misses them. No new alerts once every tower on its own schedule is dead. Sandbox CarrierAlerts.
-- Delivery reuses the carrier texts' helpers (Messaging.stamp, usable, appendTo, notifyTexts; see CarrierBroadcast),
-- but not their queue: queued carrier texts arrive without service, and an alert must not.
local Alerts = require "KnoxMobile/Core/Alerts"
local Phones = require "KnoxMobile/Game/Phones"
local WorldModel = require "KnoxMobile/Game/WorldModel"
local Util = require "KnoxMobile/Game/Util"
local Net = require "KnoxMobile/Game/Net"
local Messaging = require "KnoxMobile/Messaging"

local CarrierAlerts = {}
local T = Util.text

CarrierAlerts.KEEP_DAYS = 4 -- a phone forgets an alert this long after getting it (every alert window is shorter)

-- The texts, in the carrier's 1993 voice: short, plain, a little stiff.
function CarrierAlerts.text(kind, when)
    local day = when == "tomorrow" and T("IGUI_KnoxMobile_AlertTomorrow", "tomorrow") or T("IGUI_KnoxMobile_AlertToday", "today")
    if kind == "news1" then
        return T("IGUI_KnoxMobile_Alert_news1",
            "Emergency in Knox County. Keep calls short so 911 calls get through. Thank you for choosing Knox Mobile.")
    elseif kind == "news2" then
        return T("IGUI_KnoxMobile_Alert_news2",
            "State police have closed the roads out of Knox County. Stay home. Tune to EBS radio for news.")
    elseif kind == "news3" then
        return T("IGUI_KnoxMobile_Alert_news3", "The Army has sealed off Knox County. Stay indoors and avoid anyone who is sick.")
    elseif kind == "news4" then
        return T("IGUI_KnoxMobile_Alert_news4",
            "Military notice: no travel across the exclusion zone line. Our crews cannot reach cell sites inside the zone.")
    elseif kind == "powerWarn" then
        return T("IGUI_KnoxMobile_Alert_powerWarn", "Power outages expected in Knox County within 24 hours. Charge your phone now.")
    elseif kind == "powerOut" then
        return T("IGUI_KnoxMobile_Alert_powerOut",
            "Power is out countywide. Our cell sites are on backup batteries. Service may stop without warning.")
    elseif kind == "waterWarn" then
        return T("IGUI_KnoxMobile_Alert_waterWarn", "Water service may stop within 24 hours. Fill tubs and containers now.")
    elseif kind == "heli" then
        return T("IGUI_KnoxMobile_Alert_heli",
            "Military aircraft over the county today. Stay indoors and out of sight. Do not signal aircraft.")
    elseif kind == "storm" then
        return T("IGUI_KnoxMobile_Alert_storm", "Severe thunderstorm warning %1. Stay inside, away from windows.", day)
    elseif kind == "tropical" then
        return T("IGUI_KnoxMobile_Alert_tropical", "Tropical storm warning %1: high winds and flooding. Secure your shelter.", day)
    elseif kind == "blizzard" then
        return T("IGUI_KnoxMobile_Alert_blizzard", "Blizzard warning %1: heavy snow and high winds. Stay inside and keep warm.", day)
    elseif kind == "heat" then
        return T("IGUI_KnoxMobile_Alert_heat", "Heat advisory %1. Drink water and stay out of the midday sun.", day)
    end
    return nil
end

function CarrierAlerts.sender() return T("IGUI_KnoxMobile_AlertSender", "KNOX MOBILE ALERT") end

-- The forecaster's day: 0 today, 1 tomorrow (ClimateForecaster.getForecast). nil when it isn't there.
local function forecast(offset)
    local ok, f = pcall(function()
        local day = getClimateManager():getClimateForecaster():getForecast(offset)
        if not day then return nil end
        local temp = day:getTemperature()
        return { storm = day:isHasStorm(), tropical = day:isHasTropicalStorm(), blizzard = day:isHasBlizzard(),
            maxTemp = temp and temp:getDayMax() or nil }
    end)
    return ok and f or nil
end

-- The facts Core/Alerts needs, from the game.
function CarrierAlerts.context(settings)
    local gt = getGameTime()
    local hours = gt:getWorldAgeHours()
    local since = Util.sinceBegin()
    local heli = nil
    -- Sandbox Helicopter 1 is "never": the game then never sets a helicopter day.
    if SandboxVars and SandboxVars.Helicopter ~= 1 then
        heli = { day = gt:getHelicopterDay1(), nights = gt:getNightsSurvived(), endHour = gt:getHelicopterEndHour() }
    end
    return {
        day = hours / 24, hour = gt:getTimeOfDay(), calendarDay = Alerts.calendarDay(hours), sinceBegin = since,
        elecOff = Util.gridOffDay(), waterOff = Alerts.shutoffDay(SandboxVars and SandboxVars.WaterShutModifier, since),
        heli = heli, forecast = { [0] = forecast(0), [1] = forecast(1) }, carrierUp = WorldModel.carrierUp(settings),
    }
end

local function prune(seen, today)
    for id, day in pairs(seen) do
        if type(day) ~= "number" or today - day > CarrierAlerts.KEEP_DAYS then seen[id] = nil end
    end
end

-- Hands this player's phones the alerts they haven't had. force: ignore what they had (debug). Returns how many.
function CarrierAlerts.deliver(player, due, force)
    local count = 0
    local today = Util.nowDay()
    for _, item in ipairs(Phones.inventoryPhones(player)) do
        local state, model = Phones.get(item)
        if Messaging.usable(state) then
            if type(state.alertsSeen) ~= "table" then state.alertsSeen = {} end
            prune(state.alertsSeen, today)
            local fresh = force and due or Alerts.unseen(state.alertsSeen, due)
            if #fresh > 0 and Messaging.service(player, model).network == "world" then
                -- The carrier texts' own helpers (CarrierBroadcast uses them too), into the alert thread.
                local day, minute = Messaging.stamp()
                local name, sent = CarrierAlerts.sender(), {}
                for _, a in ipairs(fresh) do
                    local body = CarrierAlerts.text(a.kind, a.when)
                    if body then
                        Messaging.appendTo(state, Alerts.FROM, { day = day, minute = minute, inbound = true, unread = true,
                            body = body, from = Alerts.FROM, alert = true }, { name = name })
                        sent[#sent + 1] = { from = Alerts.FROM, body = body }
                    end
                    state.alertsSeen[a.id] = today
                end
                Phones.save(item, player)
                if #sent > 0 then Messaging.notifyTexts(player, item, state, sent) end
                count = count + #sent
            end
        end
    end
    return count
end

function CarrierAlerts.tick()
    local settings = Util.settings()
    if not settings.CarrierAlerts then return end
    local due = Alerts.due(CarrierAlerts.context(settings))
    if #due == 0 then return end
    for _, p in ipairs(Util.players()) do
        if not p:isDead() then CarrierAlerts.deliver(p, due) end
    end
end

-- Debug (admins and debug mode): every alert kind at once to your phones, so the texts can be read in game.
Net.onServer("debugAlerts", function(player)
    if not Util.debugAllowed(player) then return end
    local all = {}
    for _, kind in ipairs({ "news1", "news2", "news3", "news4", "powerWarn", "powerOut", "waterWarn", "heli", "storm",
        "tropical", "blizzard", "heat" }) do
        all[#all + 1] = { id = "debug:" .. kind, kind = kind, when = "tomorrow" }
    end
    CarrierAlerts.deliver(player, all, true)
    Net.toClient(player, "debugDone", { action = "alerts" })
end)

Events.EveryTenMinutes.Add(Util.safe("carrier alerts", function()
    if isClient() then return end
    CarrierAlerts.tick()
end))

return CarrierAlerts
