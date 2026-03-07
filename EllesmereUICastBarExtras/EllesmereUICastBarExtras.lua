-------------------------------------------------------------------------------
--  EllesmereUICastBarExtras.lua
--
--  IMPORTANT: Spark and SafeZone are NOT registered as oUF sub-widgets
--  (castbar.Spark / castbar.SafeZone).  They are managed entirely by our
--  PostCastStart / PostCastStop hooks to avoid any interaction with oUF's
--  CastStart processing, which could prevent the castbar from showing.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...

local E = EllesmereUI
local ECBE = E.Lite.NewAddon(ADDON_NAME)

local db
local defaults = {
    profile = {
        enabled = true,
        spark = true,
        safeZone = true,
        smoothing = true,
        channelTicks = true,
        empoweredPips = true,
    },
}

-------------------------------------------------------------------------------
--  oUF frame names created by EllesmereUIUnitFrames
-------------------------------------------------------------------------------
local FRAME_UNITS = {
    { unit = "player", name = "EllesmereUIUnitFrames_Player" },
    { unit = "target", name = "EllesmereUIUnitFrames_Target" },
    { unit = "focus", name = "EllesmereUIUnitFrames_Focus" },
}

local enhancedCastbars = {}

-------------------------------------------------------------------------------
--  Channel tick data  (spellID -> base tick count)
-------------------------------------------------------------------------------
local CHANNEL_TICKS = {
    -- Priest
    [15407] = 4, -- Mind Flay
    [391403] = 4, -- Mind Flay: Insanity
    [263165] = 4, -- Void Torrent
    [64843] = 4, -- Divine Hymn
    [47540] = 3, -- Penance
    [373129] = 3, -- Dark Reprimand (Shadow Penance)
    -- Mage
    [5143] = 5, -- Arcane Missiles
    [12051] = 3, -- Evocation
    [205021] = 5, -- Ray of Frost
    -- Warlock
    [198590] = 6, -- Drain Soul
    [234153] = 5, -- Drain Life
    [755] = 5, -- Health Funnel
    [384069] = 3, -- Malefic Rapture (if channeled variant)
    -- Druid
    [740] = 4, -- Tranquility
    -- Monk
    [117952] = 4, -- Crackling Jade Lightning
    [191837] = 3, -- Essence Font
    -- Evoker
    [356995] = 3, -- Disintegrate
    -- Hunter
    [120360] = 15, -- Barrage
    [257620] = 10, -- Multi-Shot (rapid fire)
    [257044] = 7, -- Rapid Fire
    -- Demon Hunter
    [198013] = 9, -- Eye Beam
    [211053] = 3, -- Fel Barrage
    -- Death Knight
    [152279] = 3, -- Breath of Sindragosa (tick-like)
    -- Shaman
    [188443] = 3, -- Chain Lightning (if channeled)
}

-------------------------------------------------------------------------------
--  Helpers
-------------------------------------------------------------------------------
local function UnsnapTex(tex)
    if tex and tex.SetSnapToPixelGrid then
        tex:SetSnapToPixelGrid(false)
        tex:SetTexelSnappingBias(0)
    end
end

local function GetProfile()
    if not db then return nil end
    return db.profile
end

-------------------------------------------------------------------------------
--  1. Spark  (texture only — NOT assigned to castbar.Spark)
-------------------------------------------------------------------------------
local function AddSpark(castbar)
    if castbar._ecbe_spark then return end

    local barTex = castbar:GetStatusBarTexture()
    if not barTex then return end

    local spark = castbar:CreateTexture(nil, "OVERLAY", nil, 5)
    spark:SetTexture("Interface\\Buttons\\WHITE8X8")
    spark:SetVertexColor(0.9, 0.9, 0.9, 0.6)
    spark:SetBlendMode("ADD")
    spark:SetWidth(2)
    spark:SetPoint("TOP", barTex, "TOPRIGHT", 0, 0)
    spark:SetPoint("BOTTOM", barTex, "BOTTOMRIGHT", 0, 0)
    UnsnapTex(spark)
    spark:Hide()

    castbar._ecbe_spark = spark
    -- NOTE: do NOT set castbar.Spark — oUF must not manage this
end

-------------------------------------------------------------------------------
--  2. SafeZone / Latency  (texture only — NOT assigned to castbar.SafeZone)
-------------------------------------------------------------------------------
local function AddSafeZone(castbar)
    if castbar._ecbe_safeZone then return end

    local sz = castbar:CreateTexture(nil, "OVERLAY", nil, 3)
    sz:SetTexture("Interface\\Buttons\\WHITE8X8")
    sz:SetVertexColor(0.69, 0.31, 0.31, 0.75)
    UnsnapTex(sz)
    sz:Hide()

    castbar._ecbe_safeZone = sz
    -- NOTE: do NOT set castbar.SafeZone — oUF must not manage this
end

--- Position and show the SafeZone texture for a player cast/channel.
local function ShowSafeZone(castbar)
    local sz = castbar._ecbe_safeZone
    if not sz then return end

    local isChannel = castbar.channeling
    local startTime, endTime

    if isChannel then
        local _, _, _, st, et = UnitChannelInfo("player")
        startTime, endTime = st, et
    else
        local _, _, _, st, et = UnitCastingInfo("player")
        startTime, endTime = st, et
    end

    if not startTime or not endTime or endTime == startTime then
        sz:Hide()
        return
    end

    local latency = select(4, GetNetStats()) or 0  -- world latency in ms
    local duration = endTime - startTime            -- cast duration in ms
    local ratio = latency / duration
    if ratio > 1 then ratio = 1 end

    local barWidth = castbar:GetWidth()
    if barWidth <= 0 then
        sz:Hide()
        return
    end

    sz:ClearAllPoints()
    sz:SetPoint("TOP")
    sz:SetPoint("BOTTOM")

    if isChannel then
        sz:SetPoint("LEFT")
    else
        sz:SetPoint("RIGHT")
    end

    sz:SetWidth(barWidth * ratio)
    sz:Show()
end

local function HideSafeZone(castbar)
    local sz = castbar._ecbe_safeZone
    if sz then sz:Hide() end
end

-------------------------------------------------------------------------------
--  4. Channel tick marks
-------------------------------------------------------------------------------
local function HideTicks(castbar)
    if not castbar._ecbe_ticks then return end
    for _, tick in ipairs(castbar._ecbe_ticks) do
        tick:Hide()
    end
end

local function SetTicks(castbar, numTicks)
    HideTicks(castbar)
    if not numTicks or numTicks <= 0 then return end

    if not castbar._ecbe_ticks then
        castbar._ecbe_ticks = {}
    end

    local barWidth = castbar:GetWidth()
    if barWidth <= 0 then return end

    local spacing = barWidth / numTicks

    for i = 1, numTicks - 1 do
        local tick = castbar._ecbe_ticks[i]
        if not tick then
            tick = castbar:CreateTexture(nil, "OVERLAY", nil, 4)
            tick:SetTexture("Interface\\Buttons\\WHITE8X8")
            tick:SetVertexColor(0, 0, 0, 0.8)
            tick:SetWidth(1)
            UnsnapTex(tick)
            castbar._ecbe_ticks[i] = tick
        end

        tick:ClearAllPoints()
        tick:SetPoint("TOP")
        tick:SetPoint("BOTTOM")
        tick:SetPoint("RIGHT", castbar, "LEFT", spacing * i, 0)
        tick:Show()
    end
end

-------------------------------------------------------------------------------
--  5. Empowered pip styling
-------------------------------------------------------------------------------
local function SetupPipStyling(castbar)
    if castbar._ecbe_pipsStyled then return end

    local origPostUpdatePips = castbar.PostUpdatePips
    castbar.PostUpdatePips = function(self, stages)
        local p = GetProfile()

        if not p or not p.enabled or not p.empoweredPips then
            if self.Pips then
                for _, pip in pairs(self.Pips) do
                    if pip.BasePip then
                        pip.BasePip:SetAlpha(1)
                    end
                    if pip._ecbe_tex then
                        pip._ecbe_tex:Hide()
                    end
                end
            end
            if origPostUpdatePips then origPostUpdatePips(self, stages) end
            return
        end

        if self.Pips then
            for _, pip in pairs(self.Pips) do
                if pip.BasePip then
                    pip.BasePip:SetAlpha(0)
                end

                if not pip._ecbe_styled then
                    local tex = pip:CreateTexture(nil, "ARTWORK", nil, 2)
                    tex:SetTexture("Interface\\Buttons\\WHITE8X8")
                    tex:SetVertexColor(1, 1, 1, 0.8)
                    tex:SetPoint("TOP")
                    tex:SetPoint("BOTTOM")
                    tex:SetWidth(2)
                    UnsnapTex(tex)
                    pip._ecbe_tex = tex
                    pip._ecbe_styled = true
                end

                if pip._ecbe_tex then
                    pip._ecbe_tex:Show()
                end
            end
        end

        if origPostUpdatePips then origPostUpdatePips(self, stages) end
    end

    castbar._ecbe_pipsStyled = true
end

-------------------------------------------------------------------------------
--  Hook PostCastStart / PostCastStop chains
--  Manages: Spark, SafeZone (player only), Channel Ticks (player only)
-------------------------------------------------------------------------------
local function HookCastCallbacks(castbar, unit)
    if castbar._ecbe_castHooked then return end

    local origPostCastStart   = castbar.PostCastStart
    local origPostCastStop    = castbar.PostCastStop
    local origPostChannelStop = castbar.PostChannelStop
    local origPostCastFail    = castbar.PostCastFail

    local isPlayer = (unit == "player")

    ---------- PostCastStart / PostChannelStart ----------------------------
    castbar.PostCastStart = function(self, u)
        local p = GetProfile()
        local enabled = p and p.enabled

        -- Spark: show during cast
        if self._ecbe_spark then
            if enabled and p.spark then
                self._ecbe_spark:Show()
            else
                self._ecbe_spark:Hide()
            end
        end

        -- SafeZone: show for player casts (positioned by us, not oUF)
        if isPlayer and self._ecbe_safeZone then
            if enabled and p.safeZone then
                ShowSafeZone(self)
            else
                HideSafeZone(self)
            end
        end

        -- Channel ticks: player only
        if isPlayer then
            if enabled and p.channelTicks and self.channeling and self.spellID then
                local ticks = CHANNEL_TICKS[self.spellID]
                if ticks then
                    SetTicks(self, ticks)
                else
                    HideTicks(self)
                end
            else
                HideTicks(self)
            end
        end

        if origPostCastStart then origPostCastStart(self, u) end
    end
    castbar.PostChannelStart = castbar.PostCastStart

    ---------- PostCastStop ------------------------------------------------
    castbar.PostCastStop = function(self, u, ...)
        if self._ecbe_spark then self._ecbe_spark:Hide() end
        if isPlayer then
            HideSafeZone(self)
            HideTicks(self)
        end
        if origPostCastStop then origPostCastStop(self, u, ...) end
    end

    ---------- PostChannelStop ---------------------------------------------
    castbar.PostChannelStop = function(self, u, ...)
        if self._ecbe_spark then self._ecbe_spark:Hide() end
        if isPlayer then
            HideSafeZone(self)
            HideTicks(self)
        end
        if origPostChannelStop then origPostChannelStop(self, u, ...) end
    end

    ---------- PostCastFail ------------------------------------------------
    castbar.PostCastFail = function(self, u, ...)
        if self._ecbe_spark then self._ecbe_spark:Hide() end
        if isPlayer then
            HideSafeZone(self)
            HideTicks(self)
        end
        if origPostCastFail then origPostCastFail(self, u, ...) end
    end

    castbar._ecbe_castHooked = true
end

-------------------------------------------------------------------------------
--  Runtime apply (used by options page)
-------------------------------------------------------------------------------
local function ApplyFeatures()
    local p = GetProfile()
    if not p then return end

    for _, castbar in ipairs(enhancedCastbars) do
        if not castbar then break end

        -- Spark: just hide/show the texture; hook handles cast-time visibility
        if castbar._ecbe_spark then
            if not (p.enabled and p.spark) then
                castbar._ecbe_spark:Hide()
            end
            -- If enabled, the PostCastStart hook will Show it on next cast
        end

        -- SafeZone: just hide; hook handles cast-time visibility
        if castbar._ecbe_safeZone then
            if not (p.enabled and p.safeZone) then
                castbar._ecbe_safeZone:Hide()
            end
        end

        -- Smoothing
        if p.enabled and p.smoothing and Enum and Enum.StatusBarInterpolation then
            castbar.smoothing = Enum.StatusBarInterpolation.ExponentialEaseOut
        else
            castbar.smoothing = nil
        end

        -- Channel ticks: update if currently channeling
        if p.enabled and p.channelTicks and castbar.channeling and castbar.spellID then
            local ticks = CHANNEL_TICKS[castbar.spellID]
            if ticks then
                SetTicks(castbar, ticks)
            else
                HideTicks(castbar)
            end
        else
            HideTicks(castbar)
        end

        -- Empowered pips
        if castbar.PostUpdatePips then
            castbar:PostUpdatePips(castbar.NumStages or castbar.numStages)
        end
    end
end
ns.ApplyFeatures = ApplyFeatures

-------------------------------------------------------------------------------
--  Main: find EllesmereUIUnitFrames frames and enhance their castbars once
-------------------------------------------------------------------------------
local function EnhanceCastbars()
    for _, info in ipairs(FRAME_UNITS) do
        local frame = _G[info.name]
        if frame and frame.Castbar then
            local castbar = frame.Castbar

            if not castbar._ecbe_enhanced then
                AddSpark(castbar)

                if info.unit == "player" then
                    AddSafeZone(castbar)
                end

                SetupPipStyling(castbar)
                HookCastCallbacks(castbar, info.unit)

                castbar._ecbe_enhanced = true
                table.insert(enhancedCastbars, castbar)
            end
        end
    end

    ApplyFeatures()
end

-------------------------------------------------------------------------------
--  Lifecycle
-------------------------------------------------------------------------------
function ECBE:OnInitialize()
    db = E.Lite.NewDB("EllesmereUICastBarExtrasDB", defaults, true)
    ns.db = db
end

function ECBE:OnEnable()
    C_Timer.After(1.0, EnhanceCastbars)
end
