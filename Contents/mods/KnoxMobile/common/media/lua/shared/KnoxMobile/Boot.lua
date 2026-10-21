-- Knox Mobile entry point: creates the public KnoxMobile table, reports that the mod loaded, and checks at
-- boot that every Knox item script and sandbox option made it into the game (one log line; lists anything missing).
local Version = require "KnoxMobile/Version"
local ItemIds = require "KnoxMobile/ItemIds"
local Sandbox = require "KnoxMobile/Core/Sandbox"

KnoxMobile = KnoxMobile or {}
KnoxMobile.version = Version.version

local function side()
    if isServer() then return "server" elseif isClient() then return "client" end
    return "singleplayer"
end

print("[KnoxMobile] loaded " .. Version.version .. " (" .. side() .. ")")

local function selfCheck()
    local missing, ids = {}, ItemIds.all()
    local manager = getScriptManager()
    for _, id in ipairs(ids) do
        if not manager:FindItem(ItemIds.full(id)) then missing[#missing + 1] = id end
    end
    local vars = SandboxVars and SandboxVars.KnoxMobile
    local options, found = 0, 0
    for _, opt in ipairs(Sandbox.OPTIONS) do
        options = options + 1
        if vars and vars[opt.name] ~= nil then found = found + 1 end
    end
    local line = string.format("[KnoxMobile] self-check: items %d/%d, sandbox options %d/%d",
        #ids - #missing, #ids, found, options)
    if #missing > 0 then line = line .. "; missing items: " .. table.concat(missing, ", ", 1, math.min(#missing, 8)) end
    print(line)
end

Events.OnGameBoot.Add(function()
    local ok, err = pcall(selfCheck)
    if not ok then print("[KnoxMobile] self-check failed: " .. tostring(err)) end
end)
