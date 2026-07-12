local _, STEP = ...

local ProfessionTracker = {
    initialized = false,
    tradeSkillKey = nil,
    craftSkillKey = nil,
    sent = {},
    active = {},
    fishingCastGUID = nil,
}
STEP.ProfessionTracker = ProfessionTracker

local gatherSpellKeys = {
    [2576] = "primary.mining", -- Validated on client 20506.
}

local terminalEvents = {
    UNIT_SPELLCAST_SUCCEEDED = true,
    UNIT_SPELLCAST_STOP = true,
    UNIT_SPELLCAST_FAILED = true,
    UNIT_SPELLCAST_INTERRUPTED = true,
}

local function PlayerUnit(unit)
    return unit == "player"
end

local function ResolveSkillName(name)
    local entry = STEP.SkillRegistry and STEP.SkillRegistry:Resolve(name)
    return entry and entry.key or nil
end

local function SpellName(spellID)
    if GetSpellInfo and spellID then
        local name = GetSpellInfo(spellID)
        return name
    end
end

function ProfessionTracker:Initialize()
    self.initialized = STEP.ActivityTracker and STEP.ActivityTracker.initialized == true
    self.tradeSkillKey = nil
    self.craftSkillKey = nil
    self.sent = {}
    self.active = {}
    self.fishingCastGUID = nil
    return self.initialized
end

function ProfessionTracker:UpdateContext(event)
    if event == "TRADE_SKILL_CLOSE" then
        self.tradeSkillKey = nil
        return
    elseif event == "CRAFT_CLOSE" then
        self.craftSkillKey = nil
        return
    end

    if event:match("^TRADE_SKILL") and GetTradeSkillLine then
        local name = GetTradeSkillLine()
        self.tradeSkillKey = ResolveSkillName(name)
    elseif event:match("^CRAFT") and GetCraftDisplaySkillLine then
        local name = GetCraftDisplaySkillLine()
        self.craftSkillKey = ResolveSkillName(name)
    end
end

function ProfessionTracker:ResolveCastSkill(spellID)
    local gatherSkill = gatherSpellKeys[tonumber(spellID)]
    if gatherSkill then
        return gatherSkill
    end
    local name = SpellName(spellID)
    if name and ResolveSkillName(name) == "secondary.fishing" then
        return "secondary.fishing"
    end
    return self.tradeSkillKey or self.craftSkillKey
end

function ProfessionTracker:HandleSpellcast(event, ...)
    if not self.initialized then
        return
    end
    local args = STEP.Util:Pack(...)
    if not PlayerUnit(args[1]) then
        return
    end

    local spellID = event == "UNIT_SPELLCAST_SENT" and args[4] or args[3]
    local castGUID = args[2]
    local isFishing = self.active[castGUID] == "secondary.fishing"
        or self.sent[castGUID] == "secondary.fishing"
        or self:ResolveCastSkill(spellID) == "secondary.fishing"
    if type(castGUID) ~= "string" or castGUID == "" then
        -- The Anniversary client does not supply a cast GUID for Fishing's
        -- channel start/stop events. Fishing can only have one channel active
        -- for the player, so retain it locally under a stable sentinel.
        if isFishing and event == "UNIT_SPELLCAST_CHANNEL_START" then
            castGUID = "__step_fishing_channel__"
        elseif isFishing and event == "UNIT_SPELLCAST_CHANNEL_STOP" then
            castGUID = self.fishingCastGUID
        end
    end
    if type(castGUID) ~= "string" or castGUID == "" then
        return
    end

    if event == "UNIT_SPELLCAST_SENT" then
        local skillKey = self:ResolveCastSkill(spellID)
        if skillKey then
            self.sent[castGUID] = skillKey
        end
        return
    end

    local skillKey = self.active[castGUID] or self.sent[castGUID] or self:ResolveCastSkill(spellID)
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        if skillKey then
            self.active[castGUID] = skillKey
            STEP.ActivityTracker:BeginAttempt(skillKey)
            if skillKey == "secondary.fishing" then
                self.fishingCastGUID = castGUID
            end
        end
        return
    end

    -- Fishing succeeds when the bobber is created, before its channel starts
    -- waiting for loot. Its active interval therefore ends at CHANNEL_STOP,
    -- not at the early SUCCEEDED event.
    if skillKey == "secondary.fishing" and event == "UNIT_SPELLCAST_SUCCEEDED" then
        return
    end

    if terminalEvents[event] or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        if skillKey then
            STEP.ActivityTracker:FinishAttempt(skillKey)
        end
        self.active[castGUID] = nil
        self.sent[castGUID] = nil
        if self.fishingCastGUID == castGUID then
            self.fishingCastGUID = nil
        end
    end
end
