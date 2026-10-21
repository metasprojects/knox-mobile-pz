-- Seeded random numbers for Knox Mobile (pure Lua 5.1, no game calls).
-- Park-Miller "minimal standard" generator with multiplier 48271. All arithmetic stays below 2^53,
-- so it is exact in Kahlua's doubles. The same seed gives the same sequence in game, on the server
-- and in unit tests, which keeps stories and loot reproducible. Never use ZombRand in Core modules.
local Mod = require "KnoxMobile/Core/Mod"

local Rng = {}
Rng.__index = Rng

local MODULUS = 2147483647 -- 2^31 - 1
local MULTIPLIER = 48271

-- Deterministic string hash (djb2 variant reduced mod 2^31-1); returns 1..2^31-2.
function Rng.hash(text)
    text = tostring(text)
    local h = 5381
    for i = 1, #text do
        h = Mod.floor((h * 33 + string.byte(text, i)), MODULUS)
    end
    if h == 0 then h = 1 end
    return h
end

local function normaliseSeed(seed)
    if type(seed) == "string" then return Rng.hash(seed) end
    seed = math.floor(tonumber(seed) or 1)
    seed = Mod.floor(seed, MODULUS)
    if seed <= 0 then seed = seed + MODULUS - 1 end
    return seed
end

-- Small consecutive seeds (1, 2, 3...) give tiny first draws in this generator, so a new generator
-- skips its first few steps. Restoring a saved state (fromState) does not.
local WARM_UP = 3

function Rng.new(seed)
    local r = setmetatable({ state = normaliseSeed(seed) }, Rng)
    for _ = 1, WARM_UP do r:nextInt31() end
    return r
end

function Rng.fromState(state)
    return setmetatable({ state = normaliseSeed(state) }, Rng)
end

function Rng:getState()
    return self.state
end

-- Next raw value in 1..2^31-2.
function Rng:nextInt31()
    self.state = Mod.floor((self.state * MULTIPLIER), MODULUS)
    return self.state
end

-- Float in [0, 1).
function Rng:next()
    return (self:nextInt31() - 1) / (MODULUS - 1)
end

-- Integer in [lo, hi], both inclusive.
function Rng:int(lo, hi)
    if hi < lo then lo, hi = hi, lo end
    return lo + math.floor(self:next() * (hi - lo + 1))
end

-- Float in [lo, hi).
function Rng:range(lo, hi)
    return lo + self:next() * (hi - lo)
end

-- True with probability p (0..1).
function Rng:chance(p)
    if p <= 0 then return false end
    if p >= 1 then return true end
    return self:next() < p
end

function Rng:pick(list)
    if #list == 0 then return nil end
    return list[self:int(1, #list)]
end

-- entries: { { value, weight }, ... }. Zero or negative weights never win. Nil when nothing can win.
function Rng:weighted(entries)
    local total = 0
    for i = 1, #entries do
        local w = entries[i][2]
        if w > 0 then total = total + w end
    end
    if total <= 0 then return nil end
    local roll = self:next() * total
    for i = 1, #entries do
        local w = entries[i][2]
        if w > 0 then
            if roll < w then return entries[i][1] end
            roll = roll - w
        end
    end
    -- Floating-point edge: return the last positive entry.
    for i = #entries, 1, -1 do
        if entries[i][2] > 0 then return entries[i][1] end
    end
end

-- Fisher-Yates shuffle in place; returns the list.
function Rng:shuffle(list)
    for i = #list, 2, -1 do
        local j = self:int(1, i)
        list[i], list[j] = list[j], list[i]
    end
    return list
end

-- An independent child generator named by a label. Does not advance this generator.
function Rng:fork(label)
    return Rng.new(Mod.floor((self.state + Rng.hash(label)), MODULUS))
end

return Rng
