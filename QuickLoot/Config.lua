----------------------------------------------------------------------
--  QuickLoot  –  Config / slash commands
----------------------------------------------------------------------
local ADDON_NAME, NS = ...

----------------------------------------------------------------------
--  Slash command
----------------------------------------------------------------------
SLASH_QUICKLOOT1 = "/quickloot"
SLASH_QUICKLOOT2 = "/ql"

SlashCmdList["QUICKLOOT"] = function(msg)
    local cmd = strtrim(msg):lower()
    local db  = NS.db or NS.defaults

    if cmd == "loot" then
        db.lootEnabled = not db.lootEnabled
        print("|cff00ccffQuickLoot|r: Loot frame " .. (db.lootEnabled and "|cff00ff00enabled|r" or "|cffff0000disabled|r"))
        if not db.lootEnabled and NS.lootFrame then
            NS.lootFrame:Hide()
            -- Re-enable default loot frame on next reload
        end
    elseif cmd == "trainer" then
        db.trainerEnabled = not db.trainerEnabled
        print("|cff00ccffQuickLoot|r: Trainer auto-advance " .. (db.trainerEnabled and "|cff00ff00enabled|r" or "|cffff0000disabled|r"))
    elseif cmd == "hideused" then
        db.trainerHideUsed = not db.trainerHideUsed
        print("|cff00ccffQuickLoot|r: Hide learned recipes " .. (db.trainerHideUsed and "|cff00ff00enabled|r" or "|cffff0000disabled|r"))
    elseif cmd == "scale" then
        print("|cff00ccffQuickLoot|r: Current scale = " .. (db.frameScale or 1) .. ".  Usage: /ql scale <number>")
    elseif cmd:match("^scale%s") then
        local val = tonumber(cmd:match("^scale%s+(.+)"))
        if val and val >= 0.4 and val <= 3 then
            db.frameScale = val
            if NS.lootFrame then NS.lootFrame:SetScale(val) end
            print("|cff00ccffQuickLoot|r: Scale set to " .. val)
        else
            print("|cff00ccffQuickLoot|r: Scale must be between 0.4 and 3")
        end
    elseif cmd == "reset" then
        db.framePosition = nil
        if NS.lootFrame then
            NS.lootFrame:ClearAllPoints()
            NS.lootFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 418, -186)
        end
        print("|cff00ccffQuickLoot|r: Position reset")
    else
        print("|cff00ccffQuickLoot|r commands:")
        print("  /ql |cffffff00loot|r — Toggle loot frame replacement")
        print("  /ql |cffffff00trainer|r — Toggle trainer auto-advance")
        print("  /ql |cffffff00hideused|r — Toggle hide learned recipes")
        print("  /ql |cffffff00scale <n>|r — Set loot frame scale (0.4–3)")
        print("  /ql |cffffff00reset|r — Reset loot frame position")
        print("  Alt+Drag to move the loot frame")
    end
end
