-- Endless Dungeon: small helpers, and all the game's content (monsters, zones, floors, weapons, pets, classes).
local M = require("dungeon_engine")
setfenv(1, M)

bit = require("bit")
local D = require("dungeon_data")

W, H = 15, 15
VERSION = 3

-- ================= HELPERS =================
floor, ceil, abs = math.floor, math.ceil, math.abs
min, max = math.min, math.max
function round(x) return floor(x + 0.5) end   -- JavaScript's Math.round
function random() return math.random() end    -- tests swap this for a fixed sequence

-- Content lists use the same numbering as the original game (they start at 0).
-- Lists made while playing (monsters, items, log, team...) are normal Lua lists starting at 1.
function len(t) if t[0] == nil then return #t end return #t + 1 end
local function isArray(t)
    if t[1] == nil then return false end
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n == #t
end
function zbdeep(v)
    if type(v) ~= "table" then return v end
    local o = {}
    if isArray(v) then
        for i = 1, #v do o[i - 1] = zbdeep(v[i]) end
    else
        for k, x in pairs(v) do o[k] = zbdeep(x) end
    end
    return o
end
function copy(t) local o = {}; for k, v in pairs(t) do o[k] = v end; return o end
function first(t) return t[0] ~= nil and 0 or 1 end
function contains(t, v)
    for i = first(t), #t do if t[i] == v then return true end end
    return false
end
function find1(t, v) for i = 1, #t do if t[i] == v then return i end end return nil end
function idx0(t, v) for i = 0, len(t) - 1 do if t[i] == v then return i end end return -1 end
function push(t, v) t[#t + 1] = v end
-- JavaScript truthiness: 0, '' and nil are all "false".
function tr(v) return v ~= nil and v ~= false and v ~= 0 and v ~= "" end
function J(a, b) if tr(a) then return a end return b end   -- JavaScript's a || b
function split(s, sep)
    local out, i = {}, 1
    while true do
        local j = s:find(sep, i, true)
        if not j then out[#out + 1] = s:sub(i); break end
        out[#out + 1] = s:sub(i, j - 1)
        i = j + #sep
    end
    return out
end
function join(t, sep) return table.concat(t, sep or ",") end
function startsWith(s, p) return s:sub(1, #p) == p end
function has_str(s, p) return s:find(p, 1, true) ~= nil end

function rnd(a, b) return a + floor(random() * (b - a + 1)) end
function chance(p) return random() * 100 < p end
function sign(n) return n > 0 and 1 or (n < 0 and -1 or 0) end
function pick(a)
    if a[0] ~= nil then return a[rnd(0, #a)] end
    return a[rnd(0, #a - 1) + 1]
end
function shuffle(a)
    local b = first(a)
    for i = len(a) - 1, 1, -1 do
        local j = rnd(0, i)
        a[i + b], a[j + b] = a[j + b], a[i + b]
    end
    return a
end
-- A stable sort, like JavaScript's (cmp returns a number, negative means a comes first).
function ssort(t, cmp)
    local n = #t
    if n < 2 then return t end
    local src, dst, width = t, {}, 1
    while width < n do
        local i = 1
        while i <= n do
            local mid, hi = min(i + width, n + 1), min(i + 2 * width, n + 1)
            local a, b, k = i, mid, i
            while a < mid and b < hi do
                if cmp(src[b], src[a]) < 0 then dst[k] = src[b]; b = b + 1 else dst[k] = src[a]; a = a + 1 end
                k = k + 1
            end
            while a < mid do dst[k] = src[a]; a = a + 1; k = k + 1 end
            while b < hi do dst[k] = src[b]; b = b + 1; k = k + 1 end
            i = i + 2 * width
        end
        src, dst = dst, src
        width = width * 2
    end
    if src ~= t then for i = 1, n do t[i] = src[i] end end
    return t
end
function proper(n) return n:sub(1, 4) == "The " or n:find("^%u%l+ the ") ~= nil end   -- boss names like "Grukk the Ogre"
function aName(n) return proper(n) and n or ((n:find("^[AEIOU]") and "an " or "a ") .. n) end
function the(n) return proper(n) and n or "the " .. n end
function The(n) return proper(n) and n or "The " .. n end
function plural(n)
    if n:sub(-1) == "y" then return n:sub(1, -2) .. "ies" end
    if n:sub(-1) == "s" then return n end
    return n .. "s"
end
function cap(s) return s:sub(1, 1):upper() .. s:sub(2) end
function roman(n)
    local v = { 1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1 }
    local s = { "M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I" }
    local out = ""
    for i = 1, #v do while n >= v[i] do out = out .. s[i]; n = n - v[i] end end
    return out
end
function cheb(ax, ay, bx, by) return max(abs(ax - bx), abs(ay - by)) end
-- Numbers as text, the way JavaScript writes them (no "1e+12").
function num(n)
    if n ~= n then return "NaN" end
    if n == math.huge then return "Infinity" elseif n == -math.huge then return "-Infinity" end
    if n == floor(n) and abs(n) < 2 ^ 53 then return string.format("%d", n) end
    local s
    for p = 1, 17 do   -- the shortest digits that give back the same number
        s = string.format("%." .. p .. "g", n)
        if tonumber(s) == n then break end
    end
    local mant, ex = s:match("^(-?[%d%.]+)e([-+]%d+)$")
    if not mant then return s end
    ex = tonumber(ex)
    if ex >= 21 or ex <= -7 then return mant .. "e" .. (ex > 0 and "+" or "") .. ex end
    local neg = mant:sub(1, 1) == "-"
    local digits = mant:gsub("[-%.]", "")
    if ex >= 0 then
        if #digits <= ex + 1 then return (neg and "-" or "") .. digits .. string.rep("0", ex + 1 - #digits) end
        return (neg and "-" or "") .. digits:sub(1, ex + 1) .. "." .. digits:sub(ex + 2)
    end
    return (neg and "-" or "") .. "0." .. string.rep("0", -ex - 1) .. digits
end
function fmt(n)
    -- Same as the web version: a comma before every group of 3 digits inside each run of digits.
    return (num(n):gsub("%d+", function(run)
        local out, k = "", #run
        while k > 3 do out = "," .. run:sub(k - 2, k) .. out; k = k - 3 end
        return run:sub(1, k) .. out
    end))
end

-- ================= CONTENT =================
ENEMY_DATA = zbdeep(D.ENEMY_DATA)
FAMILY = zbdeep(D.FAMILY)
TYPES = {}
do
    local n = 0
    for i = 0, len(ENEMY_DATA) - 1 do
        local p, t = split(ENEMY_DATA[i], "|"), nil
        t = tonumber(p[3])
        local F = FAMILY[p[4]]
        local bh = 4 + 0.9 * min(t, 21) + 0.25 * max(0, t - 21)
        local ba = 2 + 0.33 * min(t, 21) + 0.1 * max(0, t - 21)
        local T = { n = p[1], c = p[2], tier = t, fam = p[4], ab = p[5] ~= "" and split(p[5], ",") or {},
                    hp = bh * F[0], atk = ba * F[1], def = floor(min(t, 21) / 7) + F[2],
                    undead = false, elite = false, chest = false, heart = false, gold2 = false, v = "", spawn = "", trap = 0 }
        local ex = p[6] ~= "" and split(p[6], ",") or {}
        for j = 1, #ex do
            local kv = split(ex[j], "=")
            if kv[1] == "v" then T.v = kv[2]
            elseif kv[1] == "spawn" then T.spawn = kv[2]
            elseif kv[1] == "trap" then T.trap = tonumber(kv[2])
            elseif kv[1] == "tough" then T.hp = T.hp * 1.4
            else T[kv[1]] = true end
        end
        TYPES[n] = T
        n = n + 1
    end
end

-- ================= 10,000 MONSTER TYPES =================
-- Monster type e: species e % 100, version floor(e / 100). Every 100 floors a tougher version of each kind appears.
EVARS = zbdeep(D.EVARS)
E_N = 10000
function eVar(e)
    local k = floor(e / 100)
    if k == 0 then return nil end
    return EVARS[(k - 1 + 37 * (e % 100)) % 99]
end
function eGen(i, f) return max(0, min(99, floor((f - TYPES[i].tier) / 100))) end
function typeIndexExact(n) for i = 0, len(TYPES) - 1 do if TYPES[i].n == n then return i end end return -1 end
function eName(e)
    local b, k, n = e % 100, floor(e / 100), TYPES[e % 100].n
    if k == 0 then return n end
    local V = eVar(e)
    local w = has_str(n, V[0]) and V[1] or V[0]
    local isThe = n:sub(1, 4) == "The "
    local out = isThe and ("The " .. w .. " " .. n:sub(5)) or (w .. " " .. n)
    if w == V[0] and typeIndexExact(out) >= 0 then   -- e.g. Frost + Troll = Frost Troll, which already exists
        out = isThe and ("The " .. V[1] .. " " .. n:sub(5)) or (V[1] .. " " .. n)
    end
    return out
end
function eTier(e) return TYPES[e % 100].tier + 100 * floor(e / 100) end
function eAbs(e)
    local b, k = e % 100, floor(e / 100)
    local out = {}
    for i = 1, #TYPES[b].ab do out[i] = TYPES[b].ab[i] end
    if k > 0 then
        local V = eVar(e)
        for j = 0, 1 do if not contains(out, V[2][j]) then push(out, V[2][j]) end end
    end
    return out
end
function eOf(m) return m.e == nil and m.i or m.e end
-- Which monster types you've met, as a compact string (1 bit per type).
function mMark(e)
    local ci = bit.rshift(e, 2)
    local v = bit.bor(tonumber(S.mts:sub(ci + 1, ci + 1), 16), bit.lshift(1, bit.band(e, 3)))
    S.mts = S.mts:sub(1, ci) .. string.format("%x", v) .. S.mts:sub(ci + 2)
end
function mSeen(e)
    local ci = bit.rshift(e, 2)
    return bit.band(tonumber(S.mts:sub(ci + 1, ci + 1), 16), bit.lshift(1, bit.band(e, 3))) ~= 0
end
local BITS = { [0] = 0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4 }
function bitCount(s)
    local n = 0
    for i = 1, #s do n = n + BITS[tonumber(s:sub(i, i), 16)] end
    return n
end
function mCount() return bitCount(S.mts) end
function typeIndex(name)
    for i = 0, len(TYPES) - 1 do if TYPES[i].n == name or TYPES[i].c == name then return i end end
    return 0
end

AB = D.AB                       -- what each monster trait does
AB_ORDER = zbdeep(D.AB_ORDER)
MUTS = zbdeep(D.MUTS)           -- random traits monsters can be born with

-- A new zone every 10 floors: 8 hand-made ones, then 992 more built from words (1,000 in all).
ZONES = zbdeep(D.ZONES)
ZWORDS = zbdeep(D.ZWORDS)
do
    local LAYN = { caves = "Twisty caves.", rooms = "Rooms and corridors.", maze = "Narrow passages.", pillars = "Big halls with pillars." }
    for k = 0, 991 do
        local A = ZWORDS.adj[k % 40]
        local P = ZWORDS.place[(floor(k / 40) + 3 * (k % 40)) % 25]
        ZONES[8 + k] = { n = A[0] .. " " .. P[0], lay = P[1], hz = A[1], fav = A[3], mut = A[2], note = LAYN[P[1]] .. " " .. A[4] }
    end
end
LEVELS = zbdeep(D.LEVELS)       -- the 50 kinds of floors
TILE_CODE = D.TILE_CODE         -- 0 floor, 1 wall, 2 lava, 3 spikes, 4 mushroom, 5 water/web/mud/sand, 6 ice, 7 gas, 8 shock, 9 portal

WNAMES = zbdeep(D.WNAMES)       -- 300 weapons in 10 families
WCATS = zbdeep(D.WCATS)
MODS = zbdeep(D.MODS)           -- 20 weapon modifiers
UPS = zbdeep(D.UPS)
PERKS = zbdeep(D.PERKS)
SCROLLS = zbdeep(D.SCROLLS)
ARM = zbdeep(D.ARM)
RAR = zbdeep(D.RAR)
RAR_FX = zbdeep(D.RAR_FX)
WFX = zbdeep(D.WFX)
AFX = zbdeep(D.AFX)
ACH = zbdeep(D.ACH)
ACH2 = zbdeep(D.ACH2)           -- 1000 more achievements: [section, name, what, [levels I to V], counter, kind]
ACHIDX = {}
for i = 0, len(ACH2) - 1 do ACHIDX[ACH2[i][4]] = i end
SYL1, SYL2, SYL3 = zbdeep(D.SYL1), zbdeep(D.SYL2), zbdeep(D.SYL3)
CAPS = D.CAPS
GOOD_MODS = D.GOOD_MODS
AFX_NAME, WFX_NAME = D.AFX_NAME, D.WFX_NAME
TILE_GLYPH = D.TILE_GLYPH
BOOK_TABS = zbdeep(D.BOOK_TABS)
BOOK_TABS[len(BOOK_TABS)] = { [0] = "chars", "Characters" }
BOOK_TABS[len(BOOK_TABS)] = { [0] = "arts", "Artifacts" }
FAMILY_NAME = D.FAMILY_NAME

-- ================= 10,000 FLOOR TYPES: every floor has its own =================
FT_ADJ = zbdeep(D.FT_ADJ)
FT_SUF = zbdeep(D.FT_SUF)
FT_N, FT_BY, FT_CACHE = 10000, {}, {}
FT_CODE = D.FT_CODE
FT_BOSS = zbdeep(D.FT_BOSS)
FT_NORMAL = {}
do
    local n = 0
    for i = 0, len(LEVELS) - 1 do if not LEVELS[i].bossLevel then FT_NORMAL[n] = LEVELS[i]; n = n + 1 end end
end
function ftApply(o, E)
    if E.add then for k, v in pairs(E.add) do o[k] = J(o[k], k == "gold" and 1 or 0) + v end end
    if E.mul then for k, v in pairs(E.mul) do o[k] = round(J(o[k], 1) * v * 100) / 100 end end
    if E.set then for k, v in pairs(E.set) do o[k] = v end end
end
function levelInfoBase(name)
    for i = 0, len(LEVELS) - 1 do if LEVELS[i].n == name then return LEVELS[i] end end
    return nil
end
-- Which of the 50 kinds floor f (1 to 10,000) is.
function ftBase(f)
    if f % 50 == 0 then return levelInfoBase("The Dungeon Core") end
    if f % 5 == 0 then return levelInfoBase(FT_BOSS[(floor((f - 1) / 5) - floor((f - 1) / 50)) % 4]) end
    local nn = (f - 1) - floor((f - 1) / 5)
    local N = len(FT_NORMAL)
    local idx = (nn * 17 + floor(nn / N) * 7) % N
    local B
    for t = 0, N - 1 do   -- skip kinds that aren't allowed this early
        B = FT_NORMAL[(idx + t) % N]
        if not (B.minF and f < B.minF) and not (B.secret and f < 8) then break end
    end
    return B
end
function ftMake(f, ai, si)
    local B, A, X = ftBase(f), FT_ADJ[ai], FT_SUF[si]
    local o = copy(B)
    ftApply(o, A[2]); ftApply(o, X[1])
    return { o = o, B = B, A = A, X = X }
end
function ftFinish(m, f)
    local o, B, A, X = m.o, m.B, m.A, m.X
    local word = has_str(B.n, A[0]) and A[1] or A[0]
    o.base = B.n; o.id = f
    o.n = (B.n:sub(1, 4) == "The " and ("The " .. word .. " " .. B.n:sub(5)) or (word .. " " .. B.n)) .. (X[0] ~= "" and " " .. X[0] or "")
    o.note = B.note .. " " .. A[3] .. (X[2] ~= "" and " " .. X[2] or "")
    return o
end
function floorType(f)
    local id = (f - 1) % FT_N + 1
    if FT_CACHE[id] then return FT_CACHE[id] end
    local v = tonumber(FT_CODE:sub((id - 1) * 2 + 1, (id - 1) * 2 + 2), 36)
    local o = ftFinish(ftMake(id, floor(v / 16), v % 16), id)
    FT_CACHE[id] = o; FT_BY[o.n] = o
    return o
end
-- Which of the 10,000 floor types you've been to, as a compact string (1 bit per floor).
function ftMark(f)
    local id = (f - 1) % FT_N
    local ci = bit.rshift(id, 2)
    local v = bit.bor(tonumber(S.fts:sub(ci + 1, ci + 1), 16), bit.lshift(1, bit.band(id, 3)))
    S.fts = S.fts:sub(1, ci) .. string.format("%x", v) .. S.fts:sub(ci + 2)
end
function ftSeen(f)
    local id = (f - 1) % FT_N
    local ci = bit.rshift(id, 2)
    return bit.band(tonumber(S.fts:sub(ci + 1, ci + 1), 16), bit.lshift(1, bit.band(id, 3))) ~= 0
end
function ftCount() return bitCount(S.fts) end
function pickLevel(f) return floorType(f).n end

-- ================= PETS: 10,000 of them =================
PETS = zbdeep(D.PETS)
PWORDS = zbdeep(D.PWORDS)
do
    for k = 0, 9699 do
        local nm = PWORDS.names[floor(k / 100)] .. " the " .. PWORDS.animals[k % 100]
        local rar = (k * 7 + floor(k / 100)) % 6
        local eff = PWORDS.pool[(k * 13 + floor(k / 100) * 5) % len(PWORDS.pool)]
        PETS[300 + k] = { [0] = nm, PWORDS.feat[eff], rar, eff }
    end
end
PRAR = zbdeep(D.PRAR)
PRM = zbdeep(D.PRM)
TEAM_MAX = 5
PET_ACTIVE = D.PET_ACTIVE
PET_WEIGHT = D.PET_WEIGHT

-- ================= CLASSES: 300 in 10 tiers =================
CLASSES = zbdeep(D.CLASSDATA.classes)   -- [name, cost, tier, description, [[effect, value], ...]]
CTIERS = zbdeep(D.CLASSDATA.tiers)

-- ================= CAMP SHOPS =================
CWORDS = zbdeep(D.CWORDS)
CW_N, CW_TIER, CW_PAGE = 5000, 500, 25
CW_MODS = zbdeep(D.CW_MODS)
AWORDS = zbdeep(D.AWORDS)
CA_N, CA_TIER, CA_PAGE = 1000, 100, 25
CA_PRE = D.CA_PRE

ACH_PAGE = 40
ACH_SECS = { [0] = "Main" }
for i = 0, len(ACH2) - 1 do
    if idx0(ACH_SECS, ACH2[i][0]) < 0 then ACH_SECS[len(ACH_SECS)] = ACH2[i][0] end
end
