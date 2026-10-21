-- Client: what the server says about group chats, the Classifieds board, find my crew, SOS and carrier messages;
-- the "Send SOS" right-click option on a phone; and, for admins, the carrier message (a right-click option on the
-- ground and the chat command "/carrier <text>"). The server checks everything again.
local Phones = require "KnoxMobile/Game/Phones"
local Net = require "KnoxMobile/Game/Net"
local Util = require "KnoxMobile/Game/Util"
local Access = require "KnoxMobile/Game/Access"
local SocialText = require "KnoxMobile/Game/SocialText"
local Crew = require "KnoxMobile/Core/Crew"
local Carrier = require "KnoxMobile/Core/Carrier"

local T = Util.text

-- Per phone id: groups = { id = group }, board = { posts, now, moderator }, crew = { list | error }.
local Social = { groups = {}, board = {}, crew = {} }
KnoxMobile.Social = Social

local function me() return getPlayer() end
local function toast(s) if KnoxMobile.Client then KnoxMobile.Client.toast(s) end end
local function refresh() if KnoxMobile.UI and KnoxMobile.UI.refresh then KnoxMobile.UI.refresh() end end

-- Who a number is on this phone: the contact's name, else the number.
function Social.nameFor(state, number)
    if state and state.sim then
        for _, c in ipairs(state.sim.contacts or {}) do if c.number == number then return c.name end end
        if state.sim.number == number then return T("IGUI_KnoxMobile_Me", "Me") end
    end
    return number or "?"
end

function Social.group(phoneId, id)
    local g = Social.groups[phoneId]
    return g and g[id] or nil
end

function Social.request(command, phone, extra)
    local args = { phoneId = phone:getID() }
    for k, v in pairs(extra or {}) do args[k] = v end
    Net.toServer(me(), command, args)
end

-- Group chats ----------------------------------------------------------------------------------
Net.onClient("groupList", function(args)
    local byId = {}
    for _, g in ipairs(args.groups or {}) do byId[g.id] = g end
    Social.groups[args.phoneId] = byId
    refresh()
end)

Net.onClient("groupResult", function(args)
    if args.status == "failed" then
        toast(T("IGUI_KnoxMobile_GroupFailed", "Group: %1", SocialText.reason(args.reason, args.wait)))
    elseif args.status == "created" then
        toast(T("IGUI_KnoxMobile_GroupMade", "Group %1 started", args.name or ""))
    elseif args.status == "added" then
        toast(T("IGUI_KnoxMobile_GroupAddedOk", "Added to the group"))
    elseif args.status == "removed" then
        toast(T("IGUI_KnoxMobile_GroupRemovedOk", "Taken out of the group"))
    elseif args.status == "left" then
        toast(T("IGUI_KnoxMobile_GroupLeft", "You left the group"))
    elseif args.status == "sent" and (args.queued or 0) > 0 then
        toast(T("IGUI_KnoxMobile_GroupSentSome", "Sent to %1. %2 will get it when they're in reach.", args.delivered or 0, args.queued))
    elseif args.status == "sent" and (args.failed or 0) > 0 then
        toast(T("IGUI_KnoxMobile_GroupSentFailed", "Sent to %1. %2 can't be reached.", args.delivered or 0, args.failed))
    end
    refresh()
end)

-- Classifieds ----------------------------------------------------------------------------------
Net.onClient("boardList", function(args)
    Social.board[args.phoneId] = { posts = args.posts or {}, now = args.now, moderator = args.moderator == true }
    refresh()
end)

Net.onClient("boardResult", function(args)
    if args.status == "failed" then
        toast(T("IGUI_KnoxMobile_BoardFailed", "Classifieds: %1", SocialText.reason(args.reason, args.wait)))
        -- No board yet (the app just opened) or no service: the app says why instead of "Loading".
        if args.reason == "noService" or not Social.board[args.phoneId] then
            Social.board[args.phoneId] = { error = args.reason, posts = {} }
        end
    elseif args.status == "posted" then
        toast(T("IGUI_KnoxMobile_BoardPosted", "Your listing is up"))
    elseif args.status == "removed" then
        toast(T("IGUI_KnoxMobile_BoardRemoved", "Listing taken down"))
    end
    refresh()
end)

-- Find my crew and SOS ------------------------------------------------------------------------
Net.onClient("crewList", function(args)
    Social.crew[args.phoneId] = { list = args.list or {}, error = args.error }
    refresh()
end)

-- The phone shrieks for a while after an SOS: the ring sound, and zombie noise through the usual noise path.
-- It ignores silent mode on purpose.
local function sosRing(radius)
    local Audio = KnoxMobile.Audio
    if not Audio then return end
    Audio.ring = { mode = "ring", radius = math.min(radius or Crew.SOS_RADIUS, Crew.SOS_RADIUS), next = 0,
        untilMs = getTimestampMs() + Crew.SOS_RING_SECONDS * 1000, sound = "KnoxMobileRing" }
end

Net.onClient("sosResult", function(args)
    if args.status == "sent" then
        if (args.delivered or 0) == 0 and (args.queued or 0) == 0 then
            -- Nobody else is out there (single player, or no one with a phone): say so, the ring still lures.
            toast(T("IGUI_KnoxMobile_SosNobody", "No phone answered the SOS. Yours is ringing out loud!"))
        else
            toast(T("IGUI_KnoxMobile_SosSent", "SOS sent to %1 phones (%2 waiting). Your phone is ringing out loud!",
                args.delivered or 0, args.queued or 0))
        end
        sosRing(args.radius)
    else
        toast(T("IGUI_KnoxMobile_SosFailed", "SOS not sent: %1", SocialText.reason(args.reason, args.wait)))
    end
    refresh()
end)

function Social.sendSos(phone)
    Social.request("sos", phone)
end

-- "Send SOS" on a phone's right-click menu: works on a locked phone too, like an emergency call.
Events.OnFillInventoryObjectContextMenu.Add(Util.safe("sos menu", function(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    local item = ISInventoryPane.getActualItems(items)[1]
    if not player or not item or not Phones.isPhone(item) then return end
    local state = Phones.get(item)
    if not (state and state.power.on and state.sim and state.sim.number) then return end
    if not player:getInventory():containsID(item:getID()) then return end
    context:addOption(T("IGUI_KnoxMobile_SendSos", "Send SOS"), nil, function() Social.sendSos(item) end)
end))

-- Carrier messages (admins) --------------------------------------------------------------------
Net.onClient("carrierResult", function(args)
    if args.status == "sent" then
        toast(T("IGUI_KnoxMobile_CarrierSent", "Carrier message sent: %1 phones now, %2 later", args.delivered or 0, args.waiting or 0))
    else
        toast(T("IGUI_KnoxMobile_CarrierFailed", "Carrier message not sent: %1", SocialText.reason(args.reason, args.wait)))
    end
end)

function Social.broadcast(text)
    local body = Carrier.clean(text)
    if not body then toast(SocialText.reason("badText")); return end
    Net.toServer(me(), "carrierBroadcast", { body = body })
end

local function askBroadcast()
    local w, h = 360, 140
    local box = ISTextBox:new((getCore():getScreenWidth() - w) / 2, (getCore():getScreenHeight() - h) / 2, w, h,
        T("IGUI_KnoxMobile_CarrierPrompt", "Carrier message to every phone:"), "", nil, function(_, button)
            if button.internal == "OK" then Social.broadcast(button.parent.entry:getText()) end
        end)
    box:initialise()
    box:addToUIManager()
end

Events.OnFillWorldObjectContextMenu.Add(Util.safe("carrier menu", function(playerNum, context, _, test)
    if test then return end
    local player = getSpecificPlayer(playerNum)
    if not player or not Access.canBroadcast(player) then return end
    context:addOption(T("IGUI_KnoxMobile_CarrierMenu", "Knox Mobile: carrier message..."), nil, askBroadcast)
end))

-- "/carrier <text>" in chat. The game's chat sends unknown /commands to the server, which would answer
-- "unknown command"; this one is caught first. Everything else goes through the game's own handler.
Social.CHAT_COMMAND = "/carrier"
function Social.chatCommand(text)
    if type(text) ~= "string" then return false end
    local body = text:match("^" .. Social.CHAT_COMMAND .. "%s+(.+)$")
    if not body and text:match("^" .. Social.CHAT_COMMAND .. "%s*$") == nil then return false end
    if not Access.canBroadcast(me()) then return false end -- not ours to catch: the server says "unknown command"
    if body then Social.broadcast(body) else toast(T("IGUI_KnoxMobile_CarrierUsage", "Usage: /carrier your message")) end
    return true
end

if ISChat and ISChat.onCommandEntered then
    local gameHandler = ISChat.onCommandEntered
    ISChat.onCommandEntered = function(...)
        local chat = ISChat.instance
        local text = chat and chat.textEntry and chat.textEntry:getText()
        if Social.chatCommand(text) then
            chat:unfocus()
            return
        end
        return gameHandler(...)
    end
end

return Social
