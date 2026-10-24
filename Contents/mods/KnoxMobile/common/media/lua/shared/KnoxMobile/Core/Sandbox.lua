-- Sandbox settings for Knox Mobile: the user-facing sandbox options, their defaults, and
-- conversion to/from the game's sandbox-options.txt format. Pure Lua 5.1, no game calls.

local Sandbox = {}

Sandbox.OPTIONS = {
    { name = "EraLimit", type = "enum", default = "All", page = "KnoxMobilePhones", values = { "All", "1993Only" } },
    { name = "StartingPhone", type = "enum", default = "FindOnly", page = "KnoxMobilePhones",
        values = { "FindOnly", "Random", "PickAtCreation" } },
    { name = "StartWithOwnSim", type = "boolean", default = true, page = "KnoxMobilePhones" },
    -- Off: no phone is ever locked (Workshop request, 2026-10-24: "a sandbox setting to disable the password function").
    { name = "PinLocks", type = "boolean", default = true, page = "KnoxMobilePhones" },
    { name = "RarityMultiplier", type = "double", default = 1, page = "KnoxMobilePhones", min = 0, max = 5 },
    -- How phones turn up (2026-10-19: all of these in the sandbox settings).
    { name = "HousePhones", type = "double", default = 1, page = "KnoxMobilePhones", min = 0, max = 10 },
    { name = "BoxedPhones", type = "double", default = 1, page = "KnoxMobilePhones", min = 0, max = 10 },
    { name = "ZombiePhoneChance", type = "integer", default = 6, page = "KnoxMobilePhones", min = 0, max = 100 },
    { name = "SmartphoneShare", type = "integer", default = 25, page = "KnoxMobilePhones", min = 0, max = 100 },
    { name = "PristineOldPhones", type = "integer", default = 15, page = "KnoxMobilePhones", min = 0, max = 100 },
    { name = "PristineMidPhones", type = "integer", default = 8, page = "KnoxMobilePhones", min = 0, max = 100 },
    { name = "PristineSmartphones", type = "integer", default = 4, page = "KnoxMobilePhones", min = 0, max = 100 },
    { name = "FamilyStoryline", type = "boolean", default = true, page = "KnoxMobileStories" },
    { name = "StoryDarkness", type = "enum", default = "Standard", page = "KnoxMobileStories", values = { "Mild", "Standard", "Grim" } },
    { name = "SurvivorTexts", type = "boolean", default = true, page = "KnoxMobileStories" },
    { name = "FamilyHunt", type = "boolean", default = true, page = "KnoxMobileStories" },
    { name = "QuestTrapChance", type = "integer", default = 25, page = "KnoxMobileStories", min = 0, max = 100 },
    { name = "BatteryLifeMultiplier", type = "double", default = 1, page = "KnoxMobileBattery", min = 0.25, max = 4 },
    { name = "ChargeSpeedMultiplier", type = "double", default = 1, page = "KnoxMobileBattery", min = 0.25, max = 4 },
    { name = "BatteryWear", type = "boolean", default = true, page = "KnoxMobileBattery" },
    { name = "FlashlightDrain", type = "double", default = 1, page = "KnoxMobileBattery", min = 0, max = 4 },
    { name = "FoundPhoneChargeMin", type = "integer", default = 0, page = "KnoxMobileBattery", min = 0, max = 100 },
    { name = "FoundPhoneChargeMax", type = "integer", default = 50, page = "KnoxMobileBattery", min = 0, max = 100 },
    { name = "FoundPhoneHealthMin", type = "integer", default = 40, page = "KnoxMobileBattery", min = 0, max = 100 },
    { name = "FoundPhoneHealthMax", type = "integer", default = 100, page = "KnoxMobileBattery", min = 0, max = 100 },
    { name = "PowerBankCapacity", type = "double", default = 2.5, page = "KnoxMobileBattery", min = 0.5, max = 10 },
    { name = "ExactChargersForOldPhones", type = "boolean", default = true, page = "KnoxMobileBattery" },
    { name = "ServiceCollapse", type = "enum", default = "DaysAfterGrid", page = "KnoxMobileService",
        values = { "Never", "WithGrid", "DaysAfterGrid", "FixedDay" } },
    { name = "ServiceCollapseDays", type = "integer", default = 7, page = "KnoxMobileService", min = 0, max = 365 },
    { name = "GradualCollapse", type = "boolean", default = true, page = "KnoxMobileService" },
    { name = "NetworkCongestion", type = "boolean", default = true, page = "KnoxMobileService" },
    { name = "RepeaterRange", type = "integer", default = 300, page = "KnoxMobileService", min = 50, max = 2000 },
    { name = "RepeaterSkill", type = "integer", default = 4, page = "KnoxMobileService", min = 0, max = 10 },
    { name = "AllowPrivateRepeaters", type = "boolean", default = true, page = "KnoxMobileService" },
    { name = "QueueMessages", type = "boolean", default = true, page = "KnoxMobileService" },
    { name = "TowerRestore", type = "boolean", default = true, page = "KnoxMobileService" },
    { name = "TowerFuelUse", type = "double", default = 1, page = "KnoxMobileService", min = 0, max = 5 },
    { name = "RoofSignal", type = "double", default = 1, page = "KnoxMobileService", min = 0, max = 4 },
    { name = "CarrierAlerts", type = "boolean", default = true, page = "KnoxMobileService" },
    { name = "StumbleChance", type = "integer", default = 5, page = "KnoxMobileHandling", min = 0, max = 100 },
    { name = "DropChance", type = "integer", default = 25, page = "KnoxMobileHandling", min = 0, max = 100 },
    { name = "NoiseMultiplier", type = "double", default = 1, page = "KnoxMobileHandling", min = 0, max = 4 },
    { name = "AlarmRadius", type = "integer", default = 30, page = "KnoxMobileHandling", min = 0, max = 75 },
    { name = "HearingPenalty", type = "boolean", default = true, page = "KnoxMobileHandling" },
    { name = "DamageMultiplier", type = "double", default = 1, page = "KnoxMobileHandling", min = 0, max = 4 },
    { name = "WaterDamage", type = "boolean", default = true, page = "KnoxMobileHandling" },
    { name = "RiceTrick", type = "boolean", default = true, page = "KnoxMobileHandling" },
    { name = "FindMyCrew", type = "boolean", default = true, page = "KnoxMobileCommunity" },
    { name = "SosRange", type = "integer", default = 300, page = "KnoxMobileCommunity", min = 0, max = 2000 },
    { name = "SosToStrangers", type = "boolean", default = true, page = "KnoxMobileCommunity" },
    { name = "ClassifiedsDays", type = "integer", default = 7, page = "KnoxMobileCommunity", min = 1, max = 60 },
}

function Sandbox.defaults()
    local t = {}
    for _, opt in ipairs(Sandbox.OPTIONS) do
        t[opt.name] = opt.default
    end
    return t
end

local function readOption(opt, rawValue)
    if opt.type == "boolean" then
        if type(rawValue) == "boolean" then
            return rawValue
        end
        return opt.default
    elseif opt.type == "integer" then
        local n = tonumber(rawValue)
        if n ~= nil then
            n = math.floor(n + 0.5)
            if n < opt.min then
                n = opt.min
            elseif n > opt.max then
                n = opt.max
            end
            return n
        end
        return opt.default
    elseif opt.type == "double" then
        local n = tonumber(rawValue)
        if n ~= nil then
            if n < opt.min then
                n = opt.min
            elseif n > opt.max then
                n = opt.max
            end
            return n
        end
        return opt.default
    else -- enum
        if type(rawValue) == "number" and math.floor(rawValue) == rawValue
            and rawValue >= 1 and rawValue <= #opt.values then
            return opt.values[rawValue]
        end
        return opt.default
    end
end

function Sandbox.read(raw)
    local result = {}
    for _, opt in ipairs(Sandbox.OPTIONS) do
        local rawValue = raw and raw[opt.name]
        result[opt.name] = readOption(opt, rawValue)
    end
    if result.FoundPhoneChargeMin > result.FoundPhoneChargeMax then
        result.FoundPhoneChargeMin, result.FoundPhoneChargeMax = result.FoundPhoneChargeMax, result.FoundPhoneChargeMin
    end
    if result.FoundPhoneHealthMin > result.FoundPhoneHealthMax then
        result.FoundPhoneHealthMin, result.FoundPhoneHealthMax = result.FoundPhoneHealthMax, result.FoundPhoneHealthMin
    end
    return result
end

function Sandbox.toOptionsFile()
    local lines = {}
    table.insert(lines, "VERSION = 1,")
    table.insert(lines, "")
    for _, opt in ipairs(Sandbox.OPTIONS) do
        table.insert(lines, "option KnoxMobile." .. opt.name)
        table.insert(lines, "{")
        table.insert(lines, "    type = " .. opt.type .. ",")
        if opt.type == "enum" then
            table.insert(lines, "    numValues = " .. #opt.values .. ",")
            local idx = 1
            for i, v in ipairs(opt.values) do
                if v == opt.default then
                    idx = i
                    break
                end
            end
            table.insert(lines, "    default = " .. idx .. ",")
        elseif opt.type == "boolean" then
            table.insert(lines, "    default = " .. tostring(opt.default) .. ",")
        else
            table.insert(lines, "    min = " .. tostring(opt.min) .. ",")
            table.insert(lines, "    max = " .. tostring(opt.max) .. ",")
            table.insert(lines, "    default = " .. tostring(opt.default) .. ",")
        end
        table.insert(lines, "    page = " .. opt.page .. ",")
        table.insert(lines, "    translation = KnoxMobile_" .. opt.name .. ",")
        if opt.type == "enum" then
            table.insert(lines, "    valueTranslation = KnoxMobile_" .. opt.name .. ",")
        end
        table.insert(lines, "}")
        table.insert(lines, "")
    end
    return table.concat(lines, "\n") .. "\n"
end

function Sandbox.translationKeys()
    local keys = {}
    local pages = {}
    local seen = {}
    for _, opt in ipairs(Sandbox.OPTIONS) do
        table.insert(keys, "Sandbox_KnoxMobile_" .. opt.name)
        table.insert(keys, "Sandbox_KnoxMobile_" .. opt.name .. "_tooltip")
        if opt.type == "enum" then
            for i = 1, #opt.values do
                table.insert(keys, "Sandbox_KnoxMobile_" .. opt.name .. "_option" .. i)
            end
        end
        if not seen[opt.page] then
            seen[opt.page] = true
            table.insert(pages, opt.page)
        end
    end
    for _, page in ipairs(pages) do
        table.insert(keys, "Sandbox_" .. page)
    end
    return keys
end

return Sandbox