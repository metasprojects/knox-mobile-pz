-- 0.3.0: voice memos (docs/rounds/DEPTH_PLAN.md #3). Phones with a microphone and a color screen (2003 on, like the
-- camera roll: Photos.fits) record memos; you type what you say, and playing it back is the owner's voice through the
-- speaker (the crackle sound, and a little noise). Found phones often keep their owner's last memos. Darkness stays
-- implied (docs/lore/KNOX_LORE.md). Pure Lua 5.1; server/KnoxMobile/Memos.lua and client/KnoxMobile/Apps/Memos.lua.
local Photos = require "KnoxMobile/Core/Photos"

local Memos = {}

Memos.MAX = 20            -- memos a phone keeps
Memos.MAX_LENGTH = 300    -- characters you can say in one
Memos.PLAY_RADIUS = 6     -- a memo on the speaker: zombies this close hear it
Memos.FOUND_CHANCE = 0.5  -- a found phone that can record has its owner's memos this often

Memos.FOUND = {
    "Note to self. Pick up the prescription Thursday. Ask about the cheaper one.",
    "If whoever finds this can get to my sister, tell her I tried. That's all.",
    "Day three. Water's low. Going to try the store at first light.",
    "Grocery list. Milk, batteries, the good bread. Don't forget the dog food.",
    "Testing, testing. Okay, it works. Happy birthday, baby. I'll play it for you tonight.",
    "It's quiet tonight. First time in a while. I'm going to try to sleep.",
    "The shed code is the same as the bank card. Don't tell your brother.",
    "They said on the radio to stay put. So we're staying put.",
    "Mom, if you hear this, I'm at the school. They have cots and water. Come find me.",
    "I don't know who I'm recording this for. Just wanted to hear a voice.",
}

function Memos.fits(model) return Photos.fits(model) end

-- A found phone's memos: one or two of its owner's, on its last days. Returns a list (maybe empty).
function Memos.found(rng, lastDay)
    if not rng:chance(Memos.FOUND_CHANCE) then return {} end
    local out, used = {}, {}
    for i = 1, rng:int(1, 2) do
        local k = rng:int(1, #Memos.FOUND)
        if not used[k] then
            used[k] = true
            out[#out + 1] = { body = Memos.FOUND[k], day = lastDay - (2 - i), minute = rng:int(6 * 60, 23 * 60) }
        end
    end
    return out
end

return Memos
