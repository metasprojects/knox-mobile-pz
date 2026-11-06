-- Server: burner SIMs (after 0.3.0). A Prepaid SIM Kit holds a blank SIM marked burner. Its number, once given, stays
-- off the grid: Find my crew neither shows it nor works on it, faction and safehouse chats leave it out, your old
-- contacts don't have it, and hunting clans can't trace it. Snap any SIM and its number goes out of service.
-- global ModData: burners[number] = true, retired[number] = true.
local Util = require "KnoxMobile/Game/Util"
local State = require "KnoxMobile/State"

local Burners = {}
KnoxMobile.Burners = Burners

local function set(name)
    local md = State.get()
    if type(md[name]) ~= "table" then md[name] = {} end
    return md[name]
end

function Burners.mark(number) if number then set("burners")[number] = true end end
function Burners.is(number) return number ~= nil and set("burners")[number] == true end

-- The player key for group membership: none on a burner, so automatic groups (faction, safehouse) leave it out.
function Burners.key(player, number)
    if Burners.is(number) then return nil end
    return Util.playerKey(player)
end

function Burners.retire(number)
    if not number then return end
    set("retired")[number] = true
    if KnoxMobile.FindPhone then KnoxMobile.FindPhone.forget(number) end
    Util.log("SIM snapped:", number)
end
function Burners.retired(number) return number ~= nil and set("retired")[number] == true end

return Burners
