local _, STEP = ...

local Database = {
    initialized = false,
    compatible = false,
    sessionStarted = false,
    recoveryCopy = nil,
    migrationError = nil,
}
STEP.Database = Database

local defaults = {
    schemaVersion = STEP.Constants.SCHEMA_VERSION,
    config = {
        debug = {
            enabled = false,
            liveCombat = false,
            liveCasts = false,
        },
        panel = {
            shown = true,
            locked = false,
            scale = 1,
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 0,
            expanded = false,
            startExpanded = false,
            showHeaderSummary = true,
            sortMode = "progress",
            hideMaxed = false,
            combatBehavior = "keep",
            autoShowEquipped = false,
        },
        notifications = {
            gainMode = "discreet",
            maxMode = "exaggerated",
        },
        skills = {},
        windows = {
            config = {},
            log = {},
        },
    },
    state = {
        sessionCounter = 0,
        sessionId = nil,
        sessionStartedAt = nil,
        lastCheckpointAt = nil,
        lastCheckpointReason = nil,
        checkpointCount = 0,
        known = {},
        activity = {},
        preferencesSeen = {},
        lastScanAt = nil,
        lastScanReason = nil,
    },
    history = {
        nextEventId = 1,
        events = {},
        aggregates = {},
        segments = {},
        archivedSegments = {},
        prunedEventCount = 0,
    },
}
Database.defaults = defaults

local function EnsureTable(parent, key)
    if type(parent[key]) ~= "table" then
        parent[key] = {}
    end
    return parent[key]
end

local function NormalizeNonnegativeInteger(value, fallback)
    value = tonumber(value)
    if not STEP.Util:IsFiniteNumber(value) or value < 0 then
        return fallback
    end
    return math.floor(value)
end

local migrations = {}

migrations[1] = function(database)
    local config = EnsureTable(database, "config")
    EnsureTable(config, "debug")
    EnsureTable(config, "skills")
    EnsureTable(config, "panel")
    EnsureTable(config, "notifications")
    EnsureTable(config, "windows")

    local state = EnsureTable(database, "state")
    EnsureTable(state, "known")
    EnsureTable(state, "activity")
    EnsureTable(state, "preferencesSeen")

    local history = EnsureTable(database, "history")
    EnsureTable(history, "events")
    EnsureTable(history, "aggregates")
    EnsureTable(history, "segments")
    EnsureTable(history, "archivedSegments")
    if history.nextEventId == nil then
        history.nextEventId = 1
    end

    database.schemaVersion = 2
end
Database.migrations = migrations

function Database:GetDefaults()
    return STEP.Util:DeepCopy(defaults)
end

function Database:RunMigrations(database, fromVersion)
    local version = fromVersion
    while version < STEP.Constants.SCHEMA_VERSION do
        local migration = migrations[version]
        if type(migration) ~= "function" then
            return false, "missing migration from schema " .. tostring(version)
        end

        local ok, err = pcall(migration, database)
        if not ok then
            return false, err
        end

        local nextVersion = tonumber(database.schemaVersion)
        if nextVersion ~= version + 1 then
            return false, "migration from schema " .. tostring(version) .. " did not advance exactly one version"
        end
        version = nextVersion
    end
    return true
end

function Database:Validate()
    if not self.db or not self.compatible then
        return false
    end

    STEP.Util:ApplyDefaults(self.db, defaults)
    self.db.schemaVersion = STEP.Constants.SCHEMA_VERSION

    local debug = self.db.config.debug
    if type(debug.enabled) ~= "boolean" then
        debug.enabled = defaults.config.debug.enabled
    end
    if type(debug.liveCombat) ~= "boolean" then
        debug.liveCombat = defaults.config.debug.liveCombat
    end
    if type(debug.liveCasts) ~= "boolean" then
        debug.liveCasts = defaults.config.debug.liveCasts
    end

    local state = self.db.state
    state.sessionCounter = NormalizeNonnegativeInteger(state.sessionCounter, 0)
    state.checkpointCount = NormalizeNonnegativeInteger(state.checkpointCount, 0)

    local history = self.db.history
    history.nextEventId = math.max(1, NormalizeNonnegativeInteger(history.nextEventId, 1))
    history.prunedEventCount = NormalizeNonnegativeInteger(history.prunedEventCount, 0)
    return true
end

function Database:Initialize()
    if self.initialized then
        return self.compatible
    end

    if type(STEPDB) ~= "table" then
        STEPDB = {}
    end

    local database = STEPDB
    local isEmpty = next(database) == nil
    self.recoveryCopy = STEP.Util:DeepCopy(database)

    local version = database.schemaVersion
    if isEmpty then
        version = STEP.Constants.SCHEMA_VERSION
        database.schemaVersion = version
    elseif not STEP.Util:IsFiniteNumber(version) or version ~= math.floor(version) or version < 1 then
        self.db = database
        self.compatible = false
        self.initialized = true
        self.migrationError = "invalid schema version: " .. tostring(version)
        STEP:Print(STEP:GetText("MIGRATION_FAILED", self.migrationError))
        return false
    end

    if version > STEP.Constants.SCHEMA_VERSION then
        self.db = database
        self.compatible = false
        self.initialized = true
        STEP:Print(STEP:GetText("SCHEMA_NEWER", tostring(version), tostring(STEP.Constants.SCHEMA_VERSION)))
        return false
    end

    if version < STEP.Constants.SCHEMA_VERSION then
        local ok, err = self:RunMigrations(database, version)
        if not ok then
            STEPDB = self.recoveryCopy
            self.db = STEPDB
            self.migrationError = tostring(err)
            self.compatible = false
            self.initialized = true
            STEP:Print(STEP:GetText("MIGRATION_FAILED", self.migrationError))
            return false
        end
    end

    self.db = database
    self.compatible = true
    self.initialized = true
    return self:Validate()
end

function Database:IsCompatible()
    return self.compatible == true
end

function Database:StartSession()
    if self.sessionStarted or not self:IsCompatible() then
        return self.db and self.db.state and self.db.state.sessionId
    end

    local state = self.db.state
    state.sessionCounter = NormalizeNonnegativeInteger(state.sessionCounter, 0) + 1
    state.sessionStartedAt = STEP.Util:WallTime()
    state.sessionId = tostring(state.sessionStartedAt) .. "-" .. tostring(state.sessionCounter)
    self.sessionStarted = true
    self:Checkpoint("PLAYER_LOGIN")
    return state.sessionId
end

function Database:Checkpoint(reason)
    if not self:IsCompatible() then
        return false
    end

    local state = self.db.state
    state.lastCheckpointAt = STEP.Util:WallTime()
    state.lastCheckpointReason = reason
    state.checkpointCount = NormalizeNonnegativeInteger(state.checkpointCount, 0) + 1
    return true
end

function Database:PersistKnownSnapshot(snapshot, reason, reconcileMissing)
    if not self:IsCompatible() then
        return false
    end

    local now = STEP.Util:WallTime()
    local known = self.db.state.known
    local seen = {}

    for skillKey, data in pairs(snapshot or {}) do
        seen[skillKey] = true
        local stored = known[skillKey]
        if type(stored) ~= "table" then
            stored = {
                firstSeenAt = now,
                learnCount = 1,
            }
            known[skillKey] = stored
        elseif stored.learned == false then
            stored.learnCount = NormalizeNonnegativeInteger(stored.learnCount, 1) + 1
            stored.lastLearnedAt = now
        end

        stored.current = data.current
        stored.maximum = data.maximum
        stored.temporary = data.temporary
        stored.modifier = data.modifier
        stored.learned = true
        stored.lastSeenAt = now
        stored.unlearnedAt = nil
    end

    if reconcileMissing then
        for skillKey, stored in pairs(known) do
            if type(stored) == "table" and stored.learned ~= false and not seen[skillKey] then
                stored.learned = false
                stored.lastSeenAt = now
                stored.unlearnedAt = now
            end
        end
    end

    self.db.state.lastScanAt = now
    self.db.state.lastScanReason = reason
    return true
end

function Database:GetKnown(skillKey)
    return self.db and self.db.state and self.db.state.known[skillKey]
end

function Database:GetDebugConfig()
    return self:IsCompatible() and self.db.config.debug or nil
end

function Database:ResetHistory()
    if not self:IsCompatible() then
        return false
    end
    self.db.history = STEP.Util:DeepCopy(defaults.history)
    return true
end

function Database:DumpStatus()
    local schema = self.db and self.db.schemaVersion or "none"
    local state = self.db and self.db.state or {}
    local knownCount = state.known and STEP.Util:CountKeys(state.known) or 0
    local skillConfigCount = self.db and self.db.config and self.db.config.skills and STEP.Util:CountKeys(self.db.config.skills) or 0
    STEP:Print(string.format(
        "schema=%s/%s compatible=%s session=%s known=%d skillConfigs=%d checkpoints=%s",
        tostring(schema),
        tostring(STEP.Constants.SCHEMA_VERSION),
        tostring(self:IsCompatible()),
        tostring(state.sessionId or "none"),
        knownCount,
        skillConfigCount,
        tostring(state.checkpointCount or 0)
    ))
end
