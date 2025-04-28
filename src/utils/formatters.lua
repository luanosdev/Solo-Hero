--- src/utils/formatters.lua
-- Módulo contendo funções utilitárias para formatação de dados.

local Formatters = {}

--- Formata o tempo em segundos para o formato MM:SS.
---@param seconds number Tempo total em segundos.
---@return string Tempo formatado como "MM:SS".
function Formatters.formatTime(seconds)
    seconds = math.max(0, math.floor(seconds or 0)) -- Garante que seja número >= 0
    local min = math.floor(seconds / 60)
    local sec = seconds % 60
    return string.format("%02d:%02d", min, sec)
end

--- Formata um valor de modificador de stat para exibição.
---@param value number O valor numérico do modificador.
---@param isMultiplier boolean True se o valor representa uma mudança percentual (ex: 0.08), false se for um valor base.
---@return string Valor formatado como "+X" ou "+X%".
function Formatters.formatModifierValue(value, isMultiplier)
    value = value or 0 -- Garante que não seja nil
    local sign = value >= 0 and "+" or ""
    if isMultiplier then
        -- Formata a mudança percentual (ex: 0.08 -> +8%)
        return string.format("%s%.0f%%", sign, value * 100)
    else
        -- Formata o valor base
        return string.format("%s%.0f", sign, value)
    end
end

-- Adicionar outras funções de formatação aqui no futuro, se necessário.

return Formatters
