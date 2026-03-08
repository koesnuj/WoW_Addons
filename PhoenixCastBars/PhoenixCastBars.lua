local ADDON_NAME, PCB = ...

-- Load GCD logic if not already loaded
if not (PCB and PCB.GCD) then
    local ok, err = pcall(function()
        local gcd_path = "Interface/AddOns/PhoenixCastBars/GCD.lua"
        if loadfile then loadfile(gcd_path)() end
    end)
end
local _TargetFrameSpellBar_Update = _G.TargetFrameSpellBar_Update

-- =====================================================================
-- Utility Functions
-- =====================================================================

-- PCB:Print - Outputs colored addon messages to chat frame
-- Used throughout the addon for user-facing status messages
function PCB:Print(msg)
    msg = tostring(msg or "")
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99PhoenixCastBars:|r " .. msg)
    else
        print("PhoenixCastBars: " .. msg)
    end
end

PCB.name     = ADDON_NAME
PCB.version = "0.4.9"  -- Update this with each release
PCB.LSM      = LibStub and LibStub("LibSharedMedia-3.0", true) or nil  -- LibSharedMedia for textures/fonts
PCB.LDBIcon  = LibStub and LibStub("LibDBIcon-1.0", true) or nil       -- LibDataBroker Icon for minimap


-- ---------------------------------------------------------------------------
-- Blizzard TargetFrame spellbar suppression (prevents duplicate bars when target==player)
-- ---------------------------------------------------------------------------
function PCB:ShouldSuppressAllTargetBlizzardBars()
    local db = self.db and self.db.bars and self.db.bars.target
    return db and db.enabled == true
end

-- Hide Blizzard nameplate cast bars for the current target when PCB target bar is enabled.
function PCB:ShouldSuppressNameplateCastbar(unit)
    if not unit or not UnitIsUnit(unit, "target") then
        return false
    end

    local db = self.db and self.db.bars and self.db.bars.target
    return db and db.enabled == true
end

-- Blizzard cast-bar suppression (per-unit)
-- Goal:
--  - If PCB bar for Target/Focus is enabled, suppress Blizzard Target/Focus spellbar (prevents double bars).
--  - If PCB bar for Target/Focus is disabled, allow Blizzard Target/Focus spellbar even if global hide is enabled.
PCB._blizzardBars = PCB._blizzardBars or {}

local function GetSpellBarForUnit(unit)
    if unit == "player" then
        -- Retail has used both names across expansions.
        return _G.PlayerCastingBarFrame or _G.CastingBarFrame
    elseif unit == "target" then
        -- Retail: TargetFrame.spellbar exists; some builds expose TargetFrameSpellBar global.
        if _G.TargetFrame and _G.TargetFrame.spellbar then return _G.TargetFrame.spellbar end
        return _G.TargetFrameSpellBar
    elseif unit == "focus" then
        if _G.FocusFrame and _G.FocusFrame.spellbar then return _G.FocusFrame.spellbar end
        return _G.FocusFrameSpellBar
    elseif unit == "pet" then
        return _G.PetCastingBarFrame
    elseif unit == "vehicle" then
        return _G.VehicleCastingBarFrame
    elseif unit == "override" then
        return _G.OverrideActionBarSpellBar
    end
end

-- Cache original Blizzard bar state for safe restoration later
local function SnapshotBar(bar)
    if not bar or PCB._blizzardBars[bar] then return end
    PCB._blizzardBars[bar] = {
        onShow = bar:GetScript("OnShow"),
        hooked = false,
    }
end

-- NOTE: We use a *non-destructive* suppression strategy.
-- We do NOT UnregisterAllEvents() or override :Show(), because that permanently breaks the
-- Blizzard castbar when users toggle settings at runtime.
-- Hooks OnShow to prevent the bar from appearing while suppressed
local function EnsureSoftHook(bar)
    local info = PCB._blizzardBars and PCB._blizzardBars[bar]
    if not bar or not info or info.hooked then return end
    info.hooked = true

    -- Hook the OnShow event to intercept visibility changes
    bar:HookScript("OnShow", function(self)
        if self._pcbSuppressed then
            -- Prevent infinite recursion when Hide() triggers OnShow again
            if self._pcbHiding then return end
            self._pcbHiding = true  -- Guard flag
            self:SetAlpha(0)        -- Make invisible
            self:Hide()             -- Actually hide the frame
            self._pcbHiding = false -- Clear guard flag
        end
    end)
end

-- Suppresses a Blizzard bar without unregistering events (safe toggle)
local function SuppressBar(bar)
    if not bar then return end
    SnapshotBar(bar)
    EnsureSoftHook(bar)
    bar._pcbSuppressed = true
    bar:SetAlpha(0)
    bar:Hide()
end

-- Restores a Blizzard bar to normal behavior
local function RestoreBar(bar)
    if not bar then return end
    SnapshotBar(bar)
    EnsureSoftHook(bar)
    bar._pcbSuppressed = nil
    bar:SetAlpha(1)
    -- Do NOT force :Show(); Blizzard will show when appropriate.
end

local function UnitEnabled(unitKey)
    -- Checks if a specific unit bar (player, target, focus, etc) is enabled in settings
    -- Returns true by default if no setting exists (assumes enabled)
    local db = PCB and PCB.db
    if not db or not db.bars or not db.bars[unitKey] then return true end
    return db.bars[unitKey].enabled ~= false
end

local function UnitIsCastingOrChanneling(unit)
    -- Helper to check if a unit is currently casting a spell or channeling
    if not unit or not UnitExists(unit) then return false end
    if UnitCastingInfo(unit) ~= nil then return true end
    if UnitChannelInfo(unit) ~= nil then return true end
    return false
end

-- =====================================================================
-- Blizzard Cast Bar Management
-- =====================================================================
-- This section manages hiding/showing Blizzard's default cast bars based on
-- whether the user has enabled PhoenixCastBars for each unit type.
-- This prevents duplicate cast bars from appearing.

function PCB:UpdateBlizzardCastBars()
    -- Throttle: avoid redundant suppress/restore churn on rapid events
    local now = GetTime()
    if self._lastBlizzUpdate and (now - self._lastBlizzUpdate) < 0.25 then
        return
    end
    self._lastBlizzUpdate = now

    local db = self.db

    -- PLAYER: suppress/restore based on whether PCB player bar is enabled
    local playerBars = {
        _G.PlayerCastingBarFrame,
        _G.CastingBarFrame,
    }
    local petBar   = GetSpellBarForUnit("pet")
    local vehBar   = GetSpellBarForUnit("vehicle")
    local overBar  = GetSpellBarForUnit("override")

    if UnitEnabled("player") then
        for _, b in ipairs(playerBars) do SuppressBar(b) end
        SuppressBar(petBar)
        SuppressBar(vehBar)
        SuppressBar(overBar)
    else
        for _, b in ipairs(playerBars) do RestoreBar(b) end
        RestoreBar(petBar)
        RestoreBar(vehBar)
        RestoreBar(overBar)
    end

    -- TARGET/FOCUS: authoritative per-unit control.
    -- If the PCB bar for that unit is enabled, Blizzard bar MUST be suppressed to prevent double bars,
    -- regardless of the global hide setting.
    local targetBar = GetSpellBarForUnit("target")
    local focusBar  = GetSpellBarForUnit("focus")

    if UnitEnabled("target") then
        SuppressBar(targetBar)  -- PCB target bar active, hide Blizzard's
    else
        RestoreBar(targetBar)   -- PCB target bar disabled, restore Blizzard's
        -- If the bar is allowed again and a cast is already in progress, ensure it can appear.
        if targetBar then
            targetBar:SetAlpha(1)  -- Reset transparency
            -- If target is currently casting, show the bar immediately
            if UnitIsCastingOrChanneling("target") then
                targetBar:Show()
            end
        end
    end

    if UnitEnabled("focus") then
        SuppressBar(focusBar)
    else
        RestoreBar(focusBar)
        if focusBar then
            focusBar:SetAlpha(1)
            if UnitIsCastingOrChanneling("focus") then
                focusBar:Show()
            end
        end
    end

    -- Edge case: when target == player, Blizzard can mirror the player cast bar near the target frame,
    -- causing a duplicate cast bar even if the target spellbar is suppressed. If our TARGET bar is enabled,
    -- we authoritatively suppress the player cast bar during target==player to prevent double bars.
    -- This handles the unusual case where a player targets themselves (common in solo testing)
    if UnitEnabled("target") and UnitExists("target") and UnitIsUnit("target", "player") then
        -- Suppress ALL player cast bars when self-targeted to avoid showing two bars
        for _, b in ipairs(playerBars) do SuppressBar(b) end
    end

    -- If target bar is disabled, re-allow the target's nameplate castbar immediately (even mid-cast).
    -- This ensures the Blizzard nameplate castbar shows up when PCB target bar is turned off
    if not UnitEnabled("target") and C_NamePlate and C_NamePlate.GetNamePlates then
        local plates = C_NamePlate.GetNamePlates() or {}  -- Get all visible nameplates
        for _, plate in ipairs(plates) do
            local uf = plate and plate.UnitFrame
            local unit = uf and uf.unit
            -- Check if this nameplate belongs to the current target
            if unit and UnitIsUnit(unit, "target") then
                -- Try multiple possible locations for the castbar (varies by WoW build)
                local cb = uf.castBar or uf.CastBar or (uf.UnitFrame and (uf.UnitFrame.castBar or uf.UnitFrame.CastBar))
                if cb then
                    cb:SetAlpha(1)  -- Make visible
                    -- If currently casting/channeling, show the bar immediately
                    if UnitIsCastingOrChanneling(unit) then
                        cb:Show()
                    end
                end
            end
        end
    end
end

-- Background watcher: Blizzard sometimes re-registers or shows their bars during gameplay.
-- We enforce our desired state deterministically by listening to key events.
PCB._blizzBarWatcher = CreateFrame("Frame")
-- Zone changes, loading screens
PCB._blizzBarWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
-- UI scale/resolution changes can reset bar visibility
PCB._blizzBarWatcher:RegisterEvent("UI_SCALE_CHANGED")
-- Blizzard UI addons loading can recreate their cast bars
PCB._blizzBarWatcher:RegisterEvent("ADDON_LOADED")
-- Target/focus changes require immediate suppression updates
PCB._blizzBarWatcher:RegisterEvent("PLAYER_TARGET_CHANGED")
PCB._blizzBarWatcher:RegisterEvent("PLAYER_FOCUS_CHANGED")
-- Cast start events ensure bars are suppressed even mid-cast
PCB._blizzBarWatcher:RegisterUnitEvent("UNIT_SPELLCAST_START", "player", "vehicle", "target", "focus")
PCB._blizzBarWatcher:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player", "vehicle", "target", "focus")
PCB._blizzBarWatcher:SetScript("OnEvent", function(_, event, arg1)
    -- Always enforce. Target/Focus suppression is authoritative even if global hide is OFF.
    if PCB and PCB.UpdateBlizzardCastBars then
        -- For ADDON_LOADED, only respond to Blizzard addons (they might recreate cast bars)
        if event ~= "ADDON_LOADED" or (type(arg1) == "string" and arg1:match("^Blizzard_")) then
            PCB:UpdateBlizzardCastBars()
        end
    end
end)

-- Defaults
local defaults = {
    locked = true,
    texture = "Interface\\TARGETINGFRAME\\UI-StatusBar",
    font = "Fonts\\FRIZQT__.TTF",
    fontSize = 12,
    outline = "OUTLINE",
    colorCast = { r = 0.24, g = 0.56, b = 0.95, a = 1.0 },
    colorChannel = { r = 0.35, g = 0.90, b = 0.55, a = 1.0 },
    colorFailed = { r = 0.85, g = 0.25, b = 0.25, a = 1.0 },
    colorSuccess = { r = 0.25, g = 0.90, b = 0.35, a = 1.0 },
    safeZoneColor = { r = 1.0, g = 0.2, b = 0.2, a = 0.35 },
    minimapButton = {
        show = true,
        angle = 220,
    },
    bars = {
        player = {
            enabled = true,
            width = 260, height = 18,
            point = "CENTER", relPoint = "CENTER", x = 0, y = -180,
            alpha = 1.0, scale = 1.0,
            showIcon = true,
            iconOffsetX = -6,
            iconOffsetY = 0,
            showSpark = true,
            showTime = true,
            showSpellName = true,
            showLatency = true,
            -- showInterruptShield removed
            appearance = {
                useGlobalTexture = true, useGlobalFont = true, useGlobalFontSize = true, useGlobalOutline = true,
                texture = nil, font = nil, fontSize = nil, outline = nil,
            },
        },
        target = {
            enabled = true,
            width = 240, height = 16,
            point = "CENTER", relPoint = "CENTER", x = 0, y = -140,
            alpha = 1.0, scale = 1.0,
            showIcon = true,
            iconOffsetX = -6,
            iconOffsetY = 0,
            showSpark = true,
            showTime = true,
            showSpellName = true,
            -- showInterruptShield removed
            appearance = {
                useGlobalTexture = true, useGlobalFont = true, useGlobalFontSize = true, useGlobalOutline = true,
                texture = nil, font = nil, fontSize = nil, outline = nil,
            },
        },
        focus = {
            enabled = false,
            width = 240, height = 16,
            point = "CENTER", relPoint = "CENTER", x = 0, y = -110,
            alpha = 1.0, scale = 1.0,
            showIcon = true,
            iconOffsetX = -6,
            iconOffsetY = 0,
            showSpark = true,
            showTime = true,
            showSpellName = true,
            -- showInterruptShield removed
            appearance = {
                useGlobalTexture = true, useGlobalFont = true, useGlobalFontSize = true, useGlobalOutline = true,
                texture = nil, font = nil, fontSize = nil, outline = nil,
            },
        },
        -- ADDED: GCD bar defaults
        gcd = {
            enabled = true,
            width = 200, height = 8,
            point = "CENTER", relPoint = "CENTER", x = 0, y = -210,
            alpha = 1.0, scale = 1.0,
            showSpark = true,
            showTime = false,
            appearance = {
                useGlobalTexture = true, useGlobalFont = true, useGlobalFontSize = true, useGlobalOutline = true,
                texture = nil, font = nil, fontSize = nil, outline = nil,
            },
        },
    },
}


-- =========================================================
-- Profiles (per-character / per-spec) + Export/Import
-- =========================================================
-- SavedVariables root schema:
-- PhoenixCastBarsDB = {
--   profileMode = "character"|"spec",
--   profiles = { [profileName] = <settings table> },
--   chars = { [charKey] = { profile = "Default", specProfiles = { [specID] = "Default" } } },
-- }

local DB_SCHEMA_VERSION = 1

local function deepcopy(src)
    if type(src) ~= "table" then return src end
    local out = {}
    for k, v in pairs(src) do out[k] = deepcopy(v) end
    return out
end

local function mergeDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            mergeDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

local function GetCharKey()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName() or "Realm"
    realm = realm:gsub("%s+", "")
    return name .. "-" .. realm
end

local function GetCurrentSpecID()
    local specIndex = GetSpecialization and GetSpecialization()
    if not specIndex or specIndex == 0 then return nil end
    local specID = select(1, GetSpecializationInfo(specIndex))
    return specID
end

-- Profile serialization for export/import. Supports nil, boolean, number, string, and table (with string/number keys only).
-- Avoids loadstring for security; provides stable key ordering for consistent export strings.
-- Format: n=nil, b0/b1=boolean, d<num>;=number, s<len>:<str>=string, t...e=table
local function SerializeValue(v, out)
    local t = type(v)
    if t == "nil" then
        out[#out+1] = "n"  -- Encode nil as 'n'
    elseif t == "boolean" then
        out[#out+1] = v and "b1" or "b0"  -- 'b1' for true, 'b0' for false
    elseif t == "number" then
        out[#out+1] = "d"              -- Number prefix
        out[#out+1] = tostring(v)      -- Actual number
        out[#out+1] = ";"              -- Delimiter
    elseif t == "string" then
        out[#out+1] = "s"              -- String prefix
        out[#out+1] = tostring(#v)     -- Length of string
        out[#out+1] = ":"              -- Length delimiter
        out[#out+1] = v                -- Actual string content
    elseif t == "table" then
        out[#out+1] = "t"              -- Table start marker
        local keys = {}
        for k in pairs(v) do keys[#keys+1] = k end
        -- Sort keys for deterministic output (same profile always exports to same string)
        table.sort(keys, function(a,b) return tostring(a) < tostring(b) end)
        for i=1,#keys do
            local k = keys[i]
            SerializeValue(k, out)     -- Serialize key
            SerializeValue(v[k], out)  -- Serialize value
        end
        out[#out+1] = "e"              -- Table end marker
    else
        -- Unsupported type (function, userdata, etc.) - encode as nil
        out[#out+1] = "n"
    end
end

local function SerializeTable(tbl)
    local out = {}
    SerializeValue(tbl, out)
    return table.concat(out)
end

local function DeserializeValue(s, i)
    local tag = s:sub(i,i)
    if tag == "n" then
        return nil, i+1
    elseif tag == "b" then
        local v = s:sub(i+1,i+1) == "1"
        return v, i+2
    elseif tag == "d" then
        local j = s:find(";", i+1, true)
        if not j then return nil, #s+1 end
        local num = tonumber(s:sub(i+1, j-1))
        return num, j+1
    elseif tag == "s" then
        local colon = s:find(":", i+1, true)
        if not colon then return "", #s+1 end
        local len = tonumber(s:sub(i+1, colon-1)) or 0
        local start = colon+1
        local stop = start + len - 1
        local str = s:sub(start, stop)
        return str, stop+1
    elseif tag == "t" then
        local tbl = {}
        i = i+1
        while i <= #s do
            if s:sub(i,i) == "e" then
                return tbl, i+1
            end
            local k; k, i = DeserializeValue(s, i)
            local v; v, i = DeserializeValue(s, i)
            if k ~= nil then
                tbl[k] = v
            end
        end
        return tbl, #s+1
    end
    return nil, #s+1
end

local function DeserializeTable(s)
    if type(s) ~= "string" or s == "" then return nil end
    local v, idx = DeserializeValue(s, 1)
    if idx <= #s then
    end
    if type(v) ~= "table" then return nil end
    return v
end

function PCB:ExportProfile(profileName)
    self:InitDB()
    local name = profileName or self.dbRoot and self.dbRoot._activeProfile or "Default"
    if not self.dbRoot or not self.dbRoot.profiles or not self.dbRoot.profiles[name] then return nil end
    local payload = {
        schema = DB_SCHEMA_VERSION,
        profile = name,
        data = self.dbRoot.profiles[name],
    }
    return "PCBPROFILE1|" .. SerializeTable(payload)
end

function PCB:ImportProfile(str, newName)
    self:InitDB()
    if type(str) ~= "string" then return false, "Invalid import string." end
    local prefix, body = str:match("^(PCBPROFILE1|PCBPROFILE0)%|(.*)$")
    if not prefix or not body then return false, "Invalid import string." end
    local payload = DeserializeTable(body)
    if not payload or type(payload.data) ~= "table" then return false, "Import data could not be parsed." end
    local name = newName or payload.profile or "Imported"
    name = tostring(name):sub(1, 32)
    self.dbRoot.profiles[name] = payload.data
    return true, name
end

function PCB:SetProfileMode(mode)
    self:InitDB()
    if mode ~= "character" and mode ~= "spec" then return end
    self.dbRoot.profileMode = mode
    self:SelectActiveProfile()
end

function PCB:GetProfileMode()
    self:InitDB()
    return self.dbRoot.profileMode or "character"
end

function PCB:EnsureProfile(name)
    self.dbRoot.profiles[name] = self.dbRoot.profiles[name] or deepcopy(defaults)
end

function PCB:GetActiveProfileName()
    self:InitDB()
    return self.dbRoot._activeProfile or "Default"
end

function PCB:SetActiveProfileName(name)
    self:InitDB()
    if not self.dbRoot.profiles[name] then return end
    local charKey = GetCharKey()
    self.dbRoot.chars[charKey] = self.dbRoot.chars[charKey] or { profile = "Default", specProfiles = {} }
    local c = self.dbRoot.chars[charKey]
    if self:GetProfileMode() == "spec" then
        local specID = GetCurrentSpecID()
        if specID then
            c.specProfiles[specID] = name
        else
            c.profile = name
        end
    else
        c.profile = name
    end
    self:SelectActiveProfile()
end

function PCB:ResetProfile()
    self:InitDB()
    local profileName = self:GetActiveProfileName()
    if profileName then
        self.dbRoot.profiles[profileName] = deepcopy(defaults)
        self:SelectActiveProfile()
        self:ApplyAll()
    end
end

function PCB:SelectActiveProfile()
    local charKey = GetCharKey()
    self.dbRoot.chars[charKey] = self.dbRoot.chars[charKey] or { profile = "Default", specProfiles = {} }
    local c = self.dbRoot.chars[charKey]
    local mode = self:GetProfileMode()
    local profileName = c.profile or "Default"
    if mode == "spec" then
        local specID = GetCurrentSpecID()
        if specID and c.specProfiles and c.specProfiles[specID] then
            profileName = c.specProfiles[specID]
        end
    end
    if not self.dbRoot.profiles[profileName] then
        profileName = "Default"
        self:EnsureProfile(profileName)
    end
    self.dbRoot._activeProfile = profileName
    self.db = self.dbRoot.profiles[profileName]
end

-- =====================================================================
-- Media Registration (LibSharedMedia)
-- =====================================================================
-- Registers custom textures/fonts so they appear in LSM dropdowns
function PCB:RegisterMedia()
    if not self.LSM or not self.LSM.Register then return end

    -- Register custom textures
    self.LSM:Register("statusbar", "Phoenix CastBar", "Interface\\AddOns\\PhoenixCastBars\\Media\\Phoenix_CastBar.blp")
    self.LSM:Register("statusbar", "Phoenix Feather", "Interface\\AddOns\\PhoenixCastBars\\Media\\Phoenix_Feather.blp")

    -- Refresh when new media is registered by other addons
    self.LSM.RegisterCallback(self, "LibSharedMedia_Registered", function(_, mediatype)
        if mediatype == "statusbar" or mediatype == "font" then
            if self.ApplyAll then
                self:ApplyAll()
            end
        end
    end)
end

-- =====================================================================
-- Saved Variables / DB Initialization
-- =====================================================================
-- Handles schema migration and per-profile defaults
-- Migrates from old flat structure to new profile-based structure
function PCB:InitDB()
if self._initDB then return end  -- Guard against double initialization
self._initDB = true
    -- Migrate legacy flat DB into profile schema
    -- First-time users or corrupted SavedVariables
    if type(PhoenixCastBarsDB) ~= "table" then
        PhoenixCastBarsDB = { schema = DB_SCHEMA_VERSION, profileMode = "character", profiles = { Default = deepcopy(defaults) }, chars = {} }
    end

    PhoenixCastBarsDB.schema = PhoenixCastBarsDB.schema or DB_SCHEMA_VERSION
    PhoenixCastBarsDB.profiles = PhoenixCastBarsDB.profiles or { Default = deepcopy(defaults) }
    PhoenixCastBarsDB.chars = PhoenixCastBarsDB.chars or {}
    -- Ensure Default profile exists and has defaults merged
    PhoenixCastBarsDB.profiles.Default = PhoenixCastBarsDB.profiles.Default or deepcopy(defaults)
    mergeDefaults(PhoenixCastBarsDB.profiles.Default, defaults)
    self.dbRoot = PhoenixCastBarsDB
    self:SelectActiveProfile()
    -- Migrate old path-based keys inside active profile
    local db = self.db
    if db.texture and not db.textureKey then
        if type(db.texture) == "string" and (db.texture:find("\\") or db.texture:find("/")) then
            db.textureKey = "Custom"; db.texturePath = db.texture
        else
            db.textureKey = db.texture
        end
    end
    if db.font and not db.fontKey then
        if type(db.font) == "string" and (db.font:find("\\") or db.font:find("/")) then
            db.fontKey = "Custom"; db.fontPath = db.font
        else
            db.fontKey = db.font
        end
    end
    db.textureKey = db.textureKey or "Blizzard"
    db.fontKey    = db.fontKey or "Friz Quadrata (Default)"
    db.texturePath = db.texturePath or "Interface\\TARGETINGFRAME\\UI-StatusBar"
    db.fontPath    = db.fontPath or "Fonts\\FRIZQT__.TTF"
    db.texture = (db.textureKey == "Custom") and db.texturePath or db.textureKey
    db.font    = (db.fontKey == "Custom") and db.fontPath or db.fontKey
    self._initDB = false

end

-- Converts a color table {r,g,b,a} into individual values with defaults
function PCB:ColorFromTable(t)
    return t.r or 1, t.g or 1, t.b or 1, t.a or 1
end

-- Apply current font settings (font path, size, outline) to a FontString
function PCB:ApplyFont(fs)
    if not fs then return end
    local db = self.db
    local flags = db.outline or "OUTLINE"
    if flags == "NONE" then flags = "" end
    fs:SetFont(db.font, db.fontSize, flags)
end

-- Create a minimap button using LibDataBroker + LibDBIcon
function PCB:CreateMinimapButton()
    if not self.LDBIcon then
        self:Print("LibDBIcon not loaded - minimap button unavailable")
        return
    end
    
    -- Create LibDataBroker data object
    local LDB = LibStub("LibDataBroker-1.1", true)
    if not LDB then
        self:Print("LibDataBroker not loaded - minimap button unavailable")
        return
    end
    
    self.minimapLDB = LDB:NewDataObject("PhoenixCastBars", {
        type = "launcher",
        text = "PhoenixCastBars",
        icon = "Interface\\AddOns\\PhoenixCastBars\\Media\\Phoenix_Addon_Logo.blp",
        OnClick = function(_, button)
            if button == "LeftButton" then
                if PCB.Options and PCB.Options.Open then
                    PCB.Options:Open()
                end
            elseif button == "RightButton" then
                PCB.db.locked = not PCB.db.locked
                PCB:ApplyAll()
                PCB:Print(PCB.db.locked and "Frames locked." or "Frames unlocked. Drag to move.")
            end
        end,
        OnTooltipShow = function(tooltip)
            if not tooltip or not tooltip.AddLine then return end
            tooltip:SetText("PhoenixCastBars", 1, 1, 1)
            tooltip:AddLine("Left-click to open options", 0.2, 1, 0.2)
            tooltip:AddLine("Right-click to toggle lock", 0.2, 1, 0.2)
        end,
    })
    
    -- Register with LibDBIcon
    self.LDBIcon:Register("PhoenixCastBars", self.minimapLDB, self.db.minimapButton)
    self:UpdateMinimapButton()
end

-- Show/hide the minimap button based on saved settings
function PCB:UpdateMinimapButton()
    if not self.LDBIcon then return end
    
    if self.db and self.db.minimapButton and self.db.minimapButton.show then
        self.LDBIcon:Show("PhoenixCastBars")
    else
        self.LDBIcon:Hide("PhoenixCastBars")
    end
end

-- =====================================================================
-- Slash Commands
-- =====================================================================
-- /pcb lock | unlock | config
local function SlashHandler(msg)
    msg = strtrim(strlower(msg or ""))
    if msg == "lock" or msg == "locked" then
        PCB.db.locked = true
        if PCB.ApplyAll then
            PCB:ApplyAll()
        end
        PCB:Print("Frames locked.")
    elseif msg == "unlock" then
        PCB.db.locked = false
        if PCB.ApplyAll then
            PCB:ApplyAll()
        end
        PCB:Print("Frames unlocked. Drag to move.")
    elseif msg == "reset" then
        PhoenixCastBarsDB = nil
        ReloadUI()
    elseif msg == "resetpos" or msg == "resetpositions" then
        if PCB.ResetPositions then
            PCB:ResetPositions()
            PCB:Print("All cast bar positions reset to defaults.")
        end
    elseif msg == "test" then
        if PCB.SetTestMode then
            local newState = not PCB.testMode
            PCB:SetTestMode(newState)
            PCB:Print(newState and "Test mode enabled" or "Test mode disabled")
        end
    elseif msg == "media" then
        if PCB.LSM then
            PCB:Print("Available textures:")
            for _, name in ipairs(PCB.LSM:List("statusbar")) do
                PCB:Print("  - " .. name)
            end
            PCB:Print("Available fonts:")
            for _, name in ipairs(PCB.LSM:List("font")) do
                PCB:Print("  - " .. name)
            end
        else
            PCB:Print("LibSharedMedia not loaded")
        end
    elseif msg == "list" then
        -- Diagnostic: Lists addon registration info for troubleshooting
        local num = GetNumAddOns()
        PCB:Print(("GetNumAddOns() = %d"):format(num))
        for i = 1, num do
            local name, title = GetAddOnInfo(i)
            if name == ADDON_NAME or title == ADDON_NAME or title == "PhoenixCastBars" then
                PCB:Print(("Found at index %d: name=%s title=%s"):format(i, tostring(name), tostring(title)))
            end
        end
        local title = GetAddOnMetadata(ADDON_NAME, "Title") or "<nil>"
        local interface = GetAddOnMetadata(ADDON_NAME, "Interface") or "<nil>"
        PCB:Print(("Metadata: Title=%s Interface=%s"):format(title, interface))
    else
        if PCB.Options and PCB.Options.Open then
            PCB.Options:Open()
        else
            PCB:Print("Options UI failed to open. It may not be loaded yet.")
        end
    end
end

SLASH_PHOENIXCASTBARS1 = "/pcb"
SlashCmdList["PHOENIXCASTBARS"] = SlashHandler

-- Bootstrap
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        PCB:InitDB()
        PCB:RegisterMedia()
    elseif event == "PLAYER_LOGIN" then
        -- Authoritatively suppress Blizzard target spellbar visuals while PCB target bar is enabled.
        -- This prevents Blizzard creating/showing mirrored/extra target cast bars (e.g. when target == player).
        if not PCB._blizzTargetHooked and _G.TargetFrameSpellBar_Update then
            PCB._blizzTargetHooked = true
            local orig = _TargetFrameSpellBar_Update

            _G.TargetFrameSpellBar_Update = function(...)
                if PCB:ShouldSuppressAllTargetBlizzardBars() then
                    local spellbar = (TargetFrame and TargetFrame.spellbar) or _G.TargetFrameSpellBar
                    if spellbar then
                        spellbar:SetAlpha(0)
                        spellbar:Hide()
                    end
                    return
                end
                -- If we previously hid the spellbar while PCB target bar was enabled, its alpha can remain 0.
                -- When the user disables the PCB target bar, we must restore alpha so Blizzard can show it again.
                do
                    local spellbar = (TargetFrame and TargetFrame.spellbar) or _G.TargetFrameSpellBar
                    if spellbar then
                        spellbar:SetAlpha(1)
                    end
                end
                if orig then
                    return orig(...)
                end
            end
        end

        
        -- Suppress Blizzard nameplate cast bars for the current target when PCB target bar is enabled.
        if not PCB._nameplateCastHooked and hooksecurefunc then
            PCB._nameplateCastHooked = true
            local function OnNamePlateAdded(unitFrame)
                local frame = unitFrame
                if type(frame) ~= "table" then return end

                -- Different builds use different field names
                local castBar = frame.castBar or frame.CastBar or (frame.UnitFrame and (frame.UnitFrame.castBar or frame.UnitFrame.CastBar))
                if not castBar or castBar._pcbHooked then return end
                castBar._pcbHooked = true

                castBar:HookScript("OnShow", function(bar)
                    local unit = frame.unit
                    if PCB:ShouldSuppressNameplateCastbar(unit) then
                        bar:SetAlpha(0)
                        bar:Hide()
                    else
                        bar:SetAlpha(1)
                    end
                end)

                if castBar:IsShown() and PCB:ShouldSuppressNameplateCastbar(frame.unit) then
                    castBar:SetAlpha(0)
                    castBar:Hide()
                end
            end

            if _G.NamePlateUnitFrame_OnAdded then
                hooksecurefunc("NamePlateUnitFrame_OnAdded", OnNamePlateAdded)
            end
        end

        if PCB.UpdateCheck and PCB.UpdateCheck.Init then PCB.UpdateCheck:Init() end
        PCB:CreateBars()
        PCB:CreateMinimapButton()
        if PCB.Options and PCB.Options.Init then PCB.Options:Init() end
        PCB:ApplyAll()
        PCB:Print(("Loaded v%s. Type /pcb to open settings."):format(PCB.version))
    end
end)