-- Endless Dungeon: fighting, monster turns, floor squares, turns, potions, scrolls and walking.
local M = require("dungeon_engine")
setfenv(1, M)

local DIR4 = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
local function dirs4() return { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } end
local function nz(v) return v ~= nil and v ~= 0 end

-- ================= FIGHTING =================
function levelCheck()
    local r = S.run
    while r.xp >= r.lv * 10 do
        r.xp = r.xp - r.lv * 10; r.lv = r.lv + 1
        statMax("lvl", r.lv)
        r.maxHp = r.maxHp + round(4 * starMul() * petHpMul()); r.atk = r.atk + 1
        heal(ceil(r.maxHp / 3))
        if r.lv % 2 == 0 then
            local sp = S.perkAt["L" .. r.lv]
            if sp then applyPerk(sp); say("Level up! Level " .. r.lv .. ". Your saved perk: " .. perkInfo(sp).n .. ".")
            else push(r.queue, "L" .. r.lv); say("Level up! You are level " .. r.lv .. ". Choose a perk.") end
        else say("Level up! You are level " .. r.lv .. ". (A perk comes every 2 levels.)") end
    end
end
-- Can a monster stand here? Ghosts and fliers ignore floor dangers; fiery monsters walk on lava.
function canStep(x, y, m)
    local r = S.run
    if x < 0 or y < 0 or x >= W or y >= H then return false end
    local t = r.map[y][x]
    local ghost, fly = m and has(m, "ghost"), m and has(m, "fly")
    if t == 1 and not ghost then return false end
    if not ghost and not fly then
        if t == 2 and not (m and (has(m, "fire") or has(m, "firewalk"))) then return false end
        if t == 3 or t == 7 or t == 8 then return false end
    end
    if x == r.px and y == r.py then return false end
    return not monAt(x, y)
end
function dropAt(x, y, item)
    local r = S.run
    local D = { { 0, 0 }, { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { -1, -1 }, { 1, -1 }, { -1, 1 } }
    for d = 1, #D do
        local nx, ny = x + D[d][1], y + D[d][2]
        if not (nx < 0 or ny < 0 or nx >= W or ny >= H or r.map[ny][nx] ~= 0)
           and not (itemAt(nx, ny) >= 0 or (nx == r.sx and ny == r.sy) or (nx == r.ex and ny == r.ey)) then
            item.x = nx; item.y = ny; push(r.items, item)
            return true
        end
    end
    return false
end
function revealAll()
    local r, n = S.run, 0
    for y = 0, H - 1 do for x = 0, W - 1 do if r.seen[y][x] == 0 then r.seen[y][x] = 1; n = n + 1 end end end
    if n > 0 then stat("a_Map Filler", n) end
end
function killMon(m)
    local r = S.run
    local idx = find1(r.mons, m)
    if not idx then return end
    table.remove(r.mons, idx)
    achKill(m)
    local g = goldAmt(m.gold) + m.stolen
    charOnKill(m, g)
    local gx = round(m.xp * (1 + cv("xp") / 100))
    r.goldRun = r.goldRun + g; r.kills = r.kills + 1; r.xp = r.xp + gx
    r.ks = (r.ks or 0) + 1
    if nz(cv("killbuff")) then r.kb = 3 end
    if not m.minion then stat("kills") end
    if m.kind == "boss" then stat("bosses") end
    if m.kind == "champ" then stat("champs") end
    say("You defeat " .. the(m.name) .. " and gain " .. gx .. " XP" .. (g ~= 0 and " and " .. g .. " gold" or "") .. ".")
    if nz(fx("vamp")) then local vh = heal(fx("vamp")); if vh > 0 then say("You drain " .. vh .. " HP.") end end
    if m.kind == "boss" and random() < 0.35 then
        local bp = rollPet(r.floor, 1)
        if dropAt(m.x, m.y, { k = "pet", p = bp }) then stat("a_Boss Pet Rescue"); say("A pet was hiding with the boss: " .. petName(bp) .. " (p)!") end
    end
    if m.drop then
        -- no weapons or armor in the dungeon: treasure carriers drop a potion or a scroll
        local it = supplyItem()
        if dropAt(m.x, m.y, it) then say("It dropped " .. supplyName(it) .. "!") end
    end
    if has(m, "wisp") then revealAll(); say("Its light shows you the whole floor!") end
    if has(m, "explode") and cheb(m.x, m.y, r.px, r.py) <= 1 then
        local ed = max(1, round(m.atk * 0.6) + rnd(-1, 1) - defOf())
        hurt(ed, "an explosion")
        if r.hp > 0 then stat("c_Explosion Survivor") end
        say(The(m.name) .. " explodes! You take " .. ed .. " damage.")
    end
    if has(m, "split") and not m.small then
        local made = 0
        for d = 1, 4 do
            if made >= 2 then break end
            local nx, ny = m.x + DIR4[d][1], m.y + DIR4[d][2]
            if canStep(nx, ny) then
                local sm = ceil(m.max / 3)
                push(r.mons, { i = m.i, e = eOf(m), ch = TYPES[m.i].c, name = "Small " .. eName(eOf(m)), abs = {}, kind = "", small = true, minion = false,
                               drop = false, shield = false, summons = 0, hp = sm, max = sm, atk = max(1, round(m.atk * 0.7)),
                               def = m.def, awake = true, frozen = 0, stolen = 0, gold = ceil(m.gold / 2), ac = 0, dot = nil,
                               slowT = 0, revealed = true, alarmed = false, cd = 0, xp = ceil(m.xp / 2), x = nx, y = ny })
                made = made + 1
            end
        end
        if made > 0 then say(The(TYPES[m.i].n) .. " splits in two!") end
    end
    bountyEvent("kill", m)
    levelCheck()
end
-- Achievement counts for every monster you defeat.
function achKill(m)
    local r, how, T = S.run, killHow, TYPES[m.i]
    killHow = ""
    if m.name == "Illusion" then stat("c_Illusion Popper") end
    if m.minion then return end
    stat("k_" .. T.c); stat("kf_" .. T.fam)
    local extra = #m.abs - #T.ab
    if extra >= 2 then stat("kt2") end
    if extra >= 3 then stat("kt3") end
    if extra >= 4 then stat("kt4") end
    for j = 1, #m.abs do stat("ka_" .. m.abs[j]) end
    if r.wpn then
        local wn = WCATS[r.wpn.cat or 0].n
        stat("kw_" .. wn); stat("km_" .. modInfo(r.wpn.mod).n)
        if how == "far" and ACHIDX["kr_" .. wn] ~= nil then stat("kr_" .. wn) end
    end
    if tr(r.level) then statA("lk_" .. lbase()) end
    stat("ck_" .. curClass()[2])
    if m.frozen > 0 then stat("c_Frozen Finisher") end
    if m.small then stat("c_Split Ender") end
    if m.stolen > 0 then stat("c_Thief Catcher") end
    if how == "fire" then stat("i_Fire Finisher")
    elseif how == "pet" then stat("petkill")
    elseif how == "cls" then stat("clskill")
    elseif how == "thorns" then stat("c_Thorny") end
    if m.kind == "champ" then stat("champkill") end
    if m.kind == "boss" then
        statA("zb_" .. ZONES[floor((r.floor - 1) / 10) % len(ZONES)].n)
        if tr(r.level) then statA("bl_" .. lbase()) end
        if r.hp < r.maxHp * 0.1 then stat("c_Glass Cannon") end
    end
end
function setDot(m, frac, turns, w)
    m.dot = { d = max(1, round(atkOf() * frac)), t = turns, w = w }   -- refreshes instead of stacking
end
-- One hit from you. primary = the main hit (extra hits and chains can't trigger more extra hits).
function strike(m, mult, primary, verb)
    local r = S.run
    if not m or not find1(r.mons, m) then return end
    local wasAwake, far, full = m.awake, abs(m.x - r.px) + abs(m.y - r.py) > 1, m.hp >= m.max
    m.awake = true; m.revealed = true
    if primary and has(m, "dodge") and chance(15) then say(The(m.name) .. " dodges your attack!"); return end
    if m.shield then m.shield = false; stat("c_Shield Breaker"); say(The(m.name) .. "'s shield blocks your hit! The shield breaks."); return end
    local C, mod = wcat(), wmod()
    local def = max(0, m.def - fx("pierce") - round(petSum("armordmg") * (1 + r.floor / 15)))
    if mod == "piercing" then def = round(def * 0.8) end
    if nz(cv("pierce")) then def = round(def * (1 - cv("pierce") / 100)) end
    if (C and C.pierceAll) or (mod == "spectral" and chance(15)) then def = 0 end
    local d = max(1, round(atkOf() * mult + rnd(-1, 1) - def))
    local notes = {}
    local cc = fx("crit") + ((C and C.crit) and C.crit or 0) + (mod == "lucky" and 5 or 0)
    if cc > 0 and chance(cc) then
        d = round(d * (2 + cv("critdmg") / 100)); push(notes, "Critical hit!"); stat("c_Critical Striker")
        if nz(cv("critheal")) then heal(max(1, round(r.maxHp * cv("critheal") / 200))) end
    end
    if mod == "sharp" and chance(15) then d = round(d * 1.5); push(notes, "Sharp hit!") end
    if mod == "cursed" and chance(10) then
        d = d * 2; push(notes, "The curse doubles your damage, and bites you!")
        r.hp = max(1, r.hp - max(1, round(r.maxHp * 0.05)))
    end
    if mod == "unstable" then
        local u = rnd(1, 10)
        if u == 1 then d = d * 3; push(notes, "Unstable: triple damage!") elseif u == 2 then d = max(1, round(d / 2)) end
    end
    local T = TYPES[m.i]
    if mod == "blessed" and T.undead then d = round(d * 1.2) end
    local pm = 1 + 0.03 * petSum("dmg") + 0.02 * petSum("allstats") + ((m.kind == "boss" or m.kind == "champ") and 0.06 * petSum("bossdmg") or 0) +
               (T.undead and 0.08 * petSum("undeaddmg") or 0)
    -- class bonuses
    local cpct = clsAll("dmg") + (far and cv("ranged") or cv("melee")) + ((C and C.n == "Staff") and cv("magic") or 0) +
                 ((C and C.n == "Sword") and cv("sword") or 0) + ((C and C.n == "Spear") and cv("spear") or 0) +
                 ((T.fam == "F" or T.fam == "I") and cv("beast") or 0) + (T.undead and cv("undead") or 0) +
                 ((m.kind == "boss" or m.kind == "champ" or T.elite) and cv("boss") or 0) + (r.hp < r.maxHp / 2 and cv("lowhp") or 0) +
                 ((r.kb or 0) > 0 and cv("killbuff") or 0) + min(10, r.ks or 0) * cv("killstack") + ((not wasAwake) and cv("unaware") or 0)
    pm = pm + cpct / 100
    pm = pm + charDmgBonus(m, primary) / 100
    if pm > 1 then d = round(d * pm) end
    if has(m, "swarm") then d = max(1, ceil(d / 2)) end
    m.hp = m.hp - d
    stat("c_Damage Dealer", d); statMax("c_Big Hitter", d)
    if r.wpn then stat("dw_" .. WCATS[r.wpn.cat or 0].n, d) end
    local lh, healed = fx("leech") + (mod == "leeching" and r.wpn.mv or 0), 0
    if lh > 0 then healed = healed + heal(lh); stat("c_Leech", lh) end
    if mod == "vampiric" then healed = healed + heal(ceil(d * 0.08)); stat("c_Leech", ceil(d * 0.08)) end
    say(join(notes, " ") .. (#notes > 0 and " " or "") .. "You " .. (verb or "hit") .. " " .. the(m.name) .. " for " .. d .. "." ..
        (healed > 0 and " You heal " .. healed .. " HP." or ""))
    if has(m, "spiky") and cheb(m.x, m.y, r.px, r.py) <= 1 then
        local sd = max(1, round(d * 0.2))
        hurt(sd, aName(m.name)); say("Its spikes hurt you for " .. sd .. ".")
    end
    if primary then
        r.hits = r.hits + 1
        if mod == "regenerating" and r.hits % 5 == 0 then heal(2 + floor(r.floor / 5)) end
        if mod == "explosive" and r.hits % 5 == 0 then
            say("Your weapon explodes!")
            local near = copy(r.mons)
            for i = 1, #near do
                if near[i] ~= m and cheb(near[i].x, near[i].y, m.x, m.y) <= 1 then strike(near[i], mult * 0.5, false, "blast") end
            end
        end
    end
    charOnHit(m, d, primary)
    if m.hp <= 0 then
        if primary and full then stat("c_One Hit Wonder") end
        if not wasAwake then stat("c_Sneak Attack") end
        killHow = far and "far" or "wpn"
        killMon(m); return
    end
    -- effects on a monster that's still standing
    charOnHitAlive(m, primary)
    if not find1(r.mons, m) then return end
    if nz(cv("burnhit")) and chance(cv("burnhit")) then setDot(m, 0.4, 2, "burning"); stat("c_Burner") end
    if nz(cv("slowhit")) and chance(cv("slowhit")) then m.slowT = 2 end
    if mod == "dull" and chance(20) then m.frozen = max(m.frozen, 1); stat("c_Stunner"); say(The(m.name) .. " is stunned.") end
    if C and C.stun and chance(C.stun) then m.frozen = max(m.frozen, 1); stat("c_Stunner"); say(The(m.name) .. " is stunned.") end
    if mod == "rusty" and chance(20) then setDot(m, 0.4, 3, "bleeding"); stat("c_Bleeder") end
    if mod == "flaming" and chance(25) then setDot(m, 0.6, 2, "burning"); stat("c_Burner") end
    if mod == "poisoned" and chance(25) then setDot(m, 0.4, 3, "poisoned") end
    if mod == "frozen" and chance(20) then m.slowT = 2 end
    if mod == "heavy" and chance(20) then
        local kx, ky = m.x + sign(m.x - r.px), m.y + sign(m.y - r.py)
        if canStep(kx, ky, m) then m.x = kx; m.y = ky end
        m.frozen = max(m.frozen, 1)
        stat("c_Knockback King")
        say("You knock " .. the(m.name) .. " back!")
    end
    if primary then
        if mod == "shocking" and chance(15) then
            for j = 1, #r.mons do
                local o = r.mons[j]
                if o ~= m and cheb(o.x, o.y, m.x, m.y) <= 2 then
                    say("Lightning jumps!"); stat("c_Chain Lightning"); strike(o, mult * 0.5, false, "shock"); break
                end
            end
        end
        if mod == "echoing" and r.hits % 4 == 0 then stat("c_Echo Master"); strike(m, mult * 0.35, false, "echo-hit") end
        if mod == "swift" and chance(15) then strike(m, mult * 0.5, false, "quickly hit") end
        if nz(cv("double")) and chance(cv("double")) then strike(m, mult * 0.5, false, "strike again and hit") end
        if C and C.dbl and chance(C.dbl) then strike(m, mult * 0.6, false, "hit again") end
        if mod == "swift" and chance(20) then r.freeTurn = true; stat("c_Free Turn") end
        if mod == "heavy" and chance(15) then r.extraStep = true end
    end
end
function attack(m)
    local r, C = S.run, wcat()
    strike(m, 1, true)
    if C and C.sweep then
        local near, hit = copy(r.mons), 1
        for i = 1, #near do
            local o = near[i]
            if o ~= m and cheb(o.x, o.y, r.px, r.py) <= 1 and not hiddenMon(o) then strike(o, 1, false, "sweep"); hit = hit + 1 end
        end
        if hit >= 3 then stat("c_Sweeper") end
    end
end
function monHits(m, kind)
    local r = S.run
    local dg = fx("dodge")
    if dg > 0 and chance(dg) then stat("c_Dodger"); say("You dodge " .. the(m.name) .. "!"); return end
    if charBlock(m) then return end
    if r.petShield then r.petShield = false; stat("petblock"); say("Your pet's shield blocks " .. the(m.name) .. "'s attack!"); return end
    if (r.clsShield or 0) > 0 then r.clsShield = r.clsShield - 1; say("Your class shield blocks " .. the(m.name) .. "'s attack!"); return end
    if petSum("block") > 0 and chance(min(50, 4 * petSum("block"))) then stat("petblock"); say("Your pet blocks " .. the(m.name) .. "'s attack!"); return end
    local a, slam = monAtk(m), false
    r.wasHit = true
    if kind == "" and has(m, "slam") then m.ac = m.ac + 1; if m.ac % 3 == 0 then a = a * 2; slam = true end end
    if kind == "charge" then a = round(a * 1.5) end
    local d = max(1, round((kind == "archer" and max(1, a - 1) or a) + rnd(-1, 1) - defOf()))
    if clsDefRed() > 0 then d = max(1, round(d * (1 - clsDefRed()))) end
    hurt(d, aName(m.name))
    local v = TYPES[m.i].v
    if v == "" then v = (has(m, "archer") and #TYPES[m.i].ab == 0) and "spits at" or "shoots" end
    if kind == "archer" then say(The(m.name) .. " " .. v .. " you for " .. d .. " damage.")
    elseif kind == "fire" then say(The(m.name) .. " breathes fire for " .. d .. " damage.")
    elseif kind == "charge" then say(The(m.name) .. " charges into you for " .. d .. " damage!")
    elseif slam then say(The(m.name) .. " slams you for " .. d .. " damage!")
    else say(The(m.name) .. " attacks for " .. d .. " damage.") end
    if r.hp <= 0 then return end
    for ai = 1, #m.abs do stat("ha_" .. m.abs[ai]) end
    stat("hf_" .. TYPES[m.i].fam)
    if has(m, "vamp") then m.hp = min(m.max, m.hp + d) end
    charOnHurt(m, d, kind)
    if r.hp <= 0 or not find1(r.mons, m) then return end
    local warded = (has(m, "poison") or has(m, "weaken") or has(m, "slowhit")) and charWard()
    if warded then say("You shrug it off.") end
    if has(m, "poison") and not warded then if r.poison == 0 then say("You are poisoned!") end; r.poison = 3 end
    if has(m, "weaken") and not warded then if r.weak == 0 then say("You feel weaker!") end; r.weak = 3 end
    if has(m, "slowhit") and not warded and chance(25) and not slowResist() then if r.slow == 0 then say("You are slowed!") end; r.slow = 2 end
    if has(m, "push") and kind == "archer" then
        local px, py = r.px + sign(r.px - m.x), r.py + sign(r.py - m.y)
        if px >= 0 and py >= 0 and px < W and py < H and r.map[py][px] ~= 1 and not monAt(px, py) then
            r.px = px; r.py = py; say("The wind pushes you back!"); stepOn()
        end
    end
    if has(m, "thief") and kind == "" and r.goldRun > 0 then
        local s = min(r.goldRun, 3 + r.floor)
        r.goldRun = r.goldRun - s; m.stolen = m.stolen + s; m.fleeing = 4
        say(The(m.name) .. " steals " .. s .. " gold and runs!")
    end
    local th = fx("thorns")
    if th > 0 and kind == "" then
        local td = max(1, round(d * th / 100))
        m.hp = m.hp - td
        if m.hp <= 0 then say("Your thorns finish off " .. the(m.name) .. "!"); killHow = "thorns"; killMon(m)
        else say("Your thorns hit " .. the(m.name) .. " for " .. td .. ".") end
    end
end
function lineClear(x0, y0, x1, y1)
    local dx, dy = sign(x1 - x0), sign(y1 - y0)
    local x, y = x0 + dx, y0 + dy
    while x ~= x1 or y ~= y1 do
        if S.run.map[y][x] == 1 or monAt(x, y) then return false end
        x = x + dx; y = y + dy
    end
    return true
end
local function orOne(v, d) if v == 0 then return d end return v end
function moveMon(m)
    local r = S.run
    local dx, dy = r.px - m.x, r.py - m.y
    local steps
    if has(m, "erratic") and random() < 0.4 then
        steps = shuffle(dirs4())
    elseif abs(dx) >= abs(dy) then
        steps = { { sign(dx), 0 }, { 0, orOne(sign(dy), 1) }, { 0, orOne(sign(dy), -1) } }
    else
        steps = { { 0, sign(dy) }, { orOne(sign(dx), 1), 0 }, { orOne(sign(dx), -1), 0 } }
    end
    for s = 1, #steps do
        local nx, ny = m.x + steps[s][1], m.y + steps[s][2]
        if (steps[s][1] ~= 0 or steps[s][2] ~= 0) and canStep(nx, ny, m) then m.x = nx; m.y = ny; return true end
    end
    return false
end
function stepAway(m)
    local r = S.run
    local best, bd = nil, abs(r.px - m.x) + abs(r.py - m.y)
    for d = 1, 4 do
        local nx, ny = m.x + DIR4[d][1], m.y + DIR4[d][2]
        local nd = abs(r.px - nx) + abs(r.py - ny)
        if nd > bd and canStep(nx, ny, m) then bd = nd; best = { nx, ny } end
    end
    if best then m.x = best[1]; m.y = best[2]; return true end
    return false
end
function placeNear(x, y, m, who)
    local D = shuffle(dirs4())
    for d = 1, 4 do
        local nx, ny = x + D[d][1], y + D[d][2]
        if canStep(nx, ny, who) then m.x = nx; m.y = ny; return true end
    end
    return false
end
function addBlast(x, y, d, who)
    local r = S.run
    for i = 1, #r.blasts do if r.blasts[i].x == x and r.blasts[i].y == y then return end end
    push(r.blasts, { x = x, y = y, t = 1, d = d, who = who, onYou = x == r.px and y == r.py })
end
-- Monster helpers: summoning, healing, shields, traps, decoys, bombs.
function specialMoves(m, i, dist)
    local r = S.run
    local vis = visible(m.x, m.y)
    m.cd = m.cd + 1
    if has(m, "reshield") and not m.shield and m.cd % 5 == 0 then m.shield = true; if vis then say(The(m.name) .. "'s shield comes back.") end end
    if has(m, "summon") and (m.summons or 0) < (m.summonMax or 3) and dist <= 7 and m.cd % 4 == 0 then
        local mn = makeMinion(r.floor, m.spawn)
        if placeNear(m.x, m.y, mn, nil) then
            push(r.mons, mn); m.summons = (m.summons or 0) + 1
            if vis then say(The(m.name) .. " calls " .. aName(mn.name) .. "!") end
        end
    end
    if has(m, "healer") and m.cd % 2 == 0 then
        local best = nil
        for j = 1, #r.mons do
            local o = r.mons[j]
            if o ~= m and o.hp < o.max and cheb(o.x, o.y, m.x, m.y) <= 4 and (not best or o.hp / o.max < best.hp / best.max) then best = o end
        end
        if best then
            best.hp = min(best.max, best.hp + ceil(best.max * 0.2))
            if vis then say(The(m.name) .. " heals " .. the(best.name) .. ".") end
        end
    end
    if has(m, "shielder") and m.cd % 4 == 0 then
        for j = 1, #r.mons do
            local o = r.mons[j]
            if o ~= m and not o.shield and cheb(o.x, o.y, m.x, m.y) <= 3 then
                o.shield = true
                if vis then say(The(m.name) .. " shields " .. the(o.name) .. ".") end
                break
            end
        end
    end
    if has(m, "trapper") and dist <= 5 and m.cd % 5 == 0 then
        local D, code = shuffle(dirs4()), J(TYPES[m.i].trap, 3)
        for j = 1, 4 do
            local tx, ty = r.px + D[j][1], r.py + D[j][2]
            if not (tx < 0 or ty < 0 or tx >= W or ty >= H or r.map[ty][tx] ~= 0 or itemAt(tx, ty) >= 0 or monAt(tx, ty))
               and not ((tx == r.sx and ty == r.sy) or (tx == r.ex and ty == r.ey)) then
                r.map[ty][tx] = code
                if vis then say(The(m.name) .. " sets " .. (code == 5 and "a web" or "a spike trap") .. " next to you!") end
                break
            end
        end
    end
    if has(m, "decoy") and m.cd % 6 == 0 and (m.summons or 0) < 4 then
        local dc = { i = m.i, ch = m.ch, name = "Illusion", abs = {}, kind = "", small = false, minion = true, drop = false, shield = false,
                     summons = 0, hp = 1, max = 1, atk = 1, def = 0, awake = true, frozen = 0, stolen = 0, gold = 0, xp = 1, ac = 0,
                     dot = nil, slowT = 0, revealed = true, alarmed = false, cd = 0 }
        if placeNear(m.x, m.y, dc, nil) then
            push(r.mons, dc); m.summons = (m.summons or 0) + 1
            if vis then say(The(m.name) .. " makes a fake copy of itself!") end
        end
    end
    if has(m, "bomber") and dist >= 2 and dist <= 5 and vis and m.cd % 3 == 0 then
        addBlast(r.px, r.py, m.atk, aName(m.name) .. "'s bomb")
        say(The(m.name) .. " throws a bomb! Step off the x!")
    end
    if TYPES[m.i].heart and m.cd % 3 == 0 then
        addBlast(r.px, r.py, round(m.atk * 0.8), "the Dungeon Heart")
        say("The Dungeon Heart pulses. The floor under you cracks! Step off the x!")
    end
    if has(m, "alarm") and not m.alarmed and vis then
        m.alarmed = true
        for j = 1, #r.mons do r.mons[j].awake = true end
        say(The(m.name) .. " sounds the alarm! Every monster wakes up.")
    end
end
function monstersAct(moveOnly)
    local r = S.run
    local list = copy(r.mons)
    for i = 1, #list do
        local m = list[i]
        repeat   -- "break" below works like JavaScript's "continue"
            if not find1(r.mons, m) then break end
            local dx, dy = r.px - m.x, r.py - m.y
            local dist, cd = abs(dx) + abs(dy), cheb(m.x, m.y, r.px, r.py)
            if moveOnly then
                if m.awake and m.frozen == 0 and dist > 1 and not has(m, "turret") then moveMon(m) end
                break
            end
            if m.dot then
                m.hp = m.hp - m.dot.d
                if visible(m.x, m.y) then say(The(m.name) .. " takes " .. m.dot.d .. " damage (" .. m.dot.w .. ").") end
                m.dot.t = m.dot.t - 1
                if m.dot.t <= 0 then m.dot = nil end
                if m.hp <= 0 then killMon(m); break end
            end
            if m.frozen > 0 then m.frozen = m.frozen - 1; break end
            if has(m, "regen") and m.hp < m.max then m.hp = min(m.max, m.hp + max(1, round(m.max / 15))) end
            local wake = (has(m, "statue") or has(m, "burrow")) and 2 or 5
            if not m.awake and cd <= wake then m.awake = true end
            if not m.awake then break end
            if cd <= 1 then m.revealed = true end
            specialMoves(m, i, dist)
            if r.hp <= 0 then return end
            local slowNow = (has(m, "slowmove") or m.slowT > 0) and r.turns % 2 == 1
            if m.slowT > 0 then m.slowT = m.slowT - 1 end
            if (m.fleeing or 0) > 0 then
                m.fleeing = m.fleeing - 1
                if stepAway(m) then break end
            end
            if dist == 1 then
                if has(m, "kite") and random() < 0.5 and stepAway(m) then break end
                monHits(m, "")
                if r.hp > 0 and has(m, "multi") and find1(r.mons, m) then monHits(m, "") end
                if r.hp <= 0 then return end
                break
            end
            if has(m, "kite") and dist <= 2 and stepAway(m) then break end
            local range = has(m, "archer") and 4 or (has(m, "fire") and 2 or 0)
            if range > 0 and dist <= range and (dx == 0 or dy == 0) and lineClear(m.x, m.y, r.px, r.py) and not hiddenMon(m) then
                monHits(m, (has(m, "fire") and dist <= 2) and "fire" or "archer")
                if r.hp <= 0 then return end
                break
            end
            if has(m, "turret") then break end
            if has(m, "pull") and dist >= 2 and dist <= 5 and (dx == 0 or dy == 0) and lineClear(m.x, m.y, r.px, r.py) then
                local nx, ny = m.x + sign(dx), m.y + sign(dy)
                if r.map[ny][nx] ~= 1 and not monAt(nx, ny) then
                    r.px = nx; r.py = ny; say(The(m.name) .. " pulls you closer!"); stepOn()
                    break
                end
            end
            if has(m, "charge") and dist >= 3 and dist <= 6 and (dx == 0 or dy == 0) and lineClear(m.x, m.y, r.px, r.py) then
                local cx, cy = r.px - sign(dx), r.py - sign(dy)
                if canStep(cx, cy, m) then
                    m.x = cx; m.y = cy; monHits(m, "charge")
                    if r.hp <= 0 then return end
                    break
                end
            end
            if has(m, "blink") and dist > 2 and random() < 0.3 and placeNear(r.px, r.py, m, m) then
                say(The(m.name) .. " blinks right next to you!")
                break
            end
            if slowNow then break end
            moveMon(m)
            if has(m, "fast") and abs(r.px - m.x) + abs(r.py - m.y) > 1 then moveMon(m) end
        until true
    end
end

-- ================= TURNS =================
function hazardDmg(d) return max(1, round(d * (1 - min(0.9, 0.15 * petSum("hazard") + cv("hazard") / 100)))) end
function slowResist() return chance(min(90, 15 * petSum("slowres"))) end
local SLOW_ACH = { web = "d_Web Breaker", mud = "d_Mud Stomper", sand = "d_Sand Strider" }
function stepOn()
    local r = S.run
    local t, d = r.map[r.py][r.px], nil
    if t == 2 then d = hazardDmg(ceil(r.maxHp * 0.15)); hurt(d, "lava"); say("The lava burns you for " .. d .. "!"); if r.hp > 0 then stat("d_Lava Walker") end
    elseif t == 3 then d = hazardDmg(ceil(r.maxHp * 0.1)); hurt(d, "spikes"); say("Spikes! You take " .. d .. " damage."); if r.hp > 0 then stat("d_Spike Stepper") end
    elseif t == 4 then d = ceil(r.maxHp * 0.25); heal(d); r.map[r.py][r.px] = 0; stat("d_Mushroom Muncher"); say("You eat a mushroom. +" .. d .. " HP.")
    elseif t == 5 then
        stat(SLOW_ACH[r.slowName] or "d_Swimmer")
        if not slowResist() then
            if r.slow == 0 then say("The " .. r.slowName .. " slows you down.") end
            r.slow = max(r.slow, 1)
        end
    elseif t == 7 then stat("d_Gas Breather"); if r.poison == 0 then say("You breathe poison gas!") end; r.poison = 3
    elseif t == 8 then d = hazardDmg(ceil(r.maxHp * 0.12)); hurt(d, "a shock"); say("Zap! The floor shocks you for " .. d .. "."); if r.hp > 0 then stat("d_Shock Proof") end
    elseif t == 9 and #r.portals == 2 then
        local o = (r.portals[1][1] == r.px and r.portals[1][2] == r.py) and r.portals[2] or r.portals[1]
        if not monAt(o[1], o[2]) then
            r.px = o[1]; r.py = o[2]; stat("d_Portal Jumper"); say("The portal pulls you through!"); reveal()
        end
    end
    pickup()
end
-- Move to a square. On ice you keep sliding until something stops you.
function moveTo(nx, ny, dx, dy)
    local r, slid = S.run, 0
    r.px = nx; r.py = ny; stat("a_Step Counter"); stepOn()
    while r.map[r.py][r.px] == 6 and slid < 8 and not r.panel and r.hp > 0 do
        local tx, ty = r.px + dx, r.py + dy
        if tx < 0 or ty < 0 or tx >= W or ty >= H or r.map[ty][tx] == 1 or monAt(tx, ty) then break end
        r.px = tx; r.py = ty; slid = slid + 1
        stepOn()
    end
    if slid > 0 then stat("d_Ice Skater"); say("You slide on the ice!") end
end
function pickup()
    local r = S.run
    local i = itemAt(r.px, r.py)
    if i >= 0 then
        local it = r.items[i]
        if it.k == "gold" then local v = round(goldAmt(it.v) * (1 + charGoldBonus() / 100)); r.goldRun = r.goldRun + v; say("You pick up " .. v .. " gold."); table.remove(r.items, i)
        elseif it.k == "potion" then r.potions = r.potions + 1; say("You find a potion."); table.remove(r.items, i)
        elseif it.k == "scroll" then r.scrolls[it.s] = r.scrolls[it.s] + 1; say("You find a " .. scrollInfo(it.s).n .. " scroll."); table.remove(r.items, i)
        elseif it.k == "relic" then
            local p = randomPerk(); applyPerk(p); table.remove(r.items, i); stat("i_Relic Hunter")
            say("An ancient relic! You gain " .. perkInfo(p).n .. ": " .. perkInfo(p).d .. ".")
        elseif it.k == "chest" then openChest(i)
        elseif it.k == "gear" then noteGear(it.g); gearFound(it.g); say("There is a " .. it.g.name .. " here."); r.panel = { t = "loot" }
        elseif it.k == "shop" then say("A merchant waves at you."); r.panel = { t = "shop" }
        elseif it.k == "shrine" then say("You find a shrine."); r.panel = { t = "shrine" }
        elseif it.k == "altar" then say("You find an enchanting table."); r.panel = { t = "altar" }
        elseif it.k == "pet" then say("You found " .. PETS[it.p][0] .. "!"); r.panel = { t = "pet" } end
    end
    if r.px == r.sx and r.py == r.sy then
        say("You found the stairs. Tap Go down when you're ready.")
        bountyEvent("stairs")
    end
end
function openChest(i)
    local r = S.run
    local it = r.items[i]
    stat("chests"); stat("i_Chest Opener Plus")
    bountyEvent("chest")
    local isMimic
    if it.mimic == nil then isMimic = r.floor >= 3 and chance(r.mimicP) else isMimic = it.mimic end
    if isMimic then
        local m = makeMimic(r.floor)
        if placeNear(r.px, r.py, m, nil) then
            table.remove(r.items, find1(r.items, it))
            push(r.mons, m)
            stat("i_Mimic Spotter")
            say("The chest grows teeth! It's a Mimic (MI)!")
            return
        end
    end
    -- chests hold gold and a potion or a scroll (weapons and armor only come from the camp shops)
    local g = round(goldAmt(rnd(3, 8) + r.floor) * (1 + charGoldBonus() / 100))
    r.goldRun = r.goldRun + g
    local s = supplyItem()
    if s.k == "potion" then r.potions = r.potions + 1 else r.scrolls[s.s] = r.scrolls[s.s] + 1 end
    table.remove(r.items, find1(r.items, it))
    local art = chestArtifact()
    say("You open the chest: " .. g .. " gold, " .. supplyName(s) .. art .. "!")
end
function blastsTick()
    local r, keep = S.run, {}
    for i = 1, #r.blasts do
        local b = r.blasts[i]
        b.t = b.t - 1
        if b.t > 0 then push(keep, b)
        else
            if r.px == b.x and r.py == b.y then
                local d = max(1, b.d - floor(defOf() / 2))
                if b.who == "a falling rock" then d = hazardDmg(d) end
                hurt(d, b.who); say("Boom! " .. cap(b.who) .. " hits you for " .. d .. ".")
                if r.hp > 0 and b.who ~= "a falling rock" then stat("c_Explosion Survivor") end
            elseif b.onYou then stat(b.who == "a falling rock" and "d_Rock Dodger" or "d_Bomb Dodger") end
            local m = monAt(b.x, b.y)
            if m and not TYPES[m.i].heart then
                m.hp = m.hp - max(1, round(b.d / 2))
                if m.hp <= 0 then killMon(m) end
            end
        end
    end
    r.blasts = keep
    if r.rocks and random() < 0.35 then
        local tx, ty = r.px, r.py
        if random() > 0.4 then tx = tx + rnd(-2, 2); ty = ty + rnd(-2, 2) end
        if tx > 0 and ty > 0 and tx < W - 1 and ty < H - 1 and r.map[ty][tx] ~= 1 then
            addBlast(tx, ty, max(2, ceil(r.maxHp * 0.15)), "a falling rock")
            if tx == r.px and ty == r.py then say("Rocks are falling on you! Move!") end
        end
    end
end
local function safeSpots(r)
    local spots = {}
    for y = 0, H - 1 do
        for x = 0, W - 1 do
            if r.map[y][x] == 0 and not monAt(x, y) and itemAt(x, y) < 0 and abs(x - r.px) + abs(y - r.py) > 5 then push(spots, { x, y }) end
        end
    end
    return spots
end

-- One turn passes: monsters act, poison, bombs and regeneration tick. Returns true if the run ended.
function passTurn()
    local r = S.run
    r.turns = r.turns + 1; r.ft = r.ft + 1
    stat("a_Turn Taker")
    statMax("i_Hoarder", r.potions); statMax("i_Library Card", scrollCount())
    blastsTick()
    if r.hp > 0 then petsAct() end
    if r.hp > 0 then classAct() end
    if r.hp > 0 then monstersAct(false) end
    if r.hp > 0 and (r.slow > 0 or r.extraStep) then monstersAct(true) end
    r.extraStep = false
    if r.slow == 1 and r.hp > 0 then stat("c_Unslowed") end
    if r.weak == 1 and r.hp > 0 then stat("c_Unweakened") end
    if r.slow > 0 then r.slow = r.slow - 1 end
    if r.weak > 0 then r.weak = r.weak - 1 end
    if (r.kb or 0) > 0 then r.kb = r.kb - 1 end
    if r.hp > 0 and r.poison > 0 then
        local pd = round((1 + floor(r.floor / 6)) * (1 - min(0.9, 0.2 * petSum("poisonres"))))
        r.poison = r.poison - 1
        if pd > 0 then hurt(pd, "poison"); say("Poison deals " .. pd .. " damage.") end
        if r.poison == 0 and r.hp > 0 then stat("c_Poison Survivor") end
    end
    if r.hp <= 0 and nz(cv("reviveFloor")) and not r.clsRevF then
        r.clsRevF = true; stat("clssave"); r.hp = max(1, round(r.maxHp * cv("reviveFloor") / 100))
        say("Your " .. curClass()[0] .. " power saves you from defeat! You get back up with " .. r.hp .. " HP.")
    end
    if r.hp <= 0 and nz(cv("revive")) and not r.clsRev then
        r.clsRev = true; stat("clssave"); r.hp = max(1, round(r.maxHp * cv("revive") / 100))
        say("Your " .. curClass()[0] .. " power saves you from defeat! You get back up with " .. r.hp .. " HP.")
    end
    if r.hp > 0 and nz(cv("lowshield")) and not r.clsLow and r.hp < r.maxHp * 0.3 then
        r.clsLow = true; r.clsShield = (r.clsShield or 0) + 1; say("A shield appears around you!")
    end
    if r.hp > 0 and nz(cv("regen")) and r.turns % 3 == 0 then
        local ch = heal(max(1, round(r.maxHp * cv("regen") / 200)))
        if ch > 0 and inFight() then say("Your class heals you for " .. ch .. " HP.") end
    end
    if r.hp > 0 and nz(cv("teleport")) and not r.clsTele and r.hp < r.maxHp * 0.25 then
        local cs = safeSpots(r)
        if #cs > 0 then local cp = pick(cs); r.px = cp[1]; r.py = cp[2]; r.clsTele = true; say("Your class power teleports you to safety!") end
    end
    if r.hp <= 0 and petHas("revive") and not r.revived then
        local rv = 0
        for q = 1, #S.team do if PETS[S.team[q]][3] == "revive" then rv = S.team[q]; break end end
        r.revived = true; stat("petsave"); r.hp = max(1, round(r.maxHp * min(0.8, 0.1 * petPower(rv))))
        say(petName(rv) .. " saves you from defeat! You get back up with " .. r.hp .. " HP.")
    end
    if r.hp <= 0 then endRun(J(r.lastHurt, "the dungeon")); return true end
    if fx("regen") > 0 and r.turns % 3 == 0 then
        local rh = heal(fx("regen"))
        if rh > 0 and inFight() then say("You regenerate " .. rh .. " HP.") end
    end
    if r.hp > 0 then charTurn() end
    if petSum("regen") > 0 and r.turns % 4 == 0 then
        local ph = heal(max(1, round(r.maxHp * 0.01 * petSum("regen"))))
        if ph > 0 then stat("petheal", ph); if inFight() then say("Your pet heals you for " .. ph .. " HP.") end end
    end
    if petHas("teleport") and not r.petTele and r.hp < r.maxHp * 0.25 then
        local spots = safeSpots(r)
        if #spots > 0 then local sp = pick(spots); r.px = sp[1]; r.py = sp[2]; r.petTele = true; say("Your pet teleports you to safety!") end
    end
    local b = r.bounty
    if b and b.state == "on" and b.t == "speed" and r.ft > b.need then b.state = "failed"; say("Bounty failed: too slow.") end
    reveal()
    discover()
    return false
end
function endTurn()
    local r = S.run
    if r.freeTurn then
        r.freeTurn = false
        if r.hp <= 0 then endRun(J(r.lastHurt, "the dungeon")); return end
        say("Swift strike! You get a free turn.")
        reveal(); checkPanels(); save(); render()
        return
    end
    if passTurn() then return end
    checkPanels(); save(); render()
end

function act(dx, dy)
    local r = S.run
    if blocked() then return end
    newTurn()
    if dx ~= 0 or dy ~= 0 then
        local nx, ny = r.px + dx, r.py + dy
        if nx < 0 or ny < 0 or nx >= W or ny >= H then return end
        local m = monAt(nx, ny)
        if m then
            if not m.revealed and (has(m, "burrow") or has(m, "disguise")) then m.revealed = true; stat("c_Surprise!"); say("Surprise! It's " .. aName(m.name) .. "!") end
            attack(m)
        elseif r.map[ny][nx] == 1 then say("A wall blocks the way."); render(); return
        else
            moveTo(nx, ny, dx, dy)
            if r.hp > 0 and not r.panel and charFleet() then r.freeTurn = true end
        end
    else
        say("You wait.")
    end
    endTurn()
end
-- Shoot or reach a monster that isn't right next to you (bows, spears, staves, firearms).
function rangedAttack(m)
    local C = wcat()
    newTurn()
    strike(m, 1, true, C.range > 2 and "shoot" or "stab")
    endTurn()
end
function canReach(m)
    local r, C = S.run, wcat()
    if not C or not C.range or hiddenMon(m) then return false end
    local dx, dy = m.x - r.px, m.y - r.py
    local dist = abs(dx) + abs(dy)
    if dist < 2 or dist > C.range or (dx ~= 0 and dy ~= 0) then return false end
    return lineClear(r.px, r.py, m.x, m.y) and visible(m.x, m.y)
end

function drink()
    local r = S.run
    if not r or r.panel or r.potions < 1 then return end
    ui.bag = false; ui.elev = false
    newTurn()
    r.potions = r.potions - 1
    stat("i_Potion Drinker"); r.nps = 0
    heal(ceil(r.maxHp / 2 * (1 + 0.1 * petSum("potion") + cv("potion") / 100)))
    r.poison = 0; r.weak = 0
    say("You drink a potion. HP " .. r.hp .. "/" .. r.maxHp .. ".")
    endTurn()
end

function openBag()
    if not S.run or S.run.panel then return end
    ui.elev = false; ui.bag = true; render()
end
function scrollCount()
    local s = S.run.scrolls
    return s.fire + s.freeze + s.tele + s.map
end
function seenMonsters()
    local out, ms = {}, S.run.mons
    for i = 1, #ms do if visible(ms[i].x, ms[i].y) and not hiddenMon(ms[i]) then push(out, ms[i]) end end
    return out
end
local SCROLL_ACH = { fire = "i_Fire Starter", freeze = "i_Ice Maker", tele = "i_Teleporter", map = "i_Mapmaker" }
function readScroll(id)
    local r = S.run
    if not r or r.panel or not tr(r.scrolls[id]) then return end
    ui.bag = false
    newTurn()
    r.scrolls[id] = r.scrolls[id] - 1
    stat(SCROLL_ACH[id])
    if r.hp < r.maxHp * 0.25 then stat("se_" .. scrollInfo(id).n) end
    if id == "fire" then
        local ms = seenMonsters()
        local dmg = max(5, atkOf() * 2)
        say(#ms > 0 and "Flames burst out at " .. #ms .. (#ms == 1 and " monster!" or " monsters!") or "Flames burst out, but nothing is in sight.")
        for i = 1, #ms do
            local dd = has(ms[i], "resist") and ceil(dmg / 2) or dmg
            ms[i].hp = ms[i].hp - dd; ms[i].awake = true
            if ms[i].hp <= 0 then killHow = "fire"; killMon(ms[i]) end
        end
    elseif id == "freeze" then
        local ms = seenMonsters()
        if #ms > 0 then stat("i_Freezer", #ms) end
        for i = 1, #ms do ms[i].frozen = has(ms[i], "resist") and 1 or 3 end
        say(#ms > 0 and "Ice covers " .. #ms .. (#ms == 1 and " monster." or " monsters.") or "Ice spreads out, but nothing is in sight.")
    elseif id == "tele" then
        local spots = safeSpots(r)
        if #spots > 0 then
            local s = pick(spots)
            r.px = s[1]; r.py = s[2]
            reveal()
            say("Whoosh! You teleport.")
        else say("The scroll fizzles.") end
    elseif id == "map" then
        revealAll()
        say("The whole floor appears on your map.")
    end
    endTurn()
end

function anyMonsterInView() return #seenMonsters() > 0 end
-- Shortest path over squares you've seen, avoiding walls, monsters and harmful floors.
function findPath(tx, ty)
    local r = S.run
    local prev, q, head = {}, { { r.px, r.py } }, 1
    prev[r.px .. "," .. r.py] = false
    while head <= #q do
        local c = q[head]; head = head + 1
        if c[1] == tx and c[2] == ty then
            local path = {}
            while prev[c[1] .. "," .. c[2]] do table.insert(path, 1, c); c = prev[c[1] .. "," .. c[2]] end
            return path
        end
        for d = 1, 4 do
            local nx, ny = c[1] + DIR4[d][1], c[2] + DIR4[d][2]
            local k = nx .. "," .. ny
            if not (nx < 0 or ny < 0 or nx >= W or ny >= H or prev[k] ~= nil) then
                local t, mm = r.map[ny][nx], monAt(nx, ny)
                if not (r.seen[ny][nx] == 0 or t == 1 or (mm and not hiddenMon(mm))) and
                   not ((harmful(t) or t == 6 or t == 9) and not (nx == tx and ny == ty)) then
                    prev[k] = c; push(q, { nx, ny })
                end
            end
        end
    end
    return nil
end
-- Walk many steps in one tap. Monsters still take their turns; you stop if anything hits you.
function walkTo(path)
    local r, walked = S.run, 0
    newTurn()
    for i = 1, #path do
        local nx, ny = path[i][1], path[i][2]
        local m = monAt(nx, ny)
        if m then
            if not m.revealed and (has(m, "burrow") or has(m, "disguise")) then m.revealed = true; stat("c_Surprise!"); say("Surprise! It's " .. aName(m.name) .. "!") end
            break
        end
        local hp0 = r.hp
        r.wasHit = false
        moveTo(nx, ny, nx - r.px, ny - r.py)
        if passTurn() then return end
        if r.px ~= nx or r.py ~= ny then break end
        walked = walked + 1
        if walked == 6 then stat("a_Long Walk") end
        -- keep walking past monsters; stop only if something hits or hurts you, or there's a choice to make
        if r.wasHit or r.hp < hp0 or r.panel or #r.queue > 0 then break end
    end
    checkPanels(); save(); render()
end

function tapCell(x, y)
    local r = S.run
    if blocked() then return end
    local dx, dy, m = x - r.px, y - r.py, monAt(x, y)
    if dx == 0 and dy == 0 then
        if r.px == r.sx and r.py == r.sy then descend()
        elseif onElevator() then openElevator()
        elseif not reopenHere() then act(0, 0) end
        return
    end
    if m and canReach(m) then rangedAttack(m); return end
    if abs(dx) + abs(dy) > 1 then
        local path = findPath(x, y)
        if path and #path > 0 then walkTo(path); return end
    end
    local sx, sy, mx, my = sign(dx), sign(dy), 0, 0
    if abs(dx) >= abs(dy) then mx = sx else my = sy end
    local tx, ty = r.px + mx, r.py + my
    if r.map[ty][tx] == 1 and not monAt(tx, ty) then
        if mx ~= 0 and sy ~= 0 then mx = 0; my = sy
        elseif my ~= 0 and sx ~= 0 then my = 0; mx = sx end
    end
    act(mx, my)
end
