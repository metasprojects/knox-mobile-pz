-- Server: call WKNX 1350 (after 0.3.0). The station's request line, News.REQUEST_LINE, answers while the station is
-- on the air (through the last bulletin, News.LAST_DAY) and the carrier is up: the DJ, today's headline, the latest
-- messages listeners left, then yours after the beep (client: Client.lua's scripted call asks "wknx"). Listeners'
-- messages show in every phone's News app. global ModData: wknx = { messages = { { name, text, day } }, last = { key = minute } }.
local News = require "KnoxMobile/Core/News"
local Lang = require "KnoxMobile/Core/Lang"
local Rng = require "KnoxMobile/Core/Rng"
local Story = require "KnoxMobile/Core/Story"
local Protocol = require "KnoxMobile/Core/Protocol"
local Util = require "KnoxMobile/Game/Util"
local Net = require "KnoxMobile/Game/Net"
local WorldModel = require "KnoxMobile/Game/WorldModel"
local State = require "KnoxMobile/State"
local Messaging = require "KnoxMobile/Messaging"

local Wknx = { KEEP = 12, READ = 2, GAP = 60 }
KnoxMobile.Wknx = Wknx

local function data()
    local md = State.get()
    if type(md.wknx) ~= "table" then md.wknx = { messages = {}, last = {} } end
    return md.wknx
end

function Wknx.onAir(day) return day <= News.LAST_DAY and WorldModel.carrierUp() end

-- What the caller hears: a " / "-joined script for the scripted call.
function Wknx.script(day, rng)
    local parts = { Story.fill(rng, "WKNX 1350, you're on the air. [Go ahead.|Who's this?|Talk to me.]", {}) }
    local today = News.feed(day, 1)[1]
    if today then parts[#parts + 1] = Lang.f("Today's news: {news}.", { news = Lang.t(today.text) }) end
    local list = data().messages
    for i = #list, math.max(1, #list - Wknx.READ + 1), -1 do
        parts[#parts + 1] = Lang.f("We had a call from {name}: {text}", { name = list[i].name, text = list[i].text })
    end
    parts[#parts + 1] = Lang.t("Got a song request or a message for the county? Leave it after the beep and we'll put it on the air.")
    return table.concat(parts, " / ")
end

-- From Server.lua's placeCall.
function Wknx.call(player, item, to)
    local day = math.floor(Util.sinceOutbreak())
    Messaging.logCall(player, item, to, false)
    if not Wknx.onAir(day) then
        Net.toClient(player, "callScripted", { to = to, kind = "noAnswer", name = News.STATION })
        return
    end
    local rng = Rng.new(tostring(State.get().seed) .. ":wknx:" .. math.floor(Util.nowMinutes()))
    Net.toClient(player, "callScripted", { to = to, kind = "answer", lines = Wknx.script(day, rng), name = News.STATION,
        ask = "wknx" })
end

Protocol.register({
    wknxMessage = function(args)
        if type(args.text) ~= "string" or #args.text < 1 or #args.text > 200 then return false, "text 1-200" end
        return true
    end,
    wknxBoard = function() return true end,
})

Net.onServer("wknxMessage", function(player, args)
    local d = data()
    local key, now = Util.playerKey(player), Util.nowMinutes()
    if not Wknx.onAir(math.floor(Util.sinceOutbreak())) then return end
    if d.last[key] and now - d.last[key] < Wknx.GAP then
        return Net.toClient(player, "notify", { kind = "wknx", event = "tooSoon" })
    end
    local text = tostring(args.text):gsub("%c", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return end
    local name = "?"
    pcall(function() name = player:getDescriptor():getForename() end)
    d.last[key] = now
    d.messages[#d.messages + 1] = { name = name, text = text, day = math.floor(Util.sinceOutbreak()) }
    while #d.messages > Wknx.KEEP do table.remove(d.messages, 1) end
    Util.log("WKNX message from", key, ":", text)
    Net.toClient(player, "notify", { kind = "wknx", event = "onAir" })
end)

Net.onServer("wknxBoard", function(player)
    Net.toClient(player, "wknxBoard", { messages = data().messages })
end)

return Wknx
