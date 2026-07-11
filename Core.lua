local addonName, STEP = ...

STEP.name = addonName
STEP.callbacks = STEP.callbacks or {}
STEP.ready = false

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
    if type(eventName) ~= "string" or type(callback) ~= "function" then
        return
    end

    local listeners = self.callbacks[eventName]
    if not listeners then
        listeners = {}
        self.callbacks[eventName] = listeners
    end

    listeners[#listeners + 1] = {
        owner = owner,
        callback = callback,
    }
end

function STEP:Fire(eventName, ...)
    local listeners = self.callbacks[eventName]
    if not listeners then
        return
    end

    for index = 1, #listeners do
        local listener = listeners[index]
        local ok, err = pcall(listener.callback, listener.owner, ...)
        if not ok then
            self:Print("Callback " .. eventName .. " failed: " .. tostring(err))
        end
    end
end

function STEP:Initialize()
    if self.ready then
        return
    end

    if self.Database and not self.Database.db then
        self.Database:Initialize()
    end

    if self.Database then
        self.Database:StartSession()
    end

    if self.SkillRegistry then
        self.SkillRegistry:BuildLookup()
    end

    if self.EquipmentResolver then
        self.EquipmentResolver:Update("PLAYER_LOGIN")
    end

    if self.SkillScanner then
        self.SkillScanner:Scan("PLAYER_LOGIN", true)
    end

    self.ready = true
    self:Fire("STEP_READY")
    self:Print(self:GetText("PHASE0_READY", self.version))
end

function STEP:OnEvent(event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName and self.Database then
            self.Database:Initialize()
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
        return
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if self.DebugProbe then
            self.DebugProbe:HandleCombatLog()
        end
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        if self.EquipmentResolver then
            self.EquipmentResolver:Update(event)
        end
        if self.SkillScanner then
            self.SkillScanner:Schedule(event)
        end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        if self.EquipmentResolver then
            self.EquipmentResolver:Update(event)
        end
    elseif event == "SKILL_LINES_CHANGED"
        or event == "LEARNED_SPELL_IN_SKILL_LINE"
        or event == "PLAYER_LEVEL_UP" then
        if self.SkillScanner then
            self.SkillScanner:Schedule(event)
        end
    elseif event == "PLAYER_DEAD" then
        if self.Database then
            self.Database:Checkpoint(event)
        end
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
