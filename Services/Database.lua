local _, STEP = ...

local Database = {}
STEP.Database = Database

local function CopyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            CopyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local defaults = {
    schemaVersion = STEP.Constants.SCHEMA_VERSION,
    config = {
        debug = {
            enabled = false,
            liveCombat = false,
            liveCasts = false,
        },
        skills = {},
    },
    state = {
        sessionCounter = 0,
        sessionId = nil,
        sessionStartedAt = nil,
        lastCheckpointAt = nil,
        lastCheckpointReason = nil,
        known = {},
        lastScanAt = nil,
        lastScanReason = nil,
    },
    history = {
        events = {},
        aggregates = {},
        segments = {},
        prunedEventCount = 0,
    },
}

function Database:Initialize()
    if type(STEPDB) ~= "table" then
        STEPDB = {}
    end

    if STEPDB.schemaVersion and STEPDB.schemaVersion > STEP.Constants.SCHEMA_VERSION then
        STEP:Print("SavedVariables schema is newer than this build; preserving data without downgrade.")
    end

    CopyDefaults(STEPDB, defaults)
    self.db = STEPDB
end

function Database:StartSession()
    if not self.db then
        self:Initialize()
    end

    local state = self.db.state
    state.sessionCounter = (tonumber(state.sessionCounter) or 0) + 1
    state.sessionStartedAt = STEP.Util:WallTime()
    state.sessionId = tostring(state.sessionStartedAt) .. "-" .. tostring(state.sessionCounter)
    self:Checkpoint("PLAYER_LOGIN")
end

function Database:Checkpoint(reason)
    if not self.db then
        return
    end

    self.db.state.lastCheckpointAt = STEP.Util:WallTime()
    self.db.state.lastCheckpointReason = reason
end

function Database:GetDebugConfig()
    return self.db and self.db.config.debug
end
