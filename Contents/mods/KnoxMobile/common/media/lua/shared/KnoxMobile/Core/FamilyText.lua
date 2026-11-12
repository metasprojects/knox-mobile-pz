-- Your family answers your texts (0.2.3, Meta: "if you were to text your mom at the start of the outbreak she should at
-- least reply for the first couple hours two days"). For the first two days, while a member is still texting you,
-- they answer a few minutes to an hour later: a word on what you said, then a line from where their story is. Texts
-- sent before they answer get one answer. After that your texts wait, unread, on their phone (the family hunt).
-- Pure: no game calls.
local FamilyCall = require "KnoxMobile/Core/FamilyCall"
local Story = require "KnoxMobile/Core/Story"
local Lang = require "KnoxMobile/Core/Lang"

local FamilyText = {}

FamilyText.DAYS = 2 -- story days after the family's storyline starts
FamilyText.MAX_ASK = 320 -- characters of your texts kept for the answer

-- The day the storyline started: saved on new plans (plan.start); older ones, just before their first text.
function FamilyText.start(plan)
    if plan.start then return plan.start end
    local first
    for _, m in ipairs(plan.messages or {}) do first = math.min(first or m.day, m.day) end
    return (first or 0) - 0.1
end

-- Whether `member` answers a text sent `now` (story days): in the first two days, while they're still texting
-- (like a call's "talking", Core/FamilyCall), and not once their story has turned (dying, rescued, gone).
local ANSWERING = { worry = true, gather = true, sick = true, before = true }
function FamilyText.answers(plan, member, now)
    local stage, last = FamilyCall.status(plan, member, now)
    return ANSWERING[stage] == true and now < FamilyText.start(plan) + FamilyText.DAYS and now <= last + 0.5
end

-- How long they take, in story days: minutes at first, up to an hour once the lines are jammed.
function FamilyText.delay(rng, sinceStart)
    local minutes = sinceStart < 0.5 and rng:int(5, 20) or rng:int(15, 60)
    return minutes / 1440
end

-- A text from you to `member` at `now`. Returns true when they'll answer it (plan.asked[member]: { body, due }).
function FamilyText.ask(rng, plan, member, body, now)
    if not (member and FamilyText.answers(plan, member, now)) then return false end
    plan.asked = plan.asked or {}
    local a = plan.asked[member]
    if a then
        a.body = (a.body .. " " .. tostring(body)):sub(-FamilyText.MAX_ASK)
    else
        plan.asked[member] = { body = tostring(body):sub(1, FamilyText.MAX_ASK),
            due = now + FamilyText.delay(rng, now - FamilyText.start(plan)) }
    end
    return true
end

-- A word on what you said, by the words in your texts; the first group that matches answers. needs: one of these
-- words too; unless: none of these. `where` has two lists: before the family has named its place, and after
-- ({place}, filled by the game). The words are English and Spanish (0.2.5), without accents (Lang.fold): you can text
-- in either, whatever language the story is in, and the answer comes in the story's language.
local LOVE = {
    "Love you too. So much",
    "Miss you like crazy. We'll be together soon",
}
FamilyText.ABOUT = {
    { id = "hurt", words = { "bitten", "bite", "scratched", "scratch", "hurt", "bleeding", "blood", "injured",
        "mordida", "mordido", "mordio", "mordieron", "mordisco", "rasguno", "aranazo", "arano", "rasgunado",
        "herido", "herida", "sangre", "sangrando", "lastimado", "lastimada", "lastime" },
        lines = {
        "Hurt where?? Wash it right now. Hot water and soap, and wrap it tight",
        "What happened? Is it a bite? Tell me it's not a bite",
    } },
    { id = "help", words = { "help", "scared", "afraid", "terrified", "trapped", "panic",
        "ayuda", "ayudame", "auxilio", "miedo", "asustado", "asustada", "atrapado", "atrapada", "panico" }, lines = {
        "Breathe. Get somewhere with a door that locks and stay quiet",
        "I'm right here. Stay away from the windows and keep the lights off",
    } },
    { id = "where", words = { "where", "wya", "donde", "dnd", "ubicacion" }, lines = {
        "Still home. [We're not going anywhere till this calms down|The roads are a mess]",
        "Home, with the doors locked. Where else would we be",
    }, told = {
        "We're at {place}. Come in daylight, not after dark",
        "Still at {place}. Knock and say your name",
    } },
    { id = "coming", words = { "coming", "omw", "heading", "driving", "walking",
        "voy", "vamos", "llego", "camino", "manejando", "caminando", "yendo" }, lines = {
        "Not in the dark. Wait for daylight and take the back roads",
        "Only if it's safe. Don't you dare take the highway",
    } },
    -- "I'm not okay": the bad news.
    { id = "notOkay", words = { "safe", "ok", "okay", "fine", "alright", "good",
        "bien", "salvo", "salva", "salvos", "tranquilo", "tranquila" }, onlyIfNegated = true, lines = {
        "What's wrong? Talk to me",
        "Not okay how? Are you hurt? Tell me the truth",
    } },
    -- "You okay?": asking about them, not saying you are.
    { id = "askThem", words = { "safe", "ok", "okay", "fine", "alive", "alright",
        "bien", "salvo", "salvos", "vivos", "vivo", "viva" },
        needs = { "you", "u", "yall", "guys", "everyone", "estan", "estas", "ustedes", "tu", "todos", "uds" },
        unless = { "i", "im", "me", "yo", "estoy" }, lines = {
        "We're okay. Scared, but okay",
        "We're fine for now. Are YOU okay? That's what matters",
    } },
    { id = "safe", words = { "safe", "ok", "okay", "fine", "alive", "alright", "good",
        "bien", "salvo", "salva", "vivo", "viva", "tranquilo", "tranquila" }, notIfNegated = true, lines = {
        "Oh thank God. I've been sick with worry",
        "Okay. Okay. That's the best thing I've heard all day",
        "Good. Stay that way. Don't take chances",
    } },
    { id = "love", words = { "love", "luv", "miss", "amo", "tqm", "tkm", "extrano", "extranamos" },
        lines = LOVE },
    -- "Te quiero" is love; "quiero agua" is not.
    { id = "love", words = { "quiero" }, needs = { "te", "los", "las" }, lines = LOVE },
    { id = "food", words = { "food", "water", "hungry", "eat", "starving", "thirsty",
        "comida", "agua", "hambre", "comer", "comi", "sed" }, lines = {
        "Eat what you've got and fill every pot with water while it still runs",
        "There's canned stuff in every house. Don't be proud about it",
    } },
}

-- 0.3.1: the same groups in Portuguese (folded: plain letters), Russian and Chinese, added to the first group with
-- that id. A word that starts with "~" matches anywhere in the text: Russian stems ("~укус" is укусил, укусили...)
-- and Chinese, which has no spaces between words.
local MORE = {
    hurt = { words = { "mordida", "mordido", "mordeu", "morderam", "arranhao", "arranhado", "arranhada", "arranhou",
        "ferido", "ferida", "machucado", "machucada", "machuquei", "machucou", "sangue", "sangrando",
        "~укус", "~поцарап", "~царапин", "~ранен", "~ранил", "~рана", "~рану", "~кровь", "~крови", "~кровоточ", "~больно",
        "~咬", "~抓伤", "~受伤", "~流血", "~血", "~伤口", "~疼" } },
    help = { words = { "socorro", "ajuda", "ajudem", "ajude", "medo", "assustado", "assustada", "preso", "presa",
        "encurralado", "encurralada", "panico", "apavorado", "apavorada",
        "~помоги", "~помогите", "~помощь", "~спаси", "~страшно", "~боюсь", "~испуг", "~застрял", "~ловушк", "~паник",
        "~救命", "~救救", "~帮帮", "~帮我", "~害怕", "~好怕", "~很怕", "~困住", "~被困", "~慌" } },
    where = { words = { "onde", "cade", "aonde", "localizacao", "endereco",
        "где", "~куда", "адрес", "~在哪", "~哪里", "~哪儿", "~地址", "~什么地方" } },
    coming = { words = { "indo", "vou", "vamos", "chegando", "chego", "caminho", "dirigindo", "andando",
        "~приеду", "~приду", "~выезжаю", "~выхожу", "~уже еду", "~уже иду", "~еду к", "~иду к", "~в пути",
        "~скоро буду", "~еду домой", "~иду домой",
        "~我来", "~过来", "~在路上", "~出发", "~开车", "~马上到", "~去找你", "~回家" } },
    notOkay = { words = { "bem", "seguro", "segura", "salvo", "salva", "tranquilo", "tranquila",
        "~в порядке", "~хорошо", "~нормально", "~безопасн", "ок", "норм", "~好", "~安全", "~没事" } },
    askThem = { words = { "bem", "seguro", "segura", "salvos", "vivos", "vivo", "viva",
        "~в порядке", "~живы", "~жив", "целы", "~хорошо", "~нормально", "~безопасн",
        "~还好", "~安全", "~平安", "~没事", "~活着", "~好吗", "~怎么样" },
        needs = { "voce", "voces", "vc", "vcs", "todos", "ai", "ces", "вы", "ты", "вас", "тебя", "все", "как",
            "~你", "~大家" },
        unless = { "eu", "estou", "to", "tou", "я", "меня", "мне", "~我" } },
    safe = { words = { "bem", "seguro", "segura", "salvo", "salva", "vivo", "viva", "tranquilo", "tranquila",
        "~в порядке", "~хорошо", "~нормально", "~в безопасности", "~жив", "цел", "цела", "ок", "норм",
        "~安全", "~平安", "~没事", "~还好", "~很好", "~活着", "~挺好" } },
    love = { words = { "amo", "saudade", "saudades", "beijo", "beijos", "~люблю", "~скучаю", "~целую", "~обнимаю",
        "~爱你", "~想你" } },
    food = { words = { "comida", "agua", "fome", "comer", "comi", "sede", "faminto", "faminta",
        "~еда", "~еды", "~вода", "~воды", "~голод", "~хочу пить", "~жажд", "~поесть", "~поел", "~кушать",
        "~吃", "~饭", "~水", "~饿", "~渴", "~食物" } },
}
local added = {}
for _, group in ipairs(FamilyText.ABOUT) do
    local more = not added[group.id] and MORE[group.id]
    if more then
        added[group.id] = true
        for _, key in ipairs({ "words", "needs", "unless" }) do
            if more[key] then
                group[key] = group[key] or {}
                for _, w in ipairs(more[key]) do group[key][#group[key] + 1] = w end
            end
        end
    end
end

-- Then a line from where their story is (the stage of their latest text). Parents and the sibling talk differently.
FamilyText.LINES = {
    -- 0.3.0, Week One: answers in the week before the outbreak.
    before = {
        "I'm fine, just hot. Call your grandmother",
        "We're okay here. [The news has everybody nervous|Your dad's glued to the TV]",
        "Stay close to home this week, okay?",
        "Don't worry about us. [We have plenty of food|We stocked up]",
        "Love you. Be careful out there",
        "Your aunt says hi. She's worried about you",
        "It's probably nothing. Probably",
        "Call your father, he won't say it but he worries",
    },
    worry = {
        "Are you somewhere safe? Lock every door",
        "The TV just says stay inside. Nobody knows anything",
        "Keep your phone charged. Text me every few hours, okay?",
        "We're trying to get the radio working",
        "Don't go outside after dark. Please",
        "I keep hearing sirens. [It won't stop|All night]",
        "Calls won't go through. Texts are better",
        "Did you eat today? Don't lie to me",
        "We've got water and canned stuff. We're okay for now",
        "The neighbors aren't answering their door",
        "Stay off the main roads. They're saying the highway's blocked",
        "Fill the tub while the water's still on",
        "Text me when you wake up. I love you",
        "Is anyone with you? Don't be alone if you can help it",
        "The power flickered again. [Writing this by candle|Saving the battery]",
        "Please be careful. I can't lose you",
    },
    sibWorry = {
        "This is insane. Are you seeing the news?",
        "Mom keeps calling me. Text her too ok",
        "Stay inside. I mean it. People are losing it out there",
        "Phone's almost dead. Saving it. Text me later",
        "I saw one up close. Can't stop shaking",
        "Don't do anything stupid. I need you around",
        "Lines are jammed. Texting is the only thing that works",
        "Remember when we thought the end of the world would be cool? It isn't",
    },
    gather = {
        "We're at {place}. Come when it's light",
        "Still at {place}. We're okay here. Bring water if you can",
        "{place}. Remember it. Take the back roads",
    },
    sick = {
        "Sorry, slept all day. The fever's bad. Don't worry",
        "I'm okay. Just tired. So tired",
        "Don't come here yet. I don't want you catching this",
        "My arm's swollen where it got me. Wrapped it. It's fine",
        "Can't keep anything down. Talk tomorrow ok?",
    },
}

-- The words of a text (plain-letter words, and since 0.3.1 every run of letters, so Russian words count too), and
-- the folded text itself for the "~" words.
local function wordsOf(text)
    local folded, set = Lang.fold(text), {}
    for w in folded:gmatch("%a+") do set[w] = true end
    for w in folded:gmatch("[^%s%p%d]+") do set[w] = true end
    return set, folded
end

local function has(words, folded, w)
    if w:sub(1, 1) == "~" then return folded:find(w:sub(2), 1, true) ~= nil end
    return words[w] == true
end

-- A line from a pool, not one this family has already sent when another is left (plan.textLines).
local function pick(rng, pool, plan)
    plan.textLines = plan.textLines or {}
    local fresh = {}
    for _, line in ipairs(pool) do if not plan.textLines[line] then fresh[#fresh + 1] = line end end
    local line = rng:pick(#fresh > 0 and fresh or pool)
    plan.textLines[line] = true
    return line
end

-- "not okay", "isn't safe", "no good", "no estoy bien": not the good news.
-- 0.3.1: "não estou bem", "мне не хорошо", "我不好". Chinese lists the negated words themselves, because a bare 不 is
-- in "不用担心" (don't worry) too.
local NEGATIONS = { "not", "no", "isn", "aren", "never", "nothing", "don", "can", "cant", "nunca", "nada", "tampoco",
    "nao", "nem", "не", "нет", "ни", "ничего", "никак",
    "~不好", "~不太好", "~不安全", "~不行", "~不舒服", "~没有", "~不在" }

-- The answer from `member` to what you sent (asked), at `now`. Keeps "{place}" for the game to fill.
function FamilyText.reply(rng, plan, member, asked, now)
    local stage = FamilyCall.status(plan, member, now)
    local words, folded = wordsOf(asked)
    local about, negated = nil, false
    for _, w in ipairs(NEGATIONS) do if has(words, folded, w) then negated = true end end
    local function any(list)
        for _, w in ipairs(list) do if has(words, folded, w) then return true end end
        return false
    end
    for _, group in ipairs(FamilyText.ABOUT) do
        local fits = not (group.notIfNegated and negated) and not (group.onlyIfNegated and not negated)
            and (group.needs == nil or any(group.needs)) and not (group.unless and any(group.unless))
        if fits and any(group.words) then about = group; break end
    end
    if stage == "before" then about = nil end -- nothing has happened yet: just how their week is going
    local parts = {}
    if about then parts[1] = pick(rng, plan.placeTold and about.told or about.lines, plan) end
    -- A word on what you said, and often more; or just how things are.
    if not about or rng:chance(0.6) then
        local pool = FamilyText.LINES.worry
        if stage == "before" then pool = FamilyText.LINES.before
        elseif stage == "sick" then pool = FamilyText.LINES.sick
        elseif plan.placeTold and (stage == "gather" or rng:chance(0.3)) then pool = FamilyText.LINES.gather
        elseif member == "sib" then pool = FamilyText.LINES.sibWorry end
        parts[#parts + 1] = pick(rng, pool, plan)
    end
    -- Chinese ends a sentence with 。 and puts no space between sentences.
    local zh = Lang.code() == "zh"
    for i, p in ipairs(parts) do
        p = Story.fill(rng, p, {})
        local ended = p:find("[%.%?!]$") or p:find("。$") or p:find("！$") or p:find("？$")
        if i < #parts and not ended then p = p .. (zh and "。" or ".") end
        parts[i] = p
    end
    return table.concat(parts, zh and "" or " ")
end

-- Answers due by `now`: { { member, body } }, oldest first; they're no longer pending.
function FamilyText.due(rng, plan, now)
    local out = {}
    for member, a in pairs(plan.asked or {}) do
        if a.due <= now then out[#out + 1] = { member = member, due = a.due, asked = a.body } end
    end
    table.sort(out, function(x, y) return x.due < y.due end)
    for _, r in ipairs(out) do
        plan.asked[r.member] = nil
        r.body = FamilyText.reply(rng, plan, r.member, r.asked, now)
    end
    return out
end

return FamilyText
