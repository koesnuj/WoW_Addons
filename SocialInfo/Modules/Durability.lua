------------------------------------------------------------------------
-- SocialInfo – Durability Module
-- Shows average equipment durability percentage
------------------------------------------------------------------------
local addonName, ns = ...
local mod = {}

local SLOTS = {
    1,  -- Head
    3,  -- Shoulder
    5,  -- Chest
    6,  -- Waist
    7,  -- Legs
    8,  -- Feet
    9,  -- Wrist
    10, -- Hands
    16, -- Main Hand
    17, -- Off Hand
}

local SLOT_NAMES = {
    [1]  = "머리",
    [3]  = "어깨",
    [5]  = "가슴",
    [6]  = "허리",
    [7]  = "다리",
    [8]  = "발",
    [9]  = "손목",
    [10] = "손",
    [16] = "주무기",
    [17] = "보조무기",
}

function mod:Init()
    self.row = ns:CreateRow("durability",
        "Interface\\Icons\\Trade_BlackSmithing",
        function(tip) mod:OnTooltip(tip) end
    )

    local f = CreateFrame("Frame")
    f:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
    f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    f:SetScript("OnEvent", function() mod:Update() end)
end

function mod:Update()
    local row = self.row
    if not row then return end

    local totalCur, totalMax = 0, 0
    self.slotInfo = self.slotInfo or {}
    wipe(self.slotInfo)

    for _, slot in ipairs(SLOTS) do
        local cur, max = GetInventoryItemDurability(slot)
        if cur and max and max > 0 then
            totalCur = totalCur + cur
            totalMax = totalMax + max
            self.slotInfo[#self.slotInfo + 1] = {
                slot = slot,
                cur  = cur,
                max  = max,
                pct  = math.floor(cur / max * 100),
            }
        end
    end

    local pct = totalMax > 0 and math.floor(totalCur / totalMax * 100) or 100

    local color
    if pct >= 80 then
        color = "|cff00ff00"
    elseif pct >= 50 then
        color = "|cffffff00"
    elseif pct >= 20 then
        color = "|cffff8800"
    else
        color = "|cffff0000"
    end

    row.text:SetText(string.format("내구도  %s%d%%|r", color, pct))
end

function mod:OnTooltip(tip)
    tip:AddLine("장비 내구도", 0.4, 0.8, 1.0)
    tip:AddLine(" ")

    if not self.slotInfo or #self.slotInfo == 0 then
        tip:AddLine("장착된 장비 없음", 0.5, 0.5, 0.5)
        return
    end

    for _, info in ipairs(self.slotInfo) do
        local name = SLOT_NAMES[info.slot] or "?"
        local r, g, b
        if info.pct >= 80 then
            r, g, b = 0, 1, 0
        elseif info.pct >= 50 then
            r, g, b = 1, 1, 0
        elseif info.pct >= 20 then
            r, g, b = 1, 0.53, 0
        else
            r, g, b = 1, 0, 0
        end

        tip:AddDoubleLine(
            name,
            string.format("%d%%", info.pct),
            1, 1, 1,
            r, g, b
        )
    end
end

ns:RegisterModule("durability", mod)
