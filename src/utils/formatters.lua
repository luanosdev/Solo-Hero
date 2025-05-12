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

--- Formata um valor de stat para exibição geral, considerando seu tipo e o tipo do modificador.
---@param statKey string A chave do stat (ex: "critChance", "attackSpeed").
---@param value number O valor numérico do stat ou do modificador.
---@param modType string|nil O tipo do modificador ('fixed', 'percentage', 'fixed_percentage_as_fraction'), ou nil se formatando valor final.
---@return string O valor formatado com sufixos apropriados (%, x, /s, etc.).
function Formatters.formatStatValue(statKey, value, modType)
    value = value or 0

    -- Helper interno para formatar número com precisão opcional e remover .0 desnecessário
    local function format_number(num, precision, suffix)
        suffix = suffix or ""
        local numStr
        if num == math.floor(num) then
            numStr = tostring(math.floor(num))
        else
            numStr = string.format("%." .. (precision or 0) .. "f", num)
        end
        return numStr .. suffix
    end

    if modType then
        -- Formatação específica para MODIFICADORES
        if modType == "percentage" then
            return format_number(value, 0, "%")       -- Valor já é o percentual direto
        elseif modType == "fixed_percentage_as_fraction" then
            return format_number(value * 100, 0, "%") -- Converte fração para %
        elseif modType == "fixed" then
            -- Para 'fixed', a formatação depende um pouco do statKey para sufixos,
            -- mas o valor é absoluto.
            if statKey == "critDamage" then
                return format_number(value, 2, "x") -- Ex: 0.25x
            elseif statKey == "moveSpeed" then
                return format_number(value, 1, " m/s")
            elseif statKey == "healthRegenDelay" then
                return format_number(value, 1, "s")
            elseif statKey == "attackSpeed" then
                return format_number(value, 2, "/s")
            elseif statKey == "healthPerTick" then
                return format_number(value, 1, "/s")
            elseif statKey == "range" or statKey == "attackArea" then -- Se bônus fixo for tipo multiplicador para estes
                return format_number(value, 1, "x")
            elseif statKey == "health" or statKey == "defense" or statKey == "pickupRadius" or statKey == "runeSlots" then
                return format_number(value, 0) -- Inteiro
            else
                -- Fallback para 'fixed' genérico (valor com 1 casa decimal, sem .0)
                return format_number(value, 1)
            end
        end
    end

    -- Formatação padrão para valores FINAIS (modType é nil)
    if statKey == "critChance" or statKey == "multiAttackChance" or statKey == "expBonus" or statKey == "healingBonus" or statKey == "luck" then
        local displayValue = value * 100
        return string.format("%.0f%%", displayValue)
    elseif statKey == "cooldownReduction" then
        local displayValue = (1 - value) * 100 -- CDR final é 1 - valor (onde valor é o multiplicador total)
        return string.format("%.0f%%", displayValue)
    elseif statKey == "critDamage" then
        return string.format("%.0fx", value * 100) -- Ex: 1.5 para o total -> 150x
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
        -- Fallback para outros stats finais (mostra com 1 casa decimal)
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
