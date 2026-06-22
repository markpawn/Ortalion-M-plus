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
local function completedRunInfo()
    local dungeon, level, timed
    if C_ChallengeMode and C_ChallengeMode.GetCompletionInfo then
        local mapID, lvl, _, onTime = C_ChallengeMode.GetCompletionInfo()
        if lvl and lvl > 0 then level = lvl end
        if onTime ~= nil then timed = onTime and true or false end
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
    return dungeon, level, timed
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
    local dungeon, level, timed = completedRunInfo()
    if not dungeon then return end   -- nie udalo sie zidentyfikowac — pomijamy
    level = level or 0
    local idx = dungeonIndex(dungeon)
    local md = GigaKloceDB and GigaKloceDB.myDungeons
    if not md then return end
    md.best = md.best or {}
    md.bestTimed = md.bestTimed or {}
    local when = (GK.now and GK.now()) or time()

    -- ostatni przebieg + moj % dmg (top = 100%), liczony z metra przez ranking z Part 1
    md.lastIdx = idx or 0
    md.lastLvl = level
    md.lastTimed = timed and true or false
    md.lastWhen = when
    md.lastPct = nil
    local ranked = GK.MeterRankNow and GK.MeterRankNow()
    if ranked and ranked[1] and ranked[1].dmg > 0 then
        local meKey = normalizeName(GetUnitFullName("player"))
        for _, p in ipairs(ranked) do
            if p.key == meKey then md.lastPct = math.floor(p.dmg / ranked[1].dmg * 100 + 0.5); break end
        end
    end

    -- best per podziemie (liczy sie KAZDE ukonczenie)
    if idx and level > (md.best[idx] or 0) then
        md.best[idx] = level
        md.bestTimed[idx] = timed and true or false
    end

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
