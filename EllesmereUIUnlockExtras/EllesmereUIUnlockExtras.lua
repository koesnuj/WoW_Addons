-------------------------------------------------------------------------------
--  EllesmereUIUnlockExtras.lua
--  Registers Vehicle Leave, Queue Status, Loot Frame, Loot Roll, and Player
--  Castbar as movable elements in EllesmereUI's Unlock Mode via
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
        playerCastbar = { enabled = true },
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
--  5. Player Castbar (Detached)
--
--  EllesmereUIUnitFrames creates the player castbar as part of the oUF frame.
--  We detach it by re-anchoring the castbar background frame (castbarBg)
--  to our movable holder.  The StatusBar and icon are children of castbarBg
--  so they follow automatically.
--
--  Requires: EllesmereUIUnitFrames (oUF-based player frame)
--  Timing: Must run AFTER oUF frames are fully created (delayed init)
-------------------------------------------------------------------------------
local castbarHolder
local castbarBgRef  -- reference to castbar's parent (the background Frame)

local function SetupPlayerCastbar()
    local playerFrame = _G["EllesmereUIUnitFrames_Player"]
    if not playerFrame or not playerFrame.Castbar then return false end

    local castbar = playerFrame.Castbar
    local cbBg = castbar:GetParent()
    if not cbBg then return false end

    castbarBgRef = cbBg

    -- Read current dimensions from the castbar background
    local w, h = cbBg:GetSize()
    if not w or w < 1 then w = 200 end
    if not h or h < 1 then h = 14 end

    -- Create holder (sized to match castbarBg; icon extends to the left naturally)
    castbarHolder = CreateFrame("Frame", "EllesmereUIUnlockExtras_PlayerCastbarHolder", UIParent)
    castbarHolder:SetSize(w, h)
    castbarHolder:SetPoint("CENTER", UIParent, "CENTER", 0, -200)

    -- Apply any saved position
    ApplyPositionToHolder("PlayerCastbar", castbarHolder)

    -- Detach: re-anchor castbarBg from the unit frame to our holder
    cbBg:ClearAllPoints()
    cbBg:SetPoint("TOPLEFT", castbarHolder, "TOPLEFT", 0, 0)

    -- Guard against EllesmereUIUnitFrames re-anchoring (e.g. settings update)
    hooksecurefunc(cbBg, "SetPoint", function(self, _, parent)
        if parent ~= castbarHolder and castbarHolder then
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", castbarHolder, "TOPLEFT", 0, 0)
        end
    end)

    return true
end

local function GetPlayerCastbarElement()
    return {
        key   = "PlayerCastbar",
        label = "Player Castbar",
        order = 204,
        getFrame = function()
            return castbarHolder
        end,
        getSize = function()
            if castbarBgRef then
                local w, h = castbarBgRef:GetSize()
                if w and w > 1 then return w, h, 0 end
            end
            return 200, 14, 0
        end,
        savePosition  = function(key, point, relPoint, x, y, scale)
            SavePosition(key, point, relPoint, x, y, scale)
        end,
        loadPosition  = function(key) return LoadPosition(key) end,
        clearPosition = function(key) ClearPosition(key) end,
        applyPosition = function(key)
            ApplyPositionToHolder(key, castbarHolder)
            -- Re-anchor castbarBg to holder
            if castbarBgRef and castbarHolder then
                pcall(function()
                    castbarBgRef:ClearAllPoints()
                    castbarBgRef:SetPoint("TOPLEFT", castbarHolder, "TOPLEFT", 0, 0)
                end)
            end
        end,
        isHidden = function()
            return not castbarHolder
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

    if p.playerCastbar.enabled and castbarHolder then
        elements[#elements + 1] = GetPlayerCastbarElement()
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

    if castbarHolder then
        ApplyPositionToHolder("PlayerCastbar", castbarHolder)
        if castbarBgRef then
            pcall(function()
                castbarBgRef:ClearAllPoints()
                castbarBgRef:SetPoint("TOPLEFT", castbarHolder, "TOPLEFT", 0, 0)
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

    -- Player castbar: delayed — oUF frames must be fully created first.
    -- 1.5s to allow EllesmereUICastBarExtras (1.0s) to hook first.
    if p.playerCastbar.enabled then
        C_Timer.After(1.5, function()
            if SetupPlayerCastbar() then
                RegisterAllElements()
            end
        end)
    end

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
