-------------------------------------------------------------------------------
--  EllesmereUIUnlockExtras.lua
--  Registers Vehicle Leave, Queue Status, Loot Frame, Loot Roll,
--  LFG Ready Popup, Ready Check, Bonus Roll, and Alert Toasts
--  as movable elements in EllesmereUI's Unlock Mode.
--
--  Uses EllesmereUI.Lite profile system — positions are per-profile and
--  automatically shared/switched when the EllesmereUI profile changes.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local E = EllesmereUI
local EUE = E.Lite.NewAddon(ADDON_NAME)
ns.EUE = EUE

-------------------------------------------------------------------------------
--  DB defaults (stored under db.profile via EUILite.NewDB)
-------------------------------------------------------------------------------
local defaults = {
    profile = {
        positions = {},   -- { [key] = { point, relPoint, x, y, scale } }
        vehicleLeave = { enabled = true },
        queueStatus  = { enabled = true },
        lootFrame    = { enabled = true },
        lootRoll     = { enabled = true },
        lfgReadyPopup = { enabled = true },
        readyCheck    = { enabled = true },
        bonusRoll     = { enabled = true },
        alertToasts   = { enabled = true },
    },
}

local db  -- set in OnInitialize

-------------------------------------------------------------------------------
--  Shared helpers
-------------------------------------------------------------------------------
local function SavePosition(key, point, relPoint, x, y, scale)
    if not db then return end
    db.profile.positions[key] = {
        point    = point,
        relPoint = relPoint,
        x        = x,
        y        = y,
        scale    = scale,
    }
end

local function LoadPosition(key)
    if not db or not db.profile.positions[key] then return nil end
    return db.profile.positions[key]
end

local function ClearPosition(key)
    if not db then return end
    db.profile.positions[key] = nil
end

local function ApplyPositionToHolder(key, holder)
    if not holder then return end
    local pos = LoadPosition(key)
    if pos and pos.point then
        holder:ClearAllPoints()
        holder:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
        if pos.scale and pos.scale ~= 1 then
            pcall(holder.SetScale, holder, pos.scale)
        end
    end
end

-------------------------------------------------------------------------------
--  1. Vehicle Leave Button
--
--  Blizzard frame: MainMenuBarVehicleLeaveButton
--  Pattern: Create an invisible holder → reparent the Blizzard button to it
--           → hook SetPoint to prevent Blizzard from moving it back
-------------------------------------------------------------------------------
local vehicleHolder

local function SetupVehicleLeave()
    local button = _G.MainMenuBarVehicleLeaveButton
    if not button then return end

    vehicleHolder = CreateFrame("Frame", "EllesmereUIUnlockExtras_VehicleLeaveHolder", UIParent)
    vehicleHolder:SetSize(40, 40)
    vehicleHolder:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 300)

    -- Apply any saved position
    ApplyPositionToHolder("VehicleLeave", vehicleHolder)

    -- Reparent the Blizzard button onto our holder
    button:ClearAllPoints()
    button:SetParent(UIParent)
    button:SetPoint("CENTER", vehicleHolder, "CENTER")

    -- Prevent Blizzard Edit Mode from stealing the button's position
    -- Use pcall-wrapped SetPoint guard (the OnShow/OnHide scripts cause
    -- taint via EditModeManager's UpdateBottomActionBarPositions)
    button:SetScript("OnShow", nil)
    button:SetScript("OnHide", nil)

    hooksecurefunc(button, "SetPoint", function(self, _, parent)
        if parent ~= vehicleHolder then
            self:ClearAllPoints()
            self:SetParent(UIParent)
            self:SetPoint("CENTER", vehicleHolder, "CENTER")
        end
    end)
end

local function GetVehicleLeaveElement()
    return {
        key   = "VehicleLeave",
        label = "Vehicle Leave Button",
        order = 200,
        getFrame = function()
            return vehicleHolder
        end,
        getSize = function()
            local btn = _G.MainMenuBarVehicleLeaveButton
            if btn then
                local w, h = btn:GetSize()
                if w and w > 1 then return w, h, 0 end
            end
            return 40, 40, 0
        end,
        savePosition  = function(key, point, relPoint, x, y, scale)
            SavePosition(key, point, relPoint, x, y, scale)
        end,
        loadPosition  = function(key) return LoadPosition(key) end,
        clearPosition = function(key) ClearPosition(key) end,
        applyPosition = function(key)
            ApplyPositionToHolder(key, vehicleHolder)
            -- Re-anchor the Blizzard button
            local btn = _G.MainMenuBarVehicleLeaveButton
            if btn and vehicleHolder then
                pcall(function()
                    btn:ClearAllPoints()
                    btn:SetPoint("CENTER", vehicleHolder, "CENTER")
                end)
            end
        end,
        isHidden = function()
            -- Show the mover even when not in a vehicle so user can position it
            return not vehicleHolder
        end,
    }
end

-------------------------------------------------------------------------------
--  2. Queue Status Button
--
--  Blizzard frame: QueueStatusButton (the eye icon when queued for LFG/PvP)
--  Pattern: Create holder → reparent → hook
-------------------------------------------------------------------------------
local queueHolder

local function SetupQueueStatus()
    local button = _G.QueueStatusButton
    if not button then return end

    queueHolder = CreateFrame("Frame", "EllesmereUIUnlockExtras_QueueStatusHolder", UIParent)
    queueHolder:SetSize(32, 32)
    -- Default: near minimap bottom-right
    queueHolder:SetPoint("BOTTOMRIGHT", _G.Minimap or UIParent, "BOTTOMRIGHT", -5, 25)

    -- Apply any saved position
    ApplyPositionToHolder("QueueStatus", queueHolder)

    -- Reparent
    button:ClearAllPoints()
    button:SetParent(UIParent)
    button:SetPoint("CENTER", queueHolder, "CENTER")

    -- Guard against Blizzard repositioning
    hooksecurefunc(button, "SetPoint", function(self, _, parent)
        if parent ~= queueHolder then
            self:ClearAllPoints()
            self:SetParent(UIParent)
            self:SetPoint("CENTER", queueHolder, "CENTER")
        end
    end)

    -- Also hook SetScale so Blizzard doesn't override our scale
    local origScale = button:GetScale()
    hooksecurefunc(button, "SetScale", function(self, scale)
        if scale ~= origScale then
            -- Let our system handle scale via the unlock mover
        end
    end)
end

local function GetQueueStatusElement()
    return {
        key   = "QueueStatus",
        label = "Queue Status",
        order = 201,
        getFrame = function()
            return queueHolder
        end,
        getSize = function()
            local btn = _G.QueueStatusButton
            if btn then
                local w, h = btn:GetSize()
                if w and w > 1 then return w, h, 0 end
            end
            return 32, 32, 0
        end,
        savePosition  = function(key, point, relPoint, x, y, scale)
            SavePosition(key, point, relPoint, x, y, scale)
        end,
        loadPosition  = function(key) return LoadPosition(key) end,
        clearPosition = function(key) ClearPosition(key) end,
        applyPosition = function(key)
            ApplyPositionToHolder(key, queueHolder)
            local btn = _G.QueueStatusButton
            if btn and queueHolder then
                pcall(function()
                    btn:ClearAllPoints()
                    btn:SetPoint("CENTER", queueHolder, "CENTER")
                end)
            end
        end,
        isHidden = function()
            return not queueHolder
        end,
    }
end

-------------------------------------------------------------------------------
--  3. Loot Frame
--
--  Blizzard frame: LootFrame
--  Special handling: If the CVar "lootUnderMouse" is enabled, the loot
--  frame appears at the cursor and our mover is bypassed.
--  Pattern: Create holder → on LOOT_OPENED, reposition LootFrame to holder
-------------------------------------------------------------------------------
local lootHolder
local lootEventFrame

local function SetupLootFrame()
    lootHolder = CreateFrame("Frame", "EllesmereUIUnlockExtras_LootFrameHolder", UIParent)
    lootHolder:SetSize(170, 200)
    lootHolder:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 50, -200)

    -- Apply any saved position
    ApplyPositionToHolder("LootFrame", lootHolder)

    -- Event frame to hook LOOT_OPENED
    lootEventFrame = CreateFrame("Frame")
    lootEventFrame:RegisterEvent("LOOT_OPENED")
    lootEventFrame:RegisterEvent("LOOT_CLOSED")
    lootEventFrame:SetScript("OnEvent", function(_, event)
        if event == "LOOT_OPENED" then
            local lf = _G.LootFrame
            if not lf then return end

            -- Respect "loot under mouse" CVar
            if C_CVar and C_CVar.GetCVarBool and C_CVar.GetCVarBool("lootUnderMouse") then
                return
            end

            -- Move LootFrame to our holder position
            pcall(function()
                lf:ClearAllPoints()
                lf:SetPoint("TOPLEFT", lootHolder, "TOPLEFT")
            end)
        end
    end)
end

local function GetLootFrameElement()
    return {
        key   = "LootFrame",
        label = "Loot Frame",
        order = 202,
        getFrame = function()
            return lootHolder
        end,
        getSize = function()
            -- LootFrame varies in size; provide a reasonable default for the mover
            local lf = _G.LootFrame
            if lf and lf:IsShown() then
                local w, h = lf:GetSize()
                if w and w > 1 then return w, h, 0 end
            end
            return 170, 200, 0
        end,
        savePosition  = function(key, point, relPoint, x, y, scale)
            SavePosition(key, point, relPoint, x, y, scale)
        end,
        loadPosition  = function(key) return LoadPosition(key) end,
        clearPosition = function(key) ClearPosition(key) end,
        applyPosition = function(key)
            ApplyPositionToHolder(key, lootHolder)
        end,
        isHidden = function()
            -- Show the mover even when loot frame isn't open
            return not lootHolder
        end,
    }
end

-------------------------------------------------------------------------------
--  4. Loot Roll (Need/Greed/Disenchant)
--
--  Blizzard frame: GroupLootContainer (holds GroupLootFrame1~4)
--  The container is repositioned by Blizzard via GroupLootContainer_Update.
--  Pattern: Create holder → hook GroupLootContainer_Update to re-anchor
--           → disable UIPARENT_MANAGED_FRAME_POSITIONS for GroupLootContainer
-------------------------------------------------------------------------------
local lootRollHolder

local function SetupLootRoll()
    local container = _G.GroupLootContainer
    if not container then return end

    lootRollHolder = CreateFrame("Frame", "EllesmereUIUnlockExtras_LootRollHolder", UIParent)
    lootRollHolder:SetSize(340, 28)
    lootRollHolder:SetPoint("TOP", UIParent, "TOP", 0, -200)

    -- Apply any saved position
    ApplyPositionToHolder("LootRoll", lootRollHolder)

    -- Prevent Blizzard's managed frame system from repositioning the container
    if _G.UIPARENT_MANAGED_FRAME_POSITIONS then
        _G.UIPARENT_MANAGED_FRAME_POSITIONS.GroupLootContainer = nil
    end

    -- Stop the container from eating mouse events (Blizzard quirk since 8.1)
    container:EnableMouse(false)

    -- Anchor the container to our holder
    local function AnchorLootRoll()
        if not lootRollHolder then return end
        pcall(function()
            container:ClearAllPoints()
            container:SetPoint("TOP", lootRollHolder, "TOP")
        end)
    end

    AnchorLootRoll()
    hooksecurefunc("GroupLootContainer_Update", AnchorLootRoll)
end

local function GetLootRollElement()
    return {
        key   = "LootRoll",
        label = "Loot Roll (Need/Greed)",
        order = 203,
        getFrame = function()
            return lootRollHolder
        end,
        getSize = function()
            local c = _G.GroupLootContainer
            if c and c:IsShown() then
                local w, h = c:GetSize()
                if w and w > 1 then return w, h, 0 end
            end
            return 340, 28, 0
        end,
        savePosition  = function(key, point, relPoint, x, y, scale)
            SavePosition(key, point, relPoint, x, y, scale)
        end,
        loadPosition  = function(key) return LoadPosition(key) end,
        clearPosition = function(key) ClearPosition(key) end,
        applyPosition = function(key)
            ApplyPositionToHolder(key, lootRollHolder)
            -- Re-anchor GroupLootContainer
            local c = _G.GroupLootContainer
            if c and lootRollHolder then
                pcall(function()
                    c:ClearAllPoints()
                    c:SetPoint("TOP", lootRollHolder, "TOP")
                end)
            end
        end,
        isHidden = function()
            return not lootRollHolder
        end,
    }
end

-------------------------------------------------------------------------------
--  5. LFG Ready Popup
--
--  Blizzard frame: LFGDungeonReadyPopup
--  Shows when a dungeon/raid/battleground queue pops.
--  Pattern: Create holder → hook OnShow to reposition after Blizzard places it
-------------------------------------------------------------------------------
local lfgReadyHolder

local function SetupLFGReadyPopup()
    -- Always create the holder (LFGDungeonReadyPopup is load-on-demand and
    -- may not exist at PLAYER_LOGIN).
    lfgReadyHolder = CreateFrame("Frame", "EllesmereUIUnlockExtras_LFGReadyHolder", UIParent)
    lfgReadyHolder:SetSize(230, 195)
    lfgReadyHolder:SetPoint("CENTER", UIParent, "CENTER", 0, 100)

    ApplyPositionToHolder("LFGReadyPopup", lfgReadyHolder)

    local popupHooked = false

    -- Once the popup frame exists, install a SetPoint guard (same pattern as
    -- Vehicle Leave) so Blizzard can never reposition it away from our holder.
    local function AnchorPopup(popup)
        if popupHooked then return end
        popupHooked = true

        hooksecurefunc(popup, "SetPoint", function(self, _, relativeTo)
            if relativeTo ~= lfgReadyHolder then
                pcall(function()
                    self:ClearAllPoints()
                    self:SetPoint("CENTER", lfgReadyHolder, "CENTER")
                end)
            end
        end)

        -- Anchor once right now if already visible
        if popup:IsShown() and not InCombatLockdown() then
            pcall(function()
                popup:ClearAllPoints()
                popup:SetPoint("CENTER", lfgReadyHolder, "CENTER")
            end)
        end
    end

    -- Try immediately (works after /reload while LFG addon is already loaded)
    if _G.LFGDungeonReadyPopup then
        AnchorPopup(_G.LFGDungeonReadyPopup)
    end

    -- Primary hook: catch the popup when Blizzard shows it for the first time
    if StaticPopupSpecial_Show then
        hooksecurefunc("StaticPopupSpecial_Show", function(frame)
            if frame == _G.LFGDungeonReadyPopup then
                AnchorPopup(frame)
            end
        end)
    end

    -- Fallback: watch ADDON_LOADED until the popup frame becomes available
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("ADDON_LOADED")
    watcher:SetScript("OnEvent", function(self)
        if _G.LFGDungeonReadyPopup then
            AnchorPopup(_G.LFGDungeonReadyPopup)
            self:UnregisterEvent("ADDON_LOADED")
        end
    end)
end

local function GetLFGReadyPopupElement()
    return {
        key   = "LFGReadyPopup",
        label = "LFG Ready Popup",
        order = 204,
        getFrame = function()
            return lfgReadyHolder
        end,
        getSize = function()
            local f = _G.LFGDungeonReadyPopup
            if f and f:IsShown() then
                local w, h = f:GetSize()
                if w and w > 1 then return w, h, 0 end
            end
            return 230, 195, 0
        end,
        savePosition  = function(key, point, relPoint, x, y, scale)
            SavePosition(key, point, relPoint, x, y, scale)
        end,
        loadPosition  = function(key) return LoadPosition(key) end,
        clearPosition = function(key) ClearPosition(key) end,
        applyPosition = function(key)
            ApplyPositionToHolder(key, lfgReadyHolder)
        end,
        isHidden = function()
            return not lfgReadyHolder
        end,
    }
end

-------------------------------------------------------------------------------
--  6. Ready Check
--
--  Blizzard frame: ReadyCheckFrame
--  Shows when a group leader initiates a ready check.
--  Pattern: Create holder → hook OnShow to reposition
-------------------------------------------------------------------------------
local readyCheckHolder

local function SetupReadyCheck()
    local frame = _G.ReadyCheckFrame
    if not frame then return end

    readyCheckHolder = CreateFrame("Frame", "EllesmereUIUnlockExtras_ReadyCheckHolder", UIParent)
    readyCheckHolder:SetSize(280, 80)
    readyCheckHolder:SetPoint("TOP", UIParent, "TOP", 0, -200)

    ApplyPositionToHolder("ReadyCheck", readyCheckHolder)

    -- Reposition whenever the ready check appears
    frame:HookScript("OnShow", function(self)
        if InCombatLockdown() or not readyCheckHolder then return end
        C_Timer.After(0, function()
            if InCombatLockdown() or not self:IsShown() then return end
            pcall(function()
                self:ClearAllPoints()
                self:SetPoint("CENTER", readyCheckHolder, "CENTER")
            end)
        end)
    end)
end

local function GetReadyCheckElement()
    return {
        key   = "ReadyCheck",
        label = "Ready Check",
        order = 205,
        getFrame = function()
            return readyCheckHolder
        end,
        getSize = function()
            local f = _G.ReadyCheckFrame
            if f and f:IsShown() then
                local w, h = f:GetSize()
                if w and w > 1 then return w, h, 0 end
            end
            return 280, 80, 0
        end,
        savePosition  = function(key, point, relPoint, x, y, scale)
            SavePosition(key, point, relPoint, x, y, scale)
        end,
        loadPosition  = function(key) return LoadPosition(key) end,
        clearPosition = function(key) ClearPosition(key) end,
        applyPosition = function(key)
            ApplyPositionToHolder(key, readyCheckHolder)
        end,
        isHidden = function()
            return not readyCheckHolder
        end,
    }
end

-------------------------------------------------------------------------------
--  7. Bonus Roll
--
--  Blizzard frame: BonusRollFrame
--  Shows when a bonus roll (coin) is available after a boss kill.
--  Pattern: Create holder → hook OnShow to reposition
-------------------------------------------------------------------------------
local bonusRollHolder

local function SetupBonusRoll()
    local frame = _G.BonusRollFrame
    if not frame then return end

    bonusRollHolder = CreateFrame("Frame", "EllesmereUIUnlockExtras_BonusRollHolder", UIParent)
    bonusRollHolder:SetSize(280, 56)
    bonusRollHolder:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 260)

    ApplyPositionToHolder("BonusRoll", bonusRollHolder)

    -- Reposition whenever the bonus roll frame appears
    frame:HookScript("OnShow", function(self)
        if InCombatLockdown() or not bonusRollHolder then return end
        C_Timer.After(0, function()
            if InCombatLockdown() or not self:IsShown() then return end
            pcall(function()
                self:ClearAllPoints()
                self:SetPoint("CENTER", bonusRollHolder, "CENTER")
            end)
        end)
    end)
end

local function GetBonusRollElement()
    return {
        key   = "BonusRoll",
        label = "Bonus Roll",
        order = 206,
        getFrame = function()
            return bonusRollHolder
        end,
        getSize = function()
            local f = _G.BonusRollFrame
            if f and f:IsShown() then
                local w, h = f:GetSize()
                if w and w > 1 then return w, h, 0 end
            end
            return 280, 56, 0
        end,
        savePosition  = function(key, point, relPoint, x, y, scale)
            SavePosition(key, point, relPoint, x, y, scale)
        end,
        loadPosition  = function(key) return LoadPosition(key) end,
        clearPosition = function(key) ClearPosition(key) end,
        applyPosition = function(key)
            ApplyPositionToHolder(key, bonusRollHolder)
        end,
        isHidden = function()
            return not bonusRollHolder
        end,
    }
end

-------------------------------------------------------------------------------
--  8. Alert Toasts (Loot Won, Loot Upgrade, Achievements, etc.)
--
--  Blizzard frame: AlertFrame
--  Container for all alert toast pop-ups.  Moving AlertFrame moves the
--  entire alert stack including LootWonAlertFrame, LootUpgradeAlertFrame,
--  AchievementAlertFrame, and all other toast types.
--  Pattern: Create holder → remove from managed positions → hook SetPoint
-------------------------------------------------------------------------------
local alertToastsHolder

local function SetupAlertToasts()
    local frame = _G.AlertFrame
    if not frame then return end

    alertToastsHolder = CreateFrame("Frame", "EllesmereUIUnlockExtras_AlertToastsHolder", UIParent)
    alertToastsHolder:SetSize(300, 88)
    alertToastsHolder:SetPoint("TOP", UIParent, "TOP", 0, -50)

    ApplyPositionToHolder("AlertToasts", alertToastsHolder)

    -- Remove from Blizzard's managed frame positioning
    if _G.UIPARENT_MANAGED_FRAME_POSITIONS then
        _G.UIPARENT_MANAGED_FRAME_POSITIONS.AlertFrame = nil
    end

    -- Initial reanchor
    pcall(function()
        frame:ClearAllPoints()
        frame:SetPoint("TOP", alertToastsHolder, "TOP")
    end)

    -- Guard against Blizzard repositioning
    hooksecurefunc(frame, "SetPoint", function(self, _, parent)
        if parent ~= alertToastsHolder then
            pcall(function()
                self:ClearAllPoints()
                self:SetPoint("TOP", alertToastsHolder, "TOP")
            end)
        end
    end)
end

local function GetAlertToastsElement()
    return {
        key   = "AlertToasts",
        label = "Alert Toasts",
        order = 207,
        getFrame = function()
            return alertToastsHolder
        end,
        getSize = function()
            local f = _G.AlertFrame
            if f then
                local w, h = f:GetSize()
                if w and w > 1 then return w, h, 0 end
            end
            return 300, 88, 0
        end,
        savePosition  = function(key, point, relPoint, x, y, scale)
            SavePosition(key, point, relPoint, x, y, scale)
        end,
        loadPosition  = function(key) return LoadPosition(key) end,
        clearPosition = function(key) ClearPosition(key) end,
        applyPosition = function(key)
            ApplyPositionToHolder(key, alertToastsHolder)
            local f = _G.AlertFrame
            if f and alertToastsHolder then
                pcall(function()
                    f:ClearAllPoints()
                    f:SetPoint("TOP", alertToastsHolder, "TOP")
                end)
            end
        end,
        isHidden = function()
            return not alertToastsHolder
        end,
    }
end


-------------------------------------------------------------------------------
--  Registration
-------------------------------------------------------------------------------
local function RegisterAllElements()
    if not EllesmereUI or not EllesmereUI.RegisterUnlockElements then
        return
    end

    local p = db.profile
    local elements = {}

    if p.vehicleLeave.enabled and vehicleHolder then
        elements[#elements + 1] = GetVehicleLeaveElement()
    end

    if p.queueStatus.enabled and queueHolder then
        elements[#elements + 1] = GetQueueStatusElement()
    end

    if p.lootFrame.enabled and lootHolder then
        elements[#elements + 1] = GetLootFrameElement()
    end

    if p.lootRoll.enabled and lootRollHolder then
        elements[#elements + 1] = GetLootRollElement()
    end

    if p.lfgReadyPopup.enabled and lfgReadyHolder then
        elements[#elements + 1] = GetLFGReadyPopupElement()
    end

    if p.readyCheck.enabled and readyCheckHolder then
        elements[#elements + 1] = GetReadyCheckElement()
    end

    if p.bonusRoll.enabled and bonusRollHolder then
        elements[#elements + 1] = GetBonusRollElement()
    end

    if p.alertToasts.enabled and alertToastsHolder then
        elements[#elements + 1] = GetAlertToastsElement()
    end


    if #elements > 0 then
        EllesmereUI:RegisterUnlockElements(elements)
    end
end

--- Re-apply all saved positions from the current profile.
-- Called on login and after a profile switch.
local function ApplyAllPositions()
    if vehicleHolder then
        ApplyPositionToHolder("VehicleLeave", vehicleHolder)
        local btn = _G.MainMenuBarVehicleLeaveButton
        if btn then
            pcall(function()
                btn:ClearAllPoints()
                btn:SetPoint("CENTER", vehicleHolder, "CENTER")
            end)
        end
    end

    if queueHolder then
        ApplyPositionToHolder("QueueStatus", queueHolder)
        local btn = _G.QueueStatusButton
        if btn then
            pcall(function()
                btn:ClearAllPoints()
                btn:SetPoint("CENTER", queueHolder, "CENTER")
            end)
        end
    end

    if lootHolder then
        ApplyPositionToHolder("LootFrame", lootHolder)
    end

    if lootRollHolder then
        ApplyPositionToHolder("LootRoll", lootRollHolder)
        local c = _G.GroupLootContainer
        if c then
            pcall(function()
                c:ClearAllPoints()
                c:SetPoint("TOP", lootRollHolder, "TOP")
            end)
        end
    end

    if lfgReadyHolder then
        ApplyPositionToHolder("LFGReadyPopup", lfgReadyHolder)
    end

    if readyCheckHolder then
        ApplyPositionToHolder("ReadyCheck", readyCheckHolder)
    end

    if bonusRollHolder then
        ApplyPositionToHolder("BonusRoll", bonusRollHolder)
    end

    if alertToastsHolder then
        ApplyPositionToHolder("AlertToasts", alertToastsHolder)
        local f = _G.AlertFrame
        if f then
            pcall(function()
                f:ClearAllPoints()
                f:SetPoint("TOP", alertToastsHolder, "TOP")
            end)
        end
    end

end

-------------------------------------------------------------------------------
--  Lifecycle (EUILite.NewAddon pattern)
-------------------------------------------------------------------------------

--- OnInitialize: fires on ADDON_LOADED (SavedVariables available)
function EUE:OnInitialize()
    db = E.Lite.NewDB("EllesmereUIUnlockExtrasDB", defaults, true)
    ns.db = db
end

--- OnEnable: fires on PLAYER_LOGIN (game data available)
function EUE:OnEnable()
    local p = db.profile

    -- Set up holder frames (Blizzard frames exist at PLAYER_LOGIN)
    if p.vehicleLeave.enabled then SetupVehicleLeave() end
    if p.queueStatus.enabled  then SetupQueueStatus()  end
    if p.lootFrame.enabled    then SetupLootFrame()     end
    if p.lootRoll.enabled     then SetupLootRoll()      end
    if p.lfgReadyPopup.enabled then SetupLFGReadyPopup() end
    if p.readyCheck.enabled    then SetupReadyCheck()     end
    if p.bonusRoll.enabled     then SetupBonusRoll()      end
    if p.alertToasts.enabled   then SetupAlertToasts()    end


    -- Register with EllesmereUI's unlock system after a short delay
    -- to ensure EllesmereUI is fully loaded.
    C_Timer.After(0.5, RegisterAllElements)

    -- Re-register when EllesmereUI deferred init completes (Unlock Mode
    -- wipes and rebuilds its internal order list).
    if E.RegisterOnShow then
        E:RegisterOnShow(function()
            C_Timer.After(0, RegisterAllElements)
        end)
    end
end
