--[[--
Endless Dungeon: the game screen.

Two kinds of screens:
  * the run: stats bar, the 15x15 map, messages, and the controls (or a choice to make)
  * everything else (camp, encyclopedia, shops, pets, classes, achievements): a list of
    text and buttons, split into pages that fit the screen

Tap a square on the map to move or attack (far squares walk you there), or swipe on the
map to step in that direction. Page-turn keys and swipes turn pages in the lists.
--]]

local Blitbuffer = require("ffi/blitbuffer")
local ButtonDialog = require("ui/widget/buttondialog")
local ButtonTable = require("ui/widget/buttontable")
local CenterContainer = require("ui/widget/container/centercontainer")
local ConfirmBox = require("ui/widget/confirmbox")
local DataStorage = require("datastorage")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InfoMessage = require("ui/widget/infomessage")
local InputContainer = require("ui/widget/container/inputcontainer")
local InputDialog = require("ui/widget/inputdialog")
local LuaSettings = require("luasettings")
local RenderText = require("ui/rendertext")
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextViewer = require("ui/widget/textviewer")
local TextWidget = require("ui/widget/textwidget")
local TitleBar = require("ui/widget/titlebar")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Widget = require("ui/widget/widget")
local logger = require("logger")
local _ = require("gettext")
local Screen = Device.screen

local E = require("dungeon_engine")

local SAVE_FILE = DataStorage:getSettingsDir() .. "/endless_dungeon.lua"
local CODE_FILE = DataStorage:getFullDataDir() .. "/endless_dungeon_save.txt"

local BLACK, WHITE = Blitbuffer.COLOR_BLACK, Blitbuffer.COLOR_WHITE
local DARK, GRAY, LIGHT = Blitbuffer.COLOR_DARK_GRAY, Blitbuffer.COLOR_GRAY, Blitbuffer.COLOR_LIGHT_GRAY
local GRAY_9, GRAY_E = Blitbuffer.COLOR_GRAY_9 or GRAY, Blitbuffer.COLOR_GRAY_E or LIGHT

-- Font sizes are given unscaled, like everywhere in KOReader.
local FS = { h2 = 24, h3 = 21, text = 19, small = 17, button = 18, map_text = 17 }

local function face(size, bold) return Font:getFace(bold and "tfont" or "cfont", size) end
-- A face whose real size is px pixels (for the map, which is sized in pixels).
local function pxFace(name, px)
    local unscaled = math.max(6, math.floor(px * 100 / Screen:scaleBySize(100) + 0.5))
    return Font:getFace(name, unscaled)
end

-- ================= THE MAP =================
local MapWidget = Widget:extend{
    cell = 32,
    border = 2,
}

function MapWidget:getSize()
    local s = self.cell * E.W + 2 * self.border
    return Geom:new{ w = s, h = s }
end

local function dashedBorder(bb, x, y, w, h, t, color, dash)
    dash = dash or math.max(2, math.floor(w / 6))
    local i = 0
    while i < w do
        local l = math.min(dash, w - i)
        bb:paintRect(x + i, y, l, t, color)
        bb:paintRect(x + i, y + h - t, l, t, color)
        i = i + 2 * dash
    end
    i = 0
    while i < h do
        local l = math.min(dash, h - i)
        bb:paintRect(x, y + i, t, l, color)
        bb:paintRect(x + w - t, y + i, t, l, color)
        i = i + 2 * dash
    end
end

function MapWidget:paintTo(bb, x, y)
    local size = self:getSize()
    self.dimen = Geom:new{ x = x, y = y, w = size.w, h = size.h }
    local s, b = self.cell, self.border
    bb:paintRect(x, y, size.w, size.h, WHITE)
    bb:paintBorder(x, y, size.w, size.h, b, BLACK)
    local ox, oy = x + b, y + b
    local blasts = E.blastSet()
    local thin = math.max(1, math.floor(s / 24))
    local thick = math.max(2, math.floor(s / 12))
    self.faces = self.faces or {}
    for my = 0, E.H - 1 do
        for mx = 0, E.W - 1 do
            local c = E.cellLook(mx, my, blasts)
            local cx, cy = ox + mx * s, oy + my * s
            local fg = BLACK
            if c.base == "wall" then
                bb:paintRect(cx, cy, s, s, c.mon and GRAY_9 or DARK)
                if c.mon then dashedBorder(bb, cx, cy, s, s, thick, BLACK) end
            elseif c.base == "floor" or c.base == "dim" then
                if c.base == "dim" then bb:paintRect(cx, cy, s, s, GRAY_E); fg = DARK end
                if c.tile == 2 then bb:paintRect(cx, cy, s, s, GRAY_9); fg = WHITE        -- lava
                elseif c.tile == 5 then bb:paintRect(cx, cy, s, s, GRAY_E) end             -- water, web, mud, sand
                bb:paintBorder(cx, cy, s, s, thin, LIGHT)
                if c.tile == 9 then bb:paintBorder(cx, cy, s, s, thick, BLACK) end          -- portal
                if c.player then
                    bb:paintRect(cx, cy, s, s, BLACK); fg = WHITE
                elseif c.mon then
                    if c.boss then
                        bb:paintRect(cx, cy, s, s, BLACK); fg = WHITE
                        bb:paintBorder(cx + thick, cy + thick, s - 2 * thick, s - 2 * thick, thin, WHITE)
                    elseif c.frozen then
                        dashedBorder(bb, cx, cy, s, s, thick, BLACK)
                    else
                        bb:paintBorder(cx, cy, s, s, thick, BLACK)
                        if c.champ then bb:paintBorder(cx + 2 * thick, cy + 2 * thick, s - 4 * thick, s - 4 * thick, thin, BLACK) end
                    end
                elseif c.elevator then
                    bb:paintBorder(cx, cy, s, s, thin * 2, BLACK)
                    bb:paintBorder(cx + 3 * thin, cy + 3 * thin, s - 6 * thin, s - 6 * thin, thin, BLACK)
                elseif c.mimic then
                    dashedBorder(bb, cx, cy, s, s, thick, BLACK)
                end
                if c.blast then dashedBorder(bb, cx, cy, s, s, thick, BLACK, math.max(2, thick)) end
            end
            if c.ch ~= "" then
                local n = #c.ch
                local px = math.floor(s * (n >= 3 and 0.36 or (n == 2 and 0.5 or 0.72)))
                local f = self.faces[px]
                if not f then f = pxFace("infont", px); self.faces[px] = f end
                local w = RenderText:sizeUtf8Text(0, s, f, c.ch, true, true).x
                local baseline = cy + math.floor(s / 2 + px * 0.36)
                RenderText:renderUtf8Text(bb, cx + math.floor((s - w) / 2), baseline, f, c.ch, true, true, fg)
            end
        end
    end
end

-- Which map square is at this screen position (or nil).
function MapWidget:cellAt(pos)
    if not self.dimen or not pos then return nil end
    local x = math.floor((pos.x - self.dimen.x - self.border) / self.cell)
    local y = math.floor((pos.y - self.dimen.y - self.border) / self.cell)
    if x < 0 or y < 0 or x >= E.W or y >= E.H then return nil end
    return x, y
end

-- ================= A TAPPABLE TEXT BOX (choices with long text, the message log) =================
local TapBox = InputContainer:extend{
    text = "",
    width = 100,
    height = nil,       -- fixed height (text that doesn't fit ends with "...")
    bold = false,
    font_size = FS.text,
    bordersize = 0,
    callback = nil,
    enabled = true,
    shade = false,
}

function TapBox:init()
    local pad = Size.padding.default
    local inner_w = self.width - 2 * (self.bordersize + pad)
    local box = TextBoxWidget:new{
        text = self.text,
        face = face(self.font_size, self.bold),
        bold = self.bold,
        width = inner_w,
        height = self.height and (self.height - 2 * (self.bordersize + pad)) or nil,
        height_overflow_show_ellipsis = self.height ~= nil,
        fgcolor = self.enabled and BLACK or DARK,
        bgcolor = self.shade and LIGHT or WHITE,
    }
    self[1] = FrameContainer:new{
        bordersize = self.bordersize,
        padding = pad,
        margin = 0,
        radius = self.bordersize > 0 and Size.radius.button or nil,
        background = self.shade and LIGHT or WHITE,
        width = self.width,
        height = self.height,
        box,
    }
    self.dimen = Geom:new{ x = 0, y = 0, w = self[1]:getSize().w, h = self[1]:getSize().h }
    self.ges_events = {
        TapBox = { GestureRange:new{ ges = "tap", range = function() return self.dimen end } },
    }
end

function TapBox:onTapBox()
    if self.callback and self.enabled then
        self.callback()
        return true
    end
end

-- ================= THE GAME SCREEN =================
local GameScreen = InputContainer:extend{
    name = "EndlessDungeon",
    covers_fullscreen = true,
}

function GameScreen:init()
    self.dimen = Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }
    self.subpage = 1
    self._save_task = function() self:saveNow() end
    self.settings = LuaSettings:open(SAVE_FILE)
    math.randomseed(os.time())

    E.saveHook = function() self:scheduleSave() end
    E.askHook = function(question, yes)
        UIManager:show(ConfirmBox:new{
            text = question,
            ok_text = _("Yes"),
            ok_callback = function() yes(); self:refresh(true) end,
        })
    end
    local ok, err = pcall(E.loadGame, self.settings:readSetting("save"))
    if not ok then
        logger.warn("Endless Dungeon: could not load the save, starting fresh:", err)
        E.loadGame(nil)
    end
    E.render()

    if Device:hasKeys() then
        self.key_events = {
            Close = { { Device.input.group.Back } },
            NextPage = { { Device.input.group.PgFwd } },
            PrevPage = { { Device.input.group.PgBack } },
        }
        if Device:hasDPad() then   -- Kindles with a 5-way pad can walk with it
            self.key_events.StepUp = { { "Up" }, event = "Step", args = { 0, -1 } }
            self.key_events.StepDown = { { "Down" }, event = "Step", args = { 0, 1 } }
            self.key_events.StepLeft = { { "Left" }, event = "Step", args = { -1, 0 } }
            self.key_events.StepRight = { { "Right" }, event = "Step", args = { 1, 0 } }
            self.key_events.GoDown = { { "Press" } }   -- like Enter in the web version
        end
    end
    self.ges_events = {
        TapMap = { GestureRange:new{ ges = "tap", range = function() return self.map and self.map.dimen or Geom:new{} end } },
        Swipe = { GestureRange:new{ ges = "swipe", range = function() return self.dimen end } },
    }
    self:build()
end

-- Saving after every move would wear the flash memory and slow the Kindle down,
-- so moves are saved a couple of seconds later (and always when you leave the game).
function GameScreen:scheduleSave()
    if not self.save_pending then
        self.save_pending = true
        UIManager:scheduleIn(2, self._save_task)
    end
end
function GameScreen:saveNow()
    self.save_pending = false
    if E.S then
        self.settings:saveSetting("save", E.S)
        self.settings:flush()
    end
end

-- Wraps a button's action so the screen is redrawn after it.
function GameScreen:wrap(fn)
    return function()
        if fn then fn() end
        self:refresh()
    end
end

function GameScreen:refresh(full)
    self.refresh_count = (self.refresh_count or 0) + 1
    if self.refresh_count % 20 == 0 then full = true end
    self:build()
    local mode = (full or self.full_refresh or E.newFloor) and "full" or "ui"
    E.newFloor = false
    self.full_refresh = false
    UIManager:setDirty(self, function() return mode, self.dimen end)
end

function GameScreen:build()
    local view = E.currentView()
    if view ~= self.last_view then
        self.subpage = 1
        self.full_refresh = true
        self.height_cache = {}
    end
    self.last_view = view
    if E.ui.bookTop then
        E.ui.bookTop = false
        self.subpage = 1
    end
    self.map = nil
    if self[1] then self[1]:free() end
    if view == "run" then
        self[1] = self:buildRun()
    else
        self[1] = self:buildPage(E.page())
    end
end

function GameScreen:paintTo(bb, x, y)
    bb:paintRect(x, y, self.dimen.w, self.dimen.h, WHITE)
    InputContainer.paintTo(self, bb, x, y)
end

-- ----------------- the run -----------------
function GameScreen:dpad()
    local r = E.S.run
    local onStairs = r.px == r.sx and r.py == r.sy
    local onElev = E.onElevator()
    local sc = E.scrollCount()
    local fs = FS.button
    local function b(text, fn, enabled, main)
        return { text = text, callback = self:wrap(fn), enabled = enabled ~= false, font_size = fs,
                 background = main and LIGHT or nil }
    end
    local rows = {}
    local c = E.activeChar()
    if c then
        local ready = E.burstReady()
        local first = c.name:match("^%S+")
        table.insert(rows, {
            b(_("Switch") .. " (" .. first .. ")", function() E.openSwap() end, #E.S.party > 1),
            b(_("Burst") .. " " .. math.floor(E.energyOf(c.i)) .. "/" .. c.cost, function() E.useBurst() end, ready, ready),
        })
    end
    local grid = {
        { b(_("Potion") .. " (" .. r.potions .. ")", function() E.drink() end, r.potions >= 1),
          b("\u{2191}", function() E.act(0, -1) end),
          b(_("Scrolls") .. " (" .. sc .. ")", function() E.openBag() end, sc >= 1) },
        { b("\u{2190}", function() E.act(-1, 0) end),
          b(_("Wait"), function() E.act(0, 0) end),
          b("\u{2192}", function() E.act(1, 0) end) },
        { b(_("Elevator"), function() E.openElevator() end, onElev, onElev),
          b("\u{2193}", function() E.act(0, 1) end),
          b(_("Go down"), function() E.descend() end, onStairs, onStairs) },
        { b(_("Info"), function() self:showInfo() end),
          b(_("Encyclopedia"), function() E.openBook() end),
          b(_("Menu"), function() self:showRunMenu() end) },
    }
    for _, row in ipairs(grid) do table.insert(rows, row) end
    return rows
end

-- Choices in a side panel: long ones become text boxes, short ones share a row.
function GameScreen:choiceWidgets(rows, width)
    local group = VerticalGroup:new{ align = "left" }
    for _, row in ipairs(rows) do
        if #row == 1 then
            local btn = row[1]
            table.insert(group, TapBox:new{
                text = btn.text, width = width, bordersize = Size.border.button, font_size = FS.small,
                bold = btn.main, enabled = not btn.off, shade = btn.main, callback = self:wrap(btn.cb),
            })
            table.insert(group, VerticalSpan:new{ width = Size.padding.small })
        else
            local specs = {}
            for _, btn in ipairs(row) do
                table.insert(specs, { text = btn.text, enabled = not btn.off and not btn.label, font_size = FS.button,
                                      background = btn.main and LIGHT or nil, callback = self:wrap(btn.cb) })
            end
            table.insert(group, ButtonTable:new{ width = width, buttons = { specs }, zero_sep = false, show_parent = self })
        end
    end
    return group
end

function GameScreen:buildRun()
    local sw, sh = self.dimen.w, self.dimen.h
    local pad = Size.padding.large
    local inner = sw - 2 * pad

    -- stats bar
    local line1, line2, status = E.runBar()
    if #status > 0 then line2 = line2 .. "   " .. table.concat(status, ", "):upper() end
    local bar = VerticalGroup:new{
        align = "left",
        TextWidget:new{ text = line1, face = face(FS.text, true), bold = true, max_width = inner },
        TextBoxWidget:new{ text = line2, face = face(FS.small), width = inner },
    }

    -- controls, or a choice to make
    local side = E.runSide()
    local controls, panelText
    if side then
        controls = self:choiceWidgets(side.rows, inner)
        local title = side.title:upper() .. (side.verdict and (": " .. side.verdict) or "")
        panelText = title .. "\n" .. table.concat(side.lines or {}, "\n")
    else
        controls = ButtonTable:new{ width = inner, buttons = self:dpad(), zero_sep = true, show_parent = self }
    end

    -- the message area: messages and the bounty, or the panel's text
    local probe = TextBoxWidget:new{ text = "Ag", face = face(FS.small), width = inner }
    local line_h = probe:getSize().h
    probe:free()
    local function textHeight(text)
        local t = TextBoxWidget:new{ text = text, face = face(FS.small), width = inner - 2 * Size.padding.default }
        local h = t:getSize().h
        t:free()
        return h + 2 * Size.padding.default
    end

    local bar_h, ctl_h = bar:getSize().h, controls:getSize().h
    local gaps = 4 * Size.padding.small
    local min_msg
    if panelText then
        -- as much room as the panel's text needs (the map gets smaller for a moment)
        min_msg = math.max(line_h * 3, math.min(textHeight(panelText), line_h * 10)) + 2 * Size.padding.default
    else
        -- always the same, so the map doesn't change size from turn to turn
        min_msg = line_h * 5 + 2 * Size.padding.default
    end
    local map_avail = sh - bar_h - ctl_h - min_msg - gaps - 2 * pad
    local cell = math.floor(math.min(inner - 4, map_avail - 4) / E.W)
    cell = math.max(cell, 12)
    self.map = MapWidget:new{ cell = cell }
    local map_h = self.map:getSize().h
    local msg_h = math.max(line_h + 2 * Size.padding.default, sh - bar_h - ctl_h - map_h - gaps - 2 * pad)

    local msg, full_text
    if panelText then
        msg, full_text = panelText, panelText
    else
        local log = E.runLog()
        local head, lines = {}, {}
        if log.hpchange then table.insert(head, log.hpchange) end
        for _, l in ipairs(log.lines) do table.insert(lines, (log.combat and "- " or "") .. l) end
        local bl = E.bountyLine()
        local all = {}
        for _, l in ipairs(head) do table.insert(all, l) end
        if log.combat then table.insert(all, _("Combat log:")) end
        if log.earlier then table.insert(all, "..." .. log.earlier .. " earlier messages") end
        for _, l in ipairs(lines) do table.insert(all, l) end
        if bl then table.insert(all, bl) end
        full_text = table.concat(all, "\n")
        msg = full_text
        if textHeight(msg) > msg_h then
            -- too long: keep the HP change, then the newest messages that fit
            local shown = {}
            for i = #lines, 1, -1 do
                local try = {}
                for _, l in ipairs(head) do table.insert(try, l) end
                table.insert(try, _("Combat log (tap to see all):"))
                table.insert(try, "...")
                for j = i, #lines do table.insert(try, lines[j]) end
                if textHeight(table.concat(try, "\n")) > msg_h then break end
                shown = try
            end
            if #shown == 0 then shown = { lines[#lines] or "" } end
            msg = table.concat(shown, "\n")
        end
    end
    local msgbox = TapBox:new{
        text = msg, width = inner, height = msg_h, font_size = FS.small,
        callback = function()   -- the whole message, when it doesn't fit
            UIManager:show(TextViewer:new{ title = _("Messages"), text = full_text })
        end,
    }

    local content = VerticalGroup:new{
        align = "center",
        bar,
        VerticalSpan:new{ width = Size.padding.small },
        CenterContainer:new{ dimen = Geom:new{ w = inner, h = map_h }, self.map },
        VerticalSpan:new{ width = Size.padding.small },
        msgbox,
        VerticalSpan:new{ width = Size.padding.small },
        controls,
    }
    return FrameContainer:new{ bordersize = 0, padding = pad, margin = 0, background = WHITE, content }
end

function GameScreen:showInfo()
    UIManager:show(TextViewer:new{ title = _("This floor"), text = E.runInfo() })
end

function GameScreen:showRunMenu()
    local dialog
    dialog = ButtonDialog:new{
        buttons = {
            { { text = _("How to play"), callback = function() UIManager:close(dialog); self:showRules() end } },
            { { text = _("End run (keep your gold)"), callback = function() UIManager:close(dialog); E.giveUp(); self:refresh(true) end } },
            { { text = _("Leave the game (your run is saved)"), callback = function() UIManager:close(dialog); self:onClose() end } },
        },
    }
    UIManager:show(dialog)
end

function GameScreen:showRules()
    UIManager:show(TextViewer:new{ title = _("How to play"), text = E.rulesText() })
end

function GameScreen:onTapMap(_, ges)
    if E.currentView() ~= "run" or not self.map then return false end
    local x, y = self.map:cellAt(ges.pos)
    if not x then return false end
    E.tapCell(x, y)
    self:refresh()
    return true
end

function GameScreen:onStep(d)
    if E.currentView() ~= "run" or E.blocked() then return false end
    E.act(d[1], d[2])
    self:refresh()
    return true
end

function GameScreen:onGoDown()
    if E.currentView() ~= "run" then return false end
    E.descend()
    self:refresh()
    return true
end

function GameScreen:onSwipe(_, ges)
    local dir = ges.direction
    if E.currentView() == "run" then
        local d = ({ north = { 0, -1 }, south = { 0, 1 }, west = { -1, 0 }, east = { 1, 0 } })[dir]
        if d and not E.blocked() then
            E.act(d[1], d[2])
            self:refresh()
            return true
        end
        return false
    end
    if dir == "west" or dir == "north" then return self:onNextPage() end
    if dir == "east" or dir == "south" then return self:onPrevPage() end
end

-- ----------------- the list screens -----------------
-- Measures how wide a button needs to be, to pack rows of buttons.
local function buttonWidth(text)
    local tw = TextWidget:new{ text = text, face = face(FS.button, true), bold = true }
    local w = tw:getSize().w + 2 * Size.padding.button + Screen:scaleBySize(12)
    tw:free()
    return w
end

function GameScreen:buttonRows(btns, width, as_tabs, compact)
    local rows, row, used = {}, {}, 0
    local max_per_row = as_tabs and 4 or 5
    for _, b in ipairs(btns) do
        local w = buttonWidth(b.text)
        if #row > 0 and (used + w > width or #row >= max_per_row) then
            table.insert(rows, row); row = {}; used = 0
        end
        table.insert(row, b); used = used + w
    end
    if #row > 0 then table.insert(rows, row) end
    local specs = {}
    for _, r in ipairs(rows) do
        local srow = {}
        for _, b in ipairs(r) do
            local cb = b.cb
            if b.special then cb = function() self:special(b.special) end end
            table.insert(srow, { text = b.text, enabled = not b.off and not b.label, font_size = FS.button,
                                 background = b.main and LIGHT or nil, callback = self:wrap(cb) })
        end
        table.insert(specs, srow)
    end
    if #btns == 1 and not btns[1].main and not as_tabs then compact = true end
    if compact then
        -- a small framed button (or two) under an entry, instead of a full-width row
        local bt = ButtonTable:new{ width = width - 2 * Size.border.button, buttons = specs, zero_sep = false,
                                    shrink_unneeded_width = true, show_parent = self }
        return FrameContainer:new{ bordersize = Size.border.button, radius = Size.radius.button, padding = 0, margin = 0, bt }
    end
    return ButtonTable:new{ width = width, buttons = specs, zero_sep = false, show_parent = self }
end

function GameScreen:itemWidget(it, width)
    if it.kind == "h2" or it.kind == "h3" then
        return TextBoxWidget:new{ text = it.text, face = face(it.kind == "h2" and FS.h2 or FS.h3, true), bold = true, width = width }
    elseif it.kind == "p" then
        if it.style == "status" then
            return FrameContainer:new{
                bordersize = Size.border.thick, padding = Size.padding.default, margin = 0, width = width,
                TextBoxWidget:new{ text = it.text, face = face(FS.text, true), bold = true,
                                   width = width - 2 * (Size.border.thick + Size.padding.default) },
            }
        end
        return TextBoxWidget:new{ text = it.text, face = face(it.style == "small" and FS.small or FS.text), width = width }
    elseif it.kind == "buttons" then
        return self:buttonRows(it.buttons, width, it.tabs)
    elseif it.kind == "entry" then
        local g = VerticalGroup:new{ align = "left" }
        local title = it.title .. (it.badge and ("   [" .. it.badge .. "]") or "")
        table.insert(g, TextBoxWidget:new{ text = title, face = face(FS.text, true), bold = true, width = width })
        if #it.lines > 0 then
            table.insert(g, TextBoxWidget:new{ text = table.concat(it.lines, "\n"), face = face(FS.small), width = width })
        end
        if it.buttons and #it.buttons > 0 then
            table.insert(g, VerticalSpan:new{ width = Size.padding.small })
            table.insert(g, self:buttonRows(it.buttons, width, false, true))
        end
        return FrameContainer:new{
            bordersize = 0, padding = 0, padding_top = Size.padding.small, padding_bottom = Size.padding.small,
            margin = 0, width = width, g,
        }
    end
    return VerticalSpan:new{ width = 0 }
end

-- Splits the list into screen pages that fit, and shows the current one.
function GameScreen:buildPage(p)
    local sw, sh = self.dimen.w, self.dimen.h
    local pad = Size.padding.large
    local width = sw - 2 * pad
    local view = E.currentView()

    local title = TitleBar:new{
        width = sw,
        fullscreen = true,
        with_bottom_line = true,
        title = p.title,
        close_callback = function() self:goBack() end,
        show_parent = self,
    }

    self.page_count = 1
    local footer_probe = ButtonTable:new{ width = width, buttons = { { { text = "<", enabled = false }, { text = "1 / 1", enabled = false }, { text = ">", enabled = false } } }, show_parent = self }
    local footer_h = footer_probe:getSize().h
    footer_probe:free()
    local avail = sh - title:getSize().h - footer_h - 2 * pad - Size.padding.default

    -- lay out all items, breaking into pages. Heights are remembered, so turning pages
    -- only builds what's on the new page (much faster on a Kindle).
    self.height_cache = self.height_cache or {}
    local items = {}
    for _, it in ipairs(p.items) do
        if it.kind == "p" and it.text:find("\n") and it.style ~= "status" then
            -- long paragraphs can break across pages line by line
            for line in (it.text .. "\n"):gmatch("(.-)\n") do table.insert(items, { kind = "p", text = line, style = it.style }) end
        else
            table.insert(items, it)
        end
    end
    local function signature(it)
        local parts = { it.kind, it.style or "", it.text or it.title or "", it.badge or "", tostring(it.tabs) }
        for _, l in ipairs(it.lines or {}) do table.insert(parts, l) end
        for _, b in ipairs(it.buttons or {}) do table.insert(parts, b.text) end
        return table.concat(parts, "\1")
    end
    local gap = Size.padding.default
    local built = {}
    local function heightOf(i)
        local sig = signature(items[i])
        local h = self.height_cache[sig]
        if not h then
            local w = self:itemWidget(items[i], width)
            h = w:getSize().h
            self.height_cache[sig] = h
            built[i] = w
        end
        return h + gap
    end
    local pages, cur, used = {}, {}, 0
    local pending, pending_h = {}, 0   -- headings wait to be placed with the item after them
    local function place(list, h)
        if #cur > 0 and used + h > avail then
            table.insert(pages, cur); cur = {}; used = 0
        end
        for _, i in ipairs(list) do table.insert(cur, i) end
        used = used + h
    end
    for i, it in ipairs(items) do
        local h = heightOf(i)
        table.insert(pending, i); pending_h = pending_h + h
        local keep = it.kind == "h2" or it.kind == "h3" or (it.kind == "p" and it.style == "small")
        if not (keep and pending_h < avail / 3) then
            place(pending, pending_h)
            pending, pending_h = {}, 0
        end
    end
    if #pending > 0 then place(pending, pending_h) end
    if #cur > 0 then table.insert(pages, cur) end
    if #pages == 0 then pages = { {} } end
    self.page_count = #pages
    self.subpage = math.max(1, math.min(self.subpage, #pages))

    local body = VerticalGroup:new{ align = "left" }
    local on_page = {}
    for _, i in ipairs(pages[self.subpage]) do
        on_page[i] = true
        table.insert(body, built[i] or self:itemWidget(items[i], width))
        table.insert(body, VerticalSpan:new{ width = gap })
    end
    for i, w in pairs(built) do if not on_page[i] then w:free() end end

    local footer = ButtonTable:new{
        width = width,
        zero_sep = true,
        show_parent = self,
        buttons = { {
            { text = "\u{25C0} " .. _("Back"), enabled = self.subpage > 1, callback = function() self:onPrevPage() end },
            { text = self.subpage .. " / " .. #pages, enabled = false },
            { text = _("Next") .. " \u{25B6}", enabled = self.subpage < #pages, callback = function() self:onNextPage() end },
        } },
    }
    local body_frame = FrameContainer:new{
        bordersize = 0, padding = pad, padding_bottom = 0, margin = 0, background = WHITE,
        body,
    }
    -- keep the page buttons at the bottom of the screen
    local filler = math.max(0, sh - title:getSize().h - body_frame:getSize().h - footer:getSize().h)
    return VerticalGroup:new{
        align = "center",
        title,
        body_frame,
        VerticalSpan:new{ width = filler },
        footer,
    }
end

function GameScreen:onNextPage()
    if E.currentView() == "run" then return false end
    if self.subpage < (self.page_count or 1) then
        self.subpage = self.subpage + 1
        self:refresh()
    end
    return true
end

function GameScreen:onPrevPage()
    if E.currentView() == "run" then return false end
    if self.subpage > 1 then
        self.subpage = self.subpage - 1
        self:refresh()
    end
    return true
end

-- The title bar's X and the Back key: leave the current screen.
function GameScreen:goBack()
    local view = E.currentView()
    local ui = E.ui
    if view == "book" then ui.book = ""
    elseif view == "pets" then ui.pets = false
    elseif view == "classes" then ui.classes = false
    elseif view == "achs" then ui.achs = false
    elseif view == "wpns" then ui.wpns = false
    elseif view == "arms" then ui.arms = false
    elseif view == "chars" then ui.chars = false
    elseif view == "perks" then ui.perksView = false
    elseif view == "arts" then if ui.artSlot then ui.artSlot = nil else ui.artChar = nil end
    elseif view == "run" then self:showRunMenu(); return
    else self:onClose(); return end
    E.render()
    self:refresh(true)
end

function GameScreen:onClose()
    if E.currentView() ~= "camp" and E.currentView() ~= "run" then
        self:goBack()
        return true
    end
    if self.save_pending then UIManager:unschedule(self._save_task) end
    self:saveNow()
    UIManager:close(self)
    UIManager:setDirty(nil, "full")
    return true
end

function GameScreen:onCloseWidget()
    -- KOReader is closing us (or shutting down): make sure nothing is lost.
    if self.save_pending then
        UIManager:unschedule(self._save_task)
        self:saveNow()
    end
end

function GameScreen:onSuspend()
    if self.save_pending then
        UIManager:unschedule(self._save_task)
        self:saveNow()
    end
end

-- ----------------- save codes, files and help -----------------
function GameScreen:special(what)
    if what == "rules" then
        self:showRules()
    elseif what == "showCode" then
        local code = E.saveCode()
        local dialog
        dialog = InputDialog:new{
            title = _("Save code"),
            description = _("Copy this code somewhere safe. Paste it into Load save code (here or in the web version) to restore everything."),
            input = code,
            buttons = { {
                { text = _("Close"), id = "close", callback = function() UIManager:close(dialog) end },
                { text = _("Save to file"), callback = function() UIManager:close(dialog); self:special("saveFile") end },
            } },
        }
        UIManager:show(dialog)
    elseif what == "loadCode" then
        local dialog
        dialog = InputDialog:new{
            title = _("Load save code"),
            description = _("Paste a save code. This replaces your current progress."),
            input = "",
            buttons = { {
                { text = _("Cancel"), id = "close", callback = function() UIManager:close(dialog) end },
                { text = _("Load"), is_enter_default = true, callback = function()
                    local txt = dialog:getInputText()
                    UIManager:close(dialog)
                    self:loadCodeText(txt)
                end },
            } },
        }
        UIManager:show(dialog)
        dialog:onShowKeyboard()
    elseif what == "saveFile" then
        local f = io.open(CODE_FILE, "w")
        if f then
            f:write(E.saveCode(), "\n")
            f:close()
            UIManager:show(InfoMessage:new{ text = _("Saved your save code to:") .. "\n" .. CODE_FILE })
        else
            UIManager:show(InfoMessage:new{ text = _("Couldn't write the file:") .. "\n" .. CODE_FILE })
        end
    elseif what == "loadFile" then
        local f = io.open(CODE_FILE, "r")
        if not f then
            UIManager:show(InfoMessage:new{ text = _("No save file found. Put your save code in this file:") .. "\n" .. CODE_FILE })
            return
        end
        local txt = f:read("*a")
        f:close()
        UIManager:show(ConfirmBox:new{
            text = _("Load the save code from the file? This replaces your current progress."),
            ok_text = _("Load"),
            ok_callback = function() self:loadCodeText(txt) end,
        })
    end
end

function GameScreen:loadCodeText(txt)
    local ok = E.loadCode(txt)
    if ok then self:saveNow() end
    UIManager:show(InfoMessage:new{ text = E.ui.codeMsg, timeout = 3 })
    self:refresh(true)
end

return GameScreen
