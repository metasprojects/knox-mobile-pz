-- Server: game records saved on the phone (the Snake app's best score). Checked like every other command: the
-- phone has to be in the player's inventory, able to run games, and the score a sane whole number.
local Phones = require "KnoxMobile/Game/Phones"
local Net = require "KnoxMobile/Game/Net"

local MAX_SCORE = 10000 -- far above a full board at the top level

Net.onServer("snakeScore", function(player, args)
    if type(args.phoneId) ~= "number" or type(args.score) ~= "number" then return end
    local score = args.score
    if score ~= math.floor(score) or score < 1 or score > MAX_SCORE then return end
    local item = Phones.findById(player, args.phoneId)
    if not item or not Phones.isPhone(item) then return end
    local state, model = Phones.get(item)
    local family = state and Phones.registry:family(model.family)
    if not (family and family.features and family.features.games) then return end
    if type(state.games) ~= "table" then state.games = {} end
    if score > (tonumber(state.games.snake) or 0) then
        state.games.snake = score
        Phones.save(item, player)
    end
end)

return {}
