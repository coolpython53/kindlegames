-- Endless Dungeon: what every screen shows. These build plain descriptions (text and buttons);
-- the KOReader screen (main.lua) turns them into widgets.
local M = require("dungeon_engine")
setfenv(1, M)

-- A button: text, what it does, and whether it's greyed out (off) or the main choice (main).
function B(text, cb, off, main) return { text = text, cb = cb, off = off and true or false, main = main and true or false } end
local function Page(title) return { title = title, items = {} } end
local function add(p, item) p.items[#p.items + 1] = item end
local function h2(p, t) add(p, { kind = "h2", text = t }) end
local function h3(p, t) add(p, { kind = "h3", text = t }) end
local function para(p, t, style) add(p, { kind = "p", text = t, style = style }) end   -- style: nil, "small", "status"
local function row(p, btns) add(p, { kind = "buttons", buttons = btns }) end
local function entry(p, title, lines, btns, badge)
    add(p, { kind = "entry", title = title, lines = lines or {}, buttons = btns, badge = badge })
end
local function found(yes) return yes and "Found" or nil end

-- Which screen is showing (same order as the web version).
function currentView()
    if tr(ui.book) then return "book" end
    if ui.pets then return "pets" end
    if ui.classes then return "classes" end
    if ui.achs then return "achs" end
    if ui.wpns then return "wpns" end
    if ui.arms then return "arms" end
    if ui.perksView then return "perks" end
    if ui.chars and ui.artChar then return "arts" end
    if ui.chars then return "chars" end
    if S.run then return "run" end
    return "camp"
end
function page()
    local v = currentView()
    if v == "book" then return renderBook() end
    if v == "pets" then return renderPets() end
    if v == "classes" then return renderClasses() end
    if v == "achs" then return renderAch() end
    if v == "wpns" then return renderWeapons() end
    if v == "arms" then return renderArmor() end
    if v == "chars" then return renderChars() end
    if v == "perks" then return renderPerks() end
    if v == "arts" then return renderArtifacts() end
    return renderCamp()
end

-- ================= THE RUN SCREEN =================
function runBar()
    local r, LV = S.run, curLevel()
    local line1 = "Floor " .. r.floor .. "   " .. (LV and LV.n or zoneOf(r.floor).n)
    local parts = { "HP " .. r.hp .. "/" .. r.maxHp, "Lv " .. r.lv, "Atk " .. atkOf(), "Arm " .. defOf(), "Gold " .. r.goldRun }
    local status = {}
    if r.poison > 0 then push(status, "Poisoned") end
    if r.weak > 0 then push(status, "Weak") end
    if r.slow > 0 then push(status, "Slowed") end
    local c = activeChar()
    if c then push(parts, c.name:match("^%S+") .. " " .. floor(energyOf(c.i)) .. "/" .. c.cost) end
    return line1, join(parts, "   "), status
end
function itemGlyph(it)
    if it.k == "gold" then return "$" end
    if it.k == "potion" then return "!" end
    if it.k == "scroll" then return "?" end
    if it.k == "chest" then return "*" end
    if it.k == "gear" then return it.g.slot == "wpn" and ")" or "[" end
    if it.k == "shop" then return "&" end
    if it.k == "shrine" then return "+" end
    if it.k == "relic" then return '"' end
    if it.k == "altar" then return "{" end
    if it.k == "pet" then return "p" end
    return ""
end
-- What one map square looks like: its text, and a style for drawing it.
-- style: unseen, wall, floor, dim (remembered), and flags: player, mon, boss, champ, frozen, blast, mimic, elevator, lava, wet, ice, portal
function cellLook(x, y, blastAt)
    local r = S.run
    local vis = visible(x, y)
    local m = vis and monAt(x, y) or nil
    local t = r.map[y][x]
    local c = { ch = "" }
    if m and hiddenMon(m) then m = has(m, "disguise") and { disguised = true } or nil end
    if r.seen[y][x] == 0 then c.base = "unseen"
    elseif t == 1 then
        c.base = "wall"
        if m and not m.disguised then c.mon = true; c.ch = m.ch end
    else
        local it = itemAt(x, y)
        c.base = vis and "floor" or "dim"
        c.tile = t
        if x == r.px and y == r.py then c.player = true; c.ch = "@"
        elseif m and m.disguised then c.ch = "$"
        elseif m then
            c.mon = true; c.ch = m.ch
            c.boss = m.kind == "boss"; c.champ = m.drop and m.kind ~= "boss"; c.frozen = m.frozen > 0
        elseif blastAt[x .. "," .. y] then c.ch = "x"; c.blast = true
        elseif it >= 0 then
            c.ch = itemGlyph(r.items[it])
            c.mimic = r.items[it].k == "chest" and r.items[it].mimic and petHas("mimicwarn")
        elseif x == r.sx and y == r.sy then c.ch = ">"
        elseif x == r.ex and y == r.ey then c.ch = "E"; c.elevator = true
        elseif TILE_GLYPH[t] then c.ch = TILE_GLYPH[t] end
    end
    if blastAt[x .. "," .. y] then c.blast = true end
    return c
end
function blastSet()
    local r, b = S.run, {}
    for i = 1, #r.blasts do b[r.blasts[i].x .. "," .. r.blasts[i].y] = true end
    return b
end
-- Under the map: the last few messages, or a combat log when a lot happened this turn.
function runLog()
    local r = S.run
    local L = r.log
    if #L <= 4 then return { combat = false, lines = L } end
    local MAX = 14
    local out = { combat = true, lines = {} }
    if #L > MAX then out.earlier = #L - MAX end
    for i = max(1, #L - MAX + 1), #L do push(out.lines, L[i]) end
    if r.hpStart ~= nil and r.hpStart ~= r.hp then
        local dd = r.hp - r.hpStart
        out.hpchange = "HP " .. r.hpStart .. " -> " .. r.hp .. " (" .. (dd > 0 and "+" or "") .. dd .. ")"
    end
    return out
end
function bountyLine()
    local r = S.run
    if not r.bounty then return nil end
    return "Bounty: " .. bountyText(), r.bounty.state ~= "on"
end

-- The side panel during a run: a choice to make, the elevator, or the scrolls. nil means show the arrows.
function runSide()
    local r = S.run
    if r.panel then local p = panelView(); if p then return p end end
    if ui.elev and onElevator() then return elevatorView() end
    if ui.bag then return bagView() end
    if ui.swap then return swapView() end
    return nil
end
function elevatorView()
    local r = S.run
    return { title = "Elevator", lines = { "Go to floor " .. ui.pick, zoneOf(ui.pick).n },
             rows = { { B("-10", function() pickFloor(-10) end, ui.pick <= 1), B("-1", function() pickFloor(-1) end, ui.pick <= 1),
                        B("+1", function() pickFloor(1) end, ui.pick >= S.best), B("+10", function() pickFloor(10) end, ui.pick >= S.best) },
                      { B("Deepest (" .. S.best .. ")", function() pickFloor(S.best, true) end) },
                      { B(ui.pick == r.floor and "Stay here" or "Go to " .. ui.pick, function() rideElevator() end, false, true),
                        B("Cancel", function() ui.elev = false; render() end) } } }
end
function bagView()
    local r = S.run
    local rows = {}
    for i = 0, len(SCROLLS) - 1 do
        local s = SCROLLS[i]
        local n = r.scrolls[s.id]
        push(rows, { B(s.n .. " (" .. n .. "): " .. s.d, function() readScroll(s.id) end, n < 1) })
    end
    push(rows, { B("Close", function() ui.bag = false; render() end) })
    return { title = "Scrolls", lines = { "Reading one uses your turn." }, rows = rows }
end
function panelView()
    local r, P, it = S.run, S.run.panel, hereItem()
    if P.t == "perk" then
        local slot = r.queue[1] or ""
        local v = { title = slot:sub(1, 1) == "B" and "Blessing" or "Level up!",
                    lines = { "Choose a perk for " .. slotName(slot) .. ". It will be saved for every run." ..
                              (#r.queue > 1 and " (" .. (#r.queue - 1) .. " more after this)" or "") }, rows = {} }
        for i = 1, #P.opts do
            local p = perkInfo(P.opts[i])
            local have = r.pf[p.id] and " (have " .. r.pf[p.id] .. ")" or ""
            push(v.rows, { B(p.n .. have .. ": " .. p.d, function() choosePerk(p.id) end) })
        end
        return v
    elseif P.t == "loot" and it and it.k == "gear" then
        local g = it.g
        local cur = g.slot == "wpn" and r.wpn or r.arm
        local verdict, cls, cmp = compareInfo(g)
        return { title = "You found", verdict = verdict, verdictStyle = cls,
                 lines = { cmp, rarName(g) .. ": " .. g.name, gearDesc(g),
                           "Now using: " .. (cur and rarName(cur) .. " " .. cur.name .. ". " .. gearDesc(cur) or "nothing") },
                 rows = { { B("Equip", function() equipHere() end, false, true), B("Leave it (destroys it)", function() destroyHere() end) } } }
    elseif P.t == "shop" and it and it.k == "shop" then
        local v = { title = "Merchant", lines = { "You have " .. r.goldRun .. " gold. Gold you spend here doesn't go home." }, rows = {} }
        for i = 1, #it.stock do
            local s = it.stock[i]
            local label, desc
            if s.k == "potion" then label = "Potion"; desc = "Heals half your HP"
            elseif s.k == "scroll" then label = scrollInfo(s.s).n .. " scroll"; desc = scrollInfo(s.s).d
            else
                local sa, sb = gearScore(s.g), gearScore(s.g.slot == "wpn" and r.wpn or r.arm)
                label = rarName(s.g) .. " " .. s.g.name .. (sa > sb * 1.05 and " (BETTER)" or (sa < sb * 0.95 and " (WORSE)" or " (SAME)"))
                desc = gearDesc(s.g)
            end
            push(v.rows, { B(label .. ": " .. (s.sold and "Sold" or desc .. ". " .. s.price .. " gold"), function() shopBuy(i) end, s.sold or r.goldRun < s.price) })
        end
        push(v.rows, { B("Leave", function() closePanel() end) })
        return v
    elseif P.t == "shrine" and it and it.k == "shrine" then
        return { title = "Shrine", lines = { "Choose one blessing. The shrine fades after." },
                 rows = { { B("Rest: heal fully and cure poison", function() shrineUse("rest") end) },
                          { B("Pray: gain a random perk, but lose 1/4 of your max HP", function() shrineUse("pray") end) },
                          { B("Leave", function() closePanel() end) } } }
    elseif P.t == "pet" and it and it.k == "pet" then
        return petPanelView(it)
    elseif P.t == "altar" and it and it.k == "altar" then
        local lines = { "Give your weapon a new random modifier. Works once." }
        if r.wpn then push(lines, "Now: " .. r.wpn.name .. ". " .. modInfo(r.wpn.mod).n .. ": " .. modInfo(r.wpn.mod).d) end
        return { title = "Enchanting table", lines = lines,
                 rows = { { B("Enchant", function() altarUse() end, not r.wpn, true), B("Leave", function() closePanel() end) } } }
    end
    r.panel = nil
    return nil
end
function petLine(i, lv)
    return PETS[i][0] .. " (" .. PRAR[PETS[i][2]] .. ((petLv(i) > 1 or (lv or 0) > 1) and ", level " .. J(lv, petLv(i)) or "") .. ")"
end
function petPanelView(it)
    local i = it.p
    local v, lv = petVerdict(i), petLv(i)
    local shown = lv > 0 and min(5, lv + 1) or 1
    local view = { title = "You found a pet!", verdict = v.good and "GOOD ADDITION" or "BAD ADDITION", verdictStyle = v.good and "better" or "worse",
                   lines = { v.why, petLine(i, shown), PETS[i][1], "In this game: " .. petEffectText(i, shown) .. "." }, rows = {} }
    if lv >= 5 then push(view.rows, { B("Take the gold", function() petTake("gold") end, false, true) })
    elseif lv > 0 then push(view.rows, { B("Level up " .. petName(i), function() petTake("lvl") end, false, true) })
    else
        if #S.team < TEAM_MAX then push(view.rows, { B("Add to team", function() petTake("add") end, false, true) })
        else push(view.rows, { B("Swap for " .. petName(S.team[weakestPet()]), function() petTake("swap") end, false, v.good) }) end
        push(view.rows, { B("Send to camp", function() petTake("camp") end) })
    end
    return view
end

-- ================= FLOOR GUIDE: what this floor and its monsters do =================
function typeNames(codes, f)
    local out = {}
    for i = first(codes), #codes do
        local ti = typeIndex(codes[i])
        local T = TYPES[ti]
        local nm = eName(ti + 100 * eGen(ti, min(f, 99999)))
        if T.tier <= f + 3 and not contains(out, nm) then push(out, nm .. " (" .. T.c .. ")") end
    end
    return out
end
function levelEffects(LV, f)
    local e = {}
    if LV.heart then push(e, "The Dungeon Heart (DH) never moves, but it calls monsters and cracks the floor under you")
    elseif LV.boss then push(e, "A boss guards the stairs and drops a potion or scroll") end
    if LV.champ then push(e, LV.champ .. " champions that carry a potion or scroll") end
    if LV.dens then push(e, LV.dens < 0.85 and "Fewer monsters than usual" or (LV.dens > 1.15 and "More monsters than usual" or "About the usual number of monsters")) end
    if LV.awake then push(e, "Every monster is awake and hunting you") end
    if LV.fav then local n = typeNames(LV.fav, f); if #n > 0 then push(e, "Lots of " .. join(n, ", ")) end end
    if LV.plusMut then push(e, "Every monster has an extra trait") end
    if LV.mut then push(e, "Many monsters " .. AB[LV.mut]) end
    if LV.chest then push(e, LV.chest .. " extra treasure chest" .. (LV.chest > 1 and "s" or "") .. " (*)") end
    if LV.mimic then push(e, "About " .. round(LV.mimic * 100) .. "% of chests are Mimics") end
    if LV.gold then push(e, LV.gold >= 2 and num(LV.gold) .. " times the gold" or "Extra gold") end
    local sup = (LV.gear or 0) + (LV.cursed and 1 or 0) + (LV.secret and 2 or 0)
    if sup > 0 then push(e, sup .. " extra potion" .. (sup > 1 and "s or scrolls" or " or scroll") .. " lying on the floor") end
    if LV.pots then push(e, LV.pots .. " extra potions (!)") end
    if LV.scr then push(e, LV.scr .. " extra scroll" .. (LV.scr > 1 and "s" or "") .. " (?)") end
    if LV.relic then push(e, LV.relic .. " relic" .. (LV.relic > 1 and "s" or "") .. ' (") that give a free perk') end
    if LV.altar then push(e, "An enchanting table ({) that gives your weapon a new modifier") end
    if LV.shop then push(e, "A merchant (&) who sells a potion and scrolls") end
    if LV.shrine then push(e, "A shrine (+) where you can heal or gain a perk") end
    if LV.reveal then push(e, "The whole map is shown") end
    if LV.dark then push(e, "It is dark: you can only see 2 squares") end
    if LV.rocks then push(e, "Rocks fall from the ceiling: step off any x before it lands") end
    if LV.portals then push(e, "Two linked portals (O)") end
    if LV.mirror then push(e, "The right half of the map mirrors the left half") end
    local TN = { lava = "lava (~)", ice = "ice (-)", water = "water (=)", web = "webs (=)", mud = "mud (=)", sand = "sand (=)", gas = "poison gas (:)", shock = "shock floors (#)" }
    local sq = {}
    if LV.tile then push(sq, TN[LV.tile]) end
    if LV.tile2 and LV.tile2 ~= LV.tile then push(sq, TN[LV.tile2]) end
    if LV.spikes then push(sq, "spike traps (^)") end
    if LV.mush then push(sq, "mushrooms (%)") end
    if #sq > 0 then push(e, "Floor squares: " .. join(sq, ", ")) end
    if LV.lay then push(e, "Map: " .. ({ rooms = "rooms and corridors", caves = "open caves", maze = "a maze", pillars = "big halls with pillars" })[LV.lay]) end
    return e
end
function tileNotes()
    local r, present, out = S.run, {}, {}
    for y = 0, H - 1 do for x = 0, W - 1 do present[r.map[y][x]] = true end end
    if present[2] then push(out, "Lava (~) burns you for 15% of your max HP") end
    if present[3] then push(out, "Spikes (^) hurt you for 10% of your max HP") end
    if present[7] then push(out, "Poison gas (:) poisons you for 3 turns") end
    if present[8] then push(out, "Shock floor (#) hurts you for 12% of your max HP") end
    if present[5] then push(out, cap(r.slowName) .. " (=) slows you, so monsters get extra steps") end
    if present[6] then push(out, "Ice (-) makes you slide until something stops you") end
    if present[4] then push(out, "Mushrooms (%) heal you for 25% of your max HP") end
    if present[9] then push(out, "Portals (O) jump you to the other portal") end
    return out
end
function floorGuide()
    local r, LV = S.run, curLevel()
    local Z = zoneOf(r.floor)
    local out = { "ABOUT THIS FLOOR" }
    local e = LV and levelEffects(LV, r.floor) or {}
    push(out, (LV and LV.n or "Ordinary floor") .. ": " .. (LV and LV.note .. " " or "Nothing special about this floor. ") .. (#e > 0 and join(e, ". ") .. "." or ""))
    local zn = (LV and LV.tile) and { "This floor's own squares replace the zone's usual ones" } or { Z.note }
    if Z.hz == "dark" then push(zn, "You can only see 2 squares") end
    local zf = typeNames(Z.fav, r.floor)
    if #zf > 0 then push(zn, "More " .. join(zf, ", ") .. " here") end
    if tr(Z.mut) and r.floor >= 3 then push(zn, "Some monsters are " .. mutAdj(Z.mut)) end
    push(out, "Zone: " .. Z.n .. ". " .. (join(zn, ". ") .. "."):gsub("%.%.", "."))
    local tn = tileNotes()
    if #tn > 0 then push(out, "Floor squares: " .. join(tn, ". ") .. ".") end

    -- every kind of monster on this floor, grouped
    local groups, byKey = {}, {}
    for i = 1, #r.mons do
        local m = r.mons[i]
        if not m.minion then
            local key = m.kind == "boss" and "b" .. i or (m.kind == "mimic" and "mi" or ((m.small and "s" or (m.kind == "champ" and "c" or "t")) .. eOf(m)))
            local g = byKey[key]
            if not g then g = { m = m, n = 0, extra = {} }; byKey[key] = g; push(groups, g) end
            g.n = g.n + 1
            local EA = eAbs(eOf(m))
            for j = 1, #m.abs do
                local a = m.abs[j]
                if not contains(EA, a) and not contains(g.extra, a) then push(g.extra, a) end
            end
        end
    end
    push(out, "")
    push(out, "MONSTERS ON THIS FLOOR (" .. #groups .. " kind" .. (#groups == 1 and "" or "s") .. ")")
    if #groups == 0 then push(out, "None left. The floor is clear!") end
    for i = 1, #groups do
        local G = groups[i]
        local Mn = G.m
        local T, base, EA, EN = TYPES[Mn.i], {}, eAbs(eOf(Mn)), eName(eOf(Mn))
        for j = 1, #EA do
            if not (EA[j] == "firewalk" and contains(EA, "fire")) then
                push(base, EA[j] == "summon" and ("calls " .. (tr(T.spawn) and (T.spawn == "random" and "monsters" or plural(T.spawn)) or "monsters") .. " to help") or AB[EA[j]])
            end
        end
        local title
        if Mn.kind == "boss" then title = Mn.name .. " (boss)"
        elseif Mn.kind == "champ" then title = "Champion " .. EN
        elseif Mn.kind == "mimic" then title = EN
        elseif Mn.small then title = "Small " .. EN
        else title = EN end
        local desc = Mn.small and "Small and weak" or (#base > 0 and cap(join(base, ", ")) or "No special tricks")
        local ex = {}
        for j = 1, #G.extra do push(ex, J(mutAdj(G.extra[j]), cap(G.extra[j])) .. " (" .. AB[G.extra[j]] .. ")") end
        push(out, "[" .. Mn.ch .. "] " .. title .. (G.n > 1 and " x" .. G.n or "") .. ": " .. desc .. "." ..
             (#ex > 0 and " " .. ((Mn.kind == "boss" or G.n == 1) and "Also: " or "Some also: ") .. join(ex, ", ") .. "." or "") ..
             ((Mn.drop and Mn.kind ~= "boss") and " Carries a potion or scroll." or ""))
    end
    return out
end
-- Everything below the map in the web version, as text for a scrolling page.
function runInfo()
    local r = S.run
    local out = {}
    local bl = bountyLine()
    if bl then push(out, bl); push(out, "") end
    if #S.party > 0 then
        push(out, "YOUR PARTY")
        for _, i in ipairs(S.party) do
            local c = charInfo(i)
            push(out, (i == r.cact and "> " or "") .. c.name .. " (" .. charRarityText(c.r) .. "), energy " .. floor(energyOf(i)) .. "/" .. c.cost ..
                 (i == r.cact and " (active)" or ""))
            push(out, "  Talent, " .. c.talName .. ": " .. talentText(c) .. ".")
            push(out, "  Burst, " .. c.burst .. ": " .. burstText(c))
            push(out, "  " .. artSummary(i) .. ".")
        end
        push(out, "")
    end
    local near = seenMonsters()
    if #near > 0 then
        local C = wcat()
        push(out, "MONSTERS IN SIGHT")
        for i = 1, #near do
            local n = near[i]
            local d = monDesc(n)
            push(out, "[" .. n.ch .. "] " .. n.name .. ": " .. n.hp .. "/" .. n.max .. " HP, attack " .. monAtk(n) .. ", armor " .. n.def .. "." ..
                 (n.frozen > 0 and " Stunned/frozen." or "") .. (d ~= "" and " " .. d or "") ..
                 ((C and C.range and canReach(n)) and " In range: tap it to " .. (C.range > 2 and "shoot" or "stab") .. "." or ""))
        end
        push(out, "")
    end
    for _, l in ipairs(floorGuide()) do push(out, l) end
    push(out, "")
    local perks = {}
    for i = 0, len(PERKS) - 1 do
        local c = r.pf[PERKS[i].id]
        if c and PERKS[i].id ~= "supply" and PERKS[i].id ~= "scholar" then push(perks, PERKS[i].n .. (c > 1 and " x" .. c or "")) end
    end
    push(out, "YOUR GEAR")
    push(out, "Weapon: " .. (r.wpn and r.wpn.name .. " (" .. rarName(r.wpn) .. "). " .. gearDesc(r.wpn) or "bare hands"))
    push(out, "Armor: " .. (r.arm and r.arm.name .. " (" .. rarName(r.arm) .. "). " .. gearDesc(r.arm) or "none"))
    push(out, "Perks: " .. (#perks > 0 and join(perks, ", ") or "none yet"))
    push(out, "Pets: " .. (#S.team > 0 and petTeamNames() or "none yet (look for p on the map)"))
    push(out, "Class: " .. curClass()[0] .. ". " .. clsEffectText(S.cls or 0) .. ".")

    push(out, "")
    push(out, zoneOf(r.floor).n .. ". Deepest floor: " .. S.best .. (tr(S.stars) and ". Stars: " .. S.stars or ""))
    return join(out, "\n")
end

-- ================= ENCYCLOPEDIA =================
local ENEMY_ORDER = nil
function enemyOrder()
    if ENEMY_ORDER then return ENEMY_ORDER end
    ENEMY_ORDER = {}
    for e = 0, E_N - 1 do ENEMY_ORDER[e + 1] = e end
    table.sort(ENEMY_ORDER, function(a, b)
        local ta, tb = eTier(a), eTier(b)
        if ta ~= tb then return ta < tb end
        return a < b
    end)
    return ENEMY_ORDER
end
function eAbText(e)
    local T, A, out = TYPES[e % 100], eAbs(e), {}
    for j = 1, #A do
        if not (A[j] == "firewalk" and contains(A, "fire")) then
            push(out, A[j] == "summon" and ("calls " .. (tr(T.spawn) and (T.spawn == "random" and "monsters" or plural(T.spawn)) or "monsters") .. " to help") or AB[A[j]])
        end
    end
    return #out > 0 and cap(join(out, ", ")) .. "." or "No special tricks."
end
function zoneFloors(i)
    local out = {}
    for k = 0, 1 do
        local start = (i + k * len(ZONES)) * 10 + 1
        push(out, start .. "-" .. (start + 9))
    end
    return "Floors " .. join(out, ", ") .. ", and so on"
end
-- Page buttons used by the long lists: back 10, back, page x of y, next, next 10, and an optional jump.
local function pager(p, cur, pages, go, label, extra)
    local btns = {
        B("<< 10", function() go(cur - 10) end, cur < 10),
        B("< Back", function() go(cur - 1) end, cur <= 0),
        { text = label or ("Page " .. (cur + 1) .. " of " .. pages), label = true },
        B("Next >", function() go(cur + 1) end, cur >= pages - 1),
        B("10 >>", function() go(cur + 10) end, cur > pages - 11),
    }
    row(p, btns)
    if extra then row(p, { extra }) end
end
function renderBook()
    local tab = ui.book
    local p = Page("Encyclopedia")
    local tabs = {}
    for i = 0, len(BOOK_TABS) - 1 do
        local id = BOOK_TABS[i][0]
        push(tabs, B(BOOK_TABS[i][1], function() openBook(id) end, false, tab == id))
    end
    push(tabs, B("Close", function() ui.book = ""; render() end))
    add(p, { kind = "buttons", buttons = tabs, tabs = true })

    if tab == "enemies" then
        local order, ep = enemyOrder(), 25
        local epages = ceil(#order / ep)
        local cf = max(1, S.run and S.run.floor or S.best)
        local jp = 0
        for i = 1, #order do if eTier(order[i]) <= cf then jp = floor((i - 1) / ep) end end
        ui.ePage = max(0, min(ui.ePage or 0, epages - 1))
        para(p, "All " .. fmt(E_N) .. " monsters, in the order they first show up. You've found " .. fmt(mCount()) ..
             ". There are 100 kinds, and every 100 floors a new, tougher version of each kind appears with 2 extra traits. " ..
             "Every monster gets stronger the deeper you go, and deeper ones can also have random traits.", "small")
        local go = function(n) ui.ePage = n; ui.bookTop = true; render() end
        pager(p, ui.ePage, epages, go, nil, B("Jump to floor " .. fmt(cf), function() go(jp) end))
        for i = ui.ePage * ep + 1, min(#order, (ui.ePage + 1) * ep) do
            local e = order[i]
            local T, tier = TYPES[e % 100], eTier(e)
            local when
            if T.chest then when = "Hides in treasure chests from floor " .. max(3, tier)
            elseif T.heart then when = "Guards The Dungeon Core from floor " .. tier
            elseif T.elite then when = "Boss from floor " .. tier
            else when = "From floor " .. fmt(tier) end
            entry(p, "[" .. T.c .. "] " .. eName(e), { FAMILY_NAME[T.fam] .. ". " .. when .. "." .. (T.undead and " Undead." or ""), eAbText(e) }, nil, found(mSeen(e)))
        end
        pager(p, ui.ePage, epages, go)
    elseif tab == "weapons" then
        para(p, "All 300 weapons in 10 families. Names marked * are ones you've found (" .. countSeen("w") ..
             " so far). Names further down a list show up deeper. Past the last name, weapons keep going as +1, +2, +3 and so on.", "small")
        for i = 0, len(WCATS) - 1 do
            local C, names = WCATS[i], {}
            for j = 0, len(WNAMES[i]) - 1 do
                local nmj = WNAMES[i][j]
                push(names, S.seen["w" .. nmj] and nmj .. "*" or nmj)
            end
            entry(p, C.n, { cap(C.d) .. ". Damage x" .. num(C.mult) .. ".", join(names, ", ") .. "." })
        end
        local arm = {}
        for i = 0, len(ARM) - 1 do push(arm, ARM[i]) end
        entry(p, "Armor", { join(arm, ", ") .. ", then +1, +2 and so on." })
        local rar = {}
        for i = 0, len(RAR) - 1 do push(rar, RAR[i]) end
        entry(p, "Rarity", { join(rar, ", ") .. ". Rarer gear has more bonuses: " ..
            "weapons can get Leeching (heal per hit), Thunder (double damage), Greed (more gold), Fury (more attack) or Piercing (ignore armor); " ..
            "armor can get Thorns, Life (more HP), Shadows (dodge), Mending (heal over time) or the Turtle (more armor)." })
    elseif tab == "pets" then
        local pr, plist, pp = ui.pRar or 0, {}, 25
        for i = 0, len(PETS) - 1 do if PETS[i][2] == pr then push(plist, i) end end
        local ppages = ceil(#plist / pp)
        ui.pPage = max(0, min(ui.pPage or 0, ppages - 1))
        para(p, "All " .. fmt(len(PETS)) .. " pets. You've found " .. fmt(countKeys(S.pets)) .. ". Up to " .. TEAM_MAX ..
             " can be on your team. \"In this game\" says exactly what each one does here.", "small")
        local rtabs = {}
        for ri = 0, len(PRAR) - 1 do push(rtabs, B(PRAR[ri], function() ui.pRar = ri; ui.pPage = 0; ui.bookTop = true; render() end, false, ri == pr)) end
        row(p, rtabs)
        h3(p, PRAR[pr] .. " pets (" .. fmt(#plist) .. ")")
        local go = function(n) ui.pPage = n; ui.bookTop = true; render() end
        pager(p, ui.pPage, ppages, go)
        for k = ui.pPage * pp + 1, min(#plist, (ui.pPage + 1) * pp) do
            local i = plist[k]
            entry(p, PETS[i][0], { PETS[i][1], "In this game: " .. petEffectText(i, max(1, S.pets[i] or 1)) .. "." }, nil,
                  S.pets[i] and ("Found" .. (S.pets[i] > 1 and ", level " .. S.pets[i] or "")) or nil)
        end
        pager(p, ui.pPage, ppages, go)
    elseif tab == "mods" then
        para(p, "Every weapon has one modifier at the start of its name, like \"Flaming Moonblade\". You've found " .. countSeen("o") .. " of " .. len(MODS) .. ".", "small")
        for i = 0, len(MODS) - 1 do
            local Md = MODS[i]
            entry(p, Md.n, { (Md.pct ~= 0 and ((Md.pct > 0 and "+" or "") .. Md.pct .. "% damage. ") or "Normal damage. ") .. (Md.opt and "Shows up from floor 8." or ""),
                             cap(Md.id == "leeching" and "heals you a few HP on every hit (more on deeper weapons)" or Md.d) .. "." }, nil, found(S.seen["o" .. Md.id]))
        end
    elseif tab == "traits" then
        para(p, "Things monsters can do. Some kinds are born with them, and deeper monsters can get random extra ones. You've seen " .. countSeen("a") .. ".", "small")
        for ki = 0, len(AB_ORDER) - 1 do
            local k = AB_ORDER[ki]
            local mi = -1
            for j = 0, len(MUTS) - 1 do if MUTS[j].id == k then mi = j end end
            entry(p, mi >= 0 and MUTS[mi].adj or cap(k), { cap(AB[k]) .. "." .. (mi >= 0 and " Random trait from floor " .. max(6, 5 * (mi - 2)) .. "." or "") }, nil, found(S.seen["a" .. k]))
        end
    elseif tab == "floors" then
        local fp, cur = 25, max(1, S.run and S.run.floor or S.best)
        local fpages = FT_N / fp
        ui.fPage = max(0, min(ui.fPage or 0, fpages - 1))
        para(p, "Every floor has its own type: " .. fmt(FT_N) .. " of them, one for each floor from 1 to " .. fmt(FT_N) ..
             ". Each is one of the 50 kinds of floors below, plus a word and an ending that change it. You've visited " .. fmt(ftCount()) .. ".", "small")
        local go = function(n) ui.fPage = n; ui.bookTop = true; render() end
        h3(p, "Every floor")
        pager(p, ui.fPage, fpages, go, "Floors " .. fmt(ui.fPage * fp + 1) .. "-" .. fmt(ui.fPage * fp + fp),
              B("Jump to floor " .. fmt(cur), function() go(floor(((cur - 1) % FT_N) / fp)) end))
        for i = ui.fPage * fp, (ui.fPage + 1) * fp - 1 do
            local T2 = floorType(i + 1)
            entry(p, "Floor " .. fmt(i + 1) .. ": " .. T2.n, { zoneOf(i + 1).n .. ". " .. T2.note, join(levelEffects(T2, i + 1), ". ") .. "." }, nil, found(ftSeen(i + 1)))
        end
        pager(p, ui.fPage, fpages, go, "Floors " .. fmt(ui.fPage * fp + 1) .. "-" .. fmt(ui.fPage * fp + fp))
        h3(p, "The 50 kinds of floors")
        for i = 0, len(LEVELS) - 1 do
            local L = LEVELS[i]
            local when2 = L.secret and "Very rare secret floor" or (L.heart and "Every 50 floors" or (L.bossLevel and "Boss floors (every 5)" or (L.minF and "From floor " .. L.minF or "Any floor")))
            entry(p, L.n, { when2 .. ".", L.note .. " " .. join(levelEffects(L, 999), ". ") .. "." }, nil, found(S.seen["l" .. L.n]))
        end
    elseif tab == "zones" then
        local zp = 25
        local zpages = ceil(len(ZONES) / zp)
        local here = floor((max(1, S.run and S.run.floor or S.best) - 1) / 10) % len(ZONES)
        ui.zPage = max(0, min(ui.zPage or 0, zpages - 1))
        para(p, "A new zone every 10 floors: " .. fmt(len(ZONES)) .. " zones, " .. fmt(len(ZONES) * 10) ..
             " floors. After all of them, they come back tougher as II, III and so on, forever. You've visited " .. countSeen("z") .. ".", "small")
        local go = function(n) ui.zPage = n; ui.bookTop = true; render() end
        pager(p, ui.zPage, zpages, go, nil, B("Jump to " .. (S.run and "this zone" or "your deepest zone"), function() go(floor(here / zp)) end))
        for i = ui.zPage * zp, min(len(ZONES), (ui.zPage + 1) * zp) - 1 do
            local Z = ZONES[i]
            local lay = ({ rooms = "rooms and corridors", caves = "open caves", maze = "a maze", pillars = "big halls with pillars" })[Z.lay]
            local fav = typeNames(Z.fav, 999)
            entry(p, "#" .. (i + 1) .. " " .. Z.n, { zoneFloors(i) .. ". Map: " .. lay .. ".",
                  Z.note .. (#fav > 0 and " More " .. join(fav, ", ") .. "." or "") .. (tr(Z.mut) and " Some monsters are " .. mutAdj(Z.mut) .. "." or "") }, nil, found(S.seen["z" .. Z.n]))
        end
        pager(p, ui.zPage, zpages, go)
    elseif tab == "ach" then
        bookAch(p)
    elseif tab == "chars" then
        bookChars(p)
    elseif tab == "arts" then
        bookArts(p)
    else
        h3(p, "Perks")
        para(p, "You pick one every 2 levels. Each pick is saved for that level.", "small")
        for i = 0, len(PERKS) - 1 do entry(p, PERKS[i].n, { PERKS[i].d .. "." }) end
        h3(p, "Scrolls and potions")
        entry(p, "Potion", { "Heals half your max HP and cures poison and weakness." })
        for i = 0, len(SCROLLS) - 1 do entry(p, SCROLLS[i].n .. " scroll", { SCROLLS[i].d .. "." }) end
        h3(p, "Things on the map")
        entry(p, "Symbols", { "$ gold. ! potion. ? scroll. * treasure chest: gold and a potion or scroll (some are Mimics). & merchant. + shrine. \" relic (free perk). " ..
                              "{ enchanting table (new weapon modifier). > stairs. E elevator. p pet." })
        h3(p, "Floor squares")
        entry(p, "~ Lava", { "Burns you for 15% of your max HP." })
        entry(p, "^ Spikes", { "Hurt you for 10% of your max HP." })
        entry(p, ": Poison gas", { "Poisons you for 3 turns." })
        entry(p, "# Shock floor", { "Hurts you for 12% of your max HP." })
        entry(p, "= Water, web, mud or sand", { "Slows you, so monsters get extra steps." })
        entry(p, "- Ice", { "You slide until something stops you." })
        entry(p, "% Mushroom", { "Heals you for 25% of your max HP." })
        entry(p, "O Portal", { "Jumps you to the other portal." })
        entry(p, "x", { "A bomb or falling rock lands here next turn. Step off it!" })
        h3(p, "Camp upgrades")
        for i = 0, len(UPS) - 1 do entry(p, UPS[i].name, { UPS[i].each .. (UPS[i].max and " (up to " .. UPS[i].max .. ")" or "") .. "." }) end
        h3(p, "Achievements")
        para(p, "All " .. fmt(len(ACH) + len(ACH2)) .. " achievements are in the Achievements tab.")
    end
    row(p, { B("Back to top", function() ui.bookTop = true; render() end), B("Close", function() ui.book = ""; render() end) })
    return p
end

-- ================= PETS SCREEN =================
function renderPets()
    local p = Page("Pets")
    row(p, { B("Back to camp", function() ui.pets = false; render() end) })
    local owned = {}
    for i = 0, len(PETS) - 1 do if S.pets[i] then push(owned, i) end end
    para(p, "You can have up to " .. TEAM_MAX .. " pets on your team. Only team pets help you in the dungeon. You've found " .. fmt(#owned) .. " of " .. fmt(len(PETS)) .. ". " ..
         "Finding a pet you already have makes it level up (up to level 5).", "small")
    h3(p, "Your team (" .. #S.team .. " of " .. TEAM_MAX .. ")")
    if #S.team == 0 then para(p, "No pets yet. Look for p on the map.") end
    for k = 1, #S.team do
        local i = S.team[k]
        entry(p, petLine(i), { petEffectText(i) .. "." }, { B("Remove from team", function() petRemove(i) end) })
    end
    ssort(owned, function(a, b) local d = petScore(b) - petScore(a); return d end)
    h3(p, "Collection (strongest first)")
    local shown = 0
    for k = 1, #owned do
        local i = owned[k]
        if not contains(S.team, i) then
            if shown >= 60 then para(p, "...and " .. fmt(#owned - #S.team - shown) .. " weaker pets.", "small"); break end
            shown = shown + 1
            entry(p, petLine(i), { petEffectText(i) .. "." }, { B("Add to team", function() petAdd(i) end, #S.team >= TEAM_MAX) })
        end
    end
    if shown == 0 then para(p, "Pets you find but don't put on your team wait here.", "small") end
    row(p, { B("Back to top", function() ui.bookTop = true; render() end), B("Back to camp", function() ui.pets = false; render() end) })
    return p
end

-- ================= CLASSES SCREEN =================
function renderClasses()
    local p = Page("Classes")
    row(p, { B("Back to camp", function() ui.classes = false; render() end) })
    local cur = curClass()
    para(p, "You have " .. fmt(S.gold) .. " gold. You own " .. ownedCount() .. " of 300 classes. Buy any class in any order. " ..
         "You can equip one class at a time and switch between the ones you own for free. Classes are yours forever, even after you ascend.", "small")
    entry(p, "Equipped: " .. cur[0] .. " (Tier " .. cur[2] .. ")", { cur[3], "In this game: " .. clsEffectText(S.cls or 0) .. "." })
    h3(p, "Tiers")
    local tiers = {}
    for i = 0, len(CTIERS) - 1 do push(tiers, B((i + 1) .. ": " .. CTIERS[i], function() ui.clsTier = i + 1; ui.bookTop = true; render() end, false, ui.clsTier == i + 1)) end
    row(p, tiers)
    h3(p, "Tier " .. ui.clsTier .. ": " .. CTIERS[ui.clsTier - 1])
    for i = 0, len(CLASSES) - 1 do
        local c = CLASSES[i]
        if c[2] == ui.clsTier then
            local own, eq = S.clsOwn[i] ~= nil, (S.cls or 0) == i
            local b
            if eq then b = nil
            elseif own then b = { B("Equip", function() equipClass(i) end, false, true) }
            else b = { B("Buy for " .. fmt(c[1]) .. " gold", function() buyClass(i) end, S.gold < c[1]) } end
            entry(p, c[0] .. " (" .. (c[1] > 0 and fmt(c[1]) .. " gold" or "free") .. ")", { c[3], "In this game: " .. clsEffectText(i) .. "." }, b,
                  eq and "Equipped" or (own and "Owned" or nil))
        end
    end
    row(p, { B("Back to top", function() ui.bookTop = true; render() end), B("Back to camp", function() ui.classes = false; render() end) })
    return p
end

-- ================= ACHIEVEMENTS SCREEN =================
local function achEntry(p, name, what, t, have, need)
    entry(p, name .. (t > 0 and " " .. roman(t) or ""), { what .. ".", "Next level: " .. fmt(min(have, need)) .. " / " .. fmt(need) .. ", pays " .. fmt(achReward(t)) .. " gold" },
          nil, t > 0 and "Level " .. t or nil)
end
local function achSections(p, counts)
    local btns = {}
    for i = 0, len(ACH_SECS) - 1 do push(btns, B(ACH_SECS[i] .. " (" .. counts[i] .. ")", function() achSec(i) end, false, ui.achSec == i)) end
    row(p, btns)
end
local function achList2()
    local list = {}
    for i = 0, len(ACH2) - 1 do if ACH2[i][0] == ACH_SECS[ui.achSec] then push(list, ACH2[i]) end end
    return list
end
function renderAch()
    local p = Page("Achievements")
    row(p, { B("Back to camp", function() ui.achs = false; render() end) })
    para(p, "You've earned " .. fmt(achTotal()) .. " levels. Every achievement has endless levels: after level V, each new level " ..
         "needs twice as much and pays more gold. New levels are paid when you get back to camp.", "small")
    local lv, mainLv = {}, 0
    for i = 0, len(ACH2) - 1 do lv[ACH2[i][0]] = (lv[ACH2[i][0]] or 0) + (S.ach[ACH2[i][4]] or 0) end
    for i = 0, len(ACH) - 1 do mainLv = mainLv + (S.ach[ACH[i].id] or 0) end
    local counts = {}
    for i = 0, len(ACH_SECS) - 1 do counts[i] = i > 0 and (lv[ACH_SECS[i]] or 0) or mainLv end
    achSections(p, counts)
    h3(p, ACH_SECS[ui.achSec])
    if ui.achSec == 0 then
        for i = 0, len(ACH) - 1 do
            local A = ACH[i]
            local t = S.ach[A.id] or 0
            achEntry(p, A.n, cap(A.what), t, S.stats[A.id] or 0, achNeed(A, t))
        end
    else
        local list = achList2()
        local pages = ceil(#list / ACH_PAGE)
        ui.achPage = max(0, min(ui.achPage, pages - 1))
        local nav = function()
            if pages > 1 then
                row(p, { B("< Back", function() achPage(-1) end, ui.achPage <= 0), { text = "Page " .. (ui.achPage + 1) .. " of " .. pages, label = true },
                         B("Next >", function() achPage(1) end, ui.achPage >= pages - 1) })
            end
        end
        nav()
        for i = ui.achPage * ACH_PAGE + 1, min(#list, (ui.achPage + 1) * ACH_PAGE) do
            local A = list[i]
            local t = S.ach[A[4]] or 0
            achEntry(p, A[1], A[2], t, achVal(A), achNeed2(A, t))
        end
        nav()
    end
    row(p, { B("Back to top", function() ui.bookTop = true; render() end), B("Back to camp", function() ui.achs = false; render() end) })
    return p
end
-- Encyclopedia tab: every achievement with what levels I to V need.
local function lvText(nums, n)
    local out = {}
    for i = 0, n - 1 do push(out, roman(i + 1) .. ": " .. fmt(nums[i])) end
    return join(out, ", ")
end
function bookAch(p)
    para(p, "All " .. fmt(len(ACH) + len(ACH2)) .. " achievements, in " .. len(ACH_SECS) .. " sections. You've earned " .. fmt(achTotal()) ..
         " levels. Every achievement has endless levels: after level V, each new level needs twice as much. " ..
         "Gold for each level: I: 25, II: 38, III: 56, IV: 84, V: 127, then about 1.5 times more each level. New levels are paid at camp.", "small")
    local counts = {}
    for i = 0, len(ACH_SECS) - 1 do
        local n = 0
        if i == 0 then n = len(ACH) else for j = 0, len(ACH2) - 1 do if ACH2[j][0] == ACH_SECS[i] then n = n + 1 end end end
        counts[i] = n
    end
    achSections(p, counts)
    h3(p, ACH_SECS[ui.achSec])
    local function bentry(name, what, t, nums)
        entry(p, name, { what .. ".", "Needs " .. lvText(nums, 5) .. ", then more forever." }, nil, t > 0 and "Level " .. t or nil)
    end
    if ui.achSec == 0 then
        for i = 0, len(ACH) - 1 do
            local A = ACH[i]
            bentry(A.n, cap(A.what), S.ach[A.id] or 0, { [0] = achNeed(A, 0), achNeed(A, 1), achNeed(A, 2), achNeed(A, 3), achNeed(A, 4) })
        end
        return
    end
    local list = achList2()
    local pages = ceil(#list / ACH_PAGE)
    ui.achPage = max(0, min(ui.achPage, pages - 1))
    local function nav()
        if pages > 1 then
            row(p, { B("< Back", function() achPage(-1) end, ui.achPage <= 0), { text = "Page " .. (ui.achPage + 1) .. " of " .. pages, label = true },
                     B("Next >", function() achPage(1) end, ui.achPage >= pages - 1) })
        end
    end
    nav()
    for i = ui.achPage * ACH_PAGE + 1, min(#list, (ui.achPage + 1) * ACH_PAGE) do
        local A = list[i]
        bentry(A[1], A[2], S.ach[A[4]] or 0, A[3])
    end
    nav()
end

-- ================= CAMP SHOPS =================
local function shopTiers(p, n, current, price, go)
    local btns = {}
    for i = 1, n do push(btns, B(i .. ": " .. fmt(price(i)) .. "+", function() go(i, 0) end, false, current == i)) end
    row(p, btns)
end
function renderWeapons()
    local p = Page("Weapon shop")
    row(p, { B("Back to camp", function() ui.wpns = false; render() end) })
    para(p, "You have " .. fmt(S.gold) .. " gold. You own " .. cwOwned() .. " of " .. fmt(CW_N) .. " weapons. Weapons you buy are yours forever, even after you ascend. " ..
         "The one you equip is your starting weapon on every run, and it stays equipped until you buy or pick a different one. " ..
         "Weapons can't be found in the dungeon, so this shop is the only way to get a better one.", "small")
    if S.cwEq >= 0 then
        local eg = campWpn(S.cwEq)
        entry(p, "Equipped: " .. eg.name .. " (" .. RAR[eg.rar] .. " " .. WCATS[eg.cat].n .. ")", { gearDesc(eg) .. "." },
              { B("Use the free starter weapon instead", function() equipCW(-1) end) })
    else para(p, "Equipped: the free starter weapon (a Dull Ironfang on floor 1, or a random weapon when you start deeper).") end
    row(p, { B("Best I can afford", function() cwBest() end, false, true) })
    h3(p, "Tiers")
    shopTiers(p, CW_N / CW_TIER, ui.cwTier, function(i) return cwPrice((i - 1) * CW_TIER) end, cwGo)
    local pages = CW_TIER / CW_PAGE
    ui.cwPage = max(0, min(ui.cwPage, pages - 1))
    local function nav()
        row(p, { B("< Back", function() cwGo(ui.cwTier, ui.cwPage - 1) end, ui.cwPage <= 0), { text = "Page " .. (ui.cwPage + 1) .. " of " .. pages, label = true },
                 B("Next >", function() cwGo(ui.cwTier, ui.cwPage + 1) end, ui.cwPage >= pages - 1) })
    end
    h3(p, "Tier " .. ui.cwTier)
    nav()
    local start = (ui.cwTier - 1) * CW_TIER + ui.cwPage * CW_PAGE
    for i = start, min(start + CW_PAGE, CW_N) - 1 do
        local g, own, eq, c = campWpn(i), S.cw[i] ~= nil, S.cwEq == i, cwPrice(i)
        local b
        if eq then b = nil elseif own then b = { B("Equip", function() equipCW(i) end, false, true) }
        else b = { B("Buy for " .. fmt(c) .. " gold", function() buyCW(i) end, S.gold < c) } end
        entry(p, "#" .. (i + 1) .. " " .. g.name .. " (" .. RAR[g.rar] .. " " .. WCATS[g.cat].n .. ")", { gearDesc(g) .. "." }, b, eq and "Equipped" or (own and "Owned" or nil))
    end
    nav()
    row(p, { B("Back to top", function() ui.bookTop = true; render() end), B("Back to camp", function() ui.wpns = false; render() end) })
    return p
end
function renderArmor()
    local p = Page("Armor shop")
    row(p, { B("Back to camp", function() ui.arms = false; render() end) })
    para(p, "You have " .. fmt(S.gold) .. " gold. You own " .. caOwned() .. " of " .. fmt(CA_N) .. " armors. Armor you buy is yours forever, even after you ascend. " ..
         "The one you equip is your starting armor on every run, and it stays equipped until you buy or pick a different one. " ..
         "Armor can't be found in the dungeon, so this shop is the only way to get better armor.", "small")
    if S.caEq >= 0 then
        local eg = campArm(S.caEq)
        entry(p, "Equipped: " .. eg.name .. " (" .. RAR[eg.rar] .. " armor)", { gearDesc(eg) .. "." },
              { B("Start with no shop armor instead", function() equipCA(-1) end) })
    else para(p, "Equipped: no shop armor (no armor on floor 1, or a random armor when you start deeper).") end
    row(p, { B("Best I can afford", function() caBest() end, false, true) })
    h3(p, "Tiers")
    shopTiers(p, CA_N / CA_TIER, ui.caTier, function(i) return caPrice((i - 1) * CA_TIER) end, caGo)
    local pages = CA_TIER / CA_PAGE
    ui.caPage = max(0, min(ui.caPage, pages - 1))
    local function nav()
        row(p, { B("< Back", function() caGo(ui.caTier, ui.caPage - 1) end, ui.caPage <= 0), { text = "Page " .. (ui.caPage + 1) .. " of " .. pages, label = true },
                 B("Next >", function() caGo(ui.caTier, ui.caPage + 1) end, ui.caPage >= pages - 1) })
    end
    h3(p, "Tier " .. ui.caTier)
    nav()
    local start = (ui.caTier - 1) * CA_TIER + ui.caPage * CA_PAGE
    for i = start, min(start + CA_PAGE, CA_N) - 1 do
        local g, own, eq, c = campArm(i), S.ca[i] ~= nil, S.caEq == i, caPrice(i)
        local b
        if eq then b = nil elseif own then b = { B("Equip", function() equipCA(i) end, false, true) }
        else b = { B("Buy for " .. fmt(c) .. " gold", function() buyCA(i) end, S.gold < c) } end
        entry(p, "#" .. (i + 1) .. " " .. g.name .. " (" .. RAR[g.rar] .. " armor)", { gearDesc(g) .. "." }, b, eq and "Equipped" or (own and "Owned" or nil))
    end
    nav()
    row(p, { B("Back to top", function() ui.bookTop = true; render() end), B("Back to camp", function() ui.arms = false; render() end) })
    return p
end

-- ================= CAMP =================
-- The main screen between runs. "special" buttons are handled by the KOReader screen (dialogs, files).
function renderCamp()
    local p = Page("Endless Dungeon")
    if S.last then
        local L = S.last
        if L.note then para(p, L.note, "status")
        else
            para(p, (tr(L.killer) and "Defeated by " .. L.killer .. " on floor " .. L.floor .. "." or "You left the dungeon on floor " .. L.floor .. ".") ..
                 " You brought back " .. L.gold .. " gold." .. ((L.floor >= S.best and L.floor > 1) and " That's your deepest yet!" or ""), "status")
        end
        if L.arts and #L.arts > 0 then
            local names = {}
            for k = 1, min(6, #L.arts) do local a = artInfo(L.arts[k]); push(names, a.name .. " (" .. AR_RAR[a.r] .. ")") end
            para(p, "Artifacts found: " .. join(names, ", ") .. (#L.arts > 6 and " and " .. (#L.arts - 6) .. " more" or "") ..
                 ". Equip them on the Characters screen.", "status")
        end
        if L.ach and #L.ach > 0 then para(p, "New achievement level" .. (#L.ach > 1 and "s" or "") .. ": " .. achList(L.ach), "status") end
    end
    if tr(ui.achNote) then para(p, "New achievement levels: " .. ui.achNote, "status"); ui.achNote = "" end
    if not S.last and S.runs == 0 then
        para(p, "Welcome to camp. Head into the dungeon, grab gold, and see how deep you can go.", "status")
    end
    para(p, "Gold: " .. fmt(S.gold) .. "    Deepest floor: " .. S.best .. "    Runs: " .. S.runs .. (tr(S.stars) and "    Stars: " .. S.stars or ""))

    if S.best > 1 then ui.startAt = max(1, min(ui.startAt, S.best)) end
    row(p, { B(ui.startAt > 1 and "Enter on floor " .. ui.startAt or "Enter the dungeon", function() startRun() end, false, true) })
    row(p, { B("How to play", nil, false, false, nil), B("Encyclopedia", function() openBook() end) })
    p.items[#p.items].buttons[1].special = "rules"

    h2(p, "Characters")
    local pn = {}
    for _, i in ipairs(S.party) do push(pn, charInfo(i).name .. (i == S.lead and " (leader)" or "")) end
    para(p, "Party (" .. #S.party .. " of " .. PARTY_MAX .. "): " .. (#pn > 0 and join(pn, ", ") or "nobody yet") ..
         ". You own " .. fmt(charsOwned()) .. " of " .. fmt(CH_N) .. ". Next summon: " .. fmt(summonCost(1)) .. " gold.", "small")
    if ui.partyNote then para(p, ui.partyNote, "status") end
    row(p, { B("Characters", function() openChars() end), B("Best party", function() bestParty() end, charsOwned() == 0) })

    h2(p, "Upgrades")
    for i = 0, len(UPS) - 1 do
        local u = UPS[i]
        local c = upCost(u.id)
        entry(p, u.name .. " (level " .. S.up[u.id] .. (u.max and " of " .. u.max or "") .. ")", { u.each },
              { maxed(u.id) and { text = "Maxed", label = true } or B("Buy for " .. fmt(c) .. " gold", function() buy(u.id) end, S.gold < c) })
    end

    if S.best > 1 then
        local a = ui.startAt
        h2(p, "Elevator")
        para(p, "Start on any floor you've reached. Starting deeper gives you free levels, perks and gear.", "small")
        row(p, { B("-10", function() startPick(-10) end, a <= 1), B("-1", function() startPick(-1) end, a <= 1), { text = "Floor " .. a, label = true },
                 B("+1", function() startPick(1) end, a >= S.best), B("+10", function() startPick(10) end, a >= S.best) })
        para(p, zoneOf(a).n, "small")
        row(p, { B("Floor 1", function() startPick(1, true) end), B("Deepest (" .. S.best .. ")", function() startPick(S.best, true) end) })
        row(p, { B("Enter on floor " .. a, function() startRun() end, false, true) })
    end
    h2(p, "Class")
    para(p, curClass()[0] .. ": " .. clsEffectText(S.cls or 0) .. ". You own " .. ownedCount() .. " of 300 classes.", "small")
    row(p, { B("Classes", function() openClasses() end) })
    h2(p, "Weapon")
    para(p, (S.cwEq >= 0 and "Starting weapon: " .. campWpn(S.cwEq).name .. " (attack " .. campWpn(S.cwEq).atk .. ")" or "Starting weapon: the free starter") ..
         ". You own " .. cwOwned() .. " of " .. fmt(CW_N) .. " shop weapons.", "small")
    row(p, { B("Weapon shop", function() openWeapons() end) })
    h2(p, "Armor")
    para(p, (S.caEq >= 0 and "Starting armor: " .. campArm(S.caEq).name .. " (armor " .. campArm(S.caEq).def .. ")" or "Starting armor: none from the shop") ..
         ". You own " .. caOwned() .. " of " .. fmt(CA_N) .. " shop armors.", "small")
    row(p, { B("Armor shop", function() openArmor() end) })
    h2(p, "Pets")
    para(p, "Team (" .. #S.team .. " of " .. TEAM_MAX .. "): " .. (#S.team > 0 and petTeamNames() or "none yet. Look for p on the map."), "small")
    row(p, { B("Manage pets", function() openPets() end) })

    h2(p, "Collection")
    para(p, "Monsters found: " .. fmt(mCount()) .. " of " .. fmt(E_N) .. "\n" ..
            "Monster traits seen: " .. countSeen("a") .. " of " .. traitCount() .. "\n" ..
            "Weapons found: " .. countSeen("w") .. " of 300\n" ..
            "Weapon modifiers found: " .. countSeen("o") .. " of " .. len(MODS) .. "\n" ..
            "Kinds of floors visited: " .. countSeen("l") .. " of " .. len(LEVELS) .. "\n" ..
            "Unique floors visited: " .. fmt(ftCount()) .. " of " .. fmt(FT_N) .. "\n" ..
            "Zones visited: " .. countSeen("z") .. " of " .. fmt(len(ZONES)) .. "\n" ..
            "Pets found: " .. fmt(countKeys(S.pets)) .. " of " .. fmt(len(PETS)))

    h2(p, "Achievements")
    para(p, "You've earned " .. fmt(achTotal()) .. " achievement levels. There are " .. fmt(len(ACH) + len(ACH2)) ..
         " achievements, and every one has endless levels that pay gold.", "small")
    row(p, { B("Achievements", function() openAch() end) })

    h2(p, "Saved perks")
    local nKeys = countKeys(S.perkAt)
    if nKeys == 0 then
        para(p, "When you choose a perk, it's saved for that level. Next run you get it automatically when you reach that level again.", "small")
    else
        para(p, nKeys .. " saved: " .. perkSummary() .. ".", "small")
        row(p, { B("See saved perks", function() openPerks() end), B("Forget all", function() forgetAll() end) })
    end

    local st = newStars()
    h2(p, "Ascend")
    para(p, "Stuck? Ascend to start over from floor 1, stronger than before. Your gold, upgrades and deepest floor reset. " ..
         "You earn 1 star for every 5 floors past floor 20 on your deepest-ever floor" .. (tr(S.peak) and " (so far: floor " .. max(S.peak, S.best) .. ")" or "") ..
         ". Each star gives +10% attack, HP and gold forever. Saved perks, achievements and your collection stay." ..
         (tr(S.stars) and " You have " .. S.stars .. " star" .. (S.stars > 1 and "s" or "") .. " (ascended " .. S.asc .. " time" .. (S.asc > 1 and "s" or "") .. ")." or ""), "small")
    if st > 0 then row(p, { B("Ascend for " .. st .. " new star" .. (st > 1 and "s" or ""), function() ascend() end) })
    else para(p, "Reach floor " .. (21 + 5 * (S.stars + 1) - 1) .. " to earn your next star.") end

    h2(p, "Reset progress")
    if ui.resetArm then
        para(p, "Are you sure? This erases everything: gold, upgrades, classes, pets, perks, achievements and your collection. It can't be undone.", "status")
        row(p, { B("Yes, erase everything", function() resetTap() end, false, true), B("Cancel", function() ui.resetArm = false; render() end) })
    else
        para(p, "Start over from nothing. You'll be asked to tap twice.", "small")
        row(p, { B("Reset all progress", function() resetTap() end) })
    end
    h2(p, "Save code")
    para(p, "Progress saves on this device automatically. A save code is a backup you can keep somewhere safe or move to another device. " ..
         "It works with the web version too.", "small")
    local b1, b2, b3, b4 = B("Show save code"), B("Load save code"), B("Save to file"), B("Load from file")
    b1.special, b2.special, b3.special, b4.special = "showCode", "loadCode", "saveFile", "loadFile"
    row(p, { b1, b2 })
    row(p, { b3, b4 })
    if tr(ui.codeMsg) then para(p, ui.codeMsg, "status") end
    return p
end

-- The "How to play" text.
function rulesText()
    local D = require("dungeon_data")
    local out = {}
    for _, r in ipairs(D.RULES) do
        if r[1] == "h2" or r[1] == "h3" then
            if #out > 0 then push(out, "") end
            push(out, r[2]:upper())
        elseif r[1] == "li" then push(out, "- " .. r[2])
        else push(out, r[2]) end
    end
    return join(out, "\n")
end

-- ================= CHARACTERS =================
function swapView()
    local r = S.run
    local v = { title = "Switch character", lines = { "Switching doesn't use a turn. Characters on the bench get half energy." }, rows = {} }
    for _, i in ipairs(S.party) do
        local c = charInfo(i)
        push(v.rows, { B(c.name .. (i == r.cact and " (active)" or "") .. ": energy " .. floor(energyOf(i)) .. "/" .. c.cost .. ". " .. c.talName,
                         function() switchChar(i) end, i == r.cact) })
    end
    push(v.rows, { B("Close", function() ui.swap = false; render() end) })
    return v
end
local function charEntry(p, c, btns, badge, withArts)
    local lines = { charLine(c), "Talent, " .. c.talName .. ": " .. talentText(c) .. ".",
                    "Burst, " .. c.burst .. " (" .. c.cost .. " energy): " .. burstText(c) }
    if withArts then push(lines, artSummary(c.i) .. ".") end
    entry(p, c.name, lines, btns, badge)
end
function renderChars()
    local p = Page("Characters")
    row(p, { B("Back to camp", function() ui.chars = false; render() end) })
    local owned = charsOwned()
    para(p, "You have " .. fmt(S.gold) .. " gold and " .. fmt(owned) .. " of " .. fmt(CH_N) .. " characters. " ..
         "Each summon is a character you don't have yet. Up to " .. PARTY_MAX .. " go in your party (How to play explains talents, bursts and artifacts).", "small")
    local odds = {}
    for r = 6, 1, -1 do push(odds, CH_RAR[r] .. " " .. num(CH_ODDS[r]) .. "%") end
    para(p, "Chances: " .. join(odds, ", ") .. ".", "small")
    if owned < CH_N then
        local c1, c10 = summonCost(1), summonCost(10)
        row(p, { B("Summon 1: " .. fmt(c1) .. " gold", function() summon(1) end, S.gold < c1, true),
                 B("Summon 10: " .. fmt(c10) .. " gold", function() summon(10) end, S.gold < c10 or owned + 10 > CH_N) })
    else para(p, "You own every character!", "status") end
    if ui.lastSummon and #ui.lastSummon > 0 then
        local names = {}
        for _, i in ipairs(ui.lastSummon) do local c = charInfo(i); push(names, c.name .. " (" .. charRarityText(c.r) .. ")") end
        para(p, "You got: " .. join(names, ", "), "status")
    end
    h3(p, "Party (" .. #S.party .. " of " .. PARTY_MAX .. ")")
    if owned > 0 then
        row(p, { B("Best party", function() bestParty() end, false, true), B("Best artifacts", function() bestArtifacts() end, #S.party == 0) })
        para(p, "Best party picks your 4 strongest characters (the strongest leads). Best artifacts puts your strongest artifacts on them, leader first. " ..
             "Artifacts found: " .. fmt(artCount()) .. " of " .. fmt(AR_N) .. ".", "small")
        if ui.artNote then para(p, ui.artNote, "status") end
    end
    if ui.partyNote then para(p, ui.partyNote, "status") end
    if #S.party == 0 then para(p, "Summon a character and it joins your party.", "small") end
    for _, i in ipairs(S.party) do
        local c = charInfo(i)
        charEntry(p, c, { B("Artifacts", function() openArtifacts(i) end), B("Remove", function() partyRemove(i) end),
                          B("Lead", function() partyLead(i) end, S.lead == i) }, S.lead == i and "Leader" or "In party", true)
    end
    if owned > 0 then
        local list = {}
        for i in pairs(S.chars) do push(list, i) end
        table.sort(list, function(a, b)
            local sa, sb = charScore(a), charScore(b)
            if sa ~= sb then return sa > sb end
            return a < b
        end)
        local per = 20
        local pages = ceil(#list / per)
        ui.chPage = max(0, min(ui.chPage or 0, pages - 1))
        h3(p, "Your characters (strongest first)")
        local go = function(n) ui.chPage = n; ui.bookTop = true; render() end
        if pages > 1 then pager(p, ui.chPage, pages, go) end
        for k = ui.chPage * per + 1, min(#list, (ui.chPage + 1) * per) do
            local i = list[k]
            local inP = contains(S.party, i)
            charEntry(p, charInfo(i), not inP and { B("Add to party", function() partyAdd(i) end, #S.party >= PARTY_MAX) } or nil,
                      inP and "In party" or nil)
        end
        if pages > 1 then pager(p, ui.chPage, pages, go) end
    end
    row(p, { B("Back to top", function() ui.bookTop = true; render() end), B("Back to camp", function() ui.chars = false; render() end) })
    return p
end
function bookChars(p)
    local r = ui.chR or 6
    local list = {}
    for i = 0, CH_N - 1 do if charInfo(i).r == r then push(list, i) end end
    para(p, "All " .. fmt(CH_N) .. " characters. You own " .. fmt(charsOwned()) .. ". Rarer characters are stronger and harder to summon. " ..
         "Every one has its own burst.", "small")
    local tabs = {}
    for k = 6, 1, -1 do push(tabs, B(CH_RAR[k], function() ui.chR = k; ui.chBPage = 0; ui.bookTop = true; render() end, false, k == r)) end
    row(p, tabs)
    h3(p, CH_RAR[r] .. " characters (" .. fmt(#list) .. ")")
    local per = 25
    local pages = ceil(#list / per)
    ui.chBPage = max(0, min(ui.chBPage or 0, pages - 1))
    local go = function(n) ui.chBPage = n; ui.bookTop = true; render() end
    pager(p, ui.chBPage, pages, go)
    for k = ui.chBPage * per + 1, min(#list, (ui.chBPage + 1) * per) do
        local c = charInfo(list[k])
        charEntry(p, c, nil, S.chars[c.i] and "Owned" or nil)
    end
    pager(p, ui.chBPage, pages, go)
end

-- ================= ARTIFACTS =================
function renderArtifacts()
    local c = charInfo(ui.artChar)
    local p = Page("Artifacts: " .. c.name:match("^%S+"))
    row(p, { B("Back to characters", function() ui.artChar = nil; ui.artSlot = nil; render() end) })
    if ui.artNote then para(p, ui.artNote, "status") end
    if not ui.artSlot then
        para(p, c.name .. " can wear one of each piece. " .. artSummary(c.i) .. ".", "small")
        para(p, "ATK, DEF, Crit, Dodge and Gold work while this character is active. HP adds to the whole party's max HP. " ..
             "Energy fills this character's burst faster, and Burst makes it hit harder.", "small")
        row(p, { B("Best artifacts for " .. c.name:match("^%S+"), function() bestArtifacts(c.i) end, artCount() == 0, true) })
        for _, sl in ipairs(AR_SLOTS) do
            local i = artOn(c.i, sl)
            local n = #artOwnedList(sl)
            if i then
                local a = artInfo(i)
                entry(p, AR_SLOT_NAME[sl] .. ": " .. a.name, { AR_RAR[a.r] .. ". " .. artStatsText(a) .. "." },
                      { B("Change", function() openArtSlot(sl) end), B("Take off", function() artUnequip(c.i, sl) end) })
            else
                entry(p, AR_SLOT_NAME[sl] .. ": empty", { "You have " .. n .. " " .. AR_SLOT_NAME[sl] .. ((n == 1 or sl == "sands") and "" or "s") .. "." },
                      { B("Choose", function() openArtSlot(sl) end, n == 0) })
            end
        end
    else
        local sl = ui.artSlot
        local list = artOwnedList(sl)
        h3(p, "Choose a " .. AR_SLOT_NAME[sl] .. " (" .. #list .. ", best first)")
        row(p, { B("Back", function() ui.artSlot = nil; ui.bookTop = true; render() end) })
        local per = 20
        local pages = max(1, ceil(#list / per))
        ui.arPage = max(0, min(ui.arPage or 0, pages - 1))
        local go = function(n) ui.arPage = n; ui.bookTop = true; render() end
        if pages > 1 then pager(p, ui.arPage, pages, go) end
        for k = ui.arPage * per + 1, min(#list, (ui.arPage + 1) * per) do
            local i = list[k]
            local a = artInfo(i)
            local w = artWearer(i)
            local badge = w == c.i and "Wearing" or (w and "On " .. charInfo(w).name:match("^%S+") or nil)
            entry(p, a.name, { AR_RAR[a.r] .. ". " .. artStatsText(a) .. "." },
                  w ~= c.i and { B("Equip", function() artEquip(c.i, i) end) } or nil, badge)
        end
        if pages > 1 then pager(p, ui.arPage, pages, go) end
    end
    return p
end
function bookArts(p)
    local r, sl = ui.abR or 7, ui.abS or "flower"
    para(p, "All " .. fmt(AR_N) .. " artifacts. You've found " .. fmt(artCount()) .. ". They come from treasure chests, and deeper floors give rarer ones. " ..
         "Each character wears one Flower, Plume, Sands, Goblet and Circlet.", "small")
    local tabs = {}
    for k = 7, 1, -1 do push(tabs, B(AR_RAR[k], function() ui.abR = k; ui.abPage = 0; ui.bookTop = true; render() end, false, k == r)) end
    row(p, tabs)
    local stabs = {}
    for _, s in ipairs(AR_SLOTS) do push(stabs, B(AR_SLOT_NAME[s], function() ui.abS = s; ui.abPage = 0; ui.bookTop = true; render() end, false, s == sl)) end
    row(p, stabs)
    local list = {}
    local si = find1(AR_SLOTS, sl) - 1
    for i = si, AR_N - 1, 5 do if artRarity(i) == r then push(list, i) end end
    h3(p, AR_RAR[r] .. " " .. AR_SLOT_NAME[sl] .. "s (" .. fmt(#list) .. ")")
    local per = 25
    local pages = max(1, ceil(#list / per))
    ui.abPage = max(0, min(ui.abPage or 0, pages - 1))
    local go = function(n) ui.abPage = n; ui.bookTop = true; render() end
    pager(p, ui.abPage, pages, go)
    for k = ui.abPage * per + 1, min(#list, (ui.abPage + 1) * per) do
        local a = artInfo(list[k])
        entry(p, a.name, { artStatsText(a) .. "." }, nil, artOwned(a.i) and "Found" or nil)
    end
    pager(p, ui.abPage, pages, go)
end

-- ================= SAVED PERKS =================
-- Each perk and how many levels it's saved for, most first: "Critical x12, Tough x8".
function perkSummary()
    local count, order = {}, {}
    for _, id in pairs(S.perkAt) do
        if not count[id] then push(order, id) end
        count[id] = (count[id] or 0) + 1
    end
    table.sort(order, function(a, b)
        if count[a] ~= count[b] then return count[a] > count[b] end
        return perkInfo(a).n < perkInfo(b).n
    end)
    local out = {}
    for _, id in ipairs(order) do push(out, perkInfo(id).n .. (count[id] > 1 and " x" .. count[id] or "")) end
    return join(out, ", ")
end
function openPerks() ui.perksView = true; ui.pkPage = 0; ui.bookTop = true; render() end
function renderPerks()
    local p = Page("Saved perks")
    row(p, { B("Back to camp", function() ui.perksView = false; render() end) })
    local keys = {}
    for k in pairs(S.perkAt) do push(keys, k) end
    ssort(keys, slotOrder)
    if #keys == 0 then
        para(p, "No saved perks. When you choose a perk, it's saved for that level.", "small")
    else
        para(p, #keys .. " saved: " .. perkSummary() .. ".", "small")
        para(p, "You get each one automatically when you reach that level. Tap Change to pick again next time.", "small")
        local per = 30
        local pages = ceil(#keys / per)
        ui.pkPage = max(0, min(ui.pkPage or 0, pages - 1))
        local go = function(n) ui.pkPage = n; ui.bookTop = true; render() end
        if pages > 1 then pager(p, ui.pkPage, pages, go) end
        for i = ui.pkPage * per + 1, min(#keys, (ui.pkPage + 1) * per) do
            local key = keys[i]
            local pi = perkInfo(S.perkAt[key])
            entry(p, (slotName(key):gsub("^l", "L")) .. ": " .. pi.n, { pi.d }, { B("Change", function() forgetPerk(key) end) })
        end
        if pages > 1 then pager(p, ui.pkPage, pages, go) end
        row(p, { B("Forget all", function() forgetAll() end) })
    end
    row(p, { B("Back to top", function() ui.bookTop = true; render() end), B("Back to camp", function() ui.perksView = false; render() end) })
    return p
end
