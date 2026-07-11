local _, STEP = ...

local SkillScanner = {
    snapshot = {},
    unknown = {},
    scanScheduled = false,
    scheduledReason = nil,
    missingCounts = {},
    pendingBaselineMissing = {},
    mutatingHeaders = false,
}
STEP.SkillScanner = SkillScanner

local MISSING_CONFIRMATION_SCANS = 2

local function RestoreCollapsedHeaders(collapsedHeaders)
    if #collapsedHeaders == 0 or type(CollapseSkillHeader) ~= "function" then
        return
    end

    for collapsedIndex = #collapsedHeaders, 1, -1 do
        local headerName = collapsedHeaders[collapsedIndex]
        local lineCount = tonumber(GetNumSkillLines()) or 0
        for index = lineCount, 1, -1 do
            local skillName, isHeader, isExpanded = GetSkillLineInfo(index)
            if isHeader and isExpanded and skillName == headerName then
                CollapseSkillHeader(index)
                break
            end
        end
    end
end

function SkillScanner:ReadSnapshot()
    if type(GetNumSkillLines) ~= "function" or type(GetSkillLineInfo) ~= "function" then
        return false, nil, nil, "skill API unavailable"
    end

    local lineCount = tonumber(GetNumSkillLines()) or 0
    if lineCount <= 0 then
        return false, nil, nil, "skill API returned no lines"
    end

    local collapsedHeaders = {}
    for index = 1, lineCount do
        local skillName, isHeader, isExpanded = GetSkillLineInfo(index)
        if skillName and isHeader and not isExpanded then
            collapsedHeaders[#collapsedHeaders + 1] = skillName
        end
    end

    if #collapsedHeaders > 0 then
        if type(ExpandSkillHeader) ~= "function" or type(CollapseSkillHeader) ~= "function" then
            return false, nil, nil, "collapsed skill headers cannot be inspected safely"
        end
        self.mutatingHeaders = true
        local expanded, expandError = pcall(ExpandSkillHeader, 0)
        if not expanded then
            self.mutatingHeaders = false
            return false, nil, nil, "could not expand skill headers: " .. tostring(expandError)
        end
        lineCount = tonumber(GetNumSkillLines()) or 0
    end

    local snapshot = {}
    local unknown = {}
    local invalidLineError
    for index = 1, lineCount do
        local skillName, isHeader, isExpanded, skillRank, temporaryPoints, skillModifier, skillMaximum = GetSkillLineInfo(index)
        if skillName and not isHeader then
            local entry = STEP.SkillRegistry:Resolve(skillName)
            if entry and (not STEP.Util:IsFiniteNumber(skillRank)
                or not STEP.Util:IsFiniteNumber(skillMaximum)
                or skillRank < 0
                or skillMaximum <= 0) then
                invalidLineError = "invalid numeric values for " .. tostring(entry.key)
                break
            end

            local data = {
                name = skillName,
                current = STEP.Util:IsFiniteNumber(skillRank) and skillRank or 0,
                maximum = STEP.Util:IsFiniteNumber(skillMaximum) and skillMaximum or 0,
                temporary = STEP.Util:IsFiniteNumber(temporaryPoints) and temporaryPoints or 0,
                modifier = STEP.Util:IsFiniteNumber(skillModifier) and skillModifier or 0,
                learned = true,
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


    local restored, restoreError = pcall(RestoreCollapsedHeaders, collapsedHeaders)
    self.mutatingHeaders = false
    if not restored then
        return false, nil, nil, "could not restore skill headers: " .. tostring(restoreError)
    end
    if invalidLineError then
        return false, nil, nil, invalidLineError
    end

    if STEP.Util:CountKeys(snapshot) == 0 then
        return false, nil, nil, "no eligible skill lines were recognized"
    end

    table.sort(unknown, function(left, right)
        return tostring(left.name) < tostring(right.name)
    end)
    return true, snapshot, unknown
end

local function SnapshotFromKnown(skillKey, stored)
    local entry = STEP.SkillRegistry and STEP.SkillRegistry:Get(skillKey)
    if not entry or type(stored) ~= "table" then
        return nil
    end

    local current = tonumber(stored.current)
    local maximum = tonumber(stored.maximum)
    if not STEP.Util:IsFiniteNumber(current)
        or not STEP.Util:IsFiniteNumber(maximum)
        or current < 0
        or maximum <= 0 then
        return nil
    end

    local temporary = tonumber(stored.temporary)
    local modifier = tonumber(stored.modifier)
    return {
        skillKey = skillKey,
        name = entry.localizedName or entry.names.enUS,
        category = entry.category,
        tracker = entry.tracker,
        current = current,
        maximum = maximum,
        temporary = STEP.Util:IsFiniteNumber(temporary) and temporary or 0,
        modifier = STEP.Util:IsFiniteNumber(modifier) and modifier or 0,
        learned = true,
        scanIndex = 0,
    }
end

function SkillScanner:SeedBaselineMissing(current)
    self.pendingBaselineMissing = {}
    local known = STEP.Database and STEP.Database.db and STEP.Database.db.state.known or {}
    for skillKey, stored in pairs(known) do
        if type(stored) == "table" and stored.learned ~= false and not current[skillKey] then
            local previous = SnapshotFromKnown(skillKey, stored)
            if previous then
                self.pendingBaselineMissing[skillKey] = previous
                self.missingCounts[skillKey] = 1
            end
        end
    end
end

function SkillScanner:PreparePrevious(current, baseline)
    local previous = STEP.Util:ShallowCopy(self.snapshot)
    if baseline then
        self:SeedBaselineMissing(current)
        return previous
    end

    for skillKey, data in pairs(self.pendingBaselineMissing) do
        if current[skillKey] then
            previous[skillKey] = current[skillKey]
            self.missingCounts[skillKey] = nil
        else
            previous[skillKey] = data
        end
    end
    self.pendingBaselineMissing = {}
    return previous
end

function SkillScanner:ConfirmMissing(previous, current)
    for skillKey in pairs(current) do
        self.missingCounts[skillKey] = nil
    end

    for skillKey, data in pairs(previous) do
        if not current[skillKey] then
            local missingCount = (self.missingCounts[skillKey] or 0) + 1
            if missingCount < MISSING_CONFIRMATION_SCANS then
                self.missingCounts[skillKey] = missingCount
                current[skillKey] = data
            else
                self.missingCounts[skillKey] = nil
            end
        end
    end
end

function SkillScanner:HasPendingMissing()
    return next(self.missingCounts) ~= nil
end

function SkillScanner:IsMutatingHeaders()
    return self.mutatingHeaders == true
end

function SkillScanner:BuildChanges(previous, current, baseline)
    local changes = {}
    if baseline then
        return changes
    end

    for skillKey, data in pairs(current) do
        local old = previous[skillKey]
        if not old then
            local known = STEP.Database and STEP.Database:GetKnown(skillKey)
            changes[#changes + 1] = {
                type = "learned",
                skillKey = skillKey,
                current = data,
                relearned = known and known.learned == false or false,
            }
        else
            if data.current > old.current then
                changes[#changes + 1] = {
                    type = "gained",
                    skillKey = skillKey,
                    previous = old,
                    current = data,
                    gainedPoints = data.current - old.current,
                    reachedMaximum = data.maximum > 0 and data.current >= data.maximum,
                }
            elseif data.current < old.current then
                changes[#changes + 1] = {
                    type = "corrected",
                    skillKey = skillKey,
                    previous = old,
                    current = data,
                }
            end

            if data.maximum ~= old.maximum then
                changes[#changes + 1] = {
                    type = "maximumChanged",
                    skillKey = skillKey,
                    previous = old,
                    current = data,
                }
            end

            if data.temporary ~= old.temporary or data.modifier ~= old.modifier then
                changes[#changes + 1] = {
                    type = "modifierChanged",
                    skillKey = skillKey,
                    previous = old,
                    current = data,
                }
            end
        end
    end

    for skillKey, data in pairs(previous) do
        if not current[skillKey] then
            changes[#changes + 1] = {
                type = "unlearned",
                skillKey = skillKey,
                previous = data,
            }
        end
    end

    table.sort(changes, function(left, right)
        if left.skillKey == right.skillKey then
            return left.type < right.type
        end
        return left.skillKey < right.skillKey
    end)
    return changes
end

local eventForChange = {
    learned = "SKILL_LEARNED",
    gained = "SKILL_GAINED",
    corrected = "SKILL_CORRECTED",
    maximumChanged = "SKILL_MAXIMUM_CHANGED",
    modifierChanged = "SKILL_MODIFIER_CHANGED",
    unlearned = "SKILL_UNLEARNED",
}

function SkillScanner:EmitChanges(changes, reason)
    for index = 1, #changes do
        local change = changes[index]
        change.reason = reason
        STEP:Fire(eventForChange[change.type], change)

        if STEP.DebugProbe then
            if change.type == "gained" then
                STEP.DebugProbe:Record("skill", string.format(
                    "gain %s %d->%d/%d (+%d)",
                    change.skillKey,
                    change.previous.current,
                    change.current.current,
                    change.current.maximum,
                    change.gainedPoints
                ), true)
            elseif change.type == "learned" then
                STEP.DebugProbe:Record("skill", (change.relearned and "relearned " or "learned ") .. change.skillKey, true)
            elseif change.type == "unlearned" then
                STEP.DebugProbe:Record("skill", "unlearned " .. change.skillKey, true)
            elseif change.type == "maximumChanged" then
                STEP.DebugProbe:Record("skill", string.format("maximum %s %d->%d", change.skillKey, change.previous.maximum, change.current.maximum), true)
            elseif change.type == "modifierChanged" then
                STEP.DebugProbe:Record("skill", string.format("modifier %s %d->%d", change.skillKey, change.previous.modifier, change.current.modifier), true)
            elseif change.type == "corrected" then
                STEP.DebugProbe:Record("skill", string.format("decrease %s %d->%d", change.skillKey, change.previous.current, change.current.current), true)
            end
        end
    end
end

function SkillScanner:Scan(reason, baseline)
    local readSucceeded, ok, nextSnapshot, unknown, err = pcall(self.ReadSnapshot, self)
    if not readSucceeded then
        self.mutatingHeaders = false
        err = ok
        ok = false
        nextSnapshot = nil
        unknown = nil
    end
    if not ok then
        if STEP.DebugProbe then
            STEP.DebugProbe:Record("scan", "failed reason=" .. tostring(reason) .. " error=" .. tostring(err), true)
        end
        return false, err
    end

    local isBaseline = baseline == true
    local previous = self:PreparePrevious(nextSnapshot, isBaseline)
    if not isBaseline then
        self:ConfirmMissing(previous, nextSnapshot)
    end
    local changes = self:BuildChanges(previous, nextSnapshot, isBaseline)

    self.snapshot = nextSnapshot
    self.unknown = unknown

    if STEP.ConfigStore then
        for skillKey in pairs(nextSnapshot) do
            STEP.ConfigStore:EnsureSkill(skillKey)
        end
    end

    if STEP.Database then
        STEP.Database:PersistKnownSnapshot(nextSnapshot, reason, not isBaseline)
    end

    self:EmitChanges(changes, reason)
    local payload = {
        snapshot = nextSnapshot,
        previous = previous,
        changes = changes,
        reason = reason,
        baseline = isBaseline,
    }
    STEP:Fire("SKILLS_UPDATED", payload)

    if STEP.DebugProbe then
        STEP.DebugProbe:Record("scan", string.format(
            "reason=%s recognized=%d unknown=%d changes=%d baseline=%s",
            tostring(reason),
            STEP.Util:CountKeys(nextSnapshot),
            #unknown,
            #changes,
            tostring(isBaseline)
        ), false)
    end


    if self:HasPendingMissing() then
        self:Schedule("MISSING_CONFIRMATION")
    end
    return true, payload
end

function SkillScanner:Schedule(reason)
    self.scheduledReason = reason or self.scheduledReason or "unknown"
    if self.scanScheduled then
        return false
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
    return true
end

function SkillScanner:GetSnapshot()
    return self.snapshot
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
