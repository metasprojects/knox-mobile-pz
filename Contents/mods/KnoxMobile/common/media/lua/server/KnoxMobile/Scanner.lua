-- Server: the Scanner (0.3.0, Core/Scanner). A listen on an old analog phone ("scan", from Apps/Scanner.lua) catches
-- one fragment of what's in range: a hostile bandit clan's chatter (with the Bandits mod), the dispatcher while she's
-- on the air for this player (server/Dispatch.lua), another player's call in progress, or static.
local Scanner = require "KnoxMobile/Core/Scanner"
local ClanChatter = require "KnoxMobile/Core/ClanChatter"
local Dispatch = require "KnoxMobile/Core/Dispatch"
local Bandits = require "KnoxMobile/Game/Bandits"
local Story = require "KnoxMobile/Core/Story"
local Names = require "KnoxMobile/Story/Names"
local Lang = require "KnoxMobile/Core/Lang"
local Util = require "KnoxMobile/Game/Util"
local Rng = require "KnoxMobile/Core/Rng"
local Net = require "KnoxMobile/Game/Net"
local State = require "KnoxMobile/State"
local Phones = require "KnoxMobile/Game/Phones"
local Protocol = require "KnoxMobile/Core/Protocol"

local World = { listens = 0 }
KnoxMobile.ScannerWorld = World

Protocol.register({
    scan = function(args)
        if type(args.phoneId) ~= "number" then return false, "phoneId must be a number" end
        return true
    end,
})

local function near(x, y, px, py) return math.abs(x - px) <= Scanner.RANGE and math.abs(y - py) <= Scanner.RANGE end

-- What can be heard from here: a list of { label, line } (line is filled and cut by the caller).
function World.sources(player)
    local px, py = player:getX(), player:getY()
    local out = {}
    -- A clan in range.
    -- (KnoxMobile.Raids.near: on a server, what this player's client saw; 0.3.0 MP fix.)
    if Bandits.active() and KnoxMobile.Raids then
        for _, b in ipairs(KnoxMobile.Raids.near(player)) do
            if near(b.x, b.y, px, py) then
                out[#out + 1] = { kind = "clan", label = b.clan, lines = ClanChatter.GROUP }
                break
            end
        end
    end
    -- The dispatcher, while she's on the air for this player.
    local d = type(State.get().dispatch) == "table" and State.get().dispatch[Util.playerKey(player)]
    if d and not d.ended then
        local said = {}
        for _, b in ipairs(Dispatch.BEATS) do
            if b.kind == "text" and d.sent[b.id] and not b.reward then said[#said + 1] = b.body end
        end
        if #said > 0 then out[#out + 1] = { kind = "dispatch", lines = said } end
    end
    -- Another player on a call nearby.
    for _, call in pairs(State.calls.byId or {}) do
        if call.status == "active" then
            for _, other in ipairs(Util.players()) do
                if other ~= player and near(other:getX(), other:getY(), px, py) then
                    out[#out + 1] = { kind = "call" }
                    break
                end
            end
        end
    end
    return out
end

-- One listen: { kind, label, text }.
function World.listen(player, rng)
    local sources = World.sources(player)
    local pick = #sources > 0 and rng:chance(0.8) and sources[rng:int(1, #sources)] or nil
    if not pick then return { kind = "static", text = Lang.t(Scanner.NOISE[rng:int(1, #Scanner.NOISE)]) } end
    if pick.kind == "call" then return { kind = "call", text = Lang.t(Scanner.NOISE[2]) } end
    local line = Story.fill(rng, pick.lines[rng:int(1, #pick.lines)],
        { mate = rng:pick(Names.male), mate2 = rng:pick(Names.female), place = "" })
    return { kind = pick.kind, label = pick.label, text = Scanner.fragment(rng, line) }
end

Net.onServer("scan", function(player, args)
    local item = Phones.findById(player, args.phoneId)
    if not item then return end
    local st, model = Phones.get(item)
    if not (st and st.power and st.power.on and Scanner.fits(model)) then return end
    World.listens = World.listens + 1
    local rng = Rng.new(tostring(State.get().seed) .. ":scan:" .. Util.playerKey(player) .. ":" .. Util.nowMinutes() .. ":"
        .. World.listens)
    Net.toClient(player, "scan", World.listen(player, rng))
end)

return World
