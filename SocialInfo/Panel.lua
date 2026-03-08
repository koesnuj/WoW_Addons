------------------------------------------------------------------------
-- SocialInfo – Panel
-- Horizontal single-line bar: backdrop, drag, cell factory, auto-layout
------------------------------------------------------------------------
local addonName, ns = ...

local PADDING   = 6
local CELL_GAP  = 10
local ICON_SIZE = 14
local BAR_H     = ICON_SIZE + PADDING * 2
local FONT      = STANDARD_TEXT_FONT or "Fonts\\2002.TTF"
local FONT_SIZE = 11

local backdrop = {
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets   = { left = 1, right = 1, top = 1, bottom = 1 },
}

------------------------------------------------------------------------
-- Create main panel (no title, single-line bar)
------------------------------------------------------------------------
function ns:CreatePanel()
    if ns.panel then return end

    local panel = CreateFrame("Frame", "SocialInfoPanel", UIParent, "BackdropTemplate")
    panel:SetHeight(BAR_H)
    panel:SetWidth(200) -- recalculated on relayout
    panel:SetBackdrop(backdrop)
    panel:SetBackdropColor(0.06, 0.06, 0.06, 0.88)
    panel:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.9)
    panel:SetFrameStrata("MEDIUM")
    panel:SetClampedToScreen(true)

    -- Restore saved position
    local p = ns.db.point
    if p then
        panel:SetPoint(p[1], UIParent, p[3] or "CENTER", p[4] or 0, p[5] or 0)
    else
        panel:SetPoint("CENTER")
    end

    -- Drag support
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self)
        if not ns.db.locked then self:StartMoving() end
    end)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local pt, _, rel, x, y = self:GetPoint()
        ns.db.point = { pt, "UIParent", rel, x, y }
    end)

    -- Ctrl + mouse-wheel scaling
    panel:EnableMouseWheel(true)
    panel:SetScript("OnMouseWheel", function(self, delta)
        if IsControlKeyDown() then
            local s = ns.db.scale or 1
            s = math.max(0.5, math.min(2.0, s + delta * 0.05))
            ns.db.scale = s
            self:SetScale(s)
        end
    end)

    -- Apply saved scale
    if ns.db.scale then panel:SetScale(ns.db.scale) end

    ns.panel      = panel
    ns.cells      = {}
    ns._cellOrder  = {}
end

------------------------------------------------------------------------
-- Cell factory (horizontal)
------------------------------------------------------------------------
function ns:CreateRow(key, iconPath, tooltipFunc, clickFunc)
    local panel = ns.panel

    local cell = CreateFrame("Button", nil, panel)
    cell:SetHeight(ICON_SIZE)
    cell:RegisterForClicks("AnyUp")

    -- Icon
    cell.icon = cell:CreateTexture(nil, "ARTWORK")
    cell.icon:SetSize(ICON_SIZE, ICON_SIZE)
    cell.icon:SetPoint("LEFT")
    cell.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if iconPath then cell.icon:SetTexture(iconPath) end

    -- Text
    cell.text = cell:CreateFontString(nil, "OVERLAY")
    cell.text:SetFont(FONT, FONT_SIZE, "OUTLINE")
    cell.text:SetPoint("LEFT", cell.icon, "RIGHT", 4, 0)
    cell.text:SetJustifyH("LEFT")
    cell.text:SetWordWrap(false)

    -- Hook SetText → auto relayout
    local origSetText = cell.text.SetText
    cell.text.SetText = function(self, ...)
        origSetText(self, ...)
        ns:RelayoutCells()
    end

    -- Tooltip (default Blizzard anchor position)
    if tooltipFunc then
        cell:SetScript("OnEnter", function(self)
            GameTooltip_SetDefaultAnchor(GameTooltip, self)
            tooltipFunc(GameTooltip)
            GameTooltip:Show()
        end)
        cell:SetScript("OnLeave", GameTooltip_Hide)
    end

    -- Click
    if clickFunc then
        cell:SetScript("OnClick", clickFunc)
    end

    -- Highlight
    cell:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
    cell:GetHighlightTexture():SetAlpha(0.05)

    -- Separator (thin vertical line before this cell, except the first)
    if #ns._cellOrder > 0 then
        local sep = panel:CreateTexture(nil, "ARTWORK")
        sep:SetColorTexture(0.35, 0.35, 0.35, 0.5)
        sep:SetWidth(1)
        cell._sep = sep
    end

    ns.cells[key] = cell
    ns._cellOrder[#ns._cellOrder + 1] = key

    return cell
end

------------------------------------------------------------------------
-- Horizontal relayout – called automatically after any SetText
------------------------------------------------------------------------
function ns:RelayoutCells()
    local panel = ns.panel
    if not panel then return end

    local x = PADDING

    for i, key in ipairs(ns._cellOrder) do
        local cell = ns.cells[key]
        if cell then
            -- Separator
            if cell._sep then
                cell._sep:ClearAllPoints()
                cell._sep:SetPoint("LEFT", panel, "LEFT", x, 0)
                cell._sep:SetHeight(ICON_SIZE)
                cell._sep:SetPoint("TOP", panel, "TOP", 0, -PADDING)
                x = x + 1 + CELL_GAP * 0.5
            end

            -- Cell position
            cell:ClearAllPoints()
            cell:SetPoint("LEFT", panel, "LEFT", x, 0)

            local tw = cell.text:GetStringWidth() or 0
            local cw = ICON_SIZE + 4 + tw
            cell:SetWidth(cw)

            x = x + cw + CELL_GAP * 0.5
        end
    end

    panel:SetWidth(x - CELL_GAP * 0.5 + PADDING)
end

------------------------------------------------------------------------
-- Lock visual feedback
------------------------------------------------------------------------
function ns:UpdateLock()
    local panel = ns.panel
    if not panel then return end
    if ns.db.locked then
        panel:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.7)
    else
        panel:SetBackdropBorderColor(0.4, 0.6, 1.0, 0.8)
    end
end
