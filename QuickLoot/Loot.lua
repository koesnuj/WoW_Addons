----------------------------------------------------------------------
--  QuickLoot  –  Loot frame module
--  Replaces the default loot frame.  Positions at cursor when the
--  "lootUnderMouse" CVar is enabled and reshuffles remaining slots
--  upward after each item is looted so the next item sits under the
--  cursor automatically.
--
--  Original code: Butsu by Haste (MIT) – heavily trimmed & updated
--  for The War Within / Midnight retail API.
----------------------------------------------------------------------
local ADDON_NAME, NS = ...

----------------------------------------------------------------------
--  Upvalues
----------------------------------------------------------------------
local CreateFrame       = CreateFrame
local GetCursorPosition = GetCursorPosition
local GetLootSlotInfo   = GetLootSlotInfo
local GetLootSlotLink   = GetLootSlotLink
local GetLootSlotType   = GetLootSlotType
local GetNumLootItems   = GetNumLootItems
local IsFishingLoot     = IsFishingLoot
local IsModifiedClick   = IsModifiedClick
local LootSlot          = LootSlot
local LootSlotHasItem   = LootSlotHasItem
local CloseLoot         = CloseLoot
local ResetCursor       = ResetCursor
local StaticPopup_Hide  = StaticPopup_Hide
local UIParent          = UIParent
local UnitIsDead        = UnitIsDead
local UnitIsFriend      = UnitIsFriend
local UnitName          = UnitName
local GameTooltip       = GameTooltip
local ITEM_QUALITY_COLORS = ITEM_QUALITY_COLORS
local LOOT              = LOOT
local LOOT_SLOT_ITEM    = LOOT_SLOT_ITEM

local GetCVarBool = C_CVar and C_CVar.GetCVarBool or GetCVarBool
local GetItemReagentQuality = C_TradeSkillUI and C_TradeSkillUI.GetItemReagentQualityByItemInfo

local math_max   = math.max
local math_floor = math.floor
local pairs, next, format = pairs, next, format

----------------------------------------------------------------------
--  State
----------------------------------------------------------------------
local slots = {}
NS.lootSlots = slots

local lootFrame, lootFrameHolder
local iconSize = 22

----------------------------------------------------------------------
--  Slot callbacks
----------------------------------------------------------------------
local function SlotEnter(self)
    local id = self:GetID()
    if LootSlotHasItem(id) then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetLootItem(id)
        CursorUpdate(self)
    end
    self.drop:Show()
    self.drop:SetVertexColor(1, 1, 0)
end

local function SlotLeave(self)
    if self.quality and self.quality > 1 then
        local c = ITEM_QUALITY_COLORS[self.quality]
        self.drop:SetVertexColor(c.r, c.g, c.b)
    else
        self.drop:Hide()
    end
    GameTooltip:Hide()
    ResetCursor()
end

local function SlotClick(self)
    if IsModifiedClick() then
        HandleModifiedItemClick(GetLootSlotLink(self:GetID()))
    else
        StaticPopup_Hide("CONFIRM_LOOT_DISTRIBUTION")
        local fr = _G.LootFrame
        if fr then
            fr.selectedLootButton = self:GetName()
            fr.selectedSlot       = self:GetID()
            fr.selectedQuality    = self.quality
            fr.selectedItemName   = self.name:GetText()
        end
        LootSlot(self:GetID())
    end
end

local function SlotShow(self)
    if GameTooltip:IsOwned(self) then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetLootItem(self:GetID())
        CursorUpdate(self)
    end
end

----------------------------------------------------------------------
--  Create a loot slot button
----------------------------------------------------------------------
local function CreateSlot(id)
    local db   = NS.db or NS.defaults
    local size = db.iconSize or 22

    local frame = CreateFrame("Button", "QuickLootSlot"..id, lootFrame)
    frame:SetHeight(math_max(db.fontSizeItem or 12, size))
    frame:SetID(id)
    frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    frame:SetScript("OnEnter", SlotEnter)
    frame:SetScript("OnLeave", SlotLeave)
    frame:SetScript("OnClick", SlotClick)
    frame:SetScript("OnShow",  SlotShow)

    local iconFrame = CreateFrame("Frame", nil, frame)
    iconFrame:SetSize(size, size)
    iconFrame:SetPoint("RIGHT", frame)
    frame.iconFrame = iconFrame

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetAlpha(.8)
    icon:SetTexCoord(.07, .93, .07, .93)
    icon:SetAllPoints(iconFrame)
    frame.icon = icon

    local quest = iconFrame:CreateTexture(nil, "OVERLAY")
    quest:SetTexture(TEXTURE_ITEM_QUEST_BANG)
    quest:SetTexCoord(0, 1, 0, 1)
    quest:SetSize(size * .8, size * .8)
    quest:SetPoint("BOTTOMLEFT", -size * .15, 0)
    frame.quest = quest

    local count = iconFrame:CreateFontString(nil, "OVERLAY")
    count:SetJustifyH("RIGHT")
    count:SetPoint("BOTTOMRIGHT", iconFrame, 2, 2)
    count:SetFont(NumberFontNormalSmall:GetFont(), db.fontSizeCount or 10, "OUTLINE")
    count:SetShadowOffset(.8, -.8)
    count:SetShadowColor(0, 0, 0, 1)
    count:SetText("1")
    frame.count = count

    local name = frame:CreateFontString(nil, "OVERLAY")
    name:SetJustifyH("LEFT")
    name:SetPoint("LEFT", frame)
    name:SetPoint("RIGHT", iconFrame, "LEFT")
    name:SetNonSpaceWrap(true)
    name:SetFont(GameFontWhite:GetFont(), db.fontSizeItem or 12)
    name:SetShadowOffset(.8, -.8)
    name:SetShadowColor(0, 0, 0, 1)
    frame.name = name

    local drop = frame:CreateTexture(nil, "ARTWORK")
    drop:SetTexture([[Interface\QuestFrame\UI-QuestLogTitleHighlight]])
    drop:SetAllPoints(frame)
    drop:SetAlpha(.3)
    frame.drop = drop

    local profQuality = iconFrame:CreateTexture(nil, "OVERLAY")
    profQuality:SetPoint("TOPLEFT", -3, 2)
    frame.profQuality = profQuality

    slots[id] = frame
    return frame
end

----------------------------------------------------------------------
--  Reanchor visible slots (the core "reshuffle" mechanic)
----------------------------------------------------------------------
local function AnchorSlots()
    local db = NS.db or NS.defaults
    local frameSize = math_max(db.iconSize or 22, db.fontSizeItem or 12)
    local shownSlots = 0
    local prevShown

    for i = 1, #slots do
        local fr = slots[i]
        if fr:IsShown() then
            fr:ClearAllPoints()
            fr:SetPoint("LEFT", 8, 0)
            fr:SetPoint("RIGHT", -8, 0)
            if not prevShown then
                fr:SetPoint("TOPLEFT", lootFrame, 8, -8)
            else
                fr:SetPoint("TOP", prevShown, "BOTTOM")
            end
            fr:SetHeight(frameSize)
            shownSlots = shownSlots + 1
            prevShown = fr
        end
    end

    -- Keep top edge in place so cursor stays over the next slot
    local oldTop = lootFrame:GetTop() or 0
    lootFrame:SetHeight(math_max(shownSlots * frameSize + 16, 20))
    local point, parent, relPoint, x, y = lootFrame:GetPoint()
    if point then
        local shift = oldTop - (lootFrame:GetTop() or 0)
        lootFrame:SetPoint(point, parent, relPoint, x, y + shift)
    end
end

----------------------------------------------------------------------
--  Update frame width to fit longest item name
----------------------------------------------------------------------
local function UpdateWidth()
    local db = NS.db or NS.defaults
    local maxWidth = 0
    for _, slot in next, slots do
        if slot:IsShown() then
            maxWidth = math_max(maxWidth, slot.name:GetStringWidth())
        end
    end
    lootFrame:SetWidth(math_max(maxWidth + 30 + (db.iconSize or 22), lootFrame.title:GetStringWidth() + 5))
end

----------------------------------------------------------------------
--  Build the loot frame (once)
----------------------------------------------------------------------
local function BuildLootFrame()
    if lootFrame then return end

    lootFrame = CreateFrame("Button", "QuickLootFrame", UIParent, "BackdropTemplate")
    lootFrame:Hide()
    lootFrame:SetBackdrop({
        bgFile   = [[Interface\Tooltips\UI-Tooltip-Background]],
        edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    lootFrame:SetBackdropColor(0, 0, 0, .9)
    lootFrame:SetClampedToScreen(true)
    lootFrame:SetClampRectInsets(0, 0, 14, 0)
    lootFrame:SetHitRectInsets(0, 0, -14, 0)
    lootFrame:SetFrameStrata("HIGH")
    lootFrame:SetToplevel(true)
    lootFrame:SetMovable(true)
    lootFrame:RegisterForClicks("AnyUp")

    lootFrame:SetScript("OnMouseDown", function(self)
        if IsAltKeyDown() then self:StartMoving() end
    end)
    lootFrame:SetScript("OnMouseUp", function(self)
        self:StopMovingOrSizing()
        -- Save position
        local point, _, _, px, py = self:GetPoint()
        if point then
            local db = NS.db or NS.defaults
            db.framePosition = format("%s\031UIParent\031%d\031%d", point, math_floor(px + .5), math_floor(py + .5))
        end
    end)
    lootFrame:SetScript("OnHide", function()
        StaticPopup_Hide("CONFIRM_LOOT_DISTRIBUTION")
        CloseLoot()
    end)

    local title = lootFrame:CreateFontString(nil, "OVERLAY")
    title:SetFont(GameTooltipHeaderText:GetFont(), (NS.db or NS.defaults).fontSizeTitle or 14, "OUTLINE")
    title:SetPoint("BOTTOMLEFT", lootFrame, "TOPLEFT", 5, 0)
    lootFrame.title = title

    local db = NS.db or NS.defaults
    lootFrame:SetScale(db.frameScale or 1)

    -- Load saved position
    if db.framePosition then
        local point, parentName, px, py = strsplit("\031", db.framePosition)
        local scale = lootFrame:GetScale()
        lootFrame:ClearAllPoints()
        lootFrame:SetPoint(point, parentName, point, (tonumber(px) or 0) / scale, (tonumber(py) or 0) / scale)
    end

    -- Kill default loot frame & make ESC close ours
    _G.LootFrame:UnregisterAllEvents()
    tinsert(UISpecialFrames, "QuickLootFrame")

    NS.lootFrame = lootFrame
end

----------------------------------------------------------------------
--  Event handlers
----------------------------------------------------------------------
local function OnLootOpened(_, autoloot)
    local db = NS.db or NS.defaults
    if not db.lootEnabled then return end

    BuildLootFrame()
    lootFrame:Show()

    if not lootFrame:IsShown() then
        CloseLoot(not autoloot)
        return
    end

    -- Title
    if IsFishingLoot() then
        lootFrame.title:SetText("Fishy Loot")
    elseif not UnitIsFriend("player", "target") and UnitIsDead("target") then
        lootFrame.title:SetText(UnitName("target"))
    else
        lootFrame.title:SetText(LOOT)
    end

    -- Position at cursor when lootUnderMouse is enabled
    if GetCVarBool("lootUnderMouse") then
        local scale = lootFrame:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        lootFrame:ClearAllPoints()
        lootFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (cx / scale) - 40, (cy / scale) + 20)
        lootFrame:GetCenter()
        lootFrame:Raise()
    elseif not lootFrame.manuallyMoved then
        -- default position
        if not db.framePosition then
            lootFrame:ClearAllPoints()
            lootFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 418, -186)
        end
    end

    -- Populate slots
    local maxQuality = 0
    local numItems = GetNumLootItems()

    if numItems > 0 then
        for i = 1, numItems do
            local slot = slots[i] or CreateSlot(i)
            local textureID, item, count, currencyID, quality, locked, isQuestItem, questId, isActive = GetLootSlotInfo(i)

            if currencyID and CurrencyContainerUtil and CurrencyContainerUtil.GetCurrencyContainerInfo then
                item, textureID, count, quality = CurrencyContainerUtil.GetCurrencyContainerInfo(currencyID, count, item, textureID, quality)
            end

            if textureID then
                local c = ITEM_QUALITY_COLORS[quality or 0]
                local r, g, b = c.r, c.g, c.b

                if GetLootSlotType(i) == LOOT_SLOT_MONEY then
                    item = item:gsub("\n", ", ")
                end

                slot.count:SetShown(count and count > 1)
                slot.count:SetText(count or "")

                if quality and quality > 1 then
                    slot.drop:SetVertexColor(r, g, b)
                    slot.drop:Show()
                elseif questId or isQuestItem then
                    slot.drop:SetVertexColor(1, 1, .2)
                    slot.drop:Show()
                else
                    slot.drop:Hide()
                end

                slot.quest:SetShown(questId and not isActive)
                slot.quality     = quality
                slot.isQuestItem = isQuestItem
                slot.name:SetText(item)
                slot.name:SetTextColor(r, g, b)
                slot.icon:SetTexture(textureID)

                -- Profession quality pip
                if slot.profQuality and GetItemReagentQuality then
                    local link = GetLootSlotLink(i)
                    local pq = link and GetItemReagentQuality(link)
                    if pq then
                        slot.profQuality:SetAtlas(format("Professions-Icon-Quality-Tier%d-Inv", pq), true)
                    else
                        slot.profQuality:SetAtlas(nil)
                    end
                end

                maxQuality = math_max(maxQuality, quality or 0)
                slot:Enable()
                slot:Show()
            end
        end
    else
        -- Empty
        local slot = slots[1] or CreateSlot(1)
        local c = ITEM_QUALITY_COLORS[0]
        slot.name:SetText("Empty slot")
        slot.name:SetTextColor(c.r, c.g, c.b)
        slot.icon:SetTexture(136511)
        slot.count:Hide()
        slot.drop:Hide()
        slot:Disable()
        slot:Show()
    end

    AnchorSlots()

    local c = ITEM_QUALITY_COLORS[maxQuality]
    lootFrame:SetBackdropBorderColor(c.r, c.g, c.b, .8)
    UpdateWidth()
end

local function OnLootSlotCleared(_, id)
    if not lootFrame or not lootFrame:IsShown() then return end
    if slots[id] then
        slots[id]:Hide()
    end
    AnchorSlots()
end

local function OnLootClosed()
    if not lootFrame then return end
    StaticPopup_Hide("LOOT_BIND")
    lootFrame:Hide()
    for _, slot in pairs(slots) do
        slot:Hide()
    end
end

----------------------------------------------------------------------
--  Register events
----------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("LOOT_OPENED")
eventFrame:RegisterEvent("LOOT_SLOT_CLEARED")
eventFrame:RegisterEvent("LOOT_CLOSED")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "LOOT_OPENED" then
        OnLootOpened(...)
    elseif event == "LOOT_SLOT_CLEARED" then
        OnLootSlotCleared(...)
    elseif event == "LOOT_CLOSED" then
        OnLootClosed()
    end
end)
