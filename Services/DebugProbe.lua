local _, STEP = ...

local DebugProbe = {
    events = {},
}
STEP.DebugProbe = DebugProbe

local function IsPlayerUnit(unit)
    return unit == "player"
end

function DebugProbe:GetConfig()
    return STEP.Database and STEP.Database:GetDebugConfig()
end

function DebugProbe:IsEnabled()
    local config = self:GetConfig()
    return config and config.enabled == true
end

function DebugProbe:SetEnabled(enabled)
    local config = self:GetConfig()
    if not config then
        return
    end

    config.enabled = enabled == true
    STEP:Print(STEP:GetText(config.enabled and "DEBUG_ENABLED" or "DEBUG_DISABLED"))
end

function DebugProbe:SetLive(kind, enabled)
    local config = self:GetConfig()
    if not config then
        return
    end

    if kind == "combat" then
        config.liveCombat = enabled == true
        STEP:Print(STEP:GetText(config.liveCombat and "LIVE_COMBAT_ON" or "LIVE_COMBAT_OFF"))
    elseif kind == "casts" then
        config.liveCasts = enabled == true
        STEP:Print(STEP:GetText(config.liveCasts and "LIVE_CASTS_ON" or "LIVE_CASTS_OFF"))
    end
end

function DebugProbe:Record(kind, message, showLive)
    if not self:IsEnabled() then
        return
    end

    local entry = {
        at = STEP.Util:MonotonicTime(),
        kind = kind,
        message = tostring(message or ""),
    }

    local limit = STEP.Constants.DEBUG_EVENT_LIMIT
    if #self.events >= limit then
        table.remove(self.events, 1)
    end
    self.events[#self.events + 1] = entry

    if showLive then
        STEP:Print(kind .. ": " .. entry.message)
    end
end

function DebugProbe:HandleCombatLog()
    if not self:IsEnabled() or not CombatLogGetCurrentEventInfo then
        return
    end

    local info = STEP.Util:Pack(CombatLogGetCurrentEventInfo())
    local subevent = info[2]
    if not STEP.Constants.COMBAT_SUBEVENTS[subevent] then
        return
    end

    local playerGUID = UnitGUID and UnitGUID("player")
    local sourceGUID = info[4]
    local destinationGUID = info[8]
    if sourceGUID ~= playerGUID and destinationGUID ~= playerGUID then
        return
    end

    local sourceRole = sourceGUID == playerGUID and "player" or "other"
    local destinationRole = destinationGUID == playerGUID and "player" or "other"
    local payload = STEP.Util:FormatPacked(info, 12, math.min(info.n, 23))
    local message = string.format("%s src=%s dst=%s payload={%s}", subevent, sourceRole, destinationRole, payload)
    local config = self:GetConfig()
    self:Record("combat", message, config and config.liveCombat)
end

function DebugProbe:GetProfessionContext(event)
    local context

    if event:match("^TRADE_SKILL") and GetTradeSkillLine then
        local ok, name, rank, maximum = pcall(GetTradeSkillLine)
        if ok and name then
            context = string.format("trade=%s %s/%s", tostring(name), tostring(rank or "?"), tostring(maximum or "?"))
        end
    elseif event:match("^CRAFT") and GetCraftDisplaySkillLine then
        local ok, name, rank, maximum = pcall(GetCraftDisplaySkillLine)
        if ok and name then
            context = string.format("craft=%s %s/%s", tostring(name), tostring(rank or "?"), tostring(maximum or "?"))
        end
    end

    return context
end

function DebugProbe:HandleEvent(event, ...)
    if not self:IsEnabled() then
        return
    end

    if STEP.Constants.SPELLCAST_EVENTS[event] then
        local args = STEP.Util:Pack(...)
        if not IsPlayerUnit(args[1]) then
            return
        end

        local config = self:GetConfig()
        self:Record("cast", event .. " {" .. STEP.Util:FormatPacked(args, 1, math.min(args.n, 7)) .. "}", config and config.liveCasts)
        return
    end

    if STEP.Constants.PROFESSION_EVENTS[event] then
        local context = self:GetProfessionContext(event)
        self:Record("profession", event .. (context and " " .. context or ""), false)
        return
    end

    if event == "PLAYER_REGEN_DISABLED"
        or event == "PLAYER_REGEN_ENABLED"
        or event == "PLAYER_DEAD"
        or event == "PLAYER_EQUIPMENT_CHANGED"
        or event == "SKILL_LINES_CHANGED"
        or event == "LEARNED_SPELL_IN_SKILL_LINE"
        or event == "PLAYER_LEVEL_UP" then
        local args = STEP.Util:Pack(...)
        self:Record("system", event .. " {" .. STEP.Util:FormatPacked(args, 1, math.min(args.n, 5)) .. "}", false)
    end
end

function DebugProbe:DumpEvents()
    if #self.events == 0 then
        STEP:Print(STEP:GetText("NO_EVENTS"))
        return
    end

    local count = math.min(#self.events, STEP.Constants.DEBUG_DUMP_LIMIT)
    STEP:Print(STEP:GetText("EVENTS_HEADER", count))
    local first = #self.events - count + 1

    for index = first, #self.events do
        local entry = self.events[index]
        STEP:Print(string.format("[%0.3f] %s: %s", entry.at, entry.kind, entry.message))
    end
end

function DebugProbe:Clear()
    self.events = {}
    STEP:Print(STEP:GetText("EVENTS_CLEARED"))
end

function DebugProbe:DumpStatus()
    local config = self:GetConfig() or {}
    local sessionId = STEP.Database and STEP.Database.db and STEP.Database.db.state.sessionId or "none"
    STEP:Print(string.format(
        "version=%s phase=%s ready=%s locale=%s session=%s debug=%s liveCombat=%s liveCasts=%s buffer=%d/%d",
        tostring(STEP.version),
        tostring(STEP.Constants.DEVELOPMENT_PHASE),
        tostring(STEP.ready),
        tostring(GetLocale and GetLocale() or "unknown"),
        tostring(sessionId),
        tostring(config.enabled == true),
        tostring(config.liveCombat == true),
        tostring(config.liveCasts == true),
        #self.events,
        STEP.Constants.DEBUG_EVENT_LIMIT
    ))
end
