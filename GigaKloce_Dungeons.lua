-- ============================
-- GigaKloce :: Dungeons (rekord przebiegow M+: best key per podziemie + % dmg, kanal "D")
-- ============================
-- Po ukonczeniu M+ zapisujemy: best key PER PODZIEMIE (all-time) oraz ostatni przebieg
-- (dungeon, level, czy w czasie, nasz % dmg wzgledem topa). Dane lecą WLASNYM eventem kanalu "D"
-- (siostra H/P/K) — kazdy user self-reportuje swoje statystyki, a WSZYSTKIE 14 podziemi Legiona
-- miesci sie w JEDNEJ wiadomosci dzieki kodowaniu przez STALY indeks podziemia.
local ADDON, GK = ...
local normalizeName, displayName, GetUnitFullName = GK.normalizeName, GK.displayName, GK.GetUnitFullName

-- ============================
-- STALA LISTA PODZIEMI (kolejnosc = indeks na drucie; NIE zmieniac kolejnosci/ nie usuwac!)
-- ============================
GK.MPLUS_DUNGEONS = {
    "Court of Stars", "Eye of Azshara", "Black Rook Hold", "Neltharion's Lair",
    "Maw of Souls", "Darkheart Thicket", "Vault of the Wardens", "The Arcway",
    "Halls of Valor", "Cathedral of Eternal Night", "Lower Karazhan", "Upper Karazhan",
    "Return to Karazhan", "Seat of the Triumvirate",
}
GK.MPLUS_SHORT = {
    "Court of Stars", "Eye of Azshara", "Black Rook Hold", "Neltharion's Lair",
    "Maw of Souls", "Darkheart Thicket", "Vault of Wardens", "The Arcway",
    "Halls of Valor", "Cathedral of EN", "Lower Karazhan", "Upper Karazhan",
    "Return to Kara", "Seat of Triumvirate",
}

-- nazwa (z gry/klucza) -> indeks (substring, case-insensitive). Najpierw dluzsze/specyficzne wpisy.
local lowerList
local function dungeonIndex(name)
    if not name or name == "" then return nil end
    if not lowerList then
        lowerList = {}
        for i, d in ipairs(GK.MPLUS_DUNGEONS) do lowerList[i] = d:lower() end
    end
    local low = name:lower()
    for i, d in ipairs(lowerList) do
        if low:find(d, 1, true) then return i end
    end
    return nil
end

-- ============================
-- IDENTYFIKACJA KLUCZA
-- C_ChallengeMode (retail 7.2+) -> nazwa instancji (Tauri-safe, taka sama dla calej grupy)
-- -> klucz z bagu (tylko u posiadacza). Dzieki temu dziala i na Tauri bez C_ChallengeMode.
-- ============================
local startCtx = nil   -- { dungeon, level } zlapane na CHALLENGE_MODE_START (fallback)

local function activeRunInfo()
    local dungeon, level
    if C_ChallengeMode then
        local mapID = C_ChallengeMode.GetActiveChallengeMapID and C_ChallengeMode.GetActiveChallengeMapID()
        if mapID and C_ChallengeMode.GetMapUIInfo then
            local name = C_ChallengeMode.GetMapUIInfo(mapID)
            if name and name ~= "" then dungeon = name end
        end
        if C_ChallengeMode.GetActiveKeystoneInfo then
            local lvl = C_ChallengeMode.GetActiveKeystoneInfo()
            if lvl and lvl > 0 then level = lvl end
        end
    end
    if not dungeon then
        local iname = GetInstanceInfo()          -- nazwa instancji = nazwa podziemia
        if iname and iname ~= "" then dungeon = iname end
    end
    if not level and GK.GetMyKeystone then
        local _, lvl = GK.GetMyKeystone()         -- dziala tylko u posiadacza klucza
        if lvl then level = lvl end
    end
    return dungeon, level
end

-- Info o UKONCZONYM przebiegu: preferuj GetCompletionInfo, inaczej kontekst ze startu / instancja.
-- Zwraca: dungeon, level, timed, durSec (czas przebiegu w s; nil gdy nieznany).
local function completedRunInfo()
    local dungeon, level, timed, durSec
    if C_ChallengeMode and C_ChallengeMode.GetCompletionInfo then
        local mapID, lvl, runMs, onTime = C_ChallengeMode.GetCompletionInfo()
        if lvl and lvl > 0 then level = lvl end
        if onTime ~= nil then timed = onTime and true or false end
        if runMs and runMs > 0 then durSec = math.floor(runMs / 1000) end
        if mapID and C_ChallengeMode.GetMapUIInfo then
            local name = C_ChallengeMode.GetMapUIInfo(mapID)
            if name and name ~= "" then dungeon = name end
        end
    end
    if not dungeon and startCtx then dungeon = startCtx.dungeon end
    if not level and startCtx then level = startCtx.level end
    if not dungeon then
        local iname = GetInstanceInfo()
        if iname and iname ~= "" then dungeon = iname end
    end
    return dungeon, level, timed, durSec
end

-- Wolane z GK.OnChallengeStart (Meter): zapamietaj aktywny klucz na fallback.
function GK.DungeonsCaptureStart()
    local dungeon, level = activeRunInfo()
    if dungeon then startCtx = { dungeon = dungeon, level = level } end
end

-- ============================
-- ZAPIS PRZEBIEGU (wolane z GK.OnChallengeComplete, Meter)
-- ============================
function GK.RecordCompletedRun()
    local dungeon, level, timed, durSec = completedRunInfo()
    if not dungeon then return end   -- nie udalo sie zidentyfikowac — pomijamy
    level = level or 0
    local idx = dungeonIndex(dungeon)
    local md = GigaKloceDB and GigaKloceDB.myDungeons
    if not md then return end
    md.best = md.best or {}
    md.bestTimed = md.bestTimed or {}
    local when = (GK.now and GK.now()) or time()

    local members, rmeter, mdur
    if GK.MeterMembersNow then members, rmeter, mdur = GK.MeterMembersNow() end
    local dur = durSec or mdur or 0
    members = members or {}

    -- top dmg wsrod DPS-ow (DAMAGER) = baza dla %; meKey do oznaczenia siebie
    local meKey = normalizeName(GetUnitFullName("player"))
    local topDps = 0
    for _, m in ipairs(members) do if m.role == "DAMAGER" and (m.dmg or 0) > topDps then topDps = m.dmg end end

    -- ostatni przebieg + moj % dmg (top DPS = 100%)
    md.lastIdx = idx or 0
    md.lastLvl = level
    md.lastTimed = timed and true or false
    md.lastWhen = when
    md.lastPct = nil
    if topDps > 0 then
        for _, m in ipairs(members) do
            if m.key == meKey and m.role == "DAMAGER" then md.lastPct = math.floor(m.dmg / topDps * 100 + 0.5); break end
        end
    end

    -- best per podziemie (liczy sie KAZDE ukonczenie)
    if idx and level > (md.best[idx] or 0) then
        md.best[idx] = level
        md.bestTimed[idx] = timed and true or false
    end

    -- pelna piatka: dmg+dps ORAZ heal+hps + rola (DPS-y, healerzy, tank). Posortowane do wyswietlenia.
    local players = {}
    for _, m in ipairs(members) do
        players[#players + 1] = {
            name = GK.displayName and GK.displayName(m.name) or m.name,
            class = (GK.ClassOf and GK.ClassOf(m.name)) or nil,
            spec = (GK.SpecOf and GK.SpecOf(m.name)) or nil,
            role = m.role,
            dmg = m.dmg or 0, dps = (dur > 0) and math.floor((m.dmg or 0) / dur + 0.5) or nil,
            heal = m.heal or 0, hps = (dur > 0) and math.floor((m.heal or 0) / dur + 0.5) or nil,
            pct = (topDps > 0 and m.role == "DAMAGER") and math.floor((m.dmg or 0) / topDps * 100 + 0.5) or nil,
            isSelf = (m.key == meKey) or nil,
        }
    end
    -- kolejnosc: DAMAGER wg dmg desc, potem HEALER wg heal desc, potem TANK
    local ROLE_ORDER = { DAMAGER = 1, HEALER = 2, TANK = 3 }
    table.sort(players, function(a, b)
        local ra, rb = ROLE_ORDER[a.role] or 9, ROLE_ORDER[b.role] or 9
        if ra ~= rb then return ra < rb end
        if a.role == "HEALER" or a.role == "TANK" then return (a.heal or 0) > (b.heal or 0) end
        return (a.dmg or 0) > (b.dmg or 0)
    end)

    -- LOKALNA historia: ostatnie 10 runow per podziemie (NIE wysylane nigdzie)
    GK.PushRunHistoryPlayers(idx, level, timed, dur, players)

    if GK.BroadcastDungeons then GK.BroadcastDungeons() end
    if KloceFrame and KloceFrame.mode == "active" and KloceFrame.RefreshList then KloceFrame.RefreshList() end
    if GK.log then GK.log("[Dungeons] " .. dungeon .. " +" .. level
        .. (timed and " (timed)" or "") .. (md.lastPct and (" — " .. md.lastPct .. "% dmg") or "")) end
end

-- ============================
-- KANAL "D" (dungeons) — wszystkie podziemia w jednej wiadomosci:
--   D ~ lvls(po ".") ~ timedMask ~ lastIdx ~ lastLvl ~ lastTimed ~ lastPct
-- lvls: po jednej liczbie na podziemie (0 = brak), kolejnosc = GK.MPLUS_DUNGEONS.
-- timedMask: bit (i-1) = czy best podziemia i byl w czasie.
-- ============================
function GK.BroadcastDungeons()
    if GK.CanBroadcast and not GK.CanBroadcast() then return end   -- blocked = nie wysylam danych
    local md = GigaKloceDB and GigaKloceDB.myDungeons
    if not md then return end
    local N = #GK.MPLUS_DUNGEONS
    local lvls, mask, any = {}, 0, false
    for i = 1, N do
        local lvl = (md.best and md.best[i]) or 0
        lvls[i] = lvl
        if lvl > 0 then any = true end
        if md.bestTimed and md.bestTimed[i] then mask = mask + 2 ^ (i - 1) end
    end
    if not any and not (md.lastIdx and md.lastIdx > 0) then return end
    local s = GK.CHAN_SEP
    GK.SendChan("D" .. s .. table.concat(lvls, ".") .. s .. string.format("%d", mask)
        .. s .. (md.lastIdx or 0) .. s .. (md.lastLvl or 0) .. s .. (md.lastTimed and "1" or "0")
        .. s .. (md.lastPct ~= nil and md.lastPct or ""))
end

-- Odbior (pola juz rozbite przez parser kanalu w Events).
function GK.ReceiveDungeons(sender, lvlsStr, maskStr, lastIdx, lastLvl, lastTimed, lastPct)
    local k = normalizeName(sender)
    if k == "" then return end
    local best, bestTimed = {}, {}
    local mask = tonumber(maskStr) or 0
    local i = 0
    for tok in tostring(lvlsStr or ""):gmatch("[^.]+") do
        i = i + 1
        local lvl = tonumber(tok) or 0
        if lvl > 0 then
            best[i] = lvl
            bestTimed[i] = (math.floor(mask / (2 ^ (i - 1))) % 2) == 1
        end
    end
    local d = {
        best = best, bestTimed = bestTimed,
        lastIdx = tonumber(lastIdx) or 0,
        lastLvl = tonumber(lastLvl) or 0,
        lastTimed = (lastTimed == "1"),
        lastPct = tonumber(lastPct),
    }
    local u = GK.addonUsers[k]
    if u then u.dungeons = d end
    -- trwaly mirror best-keys (przetrwa sesje / offline)
    local cu = GK.userCache[k]
    if cu then cu.dungeons = { best = best, bestTimed = bestTimed } end
    if KloceFrame and KloceFrame.mode == "active" and KloceFrame.RefreshList then KloceFrame.RefreshList() end
end

-- ============================
-- ODCZYT DLA UI
-- ============================
-- Rekord podziemi gracza: siebie z DB, innych z addonUsers -> userCache. nil gdy brak.
local function recOf(name)
    if not name then return nil end
    local k = normalizeName(name)
    if k == normalizeName(GetUnitFullName("player")) then
        return GigaKloceDB and GigaKloceDB.myDungeons
    end
    local u = GK.addonUsers[k]
    if u and u.dungeons then return u.dungeons end
    local cu = GK.userCache[k]
    if cu and cu.dungeons then return cu.dungeons end
    return nil
end

-- best key per podziemie: zwraca tabele best[i]=lvl i bestTimed[i]=bool (moga byc puste).
function GK.BestKeysOf(name)
    local r = recOf(name)
    if not r then return nil end
    return r.best, r.bestTimed
end

-- Najwyzszy klucz overall (max po best[]). Zwraca: dungeon, level, timed (albo nil).
function GK.HighKeyOf(name)
    local r = recOf(name)
    if not r or not r.best then return nil end
    local bi, bl = nil, 0
    for i, lvl in pairs(r.best) do
        if (lvl or 0) > bl then bl = lvl; bi = i end
    end
    if not bi then return nil end
    return GK.MPLUS_DUNGEONS[bi], bl, (r.bestTimed and r.bestTimed[bi]) or false
end

-- Ostatni przebieg. Zwraca: dungeon, level, timed, pct (albo nil).
function GK.LastRunOf(name)
    local r = recOf(name)
    if not r or not r.lastIdx or r.lastIdx == 0 then return nil end
    return GK.MPLUS_DUNGEONS[r.lastIdx], r.lastLvl, r.lastTimed, r.lastPct
end

-- ============================
-- LOKALNA HISTORIA RUNOW (tylko nasz klient; NIE wysylana kanalem)
-- GigaKloceDB.runHistory[idx] = { run, run, ... } newest-first, max 10.
-- run = { when, level, timed, dur, myRole, players = { {name,class,spec,role,dmg,dps,heal,hps,pct,isSelf}, ... } }
-- players = CALA piatka (DPS + healer + tank), juz posortowana przez RecordCompletedRun.
-- ============================
local HISTORY_MAX = 10

-- players: gotowa, posortowana lista rekordow graczy (budowana w RecordCompletedRun).
function GK.PushRunHistoryPlayers(idx, level, timed, dur, players)
    if not idx or idx == 0 then return end
    GigaKloceDB.runHistory = GigaKloceDB.runHistory or {}
    local h = GigaKloceDB.runHistory[idx]
    if not h then h = {}; GigaKloceDB.runHistory[idx] = h end
    table.insert(h, 1, {
        when = (GK.now and GK.now()) or time(),
        level = level, timed = timed and true or false, dur = dur,
        myRole = (UnitGroupRolesAssigned and UnitGroupRolesAssigned("player")) or nil,
        players = players or {},
    })
    for i = #h, HISTORY_MAX + 1, -1 do table.remove(h, i) end
end

-- Historia runow danego podziemia (po indeksie). Zwraca tablice (newest-first) albo nil.
function GK.RunHistoryOf(idx)
    return GigaKloceDB and GigaKloceDB.runHistory and GigaKloceDB.runHistory[idx]
end

-- Lista podziemi, dla ktorych mamy historie: { {idx, name, count, lastWhen}, ... } sort wg lastWhen desc.
function GK.DungeonsWithHistory()
    local out = {}
    local rh = GigaKloceDB and GigaKloceDB.runHistory
    if not rh then return out end
    for idx, h in pairs(rh) do
        if type(h) == "table" and #h > 0 then
            out[#out + 1] = { idx = idx, name = GK.MPLUS_DUNGEONS[idx] or ("#" .. idx), count = #h, lastWhen = h[1].when or 0 }
        end
    end
    table.sort(out, function(a, b) return (a.lastWhen or 0) > (b.lastWhen or 0) end)
    return out
end

-- ============================
-- PRZESYL HISTORII RUNOW (super-admin: whisper request -> chunked reply). U ODBIORCY ULOTNE.
-- Serializacja: runy rozdzielone RS; pola runa rozdzielone US; gracze GS; podpola gracza ",".
-- ============================
local RS, US, GS = "\030", "\031", "\029"
local remoteRuns = {}   -- [normName] = { byIdx = {[idx]={run,...}}, when, name }

local function serializeHistory()
    local rh = GigaKloceDB and GigaKloceDB.runHistory
    if not rh then return "" end
    local runs = {}
    for idx, h in pairs(rh) do
        if type(h) == "table" then
            for _, run in ipairs(h) do
                local pls = {}
                for _, p in ipairs(run.players or {}) do
                    pls[#pls + 1] = table.concat({
                        (tostring(p.name or "")):gsub("[,%z\029\030\031]", " "),
                        p.class or "",
                        math.floor((p.dmg or 0) + 0.5),
                        p.pct or "",
                        p.isSelf and "1" or "",
                        p.role or "",
                        math.floor((p.heal or 0) + 0.5),
                    }, ",")
                end
                runs[#runs + 1] = table.concat({
                    idx, run.level or 0, run.timed and "1" or "0",
                    math.floor(run.dur or 0), run.when or 0, run.myRole or "",
                    table.concat(pls, GS),
                }, US)
            end
        end
    end
    return table.concat(runs, RS)
end

local function deserializeHistory(payload)
    local byIdx = {}
    if not payload or payload == "" then return byIdx end
    for runStr in (payload .. RS):gmatch("(.-)" .. RS) do
        if runStr ~= "" then
            local idx, level, timed, dur, when, role, plsStr =
                runStr:match("^(.-)" .. US .. "(.-)" .. US .. "(.-)" .. US .. "(.-)" .. US .. "(.-)" .. US .. "(.-)" .. US .. "(.*)$")
            idx = tonumber(idx)
            if idx then
                local players = {}
                if plsStr and plsStr ~= "" then
                    for pStr in (plsStr .. GS):gmatch("(.-)" .. GS) do
                        if pStr ~= "" then
                            -- format Part4: name,class,dmg,pct,self,role,heal ; starszy (Part3): name,class,dmg,pct,self
                            local nm, cls, dmg, pct, slf, role, heal =
                                pStr:match("^(.-),(.-),(.-),(.-),(.-),(.-),(.*)$")
                            if not nm then   -- fallback na stary 5-polowy format
                                nm, cls, dmg, pct, slf = pStr:match("^(.-),(.-),(.-),(.-),(.*)$")
                            end
                            players[#players + 1] = {
                                name = nm, class = (cls and cls ~= "" and cls) or nil,
                                dmg = tonumber(dmg) or 0, pct = tonumber(pct),
                                isSelf = (slf == "1") or nil,
                                role = (role and role ~= "" and role) or nil,
                                heal = tonumber(heal) or 0,
                            }
                        end
                    end
                end
                local h = byIdx[idx]; if not h then h = {}; byIdx[idx] = h end
                h[#h + 1] = {
                    level = tonumber(level) or 0, timed = (timed == "1"),
                    dur = tonumber(dur) or 0, when = tonumber(when) or 0,
                    myRole = (role and role ~= "" and role) or nil, players = players,
                }
            end
        end
    end
    return byIdx
end

-- Odpowiedz na MHR? — wyslij swoja historie w kawalkach (zawsze min. 1, by pytajacy nie czekal w nieskonczonosc).
function GK.SendMHist(target)
    if not target or target == "" then return end
    local payload = serializeHistory()
    local CHUNK = 200
    local total = math.max(1, math.ceil(#payload / CHUNK))
    for seq = 1, total do
        local data = payload:sub((seq - 1) * CHUNK + 1, seq * CHUNK)
        if GK.Send then GK.Send(GK.MSG_MHIST .. seq .. "/" .. total .. US .. data, "WHISPER", target) end
    end
end

local mhBuf = {}   -- [normSender] = { total, parts = {}, count, t }

-- Odbior kawalka "MHN<seq>/<total>\031<data>"; po komplecie -> deserializacja + okno.
function GK.ReceiveMHist(sender, msg)
    local body = msg:sub(#GK.MSG_MHIST + 1)          -- po "MHN"
    local header, data = body:match("^(.-)" .. US .. "(.*)$")
    if not header then return end
    local seq, total = header:match("^(%d+)/(%d+)$")
    seq, total = tonumber(seq), tonumber(total)
    if not seq or not total or total < 1 then return end
    local k = normalizeName(sender)
    local buf = mhBuf[k]
    if seq == 1 or not buf or buf.total ~= total then
        buf = { total = total, parts = {}, count = 0, t = GetTime() }
        mhBuf[k] = buf
        C_Timer.After(30, function()
            if mhBuf[k] == buf and buf.count < buf.total then mhBuf[k] = nil end   -- porzuc niekompletny
        end)
    end
    if not buf.parts[seq] then
        buf.parts[seq] = data or ""
        buf.count = buf.count + 1
    end
    if buf.count >= buf.total then
        mhBuf[k] = nil
        remoteRuns[k] = { byIdx = deserializeHistory(table.concat(buf.parts)), when = GetTime(), name = displayName(sender) }
        if ShowRunsWindow then ShowRunsWindow(nil, sender, false) end   -- otworz/odswiez okno dla tego ownera
    end
end

-- Wyslij prosbe i otworz okno w stanie "czekam" (super-admin -> klik w menu).
function GK.RequestMHist(who)
    if not who or who == "" then return end
    if normalizeName(who) == normalizeName(GetUnitFullName("player")) then
        if ShowRunsWindow then ShowRunsWindow() end   -- to ja -> lokalna historia
        return
    end
    remoteRuns[normalizeName(who)] = nil   -- wyczysc stare dane -> okno pokaze "Requesting..."
    if GK.Send then GK.Send(GK.MSG_MHREQ, "WHISPER", who) end
    if GK.out then GK.out("Requesting M+ history from " .. displayName(who) .. " ...") end
    if ShowRunsWindow then ShowRunsWindow(nil, who, true) end
end

-- ===== Odczyt dla UI: lokalny (owner=nil) albo zdalny (owner=nick) =====
function GK.HasRemoteRuns(owner)
    return (owner ~= nil) and (remoteRuns[normalizeName(owner)] ~= nil)
end

function GK.RunHistoryOfOwner(owner, idx)
    if not owner then return GK.RunHistoryOf(idx) end
    local r = remoteRuns[normalizeName(owner)]
    return r and r.byIdx and r.byIdx[idx]
end

function GK.DungeonsWithHistoryOf(owner)
    if not owner then return GK.DungeonsWithHistory() end
    local out = {}
    local r = remoteRuns[normalizeName(owner)]
    if not r or not r.byIdx then return out end
    for idx, h in pairs(r.byIdx) do
        if type(h) == "table" and #h > 0 then
            out[#out + 1] = { idx = idx, name = GK.MPLUS_DUNGEONS[idx] or ("#" .. idx), count = #h, lastWhen = h[1].when or 0 }
        end
    end
    table.sort(out, function(a, b) return (a.lastWhen or 0) > (b.lastWhen or 0) end)
    return out
end
