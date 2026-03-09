-------------------------------------------------------------------------------
--  EllesmereUI_FlyoutFix.lua
--
--  Standalone patch for EllesmereUIActionBars.
--  Fixes flyout spells (pet summon, etc.) not firing via keybind.
--
--  Problem:  EAB routes keybinds to hidden "bind buttons" (_EABBind) via
--            SetOverrideBindingClick.  These SecureActionButtonTemplate
--            frames cannot toggle SpellFlyout — only the real ActionButton
--            frame type can.
--
--  Fix (3 parts, applied externally without modifying EAB):
--    1. flyoutDirection — set on every ActionButton so the flyout opens
--       in the correct direction relative to the bar orientation.
--    2. Bind button geometry — SetAllPoints(parent) so SpellFlyout anchors
--       at the correct screen position, plus SetPassThroughButtons so real
--       mouse clicks fall through to the parent ActionButton.
--    3. Keybind routing — hook SetOverrideBindingClick globally; whenever
--       EAB targets an _EABBind button, immediately re-issue the call
--       with the parent ActionButton name instead.  This fires EVERY time
--       EAB rebinds (combat end, UPDATE_BINDINGS, etc.) so our redirect
--       is never lost.
-------------------------------------------------------------------------------

local BAR_INFO = {
    { prefix = "ActionButton",              count = 12, key = "MainBar" },
    { prefix = "MultiBarBottomLeftButton",   count = 12, key = "Bar2" },
    { prefix = "MultiBarBottomRightButton",  count = 12, key = "Bar3" },
    { prefix = "MultiBarRightButton",        count = 12, key = "Bar4" },
    { prefix = "MultiBarLeftButton",         count = 12, key = "Bar5" },
    { prefix = "MultiBar5Button",            count = 12, key = "Bar6" },
    { prefix = "MultiBar6Button",            count = 12, key = "Bar7" },
    { prefix = "MultiBar7Button",            count = 12, key = "Bar8" },
}

local BIND_SUFFIX = "_EABBind"

-------------------------------------------------------------------------------
--  3. Keybind routing (highest priority — must be active before anything)
--
--  hooksecurefunc fires AFTER the original SetOverrideBindingClick.
--  If the target is an _EABBind button, we immediately overwrite the
--  binding to point at the parent ActionButton instead.
--  Second call's target does NOT end with _EABBind → hook returns → no loop.
-------------------------------------------------------------------------------
local redirectActive = false  -- guard against re-entry

hooksecurefunc("SetOverrideBindingClick", function(owner, isPriority, key, buttonName, clickType)
    if redirectActive then return end
    if not buttonName then return end
    if not buttonName:find(BIND_SUFFIX, 1, true) then return end

    -- Derive parent ActionButton name
    local parentName = buttonName:sub(1, -(#BIND_SUFFIX + 1))
    if not _G[parentName] then return end

    redirectActive = true
    SetOverrideBindingClick(owner, isPriority, key, parentName, "HOTKEY")
    redirectActive = false
end)

-------------------------------------------------------------------------------
--  1. flyoutDirection
-------------------------------------------------------------------------------
local function GetFlyoutDirection(barKey)
    -- Read EAB's saved bar settings via EllesmereUI.Lite
    local E = _G.EllesmereUI
    local EAB = E and E.Lite and E.Lite.GetAddon and E.Lite.GetAddon("EllesmereUIActionBars", true)
    local db = EAB and EAB.db
    local s = db and db.profile and db.profile.bars and db.profile.bars[barKey]
    if not s then return "UP" end

    local isVertical = (s.orientation == "vertical")
    local growUp = (s.growDirection or "up") == "up"

    if isVertical then return "RIGHT"
    elseif growUp then return "UP"
    else return "DOWN"
    end
end

local function ApplyFlyoutDirections()
    if InCombatLockdown() then return end
    for _, info in ipairs(BAR_INFO) do
        local dir = GetFlyoutDirection(info.key)
        for i = 1, info.count do
            local btn = _G[info.prefix .. i]
            if btn then
                btn:SetAttribute("flyoutDirection", dir)
            end
        end
    end
end

-------------------------------------------------------------------------------
--  2. Bind button geometry — SetAllPoints + SetPassThroughButtons
-------------------------------------------------------------------------------
local patchedBinds = {}

local function PatchBindButton(bind, btn)
    if not bind or not btn or patchedBinds[bind] then return end
    if InCombatLockdown() then return end
    patchedBinds[bind] = true

    -- Match parent so SpellFlyout anchors to the visible button
    bind:ClearAllPoints()
    bind:SetAllPoints(btn)

    -- Real mouse clicks pass through; keybind "HOTKEY" clicks do not
    if bind.SetPassThroughButtons then
        bind:SetPassThroughButtons("LeftButton", "RightButton", "MiddleButton", "Button4", "Button5")
    end
end

local function PatchAllBindButtons()
    if InCombatLockdown() then return end
    for _, info in ipairs(BAR_INFO) do
        for i = 1, info.count do
            local btn = _G[info.prefix .. i]
            if btn then
                local bind = _G[btn:GetName() .. BIND_SUFFIX]
                if bind then
                    PatchBindButton(bind, btn)
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
--  Initialization
-------------------------------------------------------------------------------
local function ApplyAllPatches()
    if InCombatLockdown() then return end
    ApplyFlyoutDirections()
    PatchAllBindButtons()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")

    -- EAB sets up bars in OnEnable (PLAYER_LOGIN). Delay so it finishes first.
    C_Timer.After(1, function()
        if InCombatLockdown() then
            local cf = CreateFrame("Frame")
            cf:RegisterEvent("PLAYER_REGEN_ENABLED")
            cf:SetScript("OnEvent", function(s)
                s:UnregisterEvent("PLAYER_REGEN_ENABLED")
                ApplyAllPatches()
            end)
            return
        end
        ApplyAllPatches()
    end)
end)

-- Re-apply when bars are re-laid-out (settings change, profile reload, etc.)
local refreshFrame = CreateFrame("Frame")
refreshFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
refreshFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
refreshFrame:SetScript("OnEvent", function()
    C_Timer.After(0, function()
        if InCombatLockdown() then return end
        ApplyAllPatches()
    end)
end)

-- Re-apply when EllesmereUI panel closes (bar re-layout)
C_Timer.After(2, function()
    if EllesmereUI and EllesmereUI.RegisterOnShow then
        EllesmereUI:RegisterOnShow(function()
            C_Timer.After(0.5, function()
                if InCombatLockdown() then return end
                ApplyAllPatches()
            end)
        end)
    end
end)
