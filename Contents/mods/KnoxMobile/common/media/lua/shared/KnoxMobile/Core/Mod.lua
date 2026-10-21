-- Floored modulo. The game's Lua (Kahlua) gives a % b the sign of a (-4 % 1440 == -4, like Java's remainder), so
-- every clock, wrap and page in the mod uses Mod.floor, which is always in [0, b) for b > 0. tools/lint_mod.py fails
-- on a bare % in the mod's Lua (the unit tests run on real Lua 5.1, where % is already floored, and cannot see this).
local Mod = {}

function Mod.floor(a, b) return a - math.floor(a / b) * b end

return Mod
