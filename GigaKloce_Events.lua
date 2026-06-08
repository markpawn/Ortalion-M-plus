-- ============================
-- GigaKloce :: Events (slashe, eventy, menu, czat, group finder)
-- ============================
local ADDON, GK = ...
local AddonPrefix, MSG_KADD, MSG_KREM, MSG_CADD, MSG_CREM, KLOCE_TAGS, DEFAULT_TAG, TAG_COLORS, TAG_ICONS, gigakloce, gigachad, gigakloceInfo, sessionKloceToStay, promptedKloce, InitSaved, log, normalizeName, canonicalDisplay, displayName, GetUnitFullName, ensureRealm, has_value, getIndex, RosterUnitName, ClassifyMember, HasKloceInGroup, UpdateKloceAlert, DetectKloceInGroup, GetGroupLeadersAndAssistants, RefreshUI, EnsureKloceInfo, GetKloceInfo, KLOCE_SEP, BroadcastKloceDetails, AddKloce, RemoveKloce, AddChad, RemoveChad, sendRepartyLeader, MakeDailySnapshot, RestoreSnapshot, ShowKloceUI, CreateKloceButton = GK.AddonPrefix, GK.MSG_KADD, GK.MSG_KREM, GK.MSG_CADD, GK.MSG_CREM, GK.KLOCE_TAGS, GK.DEFAULT_TAG, GK.TAG_COLORS, GK.TAG_ICONS, GK.gigakloce, GK.gigachad, GK.gigakloceInfo, GK.sessionKloceToStay, GK.promptedKloce, GK.InitSaved, GK.log, GK.normalizeName, GK.canonicalDisplay, GK.displayName, GK.GetUnitFullName, GK.ensureRealm, GK.has_value, GK.getIndex, GK.RosterUnitName, GK.ClassifyMember, GK.HasKloceInGroup, GK.UpdateKloceAlert, GK.DetectKloceInGroup, GK.GetGroupLeadersAndAssistants, GK.RefreshUI, GK.EnsureKloceInfo, GK.GetKloceInfo, GK.KLOCE_SEP, GK.BroadcastKloceDetails, GK.AddKloce, GK.RemoveKloce, GK.AddChad, GK.RemoveChad, GK.sendRepartyLeader, GK.MakeDailySnapshot, GK.RestoreSnapshot, GK.ShowKloceUI, GK.CreateKloceButton
local onOff = GK.onOff
local BroadcastMyKey, ReceiveKey = GK.BroadcastMyKey, GK.ReceiveKey
local MSG_KEY = GK.MSG_KEY
local MSG_HI = GK.MSG_HI
local MSG_GADD, MSG_GREM = GK.MSG_GADD, GK.MSG_GREM
local MSG_SYNC = GK.MSG_SYNC
local MSG_HIQ = GK.MSG_HIQ
local MSG_FLAG = GK.MSG_FLAG
local reparty, repartyLeader, repartyType, repartyStage = {}, nil, nil, nil

-- ============================
-- SLASH CMD
-- ============================
SLASH_KLOCE1 = "/kloce"
SlashCmdList["KLOCE"] = function(msg)
    local log = GK.out   -- wyniki komend zawsze widoczne (niezaleznie od debug)
    msg = msg or ""
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = string.lower(cmd or "")
    rest = rest or ""

    if cmd == "add" then
        local name = rest ~= "" and rest or nil
        if not name then
            if UnitExists("target") and UnitIsPlayer("target") then
                name = GetUnitFullName("target")
            else
                log("Usage: /kloce add <nick> or target player and use /kloce add")
                return
            end
        end
        AddKloce(name)   -- sam broadcastuje (z czasem) detale

    elseif cmd == "remove" then
        local name = rest ~= "" and rest or nil
        if not name then
            if UnitExists("target") and UnitIsPlayer("target") then
                name = GetUnitFullName("target")
            else
                log("Usage: /kloce remove <nick> or target player and use /kloce remove")
                return
            end
        end
        RemoveKloce(name)   -- sam broadcastuje usuniecie (z czasem)

    elseif cmd == "list" then
        for i, v in ipairs(gigakloce) do log(i .. ". " .. displayName(v)) end

    elseif cmd == "show" then
        ShowKloceUI()
		
	elseif cmd == "silent" then
		GigaKloceDB.silent = not GigaKloceDB.silent
		log("Mute alert sound: " .. onOff(GigaKloceDB.silent))

	elseif cmd == "reparty" then
        if not (IsInGroup() or IsInRaid()) then
            log("You're not in a group or raid")
            return
        end

        local inRaid = IsInRaid()
        -- Tylko lider: reparty wyrzuca caĹ‚y skĹ‚ad i odbudowuje grupÄ™,
        -- a wykickowaÄ‡ wszystkich (Ĺ‚Ä…cznie z byĹ‚ym liderem) moĹĽe wyĹ‚Ä…cznie lider.
        if not UnitIsGroupLeader("player") then
            log("You must be the group leader to reparty.")
            return
        end

        if repartyStage then
            log("Reparty already in progress.")
            return
        end

        -- Zbierz skĹ‚ad (peĹ‚ne nazwy, bez siebie).
        local playerName = GetUnitFullName("player")
        reparty = {}
        repartyType = inRaid and "raid" or "party"
        if inRaid then
            for i = 1, GetNumGroupMembers() do
                local name = ensureRealm(GetRaidRosterInfo(i))
                if name and normalizeName(name) ~= normalizeName(playerName) then
                    table.insert(reparty, name)
                end
            end
        else
            for i = 1, GetNumSubgroupMembers() do
                local name = GetUnitFullName("party"..i)
                if name then table.insert(reparty, name) end
            end
        end

        if #reparty == 0 then
            log("Reparty: no one to re-invite.")
            repartyType = nil
            return
        end

        -- Powiadom sklad (u graczy z addonem ponowne zaproszenie auto-zaakceptuje sie),
        sendRepartyLeader()
        -- ...a nastepnie wyrzuc wszystkich. Reszta (czekanie az grupa sie rozpadnie
        -- i ponowne zaproszenia) steruje maszyna stanow w GROUP_ROSTER_UPDATE.
        repartyStage = "draining"
        for _, name in ipairs(reparty) do
            UninviteUnit(displayName(name))
        end
        log("Reparty: rebuilding group...")

    elseif cmd == "reset" then
        GigaKloceDB.btnX = nil
        GigaKloceDB.btnY = nil
        GigaKloceDB.posX = nil
        GigaKloceDB.posY = nil
        GigaKloceDB.sizeW = nil
        GigaKloceDB.sizeH = nil

        if KloceButton then
            KloceButton:ClearAllPoints()
            KloceButton:SetPoint("TOPLEFT", Minimap, "BOTTOMLEFT", 0, -2)
        end

        if KloceFrame then
            KloceFrame:ClearAllPoints()
            KloceFrame:SetSize(500, 400)
            KloceFrame:SetPoint("CENTER")
        end

        log("UI reset.")

    elseif cmd == "guild" then
        local sub, gname = rest:match("^(%S*)%s*(.-)$")
        sub = string.lower(sub or "")
        if sub == "add" and gname ~= "" then
            if GK.AddBlockedGuild then GK.AddBlockedGuild(gname) end
        elseif sub == "remove" and gname ~= "" then
            if GK.RemoveBlockedGuild then GK.RemoveBlockedGuild(gname) end
        elseif sub == "list" then
            local gl = (GK.GetBlockedGuilds and GK.GetBlockedGuilds()) or {}
            log("Blocked guilds (" .. #gl .. "):")
            for i, g in ipairs(gl) do log("  " .. i .. ". " .. g) end
        else
            log('Usage: /kloce guild add <name> | remove <name> | list')
        end

    elseif cmd == "share" then
        if GK.ShareAll then GK.ShareAll() end   -- push pelnego stanu na gildie (recznie)

    elseif cmd == "sync" then
        -- recznie: pociagnij stan od wybranego zrodla (preferowane lub najnizszy online)
        if GK.Send then GK.Send(MSG_HIQ) end   -- odswiez kto online
        C_Timer.After(2, function()
            local src = GK.PickSyncSource and GK.PickSyncSource()
            if src then GK.Send(MSG_SYNC, "WHISPER", src); log("Requesting sync from " .. src .. " ...")
            else log("No addon users online to sync from.") end
        end)

    elseif cmd == "syncfrom" then
        if rest == "" or string.lower(rest) == "clear" or string.lower(rest) == "auto" then
            GigaKloceDB.syncSource = nil
            log("Sync source: auto (lowest online).")
        else
            GigaKloceDB.syncSource = rest
            log("Sync source set to: " .. rest .. " (used on login if online).")
        end

    else
        log("Usage: /kloce add <nick>, remove <nick>, list, show, reset, share, sync, syncfrom <nick|auto>, guild <add|remove|list>  |  chads: /chad")
    end
end

-- ============================
-- SLASH CMD: /chad (lista gigachadow)
-- ============================
SLASH_GIGACHAD1 = "/chad"
SlashCmdList["GIGACHAD"] = function(msg)
    local log = GK.out   -- wyniki komend zawsze widoczne (niezaleznie od debug)
    msg = msg or ""
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = string.lower(cmd or "")
    rest = rest or ""

    if cmd == "add" then
        local name = rest ~= "" and rest or nil
        if not name then
            if UnitExists("target") and UnitIsPlayer("target") then
                name = GetUnitFullName("target")
            else
                log("Usage: /chad add <nick> or target player and use /chad add")
                return
            end
        end
        AddChad(name)   -- sam broadcastuje (z czasem) detale

    elseif cmd == "remove" then
        local name = rest ~= "" and rest or nil
        if not name then
            if UnitExists("target") and UnitIsPlayer("target") then
                name = GetUnitFullName("target")
            else
                log("Usage: /chad remove <nick> or target player and use /chad remove")
                return
            end
        end
        RemoveChad(name)   -- sam broadcastuje usuniecie (z czasem)

    elseif cmd == "list" then
        for i, v in ipairs(gigachad) do log(i .. ". " .. displayName(v)) end

    elseif cmd == "show" then
        ShowKloceUI()
        if KloceFrame and KloceFrame.SetMode then KloceFrame.SetMode("chad") end

    else
        log("Usage: /chad add <nick>, remove <nick>, list, show")
    end
end

-- ============================
-- EVENTS
-- ============================
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("CHAT_MSG_ADDON")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("PARTY_INVITE_REQUEST")
f:RegisterEvent("PARTY_LEADER_CHANGED")
f:RegisterEvent("INSPECT_READY")
f:RegisterEvent("LFG_LIST_APPLICANT_LIST_UPDATED")
f:RegisterEvent("WHO_LIST_UPDATE")

f:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        InitSaved()
        MakeDailySnapshot()          -- dzienny snapshot na wejscie (jak nie ma dzisiejszego)
        RegisterAddonMessagePrefix(AddonPrefix)
        CreateKloceButton()
        log("Addon loaded. Use /kloce")
        -- rozglaszanie wlasnego klucza M+ co 30 s (cicho, GUILD) + pierwszy raz po 8 s
        C_Timer.After(8, function()
            if GK.BroadcastMyKey then GK.BroadcastMyKey() end
            if GK.BroadcastPresence then GK.BroadcastPresence() end
            -- auto-sync: wypchnij swoj stan (push, gildia) i zapytaj kto online (do wyboru zrodla pull)
            if GK.FullBroadcast then GK.FullBroadcast() end
            if GK.Send then GK.Send(MSG_HIQ) end
        end)
        -- po zebraniu presence: wybierz JEDNO zrodlo i pociagnij od niego stan (szeptem)
        C_Timer.After(14, function()
            local src = GK.PickSyncSource and GK.PickSyncSource()
            if src and GK.Send then
                GK.Send(MSG_SYNC, "WHISPER", src)
                log("Requesting sync from " .. src .. " ...")
            end
        end)
        C_Timer.NewTicker(30, function()
            if GK.BroadcastMyKey then GK.BroadcastMyKey() end
            if GK.BroadcastPresence then GK.BroadcastPresence() end
        end)
	elseif event == "PARTY_INVITE_REQUEST" then
        local inviter = ...
        if repartyLeader and inviter and repartyLeader == normalizeName(inviter) then
            AcceptGroup()
            StaticPopup_Hide("PARTY_INVITE")
        end
		repartyLeader = nil
    elseif event == "PARTY_LEADER_CHANGED" then
        -- zmiana lidera moze nie odpalic GROUP_ROSTER_UPDATE â€” odswiez stan przycisku Reparty
        if KloceFrame and KloceFrame.RefreshPartyList then KloceFrame.RefreshPartyList() end
    elseif event == "INSPECT_READY" then
        local guid = ...
        if GK.OnInspectReady then GK.OnInspectReady(guid) end
    elseif event == "LFG_LIST_APPLICANT_LIST_UPDATED" then
        -- ktos aplikuje do naszego premade -> sprawdz gildie przez ciche /who
        if GK.ScanApplicants then GK.ScanApplicants() end
    elseif event == "WHO_LIST_UPDATE" then
        if GK.OnWhoListUpdate then GK.OnWhoListUpdate() end
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, msg, channel, sender = ...
        if prefix ~= AddonPrefix then return end
        if normalizeName(sender) == normalizeName(GetUnitFullName("player")) then return end
        local tag = msg:sub(1, 3)
        if msg:sub(1, 7) == "REPARTY" then
			local leaders = GetGroupLeadersAndAssistants()
			for _, name in ipairs(leaders) do
				if normalizeName(name) == normalizeName(sender) then
					repartyLeader = normalizeName(sender)
				end
			end
			return
        end
        if msg:sub(1, 4) == MSG_KEY then   -- "KEY:" — klucze M+ (zawsze przyjmowane, info-only)
            if GK.ReceiveKey then GK.ReceiveKey(sender, msg:sub(5)) end
            return
        end
        if msg:sub(1, 3) == MSG_HIQ then   -- "HI?" — ktos pyta kto online -> odpowiedz presence (z malym staggerem)
            local d = 0.3 + (#tostring(sender) % 5) * 0.25
            C_Timer.After(d, function() if GK.BroadcastPresence then GK.BroadcastPresence() end end)
            return
        end
        if msg:sub(1, 3) == MSG_HI then    -- "HI:" — presence + klasa + spec (info-only, zasila cache)
            if GK.ReceivePresence then GK.ReceivePresence(sender, msg:sub(4)) end
            if KloceFrame and KloceFrame.mode == "party" then
                if KloceFrame.RefreshPartyList then KloceFrame.RefreshPartyList() end
                if KloceFrame.RefreshList then KloceFrame.RefreshList() end
            end
            return
        end
        if msg:sub(1, 5) == MSG_SYNC then   -- "SYNC?" — SKIEROWANA (szept) prosba: odpowiada tylko TEN, kogo poproszono
            -- odpowiadamy po GUILD (separator \031 nie przechodzi pewnie przez WHISPER na Tauri).
            -- Prosba byla szeptem, wiec i tak odpowiada tylko jedna osoba; reszta tego nie dostaje.
            if GK.FullBroadcast then GK.FullBroadcast(true) end
            return
        end
        if msg:sub(1, 4) == MSG_FLAG then   -- "FLG:" — ustawienie flag admin/blocked (tylko zgodna wersja)
            if (not GK.VersionOK or GK.VersionOK(sender)) and GK.ApplyFlag then GK.ApplyFlag(sender, msg:sub(5)) end
            return
        end
        -- Sync listy/detali/gildii â€” tylko gdy przyjmujesz zmiany od innych (kolko zebate).
        -- Kazda wiadomosc niesie czas serwera; scalanie "nowsze wygrywa" (z nagrobkami) jest w ApplyRemote*.
        if not GigaKloceDB.acceptSync then return end
        -- gate wersji: dane sync przyjmujemy TYLKO od tej samej wersji modelu (inaczej parsowanie sie rozjedzie)
        if GK.VersionOK and not GK.VersionOK(sender) then return end
        local function refreshDetailWin(name)
            if KloceDetailFrame and KloceDetailFrame:IsShown() and KloceDetailFrame.key == normalizeName(name) and KloceDetailFrame.RefreshAll then
                KloceDetailFrame.RefreshAll()
            end
        end
        if tag == MSG_KADD then
            -- "K+:name \031 tag \031 note \031 added \031 by \031 class \031 spec \031 t"
            local name, tg, note, added, by, class, spec, t = strsplit(KLOCE_SEP, msg:sub(4), 8)
            t = tonumber(t) or GK.now()
            if name and name ~= "" and GK.ApplyRemoteKloce and GK.ApplyRemoteKloce(name, t, tg, note, added, by, class, spec) then
                refreshDetailWin(name)
                log("Sync KLOCE from " .. sender .. ": " .. displayName(name))
            end
        elseif tag == MSG_CADD then
            -- "C+:name \031 note \031 added \031 by \031 class \031 spec \031 t"
            local name, note, added, by, class, spec, t = strsplit(KLOCE_SEP, msg:sub(4), 7)
            t = tonumber(t) or GK.now()
            if name and name ~= "" and GK.ApplyRemoteChad and GK.ApplyRemoteChad(name, t, note, added, by, class, spec) then
                refreshDetailWin(name)
                log("Sync CHAD from " .. sender .. ": " .. displayName(name))
            end
        elseif tag == MSG_KREM or tag == MSG_CREM then
            -- "K-:name \031 t" (list-agnostyczne usuniecie)
            local name, t = strsplit(KLOCE_SEP, msg:sub(4), 2)
            t = tonumber(t) or GK.now()
            if name and name ~= "" and GK.ApplyRemoteRemove and GK.ApplyRemoteRemove(name, t) then
                log("Sync remove from " .. sender .. ": " .. displayName(name))
            end
        elseif tag == MSG_GADD then
            local g, t = strsplit(KLOCE_SEP, msg:sub(4), 2)
            t = tonumber(t) or GK.now()
            if g and g ~= "" and GK.ApplyRemoteGuildAdd and GK.ApplyRemoteGuildAdd(g, t) then
                log("Sync guild-block from " .. sender .. ": " .. g)
            end
        elseif tag == MSG_GREM then
            local g, t = strsplit(KLOCE_SEP, msg:sub(4), 2)
            t = tonumber(t) or GK.now()
            if g and g ~= "" and GK.ApplyRemoteGuildRemove and GK.ApplyRemoteGuildRemove(g, t) then
                log("Sync guild-unblock from " .. sender .. ": " .. g)
            end
        end

    elseif event == "GROUP_ROSTER_UPDATE" then
        -- Maszyna stanow reparty (sterowana zdarzeniami, bez sztywnych timerow).
        if repartyStage == "draining" then
            -- czekamy az stara grupa sie rozpadnie (zostajemy sami;
            -- raid moze zostac "1-osobowy", stad licznik a nie IsInGroup)
            if GetNumGroupMembers() <= 1 then
                local first = table.remove(reparty, 1)
                if not first then
                    repartyStage = nil
                    repartyType = nil
                elseif repartyType == "raid" then
                    repartyStage = "converting"
                    InviteUnit(first)
                else
                    InviteUnit(first)
                    for _, name in ipairs(reparty) do InviteUnit(name) end
                    reparty = {}
                    repartyStage = nil
                    repartyType = nil
                end
            end
            return
        elseif repartyStage == "converting" then
            -- pierwszy dolaczyl; konwertujemy na raid ZANIM dojda kolejni
            -- (zaproszenie 6. osoby w Legion NIE auto-konwertuje party w raid)
            if IsInGroup() and not IsInRaid() then
                ConvertToRaid()
                return
            elseif IsInRaid() then
                for _, name in ipairs(reparty) do InviteUnit(name) end
                reparty = {}
                repartyStage = nil
                repartyType = nil
            end
            return
        end

        -- Detekcja klocow w skladzie (alert + popup + ikonka + lista In Group).
		DetectKloceInGroup()
	end
end)

-- ============================
-- CONTEXT MENU
-- ============================
hooksecurefunc("UnitPopup_ShowMenu", function(dropdownMenu, which, unit)
    if UIDROPDOWNMENU_MENU_LEVEL ~= 1 then return end   -- tylko menu glowne, nie submenu
    if not unit then return end
    if not UnitIsPlayer(unit) then return end           -- tylko gracze (nie NPC)
    if UnitIsUnit(unit, "player") then return end        -- nie dla samego siebie
    local name = GetUnitFullName(unit)
    if not name then return end

    local onKloce = has_value(gigakloce, name)
    local onChad  = has_value(gigachad, name)

    -- Add/Remove Kloce (pomaranczowy)
    UIDropDownMenu_AddButton({
        text = onKloce and "|cffff5555Remove from Kloce|r" or "|cffff7d0aAdd to Kloce|r",
        notCheckable = true,
        func = function()
            if onKloce then RemoveKloce(name) else AddKloce(name) end   -- same broadcastuja (z czasem)
        end,
    }, 1)

    -- Block guild (zloty): klik robi /who tej osoby, pobiera gildie i dodaje ja do blokowanych
    UIDropDownMenu_AddButton({
        text = "|cffffd200Block guild (/who)|r",
        notCheckable = true,
        func = function()
            if GK.WhoAddGuild then GK.WhoAddGuild(name) end
        end,
    }, 1)

    -- Add/Remove Chads (zielony)
    UIDropDownMenu_AddButton({
        text = onChad and "|cff55ddffRemove from Chads|r" or "|cff40ff40Add to Chads|r",
        notCheckable = true,
        func = function()
            if onChad then RemoveChad(name) else AddChad(name) end   -- same broadcastuja (z czasem)
        end,
    }, 1)
end)

-- ============================
-- POPUP DIALOG
-- ============================
StaticPopupDialogs["KLOCE_CONFIRM"] = {
    text = "Do you want to remove kloc: %s?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function(self, data)
        UninviteUnit(displayName(data)) -- automatyczny kick (roster name: gole "Name" dla wlasnej realm)
    end,
	OnCancel = function(self, data)
		table.insert(sessionKloceToStay, data)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["GIGAKLOCE_CLEARTOMB"] = {
    text = "Clear deletion history (tombstones)?\nDeleted entries may reappear on next sync if someone still has them.",
    button1 = "Clear",
    button2 = "Cancel",
    OnAccept = function() if GK.ClearTombstones then GK.ClearTombstones() end end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

StaticPopupDialogs["GIGAKLOCE_IMPORT"] = {
    text = "Import snapshot from %s?\nThis OVERWRITES your current kloce + chads + blocked guilds + party presets locally.",
    button1 = "Import",
    button2 = "Cancel",
    OnAccept = function(self, data) RestoreSnapshot(data) end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["GIGAKLOCE_NEWPRESET"] = {
    text = "New party preset name:",
    button1 = "Create",
    button2 = "Cancel",
    hasEditBox = true,
    maxLetters = 32,
    OnAccept = function(self)
        local name = self.editBox and self.editBox:GetText()
        if GK.NewPreset and GK.NewPreset(name) and KloceFrame and KloceFrame.SetMode then KloceFrame.SetMode("party") end
    end,
    EditBoxOnEnterPressed = function(self)
        local name = self:GetText()
        if GK.NewPreset and GK.NewPreset(name) and KloceFrame and KloceFrame.SetMode then KloceFrame.SetMode("party") end
        self:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

StaticPopupDialogs["GIGAKLOCE_DELPRESET"] = {
    text = "Delete party preset \"%s\"?",
    button1 = "Delete",
    button2 = "Cancel",
    OnAccept = function(self, data)
        if GK.DeletePreset then GK.DeletePreset(data) end
        if KloceFrame and KloceFrame.SetMode then KloceFrame.SetMode("party") end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

-- ============================
-- CHAT TAG [KLOC] / [CHAD]
-- ============================
-- Dopina znacznik na poczatku TRESCI wiadomosci (nie autora, zeby klikalny link gracza dzialal).
-- Kloc ma pierwszenstwo gdyby ktos byl na obu listach.
local KLOC_TAG = "|cffff2020[KLOC]|r "
local CHAD_TAG = "|cff3399ff[CHAD]|r "

local function KloceChatFilter(self, event, msg, author, ...)
    if author and msg then
        if has_value(gigakloce, author) then
            return false, KLOC_TAG .. msg, author, ...
        elseif has_value(gigachad, author) then
            return false, CHAD_TAG .. msg, author, ...
        end
    end
    -- brak dopasowania: nie filtruj, zostaw oryginal
    return false
end

-- ============================
-- WYCISZANIE WYNIKOW /who (tylko podczas naszego cichego zapytania o gildie)
-- ============================
-- Buduje wzorce z globalnych formatow wynikow /who, by ukrywac TYLKO te linie.
local whoPatterns
local function buildWhoPatterns()
    if whoPatterns then return whoPatterns end
    whoPatterns = {}
    local function toPattern(fmt)
        if not fmt or fmt == "" then return nil end
        local s = fmt:gsub("%%[%d%$%.%-]*[sdfgxXc]", "\001")        -- specyfikatory (%s,%d,...) -> sentinel
        s = s:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")          -- escape znakow magicznych
        s = s:gsub("\001", ".-")                                    -- sentinel -> dowolny ciag
        return "^" .. s
    end
    for _, g in ipairs({ WHO_LIST_FORMAT, WHO_LIST_GUILD_FORMAT }) do
        local p = toPattern(g)
        if p then table.insert(whoPatterns, p) end
    end
    return whoPatterns
end

local function WhoSuppressFilter(self, event, msg, ...)
    if msg and GK.WhoSuppressing and GK.WhoSuppressing() then
        for _, pat in ipairs(buildWhoPatterns()) do
            if msg:match(pat) then return true end   -- ukryj te linie
        end
    end
    return false
end
ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", WhoSuppressFilter)

local KLOCE_CHAT_EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
    "CHAT_MSG_WHISPER", "CHAT_MSG_CHANNEL",
}
for _, e in ipairs(KLOCE_CHAT_EVENTS) do
    ChatFrame_AddMessageEventFilter(e, KloceChatFilter)
end

-- ============================
-- GROUP FINDER (flagowanie aplikantow)
-- ============================
-- Gdy wystawisz grupe (np. klucz M+) i ktos aplikuje, jego wiersz dostaje marker + kolor:
-- kloc = czerwony [KLOC], chad = niebieski [CHAD]. Oryginal ustawia kolor klasy przy kazdym
-- odswiezeniu wiersza, wiec na recyklowanych wierszach nie zostaje stary kolor.
if C_LFGList and type(LFGListApplicationViewer_UpdateApplicantMember) == "function" then
    hooksecurefunc("LFGListApplicationViewer_UpdateApplicantMember", function(member, appID, memberIdx)
        if not member or not member.Name then return end
        local name = C_LFGList.GetApplicantMemberInfo(appID, memberIdx)
        if not name or name == "" then return end
        if has_value(gigakloce, name) then
            member.Name:SetText("[KLOC] " .. displayName(name))
            member.Name:SetTextColor(1, 0.25, 0.25)
        elseif has_value(gigachad, name) then
            member.Name:SetText("[CHAD] " .. displayName(name))
            member.Name:SetTextColor(0.45, 0.7, 1)
        end
    end)
end
