local _, STEP = ...

STEP.Constants = {
    SCHEMA_VERSION = 2,
    DEVELOPMENT_PHASE = "phase2",
    SKILL_SCAN_DELAY = 0.10,
    DEBUG_EVENT_LIMIT = 120,
    DEBUG_DUMP_LIMIT = 20,
    FALLBACK_SKILL_ICON = 134400,
}

STEP.Constants.DEBUG_COMBAT_SUBEVENTS = {
    SWING_DAMAGE = true,
    SWING_MISSED = true,
    RANGE_DAMAGE = true,
    RANGE_MISSED = true,
    SPELL_DAMAGE = true,
    SPELL_MISSED = true,
}

-- Compatibility alias used only by the temporary Phase 0 diagnostic probe.
STEP.Constants.COMBAT_SUBEVENTS = STEP.Constants.DEBUG_COMBAT_SUBEVENTS

STEP.Constants.CONFIG_ENUMS = {
    visibility = {
        hidden = true,
        expanded = true,
        compact = true,
    },
    sortMode = {
        progress = true,
        alphabetical = true,
    },
    combatBehavior = {
        keep = true,
        compact = true,
        hide = true,
    },
    notificationMode = {
        exaggerated = true,
        discreet = true,
        none = true,
    },
}

STEP.Constants.SPELLCAST_EVENTS = {
    UNIT_SPELLCAST_SENT = true,
    UNIT_SPELLCAST_START = true,
    UNIT_SPELLCAST_STOP = true,
    UNIT_SPELLCAST_SUCCEEDED = true,
    UNIT_SPELLCAST_FAILED = true,
    UNIT_SPELLCAST_INTERRUPTED = true,
    UNIT_SPELLCAST_CHANNEL_START = true,
    UNIT_SPELLCAST_CHANNEL_STOP = true,
}

STEP.Constants.PROFESSION_EVENTS = {
    TRADE_SKILL_SHOW = true,
    TRADE_SKILL_UPDATE = true,
    TRADE_SKILL_CLOSE = true,
    CRAFT_SHOW = true,
    CRAFT_UPDATE = true,
    CRAFT_CLOSE = true,
    LOOT_OPENED = true,
    LOOT_CLOSED = true,
}
