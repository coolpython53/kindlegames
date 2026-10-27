--[[
Endless Dungeon: characters.

10,000 characters you summon with gold at camp (never the same one twice). Up to 4 go in
your party; one of them is active in the dungeon, and you can switch any time for free.

Every character has:
  * a rarity (Common to Mythic): rarer ones are harder to summon and stronger
  * stats: attack (while active) and max HP (for the whole party, all run long)
  * a talent: something special it does while active (classes only boost stats)
  * a burst: a big move of its own, used when its energy bar is full.
    Energy comes from hitting, defeating monsters and getting hit. The active
    character gets full energy, the others in the party get half.
    Every character needs a different amount.

Characters are built from their number, so the same number always makes the same character.
--]]
local M = require("dungeon_engine")
setfenv(1, M)

CH_N = 10000
PARTY_MAX = 4

-- ================= RARITY =================
CH_RAR = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }
CH_STARS = { "*", "**", "***", "****", "*****", "******" }
CH_ODDS = { 40, 30, 18, 8.5, 3, 0.5 }                  -- summon chance in %
local R_COUNT = { 3500, 3000, 2000, 1000, 400, 100 }   -- how many of each
local R_ATK, R_ATK_S = { 4, 8, 14, 22, 34, 50 }, { 3, 4, 6, 8, 10, 15 }
local R_HP, R_HP_S = { 2, 4, 7, 11, 16, 24 }, { 2, 3, 3, 4, 6, 8 }
local R_TAL = { 1, 1.4, 1.9, 2.5, 3.2, 4 }

-- ================= NAMES: 100 first names x 100 family names =================
local FIRST = {
    "Aria", "Kael", "Lyra", "Bram", "Sela", "Doran", "Mira", "Thane", "Vex", "Iris",
    "Corin", "Nyx", "Talia", "Rook", "Zara", "Edrin", "Wren", "Orrin", "Faye", "Garrick",
    "Ilsa", "Jax", "Kira", "Leon", "Maeve", "Nils", "Odessa", "Pax", "Quinn", "Rhea",
    "Silas", "Tamsin", "Ulric", "Vera", "Wyatt", "Xan", "Yara", "Zeke", "Ada", "Bastian",
    "Cleo", "Dax", "Elara", "Finn", "Greta", "Hugo", "Ivy", "Juno", "Kai", "Lark",
    "Milo", "Nova", "Otto", "Piper", "Rafe", "Sage", "Theo", "Uma", "Vale", "Willa",
    "Yuri", "Zuri", "Arlo", "Briar", "Cass", "Dell", "Ember", "Felix", "Gwen", "Hale",
    "Indi", "Jory", "Knox", "Lumi", "Mace", "Nell", "Oren", "Posy", "Remy", "Skye",
    "Tova", "Umber", "Vida", "Wilder", "Xyla", "Yves", "Zane", "Asher", "Bex", "Cyra",
    "Dune", "Esme", "Flint", "Gale", "Hollis", "Isla", "Jett", "Koa", "Linden", "Merrit",
}
local FAM_A = { "Storm", "Ash", "Bright", "Dusk", "Ember", "Frost", "Moon", "Iron", "Raven", "Thorn" }
local FAM_B = { "caller", "veil", "forge", "walker", "heart", "wind", "shade", "mere", "crest", "blade" }

-- ================= BURST NAMES: 20 x 25 x 20 =================
local B_EL = { "Cinder", "Frost", "Storm", "Shadow", "Radiant", "Venom", "Stone", "Tidal", "Gale", "Thunder",
               "Ember", "Lunar", "Solar", "Void", "Crystal", "Iron", "Spirit", "Verdant", "Arcane", "Astral" }
local B_NOUN = { "Lance", "Nova", "Strike", "Cascade", "Barrage", "Requiem", "Tempest", "Bloom", "Crash", "Rend",
                 "Volley", "Surge", "Spiral", "Pulse", "Fang", "Comet", "Halo", "Wave", "Burst", "Edge",
                 "Roar", "Veil", "Rain", "Crown", "Gate" }
local B_SUF = { "of Dawn", "of Dusk", "of Ruin", "of Hope", "of the Deep", "of Kings", "of Ages", "of Echoes",
                "of Thorns", "of Embers", "of Silence", "of Glory", "of the Wild", "of Stars", "of Fury",
                "of Mercy", "of Storms", "of the Void", "of Legends", "Unbound" }

-- ================= BURSTS: 16 kinds x 12 extras x 3 sizes x 18 power levels =================
-- Every character gets its own combination, so no two bursts are the same.
CH_CORES = {
    { id = "smite",   n = "Smite",    cost = 50 },
    { id = "nova",    n = "Nova",     cost = 70 },
    { id = "cross",   n = "Cross",    cost = 60 },
    { id = "chain",   n = "Chain",    cost = 65 },
    { id = "tempest", n = "Tempest",  cost = 95 },
    { id = "restore", n = "Restore",  cost = 55 },
    { id = "aegis",   n = "Aegis",    cost = 50 },
    { id = "glacier", n = "Glacier",  cost = 80 },
    { id = "reaper",  n = "Reaper",   cost = 85 },
    { id = "siphon",  n = "Siphon",   cost = 60 },
    { id = "warcry",  n = "War Cry",  cost = 45 },
    { id = "spirit",  n = "Spirit",   cost = 75 },
    { id = "miasma",  n = "Miasma",   cost = 70 },
    { id = "quake",   n = "Quake",    cost = 80 },
    { id = "blink",   n = "Blink",    cost = 40 },
    { id = "meteor",  n = "Meteor",   cost = 90 },
}
CH_RIDERS = { "none", "heal", "refund", "stun", "burn", "gold", "knock", "shred", "shield", "reveal", "cleanse", "weaken" }

-- ================= TALENTS: what each character does while active =================
CH_TALENTS = {
    { id = "echo",       n = "Echo",          base = 6 },
    { id = "cleave",     n = "Cleave",        base = 15 },
    { id = "execute",    n = "Executioner",   base = 20 },
    { id = "momentum",   n = "Momentum",      base = 4 },
    { id = "hunter",     n = "First Strike",  base = 20 },
    { id = "frost",      n = "Frostbite",     base = 5 },
    { id = "ignite",     n = "Ignite",        base = 7 },
    { id = "venom",      n = "Venom",         base = 7 },
    { id = "stagger",    n = "Stagger",       base = 6 },
    { id = "lifesteal",  n = "Lifesteal",     base = 3 },
    { id = "siphon",     n = "Energy Siphon", base = 12 },
    { id = "battery",    n = "Charged Up",    base = 10 },
    { id = "guardian",   n = "Guardian",      base = 4 },
    { id = "retaliate",  n = "Retaliate",     base = 8 },
    { id = "thorn",      n = "Spiked Skin",   base = 10 },
    { id = "mender",     n = "Mender",        base = 1 },
    { id = "secondwind", n = "Second Wind",   base = 15 },
    { id = "warding",    n = "Warding",       base = 15 },
    { id = "goldtouch",  n = "Gold Touch",    base = 10 },
    { id = "scavenger",  n = "Scavenger",     base = 4 },
    { id = "fleet",      n = "Fleet Foot",    base = 5 },
    { id = "pathfinder", n = "Pathfinder",    base = 1 },
    { id = "treasure",   n = "Treasure Nose", base = 10 },
    { id = "focus",      n = "Focus",         base = 10 },
}
local TAL_CAP = { echo = 40, frost = 35, ignite = 50, venom = 50, stagger = 40, guardian = 30, retaliate = 60,
                  scavenger = 30, fleet = 35, warding = 90, lifesteal = 15, mender = 5 }

-- ================= BUILDING A CHARACTER =================
local CACHE = {}
local function rarityOfRank(rk)
    local acc = 0
    for r = 6, 1, -1 do
        acc = acc + R_COUNT[r]
        if rk < acc then return r end
    end
    return 1
end
function charInfo(i)
    local c = CACHE[i]
    if c then return c end
    local rk = (i * 7919 + 1234) % CH_N
    local r = rarityOfRank(rk)
    local j = (i * 3571 + 17) % CH_N           -- which burst combination
    local core, rider, v, k = j % 16 + 1, floor(j / 16) % 12 + 1, floor(j / 192) % 3, floor(j / 576)
    local t = (i * 13 + floor(i / 100) * 7) % #CH_TALENTS + 1
    local T = CH_TALENTS[t]
    local tv = T.base * R_TAL[r] * (1 + 0.1 * ((i * 31) % 3))
    tv = (T.id == "mender") and floor(tv * 10 + 0.5) / 10 or round(tv)
    if T.id == "pathfinder" then tv = r >= 4 and 2 or 1 end
    if TAL_CAP[T.id] then tv = min(TAL_CAP[T.id], tv) end
    local bn = (i * 37 + 11) % CH_N              -- burst name
    c = {
        i = i, r = r,
        name = FIRST[i % 100 + 1] .. " " .. FAM_A[floor(i / 100) % 10 + 1] .. FAM_B[floor(i / 1000) + 1],
        atk = R_ATK[r] + (i * 17) % R_ATK_S[r],
        hp = R_HP[r] + (i * 23) % R_HP_S[r],
        tal = T.id, talName = T.n, tv = tv,
        core = CH_CORES[core].id, coreName = CH_CORES[core].n, rider = CH_RIDERS[rider], v = v, k = k,
        pow = 180 + 10 * (k + 18 * (r - 1)),   -- 180% (weakest Common) to 1,250% (strongest Mythic)
        cost = CH_CORES[core].cost + 6 * v + (k % 5) * 3 + ((i * 7) % 4) * 2,
        burst = B_EL[floor(bn / 500) + 1] .. " " .. B_NOUN[floor(bn / 20) % 25 + 1] .. " " .. B_SUF[bn % 20 + 1],
    }
    CACHE[i] = c
    return c
end
function charRarityText(r) return CH_STARS[r] .. " " .. CH_RAR[r] end

-- What a character's talent does, in words.
function talentText(c)
    local v = c.tv
    local t = c.tal
    if t == "echo" then return v .. "% chance your attacks hit a second time (60% damage)" end
    if t == "cleave" then return "Your attacks also hit another monster next to you for " .. v .. "% damage" end
    if t == "execute" then return "+" .. v .. "% damage to monsters below 30% HP" end
    if t == "momentum" then return "Each hit in a row on the same monster deals +" .. v .. "% more (up to 5 hits)" end
    if t == "hunter" then return "+" .. v .. "% damage to monsters that are at full HP" end
    if t == "frost" then return v .. "% chance your hits freeze the monster for a turn" end
    if t == "ignite" then return v .. "% chance your hits set the monster burning" end
    if t == "venom" then return v .. "% chance your hits poison the monster" end
    if t == "stagger" then return v .. "% chance your hits knock the monster back" end
    if t == "lifesteal" then return "Heals you " .. v .. "% of the damage you deal" end
    if t == "siphon" then return "+" .. v .. "% energy from everything" end
    if t == "battery" then return "Your party starts every floor with " .. v .. "% energy" end
    if t == "guardian" then return v .. "% chance to block a hit completely" end
    if t == "retaliate" then return v .. "% chance to hit back when a monster next to you attacks" end
    if t == "thorn" then return "Monsters that hit you take " .. v .. "% of the damage back" end
    if t == "mender" then return "Heals " .. num(v) .. "% of your max HP every 4 turns" end
    if t == "secondwind" then return "Once per floor, heals " .. v .. "% of your max HP when you drop below 30%" end
    if t == "warding" then return v .. "% chance to shrug off poison, weakness and being slowed" end
    if t == "goldtouch" then return "+" .. v .. "% gold from monsters you defeat" end
    if t == "scavenger" then return v .. "% chance a monster you defeat drops a potion or scroll" end
    if t == "fleet" then return v .. "% chance a step doesn't use your turn" end
    if t == "pathfinder" then return "You see " .. v .. " square" .. (v > 1 and "s" or "") .. " farther" end
    if t == "treasure" then return "Shows every item on a new floor, and +" .. v .. "% gold from gold piles and chests" end
    if t == "focus" then return "Your bursts are " .. v .. "% stronger" end
    return ""
end

local function riderText(c)
    local x = c.rider
    if x == "none" then return "" end
    if x == "heal" then return " Also heals you " .. (10 + 2 * c.r) .. "% of your max HP." end
    if x == "refund" then return " Gives back " .. (15 + 5 * c.r) .. "% of its energy." end
    if x == "stun" then return " Stuns what it hits for 1 turn." end
    if x == "burn" then return " Sets what it hits burning." end
    if x == "gold" then return " Each monster it hits drops " .. (2 + c.r) .. " gold per floor level." end
    if x == "knock" then return " Knocks what it hits away from you." end
    if x == "shred" then return " Halves the armor of what it hits." end
    if x == "shield" then return " Gives you a shield that blocks 1 hit." end
    if x == "reveal" then return " Shows the whole floor." end
    if x == "cleanse" then return " Cures poison, weakness and slowness." end
    if x == "weaken" then return " Lowers the attack of what it hits by 25%." end
    return ""
end
-- Burst numbers: P is the power in % of your attack.
local function burstParts(c)
    local P, v = c.pow, c.v
    if c.rider == "none" then P = round(P * 1.2) end
    return P, v
end
function burstText(c)
    local P, v = burstParts(c)
    local t = c.core
    local s
    if t == "smite" then s = "Hits the nearest monster " .. (v > 0 and (v + 1) .. " times " or "") .. "for " .. round(P / (1 + 0.4 * v)) .. "% of your attack" .. (v > 0 and " each" or "")
    elseif t == "nova" then s = "Hits every monster within " .. (1 + v) .. " square" .. (v > 0 and "s" or "") .. " for " .. round(P * 0.7) .. "%"
    elseif t == "cross" then s = "Hits every monster in your row and column (up to " .. (3 + 2 * v) .. " squares) for " .. round(P * 0.9) .. "%"
    elseif t == "chain" then s = "Hits the " .. (2 + 2 * v) .. " nearest monsters you can see for " .. round(P * 0.6) .. "% each"
    elseif t == "tempest" then s = "Hits every monster you can see for " .. round(P * 0.5) .. "% and slows them for " .. (1 + v) .. " turn" .. (v > 0 and "s" or "")
    elseif t == "restore" then s = "Heals " .. (25 + 10 * v + 3 * c.r) .. "% of your max HP and hits the nearest monster for " .. round(P * 0.3) .. "%"
    elseif t == "aegis" then s = "Gives you a shield that blocks the next " .. (1 + v + floor(c.r / 3)) .. " hit" .. ((v + floor(c.r / 3)) > 0 and "s" or "") ..
        " and bashes monsters next to you for " .. round(P * 0.3) .. "%"
    elseif t == "glacier" then s = "Freezes every monster you can see for " .. (1 + v) .. " turn" .. (v > 0 and "s" or "") .. " and hits them for " .. round(P * 0.2) .. "%"
    elseif t == "reaper" then s = "Defeats every monster you can see below " .. (10 + 5 * v + c.r) .. "% HP (bosses take " .. P .. "% instead)"
    elseif t == "siphon" then s = "Hits the nearest monster for " .. P .. "% and heals you " .. (30 + 10 * v) .. "% of the damage"
    elseif t == "warcry" then s = "Your next " .. (3 + 2 * v) .. " attacks deal +" .. round(P / 3) .. "% damage"
    elseif t == "spirit" then s = "Calls a spirit that hits the nearest monster for " .. round(P * 0.35) .. "% every turn for " .. (3 + 2 * v) .. " turns"
    elseif t == "miasma" then s = "Poisons every monster within " .. (2 + v) .. " squares for " .. round(P * 0.25) .. "% a turn, " .. (3 + v) .. " turns"
    elseif t == "quake" then s = "Hits every monster within " .. (2 + v) .. " squares for " .. round(P * 0.5) .. "% and stuns them for 1 turn"
    elseif t == "blink" then s = "Blasts monsters next to you for " .. round(P * 0.4) .. "%, then " .. (v == 2 and "teleports you next to the stairs" or "teleports you to a safe spot far away") ..
        " and heals " .. (10 + 5 * v + c.r) .. "% of your max HP"
    else s = "Drops a meteor on the toughest monster you can see for " .. round(P * 1.5) .. "%" .. (v > 0 and ", and " .. round(P * 0.75) .. "% to monsters within " .. v .. " square" .. (v > 1 and "s" or "") .. " of it" or "") end
    return s .. "." .. riderText(c)
end
function charLine(c)
    return charRarityText(c.r) .. ". Attack +" .. c.atk .. "% while active. Party max HP +" .. c.hp .. "%."
end

-- ================= SUMMONING =================
local BY_R = nil
local function byRarity()
    if BY_R then return BY_R end
    BY_R = { {}, {}, {}, {}, {}, {} }
    for i = 0, CH_N - 1 do push(BY_R[charInfo(i).r], i) end
    return BY_R
end
function charsOwned() return countKeys(S.chars) end
function summonCost(n)
    local owned, total = charsOwned(), 0
    for k = 0, (n or 1) - 1 do
        if owned + k >= CH_N then break end
        total = total + niceNum(150 * 1.0012 ^ (owned + k))
    end
    return total
end
local function unownedOf(r)
    local out = {}
    for _, i in ipairs(byRarity()[r]) do if not S.chars[i] then out[#out + 1] = i end end
    return out
end
function summonOne()
    if charsOwned() >= CH_N then return nil end
    local roll, acc, r = random() * 100, 0, 1
    for k = 6, 1, -1 do   -- rarest first
        acc = acc + CH_ODDS[k]
        if roll < acc then r = k; break end
    end
    -- none left of that rarity: the nearest more common one, then rarer ones
    local order = { r }
    for k = r - 1, 1, -1 do push(order, k) end
    for k = r + 1, 6 do push(order, k) end
    for _, k in ipairs(order) do
        local list = unownedOf(k)
        if #list > 0 then
            local i = list[rnd(1, #list)]
            S.chars[i] = 1
            if #S.party < PARTY_MAX then push(S.party, i); if S.lead == nil or S.lead < 0 then S.lead = i end end
            stat("chars")
            return i
        end
    end
    return nil
end
function summon(n)
    local cost = summonCost(n)
    if cost <= 0 or S.gold < cost then return end
    S.gold = S.gold - cost
    stat("a_Big Spender", cost)
    local got = {}
    for _ = 1, n do
        local i = summonOne()
        if i then push(got, i) end
    end
    ui.lastSummon = got
    campClaim(); save(); render()
end
function partyAdd(i)
    if S.chars[i] and #S.party < PARTY_MAX and not contains(S.party, i) then
        push(S.party, i)
        if S.lead == nil or S.lead < 0 then S.lead = i end
        save(); render()
    end
end
function partyRemove(i)
    local k = find1(S.party, i)
    if k then
        table.remove(S.party, k)
        if S.lead == i then S.lead = S.party[1] or -1 end
        save(); render()
    end
end
-- How strong a character is overall: rarity first, then burst power, attack and HP.
function charScore(i)
    local c = charInfo(i)
    return c.r * 10000 + c.pow * 4 + c.atk * 10 + c.hp * 5
end
-- Fills the party with your strongest characters; the strongest leads.
function bestParty()
    ui.artNote = nil
    local list = {}
    for i in pairs(S.chars) do push(list, i) end
    table.sort(list, function(a, b)
        local sa, sb = charScore(a), charScore(b)
        if sa ~= sb then return sa > sb end
        return a < b
    end)
    local old = {}
    for _, i in ipairs(S.party) do old[i] = true end
    S.party = {}
    for k = 1, min(PARTY_MAX, #list) do S.party[k] = list[k] end
    S.lead = S.party[1] or -1
    local changed = 0
    for _, i in ipairs(S.party) do if not old[i] then changed = changed + 1 end end
    ui.partyNote = #S.party == 0 and "You don't have any characters yet." or
        (changed == 0 and "Your party is already your best one. " .. charInfo(S.lead).name .. " leads." or
         "Best party set: " .. changed .. " new member" .. (changed > 1 and "s" or "") .. ". " .. charInfo(S.lead).name .. " leads.")
    save(); render()
end
function partyLead(i) if contains(S.party, i) then S.lead = i; save(); render() end end
function openChars() ui.chars = true; ui.artChar = nil; ui.artSlot = nil; ui.lastSummon = nil; ui.partyNote = nil; ui.chPage = 0; ui.bookTop = true; render() end

-- ================= IN THE DUNGEON =================
function activeChar()
    local r = S.run
    if not r or not r.cact or r.cact < 0 then return nil end
    return charInfo(r.cact)
end
-- The active character's talent value (0 if it has a different talent).
function tal(id)
    local c = activeChar()
    if c and c.tal == id then return c.tv end
    return 0
end
function charAtkMul() local c = activeChar(); return c and (1 + (c.atk + artStatOf(c.i, "atk")) / 100) or 1 end
function charHpMul()
    local p = 0
    for _, i in ipairs(S.party or {}) do p = p + charInfo(i).hp + artStatOf(i, "hp") end
    return 1 + p / 100
end
function charSight() return tal("pathfinder") end
function energyOf(i) return (S.run.energy or {})[i] or 0 end
function gainEnergy(n)
    local r = S.run
    if not r or not r.energy or #S.party == 0 or r.inBurst then return end   -- a burst never refills itself
    n = n * (1 + tal("siphon") / 100)
    for _, i in ipairs(S.party) do
        local c = charInfo(i)
        local add = ((i == r.cact) and n or n / 2) * (1 + artStatOf(i, "er") / 100)
        r.energy[i] = min(c.cost, (r.energy[i] or 0) + add)
    end
end
function burstReady()
    local c = activeChar()
    return c ~= nil and energyOf(c.i) >= c.cost
end
-- Switching costs no turn.
function switchChar(i)
    local r = S.run
    if not r or r.panel or not contains(S.party, i) or r.cact == i then ui.swap = false; render(); return end
    r.cact = i
    r.mom = nil
    ui.swap = false
    stat("charswitch")
    r.log = { charInfo(i).name .. " takes the lead! " .. charInfo(i).talName .. ": " .. talentText(charInfo(i)) .. "." }
    save(); render()
end
function openSwap()
    if not S.run or S.run.panel or #S.party < 2 then return end
    ui.bag = false; ui.elev = false; ui.swap = true; render()
end

-- start of a run, and every new floor
function charRunStart()
    local r = S.run
    r.energy = {}
    r.cact = -1
    if #S.party > 0 then r.cact = contains(S.party, S.lead) and S.lead or S.party[1] end
end
function charFloorStart()
    local r = S.run
    if not r.energy then charRunStart() end
    r.cSW = false
    r.mom = nil
    local b = tal("battery")
    if b > 0 then
        for _, i in ipairs(S.party) do
            local c = charInfo(i)
            r.energy[i] = max(r.energy[i] or 0, floor(c.cost * b / 100))
        end
    end
    if tal("treasure") > 0 then
        for _, it in ipairs(r.items) do r.seen[it.y][it.x] = 1 end
    end
end

-- in fights
function charDmgBonus(m, primary)
    local r, b = S.run, 0
    local c = activeChar()
    if not c then return 0 end
    if c.tal == "execute" and m.hp < m.max * 0.3 then b = b + c.tv end
    if c.tal == "hunter" and m.hp >= m.max then b = b + c.tv end
    if c.tal == "momentum" and primary then
        if r.mom and r.mom.m == m then r.mom.n = min(5, r.mom.n + 1) else r.mom = { m = m, n = 0 } end
        b = b + c.tv * r.mom.n
    end
    if primary and r.cRally and r.cRally.n > 0 then
        b = b + r.cRally.pct
        r.cRally.n = r.cRally.n - 1
        if r.cRally.n <= 0 then r.cRally = nil end
    end
    return b
end
function charOnHit(m, d, primary)
    if not primary then return end
    gainEnergy(5)
    local ls = tal("lifesteal")
    if ls > 0 then heal(max(1, round(d * ls / 100))) end
end
function charOnHitAlive(m, primary)
    local r = S.run
    local c = activeChar()
    if not c or not primary or not find1(r.mons, m) then return end
    local t, v = c.tal, c.tv
    if t == "frost" and chance(v) and not TYPES[m.i].heart then m.frozen = max(m.frozen, 1); say(The(m.name) .. " is frozen solid!") end
    if t == "ignite" and chance(v) then setDot(m, 0.5, 3, "burning") end
    if t == "venom" and chance(v) then setDot(m, 0.4, 4, "poisoned") end
    if t == "stagger" and chance(v) then
        local kx, ky = m.x + sign(m.x - r.px), m.y + sign(m.y - r.py)
        if canStep(kx, ky, m) then m.x = kx; m.y = ky; say("You knock " .. the(m.name) .. " back!") end
    end
    if t == "echo" and chance(v) then strike(m, 0.6, false, "echo and hit") end
    if t == "cleave" then
        for _, o in ipairs(copy(r.mons)) do
            if o ~= m and cheb(o.x, o.y, r.px, r.py) <= 1 and not hiddenMon(o) then
                strike(o, v / 100, false, "cleave")
                break
            end
        end
    end
end
function charOnKill(m, g)
    local r = S.run
    gainEnergy(10)
    local c = activeChar()
    if not c then return end
    if c.tal == "goldtouch" and g > 0 then
        local extra = max(1, round(g * c.tv / 100))
        r.goldRun = r.goldRun + extra
    end
    if c.tal == "scavenger" and chance(c.tv) then
        local it = supplyItem()
        if dropAt(m.x, m.y, it) then say("You find " .. supplyName(it) .. " on it.") end
    end
end
-- Returns true if a talent blocks this hit.
function charBlock(m)
    local v = tal("guardian")
    if v > 0 and chance(v) then say(activeChar().name .. " blocks " .. the(m.name) .. "'s attack!"); return true end
    return false
end
function charOnHurt(m, d, kind)
    local r = S.run
    gainEnergy(3)
    local c = activeChar()
    if not c or not find1(r.mons, m) then return end
    if c.tal == "thorn" then
        local td = max(1, round(d * c.tv / 100))
        m.hp = m.hp - td
        say("Spikes hit " .. the(m.name) .. " for " .. td .. ".")
        if m.hp <= 0 then killHow = "thorns"; killMon(m); return end
    end
    if c.tal == "retaliate" and kind == "" and cheb(m.x, m.y, r.px, r.py) <= 1 and chance(c.tv) then
        say(c.name .. " hits back!")
        strike(m, 0.5, false, "hit back at")
    end
end
function charWard() local v = tal("warding"); return v > 0 and chance(v) end
function charTurn()
    local r = S.run
    local c = activeChar()
    if c then
        if c.tal == "mender" and r.turns % 4 == 0 then heal(max(1, round(r.maxHp * c.tv / 100))) end
        if c.tal == "secondwind" and not r.cSW and r.hp > 0 and r.hp < r.maxHp * 0.3 then
            r.cSW = true
            local h = heal(round(r.maxHp * c.tv / 100))
            say(c.name .. " catches a second wind: +" .. h .. " HP!")
        end
    end
    local sp = r.cSpirit
    if sp and sp.t > 0 then
        sp.t = sp.t - 1
        local ms = seenMonsters()
        if #ms > 0 then
            ssort(ms, function(a, b) return (abs(a.x - r.px) + abs(a.y - r.py)) - (abs(b.x - r.px) + abs(b.y - r.py)) end)
            burstHit(ms[1], sp.pct, "Your spirit")
        end
        if sp.t <= 0 then r.cSpirit = nil end
    end
end
-- Returns true when a step should not use the turn.
function charFleet() local v = tal("fleet"); return v > 0 and chance(v) end
function charGoldBonus() return tal("treasure") end

-- ================= BURSTS =================
function burstHit(m, pct, who)
    local r = S.run
    if not m or not find1(r.mons, m) then return 0 end
    local d = max(1, round(atkOf() * pct / 100 * (1 + (tal("focus") + artStat("burst")) / 100) - m.def / 2))
    if has(m, "swarm") then d = max(1, ceil(d / 2)) end
    m.hp = m.hp - d; m.awake = true; m.revealed = true
    stat("c_Damage Dealer", d)
    say((who or "Your burst") .. " hits " .. the(m.name) .. " for " .. d .. ".")
    if m.hp <= 0 then killHow = "burst"; killMon(m) end
    return d
end
local function nearestFirst(list)
    local r = S.run
    ssort(list, function(a, b) return (abs(a.x - r.px) + abs(a.y - r.py)) - (abs(b.x - r.px) + abs(b.y - r.py)) end)
    return list
end
local function within(rad)
    local r, out = S.run, {}
    for _, m in ipairs(seenMonsters()) do if cheb(m.x, m.y, r.px, r.py) <= rad then push(out, m) end end
    return nearestFirst(out)
end
local function inLine(reach)
    local r, out = S.run, {}
    for _, m in ipairs(seenMonsters()) do
        local dx, dy = m.x - r.px, m.y - r.py
        if (dx == 0 or dy == 0) and abs(dx) + abs(dy) <= reach then push(out, m) end
    end
    return nearestFirst(out)
end
local function safeFar(r)
    local spots = {}
    for y = 0, H - 1 do
        for x = 0, W - 1 do
            if r.map[y][x] == 0 and not monAt(x, y) and itemAt(x, y) < 0 and abs(x - r.px) + abs(y - r.py) > 5 then push(spots, { x, y }) end
        end
    end
    return spots
end
function useBurst()
    local r = S.run
    if blocked() or not burstReady() then return end
    local c = activeChar()
    newTurn()
    r.energy[c.i] = 0
    stat("bursts")
    say(c.name .. " uses " .. c.burst .. "!")
    r.inBurst = true
    local P, v = burstParts(c)
    local hit = {}            -- monsters the burst hit (for its extra effect)
    local t = c.core
    local function hitAll(list, pct) for _, m in ipairs(list) do push(hit, m); burstHit(m, pct) end end
    if t == "smite" then
        local ms = nearestFirst(seenMonsters())
        if ms[1] then for _ = 0, v do push(hit, ms[1]); burstHit(ms[1], P / (1 + 0.4 * v)) end end
    elseif t == "nova" then hitAll(within(1 + v), P * 0.7)
    elseif t == "cross" then hitAll(inLine(3 + 2 * v), P * 0.9)
    elseif t == "chain" then
        local ms = nearestFirst(seenMonsters())
        local list = {}
        for k = 1, min(#ms, 2 + 2 * v) do list[k] = ms[k] end
        hitAll(list, P * 0.6)
    elseif t == "tempest" then
        local ms = seenMonsters()
        hitAll(ms, P * 0.5)
        for _, m in ipairs(ms) do if find1(r.mons, m) then m.slowT = max(m.slowT, 1 + v) end end
    elseif t == "restore" then
        local h = heal(round(r.maxHp * (25 + 10 * v + 3 * c.r) / 100 * (1 + tal("focus") / 100)))
        say("You heal " .. h .. " HP.")
        local ms = nearestFirst(seenMonsters())
        if ms[1] then push(hit, ms[1]); burstHit(ms[1], P * 0.3) end
    elseif t == "aegis" then
        local n = 1 + v + floor(c.r / 3)
        r.clsShield = (r.clsShield or 0) + n
        say("A shield surrounds you. It blocks the next " .. n .. " hit" .. (n > 1 and "s" or "") .. ".")
        hitAll(within(1), P * 0.3)
    elseif t == "glacier" then
        for _, m in ipairs(seenMonsters()) do
            push(hit, m)
            if not TYPES[m.i].heart then m.frozen = max(m.frozen, 1 + v) end
            burstHit(m, P * 0.2)
        end
    elseif t == "reaper" then
        local cut = (10 + 5 * v + c.r) / 100
        for _, m in ipairs(seenMonsters()) do
            push(hit, m)
            if m.kind ~= "boss" and m.hp < m.max * cut then
                m.hp = 0; say(The(m.name) .. " is cut down!"); killHow = "burst"; killMon(m)
            elseif m.kind == "boss" then burstHit(m, P) end
        end
    elseif t == "siphon" then
        local ms = nearestFirst(seenMonsters())
        if ms[1] then push(hit, ms[1]); local d = burstHit(ms[1], P); heal(round(d * (30 + 10 * v) / 100)) end
    elseif t == "warcry" then
        r.cRally = { n = 3 + 2 * v, pct = round(P / 3 * (1 + tal("focus") / 100)) }
        say("Your next " .. r.cRally.n .. " attacks deal +" .. r.cRally.pct .. "% damage!")
    elseif t == "spirit" then
        r.cSpirit = { t = 3 + 2 * v, pct = P * 0.35 }
        say("A spirit appears beside you!")
    elseif t == "miasma" then
        for _, m in ipairs(within(2 + v)) do
            push(hit, m); m.awake = true
            m.dot = { d = max(1, round(atkOf() * P * 0.25 / 100 * (1 + tal("focus") / 100))), t = 3 + v, w = "poisoned" }
        end
        say("A poison cloud spreads out" .. (#hit > 0 and " over " .. #hit .. " monster" .. (#hit > 1 and "s" or "") or "") .. ".")
    elseif t == "quake" then
        for _, m in ipairs(within(2 + v)) do
            push(hit, m)
            burstHit(m, P * 0.5)
            if find1(r.mons, m) and not TYPES[m.i].heart then m.frozen = max(m.frozen, 1) end
        end
    elseif t == "blink" then
        hitAll(within(1), P * 0.4)
        local spot
        if v == 2 then
            for _, d in ipairs({ { 0, 0 }, { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
                local x, y = r.sx + d[1], r.sy + d[2]
                if x >= 0 and y >= 0 and x < W and y < H and r.map[y][x] ~= 1 and not monAt(x, y) then spot = { x, y }; break end
            end
        end
        if not spot then local s = safeFar(r); if #s > 0 then spot = pick(s) end end
        if spot then r.px = spot[1]; r.py = spot[2]; reveal(); say("You vanish and reappear!") end
        heal(round(r.maxHp * (10 + 5 * v + c.r) / 100))
    else   -- meteor
        local ms = seenMonsters()
        local big = nil
        for _, m in ipairs(ms) do if not big or m.hp > big.hp then big = m end end
        if big then
            local bx, by = big.x, big.y
            push(hit, big); burstHit(big, P * 1.5)
            if v > 0 then
                for _, m in ipairs(ms) do
                    if m ~= big and cheb(m.x, m.y, bx, by) <= v then push(hit, m); burstHit(m, P * 0.75) end
                end
            end
        end
    end
    if t ~= "smite" and t ~= "siphon" and #hit == 0 and (t == "nova" or t == "cross" or t == "chain" or t == "tempest" or t == "meteor" or t == "quake") then
        say("Nothing was close enough.")
    end
    -- the extra effect
    r.inBurst = false
    local x = c.rider
    if x == "heal" then heal(round(r.maxHp * (10 + 2 * c.r) / 100))
    elseif x == "refund" then r.energy[c.i] = floor(c.cost * (15 + 5 * c.r) / 100)
    elseif x == "shield" then r.clsShield = (r.clsShield or 0) + 1
    elseif x == "reveal" then revealAll()
    elseif x == "cleanse" then r.poison = 0; r.weak = 0; r.slow = 0
    else
        local targets = #hit > 0 and hit or within(2)
        local seen = {}
        for _, m in ipairs(targets) do
            if not seen[m] and find1(r.mons, m) then
                seen[m] = true
                if x == "stun" and not TYPES[m.i].heart then m.frozen = max(m.frozen, 1)
                elseif x == "burn" then setDot(m, 0.5, 3, "burning")
                elseif x == "gold" then r.goldRun = r.goldRun + goldAmt((2 + c.r) * r.floor)
                elseif x == "knock" then
                    local kx, ky = m.x + sign(m.x - r.px), m.y + sign(m.y - r.py)
                    if canStep(kx, ky, m) then m.x = kx; m.y = ky end
                elseif x == "shred" then m.def = floor(m.def / 2)
                elseif x == "weaken" then m.atk = max(1, round(m.atk * 0.75)) end
            end
        end
    end
    endTurn()
end
