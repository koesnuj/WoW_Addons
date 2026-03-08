------------------------------------------------------------------------
-- SocialInfo – Talent Module
-- Shows current spec icon + spec name + active talent loadout name
------------------------------------------------------------------------
local addonName, ns = ...
local mod = {}

function mod:Init()
    self.row = ns:CreateRow("talent",
        nil, -- icon set dynamically per spec
        nil,
        function()
            if TogglePlayerSpellsFrame then
                pcall(TogglePlayerSpellsFrame)
            end
        end
    )

    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_TALENT_UPDATE")
    f:RegisterEvent("ACTIVE_COMBAT_CONFIG_CHANGED")
    f:RegisterEvent("TRAIT_CONFIG_UPDATED")
    f:RegisterEvent("TRAIT_CONFIG_DELETED")
    f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    f:RegisterEvent("SELECTED_LOADOUT_CHANGED")
    f:SetScript("OnEvent", function()
        C_Timer.After(0.2, function() mod:Update() end)
    end)
end

function mod:Update()
    local row = self.row
    if not row then return end

    local specIndex = GetSpecialization()
    if not specIndex then
        row.text:SetText("|cff888888전문화 없음|r")
        return
    end

    local _, specName, _, specIcon = GetSpecializationInfo(specIndex)
    row.icon:SetTexture(specIcon)

    -- Saved loadout name (the dropdown selection, e.g. "111")
    local loadoutName = ""
    local specID = GetSpecializationInfo(specIndex)
    if specID and C_ClassTalents.GetLastSelectedSavedConfigID then
        local savedConfigID = C_ClassTalents.GetLastSelectedSavedConfigID(specID)
        if savedConfigID then
            local info = C_Traits.GetConfigInfo(savedConfigID)
            if info and info.name and info.name ~= "" then
                loadoutName = info.name
            end
        end
    end

    if loadoutName ~= "" then
        row.text:SetText(string.format("%s |cffaaaaaa·|r |cffffcc00%s|r", specName or "", loadoutName))
    else
        row.text:SetText(specName or "")
    end
end

ns:RegisterModule("talent", mod)
