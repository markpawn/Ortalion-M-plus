-- ============================
-- GigaKloce :: Guilds (blokada gildii przez /who przy aplikacji do premade)
-- ============================
-- Pomysl: nie da sie wprost odczytac gildii aplikanta z C_LFGList. Jedyne zrodlo to /who.
-- Wiec TYLKO gdy ktos aplikuje do naszej grupy, robimy ciche /who po jego nicku, czytamy
-- gildie i jesli jest na liscie blokowanych -> dodajemy go do Kloce (tag=noob, notatka=gildia).
local ADDON, GK = ...
local normalizeName, displayName, log = GK.normalizeName, GK.displayName, GK.log
local AddonPrefix, MSG_GADD, MSG_GREM = GK.AddonPrefix, GK.MSG_GADD, GK.MSG_GREM
local SEP = GK.KLOCE_SEP   -- "\031"

-- ============================
-- Lista blokowanych gildii
-- ============================
local function blocked() return GigaKloceDB.blockedGuilds or {} end

local function guildIsBlocked(guildName)
    if not guildName or guildName == "" then return false end
    local g = string.lower(guildName)
    for _, b in ipairs(blocked()) do
        if string.lower(b) == g then return true end
    end
    return false
end
GK.GuildIsBlocked = guildIsBlocked

function GK.GetBlockedGuilds() return blocked() end

local function gtomb() return GigaKloceDB.guildTomb end
local function gts()   return GigaKloceDB.guildTs end
-- LWW dla gildii: usuniecie wygrywa remisy
local function guildCanApply(lg, ts)
    local tomb = gtomb()[lg]
    if tomb and ts <= tomb then return false end
    local addT = gts()[lg]
    if addT and ts < addT then return false end
    return true
end
local function refreshGuildUI()
    if KloceFrame and KloceFrame.RefreshBlockedGuilds then KloceFrame.RefreshBlockedGuilds() end
end

-- Lokalne dodanie (broadcast G+ z czasem, gdy not silent).
function GK.AddBlockedGuild(name, silent)
    name = name and strtrim(name) or ""
    if name == "" then return false end
    local lg = string.lower(name)
    for _, b in ipairs(blocked()) do if string.lower(b) == lg then return false end end
    table.insert(blocked(), name)
    local t = GK.now()
    gts()[lg] = t; gtomb()[lg] = nil
    log('Blocked guild added: "' .. name .. '"')
    if not silent and (not GK.CanBroadcast or GK.CanBroadcast()) then GK.Send(MSG_GADD .. name .. SEP .. t) end
    refreshGuildUI()
    return true
end

function GK.RemoveBlockedGuild(name, silent)
    if not name then return false end
    local lg = string.lower(name)
    for i, b in ipairs(blocked()) do
        if string.lower(b) == lg then
            local removed = table.remove(blocked(), i)
            local t = GK.now()
            gtomb()[lg] = t; gts()[lg] = nil
            log('Blocked guild removed: "' .. name .. '"')
            if not silent and (not GK.CanBroadcast or GK.CanBroadcast()) then GK.Send(MSG_GREM .. removed .. SEP .. t) end
            refreshGuildUI()
            return true
        end
    end
    return false
end

-- Zdalne dodanie/usuniecie gildii (LWW; bez rozsylania dalej).
function GK.ApplyRemoteGuildAdd(name, ts)
    name = name and strtrim(name) or ""
    if name == "" then return false end
    local lg = string.lower(name)
    if not guildCanApply(lg, ts) then return false end
    local present = false
    for _, b in ipairs(blocked()) do if string.lower(b) == lg then present = true; break end end
    if not present then table.insert(blocked(), name) end
    gts()[lg] = ts; gtomb()[lg] = nil
    refreshGuildUI()
    return true
end

function GK.ApplyRemoteGuildRemove(name, ts)
    name = name and strtrim(name) or ""
    if name == "" then return false end
    local lg = string.lower(name)
    if not guildCanApply(lg, ts) then return false end
    for i, b in ipairs(blocked()) do
        if string.lower(b) == lg then table.remove(blocked(), i); break end
    end
    gtomb()[lg] = ts; gts()[lg] = nil
    refreshGuildUI()
    return true
end

-- Odswiez widok aplikantow premade, by od razu pokazac kolor [KLOC] (bez zmiany zakladki).
local function refreshApplicantView()
    if LFGListFrame and LFGListFrame.ApplicationViewer and LFGListFrame.ApplicationViewer:IsShown()
       and type(LFGListApplicationViewer_UpdateResults) == "function" then
        LFGListApplicationViewer_UpdateResults(LFGListFrame.ApplicationViewer)
    end
end

-- Dodaje gracza do Kloce z powodu gildii (tag=noob, notatka=gildia, klasa z /who) i rozsyla detale.
local function blockFromGuild(name, guildName, classFile)
    if not name or name == "" then return end
    if GK.has_value and GK.gigakloce and GK.has_value(GK.gigakloce, name) then return end  -- juz jest
    if not (GK.AddKloce and GK.AddKloce(name, true)) then return end   -- silent: detale + broadcast ustawimy sami
    local info = GK.EnsureKloceInfo and GK.EnsureKloceInfo(name)
    if info then
        info.tag = "noob"
        info.note = "Guild: " .. (guildName or "?")
        if classFile and classFile ~= "" and (not info.class or info.class == "") then info.class = classFile end
        info.t = GK.now()
    end
    if GK.BroadcastKloceDetails then GK.BroadcastKloceDetails(name) end
    log("Auto-kloc (guild \"" .. (guildName or "?") .. "\"): " .. displayName(name))
    refreshApplicantView()   -- pokaz [KLOC] od razu w widoku premade
end

-- ============================
-- Ciche /who (kolejka, jeden zapytanie na raz)
-- ============================
local whoQueue = {}      -- nicki czekajace na sprawdzenie
local whoPending = nil   -- aktualnie sprawdzany nick (pelny), albo nil
local whoSeen = {}       -- [normKey]=true: nie pytaj ponownie w tej sesji
local whoFrameWasShown   -- czy FriendsFrame byl widoczny przed zapytaniem
local watchdog           -- timer bezpieczenstwa
local whoSuppress = false -- czy wyciszac systemowe komunikaty /who teraz

-- Czy trwa nasze ciche /who (uzywane przez filtr czatu do wyciszenia wynikow).
function GK.WhoSuppressing() return whoSuppress end

-- Twardy bezpiecznik: gdy podczas naszego cichego /who gra probuje otworzyc okno znajomych/Who
-- (zwlaszcza przy >1 wyniku), od razu je chowamy — chyba ze user mial je otwarte sam.
if FriendsFrame and FriendsFrame.HookScript then
    FriendsFrame:HookScript("OnShow", function(self)
        if whoPending and not whoFrameWasShown then
            if type(HideUIPanel) == "function" then HideUIPanel(self) else self:Hide() end
        end
    end)
end

-- Mapa: zlokalizowana nazwa klasy -> token ("Mag"->"MAGE"). Fallback gdy /who nie da tokenu.
local classFileByLocal
local function fileFromLocalizedClass(loc)
    if not loc or loc == "" then return nil end
    if not classFileByLocal then
        classFileByLocal = {}
        if LOCALIZED_CLASS_NAMES_MALE then for f, n in pairs(LOCALIZED_CLASS_NAMES_MALE) do classFileByLocal[n] = f end end
        if LOCALIZED_CLASS_NAMES_FEMALE then for f, n in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do classFileByLocal[n] = f end end
    end
    return classFileByLocal[loc]
end

-- Odczyt wpisu /who niezaleznie od wersji API. Zwraca: nick, gildia, token klasy ("MAGE").
local function whoEntry(i)
    local a = GetWhoInfo(i)
    if type(a) == "table" then
        return (a.fullName or a.name), (a.fullGuildName or a.guild), (a.filename or fileFromLocalizedClass(a.classStr))
    end
    -- legacy 7.3.5: name, guild, level, race, class(loc), zone, classFileName
    local name, guild, _, _, classLoc, _, classFile = GetWhoInfo(i)
    return name, guild, (classFile or fileFromLocalizedClass(classLoc))
end

local function finishWho()
    whoPending = nil
    if watchdog then watchdog:Cancel(); watchdog = nil end
    -- przywroc rzeczy
    if type(SetWhoToUI) == "function" then SetWhoToUI(0) end
    if FriendsFrame and FriendsFrame:IsShown() and not whoFrameWasShown then HideUIPanel(FriendsFrame) end
    -- kolejny z kolejki; gdy pusto, wylacz wyciszanie chwile pozniej (na spozniony komunikat)
    if #whoQueue > 0 then
        C_Timer.After(1.0, function() GK.StartNextWho() end)
    else
        C_Timer.After(0.5, function() whoSuppress = false end)
    end
end

function GK.StartNextWho()
    if whoPending then return end
    if #whoQueue == 0 then return end
    if type(SendWho) ~= "function" then whoQueue = {}; return end
    whoPending = table.remove(whoQueue, 1)   -- { name, action, filter, guild }
    whoSuppress = true   -- wycisz systemowe komunikaty /who na czas zapytania
    whoFrameWasShown = FriendsFrame and FriendsFrame:IsShown()
    if type(SetWhoToUI) == "function" then SetWhoToUI(1) end   -- wyniki do listy (czytamy GetWhoInfo), nie na czat
    SendWho(whoPending.filter)
    -- watchdog: jak WHO_LIST_UPDATE nie przyjdzie, nie blokuj kolejki
    watchdog = C_Timer.NewTimer(5, function() watchdog = nil; finishWho() end)
end

-- Aplikant do premade: dla KAZDEJ blokowanej gildii pytamy g-"gildia" n-"nick".
-- Taki filtr daje 0/1 wynik i od razu potwierdza przynaleznosc (mniej dwuznacznosci niz samo n-).
function GK.QueueGuildCheck(name)
    if not name or name == "" then return end
    local bg = blocked()
    if #bg == 0 then return end
    local k = normalizeName(name)
    if k == "" or whoSeen[k] then return end
    -- nie sprawdzaj kogos, kto juz jest na Kloce/Chad
    if GK.has_value and ((GK.gigakloce and GK.has_value(GK.gigakloce, name)) or (GK.gigachad and GK.has_value(GK.gigachad, name))) then
        return
    end
    whoSeen[k] = true
    local nameOnly = strsplit("-", name)
    for _, g in ipairs(bg) do
        table.insert(whoQueue, {
            name = name, action = "check", guild = g,
            filter = 'g-"' .. g .. '" n-"' .. nameOnly .. '"',
        })
    end
    GK.StartNextWho()
end

-- Recznie (z menu): zrob /who tej osoby, pobierz jej gildie i DODAJ ja do blokowanych.
function GK.WhoAddGuild(name)
    if not name or name == "" then return end
    log("Looking up guild of " .. displayName(name) .. " ...")
    local nameOnly = strsplit("-", name)
    table.insert(whoQueue, { name = name, action = "addguild", filter = 'n-"' .. nameOnly .. '"' })
    GK.StartNextWho()
end

-- WHO_LIST_UPDATE: dopasuj wynik do pytanego nicku, odczytaj gildie, wykonaj akcje.
function GK.OnWhoListUpdate()
    if not whoPending then return end
    local asked = whoPending.name
    local action = whoPending.action
    local wantGuild = whoPending.guild      -- dla "check": gildia uzyta w filtrze g-"..."
    local key = normalizeName(asked)
    local num = (type(GetNumWhoResults) == "function" and GetNumWhoResults()) or 0
    local guild, classFile, matched
    for i = 1, num do
        local n, g, cf = whoEntry(i)
        if n and normalizeName(n) == key then guild = g; classFile = cf; matched = true; break end
    end
    finishWho()   -- najpierw posprzataj (przywroc UI, odpal kolejny)
    if action == "addguild" then
        if guild and guild ~= "" then
            if GK.AddBlockedGuild then GK.AddBlockedGuild(guild) end
            blockFromGuild(asked, guild, classFile)   -- ta osoba tez od razu na Kloce (z klasa)
        else
            log("No guild found for " .. displayName(asked) .. " (offline / no guild).")
        end
    else   -- "check": filtr g-"gildia" juz ograniczyl wynik, wiec dopasowanie nicku = jest w tej gildii
        if matched then
            blockFromGuild(asked, (guild and guild ~= "" and guild) or wantGuild, classFile)
        end
    end
end

-- ============================
-- Skan aplikantow do naszego premade (LFG_LIST_APPLICANT_LIST_UPDATED)
-- ============================
function GK.ScanApplicants()
    if not C_LFGList then return end
    if #blocked() == 0 then return end
    local applicants = C_LFGList.GetApplicants and C_LFGList.GetApplicants()
    if not applicants then return end
    for _, appID in ipairs(applicants) do
        local _, status, _, numMembers = C_LFGList.GetApplicantInfo(appID)
        if status == "applied" then
            for i = 1, (numMembers or 1) do
                local name = C_LFGList.GetApplicantMemberInfo(appID, i)
                if name and name ~= "" then GK.QueueGuildCheck(name) end
            end
        end
    end
end
