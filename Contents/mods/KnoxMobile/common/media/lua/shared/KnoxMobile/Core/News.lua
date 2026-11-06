-- 0.3.0: the News app's headlines. A fictional station's wire, by day (days from the outbreak, Util.sinceOutbreak:
-- day 0 is July 9, 1993, when the game starts; Week One plays the days before). It follows the lore timeline
-- (docs/lore/KNOX_LORE.md): the Louisville stories, the Fourth, the shelters, the roads sealed on July 6, the dead
-- landlines, then the county going quiet. Never "zombie"; "the illness", "the sick", attacks. Pure Lua 5.1.
local News = {}

News.STATION = "WKNX 1350"
-- The request line (after 0.3.0, server/Wknx.lua): one of the 555-01xx numbers no SIM gets (Core/Sim).
News.REQUEST_LINE = "(502) 555-0135"

News.ITEMS = {
    { day = -9, text = "Heat advisory for Knox County through the holiday weekend" },
    { day = -8, text = "Louisville man hospitalized after a biting incident, police say" },
    { day = -7, text = "Flu cases up sharply in Louisville, health officials say" },
    { day = -6, text = "Fourth of July fireworks at the river will go on as planned" },
    { day = -5, text = "Louisville hospitals ask visitors to stay home" },
    { day = -5, text = "Police report attacks in three Louisville neighborhoods" },
    { day = -4, text = "Churches and schools open as shelters across the county" },
    { day = -4, text = "Long lines at pharmacies and gas stations as residents stock up" },
    { day = -3, text = "Roads out of Knox County closed at 6 a.m., checkpoints on 31W" },
    { day = -3, text = "Army: the fence is for public safety, residents should stay home" },
    { day = -2, text = "Landlines down across the county, cell service holding" },
    { day = -1, text = "Curfew from dusk in Muldraugh, West Point and Riverside" },
    { day = 0, text = "Officials: stay indoors, keep your phone charged, wait for instructions" },
    { day = 1, text = "Fort Knox spokesman says the situation at the fence is contained" },
    { day = 1, text = "Emergency broadcasts to air on the hour on AM and FM" },
    { day = 2, text = "Rosewood hospital stops taking patients" },
    { day = 3, text = "Water plant staff asked to report for work, escorts promised" },
    { day = 4, text = "Residents report armed groups on rural roads" },
    { day = 5, text = "No word from Fort Knox since Tuesday night" },
    { day = 6, text = "Power company: outages likely within days, crews cannot reach substations" },
    { day = 8, text = "This station will stay on the air as long as we can" },
    { day = 10, text = "WKNX is moving to generator power. Bulletins every two hours" },
    { day = 13, text = "Last bulletin. If you can hear this, help each other" },
}

-- The last day the station is on the air: its last bulletin.
News.LAST_DAY = -math.huge
for _, it in ipairs(News.ITEMS) do if it.day > News.LAST_DAY then News.LAST_DAY = it.day end end

-- What the feed shows on this day: up to `max` items, newest first.
function News.feed(day, max)
    local out = {}
    for i = #News.ITEMS, 1, -1 do
        local it = News.ITEMS[i]
        if it.day <= day then out[#out + 1] = it end
        if max and #out >= max then break end
    end
    return out
end

return News
