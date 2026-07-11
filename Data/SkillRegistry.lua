local _, STEP = ...

local Registry = {
    entries = {},
    byKey = {},
    byLocalizedName = {},
}
STEP.SkillRegistry = Registry

local function Add(key, category, tracker, skillLineID, enUS, ptBR, defaultVisibility)
    local entry = {
        key = key,
        category = category,
        tracker = tracker,
        knownSkillLineID = skillLineID,
        defaultVisibility = defaultVisibility,
        names = {
            enUS = enUS,
            ptBR = ptBR,
        },
    }

    Registry.entries[#Registry.entries + 1] = entry
    Registry.byKey[key] = entry
end

Add("combat.swords", "combat", "melee", 43, "Swords", "Espadas", "expanded")
Add("combat.two_handed_swords", "combat", "melee", 55, "Two-Handed Swords", "Espadas de Duas Mãos", "expanded")
Add("combat.axes", "combat", "melee", 44, "Axes", "Machados", "expanded")
Add("combat.two_handed_axes", "combat", "melee", 172, "Two-Handed Axes", "Machados de Duas Mãos", "expanded")
Add("combat.maces", "combat", "melee", 54, "Maces", "Maças", "expanded")
Add("combat.two_handed_maces", "combat", "melee", 160, "Two-Handed Maces", "Maças de Duas Mãos", "expanded")
Add("combat.daggers", "combat", "melee", 173, "Daggers", "Adagas", "expanded")
Add("combat.fist_weapons", "combat", "melee", 473, "Fist Weapons", "Armas de punho", "expanded")
Add("combat.staves", "combat", "melee", 136, "Staves", "Báculos", "expanded")
Add("combat.polearms", "combat", "melee", 229, "Polearms", "Armas de Haste", "expanded")
Add("combat.bows", "combat", "ranged", 45, "Bows", "Arcos", "expanded")
Add("combat.crossbows", "combat", "ranged", 226, "Crossbows", "Bestas", "expanded")
Add("combat.guns", "combat", "ranged", 46, "Guns", "Armas de Fogo", "expanded")
Add("combat.thrown", "combat", "ranged", 176, "Thrown", "Arremesso", "expanded")
Add("combat.wands", "combat", "ranged", 228, "Wands", "Varinhas", "expanded")
Add("combat.defense", "combat", "defense", nil, "Defense", "Defesa", "hidden")
Add("combat.unarmed", "combat", "melee", nil, "Unarmed", "Desarmado", "hidden")

Add("primary.alchemy", "primary", "craft", 171, "Alchemy", "Alquimia", "hidden")
Add("primary.blacksmithing", "primary", "craft", 164, "Blacksmithing", "Ferraria", "hidden")
Add("primary.enchanting", "primary", "craft", 333, "Enchanting", "Encantamento", "hidden")
Add("primary.engineering", "primary", "craft", 202, "Engineering", "Engenharia", "hidden")
Add("primary.herbalism", "primary", "gather", 182, "Herbalism", "Herborismo", "hidden")
Add("primary.jewelcrafting", "primary", "craft", 755, "Jewelcrafting", "Joalheria", "hidden")
Add("primary.leatherworking", "primary", "craft", 165, "Leatherworking", "Couraria", "hidden")
Add("primary.mining", "primary", "gather", 186, "Mining", "Mineração", "hidden")
Add("primary.skinning", "primary", "gather", 393, "Skinning", "Esfolamento", "hidden")
Add("primary.tailoring", "primary", "craft", 197, "Tailoring", "Alfaiataria", "hidden")

Add("secondary.cooking", "secondary", "craft", 185, "Cooking", "Culinária", "hidden")
Add("secondary.first_aid", "secondary", "craft", 129, "First Aid", "Primeiros Socorros", "hidden")
Add("secondary.fishing", "secondary", "fishing", 356, "Fishing", "Pesca", "hidden")

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
        self.byLocalizedName[localizedName] = entry
    end
end

function Registry:Resolve(localizedName)
    if type(localizedName) ~= "string" then
        return nil
    end

    local trimmed = STEP.Util:Trim(localizedName)
    return self.byLocalizedName[trimmed]
end

function Registry:Get(skillKey)
    return self.byKey[skillKey]
end

function Registry:GetLocalizedName(skillKey)
    local entry = self.byKey[skillKey]
    return entry and entry.localizedName or skillKey
end
