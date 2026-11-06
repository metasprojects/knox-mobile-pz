-- The language of the words the mod writes itself (0.2.5, Meta 2026-10-27: "get this ready for a Spanish language
-- patch"): texts, voicemails, calls, notes and recordings. Menus and labels go through the game's own translation
-- files (Translate/<language>/*.json); the story is written once, on the server, and saved, so it is written in one
-- language here. The English line is the key: Lang.t looks it up in the language's dictionaries (Lang/<code>/*.lua)
-- and gives the English back when there is no translation yet, so a line added later reads in English until someone
-- translates it. Pure Lua 5.1: the game says which language (Lang.use, Game/Util.storyLanguage); without it
-- everything stays English (the tests, the tools).
local Lang = {}

-- The game's languages (its Translate folders) that get the story in Spanish: Spain, Mexico, Chile, Argentina.
Lang.GAME = { ES = "es", ES_MX = "es", ES_CL = "es", AR = "es" }
-- Each language's dictionaries ({ [english] = translation }), searched in this order.
Lang.DICTS = { es = { "KnoxMobile/Lang/es/Story", "KnoxMobile/Lang/es/Voices", "KnoxMobile/Lang/es/Library1",
    "KnoxMobile/Lang/es/Library2", "KnoxMobile/Lang/es/Library3", "KnoxMobile/Lang/es/Library4",
    "KnoxMobile/Lang/es/Library5", "KnoxMobile/Lang/es/Library6",
    "KnoxMobile/Lang/es/Network" } }

local current = "en"
local provider = nil
local dicts = {}

-- The language from now on, "en" or "es", when no game is asking (tests and tools). Anything else is English.
function Lang.set(code) current = Lang.DICTS[code] and code or "en" end

-- fn() gives the language code: the game's choice (Game/Util.storyLanguage). nil goes back to Lang.set's.
function Lang.use(fn) provider = fn end

function Lang.code()
    if not provider then return current end
    local ok, code = pcall(provider)
    if ok and Lang.DICTS[code] then return code end
    return "en"
end

-- The story language for one of the game's languages ("ES_MX" is "es"); "en" for every language without one.
function Lang.fromGame(name) return Lang.GAME[tostring(name or "")] or "en" end

-- A language's dictionaries in one table, loaded the first time it's asked for.
function Lang.dict(code)
    if dicts[code] then return dicts[code] end
    local merged = {}
    for _, path in ipairs(Lang.DICTS[code] or {}) do
        local ok, t = pcall(require, path)
        if ok and type(t) == "table" then
            for k, v in pairs(t) do if merged[k] == nil then merged[k] = v end end
        end
    end
    dicts[code] = merged
    return merged
end

-- The line in the current language: its translation, or the line itself.
function Lang.t(text)
    if type(text) ~= "string" then return text end
    local code = Lang.code()
    if code == "en" then return text end
    return Lang.dict(code)[text] or text
end

-- Spanish runs "a" and "de" into "el": "vamos a el motel" is "vamos al motel", "de el" is "del". Place names start
-- with their article ("el motel de Muldraugh"), so a template's "a {place}" needs it.
local TIDY = {
    es = function(s)
        s = (" " .. s):gsub("([%s%(\"])([Aa]) el ", "%1%2l "):gsub("([%s%(\"])([Dd]e) el ", "%1%2l ")
        return s:sub(2)
    end,
}

-- A filled line made right for its language (nothing to do in English).
function Lang.tidy(text)
    local fn = TIDY[Lang.code()]
    if not fn or type(text) ~= "string" then return text end
    return fn(text)
end

-- A template in the current language with its {slots} filled. The values are translated too ("the Muldraugh
-- motel"); a slot with no value stays as it is ({place}, for the game to fill later).
function Lang.f(template, slots)
    local text = Lang.t(template)
    if slots then
        text = text:gsub("{(%w+)}", function(key)
            local v = slots[key]
            if v == nil then return "{" .. key .. "}" end
            return Lang.t(tostring(v))
        end)
    end
    return Lang.tidy(text)
end

-- Text a player typed, for matching words: lowercase, without accents ("¿Dónde?" reads "¿donde?"), so "donde" and
-- "dónde" are the same word, and the plain letters let the game's %a+ split it into words.
local FOLD = {
    ["á"] = "a", ["é"] = "e", ["í"] = "i", ["ó"] = "o", ["ú"] = "u", ["ü"] = "u", ["ñ"] = "n",
    ["Á"] = "a", ["É"] = "e", ["Í"] = "i", ["Ó"] = "o", ["Ú"] = "u", ["Ü"] = "u", ["Ñ"] = "n",
}
function Lang.fold(text)
    local s = tostring(text or ""):lower()
    for from, to in pairs(FOLD) do s = s:gsub(from, to) end
    return s
end

return Lang
