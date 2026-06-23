-- ============================
-- GigaKloce :: Meter (czytanie DPS z Details!/Skada/Recount, sugestie chad/kloc po M+)
-- ============================
-- Po zakonczeniu Mythic+ czytamy skumulowane obrazenia kazdego gracza z zainstalowanego metra
-- (Details!, Skada lub Recount), liczymy DELTE wzgledem snapshotu z poczatku djunga i na tej
-- podstawie proponujemy (popup): top DPS -> chad, ostatni DPS -> kloc. Ranking po delcie obrazen
-- jest rownowazny rankingowi po DPS (to samo okno czasowe dla calej grupy), wiec progi 110%/2x
-- dzialaja wprost na delcie. Pod uwage bierzemy TYLKO graczy o roli DAMAGER.
local ADDON, GK = ...
local normalizeName, displayName, has_value, RosterUnitName, GetUnitFullName, log =
    GK.normalizeName, GK.displayName, GK.has_value, GK.RosterUnitName, GK.GetUnitFullName, GK.log

-- ============================
-- ADAPTERY METROW
-- Kazdy zwraca { [normName] = { dmg = <number>, heal = <number> } } albo nil gdy metra brak.
-- Wolane przez pcall (patrz ReadCumulative) — bledne/niespodziewane API nie wywali addona.
-- ============================

-- Details!: skumulowany segment "overall". combat[1] = kontener obrazen, combat[2] = leczenia.
local function readDetails()
    local D = _G.Details or _G._detalhes
    if not D then return nil end
    local combat
    if type(D.GetCombat) == "function" then combat = D:GetCombat("overall") end
    if not combat then combat = D.tabela_overall end
    if not combat then return nil end
    local out = {}
    local function harvest(attr, field)
        local container = combat[attr]
        if not container then return end
        local function add(actor)
            if actor and actor.nome then
                local k = normalizeName(actor.nome)
                out[k] = out[k] or { dmg = 0, heal = 0 }
                out[k][field] = actor.total or actor.totaldmg or 0
            end
        end
        if type(container.ListActors) == "function" then
            for _, actor in container:ListActors() do add(actor) end
        elseif type(container._ActorTable) == "table" then
            for _, actor in ipairs(container._ActorTable) do add(actor) end
        end
    end
    harvest(1, "dmg")   -- DETAILS_ATTRIBUTE_DAMAGE
    harvest(2, "heal")  -- DETAILS_ATTRIBUTE_HEAL
    if not next(out) then return nil end
    return out
end

-- Skada: set "total" (skumulowany cala sesje). set.players[i] = { name, damage, healing }.
local function readSkada()
    local S = _G.Skada
    if not S then return nil end
    local set = S.total or S.current
    if not set or type(set.players) ~= "table" then return nil end
    local out = {}
    for _, p in ipairs(set.players) do
        if p and p.name then
            out[normalizeName(p.name)] = { dmg = p.damage or 0, heal = p.healing or 0 }
        end
    end
    if not next(out) then return nil end
    return out
end

-- Recount (best-effort; API najmniej stabilne). db2[name].Fights — 0 lub "OverallData" = caly przebieg;
-- gdy brak, sumujemy dodatnie indeksy walk.
local function readRecount()
    local R = _G.Recount
    if not R or type(R.db2) ~= "table" then return nil end
    local out = {}
    for name, data in pairs(R.db2) do
        if type(data) == "table" and type(data.Fights) == "table" then
            local overall = data.Fights[0] or data.Fights["OverallData"]
            local dmg, heal = 0, 0
            if type(overall) == "table" then
                dmg, heal = overall.Damage or 0, overall.Healing or 0
            else
                for idx, fight in pairs(data.Fights) do
                    if type(idx) == "number" and idx > 0 and type(fight) == "table" then
                        dmg = dmg + (fight.Damage or 0)
                        heal = heal + (fight.Healing or 0)
                    end
                end
            end
            if dmg > 0 or heal > 0 then out[normalizeName(name)] = { dmg = dmg, heal = heal } end
        end
    end
    if not next(out) then return nil end
    return out
end

-- Probuje kolejne metry (Details! -> Skada -> Recount), kazdy w pcall. Zwraca dane + nazwe metra.
local function ReadCumulative()
    for _, m in ipairs({ { "Details!", readDetails }, { "Skada", readSkada }, { "Recount", readRecount } }) do
        local ok, data = pcall(m[2])
        if ok and data then return data, m[1] end
    end
    return nil, nil
end
GK.MeterReadCumulative = ReadCumulative

-- ============================
-- BASELINE (snapshot poczatku dunga; ULOTNY — tylko w pamieci)
-- ============================
local baseline = nil   -- { stamp = GetTime(), data = {normName -> {dmg,heal}}, meter = <name|nil> }

function GK.MeterSnapshotBaseline()
    local data, meter = ReadCumulative()
    baseline = { stamp = GetTime(), data = data or {}, meter = meter }
    log("[DPS] Baseline snapshot (" .. (meter and ("metr: " .. meter) or "brak metra") .. ").")
end

function GK.MeterHasBaseline() return baseline ~= nil end

-- ============================
-- POMOCNICZE
-- ============================
-- Krotki format liczby (1.2M / 345.6k / 12).
local function fmt(n)
    n = n or 0
    if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
    if n >= 1e3 then return string.format("%.1fk", n / 1e3) end
    return tostring(math.floor(n + 0.5))
end

local function isAddonUser(k) return GK.addonUsers and GK.addonUsers[k] ~= nil end

-- ============================
-- PELNA LISTA CZLONKOW grupy z delta dmg+heal + rola. Zwraca: members, meter, dur.
-- members = { { key, name, role, dmg, heal }, ... } dla CALEJ grupy (tank/heal tez).
-- role: UnitGroupRolesAssigned; przy NONE/nieznanej -> HEALER gdy heal>dmg, inaczej DAMAGER.
-- Zwraca nil gdy poza grupa albo brak metra.
-- ============================
function GK.MeterMembersNow()
    if not IsInGroup() then return nil end
    local now, meter = ReadCumulative()
    if not now then return nil end

    -- delta wzgledem baseline (gdy brak baseline: uzyj danych skumulowanych jak sa).
    local function delta(k)
        local cur = now[k]; if not cur then return nil end
        local base = baseline and baseline.data and baseline.data[k]
        local bd = (base and base.dmg) or 0
        local bh = (base and base.heal) or 0
        return { dmg = math.max(0, (cur.dmg or 0) - bd), heal = math.max(0, (cur.heal or 0) - bh) }
    end

    local members = {}
    for i = 1, GetNumGroupMembers() do
        local unit, name = RosterUnitName(i)
        if unit and name then
            local k = normalizeName(name)
            local d = delta(k)
            if d then
                local role = (UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)) or "NONE"
                if role == "NONE" or role == "" then
                    role = (d.heal > d.dmg) and "HEALER" or "DAMAGER"   -- heurystyka z metra
                end
                members[#members + 1] = { key = k, name = name, role = role, dmg = d.dmg, heal = d.heal }
            end
        end
    end
    local dur = baseline and (GetTime() - baseline.stamp) or 0
    return members, meter, dur
end

-- ============================
-- RANKING DPS (rola DAMAGER) wg delty obrazen vs baseline.
-- Zwraca: ranked, meter, dur. ranked = posortowana malejaco lista { key, name, dmg, heal },
-- zawiera WSZYSTKICH DPS-ow (tez nas, userow z addonem, osoby z list) — filtrowanie kandydatow
-- robi dopiero logika sugestii. Zwraca nil gdy poza grupa albo brak metra.
-- ============================
function GK.MeterRankNow()
    local members, meter, dur = GK.MeterMembersNow()
    if not members then return nil end
    local ranked = {}
    for _, m in ipairs(members) do
        if m.role == "DAMAGER" then
            ranked[#ranked + 1] = { key = m.key, name = m.name, dmg = m.dmg, heal = m.heal }
        end
    end
    table.sort(ranked, function(a, b) return a.dmg > b.dmg end)
    return ranked, meter, dur
end

-- ============================
-- OCENA + SUGESTIE
-- opts.test = true: dry-run wywolany recznie (/kloce dps now) — wypisuje pelny ranking,
-- pomija przelacznik dpsSuggest, dziala tez bez baseline (uzywa danych skumulowanych jak sa).
-- ============================
function GK.MeterEvaluate(opts)
    opts = opts or {}
    if not opts.test and not (GigaKloceDB and GigaKloceDB.dpsSuggest) then return end
    if not IsInGroup() then
        if opts.test then GK.out("[DPS] Nie jestes w grupie.") end
        return
    end

    local ranked, meter, dur = GK.MeterRankNow()
    if not ranked then
        GK.out("[DPS] Nie znaleziono metra (Details!/Skada/Recount) albo brak danych.")
        return
    end
    local meKey = normalizeName(GetUnitFullName("player"))

    if opts.test then
        GK.out("[DPS] Metr: " .. (meter or "?") .. (baseline and "" or " (BRAK baseline — dane skumulowane)"))
        local top = ranked[1]
        for i, p in ipairs(ranked) do
            local dps = (dur > 0) and (" (" .. fmt(p.dmg / dur) .. " dps)") or ""
            local pct = (top and top.dmg > 0) and string.format("  %d%%", math.floor(p.dmg / top.dmg * 100 + 0.5)) or ""
            GK.out(string.format("  %d. %s — %s%s%s", i, displayName(p.name), fmt(p.dmg), dps, pct))
        end
        if #ranked == 0 then GK.out("  (brak graczy DPS w grupie)") end
    end

    if #ranked < 2 then return end

    local function dpsStr(dmg)
        if dur > 0 then return fmt(dmg / dur) .. " dps" end
        return fmt(dmg) .. " dmg"
    end

    -- czy kandydata wolno zaproponowac na dana liste (nie my, nie ma addona, nie jest juz na tej liscie)
    local function eligible(p, list)
        if p.key == meKey then return false end
        if isAddonUser(p.key) then return false end
        if has_value(list, p.name) then return false end
        return true
    end

    -- CHAD: top DPS, gdy > 110% drugiego (drugi musi miec realne obrazenia).
    local top, second = ranked[1], ranked[2]
    if second.dmg > 0 and top.dmg > 1.10 * second.dmg and eligible(top, GK.gigachad) then
        StaticPopup_Show("GIGAKLOCE_DPS_CHAD", displayName(top.name), dpsStr(top.dmg), top.name)
    end

    -- KLOC: ostatni DPS, gdy gracz nad nim zrobil >= 2x tyle (i sam zrobil cokolwiek).
    local last, above = ranked[#ranked], ranked[#ranked - 1]
    if above.dmg > 0 and above.dmg >= 2 * last.dmg and eligible(last, GK.gigakloce) then
        StaticPopup_Show("GIGAKLOCE_DPS_KLOC", displayName(last.name), dpsStr(last.dmg), last.name)
    end
end

-- ============================
-- WEJSCIA Z EVENTOW (wywolywane z GigaKloce_Events.lua)
-- ============================
-- Baseline robimy ZAWSZE (potrzebny i do sugestii, i do % dmg w rekordzie przebiegu),
-- niezaleznie od przelacznika dpsSuggest. Gate dotyczy tylko popupow sugestii.
function GK.OnChallengeStart()
    GK.MeterSnapshotBaseline()
    if GK.DungeonsCaptureStart then GK.DungeonsCaptureStart() end   -- zapisz kontekst klucza (fallback)
end

function GK.OnChallengeComplete()
    -- maly poslizg, zeby metr domknal ostatni pull przed odczytem
    C_Timer.After(2, function()
        if GigaKloceDB and GigaKloceDB.dpsSuggest then GK.MeterEvaluate() end
        if GK.RecordCompletedRun then GK.RecordCompletedRun() end   -- highest key + % dmg (zawsze)
    end)
end

-- Wejscie do instancji M+: gdy nie ma jeszcze baseline (np. po /reload w trakcie), zrob go.
function GK.OnEnterWorldMeter()
    if GK.MeterHasBaseline() then return end
    local active = C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive()
    local diff = select(3, GetInstanceInfo())   -- 7.3.5: difficultyID 8 = Mythic Keystone
    if active or diff == 8 then
        GK.MeterSnapshotBaseline()
    end
end
