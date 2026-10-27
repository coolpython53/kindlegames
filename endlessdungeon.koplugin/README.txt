ENDLESS DUNGEON for KOReader
============================

The full Endless Dungeon game, with one change: weapons and armor only come from
the camp shops (chests give gold, a potion or scroll, and an artifact). Same monsters, weapons, pets, classes, floors,
achievements, shops, encyclopedia and save codes as the web version), as a
KOReader plugin. Plays offline, made for e-ink.

INSTALL
1. Connect the Kindle to a computer with USB.
2. Copy the whole "endlessdungeon.koplugin" folder into koreader/plugins/
   (on a Kindle that's usually /mnt/us/koreader/plugins/).
3. Eject, then restart KOReader.
4. Open the Tools menu (the wrench/screwdriver icon) and tap "Endless Dungeon".
   Tip: in Settings > Taps and gestures you can also give it a gesture
   (look for "Endless Dungeon" in the General actions).

CHARACTERS
- At camp, tap Characters and spend gold to summon one. There are 10,000, you
  never get the same one twice, and rarer ones are stronger and harder to get.
- Up to 4 go in your party. In the dungeon, Switch changes who's active (free,
  no turn used). Burst uses the active character's special move once its
  energy bar is full. Energy comes from hitting, defeating monsters and being hit.
- Best party (at camp or on the Characters screen) puts your 4 strongest
  characters in the party and makes the strongest one leader.
- Info shows every party member's talent, burst, energy and artifacts.

ARTIFACTS
- Treasure chests hold an artifact you don't have yet: 50,000 in all, in 7
  rarities (Common to Godly). Deeper floors give rarer ones. Kept forever.
- Each character wears one Flower, Plume, Sands, Goblet and Circlet (up to 20
  for a party of 4). Equip them at camp: Characters > Artifacts on a party
  member, or Best artifacts to dress the whole party.

PLAYING
- Tap a square next to you to move or attack. Tap a square farther away that
  you've seen to walk there in one tap.
- Swipe up/down/left/right anywhere to take one step that way.
- Bows, spears, staves and firearms: tap a monster in a straight line to shoot.
- "Info" shows the bounty, every monster in sight, what this floor does, and
  your gear, perks, pets and class.
- When a lot happens in one turn, tap the message box to read the whole log.
- Lists (camp, encyclopedia, shops) are split into pages: use the Back/Next
  buttons at the bottom, swipe, or the page-turn buttons.
- The X at the top goes back. At camp, it leaves the game.

SAVING
- The game saves by itself (a couple of seconds after each move, and always
  when you leave). The save is koreader/settings/endless_dungeon.lua.
- Camp > Save code: "Save to file" writes your save code to
  koreader/endless_dungeon_save.txt. "Load from file" reads it back.
- Save codes work both ways with dungeon-all-in-one.html (including characters
  and artifacts): copy the web version's code
  into that file (or paste it with "Load save code") to bring your progress
  over, or the other way round.

FILES
  main.lua             adds the menu entry
  dungeon_screen.lua   the screen (map, buttons, pages)
  dungeon_engine.lua   loads the game rules:
    dungeon_content.lua, dungeon_rules.lua, dungeon_fight.lua,
    dungeon_extras.lua, dungeon_views.lua
  dungeon_data.lua     all the game's content, copied from the web version
