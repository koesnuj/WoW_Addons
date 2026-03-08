------------------------------------------------------------------------
-- SocialInfo – Guild Module
-- Shows online guild member count; tooltip lists members
------------------------------------------------------------------------
local addonName, ns = ...
local mod = { online = {}, count = 0 }

function mod:Init()
    self.row = ns:CreateRow("guild",
        "Interface\\GossipFrame\\TabardGossipIcon",
        function(tip) mod:OnTooltip(tip) end,
        function() if ToggleCommunitiesFrame then ToggleCommunitiesFrame() end end
    )

    local f = CreateFrame("Frame")
    f:RegisterEvent("GUILD_ROSTER_UPDATE")
    f:RegisterEvent("PLAYER_GUILD_UPDATE")
    f:SetScript("OnEvent", function() mod:Update() end)

    if IsInGuild() then
        C_GuildInfo.GuildRoster()
    end
end

function mod:Update()
    local row = self.row
    if not row then return end

    wipe(self.online)
    self.count = 0

    if not IsInGuild() then
        row.text:SetText("|cff888888길드 없음|r")
        return
    end

    local total = GetNumGuildMembers()
    for i = 1, total do
        local name, _, _, level, _, zone, _, _, isOnline, _, classFile = GetGuildRosterInfo(i)
        if isOnline and name then
            self.count = self.count + 1
            self.online[#self.online + 1] = {
                name  = Ambiguate(name, "guild"),
                level = level,
                zone  = zone or "",
                class = classFile,
            }
        end
    end

    local color = self.count > 0 and "|cff00ff00" or "|cff888888"
    row.text:SetText(string.format("길드 %s%d|r", color, self.count))
end

function mod:OnTooltip(tip)
    tip:AddLine("접속중인 길드원", 0.4, 0.8, 1.0)
    tip:AddLine(" ")

    if #self.online == 0 then
        tip:AddLine("없음", 0.5, 0.5, 0.5)
        return
    end

    table.sort(self.online, function(a, b) return a.level > b.level end)

    for _, info in ipairs(self.online) do
        local cc = RAID_CLASS_COLORS[info.class]
        local r, g, b = 1, 1, 1
        if cc then r, g, b = cc.r, cc.g, cc.b end

        tip:AddDoubleLine(
            string.format("%s  |cffaaaaaa%d|r", info.name, info.level),
            info.zone,
            r, g, b,
            0.7, 0.7, 0.7
        )
    end
end

ns:RegisterModule("guild", mod)
