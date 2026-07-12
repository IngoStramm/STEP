local _, STEP = ...

local HistoryStore = {
    initialized = false,
    tokens = {},
}
STEP.HistoryStore = HistoryStore

local function Now()
    return STEP.Util:WallTime()
end

local function IsLogged(skillKey)
    local config = STEP.ConfigStore and STEP.ConfigStore:GetSkill(skillKey)
    return config and config.logEnabled == true
end

local function History()
    return STEP.Database and STEP.Database.db and STEP.Database.db.history
end

local function EnsureArray(parent, key)
    if type(parent[key]) ~= "table" then
        parent[key] = {}
    end
    return parent[key]
end

local function EnsureAggregate(skillKey, initialValue)
    local history = History()
    local aggregate = history.aggregates[skillKey]
    if type(aggregate) ~= "table" then
        aggregate = {
            initialValue = initialValue,
            latestValue = initialValue,
            gainedPoints = 0,
            gainEvents = 0,
            activeSeconds = 0,
            onlineSeconds = 0,
            recentSamples = {},
        }
        history.aggregates[skillKey] = aggregate
    end
    return aggregate
end

function HistoryStore:EnsureSegment(skillKey, initialValue, reason)
    local history = History()
    local segments = EnsureArray(history.segments, skillKey)
    local segment = segments[#segments]
    if type(segment) == "table" and not segment.closedAt then
        return segment
    end
    history.nextSegmentId = math.max(1, math.floor(tonumber(history.nextSegmentId) or 1))
    segment = {
        segmentId = history.nextSegmentId,
        skillKey = skillKey,
        initialValue = initialValue,
        latestValue = initialValue,
        gainedPoints = 0,
        gainEvents = 0,
        activeSeconds = 0,
        onlineSeconds = 0,
        recentSamples = {},
        startedAt = Now(),
        reason = reason or "observed",
    }
    history.nextSegmentId = history.nextSegmentId + 1
    segments[#segments + 1] = segment
    self:CompactSegments(skillKey)
    return segment
end

function HistoryStore:CompactSegments(skillKey)
    local history = History()
    local segments = EnsureArray(history.segments, skillKey)
    while #segments > STEP.Constants.HISTORY_SEGMENT_LIMIT do
        local oldest = table.remove(segments, 1)
        local archived = history.archivedSegments[skillKey] or {
            segments = 0, gainedPoints = 0, gainEvents = 0, activeSeconds = 0, onlineSeconds = 0,
        }
        archived.segments = archived.segments + 1
        archived.gainedPoints = archived.gainedPoints + (oldest.gainedPoints or 0)
        archived.gainEvents = archived.gainEvents + (oldest.gainEvents or 0)
        archived.activeSeconds = archived.activeSeconds + (oldest.activeSeconds or 0)
        archived.onlineSeconds = archived.onlineSeconds + (oldest.onlineSeconds or 0)
        history.archivedSegments[skillKey] = archived
    end
end

local function AddSample(target, secondsPerPoint)
    if not secondsPerPoint then
        return
    end
    local samples = EnsureArray(target, "recentSamples")
    samples[#samples + 1] = secondsPerPoint
    while #samples > STEP.Constants.HISTORY_RECENT_SAMPLE_LIMIT do
        table.remove(samples, 1)
    end
    target.bestSecondsPerPoint = math.min(target.bestSecondsPerPoint or secondsPerPoint, secondsPerPoint)
    target.slowestSecondsPerPoint = math.max(target.slowestSecondsPerPoint or secondsPerPoint, secondsPerPoint)
end

function HistoryStore:PruneEvents()
    local history = History()
    while #history.events > STEP.Constants.HISTORY_EVENT_LIMIT do
        table.remove(history.events, 1)
        history.prunedEventCount = (history.prunedEventCount or 0) + 1
    end
end

function HistoryStore:RecordGain(change)
    if not IsLogged(change.skillKey) then
        -- A preference may change between the tracked action and the scanner
        -- update. Drop the pending interval rather than attributing it to a
        -- later, unrelated gain after logging is enabled again.
        STEP.ActivityTracker:Consume(change.skillKey)
        return nil
    end
    local history = History()
    local timing = STEP.ActivityTracker:Consume(change.skillKey)
    local segment = self:EnsureSegment(change.skillKey, change.previous.current, "observed")
    local event = {
        eventId = history.nextEventId,
        type = "gain",
        skillKey = change.skillKey,
        category = change.current.category,
        oldValue = change.previous.current,
        newValue = change.current.current,
        maximum = change.current.maximum,
        gainedPoints = change.gainedPoints,
        occurredAt = Now(),
        sessionId = STEP.Database.db.state.sessionId,
        segmentId = segment.segmentId,
        activeSeconds = timing.activeSeconds,
        onlineSeconds = timing.onlineSeconds,
        reachedMaximum = change.reachedMaximum == true,
    }
    history.nextEventId = history.nextEventId + 1
    history.events[#history.events + 1] = event
    self:PruneEvents()

    local aggregate = EnsureAggregate(change.skillKey, change.previous.current)
    local targets = { aggregate, segment }
    local secondsPerPoint = event.gainedPoints > 0 and event.activeSeconds / event.gainedPoints or nil
    for index = 1, #targets do
        local target = targets[index]
        target.latestValue = event.newValue
        target.gainedPoints = (target.gainedPoints or 0) + event.gainedPoints
        target.gainEvents = (target.gainEvents or 0) + 1
        target.activeSeconds = (target.activeSeconds or 0) + event.activeSeconds
        target.onlineSeconds = (target.onlineSeconds or 0) + event.onlineSeconds
        AddSample(target, secondsPerPoint)
        if event.reachedMaximum then
            target.reachedMaxAt = event.occurredAt
        end
    end
    STEP:Fire("HISTORY_UPDATED", { type = "gain", event = event })
    return event
end

function HistoryStore:HandleLearned(change)
    if not IsLogged(change.skillKey) then
        return
    end
    self:EnsureSegment(change.skillKey, change.current.current, change.relearned and "relearned" or "learned")
end

function HistoryStore:HandleUnlearned(change)
    local history = History()
    local segments = history and history.segments and history.segments[change.skillKey]
    local segment = type(segments) == "table" and segments[#segments]
    if segment and not segment.closedAt then
        segment.closedAt = Now()
        segment.closeReason = "unlearned"
        STEP:Fire("HISTORY_UPDATED", { type = "unlearned", skillKey = change.skillKey })
    end
end

function HistoryStore:GetAggregate(skillKey)
    local history = History()
    return history and history.aggregates[skillKey]
end

function HistoryStore:GetEvents(skillKey)
    local history = History()
    local result = {}
    for index = 1, #(history and history.events or {}) do
        local event = history.events[index]
        if not skillKey or event.skillKey == skillKey then
            result[#result + 1] = event
        end
    end
    return result
end

local function NewSummary(skillKey)
    return {
        skillKey = skillKey,
        initialValue = nil,
        latestValue = nil,
        gainedPoints = 0,
        gainEvents = 0,
        activeSeconds = 0,
        onlineSeconds = 0,
        bestSecondsPerPoint = nil,
        slowestSecondsPerPoint = nil,
    }
end

local function AddSummaryEvent(summary, event)
    if summary.initialValue == nil then
        summary.initialValue = event.oldValue
    end
    summary.latestValue = event.newValue
    summary.gainedPoints = summary.gainedPoints + (event.gainedPoints or 0)
    summary.gainEvents = summary.gainEvents + 1
    summary.activeSeconds = summary.activeSeconds + (event.activeSeconds or 0)
    summary.onlineSeconds = summary.onlineSeconds + (event.onlineSeconds or 0)
    if (event.gainedPoints or 0) > 0 then
        local secondsPerPoint = (event.activeSeconds or 0) / event.gainedPoints
        summary.bestSecondsPerPoint = math.min(summary.bestSecondsPerPoint or secondsPerPoint, secondsPerPoint)
        summary.slowestSecondsPerPoint = math.max(summary.slowestSecondsPerPoint or secondsPerPoint, secondsPerPoint)
    end
end

function HistoryStore:GetSummaryRows(scope)
    local history = History()
    local rows = {}
    if not history then
        return rows
    end

    if scope == "session" then
        local sessionId = STEP.Database and STEP.Database.db and STEP.Database.db.state.sessionId
        local summaries = {}
        for index = 1, #history.events do
            local event = history.events[index]
            if event.sessionId == sessionId then
                local summary = summaries[event.skillKey]
                if not summary then
                    summary = NewSummary(event.skillKey)
                    summaries[event.skillKey] = summary
                end
                AddSummaryEvent(summary, event)
            end
        end
        for _, summary in pairs(summaries) do
            rows[#rows + 1] = summary
        end
    else
        for skillKey, aggregate in pairs(history.aggregates) do
            rows[#rows + 1] = {
                skillKey = skillKey,
                initialValue = aggregate.initialValue,
                latestValue = aggregate.latestValue,
                gainedPoints = aggregate.gainedPoints or 0,
                gainEvents = aggregate.gainEvents or 0,
                activeSeconds = aggregate.activeSeconds or 0,
                onlineSeconds = aggregate.onlineSeconds or 0,
                bestSecondsPerPoint = aggregate.bestSecondsPerPoint,
                slowestSecondsPerPoint = aggregate.slowestSecondsPerPoint,
            }
        end
    end

    table.sort(rows, function(left, right)
        return STEP.SkillRegistry:GetLocalizedName(left.skillKey) < STEP.SkillRegistry:GetLocalizedName(right.skillKey)
    end)
    return rows
end

function HistoryStore:GetEventsForScope(skillKey, scope)
    local sessionId = STEP.Database and STEP.Database.db and STEP.Database.db.state.sessionId
    local result = {}
    local events = self:GetEvents(skillKey)
    for index = 1, #events do
        local event = events[index]
        if scope ~= "session" or event.sessionId == sessionId then
            result[#result + 1] = event
        end
    end
    return result
end

local function FormatDurationForShare(value)
    local seconds = math.max(0, math.floor(tonumber(value) or 0))
    local minutes = math.floor(seconds / 60)
    if minutes >= 60 then
        return string.format("%dh%02dm", math.floor(minutes / 60), minutes % 60)
    end
    return string.format("%dm%02ds", minutes, seconds % 60)
end

function HistoryStore:GetShareLines(scope, skillKey)
    local rows = self:GetSummaryRows(scope)
    local lines = {}
    for index = 1, #rows do
        local row = rows[index]
        if not skillKey or row.skillKey == skillKey then
            lines[#lines + 1] = STEP:GetText(
                "HISTORY_SHARE_LINE",
                STEP.SkillRegistry:GetLocalizedName(row.skillKey),
                row.initialValue or 0,
                row.latestValue or 0,
                row.gainedPoints or 0,
                FormatDurationForShare(row.activeSeconds)
            )
        end
    end
    return lines
end

function HistoryStore:Clear()
    if not STEP.Database or not STEP.Database:IsCompatible() then
        return false
    end
    if not STEP.Database:ResetHistory() then
        return false
    end
    STEP:Fire("HISTORY_UPDATED", { type = "cleared" })
    return true
end

function HistoryStore:DumpSummary()
    local history = History()
    local count = history and #history.events or 0
    STEP:Print(STEP:GetText("HISTORY_SUMMARY", count, history and history.prunedEventCount or 0))
    local keys = STEP.Util:SortedKeys(history and history.aggregates or {})
    for index = 1, #keys do
        local skillKey = keys[index]
        local aggregate = history.aggregates[skillKey]
        STEP:Print(STEP:GetText(
            "HISTORY_LINE",
            STEP.SkillRegistry:GetLocalizedName(skillKey),
            aggregate.gainedPoints or 0,
            aggregate.activeSeconds or 0,
            aggregate.onlineSeconds or 0
        ))
    end
end

function HistoryStore:Initialize()
    if self.initialized then
        return true
    end
    if not STEP.Database or not STEP.Database:IsCompatible() then
        return false
    end
    self.tokens[#self.tokens + 1] = STEP:RegisterCallback("SKILL_GAINED", self, function(_, change)
        self:RecordGain(change)
    end)
    self.tokens[#self.tokens + 1] = STEP:RegisterCallback("SKILL_LEARNED", self, function(_, change)
        self:HandleLearned(change)
    end)
    self.tokens[#self.tokens + 1] = STEP:RegisterCallback("SKILL_UNLEARNED", self, function(_, change)
        self:HandleUnlearned(change)
    end)
    self.initialized = true
    return true
end
