-- One OnTick for the whole mod (0.1.1). About twenty separate OnTick handlers made the game call into Lua well over
-- a thousand times a second, even with the phone put away (Workshop report, 2026-10-21). Each part registers here
-- instead: the game makes one call a frame, and each part keeps its own error budget (Util.safe).
-- 0.2.1: each part also says how often it needs to run (everyMs). The tick reads the clock once a frame and only calls
-- the parts that are due, so a frame with nothing due costs one call (Workshop, 2026-10-24: "still the heaviest mod
-- out of the 90 in my modpack").
local Util = require "KnoxMobile/Game/Util"

-- everyFrame: the smoke tests fire ticks faster than any interval and set it to run every part on every tick.
-- stats: the debug load readout (Debug menu), nil when off.
local Tick = { parts = {}, everyFrame = false, stats = nil }

-- everyMs: 0 (or nil) runs every frame; anything else at most that often.
function Tick.add(name, fn, everyMs)
    Tick.parts[#Tick.parts + 1] = { name = name, run = Util.safe(name, fn), every = everyMs or 0, at = 0 }
end

-- Counts one call into Knox Mobile for the load readout (the tick's parts, and hooks outside it that call this).
function Tick.count(name)
    local st = Tick.stats
    if st then st.runs[name] = (st.runs[name] or 0) + 1 end
end

local REPORT_MS = 5000

-- The debug load readout: every 5 seconds, calls into Knox Mobile per second and the busiest parts, in console.txt.
function Tick.setStats(on)
    Tick.stats = on and { ticks = 0, runs = {}, since = getTimestampMs() } or nil
end

local function report(st, now)
    local secs = math.max(0.001, (now - st.since) / 1000)
    local total, list = st.ticks, {}
    for name, n in pairs(st.runs) do
        total = total + n
        list[#list + 1] = { name = name, n = n }
    end
    table.sort(list, function(a, b) return a.n > b.n end)
    local top = {}
    for i = 1, math.min(5, #list) do top[i] = string.format("%s %.1f/s", list[i].name, list[i].n / secs) end
    Util.log(string.format("load: %.1f calls/s into Knox Mobile (%.1f ticks/s); busiest: %s", total / secs,
        st.ticks / secs, #top > 0 and table.concat(top, ", ") or "none"))
    st.ticks, st.runs, st.since = 0, {}, now
end

Events.OnTick.Add(function(ticks)
    local now = getTimestampMs()
    local parts, all, st = Tick.parts, Tick.everyFrame, Tick.stats
    for i = 1, #parts do
        local p = parts[i]
        if all or now >= p.at then
            p.at = now + p.every
            if st then st.runs[p.name] = (st.runs[p.name] or 0) + 1 end
            p.run(ticks)
        end
    end
    if st then
        st.ticks = st.ticks + 1
        if now - st.since >= REPORT_MS then report(st, now) end
    end
end)

return Tick
