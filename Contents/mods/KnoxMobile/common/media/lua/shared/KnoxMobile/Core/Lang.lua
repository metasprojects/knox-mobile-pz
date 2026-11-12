-- The language of the words the mod writes itself (0.2.5, Meta 2026-10-27: "get this ready for a Spanish language
-- patch"): texts, voicemails, calls, notes and recordings. Menus and labels go through the game's own translation
-- files (Translate/<language>/*.json); the story is written once, on the server, and saved, so it is written in one
-- language here. The English line is the key: Lang.t looks it up in the language's dictionaries (Lang/<code>/*.lua)
-- and gives the English back when there is no translation yet, so a line added later reads in English until someone
-- translates it. Pure Lua 5.1: the game says which language (Lang.use, Game/Util.storyLanguage); without it
-- everything stays English (the tests, the tools).
local Lang = {}

-- The game's languages (its Translate folders) and the story language each gets: Spanish for Spain, Mexico, Chile
-- and Argentina; 0.3.1: Russian, Brazilian Portuguese (also for Portugal's PT, which has no story of its own) and
-- Simplified Chinese.
Lang.GAME = { ES = "es", ES_MX = "es", ES_CL = "es", AR = "es", RU = "ru", PTBR = "pt", PT = "pt", CN = "zh" }
-- Each language's dictionaries ({ [english] = translation }), searched in this order.
Lang.FILES = { "Story", "Voices", "Library1", "Library2", "Library3", "Library4", "Library5", "Library6", "Network" }
Lang.DICTS = {}
for _, code in ipairs({ "es", "ru", "pt", "zh" }) do
    local list = {}
    for i, name in ipairs(Lang.FILES) do list[i] = "KnoxMobile/Lang/" .. code .. "/" .. name end
    Lang.DICTS[code] = list
end

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
-- Portuguese (0.3.1) joins em, de, a and por with the article: "em o motel" is "no motel", "de a igreja" is "da
-- igreja", "a o posto" is "ao posto", "por a estrada" is "pela estrada". Templates write "em {place}" and the place
-- name brings its article ("o motel de Muldraugh").
local PT_JOIN = {
    { "em", "o", "no" }, { "em", "a", "na" }, { "em", "os", "nos" }, { "em", "as", "nas" },
    { "de", "o", "do" }, { "de", "a", "da" }, { "de", "os", "dos" }, { "de", "as", "das" },
    { "a", "o", "ao" }, { "a", "a", "à" }, { "a", "os", "aos" }, { "a", "as", "às" },
    { "por", "o", "pelo" }, { "por", "a", "pela" }, { "por", "os", "pelos" }, { "por", "as", "pelas" },
}
local function capital(word)
    if word == "à" then return "À" elseif word == "às" then return "Às" end
    return word:sub(1, 1):upper() .. word:sub(2)
end

local TIDY = {
    es = function(s)
        s = (" " .. s):gsub("([%s%(\"])([Aa]) el ", "%1%2l "):gsub("([%s%(\"])([Dd]e) el ", "%1%2l ")
        return s:sub(2)
    end,
    pt = function(s)
        s = " " .. s
        for _, j in ipairs(PT_JOIN) do
            local prep, art, joined = j[1], j[2], j[3]
            s = s:gsub("([%s%(\"])" .. prep .. " " .. art .. " ", "%1" .. joined .. " ")
            s = s:gsub("([%s%(\"])" .. capital(prep) .. " " .. art .. " ", "%1" .. capital(joined) .. " ")
        end
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
-- 0.3.1: Portuguese accents, and Russian capitals (plain Lua's lower() only knows A-Z; the game's knows them all).
for from, to in pairs({ ["ã"] = "a", ["â"] = "a", ["à"] = "a", ["ê"] = "e", ["ô"] = "o", ["õ"] = "o", ["ç"] = "c",
    ["Ã"] = "a", ["Â"] = "a", ["À"] = "a", ["Ê"] = "e", ["Ô"] = "o", ["Õ"] = "o", ["Ç"] = "c" }) do FOLD[from] = to end
local RU_UPPER = { "А", "Б", "В", "Г", "Д", "Е", "Ж", "З", "И", "Й", "К", "Л", "М", "Н", "О", "П", "Р", "С", "Т", "У",
    "Ф", "Х", "Ц", "Ч", "Ш", "Щ", "Ъ", "Ы", "Ь", "Э", "Ю", "Я" }
local RU_LOWER = { "а", "б", "в", "г", "д", "е", "ж", "з", "и", "й", "к", "л", "м", "н", "о", "п", "р", "с", "т", "у",
    "ф", "х", "ц", "ч", "ш", "щ", "ъ", "ы", "ь", "э", "ю", "я" }
for i, up in ipairs(RU_UPPER) do FOLD[up] = RU_LOWER[i] end
FOLD["Ё"], FOLD["ё"] = "е", "е"

function Lang.fold(text)
    local s = tostring(text or ""):lower()
    for from, to in pairs(FOLD) do s = s:gsub(from, to) end
    return s
end

return Lang
