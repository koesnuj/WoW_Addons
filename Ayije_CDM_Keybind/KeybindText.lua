-- Core/KeybindText.lua - Keybind Text Overlay for Cooldown Icons
-- Shows the keyboard shortcut (e.g. "1", "S-Q") on cooldown/tracker icon frames

local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local CDM_C = CDM.CONST
local GetFrameData = CDM.GetFrameData

local VIEWERS = CDM_C.VIEWERS

-- =========================================================================
--  ACTION BAR DEFINITIONS (Bars 1-15, TWW compatible)
-- =========================================================================

-- Each entry maps a bar's button frame name prefix to its binding command prefix.
-- The .bar field names the parent bar frame; when it is shown the bar is "active".
-- Bar 1 has no .bar (always active). Bars that don't exist are safely skipped.
local BAR_DEFS = {
    { frame = "ActionButton",              bind = "ACTIONBUTTON" },                                          -- Bar 1  (Main, always active)
    { frame = "MultiBarBottomLeftButton",  bind = "MULTIACTIONBAR1BUTTON",     bar = "MultiBarBottomLeft" },  -- Bar 2  (Bottom Left)
    { frame = "MultiBarBottomRightButton", bind = "MULTIACTIONBAR2BUTTON",     bar = "MultiBarBottomRight" }, -- Bar 3  (Bottom Right)
    { frame = "MultiBarRightButton",       bind = "MULTIACTIONBAR3BUTTON",     bar = "MultiBarRight" },       -- Bar 4  (Right 1)
    { frame = "MultiBarLeftButton",        bind = "MULTIACTIONBAR4BUTTON",     bar = "MultiBarLeft" },        -- Bar 5  (Right 2)
    { frame = "MultiBar5Button",           bind = "MULTIACTIONBAR5BUTTON",     bar = "MultiBar5" },           -- Bar 6
    { frame = "MultiBar6Button",           bind = "MULTIACTIONBAR6BUTTON",     bar = "MultiBar6" },           -- Bar 7
    { frame = "MultiBar7Button",           bind = "MULTIACTIONBAR7BUTTON",     bar = "MultiBar7" },           -- Bar 8
    { frame = "MultiBar8Button",           bind = "MULTIACTIONBAR8BUTTON",     bar = "MultiBar8" },           -- Bar 9  (TWW)
    { frame = "MultiBar9Button",           bind = "MULTIACTIONBAR9BUTTON",     bar = "MultiBar9" },           -- Bar 10 (TWW)
    { frame = "MultiBar10Button",          bind = "MULTIACTIONBAR10BUTTON",    bar = "MultiBar10" },          -- Bar 11 (TWW)
    { frame = "MultiBar11Button",          bind = "MULTIACTIONBAR11BUTTON",    bar = "MultiBar11" },          -- Bar 12 (TWW)
    { frame = "MultiBar12Button",          bind = "MULTIACTIONBAR12BUTTON",    bar = "MultiBar12" },          -- Bar 13 (TWW)
    { frame = "MultiBar13Button",          bind = "MULTIACTIONBAR13BUTTON",    bar = "MultiBar13" },          -- Bar 14 (TWW)
    { frame = "MultiBar14Button",          bind = "MULTIACTIONBAR14BUTTON",    bar = "MultiBar14" },          -- Bar 15 (TWW)
}

-- Check whether a bar is active (enabled by the player).
-- Bar 1 has no .bar field and is always active; other bars are active when
-- their parent bar frame exists and is shown (reflects Edit Mode / settings).
local function IsBarActive(def)
    if not def.bar then return true end
    local barFrame = _G[def.bar]
    return barFrame and barFrame:IsShown() or false
end

-- =========================================================================
--  KEYBIND TEXT ABBREVIATION
-- =========================================================================

-- Abbreviate modifier keys for compact display
local function AbbreviateKeybind(keyText)
    if not keyText or keyText == "" then return nil end

    local text = keyText
    text = text:gsub("SHIFT%-", "S-")
    text = text:gsub("CTRL%-", "C-")
    text = text:gsub("ALT%-", "A-")
    text = text:gsub("NUMPAD", "N")
    text = text:gsub("BUTTON", "M")
    text = text:gsub("MOUSEWHEELUP", "WU")
    text = text:gsub("MOUSEWHEELDOWN", "WD")

    return text
end

-- =========================================================================
--  SPELL → KEYBIND LOOKUP (frame-based, active bars only)
-- =========================================================================

-- Note: GetEffectiveSpellID (TrackerUtils.lua) loads AFTER this file,
-- so we resolve at call time via CDM table, not at load time.
local NormalizeToBase = CDM.NormalizeToBase  -- SpellUtils.lua loads before us

-- Collect all spell ID variants for matching (original, override, base, base-override)
local function CollectSpellVariants(spellID)
    local variants = {}
    variants[spellID] = true

    local effectiveFn = CDM.GetEffectiveSpellID

    -- Override of the original spell (e.g. talent-swapped ability)
    if effectiveFn then
        local eid = effectiveFn(spellID)
        if eid then variants[eid] = true end
    end

    -- Base spell (walk override chain downward)
    if NormalizeToBase then
        local baseID = NormalizeToBase(spellID)
        if baseID then
            variants[baseID] = true
            -- Override of the base spell
            if effectiveFn then
                local beid = effectiveFn(baseID)
                if beid then variants[beid] = true end
            end
        end
    end

    -- Reverse lookup: if spellID is itself an override, find what it overrides
    -- This catches cases where the action bar shows the overridden version
    if C_Spell and C_Spell.GetBaseSpell then
        local directBase = C_Spell.GetBaseSpell(spellID)
        if directBase and directBase ~= spellID and CDM.IsSafeNumber(directBase) and directBase > 0 then
            variants[directBase] = true
            if effectiveFn then
                local dbeid = effectiveFn(directBase)
                if dbeid then variants[dbeid] = true end
            end
        end
    end

    return variants
end

-- Get the action slot from a button frame (safe for all bar types)
-- Prefers CalculateAction() which reads the live action bar page,
-- ensuring correct slot after druid form / stance changes.
local function GetButtonAction(btnFrame)
    -- CalculateAction accounts for page changes (form/stance/vehicle)
    if btnFrame.CalculateAction then
        local ok, action = pcall(btnFrame.CalculateAction, btnFrame)
        if ok and action then return action end
    end
    local action = btnFrame.action
    if action then return action end
    -- Fallback: some TWW bars may store action as a frame attribute
    if btnFrame.GetAttribute then
        action = btnFrame:GetAttribute("action")
        if action then return tonumber(action) end
    end
    return nil
end

-- Map an action slot to its keybind WITHOUT depending on frame .action state.
-- Multi-bars (2-15) have fixed .action — check those first, but only active bars.
-- Bar 1 shares ACTIONBUTTON keybinds across all pages/forms/stances,
-- so we derive the button index arithmetically: ((slot-1) % 12) + 1.
local function SlotToKeybind(slot)
    if issecretvalue(slot) then return nil end
    -- 1) Multi-bars: fixed action slots, only from active bars
    for defIdx = 2, #BAR_DEFS do
        local def = BAR_DEFS[defIdx]
        if IsBarActive(def) then
            for i = 1, 12 do
                local btnFrame = _G[def.frame .. i]
                if btnFrame and btnFrame.action == slot then
                    local key = GetBindingKey(def.bind .. i)
                    if key then return AbbreviateKeybind(key) end
                end
            end
        end
    end
    -- 2) Bar 1 (any page / form / stance): all pages share ACTIONBUTTON keybinds
    local buttonIndex = ((slot - 1) % 12) + 1
    local key = GetBindingKey("ACTIONBUTTON" .. buttonIndex)
    if key then return AbbreviateKeybind(key) end
    return nil
end

-- Search active action bar button frames for a keybind matching the spell
local function GetKeybindForSpell(spellID)
    if not spellID then return nil end

    -- WoW 12.0: secret spell IDs cannot be used as table keys or compared.
    -- Skip variant-based lookup and go straight to C_ActionBar fallback.
    if issecretvalue(spellID) then
        if C_ActionBar and C_ActionBar.FindSpellActionButtons then
            local ok, slots = pcall(C_ActionBar.FindSpellActionButtons, spellID)
            if ok and slots then
                for _, slot in ipairs(slots) do
                    local kb = SlotToKeybind(slot)
                    if kb then return kb end
                end
            end
        end
        return nil
    end

    local variants = CollectSpellVariants(spellID)

    for _, def in ipairs(BAR_DEFS) do
        if IsBarActive(def) then
            for i = 1, 12 do
                local key = GetBindingKey(def.bind .. i)
                if key then
                    local btnFrame = _G[def.frame .. i]
                    if btnFrame then
                        local action = GetButtonAction(btnFrame)
                        if action and HasAction(action) then
                            local actionType, id, subType = GetActionInfo(action)
                            -- Direct spell match
                            if actionType == "spell" and id and variants[id] then
                                return AbbreviateKeybind(key)
                            end
                            -- Macro: id is the macro index; resolve the actual spell via GetMacroSpell
                            if actionType == "macro" and id and GetMacroSpell then
                                local macroSpellID = GetMacroSpell(id)

                                if macroSpellID and variants[macroSpellID] then
                                    return AbbreviateKeybind(key)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Fallback: C_ActionBar API (frame-state-independent, covers all pages/forms)
    -- SlotToKeybind already filters by active bars.
    if C_ActionBar and C_ActionBar.FindSpellActionButtons then
        for vid, _ in pairs(variants) do
            local ok, slots = pcall(C_ActionBar.FindSpellActionButtons, vid)
            if ok and slots then
                for _, slot in ipairs(slots) do
                    local kb = SlotToKeybind(slot)
                    if kb then return kb end
                end
            end
        end
    end

    return nil
end

-- Search active action bar button frames for a keybind matching an item
local function GetKeybindForItem(itemID)
    if not itemID then return nil end

    for _, def in ipairs(BAR_DEFS) do
        if IsBarActive(def) then
            for i = 1, 12 do
                local key = GetBindingKey(def.bind .. i)
                if key then
                    local btnFrame = _G[def.frame .. i]
                    if btnFrame then
                        local action = GetButtonAction(btnFrame)
                        if action and HasAction(action) then
                            local actionType, id, subType = GetActionInfo(action)
                            if actionType == "item" and id == itemID then
                                return AbbreviateKeybind(key)
                            end
                            -- Macro: id is the macro index; resolve the actual item via GetMacroItem
                            if actionType == "macro" and id and GetMacroItem then
                                local macroItemID
                                local _, itemLink = GetMacroItem(id)
                                if itemLink then
                                    macroItemID = tonumber(itemLink:match("item:(%d+)"))
                                end
                                if macroItemID and macroItemID == itemID then
                                    return AbbreviateKeybind(key)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Fallback: C_ActionBar API (frame-state-independent, covers all pages/forms)
    -- SlotToKeybind already filters by active bars.
    if C_ActionBar and C_ActionBar.FindItemActionButtons then
        local ok, slots = pcall(C_ActionBar.FindItemActionButtons, itemID)
        if ok and slots then
            for _, slot in ipairs(slots) do
                local kb = SlotToKeybind(slot)
                if kb then return kb end
            end
        end
    end

    return nil
end

CDM.GetKeybindForSpell = GetKeybindForSpell

-- =========================================================================
--  FONTSTRING MANAGEMENT
-- =========================================================================

local function GetKeybindConfig()
    local db = CDM.db
    if not db or not db.assistEnabled then return nil end

    local defaults = CDM.defaults or {}
    local function Val(key, fallback)
        if db[key] ~= nil then return db[key] end
        if defaults[key] ~= nil then return defaults[key] end
        return fallback
    end

    return {
        fontSize = Val("assistFontSize", 10),
        color = Val("assistColor", { r = 1, g = 1, b = 1, a = 0.8 }),
        position = Val("assistPosition", "TOPLEFT"),
        offsetX = Val("assistOffsetX", 0),
        offsetY = Val("assistOffsetY", 0),
    }
end

function CDM:ApplyKeybindText(frame, vName)
    if not frame then return end

    local config = GetKeybindConfig()

    if not config then
        -- Feature disabled: hide container if present
        if frame._cdmKBContainer then
            frame._cdmKBContainer:Hide()
        end
        return
    end

    -- Get the spell ID from the frame
    -- Viewer frames: frame.cooldownInfo.spellID
    -- Tracker frames: frame.spellID directly
    local spellID
    local itemID
    local info = frame.cooldownInfo
    if info then
        spellID = info.overrideSpellID or info.spellID
    end
    if not spellID then
        spellID = frame.spellID
    end
    -- Item-based tracker frames (Racials potions/healthstones, Trinkets)
    if not spellID then
        itemID = frame.itemID
    end

    if not spellID and not itemID then
        if frame._cdmKBContainer then
            frame._cdmKBContainer:Hide()
        end
        return
    end

    -- Look up keybind (spell first, then item fallback)
    local keybindText = GetKeybindForSpell(spellID)
    if not keybindText and itemID then
        keybindText = GetKeybindForItem(itemID)
    end

    if not keybindText then
        if frame._cdmKBContainer then
            frame._cdmKBContainer:Hide()
        end
        return
    end

    -- Create container + fontstring on frame (survives weak-table GC)
    if not frame._cdmKBContainer then
        local container = CreateFrame("Frame", nil, frame)
        container:SetAllPoints(frame)
        local fs = container:CreateFontString(nil, "OVERLAY")
        fs:SetDrawLayer("OVERLAY", 7)
        fs:SetShadowOffset(1, -1)
        frame._cdmKBContainer = container
        frame._cdmKBFS = fs
    end

    local container = frame._cdmKBContainer
    local fontStr = frame._cdmKBFS

    container:SetFrameLevel(frame:GetFrameLevel() + 8)
    container:Show()

    -- Style the font string
    local fontPath = CDM_C.GetBaseFontPath and CDM_C.GetBaseFontPath()
    if not fontPath then
        fontPath = "Fonts\\FRIZQT__.TTF"
    end

    local outline = CDM.db and CDM.db.textFontOutline or "OUTLINE"
    if outline == "NONE" then outline = "" end

    fontStr:SetFont(fontPath, CDM_C.GetPixelFontSize(config.fontSize), outline)
    fontStr:SetTextColor(config.color.r, config.color.g, config.color.b, config.color.a or 0.8)
    fontStr:SetIgnoreParentScale(true)
    fontStr:ClearAllPoints()
    fontStr:SetPoint(config.position, frame, config.position, config.offsetX, config.offsetY)
    fontStr:SetText(keybindText)
    fontStr:Show()
end

-- =========================================================================
--  REFRESH ALL KEYBIND TEXTS
-- =========================================================================

function CDM:RefreshAllKeybindTexts()
    -- Wipe override cache so spec/talent changes are reflected
    if CDM.WipeEffectiveIDCache then
        CDM.WipeEffectiveIDCache()
    end
    -- Viewer-based frames (Essential, Utility)
    local viewerNames = { VIEWERS.ESSENTIAL, VIEWERS.UTILITY }
    for _, vName in ipairs(viewerNames) do
        local viewer = _G[vName]
        if viewer and viewer.itemFramePool then
            for frame in viewer.itemFramePool:EnumerateActive() do
                self:ApplyKeybindText(frame, vName)
            end
        end
    end

    -- Tracker-based frames (Defensives, Racials, Trinkets)
    local trackerDefs = {
        { containerName = "CDM_DefensivesContainer", vName = "CDM_Defensives" },
        { containerName = "CDM_RacialsContainer",    vName = "CDM_Racials" },
    }
    for _, def in ipairs(trackerDefs) do
        local container = _G[def.containerName]
        if container and container.GetChildren then
            for _, child in pairs({ container:GetChildren() }) do
                if child and (child.spellID or child.itemID) and child.IsShown and child:IsShown() then
                    self:ApplyKeybindText(child, def.vName)
                end
            end
        end
    end

    -- Trinkets (has dedicated accessor)
    local trinketFrames = CDM.GetTrinketIconFrames and CDM.GetTrinketIconFrames()
    if trinketFrames then
        for _, frame in ipairs(trinketFrames) do
            if frame and frame:IsShown() then
                self:ApplyKeybindText(frame, "CDM_Trinkets")
            end
        end
    end
end
