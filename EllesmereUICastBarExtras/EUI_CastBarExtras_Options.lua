local ADDON_NAME, ns = ...

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    if not EllesmereUI or not EllesmereUI.RegisterModule then return end

    local db
    C_Timer.After(0, function()
        db = ns.db
    end)

    local function DB()
        if not db then db = ns.db end
        return db and db.profile
    end

    local function Refresh()
        if ns.ApplyFeatures then ns.ApplyFeatures() end
    end

    local function BuildPage(pageName, parent, yOffset)
        local W = EllesmereUI.Widgets
        local y = yOffset
        local _, h, row

        _, h = W:SectionHeader(parent, "CASTBAR EXTRAS", y)
        y = y - h

        _, h = W:Toggle(parent, "Enable CastBar Extras", y,
            function()
                return DB() and DB().enabled ~= false
            end,
            function(v)
                DB().enabled = v
                Refresh()
                EllesmereUI:RefreshPage()
            end)
        y = y - h

        _, h = W:Spacer(parent, y, 10)
        y = y - h

        row, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = "Spark",
                disabled = function() return not DB().enabled end,
                disabledTooltip = "Enable CastBar Extras",
                getValue = function() return DB().spark ~= false end,
                setValue = function(v)
                    DB().spark = v
                    Refresh()
                end,
            },
            {
                type = "toggle",
                text = "Latency (SafeZone)",
                disabled = function() return not DB().enabled end,
                disabledTooltip = "Enable CastBar Extras",
                getValue = function() return DB().safeZone ~= false end,
                setValue = function(v)
                    DB().safeZone = v
                    Refresh()
                end,
            }
        )
        y = y - h

        row, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = "Smoothing",
                disabled = function() return not DB().enabled end,
                disabledTooltip = "Enable CastBar Extras",
                getValue = function() return DB().smoothing ~= false end,
                setValue = function(v)
                    DB().smoothing = v
                    Refresh()
                end,
            },
            {
                type = "toggle",
                text = "Channel Ticks",
                disabled = function() return not DB().enabled end,
                disabledTooltip = "Enable CastBar Extras",
                getValue = function() return DB().channelTicks ~= false end,
                setValue = function(v)
                    DB().channelTicks = v
                    Refresh()
                end,
            }
        )
        y = y - h

        _, h = W:Toggle(parent, "Empowered Pip Styling", y,
            function()
                return DB() and DB().empoweredPips ~= false
            end,
            function(v)
                DB().empoweredPips = v
                Refresh()
            end,
            "Replace default empowered cast pip art with flat white lines")
        y = y - h

        return math.abs(y)
    end

    EllesmereUI:RegisterModule("EllesmereUICastBarExtras", {
        title = "CastBar Extras",
        description = "Spark, Latency, Smoothing, Channel Ticks, and Empowered Pip styling.",
        pages = { "CastBar Extras" },
        buildPage = function(pageName, parent, yOffset)
            return BuildPage(pageName, parent, yOffset)
        end,
        onReset = function()
            if ns.db then ns.db:ResetProfile() end
            Refresh()
        end,
    })
end)
