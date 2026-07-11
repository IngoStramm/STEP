local _, STEP = ...

local Util = {}
STEP.Util = Util

function Util:Trim(value)
    if type(value) ~= "string" then
        return value
    end
    return value:match("^%s*(.-)%s*$")
end

function Util:Pack(...)
    return {
        n = select("#", ...),
        ...,
    }
end

function Util:SafeValue(value)
    local valueType = type(value)
    if valueType == "nil" then
        return "nil"
    elseif valueType == "string" then
        if #value > 60 then
            return value:sub(1, 57) .. "..."
        end
        return value
    elseif valueType == "number" or valueType == "boolean" then
        return tostring(value)
    end
    return "<" .. valueType .. ">"
end

function Util:FormatPacked(values, firstIndex, lastIndex)
    if type(values) ~= "table" then
        return ""
    end

    local first = math.max(1, firstIndex or 1)
    local last = math.min(values.n or #values, lastIndex or values.n or #values)
    local parts = {}

    for index = first, last do
        parts[#parts + 1] = tostring(index) .. "=" .. self:SafeValue(values[index])
    end

    return table.concat(parts, ", ")
end

function Util:SortedKeys(values)
    local keys = {}
    for key in pairs(values or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

function Util:CountKeys(values)
    local count = 0
    for _ in pairs(values or {}) do
        count = count + 1
    end
    return count
end

function Util:ShallowCopy(values)
    local copy = {}
    for key, value in pairs(values or {}) do
        copy[key] = value
    end
    return copy
end

function Util:DeepCopy(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}
    if seen[value] then
        return seen[value]
    end

    local copy = {}
    seen[value] = copy
    for key, child in pairs(value) do
        copy[self:DeepCopy(key, seen)] = self:DeepCopy(child, seen)
    end
    return copy
end

function Util:ApplyDefaults(target, defaults)
    if type(target) ~= "table" or type(defaults) ~= "table" then
        return target
    end

    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            self:ApplyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end

    return target
end

function Util:IsFiniteNumber(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

function Util:Clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    elseif value > maximum then
        return maximum
    end
    return value
end

function Util:MonotonicTime()
    if GetTimePreciseSec then
        return GetTimePreciseSec()
    end
    if GetTime then
        return GetTime()
    end
    return 0
end

function Util:WallTime()
    if GetServerTime then
        return GetServerTime()
    end
    if time then
        return time()
    end
    return 0
end

function STEP:GetText(key, ...)
    local locale = GetLocale and GetLocale() or "enUS"
    if locale == "enGB" then
        locale = "enUS"
    end

    local localized = self.Locales and self.Locales[locale]
    local fallback = self.Locales and self.Locales.enUS
    local text = localized and localized[key] or fallback and fallback[key] or key

    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, text, ...)
        if ok then
            return formatted
        end
    end

    return text
end
