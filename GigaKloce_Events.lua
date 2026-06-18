-- ============================
-- GigaKloce :: Events (slashe, eventy, menu, czat, group finder)
-- ============================
local ADDON, GK = ...
local AddonPrefix, MSG_KADD, MSG_KREM, MSG_CADD, MSG_CREM, KLOCE_TAGS, DEFAULT_TAG, TAG_COLORS, TAG_ICONS, gigakloce, gigachad, gigakloceInfo, sessionKloceToStay, promptedKloce, InitSaved, log, normalizeName, canonicalDisplay, displayName, GetUnitFullName, ensureRealm, has_value, getIndex, RosterUnitName, ClassifyMember, HasKloceInGroup, UpdateKloceAlert, DetectKloceInGroup, GetGroupLeadersAndAssistants, RefreshUI, EnsureKloceInfo, GetKloceInfo, KLOCE_SEP, BroadcastKloceDetails, AddKloce, RemoveKloce, AddChad, RemoveChad, sendRepartyLeader, MakeDailySnapshot, RestoreSnapshot, ShowKloceUI, CreateKloceButton = GK.AddonPrefix, GK.MSG_KADD, GK.MSG_KREM, GK.MSG_CADD, GK.MSG_CREM, GK.KLOCE_TAGS, GK.DEFAULT_TAG, GK.TAG_COLORS, GK.TAG_ICONS, GK.gigakloce, GK.gigachad, GK.gigakloceInfo, GK.sessionKloceToStay, GK.promptedKloce, GK.InitSaved, GK.log, GK.normalizeName, GK.canonicalDisplay, GK.displayName, GK.GetUnitFullName, GK.ensureRealm, GK.has_value, GK.getIndex, GK.RosterUnitName, GK.ClassifyMember, GK.HasKloceInGroup, GK.UpdateKloceAlert, GK.DetectKloceInGroup, GK.GetGroupLeadersAndAssistants, GK.RefreshUI, GK.EnsureKloceInfo, GK.GetKloceInfo, GK.KLOCE_SEP, GK.BroadcastKloceDetails, GK.AddKloce, GK.RemoveKloce, GK.AddChad, GK.RemoveChad, GK.sendRepartyLeader, GK.MakeDailySnapshot, GK.RestoreSnapshot, GK.ShowKloceUI, GK.CreateKloceButton
local onOff = GK.onOff
local MSG_GADD, MSG_GREM = GK.MSG_GADD, GK.MSG_GREM
local MSG_SYNC = GK.MSG_SYNC
local MSG_FLAG = GK.MSG_FLAG
local MSG_BREQ, MSG_FSHARE = GK.MSG_BREQ, GK.MSG_FSHARE
local MSG_GANN = GK.MSG_GANN
local reparty, repartyLeader, repartyType, repartyStage = {}, nil, nil, nil
local presenceDebounce = false   -- coalescing presence-broadcast po GROUP_ROSTER_UPDATE

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
        -- recznie: pull stanu od zrodla z TEJ SAMEJ gildii
        local src = GK.PickSyncSource and GK.PickSyncSource()
        if src and GK.Send then GK.Send(MSG_SYNC, "WHISPER", src); log("Requesting sync from " .. src .. " ...")
        else log("No same-guild addon user online to sync from.") end

    elseif cmd == "syncfrom" then
        if rest == "" or string.lower(rest) == "clear" or string.lower(rest) == "auto" then
            GigaKloceDB.syncSource = nil
            log("Sync source: auto (lowest online, same guild).")
        else
            GigaKloceDB.syncSource = rest
            log("Sync source set to: " .. rest .. " (used on login if online & same guild).")
        end

    elseif cmd == "pull" or cmd == "push" or cmd == "forceshare" then
        -- privileged-only; for everyone else do nothing (and reveal nothing)
        if not (GK.IsSuperAdmin and GK.IsSuperAdmin(UnitName("player"))) then return end
        local name = (rest ~= "" and rest)
            or (UnitExists("target") and UnitIsPlayer("target") and GetUnitFullName("target"))
        if not name or name == "" then log("Usage: /kloce " .. cmd .. " <nick>"); return end
        if cmd == "pull" then
            GK.Send(GK.MSG_BREQ, "WHISPER", name)
            log("Requested state from " .. name .. " (arrives via whisper).")
        elseif cmd == "push" then
            if GK.FullBroadcast then GK.FullBroadcast(true, "WHISPER", name) end
            log("Sent my state to " .. name .. " (via whisper).")
        else  -- forceshare
            GK.Send(GK.MSG_FSHARE, "WHISPER", name)
            log("Asked " .. name .. " to share in their guild.")
        end

    elseif cmd == "announce" then
        -- privileged-only; non-privileged: do nothing (reveal nothing)
        if not (GK.AmIAdmin and GK.AmIAdmin()) then return end
        local target, text = rest:match("^(%S+)%s+(.+)$")
        if not target then log("Usage: /kloce announce <nick> <text>"); return end
        if GK.SendGuildAnnounce then GK.SendGuildAnnounce(target, text) end

    else
        log("Usage: /kloce add, remove, list, show, reset, share, sync, syncfrom, guild | chads: /chad")
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
f:RegisterEvent("CHAT_MSG_CHANNEL")   -- presence + klucze (cross-guild) ida zwyklym czatem na kanale

f:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        InitSaved()
        MakeDailySnapshot()          -- dzienny snapshot na wejscie (jak nie ma dzisiejszego)
        RegisterAddonMessagePrefix(AddonPrefix)
        CreateKloceButton()
        log("Addon loaded. Use /kloce")
        -- dolacz do kanalu (presence+klucze cross-guild); ponawiamy, bo czat bywa nie gotowy od razu
        if GK.JoinSyncChannel then
            GK.JoinSyncChannel()
            C_Timer.After(4, function() if GK.JoinSyncChannel then GK.JoinSyncChannel() end end)
        end
        -- presence+klucze po kanale; push list po GUILD (do gildii) — pierwszy raz po 8 s
        C_Timer.After(8, function()
            if GK.BroadcastMyKey then GK.BroadcastMyKey() end       -- kanal: K
            if GK.BroadcastPresence then GK.BroadcastPresence() end -- kanal: H
            if GK.BroadcastParty then GK.BroadcastParty() end       -- kanal: P
            if GK.FullBroadcast then GK.FullBroadcast() end         -- GUILD: wypchnij swoj stan gildii
            if GK.RecordPlayedWith then GK.RecordPlayedWith() end   -- jesli logujesz sie juz w grupie
            -- advert: start ticker when permitted and enabled (first fire is delayed anyway)
            if GK.AmIAdmin and GK.AmIAdmin() and GK.GetAdvConfig and GK.GetAdvConfig().enabled and GK.StartAdvTicker then
                GK.StartAdvTicker()
            end
        end)
        -- po zebraniu presence: pull od zrodla z TEJ SAMEJ gildii (odpowiedz leci po GUILD)
        C_Timer.After(14, function()
            local src = GK.PickSyncSource and GK.PickSyncSource()
            if src and GK.Send then
                GK.Send(MSG_SYNC, "WHISPER", src)
                log("Requesting sync from " .. src .. " ...")
            end
        end)
        C_Timer.NewTicker(30, function()
            if GK.JoinSyncChannel then GK.JoinSyncChannel() end     -- pilnuj obecnosci w kanale
            if GK.BroadcastMyKey then GK.BroadcastMyKey() end
            if GK.BroadcastPresence then GK.BroadcastPresence() end
            if GK.BroadcastParty then GK.BroadcastParty() end
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
    elseif event == "CHAT_MSG_CHANNEL" then
        -- presence + klucze po kanale (zwykly czat z prefiksem "GK~"); reszta czatu ignorowana
        local text, sender = ...
        if not text or text:sub(1, #GK.CHAN_PFX) ~= GK.CHAN_PFX then return end
        if normalizeName(sender) == normalizeName(GetUnitFullName("player")) then return end
        local parts = { strsplit(GK.CHAN_SEP, text:sub(#GK.CHAN_PFX + 1)) }
        local typ = parts[1]
        if typ == "H" then          -- core: class, spec, flags, ver, guild, zone, itype, ilvl, note
            if GK.ReceivePresence then GK.ReceivePresence(sender, parts[2], parts[3], parts[4], parts[5], parts[6], parts[7], parts[8], parts[9], parts[10], parts[11]) end
            if KloceFrame and KloceFrame.mode == "active" then
                if KloceFrame.RefreshPartyList then KloceFrame.RefreshPartyList() end
                if KloceFrame.RefreshList then KloceFrame.RefreshList() end
            end
        elseif typ == "P" then      -- party/team composition (leader,member,...)
            if GK.ReceiveParty then GK.ReceiveParty(sender, parts[2]) end
            if KloceFrame and KloceFrame.mode == "active" and KloceFrame.RefreshList then KloceFrame.RefreshList() end
        elseif typ == "K" then      -- key: dungeon, level
            if GK.ReceiveKey then GK.ReceiveKey(sender, parts[2], tonumber(parts[3])) end
        end
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
        if msg:sub(1, 5) == MSG_SYNC then   -- "SYNC?" — in-guild pull: reply with full state over GUILD
            if GK.FullBroadcast then GK.FullBroadcast(true) end
            return
        end
        if msg:sub(1, 3) == MSG_BREQ then   -- "BRQ" — directed pull request -> reply with full state via whisper
            if GK.IsSuperAdmin and GK.IsSuperAdmin(sender) and GK.FullBroadcast then
                GK.FullBroadcast(true, "WHISPER", sender)
            end
            return
        end
        if msg:sub(1, 3) == MSG_FSHARE then -- "FSH" — directed: do a share in MY guild
            if GK.IsSuperAdmin and GK.IsSuperAdmin(sender) and GK.ShareAll then GK.ShareAll() end
            return
        end
        if msg:sub(1, 4) == MSG_FLAG then   -- "FLG:" — set flags for a player
            if not (channel ~= "WHISPER" and GK.VersionBad and GK.VersionBad(sender)) and GK.ApplyFlag then GK.ApplyFlag(sender, msg:sub(5)) end
            return
        end
        if msg:sub(1, 5) == GK.MSG_ADVCFG then   -- "ADVC:" — advert config sync (LWW), only from a permitted sender
            local su = GK.addonUsers[normalizeName(sender)]
            local senderAllowed = (GK.IsSuperAdmin and GK.IsSuperAdmin(sender)) or (su and su.admin)
            if senderAllowed and GK.ReceiveAdvConfig then
                local t, en, text = strsplit("\031", msg:sub(6), 3)
                GK.ReceiveAdvConfig(t, en, text)
            end
            return
        end
        if msg:sub(1, 5) == GK.MSG_ADVDONE then   -- "ADVD:" — someone already broadcast this cycle (dedup)
            local su = GK.addonUsers[normalizeName(sender)]
            local senderAllowed = (GK.IsSuperAdmin and GK.IsSuperAdmin(sender)) or (su and su.admin)
            if senderAllowed and GK.NoteAdvDone then GK.NoteAdvDone() end
            return
        end
        if msg:sub(1, 4) == MSG_GANN then   -- "GAN:" — relay request: post the text to MY guild chat
            local text = msg:sub(5)
            local su = GK.addonUsers[normalizeName(sender)]
            local senderAllowed = (GK.IsSuperAdmin and GK.IsSuperAdmin(sender)) or (su and su.admin)
            -- whisper only, sender verified (from presence), I'm in a guild, non-empty text
            if channel == "WHISPER" and senderAllowed and text ~= "" and IsInGuild() then
                local line = "[via " .. displayName(sender) .. "] " .. text
                if #line > 255 then line = line:sub(1, 255) end
                SendChatMessage(line, "GUILD")
                log("Relayed announce from " .. displayName(sender) .. " to guild chat.")
            end
            return
        end
        -- Sync listy/detali/gildii â€” tylko gdy przyjmujesz zmiany od innych (kolko zebate).
        if not GigaKloceDB.acceptSync then return end
        -- gate wersji: odrzucamy GUILD-dane tylko gdy wersja nadawcy ZNANA i INNA (nieznana = akceptuj,
        -- bo presence z kanalu moze jeszcze nie dojsc, a format list jest stabilny). WHISPER (most) omija.
        if channel ~= "WHISPER" and GK.VersionBad and GK.VersionBad(sender) then return end
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
		-- Zapamietaj sklad do "last played with" (podpowiedzi w polu Add).
		if GK.RecordPlayedWith then GK.RecordPlayedWith() end
		-- Sklad sie zmienil -> rozglos party (event P), debounce zeby nie spamowac kanalu.
		if not presenceDebounce then
			presenceDebounce = true
			C_Timer.After(2, function()
				presenceDebounce = false
				if GK.BroadcastParty then GK.BroadcastParty() end
			end)
		end
	end
end)

-- ============================
-- CONTEXT MENU (wlasne) — Alt + lewy klik na jednostce
-- ============================
-- Alt+LEWY klik nie wywoluje menu Blizzarda (to prawy klik), wiec zadnego dublowania.
-- NIE dotykamy menu Blizzarda (UnitPopup) -> zaden taint nie psuje Set Focus/Target.
-- Otwieramy WLASNY dropdown (osobna ramka) przez EasyMenu.
local gkUnitMenuFrame = CreateFrame("Frame", "GigaKloceUnitMenu", UIParent, "UIDropDownMenuTemplate")

local function GK_OpenMenuForName(name)
    if not name then return end
    local onKloce = has_value(gigakloce, name)
    local onChad = has_value(gigachad, name)
    local menu = {
        { text = name, isTitle = true, notCheckable = true },
        { text = onKloce and "|cffff5555Remove from Kloce|r" or "|cffff7d0aAdd to Kloce|r",
          notCheckable = true,
          func = function() if onKloce then RemoveKloce(name) else AddKloce(name) end end },
        { text = "|cffffd200Block guild (/who)|r",
          notCheckable = true,
          func = function() if GK.WhoAddGuild then GK.WhoAddGuild(name) end end },
        { text = onChad and "|cff55ddffRemove from Chads|r" or "|cff40ff40Add to Chads|r",
          notCheckable = true,
          func = function() if onChad then RemoveChad(name) else AddChad(name) end end },
        { text = "Cancel", notCheckable = true, func = function() end },
    }
    CloseDropDownMenus()           -- zamknij ewentualne menu Blizzarda, zeby zostalo tylko nasze
    EasyMenu(menu, gkUnitMenuFrame, "cursor", 0, 0, "MENU")
end
GK.OpenUnitMenu = GK_OpenMenuForName

local function GK_TriggerForUnit(unit)
    if not (unit and UnitExists(unit) and UnitIsPlayer(unit)) then return end
    if UnitIsUnit(unit, "player") then return end   -- nie na sobie
    local name = GetUnitFullName(unit)
    if not name then return end
    -- defer o klatke: nasze menu otwiera sie PO menu Blizzarda, wiec je nadpisuje
    C_Timer.After(0, function() GK_OpenMenuForName(name) end)
end

-- Swiat / nameplate'y: Alt + lewy klik na jednostce pod kursorem
WorldFrame:HookScript("OnMouseUp", function(self, button)
    if button == "LeftButton" and IsAltKeyDown() then
        GK_TriggerForUnit("mouseover")
    end
end)

-- Standardowe ramki jednostek: Alt + lewy klik
local function GK_HookUnitFrame(frame, unit)
    if not frame then return end
    frame:HookScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and IsAltKeyDown() then
            GK_TriggerForUnit(self.unit or unit)
        end
    end)
end
GK_HookUnitFrame(PlayerFrame, "player")
GK_HookUnitFrame(TargetFrame, "target")
GK_HookUnitFrame(FocusFrame, "focus")
for i = 1, 4 do
    GK_HookUnitFrame(_G["PartyMemberFrame"..i], "party"..i)
end

-- ============================
-- "Invite to guild" w menu Blizzarda (UnitPopup) — np. prawy klik na nicku w czacie.
-- UWAGA: dotykamy UnitPopup (ten sam mechanizm co taint Set Focus). Testowe; latwy rewert.
-- ============================
do
    local GK_GINV = "GIGAKLOCE_GUILDINVITE"
    local function canGuildInvite()
        if CanGuildInvite then return CanGuildInvite() end
        return IsInGuild()
    end
    if UnitPopupButtons and UnitPopupMenus then
        UnitPopupButtons[GK_GINV] = { text = "Invite to guild", dist = 0 }
        -- Tylko menu spolecznosciowe (typy uzywane przez dropdown nicku z CZATU). NIE party/raid/unit-frame.
        local MENUS = { "PLAYER", "FRIEND", "FRIEND_OFFLINE", "CHAT_ROSTER" }
        for _, m in ipairs(MENUS) do
            local list = UnitPopupMenus[m]
            if list then
                local exists = false
                for _, v in ipairs(list) do if v == GK_GINV then exists = true break end end
                if not exists then table.insert(list, #list, GK_GINV) end   -- przed "Cancel"
            end
        end

        -- Widocznosc: pokazuj WYLACZNIE w menu nicku otwartym z CZATU.
        -- Czatowy dropdown to ramka FriendsDropDown (i NIE jest z listy znajomych: friendsList=false).
        -- Ramki jednostek (PlayerFrameDropDown/PartyMemberFrameXDropDown/...) maja inny obiekt -> nie pokaze sie.
        hooksecurefunc("UnitPopup_HideButtons", function()
            local dd = UIDROPDOWNMENU_INIT_MENU
            local which = dd and dd.which
            local list = which and UnitPopupMenus[which]
            if not list then return end
            local fromChat = (dd == FriendsDropDown) and (not dd.friendsList)
            for index, value in ipairs(list) do
                if value == GK_GINV then
                    local show = fromChat and canGuildInvite() and (dd.name ~= nil and dd.name ~= "")
                    if not show and UnitPopupShown[UIDROPDOWNMENU_MENU_LEVEL] then
                        UnitPopupShown[UIDROPDOWNMENU_MENU_LEVEL][index] = 0
                    end
                end
            end
        end)

        -- Klik: zapros do gildii (sklejamy Name-Realm gdy realm znany).
        hooksecurefunc("UnitPopup_OnClick", function(self)
            if self.value ~= GK_GINV then return end
            local dd = UIDROPDOWNMENU_INIT_MENU
            local name = dd and dd.name
            if not name or name == "" then return end
            local server = dd.server
            local full = (server and server ~= "" and (name .. "-" .. server)) or name
            if GuildInvite then GuildInvite(full) end
        end)
    end
end

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

StaticPopupDialogs["GIGAKLOCE_ANNOUNCE"] = {
    text = "Guild-announce do %s\n(wrzuci na czat jego gildii; mozesz shift-klik wkleic link):",
    button1 = "Send",
    button2 = "Cancel",
    hasEditBox = true,
    maxLetters = 230,
    editBoxWidth = 320,
    OnShow = function(self) GK.announceEditBox = self.editBox end,
    OnHide = function(self) if GK.announceEditBox == self.editBox then GK.announceEditBox = nil end end,
    OnAccept = function(self, data)
        if GK.SendGuildAnnounce then GK.SendGuildAnnounce(data, self.editBox:GetText()) end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        if GK.SendGuildAnnounce then GK.SendGuildAnnounce(parent.data, self:GetText()) end
        parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}
-- shift-klik na przedmiocie/czarze wkleja link do pola ogloszenia (gdy popup ma fokus)
hooksecurefunc("ChatEdit_InsertLink", function(link)
    local eb = GK.announceEditBox
    if link and eb and eb:IsShown() and eb:HasFocus() then eb:Insert(link) end
end)

StaticPopupDialogs["GIGAKLOCE_ADVTEXT"] = {
    text = "Global channel announcement text:",
    button1 = "Save",
    button2 = "Cancel",
    hasEditBox = true,
    maxLetters = 255,
    editBoxWidth = 320,
    OnShow = function(self)
        self.editBox:SetText((GK.GetAdvConfig and GK.GetAdvConfig().text) or "")
        self.editBox:HighlightText()
    end,
    OnAccept = function(self)
        if GK.SetAdvConfig and GK.GetAdvConfig then
            GK.SetAdvConfig(GK.GetAdvConfig().enabled, self.editBox:GetText())
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        if GK.SetAdvConfig and GK.GetAdvConfig then
            GK.SetAdvConfig(GK.GetAdvConfig().enabled, self:GetText())
        end
        parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

StaticPopupDialogs["GIGAKLOCE_NEWPRESET"] = {
    text = "New party preset name:",
    button1 = "Create",
    button2 = "Cancel",
    hasEditBox = true,
    maxLetters = 32,
    OnAccept = function(self)
        local name = self.editBox and self.editBox:GetText()
        if GK.NewPreset and GK.NewPreset(name) and KloceFrame and KloceFrame.SetMode then
            KloceFrame.presetOpen = true; GigaKloceDB.presetOpen = true; KloceFrame.SetMode("active")
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local name = self:GetText()
        if GK.NewPreset and GK.NewPreset(name) and KloceFrame and KloceFrame.SetMode then
            KloceFrame.presetOpen = true; GigaKloceDB.presetOpen = true; KloceFrame.SetMode("active")
        end
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
        if KloceFrame and KloceFrame.SetMode then KloceFrame.SetMode("active") end
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
