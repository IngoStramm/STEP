local _, STEP = ...

local ConfigStore = {
    initialized = false,
}
STEP.ConfigStore = ConfigStore

local validAnchors = {
    TOPLEFT = true,
    TOP = true,
    TOPRIGHT = true,
    LEFT = true,
    CENTER = true,
    RIGHT = true,
    BOTTOMLEFT = true,
    BOTTOM = true,
    BOTTOMRIGHT = true,
}

local function IsBoolean(value)
    return type(value) == "boolean"
end

local function IsScale(value)
    return STEP.Util:IsFiniteNumber(value) and value >= 0.5 and value <= 2
end

local function IsCoordinate(value)
    return STEP.Util:IsFiniteNumber(value)
end

local function IsAnchor(value)
    return type(value) == "string" and validAnchors[value] == true
end

local function IsEnum(enumName, value)
    local values = STEP.Constants.CONFIG_ENUMS[enumName]
    return type(value) == "string" and values and values[value] == true
end

local generalFields = {
    ["panel.shown"] = IsBoolean,
    ["panel.locked"] = IsBoolean,
    ["panel.scale"] = IsScale,
    ["panel.point"] = IsAnchor,
    ["panel.relativePoint"] = IsAnchor,
    ["panel.x"] = IsCoordinate,
    ["panel.y"] = IsCoordinate,
    ["panel.expanded"] = IsBoolean,
    ["panel.startExpanded"] = IsBoolean,
    ["panel.showHeaderSummary"] = IsBoolean,
    ["panel.sortMode"] = function(value) return IsEnum("sortMode", value) end,
    ["panel.hideMaxed"] = IsBoolean,
    ["panel.combatBehavior"] = function(value) return IsEnum("combatBehavior", value) end,
    ["panel.autoShowEquipped"] = IsBoolean,
    ["notifications.gainMode"] = function(value) return IsEnum("notificationMode", value) end,
    ["notifications.maxMode"] = function(value) return IsEnum("notificationMode", value) end,
}

local skillFields = {
    visibility = function(value) return IsEnum("visibility", value) end,
    logEnabled = IsBoolean,
    notifyEnabled = IsBoolean,
}

local function SplitGeneralPath(path)
    if type(path) ~= "string" then
        return nil
    end
    local section, field = path:match("^([^.]+)%.([^.]+)$")
    if not section or not field then
        return nil
    end
    return section, field
end

local function GetDefaultGeneral(path)
    local section, field = SplitGeneralPath(path)
    local defaults = STEP.Database.defaults.config
    return section and defaults[section] and defaults[section][field]
end

local function IsEquippedSkill(skillKey)
    local state = STEP.EquipmentResolver and STEP.EquipmentResolver.state or {}
    for _, item in pairs(state) do
        if item.skillKey == skillKey then
            return true
        end
    end
    return false
end

function ConfigStore:Initialize()
    if self.initialized then
        return true
    end
    if not STEP.Database or not STEP.Database:IsCompatible() then
        return false
    end

    local config = STEP.Database.db.config
    for path, validator in pairs(generalFields) do
        local section, field = SplitGeneralPath(path)
        if not validator(config[section][field]) then
            config[section][field] = GetDefaultGeneral(path)
        end
    end

    for skillKey, values in pairs(config.skills) do
        if type(values) ~= "table" then
            config.skills[skillKey] = nil
        else
            local entry = STEP.SkillRegistry and STEP.SkillRegistry:Get(skillKey)
            if entry then
                local defaults = self:GetSkillDefaults(skillKey)
                for field, validator in pairs(skillFields) do
                    if not validator(values[field]) then
                        values[field] = defaults[field]
                    end
                end
            end
        end
    end

    self.initialized = true
    return true
end

function ConfigStore:Get(path)
    if not STEP.Database or not STEP.Database:IsCompatible() or not generalFields[path] then
        return nil
    end
    local section, field = SplitGeneralPath(path)
    return STEP.Database.db.config[section][field]
end

function ConfigStore:Set(path, value, source)
    local validator = generalFields[path]
    if not validator or not validator(value) or not STEP.Database:IsCompatible() then
        return false
    end

    local section, field = SplitGeneralPath(path)
    local config = STEP.Database.db.config
    local previous = config[section][field]
    if previous == value then
        return true
    end

    config[section][field] = value
    STEP:Fire("CONFIG_CHANGED", {
        source = source or "api",
        batch = false,
        changes = {
            {
                scope = "general",
                path = path,
                previous = previous,
                value = value,
            },
        },
    })
    return true
end

function ConfigStore:Reset(path, source)
    if not generalFields[path] then
        return false
    end
    return self:Set(path, GetDefaultGeneral(path), source or "reset")
end

function ConfigStore:GetSkillDefaults(skillKey)
    local entry = STEP.SkillRegistry and STEP.SkillRegistry:Get(skillKey)
    if not entry then
        return nil
    end

    local visibility = entry.defaultVisibility or "hidden"
    if visibility ~= "hidden" and IsEquippedSkill(skillKey) then
        visibility = "compact"
    end
    local enabled = visibility ~= "hidden"
    return {
        visibility = visibility,
        logEnabled = enabled,
        notifyEnabled = enabled,
    }
end

function ConfigStore:EnsureSkill(skillKey)
    if not STEP.Database:IsCompatible() then
        return nil, false
    end

    local entry = STEP.SkillRegistry and STEP.SkillRegistry:Get(skillKey)
    if not entry then
        return nil, false
    end

    local config = STEP.Database.db.config.skills
    local preferencesSeen = STEP.Database.db.state.preferencesSeen
    local created = type(config[skillKey]) ~= "table"
    if created then
        config[skillKey] = self:GetSkillDefaults(skillKey)
    end

    local defaults = self:GetSkillDefaults(skillKey)
    for field, validator in pairs(skillFields) do
        if not validator(config[skillKey][field]) then
            config[skillKey][field] = defaults[field]
        end
    end
    preferencesSeen[skillKey] = true
    return config[skillKey], created
end

function ConfigStore:GetSkill(skillKey)
    if not STEP.Database or not STEP.Database:IsCompatible() then
        return nil
    end
    if not STEP.SkillRegistry or not STEP.SkillRegistry:Get(skillKey) then
        return nil
    end

    local values = STEP.Database.db.config.skills[skillKey]
    return type(values) == "table" and values or nil
end

function ConfigStore:SetSkill(skillKey, field, value, source)
    local validator = skillFields[field]
    if not validator or not validator(value) then
        return false
    end

    local values = self:EnsureSkill(skillKey)
    if not values then
        return false
    end
    local previous = values[field]
    if previous == value then
        return true
    end

    values[field] = value
    STEP:Fire("CONFIG_CHANGED", {
        source = source or "api",
        batch = false,
        changes = {
            {
                scope = "skill",
                skillKey = skillKey,
                field = field,
                previous = previous,
                value = value,
            },
        },
    })
    return true
end

function ConfigStore:ResetSkill(skillKey, source)
    local values = self:EnsureSkill(skillKey)
    local defaults = self:GetSkillDefaults(skillKey)
    if not values or not defaults then
        return false
    end

    local changes = {}
    for field in pairs(skillFields) do
        if values[field] ~= defaults[field] then
            changes[#changes + 1] = {
                scope = "skill",
                skillKey = skillKey,
                field = field,
                value = defaults[field],
            }
        end
    end
    return self:ApplyBatch(changes, source or "reset")
end

function ConfigStore:ApplyBatch(proposed, source)
    if type(proposed) ~= "table" or not STEP.Database:IsCompatible() then
        return false
    end

    local normalized = {}
    local normalizedOrder = {}
    for index = 1, #proposed do
        local change = proposed[index]
        if type(change) ~= "table" then
            return false
        end

        if change.scope == "skill" then
            local validator = skillFields[change.field]
            local entry = STEP.SkillRegistry and STEP.SkillRegistry:Get(change.skillKey)
            local values = entry and STEP.Database.db.config.skills[change.skillKey]
            if type(values) ~= "table" then
                values = entry and self:GetSkillDefaults(change.skillKey) or nil
            end
            if not validator or not entry or not values or not validator(change.value) then
                return false
            end
            local identity = "skill\031" .. change.skillKey .. "\031" .. change.field
            if not normalized[identity] then
                normalizedOrder[#normalizedOrder + 1] = identity
            end
            normalized[identity] = {
                scope = "skill",
                skillKey = change.skillKey,
                field = change.field,
                previous = values[change.field],
                value = change.value,
            }
        else
            local validator = generalFields[change.path]
            if not validator or not validator(change.value) then
                return false
            end
            local section, field = SplitGeneralPath(change.path)
            local identity = "general\031" .. change.path
            if not normalized[identity] then
                normalizedOrder[#normalizedOrder + 1] = identity
            end
            normalized[identity] = {
                scope = "general",
                path = change.path,
                section = section,
                field = field,
                previous = STEP.Database.db.config[section][field],
                value = change.value,
            }
        end
    end

    local applied = {}
    for index = 1, #normalizedOrder do
        local change = normalized[normalizedOrder[index]]
        if change.previous ~= change.value then
            if change.scope == "skill" then
                local values = self:EnsureSkill(change.skillKey)
                values[change.field] = change.value
            else
                STEP.Database.db.config[change.section][change.field] = change.value
                change.section = nil
                change.field = nil
            end
            applied[#applied + 1] = change
        end
    end

    if #applied > 0 then
        STEP:Fire("CONFIG_CHANGED", {
            source = source or "batch",
            batch = true,
            changes = applied,
        })
    end
    return true
end

function ConfigStore:DumpSkill(skillKey)
    local values = self:GetSkill(skillKey)
    if not values then
        STEP:Print("Unknown skill key: " .. tostring(skillKey))
        return
    end
    STEP:Print(string.format(
        "%s visibility=%s log=%s notify=%s",
        skillKey,
        tostring(values.visibility),
        tostring(values.logEnabled),
        tostring(values.notifyEnabled)
    ))
end
