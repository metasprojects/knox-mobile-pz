-- Server: tower broadcasts (after 0.3.0). Whoever stands at a cell site they brought back on the air (SiteRestore) can
-- text every phone that tower serves right now: from "TOWER <code>", signed with their name, no replies. Once an
-- in-game hour per site.
local CellSites = require "KnoxMobile/Core/CellSites"
local Carrier = require "KnoxMobile/Core/Carrier"
local Protocol = require "KnoxMobile/Core/Protocol"
local TowerSites = require "KnoxMobile/Data/TowerSites"
local Phones = require "KnoxMobile/Game/Phones"
local Util = require "KnoxMobile/Game/Util"
local Net = require "KnoxMobile/Game/Net"
local State = require "KnoxMobile/State"
local Messaging = require "KnoxMobile/Messaging"

local TowerBroadcast = { EVERY = 60 }
KnoxMobile.TowerBroadcast = TowerBroadcast

Protocol.register({ siteBroadcast = function(args)
    if type(args.code) ~= "string" or not CellSites.byCode(TowerSites.sites, args.code) then return false, "code" end
    if type(args.body) ~= "string" then return false, "body" end
    return true
end })

local function tell(player, event, extra)
    local out = { kind = "towerCast", event = event }
    for k, v in pairs(extra or {}) do out[k] = v end
    Net.toClient(player, "notify", out)
end

local function signed(player)
    local name = "?"
    pcall(function() name = player:getDescriptor():getForename() end)
    return name
end

-- Every phone this tower serves now. Returns how many got it.
function TowerBroadcast.send(site, from, body)
    local seen, n = {}, 0
    for _, p in ipairs(Util.players()) do
        for _, item in ipairs(Phones.inventoryPhones(p)) do
            local st, model = Phones.get(item)
            local number = st and st.sim and st.sim.number
            if number and not seen[number] and Messaging.usable(st) and Messaging.service(p, model).via == site.id then
                seen[number] = true
                local day, minute = Messaging.stamp()
                Messaging.appendRecord(st, { from = from, body = body, story = true }, day, minute)
                Phones.save(item, p)
                Messaging.notifyTexts(p, item, st, { { from = from, body = body } })
                n = n + 1
            end
        end
    end
    return n
end

Net.onServer("siteBroadcast", function(player, args)
    local site = CellSites.byCode(TowerSites.sites, args.code)
    local entry = site and State.get().sites[site.id]
    local now = Util.nowMinutes()
    if not (entry and entry.connected and CellSites.isUp(entry, now)) then return tell(player, "offAir") end
    if math.floor(player:getZ()) ~= (site.z or 0) or CellSites.distance(site, player:getX(), player:getY()) > CellSites.MENU_RADIUS + 2 then
        return tell(player, "tooFar")
    end
    if entry.castAt and now - entry.castAt < TowerBroadcast.EVERY then
        return tell(player, "tooSoon", { number = math.ceil(TowerBroadcast.EVERY - (now - entry.castAt)) })
    end
    local body = Carrier.clean(args.body)
    if not body then return tell(player, "badText") end
    entry.castAt = now
    local n = TowerBroadcast.send(site, "TOWER " .. site.code, signed(player) .. ": " .. body)
    Util.log("tower broadcast from", site.code, "by", Util.playerKey(player), "to", n, "phones:", body)
    tell(player, "sent", { number = n })
end)

return TowerBroadcast
