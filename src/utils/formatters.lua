--- src/utils/formatters.lua
-- Módulo contendo funções utilitárias para formatação de dados.

---@class Formatters
local Formatters = {}

local statDisplayNames = {
    ["health"] = "Vida",
    ["healthMax"] = "Vida Máxima",
    ["defense"] = "Defesa",
    ["damageMultiplier"] = "Dano",
    ["moveSpeed"] = "Velocidade de Movimento",
    ["critChance"] = "Chance Crítica",
    ["criticalChance"] = "Chance Crítica",
    ["critDamage"] = "Dano Crítico",
    ["criticalDamage"] = "Dano Crítico",
    ["healthPerTick"] = "Regeneração de Vida por segundo",
    ["healthRegenDelay"] = "Redução de delay de Regeneração",
    ["multiAttackChance"] = "Ataque Múltiplo",
    ["attackSpeed"] = "Velocidade de Ataque",
    ["expBonus"] = "Bônus de Experiência",
    ["cooldownReduction"] = "Redução de Recarga de Runas",
    ["range"] = "Alcance",
    ["attackArea"] = "Área",
    ["pickupRadius"] = "Raio Coleta",
    ["healingBonus"] = "Bônus Cura",
    ["runeSlots"] = "Slots Runa",
    ["luck"] = "Sorte",
    ["strength"] = "Força",
    ["damage"] = "Dano",
    ["potionHealAmount"] = "Cura da Poção",
    ["potionFillRate"] = "Velocidade de Preenchimento de Poção",
    ["potionFlasks"] = "Frasco de Poção",
    ["dashCooldown"] = "Redução de Recarga do Dash",
    ["dashDistance"] = "Distância do Dash",
    ["dashCharges"] = "Carga de Dash",
    ["dashSpeed"] = "Velocidade de Dash",
}

local STAT_LABELS = {
    health = "Vida Máxima",
    defense = "Defesa",
    strength = "Força",
    moveSpeed = "Vel. Movimento",
    critChance = "Chance Crítico",
    critDamage = "Dano Crítico",
    healthPerTick = "Regen. Vida/s",
    healthRegenDelay = "Atraso Regen.",
    attackSpeed = "Vel. Ataque",
    multiAttackChance = "Chance Atq. Múltiplo",
    cooldownReduction = "Red. Recarga",
    range = "Alcance",
    attackArea = "Área de Efeito",
    expBonus = "Bônus EXP",
    pickupRadius = "Raio de Coleta",
    healingBonus = "Bônus de Cura",
    runeSlots = "Slots de Runa",
    luck = "Sorte",
    damageMultiplier = "Multiplicador de Dano"
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

--- Formata um número em notação compacta (ex: 1.2K, 5.0M, 3B, etc.).
--- @param num number|string O número a ser formatado.
--- @param precision number|nil Precisão opcional para casas decimais (default: 1).
--- @return string O número formatado de forma legível.
function Formatters.formatCompactNumber(num, precision)
    local absNum = math.abs(tonumber(num) or 0)
    local suffixes = {
        { value = 1e15, suffix = "Q" }, -- Quadrilhão
        { value = 1e12, suffix = "T" }, -- Trilhão
        { value = 1e9,  suffix = "B" }, -- Bilhão
        { value = 1e6,  suffix = "M" }, -- Milhão
        { value = 1e3,  suffix = "K" }  -- Milhar
    }

    for _, entry in ipairs(suffixes) do
        if absNum >= entry.value then
            local formatted = num / entry.value
            if precision then
                return string.format("%." .. precision .. "f%s", formatted, entry.suffix)
            else
                return string.format("%.0f%s", formatted, entry.suffix)
            end
        end
    end

    return tostring(num) -- Menor que 1000, mostra o número puro
end

--- Retorna um nome legível para uma chave de atributo.
---@param statKey string A chave do atributo (ex: "moveSpeed").
---@return string|nil O nome legível (ex: "Vel. Movimento") ou nil se não encontrado.
function Formatters.getStatLabel(statKey)
    return statDisplayNames[statKey]
end

--- Formata numeros inteiros em romano
---@param num number O número a ser formatado.
---@return string value O número formatado em romano.
function Formatters.formatRomanNumber(num)
    local roman = {
        [1] = "I",
        [2] = "II",
        [3] = "III",
        [4] = "IV",
        [5] = "V",
        [6] = "VI",
        [7] = "VII",
        [8] = "VIII",
        [9] = "IX",
        [10] = "X",
    }
    return roman[num]
end

return Formatters
