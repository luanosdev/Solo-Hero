---------------------------------------------------
-- 🔧 Helpers
---------------------------------------------------

--- Normaliza um ângulo para o intervalo [-π, π].
---@param angle number
---@return number
local function normalizeAngle(angle)
    return (angle + math.pi) % (2 * math.pi) - math.pi
end

--- Copia uma tabela de forma profunda.
---@param original table
---@return table
local function deepCopy(original)
    if type(original) ~= "table" then
        return original
    end
    local copy = {}
    for key, value in pairs(original) do
        if type(value) == "table" then
            copy[key] = deepCopy(value)
        else
            copy[key] = value
        end
    end
    return copy
end

--- Retorna o tamanho de uma tabela.
---@param t table
---@return number
local function table_size(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

return {
    normalizeAngle = normalizeAngle,
    deepCopy = deepCopy,
    table_size = table_size
}
