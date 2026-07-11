local tests = {}
local passed = 0
local failed = 0

local function Test(name, callback)
    tests[#tests + 1] = {
        name = name,
        callback = callback,
    }
end

local function Fail(message)
    error(message or "assertion failed", 2)
end

local function AssertTrue(value, message)
    if value ~= true then
        Fail(message or ("expected true, got " .. tostring(value)))
    end
end

local function AssertFalse(value, message)
    if value ~= false then
        Fail(message or ("expected false, got " .. tostring(value)))
    end
end

local function AssertNil(value, message)
    if value ~= nil then
        Fail(message or ("expected nil, got " .. tostring(value)))
    end
end

local function AssertEqual(expected, actual, message)
    if expected ~= actual then
        Fail(message or ("expected " .. tostring(expected) .. ", got " .. tostring(actual)))
    end
end

local function DeepEqual(left, right, seen)
    if type(left) ~= type(right) then
        return false
    end
    if type(left) ~= "table" then
        return left == right
    end

    seen = seen or {}
    if seen[left] == right then
        return true
    end
    seen[left] = right

    for key, value in pairs(left) do
        if not DeepEqual(value, right[key], seen) then
            return false
        end
    end
    for key in pairs(right) do
        if left[key] == nil then
            return false
        end
    end
    return true
end

local function AssertDeepEqual(expected, actual, message)
    if not DeepEqual(expected, actual) then
        Fail(message or "tables are not deeply equal")
    end
end

local chatMessages = {}
local wallTime = 1000
local monotonicTime = 50
local timers = {}
local skillLines = {}
local skillHeaderMutationHook
local inventory = {}
local itemInfo = {}

DEFAULT_CHAT_FRAME = {
    AddMessage = function(_, message)
        chatMessages[#chatMessages + 1] = message
    end,
}
C_AddOns = {
    GetAddOnMetadata = function(_, field)
        if field == "Version" then
            return "0.2.0-alpha-test"
        end
    end,
}
C_Timer = {
    After = function(delay, callback)
        timers[#timers + 1] = {
            delay = delay,
            callback = callback,
        }
    end,
}
C_Item = {
    GetItemInfoInstant = function(item)
        local data = itemInfo[item]
        if not data and type(item) == "string" then
            local id = tonumber(item:match("item:(%d+)"))
            data = id and itemInfo[id]
        end
        if not data then
            return nil
        end
        return data[1], data[2], data[3], data[4], data[5], data[6], data[7]
    end,
}
Enum = {
    ItemClass = {
        Weapon = 2,
    },
    ItemWeaponSubclass = {
        Axe1H = 0,
        Axe2H = 1,
        Bows = 2,
        Guns = 3,
        Mace1H = 4,
        Mace2H = 5,
        Polearm = 6,
        Sword1H = 7,
        Sword2H = 8,
        Staff = 10,
        Unarmed = 13,
        Dagger = 15,
        Thrown = 16,
        Crossbow = 18,
        Wand = 19,
    },
}
INVSLOT_MAINHAND = 16
INVSLOT_OFFHAND = 17
INVSLOT_RANGED = 18
SlashCmdList = {}

function GetLocale()
    return "enUS"
end

function GetServerTime()
    return wallTime
end

function GetTimePreciseSec()
    return monotonicTime
end

local function GetVisibleSkillLines()
    local visible = {}
    local showChildren = true
    for index = 1, #skillLines do
        local row = skillLines[index]
        if row[2] then
            visible[#visible + 1] = row
            showChildren = row[3] ~= false
        elseif showChildren then
            visible[#visible + 1] = row
        end
    end
    return visible
end

function GetNumSkillLines()
    return #GetVisibleSkillLines()
end

function GetSkillLineInfo(index)
    local row = GetVisibleSkillLines()[index]
    if not row then
        return nil
    end
    return row[1], row[2], row[3], row[4], row[5], row[6], row[7]
end

function ExpandSkillHeader(index)
    if index == 0 then
        for rowIndex = 1, #skillLines do
            if skillLines[rowIndex][2] then
                skillLines[rowIndex][3] = true
            end
        end
        if skillHeaderMutationHook then
            skillHeaderMutationHook()
        end
        return
    end

    local row = GetVisibleSkillLines()[index]
    if row and row[2] then
        row[3] = true
        if skillHeaderMutationHook then
            skillHeaderMutationHook()
        end
    end
end

function CollapseSkillHeader(index)
    local row = GetVisibleSkillLines()[index]
    if row and row[2] then
        row[3] = false
        if skillHeaderMutationHook then
            skillHeaderMutationHook()
        end
    end
end

function GetInventoryItemLink(_, slotID)
    local item = inventory[slotID]
    return item and item.link or nil
end

function GetInventoryItemID(_, slotID)
    local item = inventory[slotID]
    return item and item.itemID or nil
end

function CreateFrame()
    local frame = {
        events = {},
        scripts = {},
    }
    function frame:RegisterEvent(event)
        self.events[event] = true
    end
    function frame:SetScript(scriptName, callback)
        self.scripts[scriptName] = callback
    end
    return frame
end

local STEP = {}
local loadedRuntimeFiles = {}

local function GetRuntimeFiles()
    local runtimeFiles = {}
    if type(arg) == "table" then
        for index = 1, #arg do
            if type(arg[index]) == "string" and arg[index]:match("%.lua$") then
                runtimeFiles[#runtimeFiles + 1] = arg[index]
            end
        end
    end

    if #runtimeFiles > 0 then
        return runtimeFiles
    end

    if io and type(io.open) == "function" then
        local toc = io.open("STEP.toc", "r")
        if toc then
            for line in toc:lines() do
                local path = line:match("^%s*(.-)%s*$")
                if path ~= "" and not path:match("^#") and path:match("%.lua$") then
                    runtimeFiles[#runtimeFiles + 1] = path
                end
            end
            toc:close()
        end
    end

    if #runtimeFiles == 0 then
        error("no runtime files were supplied and STEP.toc could not be read")
    end
    return runtimeFiles
end

local function LoadRuntimeFiles()
    local runtimeFiles = GetRuntimeFiles()

    for index = 1, #runtimeFiles do
        local path = runtimeFiles[index]
        local chunk, err = loadfile(path)
        if not chunk then
            error(path .. ": " .. tostring(err))
        end
        chunk("STEP", STEP)
        loadedRuntimeFiles[#loadedRuntimeFiles + 1] = path
    end
end

local loaded, loadError = pcall(LoadRuntimeFiles)
if not loaded then
    io.write("FAIL runtime load\n  ", tostring(loadError), "\n")
    os.exit(1)
end

local function SetSkillRows(rows)
    skillLines = rows
end

local function ResetRuntime(database)
    STEPDB = database
    wallTime = wallTime + 100
    monotonicTime = monotonicTime + 10
    timers = {}
    chatMessages = {}
    skillLines = {}
    skillHeaderMutationHook = nil
    inventory = {}
    itemInfo = {}

    STEP.ready = false
    STEP.blocked = false
    STEP.EventBus:Reset()

    STEP.Database.initialized = false
    STEP.Database.compatible = false
    STEP.Database.sessionStarted = false
    STEP.Database.recoveryCopy = nil
    STEP.Database.migrationError = nil
    STEP.Database.db = nil

    STEP.ConfigStore.initialized = false
    STEP.EquipmentResolver.state = {}
    STEP.SkillScanner.snapshot = {}
    STEP.SkillScanner.unknown = {}
    STEP.SkillScanner.scanScheduled = false
    STEP.SkillScanner.scheduledReason = nil
    STEP.SkillScanner.missingCounts = {}
    STEP.SkillScanner.pendingBaselineMissing = {}
    STEP.SkillScanner.mutatingHeaders = false

    STEP.SkillRegistry:BuildLookup()
end

local function InitializeStores(database)
    ResetRuntime(database)
    AssertTrue(STEP.Database:Initialize())
    AssertTrue(STEP.ConfigStore:Initialize())
end

local function Skill(name, rank, maximum, temporary, modifier)
    return { name, false, false, rank, temporary or 0, modifier or 0, maximum }
end

local function Header(name, expanded)
    return { name, true, expanded ~= false, 0, 0, 0, 0 }
end

local function AddItem(slotID, itemID, classID, subclassID, subtype)
    local link = "item:" .. tostring(itemID)
    inventory[slotID] = {
        itemID = itemID,
        link = link,
    }
    itemInfo[itemID] = { itemID, "Weapon", subtype or "Weapon", "INVTYPE_WEAPON", 1, classID, subclassID }
    itemInfo[link] = itemInfo[itemID]
end

Test("loads every Lua file from the toc", function()
    AssertTrue(#loadedRuntimeFiles > 0)
    AssertTrue(type(STEP.Core) == "nil")
    AssertTrue(type(STEP.Database) == "table")
    AssertTrue(type(STEP.eventFrame) == "table")
    AssertTrue(type(SlashCmdList.STEP) == "function")
end)

Test("EventBus preserves order and isolates listener errors", function()
    STEP.EventBus:Reset()
    local calls = {}
    STEP:RegisterCallback("TEST", "first", function(owner, payload)
        calls[#calls + 1] = owner .. payload.value
    end)
    STEP:RegisterCallback("TEST", nil, function()
        error("expected test error")
    end)
    STEP:RegisterCallback("TEST", "third", function(owner, payload)
        calls[#calls + 1] = owner .. payload.value
    end)

    AssertEqual(2, STEP:Fire("TEST", { value = "!" }))
    AssertDeepEqual({ "first!", "third!" }, calls)
    AssertEqual(1, #chatMessages)
end)

Test("EventBus handles subscription and removal during dispatch", function()
    STEP.EventBus:Reset()
    local calls = {}
    local secondToken
    STEP:RegisterCallback("TEST", nil, function()
        calls[#calls + 1] = "first"
        STEP:UnregisterCallback(secondToken)
        STEP:RegisterCallback("TEST", nil, function()
            calls[#calls + 1] = "late"
        end)
    end)
    secondToken = STEP:RegisterCallback("TEST", nil, function()
        calls[#calls + 1] = "second"
    end)

    STEP:Fire("TEST", {})
    AssertDeepEqual({ "first" }, calls)
    STEP:Fire("TEST", {})
    AssertDeepEqual({ "first", "first", "late" }, calls)
end)

Test("EventBus removes all listeners owned by one consumer", function()
    STEP.EventBus:Reset()
    local owner = {}
    STEP:RegisterCallback("ONE", owner, function() end)
    STEP:RegisterCallback("TWO", owner, function() end)
    STEP:RegisterCallback("TWO", {}, function() end)
    AssertEqual(2, STEP:UnregisterCallbackOwner(owner))
    AssertEqual(1, STEP.EventBus:GetListenerCount())
end)

Test("EventBus releases unsubscribed listeners without waiting for another emit", function()
    STEP.EventBus:Reset()
    local owner = {}
    local token = STEP:RegisterCallback("NEVER_AGAIN", owner, function() end)
    AssertTrue(STEP:UnregisterCallback(token))
    AssertEqual(0, STEP.EventBus:GetListenerCount())
    AssertNil(STEP.EventBus.listeners.NEVER_AGAIN)
    AssertEqual(0, STEP:UnregisterCallbackOwner(nil))
end)

Test("Database migrates schema 1 to 2 and preserves data", function()
    local legacy = {
        schemaVersion = 1,
        config = {
            debug = { enabled = true },
            skills = {},
        },
        state = {
            sessionCounter = 4,
            known = {
                ["combat.axes"] = { current = 10 },
            },
        },
        history = {
            events = { { id = 1 } },
        },
        futureSafeField = "preserve",
    }
    InitializeStores(legacy)

    AssertEqual(2, STEPDB.schemaVersion)
    AssertTrue(STEPDB.config.debug.enabled)
    AssertEqual(10, STEPDB.state.known["combat.axes"].current)
    AssertEqual(1, #STEPDB.history.events)
    AssertEqual("preserve", STEPDB.futureSafeField)
    AssertTrue(type(STEPDB.state.preferencesSeen) == "table")
    AssertTrue(type(STEPDB.history.archivedSegments) == "table")
end)

Test("Database migration is idempotent", function()
    local value = {
        schemaVersion = 1,
        config = { debug = { enabled = true } },
        state = {},
        history = {},
    }
    STEP.Database.migrations[1](value)
    local once = STEP.Util:DeepCopy(value)
    STEP.Database.migrations[1](value)
    AssertDeepEqual(once, value)
end)

Test("Database restores the recovery copy when migration fails", function()
    local originalMigration = STEP.Database.migrations[1]
    STEP.Database.migrations[1] = function(database)
        database.partiallyChanged = true
        error("migration exploded")
    end
    ResetRuntime({
        schemaVersion = 1,
        marker = "original",
    })
    AssertFalse(STEP.Database:Initialize())
    AssertEqual(1, STEPDB.schemaVersion)
    AssertEqual("original", STEPDB.marker)
    AssertNil(STEPDB.partiallyChanged)
    AssertTrue(type(STEP.Database.recoveryCopy) == "table")
    STEP.Database.migrations[1] = originalMigration
end)

Test("Database blocks a future schema without mutation", function()
    local future = {
        schemaVersion = 99,
        marker = "untouched",
    }
    ResetRuntime(future)
    AssertFalse(STEP.Database:Initialize())
    AssertFalse(STEP.Database:IsCompatible())
    AssertEqual(99, future.schemaVersion)
    AssertEqual("untouched", future.marker)
    AssertNil(future.config)
end)

Test("Database blocks invalid nonempty schemas without mutation", function()
    local invalidDatabases = {
        { marker = "missing" },
        { schemaVersion = "1", marker = "string" },
        { schemaVersion = 1.5, marker = "fraction" },
        { schemaVersion = 0, marker = "zero" },
    }

    for index = 1, #invalidDatabases do
        local database = invalidDatabases[index]
        local original = STEP.Util:DeepCopy(database)
        ResetRuntime(database)
        AssertFalse(STEP.Database:Initialize())
        AssertDeepEqual(original, STEPDB)
        AssertDeepEqual(original, STEP.Database.recoveryCopy)
        AssertNil(STEPDB.config)
    end
end)

Test("Database validates scalar counters and creates unique sessions", function()
    InitializeStores({ schemaVersion = 2, state = { sessionCounter = "bad" } })
    AssertEqual(0, STEPDB.state.sessionCounter)
    local first = STEP.Database:StartSession()
    STEP.Database.sessionStarted = false
    wallTime = wallTime + 1
    local second = STEP.Database:StartSession()
    AssertEqual(2, STEPDB.state.sessionCounter)
    AssertFalse(first == second)
end)

Test("Database rejects non-finite and negative counters", function()
    InitializeStores({
        schemaVersion = 2,
        state = {
            sessionCounter = math.huge,
            checkpointCount = -5,
        },
        history = {
            nextEventId = math.huge - math.huge,
            prunedEventCount = -math.huge,
        },
    })
    AssertEqual(0, STEPDB.state.sessionCounter)
    AssertEqual(0, STEPDB.state.checkpointCount)
    AssertEqual(1, STEPDB.history.nextEventId)
    AssertEqual(0, STEPDB.history.prunedEventCount)
end)

Test("Registry resolves localized names and weapon subclasses", function()
    STEP.SkillRegistry:BuildLookup()
    AssertEqual("combat.swords", STEP.SkillRegistry:Resolve("  swords  ").key)
    AssertNil(STEP.SkillRegistry:Resolve("Riding"))
    AssertEqual("combat.two_handed_axes", STEP.SkillRegistry:ResolveWeaponSubclass(1))
    AssertEqual("combat.fist_weapons", STEP.SkillRegistry:ResolveWeaponSubclass(13))
    AssertEqual(STEP.Constants.FALLBACK_SKILL_ICON, STEP.SkillRegistry:GetIcon("combat.swords"))
end)

Test("Registry resolves Brazilian Portuguese names to canonical keys", function()
    local originalGetLocale = GetLocale
    GetLocale = function() return "ptBR" end
    STEP.SkillRegistry:BuildLookup()
    AssertEqual("primary.mining", STEP.SkillRegistry:Resolve("Mineração").key)
    AssertEqual("combat.fist_weapons", STEP.SkillRegistry:Resolve("armas de punho").key)
    GetLocale = originalGetLocale
    STEP.SkillRegistry:BuildLookup()
end)

Test("Registry maps every eligible weapon subclass", function()
    local expected = {
        [0] = "combat.axes",
        [1] = "combat.two_handed_axes",
        [2] = "combat.bows",
        [3] = "combat.guns",
        [4] = "combat.maces",
        [5] = "combat.two_handed_maces",
        [6] = "combat.polearms",
        [7] = "combat.swords",
        [8] = "combat.two_handed_swords",
        [10] = "combat.staves",
        [13] = "combat.fist_weapons",
        [15] = "combat.daggers",
        [16] = "combat.thrown",
        [18] = "combat.crossbows",
        [19] = "combat.wands",
    }
    for subclassID, skillKey in pairs(expected) do
        AssertEqual(skillKey, STEP.SkillRegistry:ResolveWeaponSubclass(subclassID))
    end
end)

Test("ConfigStore applies first-discovery defaults once", function()
    InitializeStores(nil)
    STEP.EquipmentResolver.state = {
        mainHand = { skillKey = "combat.axes" },
    }

    local axes = STEP.ConfigStore:EnsureSkill("combat.axes")
    local mining = STEP.ConfigStore:EnsureSkill("primary.mining")
    AssertEqual("compact", axes.visibility)
    AssertTrue(axes.logEnabled)
    AssertEqual("hidden", mining.visibility)
    AssertFalse(mining.logEnabled)

    AssertTrue(STEP.ConfigStore:SetSkill("combat.axes", "visibility", "hidden", "test"))
    STEP.ConfigStore:EnsureSkill("combat.axes")
    AssertEqual("hidden", STEP.ConfigStore:GetSkill("combat.axes").visibility)
    AssertTrue(STEPDB.state.preferencesSeen["combat.axes"])
end)

Test("ConfigStore validates enums and batches emit once", function()
    InitializeStores(nil)
    STEP.ConfigStore:EnsureSkill("combat.swords")
    local callbacks = 0
    local payload
    STEP:RegisterCallback("CONFIG_CHANGED", nil, function(_, event)
        callbacks = callbacks + 1
        payload = event
    end)

    AssertFalse(STEP.ConfigStore:Set("panel.sortMode", "invalid", "test"))
    AssertTrue(STEP.ConfigStore:ApplyBatch({
        { path = "panel.sortMode", value = "alphabetical" },
        { scope = "skill", skillKey = "combat.swords", field = "visibility", value = "compact" },
    }, "test"))
    AssertEqual(1, callbacks)
    AssertTrue(payload.batch)
    AssertEqual(2, #payload.changes)
    AssertEqual("alphabetical", STEP.ConfigStore:Get("panel.sortMode"))
    AssertEqual("compact", STEP.ConfigStore:GetSkill("combat.swords").visibility)
end)

Test("ConfigStore repairs invalid persisted values in isolation", function()
    InitializeStores({
        schemaVersion = 2,
        config = {
            panel = {
                shown = "yes",
                scale = 9,
                sortMode = "random",
                customField = "preserve",
            },
            notifications = {
                gainMode = "loudest",
            },
        },
    })
    AssertTrue(STEP.ConfigStore:Get("panel.shown"))
    AssertEqual(1, STEP.ConfigStore:Get("panel.scale"))
    AssertEqual("progress", STEP.ConfigStore:Get("panel.sortMode"))
    AssertEqual("discreet", STEP.ConfigStore:Get("notifications.gainMode"))
    AssertEqual("preserve", STEPDB.config.panel.customField)
end)

Test("ConfigStore rejects an invalid batch atomically", function()
    InitializeStores(nil)
    local callbacks = 0
    STEP:RegisterCallback("CONFIG_CHANGED", nil, function()
        callbacks = callbacks + 1
    end)
    AssertFalse(STEP.ConfigStore:ApplyBatch({
        { path = "panel.sortMode", value = "alphabetical" },
        { path = "panel.combatBehavior", value = "invalid" },
    }, "test"))
    AssertEqual("progress", STEP.ConfigStore:Get("panel.sortMode"))
    AssertEqual(0, callbacks)
end)

Test("ConfigStore skill getter is read-only before discovery", function()
    InitializeStores(nil)
    AssertNil(STEP.ConfigStore:GetSkill("primary.mining"))
    AssertNil(STEPDB.config.skills["primary.mining"])
    AssertNil(STEPDB.state.preferencesSeen["primary.mining"])
end)

Test("ConfigStore batches use the last value for duplicate targets", function()
    InitializeStores(nil)
    STEP.ConfigStore:EnsureSkill("combat.swords")
    local callbacks = 0
    local payload
    STEP:RegisterCallback("CONFIG_CHANGED", nil, function(_, event)
        callbacks = callbacks + 1
        payload = event
    end)

    AssertTrue(STEP.ConfigStore:ApplyBatch({
        { path = "panel.sortMode", value = "alphabetical" },
        { path = "panel.sortMode", value = "progress" },
        { scope = "skill", skillKey = "combat.swords", field = "visibility", value = "compact" },
        { scope = "skill", skillKey = "combat.swords", field = "visibility", value = "hidden" },
    }, "duplicates"))
    AssertEqual("progress", STEP.ConfigStore:Get("panel.sortMode"))
    AssertEqual("hidden", STEP.ConfigStore:GetSkill("combat.swords").visibility)
    AssertEqual(1, callbacks)
    AssertEqual(1, #payload.changes)
    AssertEqual("combat.swords", payload.changes[1].skillKey)
end)

Test("Scanner baseline is silent and persists canonical data", function()
    InitializeStores(nil)
    SetSkillRows({
        Header("Weapon Skills"),
        Skill("Axes", 10, 75),
        Skill("Defense", 70, 75),
        Skill("Riding", 75, 75),
    })
    local learned = 0
    local gained = 0
    local updated
    STEP:RegisterCallback("SKILL_LEARNED", nil, function() learned = learned + 1 end)
    STEP:RegisterCallback("SKILL_GAINED", nil, function() gained = gained + 1 end)
    STEP:RegisterCallback("SKILLS_UPDATED", nil, function(_, event) updated = event end)

    AssertTrue(STEP.SkillScanner:Scan("baseline", true))
    AssertEqual(0, learned)
    AssertEqual(0, gained)
    AssertTrue(updated.baseline)
    AssertEqual(10, STEPDB.state.known["combat.axes"].current)
    AssertNil(STEPDB.state.known["combat.axes"].scanIndex)
    AssertEqual(1, #STEP.SkillScanner.unknown)
    AssertEqual("Riding", STEP.SkillScanner.unknown[1].name)
end)

Test("Scanner expands collapsed headers for a complete snapshot and restores them", function()
    InitializeStores(nil)
    SetSkillRows({
        Header("Weapon Skills", false),
        Skill("Axes", 10, 75),
        Header("Professions", true),
        Skill("Mining", 20, 75),
    })

    AssertTrue(STEP.SkillScanner:Scan("collapsed", true))
    AssertEqual(10, STEP.SkillScanner:GetSnapshot()["combat.axes"].current)
    AssertEqual(20, STEP.SkillScanner:GetSnapshot()["primary.mining"].current)
    local _, isHeader, isExpanded = GetSkillLineInfo(1)
    AssertTrue(isHeader)
    AssertFalse(isExpanded)
end)

Test("Scanner ignores skill events caused by its own header mutations", function()
    InitializeStores(nil)
    STEP.ready = true
    SetSkillRows({
        Header("Weapon Skills", false),
        Skill("Axes", 10, 75),
        Header("Professions", true),
        Skill("Mining", 20, 75),
    })
    skillHeaderMutationHook = function()
        STEP:OnEvent("SKILL_LINES_CHANGED")
    end

    AssertTrue(STEP.SkillScanner:Scan("collapsed-events", true))
    AssertEqual(0, #timers)
    AssertFalse(STEP.SkillScanner:IsMutatingHeaders())
end)

Test("Scanner rejects invalid recognized numeric rows without replacing state", function()
    InitializeStores(nil)
    SetSkillRows({ Skill("Axes", 10, 75) })
    AssertTrue(STEP.SkillScanner:Scan("baseline", true))

    local gains = 0
    local corrections = 0
    STEP:RegisterCallback("SKILL_GAINED", nil, function() gains = gains + 1 end)
    STEP:RegisterCallback("SKILL_CORRECTED", nil, function() corrections = corrections + 1 end)

    SetSkillRows({ Skill("Axes", nil, 75) })
    AssertFalse(STEP.SkillScanner:Scan("invalid-rank", false))
    AssertEqual(10, STEP.SkillScanner:GetSnapshot()["combat.axes"].current)
    AssertEqual(10, STEPDB.state.known["combat.axes"].current)

    SetSkillRows({ Skill("Axes", 11, 75) })
    AssertTrue(STEP.SkillScanner:Scan("recovered", false))
    AssertEqual(1, gains)
    AssertEqual(0, corrections)
end)

Test("Scanner installs and persists state before emitting deltas", function()
    InitializeStores(nil)
    SetSkillRows({ Skill("Axes", 10, 75, 0, 0) })
    AssertTrue(STEP.SkillScanner:Scan("baseline", true))

    local gainEvent
    local modifierEvent
    STEP:RegisterCallback("SKILL_GAINED", nil, function(_, event)
        gainEvent = event
        AssertEqual(12, STEP.SkillScanner:GetSnapshot()["combat.axes"].current)
        AssertEqual(12, STEPDB.state.known["combat.axes"].current)
    end)
    STEP:RegisterCallback("SKILL_MODIFIER_CHANGED", nil, function(_, event)
        modifierEvent = event
    end)

    SetSkillRows({ Skill("Axes", 12, 75, 0, 5) })
    AssertTrue(STEP.SkillScanner:Scan("gain", false))
    AssertEqual(2, gainEvent.gainedPoints)
    AssertEqual(5, modifierEvent.current.modifier)
end)

Test("Scanner treats modifier-only updates as context, not gains", function()
    InitializeStores(nil)
    SetSkillRows({ Skill("Fishing", 325, 375, 0, 23) })
    AssertTrue(STEP.SkillScanner:Scan("baseline", true))
    local gains = 0
    local modifiers = 0
    STEP:RegisterCallback("SKILL_GAINED", nil, function() gains = gains + 1 end)
    STEP:RegisterCallback("SKILL_MODIFIER_CHANGED", nil, function() modifiers = modifiers + 1 end)

    SetSkillRows({ Skill("Fishing", 325, 375, 0, 123) })
    AssertTrue(STEP.SkillScanner:Scan("lure", false))
    AssertEqual(0, gains)
    AssertEqual(1, modifiers)
    AssertEqual(325, STEPDB.state.known["secondary.fishing"].current)
    AssertEqual(123, STEPDB.state.known["secondary.fishing"].modifier)
end)

Test("Scanner reconciles previously known missing skills during baseline", function()
    InitializeStores({
        schemaVersion = 2,
        state = {
            known = {
                ["primary.mining"] = {
                    learned = true,
                    current = 75,
                    maximum = 150,
                },
            },
        },
    })
    SetSkillRows({ Skill("Axes", 10, 75) })
    AssertTrue(STEP.SkillScanner:Scan("baseline", true))
    AssertTrue(STEPDB.state.known["primary.mining"].learned)
    AssertTrue(STEP.SkillScanner:Scan("confirmation", false))
    AssertFalse(STEPDB.state.known["primary.mining"].learned)
end)

Test("Scanner handles learn, maximum change, unlearn and relearn", function()
    InitializeStores(nil)
    SetSkillRows({ Skill("Axes", 10, 75) })
    AssertTrue(STEP.SkillScanner:Scan("baseline", true))

    local learnedEvents = {}
    local maximumEvents = 0
    local unlearnedEvents = 0
    STEP:RegisterCallback("SKILL_LEARNED", nil, function(_, event)
        learnedEvents[#learnedEvents + 1] = event
    end)
    STEP:RegisterCallback("SKILL_MAXIMUM_CHANGED", nil, function()
        maximumEvents = maximumEvents + 1
    end)
    STEP:RegisterCallback("SKILL_UNLEARNED", nil, function()
        unlearnedEvents = unlearnedEvents + 1
    end)

    SetSkillRows({ Skill("Axes", 10, 80), Skill("Mining", 1, 75) })
    AssertTrue(STEP.SkillScanner:Scan("learn", false))
    AssertEqual(1, maximumEvents)
    AssertEqual("primary.mining", learnedEvents[1].skillKey)
    AssertFalse(learnedEvents[1].relearned)

    SetSkillRows({ Skill("Axes", 10, 80) })
    AssertTrue(STEP.SkillScanner:Scan("unlearn", false))
    AssertEqual(0, unlearnedEvents)
    AssertTrue(STEPDB.state.known["primary.mining"].learned)
    AssertTrue(STEP.SkillScanner:Scan("unlearn-confirm", false))
    AssertEqual(1, unlearnedEvents)
    AssertFalse(STEPDB.state.known["primary.mining"].learned)

    SetSkillRows({ Skill("Axes", 10, 80), Skill("Mining", 1, 75) })
    AssertTrue(STEP.SkillScanner:Scan("relearn", false))
    AssertTrue(learnedEvents[2].relearned)
end)

Test("Scanner rejects an empty API result without erasing state", function()
    InitializeStores(nil)
    SetSkillRows({ Skill("Axes", 10, 75) })
    AssertTrue(STEP.SkillScanner:Scan("baseline", true))
    SetSkillRows({})
    local ok = STEP.SkillScanner:Scan("bad", false)
    AssertFalse(ok)
    AssertEqual(10, STEP.SkillScanner:GetSnapshot()["combat.axes"].current)
    AssertTrue(STEPDB.state.known["combat.axes"].learned)
end)

Test("Scanner coalesces scheduled scans and keeps the latest reason", function()
    InitializeStores(nil)
    SetSkillRows({ Skill("Axes", 10, 75) })
    AssertTrue(STEP.SkillScanner:Scan("baseline", true))
    local updated
    STEP:RegisterCallback("SKILLS_UPDATED", nil, function(_, event)
        updated = event
    end)

    AssertTrue(STEP.SkillScanner:Schedule("first"))
    AssertFalse(STEP.SkillScanner:Schedule("second"))
    AssertEqual(1, #timers)
    AssertEqual(STEP.Constants.SKILL_SCAN_DELAY, timers[1].delay)
    timers[1].callback()
    AssertEqual("second", updated.reason)
end)

Test("EquipmentResolver emits previous, current and changed slots", function()
    InitializeStores(nil)
    AddItem(16, 1001, 2, 0, "Axe")
    AddItem(17, 1002, 2, 15, "Dagger")
    AddItem(18, 1003, 2, 19, "Wand")
    local payload
    STEP:RegisterCallback("EQUIPMENT_CHANGED", nil, function(_, event)
        payload = event
    end)

    local changed = STEP.EquipmentResolver:Update("test")
    AssertTrue(changed)
    AssertEqual("combat.axes", STEP.EquipmentResolver:GetHandSkill(false))
    AssertEqual("combat.daggers", STEP.EquipmentResolver:GetHandSkill(true))
    AssertEqual("combat.wands", STEP.EquipmentResolver:GetRangedSkill())
    AssertEqual(3, #payload.changedSlots)
    AssertTrue(type(payload.previous) == "table")
    AssertEqual("test", payload.reason)

    payload = nil
    AssertFalse(STEP.EquipmentResolver:Update("same"))
    AssertNil(payload)
end)

Test("EquipmentResolver distinguishes empty hands, fist weapons and unresolved items", function()
    InitializeStores(nil)
    STEP.EquipmentResolver:Update("empty")
    AssertEqual("combat.unarmed", STEP.EquipmentResolver:GetHandSkill(false))
    AssertNil(STEP.EquipmentResolver:GetHandSkill(true))

    AddItem(16, 2001, 2, 13, "Fist Weapon")
    STEP.EquipmentResolver:Update("fist")
    AssertEqual("combat.fist_weapons", STEP.EquipmentResolver:GetHandSkill(false))

    inventory[16] = { itemID = 2002, link = "item:2002" }
    itemInfo[2002] = nil
    itemInfo["item:2002"] = nil
    STEP.EquipmentResolver:Update("uncached")
    AssertTrue(STEP.EquipmentResolver:Get("mainHand").unresolved)
    AssertNil(STEP.EquipmentResolver:GetHandSkill(false))
end)

Test("EquipmentResolver keeps a changed slot unresolved until item data settles", function()
    InitializeStores(nil)
    STEP.EquipmentResolver:Update("equipment-event", 16)
    AssertTrue(STEP.EquipmentResolver:Get("mainHand").unresolved)
    AssertFalse(STEP.EquipmentResolver:Get("mainHand").empty)
    AssertNil(STEP.EquipmentResolver:GetHandSkill(false))

    AddItem(16, 4001, 2, 7, "Sword")
    STEP.EquipmentResolver:Update("equipment-retry")
    AssertFalse(STEP.EquipmentResolver:Get("mainHand").unresolved)
    AssertEqual("combat.swords", STEP.EquipmentResolver:GetHandSkill(false))

    inventory[16] = nil
    itemInfo[4001] = nil
    itemInfo["item:4001"] = nil
    STEP.EquipmentResolver:Update("unequip-event", 16)
    AssertTrue(STEP.EquipmentResolver:Get("mainHand").unresolved)
    AssertNil(STEP.EquipmentResolver:GetHandSkill(false))
    STEP.EquipmentResolver:Update("unequip-retry")
    AssertEqual("combat.unarmed", STEP.EquipmentResolver:GetHandSkill(false))
end)

Test("EquipmentResolver does not map non-weapon items", function()
    InitializeStores(nil)
    AddItem(16, 3001, 4, 0, "Armor")
    STEP.EquipmentResolver:Update("nonweapon")
    AssertNil(STEP.EquipmentResolver:GetHandSkill(false))
    AssertNil(STEP.EquipmentResolver:Get("mainHand").skillKey)
end)

Test("Core becomes ready only after a successful baseline", function()
    ResetRuntime(nil)
    SetSkillRows({ Skill("Axes", 10, 75) })
    local readyPayload
    STEP:RegisterCallback("STEP_READY", nil, function(_, event)
        readyPayload = event
    end)
    AssertTrue(STEP:Initialize())
    AssertTrue(STEP.ready)
    AssertFalse(STEP.blocked)
    AssertEqual(2, readyPayload.schemaVersion)
    AssertEqual(10, readyPayload.snapshot["combat.axes"].current)
end)

Test("Core remains blocked when the baseline cannot be read", function()
    ResetRuntime(nil)
    SetSkillRows({})
    local readyEvents = 0
    STEP:RegisterCallback("STEP_READY", nil, function()
        readyEvents = readyEvents + 1
    end)
    AssertFalse(STEP:Initialize())
    AssertFalse(STEP.ready)
    AssertTrue(STEP.blocked)
    AssertEqual(0, readyEvents)
end)

for index = 1, #tests do
    local test = tests[index]
    local ok, err = pcall(function()
        ResetRuntime(nil)
        test.callback()
    end)
    if ok then
        passed = passed + 1
        io.write("PASS ", test.name, "\n")
    else
        failed = failed + 1
        io.write("FAIL ", test.name, "\n  ", tostring(err), "\n")
    end
end

io.write(string.format("\n%d passed, %d failed\n", passed, failed))
if failed > 0 then
    os.exit(1)
end
