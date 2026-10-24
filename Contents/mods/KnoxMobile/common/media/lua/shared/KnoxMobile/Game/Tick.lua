-- One OnTick for the whole mod (0.1.1). About twenty separate OnTick handlers made the game call into Lua well over
-- a thousand times a second, even with the phone put away (Workshop report, 2026-10-21). Each part registers here
-- instead: the game makes one call a frame, and each part keeps its own error budget (Util.safe).
local Util = require "KnoxMobile/Game/Util"

local Tick = { parts = {} }

function Tick.add(name, fn)
    Tick.parts[#Tick.parts + 1] = Util.safe(name, fn)
end

Events.OnTick.Add(function(ticks)
    local parts = Tick.parts
    for i = 1, #parts do parts[i](ticks) end
end)

return Tick
