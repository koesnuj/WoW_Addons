------------------------------------------------------------------------
-- SocialInfo – Talent Module
-- Shows current spec icon + spec name + active talent loadout name
-- Right-click: change loot specialization
------------------------------------------------------------------------
local addonName, ns = ...
local mod = {}

------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------
function mod:Init()
    self.row = ns:CreateRow("talent",
        nil, -- icon set dynamically per spec
        function(tooltip) mod:OnTooltip(tooltip) end,
        function(cell, button) mod:OnClick(button) end
    )

    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_TALENT_UPDATE")
    f:RegisterEvent("ACTIVE_COMBAT_CONFIG_CHANGED")
    f:RegisterEvent("TRAIT_CONFIG_UPDATED")
    f:RegisterEvent("TRAIT_CONFIG_DELETED")
    f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    f:RegisterEvent("SELECTED_LOADOUT_CHANGED")
    f:RegisterEvent("PLAYER_LOOT_SPEC_UPDATED")
    f:SetScript("OnEvent", function()
        C_Timer.After(0.2, function() mod:Update() end)
    end)
end

------------------------------------------------------------------------
-- Click handler: Left = talent frame, Right = loot spec menu
------------------------------------------------------------------------
function mod:OnClick(button)
    if button == "RightButton" then
        self:ShowLootSpecMenu()
    else
        if TogglePlayerSpellsFrame then
            pcall(TogglePlayerSpellsFrame)
        end
    end
end

------------------------------------------------------------------------
-- Tooltip: show current spec + loot specialization
------------------------------------------------------------------------
function mod:OnTooltip(tooltip)
    tooltip:AddLine("전문화", 1, 1, 1)
    tooltip:AddLine(" ")

    local specIndex = GetSpecialization()
    if specIndex then
        local _, specName, _, specIcon = GetSpecializationInfo(specIndex)
        tooltip:AddDoubleLine("현재 전문화:", specName or "?", 0.6, 0.6, 0.6, 1, 1, 1)
    end

    local lootSpecID = GetLootSpecialization()
    if lootSpecID == 0 then
        tooltip:AddDoubleLine("전리품 전문화:", "현재 전문화", 0.6, 0.6, 0.6, 0.3, 1, 0.3)
    else
        local _, lootName = GetSpecializationInfoByID(lootSpecID)
        tooltip:AddDoubleLine("전리품 전문화:", lootName or "?", 0.6, 0.6, 0.6, 1, 0.82, 0)
    end

    tooltip:AddLine(" ")
    tooltip:AddLine("좌클릭: 특성 창", 0.5, 0.5, 0.5)
    tooltip:AddLine("우클릭: 전리품 전문화 변경", 0.5, 0.5, 0.5)
end

------------------------------------------------------------------------
-- Right-click context menu: loot specialization picker
------------------------------------------------------------------------
function mod:ShowLootSpecMenu()
    local currentLootSpec = GetLootSpecialization()
    local numSpecs = GetNumSpecializations()
    if not numSpecs or numSpecs == 0 then return end

    MenuUtil.CreateContextMenu(self.row, function(owner, root)
        root:CreateTitle("전리품 획득 전문화")

        -- Option: "Current Spec" (lootSpecID = 0)
        local specIndex = GetSpecialization()
        local _, curSpecName, _, curSpecIcon = GetSpecializationInfo(specIndex)
        root:CreateRadio(
            string.format("|T%s:14:14:0:0:64:64:4:60:4:60|t  현재 전문화 |cffaaaaaa(%s)|r", curSpecIcon or "", curSpecName or ""),
            function() return currentLootSpec == 0 end,
            function()
                SetLootSpecialization(0)
                C_Timer.After(0.1, function() mod:Update() end)
            end
        )

        root:CreateDivider()

        -- One radio per spec
        for i = 1, numSpecs do
            local specID, name, _, icon = GetSpecializationInfo(i)
            root:CreateRadio(
                string.format("|T%s:14:14:0:0:64:64:4:60:4:60|t  %s", icon or "", name or ""),
                function() return currentLootSpec == specID end,
                function()
                    SetLootSpecialization(specID)
                    C_Timer.After(0.1, function() mod:Update() end)
                end
            )
        end
    end)
end

------------------------------------------------------------------------
-- Update display
------------------------------------------------------------------------
function mod:Update()
    local row = self.row
    if not row then return end

    local specIndex = GetSpecialization()
    if not specIndex then
        row.text:SetText("|cff888888전문화 없음|r")
        return
    end

    local specID, specName, _, specIcon = GetSpecializationInfo(specIndex)
    row.icon:SetTexture(specIcon)

    -- Saved loadout name
    local loadoutName = ""
    if specID and C_ClassTalents.GetLastSelectedSavedConfigID then
        local savedConfigID = C_ClassTalents.GetLastSelectedSavedConfigID(specID)
        if savedConfigID then
            local info = C_Traits.GetConfigInfo(savedConfigID)
            if info and info.name and info.name ~= "" then
                loadoutName = info.name
            end
        end
    end

    -- Loot spec indicator (only when different from current)
    local lootTag = ""
    local lootSpecID = GetLootSpecialization()
    if lootSpecID ~= 0 and lootSpecID ~= specID then
        local _, lootName = GetSpecializationInfoByID(lootSpecID)
        if lootName then
            lootTag = string.format(" |cffff8800[%s]|r", lootName)
        end
    end

    if loadoutName ~= "" then
        row.text:SetText(string.format("%s |cffaaaaaa·|r |cffffcc00%s|r%s", specName or "", loadoutName, lootTag))
    else
        row.text:SetText(string.format("%s%s", specName or "", lootTag))
    end
end

ns:RegisterModule("talent", mod)
