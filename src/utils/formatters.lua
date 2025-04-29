--- src/utils/formatters.lua
-- Módulo contendo funções utilitárias para formatação de dados.

local Formatters = {}

local statDisplayNames = {
    ["health"] = "Vida",
    ["defense"] = "Defesa",
    ["moveSpeed"] = "Vel. Movimento",
    ["critChance"] = "Chance Crítica",
    ["critDamage"] = "Mult. Crítico",
    ["healthPerTick"] = "Regen. Vida/s",
    ["healthRegenDelay"] = "Delay Regen.",
    ["multiAttackChance"] = "Atq. Múltiplo",
    ["attackSpeed"] = "Vel. Ataque",
    ["expBonus"] = "Bônus Exp",
    ["cooldownReduction"] = "Red. Recarga",
    ["range"] = "Alcance",
    ["attackArea"] = "Área",
    ["pickupRadius"] = "Raio Coleta",
    ["healingBonus"] = "Bônus Cura",
    ["runeSlots"] = "Slots Runa",
    ["luck"] = "Sorte",
}

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

--- Formata um valor de stat para exibição geral, considerando seu tipo.
---@param statKey string A chave do stat (ex: "critChance", "attackSpeed").
---@param value number O valor numérico do stat.
---@return string O valor formatado com sufixos apropriados (%, x, /s, etc.).
function Formatters.formatValue(statKey, value)
    value = value or 0

    -- Formatação baseada na chave do stat
    if statKey == "critChance" or statKey == "multiAttackChance" or statKey == "cooldownReduction" or statKey == "expBonus" or statKey == "healingBonus" or statKey == "luck" then
        -- Stats exibidos como porcentagem
        local displayValue = value * 100
        if statKey == "cooldownReduction" then
            displayValue = (1 - value) * 100         -- Inverte para mostrar redução
        end
        return string.format("%.0f%%", displayValue) -- Arredonda para inteiro
    elseif statKey == "critDamage" then
        -- Multiplicador de crítico
        return string.format("%.0fx", value * 100) -- Ex: 1.5 -> 150x
    elseif statKey == "moveSpeed" then
        return string.format("%.1f m/s", value)
    elseif statKey == "healthPerTick" then
        return string.format("%.1f/s", value)
    elseif statKey == "healthRegenDelay" then
        return string.format("%.1fs", value)
    elseif statKey == "attackSpeed" then
        return string.format("%.2f/s", value)
    elseif statKey == "range" or statKey == "attackArea" then
        -- Stats exibidos como multiplicador
        return string.format("x%.1f", value)
    elseif statKey == "health" or statKey == "defense" or statKey == "pickupRadius" or statKey == "runeSlots" then
        -- Valores inteiros
        return string.format("%d", value)
    else
        -- Fallback para outros stats (mostra com 1 casa decimal)
        return string.format("%.1f", value)
    end
end

--- Formata um valor de stat para exibição geral, considerando seu tipo.
---@param statKey string A chave do stat (ex: "critChance", "attackSpeed").
---@param value number O valor numérico do stat.
---@return string O valor formatado com sufixos apropriados (%, x, /s, etc.).
function Formatters.formatStatValue(statKey, value)
    value = value or 0

    -- Formatação baseada na chave do stat
    if statKey == "critChance" or statKey == "multiAttackChance" or statKey == "cooldownReduction" or statKey == "expBonus" or statKey == "healingBonus" or statKey == "luck" then
        local displayValue = value * 100
        if statKey == "cooldownReduction" then displayValue = (1 - value) * 100 end
        return string.format("%.0f%%", displayValue)
    elseif statKey == "critDamage" then
        return string.format("%.0fx", value * 100)
    elseif statKey == "moveSpeed" then
        return string.format("%.1f m/s", value)
    elseif statKey == "healthPerTick" then
        return string.format("%.1f/s", value)
    elseif statKey == "healthRegenDelay" then
        return string.format("%.1fs", value)
    elseif statKey == "attackSpeed" then
        return string.format("%.2f/s", value)
    elseif statKey == "range" or statKey == "attackArea" then
        return string.format("x%.1f", value)
    elseif statKey == "health" or statKey == "defense" or statKey == "pickupRadius" or statKey == "runeSlots" then
        return string.format("%d", value)
    else
        return string.format("%.1f", value)
    end
end

--- Retorna o nome de exibição para uma chave de stat.
---@param statKey string A chave interna do stat (ex: "critChance").
---@return string O nome formatado para exibição (ex: "Chance Crítica") ou a própria chave se não encontrada.
function Formatters.getStatDisplayName(statKey)
    return statDisplayNames[statKey] or statKey -- Retorna a chave se não houver mapeamento
end

-- Adicionar outras funções de formatação aqui no futuro, se necessário.

return Formatters
