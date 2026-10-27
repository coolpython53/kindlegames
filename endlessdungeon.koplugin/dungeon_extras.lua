-- Endless Dungeon: pets, classes, the achievements screen, and the camp weapon and armor shops.
local M = require("dungeon_engine")
setfenv(1, M)

local function nz(v) return v ~= nil and v ~= 0 end
local function byDistance(r)
    return function(a, b) return (abs(a.x - r.px) + abs(a.y - r.py)) - (abs(b.x - r.px) + abs(b.y - r.py)) end
end

-- ================= PETS =================
function petName(i)
    local n = PETS[i][0]
    local p = n:find(" the ", 1, true)
    if p and p > 1 then return n:sub(1, p - 1) end
    return n
end
function petLv(i) return S.pets[i] or 0 end
function petPower(i, lv)
    local l = J(lv, J(petLv(i), 1))
    return PRM[PETS[i][2]] * (1 + 0.15 * (l - 1)) * (1 + cv("petboost") / 100)
end
function petScore(i, lv) return petPower(i, lv) * (PET_WEIGHT[PETS[i][3]] or 1) end
-- Total power of every team pet with this effect.
function petSum(e)
    local s = 0
    if not S or not S.team then return 0 end
    for k = 1, #S.team do if PETS[S.team[k]][3] == e then s = s + petPower(S.team[k]) end end
    return s
end
function petHaste() return min(3, round(petSum("haste") / 2.5)) end
function petCd(e, P)
    local base
    if e == "bite" then base = 4 - floor(P / 2)
    elseif e == "bolt" then base = 7 - floor(P)
    elseif e == "chain" then base = 8 - floor(P)
    elseif e == "pulse" then base = 9 - floor(P)
    elseif e == "freeze" then base = 8 - floor(P)
    else base = 20 end
    return max(e == "bite" and 2 or 3, base - (e == "healburst" and 0 or petHaste()))
end
function petEffectText(i, lv)
    local e, P = PETS[i][3], petPower(i, lv)
    local R = round
    if e == "gold" then return "+" .. R(8 * P) .. "% gold" end
    if e == "loot" then return "Better gear rarity from chests and drops" end
    if e == "hazard" then return "Lava, spikes, gas, shock floors and falling rocks hurt " .. min(90, R(15 * P)) .. "% less" end
    if e == "poisonres" then return "Poison hurts " .. min(90, R(20 * P)) .. "% less" end
    if e == "slowres" then return min(90, R(15 * P)) .. "% chance to shrug off being slowed" end
    if e == "freeze" then return "Every " .. petCd(e, P) .. " turns, freezes the nearest monster for " .. (P >= 3 and 2 or 1) .. " turn" .. (P >= 3 and "s" or "") end
    if e == "pulse" then return "Every " .. petCd(e, P) .. " turns, hurts every monster within 2 squares (" .. R(12 * P) .. "% of your attack)" end
    if e == "bolt" then return "Every " .. petCd(e, P) .. " turns, hits the nearest monster you can see (" .. R(15 * P) .. "% of your attack)" end
    if e == "chain" then return "Every " .. petCd(e, P) .. " turns, hits up to 3 monsters you can see (" .. R(9 * P) .. "% of your attack each)" end
    if e == "bite" then return "Every " .. petCd(e, P) .. " turns, bites a monster next to you (" .. R(12 * P) .. "% of your attack)" end
    if e == "healburst" then return "When your HP drops below 40%, heals " .. R(20 + 10 * P) .. "% of it (every 20 turns)" end
    if e == "seehidden" then return "Shows hidden monsters (burrowers and disguises)" .. (P >= 3 and ", and you see 1 square farther" or "") end
    if e == "reveal" then return P >= 3 and "Shows the whole map on every floor" or "You see 1 square farther" end
    if e == "sight" then return P >= 4 and "You see 2 squares farther" or "You see 1 square farther" end
    if e == "regen" then return "Heals " .. max(1, R(P)) .. "% of your max HP every 4 turns" end
    if e == "floorheal" then return "Heals " .. R(8 * P) .. "% of your max HP on every new floor" end
    if e == "potion" then return "Potions heal " .. R(10 * P) .. "% more" end
    if e == "hp" then return "+" .. R(5 * P) .. "% max HP" end
    if e == "crit" then return "+" .. R(3 * P) .. "% critical" end
    if e == "dodge" then return "+" .. R(3 * P) .. "% dodge" end
    if e == "armor" then return "+" .. R(P) .. " armor, more on deeper floors" end
    if e == "block" then return min(50, R(4 * P)) .. "% chance to block a hit completely" end
    if e == "shieldfloor" then return "Blocks the first hit on every floor" end
    if e == "teleport" then return "Once per floor, teleports you away when your HP drops below 25%" end
    if e == "revive" then return "Once per run, saves you from defeat with " .. min(80, R(10 * P)) .. "% HP" end
    if e == "bossdmg" then return "+" .. R(6 * P) .. "% damage to bosses and champions" end
    if e == "undeaddmg" then return "+" .. R(8 * P) .. "% damage to undead" end
    if e == "armordmg" then return "Your hits ignore " .. R(P) .. "+ monster armor (more on deeper floors)" end
    if e == "dmg" then return "+" .. R(3 * P) .. "% damage" end
    if e == "allstats" then return "+" .. R(2 * P) .. "% damage, +" .. R(3 * P) .. "% max HP and a little armor" end
    if e == "haste" then return "Your other pets use their abilities sooner" end
    if e == "mimicwarn" then return "Marks treasure chests that are really Mimics" end
    return ""
end
function rollPet(f, bonus)
    local ri, p = 0, 0.28 + min(0.3, f / 120)
    while ri < 5 and random() < p do ri = ri + 1 end
    ri = min(5, min(ri, 1 + floor(f / 7)) + (bonus or 0))
    local all, fresh, own = {}, {}, {}
    for i = 0, len(PETS) - 1 do
        if PETS[i][2] == ri then
            push(all, i)
            if not tr(S.pets[i]) then push(fresh, i) elseif S.pets[i] < 5 then push(own, i) end
        end
    end
    -- 30% of the time it's one you already have (so pets can level up), otherwise a new one
    if #own > 0 and random() < 0.3 then return pick(own) end
    return #fresh > 0 and pick(fresh) or pick(all)
end
-- Position (in S.team) of your weakest team pet, or 0 when the team is empty.
function weakestPet()
    local w = 0
    for k = 1, #S.team do if w == 0 or petScore(S.team[k]) < petScore(S.team[w]) then w = k end end
    return w
end
-- Is a newly found pet a good addition to your team?
function petVerdict(i)
    local lv = petLv(i)
    if lv >= 5 then return { good = false, why = "You already have " .. petName(i) .. " at the top level (5). Taking it gives you gold instead." } end
    if lv > 0 then return { good = true, why = "You already have " .. petName(i) .. ". Another one makes it level " .. (lv + 1) .. " and stronger." } end
    if #S.team < TEAM_MAX then return { good = true, why = "You have a free pet slot (" .. #S.team .. " of " .. TEAM_MAX .. " used)." } end
    local w = weakestPet()
    if petScore(i, 1) > petScore(S.team[w]) * 1.05 then return { good = true, swap = w, why = "It is stronger than " .. petName(S.team[w]) .. ", your weakest pet." } end
    return { good = false, why = "It is weaker than all " .. TEAM_MAX .. " of your pets. It still joins your collection at camp." }
end
function petTake(how)
    local r, it = S.run, hereItem()
    if not it or it.k ~= "pet" then closePanel(); return end
    local i = it.p
    local lv = petLv(i)
    table.remove(r.items, find1(r.items, it))
    stat("pr_" .. PRAR[PETS[i][2]])
    if lv == 4 then stat("pl5_" .. PRAR[PETS[i][2]]) end
    if lv >= 5 then
        local g = goldAmt(30 + 10 * PETS[i][2] * PETS[i][2] + r.floor)
        r.goldRun = r.goldRun + g
        r.log = { petName(i) .. " is already the top level. You get " .. g .. " gold." }
        closePanel(); return
    end
    if lv > 0 then S.pets[i] = lv + 1; r.log = { petName(i) .. " grows stronger! It is now level " .. (lv + 1) .. "." }; closePanel(); return end
    S.pets[i] = 1
    if how == "add" and #S.team < TEAM_MAX then push(S.team, i); r.log = { petName(i) .. " joins your team!" }
    elseif how == "swap" and #S.team > 0 then
        local w = weakestPet()
        local old = S.team[w]
        S.team[w] = i
        r.log = { petName(i) .. " joins your team. " .. petName(old) .. " goes back to camp." }
    else r.log = { petName(i) .. " goes to your pet collection at camp." } end
    closePanel()
end
-- Pets with attacks act once per turn, after you.
function petsAct()
    local r = S.run
    if #S.team == 0 then return end
    if not r.petCd then r.petCd = {} end
    local m   -- (kept between pets on purpose, exactly like the web version)
    for k = 1, #S.team do
        local i = S.team[k]
        local e = PETS[i][3]
        repeat
            if not PET_ACTIVE[e] then break end
            if (r.petCd[i] or 0) > 0 then r.petCd[i] = r.petCd[i] - 1; break end
            local P, nm, acted, ms = petPower(i), petName(i), false, seenMonsters()
            if e == "healburst" then
                if r.hp < r.maxHp * 0.4 then
                    local hv = round(r.maxHp * (0.2 + 0.1 * P))
                    stat("petheal", min(hv, r.maxHp - r.hp)); heal(hv); say(nm .. " heals you for " .. hv .. "!"); acted = true
                end
            elseif e == "bite" then
                for j = 1, #ms do if abs(ms[j].x - r.px) + abs(ms[j].y - r.py) == 1 then m = ms[j]; break end end
                if m then petHit(m, 0.12 * P, nm, "bites"); acted = true end
            elseif #ms > 0 then
                ssort(ms, byDistance(r))
                if e == "bolt" then petHit(ms[1], 0.15 * P, nm, "blasts"); acted = true
                elseif e == "chain" then for j = 1, min(3, #ms) do petHit(ms[j], 0.09 * P, nm, "zaps") end; acted = true
                elseif e == "pulse" then
                    local near = {}
                    for j = 1, #ms do if cheb(ms[j].x, ms[j].y, r.px, r.py) <= 2 then push(near, ms[j]) end end
                    if #near > 0 then
                        say(nm .. " unleashes a burst!")
                        for j = 1, #near do petHit(near[j], 0.12 * P, "", "") end
                        acted = true
                    end
                elseif e == "freeze" then
                    m = ms[1]
                    if not TYPES[m.i].heart then m.frozen = max(m.frozen, P >= 3 and 2 or 1); say(nm .. " freezes " .. the(m.name) .. "!"); acted = true end
                end
            end
            if acted then r.petCd[i] = petCd(e, P) end
        until true
    end
end
function petHit(m, frac, nm, verb)
    if not find1(S.run.mons, m) then return end
    local d = max(1, round(atkOf() * frac - m.def / 2))
    m.hp = m.hp - d; m.awake = true
    if nm ~= "" then say(nm .. " " .. verb .. " " .. the(m.name) .. " for " .. d .. ".") end
    if m.hp <= 0 then killHow = clsHitting and "cls" or "pet"; killMon(m) end
end
function petTeamNames()
    local out = {}
    for k = 1, #S.team do push(out, petName(S.team[k])) end
    return join(out, ", ")
end
function openPets() ui.pets = true; ui.bookTop = true; render() end
function petAdd(i) if #S.team < TEAM_MAX and not contains(S.team, i) and S.pets[i] then push(S.team, i); save(); render() end end
function petRemove(i) local k = find1(S.team, i); if k then table.remove(S.team, k); save(); render() end end

-- ================= CLASSES =================
function curClass() return CLASSES[S.cls or 0] end
-- Sum of one effect on your equipped class.
function cv(type_)
    local e, v = curClass()[4], 0
    for i = 0, len(e) - 1 do if e[i][0] == type_ then v = v + e[i][1] end end
    return v
end
function clsAll(type_) return cv(type_) + cv("allstats") end
function clsDefRed() local Dv = clsAll("def"); return Dv > 0 and Dv / (Dv + 100) or 0 end
function clsHpMul() return 1 + clsAll("hp") / 100 end
function clsEffectText(i)
    local e, out = CLASSES[i][4], {}
    if len(e) == 0 then return "No bonuses" end
    for k = 0, len(e) - 1 do
        local t, v = e[k][0], e[k][1]
        local s
        if t == "dmg" then s = "+" .. v .. "% damage"
        elseif t == "def" then s = "+" .. v .. "% defense (you take " .. round(100 * v / (v + 100)) .. "% less damage from monsters)"
        elseif t == "hp" then s = "+" .. v .. "% max HP"
        elseif t == "allstats" then s = "+" .. v .. "% damage, defense and max HP"
        elseif t == "melee" then s = "+" .. v .. "% damage when you hit monsters next to you"
        elseif t == "ranged" then s = "+" .. v .. "% damage when you shoot or reach from a distance"
        elseif t == "magic" then s = "+" .. v .. "% damage with staves and Fire scrolls"
        elseif t == "sword" then s = "+" .. v .. "% damage with swords"
        elseif t == "spear" then s = "+" .. v .. "% damage with spears"
        elseif t == "beast" then s = "+" .. v .. "% damage to fast and insect monsters"
        elseif t == "undead" then s = "+" .. v .. "% damage to undead"
        elseif t == "boss" then s = "+" .. v .. "% damage to bosses and champions"
        elseif t == "lowhp" then s = "+" .. v .. "% damage when you are below half HP"
        elseif t == "killbuff" then s = "+" .. v .. "% damage for 3 turns after you defeat a monster"
        elseif t == "killstack" then s = "+" .. v .. "% damage for each monster you defeat on a floor (up to 10)"
        elseif t == "unaware" then s = "+" .. v .. "% damage to monsters that haven't noticed you"
        elseif t == "crit" then s = "+" .. v .. "% critical chance"
        elseif t == "critdmg" then s = "Critical hits do " .. v .. "% more damage"
        elseif t == "critheal" then s = "Critical hits heal you " .. num(v / 2) .. "% of your max HP"
        elseif t == "dodge" then s = "+" .. v .. "% dodge"
        elseif t == "xp" then s = "+" .. v .. "% experience"
        elseif t == "gold" then s = "+" .. v .. "% gold"
        elseif t == "loot" then s = "Better gear rarity"
        elseif t == "potion" then s = "Potions heal " .. v .. "% more"
        elseif t == "hazard" then s = "Floor dangers hurt " .. min(90, v) .. "% less"
        elseif t == "sight" then s = "You see " .. v .. " square" .. (v > 1 and "s" or "") .. " farther"
        elseif t == "seehidden" then s = "Shows hidden monsters"
        elseif t == "petboost" then s = "Your pets are " .. v .. "% stronger"
        elseif t == "regen" then s = "Heals " .. num(v / 2) .. "% of your max HP every 3 turns"
        elseif t == "revive" then s = "Once per run, saves you from defeat with " .. v .. "% HP"
        elseif t == "reviveFloor" then s = "Once per floor, saves you from defeat with " .. v .. "% HP"
        elseif t == "lowshield" then s = "Once per floor, a shield appears when your HP drops below 30%"
        elseif t == "shieldfloor" then s = "Blocks the first " .. (v > 1 and v .. " hits" or "hit") .. " on every floor"
        elseif t == "teleport" then s = "Once per floor, teleports you away when your HP drops below 25%"
        elseif t == "summon" then s = "A summoned helper hits the nearest monster every 4 turns (" .. v .. "% of your attack)"
        elseif t == "pulse" then s = "Every 6 turns, hurts every monster within 2 squares (" .. v .. "% of your attack)"
        elseif t == "chain" then s = "Every 5 turns, hits up to 3 monsters you can see (" .. v .. "% of your attack each)"
        elseif t == "freeze" then
            s = "Every 7 turns, freezes " .. (v >= 6 and "every monster you can see for 2 turns" or
                "the nearest monster for " .. (v >= 3 and 2 or 1) .. " turn" .. (v >= 3 and "s" or ""))
        elseif t == "burnhit" then s = v .. "% chance your hits set monsters burning"
        elseif t == "slowhit" then s = v .. "% chance your hits slow monsters"
        elseif t == "double" then s = v .. "% chance to hit again for half damage"
        elseif t == "pierce" then s = "Your hits ignore " .. v .. "% of monster armor" end
        if s then push(out, s) end
    end
    return join(out, ". ")
end
-- Class powers that act on their own every few turns.
local CLS_CD = { summon = 4, pulse = 6, chain = 5, freeze = 7 }
function classAct()
    local r = S.run
    local e = curClass()[4]
    if not r.clsCd then r.clsCd = {} end
    clsHitting = true
    for k = 0, len(e) - 1 do
        local t, v = e[k][0], e[k][1]
        local cdBase = CLS_CD[t]
        repeat
            if not cdBase then break end
            if (r.clsCd[t] or 0) > 0 then r.clsCd[t] = r.clsCd[t] - 1; break end
            local ms = seenMonsters()
            if #ms == 0 then break end
            ssort(ms, byDistance(r))
            local nm, acted = curClass()[0], false
            if t == "summon" then petHit(ms[1], v / 100, "Your " .. nm .. " helper", "hits"); acted = true
            elseif t == "chain" then for j = 1, min(3, #ms) do petHit(ms[j], v / 100, nm, "strikes") end; acted = true
            elseif t == "pulse" then
                local near = {}
                for j = 1, #ms do if cheb(ms[j].x, ms[j].y, r.px, r.py) <= 2 then push(near, ms[j]) end end
                if #near > 0 then
                    say("Your " .. nm .. " power bursts out!")
                    for j = 1, #near do petHit(near[j], v / 100, "", "") end
                    acted = true
                end
            elseif t == "freeze" then
                local list = v >= 6 and ms or { ms[1] }
                for j = 1, #list do if not TYPES[list[j].i].heart then list[j].frozen = max(list[j].frozen, v >= 3 and 2 or 1) end end
                say("Your " .. nm .. " power freezes " .. (#list > 1 and #list .. " monsters" or the(list[1].name)) .. "!")
                acted = true
            end
            if acted then r.clsCd[t] = cdBase end
        until true
    end
    clsHitting = false
end
function openClasses() ui.classes = true; ui.bookTop = true; ui.clsTier = curClass()[2]; render() end
function buyClass(i)
    local c = CLASSES[i]
    if S.clsOwn[i] or S.gold < c[1] then return end
    S.gold = S.gold - c[1]; S.clsOwn[i] = 1
    if (S.cls or 0) ~= i then stat("clsswitch") end
    S.cls = i
    stat("a_Big Spender", c[1]); stat("a_Class Shopper", c[1])
    campClaim()
    save(); render()
end
function equipClass(i)
    if S.clsOwn[i] then
        if (S.cls or 0) ~= i then stat("clsswitch") end
        S.cls = i; campClaim(); save(); render()
    end
end
function ownedCount() return countKeys(S.clsOwn) end

-- ================= ACHIEVEMENTS SCREEN =================
function openAch() ui.achs = true; ui.achPage = 0; ui.bookTop = true; render() end
function achSec(n) ui.achSec = n; ui.achPage = 0; ui.bookTop = true; render() end
function achPage(n) ui.achPage = ui.achPage + n; ui.bookTop = true; render() end

-- ================= CAMP WEAPON SHOP =================
-- 5000 weapons you buy at camp and keep forever. The one you equip is your starting weapon on every run.
function cwName(i)
    local k = floor(i / 10)
    return CWORDS.adj[k % 50] .. " " .. CWORDS.noun[i % 10][floor(k / 50)]
end
function niceNum(n)
    if n < 100 then return round(n) end
    local p = 10 ^ (floor(math.log(n) / math.log(10)) - 1)
    return round(n / p) * p
end
function cwPrice(i) return niceNum(100 * 1.0045 ^ i) end
function cwFloor(i) return 1 + floor(i / 25) end   -- as strong as gear from this floor
-- Builds a fresh copy of camp weapon i (same stats every time).
function campWpn(i)
    local c = i % 10
    local C = WCATS[c]
    local Md = modInfo(CW_MODS[(i * 7 + floor(i / 10)) % len(CW_MODS)])
    local F = cwFloor(i)
    local raw = (2 + floor(F / 2)) * 1.1
    local g = { slot = "wpn", cat = c, base = cwName(i), mod = Md.id, atk = max(1, round(raw * C.mult * (1 + Md.pct / 100))),
                def = 0, fxs = {}, mv = 2 + floor(F / 5), rar = min(len(RAR) - 1, floor(i / 560)), camp = i }
    for j = 0, RAR_FX[g.rar] - 1 do
        local k = WFX[(i + 2 * j) % len(WFX)]
        push(g.fxs, { fx = k, v = sfxValue(k, F) })
    end
    g.name = Md.n .. " " .. g.base
    return g
end
function cwOwned() return countKeys(S.cw) end
function openWeapons()
    ui.wpns = true; ui.bookTop = true
    if S.cwEq >= 0 then ui.cwTier = floor(S.cwEq / CW_TIER) + 1; ui.cwPage = floor((S.cwEq % CW_TIER) / CW_PAGE) end
    render()
end
function cwGo(tier, page) ui.cwTier = tier; ui.cwPage = page; ui.bookTop = true; render() end
-- Jump to the strongest weapon you can afford and don't own yet.
function cwBest()
    for i = CW_N - 1, 0, -1 do
        if not S.cw[i] and cwPrice(i) <= S.gold then cwGo(floor(i / CW_TIER) + 1, floor((i % CW_TIER) / CW_PAGE)); return end
    end
    cwGo(1, 0)
end
function buyCW(i)
    local c = cwPrice(i)
    if S.cw[i] or S.gold < c then return end
    S.gold = S.gold - c; S.cw[i] = 1; S.cwEq = i
    stat("a_Big Spender", c)
    campClaim(); save(); render()
end
function equipCW(i) if i < 0 or S.cw[i] then S.cwEq = i; save(); render() end end

-- ================= CAMP ARMOR SHOP =================
-- 1000 armors you buy at camp and keep forever. The one you equip is your starting armor on every run.
function caName(i) return AWORDS.adj[i % 50] .. " " .. AWORDS.noun[floor(i / 50)] end
function caPrice(i) return niceNum(100 * 1.0227 ^ i) end
function caFloor(i) return 1 + floor(i / 5) end   -- as strong as armor from this floor
function campArm(i)
    local F = caFloor(i)
    local g = { slot = "arm", atk = 0, def = max(1, round((2 + floor(F / 4)) * 1.1)), fxs = {}, base = caName(i),
                rar = min(len(RAR) - 1, floor(i / 112)), camp = i }
    for j = 0, RAR_FX[g.rar] - 1 do
        local k = AFX[(i + 2 * j) % len(AFX)]
        push(g.fxs, { fx = k, v = sfxValue(k, F) })
    end
    g.name = g.base .. (#g.fxs > 0 and " of " .. CA_PRE[g.fxs[1].fx] or "")
    return g
end
function caOwned() return countKeys(S.ca) end
function openArmor()
    ui.arms = true; ui.bookTop = true
    if S.caEq >= 0 then ui.caTier = floor(S.caEq / CA_TIER) + 1; ui.caPage = floor((S.caEq % CA_TIER) / CA_PAGE) end
    render()
end
function caGo(tier, page) ui.caTier = tier; ui.caPage = page; ui.bookTop = true; render() end
function caBest()
    for i = CA_N - 1, 0, -1 do
        if not S.ca[i] and caPrice(i) <= S.gold then caGo(floor(i / CA_TIER) + 1, floor((i % CA_TIER) / CA_PAGE)); return end
    end
    caGo(1, 0)
end
function buyCA(i)
    local c = caPrice(i)
    if S.ca[i] or S.gold < c then return end
    S.gold = S.gold - c; S.ca[i] = 1; S.caEq = i
    stat("a_Big Spender", c)
    campClaim(); save(); render()
end
function equipCA(i) if i < 0 or S.ca[i] then S.caEq = i; save(); render() end end

-- Reset everything. The first tap arms the button, the second tap erases.
function resetTap()
    if not ui.resetArm then ui.resetArm = true; render(); return end
    ui.resetArm = false
    S = freshSave(); fixSave()
    ui.startAt = 1; ui.showCode = false
    S.last = { note = "All progress was reset. A brand new adventure begins!" }
    save(); render()
    ui.bookTop = true
end
function traitCount() return len(AB_ORDER) end
function openBook(tab) ui.book = tab or "enemies"; ui.bookTop = true; render() end
