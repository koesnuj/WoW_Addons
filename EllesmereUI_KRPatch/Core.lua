local ADDON_NAME, NS = ...
if GetLocale() ~= "koKR" then return end

local E = _G.EllesmereUI
if not E then return end

local FONT_NAME = NS.FONT_NAME or "2002"
local FONT_PATH = NS.FONT_PATH or "Interface\\AddOns\\EllesmereUI_KRPatch\\2002.ttf"
local unpack = unpack or table.unpack

local FONT_KEYS = {
    "global",
    "actionBars",
    "nameplates",
    "unitFrames",
    "cdm",
    "resourceBars",
    "auraBuff",
    "raidFrames",
    "minimapChat",
    "extras",
}

local FONT_OBJECTS = {
    "GameFontNormal", "GameFontNormalSmall", "GameFontNormalLarge",
    "GameFontHighlight", "GameFontHighlightSmall", "GameFontHighlightLarge",
    "GameFontDisable", "GameFontDisableSmall",
    "SystemFont_Tiny", "SystemFont_Small", "SystemFont_Shadow_Small",
    "SystemFont_Med1", "SystemFont_Med2", "SystemFont_Med3",
    "SystemFont_Large", "SystemFont_Huge1", "SystemFont_Huge1_Outline",
    "SystemFont_NamePlate", "SystemFont_NamePlate_Outlined",
    "ChatFontNormal", "NumberFontNormal", "QuestFont", "QuestFontNormalSmall",
}

local hookedMethods = {}
local function Delay(fn)
    if C_Timer and C_Timer.After then
        C_Timer.After(0, fn)
    else
        fn()
    end
end

local function ApplySharedUIFont(fontPath)
    if not fontPath or fontPath == "" then return end
    STANDARD_TEXT_FONT = fontPath
    NAMEPLATE_FONT = fontPath
    UNIT_NAME_FONT = fontPath
    DAMAGE_TEXT_FONT = fontPath

    for i = 1, #FONT_OBJECTS do
        local obj = _G[FONT_OBJECTS[i]]
        if obj and obj.GetFont and obj.SetFont then
            local _, size, flags = obj:GetFont()
            obj:SetFont(fontPath, size or 12, flags or "")
        end
    end
end

local function LocalizeDropdownValues(values)
    if type(values) ~= "table" then return values end
    local localized = {}
    for key, value in pairs(values) do
        if key == "_menuOpts" then
            localized[key] = value
        elseif type(value) == "string" then
            localized[key] = NS.Translate(value)
        elseif type(value) == "table" then
            local entry = {}
            for entryKey, entryValue in pairs(value) do
                if (entryKey == "text" or entryKey == "note") and type(entryValue) == "string" then
                    entry[entryKey] = NS.Translate(entryValue)
                elseif entryKey == "subnav" and type(entryValue) == "table" then
                    local subnav = {}
                    for subKey, subValue in pairs(entryValue) do
                        if subKey == "values" then
                            subnav[subKey] = LocalizeDropdownValues(subValue)
                        elseif (subKey == "text" or subKey == "note") and type(subValue) == "string" then
                            subnav[subKey] = NS.Translate(subValue)
                        else
                            subnav[subKey] = subValue
                        end
                    end
                    entry[entryKey] = subnav
                else
                    entry[entryKey] = entryValue
                end
            end
            localized[key] = entry
        else
            localized[key] = value
        end
    end
    return localized
end

local function LocalizePopupOptions(opts)
    if type(opts) ~= "table" then return opts end
    local localized = {}
    for key, value in pairs(opts) do
        localized[key] = value
    end

    local textFields = {
        "title", "message", "confirmText", "cancelText",
        "content", "placeholder", "text", "disclaimer",
    }
    for i = 1, #textFields do
        local field = textFields[i]
        if type(localized[field]) == "string" then
            localized[field] = NS.Translate(localized[field])
        end
    end

    if type(localized.extraButton) == "table" then
        local extra = {}
        for key, value in pairs(localized.extraButton) do
            extra[key] = value
        end
        if type(extra.text) == "string" then
            extra.text = NS.Translate(extra.text)
        end
        localized.extraButton = extra
    end

    return localized
end

local function LocalizeCogPopupOptions(opts)
    if type(opts) ~= "table" then return opts end
    local localized = {}
    for key, value in pairs(opts) do
        localized[key] = value
    end

    if type(localized.title) == "string" then
        localized.title = NS.Translate(localized.title)
    end

    if type(localized.rows) == "table" then
        local rows = {}
        for i, row in ipairs(localized.rows) do
            local localizedRow = {}
            for key, value in pairs(row) do
                localizedRow[key] = value
            end
            if type(localizedRow.label) == "string" then
                localizedRow.label = NS.Translate(localizedRow.label)
            end
            if type(localizedRow.tooltip) == "string" then
                localizedRow.tooltip = NS.Translate(localizedRow.tooltip)
            end
            if type(localizedRow.disabledTooltip) == "string" then
                localizedRow.disabledTooltip = NS.Translate(localizedRow.disabledTooltip)
            end
            if type(localizedRow.values) == "table" then
                localizedRow.values = LocalizeDropdownValues(localizedRow.values)
            end
            rows[i] = localizedRow
        end
        localized.rows = rows
    end

    return localized
end

local function LocalizeLabelMap(labels)
    if type(labels) ~= "table" then return labels end
    local localized = {}
    for key, value in pairs(labels) do
        localized[key] = type(value) == "string" and NS.Translate(value) or value
    end
    return localized
end

local function LocalizeSegmentedConfig(cfg)
    if type(cfg) ~= "table" then return cfg end
    local localized = {}
    for key, value in pairs(cfg) do
        localized[key] = value
    end
    if type(localized.labels) == "table" then
        localized.labels = LocalizeLabelMap(localized.labels)
    end
    return localized
end

local function LocalizeWidgetConfig(cfg)
    if type(cfg) ~= "table" then return cfg end
    local localized = {}
    for key, value in pairs(cfg) do
        if (key == "text" or key == "title" or key == "tooltip" or key == "note") and type(value) == "string" then
            localized[key] = NS.Translate(value)
        elseif key == "values" and type(value) == "table" then
            localized[key] = LocalizeDropdownValues(value)
        elseif key == "labels" and type(value) == "table" then
            localized[key] = LocalizeLabelMap(value)
        else
            localized[key] = value
        end
    end
    return localized
end

local function LocalizeWidgetConfigList(configs)
    if type(configs) ~= "table" then return configs end
    local localized = {}
    for i = 1, #configs do
        localized[i] = LocalizeWidgetConfig(configs[i])
    end
    return localized
end

local function ShouldTranslateChatMessage(text)
    if type(text) ~= "string" or text == "" then return false end
    return text:find("Ellesmere", 1, true)
        or text:find("Unlock Mode", 1, true)
        or text:find("Cannot open options", 1, true)
        or text:find("All hints reset", 1, true)
        or text:find("Options closed", 1, true)
        or text:find("Party Mode addon", 1, true)
        or text:find("Sold ", 1, true)
        or text:find("Repaired all items", 1, true)
        or text:find("Reload required to create custom bars", 1, true)
        or text:find("Install by searching for", 1, true)
        or text:find("CPU Usage:", 1, true)
        or text:find("Memory Usage:", 1, true)
        or text:find("Bugcatcher:", 1, true)
        or text:find("[EABR", 1, true)
end

local EABR_SPELL_TABLE_NAMES = {
    "_EABR_RAID_BUFFS",
    "_EABR_AURAS",
    "_EABR_ROGUE_POISONS",
    "_EABR_PALADIN_RITES",
    "_EABR_SHAMAN_IMBUES",
    "_EABR_SHAMAN_SHIELDS",
}

local EABR_ITEM_TABLE_NAMES = {
    "_EABR_FLASK_ITEMS",
    "_EABR_FOOD_ITEMS",
    "_EABR_WEAPON_ENCHANT_ITEMS",
}

local EABR_TALENT_ZONE_TABLE_NAME = "_EABR_TALENT_REMINDER_ZONES"

local function GetEntryOriginalName(entry)
    if type(entry) ~= "table" then return nil end
    if type(entry._euiKROriginalName) ~= "string" or entry._euiKROriginalName == "" then
        if type(entry.name) ~= "string" or entry.name == "" then
            return nil
        end
        entry._euiKROriginalName = entry.name
    end
    return entry._euiKROriginalName
end

local function GetTranslatedFallbackName(entry)
    local originalName = GetEntryOriginalName(entry)
    if type(originalName) ~= "string" or originalName == "" then return nil end
    local translatedName = NS.Translate(originalName)
    if translatedName == originalName then
        return nil
    end
    return translatedName
end

local function ApplyLocalizedEntryName(sourceEntry, localizedEntry, localizedName)
    if type(localizedEntry) ~= "table" or type(localizedName) ~= "string" or localizedName == "" then
        return false
    end
    local originalName = GetEntryOriginalName(sourceEntry or localizedEntry)
    if originalName and (type(localizedEntry._euiKROriginalName) ~= "string" or localizedEntry._euiKROriginalName == "") then
        localizedEntry._euiKROriginalName = originalName
    end
    if localizedEntry.name == localizedName then
        return false
    end
    localizedEntry.name = localizedName
    return true
end

local function CreateLocalizedEABRTable(sourceEntries)
    if type(sourceEntries) ~= "table" then return nil end
    local localizedEntries = {}
    for key, value in pairs(sourceEntries) do
        if type(value) == "table" then
            local entryCopy = {}
            for entryKey, entryValue in pairs(value) do
                entryCopy[entryKey] = entryValue
            end
            localizedEntries[key] = entryCopy
        else
            localizedEntries[key] = value
        end
    end
    localizedEntries._euiKRLocalizedProxy = true
    localizedEntries._euiKROriginalSource = sourceEntries
    return localizedEntries
end

local function GetLocalizedEABRTable(globalName)
    local current = _G[globalName]
    if type(current) ~= "table" then return nil, nil end
    if current._euiKRLocalizedProxy and type(current._euiKROriginalSource) == "table" then
        return current._euiKROriginalSource, current
    end
    local localizedEntries = CreateLocalizedEABRTable(current)
    if localizedEntries then
        _G[globalName] = localizedEntries
    end
    return current, localizedEntries
end

local function LocalizeSpellEntryTable(sourceEntries, localizedEntries)
    if type(sourceEntries) ~= "table" or type(localizedEntries) ~= "table" then return false end
    local changed = false
    for i = 1, #sourceEntries do
        local sourceEntry = sourceEntries[i]
        local localizedEntry = localizedEntries[i]
        if type(sourceEntry) == "table" and type(localizedEntry) == "table" and type(sourceEntry.name) == "string" then
            local localizedName
            if type(NS.GetLocalizedSpellName) == "function" and sourceEntry.castSpell then
                localizedName = NS.GetLocalizedSpellName(sourceEntry.castSpell)
            end
            if (not localizedName or localizedName == "") and type(NS.GetLocalizedSpellName) == "function" and type(sourceEntry.buffIDs) == "table" then
                for j = 1, #sourceEntry.buffIDs do
                    localizedName = NS.GetLocalizedSpellName(sourceEntry.buffIDs[j])
                    if localizedName and localizedName ~= "" then
                        break
                    end
                end
            end
            if not localizedName or localizedName == "" then
                localizedName = GetTranslatedFallbackName(sourceEntry)
            end
            if ApplyLocalizedEntryName(sourceEntry, localizedEntry, localizedName) then
                changed = true
            end
        end
    end
    return changed
end

local function LocalizeItemEntryTable(sourceEntries, localizedEntries)
    if type(sourceEntries) ~= "table" or type(localizedEntries) ~= "table" then return false end
    local changed = false
    for i = 1, #sourceEntries do
        local sourceEntry = sourceEntries[i]
        local localizedEntry = localizedEntries[i]
        if type(sourceEntry) == "table" and type(localizedEntry) == "table" and type(sourceEntry.name) == "string" then
            local itemID = sourceEntry.itemID
            if not itemID and type(sourceEntry.items) == "table" then
                itemID = sourceEntry.items[1]
            end
            local localizedName
            if type(NS.GetLocalizedItemName) == "function" and itemID then
                localizedName = NS.GetLocalizedItemName(itemID)
            end
            if not localizedName or localizedName == "" then
                localizedName = GetTranslatedFallbackName(sourceEntry)
            end
            if ApplyLocalizedEntryName(sourceEntry, localizedEntry, localizedName) then
                changed = true
            end
        end
    end
    return changed
end

local function BuildLocalizedWeaponEnchantNameMap(sourceItems, localizedItems)
    local localizedByName = {}
    if type(sourceItems) ~= "table" or type(localizedItems) ~= "table" then
        return localizedByName
    end
    for i = 1, #sourceItems do
        local sourceEntry = sourceItems[i]
        local localizedEntry = localizedItems[i]
        if type(sourceEntry) == "table" and type(localizedEntry) == "table" and type(sourceEntry.name) == "string" then
            local originalName = GetEntryOriginalName(sourceEntry)
            local localizedName
            if type(NS.GetLocalizedItemName) == "function" and sourceEntry.itemID then
                localizedName = NS.GetLocalizedItemName(sourceEntry.itemID)
            end
            if not localizedName or localizedName == "" then
                localizedName = GetTranslatedFallbackName(sourceEntry)
            end
            if localizedName and localizedName ~= "" then
                localizedByName[sourceEntry.name] = localizedName
                localizedByName[localizedEntry.name] = localizedName
                if originalName and originalName ~= "" then
                    localizedByName[originalName] = localizedName
                end
            end
        end
    end
    return localizedByName
end

local function LocalizeWeaponEnchantChoiceTable(sourceChoices, localizedChoices, sourceItems, localizedItems)
    if type(sourceChoices) ~= "table" or type(localizedChoices) ~= "table" then return false end
    local localizedByName = BuildLocalizedWeaponEnchantNameMap(sourceItems, localizedItems)
    local changed = false
    for i = 1, #sourceChoices do
        local sourceEntry = sourceChoices[i]
        local localizedEntry = localizedChoices[i]
        if type(sourceEntry) == "table" and type(localizedEntry) == "table" and type(sourceEntry.name) == "string" then
            local originalName = GetEntryOriginalName(sourceEntry)
            local localizedName = localizedByName[sourceEntry.name] or localizedByName[localizedEntry.name] or localizedByName[originalName]
            if (not localizedName or localizedName == "") and originalName then
                local translatedName = NS.Translate(originalName)
                if translatedName ~= originalName then
                    localizedName = translatedName
                end
            end
            if ApplyLocalizedEntryName(sourceEntry, localizedEntry, localizedName) then
                changed = true
            end
        end
    end
    return changed
end

local function LocalizeAuraBuffReminderData()
    local changed = false

    for i = 1, #EABR_SPELL_TABLE_NAMES do
        local sourceEntries, localizedEntries = GetLocalizedEABRTable(EABR_SPELL_TABLE_NAMES[i])
        if LocalizeSpellEntryTable(sourceEntries, localizedEntries) then
            changed = true
        end
    end

    for i = 1, #EABR_ITEM_TABLE_NAMES do
        local sourceEntries, localizedEntries = GetLocalizedEABRTable(EABR_ITEM_TABLE_NAMES[i])
        if LocalizeItemEntryTable(sourceEntries, localizedEntries) then
            changed = true
        end
    end

    local sourceChoices, localizedChoices = GetLocalizedEABRTable("_EABR_WEAPON_ENCHANT_CHOICES")
    local sourceItems, localizedItems = GetLocalizedEABRTable("_EABR_WEAPON_ENCHANT_ITEMS")
    if LocalizeWeaponEnchantChoiceTable(sourceChoices, localizedChoices, sourceItems, localizedItems) then
        changed = true
    end

    if changed and type(NS.InvalidateDynamicGameNameMap) == "function" then
        NS.InvalidateDynamicGameNameMap()
    end

    return changed
end

local function LocalizeTalentReminderZones()
    local sourceZones, localizedZones = GetLocalizedEABRTable(EABR_TALENT_ZONE_TABLE_NAME)
    if type(sourceZones) ~= "table" or type(localizedZones) ~= "table" then
        return false
    end

    local changed = false
    for i = 1, #sourceZones do
        local sourceZone = sourceZones[i]
        local localizedZone = localizedZones[i]
        if type(sourceZone) == "table" and type(localizedZone) == "table" and type(sourceZone.name) == "string" then
            local localizedName = NS.Translate(GetEntryOriginalName(sourceZone) or sourceZone.name)
            if localizedName ~= sourceZone.name and ApplyLocalizedEntryName(sourceZone, localizedZone, localizedName) then
                changed = true
            end
        end
    end

    return changed
end

local function MigrateTalentReminderZoneNames()
    local aceDB = _G._EABR_AceDB
    local profile = aceDB and aceDB.profile
    local reminders = profile and profile.talentReminders
    if type(reminders) ~= "table" then
        return false
    end

    local changed = false
    for i = 1, #reminders do
        local reminder = reminders[i]
        if type(reminder) == "table" then
            local reminderChanged = false
            if type(reminder.zoneNames) == "table" then
                local migratedNames = {}
                local seenNames = {}
                for j = 1, #reminder.zoneNames do
                    local zoneName = reminder.zoneNames[j]
                    if type(zoneName) == "string" and zoneName ~= "" then
                        local localizedName = NS.Translate(zoneName)
                        if type(localizedName) ~= "string" or localizedName == "" then
                            localizedName = zoneName
                        end
                        if not seenNames[localizedName] then
                            migratedNames[#migratedNames + 1] = localizedName
                            seenNames[localizedName] = true
                        end
                        if localizedName ~= zoneName then
                            reminderChanged = true
                        end
                    end
                end
                if #migratedNames > 0 then
                    reminder.zoneNames = migratedNames
                end
            end

            if type(reminder.zoneName) == "string" and reminder.zoneName ~= "" then
                local localizedZoneName = NS.Translate(reminder.zoneName)
                if type(localizedZoneName) == "string" and localizedZoneName ~= "" and localizedZoneName ~= reminder.zoneName then
                    reminder.zoneName = localizedZoneName
                    reminderChanged = true
                end
            end

            if reminderChanged then
                reminder._nameSet = nil
                changed = true
            end
        end
    end

    return changed
end

local function EnsureLocalizedAuraBuffReminderState()
    local changed = false
    if LocalizeAuraBuffReminderData() then
        changed = true
    end
    if LocalizeTalentReminderZones() then
        changed = true
    end
    if MigrateTalentReminderZoneNames() then
        changed = true
    end
    if changed and type(NS.InvalidateDynamicGameNameMap) == "function" then
        NS.InvalidateDynamicGameNameMap()
    end
    return changed
end

local function EnsureFontsDB()
    _G.EllesmereUIDB = _G.EllesmereUIDB or {}
    _G.EllesmereUIDB.fonts = _G.EllesmereUIDB.fonts or {}
    local db = _G.EllesmereUIDB.fonts
    db.globalEnabled = true
    for i = 1, #FONT_KEYS do
        db[FONT_KEYS[i]] = FONT_NAME
    end
    return db
end

local function EnsureFontRegistry()
    E.IS_KOREAN_LOCALE = true
    E.DEFAULT_EUI_FONT_NAME = FONT_NAME
    E.FONT_BLIZZARD = E.FONT_BLIZZARD or {}
    E.FONT_BLIZZARD[FONT_NAME] = FONT_PATH
    E.FONT_FILES = E.FONT_FILES or {}
    E.FONT_FILES[FONT_NAME] = nil
    E.FONT_ORDER = E.FONT_ORDER or {}

    local found = false
    for i = 1, #E.FONT_ORDER do
        if E.FONT_ORDER[i] == FONT_NAME then
            found = true
            break
        end
    end
    if not found then
        table.insert(E.FONT_ORDER, 1, FONT_NAME)
    end
end

local function InstallCoreOverrides()
    if NS._coreOverridesInstalled then return end

    local origGetFontsDB = E.GetFontsDB
    local origResolveFontName = E.ResolveFontName

    E.GetFontsDB = function(...)
        local db
        if origGetFontsDB then
            db = origGetFontsDB(...)
        else
            db = EnsureFontsDB()
        end
        if not db then
            db = EnsureFontsDB()
        end
        db.globalEnabled = true
        for i = 1, #FONT_KEYS do
            db[FONT_KEYS[i]] = FONT_NAME
        end
        return db
    end

    E.ResolveFontName = function(fontName)
        if fontName == FONT_NAME then
            return FONT_PATH
        end
        if origResolveFontName then
            return origResolveFontName(fontName)
        end
        return FONT_PATH
    end

    E.GetFontPath = function(_)
        EnsureFontsDB()
        return FONT_PATH
    end

    E.GetFontName = function(_)
        EnsureFontsDB()
        return FONT_NAME
    end

    E.EXPRESSWAY = FONT_PATH
    E.T = NS.Translate
    E.LocalizeFrameTexts = NS.LocalizeFrameTexts
    E.MakeFont = function(parent, size, flags, r, g, b, a)
        local fs = parent:CreateFontString(nil, "OVERLAY")
        fs:SetFont(FONT_PATH, size or 12, flags or "")
        if r then fs:SetTextColor(r, g, b, a or 1) end
        return fs
    end

    EnsureFontRegistry()
    EnsureFontsDB()
    ApplySharedUIFont(FONT_PATH)
    NS._coreOverridesInstalled = true
end

local LocalizeSettingsFrames

local function InstallWidgetHooks()
    if type(E.ShowWidgetTooltip) == "function" and not NS._showWidgetTooltipWrapped then
        local origShowWidgetTooltip = E.ShowWidgetTooltip
        E.ShowWidgetTooltip = function(anchor, text, opts)
            return origShowWidgetTooltip(anchor, NS.Translate(text), opts)
        end
        NS._showWidgetTooltipWrapped = true
    end

    E.DisabledTooltip = function(requirement)
        if type(requirement) == "string" and requirement:find("^This option") then
            return NS.Translate(requirement)
        end
        if type(requirement) == "string" then
            local translated = NS.Translate(requirement)
            if translated ~= requirement then
                return NS.Translate("Required:") .. " " .. translated
            end
        end
        return NS.Translate("This option requires " .. tostring(requirement) .. " to be enabled")
    end

    if type(E.ShowConfirmPopup) == "function" and not NS._showConfirmPopupWrapped then
        local origShowConfirmPopup = E.ShowConfirmPopup
        E.ShowConfirmPopup = function(self, opts, ...)
            local results = { origShowConfirmPopup(self, LocalizePopupOptions(opts), ...) }
            Delay(LocalizeSettingsFrames)
            return unpack(results)
        end
        NS._showConfirmPopupWrapped = true
    end

    if type(E.ShowInfoPopup) == "function" and not NS._showInfoPopupWrapped then
        local origShowInfoPopup = E.ShowInfoPopup
        E.ShowInfoPopup = function(self, opts, ...)
            local results = { origShowInfoPopup(self, LocalizePopupOptions(opts), ...) }
            Delay(LocalizeSettingsFrames)
            return unpack(results)
        end
        NS._showInfoPopupWrapped = true
    end

    if type(E.ShowInputPopup) == "function" and not NS._showInputPopupWrapped then
        local origShowInputPopup = E.ShowInputPopup
        E.ShowInputPopup = function(self, opts, ...)
            local results = { origShowInputPopup(self, LocalizePopupOptions(opts), ...) }
            Delay(LocalizeSettingsFrames)
            return unpack(results)
        end
        NS._showInputPopupWrapped = true
    end
end

local function InstallDeferredWidgetHooks()
    if type(E.BuildDropdownControl) == "function" and not NS._buildDropdownWrapped then
        local origBuildDropdownControl = E.BuildDropdownControl
        E.BuildDropdownControl = function(parent, ddW, fLevel, values, order, getValue, setValue, disabledValuesFn)
            local ddBtn, ddLbl = origBuildDropdownControl(parent, ddW, fLevel, LocalizeDropdownValues(values), order, getValue, setValue, disabledValuesFn)
            if ddLbl and ddLbl.GetText and ddLbl.SetText then
                local currentText = ddLbl:GetText()
                local localizedText = NS.Translate(currentText)
                if localizedText ~= currentText then
                    ddLbl:SetText(localizedText)
                end
            end
            if ddBtn and ddBtn.HookScript and not ddBtn._euiKRPatchDropdownHooked then
                ddBtn:HookScript("OnClick", function(self)
                    Delay(function()
                        if self._ddMenu then
                            NS.LocalizeFrameTexts(self._ddMenu)
                        end
                    end)
                end)
                ddBtn._euiKRPatchDropdownHooked = true
            end
            return ddBtn, ddLbl
        end
        NS._buildDropdownWrapped = true
    end

    if type(E.BuildSegmentedControl) == "function" and not NS._buildSegmentedWrapped then
        local origBuildSegmentedControl = E.BuildSegmentedControl
        E.BuildSegmentedControl = function(cfg, ...)
            local results = { origBuildSegmentedControl(LocalizeSegmentedConfig(cfg), ...) }
            if results[1] then
                Delay(function() NS.LocalizeFrameTexts(results[1]) end)
            end
            return unpack(results)
        end
        NS._buildSegmentedWrapped = true
    end

    if type(E.BuildCogPopup) == "function" and not NS._buildCogWrapped then
        local origBuildCogPopup = E.BuildCogPopup
        E.BuildCogPopup = function(opts, ...)
            local results = { origBuildCogPopup(LocalizeCogPopupOptions(opts), ...) }
            local showFn = results[2]
            if type(showFn) == "table" and not showFn._euiKRWrapped then
                local origMeta = getmetatable(showFn)
                if origMeta and type(origMeta.__call) == "function" then
                    local proxy = { _orig = showFn, _euiKRWrapped = true }
                    setmetatable(proxy, {
                        __index = showFn,
                        __newindex = function(_, key, value)
                            showFn[key] = value
                        end,
                        __call = function(self, ...)
                            local callResults = { origMeta.__call(showFn, ...) }
                            self._popupFrame = showFn._popupFrame
                            if showFn._popupFrame then
                                Delay(function() NS.LocalizeFrameTexts(showFn._popupFrame) end)
                            end
                            return unpack(callResults)
                        end,
                    })
                    results[2] = proxy
                end
            end
            return unpack(results)
        end
        NS._buildCogWrapped = true
    end

    local widgets = E.Widgets
    if type(widgets) == "table" and not NS._widgetFactoryWrapped then
        if type(widgets.Dropdown) == "function" then
            local origDropdown = widgets.Dropdown
            widgets.Dropdown = function(self, parent, text, yOffset, values, getValue, setValue, order, tooltip)
                return origDropdown(self, parent, NS.Translate(text), yOffset, LocalizeDropdownValues(values), getValue, setValue, order, type(tooltip) == "string" and NS.Translate(tooltip) or tooltip)
            end
        end

        if type(widgets.DualRow) == "function" then
            local origDualRow = widgets.DualRow
            widgets.DualRow = function(self, parent, yOffset, leftCfg, rightCfg)
                return origDualRow(self, parent, yOffset, LocalizeWidgetConfig(leftCfg), LocalizeWidgetConfig(rightCfg))
            end
        end

        if type(widgets.TripleRow) == "function" then
            local origTripleRow = widgets.TripleRow
            widgets.TripleRow = function(self, parent, yOffset, leftCfg, midCfg, rightCfg, splits)
                return origTripleRow(self, parent, yOffset, LocalizeWidgetConfig(leftCfg), LocalizeWidgetConfig(midCfg), LocalizeWidgetConfig(rightCfg), splits)
            end
        end

        if type(widgets.DropdownWithOffsets) == "function" then
            local origDropdownWithOffsets = widgets.DropdownWithOffsets
            widgets.DropdownWithOffsets = function(self, parent, yOffset, dropdownCfg, xSliderCfg, ySliderCfg)
                return origDropdownWithOffsets(self, parent, yOffset, LocalizeWidgetConfig(dropdownCfg), LocalizeWidgetConfig(xSliderCfg), LocalizeWidgetConfig(ySliderCfg))
            end
        end

        if type(widgets.WideDropdown) == "function" then
            local origWideDropdown = widgets.WideDropdown
            widgets.WideDropdown = function(self, parent, title, yOffset, values, getValue, setValue, order, btnWidth, disabledValuesFn)
                return origWideDropdown(self, parent, NS.Translate(title), yOffset, LocalizeDropdownValues(values), getValue, setValue, order, btnWidth, disabledValuesFn)
            end
        end

        if type(widgets.TripleDropdown) == "function" then
            local origTripleDropdown = widgets.TripleDropdown
            widgets.TripleDropdown = function(self, parent, configs, yOffset)
                return origTripleDropdown(self, parent, LocalizeWidgetConfigList(configs), yOffset)
            end
        end

        NS._widgetFactoryWrapped = true
    end
end

local function LocalizeNamedFrame(frameName)
    local frame = _G[frameName]
    if frame then
        NS.LocalizeFrameTexts(frame)
    end
end

local function HookFrameLocalizer(frameName)
    local frame = _G[frameName]
    if frame and not frame._euiKRPatchLocalizeOnShow then
        frame:HookScript("OnShow", function(self)
            Delay(function() NS.LocalizeFrameTexts(self) end)
        end)
        frame._euiKRPatchLocalizeOnShow = true
    end
end

local function LocalizeTransientFrames()
    HookFrameLocalizer("DropDownList1")
    HookFrameLocalizer("DropDownList2")
    HookFrameLocalizer("DropDownList3")
    HookFrameLocalizer("EUIConfirmPopup")
    HookFrameLocalizer("EUIInfoPopup")
    HookFrameLocalizer("EUIInputPopup")
    LocalizeNamedFrame("EUIConfirmPopup")
    LocalizeNamedFrame("EUIInfoPopup")
    LocalizeNamedFrame("EUIInputPopup")
    if E._copyPopup then
        NS.LocalizeFrameTexts(E._copyPopup)
    end
    if E._colorPickerPopup then
        NS.LocalizeFrameTexts(E._colorPickerPopup)
    end
end

local function LocalizeVisibleOverlayFrames()
    if not _G.UIParent or not UIParent.GetChildren then return end
    local children = { UIParent:GetChildren() }
    for i = 1, #children do
        local child = children[i]
        local shown = false
        if child and type(child.IsShown) == "function" then
            local ok, result = pcall(child.IsShown, child)
            shown = ok and result and true or false
        end
        if shown then
            local name
            if type(child.GetName) == "function" then
                local ok, result = pcall(child.GetName, child)
                if ok then
                    name = result
                end
            end
            local strata
            if type(child.GetFrameStrata) == "function" then
                local ok, result = pcall(child.GetFrameStrata, child)
                if ok then
                    strata = result
                end
            end
            if (type(name) == "string" and (name:find("^EUI") or name:find("^DropDownList")))
                or (not name and (strata == "DIALOG" or strata == "FULLSCREEN_DIALOG")) then
                NS.LocalizeFrameTexts(child)
            end
        end
    end
end

LocalizeSettingsFrames = function()
    EnsureLocalizedAuraBuffReminderState()
    if _G.EllesmereUIFrame then
        NS.LocalizeFrameTexts(_G.EllesmereUIFrame)
    end
    if E._contentHeader then
        NS.LocalizeFrameTexts(E._contentHeader)
    end
    LocalizeTransientFrames()
    LocalizeVisibleOverlayFrames()
end

local function HookUnlockFrame()
    local frame = _G.EllesmereUnlockMode
    if not frame then return end
    if not frame._euiKRPatchHooked then
        frame:HookScript("OnShow", function(self)
            Delay(function() NS.LocalizeFrameTexts(self) end)
        end)
        frame._euiKRPatchHooked = true
    end
    NS.LocalizeFrameTexts(frame)
end

local InstallUnitFrameFontHooks
do
    local UNITFRAME_ROOT_NAMES = {
        "EllesmereUIUnitFrames_Player",
        "EllesmereUIUnitFrames_Target",
        "EllesmereUIUnitFrames_Focus",
        "EllesmereUIUnitFrames_Pet",
        "EllesmereUIUnitFrames_TargetTarget",
        "EllesmereUIUnitFrames_FocusTarget",
        "EllesmereUIUnitFrames_Boss1",
        "EllesmereUIUnitFrames_Boss2",
        "EllesmereUIUnitFrames_Boss3",
        "EllesmereUIUnitFrames_Boss4",
        "EllesmereUIUnitFrames_Boss5",
    }

    local hookedUnitFrames = {}

    local function ForceFontOnFontString(fs)
        if not fs or type(fs.GetFont) ~= "function" or type(fs.SetFont) ~= "function" then
            return
        end

        local currentPath, size, flags = fs:GetFont()
        if currentPath == FONT_PATH then
            return
        end

        fs:SetFont(FONT_PATH, size or 12, flags or "")
    end

    local function ApplyFontsToFrameTree(root)
        if not root then return end

        local queue = { root }
        local seen = {}
        local index = 1

        while queue[index] do
            local frame = queue[index]
            index = index + 1

            if frame and not seen[frame] then
                seen[frame] = true

                if type(frame.GetRegions) == "function" then
                    local regions = { frame:GetRegions() }
                    for i = 1, #regions do
                        local region = regions[i]
                        if region and type(region.IsObjectType) == "function" and region:IsObjectType("FontString") then
                            ForceFontOnFontString(region)
                        end
                    end
                end

                if type(frame.GetChildren) == "function" then
                    local children = { frame:GetChildren() }
                    for i = 1, #children do
                        queue[#queue + 1] = children[i]
                    end
                end
            end
        end
    end

    local function RefreshAllUnitFrameFonts()
        for i = 1, #UNITFRAME_ROOT_NAMES do
            ApplyFontsToFrameTree(_G[UNITFRAME_ROOT_NAMES[i]])
        end
    end

    local function HookUnitFrame(root)
        if not root or hookedUnitFrames[root] then return end

        if root.HookScript then
            root:HookScript("OnShow", function(self)
                Delay(function()
                    ApplyFontsToFrameTree(self)
                end)
            end)
        end

        if type(root.UpdateAllElements) == "function" then
            hooksecurefunc(root, "UpdateAllElements", function(self)
                Delay(function()
                    ApplyFontsToFrameTree(self)
                end)
            end)
        end

        hookedUnitFrames[root] = true
    end

    InstallUnitFrameFontHooks = function()
        for i = 1, #UNITFRAME_ROOT_NAMES do
            HookUnitFrame(_G[UNITFRAME_ROOT_NAMES[i]])
        end
        RefreshAllUnitFrameFonts()
    end
end

local InstallOverlayFeatureHooks
do
    local CHARACTER_SLOT_NAMES = {
        [1] = "CharacterHeadSlot",
        [2] = "CharacterNeckSlot",
        [3] = "CharacterShoulderSlot",
        [5] = "CharacterChestSlot",
        [6] = "CharacterWaistSlot",
        [7] = "CharacterLegsSlot",
        [8] = "CharacterFeetSlot",
        [9] = "CharacterWristSlot",
        [10] = "CharacterHandsSlot",
        [11] = "CharacterFinger0Slot",
        [12] = "CharacterFinger1Slot",
        [13] = "CharacterTrinket0Slot",
        [14] = "CharacterTrinket1Slot",
        [15] = "CharacterBackSlot",
        [16] = "CharacterMainHandSlot",
        [17] = "CharacterSecondaryHandSlot",
    }

    local overlayFrame
    local overlayHooksInstalled = false
    local playerCastbarHooksInstalled = false
    local pendingBagRefresh = false
    local pendingCharacterRefresh = false

    local function EnsureOverlayText(owner, key, size, point, relativeTo, relativePoint, xOffset, yOffset)
        if not owner then return nil end
        local fs = owner[key]
        if not fs then
            fs = owner:CreateFontString(nil, "OVERLAY")
            owner[key] = fs
        end
        fs:ClearAllPoints()
        fs:SetPoint(point, relativeTo or owner, relativePoint or point, xOffset or 0, yOffset or 0)
        fs:SetFont(FONT_PATH, size or 10, "OUTLINE")
        fs:SetShadowOffset(1, -1)
        fs:SetJustifyH("RIGHT")
        fs:SetJustifyV("TOP")
        fs:SetTextColor(1, 1, 1, 0.95)
        return fs
    end

    local function GetItemLevel(itemLocation, itemLink)
        local itemLevel
        if itemLocation and C_Item and C_Item.GetCurrentItemLevel then
            local ok, result = pcall(C_Item.GetCurrentItemLevel, itemLocation)
            if ok and type(result) == "number" and result > 1 then
                itemLevel = result
            end
        end
        if (not itemLevel or itemLevel <= 1) and itemLink and type(GetDetailedItemLevelInfo) == "function" then
            local ok, result = pcall(GetDetailedItemLevelInfo, itemLink)
            if ok and type(result) == "number" and result > 1 then
                itemLevel = result
            end
        end
        if type(itemLevel) == "number" and itemLevel > 1 then
            return math.floor(itemLevel + 0.5)
        end
        return nil
    end

    local function GetBagAndSlot(itemButton)
        if not itemButton then return nil, nil end

        local bagID
        if type(itemButton.GetBagID) == "function" then
            bagID = itemButton:GetBagID()
        end
        if bagID == nil and type(itemButton.GetParent) == "function" then
            local parent = itemButton:GetParent()
            if parent and type(parent.GetID) == "function" then
                bagID = parent:GetID()
            end
        end

        local slotID
        if type(itemButton.GetID) == "function" then
            slotID = itemButton:GetID()
        end
        if (bagID == nil or slotID == nil) and itemButton.BGR and itemButton.BGR.itemLocation then
            local itemLocation = itemButton.BGR.itemLocation
            if bagID == nil then
                bagID = itemLocation.bagID
            end
            if slotID == nil then
                slotID = itemLocation.slotIndex
            end
        end

        return bagID, slotID
    end

    local function RefreshBagItemButton(itemButton)
        if not itemButton then return end

        local fs = EnsureOverlayText(itemButton, "_euiKRBagItemLevelText", 10, "BOTTOMRIGHT", itemButton, "BOTTOMRIGHT", -2, 2)
        if not fs then return end
        fs:Hide()

        local bagID, slotID = GetBagAndSlot(itemButton)
        if type(bagID) ~= "number" or type(slotID) ~= "number" then
            return
        end

        local itemLink
        if C_Container and type(C_Container.GetContainerItemLink) == "function" then
            itemLink = C_Container.GetContainerItemLink(bagID, slotID)
        end
        if not itemLink or (type(IsEquippableItem) == "function" and not IsEquippableItem(itemLink)) then
            return
        end

        local itemLocation
        if ItemLocation and type(ItemLocation.CreateFromBagAndSlot) == "function" then
            itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
        end
        local itemLevel = GetItemLevel(itemLocation, itemLink)
        if itemLevel then
            fs:SetText(itemLevel)
            fs:Show()
        end
    end

    local function RefreshBagFrameItemLevels(frame)
        if not frame or type(frame.EnumerateValidItems) ~= "function" or not frame:IsShown() then
            return
        end
        for _, itemButton in frame:EnumerateValidItems() do
            RefreshBagItemButton(itemButton)
        end
    end

    local function HookBagFrame(frame)
        if not frame or frame._euiKRBagItemLevelHooked then return end

        if frame.HookScript then
            frame:HookScript("OnShow", function()
                pendingBagRefresh = false
                Delay(function()
                    RefreshBagFrameItemLevels(frame)
                end)
            end)
        end

        if type(frame.UpdateItems) == "function" then
            hooksecurefunc(frame, "UpdateItems", function()
                if pendingBagRefresh then return end
                pendingBagRefresh = true
                Delay(function()
                    pendingBagRefresh = false
                    RefreshBagFrameItemLevels(frame)
                end)
            end)
        end

        frame._euiKRBagItemLevelHooked = true
    end

    local function HookBagFrames()
        HookBagFrame(_G.ContainerFrameCombinedBags)

        local container = _G.ContainerFrameContainer
        local frames = container and container.ContainerFrames
        if type(frames) ~= "table" then return end
        for i = 1, #frames do
            HookBagFrame(frames[i])
        end
    end

    local function RefreshVisibleBagItemLevels()
        HookBagFrames()
        RefreshBagFrameItemLevels(_G.ContainerFrameCombinedBags)

        local container = _G.ContainerFrameContainer
        local frames = container and container.ContainerFrames
        if type(frames) ~= "table" then return end
        for i = 1, #frames do
            RefreshBagFrameItemLevels(frames[i])
        end
    end

    local function ScheduleBagItemLevelRefresh()
        if pendingBagRefresh then return end
        pendingBagRefresh = true
        Delay(function()
            pendingBagRefresh = false
            RefreshVisibleBagItemLevels()
        end)
    end

    local function RefreshCharacterSlotItemLevel(slotID, slotName)
        local slotButton = _G[slotName]
        if not slotButton then return end

        local fs = EnsureOverlayText(slotButton, "_euiKRItemLevelText", 10, "BOTTOMRIGHT", slotButton, "BOTTOMRIGHT", -2, 2)
        if not fs then return end
        fs:Hide()

        local itemLink = GetInventoryItemLink("player", slotID)
        if not itemLink then
            return
        end

        local itemLocation
        if ItemLocation and type(ItemLocation.CreateFromEquipmentSlot) == "function" then
            itemLocation = ItemLocation:CreateFromEquipmentSlot(slotID)
        end
        local itemLevel = GetItemLevel(itemLocation, itemLink)
        if itemLevel then
            fs:SetText(itemLevel)
            fs:Show()
        end
    end

    local function RefreshCharacterItemLevels()
        for slotID, slotName in pairs(CHARACTER_SLOT_NAMES) do
            RefreshCharacterSlotItemLevel(slotID, slotName)
        end
    end

    local function HookCharacterFrame()
        local frame = _G.CharacterFrame
        if not frame or frame._euiKRItemLevelHooked then return end
        if frame.HookScript then
            frame:HookScript("OnShow", function()
                pendingCharacterRefresh = false
                Delay(RefreshCharacterItemLevels)
            end)
        end
        frame._euiKRItemLevelHooked = true
    end

    local function ScheduleCharacterItemLevelRefresh()
        if pendingCharacterRefresh then return end
        pendingCharacterRefresh = true
        Delay(function()
            pendingCharacterRefresh = false
            HookCharacterFrame()
            RefreshCharacterItemLevels()
        end)
    end

    local function CleanupCDMHotkeyOverlays()
        if type(_G._ECME_GetBarFrame) ~= "function" then return end

        for _, barKey in ipairs({ "cooldowns", "utility" }) do
            local frame = _G._ECME_GetBarFrame(barKey)
            if frame and frame.GetChildren then
                local children = { frame:GetChildren() }
                for i = 1, #children do
                    local child = children[i]
                    local hotkeyText = child and child._euiKRHotkeyText
                    if hotkeyText then
                        hotkeyText:SetText("")
                        hotkeyText:Hide()
                    end
                end
            end
        end
    end

    local function SuppressBlizzardPlayerCastbar()
        local frame = _G.PlayerCastingBarFrame
        if not frame then return end

        if type(frame.UnregisterAllEvents) == "function" then
            frame:UnregisterAllEvents()
        end
        frame:Hide()
        if type(frame.SetScript) == "function" then
            frame:SetScript("OnUpdate", nil)
        end
        if not frame._euiKRHideHooked then
            hooksecurefunc(frame, "Show", function(self)
                self:Hide()
            end)
            frame._euiKRHideHooked = true
        end
    end

    local function SuppressEllesmerePlayerCastbar()
        local db = _G.EllesmereUIUnitFramesDB
        local settingsChanged = false
        if db and db.profile and db.profile.player then
            if db.profile.player.showPlayerCastbar ~= false then
                db.profile.player.showPlayerCastbar = false
                settingsChanged = true
            end
        end

        local frame = _G.EllesmereUIUnitFrames_Player
        if not frame then
            SuppressBlizzardPlayerCastbar()
            return
        end

        local castbar = frame.Castbar
        local castbarBg = castbar and castbar.GetParent and castbar:GetParent() or nil

        if castbar and type(frame.IsElementEnabled) == "function" and frame:IsElementEnabled("Castbar") and type(frame.DisableElement) == "function" then
            pcall(frame.DisableElement, frame, "Castbar")
        end

        if castbar then
            castbar:Hide()
            if not castbar._euiKRHideHooked then
                hooksecurefunc(castbar, "Show", function(self)
                    self:Hide()
                end)
                castbar._euiKRHideHooked = true
            end
        end

        if castbarBg then
            castbarBg:Hide()
            if not castbarBg._euiKRHideHooked then
                hooksecurefunc(castbarBg, "Show", function(self)
                    self:Hide()
                end)
                castbarBg._euiKRHideHooked = true
            end
        end

        if settingsChanged and frame.UpdateAllElements then
            pcall(frame.UpdateAllElements, frame, "EUIKRPatchHidePlayerCastbar")
        end

        if not playerCastbarHooksInstalled and frame.HookScript then
            frame:HookScript("OnShow", function()
                Delay(SuppressEllesmerePlayerCastbar)
            end)
            playerCastbarHooksInstalled = true
        end

        SuppressBlizzardPlayerCastbar()
    end

    local function HandleOverlayEvent(_, event, arg1)
        if event == "UNIT_INVENTORY_CHANGED" and arg1 ~= "player" then
            return
        end

        if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
            HookBagFrames()
            HookCharacterFrame()
            ScheduleBagItemLevelRefresh()
            ScheduleCharacterItemLevelRefresh()
            Delay(SuppressEllesmerePlayerCastbar)
            return
        end

        if event == "BAG_UPDATE_DELAYED" then
            ScheduleBagItemLevelRefresh()
            ScheduleCharacterItemLevelRefresh()
            return
        end

        if event == "GET_ITEM_INFO_RECEIVED" then
            ScheduleBagItemLevelRefresh()
            ScheduleCharacterItemLevelRefresh()
            return
        end

        if event == "PLAYER_EQUIPMENT_CHANGED" or event == "UNIT_INVENTORY_CHANGED" then
            ScheduleCharacterItemLevelRefresh()
            return
        end

        if event == "PLAYER_SPECIALIZATION_CHANGED" then
            Delay(SuppressEllesmerePlayerCastbar)
        end
    end

    InstallOverlayFeatureHooks = function()
        if overlayHooksInstalled then
            HookBagFrames()
            HookCharacterFrame()
            ScheduleBagItemLevelRefresh()
            ScheduleCharacterItemLevelRefresh()
            CleanupCDMHotkeyOverlays()
            return
        end

        overlayFrame = CreateFrame("Frame")
        overlayFrame:RegisterEvent("PLAYER_LOGIN")
        overlayFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        overlayFrame:RegisterEvent("BAG_UPDATE_DELAYED")
        overlayFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        overlayFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
        overlayFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
        overlayFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        overlayFrame:SetScript("OnEvent", HandleOverlayEvent)

        overlayHooksInstalled = true
        HookBagFrames()
        HookCharacterFrame()
        ScheduleBagItemLevelRefresh()
        ScheduleCharacterItemLevelRefresh()
        CleanupCDMHotkeyOverlays()
        Delay(SuppressEllesmerePlayerCastbar)
    end
end

local sweepFrame = CreateFrame("Frame")
local function StartLocalizationSweep()
    if NS._localizationSweepRunning then return end
    NS._localizationSweepRunning = true
    sweepFrame._elapsed = 0
    sweepFrame:SetScript("OnUpdate", function(self, elapsed)
        self._elapsed = (self._elapsed or 0) + elapsed
        if self._elapsed < 0.25 then return end
        self._elapsed = 0

        local settingsVisible = _G.EllesmereUIFrame and _G.EllesmereUIFrame:IsShown()
        local unlockVisible = _G.EllesmereUnlockMode and _G.EllesmereUnlockMode:IsShown()
        if not settingsVisible and not unlockVisible then
            NS._localizationSweepRunning = false
            self:SetScript("OnUpdate", nil)
            return
        end

        LocalizeSettingsFrames()
        if unlockVisible then
            HookUnlockFrame()
        end
    end)
end

local function InstallPrintHook()
    if NS._printWrapped or type(_G.print) ~= "function" then return end
    local origPrint = _G.print
    _G.print = function(...)
        local count = select("#", ...)
        local args = { ... }
        for i = 1, count do
            if ShouldTranslateChatMessage(args[i]) then
                args[i] = NS.Translate(args[i])
            end
        end
        return origPrint(unpack(args, 1, count))
    end
    NS._printWrapped = true
end

local function HookMethodOnce(methodName, callback)
    if hookedMethods[methodName] then return end
    if type(E[methodName]) ~= "function" then return end
    hooksecurefunc(E, methodName, callback)
    hookedMethods[methodName] = true
end

local function WrapUnlockOpen()
    if type(E._openUnlockMode) ~= "function" or NS._unlockWrapped then return end
    local orig = E._openUnlockMode
    E._openUnlockMode = function(...)
        local results = { orig(...) }
        Delay(HookUnlockFrame)
        return unpack(results)
    end
    NS._unlockWrapped = true
end

local function InstallRuntimeHooks()
    EnsureLocalizedAuraBuffReminderState()
    InstallCoreOverrides()
    InstallWidgetHooks()
    InstallUnitFrameFontHooks()
    InstallOverlayFeatureHooks()
    InstallPrintHook()
    if E._deferredLoaded then
        InstallDeferredWidgetHooks()
    end

    HookMethodOnce("EnsureLoaded", function()
        EnsureLocalizedAuraBuffReminderState()
        InstallCoreOverrides()
        InstallWidgetHooks()
        InstallDeferredWidgetHooks()
        InstallUnitFrameFontHooks()
        InstallOverlayFeatureHooks()
        WrapUnlockOpen()
        Delay(LocalizeSettingsFrames)
        Delay(HookUnlockFrame)
        StartLocalizationSweep()
    end)
    HookMethodOnce("Show", function() Delay(LocalizeSettingsFrames); StartLocalizationSweep() end)
    HookMethodOnce("SelectModule", function() Delay(LocalizeSettingsFrames); StartLocalizationSweep() end)
    HookMethodOnce("SelectUninstalledModule", function() Delay(LocalizeSettingsFrames); StartLocalizationSweep() end)
    HookMethodOnce("SelectPage", function() Delay(LocalizeSettingsFrames); StartLocalizationSweep() end)
    HookMethodOnce("RefreshPage", function() Delay(LocalizeSettingsFrames); StartLocalizationSweep() end)
    HookMethodOnce("ToggleUnlockMode", function() Delay(HookUnlockFrame); StartLocalizationSweep() end)

    if type(E.RegisterOnShow) == "function" and not NS._onShowRegistered then
        E:RegisterOnShow(function()
            Delay(LocalizeSettingsFrames)
            ApplySharedUIFont(FONT_PATH)
            StartLocalizationSweep()
        end)
        NS._onShowRegistered = true
    end

    WrapUnlockOpen()
    Delay(LocalizeSettingsFrames)
    Delay(HookUnlockFrame)
    StartLocalizationSweep()
end

InstallRuntimeHooks()

local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    EnsureLocalizedAuraBuffReminderState()
    InstallRuntimeHooks()
    EnsureFontsDB()
    EnsureFontRegistry()
    ApplySharedUIFont(FONT_PATH)
    InstallUnitFrameFontHooks()
    if _G.EllesmereUIDB then
        _G.EllesmereUIDB.fctFont = FONT_PATH
    end
    Delay(LocalizeSettingsFrames)
    Delay(HookUnlockFrame)
    StartLocalizationSweep()
end)

local itemInfoFrame = CreateFrame("Frame")
itemInfoFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
itemInfoFrame:RegisterEvent("ADDON_LOADED")
local _pendingAuraLocalize = false
itemInfoFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "GET_ITEM_INFO_RECEIVED" then
        if not _pendingAuraLocalize then
            _pendingAuraLocalize = true
            Delay(function()
                _pendingAuraLocalize = false
                EnsureLocalizedAuraBuffReminderState()
                if NS.InvalidateDynamicGameNameMap then
                    NS.InvalidateDynamicGameNameMap()
                end
            end)
        end
        Delay(LocalizeSettingsFrames)
        Delay(HookUnlockFrame)
        StartLocalizationSweep()
        return
    end

    if arg1 == "EllesmereUIAuraBuffReminders" then
        EnsureLocalizedAuraBuffReminderState()
        if NS.InvalidateDynamicGameNameMap then
            NS.InvalidateDynamicGameNameMap()
        end
        Delay(LocalizeSettingsFrames)
        StartLocalizationSweep()
        return
    end

    if arg1 == "EllesmereUIUnitFrames" then
        Delay(InstallUnitFrameFontHooks)
    end
end)
