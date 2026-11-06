-- Client: photo boards (after 0.3.0, server/PhotoBoards.lua). Right-click the ground by a board you set down: look at
-- it, or pin an instant photo from your bags. On the board, click a photo to take it down.
local Instant = require "KnoxMobile/Core/Instant"
local Util = require "KnoxMobile/Game/Util"
local Mod = require "KnoxMobile/Core/Mod"
local Net = require "KnoxMobile/Game/Net"
require "KnoxMobile/InstantCamera"

local T = Util.text
local View = { panel = nil }
KnoxMobile.PhotoBoardView = View

local COLS, ROWS, CELL, GAP, PAD, TOP = 4, 3, 112, 10, 16, 34
local W = PAD * 2 + COLS * CELL + (COLS - 1) * GAP
local H = TOP + PAD + ROWS * (CELL + 22) + (ROWS - 1) * GAP

KnoxMobilePhotoBoardPanel = ISPanelJoypad:derive("KnoxMobilePhotoBoardPanel")
local Panel = KnoxMobilePhotoBoardPanel

function Panel:new(player, board, photos)
    -- At the left, not the middle: in the isometric view the middle is where you and the board are (PC re-check).
    local o = ISPanelJoypad.new(self, math.max(20, math.floor(getCore():getScreenWidth() * 0.06)),
        math.max(40, (getCore():getScreenHeight() - H) / 2), W, H)
    o.player, o.board, o.photos = player, board, photos or {}
    o.backgroundColor = { r = 0.62, g = 0.45, b = 0.28, a = 1 } -- cork
    o.borderColor = { r = 0.35, g = 0.24, b = 0.14, a = 1 }
    o.moveWithMouse = true
    return o
end

local function cellAt(i)
    local c, r = Mod.floor(i - 1, COLS), math.floor((i - 1) / COLS)
    return PAD + c * (CELL + GAP), TOP + r * (CELL + 22 + GAP)
end

function Panel:prerender()
    ISPanelJoypad.prerender(self)
    self:drawText(T("IGUI_KnoxMobile_PhotoBoardTitle", "Photo board (%1 of %2)", #self.photos, COLS * ROWS), PAD, 10,
        1, 0.95, 0.85, 1, UIFont.Small)
    self:drawTextRight(T("IGUI_KnoxMobile_PhotoBoardHint", "Click a photo to take it down"), W - PAD, 10,
        1, 0.95, 0.85, 0.8, UIFont.Small)
    for i = 1, COLS * ROWS do
        local x, y = cellAt(i)
        local p = self.photos[i]
        if p then
            self:drawRect(x, y, CELL, CELL + 18, 1, 0.95, 0.94, 0.9)
            KnoxMobile.Instant.drawPhoto(self, p, x + 6, y + 6, CELL - 12)
            local cap = tostring(p.caption or "")
            if getTextManager():MeasureStringX(UIFont.Small, cap) > CELL - 8 then cap = cap:sub(1, 14) .. "..." end
            self:drawText(cap, x + 4, y + CELL, 0.15, 0.15, 0.2, 1, UIFont.Small)
            self:drawRect(x + CELL / 2 - 3, y - 3, 6, 6, 1, 0.8, 0.15, 0.15) -- the pin
        else
            self:drawRectBorder(x, y, CELL, CELL + 18, 0.3, 0.3, 0.2, 0.1)
        end
    end
end

function Panel:onMouseDown(x, y)
    for i, _ in ipairs(self.photos) do
        local cx, cy = cellAt(i)
        if x >= cx and x <= cx + CELL and y >= cy and y <= cy + CELL + 18 then
            Net.toServer(self.player, "unpinPhoto", { board = self.board, index = i })
            return true
        end
    end
    return ISPanelJoypad.onMouseDown(self, x, y)
end

function Panel:close()
    self:removeFromUIManager()
    if View.panel == self then View.panel = nil end
end
function Panel:onRightMouseDown() self:close(); return true end
function Panel:onJoypadDown(button)
    if button == Joypad.AButton and self.photos[1] then
        Net.toServer(self.player, "unpinPhoto", { board = self.board, index = #self.photos })
    elseif button == Joypad.BButton then
        self:close()
    end
end

Net.onClient("photoBoard", function(args)
    local player = getSpecificPlayer(0)
    if View.panel and View.panel.board == args.board then
        View.panel.photos = args.photos or {}
        return
    end
    if View.panel then View.panel:close() end
    local p = Panel:new(player, args.board, args.photos)
    p:initialise()
    p:addToUIManager()
    -- Not always on top (PC test: a "Pin a photo" picked over the open board landed on the board and was lost).
    p:bringToTop()
    View.panel = p
    if JoypadState and player and JoypadState.players[player:getPlayerNum() + 1] then setJoypadFocus(player:getPlayerNum(), p) end
end)

-- Boards set down on the squares under the cursor.
local function boardsAt(worldobjects)
    local out, seen = {}, {}
    for _, obj in ipairs(worldobjects) do
        local sq = obj.getSquare and obj:getSquare()
        if sq and not seen[sq] then
            seen[sq] = true
            local list = sq:getWorldObjects()
            for i = 0, list:size() - 1 do
                local item = list:get(i):getItem()
                local id = item and item:getFullType() == "KnoxMobile.PhotoBoard" and item:getModData().KnoxMobilePhotoBoardId
                if id then out[#out + 1] = { id = id, sq = sq } end
            end
        end
    end
    return out
end

Events.OnFillWorldObjectContextMenu.Add(Util.safe("photo board menu", function(playerNum, context, worldobjects, test)
    if test then return end
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    for _, b in ipairs(boardsAt(worldobjects)) do
        local id = b.id
        -- The server's reach (PhotoBoards.REACH, 3 squares): past it the options are greyed with why (PC re-check:
        -- "Look at the photo board" did nothing from 4.6 squares).
        local far = math.abs(player:getX() - b.sq:getX()) > 3 or math.abs(player:getY() - b.sq:getY()) > 3
            or math.floor(player:getZ()) ~= b.sq:getZ()
        local look = context:addOption(T("IGUI_KnoxMobile_PhotoBoardLook", "Look at the photo board"), player,
            function() Net.toServer(player, "photoBoardOpen", { board = id }) end)
        if far then
            look.notAvailable = true
            pcall(function()
                local tip = ISWorldObjectContextMenu.addToolTip()
                tip.description = T("IGUI_KnoxMobile_PhotoBoardFar", "Too far: step closer to the board.")
                look.toolTip = tip
            end)
        end
        local photos = {}
        local list = player:getInventory():getAllTypeRecurse(Instant.PHOTO)
        for i = 0, list:size() - 1 do photos[#photos + 1] = list:get(i) end
        local pin = context:addOption(T("IGUI_KnoxMobile_PhotoBoardPin", "Pin a photo"), nil, nil)
        if #photos == 0 or far then
            pin.notAvailable = true
        else
            local sub = ISContextMenu:getNew(context)
            context:addSubMenu(pin, sub)
            for _, ph in ipairs(photos) do
                sub:addOption(ph:getName(), player,
                    function() Net.toServer(player, "pinPhoto", { board = id, photoId = ph:getID() }) end)
            end
        end
    end
end))

return View
