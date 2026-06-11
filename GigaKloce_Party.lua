-- ============================
-- GigaKloce :: Party (presence + presety skladu + invite)
-- ============================
local ADDON, GK = ...
local AddonPrefix, addonUsers, userCache, log, displayName, normalizeName, GetUnitFullName =
    GK.AddonPrefix, GK.addonUsers, GK.userCache, GK.log, GK.displayName, GK.normalizeName, GK.GetUnitFullName
local MSG_FLAG = GK.MSG_FLAG

local PRESENCE_STALE = 120   -- po tylu s bez "HI" uznajemy gracza za offline/bez addonu
local PRES_SEP = "\031"      -- separator class/spec w wiadomosci presence

-- Wlasny spec (nazwa, np. "Restoration") albo "".
local function myOwnSpec()
    local idx = GetSpecialization and GetSpecialization()
    if idx and GetSpecializationInfo then
        local _, n = GetSpecializationInfo(idx)
        return n or ""
    end
    return ""
end

-- Upsert do trwalego cache (nadpisuje class/spec tylko gdy podane niepuste).
local function cacheUser(name, class, spec)
    local k = normalizeName(name)
    if k == "" then return end
    local u = userCache[k]
    if not u then u = {}; userCache[k] = u end
    u.name = displayName(name)
    if class and class ~= "" then u.class = class end
    if spec and spec ~= "" then u.spec = spec end
    u.t = GetTime()
end
GK.CacheUser = function(name, class, spec) cacheUser(name, class, spec) end

-- ===== Presence (po KANALE czatu, cross-guild) =====
-- payload: "H ~ class ~ spec ~ admin ~ blocked ~ ver ~ guild" (separator GK.CHAN_SEP, drukowalny)
local function cleanChan(s) return (tostring(s or "")):gsub("[%c~]", " ") end
function GK.BroadcastPresence()
    local _, classFile = UnitClass("player")   -- np. "MAGE" (niezalezne od jezyka)
    local adminBit   = (GK.AmIAdmin and GK.AmIAdmin()) and "1" or "0"
    local blockedBit = (GK.AmIBlocked and GK.AmIBlocked()) and "1" or "0"
    local guild = GetGuildInfo("player") or ""
    local s = GK.CHAN_SEP
    GK.SendChan("H" .. s .. (classFile or "") .. s .. cleanChan(myOwnSpec())
        .. s .. adminBit .. s .. blockedBit .. s .. (GK.DATA_VERSION or 0) .. s .. cleanChan(guild))
end

-- Wolane z parsera kanalu (Events): pola juz rozbite.
function GK.ReceivePresence(sender, class, spec, adm, blk, ver, guild)
    if class == "" then class = nil end
    if spec == "" then spec = nil end
    local k = normalizeName(sender)
    addonUsers[k] = {
        name = displayName(sender), class = class, spec = spec, t = GetTime(),
        admin = (adm == "1") or GK.IsSuperAdmin(sender), blocked = (blk == "1"),
        version = tonumber(ver) or 1,   -- brak wersji = stary klient
        guild = (guild and guild ~= "" and guild) or nil,
    }
    cacheUser(sender, class, spec)   -- zawsze pisz do trwalego cache (klasa/spec)
end

-- Czy nadawca ma te sama wersje modelu danych co my?
function GK.VersionOK(sender)
    local u = addonUsers[normalizeName(sender)]
    return u ~= nil and u.version == GK.DATA_VERSION
end
-- Czy wersja nadawcy jest ZNANA i INNA niz nasza? (nieznana = akceptuj — presence moze jeszcze nie dojsc,
-- a format list jest stabilny; gate ma blokowac tylko realnie inne wersje formatu).
function GK.VersionBad(sender)
    local u = addonUsers[normalizeName(sender)]
    return u ~= nil and u.version ~= nil and u.version ~= GK.DATA_VERSION
end

-- Klasa gracza po nicku (siebie z UnitClass; potem live presence; na koniec trwaly cache). nil gdy nieznana.
function GK.ClassOf(name)
    if not name then return nil end
    local n = normalizeName(name)
    if n == normalizeName(GetUnitFullName("player")) then
        local _, c = UnitClass("player")
        return c
    end
    local u = addonUsers[n]
    if u and u.class then return u.class end
    local c = userCache[n]
    return c and c.class
end

-- Gildia gracza po nicku (siebie z GetGuildInfo; inni z presence). nil gdy nieznana.
function GK.GuildOf(name)
    if not name then return nil end
    local n = normalizeName(name)
    if n == normalizeName(GetUnitFullName("player")) then return GetGuildInfo("player") end
    local u = addonUsers[n]
    return u and u.guild
end

-- Spec gracza po nicku (siebie z GetSpecialization; potem live presence; na koniec cache). nil gdy nieznany.
function GK.SpecOf(name)
    if not name then return nil end
    local n = normalizeName(name)
    if n == normalizeName(GetUnitFullName("player")) then
        local s = myOwnSpec()
        return s ~= "" and s or nil
    end
    local u = addonUsers[n]
    if u and u.spec then return u.spec end
    local c = userCache[n]
    return c and c.spec
end

-- Znajduje token jednostki (player/party/raid/target/...) dla danego nicku, albo nil.
local function unitForName(name)
    local target = normalizeName(name)
    if target == "" then return nil end
    local function chk(u)
        if UnitExists(u) and UnitIsPlayer(u) then
            local fn = GetUnitFullName(u)
            if fn and normalizeName(fn) == target then return u end
        end
        return nil
    end
    if chk("player") then return "player" end
    local num = GetNumGroupMembers() or 0
    if IsInRaid() then
        for i = 1, num do if chk("raid" .. i) then return "raid" .. i end end
    else
        for i = 1, num - 1 do if chk("party" .. i) then return "party" .. i end end
    end
    for _, u in ipairs({ "target", "mouseover", "focus" }) do
        if chk(u) then return u end
    end
    return nil
end

-- Auto-wykrycie klasy (i specu) gracza dostepnego w okolicy (party/raid/target/...).
-- Zwraca classFile ("DRUID") + nazwe speca (np. "Restoration").
-- Spec: pewny tylko dla siebie; dla innych best-effort (gdy dane inspectu sa w cache).
function GK.DetectClassSpec(name)
    local u = unitForName(name)
    if not u then return nil, nil end
    local _, classFile = UnitClass(u)
    local spec = nil
    if UnitIsUnit(u, "player") then
        local idx = GetSpecialization and GetSpecialization()
        if idx and GetSpecializationInfo then
            local _, specName = GetSpecializationInfo(idx)
            spec = specName
        end
    elseif GetInspectSpecialization and GetSpecializationInfoByID then
        local sid = GetInspectSpecialization(u)
        if sid and sid > 0 then
            local _, specName = GetSpecializationInfoByID(sid)
            spec = specName
        end
    end
    return classFile, spec
end

-- ===== Async inspect: automatyczne dociaganie specu cudzych postaci =====
-- Spec gracza (nie-siebie) jest dostepny dopiero po NotifyInspect + zdarzeniu INSPECT_READY.
local pendingInspect = {}   -- [guid] = { key, unit, name }

-- Prosi o spec gracza (gdy jest w zasiegu inspectu). Wynik przyjdzie w INSPECT_READY.
function GK.RequestSpec(name)
    if type(CanInspect) ~= "function" or type(NotifyInspect) ~= "function" then return end
    local u = unitForName(name)
    if not u or UnitIsUnit(u, "player") then return end   -- siebie czytamy synchronicznie
    if not CanInspect(u) then return end
    local guid = UnitGUID(u)
    if not guid then return end
    pendingInspect[guid] = { key = normalizeName(name), unit = u, name = name }
    NotifyInspect(u)
end

-- Wolane z INSPECT_READY: czyta spec, zapisuje do info, odswieza UI i rozsyla dalej.
function GK.OnInspectReady(guid)
    if not guid then return end
    local p = pendingInspect[guid]
    if not p then return end
    pendingInspect[guid] = nil
    local u = p.unit
    if not (u and UnitExists(u) and UnitGUID(u) == guid) then u = nil end
    local specName
    if u and GetInspectSpecialization and GetSpecializationInfoByID then
        local sid = GetInspectSpecialization(u)
        if sid and sid > 0 then
            local _, n = GetSpecializationInfoByID(sid)
            specName = n
        end
    end
    if type(ClearInspectPlayer) == "function" then ClearInspectPlayer() end
    if not specName or specName == "" then return end

    cacheUser(p.name, nil, specName)   -- zasil tez trwaly cache
    local info = GK.gigakloceInfo[p.key]
    if not info or (info.spec and info.spec ~= "") then return end   -- nie nadpisuj recznie ustawionego
    info.spec = specName
    info.t = GK.now()   -- nowsza zmiana -> wygra przy sync
    if GK.RefreshUI then GK.RefreshUI() end
    -- rozeslij wykryty spec wlasciwa lista (kloce/chad)
    if GK.has_value and GK.gigakloce and GK.has_value(GK.gigakloce, p.name) then
        if GK.BroadcastKloceDetails then GK.BroadcastKloceDetails(p.name) end
    elseif GK.has_value and GK.gigachad and GK.has_value(GK.gigachad, p.name) then
        if GK.BroadcastChadDetails then GK.BroadcastChadDetails(p.name) end
    end
    -- odswiez okno detali jesli otwarte na tym graczu
    if KloceDetailFrame and KloceDetailFrame:IsShown() and KloceDetailFrame.key == p.key and KloceDetailFrame.RefreshAll then
        KloceDetailFrame.RefreshAll()
    end
end

-- ===== "Last played with" (zrodlo podpowiedzi w polu Add) =====
local PLAYEDWITH_CAP = 300

-- Zapisz/odswiez jednego czlonka grupy w playedWith (klasa pewna; spec best-effort).
local function recordOne(unit)
    if not (UnitExists(unit) and UnitIsPlayer(unit)) then return end
    if UnitIsUnit(unit, "player") then return end
    local name = GetUnitFullName(unit)
    if not name or name == "" then return end
    local key = normalizeName(name)
    if key == "" then return end
    local _, classFile = UnitClass(unit)
    local _, spec = GK.DetectClassSpec(name)   -- spec tylko jesli dane inspectu sa w cache; inaczej nil
    local rec = GK.playedWith[key] or {}
    rec.name = name
    if classFile and classFile ~= "" then rec.class = classFile end
    if spec and spec ~= "" then rec.spec = spec end
    rec.t = GK.now()
    GK.playedWith[key] = rec
    if (not rec.spec or rec.spec == "") and GK.RequestSpec then GK.RequestSpec(name) end  -- dociagnij spec na pozniej
end

-- przytnij do CAP najnowszych (po czasie)
local function prunePlayedWith()
    local n = 0
    for _ in pairs(GK.playedWith) do n = n + 1 end
    if n <= PLAYEDWITH_CAP then return end
    local arr = {}
    for k, v in pairs(GK.playedWith) do arr[#arr + 1] = { k = k, t = v.t or 0 } end
    table.sort(arr, function(a, b) return a.t > b.t end)
    for i = PLAYEDWITH_CAP + 1, #arr do GK.playedWith[arr[i].k] = nil end
end

-- Zapisz caly aktualny sklad party/raid (wolane z GROUP_ROSTER_UPDATE i na logowaniu).
function GK.RecordPlayedWith()
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do recordOne("raid" .. i) end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do recordOne("party" .. i) end
    else
        return
    end
    prunePlayedWith()
end

-- Podpowiedzi do pola Add: dopasowania (pod)tekstem, posortowane "ostatnio grane".
-- Zwraca liste rekordow {name, class, spec, t}. Pusty query -> najswiezsze.
function GK.PlayedWithMatches(query, max)
    max = max or 8
    query = (query or ""):lower()
    local out = {}
    for key, rec in pairs(GK.playedWith) do
        local hay = (rec.name or key):lower()
        if query == "" or hay:find(query, 1, true) then
            out[#out + 1] = rec
        end
    end
    table.sort(out, function(a, b) return (a.t or 0) > (b.t or 0) end)
    while #out > max do table.remove(out) end
    return out
end

-- ===== Flagi admin/blocked =====
-- Admin wysyla ustawienie flag dla gracza (GUILD; cel + ewentualnie reszta aktualizuja cache/widok).
function GK.SetUserFlags(targetName, admin, blocked)
    if not targetName or targetName == "" then return end
    local nm = (GK.canonicalDisplay and GK.canonicalDisplay(targetName)) or targetName
    GK.Send(MSG_FLAG .. nm .. PRES_SEP .. (admin and "1" or "0") .. PRES_SEP .. (blocked and "1" or "0"))
end

-- Odbior FLG: ustaw flagi wg uprawnien nadawcy (admin nadaje tylko super; blocked nadaje kazdy admin).
function GK.ApplyFlag(sender, payload)
    local target, adm, blk = strsplit(PRES_SEP, payload or "", 3)
    if not target or target == "" then return end
    local superSender = GK.IsSuperAdmin(sender)
    local su = addonUsers[normalizeName(sender)]
    local adminSender = superSender or (su and su.admin)
    if not adminSender then return end   -- tylko admin moze cokolwiek ustawiac
    local tkey = normalizeName(target)
    local tu = addonUsers[tkey]
    if tu then
        if superSender then tu.admin = (adm == "1") end
        tu.blocked = (blk == "1")
    end
    -- jesli to JA jestem celem: ustaw swoje flagi i rozglos presence
    if tkey == normalizeName(GetUnitFullName("player")) then
        if superSender then GigaKloceDB.myAdmin = (adm == "1") end
        GigaKloceDB.myBlocked = (blk == "1")
        -- cicho: nikt (nawet sam zainteresowany) nie dostaje komunikatu o zmianie flag
        if GK.BroadcastPresence then GK.BroadcastPresence() end
    end
    if KloceFrame and KloceFrame.mode == "party" and KloceFrame.RefreshPartyList then KloceFrame.RefreshPartyList() end
end

-- Joiner wybiera ZRODLO sync: preferowane (GigaKloceDB.syncSource) jesli online,
-- inaczej "najnizszy" nick online z addonem (deterministycznie). Zwraca nick do szeptu albo nil.
function GK.PickSyncSource()
    local me = normalizeName(GetUnitFullName("player"))
    local myGuild = GetGuildInfo("player")
    local now = GetTime()
    -- Zrodlo MUSI byc z TEJ SAMEJ gildii (odpowiedz na SYNC? leci po GUILD, dotrze tylko do gildii).
    -- Zablokowany nie moze byc zrodlem (i tak nie odsyla danych). Cross-guild = osobny most whisper.
    local function ok(k, v)
        return k ~= me and v and not v.blocked and (now - (v.t or 0)) <= PRESENCE_STALE
            and myGuild and v.guild == myGuild
    end
    local pref = GigaKloceDB.syncSource
    if pref and pref ~= "" then
        local pk = normalizeName(pref)
        if ok(pk, addonUsers[pk]) then return addonUsers[pk].name or pref end
    end
    local bestKey, bestName
    for k, v in pairs(addonUsers) do
        if ok(k, v) then
            if not bestKey or k < bestKey then bestKey = k; bestName = v.name end
        end
    end
    return bestName   -- nil gdy nikt (nie-zablokowany) z addonem nie jest online
end

-- Lista online (z addonem) jako {name, class}, posortowana po nicku.
function GK.GetOnlineAddonUsers()
    local now = GetTime()
    local list = {}
    for k, v in pairs(addonUsers) do
        if (now - (v.t or 0)) > PRESENCE_STALE then
            addonUsers[k] = nil
        else
            table.insert(list, { name = v.name, class = v.class, spec = v.spec, admin = v.admin, blocked = v.blocked, version = v.version, guild = v.guild })
        end
    end
    table.sort(list, function(a, b) return (a.name or "") < (b.name or "") end)
    return list
end

-- ===== Presety =====
local function presets() return GigaKloceDB.partyPresets end

function GK.GetPresetNames()
    local names = {}
    for name in pairs(presets()) do table.insert(names, name) end
    table.sort(names)
    return names
end

function GK.GetCurrentPresetName() return GigaKloceDB.partyCurrent end

function GK.SetCurrentPreset(name)
    if presets()[name] then GigaKloceDB.partyCurrent = name end
end

-- tablica nickow aktualnego presetu (tworzy gdy brak)
function GK.GetCurrentMembers()
    local cur = GigaKloceDB.partyCurrent
    if not cur or not presets()[cur] then
        cur = next(presets())
        GigaKloceDB.partyCurrent = cur
    end
    presets()[cur] = presets()[cur] or {}
    return presets()[cur]
end

function GK.PartyAddMember(name)
    if not name or name == "" then return false end
    if normalizeName(name) == normalizeName(GetUnitFullName("player")) then return false end  -- nie siebie
    local m = GK.GetCurrentMembers()
    local n = normalizeName(name)
    for _, v in ipairs(m) do if normalizeName(v) == n then return false end end
    table.insert(m, name)
    return true
end

function GK.PartyRemoveMember(name)
    local m = GK.GetCurrentMembers()
    local n = normalizeName(name)
    for i, v in ipairs(m) do
        if normalizeName(v) == n then table.remove(m, i); return true end
    end
    return false
end

function GK.NewPreset(name)
    name = name and strtrim(name) or ""
    if name == "" then return false end
    if presets()[name] then GigaKloceDB.partyCurrent = name; return true end
    presets()[name] = {}
    GigaKloceDB.partyCurrent = name
    log('Party preset created: "' .. name .. '"')
    return true
end

function GK.DeletePreset(name)
    name = name or GigaKloceDB.partyCurrent
    if not name then return end
    presets()[name] = nil
    if not next(presets()) then presets()["Main"] = {} end   -- zawsze min. jeden
    GigaKloceDB.partyCurrent = next(presets())
    log('Party preset deleted: "' .. name .. '"')
end

-- Zaprasza wszystkich z aktualnego presetu.
function GK.PartyInviteAll()
    local m = GK.GetCurrentMembers()
    local n = 0
    for _, name in ipairs(m) do
        InviteUnit(displayName(name))
        n = n + 1
    end
    log("Invited " .. n .. " from preset \"" .. (GigaKloceDB.partyCurrent or "?") .. "\".")
end
