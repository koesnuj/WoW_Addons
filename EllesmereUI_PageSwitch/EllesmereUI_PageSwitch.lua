-------------------------------------------------------------------------------
--  EllesmereUI_PageSwitch.lua
--
--  Adds Shift+MouseWheel page switching to EllesmereUIActionBars MainBar.
--  Shift+WheelUp/Down = toggle between Bar1 (slots 1-12) and Action Bar 6 / MultiBar5 (slots 145-156)
--
--  ElvUI-inspired approach:
--    - Re-registers EAB's page state driver with [bar:N] BEFORE [bonusbar:5],
--      so /changeactionbar takes priority over dragonriding (bonusbar:5).
--    - Adds [bar:12] 12 condition: page 12 → offset 144 → MultiBar5 slots.
--    - Uses SecureActionButtonTemplate macros for Shift+Wheel bindings.
--    - Does NOT modify EAB's UpdateOffset — immune to EAB resets.
-------------------------------------------------------------------------------
local ADDON_NAME = ...

local MAINBAR_FRAME = "EABBar_MainBar"
local HANDLER_NAME  = "EUIPageSwitch"
local PAGE_BAR6     = 2    -- EAB "Action Bar 6" in TWW: NUM_ACTIONBAR_PAGES=2,
                            -- /changeactionbar 2 maps to Action Bar 6 (MultiBar5)

-------------------------------------------------------------------------------
--  Build modified paging conditions (ElvUI pattern)
--  Puts [bar:N] BEFORE [bonusbar:5] so user-set pages beat dragonriding.
--  Adds [bar:12] 12 for Bar6/MultiBar5 access while flying.
-------------------------------------------------------------------------------
local function BuildConditions()
    local _, class = UnitClass("player")
    local c = ""

    -- Override/vehicle bar (absolute priority, same as EAB)
    if GetOverrideBarIndex then
        c = c .. "[overridebar] " .. GetOverrideBarIndex() .. "; "
    end
    if GetVehicleBarIndex then
        c = c .. "[vehicleui][possessbar] " .. GetVehicleBarIndex() .. "; "
    end

    -- Class stance/form paging (kept before user pages, same as EAB)
    if class == "DRUID" then
        c = c .. "[bonusbar:1,stealth] 7; [bonusbar:1] 7; [bonusbar:3] 9; [bonusbar:4] 10; "
    elseif class == "ROGUE" then
        c = c .. "[bonusbar:1] 7; "
    end

    -- User-set pages (ElvUI: these come BEFORE bonusbar:5 so they work mid-flight)
    c = c .. "[bar:" .. PAGE_BAR6 .. "] " .. PAGE_BAR6 .. "; "  -- Bar6/MultiBar5
    for i = 2, NUM_ACTIONBAR_PAGES or 6 do
        c = c .. "[bar:" .. i .. "] " .. i .. "; "
    end

    -- Dragonriding/Skyriding — after user-set pages (ElvUI pattern)
    c = c .. "[bonusbar:5] 11; "

    return c .. "1"
end

-------------------------------------------------------------------------------
--  Core Init — called once MainBar frame is confirmed to exist
-------------------------------------------------------------------------------
local function Init()
    local mainBar = _G[MAINBAR_FRAME]
    if not mainBar then return end
    if not _G["ActionButton1"] then return end

    ---------------------------------------------------------------------------
    --  1. Re-register EAB's page state driver with modified conditions
    --     Unregister EAB's driver first, then re-register with our conditions.
    --     EAB's original UpdateOffset handles page 12 → offset 144 correctly.
    ---------------------------------------------------------------------------
    UnregisterStateDriver(mainBar, "page")
    RegisterStateDriver(mainBar, "page", BuildConditions())

    ---------------------------------------------------------------------------
    --  2. Two SecureActionButtonTemplate frames for bindings
    --     WheelUp  → /changeactionbar 12  (Bar6/MultiBar5)
    --     WheelDown → /changeactionbar 1   (default Bar1)
    ---------------------------------------------------------------------------
    local btn = CreateFrame("Button", HANDLER_NAME, UIParent, "SecureActionButtonTemplate")
    btn:SetSize(1, 1)
    btn:SetPoint("CENTER")
    btn:RegisterForClicks("AnyDown")
    btn:SetAttribute("type", "macro")
    -- Toggle: if currently on Bar6 → go to Bar1, otherwise → go to Bar6
    btn:SetAttribute("macrotext", "/changeactionbar [bar:" .. PAGE_BAR6 .. "] 1; " .. PAGE_BAR6)

    SetOverrideBindingClick(btn, true, "SHIFT-MOUSEWHEELUP",   HANDLER_NAME)
    SetOverrideBindingClick(btn, true, "SHIFT-MOUSEWHEELDOWN", HANDLER_NAME)

    ---------------------------------------------------------------------------
    --  3. Page indicator — shows "Bar 6" below MainBar when on page 12
    ---------------------------------------------------------------------------
    local indicator = mainBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    indicator:SetPoint("TOP", mainBar, "BOTTOM", 0, -2)
    indicator:SetTextColor(0.8, 0.8, 0.2, 0.9)
    indicator:Hide()

    mainBar:HookScript("OnAttributeChanged", function(self, name, value)
        if name == "state-page" then
            if tonumber(value) == PAGE_BAR6 then
                indicator:SetText("Bar 6")
                indicator:Show()
            else
                indicator:Hide()
            end
        end
    end)

    print("|cff0cd29f[EllesmereUI PageSwitch]|r Loaded — Shift+WheelUp=Bar6, Shift+WheelDown=Bar1")
end

-------------------------------------------------------------------------------
--  Bootstrap — wait for EllesmereUIActionBars to finish creating bars
--  EAB:OnEnable() → FinishSetup() runs at PLAYER_LOGIN.
--  We hook at PLAYER_ENTERING_WORLD + 1s delay to guarantee bars exist.
--  Combat-safe: defers Init() until out of combat if InCombatLockdown().
-------------------------------------------------------------------------------
local _initDone = false
local bootstrap = CreateFrame("Frame")
bootstrap:RegisterEvent("PLAYER_ENTERING_WORLD")
bootstrap:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        if not _initDone and _G[MAINBAR_FRAME] then
            _initDone = true
            Init()
        end
        return
    end
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    C_Timer.After(1, function()
        if _initDone then return end
        if InCombatLockdown() then
            bootstrap:RegisterEvent("PLAYER_REGEN_ENABLED")
            return
        end
        if _G[MAINBAR_FRAME] then
            _initDone = true
            Init()
        else
            C_Timer.After(2, function()
                if _initDone then return end
                if InCombatLockdown() then
                    bootstrap:RegisterEvent("PLAYER_REGEN_ENABLED")
                    return
                end
                if _G[MAINBAR_FRAME] then
                    _initDone = true
                    Init()
                end
            end)
        end
    end)
end)
