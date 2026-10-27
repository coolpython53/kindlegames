--[[
Endless Dungeon: artifacts.

50,000 artifacts, found in treasure chests and kept forever.
Every artifact is one of 5 pieces: Flower, Plume, Sands, Goblet or Circlet, and one of
7 rarities: Common, Uncommon, Rare, Epic, Legend, Mythic, Godly.
Each character wears one of each piece (so up to 5 each, 20 for a party of 4).
You equip them at camp, on the Characters screen.

What the stats do:
  ATK, DEF, Crit, Dodge, Gold   while that character is active
  HP                            max HP for the whole party, all run long
  Energy                        that character fills its burst faster (even on the bench)
  Burst                         that character's burst hits harder
--]]
local M = require("dungeon_engine")
setfenv(1, M)

AR_N = 50000
AR_SLOTS = { "flower", "plume", "sands", "goblet", "circlet" }
AR_SLOT_NAME = { flower = "Flower", plume = "Plume", sands = "Sands", goblet = "Goblet", circlet = "Circlet" }
AR_RAR = { "Common", "Uncommon", "Rare", "Epic", "Legend", "Mythic", "Godly" }
AR_ODDS = { 45, 28, 16, 7.5, 2.8, 0.65, 0.05 }                      -- chance from a chest, in %
local AR_COUNT = { 20000, 13000, 9000, 5000, 2200, 700, 100 }       -- how many of each rarity

-- Stats: name, how it's written, and the main-stat value for each rarity.
AR_STATS = {
    atk   = { n = "ATK",    pct = true, v = { 3, 5, 8, 12, 17, 24, 35 } },
    hp    = { n = "HP",     pct = true, v = { 3, 5, 8, 12, 17, 24, 35 } },
    def   = { n = "DEF",    pct = false, v = { 1, 2, 3, 5, 7, 10, 15 } },
    crit  = { n = "Crit",   pct = true, v = { 2, 3, 5, 7, 10, 14, 20 } },
    dodge = { n = "Dodge",  pct = true, v = { 1, 2, 3, 4, 6, 8, 12 } },
    er    = { n = "Energy", pct = true, v = { 5, 8, 12, 18, 26, 36, 50 } },
    burst = { n = "Burst",  pct = true, v = { 5, 8, 12, 18, 26, 36, 50 } },
    gold  = { n = "Gold",   pct = true, v = { 5, 8, 12, 18, 26, 36, 50 } },
}
local STAT_ORDER = { "atk", "hp", "def", "crit", "dodge", "er", "burst", "gold" }
-- Which main stats each piece can have.
local MAINS = {
    flower = { "hp" },
    plume = { "atk" },
    sands = { "atk", "hp", "er", "def" },
    goblet = { "atk", "hp", "burst", "gold" },
    circlet = { "crit", "atk", "hp", "dodge" },
}
local SUBS = { 0, 1, 1, 2, 2, 3, 4 }   -- extra stats by rarity
-- For "best" picks: how much each stat point is worth.
local WEIGHT = { atk = 3, hp = 2, def = 3, crit = 4, dodge = 4, er = 1.5, burst = 1.5, gold = 1 }

-- Names: 100 x 100 x 5 pieces = 50,000, all different.
local ADJ = {
    "Gilded", "Ashen", "Verdant", "Silent", "Crimson", "Frozen", "Radiant", "Hollow", "Ancient", "Wandering",
    "Shattered", "Gleaming", "Twilight", "Sunlit", "Moonlit", "Stormbound", "Thorned", "Velvet", "Iron", "Golden",
    "Silver", "Obsidian", "Ivory", "Emerald", "Sapphire", "Amber", "Opal", "Jade", "Coral", "Pearl",
    "Ember", "Tidal", "Whispering", "Dreaming", "Burning", "Glacial", "Starlit", "Dawnlit", "Duskborn", "Mistveiled",
    "Royal", "Noble", "Exiled", "Forgotten", "Hallowed", "Cursed", "Blessed", "Wild", "Gentle", "Fierce",
    "Swift", "Patient", "Brave", "Lucky", "Wise", "Proud", "Humble", "Lonely", "Merry", "Solemn",
    "Arcane", "Mystic", "Runic", "Celestial", "Abyssal", "Verdigris", "Rusted", "Polished", "Woven", "Carved",
    "Painted", "Fabled", "Lost", "Hidden", "Sacred", "Frostbitten", "Sunken", "Floating", "Echoing", "Roaring",
    "Crystal", "Shadow", "Thunder", "Blossom", "Autumn", "Winter", "Spring", "Summer", "Midnight", "Morning",
    "Scarlet", "Azure", "Violet", "Copper", "Bronze", "Marble", "Granite", "Feathered", "Scaled", "Eternal",
}
local NOUN = {
    "Phoenix", "Wanderer", "Gladiator", "Maiden", "Scholar", "Knight", "Witch", "Archer", "Sailor", "Monk",
    "Dragon", "Tiger", "Wolf", "Fox", "Owl", "Raven", "Serpent", "Stag", "Bear", "Hawk",
    "Lantern", "Mirror", "Compass", "Anchor", "Crown", "Throne", "Harp", "Bell", "Candle", "Key",
    "Forest", "Ocean", "Mountain", "River", "Desert", "Glacier", "Volcano", "Meadow", "Canyon", "Island",
    "Dawn", "Dusk", "Storm", "Rain", "Snow", "Wind", "Thunder", "Star", "Moon", "Sun",
    "Garden", "Library", "Tower", "Temple", "Castle", "Village", "Harbor", "Market", "Tavern", "Ruins",
    "Poet", "Dancer", "Hunter", "Healer", "Smith", "Merchant", "Pilgrim", "Herald", "Jester", "Sage",
    "Comet", "Eclipse", "Aurora", "Nebula", "Tide", "Ember", "Frost", "Bloom", "Thorn", "Root",
    "Oath", "Song", "Dream", "Echo", "Promise", "Secret", "Legend", "Riddle", "Wish", "Memory",
    "Lotus", "Lily", "Rose", "Iris", "Orchid", "Willow", "Cedar", "Maple", "Pine", "Oak",
}
local PIECE_WORD = { flower = "Flower", plume = "Plume", sands = "Sands", goblet = "Goblet", circlet = "Circlet" }

local function rarityOfRank(rk)
    local acc = 0
    for r = 7, 1, -1 do
        acc = acc + AR_COUNT[r]
        if rk < acc then return r end
    end
    return 1
end

-- Rarity alone (cheap: doesn't build the whole artifact).
function artRarity(i) return rarityOfRank((i * 30011 + 777) % AR_N) end
-- Builds artifact i (the same number always makes the same artifact).
local CACHE = {}
function artInfo(i)
    local a = CACHE[i]
    if a then return a end
    local slot = AR_SLOTS[i % 5 + 1]
    local r = rarityOfRank((i * 30011 + 777) % AR_N)
    local mains = MAINS[slot]
    local main = mains[(floor(i / 5) * 7 + floor(i / 500)) % #mains + 1]
    local function val(stat, frac, seed)
        local base = AR_STATS[stat].v[r] * frac * (1 + 0.1 * (seed % 3))
        return max(1, round(base))
    end
    local stats = { { k = main, v = val(main, 1, i * 13) } }
    -- extra stats: different from the main one and from each other
    local used = { [main] = true }
    local pick_ = (i * 2654435761) % 4294967296
    for s = 1, SUBS[r] do
        local tries = 0
        local k
        repeat
            k = STAT_ORDER[(floor(pick_ / (8 ^ (s + tries - 1))) + s * 3 + tries) % #STAT_ORDER + 1]
            tries = tries + 1
        until not used[k] or tries > 20
        used[k] = true
        push(stats, { k = k, v = val(k, 0.35, i + s * 7) })
    end
    a = {
        i = i, r = r, slot = slot,
        name = ADJ[floor(i / 500) + 1] .. " " .. NOUN[floor(i / 5) % 100 + 1] .. " " .. PIECE_WORD[slot],
        stats = stats,
    }
    local score = 0
    for _, s in ipairs(stats) do score = score + s.v * WEIGHT[s.k] end
    a.score = score + r * 1000   -- rarer first, then better stats
    CACHE[i] = a
    return a
end
function statText(k, v) local S_ = AR_STATS[k]; return S_.n .. " +" .. v .. (S_.pct and "%" or "") end
function artStatsText(a)
    local out = {}
    for n, s in ipairs(a.stats) do push(out, statText(s.k, s.v) .. (n == 1 and " (main)" or "")) end
    return join(out, ", ")
end
function artLine(a) return a.name .. " (" .. AR_RAR[a.r] .. " " .. AR_SLOT_NAME[a.slot] .. ")" end

-- ================= WHICH ONES YOU OWN: 1 bit each, as text =================
local function bitGet(s, i)
    local ci = bit.rshift(i, 2)
    return bit.band(tonumber(s:sub(ci + 1, ci + 1), 16), bit.lshift(1, bit.band(i, 3))) ~= 0
end
local function bitSet(s, i)
    local ci = bit.rshift(i, 2)
    local v = bit.bor(tonumber(s:sub(ci + 1, ci + 1), 16), bit.lshift(1, bit.band(i, 3)))
    return s:sub(1, ci) .. string.format("%x", v) .. s:sub(ci + 2)
end
function artOwned(i) return bitGet(S.arts, i) end
function artCount() return bitCount(S.arts) end
local OWNED_LIST = nil   -- owned artifacts by piece, rebuilt when you find a new one
function artOwnedList(slot)
    if not OWNED_LIST or OWNED_LIST.src ~= S.arts then
        OWNED_LIST = { src = S.arts, flower = {}, plume = {}, sands = {}, goblet = {}, circlet = {} }
        local s = S.arts
        for ci = 1, #s do
            local v = tonumber(s:sub(ci, ci), 16)
            if v ~= 0 then
                for b = 0, 3 do
                    if bit.band(v, bit.lshift(1, b)) ~= 0 then
                        local i = (ci - 1) * 4 + b
                        push(OWNED_LIST[AR_SLOTS[i % 5 + 1]], i)
                    end
                end
            end
        end
        for _, sl in ipairs(AR_SLOTS) do
            table.sort(OWNED_LIST[sl], function(a, b)
                local sa, sb = artInfo(a).score, artInfo(b).score
                if sa ~= sb then return sa > sb end
                return a < b
            end)
        end
    end
    return OWNED_LIST[slot]
end

-- ================= FINDING THEM =================
local BY_R = nil
local function byRarity()
    if BY_R then return BY_R end
    BY_R = {}
    for r = 1, 7 do BY_R[r] = {} end
    for i = 0, AR_N - 1 do push(BY_R[artRarity(i)], i) end
    return BY_R
end
-- A random artifact you don't have yet (deeper floors give rarer ones). nil when there's none left.
function rollArtifact(f)
    local roll, acc, r = random() * 100, 0, 1
    for k = 7, 1, -1 do
        acc = acc + AR_ODDS[k]
        if roll < acc then r = k; break end
    end
    if r < 7 and random() < min(0.5, (f or 1) / 400) then r = r + 1 end   -- deeper is luckier
    local order = { r }
    for k = r - 1, 1, -1 do push(order, k) end
    for k = r + 1, 7 do push(order, k) end
    for _, k in ipairs(order) do
        local list = byRarity()[k]
        -- try a few random picks first, then look through the whole list
        for _ = 1, 12 do
            local i = list[rnd(1, #list)]
            if not artOwned(i) then return i end
        end
        for _, i in ipairs(list) do if not artOwned(i) then return i end end
    end
    return nil
end
-- Called when you open a chest. Returns a message part, or "".
function chestArtifact()
    local r = S.run
    local i = rollArtifact(r.floor)
    if not i then return "" end
    S.arts = bitSet(S.arts, i)
    stat("artifacts")
    r.newArts = r.newArts or {}
    push(r.newArts, i)
    local a = artInfo(i)
    return ", and an artifact: " .. artLine(a)
end

-- ================= EQUIPPING =================
-- S.aeq[character][piece] = artifact number
function artOn(c, slot) local e = S.aeq[c]; return e and e[slot] or nil end
function artWearer(i)
    for c, e in pairs(S.aeq) do for _, sl in ipairs(AR_SLOTS) do if e[sl] == i then return c end end end
    return nil
end
function artEquip(c, i)
    if not artOwned(i) or not S.chars[c] then return end
    local a = artInfo(i)
    local w = artWearer(i)
    if w then S.aeq[w][a.slot] = nil end   -- take it off whoever had it
    S.aeq[c] = S.aeq[c] or {}
    S.aeq[c][a.slot] = i
    ui.artSlot = nil
    ui.artNote = AR_SLOT_NAME[a.slot] .. ": " .. a.name .. (w and w ~= c and " (moved from " .. charInfo(w).name .. ")" or "") .. "."
    save(); render()
end
function artUnequip(c, slot)
    if S.aeq[c] then S.aeq[c][slot] = nil end
    save(); render()
end
-- Total of one stat on one character's artifacts.
function artStatOf(c, k)
    local e = S.aeq and S.aeq[c]
    if not e then return 0 end
    local v = 0
    for _, sl in ipairs(AR_SLOTS) do
        local i = e[sl]
        if i then for _, s in ipairs(artInfo(i).stats) do if s.k == k then v = v + s.v end end end
    end
    return v
end
-- The active character's artifact stat.
function artStat(k)
    local c = activeChar()
    return c and artStatOf(c.i, k) or 0
end
function artSummary(c)
    local parts, n = {}, 0
    for _, sl in ipairs(AR_SLOTS) do if artOn(c, sl) then n = n + 1 end end
    for _, k in ipairs(STAT_ORDER) do
        local v = artStatOf(c, k)
        if v > 0 then push(parts, statText(k, v)) end
    end
    return "Artifacts: " .. n .. " of 5" .. (#parts > 0 and ". " .. join(parts, ", ") or "")
end
-- Puts the best artifacts on the whole party: the leader picks first, then the others in order.
function bestArtifacts(only)
    ui.partyNote = nil
    local order = {}
    if only then order = { only } else
        if S.lead and S.lead >= 0 then push(order, S.lead) end
        for _, c in ipairs(S.party) do if c ~= S.lead then push(order, c) end end
    end
    -- artifacts other party members keep (when doing just one character)
    local taken = {}
    if only then
        for _, c in ipairs(S.party) do
            if c ~= only then for _, sl in ipairs(AR_SLOTS) do local i = artOn(c, sl); if i then taken[i] = true end end end
        end
    else
        for _, c in ipairs(order) do S.aeq[c] = {} end
    end
    local moved = 0
    for _, c in ipairs(order) do
        S.aeq[c] = S.aeq[c] or {}
        for _, sl in ipairs(AR_SLOTS) do
            for _, i in ipairs(artOwnedList(sl)) do
                if not taken[i] then
                    local w = artWearer(i)
                    if w and w ~= c and not contains(S.party, w) then S.aeq[w][sl] = nil; w = nil end
                    if not w or w == c then
                        if S.aeq[c][sl] ~= i then moved = moved + 1 end
                        S.aeq[c][sl] = i
                        taken[i] = true
                        break
                    end
                end
            end
        end
    end
    ui.artNote = artCount() == 0 and "You don't have any artifacts yet. Open treasure chests in the dungeon to find them."
        or "Best artifacts equipped" .. (only and " on " .. charInfo(only).name or " on your party") .. "."
    save(); render()
end
function openArtifacts(c) ui.artChar = c; ui.artSlot = nil; ui.artNote = nil; ui.arPage = 0; ui.bookTop = true; render() end
function openArtSlot(slot) ui.artSlot = slot; ui.arPage = 0; ui.bookTop = true; render() end

function artEquipsForCode()
    local o = asObj({})
    for c, e in pairs(S.aeq) do
        local inner, any = asObj({}), false
        for _, sl in ipairs(AR_SLOTS) do if e[sl] then inner[sl] = e[sl]; any = true end end
        if any then o[c] = inner end
    end
    return o
end
