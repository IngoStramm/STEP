local _, STEP = ...

local ConfigWindow = {}
STEP.ConfigWindow = ConfigWindow

local function IsAnchor(value)
    return value == "TOPLEFT" or value == "TOP" or value == "TOPRIGHT"
        or value == "LEFT" or value == "CENTER" or value == "RIGHT"
        or value == "BOTTOMLEFT" or value == "BOTTOM" or value == "BOTTOMRIGHT"
end

local function GetSavedPosition()
    local config = STEP.Database and STEP.Database.db and STEP.Database.db.config.windows.config or {}
    local point = IsAnchor(config.point) and config.point or "CENTER"
    local relativePoint = IsAnchor(config.relativePoint) and config.relativePoint or "CENTER"
    local x = STEP.Util:IsFiniteNumber(config.x) and config.x or 0
    local y = STEP.Util:IsFiniteNumber(config.y) and config.y or 0
    return point, relativePoint, x, y
end

local function SavePosition(frame)
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    local config = STEP.Database.db.config.windows.config
    config.point = IsAnchor(point) and point or "CENTER"
    config.relativePoint = IsAnchor(relativePoint) and relativePoint or config.point
    config.x = STEP.Util:IsFiniteNumber(x) and x or 0
    config.y = STEP.Util:IsFiniteNumber(y) and y or 0
end

function ConfigWindow:Create()
    if self.frame then
        return self.frame
    end
    if not UIParent or not STEP.Database or not STEP.Database:IsCompatible() then
        return nil
    end

    local ok, frame = pcall(CreateFrame, "Frame", "STEPConfigWindow", UIParent, "BasicFrameTemplateWithInset")
    if not ok or not frame then
        local template = BackdropTemplateMixin and "BackdropTemplate" or nil
        frame = CreateFrame("Frame", "STEPConfigWindow", UIParent, template)
        if frame.SetBackdrop then
            frame:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true,
                tileSize = 16,
                edgeSize = 12,
                insets = { left = 3, right = 3, top = 3, bottom = 3 },
            })
        end
        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 2, 2)
    end

    self.frame = frame
    frame:SetSize(760, 640)
    local point, relativePoint, x, y = GetSavedPosition()
    frame:SetPoint(point, UIParent, relativePoint, x, y)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetScript("OnDragStart", function(currentFrame)
        currentFrame:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(currentFrame)
        currentFrame:StopMovingOrSizing()
        SavePosition(currentFrame)
    end)
    frame:Hide()

    if frame.TitleText then
        frame.TitleText:SetText("STEP")
    else
        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        title:SetPoint("TOP", frame, "TOP", 0, -6)
        title:SetText("STEP")
    end

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -30)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    self.content = content
    self.surface = STEP.OptionsControls:BuildSurface(content, "Standalone")

    frame:SetScript("OnShow", function()
        STEP.OptionsControls:RefreshAll()
    end)

    if UISpecialFrames then
        UISpecialFrames[#UISpecialFrames + 1] = "STEPConfigWindow"
    end
    return frame
end

function ConfigWindow:Open()
    local frame = self:Create()
    if not frame then
        return false
    end
    STEP.OptionsControls:RefreshAll()
    frame:Show()
    if frame.Raise then
        frame:Raise()
    end
    return true
end
