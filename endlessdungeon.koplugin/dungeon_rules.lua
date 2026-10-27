-- Endless Dungeon: saving, player stats, gear, monsters, maps, floors, bounties, runs, achievements, elevator, panels.
local M = require("dungeon_engine")
setfenv(1, M)

S = nil   -- everything that gets saved
ui = { showCode = false, codeMsg = "", elev = false, bag = false, pick = 1, startAt = 1, book = "", bookTop = false,
       pets = false, classes = false, clsTier = 1, achs = false, achSec = 0, achPage = 0, achNote = "", wpns = false,
       cwTier = 1, cwPage = 0, arms = false, caTier = 1, caPage = 0, ePage = 0, pRar = 0, pPage = 0, fPage = 0, zPage = 0,
       resetArm = false }
killHow, clsHitting = "", false

-- The KOReader screen fills these in. render() just asks for a redraw; ask() shows a yes/no question.
function render()
    -- Drawing the screen in the web version also tidies a few things up; do the same here.
    if S.run then ui.pets = false; ui.classes = false; ui.achs = false; ui.wpns = false; ui.arms = false; ui.chars = false; ui.artChar = nil; ui.perksView = false end
    if not S.run then ui.swap = false end
    if not tr(ui.book) and S.run then
        -- drawing the map checks every monster in sight, which can uncover a hidden one right next to you
        for y = 0, H - 1 do
            for x = 0, W - 1 do
                if visible(x, y) then local m = monAt(x, y); if m then hiddenMon(m) end end
            end
        end
        local P = S.run.panel
        if P and P.t ~= "perk" then   -- a panel for something you're no longer standing on goes away
            local it = hereItem()
            local want = { loot = "gear", shop = "shop", shrine = "shrine", pet = "pet", altar = "altar" }
            if not it or it.k ~= want[P.t] then S.run.panel = nil end
        end
    elseif not tr(ui.book) and not (ui.pets or ui.classes or ui.achs or ui.wpns or ui.arms or ui.chars or ui.perksView) and S.best > 1 then
        ui.startAt = max(1, min(ui.startAt, S.best))
    end
    M.dirty = true
end
function ask(question, yes)
    if M.askHook then M.askHook(question, yes) else yes() end
end

-- ================= JSON and base64, for save codes =================
-- Save codes are the same as the web version's, so progress can move between the two.
local OBJ, ARR = {}, {}
function asObj(t) return setmetatable(t or {}, OBJ) end
function asArr(t)
    local o = {}
    for i = 1, #(t or {}) do o[i] = t[i] end
    return setmetatable(o, ARR)
end
local function jstr(s)
    return '"' .. s:gsub('[%c"\\]', function(c)
        local map = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }
        return map[c] or string.format("\\u%04x", c:byte())
    end) .. '"'
end
function jsonEncode(v)
    local t = type(v)
    if v == nil then return "null" end
    if t == "boolean" then return tostring(v) end
    if t == "number" then return num(v) end
    if t == "string" then return jstr(v) end
    local isArr = getmetatable(v) == ARR or (getmetatable(v) ~= OBJ and v[1] ~= nil)
    if isArr then
        for k in pairs(v) do if type(k) ~= "number" or k < 1 or k > #v then isArr = false; break end end
    end
    local parts = {}
    if isArr then
        for i = 1, #v do parts[i] = jsonEncode(v[i]) end
        return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do parts[#parts + 1] = jstr(tostring(k)) .. ":" .. jsonEncode(v[k]) end
    return "{" .. table.concat(parts, ",") .. "}"
end
function jsonDecode(s)
    local pos = 1
    local function ws() pos = s:find("[^ \t\r\n]", pos) or #s + 1 end
    local val
    local function str()
        local out, i = {}, pos + 1
        while true do
            local c = s:sub(i, i)
            if c == "" then error("bad string") end
            if c == '"' then pos = i + 1; return table.concat(out) end
            if c == "\\" then
                local e = s:sub(i + 1, i + 1)
                local map = { b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }
                if e == "u" then
                    local code = tonumber(s:sub(i + 2, i + 5), 16)
                    if code < 128 then out[#out + 1] = string.char(code)
                    elseif code < 2048 then out[#out + 1] = string.char(192 + floor(code / 64), 128 + code % 64)
                    else out[#out + 1] = string.char(224 + floor(code / 4096), 128 + floor(code / 64) % 64, 128 + code % 64) end
                    i = i + 6
                else out[#out + 1] = map[e] or e; i = i + 2 end
            else out[#out + 1] = c; i = i + 1 end
        end
    end
    val = function()
        ws()
        local c = s:sub(pos, pos)
        if c == "{" then
            local o = {}
            pos = pos + 1; ws()
            if s:sub(pos, pos) == "}" then pos = pos + 1; return o end
            while true do
                ws(); local k = str(); ws()
                if s:sub(pos, pos) ~= ":" then error("bad object") end
                pos = pos + 1
                o[k] = val(); ws()
                local d = s:sub(pos, pos); pos = pos + 1
                if d == "}" then return o elseif d ~= "," then error("bad object") end
            end
        elseif c == "[" then
            local a = {}
            pos = pos + 1; ws()
            if s:sub(pos, pos) == "]" then pos = pos + 1; return a end
            while true do
                a[#a + 1] = val(); ws()
                local d = s:sub(pos, pos); pos = pos + 1
                if d == "]" then return a elseif d ~= "," then error("bad array") end
            end
        elseif c == '"' then return str()
        elseif s:sub(pos, pos + 3) == "true" then pos = pos + 4; return true
        elseif s:sub(pos, pos + 4) == "false" then pos = pos + 5; return false
        elseif s:sub(pos, pos + 3) == "null" then pos = pos + 4; return nil
        else
            local n = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
            if not n or n == "" then error("bad value") end
            pos = pos + #n
            return tonumber(n)
        end
    end
    local v = val()
    return v
end
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
function btoa(s)
    local out = {}
    for i = 1, #s, 3 do
        local a, b, c = s:byte(i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local q = { floor(n / 262144) % 64, floor(n / 4096) % 64, floor(n / 64) % 64, n % 64 }
        out[#out + 1] = B64:sub(q[1] + 1, q[1] + 1) .. B64:sub(q[2] + 1, q[2] + 1) ..
                        (b and B64:sub(q[3] + 1, q[3] + 1) or "=") .. (c and B64:sub(q[4] + 1, q[4] + 1) or "=")
    end
    return table.concat(out)
end
function atob(s)
    s = s:gsub("[^%w%+/]", "")
    local out, bits, n = {}, 0, 0
    for i = 1, #s do
        local v = B64:find(s:sub(i, i), 1, true) - 1
        n = n * 64 + v; bits = bits + 6
        if bits >= 8 then
            bits = bits - 8
            local byte = floor(n / 2 ^ bits)
            out[#out + 1] = string.char(byte)
            n = n % 2 ^ bits
        end
    end
    return table.concat(out)
end

-- ================= SAVING =================
function freshSave()
    return { v = VERSION, gold = 0, up = {}, perkAt = {}, best = 0, runs = 0, run = nil, last = nil,
             stats = {}, ach = {}, seen = {}, stars = 0, asc = 0, peak = 0, pets = {}, team = {}, cls = 0, clsOwn = { [0] = 1 },
             cw = {}, cwEq = -1, ca = {}, caEq = -1, fts = "", mts = "", chars = {}, party = {}, lead = -1, arts = "", aeq = {} }
end
function fixSave()
    for i = 0, len(UPS) - 1 do if not tr(S.up[UPS[i].id]) then S.up[UPS[i].id] = 0 end end
    if not S.perkAt then S.perkAt = {} end
    if not S.stats then S.stats = {} end
    if not S.ach then S.ach = {} end
    if not S.seen then S.seen = {} end
    if not tr(S.stars) then S.stars = 0 end
    if not tr(S.asc) then S.asc = 0 end
    if not tr(S.peak) then S.peak = 0 end
    if not S.pets then S.pets = {} end
    if not S.team then S.team = {} end
    if not S.clsOwn then S.clsOwn = { [0] = 1 } end
    if not tr(S.cls) or not S.clsOwn[S.cls] then S.cls = 0 end
    if not S.cw then S.cw = {} end
    if S.cwEq == nil or (S.cwEq >= 0 and not S.cw[S.cwEq]) then S.cwEq = -1 end
    if not S.ca then S.ca = {} end
    if not S.mts or #S.mts ~= E_N / 4 then
        S.mts = string.rep("0", E_N / 4)
        for t = 0, len(TYPES) - 1 do if S.seen["t" .. t] then mMark(t); S.seen["t" .. t] = nil end end   -- older saves
    end
    if not S.fts or #S.fts ~= FT_N / 4 then S.fts = string.rep("0", FT_N / 4) end
    if S.caEq == nil or (S.caEq >= 0 and not S.ca[S.caEq]) then S.caEq = -1 end
    if not S.chars then S.chars = {} end
    if type(S.arts) ~= "string" or #S.arts ~= AR_N / 4 then S.arts = string.rep("0", AR_N / 4) end
    if type(S.aeq) ~= "table" then S.aeq = {} end
    do   -- every artifact on at most one character, and only ones you own
        local seen = {}
        for c, e in pairs(S.aeq) do
            for _, sl in ipairs(AR_SLOTS) do
                local i = e[sl]
                if i and (seen[i] or not artOwned(i) or artInfo(i).slot ~= sl) then e[sl] = nil elseif i then seen[i] = true end
            end
        end
    end
    if not S.party then S.party = {} end
    for k = #S.party, 1, -1 do if not S.chars[S.party[k]] then table.remove(S.party, k) end end
    while #S.party > PARTY_MAX do table.remove(S.party) end
    if S.lead == nil or not contains(S.party, S.lead) then S.lead = S.party[1] or -1 end
    if not tr(S.stats.deep) or S.stats.deep < S.best then S.stats.deep = S.best end
end
-- Start the game from a saved table (or nil for a brand new game).
function loadGame(saved)
    S = saved
    if type(S) ~= "table" or not S.up then S = freshSave() end
    fixSave()
    if S.v ~= VERSION then
        -- A run saved by an older version can't continue: bank its gold and go back to camp.
        if S.run then
            S.gold = S.gold + (S.run.goldRun or 0)
            S.last = { note = "The dungeon has grown! 100 monsters, 300 weapons, 50 kinds of floors and more. Your gold from your last run is safe." }
            S.run = nil
        end
        S.v = VERSION
        save()
    end
    ui.startAt = J(S.best, 1)
    if S.run then checkPanels()
    else campClaim(); save() end
end
function save()
    if M.saveHook then M.saveHook(S) end
end
local function numKeys(t)
    local o = {}
    for k, v in pairs(t or {}) do o[tonumber(k) or k] = v end
    return o
end
function saveCode()
    return btoa(jsonEncode(asObj({ g = S.gold, u = asObj(S.up), b = S.best, r = S.runs, p = asObj(S.perkAt), st = asObj(S.stats),
        a = asObj(S.ach), sn = asObj(S.seen), s = S.stars, as = S.asc, pk = S.peak, pt = asObj(S.pets), tm = asArr(S.team), cl = S.cls,
        co = asObj(S.clsOwn), cw = asObj(S.cw), ce = S.cwEq, ca = asObj(S.ca), ae = S.caEq, ft = S.fts, mt = S.mts,
        ch = asObj(S.chars), pa = asArr(S.party), ld = S.lead, ar = S.arts, aq = artEquipsForCode() })))
end
function loadCode(txt)
    txt = (txt or ""):gsub("%s", "")
    local ok = pcall(function()
        local d = jsonDecode(atob(txt))
        if type(d) ~= "table" or type(d.g) ~= "number" or type(d.u) ~= "table" then error("bad") end
        if type(d.tm) ~= "table" then d.tm = nil end
        S.gold = d.g; S.best = d.b or 0; S.runs = d.r or 0
        S.up = {}
        for i = 0, len(UPS) - 1 do S.up[UPS[i].id] = d.u[UPS[i].id] or 0 end
        S.perkAt = d.p or {}; S.stats = d.st or {}; S.ach = d.a or {}; S.seen = d.sn or {}
        S.stars = d.s or 0; S.asc = d.as or 0; S.peak = d.pk or 0; S.pets = numKeys(d.pt); S.team = d.tm or {}
        S.cls = d.cl or 0; S.clsOwn = d.co and numKeys(d.co) or { [0] = 1 }
        S.cw = numKeys(d.cw); S.cwEq = d.ce == nil and -1 or d.ce
        S.ca = numKeys(d.ca); S.caEq = d.ae == nil and -1 or d.ae; S.fts = d.ft or ""; S.mts = d.mt or ""
        -- a code from the web version has no characters: keep the ones on this Kindle
        if d.ch then S.chars = numKeys(d.ch); S.party = type(d.pa) == "table" and d.pa or {}; S.lead = d.ld or -1 end
        if type(d.ar) == "string" then S.arts = d.ar; S.aeq = numKeys(d.aq) end
        fixSave()
        S.run = nil; S.last = nil
    end)
    if ok then
        ui.codeMsg = "Save code loaded."
        ui.startAt = J(S.best, 1)
        save()
    else
        ui.codeMsg = "That code didn't work. Check that you copied all of it."
    end
    render()
    return ok
end

-- ================= HELPERS =================
function say(t) push(S.run.log, t) end
function statA(k, n) if ACHIDX[k] ~= nil then stat(k, n) end end   -- only counters that have an achievement
function stat(k, n) S.stats[k] = (S.stats[k] or 0) + (n == nil and 1 or n) end
function statMax(k, v) if v > (S.stats[k] or 0) then S.stats[k] = v end end
function monAt(x, y)
    local ms = S.run.mons
    for i = 1, #ms do if ms[i].x == x and ms[i].y == y then return ms[i] end end
    return nil
end
-- Position of the item on this square in S.run.items, or -1.
function itemAt(x, y)
    local it = S.run.items
    for i = 1, #it do if it[i].x == x and it[i].y == y then return i end end
    return -1
end
function has(m, a) return contains(m.abs, a) end
function upCost(id)
    for i = 0, len(UPS) - 1 do if UPS[i].id == id then return round(UPS[i].base * 1.3 ^ S.up[id]) end end
    return 0
end
function perkInfo(id)
    for i = 0, len(PERKS) - 1 do if PERKS[i].id == id then return PERKS[i] end end
    return PERKS[0]
end
function scrollInfo(id)
    for i = 0, len(SCROLLS) - 1 do if SCROLLS[i].id == id then return SCROLLS[i] end end
    return SCROLLS[0]
end
function modInfo(id)
    for i = 0, len(MODS) - 1 do if MODS[i].id == id then return MODS[i] end end
    return MODS[0]
end
function levelInfo(name)
    if FT_BY[name] then return FT_BY[name] end
    for i = 0, len(LEVELS) - 1 do if LEVELS[i].n == name then return LEVELS[i] end end
    return nil
end
-- The kind of floor (one of the 50) behind a floor's own type, for achievements.
function lbase() local L = curLevel(); return L and (L.base or L.n) or "" end
function zoneOf(f)
    local z = floor((f - 1) / 10)
    local Z = ZONES[z % len(ZONES)]
    local tier = floor(z / len(ZONES)) + 1
    return { n = Z.n .. (tier > 1 and " " .. roman(tier) or ""), lay = Z.lay, hz = Z.hz, fav = Z.fav, mut = Z.mut, note = Z.note }
end
function curLevel()
    local r = S.run
    if tr(r.ftId) then return floorType(r.ftId) end
    if tr(r.level) then return levelInfo(r.level) end
    return nil
end
function view()
    local r, L = S.run, curLevel()
    if (L and L.dark) or zoneOf(r.floor).hz == "dark" then return 2 + petSight() + cv("sight") + charSight() end
    return 4 + petSight() + cv("sight") + charSight()
end
function petHpMul() return (1 + 0.05 * petSum("hp") + 0.03 * petSum("allstats")) * clsHpMul() * charHpMul() end
function starMul() return 1 + 0.1 * (S.stars or 0) end
function harmful(t) return t == 2 or t == 3 or t == 7 or t == 8 end

-- ================= SAVED PERKS =================
function slotName(key)
    if not tr(key) then return "this level" end
    return key:sub(1, 1) == "B" and "Blessing " .. key:sub(2) or "level " .. key:sub(2)
end
function slotOrder(a, b)
    local ta = a:sub(1, 1) == "B" and 0 or 1
    local tb = b:sub(1, 1) == "B" and 0 or 1
    if ta ~= tb then return ta - tb end
    return tonumber(a:sub(2)) - tonumber(b:sub(2))
end
function forgetPerk(key) S.perkAt[key] = nil; save(); render() end
function forgetAll()
    ask("Forget all saved perks? You'll choose them again as you level up.", function() S.perkAt = {}; save(); render() end)
end

-- ================= PLAYER STATS =================
function gearFx(g, key)
    local v = 0
    if not g or not g.fxs then return 0 end
    for i = 1, #g.fxs do if g.fxs[i].fx == key then v = v + g.fxs[i].v end end
    return v
end
function fx(key)
    local r = S.run
    local p, v = r.pf[key] or 0, 0
    if key == "vamp" then v = 3 * p
    elseif key == "crit" then v = 15 * p
    elseif key == "thorns" then v = 30 * p
    elseif key == "dodge" then v = 10 * p
    elseif key == "greed" then v = 40 * p
    elseif key == "regen" then v = p end
    v = v + gearFx(r.wpn, key) + gearFx(r.arm, key)
    if key == "crit" then v = v + 3 * petSum("crit")
    elseif key == "dodge" then v = v + 3 * petSum("dodge") end
    if CAPS[key] then v = min(CAPS[key], v) end
    if key == "crit" then v = min(90, v + cv("crit") + artStat("crit"))
    elseif key == "dodge" then v = min(60, v + cv("dodge") + artStat("dodge")) end
    return v
end
function capped(id) return CAPS[id] ~= nil and fx(id) >= CAPS[id] end
function wcat() local r = S.run; return (r.wpn and r.wpn.cat ~= nil) and WCATS[r.wpn.cat] or nil end
function wmod() local r = S.run; return (r.wpn and tr(r.wpn.mod)) and r.wpn.mod or "" end
function atkOf()
    local r = S.run
    local a = (r.atk + (r.wpn and r.wpn.atk or 0) + fx("fury")) * starMul() * charAtkMul()
    return max(1, round(r.weak > 0 and a * 0.7 or a))
end
function defOf()
    local r = S.run
    local pa = round((petSum("armor") + 0.5 * petSum("allstats")) * (1 + r.floor / 10))
    return r.def + (r.arm and r.arm.def or 0) + fx("guard") + pa + artStat("def")
end
function heal(n)
    local r = S.run
    local before = r.hp
    r.hp = min(r.maxHp, r.hp + n)
    return max(0, r.hp - before)
end
-- Start of a turn: clear the log and remember HP, so the combat log can show what changed.
function newTurn() local r = S.run; r.log = {}; r.hpStart = r.hp end
function inFight() return #seenMonsters() > 0 end
function goldAmt(v) return round(v * (1 + fx("greed") / 100 + 0.08 * petSum("gold") + cv("gold") / 100 + artStat("gold") / 100) * starMul()) end
function hurt(d, who)
    local r = S.run
    r.hp = r.hp - d; r.fd = r.fd + d; r.lastHurt = who
    stat("c_Damage Taker", d)
    if r.hp == 1 then stat("c_Close Call") end
    local b = r.bounty
    if b and b.state == "on" and b.t == "safe" and r.fd >= b.need then b.state = "failed"; say("Bounty failed: you lost too much HP.") end
end

function applyPerk(id)
    local r = S.run
    r.pf[id] = (r.pf[id] or 0) + 1
    stat("pp_" .. perkInfo(id).n); statMax("ps_" .. perkInfo(id).n, r.pf[id])
    if id == "tough" then r.maxHp = r.maxHp + 8; r.hp = r.hp + 8
    elseif id == "strong" then r.atk = r.atk + 2
    elseif id == "guard" then r.def = r.def + 1
    elseif id == "supply" then r.potions = r.potions + 2
    elseif id == "scholar" then for _ = 0, 2 do local s = pick(SCROLLS).id; r.scrolls[s] = r.scrolls[s] + 1 end end
end
function randomPerk()
    local p = pick(PERKS)
    while capped(p.id) do p = pick(PERKS) end
    return p.id
end
function perkChoices()
    local out = {}
    while #out < 3 do
        local id = randomPerk()
        if not contains(out, id) then push(out, id) end
    end
    return out
end

-- ================= GEAR =================
function sfxValue(k, f)
    if k == "leech" then return 1 + floor(f / 5) end
    if k == "life" then return 8 + 2 * floor(f / 2) end
    if k == "fury" then return 2 + floor(f / 4) end
    if k == "pierce" then return 1 + floor(f / 6) end
    if k == "guard" then return 1 + floor(f / 8) end
    if k == "regen" then return 1 end
    if k == "crit" then return 10 end
    if k == "greed" then return 25 end
    if k == "thorns" then return 20 end
    return 8   -- dodge
end
function rollRarity(f, minR)
    local ri = 0
    local p = 0.3 + min(0.25, f / 200) + min(0.15, 0.02 * petSum("loot")) + min(0.15, 0.015 * cv("loot"))
    while ri < len(RAR) - 1 and random() < p do ri = ri + 1 end
    ri = min(ri, 1 + floor(f / 6))
    if tr(minR) then ri = max(ri, min(minR, len(RAR) - 1)) end
    return ri
end
function addFxs(g, f, pool)
    pool = shuffle(copy(pool))
    for k = 0, RAR_FX[g.rar] - 1 do push(g.fxs, { fx = pool[k], v = sfxValue(pool[k], f) }) end
end
function makeWeapon(f, minR, opts)
    opts = opts or {}
    local c = rnd(0, len(WCATS) - 1)
    local C = WCATS[c]
    local t = max(0, floor(f / 2) + rnd(-2, 1))
    local base = WNAMES[c][min(t, 29)] .. (t > 29 and " +" .. (t - 29) or "")
    if opts.secret then base = pick({ "The Impossible Weapon", "The Dungeon's Secret" }) end
    local pool = {}
    for i = 0, len(MODS) - 1 do
        if not (MODS[i].opt and f < 8) then
            push(pool, MODS[i])
            if not MODS[i].opt then push(pool, MODS[i]) end   -- the main 10 are more common
        end
    end
    local Md = opts.cursed and modInfo("cursed") or pick(pool)
    local raw = max(1, 1 + floor(f / 2) + rnd(0, 1)) * (opts.secret and 1.5 or 1)
    local g = { slot = "wpn", cat = c, base = base, mod = Md.id, atk = max(1, round(raw * C.mult * (1 + Md.pct / 100))),
                def = 0, fxs = {}, mv = 2 + floor(f / 5) }
    g.rar = rollRarity(f, minR)
    addFxs(g, f, WFX)
    g.name = Md.n .. " " .. base
    return g
end
function makeArmor(f, minR)
    local q = rnd(0, 9)
    local bonus = q < 2 and -1 or (q < 7 and 0 or (q < 9 and 1 or 2))
    local pre = { "Battered", "", "Sturdy", "Masterwork" }
    local t = floor(f / 4) + rnd(0, 1)
    local base = t < len(ARM) and ARM[t] or ARM[len(ARM) - 1] .. " +" .. (t - len(ARM) + 1)
    local g = { slot = "arm", atk = 0, def = max(1, floor(f / 4) + rnd(0, 1) + (bonus > 0 and 1 or bonus)), fxs = {}, base = base }
    g.rar = rollRarity(f, minR)
    addFxs(g, f, AFX)
    local sfx = { thorns = "of Thorns", life = "of Life", dodge = "of Shadows", regen = "of Mending", guard = "of the Turtle" }
    local p = pre[bonus + 2]
    g.name = (p ~= "" and p .. " " or "") .. base .. (#g.fxs > 0 and " " .. sfx[g.fxs[1].fx] or "")
    return g
end
function makeGear(f, slot, minR, opts)
    if not tr(slot) then slot = random() < 0.55 and "wpn" or "arm" end
    return slot == "wpn" and makeWeapon(f, minR, opts) or makeArmor(f, minR)
end
function fxText(k, v)
    if k == "leech" then return "heals " .. v .. " HP per hit" end
    if k == "crit" then return "+" .. v .. "% double damage" end
    if k == "greed" then return "+" .. v .. "% gold" end
    if k == "fury" then return "+" .. v .. " attack" end
    if k == "pierce" then return "ignores " .. v .. " monster armor" end
    if k == "thorns" then return "hits back " .. v .. "% of damage" end
    if k == "life" then return "+" .. v .. " max HP" end
    if k == "dodge" then return "+" .. v .. "% dodge" end
    if k == "regen" then return "heals " .. v .. " HP every 3 turns" end
    if k == "guard" then return "+" .. v .. " armor" end
    return ""
end
function gearDesc(g)
    local parts = {}
    if g.slot == "wpn" then
        local C, Md = WCATS[g.cat or 0], modInfo(g.mod)
        push(parts, C.n .. ": " .. C.d)
        push(parts, "Attack +" .. g.atk)
        push(parts, Md.n .. ": " .. (g.mod == "leeching" and "heals " .. g.mv .. " HP per hit" or Md.d))
    else push(parts, "Armor +" .. g.def) end
    for i = 1, #g.fxs do push(parts, cap(fxText(g.fxs[i].fx, g.fxs[i].v))) end
    return join(parts, ". ")
end
function rarName(g) return RAR[g.rar or 0] end
function noteGear(g)
    if g.slot ~= "wpn" then return end
    if g.camp ~= nil then S.seen["o" .. g.mod] = 1; return end
    S.seen["w" .. g.base:gsub(" %+%d+$", "")] = 1
    S.seen["o" .. g.mod] = 1
end

-- ================= GEAR COMPARISON =================
-- One number for how good a piece of gear is, so two pieces can be compared.
function gearScore(g)
    if not g then return 0 end
    local s = 0
    if g.slot == "wpn" then
        local C = WCATS[g.cat or 0]
        s = g.atk * (1 + (GOOD_MODS[g.mod] or 0) + (C.crit or 0) / 100 + (C.range and 0.1 or 0) + (C.sweep and 0.1 or 0) +
                     (C.dbl and 0.12 or 0) + (C.stun and 0.05 or 0))
        for i = 1, #g.fxs do
            local f = g.fxs[i]
            if f.fx == "fury" or f.fx == "leech" or f.fx == "pierce" then s = s + f.v
            elseif f.fx == "crit" then s = s + g.atk * f.v / 100
            else s = s + 1 end
        end
    else
        s = g.def * 3
        for i = 1, #g.fxs do
            local f = g.fxs[i]
            if f.fx == "guard" then s = s + f.v * 3
            elseif f.fx == "life" then s = s + f.v / 3
            elseif f.fx == "regen" then s = s + 3
            elseif f.fx == "dodge" then s = s + f.v / 2
            else s = s + f.v / 8 end
        end
    end
    return s
end
-- "Better", "Worse" or "About the same", with the main numbers side by side.
function compareInfo(g)
    local r = S.run
    local cur = g.slot == "wpn" and r.wpn or r.arm
    local a, b = gearScore(g), gearScore(cur)
    local verdict, cls
    if not cur or a > b * 1.05 then verdict = "BETTER"; cls = "better"
    elseif a < b * 0.95 then verdict = "WORSE"; cls = "worse"
    else verdict = "ABOUT THE SAME"; cls = "same" end
    local line = g.slot == "wpn" and ("Attack " .. g.atk .. " vs " .. (cur and cur.atk or 0)) or ("Armor " .. g.def .. " vs " .. (cur and cur.def or 0))
    local extra = cur and (" Bonuses: " .. #g.fxs .. " vs " .. #cur.fxs .. ".") or ""
    if g.slot == "wpn" and cur and g.cat ~= cur.cat then extra = extra .. " Different family: " .. WCATS[g.cat].n .. " instead of " .. WCATS[cur.cat].n .. "." end
    return verdict, cls, line .. "." .. extra
end
function destroyHere()
    local r, it = S.run, hereItem()
    if not it or it.k ~= "gear" then closePanel(); return end
    stat("destroy")
    table.remove(r.items, find1(r.items, it))
    r.log = { "You leave the " .. it.g.name .. " behind. It crumbles to dust." }
    closePanel()
end

-- Achievement counts for gear you find and gear you put on.
function gearFound(g)
    if not g or g.found then return end
    g.found = 1
    stat("fr_" .. RAR[g.rar or 0])
    if g.slot == "wpn" then stat("fm_" .. modInfo(g.mod).n) end
end
function gearOn(g)
    stat("equip"); stat("eq_" .. RAR[g.rar or 0])
    local names, done = g.slot == "wpn" and WFX_NAME or AFX_NAME, {}
    if g.slot ~= "wpn" then stat("ea_" .. g.base:gsub(" %+%d+$", "")) end
    for i = 1, #g.fxs do
        local n = names[g.fxs[i].fx]
        if n and not done[n] then done[n] = 1; stat((g.slot == "wpn" and "ewb_" or "eab_") .. n) end
    end
end
function equip(g)
    local r = S.run
    noteGear(g)
    if g.slot == "wpn" then r.wpn = g; return end
    r.maxHp = r.maxHp - gearFx(r.arm, "life")
    r.arm = g
    local l = gearFx(g, "life")
    r.maxHp = r.maxHp + l; r.hp = r.hp + l
    r.hp = max(1, min(r.hp, r.maxHp))
end

-- ================= MONSTERS =================
function scaleK(f) return 1 + 0.12 * (f - 1) + 0.004 * (f - 1) * (f - 1) end
function mutCount(f)
    if f < 6 then return 0 end
    local b = (f - 6) / 15
    local n = floor(b) + (random() < b - floor(b) and 1 or 0)
    return min(3, n)
end
function bossName() return pick(SYL1) .. pick(SYL2) .. pick(SYL3) end
function addMut(m, id, muts)
    if has(m, id) then return end
    push(m.abs, id)
    push(muts, id)
end
function mutAdj(id)
    for i = 0, len(MUTS) - 1 do if MUTS[i].id == id then return MUTS[i].adj end end
    return ""
end
-- Which kind of monster shows up: newer kinds are more common, and the floor's theme favors some.
function pickType(f, fav)
    local cands, recent, favs = {}, {}, {}
    for i = 0, len(TYPES) - 1 do
        local T = TYPES[i]
        if not (T.elite or T.chest or T.heart) and T.tier <= f then
            push(cands, i)
            if T.tier >= f - 12 then push(recent, i) end
        end
    end
    if fav then
        for i = first(fav), #fav do
            local k = typeIndex(fav[i])
            if TYPES[k].tier <= f + 3 and not TYPES[k].heart then push(favs, k) end
        end
    end
    if #favs > 0 and random() < 0.5 then return pick(favs) end
    if #recent >= 4 and random() < 0.75 then return pick(recent) end
    return pick(cands)
end
function pickBossType(f)
    local el = {}
    for i = 0, len(TYPES) - 1 do if TYPES[i].elite and not TYPES[i].heart and TYPES[i].tier <= f then push(el, i) end end
    if #el > 0 then
        ssort(el, function(a, b) return TYPES[b].tier - TYPES[a].tier end)
        local top = {}
        for k = 1, min(3, #el) do top[k] = el[k] end
        return pick(top)
    end
    local best = 0
    for i = 0, len(TYPES) - 1 do
        local T = TYPES[i]
        if not T.elite and not T.chest and not T.heart and T.tier <= f and T.tier >= TYPES[best].tier then best = i end
    end
    return best
end
function makeMon(f, kind, ti, extraMuts)
    kind = kind or ""
    local Z = zoneOf(f)
    local L = (S.run and tr(S.run.level)) and curLevel() or nil
    local i = ti
    if i == nil then
        if kind == "boss" then i = pickBossType(f) else i = pickType(f, (L and L.fav) or Z.fav) end
    end
    local T, k, gen = TYPES[i], scaleK(f), eGen(i, f)
    local e = i + 100 * gen
    local vn = eName(e)
    local m = { i = i, e = e, ch = T.c, name = vn, abs = eAbs(e), kind = kind, hp = round(T.hp * k * (1 + 0.005 * gen)),
                atk = max(1, round(T.atk * k * (1 + 0.003 * gen))), def = T.def + floor((f - 1) / 6), awake = false,
                frozen = 0, stolen = 0, small = false, minion = false, drop = false, shield = false, summons = 0,
                ac = 0, dot = nil, slowT = 0, revealed = false, alarmed = false, cd = rnd(0, 3) }
    local muts = {}
    local n = mutCount(f) + (extraMuts or 0)
    if kind == "boss" then n = min(4, n + 1 + floor(f / 30))
    elseif kind == "champ" then n = min(4, n + 1) end
    if kind ~= "mimic" and not T.heart then
        local zm = (L and L.mut) or Z.mut
        if tr(zm) and f >= 3 and random() < 0.35 then addMut(m, zm, muts) end
        local pool, pn = {}, min(len(MUTS), 3 + floor(f / 5))
        for j = 0, pn - 1 do pool[j] = MUTS[j] end
        local j = 0
        while j < 30 and #muts < n do addMut(m, pick(pool).id, muts); j = j + 1 end
    end
    if has(m, "armored") then m.def = m.def + 1 + floor(f / 10) end
    if has(m, "huge") then m.hp = round(m.hp * 1.6) end
    if has(m, "shield") then m.shield = true end
    local adjs = {}
    for j = 1, min(#muts, 3) do push(adjs, mutAdj(muts[j])) end
    local isThe = vn:sub(1, 4) == "The "
    local full = isThe and vn or ((#adjs > 0 and join(adjs, " ") .. " " or "") .. vn)
    local gm, xm = T.gold2 and 2 or 1, 1
    if kind == "boss" then
        m.name = (isThe or T.heart) and (vn .. (#adjs > 0 and " (" .. join(adjs, ", ") .. ")" or "")) or (bossName() .. " the " .. full)
        local hm, am = T.elite and 1.3 or 2.5, T.elite and 1.1 or 1.3
        if T.heart then hm = 2 end
        m.hp = round(m.hp * hm); m.atk = round(m.atk * am); m.def = m.def + 1
        m.drop = true; gm = gm * 5; xm = 3
    elseif kind == "champ" then
        m.name = "Champion " .. full
        m.hp = round(m.hp * 1.7); m.atk = round(m.atk * 1.2)
        m.drop = true; gm = gm * 3; xm = 2
    elseif kind == "mimic" then
        m.hp = round(m.hp * 1.3); m.awake = true; m.revealed = true
        m.drop = true; gm = gm * 3; xm = 2
    else m.name = full end
    local mm = 1 + 0.25 * #muts
    m.max = m.hp
    m.gold = ceil((2 + T.tier / 3) * (1 + 0.1 * (f - 1)) * mm) * gm
    m.xp = ceil(T.hp * k / 2 * mm) * xm
    if tr(T.spawn) then m.spawn = T.spawn == "random" and "random" or typeIndex(T.spawn) end
    return m
end
function makeMimic(f)
    local t = pickType(f)
    local m = makeMon(f, "mimic", typeIndex("Mimic"))
    local b = makeMon(f, "", t)
    m.hp = round(b.hp * 1.3); m.max = m.hp; m.atk = b.atk; m.def = b.def
    return m
end
function makeMinion(f, spawn)
    local ti = (spawn == "random" or spawn == nil) and pickType(max(1, floor(f / 2))) or spawn
    local m = makeMon(f, "", ti)
    m.minion = true; m.awake = true; m.revealed = true
    m.gold = 0; m.xp = 1
    return m
end
function monAtk(m)
    local r = S.run
    local a = m.atk
    if has(m, "rage") and m.hp < m.max / 2 then a = a * 1.5 end
    local pack, lead = false, false
    for i = 1, #r.mons do
        local o = r.mons[i]
        if o ~= m then
            local d = cheb(o.x, o.y, m.x, m.y)
            if has(m, "pack") and o.i == m.i and d <= 2 then pack = true end
            if has(o, "leader") and d <= 3 then lead = true end
        end
    end
    if pack then a = a * 1.25 end
    if lead then a = a * 1.25 end
    return round(a)
end
function monDesc(m)
    local parts = {}
    if m.kind == "mimic" then push(parts, "a treasure chest with teeth") end
    if m.small then push(parts, "small and weak") end
    if m.minion then push(parts, "summoned helper") end
    for i = 1, #m.abs do
        local a = m.abs[i]
        if a == "shield" and not m.shield then push(parts, "its shield is broken")
        elseif a == "summon" then
            push(parts, "calls " .. ((m.spawn == "random" or m.spawn == nil) and "monsters" or plural(TYPES[m.spawn].n)) .. " to help")
        elseif AB[a] then push(parts, AB[a]) end
    end
    if m.dot then push(parts, m.dot.w) end
    if m.slowT > 0 then push(parts, "slowed") end
    if m.drop then push(parts, "carries treasure") end
    return #parts > 0 and cap(join(parts, ", ")) .. "." or ""
end
-- Hidden monsters: burrowers underground, disguised ones pretending to be gold.
function petSight()
    local s = 0
    for k = 1, #S.team do
        local e, P = PETS[S.team[k]][3], petPower(S.team[k])
        if e == "sight" then s = s + (P >= 4 and 2 or 1)
        elseif (e == "reveal" and P < 3) or (e == "seehidden" and P >= 3) then s = s + 1 end
    end
    return min(2, s)
end
function petHas(e)
    for k = 1, #S.team do if PETS[S.team[k]][3] == e then return true end end
    return false
end
function hiddenMon(m)
    if m.revealed or petHas("seehidden") or tr(cv("seehidden")) then return false end
    local r = S.run
    local d = cheb(m.x, m.y, r.px, r.py)
    if d <= 1 then
        m.revealed = true
        if has(m, "burrow") or has(m, "disguise") then stat("c_Surprise!") end
        return false
    end
    return has(m, "burrow") or has(m, "disguise")
end

-- ================= MAP LAYOUTS =================
-- Maps are numbered from 0 like the original: map[y][x].
function blankMap(v)
    local m = {}
    for y = 0, H - 1 do
        m[y] = {}
        for x = 0, W - 1 do m[y][x] = v end
    end
    return m
end
local DIR4 = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
function largestRegion(map)
    local seen, best = {}, {}
    for y = 0, H - 1 do
        for x = 0, W - 1 do
            if map[y][x] ~= 1 and not seen[x .. "," .. y] then
                local reg, q = {}, { { x, y } }
                seen[x .. "," .. y] = 1
                while #q > 0 do
                    local c = table.remove(q)
                    push(reg, c)
                    for d = 1, 4 do
                        local nx, ny = c[1] + DIR4[d][1], c[2] + DIR4[d][2]
                        local k = nx .. "," .. ny
                        if not (nx < 0 or ny < 0 or nx >= W or ny >= H or map[ny][nx] == 1 or seen[k]) then
                            seen[k] = 1; push(q, { nx, ny })
                        end
                    end
                end
                if #reg > #best then best = reg end
            end
        end
    end
    return best
end
function keepRegion(map, reg)
    local keep = {}
    for i = 1, #reg do keep[reg[i][1] .. "," .. reg[i][2]] = 1 end
    for y = 0, H - 1 do for x = 0, W - 1 do if not keep[x .. "," .. y] then map[y][x] = 1 end end end
end
function layoutRooms()
    local map, rooms, tries = blankMap(1), {}, 0
    while #rooms < 7 and tries < 300 do
        tries = tries + 1
        local w = rnd(3, 5)
        local h = rnd(3, 5)
        local rx = rnd(1, W - w - 1)
        local ry = rnd(1, H - h - 1)
        local ok = true
        for i = 1, #rooms do
            local o = rooms[i]
            if rx <= o.x + o.w and o.x <= rx + w and ry <= o.y + o.h and o.y <= ry + h then ok = false; break end
        end
        if ok then
            for y = ry, ry + h - 1 do for x = rx, rx + w - 1 do map[y][x] = 0 end end
            push(rooms, { x = rx, y = ry, w = w, h = h, cx = rx + floor(w / 2), cy = ry + floor(h / 2) })
        end
    end
    if #rooms < 4 then return nil end
    for i = 2, #rooms do
        local a, b = rooms[i - 1], rooms[i]
        local cx, cy = a.cx, a.cy
        if random() < 0.5 then
            while cx ~= b.cx do map[cy][cx] = 0; cx = cx + sign(b.cx - cx) end
            while cy ~= b.cy do map[cy][cx] = 0; cy = cy + sign(b.cy - cy) end
        else
            while cy ~= b.cy do map[cy][cx] = 0; cy = cy + sign(b.cy - cy) end
            while cx ~= b.cx do map[cy][cx] = 0; cx = cx + sign(b.cx - cx) end
        end
    end
    return { map = map, x = rooms[1].cx, y = rooms[1].cy }
end
function layoutCaves()
    local map = blankMap(1)
    for y = 1, H - 2 do for x = 1, W - 2 do map[y][x] = random() < 0.42 and 1 or 0 end end
    for _ = 1, 4 do
        local nm = blankMap(1)
        for y = 1, H - 2 do
            for x = 1, W - 2 do
                local c = 0
                for dy = -1, 1 do for dx = -1, 1 do c = c + map[y + dy][x + dx] end end
                nm[y][x] = c >= 5 and 1 or 0
            end
        end
        map = nm
    end
    local reg = largestRegion(map)
    if #reg < 70 then return nil end
    keepRegion(map, reg)
    local s = pick(reg)
    return { map = map, x = s[1], y = s[2] }
end
function layoutMaze()
    local map, stack, seen = blankMap(1), { { 1, 1 } }, { ["1,1"] = 1 }
    local D = { { 2, 0 }, { -2, 0 }, { 0, 2 }, { 0, -2 } }
    map[1][1] = 0
    while #stack > 0 do
        local c, opts = stack[#stack], {}
        for d = 1, 4 do
            local nx, ny = c[1] + D[d][1], c[2] + D[d][2]
            if nx >= 1 and nx <= W - 2 and ny >= 1 and ny <= H - 2 and not seen[nx .. "," .. ny] then push(opts, { nx, ny }) end
        end
        if #opts == 0 then table.remove(stack)
        else
            local n = pick(opts)
            map[(c[2] + n[2]) / 2][(c[1] + n[1]) / 2] = 0
            map[n[2]][n[1]] = 0
            seen[n[1] .. "," .. n[2]] = 1
            push(stack, n)
        end
    end
    for _ = 1, 14 do   -- open a few walls so there are loops
        local x = rnd(1, W - 2)
        local y = rnd(1, H - 2)
        if map[y][x] == 1 and ((map[y][x - 1] == 0 and map[y][x + 1] == 0) or (map[y - 1][x] == 0 and map[y + 1][x] == 0)) then map[y][x] = 0 end
    end
    for _ = 1, 2 do   -- two small chambers
        local rx = rnd(1, W - 4)
        local ry = rnd(1, H - 4)
        for y = ry, ry + 2 do for x = rx, rx + 2 do map[y][x] = 0 end end
    end
    return { map = map, x = 1, y = 1 }
end
function layoutPillars()
    local map = blankMap(1)
    for y = 1, H - 2 do for x = 1, W - 2 do map[y][x] = 0 end end
    for y = 2, H - 3, 2 do for x = 2, W - 3, 2 do if random() < 0.55 then map[y][x] = 1 end end end
    for _ = 1, 5 do
        local ln = rnd(2, 4)
        local hz = random() < 0.5
        local sx = rnd(2, W - 3)
        local sy = rnd(2, H - 3)
        for k = 0, ln - 1 do
            local xx, yy = sx + (hz and k or 0), sy + (hz and 0 or k)
            if xx < W - 1 and yy < H - 1 then map[yy][xx] = 1 end
        end
    end
    local reg = largestRegion(map)
    if #reg < 70 then return nil end
    keepRegion(map, reg)
    local best = reg[1]
    for i = 2, #reg do if reg[i][1] + reg[i][2] < best[1] + best[2] then best = reg[i] end end
    return { map = map, x = best[1], y = best[2] }
end
-- Mirror Hall: the right half is a reflection of the left half.
function mirrorLayout(L)
    local map = L.map
    for y = 0, H - 1 do for x = ceil(W / 2), W - 1 do map[y][x] = map[y][W - 1 - x] end end
    local mid = floor(H / 2)
    for x = 1, W - 2 do map[mid][x] = 0 end
    local reg = largestRegion(map)
    if #reg < 60 then return nil end
    keepRegion(map, reg)
    if map[L.y][L.x] == 1 then L.x = reg[1][1]; L.y = reg[1][2] end
    return L
end
-- Distance from a square to every square you can walk to without stepping on anything harmful.
function bfsDist(map, sx, sy)
    local dist, q, head = {}, { { sx, sy } }, 1
    dist[sx .. "," .. sy] = 0
    while head <= #q do
        local c = q[head]; head = head + 1
        local cd = dist[c[1] .. "," .. c[2]]
        for d = 1, 4 do
            local nx, ny = c[1] + DIR4[d][1], c[2] + DIR4[d][2]
            local k = nx .. "," .. ny
            if not (nx < 0 or ny < 0 or nx >= W or ny >= H or dist[k] ~= nil) then
                local t = map[ny][nx]
                if t ~= 1 and not harmful(t) then dist[k] = cd + 1; push(q, { nx, ny }) end
            end
        end
    end
    return dist
end
-- Every safe square can still be reached without stepping on lava, spikes, gas or shock floor.
function allConnected(map, sx, sy)
    local dist, total, got = bfsDist(map, sx, sy), 0, 0
    for y = 0, H - 1 do
        for x = 0, W - 1 do
            local t = map[y][x]
            if t ~= 1 and not harmful(t) then
                total = total + 1
                if dist[x .. "," .. y] ~= nil then got = got + 1 end
            end
        end
    end
    return total == got
end
function placeTiles(map, code, n, r)
    local placed, t = 0, 0
    while t < 160 and placed < n do
        t = t + 1
        local x = rnd(1, W - 2)
        local y = rnd(1, H - 2)
        local skip = map[y][x] ~= 0 or abs(x - r.ex) + abs(y - r.ey) < 3 or (x == r.sx and y == r.sy)
        -- ice only goes in straight corridors, so sliding can never skip past a turn
        if not skip and code == 6 and not ((map[y][x - 1] == 1 and map[y][x + 1] == 1) or (map[y - 1][x] == 1 and map[y + 1][x] == 1)) then skip = true end
        if not skip then
            map[y][x] = code
            if harmful(code) and not allConnected(map, r.ex, r.ey) then map[y][x] = 0
            else placed = placed + 1 end
        end
    end
end

-- A potion or a random scroll: what chests, treasure carriers and loot floors give
-- (weapons and armor only come from the camp shops).
function supplyItem()
    if random() < 0.5 then return { k = "potion" } end
    return { k = "scroll", s = pick(SCROLLS).id }
end
function supplyName(it)
    if it.k == "potion" then return "a potion" end
    return "a " .. scrollInfo(it.s).n .. " scroll"
end
function shopStock(f)
    local a = { k = "potion", price = 10 + 2 * f }
    local b = { k = "scroll", s = pick(SCROLLS).id, price = 12 + 2 * f }
    local s2 = pick(SCROLLS).id
    while s2 == b.s do s2 = pick(SCROLLS).id end
    local c = { k = "scroll", s = s2, price = 12 + 2 * f }
    return { a, b, c }
end

-- ================= DUNGEON GENERATION =================
function genFloor()
    local r = S.run
    local f, Z = r.floor, zoneOf(S.run.floor)
    r.ftId = (f - 1) % FT_N + 1
    r.level = pickLevel(f)
    local LV = curLevel() or {}
    local lay, L, tries = LV.lay or Z.lay, nil, 0
    while not L and tries < 40 do
        tries = tries + 1
        if lay == "caves" then L = layoutCaves()
        elseif lay == "maze" then L = layoutMaze()
        elseif lay == "pillars" then L = layoutPillars()
        else L = layoutRooms() end
        if L and LV.mirror then L = mirrorLayout(L) end
    end
    while not L do L = layoutRooms() end
    local map = L.map
    r.map = map; r.mons = {}; r.items = {}; r.blasts = {}; r.portals = {}
    r.seen = blankMap(0)
    r.px = L.x; r.py = L.y
    r.ex = L.x; r.ey = L.y    -- elevator: where you arrive on every floor

    -- stairs go on the square farthest from the start
    local dist, far, cells = bfsDist(map, r.ex, r.ey), -1, {}
    for y = 0, H - 1 do
        for x = 0, W - 1 do
            local d = dist[x .. "," .. y]
            if d ~= nil then
                push(cells, { x, y })
                if d > far or (d == far and random() < 0.3) then far = d; r.sx = x; r.sy = y end
            end
        end
    end
    r.sd = far

    -- floor tiles: the level type's tiles, otherwise the zone's
    if LV.tile then placeTiles(map, TILE_CODE[LV.tile], LV.tiles or 6, r)
    elseif tr(Z.hz) and Z.hz ~= "dark" then placeTiles(map, TILE_CODE[Z.hz], Z.hz == "mushroom" and rnd(2, 3) or rnd(5, 9), r) end
    if LV.tile2 then placeTiles(map, TILE_CODE[LV.tile2], LV.tiles2 or 3, r) end
    if LV.spikes then placeTiles(map, 3, LV.spikes, r) end
    if LV.mush then placeTiles(map, 4, LV.mush, r) end
    local st = LV.tile or Z.hz
    r.slowName = st == "web" and "web" or (st == "mud" and "mud" or (st == "sand" and "sand" or "water"))
    r.rocks = LV.rocks and true or false

    local function freeSpot(nearStairs)
        local opts = {}
        for c = 1, #cells do
            local cx, cy = cells[c][1], cells[c][2]
            if not (map[cy][cx] ~= 0 or (cx == r.sx and cy == r.sy) or abs(cx - r.ex) + abs(cy - r.ey) < 4
                    or (nearStairs and abs(cx - r.sx) + abs(cy - r.sy) > 3) or monAt(cx, cy) or itemAt(cx, cy) >= 0) then
                push(opts, cells[c])
            end
        end
        if #opts == 0 and nearStairs then return freeSpot(false) end
        if #opts == 0 then return nil end
        local p = pick(opts)
        return { x = p[1], y = p[2] }
    end
    local function addMon(m, near)
        local p = freeSpot(near)
        if p then m.x = p.x; m.y = p.y; push(r.mons, m) end
        return p
    end
    local function addItem(it)
        local p = freeSpot(false)
        if p then it.x = p.x; it.y = p.y; push(r.items, it) end
        return p
    end

    -- portals come in a linked pair
    if LV.portals then
        local p1, p2 = freeSpot(false), nil
        if p1 then map[p1.y][p1.x] = 9; p2 = freeSpot(false) end
        if p1 and p2 then map[p2.y][p2.x] = 9; r.portals = { { p1.x, p1.y }, { p2.x, p2.y } }
        elseif p1 then map[p1.y][p1.x] = 0 end
    end

    -- monsters
    local n = round(min(12, 3 + floor(f / 2)) * (LV.dens or 1))
    n = min(18, max(1, n))
    for _ = 1, n do
        local kind = (f >= 4 and random() < 0.06) and "champ" or ""
        addMon(makeMon(f, kind, nil, LV.plusMut or 0))
    end
    for _ = 1, (LV.champ or 0) do addMon(makeMon(f, "champ", nil, LV.plusMut or 0), true) end
    if LV.heart then
        local heart = makeMon(f, "boss", typeIndex("Dungeon Heart"))
        heart.summonMax = 6
        addMon(heart, true)
    elseif LV.boss then addMon(makeMon(f, "boss", nil, LV.plusMut or 0), true) end
    if LV.awake then for i = 1, #r.mons do r.mons[i].awake = true end end

    -- treasure
    local gm = LV.gold or 1
    local piles = round(rnd(2, 4) * (gm > 1 and 1.5 or 1))
    for _ = 1, piles do addItem({ k = "gold", v = round((rnd(2, 5) + f) * gm) }) end
    local pots = (random() < 0.5 and 1 or 0) + (f % 3 == 0 and 1 or 0) + (LV.pots or 0)
    for _ = 1, pots do addItem({ k = "potion" }) end
    local scr = (LV.scr or 0) + (random() < 0.4 and 1 or 0)
    for _ = 1, scr do addItem({ k = "scroll", s = pick(SCROLLS).id }) end
    local chests = (random() < 0.35 and 1 or 0) + (LV.chest or 0)
    r.mimicP = LV.mimic and LV.mimic * 100 or 15
    for _ = 1, chests do addItem({ k = "chest", mimic = f >= 3 and chance(r.mimicP) }) end
    if random() < 0.22 + ((LV.n == "Nest" or LV.n == "Monster Breeding Grounds") and 0.5 or 0) then addItem({ k = "pet", p = rollPet(f) }) end
    -- floors that used to have gear lying around get potions and scrolls instead
    for _ = 1, (LV.gear or 0) + (LV.cursed and 1 or 0) + (LV.secret and 2 or 0) do addItem(supplyItem()) end
    for _ = 1, (LV.relic or 0) do addItem({ k = "relic" }) end
    if LV.altar then addItem({ k = "altar" }) end
    if LV.shop or (f >= 3 and random() < 0.1) then addItem({ k = "shop", stock = shopStock(f) }) end
    if LV.shrine or (f >= 2 and random() < 0.1) then addItem({ k = "shrine" }) end
    -- a Chest Guardian sometimes waits beside a chest
    if f >= TYPES[typeIndex("Chest Guardian")].tier then
        for i = 1, #r.items do
            if r.items[i].k == "chest" and random() < 0.3 then
                local cg = makeMon(f, "", typeIndex("Chest Guardian"))
                if placeNear(r.items[i].x, r.items[i].y, cg, nil) then push(r.mons, cg) end
            end
        end
    end
    r.chestRar = LV.rar or 0

    r.ft = 0; r.fd = 0
    r.petShield = petHas("shieldfloor"); r.petTele = false
    r.clsShield = cv("shieldfloor"); r.clsTele = false; r.clsLow = false; r.clsRevF = false; r.ks = 0
    r.bounty = makeBounty()
    charFloorStart()
    reveal()
    local petMap = false
    for i = 1, #S.team do if PETS[S.team[i]][3] == "reveal" and petPower(S.team[i]) >= 3 then petMap = true end end
    if LV.reveal or petMap then for y = 0, H - 1 do for x = 0, W - 1 do r.seen[y][x] = 1 end end end
end

-- ================= BOUNTIES: a small goal on every floor =================
function makeBounty()
    local r = S.run
    local f, opts, counts, real, big = r.floor, {}, {}, 0, ""
    for i = 1, #r.mons do
        local m = r.mons[i]
        real = real + 1
        if m.kind == "boss" then big = "boss"
        elseif m.kind == "champ" and big == "" then big = "champion" end
        if m.kind == "" then counts[m.i] = (counts[m.i] or 0) + 1 end
    end
    if real >= 3 then push(opts, { t = "kills", need = min(real, rnd(3, 5)) }) end
    local keys = {}
    for k in pairs(counts) do push(keys, k) end
    table.sort(keys)   -- JavaScript goes through number keys in order
    for _, k in ipairs(keys) do if counts[k] >= 2 then push(opts, { t = "type", ti = k, need = 2 }) end end
    for i = 1, #r.items do if r.items[i].k == "chest" then push(opts, { t = "chest", need = 1 }); break end end
    if big ~= "" then push(opts, { t = "big", what = big, need = 1 }); push(opts, { t = "big", what = big, need = 1 }) end
    push(opts, { t = "speed", need = r.sd * 2 + 10 })
    push(opts, { t = "safe", need = ceil(r.maxHp * 0.4) })
    local b = pick(opts)
    b.have = 0; b.state = "on"
    b.gold = 10 + 3 * f + ((b.t == "big" or b.t == "type") and 5 + f or 0)
    b.bonus = random() < 0.3 and pick(SCROLLS).id or ""
    return b
end
function bountyText()
    local r = S.run
    local b = r.bounty
    if not b then return "" end
    local t
    if b.t == "kills" then t = "Defeat " .. b.need .. " monsters (" .. b.have .. "/" .. b.need .. ")"
    elseif b.t == "type" then t = "Defeat 2 " .. plural(TYPES[b.ti].n) .. " (" .. b.have .. "/2)"
    elseif b.t == "chest" then t = "Open a treasure chest (*)"
    elseif b.t == "big" then t = "Defeat the " .. b.what
    elseif b.t == "speed" then t = "Reach the stairs within " .. b.need .. " turns (" .. r.ft .. " so far)"
    else t = "Reach the stairs losing less than " .. b.need .. " HP (" .. r.fd .. " lost)" end
    local reward = " for " .. goldAmt(b.gold) .. " gold" .. (b.bonus ~= "" and " and a " .. scrollInfo(b.bonus).n .. " scroll" or "")
    if b.state == "done" then return "Done! " .. t .. "." end
    if b.state == "failed" then return "Failed. " .. t .. "." end
    return t .. reward .. "."
end
function bountyEvent(kind, m)
    local r = S.run
    local b = r.bounty
    if not b or b.state ~= "on" then return end
    if kind == "kill" then
        if m.minion then return end
        if b.t == "kills" then b.have = b.have + 1
        elseif b.t == "type" and m.i == b.ti and m.kind == "" and not m.small then b.have = b.have + 1
        elseif b.t == "big" and (m.kind == "boss" or m.kind == "champ") then b.have = b.have + 1 end
    elseif kind == "chest" and b.t == "chest" then b.have = b.have + 1
    elseif kind == "stairs" and (b.t == "speed" or b.t == "safe") then b.have = b.need end
    if b.have >= b.need then payBounty() end
end
local BOUNTY_ACH = { kills = "Monster Bounty", type = "Hunting Bounty", chest = "Chest Bounty", big = "Big Game Bounty",
                     speed = "Speed Bounty", safe = "Careful Bounty" }
function payBounty()
    local r = S.run
    local b = r.bounty
    local g = goldAmt(b.gold)
    b.state = "done"
    r.goldRun = r.goldRun + g
    stat("bounties")
    stat("b_" .. BOUNTY_ACH[b.t])
    if tr(r.level) then statA("lb_" .. lbase()) end
    r.bst = (r.bst or 0) + 1; statMax("bstreak", r.bst)
    if b.bonus ~= "" then r.scrolls[b.bonus] = r.scrolls[b.bonus] + 1 end
    say("Bounty complete! +" .. g .. " gold" .. (b.bonus ~= "" and " and a " .. scrollInfo(b.bonus).n .. " scroll" or "") .. ".")
end

-- ================= DISCOVERIES =================
function discover()
    local r, ms = S.run, seenMonsters()
    for i = 1, #ms do
        local m = ms[i]
        if not m.minion then
            local ei = eOf(m)
            if not mSeen(ei) then mMark(ei); say("New monster: " .. eName(ei) .. " (" .. TYPES[m.i].c .. ")!") end
            for j = 1, #m.abs do
                local a = m.abs[j]
                if not S.seen["a" .. a] then S.seen["a" .. a] = 1; say("New trait: " .. J(mutAdj(a), cap(a)) .. ". It " .. AB[a] .. ".") end
            end
        end
    end
    S.seen["z" .. zoneOf(r.floor).n] = 1
    if tr(r.level) then S.seen["l" .. lbase()] = 1; ftMark(r.floor) end
end
function countSeen(prefix)
    local n = 0
    for k in pairs(S.seen) do if k:sub(1, 1) == prefix then n = n + 1 end end
    return n
end
function reveal()
    local r, v, n = S.run, view(), 0
    for y = max(0, r.py - v), min(H - 1, r.py + v) do
        for x = max(0, r.px - v), min(W - 1, r.px + v) do
            if r.seen[y][x] == 0 then r.seen[y][x] = 1; n = n + 1 end
        end
    end
    if n > 0 then stat("a_Map Filler", n) end
end
function visible(x, y)
    local v = view()
    return abs(x - S.run.px) <= v and abs(y - S.run.py) <= v
end
-- Messages when you arrive on a floor: new zone, floor type, boss name.
function floorIntro(firstLine, showZone)
    local r = S.run
    local Z, LV = zoneOf(r.floor), curLevel()
    r.log = { firstLine }
    if showZone or r.floor == 1 or zoneOf(r.floor - 1).n ~= Z.n then say("Zone: " .. Z.n .. "." .. ((LV and LV.tile) and "" or " " .. Z.note)) end
    if LV then say(LV.n .. ": " .. LV.note) end
    for i = 1, #r.mons do if r.mons[i].kind == "boss" then say(r.mons[i].name .. " waits near the stairs!") end end
end

-- ================= RUNS =================
function headStart(f) return max(0, round(0.24 * f ^ 1.5) - 1) end   -- free levels when starting deep
function startRun()
    local u = S.up
    local f = max(1, min(ui.startAt, J(S.best, 1)))
    local extra, sm = headStart(f), starMul()
    S.run = { floor = f - 1, maxHp = round((20 + 5 * u.hp + 4 * extra) * sm * petHpMul()), hp = 0,
              atk = 3 + u.atk + extra, def = u.def,
              lv = 1 + extra, xp = 0, potions = 1 + u.pot, scrolls = { fire = 0, freeze = 0, tele = 0, map = 0 },
              goldRun = 0, kills = 0, log = {}, pf = {}, queue = {}, poison = 0, weak = 0, slow = 0, hits = 0, turns = 0, panel = nil,
              level = "", wpn = nil, arm = nil, ft = 0, fd = 0, lastHurt = "", bounty = nil, blasts = {}, portals = {}, petCd = {}, revived = false }
    charRunStart()
    local r = S.run
    r.cb = (S.last and tr(S.last.floor) and S.best > 4 and S.last.floor < S.best / 2) and true or false   -- a short run last time
    stat("a_Adventurer"); if f >= 10 then stat("a_Deep Start") end
    for _ = 1, u.scr do local s = pick(SCROLLS).id; r.scrolls[s] = r.scrolls[s] + 1 end
    local saved, free = 0, 0
    for i = 1, u.perk do
        if S.perkAt["B" .. i] then applyPerk(S.perkAt["B" .. i]); saved = saved + 1; stat("blessed")
        else push(r.queue, "B" .. i) end
    end
    if f > 1 then
        equip(S.cwEq >= 0 and campWpn(S.cwEq) or makeGear(f - 1, "wpn"))
        equip(S.caEq >= 0 and campArm(S.caEq) or makeGear(f - 1, "arm"))
        -- levels you skip with the elevator: use your saved perk for that level, or a random one
        for i = 2, r.lv, 2 do
            if S.perkAt["L" .. i] then applyPerk(S.perkAt["L" .. i]); saved = saved + 1
            else applyPerk(randomPerk()); free = free + 1 end
        end
    elseif S.cwEq >= 0 then equip(campWpn(S.cwEq))
    else equip({ slot = "wpn", cat = 0, base = "Ironfang", mod = "dull", atk = 1, def = 0, fxs = {}, rar = 0, mv = 2, name = "Dull Ironfang" }) end
    if f <= 1 and S.caEq >= 0 then equip(campArm(S.caEq)) end
    r.hp = r.maxHp
    statMax("lvl", r.lv)
    S.runs = S.runs + 1
    ui.partyNote = nil
    S.last = nil
    ui.elev = false; ui.bag = false
    nextFloor(true)
    floorIntro(f == 1 and "You enter the dungeon. Find the stairs (>) to go deeper."
               or "The elevator drops you on floor " .. f .. ". You start at level " .. r.lv .. " with gear.", true)
    if saved > 0 or free > 0 then
        say("Perks: " .. saved .. " saved" .. (free > 0 and ", " .. free .. " random for levels you haven't picked yet" or "") .. ".")
    end
    discover()
    checkPanels(); save(); render()
    M.newFloor = true
end
function nextFloor(quiet)
    local r = S.run
    ui.elev = false; ui.bag = false
    r.floor = r.floor + 1
    if r.floor > S.best and r.cb then r.cb = false; stat("a_Comeback Kid") end
    if r.floor > S.best then S.best = r.floor end
    statMax("a_Deep Diver Plus", r.floor)
    if (r.floor - 1) % 10 == 0 then r.zStart = r.floor end   -- the first floor of a zone
    statMax("cd_" .. curClass()[2], r.floor)
    if r.floor > (S.stats.deep or 0) then S.stats.deep = r.floor end
    if not quiet then stat("floors") end
    if r.floor > 1 then heal(ceil(r.maxHp / 10 + r.maxHp * 0.08 * petSum("floorheal"))) end
    genFloor()
    floorIntro("You reach floor " .. r.floor .. ".")
    M.newFloor = true
end
function blocked()
    local r = S.run
    return not r or r.panel ~= nil or ui.elev or ui.bag or ui.swap or tr(ui.book)
end
function descend()
    local r = S.run
    if not r or r.panel or r.px ~= r.sx or r.py ~= r.sy then return end
    floorDone()
    nextFloor(); discover(); checkPanels(); save(); render()
end
-- Achievement counts for finishing a floor by taking the stairs.
function floorDone()
    local r = S.run
    local zn, L = ZONES[floor((r.floor - 1) / 10) % len(ZONES)].n, curLevel()
    stat("a_Stair Climber"); statA("zc_" .. zn)
    if tr(r.level) then statA("lc_" .. lbase()) end
    if r.fd == 0 then stat("c_Untouchable"); statA("zu_" .. zn) end
    if r.floor % 10 == 0 and r.zStart == r.floor - 9 then stat("zx_clear") end
    local zh = zoneOf(r.floor).hz
    if zh == "lava" then stat("zx_lava") elseif zh == "ice" then stat("zx_ice") elseif zh == "dark" then stat("zx_dark")
    elseif zh == "water" or zh == "mud" or zh == "sand" or zh == "web" then stat("zx_wet")
    elseif zh == "shock" or zh == "gas" then stat("zx_shock") end
    if r.hp >= r.maxHp then stat("a_Full Health Finish") end
    if r.ft < 20 then stat("a_Speedrunner") end
    if not tr(r.ks) then stat("a_Peaceful Path") end
    if (L and L.dark) or zoneOf(r.floor).hz == "dark" then stat("d_Darkness Delver") end
    if not r.bounty or r.bounty.state ~= "done" then r.bst = 0 end
    r.nps = (r.nps or 0) + 1; statMax("a_Potion Saver", r.nps)
    for k = 1, #S.team do statA("pf_" .. S.team[k]) end
    if #S.team >= TEAM_MAX then stat("fullteam") end
end
function endRun(killer)
    local r = S.run
    S.gold = S.gold + r.goldRun
    stat("gold", r.goldRun)
    statMax("a_Rich Run", r.goldRun)
    S.last = { floor = r.floor, gold = r.goldRun, killer = killer, kills = r.kills, lv = r.lv, arts = r.newArts }
    S.run = nil
    S.last.ach = claimAch()
    ui.elev = false; ui.bag = false
    save(); render()
    M.newFloor = true
end
function giveUp()
    if S.run then ask("End this run? You keep the gold you found.", function() if S.run then endRun("") end end) end
end
function upMax(id)
    for i = 0, len(UPS) - 1 do if UPS[i].id == id then return UPS[i].max or 0 end end
    return 0
end
function upName(id) for i = 0, len(UPS) - 1 do if UPS[i].id == id then return UPS[i].name end end return "" end
function maxed(id) return upMax(id) > 0 and S.up[id] >= upMax(id) end
function buy(id)
    local c = upCost(id)
    if S.gold < c or maxed(id) then return end
    S.gold = S.gold - c; S.up[id] = S.up[id] + 1
    stat("up_" .. upName(id)); stat("a_Upgrade Fan"); stat("a_Big Spender", c)
    campClaim()
    save(); render()
end

-- ================= ACHIEVEMENTS: every one has endless tiers =================
function achNeed(a, t)
    if a.lin then return a.lin * (t + 1) end
    local f3 = ({ [0] = 1, 2, 5 })[t % 3]
    return a.base * f3 * 10 ^ floor(t / 3)
end
function achReward(t) return round(25 * 1.5 ^ t) end
function claimAch()
    local out = {}
    statMax("a_Camp Bank", S.gold)
    for i = 0, len(ACH) - 1 do
        local a = ACH[i]
        local t = S.ach[a.id] or 0
        while (S.stats[a.id] or 0) >= achNeed(a, t) do
            local g = achReward(t)
            S.gold = S.gold + g; t = t + 1
            push(out, a.n .. " " .. roman(t) .. " (+" .. fmt(g) .. " gold)")
        end
        S.ach[a.id] = t
    end
    for _ = 0, 1 do
        for i = 0, len(ACH2) - 1 do
            local A = ACH2[i]
            local v = achVal(A)
            local t = S.ach[A[4]] or 0
            while v >= achNeed2(A, t) do
                local g = achReward(t)
                S.gold = S.gold + g; t = t + 1
                push(out, A[1] .. " " .. roman(t) .. " (+" .. fmt(g) .. " gold)")
            end
            if t > 0 then S.ach[A[4]] = t end
        end
    end
    return out
end
-- After level V, every level needs twice as much as the one before.
function achNeed2(A, t) return t < 5 and A[3][t] or A[3][4] * 2 ^ (t - 4) end
function countKeys(o) local n = 0; for _ in pairs(o) do n = n + 1 end; return n end
function achVal(A) return A[5] == "s" and achSpecial(A[4]) or (S.stats[A[4]] or 0) end
function achSpecial(k)
    local n = 0
    if startsWith(k, "wc_") then
        for i = 0, len(WCATS) - 1 do
            if "wc_" .. WCATS[i].n == k then
                for j = 0, len(WNAMES[i]) - 1 do if S.seen["w" .. WNAMES[i][j]] then n = n + 1 end end
            end
        end
        return n
    end
    if startsWith(k, "ct_") then
        local tier = tonumber(k:sub(4))
        for i = 0, len(CLASSES) - 1 do if CLASSES[i][2] == tier and S.clsOwn[i] then n = n + 1 end end
        return n
    end
    if k == "petset" then return countKeys(S.pets) end
    if k == "clsset" then return countKeys(S.clsOwn) end
    if k == "perksaved" then return countKeys(S.perkAt) end
    if k == "a_Star Gazer" then return S.stars or 0 end
    if k == "zx_explore" or k == "zx_travel" then return countSeen("z") end
    if k == "a_Discoverer" then return countKeys(S.seen) + mCount() end
    if k == "a_Achievement Hunter" then for _, v in pairs(S.ach) do n = n + v end; return n end
    return 0
end
function achTotal() local n = 0; for _, v in pairs(S.ach) do n = n + v end; return n end
-- Claim at camp (after buying things) and show what you earned.
function campClaim()
    local got = claimAch()
    if #got > 0 then ui.achNote = achList(got) end
end
function achList(got)
    if #got > 6 then
        return join({ got[1], got[2], got[3], got[4], got[5], got[6] }, ", ") .. " and " .. (#got - 6) .. " more"
    end
    return join(got, ", ")
end

-- ================= ASCENSION =================
-- Stars come from your deepest floor ever: 1 for every 5 floors past 20. Ascending pays the ones you don't have yet.
function starsFor(best) return max(0, floor((best - 20) / 5)) end
function newStars() return max(0, starsFor(max(S.best, S.peak)) - S.stars) end
function ascend()
    local n = newStars()
    if n < 1 then return end
    ask("Ascend? Your gold, upgrades and deepest floor reset to zero. You gain " .. n .. " star" .. (n > 1 and "s" or "") ..
        ". Saved perks, achievements and stars stay forever.", function()
        S.peak = max(S.peak, S.best)
        S.stars = S.stars + n; S.asc = S.asc + 1
        stat("a_Ascender")
        S.gold = 0; S.best = 0; S.run = nil
        for i = 0, len(UPS) - 1 do S.up[UPS[i].id] = 0 end
        ui.startAt = 1
        S.last = { note = "You ascended! You now have " .. S.stars .. " stars: +" .. (S.stars * 10) .. "% attack, HP and gold, forever." }
        campClaim()
        save(); render()
    end)
end

-- ================= ELEVATOR =================
function onElevator()
    local r = S.run
    return r ~= nil and r.px == r.ex and r.py == r.ey
end
function openElevator()
    if not onElevator() or S.run.panel then return end
    ui.bag = false; ui.elev = true; ui.pick = S.run.floor
    render()
end
function pickFloor(n, absolute)
    local p = absolute and n or ui.pick + n
    ui.pick = max(1, min(S.best, p))
    render()
end
function startPick(n, absolute)
    local p = absolute and n or ui.startAt + n
    ui.startAt = max(1, min(J(S.best, 1), p))
    render()
end
function rideElevator()
    local r = S.run
    if not onElevator() then return end
    ui.elev = false
    if ui.pick == r.floor then render(); return end
    stat("a_Elevator Rider")
    r.zStart = nil
    r.floor = ui.pick
    genFloor()
    floorIntro("The elevator takes you to floor " .. r.floor .. ".", true)
    discover()
    save(); render()
    M.newFloor = true
end

-- ================= PANELS: level up, loot, merchant, shrine, altar =================
function checkPanels()
    local r = S.run
    if r and not r.panel and #r.queue > 0 then r.panel = { t = "perk", opts = perkChoices() } end
end
function closePanel()
    local r = S.run
    if not r then return end
    r.panel = nil
    checkPanels(); save(); render()
end
function choosePerk(id)
    local r = S.run
    if not r or not r.panel or r.panel.t ~= "perk" then return end
    applyPerk(id)
    local key = table.remove(r.queue, 1)
    if key then S.perkAt[key] = id end
    if key and key:sub(1, 1) == "B" then stat("blessed") end
    r.log = { "You chose " .. perkInfo(id).n .. ". It's saved: you'll get it again every time you reach " .. slotName(key) .. "." }
    closePanel()
end
function hereItem()
    local i = itemAt(S.run.px, S.run.py)
    return i >= 0 and S.run.items[i] or nil
end
function equipHere()
    local r, it = S.run, hereItem()
    if not it or it.k ~= "gear" then closePanel(); return end
    equip(it.g); gearOn(it.g)
    table.remove(r.items, find1(r.items, it))
    r.log = { "You equip the " .. it.g.name .. "." }
    closePanel()
end
function shopBuy(j)
    local r, it = S.run, hereItem()
    if not it or it.k ~= "shop" then return end
    local s = it.stock[j]
    if not s or s.sold or r.goldRun < s.price then return end
    r.goldRun = r.goldRun - s.price; s.sold = true
    stat("a_Merchant Friend", s.price)
    if s.k == "potion" then r.potions = r.potions + 1; stat("i_Potion Shopper"); r.log = { "You buy a potion." }
    elseif s.k == "scroll" then r.scrolls[s.s] = r.scrolls[s.s] + 1; stat("i_Scroll Shopper"); r.log = { "You buy a " .. scrollInfo(s.s).n .. " scroll." }
    else equip(s.g); gearOn(s.g); stat("i_Gear Shopper"); r.log = { "You buy and equip the " .. s.g.name .. "." } end
    save(); render()
end
function shrineUse(how)
    local r, it = S.run, hereItem()
    if not it or it.k ~= "shrine" then closePanel(); return end
    table.remove(r.items, find1(r.items, it))
    stat(how == "rest" and "i_Shrine Rester" or "i_Shrine Prayer")
    if how == "rest" then
        r.hp = r.maxHp; r.poison = 0; r.weak = 0; r.slow = 0
        r.log = { "You rest at the shrine. Fully healed!" }
    else
        local p = randomPerk()
        applyPerk(p)
        r.hp = max(1, r.hp - ceil(r.maxHp / 4))
        r.log = { "The shrine glows. You gain " .. perkInfo(p).n .. ": " .. perkInfo(p).d .. "." }
    end
    closePanel()
end
function altarUse()
    local r, it = S.run, hereItem()
    if not it or it.k ~= "altar" or not r.wpn then closePanel(); return end
    local pool = {}
    for i = 0, len(MODS) - 1 do
        if MODS[i].id ~= r.wpn.mod and MODS[i].id ~= "dull" and MODS[i].id ~= "rusty" then push(pool, MODS[i]) end
    end
    local old, Md = modInfo(r.wpn.mod), pick(pool)
    r.wpn.atk = max(1, round(r.wpn.atk / (1 + old.pct / 100) * (1 + Md.pct / 100)))
    r.wpn.mod = Md.id
    stat("i_Enchanter")
    r.wpn.name = Md.n .. " " .. r.wpn.base
    noteGear(r.wpn)
    table.remove(r.items, find1(r.items, it))
    r.log = { "The table glows. Your weapon is now the " .. r.wpn.name .. "!" }
    closePanel()
end
function reopenHere()
    local it = hereItem()
    if not it then return false end
    if it.k == "gear" then S.run.panel = { t = "loot" }
    elseif it.k == "shop" then S.run.panel = { t = "shop" }
    elseif it.k == "shrine" then S.run.panel = { t = "shrine" }
    elseif it.k == "altar" then S.run.panel = { t = "altar" }
    elseif it.k == "pet" then S.run.panel = { t = "pet" }
    else return false end
    render()
    return true
end
