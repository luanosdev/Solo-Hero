---@class CombatGeometry
---@description Módulo de utilidades matemáticas puras para cálculos de combate.
--- Contém funções geométricas sem estado para detecção de colisão e outras lógicas de combate.
--- Este módulo não deve ter NENHUMA dependência de managers, services ou do estado do jogo.
local CombatGeometry = {
    HIT_TOLERANCE_MULTIPLIER = 1.2,
    ANGLE_TOLERANCE_MULTIPLIER = 0.15,
}

---@public Normaliza um ângulo para o intervalo [-pi, pi].
---@param angle number Ângulo em radianos.
---@return number Ângulo normalizado.
function CombatGeometry.normalizeAngle(angle)
    return (angle + math.pi) % (2 * math.pi) - math.pi
end

---@public Verifica se um ponto está dentro de uma área circular.
---@param pointPosition table Posição do ponto {x, y}.
---@param circleCenter table Posição do centro do círculo {x, y}.
---@param circleRadius number Raio do círculo.
---@return boolean
function CombatGeometry.isPointInCircle(pointPosition, circleCenter, circleRadius)
    if not circleRadius or circleRadius <= 0 then
        return false
    end
    local dx = pointPosition.x - circleCenter.x
    local dy = pointPosition.y - circleCenter.y
    local distanceSq = dx * dx + dy * dy
    return distanceSq <= (circleRadius * circleRadius)
end

---@public Verifica se um ponto está dentro de uma área de cone.
---@param pointPosition Vector2D Posição do ponto.
---@param coneOrigin Vector2D Posição da origem do cone.
---@param coneAngle number Ângulo central do cone em radianos.
---@param coneRange number Alcance (comprimento) do cone.
---@param coneHalfWidth number Metade da largura angular do cone em radianos (e.g., math.pi / 4 para um cone de 90 graus).
---@return boolean
function CombatGeometry.isPointInCone(pointPosition, coneOrigin, coneAngle, coneRange, coneHalfWidth)
    if not coneRange or coneRange <= 0 or not coneHalfWidth or coneHalfWidth <= 0 then
        return false
    end
    local dx = pointPosition.x - coneOrigin.x
    local dy = pointPosition.y - coneOrigin.y
    local distanceSq = dx * dx + dy * dy

    if distanceSq > (coneRange * coneRange) then
        return false -- Ponto está fora do alcance
    end

    local pointAngle = math.atan2(dy, dx)
    local relativeAngle = CombatGeometry.normalizeAngle(pointAngle - coneAngle)

    return math.abs(relativeAngle) <= coneHalfWidth
end

--- Verifica se um ponto está dentro de uma área de linha (cápsula/retângulo orientado).
---@param pointPosition Vector2D Posição do ponto.
---@param pointRadius number Raio do ponto (para detecção permissiva).
---@param lineStart Vector2D Posição inicial da linha.
---@param lineEnd Vector2D Posição final da linha.
---@param lineWidth number Largura da linha.
---@return boolean
function CombatGeometry.isPointInLineArea(pointPosition, pointRadius, lineStart, lineEnd, lineWidth)
    if not lineWidth or lineWidth <= 0 then return false end

    local dx = lineEnd.x - lineStart.x
    local dy = lineEnd.y - lineStart.y
    local lineLengthSq = dx * dx + dy * dy

    if lineLengthSq == 0 then
        -- A linha é um ponto, trata como uma verificação de círculo.
        return CombatGeometry.isPointInCircle(pointPosition, lineStart, lineWidth * 0.5 + pointRadius)
    end

    -- Calcula a projeção do ponto no segmento de linha
    local t = ((pointPosition.x - lineStart.x) * dx + (pointPosition.y - lineStart.y) * dy) / lineLengthSq
    t = math.max(0, math.min(1, t)) -- Clamp para o segmento de linha

    -- Ponto mais próximo no segmento de linha
    local closestPointX = lineStart.x + t * dx
    local closestPointY = lineStart.y + t * dy

    -- Distância do ponto ao ponto mais próximo na linha
    local distToLineX = pointPosition.x - closestPointX
    local distToLineY = pointPosition.y - closestPointY
    local distanceToLineSq = distToLineX * distToLineX + distToLineY * distToLineY

    local combinedWidth = lineWidth * 0.5 + pointRadius
    return distanceToLineSq <= (combinedWidth * combinedWidth)
end

---@public Calcula o dano com a mecânica de Super Crítico.
--- Final Damage = Base Damage × (1 + Crit Bonus × Crit Stacks)
---@param baseDamage number Dano base.
---@param critChance number Chance de crítico (ex: 3.10 para 310%).
---@param critBonus number Bônus de dano de crítico por acúmulo (ex: 2.20 para 220%).
---@return number damage, boolean isCritical, boolean isSuperCritical, number critStacks
function CombatGeometry.calculateSuperCriticalDamage(baseDamage, critChance, critBonus)
    if not critChance or critChance <= 0 or not critBonus then
        return baseDamage, false, false, 0
    end

    local critStacks = math.floor(critChance)
    local decimalChance = critChance - critStacks

    if decimalChance > 0 and math.random() < decimalChance then
        critStacks = critStacks + 1
    end

    local isCritical = critStacks > 0
    if not isCritical then
        return baseDamage, false, false, 0
    end

    local isSuperCritical = critStacks > 1
    local critMultiplier = 1 + (critBonus * critStacks)
    local finalDamage = math.floor(baseDamage * critMultiplier)

    return finalDamage, isCritical, isSuperCritical, critStacks
end

---@public Calcula o numero de ataques para um cast (ex: multi-ataque, projéteis).
---@param multiAttackChance number
---@return number totalAttacks
function CombatGeometry.calculateMultiAttacks(multiAttackChance)
    local extraAttacks = math.floor(multiAttackChance)
    local decimalChance = multiAttackChance - extraAttacks

    local totalAttacks = 1 + extraAttacks
    if decimalChance > 0 and math.random() < decimalChance then
        totalAttacks = totalAttacks + 1
    end

    return totalAttacks
end

return CombatGeometry
