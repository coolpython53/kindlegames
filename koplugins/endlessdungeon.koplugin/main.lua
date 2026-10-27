--[[--
Endless Dungeon for KOReader.

Adds "Endless Dungeon" to the Tools menu (in the file browser and while reading).
The game itself is in dungeon_screen.lua (the screen) and dungeon_engine.lua (the rules).

@module koplugin.EndlessDungeon
--]]--

local Dispatcher = require("dispatcher")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

local EndlessDungeon = WidgetContainer:extend{
    name = "endlessdungeon",
    is_doc_only = false,
}

function EndlessDungeon:onDispatcherRegisterActions()
    Dispatcher:registerAction("endless_dungeon", {
        category = "none",
        event = "OpenEndlessDungeon",
        title = _("Endless Dungeon"),
        general = true,
    })
end

function EndlessDungeon:init()
    self:onDispatcherRegisterActions()
    self.ui.menu:registerToMainMenu(self)
end

function EndlessDungeon:addToMainMenu(menu_items)
    menu_items.endless_dungeon = {
        text = _("Endless Dungeon"),
        sorting_hint = "tools",
        callback = function()
            self:openGame()
        end,
    }
end

function EndlessDungeon:onOpenEndlessDungeon()
    self:openGame()
    return true
end

function EndlessDungeon:openGame()
    -- Loaded only when you open the game, so KOReader itself starts as fast as before.
    local GameScreen = require("dungeon_screen")
    UIManager:show(GameScreen:new{})
end

return EndlessDungeon
