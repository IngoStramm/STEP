local _, STEP = ...

local EquipmentResolver = {
    state = {},
}
STEP.EquipmentResolver = EquipmentResolver

local weaponSubclassToSkill = {}

local function MapSubclass(enumValue, fallbackValue, skillKey)
    weaponSubclassToSkill[enumValue or fallbackValue] = skillKey
end

local weaponSubclass = Enum and Enum.ItemWeaponSubclass or {}
MapSubclass(weaponSubclass.Axe1H, 0, "combat.axes")
MapSubclass(weaponSubclass.Axe2H, 1, "combat.two_handed_axes")
MapSubclass(weaponSubclass.Bows, 2, "combat.bows")
MapSubclass(weaponSubclass.Guns, 3, "combat.guns")
MapSubclass(weaponSubclass.Mace1H, 4, "combat.maces")
MapSubclass(weaponSubclass.Mace2H, 5, "combat.two_handed_maces")
MapSubclass(weaponSubclass.Polearm, 6, "combat.polearms")
MapSubclass(weaponSubclass.Sword1H, 7, "combat.swords")
MapSubclass(weaponSubclass.Sword2H, 8, "combat.two_handed_swords")
MapSubclass(weaponSubclass.Staff, 10, "combat.staves")
MapSubclass(weaponSubclass.Unarmed, 13, "combat.fist_weapons")
MapSubclass(weaponSubclass.Dagger, 15, "combat.daggers")
MapSubclass(weaponSubclass.Thrown, 16, "combat.thrown")
MapSubclass(weaponSubclass.Crossbow, 18, "combat.crossbows")
MapSubclass(weaponSubclass.Wand, 19, "combat.wands")

local slots = {
    { key = "mainHand", id = INVSLOT_MAINHAND or 16 },
    { key = "offHand", id = INVSLOT_OFFHAND or 17 },
    { key = "ranged", id = INVSLOT_RANGED or 18 },
}

local weaponClassID = Enum and Enum.ItemClass and Enum.ItemClass.Weapon or 2

local function GetInstantInfo(link)
    if C_Item and C_Item.GetItemInfoInstant then
        return C_Item.GetItemInfoInstant(link)
    end
    if GetItemInfoInstant then
        return GetItemInfoInstant(link)
    end
end

local function ResolveSlot(slot)
    local link = GetInventoryItemLink and GetInventoryItemLink("player", slot.id)
    if not link then
        return {
            slotKey = slot.key,
            slotID = slot.id,
            empty = true,
            unarmedCandidate = slot.key == "mainHand",
        }
    end

    local itemID, itemType, itemSubType, equipLocation, icon, classID, subclassID = GetInstantInfo(link)
    local skillKey
    if classID == weaponClassID then
        skillKey = weaponSubclassToSkill[subclassID]
    end

    return {
        slotKey = slot.key,
        slotID = slot.id,
        empty = false,
        link = link,
        itemID = itemID,
        itemType = itemType,
        itemSubType = itemSubType,
        equipLocation = equipLocation,
        icon = icon,
        classID = classID,
        subclassID = subclassID,
        skillKey = skillKey,
    }
end

local function Signature(state)
    local parts = {}
    for index = 1, #slots do
        local item = state[slots[index].key] or {}
        parts[#parts + 1] = table.concat({
            slots[index].key,
            tostring(item.itemID or 0),
            tostring(item.classID or 0),
            tostring(item.subclassID or 0),
            tostring(item.skillKey or "none"),
            tostring(item.unarmedCandidate == true),
        }, ":")
    end
    return table.concat(parts, "|")
end

function EquipmentResolver:Update(reason)
    local nextState = {}
    for index = 1, #slots do
        local slot = slots[index]
        nextState[slot.key] = ResolveSlot(slot)
    end

    local previousSignature = Signature(self.state)
    local nextSignature = Signature(nextState)
    self.state = nextState

    if previousSignature ~= nextSignature then
        STEP:Fire("EQUIPMENT_CHANGED", nextState, reason)
        if STEP.DebugProbe then
            STEP.DebugProbe:Record("equipment", "changed reason=" .. tostring(reason), false)
        end
    end
end

function EquipmentResolver:Get(slotKey)
    return self.state[slotKey]
end

function EquipmentResolver:GetHandSkill(isOffHand)
    local slot = self.state[isOffHand and "offHand" or "mainHand"]
    if not slot then
        return nil
    end
    if slot.skillKey then
        return slot.skillKey
    end
    if not isOffHand and slot.unarmedCandidate then
        return "combat.unarmed"
    end
    return nil
end

function EquipmentResolver:Dump()
    STEP:Print(STEP:GetText("EQUIPMENT_HEADER"))
    for index = 1, #slots do
        local slot = self.state[slots[index].key] or ResolveSlot(slots[index])
        if slot.empty then
            local suffix = slot.unarmedCandidate and "; candidate=combat.unarmed" or ""
            STEP:Print(string.format("%s[%d]: %s%s", slot.slotKey, slot.slotID, STEP:GetText("EMPTY_SLOT"), suffix))
        else
            STEP:Print(string.format(
                "%s[%d]: item=%s class=%s subclass=%s (%s) skill=%s",
                slot.slotKey,
                slot.slotID,
                tostring(slot.itemID or "?"),
                tostring(slot.classID or "?"),
                tostring(slot.subclassID or "?"),
                tostring(slot.itemSubType or "?"),
                tostring(slot.skillKey or "unresolved")
            ))
        end
    end
end
