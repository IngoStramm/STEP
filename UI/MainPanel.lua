local _, STEP = ...

local MainPanel = {
    initialized = false,
    inCombat = false,
    rowPool = {},
    sectionPool = {},
}
STEP.MainPanel = MainPanel

local PANEL_WIDTH = 232
local HEADER_HEIGHT = 22
local ROW_HEIGHT = 19
local SECTION_HEIGHT = 15
local PADDING = 5
local ICON_SIZE = 16

local backdrop = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

local function SetBackdrop(frame)
    if not frame.SetBackdrop then
        return
    end
    frame:SetBackdrop(backdrop)
    frame:SetBackdropColor(0.035, 0.035, 0.045, 0.92)
    frame:SetBackdropBorderColor(0.24, 0.24, 0.28, 0.95)
end

local function CreateFont(parent, template, justify)
    local text = parent:CreateFontString(nil, "OVERLAY", template)
    text:SetJustifyH(justify or "LEFT")
    text:SetJustifyV("MIDDLE")
    return text
end

local function HidePool(pool)
    for index = 1, #pool do
        pool[index]:Hide()
    end
end

function MainPanel:ApplyPosition()
    if not self.frame then
        return
    end

    local point = STEP.ConfigStore:Get("panel.point") or "CENTER"
    local relativePoint = STEP.ConfigStore:Get("panel.relativePoint") or point
    local x = STEP.ConfigStore:Get("panel.x") or 0
    local y = STEP.ConfigStore:Get("panel.y") or 0
    self.frame:ClearAllPoints()
    self.frame:SetPoint(point, UIParent, relativePoint, x, y)
    self.frame:SetScale(STEP.ConfigStore:Get("panel.scale") or 1)
end

function MainPanel:SavePosition()
    if not self.frame then
        return
    end
    local point, _, relativePoint, x, y = self.frame:GetPoint(1)
    if not point then
        return
    end
    STEP.ConfigStore:ApplyBatch({
        { scope = "general", path = "panel.point", value = point },
        { scope = "general", path = "panel.relativePoint", value = relativePoint or point },
        { scope = "general", path = "panel.x", value = x or 0 },
        { scope = "general", path = "panel.y", value = y or 0 },
    }, "main-panel-position")
end

function MainPanel:AcquireRow(index)
    local row = self.rowPool[index]
    if row then
        return row
    end

    row = CreateFrame("Frame", nil, self.frame)
    row:SetHeight(ROW_HEIGHT)
    row:EnableMouse(true)

    row.highlight = row:CreateTexture(nil, "BACKGROUND")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(0.16, 0.52, 0.86, 0.16)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.name = CreateFont(row, "GameFontHighlightSmall", "LEFT")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
    row.name:SetWidth(128)

    row.maximum = CreateFont(row, "GameFontHighlightSmall", "RIGHT")
    row.maximum:SetPoint("RIGHT", row, "RIGHT", -1, 0)
    row.maximum:SetWidth(29)

    row.slash = CreateFont(row, "GameFontHighlightSmall", "CENTER")
    row.slash:SetPoint("RIGHT", row.maximum, "LEFT", 0, 0)
    row.slash:SetWidth(8)
    row.slash:SetText("/")

    row.current = CreateFont(row, "GameFontHighlightSmall", "RIGHT")
    row.current:SetPoint("RIGHT", row.slash, "LEFT", 0, 0)
    row.current:SetWidth(29)

    row:SetScript("OnEnter", function(currentRow)
        self:ShowRowTooltip(currentRow)
    end)
    row:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    self.rowPool[index] = row
    return row
end

function MainPanel:AcquireSection(index)
    local section = self.sectionPool[index]
    if section then
        return section
    end

    section = CreateFrame("Frame", nil, self.frame)
    section:SetHeight(SECTION_HEIGHT)
    section.separator = section:CreateTexture(nil, "ARTWORK")
    section.separator:SetHeight(1)
    section.separator:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
    section.separator:SetPoint("TOPRIGHT", section, "TOPRIGHT", 0, 0)
    section.separator:SetColorTexture(0.45, 0.45, 0.50, 0.45)
    section.label = CreateFont(section, "GameFontNormalSmall", "LEFT")
    section.label:SetPoint("BOTTOMLEFT", section, "BOTTOMLEFT", 0, 0)
    section.label:SetPoint("BOTTOMRIGHT", section, "BOTTOMRIGHT", -1, 0)

    self.sectionPool[index] = section
    return section
end

function MainPanel:ShowRowTooltip(row)
    local data = row and row.data and row.data.tooltip
    if not data or not GameTooltip then
        return
    end

    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(data.name, 1, 0.82, 0)
    GameTooltip:AddDoubleLine(STEP:GetText("PANEL_TOOLTIP_VALUE"), data.valueText, 0.72, 0.72, 0.72, 1, 1, 1)
    GameTooltip:AddDoubleLine(STEP:GetText("PANEL_TOOLTIP_PROGRESS"), tostring(data.progressPercent) .. "%", 0.72, 0.72, 0.72, 1, 1, 1)
    GameTooltip:AddDoubleLine(STEP:GetText("PANEL_TOOLTIP_MISSING"), tostring(data.missingPoints), 0.72, 0.72, 0.72, 1, 1, 1)
    if data.bonusTotal ~= 0 then
        GameTooltip:AddDoubleLine(STEP:GetText("PANEL_TOOLTIP_BONUS"), data.bonusText, 0.72, 0.72, 0.72, 0.35, 0.85, 1)
    end
    if data.isEquipped then
        GameTooltip:AddLine(STEP:GetText("PANEL_TOOLTIP_EQUIPPED"), 0.35, 0.85, 1)
    end
    GameTooltip:Show()
end

function MainPanel:Render(model)
    if not self.frame then
        return
    end

    HidePool(self.rowPool)
    HidePool(self.sectionPool)

    self.summary:SetText(model.headerText or "")
    self.toggle:SetText(model.expanded and "\226\136\146" or "+")

    if not model.shouldShowPanel or model.displayedCount == 0 then
        self.frame:Hide()
        return
    end

    local y = -HEADER_HEIGHT - PADDING
    local rowIndex = 0
    local sectionIndex = 0
    for categoryIndex = 1, #model.sections do
        local category = model.sections[categoryIndex]
        if category.showHeader then
            sectionIndex = sectionIndex + 1
            local section = self:AcquireSection(sectionIndex)
            section:ClearAllPoints()
            section:SetPoint("TOPLEFT", self.frame, "TOPLEFT", PADDING, y)
            section:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -PADDING, y)
            section.label:SetText(category.label)
            if category.hasSeparatorBefore then
                section.separator:Show()
            else
                section.separator:Hide()
            end
            section:Show()
            y = y - SECTION_HEIGHT
        end

        for categoryRowIndex = 1, #category.rows do
            rowIndex = rowIndex + 1
            local data = category.rows[categoryRowIndex]
            local row = self:AcquireRow(rowIndex)
            row.data = data
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", self.frame, "TOPLEFT", PADDING, y)
            row:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -PADDING, y)
            row.icon:SetTexture(data.icon)
            row.name:SetText(data.name)
            row.current:SetText(data.currentText)
            row.current:SetTextColor(data.currentColor.r, data.currentColor.g, data.currentColor.b)
            row.slash:SetTextColor(1, 1, 1)
            row.maximum:SetText(data.maximumText)
            row.maximum:SetTextColor(1, 1, 1)
            if data.isEquipped then
                row.highlight:Show()
            else
                row.highlight:Hide()
            end
            row:Show()
            y = y - ROW_HEIGHT
        end
    end

    self.frame:SetHeight(math.max(HEADER_HEIGHT, -y + PADDING))
    self.frame:Show()
end

function MainPanel:Refresh()
    if not STEP.ViewModel or not STEP.Database or not STEP.Database:IsCompatible() then
        return nil
    end
    local model = STEP.ViewModel:Build({ inCombat = self.inCombat })
    self.lastModel = model
    self:Render(model)
    return model
end

function MainPanel:OnStateChanged(payload)
    for index = 1, payload and payload.changes and #payload.changes or 0 do
        local change = payload.changes[index]
        if change.scope == "general" and change.path == "panel.scale" then
            self:ApplyPosition()
            break
        end
    end
    self:Refresh()
end

function MainPanel:Initialize()
    if self.initialized then
        return true
    end
    if not UIParent or type(CreateFrame) ~= "function" then
        return false
    end

    if STEP.ConfigStore:Get("panel.startExpanded") == true then
        STEP.ConfigStore:Set("panel.expanded", true, "startup")
    end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame("Frame", "STEPMainPanel", UIParent, template)
    self.frame = frame
    frame:SetSize(PANEL_WIDTH, HEADER_HEIGHT)
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    SetBackdrop(frame)

    local header = CreateFrame("Button", nil, frame)
    self.header = header
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    header:SetHeight(HEADER_HEIGHT - 2)
    header:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    header.background = header:CreateTexture(nil, "BACKGROUND")
    header.background:SetAllPoints()
    header.background:SetColorTexture(0.08, 0.08, 0.10, 0.90)

    self.title = CreateFont(header, "GameFontNormalSmall", "LEFT")
    self.title:SetPoint("LEFT", header, "LEFT", 6, 0)
    self.title:SetText("STEP")

    self.toggle = CreateFont(header, "GameFontHighlight", "CENTER")
    self.toggle:SetPoint("RIGHT", header, "RIGHT", -4, 0)
    self.toggle:SetWidth(18)

    self.summary = CreateFont(header, "GameFontDisableSmall", "RIGHT")
    self.summary:SetPoint("LEFT", self.title, "RIGHT", 8, 0)
    self.summary:SetPoint("RIGHT", self.toggle, "LEFT", -4, 0)

    header:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" or STEP.ConfigStore:Get("panel.locked") then
            return
        end
        self.dragging = true
        self.dragStartX, self.dragStartY = GetCursorPosition()
        frame:StartMoving()
    end)
    header:SetScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" or not self.dragging then
            return
        end
        self.dragging = false
        frame:StopMovingOrSizing()
        local x, y = GetCursorPosition()
        local dx = x - (self.dragStartX or x)
        local dy = y - (self.dragStartY or y)
        self.suppressToggle = dx * dx + dy * dy > 9
        self:SavePosition()
    end)
    header:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            if STEP.ConfigWindow then
                STEP.ConfigWindow:Open()
            end
            return
        end
        if self.suppressToggle then
            self.suppressToggle = false
            return
        end
        self:ToggleExpanded()
    end)

    self.initialized = true
    self:ApplyPosition()
    STEP:RegisterCallback("SKILLS_UPDATED", self, self.OnStateChanged)
    STEP:RegisterCallback("EQUIPMENT_CHANGED", self, self.OnStateChanged)
    STEP:RegisterCallback("CONFIG_CHANGED", self, self.OnStateChanged)
    self:Refresh()
    return true
end

function MainPanel:SetCombatState(inCombat)
    local value = inCombat == true
    if self.inCombat == value then
        return
    end
    self.inCombat = value
    self:Refresh()
end

function MainPanel:SetExpanded(expanded)
    STEP.ConfigStore:Set("panel.expanded", expanded == true, "main-panel")
    self:Refresh()
    return expanded == true
end

function MainPanel:ToggleExpanded()
    return self:SetExpanded(not (STEP.ConfigStore:Get("panel.expanded") == true))
end

function MainPanel:SetShown(shown)
    STEP.ConfigStore:Set("panel.shown", shown == true, "main-panel")
    self:Refresh()
    return shown == true
end

function MainPanel:ToggleShown()
    return self:SetShown(not (STEP.ConfigStore:Get("panel.shown") == true))
end

function MainPanel:ToggleLocked()
    local locked = not (STEP.ConfigStore:Get("panel.locked") == true)
    STEP.ConfigStore:Set("panel.locked", locked, "main-panel")
    return locked
end

function MainPanel:ResetPosition()
    STEP.ConfigStore:ApplyBatch({
        { scope = "general", path = "panel.point", value = "CENTER" },
        { scope = "general", path = "panel.relativePoint", value = "CENTER" },
        { scope = "general", path = "panel.x", value = 0 },
        { scope = "general", path = "panel.y", value = 0 },
    }, "main-panel-reset")
    self:ApplyPosition()
end
