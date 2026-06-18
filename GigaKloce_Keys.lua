-- ============================
-- GigaKloce :: Keys (klucze M+ — detekcja, broadcast, odbior)
-- ============================
local ADDON, GK = ...
local AddonPrefix, guildKeys, log, displayName, normalizeName, GetUnitFullName =
    GK.AddonPrefix, GK.guildKeys, GK.log, GK.displayName, GK.normalizeName, GK.GetUnitFullName

local KEYSTONE_ID = 138019   -- Mythic Keystone (Legion)
local KEY_STALE = 180        -- po tylu sekundach bez odswiezenia uznajemy klucz za nieaktualny

-- Nazwy podziemi Legion (czyste). Szukamy ich w linku klucza (jak Twoja WeakAura).
local DUNGEONS = {
    "Court of Stars", "Eye of Azshara", "Black Rook Hold", "Neltharion's Lair",
    "Maw of Souls", "Darkheart Thicket", "Vault of the Wardens", "The Arcway",
    "Halls of Valor", "Cathedral of Eternal Night", "Lower Karazhan", "Upper Karazhan",
    "Return to Karazhan", "Seat of the Triumvirate",
}

-- ukryty tooltip do odczytu poziomu klucza (tworzony leniwie, NIE przy ladowaniu pliku)
local scanTip
local function getScanTip()
    if not scanTip then
        scanTip = CreateFrame("GameTooltip", "GigaKloceKeyScan", nil, "GameTooltipTemplate")
    end
    return scanTip
end

local function readLevel(bag, slot, link)
    local scanTip = getScanTip()
    scanTip:SetOwner(UIParent, "ANCHOR_NONE")
    scanTip:ClearLines()
    scanTip:SetBagItem(bag, slot)
    for i = 1, scanTip:NumLines() do
        local fs = _G["GigaKloceKeyScanTextLeft" .. i]
        local txt = fs and fs:GetText()
        if txt then
            local lvl = txt:match("[Ll]evel%s*(%d+)") or txt:match("%((%d+)%)") or txt:match("%+%s*(%d+)")
            if lvl then return tonumber(lvl) end
        end
    end
    -- fallback: sprobuj z linka
    if link then
        local lvl = link:match("%((%d+)%)") or link:match("%+%s*(%d+)")
        if lvl then return tonumber(lvl) end
    end
    return nil
end

-- Zwraca: dungeon (czysta nazwa) , level , link  — albo nil jesli brak klucza w bagach.
function GK.GetMyKeystone()
    for bag = 0, NUM_BAG_SLOTS do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, (numSlots or 0) do
            if GetContainerItemID(bag, slot) == KEYSTONE_ID then
                local link = GetContainerItemLink(bag, slot)
                local low = link and link:lower()
                local dungeon
                if low then
                    for _, d in ipairs(DUNGEONS) do
                        if low:find(d:lower(), 1, true) then dungeon = d; break end
                    end
                end
                return (dungeon or "Mythic Keystone"), readLevel(bag, slot, link), link
            end
        end
    end
    return nil
end

-- Wlasna PUBLIC note z gildii (z rostera). "" gdy brak/gildia nie wczytana. Officer note NIE ruszamy.
local function myGuildNote()
    if not IsInGuild() then return "" end
    if type(GuildRoster) == "function" then GuildRoster() end   -- odswiez (async; czytamy co jest w cache)
    local me = UnitName("player")
    for i = 1, (GetNumGuildMembers() or 0) do
        local name, _, _, _, _, _, publicNote = GetGuildRosterInfo(i)
        if name then
            local nm = strsplit("-", name)   -- roster bywa "Nick-Realm"
            if nm == me then return publicNote or "" end
        end
    end
    return ""
end

-- Rozglasza Twoj klucz po KANALE (cicho, cross-guild) i zapisuje lokalnie.
function GK.BroadcastMyKey()
    local dungeon, level = GK.GetMyKeystone()
    if not dungeon then return end
    local me = GetUnitFullName("player")
    local _, ilvl = GetAverageItemLevel()
    ilvl = math.floor((ilvl or 0) + 0.5)
    local note = (myGuildNote():gsub("[%c~]", " ")):sub(1, 60)   -- bez znakow kontrolnych/~, limit
    -- UWAGA: strefa/typ instancji NIE leci z kluczem — jedzie z presence (GK.BroadcastPresence),
    -- dzieki czemu lokalizacje znamy TEZ dla osob bez klucza.
    guildKeys[normalizeName(me)] = { name = displayName(me), dungeon = dungeon, level = level or 0, ilvl = ilvl, note = note, t = GetTime() }
    local s = GK.CHAN_SEP
    GK.SendChan("K" .. s .. (tostring(dungeon):gsub("[%c~]", " ")) .. s .. (level or 0) .. s .. ilvl .. s .. note)
    if KloceFrame and KloceFrame.mode == "active" and KloceFrame.RefreshList then KloceFrame.RefreshList() end
end

-- Odbior klucza z kanalu (pola juz rozbite przez parser w Events).
function GK.ReceiveKey(sender, dungeon, lvl, ilvl, note)
    if not dungeon or dungeon == "" then return end
    guildKeys[normalizeName(sender)] = {
        name = displayName(sender),
        dungeon = dungeon,
        level = tonumber(lvl) or 0,
        ilvl = tonumber(ilvl) or 0,
        note = note or "",
        t = GetTime(),
    }
    if KloceFrame and KloceFrame.mode == "active" and KloceFrame.RefreshList then
        KloceFrame.RefreshList()
    end
end

-- Usuwa nieaktualne wpisy (gracz wylogowany / nie nadaje). Zwraca posortowana liste.
function GK.GetSortedKeys()
    local now = GetTime()
    local list = {}
    for k, v in pairs(guildKeys) do
        if (now - (v.t or 0)) > KEY_STALE then
            guildKeys[k] = nil
        else
            table.insert(list, v)
        end
    end
    table.sort(list, function(a, b)
        if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) > (b.level or 0) end
        return (a.name or "") < (b.name or "")
    end)
    return list
end
