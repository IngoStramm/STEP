local _, STEP = ...

local function PrintHelp()
    STEP:Print(STEP:GetText("HELP_HEADER"))
    STEP:Print(STEP:GetText("HELP_PANEL"))
    STEP:Print(STEP:GetText("HELP_PANEL_STATE"))
    STEP:Print(STEP:GetText("HELP_PANEL_LOCK"))
    STEP:Print(STEP:GetText("HELP_CONFIG"))
    STEP:Print(STEP:GetText("HELP_LOG"))
    STEP:Print(STEP:GetText("HELP_BULK"))
    STEP:Print(STEP:GetText("HELP_STATUS"))
    STEP:Print(STEP:GetText("HELP_SCAN"))
    STEP:Print(STEP:GetText("HELP_DEBUG"))
    STEP:Print(STEP:GetText("HELP_SNAPSHOT"))
    STEP:Print(STEP:GetText("HELP_EQUIPMENT"))
    STEP:Print(STEP:GetText("HELP_EVENTS"))
    STEP:Print(STEP:GetText("HELP_LIVE"))
    STEP:Print(STEP:GetText("HELP_CLEAR"))
    STEP:Print(STEP:GetText("HELP_DATABASE"))
    STEP:Print(STEP:GetText("HELP_BUS"))
    STEP:Print(STEP:GetText("HELP_CONFIG_STATE"))
end

local SplitCommand
local ParseOnOff

local presetAliases = {
    weapons = "weapons",
    armas = "weapons",
    professions = "professions",
    profissoes = "professions",
    complete = "complete",
    completo = "complete",
    empty = "empty",
    vazio = "empty",
}

local categoryAliases = {
    combat = "combat",
    combate = "combat",
    primary = "primary",
    primaria = "primary",
    secondary = "secondary",
    secundaria = "secondary",
}

local visibilityAliases = {
    expanded = "expanded",
    expandido = "expanded",
    compact = "compact",
    compacto = "compact",
    hidden = "hidden",
    oculto = "hidden",
    oculta = "hidden",
}

local function HandlePreset(rest)
    local preset = presetAliases[STEP.Util:Trim(rest or ""):lower()]
    if not preset then
        STEP:Print(STEP:GetText("INVALID_COMMAND"))
        return
    end
    STEP.OptionsControls:RequestPreset(preset)
end

local function HandleCategory(rest)
    local categoryName, operationRest = SplitCommand(rest)
    local operation, value = SplitCommand(operationRest)
    local category = categoryAliases[categoryName]
    if not category then
        STEP:Print(STEP:GetText("INVALID_COMMAND"))
        return
    end

    if operation == "visibility" or operation == "visibilidade" then
        local visibility = visibilityAliases[value]
        if visibility then
            STEP.OptionsControls:RequestCategory(category, "visibility", visibility)
            return
        end
    elseif operation == "log" then
        local enabled = ParseOnOff(value)
        if enabled ~= nil then
            STEP.OptionsControls:RequestCategory(category, "log", enabled)
            return
        end
    elseif operation == "notify" or operation == "notificar" then
        local enabled = ParseOnOff(value)
        if enabled ~= nil then
            STEP.OptionsControls:RequestCategory(category, "notify", enabled)
            return
        end
    elseif operation == "reset" or operation == "padrao" then
        STEP.OptionsControls:RequestCategory(category, "reset")
        return
    end
    STEP:Print(STEP:GetText("INVALID_COMMAND"))
end

SplitCommand = function(message)
    local trimmed = STEP.Util:Trim(message or "") or ""
    local command, rest = trimmed:match("^(%S+)%s*(.-)$")
    return command and command:lower() or "", rest or ""
end

ParseOnOff = function(value)
    local normalized = STEP.Util:Trim(value or ""):lower()
    if normalized == "on" then
        return true
    elseif normalized == "off" then
        return false
    end
    return nil
end

local function RequireDebug()
    if STEP.DebugProbe and STEP.DebugProbe:IsEnabled() then
        return true
    end
    STEP:Print(STEP:GetText("DEBUG_REQUIRED"))
    return false
end

local function HandleDebug(rest)
    local subcommand, value = SplitCommand(rest)

    if subcommand == "on" then
        STEP.DebugProbe:SetEnabled(true)
    elseif subcommand == "off" then
        STEP.DebugProbe:SetEnabled(false)
    elseif subcommand == "snapshot" then
        if RequireDebug() then
            STEP.SkillScanner:DumpSnapshot()
        end
    elseif subcommand == "equipment" then
        if RequireDebug() then
            STEP.EquipmentResolver:Dump()
        end
    elseif subcommand == "events" then
        if RequireDebug() then
            STEP.DebugProbe:DumpEvents()
        end
    elseif subcommand == "clear" then
        if RequireDebug() then
            STEP.DebugProbe:Clear()
        end
    elseif subcommand == "database" then
        if RequireDebug() then
            STEP.Database:DumpStatus()
        end
    elseif subcommand == "bus" then
        if RequireDebug() then
            STEP:Print("EventBus listeners=" .. tostring(STEP.EventBus:GetListenerCount()))
        end
    elseif subcommand == "config" then
        if RequireDebug() then
            STEP.ConfigStore:DumpSkill(value)
        end
    elseif subcommand == "combat" or subcommand == "casts" then
        local enabled = ParseOnOff(value)
        if enabled == nil then
            STEP:Print(STEP:GetText("INVALID_COMMAND"))
        elseif RequireDebug() then
            STEP.DebugProbe:SetLive(subcommand, enabled)
        end
    else
        STEP:Print(STEP:GetText("INVALID_COMMAND"))
    end
end

local function HandleSlashCommand(message)
    local command, rest = SplitCommand(message)

    if command == "" then
        STEP.MainPanel:ToggleShown()
    elseif command == "help" then
        PrintHelp()
    elseif command == "status" then
        STEP.DebugProbe:DumpStatus()
    elseif command == "scan" then
        STEP.SkillScanner:Schedule("slash")
        STEP:Print(STEP:GetText("SCAN_REQUESTED"))
    elseif command == "debug" then
        HandleDebug(rest)
    elseif command == "expand" then
        STEP.MainPanel:SetExpanded(true)
    elseif command == "compact" then
        STEP.MainPanel:SetExpanded(false)
    elseif command == "toggle" then
        STEP.MainPanel:ToggleExpanded()
    elseif command == "show" then
        STEP.MainPanel:SetShown(true)
    elseif command == "hide" then
        STEP.MainPanel:SetShown(false)
    elseif command == "lock" then
        local locked = STEP.MainPanel:ToggleLocked()
        STEP:Print(STEP:GetText(locked and "PANEL_LOCKED" or "PANEL_UNLOCKED"))
    elseif command == "reset" then
        STEP.MainPanel:ResetPosition()
        STEP:Print(STEP:GetText("PANEL_POSITION_RESET"))
    elseif command == "config" then
        STEP.ConfigWindow:Open()
    elseif command == "options" then
        STEP.NativeOptions:Open()
    elseif command == "log" then
        if not (STEP.HistoryWindow and STEP.HistoryWindow:Open()) then
            STEP.HistoryStore:DumpSummary()
        end
    elseif command == "preset" then
        HandlePreset(rest)
    elseif command == "category" or command == "categoria" then
        HandleCategory(rest)
    else
        STEP:Print(STEP:GetText("INVALID_COMMAND"))
    end
end

SLASH_STEP1 = "/step"
SlashCmdList.STEP = HandleSlashCommand
