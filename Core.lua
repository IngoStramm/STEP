local addonName, STEP = ...

STEP.name = addonName
STEP.ready = false
STEP.blocked = false

local function GetMetadata(field)
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(addonName, field)
    end
    if GetAddOnMetadata then
        return GetAddOnMetadata(addonName, field)
    end
end

STEP.version = GetMetadata("Version") or "development"

function STEP:Print(message)
    local text = tostring(message or "")
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff58c6ff[STEP]|r " .. text)
    end
end

function STEP:RegisterCallback(eventName, owner, callback)
    return self.EventBus and self.EventBus:Subscribe(eventName, owner, callback) or nil
end

function STEP:UnregisterCallback(token)
    return self.EventBus and self.EventBus:Unsubscribe(token) or false
end

function STEP:UnregisterCallbackOwner(owner)
    return self.EventBus and self.EventBus:UnsubscribeOwner(owner) or 0
end

function STEP:Fire(eventName, payload)
    return self.EventBus and self.EventBus:Emit(eventName, payload) or 0
end

function STEP:PrepareSavedVariables()
    if not self.Database or not self.Database:Initialize() then
        self.blocked = true
        return false
    end

    if self.SkillRegistry then
        self.SkillRegistry:BuildLookup()
    end
    if self.ConfigStore and not self.ConfigStore:Initialize() then
        self.blocked = true
        return false
    end
    return true
end

function STEP:Initialize()
    if self.ready then
        return true
    end

    if not self:PrepareSavedVariables() then
        return false
    end

    self.Database:StartSession()
    if self.EquipmentResolver then
        self.EquipmentResolver:Update("PLAYER_LOGIN")
    end

    local scanOK, scanResult = self.SkillScanner:Scan("PLAYER_LOGIN", true)
    if not scanOK then
        self.blocked = true
        self:Print(self:GetText("BOOTSTRAP_SCAN_FAILED", tostring(scanResult)))
        return false
    end

    self.blocked = false
    self.ready = true
    if self.MainPanel then
        self.MainPanel:Initialize()
    end
    self:Fire("STEP_READY", {
        version = self.version,
        phase = self.Constants.DEVELOPMENT_PHASE,
        schemaVersion = self.Constants.SCHEMA_VERSION,
        snapshot = self.SkillScanner:GetSnapshot(),
    })
    self:Print(self:GetText("PHASE2_READY", self.version))
    return true
end

function STEP:OnEvent(event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            self:PrepareSavedVariables()
        end
        return
    end

    if event == "PLAYER_LOGIN" then
        self:Initialize()
        return
    end

    if event == "PLAYER_LOGOUT" then
        if self.Database then
            self.Database:Checkpoint("PLAYER_LOGOUT")
        end
        return
    end

    if not self.ready then
        if event == "PLAYER_ENTERING_WORLD" and self.Database and self.Database:IsCompatible() then
            self:Initialize()
        end
        return
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if self.DebugProbe then
            self.DebugProbe:HandleCombatLog()
        end
        return
    end

    if event == "SKILL_LINES_CHANGED"
        and self.SkillScanner
        and self.SkillScanner:IsMutatingHeaders() then
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        if self.MainPanel then
            self.MainPanel:SetCombatState(true)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if self.MainPanel then
            self.MainPanel:SetCombatState(false)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        self.EquipmentResolver:Update(event)
        self.SkillScanner:Schedule(event)
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        local slotID = ...
        self.EquipmentResolver:Update(event, slotID)
        self.SkillScanner:Schedule(event)
        if C_Timer and C_Timer.After then
            C_Timer.After(self.Constants.SKILL_SCAN_DELAY, function()
                if self.ready then
                    self.EquipmentResolver:Update(event .. "_RETRY")
                    self.SkillScanner:Schedule(event .. "_RETRY")
                end
            end)
        end
    elseif event == "SKILL_LINES_CHANGED"
        or event == "LEARNED_SPELL_IN_SKILL_LINE"
        or event == "PLAYER_LEVEL_UP" then
        self.SkillScanner:Schedule(event)
    elseif event == "PLAYER_DEAD" then
        self.Database:Checkpoint(event)
    end

    if self.DebugProbe then
        self.DebugProbe:HandleEvent(event, ...)
    end
end

local eventFrame = CreateFrame("Frame")
STEP.eventFrame = eventFrame

local events = {
    "ADDON_LOADED",
    "PLAYER_LOGIN",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_LOGOUT",
    "PLAYER_LEVEL_UP",
    "PLAYER_EQUIPMENT_CHANGED",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
    "PLAYER_DEAD",
    "SKILL_LINES_CHANGED",
    "LEARNED_SPELL_IN_SKILL_LINE",
    "COMBAT_LOG_EVENT_UNFILTERED",
    "UNIT_SPELLCAST_SENT",
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_SUCCEEDED",
    "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP",
    "TRADE_SKILL_SHOW",
    "TRADE_SKILL_UPDATE",
    "TRADE_SKILL_CLOSE",
    "CRAFT_SHOW",
    "CRAFT_UPDATE",
    "CRAFT_CLOSE",
    "LOOT_OPENED",
    "LOOT_CLOSED",
}

for index = 1, #events do
    eventFrame:RegisterEvent(events[index])
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    STEP:OnEvent(event, ...)
end)
