------------------------------------------------------------------------
-- SocialInfo – Friends Module
-- Shows online friend count (character + BattleNet); tooltip lists them
------------------------------------------------------------------------
local addonName, ns = ...
local mod = { online = {}, count = 0 }

function mod:Init()
    self.row = ns:CreateRow("friends",
        "Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon",
        function(tip) mod:OnTooltip(tip) end,
        function() if ToggleFriendsFrame then ToggleFriendsFrame(1) end end
    )

    local f = CreateFrame("Frame")
    f:RegisterEvent("FRIENDLIST_UPDATE")
    f:RegisterEvent("BN_FRIEND_INFO_CHANGED")
    f:RegisterEvent("BN_FRIEND_LIST_SIZE_CHANGED")
    f:SetScript("OnEvent", function() mod:Update() end)

    C_FriendList.ShowFriends()
end

function mod:Update()
    local row = self.row
    if not row then return end

    wipe(self.online)
    self.count = 0

    ----------------------------------------------------------------
    -- Character friends
    ----------------------------------------------------------------
    local numChar = C_FriendList.GetNumFriends()
    for i = 1, numChar do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info and info.connected then
            self.count = self.count + 1
            self.online[#self.online + 1] = {
                name  = info.name,
                level = info.level or 0,
                class = info.className or "",
                area  = info.area or "",
                bnet  = false,
            }
        end
    end

    ----------------------------------------------------------------
    -- BattleNet friends
    ----------------------------------------------------------------
    local numBN = BNGetNumFriends()
    for i = 1, numBN do
        local acctInfo = C_BattleNet.GetFriendAccountInfo(i)
        if acctInfo then
            local gi = acctInfo.gameAccountInfo
            if gi and gi.isOnline then
                local isWoW = gi.clientProgram == BNET_CLIENT_WOW
                self.count = self.count + 1
                self.online[#self.online + 1] = {
                    name  = acctInfo.accountName or "?",
                    toon  = isWoW and (gi.characterName or "") or "",
                    level = isWoW and (gi.characterLevel or 0) or 0,
                    class = isWoW and (gi.className or "") or "",
                    area  = isWoW and (gi.areaName or "") or "",
                    game  = gi.clientProgram or "",
                    bnet  = true,
                    isWoW = isWoW,
                }
            end
        end
    end

    local color = self.count > 0 and "|cff00ff00" or "|cff888888"
    row.text:SetText(string.format("친구 %s%d|r", color, self.count))
end

function mod:OnTooltip(tip)
    tip:AddLine("접속중인 친구", 0.4, 0.8, 1.0)
    tip:AddLine(" ")

    if #self.online == 0 then
        tip:AddLine("없음", 0.5, 0.5, 0.5)
        return
    end

    for _, info in ipairs(self.online) do
        if info.bnet then
            if info.isWoW then
                local display = info.toon ~= ""
                    and string.format("%s |cff82c5ff(%s)|r", info.toon, info.name)
                    or info.name
                tip:AddDoubleLine(
                    display, info.area,
                    0.51, 0.77, 1.0,
                    0.7, 0.7, 0.7
                )
            else
                tip:AddDoubleLine(
                    info.name,
                    info.game,
                    0.51, 0.77, 1.0,
                    0.5, 0.5, 0.5
                )
            end
        else
            tip:AddDoubleLine(
                string.format("%s  |cffaaaaaa%d|r", info.name, info.level),
                info.area,
                1, 1, 1,
                0.7, 0.7, 0.7
            )
        end
    end
end

ns:RegisterModule("friends", mod)
