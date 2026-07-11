local _, STEP = ...

local EquipmentResolver = {
    state = {},
}
STEP.EquipmentResolver = EquipmentResolver

local slots = {
    { key = "mainHand", id = INVSLOT_MAINHAND or 16 },
    { key = "offHand", id = INVSLOT_OFFHAND or 17 },
    { key = "ranged", id = INVSLOT_RANGED or 18 },
}

local weaponClassID = Enum and Enum.ItemClass and Enum.ItemClass.Weapon or 2

local function GetInstantInfo(item)
    if C_Item and C_Item.GetItemInfoInstant then
        return C_Item.GetItemInfoInstant(item)
    end
    if GetItemInfoInstant then
        return GetItemInfoInstant(item)
    end
end

local function ResolveSlot(slot, changedSlotID)
    local link = GetInventoryItemLink and GetInventoryItemLink("player", slot.id)
    local inventoryItemID = GetInventoryItemID and GetInventoryItemID("player", slot.id)
    local itemReference = link or inventoryItemID
    if not itemReference then
        -- Inventory queries can lag PLAYER_EQUIPMENT_CHANGED. The meaning of
        -- its boolean has varied across clients, so a changed slot is kept
        -- unresolved until the scheduled retry instead of inferring empty.
        local pendingChangedSlot = slot.id == changedSlotID
        return {
            slotKey = slot.key,
            slotID = slot.id,
            empty = not pendingChangedSlot,
            unresolved = pendingChangedSlot,
            pendingItemData = pendingChangedSlot,
            unarmedCandidate = not pendingChangedSlot and slot.key == "mainHand",
        }
    end

    local itemID, itemType, itemSubType, equipLocation, icon, classID, subclassID = GetInstantInfo(itemReference)
    itemID = itemID or inventoryItemID
    if not classID or subclassID == nil then
        return {
            slotKey = slot.key,
            slotID = slot.id,
            empty = false,
            unresolved = true,
            link = link,
            itemID = itemID,
        }
    end

    local skillKey
    if classID == weaponClassID and STEP.SkillRegistry then
        skillKey = STEP.SkillRegistry:ResolveWeaponSubclass(subclassID)
    end

    return {
        slotKey = slot.key,
        slotID = slot.id,
        empty = false,
        unresolved = false,
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

local function SlotSignature(item)
    item = item or {}
    return table.concat({
        tostring(item.itemID or 0),
        tostring(item.classID or 0),
        tostring(item.subclassID or 0),
        tostring(item.skillKey or "none"),
        tostring(item.empty == true),
        tostring(item.unresolved == true),
        tostring(item.unarmedCandidate == true),
    }, ":")
end

function EquipmentResolver:Update(reason, changedSlotID)
    local previousState = self.state
    local nextState = {}
    local changedSlots = {}

    for index = 1, #slots do
        local slot = slots[index]
        local nextItem = ResolveSlot(slot, changedSlotID)
        nextState[slot.key] = nextItem
        if SlotSignature(previousState[slot.key]) ~= SlotSignature(nextItem) then
            changedSlots[#changedSlots + 1] = slot.key
        end
    end

    self.state = nextState
    if #changedSlots == 0 then
        return false, nextState
    end

    STEP:Fire("EQUIPMENT_CHANGED", {
        previous = previousState,
        current = nextState,
        changedSlots = changedSlots,
        reason = reason,
    })
    if STEP.DebugProbe then
        STEP.DebugProbe:Record("equipment", "changed reason=" .. tostring(reason) .. " slots=" .. table.concat(changedSlots, ","), false)
    end
    return true, nextState
end

function EquipmentResolver:Get(slotKey)
    return self.state[slotKey]
end

function EquipmentResolver:GetState()
    return self.state
end

function EquipmentResolver:GetSlotSkill(slotKey)
    local slot = self.state[slotKey]
    if not slot or slot.unresolved then
        return nil
    end
    if slot.skillKey then
        return slot.skillKey
    end
    if slotKey == "mainHand" and slot.unarmedCandidate then
        return "combat.unarmed"
    end
    return nil
end

function EquipmentResolver:GetHandSkill(isOffHand)
    return self:GetSlotSkill(isOffHand and "offHand" or "mainHand")
end

function EquipmentResolver:GetRangedSkill()
    return self:GetSlotSkill("ranged")
end

function EquipmentResolver:Dump()
    STEP:Print(STEP:GetText("EQUIPMENT_HEADER"))
    for index = 1, #slots do
        local slot = self.state[slots[index].key] or ResolveSlot(slots[index])
        if slot.empty then
            local suffix = slot.unarmedCandidate and "; candidate=combat.unarmed" or ""
            STEP:Print(string.format("%s[%d]: %s%s", slot.slotKey, slot.slotID, STEP:GetText("EMPTY_SLOT"), suffix))
        elseif slot.unresolved then
            STEP:Print(string.format("%s[%d]: item=%s unresolved", slot.slotKey, slot.slotID, tostring(slot.itemID or "?")))
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
