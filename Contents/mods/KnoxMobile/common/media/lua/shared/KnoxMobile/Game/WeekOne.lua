-- 0.3.0: Week One (Workshop 3403180543, runs on the Bandits mod) starts the game days before the outbreak. Read from its
-- 42.20 files (client/BWOScheduler.lua): its clock is the world age in hours minus a shift picked by its sandbox
-- option StartTime (1 week before = 0, 2 weeks = 168, 4 weeks = 504, 12 weeks = 1848, a year = 8760, 10 years =
-- 87432), and the Knox Event comes at about hour 168 of that clock. Knox Mobile's network counts its days from the
-- outbreak (Util.sinceOutbreak), so the towers are up and quiet through the week before and start failing after.
local WeekOne = {}

WeekOne.OUTBREAK_HOUR = 168
WeekOne.SHIFT = { 0, 168, 504, 1848, 8760, 87432 }

function WeekOne.active()
    return type(SandboxVars) == "table" and type(SandboxVars.BanditsWeekOne) == "table"
end

-- The world-age day the outbreak comes on (0 without Week One: play starts at the outbreak).
function WeekOne.outbreakDay()
    if not WeekOne.active() then return 0 end
    local option = tonumber(SandboxVars.BanditsWeekOne.StartTime) or 1
    local shift = WeekOne.SHIFT[option] or 0
    return (WeekOne.OUTBREAK_HOUR + shift) / 24
end

return WeekOne
