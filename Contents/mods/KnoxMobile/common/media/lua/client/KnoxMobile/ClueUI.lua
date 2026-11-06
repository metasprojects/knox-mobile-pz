-- Client: reading a dead person's clues and trying what you learned on their phone (0.2.2; server/Clues.lua puts the
-- clues there, Core/Clues says what they are). Right-click their ID card, dog tags, badge or a note to read it, or the
-- phone to turn it over. A code you've read stays known for that phone (player mod data, never listed twice), and the
-- phone's right-click menu offers to try it.
local Clues = require "KnoxMobile/Core/Clues"
local Phones = require "KnoxMobile/Game/Phones"
local Util = require "KnoxMobile/Game/Util"
local Net = require "KnoxMobile/Game/Net"

local ClueUI = {}
KnoxMobile.ClueUI = ClueUI

local T = Util.text
local ID_TYPES = { ["Base.IDcard"] = true, ["Base.IDcard_Female"] = true, ["Base.IDcard_Male"] = true }

-- Codes this character has read for one phone: { { pin, label } }.
function ClueUI.known(player, phoneId)
    local all = player:getModData().KnoxMobileKnownPins
    return type(all) == "table" and all[tostring(phoneId)] or {}
end

function ClueUI.remember(player, phoneId, pin, label)
    if not (phoneId and type(pin) == "string" and pin:match("^%d%d%d%d$")) then return end
    local key = tostring(phoneId)
    local list = ClueUI.known(player, phoneId)
    for _, e in ipairs(list) do if e.pin == pin then return end end
    local copy = {}
    for i, e in ipairs(list) do copy[i] = e end
    copy[#copy + 1] = { pin = pin, label = label }
    -- Kept on the server's copy of the character too (0.2.4): in multiplayer this copy can lose it.
    KnoxMobile.Client.keep(player, "KnoxMobileKnownPins", key, copy)
end

-- The lock screen's (and the tooltip's) one line on where this phone's code is. Short: it has to fit a brick's LCD
-- in two lines.
function ClueUI.hint(item)
    local clue = item:getModData().KnoxMobileClue
    local kind = type(clue) == "table" and clue.kind or "tape"
    if kind == "birthday" then return T("IGUI_KnoxMobile_HintBirthday", "PIN clue: birthday on their ID")
    elseif kind == "note" then return T("IGUI_KnoxMobile_HintNote", "PIN clue: a note on the body")
    elseif kind == "tags" and clue.tags == "badge" then return T("IGUI_KnoxMobile_HintBadge", "PIN clue: their badge")
    elseif kind == "tags" then return T("IGUI_KnoxMobile_HintDogTags", "PIN clue: their dog tags")
    elseif kind == "easy" then return T("IGUI_KnoxMobile_HintEasy", "PIN clue: an easy code")
    elseif kind == "factory" then return T("IGUI_KnoxMobile_HintFactory", "PIN clue: maker's code (manual)")
    elseif kind == "house" then return T("IGUI_KnoxMobile_HintHouse", "PIN clue: a note in that house")
    elseif kind == "car" then return T("IGUI_KnoxMobile_HintCar", "PIN clue: a note in that car")
    elseif kind == "none" then return T("IGUI_KnoxMobile_HintNone", "No clue: crack it (right-click)")
    end
    return T("IGUI_KnoxMobile_HintTape", "PIN clue: the back of the phone")
end

local function popup(player, title, lines)
    local text = "<SIZE:medium> " .. title .. " <LINE> <SIZE:small> " .. table.concat(lines, " <LINE> ")
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local box = ISModalRichText:new(sw / 2 - 200, sh / 2 - 90, 400, 180, text, false, nil, nil, player:getPlayerNum())
    box:initialise()
    box.chatText:paginate()
    box:setHeightToContents()
    box:setY(sh / 2 - box:getHeight() / 2)
    box:setAlwaysOnTop(true)
    box:addToUIManager()
    box:bringToTop()
    return box
end

local function pickUpFirst(player, item)
    return Phones.findById(player, item:getID()) == nil and T("IGUI_KnoxMobile_PickUpFirst", "Pick it up first") or nil
end

-- The phone's right-click menu, for somebody else's locked phone (Menu.lua). option(menu, text, fn, reason).
function ClueUI.phoneOptions(menu, player, item, state, model, option)
    local id = item:getID()
    option(menu, T("IGUI_KnoxMobile_LookBack", "Look at the back"), function() Net.toServer(player, "lookBack", { phoneId = id }) end,
        pickUpFirst(player, item))
    local why = pickUpFirst(player, item)
    if not why and not state.power.on then why = T("IGUI_KnoxMobile_CrackNeedsPower", "Charge it and turn it on first") end
    local until_ = state.security.lockoutUntil
    if not why and until_ and Util.nowMinutes() < until_ then
        why = T("IGUI_KnoxMobile_LockedOut", "Too many tries. Locked for an hour.")
    end
    local tried = {}
    for _, e in ipairs(ClueUI.known(player, id)) do
        tried[e.pin] = true
        option(menu, T("IGUI_KnoxMobile_TryCode", "Try %1 (%2)", e.pin, e.label),
            function() KnoxMobile.Client.setting(item, "unlock", e.pin) end, why)
    end
    -- A maker's manual you've read gives its factory code, for every phone of that kind.
    local factory = Clues.FACTORY[model.family]
    local families = player:getModData().KnoxMobileKnown
    if factory and not tried[factory] and type(families) == "table" and families[model.family] then
        option(menu, T("IGUI_KnoxMobile_TryFactory", "Try the factory code (%1)", factory),
            function() KnoxMobile.Client.setting(item, "unlock", factory) end, why)
    end
end

Net.onClient("lookBack", function(args)
    local player = getPlayer()
    if not player then return end
    if type(args.text) == "string" then
        popup(player, T("IGUI_KnoxMobile_BackTitle", "The back of the phone"), { args.text })
        ClueUI.remember(player, args.phoneId, args.pin, T("IGUI_KnoxMobile_FromBack", "from the back"))
    else
        KnoxMobile.Client.toast(T("IGUI_KnoxMobile_BackNothing", "Nothing written on the back. Only scratches."))
    end
end)

-- Their ID card, dog tags, badge or a note ------------------------------------------------------------------------
local function lookAtCard(player, item)
    local md = item:getModData()
    local lines = { tostring(md.KnoxMobileOwner or ""), T("IGUI_KnoxMobile_CardBorn", "Born %1", tostring(md.KnoxMobileBornDate)) }
    if md.KnoxMobileHome then lines[#lines + 1] = T("IGUI_KnoxMobile_CardHome", "Lives in %1, KY", tostring(md.KnoxMobileHome)) end
    popup(player, T("IGUI_KnoxMobile_CardTitle", "Commonwealth of Kentucky ID"), lines)
    ClueUI.remember(player, md.KnoxMobileCluePhone, Clues.codeFromBorn(md.KnoxMobileBornDate),
        T("IGUI_KnoxMobile_FromBirthday", "their birthday"))
end

local function lookAtTags(player, item)
    local md = item:getModData()
    if md.KnoxMobileTagKind == "badge" then
        popup(player, T("IGUI_KnoxMobile_BadgeTitle", "A badge"),
            { tostring(md.KnoxMobileOwner or ""), T("IGUI_KnoxMobile_BadgeNumber", "Badge no. %1", tostring(md.KnoxMobileTagNumber)) })
        ClueUI.remember(player, md.KnoxMobileCluePhone, Clues.codeFromNumber(md.KnoxMobileTagNumber),
            T("IGUI_KnoxMobile_FromBadge", "their badge number"))
    else
        popup(player, T("IGUI_KnoxMobile_TagsTitle", "Dog tags"),
            { tostring(md.KnoxMobileOwner or ""):upper(), tostring(md.KnoxMobileTagNumber), "US ARMY" })
        ClueUI.remember(player, md.KnoxMobileCluePhone, Clues.codeFromNumber(md.KnoxMobileTagNumber),
            T("IGUI_KnoxMobile_FromTags", "the last 4 on the tags"))
    end
end

local function readNote(player, item)
    local md = item:getModData()
    popup(player, item:getName(), { tostring(md.KnoxMobileClueText or "") })
    ClueUI.remember(player, md.KnoxMobileCluePhone, md.KnoxMobileCluePin, T("IGUI_KnoxMobile_FromNote", "from the note"))
end

Events.OnFillInventoryObjectContextMenu.Add(Util.safe("clue menu", function(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    local item = ISInventoryPane.getActualItems(items)[1]
    if not (player and item) then return end
    local md = item:getModData()
    if not md.KnoxMobileCluePhone then return end
    if ID_TYPES[item:getFullType()] and md.KnoxMobileBornDate then
        context:addOption(T("IGUI_KnoxMobile_LookCard", "Look at the ID card"), nil, function() lookAtCard(player, item) end)
    elseif md.KnoxMobileTagKind == "badge" then
        context:addOption(T("IGUI_KnoxMobile_LookBadge", "Look at the badge"), nil, function() lookAtTags(player, item) end)
    elseif md.KnoxMobileTagKind then
        context:addOption(T("IGUI_KnoxMobile_ReadTags", "Read the dog tags"), nil, function() lookAtTags(player, item) end)
    elseif md.KnoxMobileClueText then
        context:addOption(T("IGUI_KnoxMobile_ReadNote", "Read the note"), nil, function() readNote(player, item) end)
    end
end))

return ClueUI
