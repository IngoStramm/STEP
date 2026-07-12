local _, STEP = ...

local HistoryWindow = {
    initialized = false,
    rowPool = {},
    scope = "session",
    shareChannel = "SAY",
    shareGeneration = 0,
    shareSending = false,
}
STEP.HistoryWindow = HistoryWindow

local shareChannels = {
    { value = "SAY", textKey = "HISTORY_CHANNEL_SAY" },
    { value = "PARTY", textKey = "HISTORY_CHANNEL_PARTY" },
    { value = "RAID", textKey = "HISTORY_CHANNEL_RAID" },
    { value = "GUILD", textKey = "HISTORY_CHANNEL_GUILD" },
    { value = "WHISPER", textKey = "HISTORY_CHANNEL_WHISPER" },
}

local function IsAnchor(value)
    return value == "TOPLEFT" or value == "TOP" or value == "TOPRIGHT"
        or value == "LEFT" or value == "CENTER" or value == "RIGHT"
        or value == "BOTTOMLEFT" or value == "BOTTOM" or value == "BOTTOMRIGHT"
end

local function FormatDuration(value)
    local seconds = math.max(0, math.floor(tonumber(value) or 0))
    local minutes = math.floor(seconds / 60)
    seconds = seconds % 60
    if minutes >= 60 then
        return string.format("%dh %02dm", math.floor(minutes / 60), minutes % 60)
    end
    return string.format("%dm %02ds", minutes, seconds)
end

local function SavePosition(frame)
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    local target = STEP.Database.db.config.windows.log
    target.point = IsAnchor(point) and point or "CENTER"
    target.relativePoint = IsAnchor(relativePoint) and relativePoint or target.point
    target.x = STEP.Util:IsFiniteNumber(x) and x or 0
    target.y = STEP.Util:IsFiniteNumber(y) and y or 0
end

local function CreateText(parent, template, justify)
    local text = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    text:SetJustifyH(justify or "LEFT")
    text:SetJustifyV("MIDDLE")
    return text
end

local function IsShareChannelAvailable(channel)
    if channel == "SAY" or channel == "WHISPER" then
        return true
    end
    if channel == "PARTY" then
        if type(IsInGroup) == "function" then
            return IsInGroup() == true
        end
        return type(GetNumPartyMembers) == "function" and GetNumPartyMembers() > 0
    end
    if channel == "RAID" then
        return type(IsInRaid) == "function" and IsInRaid() == true
    end
    if channel == "GUILD" then
        return type(IsInGuild) == "function" and IsInGuild() == true
    end
    return false
end

function HistoryWindow:SetShareChannel(channel)
    if not IsShareChannelAvailable(channel) then
        STEP:Print(STEP:GetText("HISTORY_SHARE_CHANNEL_UNAVAILABLE"))
        return false
    end
    self.shareChannel = channel
    if self.channelDropdown and UIDropDownMenu_SetSelectedValue then
        UIDropDownMenu_SetSelectedValue(self.channelDropdown, channel)
    end
    if self.whisperTarget then
        self.whisperTarget:SetShown(channel == "WHISPER")
    end
    if self.whisperLabel then
        self.whisperLabel:SetShown(channel == "WHISPER")
    end
    return true
end

function HistoryWindow:AcquireRow(index)
    local row = self.rowPool[index]
    if row then
        return row
    end
    row = CreateFrame("Button", nil, self.list)
    row:SetHeight(23)
    row:RegisterForClicks("LeftButtonUp")
    row.highlight = row:CreateTexture(nil, "BACKGROUND")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(0.18, 0.48, 0.85, 0.25)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.name = CreateText(row)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
    row.name:SetWidth(146)
    row.progress = CreateText(row, nil, "RIGHT")
    row.progress:SetPoint("LEFT", row, "LEFT", 176, 0)
    row.progress:SetWidth(86)
    row.points = CreateText(row, nil, "RIGHT")
    row.points:SetPoint("LEFT", row, "LEFT", 270, 0)
    row.points:SetWidth(42)
    row.active = CreateText(row, nil, "RIGHT")
    row.active:SetPoint("LEFT", row, "LEFT", 322, 0)
    row.active:SetWidth(75)
    row.average = CreateText(row, nil, "RIGHT")
    row.average:SetPoint("LEFT", row, "LEFT", 407, 0)
    row.average:SetWidth(82)
    row:SetScript("OnClick", function(currentRow)
        self.selectedSkillKey = currentRow.skillKey
        self:Refresh()
    end)
    self.rowPool[index] = row
    return row
end

function HistoryWindow:RenderDetails()
    local events = self.selectedSkillKey and STEP.HistoryStore:GetEventsForScope(self.selectedSkillKey, self.scope) or {}
    if #events == 0 then
        self.details:SetText(STEP:GetText("HISTORY_DETAIL_EMPTY"))
        return
    end
    local lines = { STEP:GetText("HISTORY_DETAIL_TITLE", STEP.SkillRegistry:GetLocalizedName(self.selectedSkillKey)) }
    local first = math.max(1, #events - 4)
    for index = first, #events do
        local event = events[index]
        lines[#lines + 1] = STEP:GetText(
            "HISTORY_DETAIL_LINE",
            event.oldValue,
            event.newValue,
            FormatDuration(event.activeSeconds),
            FormatDuration(event.onlineSeconds)
        )
    end
    self.details:SetText(table.concat(lines, "\n"))
end

function HistoryWindow:CancelShare()
    self.shareGeneration = (self.shareGeneration or 0) + 1
    self.shareSending = false
    self.pendingShare = nil
end

function HistoryWindow:SendLines(lines, channel, target)
    if self.shareSending then
        STEP:Print(STEP:GetText("HISTORY_SHARE_BUSY"))
        return false
    end
    self.shareSending = true
    self.shareGeneration = (self.shareGeneration or 0) + 1
    local generation = self.shareGeneration

    local function SendNext(index)
        if generation ~= self.shareGeneration then
            return
        end
        if index > #lines then
            self.shareSending = false
            STEP:Print(STEP:GetText("HISTORY_SHARE_COMPLETE", #lines))
            return
        end
        if type(SendChatMessage) == "function" then
            SendChatMessage(lines[index], channel, nil, target)
        else
            STEP:Print(lines[index])
        end
        if index < #lines and C_Timer and type(C_Timer.After) == "function" then
            C_Timer.After(0.40, function() SendNext(index + 1) end)
        else
            SendNext(index + 1)
        end
    end

    SendNext(1)
    return true
end

function HistoryWindow:Share(skillKey, requireConfirmation)
    local lines = STEP.HistoryStore:GetShareLines(self.scope, skillKey)
    if #lines == 0 then
        STEP:Print(STEP:GetText("HISTORY_SHARE_EMPTY"))
        return false
    end
    local channel = self.shareChannel or "SAY"
    if not IsShareChannelAvailable(channel) then
        STEP:Print(STEP:GetText("HISTORY_SHARE_CHANNEL_UNAVAILABLE"))
        return false
    end
    local target
    if channel == "WHISPER" then
        target = self.whisperTarget and STEP.Util:Trim(self.whisperTarget:GetText()) or ""
        if target == "" then
            STEP:Print(STEP:GetText("HISTORY_SHARE_TARGET_REQUIRED"))
            return false
        end
    end
    if requireConfirmation or #lines > 1 then
        self.pendingShare = { lines = lines, channel = channel, target = target }
        if StaticPopup_Show then
            StaticPopup_Show("STEP_HISTORY_SHARE", #lines)
            return true
        end
    end
    return self:SendLines(lines, channel, target)
end

function HistoryWindow:Refresh()
    if not self.frame then
        return
    end
    self.sessionButton:SetEnabled(true)
    self.allButton:SetEnabled(true)
    local rows = STEP.HistoryStore:GetSummaryRows(self.scope)
    local hasSelected = false
    for index = 1, #rows do
        if rows[index].skillKey == self.selectedSkillKey then
            hasSelected = true
            break
        end
    end
    if not hasSelected then
        self.selectedSkillKey = rows[1] and rows[1].skillKey or nil
    end
    for index = 1, #self.rowPool do
        self.rowPool[index]:Hide()
    end
    for index = 1, #rows do
        local data = rows[index]
        local row = self:AcquireRow(index)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.list, "TOPLEFT", 0, -((index - 1) * 23))
        row:SetPoint("TOPRIGHT", self.list, "TOPRIGHT", 0, -((index - 1) * 23))
        row.skillKey = data.skillKey
        row.icon:SetTexture(STEP.SkillRegistry:GetIcon(data.skillKey))
        row.name:SetText(STEP.SkillRegistry:GetLocalizedName(data.skillKey))
        row.progress:SetText(string.format("%s -> %s", tostring(data.initialValue or "?"), tostring(data.latestValue or "?")))
        row.points:SetText("+" .. tostring(data.gainedPoints))
        row.active:SetText(FormatDuration(data.activeSeconds))
        local average = data.gainedPoints > 0 and data.activeSeconds / data.gainedPoints or 0
        row.average:SetText(data.gainedPoints > 0 and FormatDuration(average) or "-")
        row.highlight:SetShown(data.skillKey == self.selectedSkillKey)
        row:Show()
    end
    if self.scope == "session" then
        self.summary:SetText(STEP:GetText("HISTORY_VIEWING_SESSION"))
    else
        self.summary:SetText(STEP:GetText("HISTORY_VIEWING_ALL"))
    end
    self.empty:SetShown(#rows == 0)
    self:RenderDetails()
end

function HistoryWindow:Create()
    if self.frame then
        return self.frame
    end
    if not UIParent or not STEP.Database or not STEP.Database:IsCompatible() then
        return nil
    end
    local frame = CreateFrame("Frame", "STEPHistoryWindow", UIParent, "BasicFrameTemplateWithInset")
    self.frame = frame
    frame:SetSize(620, 480)
    local saved = STEP.Database.db.config.windows.log or {}
    frame:SetPoint(IsAnchor(saved.point) and saved.point or "CENTER", UIParent, IsAnchor(saved.relativePoint) and saved.relativePoint or "CENTER", saved.x or 0, saved.y or 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetScript("OnDragStart", function(currentFrame) currentFrame:StartMoving() end)
    frame:SetScript("OnDragStop", function(currentFrame)
        currentFrame:StopMovingOrSizing()
        SavePosition(currentFrame)
    end)
    frame:Hide()
    if frame.TitleText then
        frame.TitleText:SetText(STEP:GetText("HISTORY_WINDOW_TITLE"))
    end
    if UISpecialFrames then
        UISpecialFrames[#UISpecialFrames + 1] = "STEPHistoryWindow"
    end

    local sessionButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    self.sessionButton = sessionButton
    sessionButton:SetSize(118, 22)
    sessionButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -38)
    sessionButton:SetText(STEP:GetText("HISTORY_SCOPE_SESSION"))
    sessionButton:SetScript("OnClick", function()
        self.scope = "session"
        self:Refresh()
    end)
    local allButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    self.allButton = allButton
    allButton:SetSize(118, 22)
    allButton:SetPoint("LEFT", sessionButton, "RIGHT", 8, 0)
    allButton:SetText(STEP:GetText("HISTORY_SCOPE_ALL"))
    allButton:SetScript("OnClick", function()
        self.scope = "all"
        self:Refresh()
    end)

    local shareSelected = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    shareSelected:SetSize(112, 22)
    shareSelected:SetPoint("LEFT", allButton, "RIGHT", 12, 0)
    shareSelected:SetText(STEP:GetText("HISTORY_SHARE_SELECTED"))
    shareSelected:SetScript("OnClick", function()
        self:Share(self.selectedSkillKey)
    end)

    local shareView = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    shareView:SetSize(96, 22)
    shareView:SetPoint("LEFT", shareSelected, "RIGHT", 6, 0)
    shareView:SetText(STEP:GetText("HISTORY_SHARE_VIEW"))
    shareView:SetScript("OnClick", function()
        self:Share(nil, true)
    end)

    if StaticPopupDialogs then
        StaticPopupDialogs.STEP_HISTORY_CLEAR = StaticPopupDialogs.STEP_HISTORY_CLEAR or {
            text = STEP:GetText("HISTORY_CLEAR_CONFIRM"),
            button1 = YES,
            button2 = NO,
            OnAccept = function()
                if STEP.HistoryStore:Clear() then
                    STEP:Print(STEP:GetText("HISTORY_CLEARED"))
                end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopupDialogs.STEP_HISTORY_SHARE = StaticPopupDialogs.STEP_HISTORY_SHARE or {
            text = STEP:GetText("HISTORY_SHARE_CONFIRM"),
            button1 = YES,
            button2 = NO,
            OnAccept = function()
                local request = HistoryWindow.pendingShare
                HistoryWindow.pendingShare = nil
                if request then
                    HistoryWindow:SendLines(request.lines, request.channel, request.target)
                end
            end,
            OnCancel = function()
                HistoryWindow.pendingShare = nil
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end
    local clear = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    clear:SetSize(110, 22)
    clear:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -38)
    clear:SetText(STEP:GetText("HISTORY_CLEAR"))
    clear:SetScript("OnClick", function()
        if StaticPopup_Show then
            StaticPopup_Show("STEP_HISTORY_CLEAR")
        end
    end)

    local channelLabel = CreateText(frame, "GameFontNormalSmall")
    channelLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -72)
    channelLabel:SetText(STEP:GetText("HISTORY_SHARE_CHANNEL"))
    local channelDropdown = CreateFrame("Frame", nil, frame, "UIDropDownMenuTemplate")
    self.channelDropdown = channelDropdown
    channelDropdown:SetPoint("LEFT", channelLabel, "RIGHT", -8, -1)
    if UIDropDownMenu_SetWidth then
        UIDropDownMenu_SetWidth(channelDropdown, 110)
    end
    if UIDropDownMenu_Initialize then
        UIDropDownMenu_Initialize(channelDropdown, function(_, level)
            for index = 1, #shareChannels do
                local option = shareChannels[index]
                local info = UIDropDownMenu_CreateInfo()
                info.text = STEP:GetText(option.textKey)
                info.value = option.value
                info.disabled = not IsShareChannelAvailable(option.value)
                info.checked = self.shareChannel == option.value
                info.func = function()
                    self:SetShareChannel(option.value)
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
        UIDropDownMenu_SetSelectedValue(channelDropdown, self.shareChannel)
    end

    self.whisperLabel = CreateText(frame, "GameFontNormalSmall")
    self.whisperLabel:SetPoint("LEFT", channelDropdown, "RIGHT", 2, 0)
    self.whisperLabel:SetText(STEP:GetText("HISTORY_SHARE_TARGET"))
    self.whisperTarget = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    self.whisperTarget:SetSize(130, 22)
    self.whisperTarget:SetPoint("LEFT", self.whisperLabel, "RIGHT", 8, 0)
    self.whisperTarget:SetAutoFocus(false)
    self.whisperLabel:Hide()
    self.whisperTarget:Hide()

    self.summary = CreateText(frame, "GameFontDisableSmall", "RIGHT")
    self.summary:SetPoint("RIGHT", frame, "RIGHT", -20, -78)
    self.summary:SetText("")

    local headers = { { "HISTORY_COLUMN_SKILL", 0, "LEFT" }, { "HISTORY_COLUMN_PROGRESS", 176, "RIGHT" }, { "HISTORY_COLUMN_POINTS", 270, "RIGHT" }, { "HISTORY_COLUMN_ACTIVE", 322, "RIGHT" }, { "HISTORY_COLUMN_AVERAGE", 407, "RIGHT" } }
    for index = 1, #headers do
        local header = CreateText(frame, "GameFontNormalSmall", headers[index][3])
        header:SetPoint("TOPLEFT", frame, "TOPLEFT", 22 + headers[index][2], -103)
        header:SetWidth(index == 1 and 150 or 80)
        header:SetText(STEP:GetText(headers[index][1]))
    end
    self.list = CreateFrame("Frame", nil, frame)
    self.list:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -129)
    self.list:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -129)
    self.list:SetHeight(189)
    self.empty = CreateText(self.list, "GameFontDisableSmall", "CENTER")
    self.empty:SetAllPoints()
    self.empty:SetText(STEP:GetText("HISTORY_EMPTY"))

    self.details = CreateText(frame, "GameFontHighlightSmall", "LEFT")
    self.details:SetPoint("TOPLEFT", self.list, "BOTTOMLEFT", 2, -14)
    self.details:SetPoint("TOPRIGHT", self.list, "BOTTOMRIGHT", -2, -14)
    self.details:SetJustifyV("TOP")

    frame:SetScript("OnShow", function() self:Refresh() end)
    frame:SetScript("OnHide", function() self:CancelShare() end)
    self.initialized = true
    STEP:RegisterCallback("HISTORY_UPDATED", self, function() self:Refresh() end)
    return frame
end

function HistoryWindow:Open()
    local frame = self:Create()
    if not frame then
        return false
    end
    self:Refresh()
    frame:Show()
    if frame.Raise then
        frame:Raise()
    end
    return true
end
