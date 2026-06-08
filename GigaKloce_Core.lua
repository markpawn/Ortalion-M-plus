-- ============================
-- GigaKloce :: Core (namespace, stale, stan, InitSaved)
-- ============================
local ADDON, GK = ...

GK.AddonPrefix = "GIGA_KLOCE"
-- Wersja MODELU DANYCH / formatu wiadomosci sync. Sync przyjmujemy tylko od tej samej wersji.
-- WAZNE: kazda zmiana formatu wiadomosci albo struktury danych MUSI podbic ten numer.
GK.DATA_VERSION = 2
-- Prefiksy wiadomosci sync (3 znaki): K=kloce, C=chad; +=add, -=remove.
GK.MSG_KADD, GK.MSG_KREM = "K+:", "K-:"
GK.MSG_CADD, GK.MSG_CREM = "C+:", "C-:"
GK.MSG_GADD, GK.MSG_GREM = "G+:", "G-:"   -- sync listy blokowanych gildii
GK.MSG_KEY = "KEY:"   -- rozglaszanie wlasnego klucza M+ (cicho, GUILD)
GK.MSG_HI  = "HI:"    -- presence: "jestem online z addonem"
GK.MSG_HIQ = "HI?"    -- prosba o presence (kto online) — do wyboru zrodla sync
GK.MSG_SYNC = "SYNC?" -- skierowana (WHISPER) prosba o pelny stan do wybranej osoby
GK.MSG_FLAG = "FLG:"  -- ustawienie flag admin/blocked dla gracza (przez admina)
GK.SUPER_ADMIN = "alvcard"   -- super admin (nazwa bez realmu, lowercase): zawsze admin, nigdy blocked
GK.guildKeys = {}     -- ulotne: [normalizeName] = {name, dungeon, level, t}
GK.addonUsers = {}    -- ulotne: [normalizeName] = {name, class, spec, t} (kto ma addon, online TERAZ)
GK.userCache = {}     -- TRWALY cache: [normalizeName] = {name, class, spec, t} (z presence; do presetow/list)

GK.KLOCE_TAGS = { "noob", "leaver", "debil", "ninja" }
GK.DEFAULT_TAG = "noob"
GK.TAG_COLORS = {   -- tlo "chipa" per tag
    noob   = { 0.50, 0.50, 0.50 },
    leaver = { 0.80, 0.25, 0.20 },
    debil = { 0.85, 0.50, 0.15 },
    ninja  = { 0.45, 0.30, 0.65 },
}
-- Ikona per tag (bez rozszerzenia — WoW doklei .blp; PNG nie zadziala!).
local ASSET = "Interface\\AddOns\\GigaKloce\\assets\\"
GK.TAG_ICONS = {
    noob   = ASSET .. "nieumyty",
    leaver = ASSET .. "kargullowanie",
    debil = ASSET .. "honk",
    ninja  = ASSET .. "yikes",
}

-- Stabilne tabele stanu. Inne pliki je aliasuja (local x = GK.x), dlatego InitSaved
-- WYPELNIA je w miejscu (wipe+insert), a nie podmienia referencji.
GK.gigakloce = {}
GK.gigachad = {}
GK.gigakloceInfo = {}   -- boczne detale Kloce: [normalizeName] = {tag, note, added, by}
GK.sessionKloceToStay = {}
GK.promptedKloce = {}   -- klocki, dla ktorych popup juz wyskoczyl w obecnym skladzie

function GK.InitSaved()
    GigaKloceDB = GigaKloceDB or {}
    GigaKloceDB.lista = GigaKloceDB.lista or {}
    GigaKloceDB.chads = GigaKloceDB.chads or {}
    GigaKloceDB.info  = GigaKloceDB.info or {}
    GigaKloceDB.snapshots = GigaKloceDB.snapshots or {}
    -- presety skladu (Party): nazwa -> { nicki }. Zawsze min. jeden ("Main").
    GigaKloceDB.partyPresets = GigaKloceDB.partyPresets or {}
    if not next(GigaKloceDB.partyPresets) then GigaKloceDB.partyPresets["Main"] = {} end
    if not GigaKloceDB.partyPresets[GigaKloceDB.partyCurrent or ""] then
        GigaKloceDB.partyCurrent = next(GigaKloceDB.partyPresets)
    end
    -- wypelnij stabilne tabele danymi z zapisu (bez podmiany referencji)
    wipe(GK.gigakloce);     for _, v in ipairs(GigaKloceDB.lista) do table.insert(GK.gigakloce, v) end
    wipe(GK.gigachad);      for _, v in ipairs(GigaKloceDB.chads) do table.insert(GK.gigachad, v) end
    wipe(GK.gigakloceInfo); for k, v in pairs(GigaKloceDB.info) do GK.gigakloceInfo[k] = v end
    -- migracja starego tagu: mooron -> debil
    for _, v in pairs(GK.gigakloceInfo) do if v.tag == "mooron" then v.tag = "debil" end end
    -- przepnij zapis na nasze stabilne tabele (one ida do SavedVariables)
    GigaKloceDB.lista = GK.gigakloce
    GigaKloceDB.chads = GK.gigachad
    GigaKloceDB.info  = GK.gigakloceInfo
    GigaKloceDB.silent = GigaKloceDB.silent or false
    if GigaKloceDB.acceptSync == nil then GigaKloceDB.acceptSync = true end  -- przyjmuj sync od innych
    GigaKloceDB.debug = GigaKloceDB.debug or false   -- gadatliwe logi (domyslnie cicho)
    GigaKloceDB.myAdmin = GigaKloceDB.myAdmin or false      -- czy mam flage admin (nadaje Alvcard)
    GigaKloceDB.myBlocked = GigaKloceDB.myBlocked or false  -- czy jestem zablokowany (nie wysylam sync)
    -- trwaly cache uzytkownikow z addonem (klasa/spec) — zasilany przez presence, czytany przez presety/listy
    GigaKloceDB.userCache = GigaKloceDB.userCache or {}
    wipe(GK.userCache); for k, v in pairs(GigaKloceDB.userCache) do GK.userCache[k] = v end
    GigaKloceDB.userCache = GK.userCache
    -- lista blokowanych gildii (auto-kloc przy aplikacji do premade)
    GigaKloceDB.blockedGuilds = GigaKloceDB.blockedGuilds or {}
    -- preferowane zrodlo sync (opcjonalne): nick, od ktorego joiner woli ciagnac stan. nil = auto.
    -- GigaKloceDB.syncSource

    -- sprzataj rozjechane/kontrolne wpisy z poprzednich, blednych syncow.
    -- Odrzuca znaki kontrolne ORAZ ? : + (maja je nasze prefiksy: HI?, SYNC?, K+:, FLG:...), a nick/gildia nie.
    local function bad(s) return type(s) ~= "string" or s == "" or s:find("[%z\001-\031?:+]") ~= nil end
    for i = #GK.gigakloce, 1, -1 do if bad(GK.gigakloce[i]) then table.remove(GK.gigakloce, i) end end
    for i = #GK.gigachad,  1, -1 do if bad(GK.gigachad[i])  then table.remove(GK.gigachad,  i) end end
    for k in pairs(GK.gigakloceInfo) do if bad(k) then GK.gigakloceInfo[k] = nil end end
    for i = #GigaKloceDB.blockedGuilds, 1, -1 do if bad(GigaKloceDB.blockedGuilds[i]) then table.remove(GigaKloceDB.blockedGuilds, i) end end
    -- napraw stare, sklejone detale (np. by="Nick HUNTER Survival" -> class/spec/by)
    if GK.SanitizeInfo then GK.SanitizeInfo() end

    -- ===== Sync: znaczniki czasu + nagrobki (tombstones) =====
    -- Czas: GetServerTime() (jednolity dla wszystkich na realmie). "Nowsze wygrywa" dziala
    -- dla DODAWANIA i USUWANIA, wiec usuniecie nie "zmartwychwstaje" przy reconcile.
    GigaKloceDB.tombstones = GigaKloceDB.tombstones or {}   -- [normKey] = czas usuniecia (kloce/chad)
    GigaKloceDB.guildTs    = GigaKloceDB.guildTs or {}      -- [lowerGuild] = czas dodania
    GigaKloceDB.guildTomb  = GigaKloceDB.guildTomb or {}    -- [lowerGuild] = czas usuniecia
    local now = (GetServerTime and GetServerTime()) or time()
    -- migracja: nadaj brakujace znaczniki czasu istniejacym wpisom i gildiom
    for _, v in pairs(GK.gigakloceInfo) do if not v.t then v.t = now end end
    for _, g in ipairs(GigaKloceDB.blockedGuilds) do
        local lg = string.lower(g)
        if not GigaKloceDB.guildTs[lg] then GigaKloceDB.guildTs[lg] = now end
    end
    -- przytnij stare nagrobki (>60 dni), zeby nie rosly w nieskonczonosc
    local CUTOFF = 60 * 24 * 3600
    for k, t in pairs(GigaKloceDB.tombstones) do if now - (t or 0) > CUTOFF then GigaKloceDB.tombstones[k] = nil end end
    for k, t in pairs(GigaKloceDB.guildTomb) do if now - (t or 0) > CUTOFF then GigaKloceDB.guildTomb[k] = nil end end
end
