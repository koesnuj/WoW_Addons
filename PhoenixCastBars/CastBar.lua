-- PhoenixCastBars - CastBar.lua
-- Handles cast bar creation, styling, positioning, and event handling

local ADDON_NAME, PCB = ...
PCB = PCB or {}
PCB.Bars = PCB.Bars or {}

local BAR_UNITS = { player = "player", target = "target", focus = "focus" }
local NAMEPLATE_MAX = 40
local POLL_INTERVAL = 0.10
local END_GRACE_SECONDS = 0.05
local TEXT_UPDATE_INTERVAL = 0.05

local DEFAULT_INTERPOLATION = (Enum and Enum.StatusBarTimerInterpolation and Enum.StatusBarTimerInterpolation.Linear) or nil
local DIR_ELAPSED = (Enum and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.ElapsedTime) or nil
local DIR_REMAINING = (Enum and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime) or nil

local EVENTS = {
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_SENT",
    "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "UNIT_SPELLCAST_EMPOWER_START",
    "UNIT_SPELLCAST_EMPOWER_UPDATE",
    "UNIT_SPELLCAST_EMPOWER_STOP",
    "PLAYER_TARGET_CHANGED",
    "PLAYER_FOCUS_CHANGED",
    "PLAYER_ENTERING_WORLD",
    "VEHICLE_UPDATE",
}

local STOP_EVENTS = {
    UNIT_SPELLCAST_STOP = true,
    UNIT_SPELLCAST_FAILED = true,
    UNIT_SPELLCAST_INTERRUPTED = true,
    UNIT_SPELLCAST_CHANNEL_STOP = true,
    UNIT_SPELLCAST_EMPOWER_STOP = true,
}

function PCB:IsBarEnabled(key)
    local db = PCB.db
    local bdb = db and db.bars and db.bars[key]
    return not (bdb and bdb.enabled == false)
end

local function SafeNow()
    return GetTime()
end

local function SafeBoolTrue(v)
    local ok, r = pcall(function() return v == true end)
    return ok and r == true
end

local function SafeDivMsToSec(ms)
    local ok, r = pcall(function() return ms / 1000 end)
    if ok and type(r) == "number" then
        return r
    end
    return nil
end

local function TrySetTexture(texObj, texturePath)
    if not texObj then return end
    pcall(function() texObj:SetTexture(texturePath) end)
end

local function TrySetFont(fs, font, size, flags)
    if not fs then return end
    pcall(function() fs:SetFont(font, size, flags) end)
end

local function TrySetText(fs, s)
    if not fs then return end
    pcall(function() fs:SetText(s or "") end)
end

local function TrySetStatusBarTexture(sb, tex)
    if not sb then return end
    pcall(function() sb:SetStatusBarTexture(tex) end)
end

local function TrySetMinMax(sb, a, b)
    if not sb then return end
    pcall(function() sb:SetMinMaxValues(a, b) end)
end

local function TrySetValue(sb, v)
    if not sb then return end
    pcall(function() sb:SetValue(v) end)
end

local function TrySetTimerDuration(sb, durationObj, interpolation, direction)
    if not sb or not sb.SetTimerDuration then return false end
    local ok = pcall(function()
        if interpolation ~= nil and direction ~= nil then
            sb:SetTimerDuration(durationObj, interpolation, direction)
        elseif interpolation ~= nil then
            sb:SetTimerDuration(durationObj, interpolation)
        else
            sb:SetTimerDuration(durationObj)
        end
    end)
    return ok
end

local function LSMFetch(mediatype, key)
    if not key or key == "" then return nil end
    if PCB.LSM and PCB.LSM.Fetch then
        local ok, path = pcall(function() return PCB.LSM:Fetch(mediatype, key) end)
        if ok and type(path) == "string" and path ~= "" then
            return path
        end
    end
    return nil
end

local function IsPath(s)
    return type(s) == "string" and (s:find("\\") or s:find("/"))
end

local function ResolveGlobalTexturePath(db)
    local key = db.textureKey
    local path = db.texturePath

    if not key and type(db.texture) == "string" then
        if IsPath(db.texture) then
            key = "Custom"
            path = db.texture
        else
            key = db.texture
        end
    end

    key = key or "Blizzard"
    if key == "Custom" and IsPath(path) then
        return path
    end

    local fetched = LSMFetch("statusbar", key)
    if fetched then return fetched end

    if IsPath(key) then return key end

    return "Interface\\TARGETINGFRAME\\UI-StatusBar"
end

local function ResolveGlobalFontPath(db)
    local key = db.fontKey
    local path = db.fontPath

    if not key and type(db.font) == "string" then
        if IsPath(db.font) then
            key = "Custom"
            path = db.font
        else
            key = db.font
        end
    end

    key = key or "Friz Quadrata TT"
    if key == "Custom" and IsPath(path) then
        return path
    end

    local fetched = LSMFetch("font", key)
    if fetched then return fetched end

    if IsPath(key) then return key end

    return "Fonts\\FRIZQT__.TTF"
end

local function ResolvePerBarOverrides(db, bdb)
    local globalTex = ResolveGlobalTexturePath(db)
    local globalFont = ResolveGlobalFontPath(db)
    local globalSize = db.fontSize or 12
    local globalOutline = db.outline or "OUTLINE"

    local tex = globalTex
    local font = globalFont
    local size = globalSize
    local outline = globalOutline

    if bdb then
        if bdb.enableTextureOverride and bdb.textureKey then
            if bdb.textureKey == "Custom" and IsPath(bdb.texturePath) then
                tex = bdb.texturePath
            else
                tex = LSMFetch("statusbar", bdb.textureKey) or tex
            end
        end

        if bdb.enableFontOverride and bdb.fontKey then
            if bdb.fontKey == "Custom" and IsPath(bdb.fontPath) then
                font = bdb.fontPath
            else
                font = LSMFetch("font", bdb.fontKey) or font
            end
        end

        if bdb.enableFontSizeOverride and type(bdb.fontSize) == "number" then
            size = bdb.fontSize
        end

        if bdb.enableOutlineOverride and type(bdb.outline) == "string" then
            outline = bdb.outline
        end

        local ap = bdb.appearance
        if type(ap) == "table" then
            if ap.useGlobalTexture == false then
                if IsPath(ap.texture) then
                    tex = ap.texture
                elseif type(ap.texture) == "string" then
                    tex = LSMFetch("statusbar", ap.texture) or tex
                end
            end

            if ap.useGlobalFont == false then
                if IsPath(ap.font) then
                    font = ap.font
                elseif type(ap.font) == "string" then
                    font = LSMFetch("font", ap.font) or font
                end
            end

            if ap.useGlobalFontSize == false and type(ap.fontSize) == "number" then
                size = ap.fontSize
            end

            if ap.useGlobalOutline == false and type(ap.outline) == "string" then
                outline = ap.outline
            end
        end
    end

    if outline == "NONE" then outline = "" end
    return tex, font, size, outline
end

local function ResolveNameplateForUnit(unitToken)
    if not UnitExists(unitToken) then return unitToken end
    if not UnitIsEnemy("player", unitToken) then return unitToken end

    for i = 1, NAMEPLATE_MAX do
        local u = "nameplate" .. i
        if UnitExists(u) and UnitIsUnit(u, unitToken) then
            return u
        end
    end
    return unitToken
end

local function GetEffectiveUnit(f, unitHint)
    if f.key == "target" then
        if f._effectiveUnit and f._effectiveUnitActive then
            if UnitExists(f._effectiveUnit) and UnitExists("target") and UnitIsUnit(f._effectiveUnit, "target") then
                return f._effectiveUnit
            end
        end
        local u = ResolveNameplateForUnit("target")
        f._effectiveUnit = u
        return u
    elseif f.key == "focus" then
        if f._effectiveUnit and f._effectiveUnitActive then
            if UnitExists(f._effectiveUnit) and UnitExists("focus") and UnitIsUnit(f._effectiveUnit, "focus") then
                return f._effectiveUnit
            end
        end
        local u = ResolveNameplateForUnit("focus")
        f._effectiveUnit = u
        return u
    end

    if type(unitHint) == "string" and unitHint ~= "" then
        return unitHint
    end
    return BAR_UNITS[f.key] or "player"
end

local HAS_DURATION_API = type(UnitCastingDuration) == "function" and type(UnitChannelDuration) == "function"

local function GetDurationForUnit(unit, isChannel)
    if not HAS_DURATION_API then return nil end
    if isChannel then
        local ok, d = pcall(function() return UnitChannelDuration(unit) end)
        if ok then return d end
    else
        local ok, d = pcall(function() return UnitCastingDuration(unit) end)
        if ok then return d end
    end
    return nil
end

local function DurationRemainingSeconds(durationObj)
    if not durationObj then return nil end
    if not durationObj.EvaluateRemainingDuration then return nil end
    local ok, v = pcall(function() return durationObj:EvaluateRemainingDuration(nil) end)
    if ok and type(v) == "number" then
        return v
    end
    return nil
end

local function CreateBackdrop(parent)
    local bg = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    bg:SetPoint("TOPLEFT", parent, "TOPLEFT", -2, 2)
    bg:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 2, -2)
    bg:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    bg:SetBackdropColor(0.06, 0.06, 0.08, 0.85)
    bg:SetBackdropBorderColor(0.20, 0.20, 0.25, 0.95)
    return bg
end

local function CreateCastBarFrame(key)
    local container = CreateFrame("Frame", "PhoenixCastBars_Container_" .. key, UIParent)
    container:SetSize(260, 32)
    container:Hide()

    local f = CreateFrame("Frame", "PhoenixCastBars_" .. key, container)
    f:SetPoint("CENTER", container, "CENTER", 0, 0)
    f.key = key
    f.unit = BAR_UNITS[key]
    f.container = container
    f._latencySent = {}
    f._latency = 0
    f._pollElapsed = 0
    f._textElapsed = 0
    f._effectiveUnit = nil
    f._effectiveUnitActive = false
    f._endGraceUntil = nil
    f._state = nil

    f._stopCheckAt = nil
    f._stopUnit = nil

    f._localStartTime = nil
    f._localEndTime = nil
    f._localDuration = nil

    f.bg = CreateBackdrop(f)

    f.bar = CreateFrame("StatusBar", nil, f)
    f.bar:SetAllPoints(f)
    TrySetMinMax(f.bar, 0, 1)
    TrySetValue(f.bar, 0)

    f.bar.bgTex = f.bar:CreateTexture(nil, "BACKGROUND")
    f.bar.bgTex:SetAllPoints(f.bar)
    f.bar.bgTex:SetTexture("Interface\\Buttons\\WHITE8x8")
    f.bar.bgTex:SetVertexColor(0, 0, 0, 0.35)

    f.spark = f.bar:CreateTexture(nil, "OVERLAY")
    f.spark:SetTexture("Interface\\AddOns\\PhoenixCastBars\\Media\\phoenix_spark.blp")
    f.spark:SetWidth(4)
    f.spark:SetBlendMode("ADD")
    f.spark:SetAlpha(0.85)
    f.spark:Hide()

    f.safeZone = f.bar:CreateTexture(nil, "OVERLAY")
    f.safeZone:SetColorTexture(1, 0, 0, 0.35)
    f.safeZone:SetPoint("TOPRIGHT")
    f.safeZone:SetPoint("BOTTOMRIGHT")
    f.safeZone:Hide()

    f.icon = f:CreateTexture(nil, "OVERLAY")
    f.icon:SetPoint("RIGHT", f, "LEFT", -6, 0)
    f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    f.icon:Hide()

    -- Interrupt shield (Retail 12.x atlas)
    f.shield = f:CreateTexture(nil, "OVERLAY")
    f.shield:SetAllPoints(f.icon)
    f.shield:SetDrawLayer("OVERLAY", 7)

    -- Use Blizzard interrupt atlas
    f.shield:SetAtlas("nameplates-InterruptShield")

    f.shield:Hide()

    ----------------------------------------------------------------
    -- Empower stages for Evokers.
    ----------------------------------------------------------------
    f.empowerStages = {}
    for i = 1, 3 do
        local stageFrame = CreateFrame("Frame", nil, f)
        stageFrame:SetWidth(4)
        stageFrame:SetHeight(24)
        stageFrame:SetFrameStrata("HIGH")
        stageFrame:SetFrameLevel(f:GetFrameLevel() + 10)

        local stageTex = stageFrame:CreateTexture(nil, "OVERLAY")
        stageTex:SetAllPoints(stageFrame)
        stageTex:SetColorTexture(1, 1, 1, 1)

        stageFrame:Hide()
        f.empowerStages[i] = stageFrame
    end

    f.textOverlay = CreateFrame("Frame", nil, f)
    f.textOverlay:SetAllPoints(f)
    f.textOverlay:SetFrameLevel(f:GetFrameLevel() + 20)

    f.spellText = f.textOverlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.spellText:SetJustifyH("LEFT")
    f.spellText:SetPoint("LEFT", f.bar, "LEFT", 6, 0)

    f.timeText = f.textOverlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.timeText:SetJustifyH("RIGHT")
    f.timeText:SetPoint("RIGHT", f.bar, "RIGHT", -6, 0)

    f.dragText = f.textOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.dragText:SetPoint("CENTER", f, "CENTER", 0, 0)
    f.dragText:SetTextColor(1, 1, 1, 0.6)
    f.dragText:Hide()

    f.unlockLabel = f.textOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.unlockLabel:SetPoint("LEFT", f, "LEFT", 2, 1)
    f.unlockLabel:SetJustifyH("LEFT")
    f.unlockLabel:SetTextColor(0.95, 0.45, 0.10, 1)
    f.unlockLabel:Hide()

    container:SetMovable(true)
    container:SetClampedToScreen(true)
    container:SetClampRectInsets(0, 0, 0, 0)
    container:EnableMouse(false)
    container:RegisterForDrag()

    return f
end

local function UpdateVisualSizes(f)
    local h = f:GetHeight()
    if type(h) ~= "number" or h <= 0 then h = 16 end
    local w = f:GetWidth()
    if type(w) ~= "number" or w <= 0 then w = 260 end
    if f.container then
        f.container:SetSize(w, h)
    end
    if f.icon then
        f.icon:SetSize(h + 2, h + 2)
    end
    if f.spark then
        f.spark:SetHeight(h)
    end
end

local function ApplyIconOffsets(f)
    local db = PCB.db or {}
    local bdb = (db.bars and db.bars[f.key]) or {}
    local ox = (type(bdb.iconOffsetX) == "number") and bdb.iconOffsetX or -6
    local oy = (type(bdb.iconOffsetY) == "number") and bdb.iconOffsetY or 0
    if f.icon then
        f.icon:ClearAllPoints()
        f.icon:SetPoint("RIGHT", f, "LEFT", ox, oy)
    end
end

local function ApplyAppearance(f)
    local db = PCB.db or {}
    local bdb = (db.bars and db.bars[f.key]) or {}

    if f.container then
        f.container:ClearAllPoints()
        f.container:SetPoint(bdb.point or "CENTER", UIParent, bdb.relPoint or "CENTER", bdb.x or 0, bdb.y or 0)
        f.container:SetAlpha(bdb.alpha or 1)
    end

    f:SetSize(bdb.width or 240, bdb.height or 16)
    f:SetScale(bdb.scale or 1)

    UpdateVisualSizes(f)
    ApplyIconOffsets(f)

    local texPath, fontPath, fontSize, flags = ResolvePerBarOverrides(db, bdb)

    TrySetStatusBarTexture(f.bar, texPath)

    TrySetFont(f.spellText, fontPath, fontSize, flags)
    TrySetFont(f.timeText, fontPath, fontSize, flags)
    if f.dragText then
        TrySetFont(f.dragText, fontPath, fontSize + 2, flags)
    end
end

local function UpdateEmpowerStages(f)
    if not f.empowerStages then 
        return 
    end

    local st = f._state
    if not st or st.kind ~= "cast" then
        for i = 1, 3 do
            if f.empowerStages[i] then
                f.empowerStages[i]:Hide()
            end
        end
        return
    end

    local isEmpower = false
    if st.name then
        local ok, lowerName = pcall(function() return st.name:lower() end)
        if ok and lowerName then
            local ok2, hasEmpower = pcall(function() 
                return lowerName:find("empower") or 
                       lowerName:find("deep breath") or 
                       lowerName:find("fire breath") or 
                       lowerName:find("eternity surge") or
                       lowerName:find("dream breath") or
                       lowerName:find("spiritbloom") or
                       lowerName:find("tip the scales")
            end)
            if ok2 and hasEmpower then
                isEmpower = true
            end
        end
    end

    if not isEmpower then
        for i = 1, 3 do
            if f.empowerStages[i] then
                f.empowerStages[i]:Hide()
            end
        end
        return
    end

    local barWidth = f.bar:GetWidth()
    local barHeight = f.bar:GetHeight()
    if barWidth and barWidth > 0 and barHeight and barHeight > 0 then
        local positions = {0.25, 0.50, 0.75}
        for i = 1, 3 do
            local stage = f.empowerStages[i]
            if stage then
                stage:SetHeight(barHeight)
                stage:SetWidth(3)
                stage:ClearAllPoints()
                stage:SetPoint("CENTER", f.bar, "LEFT", barWidth * positions[i], 0)
                stage:Show()
            end
        end
    end

    if f.bar and st.startSec and st.endSec then
        local now = GetTime()
        local elapsed = now - st.startSec
        local duration = st.endSec - st.startSec
        local progress = duration > 0 and (elapsed / duration) or 0

        local r, g, b
        if progress < 0.25 then
            r, g, b = 0.9, 0.2, 0.2
        elseif progress < 0.50 then
            r, g, b = 1.0, 0.8, 0
        elseif progress < 0.75 then
            r, g, b = 0.2, 0.9, 0.2
        else
            r, g, b = 0.15, 0.45, 0.9
        end

        pcall(function() f.bar:SetStatusBarColor(r, g, b, 1) end)
    end
end

local function NormalizeColor(c, fallback)
    if type(c) ~= "table" then c = fallback end
    local r = (type(c.r) == "number") and c.r or (fallback and fallback.r) or 1
    local g = (type(c.g) == "number") and c.g or (fallback and fallback.g) or 1
    local b = (type(c.b) == "number") and c.b or (fallback and fallback.b) or 1
    local a = (type(c.a) == "number") and c.a or (fallback and fallback.a) or 1
    return r, g, b, a
end

local FALLBACK_CAST    = { r = 0.24, g = 0.56, b = 0.95, a = 1.0 }
local FALLBACK_CHANNEL = { r = 0.35, g = 0.90, b = 0.55, a = 1.0 }

local function ApplyCastBarColor(f)
    if not f or not f.bar or not f.bar.SetStatusBarColor then return end

    local db = PCB.db or {}
    local st = f._state
    if not st then return end

    -- Use notInterruptible from UnitCastingInfo/UnitChannelInfo directly
    -- (TargetFrameSpellBar.showShield is unreliable when Blizzard bar is suppressed)
    local okNI, rawShield = pcall(function() return st.notInterruptible == true end)
    local showShield = (okNI and rawShield or false)

    -- Colour override when not interruptible
    if showShield then
        f.bar:SetStatusBarColor(0.85, 0.15, 0.15, 1)
        return
    end

    -- Normal colour pipeline
    if st.kind == "channel" then
        local r, g, b, a = NormalizeColor(db.colorChannel, FALLBACK_CHANNEL)
        f.bar:SetStatusBarColor(r, g, b, a)
    else
        local r, g, b, a = NormalizeColor(db.colorCast, FALLBACK_CAST)
        f.bar:SetStatusBarColor(r, g, b, a)
    end
end

local function ResetState(f, forceHide)
    f._state = nil
    f._endGraceUntil = nil
    f._effectiveUnitActive = false
    f._textElapsed = 0

    f._stopCheckAt = nil
    f._stopUnit = nil

    f._localStartTime = nil
    f._localEndTime = nil
    f._localDuration = nil

    TrySetMinMax(f.bar, 0, 1)
    TrySetValue(f.bar, 0)

    TrySetText(f.timeText, "")
    TrySetText(f.spellText, "")

    TrySetTexture(f.icon, nil)
    f.icon:Hide()

    if f.spark then f.spark:Hide() end
    if f.empowerStages then
        for i = 1, 3 do
            if f.empowerStages[i] then f.empowerStages[i]:Hide() end
        end
    end

    if forceHide and PCB.db and PCB.db.locked and not f.isMover and not f.test then
        if f.container then f.container:Hide() end
        f:Hide()
    end
end

local function ApplySparkFromFillTexture(f)
    if not f.spark or not f.bar then return end

    local db = PCB.db or {}
    local bdb = (db.bars and db.bars[f.key]) or {}
    -- FIX: Check showSpark setting - default to true if not set
    if bdb.showSpark == false then
        f.spark:Hide()
        return
    end

    local tex = nil
    local ok = pcall(function() tex = f.bar:GetStatusBarTexture() end)
    if not ok or not tex then
        f.spark:Hide()
        return
    end

    local isShown = true
    pcall(function() isShown = tex:IsShown() end)
    if not isShown then
        f.spark:Hide()
        return
    end

    local anchor = "RIGHT"
    f.spark:ClearAllPoints()
    f.spark:SetPoint("CENTER", tex, anchor, 0, 0)
    f.spark:Show()
end

local function EnsureVisible(f)
    if f.container and not f.container:IsShown() then f.container:Show() end
    if not f:IsShown() then f:Show() end
end

local function SetIcon(f, texture)
    local db = PCB.db or {}
    local bdb = (db.bars and db.bars[f.key]) or {}
    -- FIX: Check showIcon setting - default to true if not set (nil means enabled by default)
    if bdb.showIcon == false then
        TrySetTexture(f.icon, nil)
        f.icon:Hide()
        return
    end
    if texture ~= nil then
        TrySetTexture(f.icon, texture)
        f.icon:Show()
    else
        TrySetTexture(f.icon, nil)
        f.icon:Hide()
    end
end

local function SetTexts(f, name, remainingSeconds)
    local db = PCB.db or {}
    local bdb = (db.bars and db.bars[f.key]) or {}

    -- FIX: Check showSpellName setting - default to true if not set
    if bdb.showSpellName == false then
        TrySetText(f.spellText, "")
    else
        TrySetText(f.spellText, name or "")
    end

    -- FIX: Check showTime setting - default to false if not set
    if bdb.showTime ~= true then
        TrySetText(f.timeText, "")
        return
    end

    if type(remainingSeconds) == "number" then
        pcall(function() f.timeText:SetFormattedText("%.1f", remainingSeconds) end)
    else
        TrySetText(f.timeText, "")
    end
end

local function ArmStopCheck(f, unitHint)
    f._stopUnit = unitHint or f.unit
    f._stopCheckAt = SafeNow() + END_GRACE_SECONDS
end

local function VerifyAndStopIfInactive(f)
    if not f._stopCheckAt then return end
    local now = SafeNow()
    if now < f._stopCheckAt then return end

    f._stopCheckAt = nil
    local unit = GetEffectiveUnit(f, f._stopUnit)
    f._stopUnit = nil

    if UnitCastingInfo(unit) ~= nil then return end
    if UnitChannelInfo(unit) ~= nil then return end

    ResetState(f, true)
end

local FrameOnUpdate

local function ReadUnitCast(unit)

    local name, _, texture, startMS, endMS, _, _, notInterruptCast = UnitCastingInfo(unit)
    local kind = "cast"
    local notInterruptible = notInterruptCast

    if not name then
        local cName, _, cTex, cStartMS, cEndMS, _, notInterruptChannel = UnitChannelInfo(unit)
        name = cName
        texture = cTex
        startMS = cStartMS
        endMS = cEndMS
        notInterruptible = notInterruptChannel
        if name then
            kind = "channel"
        end
    end

    if not name or not startMS or not endMS then
        return nil
    end

    if kind == "channel" and name then
        local ok, lowerName = pcall(function() return name:lower() end)
        if ok and lowerName then
            local ok2, isEmpowerSpell = pcall(function()
                return lowerName:find("empower") or 
                       lowerName:find("deep breath") or 
                       lowerName:find("fire breath") or 
                       lowerName:find("eternity surge") or
                       lowerName:find("dream breath") or
                       lowerName:find("spiritbloom") or
                       lowerName:find("tip the scales")
            end)
            if ok2 and isEmpowerSpell then
                kind = "cast"
            end
        end
    end

    local durationObj = nil
    if HAS_DURATION_API then
        durationObj = GetDurationForUnit(unit, (kind == "channel")) or GetDurationForUnit(unit, false)
    end

    local ok, isNI = pcall(function() return notInterruptible == true end)
    return kind, name, texture, SafeDivMsToSec(startMS), SafeDivMsToSec(endMS), (ok and isNI or false), durationObj
end

local function ConfigureStatusBarForState(f)
    local st = f._state
    if not st or not f.bar then return end

    local dur = nil

    if st.startSec and st.endSec then
        local d = st.endSec - st.startSec
        if type(d) == "number" and d > 0 then
            dur = d
        end
    end

    if not dur and st.unit then
        local unit = st.unit
        if st.kind == "channel" then
            local name, _, _, startMS, endMS = UnitChannelInfo(unit)
            if name and startMS and endMS then
                local d = (endMS - startMS) / 1000
                if type(d) == "number" and d > 0 then
                    dur = d
                end
            end
        else
            local name, _, _, startMS, endMS = UnitCastingInfo(unit)
            if name and startMS and endMS then
                local d = (endMS - startMS) / 1000
                if type(d) == "number" and d > 0 then
                    dur = d
                end
            end
        end
    end

    if type(dur) ~= "number" or dur <= 0 then
        if st.kind == "channel" then
            dur = 3.0
        else
            dur = 1.5
        end
    end

    st.durationSec = dur

    local useDuration = (st.durationObj and f.bar.SetTimerDuration)

    if useDuration and st.kind == "cast" then
        TrySetMinMax(f.bar, 0, 1)
        TrySetValue(f.bar, 0)

        if not TrySetTimerDuration(f.bar, st.durationObj, DEFAULT_INTERPOLATION, DIR_ELAPSED) then
            st.durationObj = nil
            useDuration = false
        end
    else
        useDuration = false
        st.durationObj = nil
    end

    if not useDuration then
        TrySetMinMax(f.bar, 0, dur)
        if st.kind == "channel" then
            TrySetValue(f.bar, dur)
        else
            TrySetValue(f.bar, 0)
        end
    end
end

local function StartOrRefreshFromUnit(f, unitHint)
    local unit = GetEffectiveUnit(f, unitHint)

    local kind, name, texture, startSec, endSec, notInterruptible, durationObj = ReadUnitCast(unit)
    if not kind then
        return false
    end

    if (f.key == "target" or f.key == "focus") and unit ~= BAR_UNITS[f.key] then
        f._effectiveUnitActive = true
        f._effectiveUnit = unit
    end

    f._stopCheckAt = nil
    f._stopUnit = nil

    if not f._state then ApplyAppearance(f) end
    ApplyCastBarColor(f)
    SetIcon(f, texture)

    local st = f._state or {}
    f._state = st

    st.kind = kind
    st.unit = unit
    st.name = name
    st.texture = texture
    st.startSec = startSec
    st.endSec = endSec
    st.durationObj = durationObj
    st.durationSec = nil
    st.notInterruptible = notInterruptible

    -- FIX: Respect showSpellName setting when setting initial text
    local db = PCB.db or {}
    local bdb = (db.bars and db.bars[f.key]) or {}
    if f.spellText then
        if bdb.showSpellName ~= false then
            f.spellText:SetText(name or "")
        else
            f.spellText:SetText("")
        end
    end

    ConfigureStatusBarForState(f)

    local initialElapsed = 0
    if st.kind == "channel" and st.unit then
        local name, _, _, startMS, endMS = UnitChannelInfo(st.unit)
        if name and startMS and endMS then
            local nowMs = GetTime() * 1000
            local apiElapsed = (nowMs - startMS) / 1000
            if apiElapsed > 0 and apiElapsed < st.durationSec then
                initialElapsed = apiElapsed
            end
        end
    end

    st._localDuration = st.durationSec
    st._localStartTime = SafeNow() - initialElapsed
    st._localEndTime = st._localStartTime + st._localDuration

    f._pollElapsed = 0
    f._textElapsed = 0
    f._endGraceUntil = nil

    if f.container then f.container:Show() end
    f:Show()
    f:SetScript("OnUpdate", FrameOnUpdate)

    return true
end

local function ShouldStillBeCasting(unit)
    if UnitCastingInfo(unit) ~= nil then return true end
    if UnitChannelInfo(unit) ~= nil then return true end
    return false
end

local function StopIfReallyStopped(f, unitHint)
    if not f or not f._state then return end
    local st = f._state
    local unit = GetEffectiveUnit(f, unitHint or st.unit)

    local now = SafeNow()
    if f._endGraceUntil and now < f._endGraceUntil then
        return
    end

    if ShouldStillBeCasting(unit) then
        return
    end

    ResetState(f, true)
end

local function RefreshFrame(f, unitHint)
    if not f then return end
    if f.key and not PCB:IsBarEnabled(f.key) then
        ResetState(f, true)
        return
    end
    local unit = GetEffectiveUnit(f, unitHint)

    if not StartOrRefreshFromUnit(f, unit) then
        if f._state then
            f._endGraceUntil = SafeNow() + END_GRACE_SECONDS
            StopIfReallyStopped(f, unit)
        else
            ResetState(f, true)
        end
    end
end

FrameOnUpdate = function(f, elapsed)
    if not f then return end

    if VerifyAndStopIfInactive then
        VerifyAndStopIfInactive(f)
    end

    if not f._state then
        f:SetScript("OnUpdate", nil)
        return
    end

    local st = f._state
    local now = SafeNow()

    f._pollElapsed = (f._pollElapsed or 0) + (elapsed or 0)
    if f._pollElapsed >= POLL_INTERVAL then
        f._pollElapsed = 0

        if f.key == "target" then
            local u = GetEffectiveUnit(f, "target")
            if u ~= st.unit then
                StartOrRefreshFromUnit(f, u)
                return
            end
        elseif f.key == "focus" then
            local u = GetEffectiveUnit(f, "focus")
            if u ~= st.unit then
                StartOrRefreshFromUnit(f, u)
                return
            end
        end

        do
            local pollUnit = GetEffectiveUnit(f, st.unit)
            if not ShouldStillBeCasting(pollUnit) and not f._endGraceUntil then
                f._endGraceUntil = SafeNow() + END_GRACE_SECONDS * 3
            end
            StopIfReallyStopped(f, pollUnit)
        end
    end

    local remaining, elapsedSec

    if st.kind == "channel" then
        local apiRemaining, apiElapsed, apiValid = nil, nil, false

        if st.startSec and st.endSec then
            local r = st.endSec - now
            local e = now - st.startSec
            if type(r) == "number" and r >= -1 and r <= (st.durationSec or 999) then
                apiRemaining = r
            end
            if type(e) == "number" and e >= -1 and e <= (st.durationSec or 999) then
                apiElapsed = e
            end
            if apiRemaining and apiElapsed and apiRemaining >= 0 and apiElapsed >= 0 then
                apiValid = true
            end
        end

        if not st._localStartTime or not st._localDuration then
            if apiValid and apiRemaining > 0 then
                st._localStartTime = now - apiElapsed
                st._localDuration = apiElapsed + apiRemaining
                st._localEndTime = st._localStartTime + st._localDuration
            elseif st.durationSec and st.durationSec > 0 then
                st._localDuration = st.durationSec
                st._localStartTime = now
                st._localEndTime = now + st._localDuration
            else
                st._localDuration = 3.0
                st._localStartTime = now
                st._localEndTime = now + st._localDuration
            end
        elseif apiValid then
            local localElapsed = now - st._localStartTime
            local localRemaining = st._localEndTime - now
            local drift = math.abs(localRemaining - apiRemaining)

            if drift > 0.5 and apiRemaining > 0 then
                st._localStartTime = now - apiElapsed
                st._localEndTime = st._localStartTime + (apiElapsed + apiRemaining)
            end
        end

        elapsedSec = now - st._localStartTime
        remaining = st._localEndTime - now

        if remaining < 0 then remaining = 0 end
        if remaining > (st._localDuration or 999) then remaining = st._localDuration or 0 end
        if elapsedSec < 0 then elapsedSec = 0 end
        if elapsedSec > (st._localDuration or 0) then elapsedSec = st._localDuration or 0 end

    elseif st.durationObj and st.durationObj.GetRemainingDuration then
        remaining = st.durationObj:GetRemainingDuration()
        if type(remaining) ~= "number" then remaining = nil end
        if st.durationObj.GetElapsedDuration then
            elapsedSec = st.durationObj:GetElapsedDuration()
            if type(elapsedSec) ~= "number" then elapsedSec = nil end
        end

        if (type(remaining) ~= "number" or type(elapsedSec) ~= "number") and st.startSec and st.endSec then
            local r = st.endSec - now
            local e = now - st.startSec
            remaining = type(r) == "number" and r or remaining
            elapsedSec = type(e) == "number" and e or elapsedSec
        end
    elseif st.startSec and st.endSec then
        local r = st.endSec - now
        local e = now - st.startSec
        remaining = type(r) == "number" and r or nil
        elapsedSec = type(e) == "number" and e or nil
    end

    local hasRemaining = type(remaining) == "number"
    local hasElapsed = type(elapsedSec) == "number"

    if not hasRemaining and not hasElapsed then
        StopIfReallyStopped(f, st.unit)
        return
    end

    if not hasRemaining then remaining = 0 end
    if not hasElapsed then elapsedSec = 0 end

    if not (st.durationObj and f.bar and f.bar.SetTimerDuration) then
        local dur = st.durationSec or 1
        remaining = math.max(0, math.min(remaining, dur))
        elapsedSec = math.max(0, math.min(elapsedSec, dur))

        if st.kind == "channel" then
            TrySetValue(f.bar, remaining)
        else
            TrySetValue(f.bar, elapsedSec)
        end
    end

    -- FIX: Check showLatency setting before showing safeZone (latency indicator)
    local db = PCB.db or {}
    local bdb = (db.bars and db.bars[f.key]) or {}
    if f.key == "player" and f._latency and f._latency > 0 and st.durationSec and st.durationSec > 0 then
        if bdb.showLatency ~= false then  -- Default to showing latency unless explicitly disabled
            local latency = math.min(f._latency, st.durationSec)
            local ratio = latency / st.durationSec
            local width = f.bar:GetWidth()

            f.safeZone:SetWidth(width * ratio)
            f.safeZone:Show()
        else
            f.safeZone:Hide()
        end
    else
        f.safeZone:Hide()
    end

    if st.kind == "cast" then
        UpdateEmpowerStages(f)
    end

    -- =====================================================
    -- Interrupt Shield Display (Target/Focus, from API)
    -- =====================================================
    -- Use st.notInterruptible from UnitCastingInfo/UnitChannelInfo directly.
    -- TargetFrameSpellBar.showShield is unreliable when Blizzard bar is suppressed by PCB.
    if (f.key == "target" or f.key == "focus") and f.shield and f.icon then
        local okNI, rawShield = pcall(function() return st.notInterruptible == true end)
        local showShield = (okNI and rawShield or false)

        if showShield then
            if f.icon:IsShown() then
                f.icon:Hide()
            end
            if not f.shield:IsShown() then
                f.shield:Show()
            end
        else
            if f.shield:IsShown() then
                f.shield:Hide()
            end
            -- Only re-show icon if showIcon setting is enabled
            if bdb.showIcon ~= false and not f.icon:IsShown() then
                f.icon:Show()
            end
        end
    end

    -- FIX: Check showSpark setting before showing spark
    if f.spark and f.bar and f.bar.GetStatusBarTexture then
        if bdb.showSpark ~= false then  -- Default to showing spark unless explicitly disabled
            local tex = f.bar:GetStatusBarTexture()
            if tex then
                f.spark:ClearAllPoints()
                f.spark:SetPoint("CENTER", tex, "RIGHT", 0, 0)
                f.spark:Show()
            end
        else
            f.spark:Hide()
        end
    end

    -- FIX: Only update time text if showTime is enabled
    f._textElapsed = (f._textElapsed or 0) + (elapsed or 0)
    if f._textElapsed >= TEXT_UPDATE_INTERVAL then
        f._textElapsed = 0
        if f.timeText then
            -- Check showTime setting - default to false if not explicitly enabled
            if bdb.showTime == true then
                f.timeText:SetText(string.format("%.1f", remaining))
            else
                f.timeText:SetText("")
            end
        end
    end
end

local function Round(n)
    if type(n) ~= "number" then return 0 end
    if n >= 0 then
        return math.floor(n + 0.5)
    end
    return math.ceil(n - 0.5)
end

function PCB:SaveBarPosition(f)
    if not f or not f.key or not self.db then return end
    self.db.bars = self.db.bars or {}
    self.db.bars[f.key] = self.db.bars[f.key] or {}
    local bdb = self.db.bars[f.key]

    local frameToCheck = f.container or f
    local point, relTo, relPoint, x, y = frameToCheck:GetPoint(1)
    if not point then return end

    bdb.point = point
    bdb.relPoint = relPoint or point
    bdb.x = Round(x)
    bdb.y = Round(y)
end

local function EnableDragging(f)
    if not f or f._dragEnabled then return end
    f._dragEnabled = true

    local dragFrame = f.container or f
    dragFrame:EnableMouse(true)
    dragFrame:RegisterForDrag("LeftButton")

    dragFrame:SetScript("OnDragStart", function(self)
        if PCB.db and PCB.db.locked then return end
        pcall(function() self:StopMovingOrSizing() end)
        pcall(function() self:StartMoving() end)
    end)

    dragFrame:SetScript("OnDragStop", function(self)
        pcall(function() self:StopMovingOrSizing() end)
        if PCB and PCB.SaveBarPosition then
            PCB:SaveBarPosition(f)
        end
    end)
end

local function DisableDragging(f)
    if not f or not f._dragEnabled then return end
    f._dragEnabled = nil

    local dragFrame = f.container or f
    dragFrame:RegisterForDrag()
    dragFrame:EnableMouse(false)
    dragFrame:SetScript("OnDragStart", nil)
    dragFrame:SetScript("OnDragStop", nil)
end

local function ShowMover(f)
    f.isMover = true
    if f.container then f.container:Show() end
    f:Show()
    TrySetMinMax(f.bar, 0, 1)
    TrySetValue(f.bar, 0.75)
    TrySetText(f.spellText, "")
    TrySetText(f.timeText, "")
    f.icon:Hide()

    if f.spark then f.spark:Hide() end
    if f.dragText then
        f.dragText:SetText("Drag to move")
        f.dragText:Show()
    end

    if f.unlockLabel then
        local label
        if f.key == "player" then
            label = "Player"
        elseif f.key == "target" then
            label = "Target"
        elseif f.key == "focus" then
            label = "Focus"
        else
            label = tostring(f.key or "Cast Bar")
        end
        f.unlockLabel:SetText(label)
        f.unlockLabel:Show()
    end

    ApplyCastBarColor(f)
end

local function HideMover(f)
    f.isMover = false
    if f.dragText then f.dragText:Hide() end
    if f.unlockLabel then f.unlockLabel:Hide() end
    if (PCB.db and PCB.db.locked) and not f._state and not f.test then
        if f.container then f.container:Hide() end
        f:Hide()
    end
end

function PCB:SetMoverMode(enabled)
    if not self.Bars then return end
    for _, f in pairs(self.Bars) do
        local key = f and f.key
        local barEnabled = (key and PCB:IsBarEnabled(key)) or true

        if enabled and barEnabled then
            ShowMover(f)
            EnableDragging(f)
        else
            DisableDragging(f)
            HideMover(f)
        end

        if not barEnabled then
            ResetState(f, true)
        end
    end
end

function PCB:SetTestMode(enabled)
    self.testMode = enabled and true or false
    if not self.Bars then return end

    for _, f in pairs(self.Bars) do
        local key = f and f.key
        if key and not PCB:IsBarEnabled(key) then
            ResetState(f, true)
        elseif self.testMode then
            f.test = true
            f._state = {
                kind = "cast",
                name = "Test Cast",
                texture = "Interface\\Icons\\INV_Misc_QuestionMark",
                durationObj = nil,
                startSec = SafeNow(),
                endSec = SafeNow() + 3.5,
            }
            SetIcon(f, f._state.texture)
            ApplyAppearance(f)
            ApplyCastBarColor(f)
            EnsureVisible(f)
            TrySetMinMax(f.bar, 0, 3.5)
            TrySetValue(f.bar, 1.0)
            SetTexts(f, f._state.name, 3.5)
            ApplySparkFromFillTexture(f)
        else
            f.test = nil
            ResetState(f, true)
        end
    end
end

PCB.ApplyAppearance = ApplyAppearance
PCB.ApplyCastBarColor = ApplyCastBarColor
PCB.FrameOnUpdate = FrameOnUpdate

function PCB:CreateBars()
    for key in pairs(BAR_UNITS) do
        if not self.Bars[key] then
            self.Bars[key] = CreateCastBarFrame(key)
            ApplyAppearance(self.Bars[key])
        end
    end

    if not self.Bars.gcd then
        self.Bars.gcd = CreateCastBarFrame("gcd")
        ApplyAppearance(self.Bars.gcd)
    end

    if not self.eventFrame then
        local ef = CreateFrame("Frame")
        for _, e in ipairs(EVENTS) do
            ef:RegisterEvent(e)
        end
        ef:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

        local function RefreshAllMatching(unitEvent)
            if not unitEvent then return end
            for key, f in pairs(self.Bars) do
                if f then
                    local eff = GetEffectiveUnit(f, key)
                    if unitEvent == f.unit or unitEvent == eff or unitEvent == f._effectiveUnit then
                        RefreshFrame(f, key)
                    end
                end
            end
        end

        ef:SetScript("OnEvent", function(_, event, unit, ...)
            if event == "PLAYER_TARGET_CHANGED" then
                local f = self.Bars.target
                if f then
                    f._effectiveUnit = nil
                    f._effectiveUnitActive = false
                    f._endGraceUntil = nil
                    ArmStopCheck(f, "target")
                    RefreshFrame(f, "target")
                end
                return
            end

            if event == "PLAYER_FOCUS_CHANGED" then
                local f = self.Bars.focus
                if f then
                    f._effectiveUnit = nil
                    f._effectiveUnitActive = false
                    f._endGraceUntil = nil
                    ArmStopCheck(f, "focus")
                    RefreshFrame(f, "focus")
                end
                return
            end

            if event == "PLAYER_ENTERING_WORLD" or event == "VEHICLE_UPDATE" then
                local f = self.Bars.player
                if f then
                    ArmStopCheck(f, "player")
                    RefreshFrame(f, "player")
                end
                local p = self.Bars.pet
                if p then
                    ArmStopCheck(p, "pet")
                    RefreshFrame(p, "pet")
                end
                return
            end

            if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" then
                local f = self.Bars.gcd
                if f and PCB and PCB.GCD and PCB.GCD.StartGCDBar then
                    PCB.GCD.StartGCDBar(f)
                end
            end

            if event == "UNIT_SPELLCAST_SENT" and unit == "player" then
                local castGUID = select(2, ...)  -- Get the 2nd vararg (castGUID)
                local f = self.Bars.player
                if f and castGUID and type(castGUID) == "string" then
                    f._latencySent[castGUID] = GetTime()
                end
                return
            end

            if event == "UNIT_SPELLCAST_START" and unit == "player" then
                local castGUID = ...
                local f = self.Bars.player
                if f and castGUID then
                    local sent = f._latencySent[castGUID]
                    if sent then
                        f._latency = GetTime() - sent
                        f._latencySent[castGUID] = nil
                    end
                end
            end

            if unit then
                RefreshAllMatching(unit)
            end
        end)

        self.eventFrame = ef

        for key, f in pairs(self.Bars) do
            if f and key ~= "gcd" then
                ArmStopCheck(f, key)
                RefreshFrame(f, key)
            end
        end
    end
end

function PCB:DestroyBars()
    if self.eventFrame then
        self.eventFrame:UnregisterAllEvents()
        self.eventFrame:SetScript("OnEvent", nil)
        self.eventFrame = nil
    end

    for key, f in pairs(self.Bars) do
        if f and f.Hide then
            f:Hide()
        end
        self.Bars[key] = nil
    end
end

function PCB:ApplyAll()
    if not self.Bars then return end

    for _, f in pairs(self.Bars) do
        local key = f and f.key
        if key and not PCB:IsBarEnabled(key) then
            ResetState(f, true)
        else
            ApplyAppearance(f)
            ApplyCastBarColor(f)

            if key == "gcd" and (not self.db.bars or not self.db.bars.gcd or not self.db.bars.gcd.enabled) then
                if f.container then f.container:Hide() end
                f:Hide()
            elseif self.db and self.db.locked and not f._state and not f.test and not f.isMover then
                if f.container then f.container:Hide() end
                f:Hide()
            end
        end
    end

    if not self.testMode and self.SetMoverMode then
        self:SetMoverMode(self.db and (not self.db.locked))
    end

    if PCB and PCB.UpdateBlizzardCastBars then
        PCB:UpdateBlizzardCastBars()
    end
end