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
local combatLogInfo = {}

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

function UnitGUID(unit)
    return unit == "player" and "Player-1" or nil
end

function CombatLogGetCurrentEventInfo()
    return (table.unpack or unpack)(combatLogInfo)
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
    combatLogInfo = {}

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
    STEP.ActivityTracker.initialized = false
    STEP.CombatTracker.initialized = false
    STEP.CombatTracker.inCombat = false
    STEP.ProfessionTracker.initialized = false
    STEP.ProfessionTracker.tradeSkillKey = nil
    STEP.ProfessionTracker.craftSkillKey = nil
    STEP.ProfessionTracker.sent = {}
    STEP.ProfessionTracker.active = {}
    STEP.ProfessionTracker.fishingCastGUID = nil
    STEP.NotificationQueue.initialized = false
    STEP.NotificationQueue.queue = {}
    STEP.NotificationQueue.current = nil
    STEP.NotificationQueue.frame = nil
    STEP.NotificationQueue.token = nil
    STEP.HistoryStore.initialized = false
    STEP.HistoryStore.tokens = {}
    STEP.EquipmentResolver.state = {}
    STEP.SkillScanner.snapshot = {}
    STEP.SkillScanner.unknown = {}
    STEP.SkillScanner.scanScheduled = false
    STEP.SkillScanner.scheduledReason = nil
    STEP.SkillScanner.missingCounts = {}
    STEP.SkillScanner.pendingBaselineMissing = {}
    STEP.SkillScanner.mutatingHeaders = false

    STEP.SkillRegistry:BuildLookup()
    if STEP.MainPanel then
        STEP.MainPanel.inCombat = false
        STEP.MainPanel.lastModel = nil
    end
end

local function InitializeStores(database)
    ResetRuntime(database)
    AssertTrue(STEP.Database:Initialize())
    AssertTrue(STEP.ConfigStore:Initialize())
end

local function InitializeTracking(database)
    InitializeStores(database)
    STEP.Database:StartSession()
    AssertTrue(STEP.ActivityTracker:Initialize())
    AssertTrue(STEP.CombatTracker:Initialize())
    AssertTrue(STEP.ProfessionTracker:Initialize())
    AssertTrue(STEP.HistoryStore:Initialize())
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

local function SnapshotSkill(current, maximum, temporary, modifier)
    return {
        current = current,
        maximum = maximum,
        temporary = temporary or 0,
        modifier = modifier or 0,
        learned = true,
    }
end

local function RowsByKey(viewModel)
    local rows = {}
    for index = 1, #viewModel.rows do
        rows[viewModel.rows[index].skillKey] = viewModel.rows[index]
    end
    return rows
end

Test("loads every Lua file from the toc", function()
    AssertTrue(#loadedRuntimeFiles > 0)
    AssertTrue(type(STEP.Core) == "nil")
    AssertTrue(type(STEP.Database) == "table")
    AssertTrue(type(STEP.ConfigActions) == "table")
    AssertTrue(type(STEP.MainPanel) == "table")
    AssertTrue(type(STEP.OptionsControls) == "table")
    AssertTrue(type(STEP.NativeOptions) == "table")
    AssertTrue(type(STEP.ConfigWindow) == "table")
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
                enabled = "yes",
                scale = 9,
                position = "diagonal",
                sound = "missing",
                soundChannel = "Effects",
            },
        },
    })
    AssertTrue(STEP.ConfigStore:Get("panel.shown"))
    AssertEqual(1, STEP.ConfigStore:Get("panel.scale"))
    AssertEqual("progress", STEP.ConfigStore:Get("panel.sortMode"))
    AssertTrue(STEP.ConfigStore:Get("notifications.enabled"))
    AssertEqual(1, STEP.ConfigStore:Get("notifications.scale"))
    AssertEqual("upper", STEP.ConfigStore:Get("notifications.position"))
    AssertEqual("none", STEP.ConfigStore:Get("notifications.sound"))
    AssertEqual("Master", STEP.ConfigStore:Get("notifications.soundChannel"))
    AssertEqual("preserve", STEPDB.config.panel.customField)
end)

Test("SoundRegistry validates and plays native and optional sounds", function()
    InitializeStores(nil)
    AssertTrue(STEP.SoundRegistry:IsValid("none"))
    AssertTrue(STEP.SoundRegistry:IsValid("wa_tada"))
    AssertFalse(STEP.SoundRegistry:IsValid("missing"))
    AssertFalse(STEP.SoundRegistry:Play("none", "Master"))

    local originalGetAddOnInfo = C_AddOns.GetAddOnInfo
    C_AddOns.GetAddOnInfo = function(name)
        if name == "WeakAuras" or name == "Decursive" then
            return name
        end
    end
    local soundValues = STEP.SoundRegistry:GetValues()
    AssertTrue(#soundValues > 100)
    AssertTrue(STEP.SoundRegistry:IsValid("decursive_affliction"))
    AssertTrue(STEP.SoundRegistry:IsValid("wa_voice_triangle"))
    AssertTrue(STEP.SoundRegistry:IsValid("wa_pa_yeehaw"))
    C_AddOns.GetAddOnInfo = originalGetAddOnInfo

    local originalPlaySoundFile = PlaySoundFile
    local originalPlaySound = PlaySound
    local originalSoundKit = SOUNDKIT
    local filePath, fileChannel, kitId, kitChannel
    PlaySoundFile = function(path, channel)
        filePath, fileChannel = path, channel
        return true
    end
    PlaySound = function(id, channel)
        kitId, kitChannel = id, channel
        return true
    end
    SOUNDKIT = { RAID_WARNING = 12345 }

    AssertTrue(STEP.SoundRegistry:Play("wa_tada", "SFX"))
    AssertTrue(string.find(filePath, "WeakAuras", 1, true) ~= nil)
    AssertEqual("SFX", fileChannel)
    AssertTrue(STEP.SoundRegistry:Play("raid", "Dialog"))
    AssertEqual(12345, kitId)
    AssertEqual("Dialog", kitChannel)

    PlaySoundFile = originalPlaySoundFile
    PlaySound = originalPlaySound
    SOUNDKIT = originalSoundKit
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

Test("ConfigActions builds the four presets for learned skills only", function()
    InitializeStores(nil)
    local snapshot = {
        ["combat.axes"] = SnapshotSkill(10, 100),
        ["combat.swords"] = SnapshotSkill(20, 100),
        ["combat.defense"] = SnapshotSkill(30, 100),
        ["primary.mining"] = SnapshotSkill(40, 100),
        ["secondary.cooking"] = SnapshotSkill(50, 100),
    }
    local equipment = {
        mainHand = { skillKey = "combat.axes" },
    }

    local function Targets(proposal)
        local targets = {}
        for index = 1, #proposal.changes do
            local change = proposal.changes[index]
            targets[change.skillKey] = targets[change.skillKey] or {}
            targets[change.skillKey][change.field] = change.value
        end
        return targets
    end

    local options = { snapshot = snapshot, equipment = equipment }
    local weapons = Targets(STEP.ConfigActions:BuildPresetProposal("weapons", options))
    AssertEqual("compact", weapons["combat.axes"].visibility)
    AssertEqual("expanded", weapons["combat.swords"].visibility)
    AssertEqual("hidden", weapons["combat.defense"].visibility)
    AssertEqual("hidden", weapons["primary.mining"].visibility)
    AssertTrue(weapons["combat.axes"].logEnabled)
    AssertFalse(weapons["primary.mining"].notifyEnabled)

    local professions = Targets(STEP.ConfigActions:BuildPresetProposal("professions", options))
    AssertEqual("hidden", professions["combat.axes"].visibility)
    AssertEqual("compact", professions["primary.mining"].visibility)
    AssertEqual("compact", professions["secondary.cooking"].visibility)
    AssertTrue(professions["primary.mining"].notifyEnabled)

    local complete = Targets(STEP.ConfigActions:BuildPresetProposal("complete", options))
    AssertEqual("compact", complete["combat.axes"].visibility)
    AssertEqual("expanded", complete["combat.swords"].visibility)
    AssertEqual("hidden", complete["combat.defense"].visibility)
    AssertEqual("expanded", complete["primary.mining"].visibility)

    local empty = Targets(STEP.ConfigActions:BuildPresetProposal("empty", options))
    AssertEqual("hidden", empty["combat.axes"].visibility)
    AssertEqual("hidden", empty["secondary.cooking"].visibility)
    AssertFalse(empty["combat.axes"].logEnabled)
    AssertFalse(empty["secondary.cooking"].notifyEnabled)
end)

Test("ConfigActions analyzes and applies category batches once", function()
    InitializeStores(nil)
    STEP.EquipmentResolver.state = {}
    STEP.ConfigStore:EnsureSkill("combat.axes")
    STEP.ConfigStore:EnsureSkill("combat.swords")
    STEP.ConfigStore:SetSkill("combat.axes", "visibility", "hidden", "test")

    local proposal = STEP.ConfigActions:BuildCategoryProposal("combat", "visibility", "compact", {
        snapshot = {
            ["combat.axes"] = SnapshotSkill(10, 100),
            ["combat.swords"] = SnapshotSkill(20, 100),
            ["primary.mining"] = SnapshotSkill(30, 100),
        },
        equipment = {},
    })
    local analysis = STEP.ConfigActions:AnalyzeProposal(proposal)
    AssertEqual(2, analysis.total)
    AssertEqual(2, analysis.changed)
    AssertEqual(1, analysis.customOverwrites)

    local callbacks = 0
    STEP:RegisterCallback("CONFIG_CHANGED", nil, function(_, payload)
        callbacks = callbacks + 1
        AssertTrue(payload.batch)
    end)
    AssertTrue(STEP.ConfigActions:ApplyProposal(proposal, "test-category"))
    AssertEqual(1, callbacks)
    AssertEqual("compact", STEP.ConfigStore:GetSkill("combat.axes").visibility)
    AssertEqual("compact", STEP.ConfigStore:GetSkill("combat.swords").visibility)

    AssertNil(STEP.ConfigActions:BuildCategoryProposal("invalid", "visibility", "hidden"))
    AssertNil(STEP.ConfigActions:BuildPresetProposal("invalid"))
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

Test("ViewModel applies compact and expanded visibility without mandatory skills", function()
    InitializeStores(nil)
    local snapshot = {
        ["combat.axes"] = SnapshotSkill(10, 100),
        ["combat.swords"] = SnapshotSkill(50, 100),
        ["combat.defense"] = SnapshotSkill(100, 100),
        ["primary.mining"] = SnapshotSkill(25, 100),
    }
    local configs = {
        ["combat.axes"] = { visibility = "compact", logEnabled = true, notifyEnabled = true },
        ["combat.swords"] = { visibility = "expanded", logEnabled = true, notifyEnabled = true },
        ["combat.defense"] = { visibility = "hidden", logEnabled = false, notifyEnabled = false },
        ["primary.mining"] = { visibility = "expanded", logEnabled = false, notifyEnabled = false },
    }
    local equipment = {
        mainHand = { skillKey = "combat.swords" },
    }
    local originalConfigs = STEP.Util:DeepCopy(configs)

    local compact = STEP.ViewModel:Build({
        snapshot = snapshot,
        skillConfigs = configs,
        equipment = equipment,
        mode = "compact",
    })
    AssertEqual(1, #compact.rows)
    AssertEqual("combat.axes", compact.rows[1].skillKey)

    local autoEquipped = STEP.ViewModel:Build({
        snapshot = snapshot,
        skillConfigs = configs,
        equipment = equipment,
        mode = "compact",
        autoShowEquipped = true,
    })
    AssertEqual(2, #autoEquipped.rows)
    AssertTrue(RowsByKey(autoEquipped)["combat.swords"].isEquipped)

    local expanded = STEP.ViewModel:Build({
        snapshot = snapshot,
        skillConfigs = configs,
        equipment = equipment,
        mode = "expanded",
    })
    AssertEqual(3, #expanded.rows)
    AssertEqual(2, #expanded.sections)
    AssertEqual("combat", expanded.sections[1].key)
    AssertEqual("primary", expanded.sections[2].key)
    AssertNil(RowsByKey(expanded)["combat.defense"])
    AssertDeepEqual(originalConfigs, configs)
end)

Test("ViewModel uses base progress for colors and keeps maximum text white", function()
    InitializeStores(nil)
    local model = STEP.ViewModel:Build({
        snapshot = {
            ["combat.axes"] = SnapshotSkill(100, 100),
            ["combat.swords"] = SnapshotSkill(90, 100, 10, 5),
            ["combat.maces"] = SnapshotSkill(89, 100),
            ["combat.daggers"] = SnapshotSkill(179, 200),
            ["combat.defense"] = SnapshotSkill(0, 0),
            ["secondary.fishing"] = SnapshotSkill(325, 375, 0, 123),
        },
        skillConfigs = {
            ["combat.axes"] = { visibility = "compact" },
            ["combat.swords"] = { visibility = "compact" },
            ["combat.maces"] = { visibility = "compact" },
            ["combat.daggers"] = { visibility = "compact" },
            ["combat.defense"] = { visibility = "compact" },
            ["secondary.fishing"] = { visibility = "compact" },
        },
        equipment = {},
        mode = "compact",
    })
    local rows = RowsByKey(model)
    AssertEqual("green", rows["combat.axes"].progressState)
    AssertEqual("yellow", rows["combat.swords"].progressState)
    AssertEqual(90, rows["combat.swords"].progressPercent)
    AssertEqual("red", rows["combat.maces"].progressState)
    AssertEqual("red", rows["combat.daggers"].progressState)
    AssertEqual(89, rows["combat.daggers"].progressPercent)
    AssertEqual("neutral", rows["combat.defense"].progressState)
    AssertFalse(rows["combat.defense"].progressValid)
    AssertEqual("invalid_maximum", model.diagnostics[1].code)
    AssertEqual("red", rows["secondary.fishing"].progressState)
    AssertEqual("325", rows["secondary.fishing"].currentText)
    AssertEqual("375", rows["secondary.fishing"].maximumText)
    AssertEqual(50, rows["secondary.fishing"].missingPoints)
    AssertEqual(123, rows["secondary.fishing"].bonusTotal)
    AssertEqual(448, rows["secondary.fishing"].tooltip.effective)
    AssertEqual("+123", rows["secondary.fishing"].tooltip.bonusText)
    AssertTrue(rows["combat.axes"].maximumColor == STEP.ViewModel.COLORS.white)
    AssertTrue(rows["combat.swords"].separatorColor == STEP.ViewModel.COLORS.white)
end)

Test("ViewModel sorts within categories and never mixes their order", function()
    InitializeStores(nil)
    local snapshot = {
        ["combat.swords"] = SnapshotSkill(50, 100),
        ["combat.axes"] = SnapshotSkill(10, 100),
        ["combat.daggers"] = SnapshotSkill(100, 100),
        ["primary.mining"] = SnapshotSkill(5, 100),
    }
    local configs = {}
    for skillKey in pairs(snapshot) do
        configs[skillKey] = { visibility = "compact" }
    end

    local progress = STEP.ViewModel:Build({
        snapshot = snapshot,
        skillConfigs = configs,
        equipment = {},
        mode = "compact",
        sortMode = "progress",
    })
    AssertEqual("combat.axes", progress.rows[1].skillKey)
    AssertEqual("combat.swords", progress.rows[2].skillKey)
    AssertEqual("combat.daggers", progress.rows[3].skillKey)
    AssertEqual("primary.mining", progress.rows[4].skillKey)

    local alphabetical = STEP.ViewModel:Build({
        snapshot = snapshot,
        skillConfigs = configs,
        equipment = {},
        mode = "compact",
        sortMode = "alphabetical",
    })
    AssertEqual("combat.axes", alphabetical.rows[1].skillKey)
    AssertEqual("combat.daggers", alphabetical.rows[2].skillKey)
    AssertEqual("combat.swords", alphabetical.rows[3].skillKey)
    AssertEqual("primary.mining", alphabetical.rows[4].skillKey)
end)

Test("ViewModel builds summary, equipped slots and empty states", function()
    InitializeStores(nil)
    local options = {
        snapshot = {
            ["combat.axes"] = SnapshotSkill(100, 100),
            ["combat.swords"] = SnapshotSkill(50, 100),
        },
        skillConfigs = {
            ["combat.axes"] = { visibility = "compact" },
            ["combat.swords"] = { visibility = "compact" },
        },
        equipment = {
            mainHand = { skillKey = "combat.axes" },
            offHand = { skillKey = "combat.axes" },
        },
        mode = "compact",
    }
    local model = STEP.ViewModel:Build(options)
    local axes = RowsByKey(model)["combat.axes"]
    AssertEqual(2, model.summary.total)
    AssertEqual(1, model.summary.maxed)
    AssertEqual(1, model.summary.needsTraining)
    AssertEqual("1 skill needs training", model.headerText)
    AssertTrue(axes.isEquipped)
    AssertDeepEqual({ "mainHand", "offHand" }, axes.equippedSlots)

    options.hideMaxed = true
    local withoutMaxed = STEP.ViewModel:Build(options)
    AssertEqual(1, #withoutMaxed.rows)
    AssertEqual("combat.swords", withoutMaxed.rows[1].skillKey)

    options.skillConfigs["combat.swords"].visibility = "hidden"
    local empty = STEP.ViewModel:Build(options)
    AssertTrue(empty.empty)
    AssertEqual(0, #empty.sections)
    AssertEqual("1/1 at maximum", empty.headerText)
    AssertFalse(empty.shouldShowPanel)
    AssertEqual("all_maxed_hidden", empty.emptyReason)
end)

Test("ViewModel first-discovery defaults and localization stay deterministic", function()
    InitializeStores(nil)
    local originalGetLocale = GetLocale
    GetLocale = function() return "ptBR" end
    STEP.SkillRegistry:BuildLookup()

    local snapshot = {
        ["combat.axes"] = SnapshotSkill(10, 100),
        ["combat.swords"] = SnapshotSkill(20, 100),
        ["combat.defense"] = SnapshotSkill(30, 100),
        ["primary.mining"] = SnapshotSkill(40, 100),
    }
    local equipment = {
        mainHand = { skillKey = "combat.axes" },
    }
    local compact = STEP.ViewModel:Build({
        snapshot = snapshot,
        skillConfigs = {},
        equipment = equipment,
        mode = "compact",
    })
    AssertEqual(1, #compact.rows)
    AssertEqual("Machados 1M", compact.rows[1].name)
    AssertEqual("Machados", compact.rows[1].fullName)
    AssertEqual("Pericias de combate", compact.sections[1].label)
    AssertEqual("2 pericias precisam de treino", compact.headerText)

    local expanded = STEP.ViewModel:Build({
        snapshot = snapshot,
        skillConfigs = {},
        equipment = equipment,
        mode = "expanded",
    })
    AssertEqual(2, #expanded.rows)
    AssertNil(RowsByKey(expanded)["combat.defense"])
    AssertNil(RowsByKey(expanded)["primary.mining"])

    GetLocale = originalGetLocale
    STEP.SkillRegistry:BuildLookup()
end)

Test("ViewModel keeps compact as a subset and excludes unknown or unlearned skills", function()
    InitializeStores(nil)
    local snapshot = {
        ["combat.axes"] = SnapshotSkill(10, 100),
        ["combat.swords"] = SnapshotSkill(20, 100),
        ["combat.defense"] = SnapshotSkill(30, 100),
        ["primary.mining"] = SnapshotSkill(40, 100),
        ["unknown.skill"] = SnapshotSkill(50, 100),
    }
    snapshot["primary.mining"].learned = false
    local configs = {
        ["combat.axes"] = { visibility = "compact" },
        ["combat.swords"] = { visibility = "expanded" },
        ["combat.defense"] = { visibility = "hidden" },
        ["primary.mining"] = { visibility = "compact" },
        ["unknown.skill"] = { visibility = "compact" },
    }
    local compact = STEP.ViewModel:Build({
        snapshot = snapshot,
        skillConfigs = configs,
        equipment = {},
        mode = "compact",
    })
    local expanded = STEP.ViewModel:Build({
        snapshot = snapshot,
        skillConfigs = configs,
        equipment = {},
        mode = "expanded",
    })
    local expandedRows = RowsByKey(expanded)
    for index = 1, #compact.rows do
        AssertTrue(expandedRows[compact.rows[index].skillKey] ~= nil)
    end
    AssertEqual(1, #compact.rows)
    AssertEqual(2, #expanded.rows)
    AssertNil(expandedRows["combat.defense"])
    AssertNil(expandedRows["primary.mining"])
    AssertNil(expandedRows["unknown.skill"])
    AssertEqual(1, #expanded.sections)
end)

Test("ViewModel exposes canonical section and separator metadata", function()
    InitializeStores(nil)
    local model = STEP.ViewModel:Build({
        snapshot = {
            ["combat.axes"] = SnapshotSkill(10, 100),
            ["primary.mining"] = SnapshotSkill(20, 100),
            ["secondary.fishing"] = SnapshotSkill(30, 100),
        },
        skillConfigs = {
            ["combat.axes"] = { visibility = "compact" },
            ["primary.mining"] = { visibility = "compact" },
            ["secondary.fishing"] = { visibility = "compact" },
        },
        equipment = {},
        mode = "compact",
    })
    AssertTrue(model.showSectionHeaders)
    AssertEqual(3, #model.sections)
    AssertEqual("combat", model.sections[1].key)
    AssertEqual("primary", model.sections[2].key)
    AssertEqual("secondary", model.sections[3].key)
    AssertFalse(model.sections[1].hasSeparatorBefore)
    AssertTrue(model.sections[2].hasSeparatorBefore)
    AssertTrue(model.sections[3].hasSeparatorBefore)
    AssertEqual(model.sections[1].rows[1], model.rows[1])
    AssertEqual(model.sections[2].rows[1], model.rows[2])
    AssertEqual(model.sections[3].rows[1], model.rows[3])
end)

Test("ViewModel auto-shows only resolved equipped expanded skills", function()
    InitializeStores(nil)
    local snapshot = {
        ["combat.axes"] = SnapshotSkill(10, 100),
        ["combat.swords"] = SnapshotSkill(20, 100),
    }
    local configs = {
        ["combat.axes"] = { visibility = "hidden" },
        ["combat.swords"] = { visibility = "expanded" },
    }

    local unresolved = STEP.ViewModel:Build({
        snapshot = snapshot,
        skillConfigs = configs,
        equipment = { mainHand = { skillKey = "combat.swords", unresolved = true } },
        mode = "compact",
        autoShowEquipped = true,
    })
    AssertTrue(unresolved.empty)

    local resolved = STEP.ViewModel:Build({
        snapshot = snapshot,
        skillConfigs = configs,
        equipment = {
            mainHand = { skillKey = "combat.swords" },
            offHand = { skillKey = "combat.axes" },
        },
        mode = "compact",
        autoShowEquipped = true,
    })
    AssertEqual(1, #resolved.rows)
    AssertEqual("combat.swords", resolved.rows[1].skillKey)
    AssertNil(RowsByKey(resolved)["combat.axes"])
end)

Test("ViewModel summary is stable before mode and maxed filters", function()
    InitializeStores(nil)
    local options = {
        snapshot = {
            ["combat.axes"] = SnapshotSkill(100, 100),
            ["combat.swords"] = SnapshotSkill(50, 100),
            ["primary.mining"] = SnapshotSkill(25, 100),
        },
        skillConfigs = {
            ["combat.axes"] = { visibility = "compact" },
            ["combat.swords"] = { visibility = "expanded" },
            ["primary.mining"] = { visibility = "expanded" },
        },
        equipment = {},
        mode = "compact",
    }
    local compact = STEP.ViewModel:Build(options)
    AssertEqual(3, compact.summary.total)
    AssertEqual(1, compact.summary.maxed)
    AssertEqual(2, compact.summary.needsTraining)
    AssertEqual("2 skills need training", compact.headerText)

    options.mode = "expanded"
    options.hideMaxed = true
    local expanded = STEP.ViewModel:Build(options)
    AssertEqual(3, expanded.summary.total)
    AssertEqual(1, expanded.summary.maxed)
    AssertEqual(2, #expanded.rows)
    AssertEqual(3, expanded.counts.enabled)
    AssertEqual(3, expanded.counts.modeEligible)
    AssertEqual(2, expanded.counts.displayed)

    options.showHeaderSummary = false
    local withoutText = STEP.ViewModel:Build(options)
    AssertNil(withoutText.headerText)
    AssertEqual(2, withoutText.summary.needsTraining)
end)

Test("ViewModel transient rows override visibility and hideMaxed without duplication", function()
    InitializeStores(nil)
    local options = {
        snapshot = {
            ["combat.axes"] = SnapshotSkill(100, 100),
        },
        skillConfigs = {
            ["combat.axes"] = { visibility = "hidden" },
        },
        equipment = {},
        mode = "compact",
        hideMaxed = true,
        transient = {
            ["combat.axes"] = { kind = "max", token = 42 },
            ["unknown.skill"] = { kind = "gain", token = 99 },
        },
    }
    local transientModel = STEP.ViewModel:Build(options)
    AssertEqual(1, #transientModel.rows)
    AssertTrue(transientModel.rows[1].isTransient)
    AssertEqual("max", transientModel.rows[1].transientKind)
    AssertEqual(42, transientModel.rows[1].transientToken)
    AssertEqual("green", transientModel.rows[1].progressState)
    AssertEqual(0, transientModel.summary.total)

    options.transient = nil
    local normalModel = STEP.ViewModel:Build(options)
    AssertTrue(normalModel.empty)
    AssertEqual("no_selected_skills", normalModel.emptyReason)
end)

Test("ViewModel resolves panel state without mutating persisted expansion", function()
    InitializeStores(nil)
    local base = {
        snapshot = {
            ["combat.axes"] = SnapshotSkill(10, 100),
            ["combat.swords"] = SnapshotSkill(20, 100),
        },
        skillConfigs = {
            ["combat.axes"] = { visibility = "compact" },
            ["combat.swords"] = { visibility = "expanded" },
        },
        equipment = {},
        expanded = true,
    }
    local disabled = STEP.ViewModel:Build({
        snapshot = base.snapshot,
        skillConfigs = base.skillConfigs,
        equipment = base.equipment,
        expanded = true,
        panelShown = false,
    })
    AssertFalse(disabled.shouldShowPanel)
    AssertEqual("panel_disabled", disabled.hiddenReason)
    AssertTrue(disabled.persistedExpanded)

    local combatHidden = STEP.ViewModel:Build({
        snapshot = base.snapshot,
        skillConfigs = base.skillConfigs,
        equipment = base.equipment,
        expanded = true,
        inCombat = true,
        combatBehavior = "hide",
    })
    AssertFalse(combatHidden.shouldShowPanel)
    AssertEqual("combat_hidden", combatHidden.hiddenReason)
    AssertTrue(combatHidden.expanded)

    local combatCompact = STEP.ViewModel:Build({
        snapshot = base.snapshot,
        skillConfigs = base.skillConfigs,
        equipment = base.equipment,
        expanded = true,
        inCombat = true,
        combatBehavior = "compact",
    })
    AssertTrue(combatCompact.persistedExpanded)
    AssertFalse(combatCompact.expanded)
    AssertEqual("compact", combatCompact.combatOverride)
    AssertEqual(1, #combatCompact.rows)
end)

Test("ViewModel builds deterministically without mutating any input", function()
    InitializeStores(nil)
    local input = {
        snapshot = {
            ["combat.axes"] = SnapshotSkill(50, 100, 0, 10),
            ["combat.swords"] = SnapshotSkill(50, 100),
        },
        skillConfigs = {
            ["combat.axes"] = { visibility = "compact", logEnabled = true },
            ["combat.swords"] = { visibility = "compact", notifyEnabled = true },
        },
        equipment = {
            mainHand = { skillKey = "combat.axes" },
        },
        transient = {
            ["combat.swords"] = { kind = "gain", token = 7 },
        },
        mode = "compact",
    }
    local original = STEP.Util:DeepCopy(input)
    local first = STEP.ViewModel:Build(input)
    local second = STEP.ViewModel:Build(input)
    AssertDeepEqual(original, input)
    AssertDeepEqual(first, second)
    AssertEqual(2, #first.rows)
end)

Test("ViewModel falls back to English for enGB and unsupported locales", function()
    InitializeStores(nil)
    local originalGetLocale = GetLocale
    local function BuildForLocale(locale)
        GetLocale = function() return locale end
        STEP.SkillRegistry:BuildLookup()
        return STEP.ViewModel:Build({
            snapshot = { ["combat.axes"] = SnapshotSkill(10, 100) },
            skillConfigs = { ["combat.axes"] = { visibility = "compact" } },
            equipment = {},
            mode = "compact",
        })
    end

    local enGB = BuildForLocale("enGB")
    AssertEqual("1H Axes", enGB.rows[1].name)
    AssertEqual("Axes", enGB.rows[1].fullName)
    AssertEqual("Combat Skills", enGB.sections[1].label)
    local unsupported = BuildForLocale("deDE")
    AssertEqual("1H Axes", unsupported.rows[1].name)
    AssertEqual("1 skill needs training", unsupported.headerText)

    GetLocale = originalGetLocale
    STEP.SkillRegistry:BuildLookup()
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

Test("ActivityTracker accumulates exact attempts and never bridges reload time", function()
    InitializeTracking(nil)
    STEP.ConfigStore:EnsureSkill("primary.mining")
    AssertTrue(STEP.ConfigStore:SetSkill("primary.mining", "logEnabled", true))

    AssertTrue(STEP.ActivityTracker:BeginAttempt("primary.mining"))
    monotonicTime = monotonicTime + 4.5
    AssertTrue(STEP.ActivityTracker:FinishAttempt("primary.mining"))
    local first = STEP.ActivityTracker:Consume("primary.mining")
    AssertEqual(4.5, first.activeSeconds)
    AssertEqual(4.5, first.onlineSeconds)

    AssertTrue(STEP.ActivityTracker:BeginAttempt("primary.mining"))
    monotonicTime = monotonicTime + 2
    STEP.ActivityTracker:Checkpoint("reload")
    monotonicTime = monotonicTime + 500
    STEP.ActivityTracker.initialized = false
    AssertTrue(STEP.ActivityTracker:Initialize())
    local resumed = STEP.ActivityTracker:Consume("primary.mining")
    AssertEqual(2, resumed.activeSeconds)
    AssertEqual(2, resumed.onlineSeconds)
end)

Test("CombatTracker maps real melee and defense pulses only while in combat", function()
    InitializeTracking(nil)
    STEP.ConfigStore:EnsureSkill("combat.axes")
    STEP.ConfigStore:EnsureSkill("combat.defense")
    AssertTrue(STEP.ConfigStore:SetSkill("combat.axes", "logEnabled", true))
    AssertTrue(STEP.ConfigStore:SetSkill("combat.defense", "logEnabled", true))
    AddItem(16, 1001, 2, 0, "Axe")
    STEP.EquipmentResolver:Update("test")

    combatLogInfo = { 0, "SWING_DAMAGE", false, "Player-1", "player", 0, 0, "Creature-1" }
    STEP.CombatTracker:HandleCombatLog()
    AssertEqual(0, STEP.ActivityTracker:Consume("combat.axes").activeSeconds)

    STEP.CombatTracker:SetCombatState(true)
    STEP.CombatTracker:HandleCombatLog()
    monotonicTime = monotonicTime + 1.5
    combatLogInfo = { 0, "SWING_MISSED", false, "Creature-1", "creature", 0, 0, "Player-1" }
    STEP.CombatTracker:HandleCombatLog()
    monotonicTime = monotonicTime + 1
    local axe = STEP.ActivityTracker:Consume("combat.axes")
    monotonicTime = monotonicTime + 1
    local defense = STEP.ActivityTracker:Consume("combat.defense")
    AssertEqual(2.5, axe.activeSeconds)
    AssertEqual(2, defense.activeSeconds)
end)

Test("ProfessionTracker records validated mining attempts and HistoryStore records scanner gains", function()
    InitializeTracking(nil)
    STEP.ConfigStore:EnsureSkill("primary.mining")
    AssertTrue(STEP.ConfigStore:SetSkill("primary.mining", "logEnabled", true))
    SetSkillRows({ Skill("Mining", 20, 75) })
    AssertTrue(STEP.SkillScanner:Scan("baseline", true))

    STEP.ProfessionTracker:HandleSpellcast("UNIT_SPELLCAST_START", "player", "Cast-1", 2576)
    monotonicTime = monotonicTime + 3
    STEP.ProfessionTracker:HandleSpellcast("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 2576)
    wallTime = wallTime + 3
    SetSkillRows({ Skill("Mining", 21, 75) })
    AssertTrue(STEP.SkillScanner:Scan("mining-gain", false))

    local events = STEP.HistoryStore:GetEvents("primary.mining")
    AssertEqual(1, #events)
    AssertEqual("gain", events[1].type)
    AssertEqual(20, events[1].oldValue)
    AssertEqual(21, events[1].newValue)
    AssertEqual(3, events[1].activeSeconds)
    AssertEqual(3, events[1].onlineSeconds)
    local aggregate = STEP.HistoryStore:GetAggregate("primary.mining")
    AssertEqual(1, aggregate.gainedPoints)
    AssertEqual(3, aggregate.activeSeconds)
end)

Test("ProfessionTracker keeps Fishing active through its early success event", function()
    InitializeTracking(nil)
    STEP.ConfigStore:EnsureSkill("secondary.fishing")
    AssertTrue(STEP.ConfigStore:SetSkill("secondary.fishing", "logEnabled", true))
    local originalGetSpellInfo = GetSpellInfo
    GetSpellInfo = function(spellID)
        return spellID == 33095 and "Fishing" or nil
    end

    STEP.ProfessionTracker:HandleSpellcast("UNIT_SPELLCAST_CHANNEL_START", "player", nil, 33095)
    monotonicTime = monotonicTime + 1
    STEP.ProfessionTracker:HandleSpellcast("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-Fishing", 33095)
    monotonicTime = monotonicTime + 5
    STEP.ProfessionTracker:HandleSpellcast("UNIT_SPELLCAST_CHANNEL_STOP", "player", nil, 33095)
    local timing = STEP.ActivityTracker:Consume("secondary.fishing")
    AssertEqual(6, timing.activeSeconds)
    GetSpellInfo = originalGetSpellInfo
end)

Test("HistoryStore builds session and complete summary rows", function()
    InitializeTracking(nil)
    STEP.ConfigStore:EnsureSkill("secondary.fishing")
    AssertTrue(STEP.ConfigStore:SetSkill("secondary.fishing", "logEnabled", true))
    STEP.ActivityTracker:BeginAttempt("secondary.fishing")
    monotonicTime = monotonicTime + 4
    STEP.ActivityTracker:FinishAttempt("secondary.fishing")
    STEP.HistoryStore:RecordGain({
        skillKey = "secondary.fishing",
        current = { category = "secondary", current = 11, maximum = 75 },
        previous = { current = 10 },
        gainedPoints = 1,
    })
    local sessionRows = STEP.HistoryStore:GetSummaryRows("session")
    AssertEqual(1, #sessionRows)
    AssertEqual("secondary.fishing", sessionRows[1].skillKey)
    AssertEqual(4, sessionRows[1].activeSeconds)
    AssertEqual(10, sessionRows[1].initialValue)
    AssertEqual(11, sessionRows[1].latestValue)
    local allRows = STEP.HistoryStore:GetSummaryRows("all")
    AssertEqual(1, #allRows)
    AssertEqual(1, allRows[1].gainedPoints)
    local events = STEP.HistoryStore:GetEventsForScope("secondary.fishing", "session")
    AssertEqual(1, #events)
end)

Test("HistoryStore builds share lines and clears detailed history", function()
    InitializeTracking(nil)
    STEP.ConfigStore:EnsureSkill("secondary.fishing")
    AssertTrue(STEP.ConfigStore:SetSkill("secondary.fishing", "logEnabled", true))
    STEP.HistoryStore:RecordGain({
        skillKey = "secondary.fishing",
        current = { category = "secondary", current = 11, maximum = 75 },
        previous = { current = 10 },
        gainedPoints = 1,
    })
    local lines = STEP.HistoryStore:GetShareLines("session", "secondary.fishing")
    AssertEqual(1, #lines)
    AssertTrue(lines[1]:find("Fishing", 1, true) ~= nil)
    AssertTrue(STEP.HistoryStore:Clear())
    AssertEqual(0, #STEP.HistoryStore:GetSummaryRows("all"))
    AssertEqual(0, #STEP.HistoryStore:GetEvents())
end)

Test("HistoryWindow routes shared summaries to the selected chat destination", function()
    InitializeTracking(nil)
    STEP.ConfigStore:EnsureSkill("secondary.fishing")
    AssertTrue(STEP.ConfigStore:SetSkill("secondary.fishing", "logEnabled", true))
    STEP.HistoryStore:RecordGain({
        skillKey = "secondary.fishing",
        current = { category = "secondary", current = 11, maximum = 75 },
        previous = { current = 10 },
        gainedPoints = 1,
    })
    local sent = {}
    local originalSendChatMessage = SendChatMessage
    SendChatMessage = function(message, channel, language, target)
        sent[#sent + 1] = { message = message, channel = channel, language = language, target = target }
    end
    STEP.HistoryWindow.shareChannel = "WHISPER"
    STEP.HistoryWindow.whisperTarget = {
        GetText = function() return "Testfriend" end,
    }
    AssertTrue(STEP.HistoryWindow:Share("secondary.fishing"))
    AssertEqual(1, #sent)
    AssertEqual("WHISPER", sent[1].channel)
    AssertEqual("Testfriend", sent[1].target)
    AssertTrue(sent[1].message:find("Fishing", 1, true) ~= nil)
    STEP.HistoryWindow.shareChannel = "SAY"
    STEP.HistoryWindow.whisperTarget = nil
    SendChatMessage = originalSendChatMessage
end)

Test("HistoryWindow spaces and cancels multi-line chat sharing", function()
    InitializeTracking(nil)
    local sent = {}
    local originalSendChatMessage = SendChatMessage
    SendChatMessage = function(message, channel)
        sent[#sent + 1] = { message = message, channel = channel }
    end
    STEP.HistoryWindow:CancelShare()
    AssertTrue(STEP.HistoryWindow:SendLines({ "first", "second", "third" }, "SAY"))
    AssertEqual(1, #sent)
    AssertEqual(1, #timers)
    AssertEqual(0.40, timers[1].delay)
    timers[1].callback()
    AssertEqual(2, #sent)
    AssertEqual(2, #timers)
    STEP.HistoryWindow:CancelShare()
    timers[2].callback()
    AssertEqual(2, #sent)
    AssertFalse(STEP.HistoryWindow.shareSending)
    SendChatMessage = originalSendChatMessage
end)

Test("NotificationQueue honors global and individual participation", function()
    InitializeStores(nil)
    STEP.ConfigStore:EnsureSkill("secondary.fishing")
    AssertTrue(STEP.ConfigStore:SetSkill("secondary.fishing", "notifyEnabled", true))
    local originalEnsureFrame = STEP.NotificationQueue.EnsureFrame
    STEP.NotificationQueue.EnsureFrame = function()
        return nil
    end
    local change = {
        skillKey = "secondary.fishing",
        current = { current = 30, maximum = 75 },
        reachedMaximum = false,
    }
    AssertTrue(STEP.NotificationQueue:HandleGain(change))
    AssertEqual("secondary.fishing", STEP.NotificationQueue.queue[1].change.skillKey)
    AssertTrue(STEP.ConfigStore:Set("notifications.enabled", false))
    AssertFalse(STEP.NotificationQueue:HandleGain(change))
    AssertEqual(1, #STEP.NotificationQueue.queue)
    AssertTrue(STEP.ConfigStore:Set("notifications.enabled", true))
    change.reachedMaximum = true
    AssertTrue(STEP.NotificationQueue:HandleGain(change))
    AssertTrue(STEP.NotificationQueue.queue[2].change.reachedMaximum)
    STEP.NotificationQueue.EnsureFrame = originalEnsureFrame
end)

Test("NotificationQueue previews without requiring individual skill participation", function()
    InitializeStores(nil)
    STEP.SkillScanner.snapshot = {
        ["secondary.fishing"] = {
            learned = true,
            current = 30,
            maximum = 75,
        },
    }
    local originalEnsureFrame = STEP.NotificationQueue.EnsureFrame
    STEP.NotificationQueue.EnsureFrame = function()
        return nil
    end
    AssertTrue(STEP.NotificationQueue:Preview(false))
    AssertEqual("secondary.fishing", STEP.NotificationQueue.queue[1].change.skillKey)
    AssertFalse(STEP.NotificationQueue.queue[1].change.reachedMaximum)
    AssertTrue(STEP.NotificationQueue:Preview(true))
    AssertTrue(STEP.NotificationQueue.queue[2].change.reachedMaximum)
    AssertEqual(75, STEP.NotificationQueue.queue[2].change.current.current)
    AssertTrue(STEP.ConfigStore:Set("notifications.enabled", false))
    AssertFalse(STEP.NotificationQueue:Preview(false))
    AssertEqual(2, #STEP.NotificationQueue.queue)
    STEP.NotificationQueue.EnsureFrame = originalEnsureFrame
end)

Test("HistoryStore retains aggregate totals when detailed events are pruned", function()
    InitializeTracking(nil)
    STEP.ConfigStore:EnsureSkill("combat.axes")
    AssertTrue(STEP.ConfigStore:SetSkill("combat.axes", "logEnabled", true))
    local originalLimit = STEP.Constants.HISTORY_EVENT_LIMIT
    STEP.Constants.HISTORY_EVENT_LIMIT = 2
    for value = 1, 3 do
        STEP.ActivityTracker:BeginAttempt("combat.axes")
        monotonicTime = monotonicTime + 1
        STEP.ActivityTracker:FinishAttempt("combat.axes")
        STEP.HistoryStore:RecordGain({
            skillKey = "combat.axes",
            current = { category = "combat", current = value, maximum = 75 },
            previous = { current = value - 1 },
            gainedPoints = 1,
            reachedMaximum = false,
        })
    end
    STEP.Constants.HISTORY_EVENT_LIMIT = originalLimit
    AssertEqual(2, #STEPDB.history.events)
    AssertEqual(1, STEPDB.history.prunedEventCount)
    AssertEqual(3, STEP.HistoryStore:GetAggregate("combat.axes").gainedPoints)
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

Test("MainPanel commands persist visibility, mode, lock and reset position", function()
    InitializeStores(nil)
    AssertTrue(STEP.ConfigStore:Get("panel.shown"))
    AssertFalse(STEP.ConfigStore:Get("panel.expanded"))
    AssertFalse(STEP.ConfigStore:Get("panel.locked"))

    SlashCmdList.STEP("")
    AssertFalse(STEP.ConfigStore:Get("panel.shown"))
    SlashCmdList.STEP("show")
    AssertTrue(STEP.ConfigStore:Get("panel.shown"))
    SlashCmdList.STEP("expand")
    AssertTrue(STEP.ConfigStore:Get("panel.expanded"))
    SlashCmdList.STEP("compact")
    AssertFalse(STEP.ConfigStore:Get("panel.expanded"))
    SlashCmdList.STEP("toggle")
    AssertTrue(STEP.ConfigStore:Get("panel.expanded"))
    SlashCmdList.STEP("lock")
    AssertTrue(STEP.ConfigStore:Get("panel.locked"))

    AssertTrue(STEP.ConfigStore:Set("panel.point", "TOPLEFT"))
    AssertTrue(STEP.ConfigStore:Set("panel.relativePoint", "TOPLEFT"))
    AssertTrue(STEP.ConfigStore:Set("panel.x", 80))
    AssertTrue(STEP.ConfigStore:Set("panel.y", -40))
    SlashCmdList.STEP("reset")
    AssertEqual("CENTER", STEP.ConfigStore:Get("panel.point"))
    AssertEqual("CENTER", STEP.ConfigStore:Get("panel.relativePoint"))
    AssertEqual(0, STEP.ConfigStore:Get("panel.x"))
    AssertEqual(0, STEP.ConfigStore:Get("panel.y"))
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
