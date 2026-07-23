-- ============================
-- GigaKloce :: Core (namespace, stale, stan, InitSaved)
-- ============================
local ADDON, GK = ...

GK.AddonPrefix = "GIGA_KLOCE"
-- Wersja MODELU DANYCH / formatu wiadomosci sync. Sync przyjmujemy tylko od tej samej wersji.
-- WAZNE: kazda zmiana formatu wiadomosci albo struktury danych MUSI podbic ten numer.
-- v3: presence+klucze przez wlasny kanal czatu (cross-guild); listy sync nadal po GUILD; directed WHISPER state transfer.
-- v4: cross-guild announce relay (WHISPER GAN -> recipient posts to their guild chat).
GK.DATA_VERSION = 4
-- Prefiksy wiadomosci sync po ADDON (GUILD/WHISPER), separator \031: K=kloce, C=chad; +=add, -=remove.
GK.MSG_KADD, GK.MSG_KREM = "K+:", "K-:"
GK.MSG_CADD, GK.MSG_CREM = "C+:", "C-:"
GK.MSG_GADD, GK.MSG_GREM = "G+:", "G-:"   -- sync listy blokowanych gildii
GK.MSG_SYNC = "SYNC?" -- directed (WHISPER) request for full state (in-guild pull)
GK.MSG_FLAG = "FLG:"  -- set user flags for a player
GK.MSG_BREQ = "BRQ"   -- directed: request state (WHISPER, privileged only)
GK.MSG_FSHARE = "FSH" -- directed: "do a share in your guild" (WHISPER, privileged only)
GK.MSG_GANN = "GAN:"  -- cross-guild announce relay: WHISPER -> recipient posts text to THEIR guild chat
GK.MSG_MHREQ = "MHR?" -- directed (WHISPER): super-admin requests target's M+ run history
GK.MSG_MHIST = "MHN"  -- directed (WHISPER) reply, chunked: MHN<seq>/<total>\031<data> (run history)
GK.MSG_ADVCFG = "ADVC:" -- advert config sync (enabled+text, LWW) over GUILD
GK.MSG_ADVDONE = "ADVD:" -- advert "broadcast this cycle" (dedup) over GUILD
GK.SUPER_ADMINS = { alvcard = true, dajkamienia = true, vilem = true, ryshard = true, soplice = true, nithalak = true, cwelownik = true }   -- privileged identities (name without realm, lowercase)

-- ===== Kanal czatu: presence + klucze (cross-guild). Addon-msg po kanale nie dziala na Tauri,
-- wiec idzie ZWYKLYM czatem (SendChatMessage) z drukowalnym separatorem; kanal ukryty z okien czatu. =====
GK.SYNC_CHANNEL = "OrtalionMplusSync"
GK.SYNC_CHANNEL_PW = ""        -- bez hasla
GK.CHAN_PFX = "GK~"            -- magiczny prefiks naszych linii na kanale
GK.CHAN_SEP = "~"              -- separator pol (drukowalny; czat tnie znaki niedrukowalne)
GK.guildKeys = {}     -- ulotne: [normalizeName] = {name, dungeon, level, t}
GK.addonUsers = {}    -- ulotne: [normalizeName] = {name, class, spec, t} (kto ma addon, online TERAZ)
GK.userCache = {}     -- TRWALY cache: [normalizeName] = {name, class, spec, t} (z presence; do presetow/list)
GK.playedWith = {}    -- ULOTNE: [normalizeName] = {name, class, spec, t} (ludzie z party/raid; podpowiedzi w Add) — NIE zapisywane

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
    if GigaKloceDB.dpsSuggest == nil then GigaKloceDB.dpsSuggest = true end  -- sugestie chad/kloc po M+ wg DPS
    GigaKloceDB.myDungeons = GigaKloceDB.myDungeons or {}   -- moj rekord M+: highest key + ostatni przebieg (kanal "D")
    GigaKloceDB.myAdmin = GigaKloceDB.myAdmin or false      -- my privileged flag
    GigaKloceDB.myBlocked = GigaKloceDB.myBlocked or false  -- am I blocked (don't send sync)
    -- trwaly cache uzytkownikow z addonem (klasa/spec) — zasilany przez presence, czytany przez presety/listy
    GigaKloceDB.userCache = GigaKloceDB.userCache or {}
    wipe(GK.userCache); for k, v in pairs(GigaKloceDB.userCache) do GK.userCache[k] = v end
    GigaKloceDB.userCache = GK.userCache
    -- "last played with" jest ULOTNE (tylko GK.playedWith w pamieci) — nie zapisujemy go do DB.
    -- Usun ewentualny wpis z wczesniejszych testow, zeby nie smiecil w SavedVariables.
    GigaKloceDB.playedWith = nil
    -- lista blokowanych gildii (auto-kloc przy aplikacji do premade)
    GigaKloceDB.blockedGuilds = GigaKloceDB.blockedGuilds or {}
    -- advert: shared config { enabled, text, t } synchronized LWW between permitted users
    GigaKloceDB.guildAdv = GigaKloceDB.guildAdv or { enabled = false, text = "", t = 0 }
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
