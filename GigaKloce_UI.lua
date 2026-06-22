-- ============================
-- GigaKloce :: UI (okno, Details, ikona, zebatka)
-- ============================
local ADDON, GK = ...
local AddonPrefix, MSG_KADD, MSG_KREM, MSG_CADD, MSG_CREM, KLOCE_TAGS, DEFAULT_TAG, TAG_COLORS, TAG_ICONS, gigakloce, gigachad, gigakloceInfo, sessionKloceToStay, promptedKloce, InitSaved, log, normalizeName, canonicalDisplay, displayName, GetUnitFullName, ensureRealm, has_value, getIndex, RosterUnitName, ClassifyMember, HasKloceInGroup, UpdateKloceAlert, DetectKloceInGroup, GetGroupLeadersAndAssistants, RefreshUI, EnsureKloceInfo, GetKloceInfo, KLOCE_SEP, BroadcastKloceDetails, AddKloce, RemoveKloce, AddChad, RemoveChad, sendRepartyLeader, MakeDailySnapshot, RestoreSnapshot = GK.AddonPrefix, GK.MSG_KADD, GK.MSG_KREM, GK.MSG_CADD, GK.MSG_CREM, GK.KLOCE_TAGS, GK.DEFAULT_TAG, GK.TAG_COLORS, GK.TAG_ICONS, GK.gigakloce, GK.gigachad, GK.gigakloceInfo, GK.sessionKloceToStay, GK.promptedKloce, GK.InitSaved, GK.log, GK.normalizeName, GK.canonicalDisplay, GK.displayName, GK.GetUnitFullName, GK.ensureRealm, GK.has_value, GK.getIndex, GK.RosterUnitName, GK.ClassifyMember, GK.HasKloceInGroup, GK.UpdateKloceAlert, GK.DetectKloceInGroup, GK.GetGroupLeadersAndAssistants, GK.RefreshUI, GK.EnsureKloceInfo, GK.GetKloceInfo, GK.KLOCE_SEP, GK.BroadcastKloceDetails, GK.AddKloce, GK.RemoveKloce, GK.AddChad, GK.RemoveChad, GK.sendRepartyLeader, GK.MakeDailySnapshot, GK.RestoreSnapshot
local onOff = GK.onOff
local GetSortedKeys, GetMyKeystone, BroadcastMyKey = GK.GetSortedKeys, GK.GetMyKeystone, GK.BroadcastMyKey
local BroadcastChadDetails = GK.BroadcastChadDetails

-- ============================
-- UI
-- ============================
local KloceFrame

-- ============================
-- DETALE GRACZA (klasa + spec + notatka + data/kto; tag tylko dla Kloce) â€” Kloce i Chady
-- ============================
local CLASS_ORDER = CLASS_SORT_ORDER or {
    "WARRIOR","DEATHKNIGHT","PALADIN","MONK","PRIEST","SHAMAN",
    "DRUID","ROGUE","MAGE","WARLOCK","HUNTER","DEMONHUNTER",
}
local function classLocName(cf)
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[cf]) or cf
end
local function classColored(cf)
    if not cf or cf == "" then return "|cff888888(unknown)|r" end
    local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[cf]
    if cc and cc.colorStr then return "|c" .. cc.colorStr .. classLocName(cf) .. "|r" end
    return classLocName(cf)
end

-- "Imie" pokolorowane wg klasy (cf = classFile, np. "MAGE").
local function nameColored(name, cf)
    local cc = cf and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cf]
    if cc and cc.colorStr then return "|c" .. cc.colorStr .. name .. "|r" end
    return name
end
-- "+lvl" pokolorowane wg tieru klucza (spojnie z keyLvlStr w RefreshList).
local function keyLevelColored(lvl)
    lvl = lvl or 0
    local hex = (lvl >= 15 and "ff4d3f") or (lvl >= 12 and "ff8c33") or (lvl >= 9 and "a66cf2")
        or (lvl >= 6 and "4d99ff") or "aaaaaa"
    return "|cff" .. hex .. "+" .. lvl .. "|r"
end

-- mapa classFile ("DRUID") -> classID (numer), budowana leniwie raz
local CLASS_ID_BY_FILE
local function classIDByFile(cf)
    if not cf or cf == "" then return nil end
    if not CLASS_ID_BY_FILE then
        CLASS_ID_BY_FILE = {}
        local n = (GetNumClasses and GetNumClasses()) or 12
        for i = 1, n do
            local _, file = GetClassInfo(i)
            if file then CLASS_ID_BY_FILE[file] = i end
        end
    end
    return CLASS_ID_BY_FILE[cf]
end
-- nazwy specow danej klasy (np. {"Balance","Feral","Guardian","Restoration"})
local function specsForClass(cf)
    local list = {}
    local cid = classIDByFile(cf)
    if cid and GetNumSpecializationsForClassID and GetSpecializationInfoForClassID then
        for i = 1, GetNumSpecializationsForClassID(cid) do
            local _, name = GetSpecializationInfoForClassID(cid, i)
            if name and name ~= "" then list[#list + 1] = name end
        end
    end
    return list
end
local function specValidForClass(spec, cf)
    if not spec or spec == "" then return false end
    for _, n in ipairs(specsForClass(cf)) do if n == spec then return true end end
    return false
end
-- Inline-ikona speca (kazdy spec ma wlasna). "" gdy nieznany/niedopasowany.
local function specIconStr(cf, specName)
    if not specName or specName == "" then return "" end
    local cid = classIDByFile(cf)
    if not cid or not GetNumSpecializationsForClassID or not GetSpecializationInfoForClassID then return "" end
    for i = 1, GetNumSpecializationsForClassID(cid) do
        local _, name, _, icon = GetSpecializationInfoForClassID(cid, i)
        if name == specName and icon then
            return string.format("|T%s:16:16:0:0|t ", icon)
        end
    end
    return ""
end

local KloceDetailFrame
local function BuildKloceDetailFrame()
    if KloceDetailFrame then return KloceDetailFrame end
    local f = CreateFrame("Frame", "KloceDetailFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(400, 400)
    f:SetPoint("CENTER", 0, 40)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    table.insert(UISpecialFrames, "KloceDetailFrame")

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.title:SetPoint("CENTER", f.TitleBg, "CENTER", 0, 0)
    f.title:SetText("Player Details")

    f.nameFS = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.nameFS:SetPoint("TOPLEFT", 16, -32)

    f.metaFS = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.metaFS:SetPoint("TOPLEFT", 16, -54)

    -- ===== Klasa (dropdown) + Spec (dropdown) =====
    local function syncDetail()
        local info = f.key and gigakloceInfo[f.key]
        if info then info.t = (GK.now and GK.now()) or 0 end   -- edycja = nowsza zmiana (wygra przy sync)
        if KloceFrame and KloceFrame.RefreshList then KloceFrame.RefreshList() end
        if f.entry then
            if f.isKloce then BroadcastKloceDetails(f.entry) else BroadcastChadDetails(f.entry) end
        end
    end

    local function setClass(cf)
        local info = f.key and gigakloceInfo[f.key]
        if not info then return end
        info.class = cf or ""
        -- spec nalezacy do innej klasy -> wyczysc (np. zmiana Druid -> Mage)
        if info.spec and info.spec ~= "" and not specValidForClass(info.spec, info.class) then
            info.spec = ""
        end
        f.UpdateClass()
        if f.UpdateSpec then f.UpdateSpec() end
        syncDetail()
    end

    local classLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    classLabel:SetPoint("TOPLEFT", 16, -82)
    classLabel:SetText("Class:")

    local classDD = CreateFrame("Frame", "KloceClassDropdown", f, "UIDropDownMenuTemplate")
    classDD:SetPoint("TOPLEFT", classLabel, "BOTTOMLEFT", -16, -2)
    UIDropDownMenu_SetWidth(classDD, 130)
    UIDropDownMenu_Initialize(classDD, function(self, level)
        local cur = (f.key and gigakloceInfo[f.key] and gigakloceInfo[f.key].class) or ""
        local none = UIDropDownMenu_CreateInfo()
        none.text = "|cff888888(unknown)|r"; none.value = ""
        none.checked = (cur == "")
        none.func = function() setClass("") end
        UIDropDownMenu_AddButton(none, level)
        for _, cf in ipairs(CLASS_ORDER) do
            local item = UIDropDownMenu_CreateInfo()
            item.text = classColored(cf)
            item.value = cf
            item.checked = (cur == cf)
            item.func = function() setClass(cf) end
            UIDropDownMenu_AddButton(item, level)
        end
    end)
    f.classDD = classDD
    function f.UpdateClass()
        local info = f.key and gigakloceInfo[f.key]
        UIDropDownMenu_SetText(classDD, classColored(info and info.class or ""))
    end

    local function setSpec(name)
        local info = f.key and gigakloceInfo[f.key]
        if not info then return end
        info.spec = name or ""
        f.UpdateSpec()
        syncDetail()
    end

    local specLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    specLabel:SetPoint("TOPLEFT", 210, -82)
    specLabel:SetText("Spec:")

    local specDD = CreateFrame("Frame", "KloceSpecDropdown", f, "UIDropDownMenuTemplate")
    specDD:SetPoint("TOPLEFT", specLabel, "BOTTOMLEFT", -16, -2)
    UIDropDownMenu_SetWidth(specDD, 130)
    UIDropDownMenu_Initialize(specDD, function(self, level)
        local info = f.key and gigakloceInfo[f.key]
        local cur = (info and info.spec) or ""
        local cf = (info and info.class) or ""
        local none = UIDropDownMenu_CreateInfo()
        none.text = "|cff888888(unknown)|r"; none.value = ""
        none.checked = (cur == "")
        none.func = function() setSpec("") end
        UIDropDownMenu_AddButton(none, level)
        local specs = specsForClass(cf)
        if #specs == 0 then
            local hint = UIDropDownMenu_CreateInfo()
            hint.text = "|cff666666(set class first)|r"; hint.notCheckable = true; hint.disabled = true
            UIDropDownMenu_AddButton(hint, level)
        end
        for _, sname in ipairs(specs) do
            local item = UIDropDownMenu_CreateInfo()
            item.text = sname; item.value = sname
            item.checked = (cur == sname)
            item.func = function() setSpec(sname) end
            UIDropDownMenu_AddButton(item, level)
        end
    end)
    f.specDD = specDD
    function f.UpdateSpec()
        local info = f.key and gigakloceInfo[f.key]
        local s = info and info.spec
        UIDropDownMenu_SetText(specDD, (s and s ~= "") and s or "|cff888888(unknown)|r")
    end

    -- ===== Tag (tylko Kloce) =====
    local tagLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tagLabel:SetPoint("TOPLEFT", 16, -140)
    tagLabel:SetText("Tag:")
    f.tagLabel = tagLabel

    local tagDD = CreateFrame("Frame", "KloceTagDropdown", f, "UIDropDownMenuTemplate")
    tagDD:SetPoint("TOPLEFT", tagLabel, "BOTTOMLEFT", -16, -2)
    UIDropDownMenu_SetWidth(tagDD, 130)
    UIDropDownMenu_Initialize(tagDD, function(self, level)
        for _, t in ipairs(KLOCE_TAGS) do
            local item = UIDropDownMenu_CreateInfo()
            item.text = t
            item.value = t
            item.checked = (f.key and gigakloceInfo[f.key] and gigakloceInfo[f.key].tag == t) or false
            item.func = function()
                local key = f.key
                local info = key and gigakloceInfo[key]
                if info then
                    info.tag = t
                    info.t = (GK.now and GK.now()) or 0   -- nowsza zmiana
                    UIDropDownMenu_SetText(tagDD, t)
                    if KloceFrame and KloceFrame.RefreshList then KloceFrame.RefreshList() end
                    if f.entry then BroadcastKloceDetails(f.entry) end   -- sync (ostatni wygrywa)
                end
            end
            UIDropDownMenu_AddButton(item, level)
        end
    end)
    f.tagDD = tagDD
    function f.UpdateTag()
        local info = f.key and gigakloceInfo[f.key]
        UIDropDownMenu_SetText(tagDD, (info and info.tag) or DEFAULT_TAG)
    end

    -- ===== Notatka =====
    local noteLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    noteLabel:SetText("Note (why):")
    f.noteLabel = noteLabel

    local noteBg = CreateFrame("Frame", nil, f)
    noteBg:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    noteBg:SetBackdropColor(0, 0, 0, 0.6)
    noteBg:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.9)
    f.noteBg = noteBg

    local box = CreateFrame("EditBox", nil, noteBg)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetFontObject(ChatFontNormal)
    box:SetPoint("TOPLEFT", 8, -8)
    box:SetPoint("BOTTOMRIGHT", -8, 8)
    box:SetJustifyH("LEFT")
    box:SetMaxLetters(70)   -- notatka max 70 znakow
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnTextChanged", function(self)
        local key = f.key
        if key and gigakloceInfo[key] then gigakloceInfo[key].note = self:GetText() end
    end)
    box:SetScript("OnEditFocusLost", function(self)
        local key = f.key
        if key and gigakloceInfo[key] then
            gigakloceInfo[key].note = self:GetText()
            gigakloceInfo[key].t = (GK.now and GK.now()) or 0   -- nowsza zmiana
            if f.entry then
                if f.isKloce then BroadcastKloceDetails(f.entry) else BroadcastChadDetails(f.entry) end
            end
        end
    end)
    noteBg:EnableMouse(true)
    noteBg:SetScript("OnMouseDown", function() box:SetFocus() end)
    f.noteBox = box

    -- Odswieza wszystkie pola z bocznej tabeli + uklada wg trybu (kloce ma tag, chad nie).
    function f.RefreshAll()
        local info = (f.key and gigakloceInfo[f.key]) or {}
        if f.entry then f.nameFS:SetText(displayName(f.entry)) end
        f.title:SetText(f.isKloce and "Kloce Details" or "Chad Details")
        f.metaFS:SetText("Added: " .. (info.added or "?") .. ((info.by and info.by ~= "") and ("  by " .. info.by) or ""))
        f.UpdateClass()
        f.UpdateSpec()
        f.UpdateTag()
        f.noteBox:SetText(info.note or "")
        if f.isKloce then
            f.tagLabel:Show(); f.tagDD:Show()
            f.noteLabel:ClearAllPoints(); f.noteLabel:SetPoint("TOPLEFT", 16, -198)
            f.noteBg:ClearAllPoints()
            f.noteBg:SetPoint("TOPLEFT", 14, -214); f.noteBg:SetPoint("BOTTOMRIGHT", -14, 16)
        else
            f.tagLabel:Hide(); f.tagDD:Hide()
            f.noteLabel:ClearAllPoints(); f.noteLabel:SetPoint("TOPLEFT", 16, -140)
            f.noteBg:ClearAllPoints()
            f.noteBg:SetPoint("TOPLEFT", 14, -156); f.noteBg:SetPoint("BOTTOMRIGHT", -14, 16)
        end
    end

    KloceDetailFrame = f
    return f
end

function ShowKloceDetails(entry)
    local key = normalizeName(entry)
    if key == "" then return end
    EnsureKloceInfo(entry)
    local f = BuildKloceDetailFrame()
    f.key = key
    f.entry = entry
    f.isKloce = has_value(gigakloce, entry)
    f.RefreshAll()
    f:Show()
end

-- ============================
-- OKNO: STATY PODZIEMI (read-only) — highest key + ostatni przebieg (% dmg). Klik usera w Active.
-- ============================
local function BuildDungeonDetailFrame()
    if GigaKloceDungeonFrame then return GigaKloceDungeonFrame end
    local f = CreateFrame("Frame", "GigaKloceDungeonFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(320, 470)
    f:SetPoint("CENTER", 0, 40)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    table.insert(UISpecialFrames, "GigaKloceDungeonFrame")

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.title:SetPoint("CENTER", f.TitleBg, "CENTER", 0, 0)
    f.title:SetText("M+ stats")

    f.nameFS = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.nameFS:SetPoint("TOPLEFT", 16, -34)

    f.bodyFS = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.bodyFS:SetPoint("TOPLEFT", 16, -62)
    f.bodyFS:SetPoint("TOPRIGHT", -16, -62)
    f.bodyFS:SetJustifyH("LEFT"); f.bodyFS:SetJustifyV("TOP"); f.bodyFS:SetSpacing(5)

    function f.RefreshAll()
        local entry = f.entry
        if not entry then return end
        local cf = GK.ClassOf and GK.ClassOf(entry)
        local sp = GK.SpecOf and GK.SpecOf(entry)
        local icon = specIconStr(cf, sp)
        f.nameFS:SetText(icon .. nameColored(displayName(entry), cf))

        local lines = {}
        local function add(s) lines[#lines + 1] = s end

        local clsSpec = classColored(cf or "")
        if sp and sp ~= "" then clsSpec = clsSpec .. "  |cffcccccc" .. sp .. "|r" end
        add(clsSpec)

        local il = GK.IlvlOf and GK.IlvlOf(entry)
        if il and il > 0 then add("Item level: |cff9d9d9d" .. il .. "|r") end
        local zone = GK.ZoneOf and GK.ZoneOf(entry)
        if zone and zone ~= "" then add("Zone: |cffffffff" .. zone .. "|r") end
        local nt = GK.NoteOf and GK.NoteOf(entry)
        if nt and nt ~= "" then add("Note: |cff6688aa" .. nt .. "|r") end
        add(" ")

        -- best key per podziemie (wszystkie 14 z kanalu "D"); * = w czasie, — = brak
        add("|cffffd200Best keys:|r |cff888888(* = timed)|r")
        local best, bestTimed
        if GK.BestKeysOf then best, bestTimed = GK.BestKeysOf(entry) end
        best = best or {}
        for i, dn in ipairs(GK.MPLUS_DUNGEONS or {}) do
            local short = (GK.MPLUS_SHORT and GK.MPLUS_SHORT[i]) or dn
            local lvl = best[i] or 0
            if lvl > 0 then
                add("  " .. short .. "   " .. keyLevelColored(lvl) .. ((bestTimed and bestTimed[i]) and " |cff40ff40*|r" or ""))
            else
                add("  |cff666666" .. short .. "   —|r")
            end
        end
        add(" ")

        local ld, ll, lt, lp
        if GK.LastRunOf then ld, ll, lt, lp = GK.LastRunOf(entry) end
        if ld then
            local pct = (lp ~= nil) and ("  |cffffffff" .. lp .. "% dmg|r |cff888888(top=100%)|r") or ""
            add("|cffffd200Last run:|r " .. keyLevelColored(ll) .. " " .. ld .. (lt and " |cff40ff40*|r" or "") .. pct)
        end

        f.bodyFS:SetText(table.concat(lines, "\n"))
    end

    return f
end

function ShowDungeonDetails(entry)
    if not entry or entry == "" then return end
    local f = BuildDungeonDetailFrame()
    f.entry = entry
    f.RefreshAll()
    f:Show()
end

-- ============================
-- OKNO: BLOKOWANE GILDIE (zarzadzanie lista)
-- ============================
local BlockedGuildsFrame
local function BuildBlockedGuildsFrame()
    if BlockedGuildsFrame then return BlockedGuildsFrame end
    local f = CreateFrame("Frame", "GigaKloceGuildFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(340, 380)
    f:SetPoint("CENTER", 0, 30)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    table.insert(UISpecialFrames, "GigaKloceGuildFrame")

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.title:SetPoint("CENTER", f.TitleBg, "CENTER", 0, 0)
    f.title:SetText("Blocked Guilds")

    local addBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    addBtn:SetSize(60, 22); addBtn:SetText("Add")
    addBtn:SetPoint("TOPRIGHT", -14, -34)

    local edit = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    edit:SetSize(1, 22)
    edit:SetPoint("TOPLEFT", 18, -34)
    edit:SetPoint("RIGHT", addBtn, "LEFT", -8, 0)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(48)

    local function doAdd()
        local name = edit:GetText()
        if GK.AddBlockedGuild and GK.AddBlockedGuild(name) then edit:SetText("") end
        edit:ClearFocus()
        f.Refresh()
    end
    addBtn:SetScript("OnClick", doAdd)
    edit:SetScript("OnEnterPressed", doAdd)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- lista z przewijaniem
    local scroll = CreateFrame("ScrollFrame", "GigaKloceGuildScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 14, -64)
    scroll:SetPoint("BOTTOMRIGHT", -34, 14)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(290, 1)
    scroll:SetScrollChild(content)
    -- szerokosc childa = szerokosc scrolla (inaczej wiersze i przyciski Remove sa sciesnione i nieklikalne)
    scroll:SetScript("OnSizeChanged", function(self) content:SetWidth(math.max(self:GetWidth(), 50)) end)

    f.rows = {}
    local ROWH = 24
    local function acquire(i)
        local r = f.rows[i]
        if r then return r end
        r = CreateFrame("Button", nil, content)
        r:SetSize(260, ROWH)
        r:SetPoint("TOPLEFT", 4, -((i - 1) * ROWH) - 2)
        r:SetPoint("RIGHT", content, "RIGHT", -4, 0)
        r.bg = r:CreateTexture(nil, "BACKGROUND")
        r.bg:SetAllPoints(); r.bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.03 or 0.06)
        r.text = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        r.text:SetPoint("LEFT", 6, 0)
        r.del = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
        r.del:SetSize(64, 20); r.del:SetText("Remove")
        r.del:SetPoint("RIGHT", -2, 0)
        f.rows[i] = r
        return r
    end

    f.empty = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.empty:SetPoint("TOPLEFT", 6, -6)
    f.empty:SetText("No blocked guilds yet.")

    function f.Refresh()
        local list = (GK.GetBlockedGuilds and GK.GetBlockedGuilds()) or {}
        f.title:SetText("Blocked Guilds |cff888888(" .. #list .. ")|r")
        if #list == 0 then f.empty:Show() else f.empty:Hide() end
        for i, g in ipairs(list) do
            local r = acquire(i)
            r.text:SetText(g)
            r.del:SetScript("OnClick", function()
                if GK.RemoveBlockedGuild then GK.RemoveBlockedGuild(g) end
                f.Refresh()
            end)
            r:Show()
        end
        for i = #list + 1, #f.rows do f.rows[i]:Hide() end
        content:SetHeight(math.max(#list * ROWH + 4, 10))
    end

    BlockedGuildsFrame = f
    return f
end

function ShowBlockedGuilds()
    local f = BuildBlockedGuildsFrame()
    -- pozwol modulowi Guilds odswiezac liste po zmianach (slash/auto)
    if KloceFrame then KloceFrame.RefreshBlockedGuilds = f.Refresh end
    f.Refresh()
    f:Show()
end

local function CreateKloceUI()
    if KloceFrame then
        KloceFrame:Show()
        return
    end

    local saved = GigaKloceDB

    -- ===== Glowna ramka =====
    KloceFrame = CreateFrame("Frame", "KloceFrame", UIParent, "BasicFrameTemplateWithInset")
    KloceFrame:SetMinResize(460, 320)
    KloceFrame:SetSize(saved.sizeW or 560, saved.sizeH or 460)
    KloceFrame.mode = "active"
    KloceFrame.presetOpen = saved.presetOpen and true or false
    KloceFrame.partyOpen = saved.partyOpen and true or false
    table.insert(UISpecialFrames, "KloceFrame")

    if saved.posX and saved.posY then
        KloceFrame:ClearAllPoints()
        KloceFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", saved.posX, saved.posY)
    else
        KloceFrame:SetPoint("CENTER")
    end

    KloceFrame.title = KloceFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    KloceFrame.title:SetPoint("CENTER", KloceFrame.TitleBg, "CENTER", 0, 0)
    KloceFrame.title:SetText("Ortalion M+")

    -- ===== Portret (logo) w lewym gornym rogu =====
    -- Osobna ramka o WYZSZYM poziomie (inaczej Inset z szablonu zaslania dolna czesc).
    -- Pozycja zablokowana (CENTER wzgledem KloceFrame TOPLEFT). Okragle przyciecie maska.
    local portFrame = CreateFrame("Frame", nil, KloceFrame)
    portFrame:SetFrameLevel(KloceFrame:GetFrameLevel() + 10)
    portFrame:SetSize(74, 74)
    portFrame:SetPoint("CENTER", KloceFrame, "TOPLEFT", 25, -21)
    local portrait = portFrame:CreateTexture(nil, "ARTWORK")
    portrait:SetAllPoints(portFrame)
    portrait:SetTexture("Interface\\AddOns\\GigaKloce\\assets\\logo")   -- SetTexture (pewne; SetPortraitToTexture nie laduje custom blp)
    if portrait.SetMask then portrait:SetMask("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask") end
    KloceFrame.portrait = portrait

    -- ===== Kolko zebate (ustawienia: import snapshotu, accept sync) =====
    local gearMenu = CreateFrame("Frame", "GigaKloceGearDD", UIParent, "UIDropDownMenuTemplate")
    local userMenu = CreateFrame("Frame", "GigaKloceUserDD", UIParent, "UIDropDownMenuTemplate")  -- menu kontekstowe userow

    -- Wspolne menu kontekstowe dla KAZDEJ listy userow: zawsze Invite + Whisper (poza soba),
    -- plus optional extra items (privileged). Opened with right-click.
    local function openUserMenu(name, extra)
        if not name or name == "" then return end
        local who = displayName(name)
        local menu = { { text = who, isTitle = true, notCheckable = true } }
        if normalizeName(name) ~= normalizeName(GetUnitFullName("player")) then
            menu[#menu + 1] = { text = "Invite", notCheckable = true,
                func = function() if InviteUnit then InviteUnit(who) end end }
            menu[#menu + 1] = { text = "Whisper", notCheckable = true,
                func = function() if ChatFrame_SendTell then ChatFrame_SendTell(who) end end }
        end
        if extra then for _, e in ipairs(extra) do menu[#menu + 1] = e end end
        menu[#menu + 1] = { text = "Cancel", notCheckable = true, func = function() end }
        EasyMenu(menu, userMenu, "cursor", 0, 0, "MENU")
    end

    -- czy dana osoba jest w MOJEJ grupie (po nazwie)
    local function isInMyGroup(name)
        if not name or not IsInGroup() then return false end
        local key = normalizeName(name)
        for i = 1, GetNumGroupMembers() do
            local _, nm = RosterUnitName(i)
            if nm and normalizeName(nm) == key then return true end
        end
        return false
    end

    -- Builds extra context-menu items: privileged actions (flags, announce, cross-guild sync) plus
    -- Kick (when the person is in my group and I'm leader/assistant). Works for ANY name on a list.
    local function buildUserExtra(name)
        local extra = {}
        local amAdmin = GK.AmIAdmin and GK.AmIAdmin()
        local u = GK.addonUsers and GK.addonUsers[normalizeName(name)]
        -- Privileged options ONLY for addon users (they go via whisper to the target; pointless otherwise).
        -- Without the addon only Invite/Whisper remain (from openUserMenu).
        if amAdmin and u then
            local iAmSuper = GK.IsSuperAdmin and GK.IsSuperAdmin(UnitName("player"))
            local who = name
            local uAdmin = u and u.admin
            local uBlocked = u and u.blocked
            if iAmSuper then
                extra[#extra + 1] = { text = "Admin", isNotRadio = true, keepShownOnClick = false,
                    checked = function() return uAdmin end,
                    func = function() if GK.SetUserFlags then GK.SetUserFlags(who, not uAdmin, uBlocked) end end }
            end
            extra[#extra + 1] = { text = "Blocked", isNotRadio = true, keepShownOnClick = false,
                checked = function() return uBlocked end,
                func = function() if GK.SetUserFlags then GK.SetUserFlags(who, uAdmin, not uBlocked) end end }
            extra[#extra + 1] = { text = "|cff66ccffAnnounce to their guild...|r", notCheckable = true,
                func = function() StaticPopup_Show("GIGAKLOCE_ANNOUNCE", displayName(who), nil, who) end }
            if iAmSuper then   -- cross-guild sync
                extra[#extra + 1] = { text = "|cffffd200Pull sync (cross-guild)|r", notCheckable = true,
                    func = function() if GK.Send then GK.Send(GK.MSG_BREQ, "WHISPER", who) end
                        GK.out("Requested state from " .. displayName(who) .. ".") end }
                extra[#extra + 1] = { text = "|cffffd200Push sync (cross-guild)|r", notCheckable = true,
                    func = function() if GK.FullBroadcast then GK.FullBroadcast(true, "WHISPER", who) end
                        GK.out("Sent my state to " .. displayName(who) .. ".") end }
                extra[#extra + 1] = { text = "|cffffd200Force their guild-share|r", notCheckable = true,
                    func = function() if GK.Send then GK.Send(GK.MSG_FSHARE, "WHISPER", who) end
                        GK.out("Asked " .. displayName(who) .. " to share.") end }
            end
        end
        -- Kick: tylko gdy w mojej grupie, jestem liderem/asystentem i to nie ja
        if isInMyGroup(name) and (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player"))
           and normalizeName(name) ~= normalizeName(GetUnitFullName("player")) then
            extra[#extra + 1] = { text = "|cffff5555Kick|r", notCheckable = true,
                func = function()
                    UninviteUnit(displayName(name))
                    log("Kloc kicked: " .. displayName(name))
                    if KloceFrame.RefreshList then KloceFrame.RefreshList() end
                    if KloceFrame.RefreshPartyList then KloceFrame.RefreshPartyList() end
                end }
        end
        return extra
    end
    local gear = CreateFrame("Button", nil, KloceFrame)
    gear:SetSize(20, 20)
    gear:SetPoint("TOPRIGHT", -26, -1)   -- na lewo od przycisku [X]
    gear:SetNormalTexture("Interface\\Worldmap\\Gear_64")
    gear:SetHighlightTexture("Interface\\Worldmap\\Gear_64")
    gear:GetNormalTexture():SetTexCoord(0, 0.5, 0, 0.5)      -- wytnij 1 zebatke z siatki 2x2
    gear:GetHighlightTexture():SetTexCoord(0, 0.5, 0, 0.5)
    gear:GetHighlightTexture():SetAlpha(0.4)
    gear:SetScript("OnClick", function(self)
        local snaps = GigaKloceDB.snapshots or {}
        local importList = {}
        if #snaps == 0 then
            importList[1] = { text = "(no snapshots yet)", notCheckable = true, disabled = true }
        else
            for i = #snaps, 1, -1 do   -- najnowsze na gorze
                local s = snaps[i]
                importList[#importList + 1] = {
                    text = s.date .. "   |cff888888(" .. #(s.lista or {}) .. "K / " .. #(s.chads or {}) .. "C / " .. #(s.blockedGuilds or {}) .. "G)|r",
                    notCheckable = true,
                    func = function() StaticPopup_Show("GIGAKLOCE_IMPORT", s.date, nil, s) end,
                }
            end
        end
        local menu = {
            { text = "GigaKloce", isTitle = true, notCheckable = true },
            { text = "Accept sync from others",
              isNotRadio = true, keepShownOnClick = true,
              checked = function() return GigaKloceDB.acceptSync end,
              func = function() GigaKloceDB.acceptSync = not GigaKloceDB.acceptSync
                  GK.out("Accept sync from others: " .. onOff(GigaKloceDB.acceptSync)) end },
            { text = "Mute alert sound",
              isNotRadio = true, keepShownOnClick = true,
              checked = function() return GigaKloceDB.silent end,
              func = function() GigaKloceDB.silent = not GigaKloceDB.silent
                  GK.out("Mute alert sound: " .. onOff(GigaKloceDB.silent)) end },
            { text = "Debug logging",
              isNotRadio = true, keepShownOnClick = true,
              checked = function() return GigaKloceDB.debug end,
              func = function() GigaKloceDB.debug = not GigaKloceDB.debug
                  GK.out("Debug logging: " .. onOff(GigaKloceDB.debug)) end },
            { text = "Blocked guilds...", notCheckable = true,
              func = function() if ShowBlockedGuilds then ShowBlockedGuilds() end end },
            { text = "Clear deletion history (tombstones)", notCheckable = true,
              func = function() StaticPopup_Show("GIGAKLOCE_CLEARTOMB") end },
            { text = "Regenerate today's snapshot", notCheckable = true,
              func = function() if GK.MakeDailySnapshot then GK.MakeDailySnapshot(true) end end },
            { text = "Import snapshot", hasArrow = true, notCheckable = true, menuList = importList },
            { text = "", notCheckable = true, disabled = true },   -- separator
            { text = "Resync", notCheckable = true,
              func = function() if GK.FullBroadcast then GK.FullBroadcast(true) end
                  GK.out("Resync: forced a full sync to the guild.") end },
            { text = "Reparty", notCheckable = true,
              disabled = not (IsInGroup() and UnitIsGroupLeader("player")),
              func = function() SlashCmdList["KLOCE"]("reparty") end },
            { text = "Cancel", notCheckable = true, func = function() end },
        }
        -- Global guild-advert items (gear menu) — inserted before "Cancel"; visible only to permitted users
        if GK.AmIAdmin and GK.AmIAdmin() then
            table.insert(menu, #menu, { text = "", notCheckable = true, disabled = true })   -- separator
            table.insert(menu, #menu, { text = "Guild advert (Global)", isTitle = true, notCheckable = true })
            table.insert(menu, #menu, { text = "Enabled", isNotRadio = true, keepShownOnClick = true,
                checked = function() return GK.GetAdvConfig and GK.GetAdvConfig().enabled end,
                func = function()
                    local c = GK.GetAdvConfig and GK.GetAdvConfig()
                    if c and GK.SetAdvConfig then GK.SetAdvConfig(not c.enabled, c.text) end
                end })
            table.insert(menu, #menu, { text = "Set advert text...", notCheckable = true,
                func = function() StaticPopup_Show("GIGAKLOCE_ADVTEXT") end })
            table.insert(menu, #menu, { text = "Broadcast now", notCheckable = true,
                func = function() if GK.AdvBroadcastNow then GK.AdvBroadcastNow() end end })
        end
        EasyMenu(menu, gearMenu, self, 0, -2, "MENU")
    end)
    gear:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Settings: import snapshot, accept sync", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    gear:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- przeciaganie
    KloceFrame:SetMovable(true); KloceFrame:EnableMouse(true); KloceFrame:RegisterForDrag("LeftButton")
    KloceFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    KloceFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        saved.posX, saved.posY = self:GetLeft(), self:GetTop()
    end)

    -- zmiana rozmiaru
    KloceFrame:SetResizable(true)
    local resizeBtn = CreateFrame("Button", nil, KloceFrame)
    resizeBtn:SetPoint("BOTTOMRIGHT", -4, 4); resizeBtn:SetSize(16, 16)
    resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeBtn:SetScript("OnMouseDown", function(_, b) if b == "LeftButton" then KloceFrame:StartSizing("BOTTOMRIGHT") end end)
    resizeBtn:SetScript("OnMouseUp", function()
        KloceFrame:StopMovingOrSizing()
        saved.sizeW, saved.sizeH = KloceFrame:GetWidth(), KloceFrame:GetHeight()
    end)

    -- ===== Zakladki (kolejnosc: Active | Kloce | Chady) =====
    local tabActive = CreateFrame("Button", nil, KloceFrame, "UIPanelButtonTemplate")
    tabActive:SetSize(86, 22); tabActive:SetText("Active")

    local tabKloce = CreateFrame("Button", nil, KloceFrame, "UIPanelButtonTemplate")
    tabKloce:SetSize(86, 22); tabKloce:SetText("Kloce")

    local tabChad = CreateFrame("Button", nil, KloceFrame, "UIPanelButtonTemplate")
    tabChad:SetSize(86, 22); tabChad:SetText("Chady")

    -- kolejnosc na pasku: Active -> Kloce -> Chady
    tabActive:SetPoint("TOPLEFT", 64, -28)   -- przesuniete w prawo, zeby nie wchodzic pod portret
    tabKloce:SetPoint("LEFT", tabActive, "RIGHT", 6, 0)
    tabChad:SetPoint("LEFT", tabKloce, "RIGHT", 6, 0)

    -- toggle "Preset" (widoczny tylko w Active): otwiera prawy panel z presetem
    local presetToggle = CreateFrame("Button", nil, KloceFrame, "UIPanelButtonTemplate")
    presetToggle:SetSize(84, 22)
    presetToggle:SetPoint("TOPRIGHT", -14, -30)
    presetToggle:SetText("Preset")
    presetToggle:SetScript("OnClick", function()
        KloceFrame.presetOpen = not KloceFrame.presetOpen
        saved.presetOpen = KloceFrame.presetOpen
        if KloceFrame.SetMode then KloceFrame.SetMode("active") end
    end)
    presetToggle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Toggle the party preset panel.", 1, 1, 1, true)
        GameTooltip:AddLine("Left-click someone on the left to add them; left-click in the preset to remove.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    presetToggle:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- toggle "Party" (permitted users only): groups the Active list into teams (who plays with whom)
    local partyToggle = CreateFrame("Button", nil, KloceFrame, "UIPanelButtonTemplate")
    partyToggle:SetSize(84, 22)
    partyToggle:SetPoint("RIGHT", presetToggle, "LEFT", -6, 0)
    partyToggle:SetText("Party")
    partyToggle:SetScript("OnClick", function()
        KloceFrame.partyOpen = not KloceFrame.partyOpen
        saved.partyOpen = KloceFrame.partyOpen
        if KloceFrame.SetMode then KloceFrame.SetMode("active") end
    end)
    partyToggle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Group the Active list into teams (who plays with whom).", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    partyToggle:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- styl aktywnej zakladki: podswietlona + zloty tekst; nieaktywna przyciemniona
    local function styleTab(b, active)
        if active then
            b:LockHighlight()
            b:GetFontString():SetTextColor(1, 0.82, 0)
        else
            b:UnlockHighlight()
            b:GetFontString():SetTextColor(0.65, 0.65, 0.65)
        end
    end

    -- ===== Gorny pasek: pole + Add =====
    local editBox = CreateFrame("EditBox", nil, KloceFrame, "InputBoxTemplate")
    editBox:SetSize(210, 22)
    editBox:SetPoint("TOPLEFT", 16, -58)
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local addBtn = CreateFrame("Button", nil, KloceFrame, "UIPanelButtonTemplate")
    addBtn:SetSize(70, 22)
    addBtn:SetPoint("LEFT", editBox, "RIGHT", 8, 0)
    addBtn:SetText("Add")

    local tip = KloceFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    tip:SetPoint("LEFT", addBtn, "RIGHT", 12, 0)
    tip:SetPoint("RIGHT", KloceFrame, "RIGHT", -16, 0)   -- ogranicz do krawedzi ramki (relatywne)
    tip:SetJustifyH("LEFT")
    tip:SetWordWrap(false)                                -- nie zawijaj; przytnij gdy ciasno
    tip:SetText("Type a name, or target a player and press Add")

    -- ===== Kontrolki Party (widoczne tylko w trybie Party): dropdown presetu + Invite all =====
    local presetDD = CreateFrame("Frame", "GigaKlocePresetDD", KloceFrame, "UIDropDownMenuTemplate")
    presetDD:SetPoint("TOPLEFT", -2, -54)
    UIDropDownMenu_SetWidth(presetDD, 150)
    UIDropDownMenu_Initialize(presetDD, function(self, level)
        for _, name in ipairs(GK.GetPresetNames()) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = name
            info.checked = (name == GK.GetCurrentPresetName())
            info.func = function()
                GK.SetCurrentPreset(name)
                UIDropDownMenu_SetText(presetDD, name)
                if KloceFrame.RefreshList then KloceFrame.RefreshList() end
                if KloceFrame.RefreshPartyList then KloceFrame.RefreshPartyList() end   -- czlonkowie presetu sa w prawym panelu
            end
            UIDropDownMenu_AddButton(info, level)
        end
        local sep = UIDropDownMenu_CreateInfo(); sep.text = ""; sep.disabled = true; sep.notCheckable = true
        UIDropDownMenu_AddButton(sep, level)
        local nw = UIDropDownMenu_CreateInfo()
        nw.text = "+ New preset..."; nw.notCheckable = true
        nw.func = function() StaticPopup_Show("GIGAKLOCE_NEWPRESET") end
        UIDropDownMenu_AddButton(nw, level)
        local del = UIDropDownMenu_CreateInfo()
        del.text = "Delete current"; del.notCheckable = true
        del.func = function() StaticPopup_Show("GIGAKLOCE_DELPRESET", GK.GetCurrentPresetName()) end
        UIDropDownMenu_AddButton(del, level)
    end)

    local inviteAllBtn = CreateFrame("Button", nil, KloceFrame, "UIPanelButtonTemplate")
    inviteAllBtn:SetSize(90, 22)
    inviteAllBtn:SetPoint("LEFT", presetDD, "RIGHT", -6, 2)
    inviteAllBtn:SetText("Invite all")
    inviteAllBtn:SetScript("OnClick", function() if GK.PartyInviteAll then GK.PartyInviteAll() end end)
    inviteAllBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Invite everyone from the selected preset.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    inviteAllBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- ===== Panele list =====
    local function MakePanel()
        local pnl = CreateFrame("Frame", nil, KloceFrame)
        pnl:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        pnl:SetBackdropColor(0, 0, 0, 0.55)
        pnl:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.9)
        return pnl
    end

    local leftPanel = MakePanel()
    leftPanel:SetPoint("TOPLEFT", 14, -88)
    leftPanel:SetPoint("BOTTOMRIGHT", KloceFrame, "BOTTOM", -5, 42)

    local rightPanel = MakePanel()
    rightPanel:SetPoint("TOPRIGHT", -14, -88)
    rightPanel:SetPoint("BOTTOMLEFT", KloceFrame, "BOTTOM", 5, 42)

    local leftHeader = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    leftHeader:SetPoint("TOPLEFT", 10, -8)

    local rightHeader = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rightHeader:SetPoint("TOPLEFT", 10, -8)

    local function HeaderLine(pnl)
        local ln = pnl:CreateTexture(nil, "ARTWORK")
        ln:SetColorTexture(1, 1, 1, 0.13)
        ln:SetHeight(1)
        ln:SetPoint("TOPLEFT", pnl, "TOPLEFT", 8, -26)
        ln:SetPoint("TOPRIGHT", pnl, "TOPRIGHT", -8, -26)
    end
    HeaderLine(leftPanel); HeaderLine(rightPanel)

    -- scrolle
    local scrollLeft = CreateFrame("ScrollFrame", "KloceScrollLeft", leftPanel, "UIPanelScrollFrameTemplate")
    scrollLeft:SetPoint("TOPLEFT", 8, -30)
    scrollLeft:SetPoint("BOTTOMRIGHT", -28, 8)
    local contentLeft = CreateFrame("Frame", nil, scrollLeft)
    contentLeft:SetSize(10, 10)
    scrollLeft:SetScrollChild(contentLeft)

    local scrollRight = CreateFrame("ScrollFrame", "KloceScrollRight", rightPanel, "UIPanelScrollFrameTemplate")
    scrollRight:SetPoint("TOPLEFT", 8, -30)
    scrollRight:SetPoint("BOTTOMRIGHT", -28, 8)
    local contentRight = CreateFrame("Frame", nil, scrollRight)
    contentRight:SetSize(10, 10)
    scrollRight:SetScrollChild(contentRight)

    KloceFrame.items = {}
    KloceFrame.partyItems = {}

    local leftEmpty = contentLeft:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    leftEmpty:SetPoint("TOPLEFT", 8, -10)

    local rightEmpty = contentRight:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    rightEmpty:SetPoint("TOPLEFT", 8, -10)

    -- fabryka wierszy (pula wielokrotnego uzytku)
    local ROW_H = 28
    local function AcquireRow(content, pool, i)
        local row = pool[i]
        if not row then
            row = CreateFrame("Button", nil, content)
            row:SetHeight(ROW_H - 1)
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            row:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
            local hl = row:GetHighlightTexture()
            hl:SetVertexColor(0.40, 0.60, 1.0, 0.20)
            row.btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            row.btn:SetSize(66, 18)
            row.btn:SetPoint("RIGHT", -4, 0)
            -- "chip" z tagiem (kolorowy badge z zaokraglonymi rogami), tylko dla Kloce
            row.chip = CreateFrame("Frame", nil, row)
            row.chip:SetHeight(19)
            row.chip:SetWidth(1)
            row.chip:SetPoint("RIGHT", row.btn, "LEFT", -8, 0)
            row.chip:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Tooltips\\ChatBubble-Backdrop",
                tile = false, edgeSize = 9,
                insets = { left = 3, right = 3, top = 3, bottom = 3 },
            })
            row.chip.label = row.chip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.chip.label:SetPoint("CENTER")
            row.chip.label:SetTextColor(1, 1, 1)
            -- ikona tagu (przed chipem)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(22, 22)
            row.icon:SetPoint("RIGHT", row.chip, "LEFT", -5, 0)
            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.text:SetJustifyH("LEFT")
            row.text:SetPoint("LEFT", 8, 0)
            row.text:SetPoint("RIGHT", row.icon, "LEFT", -5, 0)
            pool[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -((i - 1) * ROW_H) - 2)
        row:SetPoint("RIGHT", content, "RIGHT", 0, 0)
        row.bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.05 or 0.0)
        row:SetScript("OnEnter", nil); row:SetScript("OnLeave", nil)  -- reset hover (pula wspoldzielona; tylko Keys ustawia)
        row:Show()
        return row
    end

    -- ScrollFrame w 7.3.5 przycina rendering, ale NIE kliki â€” chowamy wiersze poza oknem.
    local function CullRows(scroll, pool, count)
        local offset = scroll:GetVerticalScroll() or 0
        local viewH = scroll:GetHeight()
        for i = 1, count do
            local row = pool[i]
            if row then
                local top = (i - 1) * ROW_H + 2
                if (top + ROW_H) >= offset and top <= (offset + viewH) then
                    row:Show()
                else
                    row:Hide()
                end
            end
        end
    end

    -- kolor poziomu klucza wg tieru
    local function keyLvlStr(lvl)
        lvl = lvl or 0
        local hex = (lvl >= 15 and "ff4d3f") or (lvl >= 12 and "ff8c33") or (lvl >= 9 and "a66cf2")
            or (lvl >= 6 and "4d99ff") or "aaaaaa"
        return "|cff" .. hex .. "+" .. lvl .. "|r"
    end

    -- inline ikona klasy (np. "MAGE") tuz przed nickiem
    local CLASS_SHEET = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
    local function classIcon(class)
        local c = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
        if not c then return "" end
        return string.format("|T%s:16:16:0:0:256:256:%d:%d:%d:%d|t ",
            CLASS_SHEET, c[1] * 256, c[2] * 256, c[3] * 256, c[4] * 256)
    end
    -- nick pokolorowany kolorem klasy (inline), gdy klasa znana
    local function classNameStr(name, class)
        local cc = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if cc and cc.colorStr then return "|c" .. cc.colorStr .. name .. "|r" end
        return name
    end

    -- ===== Lewa lista: zapisani wg aktywnej zakladki (kloce / chad) lub klucze (keys) =====
    local function RefreshList()
        contentLeft:SetWidth(math.max(scrollLeft:GetWidth(), 50))

        -- Tryb Active: WSZYSCY ludzie (sklad + online z addonem + klucze). Sklad/"Me" na gorze,
        -- reszta pogrupowana po GILDII (Z->A), "No Guild" na koncu. Osoby bez klucza tez widoczne.
        if KloceFrame.mode == "active" then
            -- zbierz unikalne osoby; wpis z kluczem = dane klucza, bez klucza = { name=..., noKey=true }
            local byName, ordered = {}, {}
            local function ensure(name)
                if not name or name == "" then return end
                local k = normalizeName(name)
                if not byName[k] then
                    local e = { name = displayName(name), noKey = true }
                    byName[k] = e; ordered[#ordered + 1] = e
                end
            end
            for _, kdata in ipairs((GK.GetSortedKeys and GK.GetSortedKeys()) or {}) do
                local k = normalizeName(kdata.name)
                if not byName[k] then byName[k] = kdata; ordered[#ordered + 1] = kdata end
            end
            ensure(GetUnitFullName("player"))
            local inParty = {}
            if IsInGroup() then
                for i = 1, GetNumGroupMembers() do
                    local _, nm = RosterUnitName(i)
                    if nm then inParty[normalizeName(nm)] = true; ensure(nm) end
                end
            end
            inParty[normalizeName(GetUnitFullName("player"))] = true
            for _, u in ipairs((GK.GetOnlineAddonUsers and GK.GetOnlineAddonUsers()) or {}) do
                ensure(u.name)
            end

            -- toggle "Party" (permitted only): reconstructed teams -> sub-headers; their members
            -- wypadaja z kubelkow gildii (set `teamed`).
            local teams, teamed
            if KloceFrame.partyOpen and GK.AmIAdmin and GK.AmIAdmin() and GK.GetTeams then
                teams, teamed = GK.GetTeams()
            end

            local NOGUILD = "\255noguild"   -- sentinel: kubel "bez gildii"
            local party, buckets, order = {}, {}, {}
            for _, e in ipairs(ordered) do
                local nk = normalizeName(e.name)
                if inParty[nk] then
                    table.insert(party, e)              -- sklad -> sekcja Party/Me (na gorze)
                elseif teamed and teamed[nk] then
                    -- pominiete: pokaze sie w sekcji swojego teamu (nizej)
                else
                    local g = (GK.GuildOf and GK.GuildOf(e.name)) or ""
                    local bk = (g ~= "" and g) or NOGUILD
                    if not buckets[bk] then buckets[bk] = {}; order[#order + 1] = bk end
                    table.insert(buckets[bk], e)
                end
            end
            local function cmp(a, b)   -- poziom klucza malejaco, potem nazwa
                if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) > (b.level or 0) end
                return (a.name or "") < (b.name or "")
            end
            table.sort(party, cmp)
            for _, bk in ipairs(order) do table.sort(buckets[bk], cmp) end
            table.sort(order, function(a, b)   -- gildie Z->A; "No Guild" zawsze na koniec
                if a == NOGUILD then return false end
                if b == NOGUILD then return true end
                return a > b
            end)

            local items = {}
            -- 1) Twoja grupa (z live rostera) na gorze
            items[#items + 1] = { header = IsInGroup() and ("Party (" .. #party .. ")") or "Me" }
            for _, e in ipairs(party) do items[#items + 1] = e end
            -- 2) Inne druzyny (kto z kim gra) — naglowek "<lider>'s group"
            if teams then
                for _, t in ipairs(teams) do
                    items[#items + 1] = { header = (t.leader or "?") .. "'s group" }
                    for _, m in ipairs(t.members) do
                        items[#items + 1] = byName[normalizeName(m.name)] or { name = m.display, noKey = true }
                    end
                end
            end
            -- 3) Reszta w kubelkach gildii
            for _, bk in ipairs(order) do
                local list = buckets[bk]
                local label = (bk == NOGUILD) and "No Guild" or bk
                items[#items + 1] = { header = label .. " (" .. #list .. ")" }
                for _, e in ipairs(list) do items[#items + 1] = e end
            end

            leftEmpty:SetText("No one around yet — guildies need GigaKloce running.")
            if #ordered == 0 then leftEmpty:Show() else leftEmpty:Hide() end
            leftHeader:SetText("Active |cff888888(" .. #ordered .. ")|r")
            for i, it in ipairs(items) do
                local row = AcquireRow(contentLeft, KloceFrame.items, i)
                row.chip:Hide(); row.chip:SetWidth(1)
                row.icon:Hide()
                row.btn:Hide()
                if it.header then
                    row:SetScript("OnClick", nil)
                    row:SetScript("OnEnter", nil); row:SetScript("OnLeave", nil)
                    row.text:SetText("|cffffd200" .. it.header .. "|r")
                    row.text:SetTextColor(1, 0.82, 0)
                else
                    local cls = GK.ClassOf and GK.ClassOf(it.name)
                    local sp = GK.SpecOf and GK.SpecOf(it.name)
                    local icon = specIconStr(cls, sp)   -- ikona speca (gdy znany), inaczej ikona klasy
                    if icon == "" then icon = classIcon(cls) end
                    local nameStr = icon .. classNameStr(displayName(it.name), cls)
                    -- ilvl + notatka to atrybuty GRACZA (z presence) -> pokazujemy dla KAZDEGO, tez bez klucza
                    local il = GK.IlvlOf and GK.IlvlOf(it.name)
                    local ilvlStr = (il and il > 0) and ("  |cff9d9d9d" .. il .. " ilvl|r") or ""
                    local nt = GK.NoteOf and GK.NoteOf(it.name)
                    local noteStr = (nt and nt ~= "") and ("  |cff6688aa" .. nt .. "|r") or ""
                    -- highest key all-time (z kanalu "D") — krotki tag "H:+N"
                    local hiStr = ""
                    if GK.HighKeyOf then
                        local hd, hl = GK.HighKeyOf(it.name)
                        if hd then hiStr = "  |cffffd200H:|r" .. keyLvlStr(hl) end
                    end
                    if it.noKey then
                        row.text:SetText("  " .. nameStr .. ilvlStr .. hiStr .. noteStr)
                    else
                        row.text:SetText("  " .. nameStr .. ilvlStr .. hiStr
                            .. "  |cff888888—|r  " .. (it.dungeon or "?") .. "   " .. keyLvlStr(it.level) .. noteStr)
                    end
                    row.text:SetTextColor(1, 1, 1)
                    local nm = it.name
                    -- right click = menu (Invite/Whisper/extras/Kick); left click = add to preset ONLY when preset panel open
                    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                    row:SetScript("OnClick", function(_, button)
                        if button == "RightButton" then
                            openUserMenu(nm, buildUserExtra(nm))
                        elseif KloceFrame.presetOpen then
                            if GK.PartyAddMember and GK.PartyAddMember(nm) then
                                if KloceFrame.RefreshList then KloceFrame.RefreshList() end
                                if KloceFrame.RefreshPartyList then KloceFrame.RefreshPartyList() end
                            end
                        elseif ShowDungeonDetails then   -- preset OFF: lewy klik = okno statow M+
                            ShowDungeonDetails(nm)
                        end
                    end)
                    -- hover = strefa + typ instancji (z presence, wiec dziala TEZ bez klucza) + podpowiedz
                    row:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:AddLine(displayName(it.name), 1, 1, 1)
                        local zone, itype
                        if GK.ZoneOf then zone, itype = GK.ZoneOf(it.name) end
                        if zone and zone ~= "" then
                            GameTooltip:AddLine("Zone: |cffffffff" .. zone .. "|r", 0.7, 0.7, 0.7)
                        else
                            GameTooltip:AddLine("Zone: |cff888888unknown|r", 0.7, 0.7, 0.7)
                        end
                        local INST = { party = "Mythic+ / Dungeon", raid = "Raid", pvp = "Battleground", arena = "Arena", scenario = "Scenario" }
                        local lbl = INST[itype or "none"]
                        if lbl then GameTooltip:AddLine("In instance: " .. lbl, 0.4, 0.8, 1) end
                        if KloceFrame.presetOpen then
                            GameTooltip:AddLine("|cff888888Left-click: add to preset|r", 0.5, 0.5, 0.5)
                        else
                            GameTooltip:AddLine("|cff888888Left-click: M+ details|r", 0.5, 0.5, 0.5)
                        end
                        GameTooltip:Show()
                    end)
                    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
                end
            end
            for i = #items + 1, #KloceFrame.items do KloceFrame.items[i]:Hide() end
            contentLeft:SetHeight(math.max(#items * ROW_H + 4, 10))
            KloceFrame.leftN = #items
            CullRows(scrollLeft, KloceFrame.items, #items)
            return
        end

        local chadMode = (KloceFrame.mode == "chad")
        local tab = chadMode and gigachad or gigakloce
        local count = #tab
        leftEmpty:SetText(chadMode and "No chads saved yet." or "No kloce saved yet.")
        leftHeader:SetText((chadMode and "Saved Chads " or "Saved Kloce ") .. "|cff888888(" .. count .. ")|r")
        if count == 0 then leftEmpty:Show() else leftEmpty:Hide() end
        for i, entry in ipairs(tab) do
            local row = AcquireRow(contentLeft, KloceFrame.items, i)
            local info = GetKloceInfo(entry)
            local cls = info and info.class
            local sp = info and info.spec
            -- ikona speca (gdy znany), inaczej ikona klasy; nick w kolorze klasy
            local icon = specIconStr(cls, sp)
            if icon == "" then icon = classIcon(cls) end
            row.text:SetText(i .. ".  " .. icon .. classNameStr(displayName(entry), cls))
            row.text:SetTextColor(chadMode and 0.45 or 1, 1, chadMode and 0.45 or 1)
            if chadMode then
                -- Chad: bez tag-ikony; klik otwiera detale (class/spec/note edytowalne)
                row.chip:Hide(); row.chip:SetWidth(1)
                row.icon:Hide()
                row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                row:SetScript("OnClick", function(_, button)
                    if button == "RightButton" then openUserMenu(entry) else ShowKloceDetails(entry) end
                end)
            else
                -- Kloce: ikona taga + klik w wiersz otwiera detale (chip z tagiem wylaczony)
                local tag = (info and info.tag) or DEFAULT_TAG
                row.chip:Hide(); row.chip:SetWidth(1)
                local iconPath = TAG_ICONS[tag]
                if iconPath then row.icon:SetTexture(iconPath); row.icon:Show() else row.icon:Hide() end
                row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                row:SetScript("OnClick", function(_, button)
                    if button == "RightButton" then openUserMenu(entry) else ShowKloceDetails(entry) end
                end)
            end
            row.btn:Show()
            row.btn:SetText("Remove")
            row.btn:Enable()
            row.btn:SetScript("OnClick", function()
                if chadMode then RemoveChad(entry) else RemoveKloce(entry) end   -- same broadcastuja (z czasem)
            end)
        end
        for i = count + 1, #KloceFrame.items do KloceFrame.items[i]:Hide() end
        contentLeft:SetHeight(math.max(count * ROW_H + 4, 10))
        KloceFrame.leftN = count
        CullRows(scrollLeft, KloceFrame.items, count)
    end
    KloceFrame.RefreshList = RefreshList

    -- ===== Prawa lista: kto z listy jest w Twojej grupie =====
    -- Wspolna lista "In Group" (niezalezna od zakladki): kloce ORAZ chadzi w skladzie.
    -- Kloc = pomaranczowy + Kick; Chad = zielony, bez przycisku.
    local function RefreshPartyList()
        contentRight:SetWidth(math.max(scrollRight:GetWidth(), 50))

        -- Tryb Active z otwartym presetem: prawy panel = czlonkowie biezacego presetu.
        -- Lewy klik na wierszu = usun z presetu; prawy klik = Invite/Whisper. (Dodawanie: lewy klik w liscie Active.)
        if KloceFrame.mode == "active" then
            if not KloceFrame.presetOpen then
                for i = 1, #KloceFrame.partyItems do KloceFrame.partyItems[i]:Hide() end
                rightEmpty:Hide()
                KloceFrame.rightN = 0
                return
            end
            local members = (GK.GetCurrentMembers and GK.GetCurrentMembers()) or {}
            local count = #members
            rightEmpty:SetText("Preset empty — left-click people on the left to add.")
            if count == 0 then rightEmpty:Show() else rightEmpty:Hide() end
            rightHeader:SetText("Preset: " .. (GK.GetCurrentPresetName() or "?") .. " |cff888888(" .. count .. ")|r")
            for i, nm in ipairs(members) do
                local row = AcquireRow(contentRight, KloceFrame.partyItems, i)
                row.chip:Hide(); row.chip:SetWidth(1); row.icon:Hide(); row.btn:Hide()
                local cls = GK.ClassOf and GK.ClassOf(nm)
                local sp = GK.SpecOf and GK.SpecOf(nm)
                local icon = specIconStr(cls, sp)
                if icon == "" then icon = classIcon(cls) end
                row.text:SetText(i .. ".  " .. icon .. classNameStr(displayName(nm), cls))
                row.text:SetTextColor(1, 1, 1)
                row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                row:SetScript("OnClick", function(_, button)
                    if button == "RightButton" then
                        openUserMenu(nm, buildUserExtra(nm))
                    else   -- lewy klik = usun z presetu
                        if GK.PartyRemoveMember then GK.PartyRemoveMember(nm) end
                        if KloceFrame.RefreshList then KloceFrame.RefreshList() end
                        if KloceFrame.RefreshPartyList then KloceFrame.RefreshPartyList() end
                    end
                end)
                row:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(displayName(nm), 1, 1, 1)
                    GameTooltip:AddLine("|cff888888Left-click: remove from preset|r", 0.5, 0.5, 0.5)
                    GameTooltip:Show()
                end)
                row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            end
            for i = count + 1, #KloceFrame.partyItems do KloceFrame.partyItems[i]:Hide() end
            contentRight:SetHeight(math.max(count * ROW_H + 4, 10))
            KloceFrame.rightN = count
            CullRows(scrollRight, KloceFrame.partyItems, count)
            return
        end

        local members = {}
        if IsInGroup() then
            for i = 1, GetNumGroupMembers() do
                local unit, name = RosterUnitName(i)
                if name then
                    local kind = ClassifyMember(unit, name)
                    if kind then
                        local _, classFile = UnitClass(unit)
                        table.insert(members, { name = name, kind = kind, unit = unit, class = classFile })
                    end
                end
            end
        end
        rightEmpty:SetText("No kloce or chads in your group.")
        if #members == 0 then rightEmpty:Show() else rightEmpty:Hide() end
        rightHeader:SetText("In Group |cff888888(" .. #members .. ")|r")
        local canKick = UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
        for i, m in ipairs(members) do
            local row = AcquireRow(contentRight, KloceFrame.partyItems, i)
            row.chip:Hide(); row.chip:SetWidth(1); row.icon:Hide()
            row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            row:SetScript("OnClick", function(_, button) if button == "RightButton" then openUserMenu(m.name) end end)
            local info = GetKloceInfo(m.name)
            -- uzupelnij klase w info na podstawie zywej jednostki (gdy brak)
            if info and (not info.class or info.class == "") and m.class then info.class = m.class end
            local cls = (info and info.class) or m.class
            local sp = info and info.spec
            local icon = specIconStr(cls, sp)
            if icon == "" then icon = classIcon(cls) end
            row.text:SetText(icon .. displayName(m.name))
            -- brak specu? zlec inspect — ikona dociagnie sie sama (gracz jest w grupie)
            if (not sp or sp == "") and GK.RequestSpec then GK.RequestSpec(m.name) end
            if m.kind == "chad" then
                -- chad: na zielono, bez przycisku (nic nie triggeruje)
                row.text:SetTextColor(0.45, 1, 0.45)
                row.btn:Hide()
            else
                row.text:SetTextColor(1, 0.82, 0.4)   -- kloc: pomaranczowy akcent
                row.btn:Show()
                row.btn:SetText("Kick")
                if canKick then
                    row.btn:Enable()
                    row.btn:SetScript("OnClick", function()
                        UninviteUnit(displayName(m.name))
                        log("Kloc kicked: " .. displayName(m.name))
                        if KloceFrame.RefreshPartyList then KloceFrame.RefreshPartyList() end
                    end)
                else
                    row.btn:Disable()
                    row.btn:SetScript("OnClick", nil)
                end
            end
        end
        for i = #members + 1, #KloceFrame.partyItems do KloceFrame.partyItems[i]:Hide() end
        contentRight:SetHeight(math.max(#members * ROW_H + 4, 10))
        KloceFrame.rightN = #members
        CullRows(scrollRight, KloceFrame.partyItems, #members)
    end
    KloceFrame.RefreshPartyList = RefreshPartyList

    -- przelaczanie trybu (zakladki)
    local function SetMode(mode)
        KloceFrame.mode = mode
        styleTab(tabActive, mode == "active")
        styleTab(tabKloce, mode == "kloce")
        styleTab(tabChad, mode == "chad")

        local activeMode = (mode == "active")
        local showInput = (mode == "kloce" or mode == "chad")
        editBox:SetShown(showInput)
        addBtn:SetShown(showInput)
        tip:SetShown(showInput)
        -- toggle Preset widoczny i podswietlony tylko w Active (gdy wlaczony)
        presetToggle:SetShown(activeMode)
        styleTab(presetToggle, activeMode and KloceFrame.presetOpen)
        -- Party toggle visible only to permitted users in Active
        local amAdmin = GK.AmIAdmin and GK.AmIAdmin()
        partyToggle:SetShown(activeMode and amAdmin)
        styleTab(partyToggle, activeMode and amAdmin and KloceFrame.partyOpen)

        -- czy prawy panel jest widoczny:
        --  Active -> tylko gdy toggle Preset wlaczony (prawy = czlonkowie presetu)
        --  Kloce/Chady -> zawsze (prawy = "In Group")
        local splitRight
        if activeMode then
            splitRight = KloceFrame.presetOpen and true or false
            if splitRight then
                presetDD:ClearAllPoints()
                presetDD:SetPoint("BOTTOMLEFT", rightPanel, "TOPLEFT", -12, 2)
                presetDD:Show(); inviteAllBtn:Show()
                UIDropDownMenu_SetText(presetDD, GK.GetCurrentPresetName() or "")
            else
                presetDD:Hide(); inviteAllBtn:Hide()
            end
        else
            presetDD:Hide(); inviteAllBtn:Hide()
            splitRight = true
        end

        local BOT = 26   -- zostaw miejsce nad uchwytem zmiany rozmiaru (prawy-dolny rog)
        local leftTop = activeMode and -62 or -88
        if not splitRight then
            -- lewa lista na cala szerokosc, prawy panel ukryty
            rightPanel:Hide()
            leftPanel:ClearAllPoints()
            leftPanel:SetPoint("TOPLEFT", 14, leftTop)
            leftPanel:SetPoint("BOTTOMRIGHT", KloceFrame, "BOTTOMRIGHT", -14, BOT)
        else
            rightPanel:Show()
            leftPanel:ClearAllPoints()
            leftPanel:SetPoint("TOPLEFT", 14, leftTop)
            leftPanel:SetPoint("BOTTOMRIGHT", KloceFrame, "BOTTOM", -5, BOT)
            rightPanel:ClearAllPoints()
            rightPanel:SetPoint("TOPRIGHT", -14, -88)
            rightPanel:SetPoint("BOTTOMLEFT", KloceFrame, "BOTTOM", 5, BOT)
        end

        if activeMode then
            if GK.BroadcastMyKey then GK.BroadcastMyKey() end       -- K: odswiez/rozglos swoj klucz
            if GK.BroadcastPresence then GK.BroadcastPresence() end  -- H: pobudka puli online
            if GK.BroadcastParty then GK.BroadcastParty() end        -- P: sklad
        end
        RefreshList()
        RefreshPartyList()
    end
    KloceFrame.SetMode = SetMode
    tabActive:SetScript("OnClick", function() SetMode("active") end)
    tabKloce:SetScript("OnClick", function() SetMode("kloce") end)
    tabChad:SetScript("OnClick", function() SetMode("chad") end)

    -- szerokosc dzieci scrolla + culling przy resize i scrollowaniu
    scrollLeft:SetScript("OnSizeChanged", function(self)
        contentLeft:SetWidth(math.max(self:GetWidth(), 50))
        CullRows(self, KloceFrame.items, KloceFrame.leftN or 0)
    end)
    scrollRight:SetScript("OnSizeChanged", function(self)
        contentRight:SetWidth(math.max(self:GetWidth(), 50))
        CullRows(self, KloceFrame.partyItems, KloceFrame.rightN or 0)
    end)
    scrollLeft:HookScript("OnVerticalScroll", function(self) CullRows(self, KloceFrame.items, KloceFrame.leftN or 0) end)
    scrollRight:HookScript("OnVerticalScroll", function(self) CullRows(self, KloceFrame.partyItems, KloceFrame.rightN or 0) end)

    -- ===== Dodawanie (wg trybu) =====
    local function DoAdd()
        local text = editBox:GetText()
        local toAdd = (text ~= "" and text) or GetUnitFullName("target")
        if toAdd and toAdd ~= "" then
            if KloceFrame.mode == "chad" then AddChad(toAdd) else AddKloce(toAdd) end   -- same broadcastuja
            editBox:SetText("")
        end
    end
    addBtn:SetScript("OnClick", DoAdd)
    editBox:SetScript("OnEnterPressed", function(self) DoAdd(); self:ClearFocus() end)

    -- ===== Podpowiedzi "last played with" pod polem Add =====
    local SUG_MAX, SUG_ROWH = 8, 18
    local sugFrame = CreateFrame("Frame", "GigaKloceAddSuggest", KloceFrame)
    sugFrame:SetFrameStrata("DIALOG")
    sugFrame:SetPoint("TOPLEFT", editBox, "BOTTOMLEFT", 0, -2)
    sugFrame:SetPoint("TOPRIGHT", editBox, "BOTTOMRIGHT", 0, -2)
    sugFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    sugFrame:SetBackdropColor(0, 0, 0, 0.92)
    sugFrame:Hide()
    sugFrame.rows = {}
    for i = 1, SUG_MAX do
        local b = CreateFrame("Button", nil, sugFrame)
        b:SetHeight(SUG_ROWH)
        b:SetPoint("TOPLEFT", 4, -4 - (i - 1) * SUG_ROWH)
        b:SetPoint("TOPRIGHT", -4, -4 - (i - 1) * SUG_ROWH)
        b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetAllPoints(); b.hl:SetColorTexture(1, 1, 1, 0.12)
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        b.text:SetPoint("LEFT", 4, 0); b.text:SetJustifyH("LEFT")
        b:SetScript("OnClick", function(self)
            local rec = self.rec
            if rec and GK.AddPlayedWith then
                GK.AddPlayedWith(rec.name, KloceFrame.mode == "chad", rec.class, rec.spec)
            end
            editBox:SetText("")
            sugFrame:Hide()
            editBox:ClearFocus()
        end)
        sugFrame.rows[i] = b
    end

    local function UpdateSuggestions()
        if (KloceFrame.mode ~= "kloce" and KloceFrame.mode ~= "chad") or not editBox:HasFocus() then
            sugFrame:Hide(); return
        end
        local matches = (GK.PlayedWithMatches and GK.PlayedWithMatches(editBox:GetText(), SUG_MAX)) or {}
        if #matches == 0 then sugFrame:Hide(); return end
        for i, b in ipairs(sugFrame.rows) do
            local rec = matches[i]
            if rec then
                b.rec = rec
                local cc = rec.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[rec.class]
                local nm = (cc and cc.colorStr) and ("|c" .. cc.colorStr .. rec.name .. "|r") or rec.name
                b.text:SetText(nm)
                b:Show()
            else
                b.rec = nil; b:Hide()
            end
        end
        sugFrame:SetHeight(8 + math.min(#matches, SUG_MAX) * SUG_ROWH)
        sugFrame:Show()
    end

    editBox:HookScript("OnTextChanged", function(_, userInput) if userInput then UpdateSuggestions() end end)
    editBox:HookScript("OnEditFocusGained", function() UpdateSuggestions() end)
    editBox:HookScript("OnEditFocusLost", function()
        C_Timer.After(0.18, function() if not editBox:HasFocus() then sugFrame:Hide() end end)
    end)

    -- (Resync i Reparty przeniesione do menu kolka zebatego; Mute alert sound tez tam)

    -- pierwsze ulozenie (po przeliczeniu rozmiarow przez silnik UI)
    PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
    C_Timer.After(0, function() SetMode(KloceFrame.mode or "active") end)

    KloceFrame:HookScript("OnShow", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
        SetMode(KloceFrame.mode or "active")
    end)
    KloceFrame:HookScript("OnHide", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
    end)
end
local function ShowKloceUI()
    CreateKloceUI()
end

-- ============================
-- IKONKA
-- ============================
local function CreateKloceButton()
    if KloceButton then return end
    local saved = GigaKloceDB
    KloceButton = CreateFrame("Button", "KloceButton", UIParent)
    KloceButton:SetSize(32, 32)
    if saved.btnX and saved.btnY then
        KloceButton:SetPoint("CENTER", UIParent, "BOTTOMLEFT", saved.btnX, saved.btnY)
    else
        KloceButton:SetPoint("TOPLEFT", Minimap, "BOTTOMLEFT", 0, -2)
    end

    KloceButton:SetMovable(true)
    KloceButton:RegisterForDrag("LeftButton")

    local tex = KloceButton:CreateTexture(nil, "BACKGROUND")
    tex:SetAllPoints()
    KloceButton.icon = tex
    -- ikona zalezna od stanu: brak kloca = stara, jest kloc = garrosh (przelacza UpdateKloceAlert)
    KloceButton.iconNormal = "Interface\\Icons\\inv_misc_groupneedmore"
    KloceButton.iconAlert  = "Interface\\AddOns\\GigaKloce\\assets\\garosh"  -- wymaga garosh.blp
    tex:SetTexture(KloceButton.iconNormal)

    -- Czerwona poĹ›wiata-alert (gdy kloc jest w skĹ‚adzie) â€” mocno pulsujÄ…ca.
    local glow = KloceButton:CreateTexture(nil, "OVERLAY")
    glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(1, 0.05, 0.05)
    glow:SetPoint("CENTER", KloceButton, "CENTER", 0, 0)
    glow:SetSize(32 * 2.1, 32 * 2.1)
    glow:Hide()
    KloceButton.glow = glow
    KloceButton.glowBase = 32 * 2.1

    -- Pulsowanie (alpha + rozmiar) sterowane OnUpdate â€” mocniejszy, bardziej widoczny efekt.
    KloceButton.pulseT = 0
    KloceButton:SetScript("OnUpdate", function(self, elapsed)
        if not self.alertActive then return end
        self.pulseT = self.pulseT + elapsed
        local s = (math.sin(self.pulseT * 6) + 1) * 0.5   -- 0..1
        self.glow:SetAlpha(0.5 + 0.5 * s)                 -- alpha 0.5..1.0
        local sz = self.glowBase * (1.0 + 0.22 * s)        -- rozmiar +22% w szczycie
        self.glow:SetSize(sz, sz)
    end)

    KloceButton:SetScript("OnClick", function()
        if KloceFrame and KloceFrame:IsShown() then
            KloceFrame:Hide()
        else
            ShowKloceUI()
        end
    end)

    KloceButton:SetScript("OnDragStart", function(self)
        if IsAltKeyDown() then
            self:StartMoving()
        end
    end)

    KloceButton:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        saved.btnX, saved.btnY = x, y
    end)

    UpdateKloceAlert()
end


-- eksport do namespace
GK.ShowKloceUI, GK.CreateKloceButton = ShowKloceUI, CreateKloceButton
