-- Init.lua — Ayije_CDM_Keybind bootstrap
-- Injects keybind text overlay into Ayije_CDM without modifying original files.
-- Loads after Ayije_CDM (Dependencies: Ayije_CDM).

local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
if not CDM then return end

-- =========================================================================
--  DEFAULTS INJECTION
-- =========================================================================
-- Inject keybind defaults into CDM.defaults so new installs get sensible values.
-- Existing saved settings in CDM.db take priority (SavedVariables survive updates).

local defaults = CDM.defaults
if defaults then
    if defaults.keybindEnabled == nil then defaults.keybindEnabled = false end
    if defaults.keybindFontSize == nil then defaults.keybindFontSize = 10 end
    if defaults.keybindColor == nil then defaults.keybindColor = { r = 1, g = 1, b = 1, a = 0.8 } end
    if defaults.keybindPosition == nil then defaults.keybindPosition = "TOPLEFT" end
    if defaults.keybindOffsetX == nil then defaults.keybindOffsetX = 0 end
    if defaults.keybindOffsetY == nil then defaults.keybindOffsetY = 0 end
end

-- =========================================================================
--  STYLE HOOKS (replaces original Style.lua / Main.lua integration)
-- =========================================================================
-- Hook ApplyStyle to inject keybind text on viewer frames.
-- Controlled by assistEnabled via GetKeybindConfig().

hooksecurefunc(CDM, "ApplyStyle", function(self, frame, vName)
    if self.ApplyKeybindText then
        self:ApplyKeybindText(frame, vName)
    end
end)

-- Hook ApplyTrackerStyle for Defensives/Racials/Trinkets tracker frames.
if CDM.ApplyTrackerStyle then
    hooksecurefunc(CDM, "ApplyTrackerStyle", function(self, frame, vName)
        if self.ApplyKeybindText then
            self:ApplyKeybindText(frame, vName)
        end
    end)
end

-- =========================================================================
--  OPTIONS UI (replaces CDM_Options/Text.lua keybind section)
-- =========================================================================
-- CreateKeybindTab follows the same pattern as Text.lua tabs.
-- It is registered when CDM_Options loads (ADDON_LOADED hook below).

local function CreateKeybindTab(page, tabId)
    local ns = CDM._OptionsNS
    if not ns then return end
    local UI = ns.ConfigUI
    if not UI then return end
    local API = CDM.API

    local scrollChild = UI.CreateScrollableTab(page, "AyijeCDM_KeybindScrollFrame", 600, 1280)

    local layout = UI.CreateVerticalLayout(0)
    local function NextY(spacing) return layout:Next(spacing) end

    local function SetDB(key)
        return function(v) CDM.db[key] = v; API:RefreshConfig() end
    end

    -- Header
    local header = UI.CreateHeader(scrollChild, "단축키 텍스트")
    header:SetPoint("TOPLEFT", 0, NextY(0))

    -- Enable checkbox
    page.controls.keybindEnabled = UI.CreateModernCheckbox(
        scrollChild, "단축키 표시",
        CDM.db.keybindEnabled or false,
        SetDB("keybindEnabled")
    )
    page.controls.keybindEnabled:SetPoint("TOPLEFT", 0, NextY(30))

    -- Font size slider
    page.controls.keybindFontSize = UI.CreateModernSlider(
        scrollChild, "글자 크기", 6, 24,
        CDM.db.keybindFontSize or CDM.defaults.keybindFontSize or 10,
        SetDB("keybindFontSize")
    )
    page.controls.keybindFontSize:SetPoint("TOPLEFT", 0, NextY(35))

    -- Color picker
    page.keybindColorPicker = UI.CreateColorSwatch(scrollChild, "색상", "keybindColor")
    page.keybindColorPicker:SetPoint("TOPLEFT", 0, NextY(60))

    -- Position Dropdown
    local lblPos = scrollChild:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    lblPos:SetText("위치")
    lblPos:SetPoint("TOPLEFT", 0, NextY(60))

    local ddPos = CreateFrame("DropdownButton", nil, scrollChild, "WowStyle1DropdownTemplate")
    ddPos:SetPoint("TOPLEFT", lblPos, "BOTTOMLEFT", 0, -10)
    ddPos:SetWidth(180)
    ddPos:SetDefaultText(CDM.db.keybindPosition or CDM.defaults.keybindPosition or "TOPLEFT")
    page.keybindPosDropdown = ddPos
    NextY(45)

    UI.SetupPositionDropdown(
        ddPos,
        function() return CDM.db.keybindPosition end,
        function(pos)
            CDM.db.keybindPosition = pos
            ddPos:SetDefaultText(pos)
            API:RefreshConfig()
        end
    )

    -- X Offset slider
    page.controls.keybindOffsetX = UI.CreateModernSlider(
        scrollChild, "X 오프셋", -50, 50,
        CDM.db.keybindOffsetX or 0,
        SetDB("keybindOffsetX")
    )
    page.controls.keybindOffsetX:SetPoint("TOPLEFT", 0, NextY(10))

    -- Y Offset slider
    page.controls.keybindOffsetY = UI.CreateModernSlider(
        scrollChild, "Y 오프셋", -50, 50,
        CDM.db.keybindOffsetY or 0,
        SetDB("keybindOffsetY")
    )
    page.controls.keybindOffsetY:SetPoint("TOPLEFT", 0, NextY(60))
end

-- =========================================================================
--  EVENT REGISTRATION (replaces Main.lua keybind event block)
-- =========================================================================

local eventFrame = CreateFrame("Frame")

local function RefreshKeybinds()
    if CDM.RefreshAllKeybindTexts then
        CDM:RefreshAllKeybindTexts()
    end
end

local function RefreshKeybindsDelayed(delay)
    C_Timer.After(delay or 0.3, RefreshKeybinds)
end

-- Debounced refresh: coalesces rapid bursts of ACTIONBAR_SLOT_CHANGED
-- (e.g. 16 slots firing at once when mousing over party frames) into one call.
local _refreshPending = false
local function RefreshKeybindsDebounced()
    if not _refreshPending then
        _refreshPending = true
        C_Timer.After(0.15, function()
            _refreshPending = false
            RefreshKeybinds()
        end)
    end
end

eventFrame:RegisterEvent("UPDATE_BINDINGS")
eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
eventFrame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
eventFrame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
eventFrame:RegisterEvent("ADDON_LOADED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "UPDATE_BINDINGS" or event == "ACTIONBAR_SLOT_CHANGED" then
        RefreshKeybindsDebounced()
    elseif event == "SPELLS_CHANGED" then
        RefreshKeybindsDelayed(0.1)
    elseif event == "UPDATE_SHAPESHIFT_FORM"
        or event == "UPDATE_BONUS_ACTIONBAR"
        or event == "ACTIONBAR_PAGE_CHANGED" then
        RefreshKeybindsDelayed(0.3)
    elseif event == "ADDON_LOADED" then
        local addonLoaded = ...
        if addonLoaded == "Ayije_CDM_Options" then
            -- CDM_Options just loaded — register our keybind settings tab
            local API = CDM.API
            if API and API.RegisterConfigTab then
                API:RegisterConfigTab("keybind", "단축키", CreateKeybindTab, 6)
            end
            self:UnregisterEvent("ADDON_LOADED")
        end
    end
end)

-- =========================================================================
--  ASSIST TOGGLE CALLBACK
-- =========================================================================
-- Respond to assistEnabled changes so keybind text hides/shows immediately.

if CDM.RegisterRefreshCallback then
    CDM:RegisterRefreshCallback("assist", function()
        if CDM.RefreshAllKeybindTexts then
            CDM:RefreshAllKeybindTexts()
        end
    end, 37)
end
