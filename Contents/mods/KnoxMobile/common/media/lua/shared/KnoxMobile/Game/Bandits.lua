-- 0.3.0: the Bandits NPC mod (Workshop 3268487204; also the engine under Week One). A bandit is a zombie the Bandits
-- mod drives: IsoZombie with the "Bandit" variable set, and its brain in BanditBrain.Get(zombie) (read from Bandits
-- 42.21's shared/BanditBrain.lua and server/BanditServerSpawner.lua makeBrain: fullname, clan/cid, hostile, hostileP,
-- program.name, bornCoords). Clan names live in BanditCustom.clanData[cid].general.name ("Rusty_Wolves").
-- Everything here reads only; nothing changes when the mod isn't there.
local Bandits = {}

function Bandits.active()
    return type(BanditBrain) == "table" and type(BanditBrain.Get) == "function"
end

-- Is this zombie one of the Bandits mod's NPCs?
function Bandits.isBandit(zombie)
    if not zombie or not Bandits.active() then return false end
    if not zombie.getVariableBoolean then return false end
    return zombie:getVariableBoolean("Bandit") == true
end

local function clanName(cid)
    local data = type(BanditCustom) == "table" and type(BanditCustom.clanData) == "table" and BanditCustom.clanData[cid]
    local name = data and type(data.general) == "table" and data.general.name
    if type(name) ~= "string" or name == "" then return nil end
    return (name:gsub("_", " "))
end

-- What Knox Mobile needs to know about a bandit, or nil. { name, clan (display name or nil), cid, hostile, program,
-- camp = { x, y } or nil }.
function Bandits.info(zombie)
    if not Bandits.isBandit(zombie) then return nil end
    local brain = BanditBrain.Get(zombie)
    if type(brain) ~= "table" then return nil end
    local cid = brain.clan or brain.cid
    local born = type(brain.bornCoords) == "table" and brain.bornCoords or nil
    return {
        name = type(brain.fullname) == "string" and brain.fullname or nil,
        cid = cid ~= nil and tostring(cid) or nil,
        clan = cid ~= nil and clanName(cid) or nil,
        hostile = brain.hostile == true or brain.hostileP == true,
        program = type(brain.program) == "table" and brain.program.name or nil,
        camp = born and tonumber(born.x) and tonumber(born.y) and { x = math.floor(born.x), y = math.floor(born.y) } or nil,
    }
end

return Bandits
