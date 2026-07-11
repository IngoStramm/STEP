local _, STEP = ...

local function PrintHelp()
    STEP:Print(STEP:GetText("HELP_HEADER"))
    STEP:Print(STEP:GetText("HELP_STATUS"))
    STEP:Print(STEP:GetText("HELP_SCAN"))
    STEP:Print(STEP:GetText("HELP_DEBUG"))
    STEP:Print(STEP:GetText("HELP_SNAPSHOT"))
    STEP:Print(STEP:GetText("HELP_EQUIPMENT"))
    STEP:Print(STEP:GetText("HELP_EVENTS"))
    STEP:Print(STEP:GetText("HELP_LIVE"))
    STEP:Print(STEP:GetText("HELP_CLEAR"))
end

local function SplitCommand(message)
    local trimmed = STEP.Util:Trim(message or "") or ""
    local command, rest = trimmed:match("^(%S+)%s*(.-)$")
    return command and command:lower() or "", rest or ""
end

local function ParseOnOff(value)
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

    if command == "" or command == "help" then
        PrintHelp()
    elseif command == "status" then
        STEP.DebugProbe:DumpStatus()
    elseif command == "scan" then
        STEP.SkillScanner:Schedule("slash")
        STEP:Print(STEP:GetText("SCAN_REQUESTED"))
    elseif command == "debug" then
        HandleDebug(rest)
    else
        STEP:Print(STEP:GetText("INVALID_COMMAND"))
    end
end

SLASH_STEP1 = "/step"
SlashCmdList.STEP = HandleSlashCommand
