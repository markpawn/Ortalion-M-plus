-- ============================
-- GigaKloce :: Dungeons (rekord przebiegow M+: highest key + % dmg, kanal "D")
-- ============================
-- Po ukonczeniu M+ zapisujemy: ostatni przebieg (dungeon, level, czy w czasie, nasz % dmg wzgledem topa)
-- oraz najwyzszy klucz all-time. Dane lecą WLASNYM eventem kanalu "D" (siostra H/P/K) — kazdy user
-- self-reportuje swoje statystyki. Inni widza je w oknie "Active" (klik -> okno szczegolow).
local ADDON, GK = ...
local normalizeName, displayName, GetUnitFullName = GK.normalizeName, GK.displayName, GK.GetUnitFullName

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
    local md = GigaKloceDB and GigaKloceDB.myDungeons
    if not md then return end
    local when = (GK.now and GK.now()) or time()

    -- ostatni przebieg + moj % dmg (top = 100%), liczony z metra przez ranking z Part 1
    md.lastDun, md.lastLvl, md.lastTimed, md.lastWhen = dungeon, level, timed and true or false, when
    md.lastPct = nil
    local ranked = GK.MeterRankNow and GK.MeterRankNow()
    if ranked and ranked[1] and ranked[1].dmg > 0 then
        local meKey = normalizeName(GetUnitFullName("player"))
        for _, p in ipairs(ranked) do
            if p.key == meKey then md.lastPct = math.floor(p.dmg / ranked[1].dmg * 100 + 0.5); break end
        end
    end

    -- najwyzszy klucz all-time (liczy sie KAZDE ukonczenie)
    if level > (md.hiLvl or 0) then
        md.hiDun, md.hiLvl, md.hiTimed, md.hiWhen = dungeon, level, timed and true or false, when
    end

    if GK.BroadcastDungeons then GK.BroadcastDungeons() end
    if KloceFrame and KloceFrame.mode == "active" and KloceFrame.RefreshList then KloceFrame.RefreshList() end
    if GK.log then GK.log("[Dungeons] " .. dungeon .. " +" .. level
        .. (timed and " (timed)" or "") .. (md.lastPct and (" — " .. md.lastPct .. "% dmg") or "")) end
end

-- ============================
-- KANAL "D" (dungeons): D ~ hiDun ~ hiLvl ~ hiTimed ~ lastDun ~ lastLvl ~ lastTimed ~ lastPct
-- ============================
local function c(x) return (tostring(x or "")):gsub("[%c~]", " ") end

function GK.BroadcastDungeons()
    if GK.CanBroadcast and not GK.CanBroadcast() then return end   -- blocked = nie wysylam danych
    local md = GigaKloceDB and GigaKloceDB.myDungeons
    if not md or (not md.hiDun and not md.lastDun) then return end
    local s = GK.CHAN_SEP
    GK.SendChan("D" .. s .. c(md.hiDun) .. s .. (md.hiLvl or 0) .. s .. (md.hiTimed and "1" or "0")
        .. s .. c(md.lastDun) .. s .. (md.lastLvl or 0) .. s .. (md.lastTimed and "1" or "0")
        .. s .. (md.lastPct ~= nil and md.lastPct or ""))
end

-- Odbior (pola juz rozbite przez parser kanalu w Events).
function GK.ReceiveDungeons(sender, hiDun, hiLvl, hiTimed, lastDun, lastLvl, lastTimed, lastPct)
    local k = normalizeName(sender)
    if k == "" then return end
    local d = {
        hiDun = (hiDun and hiDun ~= "" and hiDun) or nil,
        hiLvl = tonumber(hiLvl) or 0,
        hiTimed = (hiTimed == "1"),
        lastDun = (lastDun and lastDun ~= "" and lastDun) or nil,
        lastLvl = tonumber(lastLvl) or 0,
        lastTimed = (lastTimed == "1"),
        lastPct = tonumber(lastPct),
    }
    local u = GK.addonUsers[k]
    if u then u.dungeons = d end
    -- trwaly mirror highest-key (przetrwa sesje / offline)
    local cu = GK.userCache[k]
    if cu then cu.dungeons = { hiDun = d.hiDun, hiLvl = d.hiLvl, hiTimed = d.hiTimed } end
    if KloceFrame and KloceFrame.mode == "active" and KloceFrame.RefreshList then KloceFrame.RefreshList() end
end

-- ============================
-- ODCZYT DLA UI
-- ============================
-- Zwraca: dungeon, level, timed  (albo nil). Siebie z DB, innych z addonUsers -> userCache.
function GK.HighKeyOf(name)
    if not name then return nil end
    local k = normalizeName(name)
    if k == normalizeName(GetUnitFullName("player")) then
        local md = GigaKloceDB and GigaKloceDB.myDungeons
        if md and md.hiDun then return md.hiDun, md.hiLvl, md.hiTimed end
        return nil
    end
    local u = GK.addonUsers[k]
    if u and u.dungeons and u.dungeons.hiDun then return u.dungeons.hiDun, u.dungeons.hiLvl, u.dungeons.hiTimed end
    local cu = GK.userCache[k]
    if cu and cu.dungeons and cu.dungeons.hiDun then return cu.dungeons.hiDun, cu.dungeons.hiLvl, cu.dungeons.hiTimed end
    return nil
end

-- Zwraca: dungeon, level, timed, pct  (albo nil).
function GK.LastRunOf(name)
    if not name then return nil end
    local k = normalizeName(name)
    if k == normalizeName(GetUnitFullName("player")) then
        local md = GigaKloceDB and GigaKloceDB.myDungeons
        if md and md.lastDun then return md.lastDun, md.lastLvl, md.lastTimed, md.lastPct end
        return nil
    end
    local u = GK.addonUsers[k]
    if u and u.dungeons and u.dungeons.lastDun then
        local d = u.dungeons
        return d.lastDun, d.lastLvl, d.lastTimed, d.lastPct
    end
    return nil
end
