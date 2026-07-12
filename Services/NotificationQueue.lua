local _, STEP = ...

local NotificationQueue = {
    initialized = false,
    queue = {},
    current = nil,
}
STEP.NotificationQueue = NotificationQueue

local notificationOffsets = {
    upper = 210,
    center = 0,
    lower = -210,
}

local function CanNotify(change)
    if not STEP.ConfigStore or STEP.ConfigStore:Get("notifications.enabled") ~= true then
        return false
    end
    local config = STEP.ConfigStore and STEP.ConfigStore:GetSkill(change.skillKey)
    return config and config.notifyEnabled == true
end

function NotificationQueue:CenterContent(frame)
    local textWidth = frame.text:GetStringWidth() or 0
    local totalWidth = 42 + 10 + textWidth
    frame.icon:ClearAllPoints()
    frame.icon:SetPoint("LEFT", frame, "CENTER", -totalWidth / 2, 0)
    frame.text:ClearAllPoints()
    frame.text:SetPoint("LEFT", frame.icon, "RIGHT", 10, 0)
end

function NotificationQueue:EnsureFrame()
    if self.frame then
        return self.frame
    end
    if not UIParent or type(CreateFrame) ~= "function" then
        return nil
    end
    local frame = CreateFrame("Frame", "STEPNotificationFrame", UIParent)
    self.frame = frame
    frame:SetSize(300, 72)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 210)
    frame:SetFrameStrata("HIGH")
    frame:Hide()

    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetSize(42, 42)
    frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    frame.text:SetJustifyH("LEFT")
    frame.text:SetJustifyV("MIDDLE")
    frame:SetScript("OnUpdate", function(_, elapsed)
        self:OnUpdate(elapsed)
    end)
    return frame
end

function NotificationQueue:ShowNext()
    if self.current or #self.queue == 0 then
        return
    end
    local frame = self:EnsureFrame()
    if not frame then
        return
    end
    self.current = table.remove(self.queue, 1)
    self.current.elapsed = 0
    self.current.duration = 1.8
    frame:ClearAllPoints()
    local position = STEP.ConfigStore:Get("notifications.position") or "upper"
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, notificationOffsets[position] or notificationOffsets.upper)
    frame.icon:SetTexture(STEP.SkillRegistry:GetIcon(self.current.change.skillKey))
    frame.text:SetText(STEP:GetText(
        self.current.change.reachedMaximum and "NOTIFICATION_MAX" or "NOTIFICATION_GAIN",
        STEP.SkillRegistry:GetLocalizedName(self.current.change.skillKey),
        self.current.change.current.current,
        self.current.change.current.maximum
    ))
    self:CenterContent(frame)
    frame:SetScale(STEP.ConfigStore:Get("notifications.scale") or 1)
    frame:SetAlpha(1)
    frame:Show()
    if STEP.SoundRegistry then
        STEP.SoundRegistry:Play(
            STEP.ConfigStore:Get("notifications.sound") or "none",
            STEP.ConfigStore:Get("notifications.soundChannel") or "Master"
        )
    end
end

function NotificationQueue:Queue(change)
    self.queue[#self.queue + 1] = { change = change }
    self:ShowNext()
    return true
end

function NotificationQueue:OnUpdate(elapsed)
    local current = self.current
    if not current or not self.frame then
        return
    end
    current.elapsed = current.elapsed + (elapsed or 0)
    local remaining = current.duration - current.elapsed
    if remaining <= 0 then
        self.frame:Hide()
        self.current = nil
        self:ShowNext()
        return
    end
    local fadeStart = current.duration * 0.62
    if current.elapsed >= fadeStart then
        self.frame:SetAlpha(math.max(0, remaining / (current.duration - fadeStart)))
    end
end

function NotificationQueue:HandleGain(change)
    if not CanNotify(change) then
        return false
    end
    return self:Queue(change)
end

function NotificationQueue:Preview(reachedMaximum)
    if not STEP.ConfigStore or STEP.ConfigStore:Get("notifications.enabled") ~= true then
        STEP:Print(STEP:GetText("NOTIFICATION_PREVIEW_DISABLED"))
        return false
    end

    local snapshot = STEP.SkillScanner and STEP.SkillScanner:GetSnapshot() or {}
    local entries = STEP.SkillRegistry and STEP.SkillRegistry:GetEntries() or {}
    for index = 1, #entries do
        local skillKey = entries[index].key
        local skill = snapshot[skillKey]
        if skill and skill.learned ~= false and tonumber(skill.current) and tonumber(skill.maximum) then
            local current = tonumber(skill.current)
            local maximum = tonumber(skill.maximum)
            if reachedMaximum then
                current = maximum
            end
            return self:Queue({
                skillKey = skillKey,
                current = {
                    current = current,
                    maximum = maximum,
                },
                reachedMaximum = reachedMaximum and true or false,
                preview = true,
            })
        end
    end

    STEP:Print(STEP:GetText("NOTIFICATION_PREVIEW_UNAVAILABLE"))
    return false
end

function NotificationQueue:Initialize()
    if self.initialized then
        return true
    end
    self.token = STEP:RegisterCallback("SKILL_GAINED", self, function(_, change)
        self:HandleGain(change)
    end)
    self.initialized = self.token ~= nil
    return self.initialized
end
