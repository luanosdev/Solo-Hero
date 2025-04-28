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

--- Formata um modificador de arquétipo específico para exibição em tooltip.
---@param key string Chave completa do modificador (ex: "health_add").
---@param value number Valor do modificador.
---@return string Modificador formatado sem o label inicial (ex: ": +10", ": +5%").
function Formatters.formatArchetypeModifierForTooltip(key, value)
    local statName, modifierType = key:match("^(.+)_([^_]+)$")
    if not statName then return ": " .. tostring(value) end -- Fallback

    local formattedValue = "?"

    if modifierType == "add" then
        -- MODIFICADO: Trata stats de "Chance" separadamente
        if string.find(statName, "Chance") then
            -- Formata como pontos percentuais adicionados, e.g., 0.30 -> +30.0%
            formattedValue = string.format("%+.1f%%", value * 100)
            formattedValue = formattedValue:gsub("%.0%%$", "%%") -- Remove .0% se for inteiro
        else
            -- Formatação padrão para outros stats 'add' (e.g., health, defense, luck)
            formattedValue = string.format("%+.2f", value)
            formattedValue = formattedValue:gsub("%.00$", "") -- Remove .00 se for inteiro
        end
    elseif modifierType == "mult" then
        -- Mantém lógica para 'mult' (exibe mudança percentual)
        local percentage = (value - 1) * 100
        formattedValue = string.format("%+.1f%%", percentage)
        formattedValue = formattedValue:gsub("%.0%%$", "%%")
        if statName == "range" or statName == "attackArea" then formattedValue = string.format("x%.1f", value) end
    else
        formattedValue = tostring(value)
    end
    -- Retorna apenas o valor formatado, precedido por ": "
    return ": " .. formattedValue
end

-- Adicionar outras funções de formatação aqui no futuro, se necessário.

return Formatters
