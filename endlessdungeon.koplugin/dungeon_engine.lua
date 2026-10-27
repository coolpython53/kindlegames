--[[
Endless Dungeon for KOReader: the whole game engine.

This is a translation of the web version (dungeon.html) into Lua. The rules are
split over a few files that all share one set of names (this table), so the
code can read almost line for line like the original:

  dungeon_data.lua     every content table (monsters, weapons, pets, classes...)
  dungeon_content.lua  helpers, and the 10,000 monsters, 1,000 zones, 10,000 pets...
  dungeon_rules.lua    saving, gear, monsters, maps, floors, bounties, runs
  dungeon_fight.lua    fighting, turns, scrolls, walking
  dungeon_extras.lua   pets, classes, achievements, camp shops
  dungeon_chars.lua    the 10,000 characters: talents, energy and bursts
  dungeon_arts.lua     the 50,000 artifacts characters wear
  dungeon_views.lua    what every screen shows (the KOReader screen draws it)

Nothing here touches KOReader, so the engine can also be tested on a computer.
--]]

local M = setmetatable({}, { __index = _G })
package.loaded["dungeon_engine"] = M

for _, part in ipairs({ "dungeon_content", "dungeon_rules", "dungeon_fight", "dungeon_extras", "dungeon_chars", "dungeon_arts", "dungeon_views" }) do
    require(part)
end

return M
