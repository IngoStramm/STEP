local _, STEP = ...

local OptionsControls = {
    initialized = false,
    surfaces = {},
    nextControlID = 0,
}
STEP.OptionsControls = OptionsControls

local CONTENT_WIDTH = 680
local SKILL_ROW_HEIGHT = 28
local CATEGORY_HEIGHT = 90
local CATEGORY_GAP = 14

local categoryOrder = {
    "combat",
    "primary",
    "secondary",
}

local categoryTextKeys = {
    combat = "CATEGORY_COMBAT",
    primary = "CATEGORY_PRIMARY",
    secondary = "CATEGORY_SECONDARY",
}

local visibilityValues = { "hidden", "expanded", "compact" }
local sortValues = { "progress", "alphabetical" }
local combatValues = { "keep", "compact", "hide" }
local notificationValues = { "exaggerated", "discreet", "none" }

local visibilityTextKeys = {
    hidden = "OPTION_VISIBILITY_HIDDEN",
    expanded = "OPTION_VISIBILITY_EXPANDED",
    compact = "OPTION_VISIBILITY_COMPACT",
}

local sortTextKeys = {
    progress = "OPTION_SORT_PROGRESS",
    alphabetical = "OPTION_SORT_ALPHABETICAL",
}

local combatTextKeys = {
    keep = "OPTION_COMBAT_KEEP",
    compact = "OPTION_COMBAT_COMPACT",
    hide = "OPTION_COMBAT_HIDE",
}

local notificationTextKeys = {
    exaggerated = "OPTION_NOTIFY_EXAGGERATED",
    discreet = "OPTION_NOTIFY_DISCREET",
    none = "OPTION_NOTIFY_NONE",
}

local presetTextKeys = {
    weapons = "PRESET_WEAPONS",
    professions = "PRESET_PROFESSIONS",
    complete = "PRESET_COMPLETE",
    empty = "PRESET_EMPTY",
}

local function CreateText(parent, text, template)
    local font = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
    font:SetText(text or "")
    font:SetJustifyH("LEFT")
    return font
end

local function SetCheckLabel(check, label)
    if not label or label == "" then
        if check.Text then
            check.Text:SetText("")
        end
        check:SetHitRectInsets(-8, -8, -5, -5)
        return
    end
    if check.Text then
        check.Text:SetText(label)
    else
        check.Text = CreateText(check, label, "GameFontHighlight")
        check.Text:SetPoint("LEFT", check, "RIGHT", 2, 0)
    end
    check:SetHitRectInsets(0, -190, 0, 0)
end

local function CreateCheck(parent, label, getter, setter, tooltip)
    local check = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    SetCheckLabel(check, label)
    check.getter = getter
    check.setter = setter
    check:SetScript("OnClick", function(self)
        self.setter(self:GetChecked() and true or false)
    end)
    if tooltip and tooltip ~= "" then
        check:SetScript("OnEnter", function(self)
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
                GameTooltip:ClearLines()
                GameTooltip:AddLine(tooltip, 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        check:SetScript("OnLeave", function()
            if GameTooltip then
                GameTooltip:Hide()
            end
        end)
    end
    function check:Refresh()
        self:SetChecked(self.getter() and true or false)
    end
    return check
end

local function GetEnumLabel(value, textKeys)
    return STEP:GetText(textKeys and textKeys[value] or tostring(value))
end

function OptionsControls:GetUniqueName(prefix)
    self.nextControlID = self.nextControlID + 1
    return "STEP" .. tostring(prefix or "Option") .. tostring(self.nextControlID)
end

function OptionsControls:CreateEnumSelector(parent, prefix, width, values, getter, setter, textKeys)
    local control = {
        values = values,
        getter = getter,
        setter = setter,
    }

    if UIDropDownMenu_Initialize
        and UIDropDownMenu_CreateInfo
        and UIDropDownMenu_AddButton
        and UIDropDownMenu_SetWidth
        and UIDropDownMenu_SetText then
        local name = self:GetUniqueName(prefix)
        local ok, dropdown = pcall(CreateFrame, "Frame", name, parent, "UIDropDownMenuTemplate")
        if ok and dropdown then
            control.frame = dropdown
            control.dropdown = dropdown
            UIDropDownMenu_SetWidth(dropdown, width)
            UIDropDownMenu_Initialize(dropdown, function(_, level)
                for index = 1, #values do
                    local selectedValue = values[index]
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = GetEnumLabel(selectedValue, textKeys)
                    info.checked = getter() == selectedValue
                    info.func = function()
                        setter(selectedValue)
                    end
                    UIDropDownMenu_AddButton(info, level)
                end
            end)
            function control:Refresh()
                UIDropDownMenu_SetText(self.dropdown, GetEnumLabel(self.getter(), textKeys))
            end
            return control
        end
    end

    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 22)
    control.frame = button
    control.button = button
    button:SetScript("OnClick", function()
        local current = getter()
        local nextIndex = 1
        for index = 1, #values do
            if values[index] == current then
                nextIndex = index % #values + 1
                break
            end
        end
        setter(values[nextIndex])
    end)
    function control:Refresh()
        self.button:SetText(GetEnumLabel(self.getter(), textKeys))
    end
    return control
end

function OptionsControls:CreateActionSelector(parent, prefix, width, labelKey, items, handler)
    local control = {}
    local label = STEP:GetText(labelKey)

    if UIDropDownMenu_Initialize
        and UIDropDownMenu_CreateInfo
        and UIDropDownMenu_AddButton
        and UIDropDownMenu_SetWidth
        and UIDropDownMenu_SetText then
        local name = self:GetUniqueName(prefix)
        local ok, dropdown = pcall(CreateFrame, "Frame", name, parent, "UIDropDownMenuTemplate")
        if ok and dropdown then
            control.frame = dropdown
            control.dropdown = dropdown
            UIDropDownMenu_SetWidth(dropdown, width)
            UIDropDownMenu_Initialize(dropdown, function(_, level)
                for index = 1, #items do
                    local item = items[index]
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = STEP:GetText(item.labelKey)
                    info.notCheckable = true
                    info.func = function()
                        UIDropDownMenu_SetText(dropdown, label)
                        handler(item.value)
                    end
                    UIDropDownMenu_AddButton(info, level)
                end
            end)
            function control:Refresh()
                UIDropDownMenu_SetText(self.dropdown, label)
            end
            return control
        end
    end

    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 22)
    button:SetText(label)
    button:SetScript("OnClick", function()
        if items[1] then
            handler(items[1].value)
        end
    end)
    control.frame = button
    function control:Refresh()
        self.frame:SetText(label)
    end
    return control
end

function OptionsControls:CommitProposal(proposal, label)
    if not STEP.ConfigActions:ApplyProposal(proposal, "options-bulk") then
        return false
    end
    STEP:Print(STEP:GetText("CONFIG_ACTION_APPLIED", label))
    if proposal.kind == "preset" and proposal.id == "empty" then
        STEP:Print(STEP:GetText("CONFIG_NONE_VISIBLE"))
    end
    return true
end

function OptionsControls:EnsureConfirmationDialog()
    if not StaticPopupDialogs then
        return false
    end
    if not StaticPopupDialogs.STEP_CONFIRM_CONFIG_OVERWRITE then
        StaticPopupDialogs.STEP_CONFIRM_CONFIG_OVERWRITE = {
            text = "%s",
            button1 = YES or "Yes",
            button2 = NO or "No",
            OnAccept = function(_, data)
                if data then
                    OptionsControls:CommitProposal(data.proposal, data.label)
                end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end
    return true
end

function OptionsControls:RequestProposal(proposal, label)
    local analysis = STEP.ConfigActions:AnalyzeProposal(proposal)
    if not analysis or analysis.changed == 0 then
        STEP:Print(STEP:GetText("CONFIG_NO_CHANGES"))
        return false
    end

    if analysis.customOverwrites > 0 then
        if self:EnsureConfirmationDialog() and StaticPopup_Show then
            local dialog = StaticPopup_Show(
                "STEP_CONFIRM_CONFIG_OVERWRITE",
                STEP:GetText("CONFIG_CONFIRM_OVERWRITE", analysis.customOverwrites),
                nil,
                { proposal = proposal, label = label }
            )
            if dialog then
                return true
            end
        end
        STEP:Print(STEP:GetText("CONFIG_CONFIRM_UNAVAILABLE"))
        return false
    end
    return self:CommitProposal(proposal, label)
end

function OptionsControls:RequestPreset(preset)
    local proposal = STEP.ConfigActions:BuildPresetProposal(preset)
    local labelKey = presetTextKeys[preset]
    if not proposal or not labelKey then
        return false
    end
    return self:RequestProposal(proposal, STEP:GetText(labelKey))
end

function OptionsControls:RequestCategory(category, operation, value)
    local proposal = STEP.ConfigActions:BuildCategoryProposal(category, operation, value)
    local categoryKey = categoryTextKeys[category]
    if not proposal or not categoryKey then
        return false
    end
    return self:RequestProposal(proposal, STEP:GetText(categoryKey))
end

function OptionsControls:CreateLabeledEnum(parent, prefix, label, width, values, getter, setter, textKeys)
    local control = self:CreateEnumSelector(parent, prefix, width, values, getter, setter, textKeys)
    control.label = CreateText(parent, label, "GameFontHighlightSmall")
    function control:SetPoint(relativeTo, x, y)
        self.label:SetPoint("TOPLEFT", relativeTo, "TOPLEFT", x, y)
        self.frame:SetPoint("TOPLEFT", self.label, "BOTTOMLEFT", -16, -2)
    end
    return control
end

local function CreateScaleSlider(parent, prefix)
    local control = {
        refreshing = false,
    }
    control.label = CreateText(parent, STEP:GetText("OPTION_SCALE"), "GameFontHighlightSmall")
    control.value = CreateText(parent, "", "GameFontHighlightSmall")
    control.value:SetJustifyH("RIGHT")

    local name = OptionsControls:GetUniqueName(prefix)
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    control.slider = slider
    slider:SetMinMaxValues(0.5, 2)
    slider:SetValueStep(0.05)
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end
    slider:SetWidth(250)
    local low = _G and _G[name .. "Low"]
    local high = _G and _G[name .. "High"]
    local text = _G and _G[name .. "Text"]
    if low then low:SetText("50%") end
    if high then high:SetText("200%") end
    if text then text:SetText("") end

    slider:SetScript("OnValueChanged", function(_, value)
        local rounded = math.floor(value * 20 + 0.5) / 20
        control.value:SetText(tostring(math.floor(rounded * 100 + 0.5)) .. "%")
        if not control.refreshing then
            STEP.ConfigStore:Set("panel.scale", rounded, "options")
        end
    end)

    function control:SetPoint(relativeTo, x, y)
        self.label:SetPoint("TOPLEFT", relativeTo, "TOPLEFT", x, y)
        self.value:SetPoint("TOPRIGHT", relativeTo, "TOPLEFT", x + 250, y)
        self.slider:SetPoint("TOPLEFT", self.label, "BOTTOMLEFT", 0, -8)
    end
    function control:Refresh()
        self.refreshing = true
        local value = STEP.ConfigStore:Get("panel.scale") or 1
        self.slider:SetValue(value)
        self.value:SetText(tostring(math.floor(value * 100 + 0.5)) .. "%")
        self.refreshing = false
    end
    return control
end

local function CreateSection(parent, label)
    local section = CreateFrame("Frame", nil, parent)
    section:SetHeight(CATEGORY_HEIGHT)
    section.label = CreateText(section, label, "GameFontNormal")
    section.label:SetPoint("TOPLEFT", section, "TOPLEFT", 2, -2)
    section.line = section:CreateTexture(nil, "ARTWORK")
    section.line:SetHeight(1)
    section.line:SetPoint("LEFT", section.label, "RIGHT", 8, 0)
    section.line:SetPoint("TOPRIGHT", section, "TOPRIGHT", -90, -8)
    section.line:SetColorTexture(0.45, 0.45, 0.50, 0.45)

    section.skillHeader = CreateText(section, STEP:GetText("OPTION_SKILL"), "GameFontHighlightSmall")
    section.skillHeader:SetPoint("TOPLEFT", section, "TOPLEFT", 4, -28)
    section.visibilityHeader = CreateText(section, STEP:GetText("OPTION_VISIBILITY"), "GameFontHighlightSmall")
    section.visibilityHeader:SetJustifyH("CENTER")
    section.visibilityHeader:SetPoint("TOP", section, "TOPLEFT", 309, -28)
    section.logHeader = CreateText(section, STEP:GetText("OPTION_LOG"), "GameFontHighlightSmall")
    section.logHeader:SetJustifyH("CENTER")
    section.logHeader:SetPoint("TOP", section, "TOPLEFT", 504, -28)
    section.notifyHeader = CreateText(section, STEP:GetText("OPTION_NOTIFY"), "GameFontHighlightSmall")
    section.notifyHeader:SetJustifyH("CENTER")
    section.notifyHeader:SetPoint("TOP", section, "TOPLEFT", 593, -28)
    return section
end

function OptionsControls:AddCategoryActions(section, surface, category)
    section.visibilityAction = self:CreateActionSelector(
        section,
        surface.prefix .. category .. "BulkVisibility",
        128,
        "BULK_VISIBILITY",
        {
            { value = "expanded", labelKey = "OPTION_VISIBILITY_EXPANDED" },
            { value = "compact", labelKey = "OPTION_VISIBILITY_COMPACT" },
            { value = "hidden", labelKey = "OPTION_VISIBILITY_HIDDEN" },
        },
        function(value)
            self:RequestCategory(category, "visibility", value)
        end
    )
    section.visibilityAction.frame:SetPoint("TOPLEFT", section, "TOPLEFT", 224, -52)

    section.logAction = self:CreateActionSelector(
        section,
        surface.prefix .. category .. "BulkLog",
        60,
        "BULK_LOGS",
        {
            { value = true, labelKey = "BULK_ENABLE" },
            { value = false, labelKey = "BULK_DISABLE" },
        },
        function(value)
            self:RequestCategory(category, "log", value)
        end
    )
    section.logAction.frame:SetPoint("TOPLEFT", section, "TOPLEFT", 444, -52)

    section.notifyAction = self:CreateActionSelector(
        section,
        surface.prefix .. category .. "BulkNotify",
        60,
        "BULK_NOTIFY",
        {
            { value = true, labelKey = "BULK_ENABLE" },
            { value = false, labelKey = "BULK_DISABLE" },
        },
        function(value)
            self:RequestCategory(category, "notify", value)
        end
    )
    section.notifyAction.frame:SetPoint("TOPLEFT", section, "TOPLEFT", 545, -52)

    section.reset = CreateFrame("Button", nil, section, "UIPanelButtonTemplate")
    section.reset:SetSize(78, 22)
    section.reset:SetPoint("TOPRIGHT", section, "TOPRIGHT", -2, -1)
    section.reset:SetText(STEP:GetText("BULK_RESET"))
    section.reset:SetScript("OnClick", function()
        self:RequestCategory(category, "reset")
    end)
end

function OptionsControls:CreateSkillRow(parent, surface, entry)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(SKILL_ROW_HEIGHT)
    row.entry = entry

    row.background = row:CreateTexture(nil, "BACKGROUND")
    row.background:SetAllPoints()

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.name = CreateText(row, entry.localizedName or entry.names.enUS, "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetWidth(205)

    row.visibility = self:CreateEnumSelector(
        row,
        surface.prefix .. "Visibility",
        132,
        visibilityValues,
        function()
            local values = STEP.ConfigStore:GetSkill(entry.key)
            return values and values.visibility or "hidden"
        end,
        function(value)
            STEP.ConfigStore:SetSkill(entry.key, "visibility", value, "options")
        end,
        visibilityTextKeys
    )
    row.visibility.frame:SetPoint("LEFT", row, "LEFT", 226, 0)

    row.log = CreateCheck(row, "", function()
        local values = STEP.ConfigStore:GetSkill(entry.key)
        return values and values.logEnabled == true
    end, function(value)
        STEP.ConfigStore:SetSkill(entry.key, "logEnabled", value, "options")
    end, STEP:GetText("OPTION_LOG_TOOLTIP"))
    row.log:SetPoint("LEFT", row, "LEFT", 500, 0)

    row.notify = CreateCheck(row, "", function()
        local values = STEP.ConfigStore:GetSkill(entry.key)
        return values and values.notifyEnabled == true
    end, function(value)
        STEP.ConfigStore:SetSkill(entry.key, "notifyEnabled", value, "options")
    end, STEP:GetText("OPTION_NOTIFY_TOOLTIP"))
    row.notify:SetPoint("LEFT", row, "LEFT", 590, 0)

    function row:Refresh()
        self.name:SetText(self.entry.localizedName or self.entry.names.enUS)
        self.icon:SetTexture(self.entry.icon or STEP.Constants.FALLBACK_SKILL_ICON)
        self.visibility:Refresh()
        self.log:Refresh()
        self.notify:Refresh()
    end
    return row
end

local function AddGeneralCheck(surface, labelKey, path, x, y)
    local check = CreateCheck(surface.child, STEP:GetText(labelKey), function()
        return STEP.ConfigStore:Get(path) == true
    end, function(value)
        STEP.ConfigStore:Set(path, value, "options")
    end)
    check:SetPoint("TOPLEFT", surface.child, "TOPLEFT", x, y)
    surface.generalChecks[#surface.generalChecks + 1] = check
    return check
end

function OptionsControls:BuildSurface(parent, prefix)
    local surface = {
        parent = parent,
        prefix = prefix,
        generalChecks = {},
        generalEnums = {},
        skillRows = {},
        categorySections = {},
    }

    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -28, 4)
    surface.scroll = scroll

    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(CONTENT_WIDTH, 1)
    scroll:SetScrollChild(child)
    surface.child = child

    surface.title = CreateText(child, STEP:GetText("OPTIONS_TITLE"), "GameFontNormalLarge")
    surface.title:SetPoint("TOPLEFT", child, "TOPLEFT", 16, -14)
    surface.description = CreateText(child, STEP:GetText("OPTIONS_DESCRIPTION"), "GameFontHighlightSmall")
    surface.description:SetPoint("TOPLEFT", child, "TOPLEFT", 16, -42)
    surface.generalTitle = CreateText(child, STEP:GetText("OPTIONS_GENERAL"), "GameFontNormal")
    surface.generalTitle:SetPoint("TOPLEFT", child, "TOPLEFT", 16, -72)

    AddGeneralCheck(surface, "OPTION_SHOW_PANEL", "panel.shown", 16, -98)
    AddGeneralCheck(surface, "OPTION_LOCK_PANEL", "panel.locked", 16, -126)
    AddGeneralCheck(surface, "OPTION_START_EXPANDED", "panel.startExpanded", 16, -154)
    AddGeneralCheck(surface, "OPTION_SHOW_SUMMARY", "panel.showHeaderSummary", 16, -182)
    AddGeneralCheck(surface, "OPTION_HIDE_MAXED", "panel.hideMaxed", 16, -210)
    AddGeneralCheck(surface, "OPTION_AUTO_EQUIPPED", "panel.autoShowEquipped", 16, -238)

    surface.reset = CreateFrame("Button", nil, child, "UIPanelButtonTemplate")
    surface.reset:SetSize(150, 24)
    surface.reset:SetPoint("TOPLEFT", child, "TOPLEFT", 16, -278)
    surface.reset:SetText(STEP:GetText("OPTION_RESET_POSITION"))
    surface.reset:SetScript("OnClick", function()
        STEP.MainPanel:ResetPosition()
        STEP:Print(STEP:GetText("PANEL_POSITION_RESET"))
    end)

    surface.scale = CreateScaleSlider(child, prefix .. "Scale")
    surface.scale:SetPoint(child, 356, -98)

    surface.sort = self:CreateLabeledEnum(child, prefix .. "Sort", STEP:GetText("OPTION_SORT"), 220, sortValues, function()
        return STEP.ConfigStore:Get("panel.sortMode") or "progress"
    end, function(value)
        STEP.ConfigStore:Set("panel.sortMode", value, "options")
    end, sortTextKeys)
    surface.sort:SetPoint(child, 356, -164)
    surface.generalEnums[#surface.generalEnums + 1] = surface.sort

    surface.combat = self:CreateLabeledEnum(child, prefix .. "Combat", STEP:GetText("OPTION_COMBAT"), 220, combatValues, function()
        return STEP.ConfigStore:Get("panel.combatBehavior") or "keep"
    end, function(value)
        STEP.ConfigStore:Set("panel.combatBehavior", value, "options")
    end, combatTextKeys)
    surface.combat:SetPoint(child, 356, -224)
    surface.generalEnums[#surface.generalEnums + 1] = surface.combat

    surface.gainNotification = self:CreateLabeledEnum(child, prefix .. "Gain", STEP:GetText("OPTION_GAIN_NOTIFICATION"), 220, notificationValues, function()
        return STEP.ConfigStore:Get("notifications.gainMode") or "discreet"
    end, function(value)
        STEP.ConfigStore:Set("notifications.gainMode", value, "options")
    end, notificationTextKeys)
    surface.gainNotification:SetPoint(child, 356, -284)
    surface.generalEnums[#surface.generalEnums + 1] = surface.gainNotification

    surface.maxNotification = self:CreateLabeledEnum(child, prefix .. "Max", STEP:GetText("OPTION_MAX_NOTIFICATION"), 220, notificationValues, function()
        return STEP.ConfigStore:Get("notifications.maxMode") or "exaggerated"
    end, function(value)
        STEP.ConfigStore:Set("notifications.maxMode", value, "options")
    end, notificationTextKeys)
    surface.maxNotification:SetPoint(child, 356, -344)
    surface.generalEnums[#surface.generalEnums + 1] = surface.maxNotification

    surface.presetsTitle = CreateText(child, STEP:GetText("OPTIONS_PRESETS"), "GameFontNormal")
    surface.presetsTitle:SetPoint("TOPLEFT", child, "TOPLEFT", 16, -408)
    surface.presetButtons = {}
    local presetOrder = { "weapons", "professions", "complete", "empty" }
    for index = 1, #presetOrder do
        local preset = presetOrder[index]
        local button = CreateFrame("Button", nil, child, "UIPanelButtonTemplate")
        button:SetSize(146, 24)
        button:SetPoint("TOPLEFT", child, "TOPLEFT", 16 + (index - 1) * 158, -432)
        button:SetText(STEP:GetText(presetTextKeys[preset]))
        button:SetScript("OnClick", function()
            self:RequestPreset(preset)
        end)
        surface.presetButtons[#surface.presetButtons + 1] = button
    end

    surface.skillsTitle = CreateText(child, STEP:GetText("OPTIONS_SKILLS"), "GameFontNormal")
    surface.skillsTitle:SetPoint("TOPLEFT", child, "TOPLEFT", 16, -478)

    for categoryIndex = 1, #categoryOrder do
        local category = categoryOrder[categoryIndex]
        local section = CreateSection(child, STEP:GetText(categoryTextKeys[category]))
        self:AddCategoryActions(section, surface, category)
        surface.categorySections[category] = section
    end

    local entries = STEP.SkillRegistry:GetEntries()
    for index = 1, #entries do
        local entry = entries[index]
        surface.skillRows[entry.key] = self:CreateSkillRow(child, surface, entry)
    end

    parent:SetScript("OnShow", function()
        self:RefreshSurface(surface)
    end)
    self.surfaces[#self.surfaces + 1] = surface
    self:RefreshSurface(surface)
    return surface
end

function OptionsControls:RefreshSurface(surface)
    if not surface or not STEP.Database or not STEP.Database:IsCompatible() then
        return
    end

    for index = 1, #surface.generalChecks do
        surface.generalChecks[index]:Refresh()
    end
    surface.scale:Refresh()
    for index = 1, #surface.generalEnums do
        surface.generalEnums[index]:Refresh()
    end

    local snapshot = STEP.SkillScanner and STEP.SkillScanner:GetSnapshot() or {}
    local y = -504
    local visibleIndex = 0
    for categoryIndex = 1, #categoryOrder do
        local category = categoryOrder[categoryIndex]
        local section = surface.categorySections[category]
        local categoryRows = {}
        local entries = STEP.SkillRegistry:GetEntries()
        for entryIndex = 1, #entries do
            local entry = entries[entryIndex]
            local data = snapshot[entry.key]
            if entry.category == category and type(data) == "table" and data.learned ~= false then
                categoryRows[#categoryRows + 1] = surface.skillRows[entry.key]
            end
        end

        if #categoryRows > 0 then
            if visibleIndex > 0 then
                y = y - CATEGORY_GAP
            end
            section:ClearAllPoints()
            section:SetPoint("TOPLEFT", surface.child, "TOPLEFT", 16, y)
            section:SetPoint("TOPRIGHT", surface.child, "TOPRIGHT", -16, y)
            section:Show()
            section.visibilityAction:Refresh()
            section.logAction:Refresh()
            section.notifyAction:Refresh()
            y = y - CATEGORY_HEIGHT
            for rowIndex = 1, #categoryRows do
                visibleIndex = visibleIndex + 1
                local row = categoryRows[rowIndex]
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", surface.child, "TOPLEFT", 16, y)
                row:SetPoint("TOPRIGHT", surface.child, "TOPRIGHT", -16, y)
                if visibleIndex % 2 == 0 then
                    row.background:SetColorTexture(1, 1, 1, 0.025)
                else
                    row.background:SetColorTexture(0, 0, 0, 0)
                end
                row:Refresh()
                row:Show()
                y = y - SKILL_ROW_HEIGHT
            end
        else
            section:Hide()
        end
    end

    for skillKey, row in pairs(surface.skillRows) do
        local data = snapshot[skillKey]
        if type(data) ~= "table" or data.learned == false then
            row:Hide()
        end
    end
    surface.child:SetHeight(math.max(520, -y + 24))
end

function OptionsControls:RefreshAll()
    for index = 1, #self.surfaces do
        self:RefreshSurface(self.surfaces[index])
    end
end

function OptionsControls:OnStateChanged()
    self:RefreshAll()
end

function OptionsControls:Initialize()
    if self.initialized then
        return true
    end
    if not UIParent then
        return false
    end
    self:EnsureConfirmationDialog()
    STEP:RegisterCallback("CONFIG_CHANGED", self, self.OnStateChanged)
    STEP:RegisterCallback("SKILLS_UPDATED", self, self.OnStateChanged)
    self.initialized = true
    return true
end
