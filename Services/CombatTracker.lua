local _, STEP = ...

local CombatTracker = {
    initialized = false,
    inCombat = false,
}
STEP.CombatTracker = CombatTracker

local meleeEvents = {
    SWING_DAMAGE = true,
    SWING_MISSED = true,
}
local rangedEvents = {
    RANGE_DAMAGE = true,
    RANGE_MISSED = true,
}
local defenseEvents = {
    SWING_DAMAGE = true,
    SWING_MISSED = true,
    RANGE_DAMAGE = true,
    RANGE_MISSED = true,
    SPELL_DAMAGE = true,
    SPELL_MISSED = true,
}

function CombatTracker:Initialize()
    if self.initialized then
        return true
    end
    self.initialized = STEP.ActivityTracker and STEP.ActivityTracker.initialized == true
    return self.initialized
end

function CombatTracker:SetCombatState(inCombat)
    self.inCombat = inCombat == true
end

function CombatTracker:HandleCombatLog()
    if not self.inCombat or not CombatLogGetCurrentEventInfo then
        return
    end
    local info = STEP.Util:Pack(CombatLogGetCurrentEventInfo())
    local subevent = info[2]
    local playerGUID = UnitGUID and UnitGUID("player")
    if not playerGUID or not subevent then
        return
    end

    local sourceGUID = info[4]
    local destinationGUID = info[8]
    local skillKey
    if sourceGUID == playerGUID and meleeEvents[subevent] then
        skillKey = STEP.EquipmentResolver and STEP.EquipmentResolver:GetHandSkill(false)
    elseif sourceGUID == playerGUID and rangedEvents[subevent] then
        skillKey = STEP.EquipmentResolver and STEP.EquipmentResolver:GetRangedSkill()
    elseif destinationGUID == playerGUID and defenseEvents[subevent] then
        skillKey = "combat.defense"
    end

    if skillKey then
        STEP.ActivityTracker:PulseCombat(skillKey)
    end
end

