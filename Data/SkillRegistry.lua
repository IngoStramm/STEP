local _, STEP = ...

local Registry = {
    entries = {},
    byKey = {},
    byLocalizedName = {},
    byWeaponSubclass = {},
}
STEP.SkillRegistry = Registry

local function NormalizeName(value)
    local trimmed = STEP.Util:Trim(value)
    return type(trimmed) == "string" and trimmed:lower() or nil
end

local function Add(key, category, tracker, skillLineID, enUS, ptBR, defaultVisibility, weaponSubclassID, iconSpellID)
    local entry = {
        key = key,
        category = category,
        tracker = tracker,
        knownSkillLineID = skillLineID,
        defaultVisibility = defaultVisibility,
        weaponSubclassID = weaponSubclassID,
        icon = STEP.Constants.FALLBACK_SKILL_ICON,
        iconSpellID = iconSpellID,
        names = {
            enUS = enUS,
            ptBR = ptBR,
        },
    }

    Registry.entries[#Registry.entries + 1] = entry
    Registry.byKey[key] = entry
    if weaponSubclassID ~= nil then
        Registry.byWeaponSubclass[weaponSubclassID] = entry
    end
end

Add("combat.swords", "combat", "melee", 43, "Swords", "Espadas", "expanded", 7, 201)
Add("combat.two_handed_swords", "combat", "melee", 55, "Two-Handed Swords", "Espadas de Duas Mãos", "expanded", 8, 202)
Add("combat.axes", "combat", "melee", 44, "Axes", "Machados", "expanded", 0, 196)
Add("combat.two_handed_axes", "combat", "melee", 172, "Two-Handed Axes", "Machados de Duas Mãos", "expanded", 1, 197)
Add("combat.maces", "combat", "melee", 54, "Maces", "Maças", "expanded", 4, 198)
Add("combat.two_handed_maces", "combat", "melee", 160, "Two-Handed Maces", "Maças de Duas Mãos", "expanded", 5, 199)
Add("combat.daggers", "combat", "melee", 173, "Daggers", "Adagas", "expanded", 15, 1180)
Add("combat.fist_weapons", "combat", "melee", 473, "Fist Weapons", "Armas de punho", "expanded", 13, 15590)
Add("combat.staves", "combat", "melee", 136, "Staves", "Báculos", "expanded", 10, 227)
Add("combat.polearms", "combat", "melee", 229, "Polearms", "Armas de Haste", "expanded", 6, 200)
Add("combat.bows", "combat", "ranged", 45, "Bows", "Arcos", "expanded", 2, 264)
Add("combat.crossbows", "combat", "ranged", 226, "Crossbows", "Bestas", "expanded", 18, 5011)
Add("combat.guns", "combat", "ranged", 46, "Guns", "Armas de Fogo", "expanded", 3, 266)
Add("combat.thrown", "combat", "ranged", 176, "Thrown", "Arremesso", "expanded", 16, 2567)
Add("combat.wands", "combat", "ranged", 228, "Wands", "Varinhas", "expanded", 19, 5009)
Add("combat.defense", "combat", "defense", nil, "Defense", "Defesa", "hidden", nil, 204)
Add("combat.unarmed", "combat", "melee", nil, "Unarmed", "Desarmado", "hidden", nil, 203)

Add("primary.alchemy", "primary", "craft", 171, "Alchemy", "Alquimia", "hidden", nil, 2259)
Add("primary.blacksmithing", "primary", "craft", 164, "Blacksmithing", "Ferraria", "hidden", nil, 2018)
Add("primary.enchanting", "primary", "craft", 333, "Enchanting", "Encantamento", "hidden", nil, 7411)
Add("primary.engineering", "primary", "craft", 202, "Engineering", "Engenharia", "hidden", nil, 4036)
Add("primary.herbalism", "primary", "gather", 182, "Herbalism", "Herborismo", "hidden", nil, 2366)
Add("primary.jewelcrafting", "primary", "craft", 755, "Jewelcrafting", "Joalheria", "hidden", nil, 25229)
Add("primary.leatherworking", "primary", "craft", 165, "Leatherworking", "Couraria", "hidden", nil, 2108)
Add("primary.mining", "primary", "gather", 186, "Mining", "Mineração", "hidden", nil, 2575)
Add("primary.skinning", "primary", "gather", 393, "Skinning", "Esfolamento", "hidden", nil, 8613)
Add("primary.tailoring", "primary", "craft", 197, "Tailoring", "Alfaiataria", "hidden", nil, 3908)

Add("secondary.cooking", "secondary", "craft", 185, "Cooking", "Culinária", "hidden", nil, 2550)
Add("secondary.first_aid", "secondary", "craft", 129, "First Aid", "Primeiros Socorros", "hidden", nil, 3273)
Add("secondary.fishing", "secondary", "fishing", 356, "Fishing", "Pesca", "hidden", nil, 7620)

function Registry:BuildLookup()
    self.byLocalizedName = {}
    local locale = GetLocale and GetLocale() or "enUS"
    if locale == "enGB" then
        locale = "enUS"
    end

    self.locale = locale

    for index = 1, #self.entries do
        local entry = self.entries[index]
        local localizedName = entry.names[locale] or entry.names.enUS
        entry.localizedName = localizedName
        if entry.iconSpellID and GetSpellTexture then
            entry.icon = GetSpellTexture(entry.iconSpellID) or STEP.Constants.FALLBACK_SKILL_ICON
        else
            entry.icon = STEP.Constants.FALLBACK_SKILL_ICON
        end
        self.byLocalizedName[NormalizeName(localizedName)] = entry
        self.byLocalizedName[NormalizeName(entry.names.enUS)] = entry
    end
end

function Registry:Resolve(localizedName)
    if type(localizedName) ~= "string" then
        return nil
    end

    return self.byLocalizedName[NormalizeName(localizedName)]
end

function Registry:Get(skillKey)
    return self.byKey[skillKey]
end

function Registry:GetLocalizedName(skillKey)
    local entry = self.byKey[skillKey]
    return entry and entry.localizedName or skillKey
end

function Registry:ResolveWeaponSubclass(subclassID)
    local entry = self.byWeaponSubclass[tonumber(subclassID)]
    return entry and entry.key or nil
end

function Registry:GetIcon(skillKey)
    local entry = self.byKey[skillKey]
    return entry and entry.icon or STEP.Constants.FALLBACK_SKILL_ICON
end

function Registry:GetEntries()
    return self.entries
end

function Registry:GetByCategory(category)
    local entries = {}
    for index = 1, #self.entries do
        if self.entries[index].category == category then
            entries[#entries + 1] = self.entries[index]
        end
    end
    return entries
end
