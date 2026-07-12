local _, STEP = ...

local ActivityTracker = {
    initialized = false,
}
STEP.ActivityTracker = ActivityTracker

local function Now()
    return STEP.Util:MonotonicTime()
end

local function IsTracked(skillKey)
    local config = STEP.ConfigStore and STEP.ConfigStore:GetSkill(skillKey)
    return config and config.logEnabled == true
end

function ActivityTracker:GetState(skillKey, create)
    local database = STEP.Database and STEP.Database.db
    local activity = database and database.state and database.state.activity
    if type(activity) ~= "table" then
        return nil
    end
    local state = activity[skillKey]
    if type(state) ~= "table" and create then
        state = {
            activeSeconds = 0,
            onlineSeconds = 0,
        }
        activity[skillKey] = state
    end
    return state
end

function ActivityTracker:Initialize()
    if self.initialized then
        return true
    end
    if not STEP.Database or not STEP.Database:IsCompatible() then
        return false
    end

    local now = Now()
    local activity = STEP.Database.db.state.activity
    for _, state in pairs(activity) do
        if type(state) == "table" then
            -- Monotonic time restarts on reload/login. Persist accumulated values,
            -- but never bridge an incomplete attempt or offline interval.
            state.attemptStartedAt = nil
            state.lastPulseAt = nil
            state.onlineStartedAt = now
        end
    end
    self.initialized = true
    return true
end

function ActivityTracker:AccumulateOnline(state, now)
    local startedAt = tonumber(state.onlineStartedAt)
    if startedAt and now >= startedAt then
        state.onlineSeconds = (tonumber(state.onlineSeconds) or 0) + (now - startedAt)
    end
    state.onlineStartedAt = now
end

function ActivityTracker:BeginAttempt(skillKey)
    if not IsTracked(skillKey) then
        return false
    end
    local state = self:GetState(skillKey, true)
    local now = Now()
    self:AccumulateOnline(state, now)
    if not state.attemptStartedAt then
        state.attemptStartedAt = now
    end
    return true
end

function ActivityTracker:FinishAttempt(skillKey)
    local state = self:GetState(skillKey, false)
    if not state then
        return false
    end
    local now = Now()
    self:AccumulateOnline(state, now)
    local startedAt = tonumber(state.attemptStartedAt)
    if startedAt and now >= startedAt then
        state.activeSeconds = (tonumber(state.activeSeconds) or 0) + (now - startedAt)
    end
    state.attemptStartedAt = nil
    return true
end

function ActivityTracker:PulseCombat(skillKey)
    if not IsTracked(skillKey) then
        return false
    end
    local state = self:GetState(skillKey, true)
    local now = Now()
    self:AccumulateOnline(state, now)
    local lastPulseAt = tonumber(state.lastPulseAt)
    if lastPulseAt and now >= lastPulseAt then
        state.activeSeconds = (tonumber(state.activeSeconds) or 0)
            + math.min(now - lastPulseAt, STEP.Constants.COMBAT_ACTIVITY_GRACE)
    end
    state.lastPulseAt = now
    return true
end

function ActivityTracker:Flush(skillKey, now)
    local state = self:GetState(skillKey, false)
    if not state then
        return nil
    end
    now = now or Now()
    self:AccumulateOnline(state, now)

    local lastPulseAt = tonumber(state.lastPulseAt)
    if lastPulseAt and now >= lastPulseAt then
        state.activeSeconds = (tonumber(state.activeSeconds) or 0)
            + math.min(now - lastPulseAt, STEP.Constants.COMBAT_ACTIVITY_GRACE)
    end
    state.lastPulseAt = nil
    return state
end

function ActivityTracker:Consume(skillKey)
    local state = self:Flush(skillKey)
    if not state then
        return { activeSeconds = 0, onlineSeconds = 0 }
    end
    local pending = {
        activeSeconds = math.max(0, tonumber(state.activeSeconds) or 0),
        onlineSeconds = math.max(0, tonumber(state.onlineSeconds) or 0),
    }
    state.activeSeconds = 0
    state.onlineSeconds = 0
    return pending
end

function ActivityTracker:Checkpoint(reason)
    if not self.initialized then
        return
    end
    local now = Now()
    local activity = STEP.Database.db.state.activity
    for skillKey in pairs(activity) do
        self:Flush(skillKey, now)
        local state = activity[skillKey]
        if state then
            local startedAt = tonumber(state.attemptStartedAt)
            if startedAt and now >= startedAt then
                state.activeSeconds = (tonumber(state.activeSeconds) or 0) + (now - startedAt)
            end
            state.attemptStartedAt = nil
            state.onlineStartedAt = nil
        end
    end
    if STEP.DebugProbe then
        STEP.DebugProbe:Record("activity", "checkpoint reason=" .. tostring(reason), false)
    end
end
