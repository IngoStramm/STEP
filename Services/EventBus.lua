local _, STEP = ...

local EventBus = {
    listeners = {},
    tokens = {},
    nextToken = 0,
    dispatchDepth = 0,
    dirtyEvents = {},
}
STEP.EventBus = EventBus

local function Compact(list)
    local writeIndex = 1
    for readIndex = 1, #list do
        local listener = list[readIndex]
        if listener.active then
            list[writeIndex] = listener
            writeIndex = writeIndex + 1
        end
    end

    for index = writeIndex, #list do
        list[index] = nil
    end
end

local function CleanupEvent(self, eventName)
    local list = self.listeners[eventName]
    if not list then
        self.dirtyEvents[eventName] = nil
        return
    end

    Compact(list)
    if #list == 0 then
        self.listeners[eventName] = nil
    end
    self.dirtyEvents[eventName] = nil
end

local function MarkForCleanup(self, eventName)
    if self.dispatchDepth > 0 then
        self.dirtyEvents[eventName] = true
    else
        CleanupEvent(self, eventName)
    end
end

function EventBus:Subscribe(eventName, owner, callback)
    if type(eventName) ~= "string" or eventName == "" or type(callback) ~= "function" then
        return nil
    end

    local list = self.listeners[eventName]
    if not list then
        list = {}
        self.listeners[eventName] = list
    end

    self.nextToken = self.nextToken + 1
    local listener = {
        token = self.nextToken,
        eventName = eventName,
        owner = owner,
        callback = callback,
        active = true,
    }
    list[#list + 1] = listener
    self.tokens[listener.token] = listener
    return listener.token
end

function EventBus:Unsubscribe(token)
    local listener = self.tokens[token]
    if not listener then
        return false
    end

    listener.active = false
    self.tokens[token] = nil
    MarkForCleanup(self, listener.eventName)
    return true
end

function EventBus:UnsubscribeOwner(owner)
    if owner == nil then
        return 0
    end

    local removed = 0
    local affectedEvents = {}
    for token, listener in pairs(self.tokens) do
        if listener.owner == owner then
            listener.active = false
            self.tokens[token] = nil
            affectedEvents[listener.eventName] = true
            removed = removed + 1
        end
    end

    for eventName in pairs(affectedEvents) do
        MarkForCleanup(self, eventName)
    end
    return removed
end

function EventBus:Emit(eventName, payload)
    local list = self.listeners[eventName]
    if not list or #list == 0 then
        return 0
    end

    local snapshot = {}
    for index = 1, #list do
        snapshot[index] = list[index]
    end

    local delivered = 0
    self.dispatchDepth = self.dispatchDepth + 1
    for index = 1, #snapshot do
        local listener = snapshot[index]
        if listener.active then
            local ok, err = pcall(listener.callback, listener.owner, payload)
            if ok then
                delivered = delivered + 1
            elseif STEP.Print then
                STEP:Print("Callback " .. tostring(eventName) .. " failed: " .. tostring(err))
            end
        end
    end
    self.dispatchDepth = self.dispatchDepth - 1

    self.dirtyEvents[eventName] = true
    if self.dispatchDepth == 0 then
        local dirtyEvents = self.dirtyEvents
        self.dirtyEvents = {}
        for dirtyEvent in pairs(dirtyEvents) do
            CleanupEvent(self, dirtyEvent)
        end
    end
    return delivered
end

function EventBus:GetListenerCount(eventName)
    if eventName then
        local list = self.listeners[eventName] or {}
        local count = 0
        for index = 1, #list do
            if list[index].active then
                count = count + 1
            end
        end
        return count
    end

    local count = 0
    for _ in pairs(self.tokens) do
        count = count + 1
    end
    return count
end

function EventBus:Reset()
    self.listeners = {}
    self.tokens = {}
    self.nextToken = 0
    self.dispatchDepth = 0
    self.dirtyEvents = {}
end
