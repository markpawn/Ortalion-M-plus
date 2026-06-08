-- ============================
-- GigaKloce :: Util (nazwy, klasyfikacja, alert, detekcja)
-- ============================
local ADDON, GK = ...
local AddonPrefix, MSG_KADD, MSG_KREM, MSG_CADD, MSG_CREM, KLOCE_TAGS, DEFAULT_TAG, TAG_COLORS, TAG_ICONS, gigakloce, gigachad, gigakloceInfo, sessionKloceToStay, promptedKloce, InitSaved = GK.AddonPrefix, GK.MSG_KADD, GK.MSG_KREM, GK.MSG_CADD, GK.MSG_CREM, GK.KLOCE_TAGS, GK.DEFAULT_TAG, GK.TAG_COLORS, GK.TAG_ICONS, GK.gigakloce, GK.gigachad, GK.gigakloceInfo, GK.sessionKloceToStay, GK.promptedKloce, GK.InitSaved

-- ============================
-- POMOCNICZE FUNKCJE
-- ============================
-- Zawsze widoczny komunikat (na zadanie uzytkownika: wyniki komend, "Usage", przelaczniki).
function GK.out(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[GigaKloce]|r " .. tostring(msg))
end

-- log() = gadanina (sync, add/remove, itp.) — wypisywana TYLKO gdy debug wlaczony (zebatka).
local function log(msg)
    if not (GigaKloceDB and GigaKloceDB.debug) then return end
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[GigaKloce]|r " .. tostring(msg))
end

-- jednolity ON/OFF dla przelacznikow (zielony/czerwony)
local function onOff(v)
    return v and "|cff40ff40ON|r" or "|cffff5555OFF|r"
end
GK.onOff = onOff

-- Czas serwera (jednolity dla wszystkich na realmie) — do porownan "nowsze wygrywa".
function GK.now()
    return (GetServerTime and GetServerTime()) or time()
end

-- Kolejka wysylki addon-message z throttlingiem (klient gubi wiadomosci przy zalewie).
-- Wszystkie nasze wiadomosci sync ida tedy: ~8/s, po jednej na tick.
local sendQ, sendTicker = {}, nil
function GK.Send(payload, channel, target)
    sendQ[#sendQ + 1] = { p = payload, c = channel or "GUILD", t = target }
    if not sendTicker then
        sendTicker = C_Timer.NewTicker(0.12, function()
            local m = table.remove(sendQ, 1)
            if m then
                SendAddonMessage(GK.AddonPrefix, m.p, m.c, m.t)   -- t (target) uzywany tylko dla WHISPER
            elseif sendTicker then
                sendTicker:Cancel(); sendTicker = nil
            end
        end)
    end
end

local function NormalizeRealm(realm)
    if not realm or realm == "" then return "" end
    return (realm:gsub("%s+", ""))
end

local function MyRealm()
    return NormalizeRealm(GetNormalizedRealmName())
end

-- Klucz porĂłwnaĹ„: "imie-realm" maĹ‚ymi literami; brak realmu = realm wĹ‚asny.
-- DziÄ™ki temu "Bob", "Bob-Tauri" i roster "Bob" to ten sam gracz,
-- a "Bob-Evermoon" (poĹ‚Ä…czony realm) jest traktowany jako ktoĹ› inny.
local function normalizeName(name)
    if not name or name == "" then return "" end
    local n, r = strsplit("-", name, 2)
    n = string.lower(n)
    if not r or r == "" then
        r = string.lower(MyRealm())
    else
        r = string.lower(NormalizeRealm(r))
    end
    if r == "" then return n end
    return n .. "-" .. r
end

-- PeĹ‚na nazwa "Imie-Realm" zachowujÄ…ca wielkoĹ›Ä‡ liter (do zapisu i wysyĹ‚ki).
local function canonicalDisplay(name)
    if not name or name == "" then return name end
    local n, r = strsplit("-", name, 2)
    if not r or r == "" then r = MyRealm() end
    r = NormalizeRealm(r)
    if r == "" then return n end
    return n .. "-" .. r
end

-- Wersja do wyĹ›wietlenia: ukrywa wĹ‚asny realm, pokazuje obcy (np. "-Evermoon").
local function displayName(stored)
    if not stored or stored == "" then return stored end
    local n, r = strsplit("-", stored, 2)
    if r and r ~= "" and string.lower(NormalizeRealm(r)) ~= string.lower(MyRealm()) then
        return n .. "-" .. r
    end
    return n
end

-- ===== Uprawnienia (admin / blocked) =====
-- nazwa bez realmu, lowercase (do porownan z super adminem)
local function namePart(n)
    if not n or n == "" then return "" end
    local p = strsplit("-", n)
    return string.lower(p or "")
end
local function isSuperAdmin(name) return namePart(name) == GK.SUPER_ADMIN end
GK.IsSuperAdmin = isSuperAdmin

-- Czy JA jestem adminem (super albo nadana flaga)?
function GK.AmIAdmin()
    if isSuperAdmin(UnitName("player")) then return true end
    return (GigaKloceDB and GigaKloceDB.myAdmin) == true
end
-- Czy JA jestem zablokowany? (super admin nigdy)
function GK.AmIBlocked()
    if isSuperAdmin(UnitName("player")) then return false end
    return (GigaKloceDB and GigaKloceDB.myBlocked) == true
end
-- Czy moge wysylac swoje dane do sync? (zablokowany = tylko biernie slucha)
function GK.CanBroadcast() return not GK.AmIBlocked() end

-- "Imie-Realm" dla jednostki (uzupeĹ‚nia wĹ‚asny realm, gdy UnitName nie zwraca realmu).
local function GetUnitFullName(unit)
    local name, realm = UnitName(unit)
    if not name or name == "" then return nil end
    if realm and realm ~= "" then
        return name .. "-" .. NormalizeRealm(realm)
    end
    return name .. "-" .. MyRealm()
end

-- UzupeĹ‚nia wĹ‚asny realm w surowej nazwie z rostera, jeĹ›li go brak.
local function ensureRealm(name)
    if not name or name == "" then return name end
    if name:find("-") then return name end
    return name .. "-" .. MyRealm()
end

local function has_value(tab, val)
    local valLower = normalizeName(val)
    for _, value in ipairs(tab) do
        if normalizeName(value) == valLower then
            return true
        end
    end
    return false
end

local function getIndex(tab, val)
    local valLower = normalizeName(val)
    for i, v in ipairs(tab) do
        if normalizeName(v) == valLower then
            return i
        end
    end
    return nil
end

-- (unit, "Imie-Realm") dla i-tego czlonka grupy.
local function RosterUnitName(i)
    if IsInRaid() then
        return "raid"..i, ensureRealm(GetRaidRosterInfo(i))
    elseif i == 1 then
        return "player", GetUnitFullName("player")
    else
        return "party"..(i - 1), GetUnitFullName("party"..(i - 1))
    end
end

-- Klasyfikacja czlonka grupy: "kloce" / "chad" / nil.
local function ClassifyMember(unit, name)
    if name and has_value(gigakloce, name) then return "kloce" end
    if name and has_value(gigachad, name) then return "chad" end
    return nil
end

-- Czy w obecnym skĹ‚adzie (party/raid) siedzi przynajmniej jeden kloc?
local function HasKloceInGroup()
    if not IsInGroup() then return false end
    for i = 1, GetNumGroupMembers() do
        local unit, name = RosterUnitName(i)
        if ClassifyMember(unit, name) == "kloce" then return true end
    end
    return false
end

-- WĹ‚Ä…cza/wyĹ‚Ä…cza czerwonÄ… pulsujÄ…cÄ… poĹ›wiatÄ™ na ikonce przy minimapie.
local function UpdateKloceAlert()
    if not KloceButton or not KloceButton.glow then return end
    if HasKloceInGroup() then
        KloceButton.alertActive = true
        KloceButton.glow:Show()
        if KloceButton.icon and KloceButton.iconAlert then KloceButton.icon:SetTexture(KloceButton.iconAlert) end
    else
        KloceButton.alertActive = false
        KloceButton.glow:Hide()
        if KloceButton.icon and KloceButton.iconNormal then KloceButton.icon:SetTexture(KloceButton.iconNormal) end
    end
end

-- Skanuje skĹ‚ad, odpala alert (dĹşwiÄ™k + popup) dla nowo wykrytych klocĂłw,
-- odĹ›wieĹĽa ikonkÄ™ i panel "In Group". WoĹ‚ane przy GROUP_ROSTER_UPDATE.
local function DetectKloceInGroup()
    local present = {}
    if IsInGroup() then
        for i = 1, GetNumGroupMembers() do
            local unit, name = RosterUnitName(i)
            if name and ClassifyMember(unit, name) == "kloce" then
                local key = normalizeName(name)
                present[key] = true
                if not promptedKloce[key] and not has_value(sessionKloceToStay, name) then
                    promptedKloce[key] = true
                    log("Gigakloc in party: " .. displayName(name))
                    if not GigaKloceDB.silent then
                        PlaySoundFile("Interface\\AddOns\\GigaKloce\\wipe.ogg", "Master")
                    end
                    if UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") then
                        StaticPopup_Show("KLOCE_CONFIRM", displayName(name), nil, name)
                    end
                end
            end
        end
    end
    -- czyscimy flagi dla tych, ktorych juz nie ma w skladzie (rejoin = ponowny popup)
    for key in pairs(promptedKloce) do
        if not present[key] then promptedKloce[key] = nil end
    end
    UpdateKloceAlert()
    if KloceFrame and KloceFrame.RefreshPartyList then KloceFrame.RefreshPartyList() end
end

local function GetGroupLeadersAndAssistants()
    local result = {}

    if IsInRaid() then
        -- raid: rank 2 = leader, rank 1 = assistant
        for i = 1, GetNumGroupMembers() do
            local name, rank = GetRaidRosterInfo(i)
            if name and (rank == 1 or rank == 2) then
                table.insert(result, ensureRealm(name))
            end
        end
    elseif IsInGroup() then
        -- party: sprawdzamy playera i party1â€“party4
        if UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") then
            local playerName = GetUnitFullName("player")
            if playerName then table.insert(result, playerName) end
        end

        for i = 1, GetNumSubgroupMembers() do
            local unit = "party"..i
            local name = GetUnitFullName(unit)
            if name and (UnitIsGroupLeader(unit) or UnitIsGroupAssistant(unit)) then
                table.insert(result, name)
            end
        end
    end

    return result
end

local function getNick(input)
    local sep = "-"
    local t = {}
    for str in string.gmatch(input, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t[1]
end


-- eksport do namespace
GK.log, GK.normalizeName, GK.canonicalDisplay, GK.displayName, GK.GetUnitFullName, GK.ensureRealm, GK.has_value, GK.getIndex, GK.RosterUnitName, GK.ClassifyMember, GK.HasKloceInGroup, GK.UpdateKloceAlert, GK.DetectKloceInGroup, GK.GetGroupLeadersAndAssistants = log, normalizeName, canonicalDisplay, displayName, GetUnitFullName, ensureRealm, has_value, getIndex, RosterUnitName, ClassifyMember, HasKloceInGroup, UpdateKloceAlert, DetectKloceInGroup, GetGroupLeadersAndAssistants
