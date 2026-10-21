-- Calculator: a pocket calculator's logic (client/KnoxMobile/Apps/Calculator.lua draws it). Pure Lua 5.1.
-- It works like the four-function calculators phones shipped with: left to right, no precedence
-- (2 + 3 x 4 = 20), "=" repeats the last operation, % takes a percentage of the first number.
--
--   local c = Calculator.new(10)          -- display width in digits
--   Calculator.press(c, "1"); Calculator.press(c, "+"); Calculator.press(c, "2"); Calculator.press(c, "=")
--   Calculator.display(c)                 -- "3"
-- Keys: "0".."9", ".", "+", "-", "*", "/", "=", "%", "neg" (change sign), "back" (delete a digit), "C" (clear).
local Calculator = {}

Calculator.KEYS = { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "+", "-", "*", "/", "=", "%", "neg", "back", "C" }
local OPS = { ["+"] = true, ["-"] = true, ["*"] = true, ["/"] = true }
Calculator.OPS = OPS

function Calculator.new(digits)
    return { digits = math.max(6, math.floor(digits or 10)), entry = "0", acc = nil, op = nil, fresh = true,
        lastOp = nil, lastArg = nil, error = false }
end

local function apply(a, op, b)
    if op == "+" then return a + b end
    if op == "-" then return a - b end
    if op == "*" then return a * b end
    if op == "/" then
        if b == 0 then return nil end
        return a / b
    end
    return b
end

-- Formats a number to fit `digits` characters (the sign and point not counted), or nil when it can't.
function Calculator.format(n, digits)
    if n ~= n or n == math.huge or n == -math.huge then return nil end
    if n == 0 then return "0" end
    local neg = n < 0
    local a = math.abs(n)
    if a >= 10 ^ digits then return nil end
    local intDigits = a >= 1 and #string.format("%.0f", math.floor(a)) or 1
    local decimals = math.max(0, digits - intDigits)
    local s = string.format("%." .. decimals .. "f", a)
    if s:find("%.") then s = s:gsub("0+$", ""):gsub("%.$", "") end
    -- Rounding can carry into a new digit (9.999 -> 10.00).
    local plain = s:gsub("%.", "")
    if #plain > digits then
        s = string.format("%." .. math.max(0, decimals - 1) .. "f", a)
        if s:find("%.") then s = s:gsub("0+$", ""):gsub("%.$", "") end
        if #s:gsub("%.", "") > digits then return nil end
    end
    if s == "0" then return "0" end
    return (neg and "-" or "") .. s
end

local function value(c) return tonumber(c.entry) or 0 end

local function setResult(c, n)
    local s = n and Calculator.format(n, c.digits)
    if not s then
        c.error, c.entry, c.acc, c.op = true, "Error", nil, nil
        return false
    end
    c.entry = s
    return true
end

local function digitCount(s) return #(s:gsub("[%-%.]", "")) end

-- Presses one key. Returns the calculator.
function Calculator.press(c, k)
    if k == "C" then
        local digits = c.digits
        for key in pairs(c) do c[key] = nil end
        local fresh = Calculator.new(digits)
        for key, v in pairs(fresh) do c[key] = v end
        return c
    end
    if c.error then
        -- Only clear (or a new number) gets out of an error.
        if k:match("^%d$") or k == "." then Calculator.press(c, "C") else return c end
    end
    if k:match("^%d$") then
        if c.fresh then c.entry, c.fresh = "0", false end
        if digitCount(c.entry) >= c.digits then return c end
        if c.entry == "0" then c.entry = k
        elseif c.entry == "-0" then c.entry = "-" .. k
        else c.entry = c.entry .. k end
        return c
    end
    if k == "." then
        if c.fresh then c.entry, c.fresh = "0", false end
        if not c.entry:find("%.") and digitCount(c.entry) < c.digits then c.entry = c.entry .. "." end
        return c
    end
    if k == "back" then
        if c.fresh then return c end
        c.entry = c.entry:sub(1, -2)
        if c.entry == "" or c.entry == "-" then c.entry = "0" end
        return c
    end
    if k == "neg" then
        if c.entry == "0" then return c end
        if c.entry:sub(1, 1) == "-" then c.entry = c.entry:sub(2) else c.entry = "-" .. c.entry end
        if c.fresh and c.acc == nil then c.lastOp = nil end
        return c
    end
    if k == "%" then
        -- 50 + 10 % = 55 (10% of 50); alone, 10 % = 0.1.
        local n = value(c)
        if c.acc ~= nil and (c.op == "+" or c.op == "-") then n = c.acc * n / 100 else n = n / 100 end
        setResult(c, n)
        c.fresh = true
        return c
    end
    if OPS[k] then
        if c.acc ~= nil and c.op and not c.fresh then
            if not setResult(c, apply(c.acc, c.op, value(c))) then return c end
        end
        c.acc, c.op, c.fresh = value(c), k, true
        c.lastOp, c.lastArg = nil, nil
        return c
    end
    if k == "=" then
        if c.op and c.acc ~= nil then
            local b = value(c)
            local op = c.op
            if setResult(c, apply(c.acc, op, b)) then c.lastOp, c.lastArg = op, b end
            c.acc, c.op = nil, nil
        elseif c.lastOp then
            -- "=" again repeats the last operation: 2 + 3 = = gives 8.
            setResult(c, apply(value(c), c.lastOp, c.lastArg))
        end
        c.fresh = true
        return c
    end
    return c
end

-- Presses each key of a string like "12+3=" (handy for tests and typing). "n" is "neg", "<" is "back".
function Calculator.type(c, keys)
    for ch in tostring(keys):gmatch(".") do
        local k = ch
        if ch == "n" then k = "neg" elseif ch == "<" then k = "back" elseif ch == "c" then k = "C" end
        Calculator.press(c, k)
    end
    return c
end

function Calculator.display(c) return c.entry end

-- The pending operation for a small second line: "12 +" while an operator waits, else "".
function Calculator.pending(c)
    if c.error or not c.op or c.acc == nil then return "" end
    local SHOW = { ["+"] = "+", ["-"] = "-", ["*"] = "x", ["/"] = "/" }
    return (Calculator.format(c.acc, c.digits) or "") .. " " .. SHOW[c.op]
end

return Calculator
