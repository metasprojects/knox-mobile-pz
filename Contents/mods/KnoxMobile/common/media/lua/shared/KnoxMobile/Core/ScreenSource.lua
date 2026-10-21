-- The screen slot (spec §12.2): who draws the phone screen. The default is the phone's own shell;
-- add-ons (Knox Mobile+ and Link) register sources that take over while available. Pure Lua 5.1.

local ScreenSource = {}
ScreenSource.__index = ScreenSource

local SHELL = { id = "shell", priority = 0 }

function ScreenSource.new()
    return setmetatable({ list = {} }, ScreenSource)
end

-- def: { id, priority (number), isAvailable(phone) -> bool, render(ctx, x, y, w, h), onInput(ctx, ev) }
function ScreenSource:register(def)
    if type(def) ~= "table" or type(def.id) ~= "string" or #def.id == 0 then return false, "id required" end
    if def.id == SHELL.id then return false, "shell is the built-in source" end
    if type(def.priority) ~= "number" then return false, def.id .. ": priority must be a number" end
    if type(def.isAvailable) ~= "function" then return false, def.id .. ": isAvailable function required" end
    if type(def.render) ~= "function" then return false, def.id .. ": render function required" end
    for _, s in ipairs(self.list) do
        if s.id == def.id then return false, def.id .. ": already registered" end
    end
    self.list[#self.list + 1] = def
    table.sort(self.list, function(a, b) return a.priority > b.priority end)
    return true
end

-- The highest-priority source available for this phone; a source that errors counts as unavailable.
function ScreenSource:active(phone)
    for _, s in ipairs(self.list) do
        local ok, available = pcall(s.isAvailable, phone)
        if ok and available then return s end
    end
    return SHELL
end

return ScreenSource
