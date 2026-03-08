------------------------------------------------------------------------
-- SocialInfo – Core
-- Addon namespace, SavedVariables, module registry, slash commands
------------------------------------------------------------------------
local addonName, ns = ...

ns.modules     = {}
ns.moduleOrder = {}

------------------------------------------------------------------------
-- Module API
------------------------------------------------------------------------
function ns:RegisterModule(key, mod)
    ns.modules[key] = mod
    ns.moduleOrder[#ns.moduleOrder + 1] = key
end

function ns:UpdateAll()
    for _, key in ipairs(ns.moduleOrder) do
        local mod = ns.modules[key]
        if mod and mod.Update then
            pcall(mod.Update, mod)
        end
    end
end

------------------------------------------------------------------------
-- Initialisation
------------------------------------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")

loader:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= addonName then return end

        SocialInfoDB = SocialInfoDB or {}
        ns.db = SocialInfoDB

        if ns.db.locked == nil then ns.db.locked = false end

        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_ENTERING_WORLD" then
        ns:CreatePanel()

        for _, key in ipairs(ns.moduleOrder) do
            local mod = ns.modules[key]
            if mod and mod.Init then
                pcall(mod.Init, mod)
            end
        end

        C_Timer.After(1, function() ns:UpdateAll() end)
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end)

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------
SLASH_SOCIALINFO1 = "/sinfo"
SLASH_SOCIALINFO2 = "/socialinfo"

SlashCmdList["SOCIALINFO"] = function(msg)
    msg = (msg or ""):trim():lower()

    if msg == "lock" then
        ns.db.locked = true
        if ns.panel then ns:UpdateLock() end
        print("|cff00ccffSocialInfo:|r Locked.")

    elseif msg == "unlock" then
        ns.db.locked = false
        if ns.panel then ns:UpdateLock() end
        print("|cff00ccffSocialInfo:|r Unlocked – drag to move.")

    elseif msg == "toggle" or msg == "" then
        if ns.panel then
            ns.panel:SetShown(not ns.panel:IsShown())
        end

    elseif msg == "reset" then
        ns.db.point = nil
        ns.db.scale = 1
        if ns.panel then
            ns.panel:ClearAllPoints()
            ns.panel:SetPoint("CENTER")
            ns.panel:SetScale(1)
        end
        print("|cff00ccffSocialInfo:|r Position & scale reset.")

    elseif msg:match("^scale") then
        local val = tonumber(msg:match("scale%s+(%S+)"))
        if val and val >= 0.5 and val <= 2.0 then
            ns.db.scale = val
            if ns.panel then ns.panel:SetScale(val) end
            print(string.format("|cff00ccffSocialInfo:|r Scale = %.0f%%", val * 100))
        else
            print("|cff00ccffSocialInfo:|r /sinfo scale <0.5~2.0>")
        end

    else
        print("|cff00ccffSocialInfo|r commands:")
        print("  /sinfo \226\128\148 Toggle panel")
        print("  /sinfo lock \226\128\148 Lock position")
        print("  /sinfo unlock \226\128\148 Unlock (drag to move)")
        print("  /sinfo scale <0.5~2.0> \226\128\148 Set scale")
        print("  /sinfo reset \226\128\148 Reset position & scale")
    end
end
