----------------------------------------------------------------------
--  QuickLoot  –  Trainer auto-advance module
--
--  After learning a recipe from a trainer NPC:
--    1. Hides already-learned ("used") entries from the list
--    2. Auto-selects the next available (learnable) recipe
--    3. Scrolls the list so that recipe is visible
--
--  Uses Blizzard's own ClassTrainer_SelectNearestLearnableSkill()
--  which already exists but is only called when the trainer window
--  first opens — not after each purchase.
----------------------------------------------------------------------
local ADDON_NAME, NS = ...

----------------------------------------------------------------------
--  Hook BuyTrainerService
----------------------------------------------------------------------
local hooked = false

local function HookTrainer()
    if hooked then return end
    hooked = true

    hooksecurefunc("BuyTrainerService", function(index)
        local db = NS.db or NS.defaults
        if not db.trainerEnabled then return end

        -- 1. Hide already-learned entries so they disappear from the list
        if db.trainerHideUsed then
            if GetTrainerServiceTypeFilter and SetTrainerServiceTypeFilter then
                if GetTrainerServiceTypeFilter("used") then
                    SetTrainerServiceTypeFilter("used", false)
                end
            end
        end

        -- 2. After TRAINER_UPDATE fires (which refreshes the list),
        --    auto-select the next available recipe.
        --    Small delay lets the event propagate and the list rebuild.
        C_Timer.After(0.15, function()
            if ClassTrainer_SelectNearestLearnableSkill then
                ClassTrainer_SelectNearestLearnableSkill()
            end
        end)
    end)
end

----------------------------------------------------------------------
--  Wait for Blizzard_TrainerUI to load (it's a load-on-demand addon)
----------------------------------------------------------------------
local waitFrame = CreateFrame("Frame")
waitFrame:RegisterEvent("ADDON_LOADED")
waitFrame:SetScript("OnEvent", function(self, event, addon)
    if addon == "Blizzard_TrainerUI" then
        self:UnregisterEvent("ADDON_LOADED")
        HookTrainer()
    end
end)

-- In case it's already loaded (e.g. user /reload while trainer is open)
if IsAddOnLoaded and IsAddOnLoaded("Blizzard_TrainerUI") then
    HookTrainer()
elseif C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_TrainerUI") then
    HookTrainer()
end
