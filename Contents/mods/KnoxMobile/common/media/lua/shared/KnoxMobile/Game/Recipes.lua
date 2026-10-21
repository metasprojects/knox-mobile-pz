-- The repeater recipe's Electrical level follows sandbox RepeaterSkill (spec §7.3, §14). Item scripts can't
-- read sandbox options, so once the world's settings are known the recipe's requirement is replaced
-- (CraftRecipe.clearRequiredSkills / addRequiredSkill). Runs on the server and on every client.
local Util = require "KnoxMobile/Game/Util"

local Recipes = {}

function Recipes.applyRepeaterSkill()
    local manager = getScriptManager()
    local recipe = manager:getCraftRecipe("KnoxMobile.BuildCellRepeater") or manager:getCraftRecipe("BuildCellRepeater")
    if not recipe then return false end
    local level = Util.settings().RepeaterSkill
    recipe:clearRequiredSkills()
    if level > 0 then recipe:addRequiredSkill(Perks.Electricity, level) end
    Util.log("repeater recipe needs Electrical", level)
    return true
end

Events.OnInitGlobalModData.Add(Util.safe("repeater skill", Recipes.applyRepeaterSkill))
Events.OnGameStart.Add(Util.safe("repeater skill", Recipes.applyRepeaterSkill))

return Recipes
