-- ============================
-- GigaKloce :: Snapshots (dzienne kopie, import)
-- ============================
local ADDON, GK = ...
local AddonPrefix, MSG_KADD, MSG_KREM, MSG_CADD, MSG_CREM, KLOCE_TAGS, DEFAULT_TAG, TAG_COLORS, TAG_ICONS, gigakloce, gigachad, gigakloceInfo, sessionKloceToStay, promptedKloce, InitSaved, log, normalizeName, canonicalDisplay, displayName, GetUnitFullName, ensureRealm, has_value, getIndex, RosterUnitName, ClassifyMember, HasKloceInGroup, UpdateKloceAlert, DetectKloceInGroup, GetGroupLeadersAndAssistants, RefreshUI, EnsureKloceInfo, GetKloceInfo, KLOCE_SEP, BroadcastKloceDetails, AddKloce, RemoveKloce, AddChad, RemoveChad, sendRepartyLeader = GK.AddonPrefix, GK.MSG_KADD, GK.MSG_KREM, GK.MSG_CADD, GK.MSG_CREM, GK.KLOCE_TAGS, GK.DEFAULT_TAG, GK.TAG_COLORS, GK.TAG_ICONS, GK.gigakloce, GK.gigachad, GK.gigakloceInfo, GK.sessionKloceToStay, GK.promptedKloce, GK.InitSaved, GK.log, GK.normalizeName, GK.canonicalDisplay, GK.displayName, GK.GetUnitFullName, GK.ensureRealm, GK.has_value, GK.getIndex, GK.RosterUnitName, GK.ClassifyMember, GK.HasKloceInGroup, GK.UpdateKloceAlert, GK.DetectKloceInGroup, GK.GetGroupLeadersAndAssistants, GK.RefreshUI, GK.EnsureKloceInfo, GK.GetKloceInfo, GK.KLOCE_SEP, GK.BroadcastKloceDetails, GK.AddKloce, GK.RemoveKloce, GK.AddChad, GK.RemoveChad, GK.sendRepartyLeader

-- ============================
-- SNAPSHOTY (dzienne kopie, max 10, rolling) â€” siatka bezpieczenstwa
-- ============================
local function copyList(t)
    local r = {}
    for i, v in ipairs(t) do r[i] = v end
    return r
end
local function copyInfo(t)
    local r = {}
    for k, v in pairs(t) do r[k] = { tag = v.tag, note = v.note, added = v.added, by = v.by, class = v.class, spec = v.spec } end
    return r
end
-- gleboka kopia presetow party: nazwa -> { nicki }
local function copyPresets(t)
    local r = {}
    for name, members in pairs(t or {}) do
        local m = {}
        for i, v in ipairs(members) do m[i] = v end
        r[name] = m
    end
    return r
end

-- Robi snapshot raz na dzien (na wejscie): jak nie ma dzisiejszego, zapisuje. Max 10, najstarszy leci.
-- force=true: nadpisz dzisiejszy snapshot biezacym stanem (reczne przegenerowanie).
-- Backupuje WSZYSTKIE nasze dane: Kloce, Chady, detale (tag/note/class/spec), blokowane gildie, presety party.
local function MakeDailySnapshot(force)
    local today = (type(date) == "function" and date("%Y-%m-%d")) or nil
    if not today then return end
    local snaps = GigaKloceDB.snapshots
    for i = #snaps, 1, -1 do
        if snaps[i].date == today then
            if not force then return end       -- dzisiejszy juz jest, nie ruszamy
            table.remove(snaps, i)             -- force: usun dzisiejszy, zapiszemy swiezy
        end
    end
    table.insert(snaps, {
        date = today,
        lista = copyList(gigakloce),
        chads = copyList(gigachad),
        info  = copyInfo(gigakloceInfo),
        blockedGuilds = copyList(GigaKloceDB.blockedGuilds or {}),
        presets = copyPresets(GigaKloceDB.partyPresets),
        partyCurrent = GigaKloceDB.partyCurrent,
    })
    while #snaps > 10 do table.remove(snaps, 1) end
    if force then
        GK.out("Snapshot regenerated for " .. today .. " (" .. #gigakloce .. "K / " .. #gigachad .. "C / "
            .. #(GigaKloceDB.blockedGuilds or {}) .. "G).")
    end
end

-- Przywraca snapshot LOKALNIE. Aby import "wygral" przy nastepnym sync (ochrona przed trollem):
-- wszystkim przywroconym wpisom nadajemy czas = TERAZ, a to czego w snapshocie NIE ma -> nagrobek (teraz).
-- Pola, ktorych snapshot nie ma (stare backupy), nie sa ruszane.
local function RestoreSnapshot(snap)
    if not snap then return end
    local now = (GetServerTime and GetServerTime()) or time()

    -- zapamietaj obecne klucze (przed nadpisaniem), by te usuniete przez import dostaly nagrobek
    local oldKeys = {}
    for _, v in ipairs(gigakloce) do oldKeys[normalizeName(v)] = true end
    for _, v in ipairs(gigachad)  do oldKeys[normalizeName(v)] = true end

    wipe(gigakloce);     for _, v in ipairs(snap.lista or {}) do table.insert(gigakloce, v) end
    wipe(gigachad);      for _, v in ipairs(snap.chads or {}) do table.insert(gigachad, v) end
    wipe(gigakloceInfo); for k, v in pairs(snap.info or {}) do
        gigakloceInfo[k] = { tag = v.tag, note = v.note, added = v.added, by = v.by, class = v.class, spec = v.spec, t = now }
    end
    -- nagrobki: dla wszystkiego, co bylo a teraz juz nie ma (po imporcie)
    GigaKloceDB.tombstones = GigaKloceDB.tombstones or {}
    for key in pairs(oldKeys) do
        if not gigakloceInfo[key] then GigaKloceDB.tombstones[key] = now end
    end
    -- a obecnym wpisom wyczysc ewentualne nagrobki
    for key in pairs(gigakloceInfo) do GigaKloceDB.tombstones[key] = nil end

    -- blokowane gildie (tylko jesli snapshot je ma)
    if snap.blockedGuilds then
        local oldG = {}
        for _, g in ipairs(GigaKloceDB.blockedGuilds or {}) do oldG[string.lower(g)] = true end
        GigaKloceDB.blockedGuilds = GigaKloceDB.blockedGuilds or {}
        GigaKloceDB.guildTs = GigaKloceDB.guildTs or {}
        GigaKloceDB.guildTomb = GigaKloceDB.guildTomb or {}
        wipe(GigaKloceDB.blockedGuilds)
        local newG = {}
        for _, g in ipairs(snap.blockedGuilds) do
            table.insert(GigaKloceDB.blockedGuilds, g)
            local lg = string.lower(g)
            newG[lg] = true
            GigaKloceDB.guildTs[lg] = now
            GigaKloceDB.guildTomb[lg] = nil
        end
        for lg in pairs(oldG) do
            if not newG[lg] then GigaKloceDB.guildTomb[lg] = now; GigaKloceDB.guildTs[lg] = nil end
        end
    end
    -- presety party (tylko jesli snapshot je ma)
    if snap.presets then
        GigaKloceDB.partyPresets = GigaKloceDB.partyPresets or {}
        wipe(GigaKloceDB.partyPresets)
        for name, members in pairs(snap.presets) do
            local m = {}
            for i, v in ipairs(members) do m[i] = v end
            GigaKloceDB.partyPresets[name] = m
        end
        if not next(GigaKloceDB.partyPresets) then GigaKloceDB.partyPresets["Main"] = {} end
        if snap.partyCurrent and GigaKloceDB.partyPresets[snap.partyCurrent] then
            GigaKloceDB.partyCurrent = snap.partyCurrent
        else
            GigaKloceDB.partyCurrent = next(GigaKloceDB.partyPresets)
        end
    end
    if GK.SanitizeInfo then GK.SanitizeInfo() end   -- napraw stare, sklejone detale z importu
    RefreshUI()
    UpdateKloceAlert()
    if KloceFrame and KloceFrame.RefreshBlockedGuilds then KloceFrame.RefreshBlockedGuilds() end
    if KloceFrame and KloceFrame.SetMode and KloceFrame.mode then KloceFrame.SetMode(KloceFrame.mode) end  -- odswiez preset dropdown itp.
    log("Snapshot restored: " .. (snap.date or "?") .. " (" .. #gigakloce .. " kloce, " .. #gigachad .. " chads, "
        .. #(snap.blockedGuilds or {}) .. " guilds)")
    -- wypchnij przywrocony (zwycieski) stan do ekipy
    if GK.FullBroadcast then GK.FullBroadcast(true) end
end


-- eksport do namespace
GK.MakeDailySnapshot, GK.RestoreSnapshot = MakeDailySnapshot, RestoreSnapshot
