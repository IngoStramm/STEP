local _, STEP = ...

local ViewModel = {}
STEP.ViewModel = ViewModel

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

local slotOrder = {
    "mainHand",
    "offHand",
    "ranged",
}

ViewModel.COLORS = {
    green = { r = 0.20, g = 1.00, b = 0.20 },
    yellow = { r = 1.00, g = 0.82, b = 0.00 },
    red = { r = 1.00, g = 0.20, b = 0.20 },
    neutral = { r = 0.72, g = 0.72, b = 0.72 },
    white = { r = 1.00, g = 1.00, b = 1.00 },
}

local function GetGeneralOption(options, optionKey, configPath, fallback)
    if options[optionKey] ~= nil then
        return options[optionKey]
    end
    if STEP.ConfigStore then
        local value = STEP.ConfigStore:Get(configPath)
        if value ~= nil then
            return value
        end
    end
    return fallback
end

local function BuildEquippedMap(equipment)
    local equipped = {}
    for index = 1, #slotOrder do
        local slotKey = slotOrder[index]
        local item = equipment and equipment[slotKey]
        if item and not item.unresolved and item.skillKey then
            local slots = equipped[item.skillKey]
            if not slots then
                slots = {}
                equipped[item.skillKey] = slots
            end
            slots[#slots + 1] = slotKey
        end
    end
    return equipped
end

local function GetDefaultSkillConfig(entry, isEquipped)
    local visibility = entry.defaultVisibility or "hidden"
    if visibility ~= "hidden" and isEquipped then
        visibility = "compact"
    end
    local enabled = visibility ~= "hidden"
    return {
        visibility = visibility,
        logEnabled = enabled,
        notifyEnabled = enabled,
    }
end

local function ResolveSkillConfig(skillConfigs, entry, isEquipped)
    local values = skillConfigs and skillConfigs[entry.key]
    if type(values) ~= "table" then
        return GetDefaultSkillConfig(entry, isEquipped)
    end

    return {
        visibility = values.visibility or "hidden",
        logEnabled = values.logEnabled == true,
        notifyEnabled = values.notifyEnabled == true,
    }
end

local function IsVisible(visibility, mode, isEquipped, autoShowEquipped)
    if visibility == "hidden" then
        return false
    end
    if mode == "expanded" then
        return visibility == "expanded" or visibility == "compact"
    end
    if visibility == "compact" then
        return true
    end
    return autoShowEquipped and isEquipped and visibility == "expanded"
end

local function GetProgress(current, maximum)
    if maximum <= 0 then
        return 0, "neutral", false
    end

    local ratio = STEP.Util:Clamp(current / maximum, 0, 1)
    if current >= maximum then
        return ratio, "green", true
    elseif ratio >= 0.90 then
        return ratio, "yellow", false
    end
    return ratio, "red", false
end

local function AlphabeticalValue(value)
    return tostring(value or ""):lower()
end

local function CompareAlphabetical(left, right)
    local leftName = AlphabeticalValue(left.name)
    local rightName = AlphabeticalValue(right.name)
    if leftName == rightName then
        return left.skillKey < right.skillKey
    end
    return leftName < rightName
end

local function CompareProgress(left, right)
    if left.progress == right.progress then
        if left.isMaxed ~= right.isMaxed then
            return not left.isMaxed
        end
        return CompareAlphabetical(left, right)
    end
    return left.progress < right.progress
end

local function BuildRow(skillKey, data, entry, skillConfig, equippedSlots, transientState)
    local current = tonumber(data.current) or 0
    local maximum = tonumber(data.maximum) or 0
    local temporary = tonumber(data.temporary) or 0
    local modifier = tonumber(data.modifier) or 0
    local progress, progressState, isMaxed = GetProgress(current, maximum)
    local name = entry.localizedName or data.name or entry.names.enUS or skillKey
    local progressPercent = math.floor(progress * 100 + 0.00001)
    local missingPoints = maximum > 0 and math.max(0, maximum - current) or 0
    local bonusTotal = temporary + modifier
    local transientKind = type(transientState) == "table" and transientState.kind
        or transientState and "gain"
        or nil

    return {
        skillKey = skillKey,
        category = entry.category,
        tracker = entry.tracker,
        icon = entry.icon or STEP.Constants.FALLBACK_SKILL_ICON,
        name = name,
        fullName = name,
        current = current,
        maximum = maximum,
        temporary = temporary,
        modifier = modifier,
        bonusTotal = bonusTotal,
        currentText = tostring(current),
        maximumText = tostring(maximum),
        progress = progress,
        progressPercent = progressPercent,
        progressState = progressState,
        progressValid = maximum > 0,
        missingPoints = missingPoints,
        isMaxed = isMaxed,
        currentColor = ViewModel.COLORS[progressState],
        separatorColor = ViewModel.COLORS.white,
        maximumColor = ViewModel.COLORS.white,
        visibility = skillConfig.visibility,
        logEnabled = skillConfig.logEnabled,
        notifyEnabled = skillConfig.notifyEnabled,
        isEquipped = equippedSlots ~= nil,
        equippedSlots = equippedSlots or {},
        isTransient = transientState ~= nil and transientState ~= false,
        transientKind = transientKind,
        transientToken = type(transientState) == "table" and transientState.token or nil,
        tooltip = {
            skillKey = skillKey,
            name = name,
            current = current,
            maximum = maximum,
            temporary = temporary,
            modifier = modifier,
            bonusTotal = bonusTotal,
            effective = current + bonusTotal,
            progressPercent = progressPercent,
            missingPoints = missingPoints,
            valueText = tostring(current) .. "/" .. tostring(maximum),
            bonusText = bonusTotal > 0 and "+" .. tostring(bonusTotal) or tostring(bonusTotal),
            isEquipped = equippedSlots ~= nil,
            equippedSlots = equippedSlots or {},
        },
    }
end

function ViewModel:ResolvePanelState(options, counts)
    options = options or {}
    local persistedExpanded = GetGeneralOption(options, "expanded", "panel.expanded", false) == true
    local requestedMode = options.effectiveMode or options.mode
    local explicitMode = requestedMode == "expanded" and "expanded"
        or requestedMode == "compact" and "compact"
        or nil
    local combatBehavior = GetGeneralOption(options, "combatBehavior", "panel.combatBehavior", "keep")
    if combatBehavior ~= "compact" and combatBehavior ~= "hide" then
        combatBehavior = "keep"
    end
    local inCombat = options.inCombat == true
    local combatOverride
    local mode = explicitMode or (persistedExpanded and "expanded" or "compact")
    if not explicitMode and inCombat and combatBehavior == "compact" then
        mode = "compact"
        combatOverride = "compact"
    elseif inCombat and combatBehavior == "hide" then
        combatOverride = "hide"
    end

    local panelShown = GetGeneralOption(options, "panelShown", "panel.shown", true) == true
    local displayed = counts and counts.displayed or nil
    local eligible = counts and counts.eligible or 0
    local eligibleMaxed = counts and counts.eligibleMaxed or 0
    local emptyReason
    if not panelShown then
        emptyReason = "panel_disabled"
    elseif combatOverride == "hide" then
        emptyReason = "combat_hidden"
    elseif displayed ~= nil and displayed == 0 then
        if counts.hideMaxed and eligible > 0 and eligible == eligibleMaxed then
            emptyReason = "all_maxed_hidden"
        else
            emptyReason = "no_selected_skills"
        end
    end

    return {
        mode = mode,
        persistedExpanded = persistedExpanded,
        inCombat = inCombat,
        combatBehavior = combatBehavior,
        combatOverride = combatOverride,
        panelShown = panelShown,
        shouldShowPanel = emptyReason == nil,
        emptyReason = emptyReason,
    }
end

local function BuildSummary(total, maxed, showHeaderSummary)
    local needsTraining = total - maxed
    local text
    if showHeaderSummary and total > 0 then
        if needsTraining == 0 then
            text = STEP:GetText("SUMMARY_MAXED", maxed, total)
        elseif needsTraining == 1 then
            text = STEP:GetText("SUMMARY_NEEDS_TRAINING_ONE", needsTraining)
        else
            text = STEP:GetText("SUMMARY_NEEDS_TRAINING_MANY", needsTraining)
        end
    end

    return {
        total = total,
        maxed = maxed,
        needsTraining = needsTraining,
        text = text,
    }
end

function ViewModel:Build(options)
    options = options or {}
    local snapshot = options.snapshot
        or STEP.SkillScanner and STEP.SkillScanner:GetSnapshot()
        or {}
    local skillConfigs = options.skillConfigs
        or STEP.Database and STEP.Database.db and STEP.Database.db.config.skills
        or {}
    local equipment = options.equipment
        or STEP.EquipmentResolver and STEP.EquipmentResolver:GetState()
        or {}
    local equipped = BuildEquippedMap(equipment)

    local initialPanelState = self:ResolvePanelState(options)
    local mode = initialPanelState.mode
    local sortMode = GetGeneralOption(options, "sortMode", "panel.sortMode", "progress")
    if sortMode ~= "alphabetical" then
        sortMode = "progress"
    end
    local hideMaxed = GetGeneralOption(options, "hideMaxed", "panel.hideMaxed", false) == true
    local autoShowEquipped = GetGeneralOption(options, "autoShowEquipped", "panel.autoShowEquipped", false) == true
    local showHeaderSummary = GetGeneralOption(options, "showHeaderSummary", "panel.showHeaderSummary", true) == true
    local transient = type(options.transient) == "table" and options.transient or {}

    local rowsByCategory = {
        combat = {},
        primary = {},
        secondary = {},
    }
    local summaryTotal = 0
    local summaryMaxed = 0
    local modeEligibleTotal = 0
    local modeEligibleMaxed = 0
    local diagnostics = {}

    for skillKey, data in pairs(snapshot) do
        local entry = STEP.SkillRegistry and STEP.SkillRegistry:Get(skillKey)
        if entry and rowsByCategory[entry.category] and type(data) == "table" and data.learned ~= false then
            local equippedSlots = equipped[skillKey]
            local skillConfig = ResolveSkillConfig(skillConfigs, entry, equippedSlots ~= nil)
            local current = tonumber(data.current) or 0
            local maximum = tonumber(data.maximum) or 0
            local isMaxed = maximum > 0 and current >= maximum
            if maximum <= 0 then
                diagnostics[#diagnostics + 1] = {
                    skillKey = skillKey,
                    code = "invalid_maximum",
                }
            end
            if skillConfig.visibility ~= "hidden" then
                summaryTotal = summaryTotal + 1
                if isMaxed then
                    summaryMaxed = summaryMaxed + 1
                end
            end

            local transientState = transient[skillKey]
            local visible = IsVisible(
                skillConfig.visibility,
                mode,
                equippedSlots ~= nil,
                autoShowEquipped
            ) or (transientState ~= nil and transientState ~= false)
            if visible then
                modeEligibleTotal = modeEligibleTotal + 1
                if isMaxed then
                    modeEligibleMaxed = modeEligibleMaxed + 1
                end
            end
            if visible and not (hideMaxed and isMaxed and not transientState) then
                rowsByCategory[entry.category][#rowsByCategory[entry.category] + 1] = BuildRow(
                    skillKey,
                    data,
                    entry,
                    skillConfig,
                    equippedSlots,
                    transientState
                )
            end
        end
    end

    local comparator = sortMode == "alphabetical" and CompareAlphabetical or CompareProgress
    local sections = {}
    local rows = {}

    table.sort(diagnostics, function(left, right)
        return left.skillKey < right.skillKey
    end)

    for categoryIndex = 1, #categoryOrder do
        local category = categoryOrder[categoryIndex]
        local categoryRows = rowsByCategory[category]
        table.sort(categoryRows, comparator)
        if #categoryRows > 0 then
            sections[#sections + 1] = {
                key = category,
                label = STEP:GetText(categoryTextKeys[category]),
                rows = categoryRows,
            }
            for rowIndex = 1, #categoryRows do
                local row = categoryRows[rowIndex]
                rows[#rows + 1] = row
            end
        end
    end

    local showSectionHeaders = #sections > 1
    for sectionIndex = 1, #sections do
        sections[sectionIndex].showHeader = showSectionHeaders
        sections[sectionIndex].hasSeparatorBefore = showSectionHeaders and sectionIndex > 1
    end

    local summary = BuildSummary(summaryTotal, summaryMaxed, showHeaderSummary)
    local panelState = self:ResolvePanelState(options, {
        displayed = #rows,
        eligible = modeEligibleTotal,
        eligibleMaxed = modeEligibleMaxed,
        hideMaxed = hideMaxed,
    })
    return {
        mode = mode,
        expanded = mode == "expanded",
        persistedExpanded = panelState.persistedExpanded,
        sortMode = sortMode,
        hideMaxed = hideMaxed,
        autoShowEquipped = autoShowEquipped,
        sections = sections,
        rows = rows,
        displayedCount = #rows,
        eligibleCount = modeEligibleTotal,
        counts = {
            enabled = summaryTotal,
            modeEligible = modeEligibleTotal,
            displayed = #rows,
        },
        empty = #rows == 0,
        showSectionHeaders = showSectionHeaders,
        summary = summary,
        headerText = summary.text,
        panelShown = panelState.panelShown,
        inCombat = panelState.inCombat,
        combatBehavior = panelState.combatBehavior,
        combatOverride = panelState.combatOverride,
        shouldShowPanel = panelState.shouldShowPanel,
        emptyReason = panelState.emptyReason,
        hiddenReason = panelState.emptyReason,
        diagnostics = diagnostics,
    }
end
