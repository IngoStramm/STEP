local _, STEP = ...

local SkillScanner = {
    snapshot = {},
    unknown = {},
    scanScheduled = false,
    scheduledReason = nil,
}
STEP.SkillScanner = SkillScanner

local function ReadSnapshot()
    local snapshot = {}
    local unknown = {}
    local lineCount = GetNumSkillLines and GetNumSkillLines() or 0

    for index = 1, lineCount do
        local skillName, isHeader, isExpanded, skillRank, temporaryPoints, skillModifier, skillMaximum = GetSkillLineInfo(index)
        if skillName and not isHeader then
            local entry = STEP.SkillRegistry:Resolve(skillName)
            local data = {
                name = skillName,
                current = tonumber(skillRank) or 0,
                maximum = tonumber(skillMaximum) or 0,
                temporary = tonumber(temporaryPoints) or 0,
                modifier = tonumber(skillModifier) or 0,
                scanIndex = index,
                isExpanded = isExpanded,
            }

            if entry then
                data.skillKey = entry.key
                data.category = entry.category
                data.tracker = entry.tracker
                snapshot[entry.key] = data
            elseif data.maximum > 0 then
                unknown[#unknown + 1] = data
            end
        end
    end

    table.sort(unknown, function(left, right)
        return tostring(left.name) < tostring(right.name)
    end)

    return snapshot, unknown
end

local function PersistSnapshot(snapshot, reason)
    local database = STEP.Database and STEP.Database.db
    if not database then
        return
    end

    local now = STEP.Util:WallTime()
    local known = database.state.known

    for skillKey, data in pairs(snapshot) do
        local stored = known[skillKey]
        if type(stored) ~= "table" then
            stored = {
                firstSeenAt = now,
            }
            known[skillKey] = stored
        end

        stored.current = data.current
        stored.maximum = data.maximum
        stored.temporary = data.temporary
        stored.modifier = data.modifier
        stored.learned = true
        stored.lastSeenAt = now
    end

    database.state.lastScanAt = now
    database.state.lastScanReason = reason
end

function SkillScanner:Compare(previous, current)
    for skillKey, data in pairs(current) do
        local old = previous[skillKey]
        if not old then
            STEP:Fire("SKILL_LEARNED", skillKey, data)
            if STEP.DebugProbe then
                STEP.DebugProbe:Record("skill", "learned " .. skillKey .. " " .. data.current .. "/" .. data.maximum, true)
            end
        elseif data.current > old.current then
            local gained = data.current - old.current
            STEP:Fire("SKILL_GAINED", skillKey, old, data, gained)
            if STEP.DebugProbe then
                STEP.DebugProbe:Record("skill", string.format("gain %s %d->%d/%d (+%d)", skillKey, old.current, data.current, data.maximum, gained), true)
            end
        elseif data.current < old.current then
            if STEP.DebugProbe then
                STEP.DebugProbe:Record("skill", string.format("decrease %s %d->%d/%d", skillKey, old.current, data.current, data.maximum), true)
            end
        elseif data.maximum ~= old.maximum and STEP.DebugProbe then
            STEP.DebugProbe:Record("skill", string.format("maximum %s %d->%d current=%d", skillKey, old.maximum, data.maximum, data.current), true)
        end
    end

    for skillKey, data in pairs(previous) do
        if not current[skillKey] then
            local database = STEP.Database and STEP.Database.db
            if database and database.state.known[skillKey] then
                database.state.known[skillKey].learned = false
                database.state.known[skillKey].lastSeenAt = STEP.Util:WallTime()
            end

            STEP:Fire("SKILL_UNLEARNED", skillKey, data)
            if STEP.DebugProbe then
                STEP.DebugProbe:Record("skill", "unlearned " .. skillKey, true)
            end
        end
    end
end

function SkillScanner:Scan(reason, baseline)
    local nextSnapshot, unknown = ReadSnapshot()
    local previous = self.snapshot

    if not baseline then
        self:Compare(previous, nextSnapshot)
    end

    self.snapshot = nextSnapshot
    self.unknown = unknown
    PersistSnapshot(nextSnapshot, reason)
    STEP:Fire("SKILLS_UPDATED", nextSnapshot, reason, baseline == true)

    if STEP.DebugProbe then
        local recognizedCount = 0
        for _ in pairs(nextSnapshot) do
            recognizedCount = recognizedCount + 1
        end
        STEP.DebugProbe:Record("scan", string.format("reason=%s recognized=%d unknown=%d baseline=%s", tostring(reason), recognizedCount, #unknown, tostring(baseline == true)), false)
    end
end

function SkillScanner:Schedule(reason)
    self.scheduledReason = reason or self.scheduledReason or "unknown"
    if self.scanScheduled then
        return
    end

    self.scanScheduled = true
    local function Run()
        self.scanScheduled = false
        local scanReason = self.scheduledReason
        self.scheduledReason = nil
        self:Scan(scanReason, false)
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(STEP.Constants.SKILL_SCAN_DELAY, Run)
    else
        Run()
    end
end

function SkillScanner:DumpSnapshot()
    local keys = STEP.Util:SortedKeys(self.snapshot)
    STEP:Print(STEP:GetText("SNAPSHOT_HEADER", #keys, #self.unknown))

    for index = 1, #keys do
        local skillKey = keys[index]
        local data = self.snapshot[skillKey]
        STEP:Print(string.format(
            "%s: %s %d/%d temp=%d modifier=%d line=%d tracker=%s",
            skillKey,
            tostring(data.name),
            data.current,
            data.maximum,
            data.temporary,
            data.modifier,
            data.scanIndex,
            tostring(data.tracker)
        ))
    end

    for index = 1, #self.unknown do
        local data = self.unknown[index]
        STEP:Print(string.format(
            "unknown: %s %d/%d temp=%d modifier=%d line=%d",
            tostring(data.name),
            data.current,
            data.maximum,
            data.temporary,
            data.modifier,
            data.scanIndex
        ))
    end
end
