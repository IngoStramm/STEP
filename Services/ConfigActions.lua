local _, STEP = ...

local ConfigActions = {}
STEP.ConfigActions = ConfigActions

local validCategories = {
    combat = true,
    primary = true,
    secondary = true,
}

local validPresets = {
    weapons = true,
    professions = true,
    complete = true,
    empty = true,
}

local function BuildEquippedMap(equipment)
    local equipped = {}
    for _, item in pairs(equipment or {}) do
        if type(item) == "table" and item.skillKey then
            equipped[item.skillKey] = true
        end
    end
    return equipped
end

local function GetContext(options)
    options = options or {}
    local snapshot = options.snapshot
        or STEP.SkillScanner and STEP.SkillScanner:GetSnapshot()
        or {}
    local equipment = options.equipment
        or STEP.EquipmentResolver and STEP.EquipmentResolver:GetState()
        or {}
    return snapshot, BuildEquippedMap(equipment)
end

local function GetLearnedEntries(category, options)
    local snapshot = GetContext(options)
    local learned = {}
    local entries = STEP.SkillRegistry:GetEntries()
    for index = 1, #entries do
        local entry = entries[index]
        local data = snapshot[entry.key]
        if (not category or entry.category == category)
            and type(data) == "table"
            and data.learned ~= false then
            learned[#learned + 1] = entry
        end
    end
    return learned
end

local function AddSkillChange(changes, skillKey, field, value)
    changes[#changes + 1] = {
        scope = "skill",
        skillKey = skillKey,
        field = field,
        value = value,
    }
end

local function AddSkillState(changes, skillKey, visibility, enabled)
    AddSkillChange(changes, skillKey, "visibility", visibility)
    AddSkillChange(changes, skillKey, "logEnabled", enabled)
    AddSkillChange(changes, skillKey, "notifyEnabled", enabled)
end

local function IsSpecialCombatSkill(skillKey)
    return skillKey == "combat.defense" or skillKey == "combat.unarmed"
end

function ConfigActions:BuildCategoryProposal(category, operation, value, options)
    if not validCategories[category] then
        return nil
    end
    if operation == "visibility" then
        if value ~= "hidden" and value ~= "expanded" and value ~= "compact" then
            return nil
        end
    elseif operation == "log" or operation == "notify" then
        if type(value) ~= "boolean" then
            return nil
        end
    elseif operation ~= "reset" then
        return nil
    end

    local changes = {}
    local entries = GetLearnedEntries(category, options)
    for index = 1, #entries do
        local entry = entries[index]
        if operation == "visibility" then
            AddSkillChange(changes, entry.key, "visibility", value)
        elseif operation == "log" then
            AddSkillChange(changes, entry.key, "logEnabled", value)
        elseif operation == "notify" then
            AddSkillChange(changes, entry.key, "notifyEnabled", value)
        else
            local defaults = STEP.ConfigStore:GetSkillDefaults(entry.key)
            AddSkillChange(changes, entry.key, "visibility", defaults.visibility)
            AddSkillChange(changes, entry.key, "logEnabled", defaults.logEnabled)
            AddSkillChange(changes, entry.key, "notifyEnabled", defaults.notifyEnabled)
        end
    end

    return {
        kind = "category",
        id = category,
        operation = operation,
        value = value,
        changes = changes,
    }
end

function ConfigActions:BuildPresetProposal(preset, options)
    if not validPresets[preset] then
        return nil
    end

    local _, equipped = GetContext(options)
    local changes = {}
    local entries = GetLearnedEntries(nil, options)
    for index = 1, #entries do
        local entry = entries[index]
        local visibility = "hidden"
        local enabled = false

        if preset == "weapons" then
            if entry.category == "combat" and not IsSpecialCombatSkill(entry.key) then
                visibility = equipped[entry.key] and "compact" or "expanded"
                enabled = true
            end
        elseif preset == "professions" then
            if entry.category == "primary" or entry.category == "secondary" then
                visibility = "compact"
                enabled = true
            end
        elseif preset == "complete" then
            if not IsSpecialCombatSkill(entry.key) then
                visibility = equipped[entry.key] and "compact" or "expanded"
                enabled = true
            end
        end

        AddSkillState(changes, entry.key, visibility, enabled)
    end

    return {
        kind = "preset",
        id = preset,
        changes = changes,
    }
end

local function GetCurrentAndDefault(change)
    if change.scope ~= "skill" then
        return nil, nil
    end
    local current = STEP.ConfigStore:GetSkill(change.skillKey)
        or STEP.ConfigStore:GetSkillDefaults(change.skillKey)
    local defaults = STEP.ConfigStore:GetSkillDefaults(change.skillKey)
    if not current or not defaults then
        return nil, nil
    end
    return current[change.field], defaults[change.field]
end

function ConfigActions:AnalyzeProposal(proposal)
    if type(proposal) ~= "table" or type(proposal.changes) ~= "table" then
        return nil
    end

    local analysis = {
        total = #proposal.changes,
        changed = 0,
        customOverwrites = 0,
    }
    for index = 1, #proposal.changes do
        local change = proposal.changes[index]
        local current, default = GetCurrentAndDefault(change)
        if current ~= nil and current ~= change.value then
            analysis.changed = analysis.changed + 1
            if current ~= default then
                analysis.customOverwrites = analysis.customOverwrites + 1
            end
        end
    end
    return analysis
end

function ConfigActions:ApplyProposal(proposal, source)
    if type(proposal) ~= "table" or type(proposal.changes) ~= "table" then
        return false
    end
    return STEP.ConfigStore:ApplyBatch(proposal.changes, source or proposal.kind or "bulk")
end
