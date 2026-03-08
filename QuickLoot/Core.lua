----------------------------------------------------------------------
--  QuickLoot  –  Core / shared namespace
--  Loot frame replacement + trainer auto-advance
--  Based on Butsu by Haste (MIT)
----------------------------------------------------------------------
local ADDON_NAME, NS = ...

----------------------------------------------------------------------
--  Default settings
----------------------------------------------------------------------
NS.defaults = {
    -- Loot frame
    lootEnabled     = true,
    iconSize        = 22,
    fontSizeTitle   = 14,
    fontSizeItem    = 12,
    fontSizeCount   = 10,
    frameScale      = 1,
    framePosition   = nil,  -- saved as "point\031parent\031x\031y"

    -- Trainer
    trainerEnabled  = true,
    trainerHideUsed = true,
}

----------------------------------------------------------------------
--  Saved-variable bootstrap
----------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, addon)
    if addon ~= ADDON_NAME then return end
    f:UnregisterEvent("ADDON_LOADED")

    QuickLootDB = QuickLootDB or {}
    NS.db = setmetatable(QuickLootDB, { __index = NS.defaults })
end)
