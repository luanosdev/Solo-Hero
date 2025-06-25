----------------------------------------------------------------------------
-- Multi Attack Calculator
-- Sistema unificado para calcular múltiplos ataques de forma otimizada.
-- Centraliza toda a lógica de multi-attack para melhor performance e consistência.
----------------------------------------------------------------------------

---@class MultiAttackCalculator
local MultiAttackCalculator = {}

-- Cache de cálculos para evitar recomputação no mesmo frame
local calculationCache = {}
local lastCacheFrame = 0

---@class MultiAttackResult
---@field totalAttacks number Número total de ataques
---@field extraAttacks number Ataques extras inteiros
---@field decimalChance number Chance de ataque extra decimal (0-1)
---@field hasDecimalExtra boolean Se foi sorteado o ataque extra decimal
---@field progressiveMultipliers number[] Multiplicadores progressivos para cada ataque extra

--- Calcula multi-attack básico (para a maioria das habilidades)
---@param multiAttackChance number Chance de multi-attack dos stats
---@param frameNumber number? Número do frame atual (opcional, para cache)
---@return MultiAttackResult
function MultiAttackCalculator.calculateBasic(multiAttackChance, frameNumber)
    -- Sistema de cache para evitar recálculos desnecessários
    if frameNumber and frameNumber == lastCacheFrame then
        local cached = calculationCache[multiAttackChance]
        if cached then
            return cached
        end
    end

    multiAttackChance = multiAttackChance or 0

    local extraAttacks = math.floor(multiAttackChance)
    local decimalChance = multiAttackChance - extraAttacks
    local hasDecimalExtra = decimalChance > 0 and math.random() < decimalChance

    local result = {
        totalAttacks = 1 + extraAttacks + (hasDecimalExtra and 1 or 0),
        extraAttacks = extraAttacks,
        decimalChance = decimalChance,
        hasDecimalExtra = hasDecimalExtra
    }

    -- Cache result se frameNumber fornecido
    if frameNumber then
        if frameNumber ~= lastCacheFrame then
            calculationCache = {} -- Limpa cache de frame anterior
            lastCacheFrame = frameNumber
        end
        calculationCache[multiAttackChance] = result
    end

    return result
end

--- Calcula multi-attack para projéteis (considera projéteis base)
---@param baseProjectiles number Número base de projéteis da arma
---@param multiAttackChance number Chance de multi-attack dos stats
---@param frameNumber number? Número do frame atual (opcional)
---@return MultiAttackResult
function MultiAttackCalculator.calculateProjectiles(baseProjectiles, multiAttackChance, frameNumber)
    local basic = MultiAttackCalculator.calculateBasic(multiAttackChance, frameNumber)

    return {
        totalAttacks = baseProjectiles + basic.extraAttacks + (basic.hasDecimalExtra and 1 or 0),
        extraAttacks = basic.extraAttacks,
        decimalChance = basic.decimalChance,
        hasDecimalExtra = basic.hasDecimalExtra,
        baseProjectiles = baseProjectiles
    }
end

--- Calcula multi-attack para correntes (Chain Lightning)
---@param baseChainCount number Número base de saltos
---@param stats FinalStats Stats finais do jogador
---@param frameNumber number? Número do frame atual (opcional)
---@return MultiAttackResult
function MultiAttackCalculator.calculateChains(baseChainCount, stats, frameNumber)
    local cacheKey = string.format(
        "chain_%d_%.2f_%.2f_%.2f",
        baseChainCount,
        stats.range,
        stats.multiAttackChance,
        stats.strength
    )

    if frameNumber and frameNumber == lastCacheFrame then
        local cached = calculationCache[cacheKey]
        if cached then
            return cached
        end
    end

    -- Pesos para os atributos que influenciam os saltos
    local RANGE_MULTIPLIER_EFFECT = 1.0
    local MULTI_ATTACK_BONUS_WEIGHT = 0.50
    local STRENGTH_BONUS_WEIGHT = 0.25

    local currentRange = stats.range or 1
    local currentMultiAttack = stats.multiAttackChance or 1
    local currentStrength = stats.strength or 1

    -- Calcula saltos potenciais
    local baseJumpsAfterRange = baseChainCount * (currentRange * RANGE_MULTIPLIER_EFFECT)

    local multiAttackBonusJumps = 0
    if currentMultiAttack > 1 then
        multiAttackBonusJumps = (currentMultiAttack - 1) * baseChainCount * MULTI_ATTACK_BONUS_WEIGHT
    end

    local strengthBonusJumps = 0
    if currentStrength > 1 then
        strengthBonusJumps = (currentStrength - 1) * baseChainCount * STRENGTH_BONUS_WEIGHT
    end

    local rawPotentialJumps = baseJumpsAfterRange + multiAttackBonusJumps + strengthBonusJumps

    local guaranteedJumps = math.floor(rawPotentialJumps)
    local additionalJumpChance = rawPotentialJumps - guaranteedJumps
    local hasDecimalExtra = additionalJumpChance > 0 and math.random() < additionalJumpChance

    local result = {
        totalAttacks = guaranteedJumps + (hasDecimalExtra and 1 or 0),
        extraAttacks = guaranteedJumps,
        decimalChance = additionalJumpChance,
        hasDecimalExtra = hasDecimalExtra,
        rawPotential = rawPotentialJumps
    }

    -- Cache result
    if frameNumber then
        if frameNumber ~= lastCacheFrame then
            calculationCache = {}
            lastCacheFrame = frameNumber
        end
        calculationCache[cacheKey] = result
    end

    return result
end

--- Calcula multi-attack com área crescente (Circular Smash)
---@param multiAttackChance number Chance de multi-attack
---@param rangeMultiplier number Multiplicador de range do jogador
---@param frameNumber number? Número do frame atual (opcional)
---@return MultiAttackResult
function MultiAttackCalculator.calculateAreaGrowth(multiAttackChance, rangeMultiplier, frameNumber)
    local basic = MultiAttackCalculator.calculateBasic(multiAttackChance, frameNumber)

    -- Calcula multiplicadores progressivos para cada ataque extra
    local progressiveMultipliers = { 1.0 } -- Primeiro ataque sempre 1.0
    local currentMultiplier = 1.0

    for i = 1, basic.extraAttacks + (basic.hasDecimalExtra and 1 or 0) do
        currentMultiplier = currentMultiplier + 0.20
        table.insert(progressiveMultipliers, currentMultiplier * (rangeMultiplier or 1))
    end

    return {
        totalAttacks = basic.totalAttacks,
        extraAttacks = basic.extraAttacks,
        decimalChance = basic.decimalChance,
        hasDecimalExtra = basic.hasDecimalExtra,
        progressiveMultipliers = progressiveMultipliers
    }
end

--- Calcula ângulos para múltiplos projéteis (dispersão)
---@param totalProjectiles number Número total de projéteis
---@param baseAngle number Ângulo base da mira
---@param spreadAngle number Ângulo de dispersão total
---@return number[] angulos Tabela com ângulos para cada projétil
function MultiAttackCalculator.calculateProjectileAngles(totalProjectiles, baseAngle, spreadAngle)
    local angles = {}

    if totalProjectiles == 1 then
        table.insert(angles, baseAngle)
    else
        local angleStep = spreadAngle / (totalProjectiles - 1)
        local startAngleOffset = -spreadAngle / 2

        for i = 0, totalProjectiles - 1 do
            table.insert(angles, baseAngle + startAngleOffset + (i * angleStep))
        end
    end

    return angles
end

--- Calcula delays escalonados para ataques extras
---@param totalAttacks number Número total de ataques
---@param baseDelay number Delay base entre ataques
---@return number[] delays Tabela com delays para cada ataque
function MultiAttackCalculator.calculateAttackDelays(totalAttacks, baseDelay)
    local delays = {}
    local currentDelay = 0

    for i = 1, totalAttacks do
        table.insert(delays, currentDelay)
        currentDelay = currentDelay + baseDelay
    end

    return delays
end

--- Limpa cache (chamado quando necessário)
function MultiAttackCalculator.clearCache()
    calculationCache = {}
    lastCacheFrame = 0
end

--- Função de debug para monitorar cache
---@return table info Informações do cache
function MultiAttackCalculator.getCacheInfo()
    local count = 0
    for _ in pairs(calculationCache) do
        count = count + 1
    end

    return {
        cacheEntries = count,
        lastFrame = lastCacheFrame
    }
end

return MultiAttackCalculator
