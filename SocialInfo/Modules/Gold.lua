------------------------------------------------------------------------
-- SocialInfo – Gold Module
-- Shows current character gold; tooltip lists all characters on account
------------------------------------------------------------------------
local addonName, ns = ...
local mod = {}

local function FormatMoney(money)
    local gold   = math.floor(money / 10000)
    local silver = math.floor((money % 10000) / 100)
    local copper = money % 100
    return string.format(
        "%s|cffffd700g|r %d|cffc0c0c0s|r %d|cffb87333c|r",
        BreakUpLargeNumbers(gold), silver, copper
    )
end

function mod:Init()
    self.row = ns:CreateRow("gold",
        "Interface\\MoneyFrame\\UI-GoldIcon",
        function(tip) mod:OnTooltip(tip) end,
        function() ToggleAllBags() end
    )

    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_MONEY")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function() mod:Update() end)
end

function mod:Update()
    local row = self.row
    if not row then return end

    local money = GetMoney()

    -- Save this character's gold (account-wide SavedVariables)
    ns.db.charGold = ns.db.charGold or {}
    local name  = UnitName("player")
    local realm = GetRealmName()
    local key   = name .. " - " .. realm
    local _, classFile = UnitClass("player")

    ns.db.charGold[key] = {
        money = money,
        class = classFile,
    }

    row.text:SetText(FormatMoney(money))
end

function mod:OnTooltip(tip)
    tip:AddLine("캐릭터별 골드", 0.4, 0.8, 1.0)
    tip:AddLine(" ")

    local charGold = ns.db.charGold
    if not charGold then return end

    -- Sort by gold descending
    local sorted = {}
    local total  = 0
    for charKey, data in pairs(charGold) do
        sorted[#sorted + 1] = { key = charKey, money = data.money or 0, class = data.class }
        total = total + (data.money or 0)
    end
    table.sort(sorted, function(a, b) return a.money > b.money end)

    for _, info in ipairs(sorted) do
        local cc = RAID_CLASS_COLORS[info.class]
        local r, g, b = 1, 1, 1
        if cc then r, g, b = cc.r, cc.g, cc.b end

        local gold = math.floor(info.money / 10000)
        tip:AddDoubleLine(
            info.key,
            BreakUpLargeNumbers(gold) .. "|cffffd700g|r",
            r, g, b,
            1, 1, 1
        )
    end

    tip:AddLine(" ")
    local totalGold = math.floor(total / 10000)
    tip:AddDoubleLine(
        "합계",
        BreakUpLargeNumbers(totalGold) .. "|cffffd700g|r",
        1, 0.82, 0,
        1, 1, 1
    )
end

ns:RegisterModule("gold", mod)
