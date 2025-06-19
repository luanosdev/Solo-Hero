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

--- Interpolação linear entre dois valores.
---@param a number
---@param b number
---@param t number
---@return number
local function lerp(a, b, t)
    return a * (1 - t) + b * t
end

--- Funcção para verificar se o mouse está sobre a área
--- @param area table A área para verificar com x, y, width, height
--- @return boolean
function IsMouseOver(area)
    local mx, my = love.mouse.getPosition()
    return mx >= area.x and mx <= area.x + area.width and
        my >= area.y and my <= area.y + area.height
end

--- Copia uma tabela (shallow copy).
--- @param orig table A tabela original.
--- @return table Uma nova tabela que é uma cópia da original.
function table.copy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

return {
    normalizeAngle = normalizeAngle,
    deepCopy = deepCopy,
    table_size = table_size,
    lerp = lerp
}
