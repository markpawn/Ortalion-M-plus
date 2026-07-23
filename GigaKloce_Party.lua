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
-- payload: "H ~ class ~ spec ~ f1 ~ f2 ~ ver ~ guild ~ zone ~ itype ~ party" (separator GK.CHAN_SEP, printable)
-- zone/itype/party are TRAILING fields: older clients ignore them (no version bump).
local function cleanChan(s) return (tostring(s or "")):gsub("[%c~]", " ") end

-- Moja strefa do wyswietlania. Preferujemy to, CO WIDZI GILDIA (pole `zone` z rostera) — wtedy jest
-- spojnie z panelem gildii (np. "Frostwall" zamiast budynku "Town Hall"). Fallback: API stref.
local function myZoneText()
    if IsInGuild() then
        if type(GuildRoster) == "function" then GuildRoster() end   -- odswiez (async; czytamy cache)
        local me = UnitName("player")
        for i = 1, (GetNumGuildMembers() or 0) do
            local name, _, _, _, _, zone = GetGuildRosterInfo(i)
            if name then
                local nm = strsplit("-", name)   -- roster bywa "Nick-Realm"
                if nm == me and zone and zone ~= "" then return zone end
            end
        end
    end
    return GetZoneText() or GetRealZoneText() or ""
end

-- Moj sklad do broadcastu: lider PIERWSZY, potem reszta, max 5 (lider + do 4 innych), nicki canonical
-- zlaczone przecinkiem. Solo / poza grupa -> "". (Raid >5: pierwsze 5 wg kolejnosci rostera.)
local PARTY_SEP = ","
local function myGroupForBroadcast()
    if not IsInGroup() then return "" end
    local canon = GK.canonicalDisplay or function(n) return n end
    local rost = GK.RosterUnitName
    if not rost then return "" end
    local members, leader = {}, nil
    for i = 1, (GetNumGroupMembers() or 0) do
        local unit, name = rost(i)
        if unit and name then
            local nm = canon(name) or name
            members[#members + 1] = nm
            if UnitIsGroupLeader(unit) then leader = nm end
        end
    end
    if #members == 0 then return "" end
    -- lider pierwszy, reszta w kolejnosci rostera (bez duplikatu lidera), cap 5
    local out, seen = {}, {}
    if leader then out[1] = leader; seen[normalizeName(leader)] = true end
    for _, nm in ipairs(members) do
        local nk = normalizeName(nm)
        if not seen[nk] then out[#out + 1] = nm; seen[nk] = true end
        if #out >= 5 then break end
    end
    return table.concat(out, PARTY_SEP)
end

-- "H" core: player attributes (NOT key-specific). ilvl + guild note travel here, so they show
-- even for players WITHOUT a keystone. Party/team composition is a separate "P" event.
function GK.BroadcastPresence()
    local _, classFile = UnitClass("player")   -- np. "MAGE" (niezalezne od jezyka)
    local adminBit   = (GK.AmIAdmin and GK.AmIAdmin()) and "1" or "0"
    local blockedBit = (GK.AmIBlocked and GK.AmIBlocked()) and "1" or "0"
    local guild = GetGuildInfo("player") or ""
    local zone = (cleanChan(myZoneText())):sub(1, 40)
    local inInst, itype = IsInInstance()
    if not inInst then itype = "none" end
    local _, ilvl = GetAverageItemLevel()
    ilvl = math.floor((ilvl or 0) + 0.5)
    local note = (cleanChan((GK.MyGuildNote and GK.MyGuildNote()) or "")):sub(1, 60)
    local s = GK.CHAN_SEP
    GK.SendChan("H" .. s .. (classFile or "") .. s .. cleanChan(myOwnSpec())
        .. s .. adminBit .. s .. blockedBit .. s .. (GK.DATA_VERSION or 0) .. s .. cleanChan(guild)
        .. s .. zone .. s .. itype .. s .. ilvl .. s .. note)
end

-- "P" party/team: composition only (leader first, max 5). Separate event so "H" stays small.
function GK.BroadcastParty()
    local s = GK.CHAN_SEP
    local party = (cleanChan(myGroupForBroadcast())):sub(1, 120)   -- "" when solo -> clears team at receivers
    GK.SendChan("P" .. s .. party)
end

-- Wolane z parsera kanalu (Events): pola juz rozbite.
function GK.ReceivePresence(sender, class, spec, adm, blk, ver, guild, zone, itype, ilvl, note)
    if class == "" then class = nil end
    if spec == "" then spec = nil end
    local k = normalizeName(sender)
    local prev = addonUsers[k]
    addonUsers[k] = {
        name = displayName(sender), class = class, spec = spec, t = GetTime(),
        admin = (adm == "1") or GK.IsSuperAdmin(sender), blocked = (blk == "1"),
        version = tonumber(ver) or 1,   -- brak wersji = stary klient
        guild = (guild and guild ~= "" and guild) or nil,
        zone = (zone and zone ~= "" and zone) or nil,
        itype = (itype and itype ~= "" and itype) or nil,
        ilvl = tonumber(ilvl) or nil,
        note = (note and note ~= "" and note) or nil,
        party = prev and prev.party or nil,   -- party comes from the "P" event; don't wipe it here
    }
    cacheUser(sender, class, spec)   -- zawsze pisz do trwalego cache (klasa/spec)
end

-- "P" event: update only the team composition on the existing presence entry.
function GK.ReceiveParty(sender, listStr)
    local u = addonUsers[normalizeName(sender)]
    if not u then return end   -- no presence yet; "P" follows "H" on the next cycle
    local plist = nil
    if listStr and listStr ~= "" then
        plist = {}
        for _, nm in ipairs({ strsplit(PARTY_SEP, listStr) }) do
            if nm and nm ~= "" then plist[#plist + 1] = nm end   -- [1] = leader
        end
        if #plist < 2 then plist = nil end   -- a "team" needs at least 2
    end
    u.party = plist
    u.t = GetTime()
end

-- Zrekonstruowane druzyny z presence (dla toggle "Party"). Zwraca:
--   teams  = lista { leader=display, members={ {name=canon, display=, addon=bool}, ... } }  (posort. po liderze)
--   teamed = set [normalizeName] = true dla WSZYSTKICH osob w teamach (do wykluczenia z kubelkow gildii)
-- Dedup po kanonicznym kluczu (posortowane znorm. nicki). Pomija team zawierajacy MNIE (moja grupa = sekcja "Party").
function GK.GetTeams()
    local now = GetTime()
    local meKey = normalizeName(GetUnitFullName("player"))
    local byKey = {}
    for _, u in pairs(addonUsers) do
        if u.party and (now - (u.t or 0)) <= PRESENCE_STALE then
            local keys = {}
            for _, nm in ipairs(u.party) do keys[#keys + 1] = normalizeName(nm) end
            table.sort(keys)
            local key = table.concat(keys, PARTY_SEP)
            if not byKey[key] then byKey[key] = u.party end   -- pierwszy wygrywa (lider = [1])
        end
    end
    local teams, teamed = {}, {}
    for _, plist in pairs(byKey) do
        local containsMe = false
        for _, nm in ipairs(plist) do if normalizeName(nm) == meKey then containsMe = true; break end end
        if not containsMe then
            local members = {}
            for _, nm in ipairs(plist) do
                local nk = normalizeName(nm)
                teamed[nk] = true
                members[#members + 1] = { name = nm, display = displayName(nm), addon = (addonUsers[nk] ~= nil) }
            end
            teams[#teams + 1] = { leader = displayName(plist[1]), members = members }
        end
    end
    table.sort(teams, function(a, b) return (a.leader or "") < (b.leader or "") end)
    return teams, teamed
end

-- ===== Global advert: auto guild ad on the "global" channel =====
-- Config { enabled, text, t } SHARED and synchronized LWW between permitted users (over GUILD).
-- Fixed interval; first fire after ADV_INTERVAL (not on login). Dedup: if someone broadcast in
-- the last cycle (advLastDoneAt), skip THIS fire (the timer keeps running).
local ADV_INTERVAL = 900   -- co 15 min (pierwszy fire po 15 min; tez okno dedup)
local ADV_CHANNEL = "global"
local ADV_SEP = "\031"
local advTicker, advLastDoneAt = nil, 0

local function advConfig()
    GigaKloceDB.guildAdv = GigaKloceDB.guildAdv or { enabled = false, text = "", t = 0 }
    return GigaKloceDB.guildAdv
end
function GK.GetAdvConfig() return advConfig() end

-- force = manual "Broadcast now" (skips enabled + dedup window; still needs permission/text/channel)
local function doAdvBroadcast(force)
    local c = advConfig()
    if not (GK.AmIAdmin and GK.AmIAdmin()) then if not force then GK.StopAdvTicker() end; return end
    if not force then
        if not c.enabled then GK.StopAdvTicker(); return end
        -- someone already broadcast this cycle? -> skip (the timer is NOT cancelled)
        if (GetTime() - (advLastDoneAt or 0)) < ADV_INTERVAL then return end
    end
    local text = (tostring(c.text or ""):gsub("[%c]", " "))
    text = (text:gsub("^%s+", ""):gsub("%s+$", ""))
    if text == "" then return end
    if #text > 255 then text = text:sub(1, 255) end
    local idx = GetChannelName(ADV_CHANNEL)
    if not idx or idx == 0 then GK.out("Advert: you're not on the '" .. ADV_CHANNEL .. "' channel — skipping."); return end
    SendChatMessage(text, "CHANNEL", nil, idx)
    if GK.Send then GK.Send(GK.MSG_ADVDONE, "GUILD") end   -- notify others (dedup)
end

function GK.StartAdvTicker()
    if advTicker then return end
    advTicker = C_Timer.NewTicker(ADV_INTERVAL, doAdvBroadcast)   -- first fire after ADV_INTERVAL
end
function GK.StopAdvTicker()
    if advTicker then advTicker:Cancel(); advTicker = nil end
end
-- someone announced they broadcast this cycle (mutes our next fire)
function GK.NoteAdvDone() advLastDoneAt = GetTime() end
-- manual immediate broadcast (e.g. from the "Broadcast now" menu)
function GK.AdvBroadcastNow() doAdvBroadcast(true) end

-- Wlacznik jest LOKALNY (kazdy admin decyduje u siebie; nie rozsylany).
function GK.SetAdvEnabled(enabled)
    local c = advConfig()
    c.enabled = enabled and true or false
    if c.enabled and GK.AmIAdmin and GK.AmIAdmin() then GK.StartAdvTicker() else GK.StopAdvTicker() end
end

-- Ustaw+rozglos TEKST (wspolny, LWW po GUILD). Wlacznik zostaje lokalny.
function GK.SetAdvConfig(enabled, text)
    local c = advConfig()
    if text ~= nil then c.text = tostring(text) end
    c.t = (GK.now and GK.now()) or 0
    if GK.Send then
        -- enabledBit wysylany tylko informacyjnie; odbiorcy go IGNORUJA (wlacznik lokalny)
        GK.Send(GK.MSG_ADVCFG .. c.t .. ADV_SEP .. (c.enabled and "1" or "0") .. ADV_SEP .. (c.text or ""), "GUILD")
    end
    if c.enabled and GK.AmIAdmin and GK.AmIAdmin() then GK.StartAdvTicker() else GK.StopAdvTicker() end
end

-- Odbior configu (LWW po t): aktualizuje TYLKO wspolny tekst. Wlacznik/ticker sa LOKALNE — nie ruszamy.
function GK.ReceiveAdvConfig(t, enBit, text)
    t = tonumber(t) or 0
    local c = advConfig()
    if t <= (c.t or 0) then return end   -- older/equal -> ignore
    c.t = t
    c.text = text or ""
end

-- Strefa + typ instancji gracza po nicku (siebie czytamy na zywo; innych z presence). zone, itype (lub nil).
function GK.ZoneOf(name)
    if not name then return nil end
    local n = normalizeName(name)
    if n == normalizeName(GetUnitFullName("player")) then
        local zone = (cleanChan(myZoneText())):sub(1, 40)
        local inInst, itype = IsInInstance()
        if not inInst then itype = "none" end
        return (zone ~= "" and zone) or nil, itype
    end
    local u = addonUsers[n]
    if u then return u.zone, u.itype end
    return nil
end

-- ilvl gracza po nicku (siebie na zywo; innych z presence). nil gdy nieznany.
function GK.IlvlOf(name)
    if not name then return nil end
    local n = normalizeName(name)
    if n == normalizeName(GetUnitFullName("player")) then
        local _, il = GetAverageItemLevel()
        return math.floor((il or 0) + 0.5)
    end
    local u = addonUsers[n]
    return u and u.ilvl
end

-- Publiczna notatka gildiowa gracza po nicku (siebie z rostera; innych z presence). nil/"" gdy brak.
function GK.NoteOf(name)
    if not name then return nil end
    local n = normalizeName(name)
    if n == normalizeName(GetUnitFullName("player")) then
        return (GK.MyGuildNote and GK.MyGuildNote()) or ""
    end
    local u = addonUsers[n]
    return u and u.note
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
    local full = GetUnitFullName(unit)
    if not full or full == "" then return end
    -- Tauri zwraca czasem CZASTKOWE/niezaladowane odczyty dla swiezych czlonkow grupy:
    -- "Yiik-" (realm jeszcze nie doszedl) albo "Unknown-Evermoon". Odrzuc je, inaczej ta sama
    -- osoba trafia pod dwa klucze (raz wlasny realm, raz docelowy) -> duplikaty na liscie.
    local namePart = strsplit("-", full, 2)
    if not namePart or namePart == "" or namePart == UNKNOWN then return end
    if full:sub(-1) == "-" then return end
    local key = normalizeName(full)
    if key == "" then return end
    local _, classFile = UnitClass(unit)
    local _, spec = GK.DetectClassSpec(full)   -- spec tylko jesli dane inspectu sa w cache; inaczej nil
    local rec = GK.playedWith[key] or {}
    rec.name = displayName(full)               -- spojnie z listami: chowa wlasny realm, pokazuje obcy
    if classFile and classFile ~= "" then rec.class = classFile end
    if spec and spec ~= "" then rec.spec = spec end
    rec.t = GK.now()
    GK.playedWith[key] = rec
    if (not rec.spec or rec.spec == "") and GK.RequestSpec then GK.RequestSpec(full) end  -- dociagnij spec na pozniej
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

-- ===== User flags =====
-- Send a flag update for a player (via whisper to the target; works cross-guild/realm).
function GK.SetUserFlags(targetName, admin, blocked)
    if not targetName or targetName == "" then return end
    local nm = (GK.canonicalDisplay and GK.canonicalDisplay(targetName)) or targetName
    -- Whisper to the target; the target applies the flag and rebroadcasts presence so everyone sees it.
    GK.Send(MSG_FLAG .. nm .. PRES_SEP .. (admin and "1" or "0") .. PRES_SEP .. (blocked and "1" or "0"), "WHISPER", nm)
end

-- Receive FLG: apply flags per sender permissions (privileged sender required).
function GK.ApplyFlag(sender, payload)
    local target, adm, blk = strsplit(PRES_SEP, payload or "", 3)
    if not target or target == "" then return end
    local superSender = GK.IsSuperAdmin(sender)
    local su = addonUsers[normalizeName(sender)]
    local allowedSender = superSender or (su and su.admin)
    if not allowedSender then return end   -- only a permitted sender may set anything
    local tkey = normalizeName(target)
    local tu = addonUsers[tkey]
    if tu then
        if superSender then tu.admin = (adm == "1") end
        tu.blocked = (blk == "1")
    end
    -- if I'm the target: set my flags and rebroadcast presence
    if tkey == normalizeName(GetUnitFullName("player")) then
        if superSender then GigaKloceDB.myAdmin = (adm == "1") end
        GigaKloceDB.myBlocked = (blk == "1")
        -- silent: nobody (not even the target) gets a message about the flag change
        if GK.BroadcastPresence then GK.BroadcastPresence() end
    end
    if KloceFrame and KloceFrame.mode == "active" then
        if KloceFrame.RefreshPartyList then KloceFrame.RefreshPartyList() end
        if KloceFrame.RefreshList then KloceFrame.RefreshList() end
    end
end

-- ===== Cross-guild announce relay =====
-- Sends text to a recipient in another guild; their client posts it to their guild chat ([via Nick] prefix).
function GK.SendGuildAnnounce(target, text)
    if not (GK.AmIAdmin and GK.AmIAdmin()) then return false end   -- not permitted: do nothing, reveal nothing
    if not target or target == "" then GK.out("Specify a recipient."); return false end
    text = (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
    if text == "" then GK.out("Empty announcement text."); return false end
    if #text > 230 then text = text:sub(1, 230) end   -- leave room for "[via Nick-Realm] " (guild chat limit 255)
    local to = (GK.canonicalDisplay and GK.canonicalDisplay(target)) or target
    GK.Send(GK.MSG_GANN .. text, "WHISPER", to)
    GK.out("Announcement sent to " .. displayName(to) .. " (will post to their guild chat).")
    return true
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
