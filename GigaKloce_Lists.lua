-- ============================
-- GigaKloce :: Lists (add/remove/info, broadcast, RefreshUI)
-- ============================
local ADDON, GK = ...
local AddonPrefix, MSG_KADD, MSG_KREM, MSG_CADD, MSG_CREM, KLOCE_TAGS, DEFAULT_TAG, TAG_COLORS, TAG_ICONS, gigakloce, gigachad, gigakloceInfo, sessionKloceToStay, promptedKloce, InitSaved, log, normalizeName, canonicalDisplay, displayName, GetUnitFullName, ensureRealm, has_value, getIndex, RosterUnitName, ClassifyMember, HasKloceInGroup, UpdateKloceAlert, DetectKloceInGroup, GetGroupLeadersAndAssistants = GK.AddonPrefix, GK.MSG_KADD, GK.MSG_KREM, GK.MSG_CADD, GK.MSG_CREM, GK.KLOCE_TAGS, GK.DEFAULT_TAG, GK.TAG_COLORS, GK.TAG_ICONS, GK.gigakloce, GK.gigachad, GK.gigakloceInfo, GK.sessionKloceToStay, GK.promptedKloce, GK.InitSaved, GK.log, GK.normalizeName, GK.canonicalDisplay, GK.displayName, GK.GetUnitFullName, GK.ensureRealm, GK.has_value, GK.getIndex, GK.RosterUnitName, GK.ClassifyMember, GK.HasKloceInGroup, GK.UpdateKloceAlert, GK.DetectKloceInGroup, GK.GetGroupLeadersAndAssistants

-- Odswieza otwarte UI (listy czytaja aktywny tryb same).
local function RefreshUI()
    if KloceFrame and KloceFrame.RefreshList then KloceFrame.RefreshList() end
    if KloceFrame and KloceFrame.RefreshPartyList then KloceFrame.RefreshPartyList() end
end

-- Detale gracza (boczna tabela, wspolna dla Kloce i Chadow). Tworzy domyslny wpis gdy brak.
-- tag ma sens tylko dla Kloce; class/spec dla obu (auto-wykrywane gdy gracz jest w poblizu).
local function EnsureKloceInfo(name, by)
    local k = normalizeName(name)
    if k == "" then return nil end
    local info = gigakloceInfo[k]
    if not info then
        local stamp = (type(date) == "function" and date("%Y-%m-%d %H:%M")) or "?"
        info = { tag = DEFAULT_TAG, note = "", added = stamp, by = by or "", class = "", spec = "", t = GK.now() }
        gigakloceInfo[k] = info
    elseif by and by ~= "" and (not info.by or info.by == "") then
        info.by = by
    end
    -- auto-wykrycie klasy/specu, gdy brak (gracz online w party/raid/target/...)
    if (not info.class or info.class == "") and GK.DetectClassSpec then
        local cls, spec = GK.DetectClassSpec(name)
        if cls and cls ~= "" then info.class = cls end
        if spec and spec ~= "" and (not info.spec or info.spec == "") then info.spec = spec end
    end
    -- spec cudzej postaci wymaga inspectu (async) — zlec, jesli wciaz brak i gracz w poblizu
    if (not info.spec or info.spec == "") and GK.RequestSpec then GK.RequestSpec(name) end
    return info
end
local function GetKloceInfo(name) return gigakloceInfo[normalizeName(name)] end

local KLOCE_SEP = "\031"   -- unit separator (nie wystepuje w nickach/tagach)
local function san(s) return (tostring(s or "")):gsub("[%c]", " ") end
-- Czy nick jest "czysty"? Odrzuca znaki kontrolne ORAZ ? : + (zaden prawdziwy nick/gildia ich nie ma,
-- ale maja je WSZYSTKIE nasze prefiksy wiadomosci: HI?, SYNC?, K+:, G+:, FLG: ...). Chroni przed
-- zapisaniem wiadomosci kontrolnej / rozjechanego ladunku jako nicku.
local function isClean(name)
    return name and name ~= "" and not tostring(name):find("[%z\001-\031?:+]")
end

-- ===== Nagrobki (tombstones) i porownania czasu =====
local function clearTomb(key) GigaKloceDB.tombstones[key] = nil end
local function setTomb(key, t)
    local cur = GigaKloceDB.tombstones[key]
    if not cur or (t or 0) > cur then GigaKloceDB.tombstones[key] = t end
end
-- znany czas dla klucza: info.t gdy obecny, inaczej nagrobek, inaczej nil
local function knownTs(key)
    local info = gigakloceInfo[key]
    if info and info.t then return info.t, "present" end
    local tomb = GigaKloceDB.tombstones[key]
    if tomb then return tomb, "tomb" end
    return nil, nil
end
-- czy zdarzenie o czasie ts moze nadpisac obecny stan (LWW; usuniecie wygrywa remisy)
local function canApply(key, ts)
    local cur, kind = knownTs(key)
    if not cur then return true end
    if kind == "tomb" then return ts > cur end
    return ts >= cur
end

-- ===== Broadcasty (z czasem; przez throttlowana kolejke GK.Send) =====
-- channel/target opcjonalne: domyslnie GUILD, dla skierowanej odpowiedzi -> ("WHISPER", nick).
-- K+: name \031 tag \031 note \031 added \031 by \031 class \031 spec \031 t
local function BroadcastKloceDetails(name, channel, target)
    if GK.CanBroadcast and not GK.CanBroadcast() then return end   -- blocked = nie wysylam danych
    if not has_value(gigakloce, name) then return end
    local info = gigakloceInfo[normalizeName(name)] or {}
    local note = san(info.note):sub(1, 70)
    GK.Send(MSG_KADD .. canonicalDisplay(name) .. KLOCE_SEP .. (info.tag or DEFAULT_TAG) .. KLOCE_SEP .. note
        .. KLOCE_SEP .. san(info.added) .. KLOCE_SEP .. san(info.by)
        .. KLOCE_SEP .. san(info.class) .. KLOCE_SEP .. san(info.spec)
        .. KLOCE_SEP .. (info.t or GK.now()), channel, target)
end
-- C+: name \031 note \031 added \031 by \031 class \031 spec \031 t (bez tagu)
local function BroadcastChadDetails(name, channel, target)
    if GK.CanBroadcast and not GK.CanBroadcast() then return end   -- blocked = nie wysylam danych
    if not has_value(gigachad, name) then return end
    local info = gigakloceInfo[normalizeName(name)] or {}
    local note = san(info.note):sub(1, 70)
    GK.Send(MSG_CADD .. canonicalDisplay(name) .. KLOCE_SEP .. note
        .. KLOCE_SEP .. san(info.added) .. KLOCE_SEP .. san(info.by)
        .. KLOCE_SEP .. san(info.class) .. KLOCE_SEP .. san(info.spec)
        .. KLOCE_SEP .. (info.t or GK.now()), channel, target)
end
-- K-: key \031 t (usuniecie; list-agnostyczne, odbiorca kasuje z obu list i stawia nagrobek)
local function BroadcastRemove(key, t, channel, target)
    if GK.CanBroadcast and not GK.CanBroadcast() then return end   -- blocked = nie wysylam danych
    GK.Send(MSG_KREM .. key .. KLOCE_SEP .. (t or GK.now()), channel, target)
end

-- Generyczne prymitywy listy (bez broadcastu/nagrobka).
local function AddToList(tab, name, silent, label, isKloce, by)
    if not isClean(name) then return false end   -- nie zapisuj rozjechanego ladunku jako nicku
    local n = normalizeName(name)
    if n == "" then return false end
    if n == normalizeName(GetUnitFullName("player")) then
        if not silent then log("You cannot add yourself.") end
        return false
    end
    if not has_value(tab, n) then
        local stored = canonicalDisplay(name)
        table.insert(tab, stored)
        EnsureKloceInfo(stored, by)
        if not silent then log("Added " .. displayName(stored) .. " to " .. label) end
        RefreshUI()
        if isKloce then UpdateKloceAlert() end
        return true
    else
        if not silent then log(displayName(canonicalDisplay(name)) .. " is already on the " .. label .. " list.") end
        return false
    end
end

-- keepInfo=true: NIE kasuj detali (przenosiny kloce<->chad zachowuja class/spec).
local function RemoveFromList(tab, name, silent, label, isKloce, keepInfo)
    local idx = getIndex(tab, name)
    if idx then
        local removed = table.remove(tab, idx)
        if not keepInfo then gigakloceInfo[normalizeName(removed)] = nil end
        if not silent then log("Removed " .. displayName(removed) .. " from " .. label) end
        RefreshUI()
        if isKloce then UpdateKloceAlert() end
        return true
    else
        if not silent then log(displayName(canonicalDisplay(name)) .. " is not on the " .. label .. " list.") end
        return false
    end
end

-- ===== Lokalne akcje uzytkownika (ustawiaja czas serwera + nagrobki, broadcastuja gdy not silent) =====
local function RemoveKloce(name, silent)
    local ok = RemoveFromList(gigakloce, name, silent, "Kloce", true, false)
    if ok then
        local key, t = normalizeName(name), GK.now()
        setTomb(key, t)
        if not silent then BroadcastRemove(key, t) end
    end
    return ok
end
local function RemoveChad(name, silent)
    local ok = RemoveFromList(gigachad, name, silent, "Chads", false, false)
    if ok then
        local key, t = normalizeName(name), GK.now()
        setTomb(key, t)
        if not silent then BroadcastRemove(key, t) end
    end
    return ok
end

-- Listy wzajemnie wykluczajace sie: dodanie do jednej usuwa z drugiej.
-- not silent: ustaw czas = teraz, wyczysc nagrobek, rozeslij pelne detale.
local function AddKloce(name, silent, by)
    local who = (by and by ~= "" and by) or displayName(GetUnitFullName("player"))
    local ok = AddToList(gigakloce, name, silent, "Kloce", true, who)
    local moved = RemoveFromList(gigachad, name, true, "Chads", false, true)   -- keepInfo
    local info = EnsureKloceInfo(name, who)
    clearTomb(normalizeName(name))
    if moved and not silent then log(displayName(canonicalDisplay(name)) .. " moved from Chads to Kloce.") end
    if not silent then
        if info then info.t = GK.now() end
        BroadcastKloceDetails(name)
    end
    return ok
end

local function AddChad(name, silent, by)
    local who = (by and by ~= "" and by) or displayName(GetUnitFullName("player"))
    local ok = AddToList(gigachad, name, silent, "Chads", false, who)
    local moved = RemoveFromList(gigakloce, name, true, "Kloce", true, true)   -- keepInfo
    local info = EnsureKloceInfo(name, who)
    clearTomb(normalizeName(name))
    if moved and not silent then log(displayName(canonicalDisplay(name)) .. " moved from Kloce to Chads.") end
    if not silent then
        if info then info.t = GK.now() end
        BroadcastChadDetails(name)
    end
    return ok
end

-- Dodanie z podpowiedzi "played with": dodaj wg trybu i nanies klase/spec (z rekordu lub live/cache).
function GK.AddPlayedWith(name, isChad, class, spec)
    if not name or name == "" then return end
    if isChad then AddChad(name) else AddKloce(name) end
    local info = gigakloceInfo[normalizeName(name)]
    if info then
        class = (class and class ~= "" and class) or (GK.ClassOf and GK.ClassOf(name)) or nil
        spec  = (spec  and spec  ~= "" and spec ) or (GK.SpecOf  and GK.SpecOf(name))  or nil
        local changed = false
        if class and class ~= "" and info.class ~= class then info.class = class; changed = true end
        if spec  and spec  ~= "" and info.spec  ~= spec  then info.spec  = spec;  changed = true end
        if changed then
            info.t = GK.now()
            if isChad then BroadcastChadDetails(name) else BroadcastKloceDetails(name) end
        end
    end
    if RefreshUI then RefreshUI() end
end

-- ===== Zastosowanie zdalnych zmian (LWW; BEZ rozsylania dalej) =====
function GK.ApplyRemoteKloce(name, ts, tag, note, added, by, class, spec)
    if not isClean(name) then return false end
    local key = normalizeName(name)
    if not canApply(key, ts) then return false end
    if not has_value(gigakloce, name) then table.insert(gigakloce, canonicalDisplay(name)) end
    local ci = getIndex(gigachad, name); if ci then table.remove(gigachad, ci) end
    clearTomb(key)
    local info = EnsureKloceInfo(name, by)
    if info then
        if tag and tag ~= "" then info.tag = tag end
        if note ~= nil then info.note = note end
        if added and added ~= "" then info.added = added end
        if by and by ~= "" then info.by = by end
        if class and class ~= "" then info.class = class end
        if spec and spec ~= "" then info.spec = spec end
        info.t = ts
    end
    RefreshUI(); UpdateKloceAlert()
    return true
end

function GK.ApplyRemoteChad(name, ts, note, added, by, class, spec)
    if not isClean(name) then return false end
    local key = normalizeName(name)
    if not canApply(key, ts) then return false end
    if not has_value(gigachad, name) then table.insert(gigachad, canonicalDisplay(name)) end
    local ki = getIndex(gigakloce, name); if ki then table.remove(gigakloce, ki) end
    clearTomb(key)
    local info = EnsureKloceInfo(name, by)
    if info then
        if note ~= nil then info.note = note end
        if added and added ~= "" then info.added = added end
        if by and by ~= "" then info.by = by end
        if class and class ~= "" then info.class = class end
        if spec and spec ~= "" then info.spec = spec end
        info.t = ts
    end
    RefreshUI(); UpdateKloceAlert()
    return true
end

function GK.ApplyRemoteRemove(name, ts)
    local key = normalizeName(name)
    if not canApply(key, ts) then return false end
    local ki = getIndex(gigakloce, name); if ki then table.remove(gigakloce, ki) end
    local ci = getIndex(gigachad, name); if ci then table.remove(gigachad, ci) end
    gigakloceInfo[key] = nil
    setTomb(key, ts)
    RefreshUI(); UpdateKloceAlert()
    return true
end

local function sendRepartyLeader()
	-- WAZNE: od razu, NIE przez throttlowana kolejke — inaczej kick (natychmiastowy) dojdzie
	-- do czlonka przed REPARTY i auto-accept nie zadziala.
	SendAddonMessage(AddonPrefix, "REPARTY", "GUILD")
end

-- ===== Pelny sync: obecne wpisy + nagrobki + gildie. =====
-- channel/target: domyslnie GUILD (broadcast). Dla skierowanej odpowiedzi -> ("WHISPER", nick).
-- Throttle 30s dotyczy tylko broadcastu (force pomija); odpowiedzi skierowane sa zawsze.
local lastFull = 0
local function FullBroadcast(force, channel, target)
    if GK.CanBroadcast and not GK.CanBroadcast() then return end   -- blocked = nie wysylam danych
    local n = GK.now()
    local directed = (channel ~= nil)
    if not force and not directed and (n - lastFull) < 30 then return end
    if not directed then lastFull = n end
    for _, v in ipairs(gigakloce) do if v ~= "" then BroadcastKloceDetails(v, channel, target) end end
    for _, v in ipairs(gigachad)  do if v ~= "" then BroadcastChadDetails(v, channel, target) end end
    for key, t in pairs(GigaKloceDB.tombstones or {}) do GK.Send(MSG_KREM .. key .. KLOCE_SEP .. (t or n), channel, target) end
    local guilds = (GK.GetBlockedGuilds and GK.GetBlockedGuilds()) or {}
    for _, g in ipairs(guilds) do
        GK.Send(GK.MSG_GADD .. g .. KLOCE_SEP .. ((GigaKloceDB.guildTs and GigaKloceDB.guildTs[string.lower(g)]) or n), channel, target)
    end
    for lg, t in pairs(GigaKloceDB.guildTomb or {}) do GK.Send(GK.MSG_GREM .. lg .. KLOCE_SEP .. (t or n), channel, target) end
    log("Sync sent" .. (directed and (" to " .. tostring(target)) or "") .. ": "
        .. #gigakloce .. " kloce + " .. #gigachad .. " chads + " .. #guilds .. " guilds.")
end

-- ===== Naprawa uszkodzonych detali (stary bug sync sklejal pola, np. by="Nick HUNTER Survival") =====
local CLASS_TOKENS = {
    WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, PRIEST = true, DEATHKNIGHT = true,
    SHAMAN = true, MAGE = true, WARLOCK = true, MONK = true, DRUID = true, DEMONHUNTER = true,
}
-- Jesli klasa pusta, a w polu (by/added/note) tkwi token klasy poprzedzony nickiem:
-- rozdziel na class (token) + spec (reszta po tokenie), a pole zostaw na czesc przed tokenem.
local function recoverInfo(info)
    if not info then return end
    if info.class and info.class ~= "" then return end
    for _, fld in ipairs({ "by", "added", "note" }) do
        local s = info[fld]
        if type(s) == "string" and s:find("%S") then
            local words = {}
            for w in s:gmatch("%S+") do words[#words + 1] = w end
            for i = 2, #words do                      -- i>=2: token klasy musi byc poprzedzony nickiem
                if CLASS_TOKENS[words[i]:upper()] then
                    info.class = words[i]:upper()
                    local rest = {}
                    for j = i + 1, #words do rest[#rest + 1] = words[j] end
                    if #rest > 0 and (not info.spec or info.spec == "") then info.spec = table.concat(rest, " ") end
                    local pre = {}
                    for j = 1, i - 1 do pre[#pre + 1] = words[j] end
                    info[fld] = table.concat(pre, " ")
                    return
                end
            end
        end
    end
end
-- Przejdz po wszystkich detalach i napraw uszkodzone wpisy.
local function SanitizeInfo()
    for _, info in pairs(gigakloceInfo) do recoverInfo(info) end
end

-- Stary "Share" = wymus pelny sync (broadcast).
local function ShareAll() FullBroadcast(true) end

-- Czysci nagrobki (historia usuniec) — lokalnie. Po tym usuniete wpisy moga wrocic przy sync,
-- jesli ktos je jeszcze ma; przydatne do "resetu" stanu sync albo gdy nagrobki zablokowaly ponowne dodanie.
local function ClearTombstones()
    local nk = 0; for _ in pairs(GigaKloceDB.tombstones or {}) do nk = nk + 1 end
    local ng = 0; for _ in pairs(GigaKloceDB.guildTomb or {}) do ng = ng + 1 end
    wipe(GigaKloceDB.tombstones)
    wipe(GigaKloceDB.guildTomb)
    log("Cleared tombstones: " .. nk .. " players + " .. ng .. " guilds.")
end


-- eksport do namespace
GK.RefreshUI, GK.EnsureKloceInfo, GK.GetKloceInfo, GK.KLOCE_SEP, GK.BroadcastKloceDetails, GK.BroadcastChadDetails, GK.AddKloce, GK.RemoveKloce, GK.AddChad, GK.RemoveChad, GK.sendRepartyLeader, GK.ShareAll, GK.FullBroadcast, GK.ClearTombstones, GK.SanitizeInfo = RefreshUI, EnsureKloceInfo, GetKloceInfo, KLOCE_SEP, BroadcastKloceDetails, BroadcastChadDetails, AddKloce, RemoveKloce, AddChad, RemoveChad, sendRepartyLeader, ShareAll, FullBroadcast, ClearTombstones, SanitizeInfo
