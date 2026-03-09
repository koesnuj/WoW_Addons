-------------------------------------------------------------------------------
--  EllesmereUI_Profiles.lua
--
--  Global profile system: import/export, presets, spec assignment.
--  Handles serialization (LibDeflate + custom serializer) and profile
--  management across all EllesmereUI addons.
--
--  Load order (via TOC):
--    1. Libs/LibDeflate.lua
--    2. EllesmereUI_Lite.lua
--    3. EllesmereUI.lua
--    4. EllesmereUI_Widgets.lua
--    5. EllesmereUI_Presets.lua
--    6. EllesmereUI_Profiles.lua  -- THIS FILE
-------------------------------------------------------------------------------

local EllesmereUI = _G.EllesmereUI

-------------------------------------------------------------------------------
--  LibDeflate reference (loaded before us via TOC)
-------------------------------------------------------------------------------
local LibDeflate = _G.LibDeflate

-------------------------------------------------------------------------------
--  Addon registry: maps addon folder names to their DB accessor info.
--  Each entry: { svName, globalName, isFlat }
--    svName    = SavedVariables name (e.g. "EllesmereUINameplatesDB")
--    globalName = global variable holding the AceDB object (e.g. "_ECME_AceDB")
--    isFlat    = true if the DB is a flat table (Nameplates), false if AceDB
--
--  Order matters for UI display.
-------------------------------------------------------------------------------
local ADDON_DB_MAP = {
    { folder = "EllesmereUINameplates",        display = "Nameplates",         svName = "EllesmereUINameplatesDB",        globalName = nil,            isFlat = true  },
    { folder = "EllesmereUIActionBars",        display = "Action Bars",        svName = "EllesmereUIActionBarsDB",        globalName = nil,            isFlat = false },
    { folder = "EllesmereUIUnitFrames",        display = "Unit Frames",        svName = "EllesmereUIUnitFramesDB",        globalName = nil,            isFlat = false },
    { folder = "EllesmereUICooldownManager",   display = "Cooldown Manager",   svName = "EllesmereUICooldownManagerDB",   globalName = "_ECME_AceDB",  isFlat = false },
    { folder = "EllesmereUIResourceBars",      display = "Resource Bars",      svName = "EllesmereUIResourceBarsDB",      globalName = "_ERB_AceDB",   isFlat = false },
    { folder = "EllesmereUIAuraBuffReminders", display = "AuraBuff Reminders", svName = "EllesmereUIAuraBuffRemindersDB", globalName = "_EABR_AceDB",  isFlat = false },
    { folder = "EllesmereUICursor",            display = "Cursor",             svName = "EllesmereUICursorDB",            globalName = "_ECL_AceDB",   isFlat = false },
}
EllesmereUI._ADDON_DB_MAP = ADDON_DB_MAP

-------------------------------------------------------------------------------
--  Serializer: Lua table <-> string (no AceSerializer dependency)
--  Handles: string, number, boolean, nil, table (nested), color tables
-------------------------------------------------------------------------------
local Serializer = {}

local function SerializeValue(v, parts)
    local t = type(v)
    if t == "string" then
        parts[#parts + 1] = "s"
        -- Length-prefixed to avoid delimiter issues
        parts[#parts + 1] = #v
        parts[#parts + 1] = ":"
        parts[#parts + 1] = v
    elseif t == "number" then
        parts[#parts + 1] = "n"
        parts[#parts + 1] = tostring(v)
        parts[#parts + 1] = ";"
    elseif t == "boolean" then
        parts[#parts + 1] = v and "T" or "F"
    elseif t == "nil" then
        parts[#parts + 1] = "N"
    elseif t == "table" then
        parts[#parts + 1] = "{"
        -- Serialize array part first (integer keys 1..n)
        local n = #v
        for i = 1, n do
            SerializeValue(v[i], parts)
        end
        -- Then hash part (non-integer keys, or integer keys > n)
        for k, val in pairs(v) do
            local kt = type(k)
            if kt == "number" and k >= 1 and k <= n and k == math.floor(k) then
                -- Already serialized in array part
            else
                parts[#parts + 1] = "K"
                SerializeValue(k, parts)
                SerializeValue(val, parts)
            end
        end
        parts[#parts + 1] = "}"
    end
end

function Serializer.Serialize(tbl)
    local parts = {}
    SerializeValue(tbl, parts)
    return table.concat(parts)
end

-- Deserializer
local function DeserializeValue(str, pos)
    local tag = str:sub(pos, pos)
    if tag == "s" then
        -- Find the colon after the length
        local colonPos = str:find(":", pos + 1, true)
        if not colonPos then return nil, pos end
        local len = tonumber(str:sub(pos + 1, colonPos - 1))
        if not len then return nil, pos end
        local val = str:sub(colonPos + 1, colonPos + len)
        return val, colonPos + len + 1
    elseif tag == "n" then
        local semi = str:find(";", pos + 1, true)
        if not semi then return nil, pos end
        return tonumber(str:sub(pos + 1, semi - 1)), semi + 1
    elseif tag == "T" then
        return true, pos + 1
    elseif tag == "F" then
        return false, pos + 1
    elseif tag == "N" then
        return nil, pos + 1
    elseif tag == "{" then
        local tbl = {}
        local idx = 1
        local p = pos + 1
        while p <= #str do
            local c = str:sub(p, p)
            if c == "}" then
                return tbl, p + 1
            elseif c == "K" then
                -- Key-value pair
                local key, val
                key, p = DeserializeValue(str, p + 1)
                val, p = DeserializeValue(str, p)
                if key ~= nil then
                    tbl[key] = val
                end
            else
                -- Array element
                local val
                val, p = DeserializeValue(str, p)
                tbl[idx] = val
                idx = idx + 1
            end
        end
        return tbl, p
    end
    return nil, pos + 1
end

function Serializer.Deserialize(str)
    if not str or #str == 0 then return nil end
    local val, _ = DeserializeValue(str, 1)
    return val
end

EllesmereUI._Serializer = Serializer

-------------------------------------------------------------------------------
--  Deep copy utility
-------------------------------------------------------------------------------
local function DeepCopy(src)
    if type(src) ~= "table" then return src end
    local copy = {}
    for k, v in pairs(src) do
        copy[k] = DeepCopy(v)
    end
    return copy
end

local function DeepMerge(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" and type(dst[k]) == "table" then
            DeepMerge(dst[k], v)
        else
            dst[k] = DeepCopy(v)
        end
    end
end

EllesmereUI._DeepCopy = DeepCopy

-------------------------------------------------------------------------------
--  Profile DB helpers
--  Profiles are stored in EllesmereUIDB.profiles = { [name] = profileData }
--  profileData = {
--      addons = { [folderName] = <snapshot of that addon's profile table> },
--      fonts  = <snapshot of EllesmereUIDB.fonts>,
--      customColors = <snapshot of EllesmereUIDB.customColors>,
--  }
--  EllesmereUIDB.activeProfile = "Custom"  (name of active profile)
--  EllesmereUIDB.profileOrder  = { "Custom", ... }
--  EllesmereUIDB.specProfiles  = { [specID] = "profileName" }
-------------------------------------------------------------------------------
local function GetProfilesDB()
    if not EllesmereUIDB then EllesmereUIDB = {} end
    if not EllesmereUIDB.profiles then EllesmereUIDB.profiles = {} end
    if not EllesmereUIDB.profileOrder then EllesmereUIDB.profileOrder = {} end
    if not EllesmereUIDB.specProfiles then EllesmereUIDB.specProfiles = {} end
    return EllesmereUIDB
end

--- Check if an addon is loaded
local function IsAddonLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded(name) end
    if _G.IsAddOnLoaded then return _G.IsAddOnLoaded(name) end
    return false
end

--- Get the live profile table for an addon
local function GetAddonProfile(entry)
    if entry.isFlat then
        -- Flat DB (Nameplates): the global IS the profile
        return _G[entry.svName]
    else
        -- AceDB-style: profile lives under .profile
        local aceDB = entry.globalName and _G[entry.globalName]
        if aceDB and aceDB.profile then return aceDB.profile end
        -- Fallback for Lite.NewDB addons: look up the current character's profile
        local raw = _G[entry.svName]
        if raw and raw.profiles then
            -- Determine the profile name for this character
            local profileName = "Default"
            if raw.profileKeys then
                local charKey = UnitName("player") .. " - " .. GetRealmName()
                profileName = raw.profileKeys[charKey] or "Default"
            end
            if raw.profiles[profileName] then
                return raw.profiles[profileName]
            end
        end
        return nil
    end
end

--- Snapshot the current state of all loaded addons into a profile data table
function EllesmereUI.SnapshotAllAddons()
    local data = { addons = {} }
    for _, entry in ipairs(ADDON_DB_MAP) do
        if IsAddonLoaded(entry.folder) then
            local profile = GetAddonProfile(entry)
            if profile then
                data.addons[entry.folder] = DeepCopy(profile)
            end
        end
    end
    -- Include global font and color settings
    data.fonts = DeepCopy(EllesmereUI.GetFontsDB())
    local cc = EllesmereUI.GetCustomColorsDB()
    data.customColors = DeepCopy(cc)
    return data
end

--- Snapshot a single addon's profile
function EllesmereUI.SnapshotAddon(folderName)
    for _, entry in ipairs(ADDON_DB_MAP) do
        if entry.folder == folderName and IsAddonLoaded(folderName) then
            local profile = GetAddonProfile(entry)
            if profile then return DeepCopy(profile) end
        end
    end
    return nil
end

--- Snapshot multiple addons (for multi-addon export)
function EllesmereUI.SnapshotAddons(folderList)
    local data = { addons = {} }
    for _, folderName in ipairs(folderList) do
        for _, entry in ipairs(ADDON_DB_MAP) do
            if entry.folder == folderName and IsAddonLoaded(folderName) then
                local profile = GetAddonProfile(entry)
                if profile then
                    data.addons[folderName] = DeepCopy(profile)
                end
                break
            end
        end
    end
    -- Always include fonts and colors
    data.fonts = DeepCopy(EllesmereUI.GetFontsDB())
    data.customColors = DeepCopy(EllesmereUI.GetCustomColorsDB())
    return data
end

--- Apply a profile data table to all loaded addons
function EllesmereUI.ApplyProfileData(profileData)
    if not profileData or not profileData.addons then return end
    for _, entry in ipairs(ADDON_DB_MAP) do
        local snap = profileData.addons[entry.folder]
        if snap and IsAddonLoaded(entry.folder) then
            local profile = GetAddonProfile(entry)
            if profile then
                if entry.isFlat then
                    -- Flat DB: wipe and copy
                    local db = _G[entry.svName]
                    if db then
                        -- Preserve preset/spec keys that are internal
                        for k in pairs(db) do
                            if not k:match("^_") then
                                db[k] = nil
                            end
                        end
                        for k, v in pairs(snap) do
                            if not k:match("^_") then
                                db[k] = DeepCopy(v)
                            end
                        end
                    end
                else
                    -- AceDB: wipe profile and copy
                    for k in pairs(profile) do profile[k] = nil end
                    for k, v in pairs(snap) do
                        profile[k] = DeepCopy(v)
                    end
                end
            end
        end
    end
    -- Apply fonts and colors
    if profileData.fonts then
        local fontsDB = EllesmereUI.GetFontsDB()
        for k in pairs(fontsDB) do fontsDB[k] = nil end
        for k, v in pairs(profileData.fonts) do
            fontsDB[k] = DeepCopy(v)
        end
    end
    if profileData.customColors then
        local colorsDB = EllesmereUI.GetCustomColorsDB()
        for k in pairs(colorsDB) do colorsDB[k] = nil end
        for k, v in pairs(profileData.customColors) do
            colorsDB[k] = DeepCopy(v)
        end
    end
end

--- Apply a partial profile (specific addons only) by merging into active
function EllesmereUI.ApplyPartialProfile(profileData)
    if not profileData or not profileData.addons then return end
    for folderName, snap in pairs(profileData.addons) do
        for _, entry in ipairs(ADDON_DB_MAP) do
            if entry.folder == folderName and IsAddonLoaded(folderName) then
                local profile = GetAddonProfile(entry)
                if profile then
                    if entry.isFlat then
                        local db = _G[entry.svName]
                        if db then
                            for k, v in pairs(snap) do
                                if not k:match("^_") then
                                    db[k] = DeepCopy(v)
                                end
                            end
                        end
                    else
                        for k, v in pairs(snap) do
                            profile[k] = DeepCopy(v)
                        end
                    end
                end
                break
            end
        end
    end
    -- Always apply fonts and colors if present
    if profileData.fonts then
        local fontsDB = EllesmereUI.GetFontsDB()
        for k, v in pairs(profileData.fonts) do
            fontsDB[k] = DeepCopy(v)
        end
    end
    if profileData.customColors then
        local colorsDB = EllesmereUI.GetCustomColorsDB()
        for k, v in pairs(profileData.customColors) do
            colorsDB[k] = DeepCopy(v)
        end
    end
end

-------------------------------------------------------------------------------
--  Export / Import
--  Format: !EUI_<base64 encoded compressed serialized data>
--  The data table contains:
--    { version = 1, type = "full"|"partial", data = profileData }
-------------------------------------------------------------------------------
local EXPORT_PREFIX = "!EUI_"

function EllesmereUI.ExportProfile(profileName)
    local db = GetProfilesDB()
    local profileData = db.profiles[profileName]
    if not profileData then return nil end
    local payload = { version = 1, type = "full", data = profileData }
    local serialized = Serializer.Serialize(payload)
    if not LibDeflate then return nil end
    local compressed = LibDeflate:CompressDeflate(serialized)
    local encoded = LibDeflate:EncodeForPrint(compressed)
    return EXPORT_PREFIX .. encoded
end

function EllesmereUI.ExportAddons(folderList)
    local profileData = EllesmereUI.SnapshotAddons(folderList)
    local payload = { version = 1, type = "partial", data = profileData }
    local serialized = Serializer.Serialize(payload)
    if not LibDeflate then return nil end
    local compressed = LibDeflate:CompressDeflate(serialized)
    local encoded = LibDeflate:EncodeForPrint(compressed)
    return EXPORT_PREFIX .. encoded
end

function EllesmereUI.ExportCurrentProfile()
    local profileData = EllesmereUI.SnapshotAllAddons()
    local payload = { version = 1, type = "full", data = profileData }
    local serialized = Serializer.Serialize(payload)
    if not LibDeflate then return nil end
    local compressed = LibDeflate:CompressDeflate(serialized)
    local encoded = LibDeflate:EncodeForPrint(compressed)
    return EXPORT_PREFIX .. encoded
end

function EllesmereUI.DecodeImportString(importStr)
    if not importStr or #importStr < #EXPORT_PREFIX then return nil, "Invalid string" end
    if importStr:sub(1, #EXPORT_PREFIX) ~= EXPORT_PREFIX then
        return nil, "Not a valid EllesmereUI profile string"
    end
    if not LibDeflate then return nil, "LibDeflate not available" end
    local encoded = importStr:sub(#EXPORT_PREFIX + 1)
    local decoded = LibDeflate:DecodeForPrint(encoded)
    if not decoded then return nil, "Failed to decode string" end
    local decompressed = LibDeflate:DecompressDeflate(decoded)
    if not decompressed then return nil, "Failed to decompress data" end
    local payload = Serializer.Deserialize(decompressed)
    if not payload or type(payload) ~= "table" then
        return nil, "Failed to deserialize data"
    end
    if payload.version ~= 1 then
        return nil, "Unsupported profile version"
    end
    return payload, nil
end

--- Import a profile string. Returns: success, errorMsg
--- The caller must provide a name for the new profile.
function EllesmereUI.ImportProfile(importStr, profileName)
    local payload, err = EllesmereUI.DecodeImportString(importStr)
    if not payload then return false, err end

    local db = GetProfilesDB()

    if payload.type == "full" then
        -- Full profile: store as a new named profile
        db.profiles[profileName] = DeepCopy(payload.data)
        -- Add to order if not present
        local found = false
        for _, n in ipairs(db.profileOrder) do
            if n == profileName then found = true; break end
        end
        if not found then
            table.insert(db.profileOrder, 1, profileName)
        end
        -- Make it the active profile
        db.activeProfile = profileName
        EllesmereUI.ApplyProfileData(payload.data)
        return true, nil
    elseif payload.type == "partial" then
        -- Partial: copy current profile, overwrite the imported addons
        local currentSnap = EllesmereUI.SnapshotAllAddons()
        -- Merge imported addon data over current
        if payload.data and payload.data.addons then
            for folder, snap in pairs(payload.data.addons) do
                currentSnap.addons[folder] = DeepCopy(snap)
            end
        end
        -- Merge fonts/colors if present
        if payload.data.fonts then
            currentSnap.fonts = DeepCopy(payload.data.fonts)
        end
        if payload.data.customColors then
            currentSnap.customColors = DeepCopy(payload.data.customColors)
        end
        -- Store as new profile
        db.profiles[profileName] = currentSnap
        local found = false
        for _, n in ipairs(db.profileOrder) do
            if n == profileName then found = true; break end
        end
        if not found then
            table.insert(db.profileOrder, 1, profileName)
        end
        db.activeProfile = profileName
        EllesmereUI.ApplyProfileData(currentSnap)
        return true, nil
    end

    return false, "Unknown profile type"
end

-------------------------------------------------------------------------------
--  Profile management
-------------------------------------------------------------------------------
function EllesmereUI.SaveCurrentAsProfile(name)
    local db = GetProfilesDB()
    db.profiles[name] = EllesmereUI.SnapshotAllAddons()
    local found = false
    for _, n in ipairs(db.profileOrder) do
        if n == name then found = true; break end
    end
    if not found then
        table.insert(db.profileOrder, 1, name)
    end
    db.activeProfile = name
end

function EllesmereUI.DeleteProfile(name)
    local db = GetProfilesDB()
    db.profiles[name] = nil
    for i, n in ipairs(db.profileOrder) do
        if n == name then table.remove(db.profileOrder, i); break end
    end
    -- Clean up spec assignments
    for specID, pName in pairs(db.specProfiles) do
        if pName == name then db.specProfiles[specID] = nil end
    end
    -- If deleted profile was active, fall back to Custom
    if db.activeProfile == name then
        db.activeProfile = "Custom"
    end
end

function EllesmereUI.RenameProfile(oldName, newName)
    local db = GetProfilesDB()
    if not db.profiles[oldName] then return end
    db.profiles[newName] = db.profiles[oldName]
    db.profiles[oldName] = nil
    for i, n in ipairs(db.profileOrder) do
        if n == oldName then db.profileOrder[i] = newName; break end
    end
    for specID, pName in pairs(db.specProfiles) do
        if pName == oldName then db.specProfiles[specID] = newName end
    end
    if db.activeProfile == oldName then
        db.activeProfile = newName
    end
end

function EllesmereUI.SwitchProfile(name)
    local db = GetProfilesDB()
    local profileData = db.profiles[name]
    if not profileData then return end
    db.activeProfile = name
    EllesmereUI.ApplyProfileData(profileData)
end

function EllesmereUI.GetActiveProfileName()
    local db = GetProfilesDB()
    return db.activeProfile or "Custom"
end

function EllesmereUI.GetProfileList()
    local db = GetProfilesDB()
    return db.profileOrder, db.profiles
end

function EllesmereUI.AssignProfileToSpec(profileName, specID)
    local db = GetProfilesDB()
    db.specProfiles[specID] = profileName
end

function EllesmereUI.UnassignSpec(specID)
    local db = GetProfilesDB()
    db.specProfiles[specID] = nil
end

function EllesmereUI.GetSpecProfile(specID)
    local db = GetProfilesDB()
    return db.specProfiles[specID]
end

-------------------------------------------------------------------------------
--  Auto-save active profile on setting changes
--  Called by addons after any setting change to keep the active profile
--  in sync with live settings.
-------------------------------------------------------------------------------
function EllesmereUI.AutoSaveActiveProfile()
    local db = GetProfilesDB()
    local name = db.activeProfile or "Custom"
    db.profiles[name] = EllesmereUI.SnapshotAllAddons()
end

-------------------------------------------------------------------------------
--  Spec auto-switch handler
-------------------------------------------------------------------------------
do
    local specFrame = CreateFrame("Frame")
    specFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    specFrame:SetScript("OnEvent", function(_, event, unit)
        if event ~= "PLAYER_SPECIALIZATION_CHANGED" then return end
        if unit ~= "player" then return end
        local specIdx = GetSpecialization and GetSpecialization() or 0
        local specID = specIdx and specIdx > 0
            and GetSpecializationInfo(specIdx) or nil
        if not specID then return end
        local db = GetProfilesDB()
        local targetProfile = db.specProfiles[specID]
        if targetProfile and db.profiles[targetProfile] then
            local current = db.activeProfile or "Custom"
            if current ~= targetProfile then
                -- Auto-save current before switching
                db.profiles[current] = EllesmereUI.SnapshotAllAddons()
                EllesmereUI.SwitchProfile(targetProfile)
                -- Refresh UI if panel is open
                if EllesmereUI._mainFrame
                    and EllesmereUI._mainFrame:IsShown() then
                    EllesmereUI:InvalidatePageCache()
                    EllesmereUI:RefreshPage(true)
                end
            end
        end
    end)
end

-------------------------------------------------------------------------------
--  Popular Presets & Weekly Spotlight
--  Hardcoded profile strings that ship with the addon.
--  To add a new preset: add an entry to POPULAR_PRESETS with name + string.
--  To update the weekly spotlight: change WEEKLY_SPOTLIGHT.
-------------------------------------------------------------------------------
EllesmereUI.POPULAR_PRESETS = {
    -- { name = "Preset Name", description = "Short description", exportString = "!EUI_..." },
    -- EllesmereUI default is handled specially (applies defaults, no string needed)
    { name = "EllesmereUI", description = "The default EllesmereUI look", exportString = nil },
    { name = "Spin the Wheel", description = "Randomize all settings", exportString = nil },
}

EllesmereUI.WEEKLY_SPOTLIGHT = nil  -- { name = "...", description = "...", exportString = "!EUI_..." }
-- To set a weekly spotlight, uncomment and fill in:
-- EllesmereUI.WEEKLY_SPOTLIGHT = {
--     name = "Week 1 Spotlight",
--     description = "A clean minimal setup",
--     exportString = "!EUI_...",
-- }

-------------------------------------------------------------------------------
--  Spin the Wheel: global randomizer
--  Randomizes all addon settings except X/Y offsets and Scale.
--  Party Mode is hard-set to enabled.
-------------------------------------------------------------------------------
function EllesmereUI.SpinTheWheel()
    local function rColor()
        return { r = math.random(), g = math.random(), b = math.random() }
    end
    local function rBool() return math.random() > 0.5 end
    local function pick(t) return t[math.random(#t)] end
    local function rRange(lo, hi) return lo + math.random() * (hi - lo) end
    local floor = math.floor

    -- Party Mode: hard-set to enabled
    if EllesmereUIDB then
        EllesmereUIDB.partyMode = true
    end

    -- Randomize each loaded addon (except Nameplates which has its own randomizer)
    for _, entry in ipairs(ADDON_DB_MAP) do
        if IsAddonLoaded(entry.folder) and entry.folder ~= "EllesmereUINameplates" then
            local profile = GetAddonProfile(entry)
            if profile then
                EllesmereUI._RandomizeProfile(profile, entry.folder)
            end
        end
    end

    -- Nameplates: use the existing randomizer keys from the preset system
    if IsAddonLoaded("EllesmereUINameplates") then
        local db = _G.EllesmereUINameplatesDB
        if db then
            EllesmereUI._RandomizeNameplates(db)
        end
    end

    -- Randomize global fonts
    local fontsDB = EllesmereUI.GetFontsDB()
    local validFonts = {}
    for _, name in ipairs(EllesmereUI.FONT_ORDER) do
        if name ~= "---" then validFonts[#validFonts + 1] = name end
    end
    fontsDB.global = pick(validFonts)
    local outlineModes = { "none", "outline", "shadow" }
    fontsDB.outlineMode = pick(outlineModes)

    -- Randomize class colors
    local colorsDB = EllesmereUI.GetCustomColorsDB()
    colorsDB.class = {}
    for token in pairs(EllesmereUI.CLASS_COLOR_MAP) do
        colorsDB.class[token] = rColor()
    end
end

--- Generic profile randomizer for AceDB-style addons.
--- Skips keys containing "offset", "Offset", "scale", "Scale", "X", "Y",
--- "pos", "Pos", "position", "Position", "anchor", "Anchor" (position-related).
function EllesmereUI._RandomizeProfile(profile, folderName)
    local function rColor()
        return { r = math.random(), g = math.random(), b = math.random() }
    end
    local function rBool() return math.random() > 0.5 end

    local function IsPositionKey(k)
        local kl = k:lower()
        if kl:find("offset") then return true end
        if kl:find("scale") then return true end
        if kl:find("position") then return true end
        if kl:find("anchor") then return true end
        if kl == "x" or kl == "y" then return true end
        if kl == "offsetx" or kl == "offsety" then return true end
        if kl:find("unlockpos") then return true end
        return false
    end

    local function RandomizeTable(tbl, depth)
        if depth > 5 then return end  -- safety limit
        for k, v in pairs(tbl) do
            if type(k) == "string" and IsPositionKey(k) then
                -- Skip position/scale keys
            elseif type(v) == "table" then
                -- Check if it's a color table
                if v.r and v.g and v.b then
                    tbl[k] = rColor()
                    if v.a then tbl[k].a = v.a end  -- preserve alpha
                else
                    RandomizeTable(v, depth + 1)
                end
            elseif type(v) == "boolean" then
                tbl[k] = rBool()
            elseif type(v) == "number" then
                -- Randomize numbers within a reasonable range of their current value
                if v == 0 then
                    -- Leave zero values alone (often flags)
                elseif v >= 0 and v <= 1 then
                    tbl[k] = math.random() -- 0-1 range (likely alpha/ratio)
                elseif v > 1 and v <= 50 then
                    tbl[k] = math.random(1, math.floor(v * 2))
                end
            end
        end
    end

    RandomizeTable(profile, 0)
end

--- Nameplate-specific randomizer (reuses the existing logic from the
--- commented-out preset system in the nameplates options file)
function EllesmereUI._RandomizeNameplates(db)
    local function rColor()
        return { r = math.random(), g = math.random(), b = math.random() }
    end
    local function rBool() return math.random() > 0.5 end
    local function pick(t) return t[math.random(#t)] end

    local borderOptions = { "ellesmere", "simple" }
    local glowOptions = { "ellesmereui", "vibrant", "none" }
    local cpPosOptions = { "bottom", "top" }
    local timerOptions = { "topleft", "center", "topright", "none" }

    -- Aura slots: exclusive pick
    local auraSlots = { "top", "left", "right", "topleft", "topright", "bottom" }
    local function pickAuraSlot()
        if #auraSlots == 0 then return "none" end
        local i = math.random(#auraSlots)
        local s = auraSlots[i]
        table.remove(auraSlots, i)
        return s
    end

    db.borderStyle = pick(borderOptions)
    db.borderColor = rColor()
    db.targetGlowStyle = pick(glowOptions)
    db.showTargetArrows = rBool()
    db.showClassPower = rBool()
    db.classPowerPos = pick(cpPosOptions)
    db.classPowerClassColors = rBool()
    db.classPowerGap = math.random(0, 6)
    db.classPowerCustomColor = rColor()
    db.classPowerBgColor = rColor()
    db.classPowerEmptyColor = rColor()

    -- Text slots
    local textPool = { "enemyName", "healthPercent", "healthNumber",
        "healthPctNum", "healthNumPct" }
    local function pickText()
        if #textPool == 0 then return "none" end
        local i = math.random(#textPool)
        local e = textPool[i]
        table.remove(textPool, i)
        return e
    end
    db.textSlotTop = pickText()
    db.textSlotRight = pickText()
    db.textSlotLeft = pickText()
    db.textSlotCenter = pickText()
    db.textSlotTopColor = rColor()
    db.textSlotRightColor = rColor()
    db.textSlotLeftColor = rColor()
    db.textSlotCenterColor = rColor()

    db.healthBarHeight = math.random(10, 24)
    db.healthBarWidth = math.random(2, 10)
    db.castBarHeight = math.random(10, 24)
    db.castNameSize = math.random(8, 14)
    db.castNameColor = rColor()
    db.castTargetSize = math.random(8, 14)
    db.castTargetClassColor = rBool()
    db.castTargetColor = rColor()
    db.castScale = math.random(10, 40) * 5
    db.showCastIcon = math.random() > 0.3
    db.castIconScale = math.floor((0.5 + math.random() * 1.5) * 10 + 0.5) / 10

    db.debuffSlot = pickAuraSlot()
    db.buffSlot = pickAuraSlot()
    db.ccSlot = pickAuraSlot()
    db.debuffYOffset = math.random(0, 8)
    db.sideAuraXOffset = math.random(0, 8)
    db.auraSpacing = math.random(0, 6)

    db.topSlotSize = math.random(18, 34)
    db.rightSlotSize = math.random(18, 34)
    db.leftSlotSize = math.random(18, 34)
    db.toprightSlotSize = math.random(18, 34)
    db.topleftSlotSize = math.random(18, 34)

    local timerPos = pick(timerOptions)
    db.debuffTimerPosition = timerPos
    db.buffTimerPosition = timerPos
    db.ccTimerPosition = timerPos

    db.auraDurationTextSize = math.random(8, 14)
    db.auraDurationTextColor = rColor()
    db.auraStackTextSize = math.random(8, 14)
    db.auraStackTextColor = rColor()
    db.buffTextSize = math.random(8, 14)
    db.buffTextColor = rColor()
    db.ccTextSize = math.random(8, 14)
    db.ccTextColor = rColor()

    db.raidMarkerPos = pickAuraSlot()
    db.classificationSlot = pickAuraSlot()

    db.textSlotTopSize = math.random(8, 14)
    db.textSlotRightSize = math.random(8, 14)
    db.textSlotLeftSize = math.random(8, 14)
    db.textSlotCenterSize = math.random(8, 14)

    db.hashLineEnabled = math.random() > 0.7
    db.hashLinePercent = math.random(10, 50)
    db.hashLineColor = rColor()
    db.focusCastHeight = 100 + math.random(0, 4) * 25

    -- Font
    local validFonts = {}
    for _, f in ipairs(EllesmereUI.FONT_ORDER) do
        if f ~= "---" then validFonts[#validFonts + 1] = f end
    end
    db.font = "Interface\\AddOns\\EllesmereUI\\media\\fonts\\"
        .. (EllesmereUI.FONT_FILES[pick(validFonts)] or "Expressway.TTF")

    -- Colors
    db.focusColorEnabled = true
    db.tankHasAggroEnabled = true
    db.focus = rColor()
    db.caster = rColor()
    db.miniboss = rColor()
    db.enemyInCombat = rColor()
    db.castBar = rColor()
    db.interruptReady = rColor()
    db.castBarUninterruptible = rColor()
    db.tankHasAggro = rColor()
    db.tankLosingAggro = rColor()
    db.tankNoAggro = rColor()
    db.dpsHasAggro = rColor()
    db.dpsNearAggro = rColor()

    -- Bar texture (skip texture key randomization — texture list is addon-local)
    db.healthBarTextureClassColor = math.random() > 0.5
    if not db.healthBarTextureClassColor then
        db.healthBarTextureColor = rColor()
    end
    db.healthBarTextureScale = math.random(5, 20) / 10
    db.healthBarTextureFit = math.random() > 0.3
end

-------------------------------------------------------------------------------
--  Initialize profile system on first login
--  Creates the "Custom" profile from current settings if none exists.
--  Also handles _pendingPresetReset for the "EllesmereUI (Default)" button.
-------------------------------------------------------------------------------
do
    local initFrame = CreateFrame("Frame")
    initFrame:RegisterEvent("PLAYER_LOGIN")
    initFrame:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_LOGIN")

        -- Handle pending preset reset (EllesmereUI Default button)
        -- This wipes all addon SVs so they re-init with built-in defaults,
        -- then reloads once more.
        if EllesmereUIDB and EllesmereUIDB._pendingPresetReset == "ellesmereui" then
            EllesmereUIDB._pendingPresetReset = nil
            -- Wipe each addon's saved variables so they re-init with defaults
            for _, entry in ipairs(ADDON_DB_MAP) do
                local sv = _G[entry.svName]
                if sv then
                    if entry.isFlat then
                        -- Flat DB: wipe all non-internal keys
                        for k in pairs(sv) do
                            if type(k) == "string" and not k:match("^_") then
                                sv[k] = nil
                            end
                        end
                    else
                        -- AceDB: wipe the profiles table so it re-creates Default
                        if sv.profiles then
                            sv.profiles = nil
                        end
                    end
                end
            end
            -- Reset fonts and colors to defaults
            if EllesmereUIDB.fonts then
                EllesmereUIDB.fonts = nil
            end
            if EllesmereUIDB.customColors then
                EllesmereUIDB.customColors = nil
            end
            -- Keep profile metadata but update the active profile snapshot after reload
            EllesmereUIDB._pendingDefaultSnapshot = true
            C_Timer.After(0, function() ReloadUI() end)
            return
        end

        -- After a default reset reload, snapshot the fresh defaults as active profile
        if EllesmereUIDB and EllesmereUIDB._pendingDefaultSnapshot then
            EllesmereUIDB._pendingDefaultSnapshot = nil
            C_Timer.After(0.5, function()
                local db = GetProfilesDB()
                local name = db.activeProfile or "Custom"
                db.profiles[name] = EllesmereUI.SnapshotAllAddons()
            end)
        end

        local db = GetProfilesDB()
        -- On first install, create "Custom" from current (default) settings
        if not db.activeProfile then
            db.activeProfile = "Custom"
        end
        -- Ensure Custom profile exists with current settings
        if not db.profiles["Custom"] then
            -- Delay slightly to let all addons initialize their DBs
            C_Timer.After(0.5, function()
                db.profiles["Custom"] = EllesmereUI.SnapshotAllAddons()
            end)
        end
        -- Ensure Custom is in the order list
        local hasCustom = false
        for _, n in ipairs(db.profileOrder) do
            if n == "Custom" then hasCustom = true; break end
        end
        if not hasCustom then
            table.insert(db.profileOrder, "Custom")
        end

        -- Auto-save active profile when the settings panel closes
        C_Timer.After(1, function()
            if EllesmereUI._mainFrame and not EllesmereUI._profileAutoSaveHooked then
                EllesmereUI._profileAutoSaveHooked = true
                EllesmereUI._mainFrame:HookScript("OnHide", function()
                    EllesmereUI.AutoSaveActiveProfile()
                end)
            end
        end)
    end)
end

-------------------------------------------------------------------------------
--  Export Popup: shows a read-only text box with the export string
-------------------------------------------------------------------------------
function EllesmereUI:ShowExportPopup(exportStr)
    local POPUP_W, POPUP_H = 520, 260
    local FONT = EllesmereUI.EXPRESSWAY
    local EG = EllesmereUI.ELLESMERE_GREEN
    local PP = EllesmereUI.PanelPP

    -- Dimmer
    local dimmer = CreateFrame("Frame", nil, UIParent)
    dimmer:SetFrameStrata("FULLSCREEN_DIALOG")
    dimmer:SetAllPoints(UIParent)
    dimmer:EnableMouse(true)
    dimmer:EnableMouseWheel(true)
    dimmer:SetScript("OnMouseWheel", function() end)

    local dimTex = dimmer:CreateTexture(nil, "BACKGROUND")
    dimTex:SetAllPoints()
    dimTex:SetColorTexture(0, 0, 0, 0.25)

    -- Popup
    local popup = CreateFrame("Frame", nil, dimmer)
    popup:SetSize(POPUP_W, POPUP_H)
    popup:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetFrameLevel(dimmer:GetFrameLevel() + 10)
    popup:EnableMouse(true)

    local bg = popup:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.06, 0.08, 0.10, 1)
    EllesmereUI.MakeBorder(popup, 1, 1, 1, 0.15, PP)

    -- Title
    local title = EllesmereUI.MakeFont(popup, 18, nil, 1, 1, 1)
    title:SetPoint("TOP", popup, "TOP", 0, -20)
    title:SetText("Export Profile")

    -- Subtitle
    local sub = EllesmereUI.MakeFont(popup, 12, nil, 1, 1, 1)
    sub:SetAlpha(0.45)
    sub:SetPoint("TOP", title, "BOTTOM", 0, -6)
    sub:SetText("Copy the string below and share it")

    -- EditBox
    local editBox = CreateFrame("EditBox", nil, popup)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFont(FONT, 11, EllesmereUI.GetFontOutlineFlag())
    editBox:SetTextColor(1, 1, 1, 0.75)
    editBox:SetPoint("TOPLEFT", popup, "TOPLEFT", 20, -70)
    editBox:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -20, 60)
    editBox:SetText(exportStr)
    editBox._readOnlyText = exportStr
    editBox:SetScript("OnChar", function(self)
        if self._readOnlyText then
            self:SetText(self._readOnlyText)
            self:HighlightText()
        end
    end)
    editBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput and self._readOnlyText then
            self:SetText(self._readOnlyText)
            self:HighlightText()
        end
    end)
    editBox:SetScript("OnMouseUp", function(self)
        C_Timer.After(0, function()
            editBox:SetFocus()
            editBox:HighlightText()
        end)
    end)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, popup)
    closeBtn:SetSize(120, 32)
    closeBtn:SetPoint("BOTTOM", popup, "BOTTOM", 0, 14)
    closeBtn:SetFrameLevel(popup:GetFrameLevel() + 2)
    EllesmereUI.MakeStyledButton(closeBtn, "Close", 13,
        EllesmereUI.RB_COLOURS, function() dimmer:Hide() end)

    -- Dimmer click to close
    dimmer:SetScript("OnMouseDown", function(self)
        if not popup:IsMouseOver() then self:Hide() end
    end)

    -- Escape to close
    popup:EnableKeyboard(true)
    popup:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            dimmer:Hide()
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    dimmer:Show()
    C_Timer.After(0.05, function()
        editBox:SetFocus()
        editBox:HighlightText()
    end)
end

-------------------------------------------------------------------------------
--  Import Popup: shows an editable text box for pasting import strings
--  onImport(str) is called with the pasted string
-------------------------------------------------------------------------------
function EllesmereUI:ShowImportPopup(onImport)
    local POPUP_W, POPUP_H = 520, 260
    local FONT = EllesmereUI.EXPRESSWAY
    local EG = EllesmereUI.ELLESMERE_GREEN
    local PP = EllesmereUI.PanelPP

    -- Dimmer
    local dimmer = CreateFrame("Frame", nil, UIParent)
    dimmer:SetFrameStrata("FULLSCREEN_DIALOG")
    dimmer:SetAllPoints(UIParent)
    dimmer:EnableMouse(true)
    dimmer:EnableMouseWheel(true)
    dimmer:SetScript("OnMouseWheel", function() end)

    local dimTex = dimmer:CreateTexture(nil, "BACKGROUND")
    dimTex:SetAllPoints()
    dimTex:SetColorTexture(0, 0, 0, 0.25)

    -- Popup
    local popup = CreateFrame("Frame", nil, dimmer)
    popup:SetSize(POPUP_W, POPUP_H)
    popup:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetFrameLevel(dimmer:GetFrameLevel() + 10)
    popup:EnableMouse(true)

    local bg = popup:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.06, 0.08, 0.10, 1)
    EllesmereUI.MakeBorder(popup, 1, 1, 1, 0.15, PP)

    -- Title
    local title = EllesmereUI.MakeFont(popup, 18, nil, 1, 1, 1)
    title:SetPoint("TOP", popup, "TOP", 0, -20)
    title:SetText("Import Profile")

    -- Subtitle
    local sub = EllesmereUI.MakeFont(popup, 12, nil, 1, 1, 1)
    sub:SetAlpha(0.45)
    sub:SetPoint("TOP", title, "BOTTOM", 0, -6)
    sub:SetText("Paste an EllesmereUI profile string below")

    -- EditBox
    local editBox = CreateFrame("EditBox", nil, popup)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFont(FONT, 11, EllesmereUI.GetFontOutlineFlag())
    editBox:SetTextColor(1, 1, 1, 0.75)
    editBox:SetPoint("TOPLEFT", popup, "TOPLEFT", 20, -70)
    editBox:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -20, 60)
    editBox:SetText("")

    -- Import button
    local importBtn = CreateFrame("Button", nil, popup)
    importBtn:SetSize(120, 32)
    importBtn:SetPoint("BOTTOMRIGHT", popup, "BOTTOM", -4, 14)
    importBtn:SetFrameLevel(popup:GetFrameLevel() + 2)
    local importBg, importBrd, importLbl = EllesmereUI.MakeStyledButton(
        importBtn, "Import", 13, EllesmereUI.WB_COLOURS, function()
            local str = editBox:GetText()
            if str and #str > 0 then
                dimmer:Hide()
                if onImport then onImport(str) end
            end
        end)

    -- Cancel button
    local cancelBtn = CreateFrame("Button", nil, popup)
    cancelBtn:SetSize(120, 32)
    cancelBtn:SetPoint("BOTTOMLEFT", popup, "BOTTOM", 4, 14)
    cancelBtn:SetFrameLevel(popup:GetFrameLevel() + 2)
    EllesmereUI.MakeStyledButton(cancelBtn, "Cancel", 13,
        EllesmereUI.RB_COLOURS, function() dimmer:Hide() end)

    -- Dimmer click to close
    dimmer:SetScript("OnMouseDown", function(self)
        if not popup:IsMouseOver() then self:Hide() end
    end)

    -- Escape to close
    popup:EnableKeyboard(true)
    popup:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            dimmer:Hide()
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    dimmer:Show()
    C_Timer.After(0.05, function()
        editBox:SetFocus()
    end)
end
