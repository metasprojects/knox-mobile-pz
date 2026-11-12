-- Breaking text into lines that fit (0.3.1, for the Chinese story and menus): English, Spanish and Russian break at
-- spaces; Chinese and Japanese have no spaces, so a line may break between any two of their characters, but never
-- before a closing mark (，。！？ and the like). Pure Lua 5.1, UTF-8.
-- Words.lines(paragraph, fits) -> { line, ... } where fits(s) says whether s fits the width.
local Words = {}

-- The UTF-8 characters of s, one string each.
function Words.chars(s)
    local out = {}
    for ch in tostring(s or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do out[#out + 1] = ch end
    return out
end

local function code(ch)
    local b1, b2, b3 = ch:byte(1, 3)
    if #ch == 3 then return (b1 - 224) * 4096 + (b2 - 128) * 64 + (b3 - 128) end
    return -1
end

-- A character a line may break before and after: CJK ideographs, kana, full-width forms and CJK punctuation.
function Words.isWide(ch)
    local c = code(ch)
    return (c >= 0x2E80 and c <= 0x9FFF) or (c >= 0xF900 and c <= 0xFAFF) or (c >= 0xFF00 and c <= 0xFFEF)
        or (c >= 0x3000 and c <= 0x303F)
end

-- Marks that stay on the line before them.
local CLOSING = {}
for _, ch in ipairs(Words.chars("，。！？、；：」』）》〉】…%,.!?;:)]")) do CLOSING[ch] = true end
Words.CLOSING = CLOSING

-- The pieces a line may break between: { text, space } where space says a space came before the piece.
function Words.pieces(para)
    local out, word, space = {}, "", false
    local function flush()
        if word ~= "" then out[#out + 1] = { word, space }; word, space = "", false end
    end
    for _, ch in ipairs(Words.chars(para)) do
        if ch:match("^%s$") then
            flush(); space = #out > 0
        elseif Words.isWide(ch) and not CLOSING[ch] then
            flush(); out[#out + 1] = { ch, space }; space = false
        elseif CLOSING[ch] and word == "" and #out > 0 and not space then
            out[#out][1] = out[#out][1] .. ch
        else
            word = word .. ch
        end
    end
    flush()
    return out
end

-- One paragraph (no line breaks) filled into lines; a piece wider than the line gets a line of its own.
function Words.lines(para, fits)
    local lines, line = {}, ""
    for _, p in ipairs(Words.pieces(para)) do
        local try = line == "" and p[1] or (line .. (p[2] and " " or "") .. p[1])
        if line == "" or fits(try) then line = try
        else lines[#lines + 1] = line; line = p[1] end
    end
    lines[#lines + 1] = line
    return lines
end

-- s without its last character (UTF-8 safe).
function Words.dropLast(s)
    local cs = Words.chars(s)
    cs[#cs] = nil
    return table.concat(cs)
end

return Words
