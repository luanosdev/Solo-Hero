---@class CombatHelpers
local CombatHelpers = {
    HIT_TOLERANCE_MULTIPLIER = 1.2,
    ANGLE_TOLERANCE_MULTIPLIER = 0.15,
}

-- Cache para otimização de colisões
local collisionCache = {}
local lastCacheUpdateTime = 0
local CACHE_DURATION = 0.033 -- Cache por ~2 frames (33ms)

-- Pools especializados para diferentes tipos de busca
local circularSearchPool = {}
local coneSearchPool = {}
local lineSearchPool = {}

-- Constantes de otimização
local PI = math.pi
local PI_2 = PI * 2
local HALF_PI = PI * 0.5

--- Limpa cache se necessário (otimização)
local function updateCache()
    local currentTime = love.timer.getTime()
    if currentTime - lastCacheUpdateTime > CACHE_DURATION then
        collisionCache = {}
        lastCacheUpdateTime = currentTime
    end
end

--- Calcula o raio permissivo para um ataque com base no poder de knockback.
--- @param enemy BaseEnemy O inimigo que sofrerá o ataque.
--- @return number O raio permissivo.
function CombatHelpers.getPermissiveRadius(enemy)
    return enemy.radius * CombatHelpers.HIT_TOLERANCE_MULTIPLIER
end

--- Normaliza um ângulo para o intervalo [-pi, pi].
--- @param angle number Ângulo em radianos.
--- @return number Ângulo normalizado.
local function normalizeAngle(angle)
    return (angle + math.pi) % (2 * math.pi) - math.pi
end


--- Aplica knockback a um inimigo alvo.
--- @param targetEnemy BaseEnemy O inimigo que sofrerá o knockback.
--- @param attackerPosition table|nil Posição {x, y} da origem do ataque (jogador, centro do AoE).
--- @param attackKnockbackPower number O poder de knockback do ataque.
--- @param attackKnockbackForce number A força base de knockback do ataque.
--- @param playerStrength number A força atual do jogador.
--- @param knockbackDirectionOverride? {x: number, y: number} Vetor de direção normalizado opcional para o knockback (usado por projéteis).
--- @return boolean True se o knockback foi aplicado, false caso contrário.
function CombatHelpers.applyKnockback(
    targetEnemy,
    attackerPosition,
    attackKnockbackPower,
    attackKnockbackForce,
    playerStrength,
    knockbackDirectionOverride
)
    if not targetEnemy or not targetEnemy.isAlive or targetEnemy.isDying or not targetEnemy.knockbackResistance then
        return false
    end

    if not attackKnockbackPower or attackKnockbackPower <= 0 or targetEnemy.knockbackResistance <= 0 then
        return false
    end

    if attackKnockbackPower >= targetEnemy.knockbackResistance then
        local dirX, dirY = 0, 0

        if knockbackDirectionOverride and (knockbackDirectionOverride.x ~= 0 or knockbackDirectionOverride.y ~= 0) then
            -- Usa a direção fornecida (já deve estar normalizada)
            dirX = knockbackDirectionOverride.x
            dirY = knockbackDirectionOverride.y
        elseif attackerPosition then
            -- Calcula a direção do atacante para o alvo
            local dx = targetEnemy.position.x - attackerPosition.x
            local dy = targetEnemy.position.y - attackerPosition.y
            local distSq = dx * dx + dy * dy

            if distSq > 0 then
                local dist = math.sqrt(distSq)
                dirX = dx / dist
                dirY = dy / dist
            else
                -- Alvo e atacante na mesma posição, empurra em direção aleatória
                local randomAngle = math.random() * 2 * math.pi
                dirX = math.cos(randomAngle)
                dirY = math.sin(randomAngle)
            end
        else
            -- Não há direção de override nem posição do atacante, não pode aplicar knockback
            return false
        end

        -- Garante que playerStrength é um número
        local strength = playerStrength or 0
        local knockbackVelocityValue = (strength + attackKnockbackForce) / 1 -- Conforme a fórmula

        if knockbackVelocityValue > 0 then
            targetEnemy:applyKnockback(dirX, dirY, knockbackVelocityValue)
            return true
        end
    end

    return false
end

--- Encontra inimigos em uma área circular, considerando o raio dos inimigos para uma detecção mais permissiva.
--- @param searchCenter table Posição {x, y} do centro da busca.
--- @param searchRadius number O raio do ataque.
--- @param requestingEntity table A entidade que iniciou a busca (para evitar auto-colisão, opcional).
--- @return BaseEnemy[] Uma lista (do TablePool) de inimigos atingidos.
function CombatHelpers.findEnemiesInCircularArea(searchCenter, searchRadius, requestingEntity)
    local ManagerRegistry = require("src.managers.manager_registry")
    local TablePool = require("src.utils.table_pool")
    local enemyManager = ManagerRegistry:get("enemyManager")
    local spatialGrid = enemyManager.spatialGrid
    local enemiesHit = TablePool.getArray()

    if not searchRadius or searchRadius <= 0 then
        return enemiesHit
    end

    -- Busca inicial um pouco maior para garantir que inimigos na borda sejam considerados
    local nearbyEnemies = spatialGrid:getNearbyEntities(searchCenter.x, searchCenter.y, searchRadius, requestingEntity)

    for i = 1, #nearbyEnemies do
        local enemy = nearbyEnemies[i]
        if enemy and enemy.isAlive then
            local dx = enemy.position.x - searchCenter.x
            local dy = enemy.position.y - searchCenter.y
            local distanceSq = dx * dx + dy * dy
            -- Verificação permissiva: raio do ataque + raio do inimigo
            local combinedRadius = searchRadius + CombatHelpers.getPermissiveRadius(enemy)
            if distanceSq <= (combinedRadius * combinedRadius) then
                table.insert(enemiesHit, enemy)
            end
        end
    end

    TablePool.releaseArray(nearbyEnemies)
    return enemiesHit
end

--- Encontra inimigos em uma área de cone, considerando o raio dos inimigos.
--- @param coneArea table A área do cone {position, angle, range, halfWidth}.
--- @param requestingEntity table A entidade que iniciou a busca.
--- @return table Uma lista (do TablePool) de inimigos atingidos.
function CombatHelpers.findEnemiesInConeArea(coneArea, requestingEntity)
    local ManagerRegistry = require("src.managers.manager_registry")
    local TablePool = require("src.utils.table_pool")
    local enemyManager = ManagerRegistry:get("enemyManager")
    local spatialGrid = enemyManager.spatialGrid
    local enemiesHit = TablePool.getArray()

    if not coneArea or not coneArea.range or coneArea.range <= 0 or not coneArea.halfWidth or coneArea.halfWidth <= 0 then
        return enemiesHit
    end

    local nearbyEnemies = spatialGrid:getNearbyEntities(coneArea.position.x, coneArea.position.y, coneArea.range,
        requestingEntity)

    for i = 1, #nearbyEnemies do
        local enemy = nearbyEnemies[i]
        if enemy and enemy.isAlive then
            local dx = enemy.position.x - coneArea.position.x
            local dy = enemy.position.y - coneArea.position.y
            local distanceSq = dx * dx + dy * dy

            -- Verificação de distância permissiva
            local combinedRange = coneArea.range + CombatHelpers.getPermissiveRadius(enemy)
            if distanceSq <= (combinedRange * combinedRange) then
                local pointAngle = math.atan2(dy, dx)
                local relativeAngle = normalizeAngle(pointAngle - coneArea.angle)

                -- Verificação de ângulo (poderia ser mais permissiva também, mas por agora está ok)
                if math.abs(relativeAngle) <= (coneArea.halfWidth + CombatHelpers.ANGLE_TOLERANCE_MULTIPLIER) then
                    table.insert(enemiesHit, enemy)
                end
            end
        end
    end

    TablePool.releaseArray(nearbyEnemies)
    return enemiesHit
end

--- Encontra inimigos em uma METADE específica de uma área de cone.
--- @param coneArea table A área do cone {position, angle, range, halfWidth}.
--- @param checkLeft boolean True para verificar a metade esquerda, False para a direita.
--- @param requestingEntity table A entidade que iniciou a busca.
--- @return table Uma lista (do TablePool) de inimigos atingidos.
function CombatHelpers.findEnemiesInConeHalfArea(coneArea, checkLeft, requestingEntity)
    local ManagerRegistry = require("src.managers.manager_registry")
    local TablePool = require("src.utils.table_pool")
    local enemyManager = ManagerRegistry:get("enemyManager")
    local spatialGrid = enemyManager.spatialGrid
    local enemiesHit = TablePool.getArray()

    if not coneArea or not coneArea.range or coneArea.range <= 0 or not coneArea.halfWidth or coneArea.halfWidth <= 0 then
        return enemiesHit
    end

    local nearbyEnemies = spatialGrid:getNearbyEntities(coneArea.position.x, coneArea.position.y, coneArea.range,
        requestingEntity)

    for i = 1, #nearbyEnemies do
        local enemy = nearbyEnemies[i]
        if enemy and enemy.isAlive then
            local dx = enemy.position.x - coneArea.position.x
            local dy = enemy.position.y - coneArea.position.y
            local distanceSq = dx * dx + dy * dy

            local combinedRange = coneArea.range + CombatHelpers.getPermissiveRadius(enemy)
            if distanceSq <= (combinedRange * combinedRange) then
                local pointAngle = math.atan2(dy, dx)
                local relativeAngle = normalizeAngle(pointAngle - coneArea.angle)

                if checkLeft then -- Checa metade esquerda (ângulo relativo entre -halfWidth e 0)
                    if relativeAngle >= (-coneArea.halfWidth - CombatHelpers.ANGLE_TOLERANCE_MULTIPLIER) and relativeAngle <= 0 then
                        table.insert(enemiesHit, enemy)
                    end
                else -- Checa metade direita (ângulo relativo entre 0 e +halfWidth)
                    if relativeAngle > 0 and relativeAngle <= (coneArea.halfWidth + CombatHelpers.ANGLE_TOLERANCE_MULTIPLIER) then
                        table.insert(enemiesHit, enemy)
                    end
                end
            end
        end
    end

    TablePool.releaseArray(nearbyEnemies)
    return enemiesHit
end

--- Encontra inimigos em uma área de linha (útil para projéteis, raios, etc), considerando o raio dos inimigos.
--- @param lineArea table A área da linha {startPosition, endPosition, width}.
--- @param requestingEntity table A entidade que iniciou a busca.
--- @return table Uma lista (do TablePool) de inimigos atingidos.
function CombatHelpers.findEnemiesInLineArea(lineArea, requestingEntity)
    local ManagerRegistry = require("src.managers.manager_registry")
    local TablePool = require("src.utils.table_pool")
    local enemyManager = ManagerRegistry:get("enemyManager")
    local spatialGrid = enemyManager.spatialGrid
    local enemiesHit = TablePool.getArray()

    if not lineArea or not lineArea.startPosition or not lineArea.endPosition or not lineArea.width or lineArea.width <= 0 then
        return enemiesHit
    end

    local startPos = lineArea.startPosition
    local endPos = lineArea.endPosition
    local lineWidth = lineArea.width

    -- Calcula o comprimento da linha e a direção
    local dx = endPos.x - startPos.x
    local dy = endPos.y - startPos.y
    local lineLength = math.sqrt(dx * dx + dy * dy)

    if lineLength <= 0 then
        return enemiesHit
    end

    -- Vetor unitário da direção da linha
    local dirX = dx / lineLength
    local dirY = dy / lineLength

    -- Vetor perpendicular para cálculo da largura
    local perpX = -dirY
    local perpY = dirX

    -- Busca inimigos em área expandida ao redor da linha
    local centerX = (startPos.x + endPos.x) * 0.5
    local centerY = (startPos.y + endPos.y) * 0.5
    local searchRadius = math.max(lineLength * 0.5, lineWidth) + 100 -- Buffer adicional

    local nearbyEnemies = spatialGrid:getNearbyEntities(centerX, centerY, searchRadius, requestingEntity)

    for i = 1, #nearbyEnemies do
        local enemy = nearbyEnemies[i]
        if enemy and enemy.isAlive then
            local enemyX = enemy.position.x
            local enemyY = enemy.position.y

            -- Calcula a projeção do inimigo na linha
            local toEnemyX = enemyX - startPos.x
            local toEnemyY = enemyY - startPos.y

            -- Projeção escalar na direção da linha
            local projectionScalar = toEnemyX * dirX + toEnemyY * dirY

            -- Verifica se a projeção está dentro dos limites da linha
            if projectionScalar >= 0 and projectionScalar <= lineLength then
                -- Calcula o ponto mais próximo na linha
                local closestX = startPos.x + projectionScalar * dirX
                local closestY = startPos.y + projectionScalar * dirY

                -- Calcula a distância perpendicular à linha
                local perpDistX = enemyX - closestX
                local perpDistY = enemyY - closestY
                local perpDistance = math.sqrt(perpDistX * perpDistX + perpDistY * perpDistY)

                -- Verifica se está dentro da largura da linha (considerando raio do inimigo)
                local combinedWidth = lineWidth * 0.5 + CombatHelpers.getPermissiveRadius(enemy)
                if perpDistance <= combinedWidth then
                    table.insert(enemiesHit, enemy)
                end
            else
                -- Verifica distância das extremidades da linha se não está na projeção
                local distToStart = math.sqrt((enemyX - startPos.x) ^ 2 + (enemyY - startPos.y) ^ 2)
                local distToEnd = math.sqrt((enemyX - endPos.x) ^ 2 + (enemyY - endPos.y) ^ 2)
                local minDistToEnds = math.min(distToStart, distToEnd)

                -- Se está perto de uma das extremidades, considera como hit
                local combinedRadius = lineWidth * 0.5 + CombatHelpers.getPermissiveRadius(enemy)
                if minDistToEnds <= combinedRadius then
                    table.insert(enemiesHit, enemy)
                end
            end
        end
    end

    TablePool.releaseArray(nearbyEnemies)
    return enemiesHit
end

--- Aplica dano e knockback a uma lista de inimigos.
--- @param enemies table Lista de inimigos a serem atingidos.
--- @param finalStats table Stats finais do jogador (para dano, crítico, força).
--- @param knockbackData {power: number, force: number, attackerPosition: Vector2D } Dados do knockback.
--- @param enemiesKnockedBackInThisCast table Tabela para rastrear IDs de inimigos que já sofreram knockback.
--- @param playerManager PlayerManager Instância do PlayerManager.
--- @param weaponInstance BaseWeapon A instância da arma que desferiu o golpe.
function CombatHelpers.applyHitEffects(
    enemies,
    finalStats,
    knockbackData,
    enemiesKnockedBackInThisCast,
    playerManager,
    weaponInstance
)
    if not enemies or #enemies == 0 then return end

    -- Registra o número de inimigos atingidos para a estatística "Máx. Inimigos Atingidos"
    if playerManager and playerManager.gameStatisticsManager then
        playerManager.gameStatisticsManager:registerEnemiesHit(#enemies)
    end

    local totalDamage = finalStats.weaponDamage
    if not totalDamage then return end

    for i = 1, #enemies do
        local enemy = enemies[i]
        if enemy and enemy.isAlive then
            -- Aplica Dano com nova mecânica de Super Crítico
            local critChance = finalStats.critChance
            local critBonus = finalStats.critDamage - 1 -- Converte multiplicador para bônus

            local damageToApply, isCritical, isSuperCritical, critStacks = CombatHelpers.calculateSuperCriticalDamage(
                totalDamage,
                critChance,
                critBonus
            )

            enemy:takeDamage(damageToApply, isCritical, isSuperCritical)

            -- Registra o dano causado para as estatísticas
            if playerManager and playerManager.registerDamageDealt then
                local source = { weaponId = weaponInstance and weaponInstance.itemBaseId }
                -- Passa o novo parâmetro isSuperCritical
                playerManager:registerDamageDealt(damageToApply, isCritical, source, isSuperCritical)
            end

            -- Aplica Knockback
            if knockbackData and knockbackData.power > 0 and not enemiesKnockedBackInThisCast[enemy.id] then
                local knockbackApplied = CombatHelpers.applyKnockback(
                    enemy,
                    knockbackData.attackerPosition,
                    knockbackData.power,
                    knockbackData.force,
                    finalStats.strength,
                    nil
                )
                if knockbackApplied then
                    enemiesKnockedBackInThisCast[enemy.id] = true
                end
            end
        end
    end
end

--- FUNÇÕES OTIMIZADAS ADICIONAIS PARA MÁXIMA PERFORMANCE ---

--- Busca circular otimizada com cache
---@param center Vector2D Centro da busca
---@param radius number Raio da busca
---@param requestingEntity table Entidade que faz a busca
---@return BaseEnemy[] Lista de inimigos encontrados
function CombatHelpers.findEnemiesInCircularAreaOptimized(center, radius, requestingEntity)
    updateCache()

    local cacheKey = string.format("circle_%.1f_%.1f_%.1f", center.x, center.y, radius)
    local cached = collisionCache[cacheKey]
    if cached then
        return cached
    end

    local result = CombatHelpers.findEnemiesInCircularArea(center, radius, requestingEntity)
    collisionCache[cacheKey] = result
    return result
end

--- Busca em cone otimizada com pooling
---@param coneArea table Área do cone
---@param requestingEntity table Entidade que faz a busca
---@return BaseEnemy[] Lista de inimigos encontrados
function CombatHelpers.findEnemiesInConeAreaOptimized(coneArea, requestingEntity)
    updateCache()

    -- Usa pool específico para cones se disponível
    if #coneSearchPool > 0 then
        local pooledResult = table.remove(coneSearchPool)
        -- Limpa resultado anterior
        for i = #pooledResult, 1, -1 do
            pooledResult[i] = nil
        end

        -- Executa busca real
        local actualResult = CombatHelpers.findEnemiesInConeArea(coneArea, requestingEntity)

        -- Copia para o resultado pooled
        for i = 1, #actualResult do
            pooledResult[i] = actualResult[i]
        end

        return pooledResult
    else
        return CombatHelpers.findEnemiesInConeArea(coneArea, requestingEntity)
    end
end

--- Busca em linha otimizada com pooling
---@param lineArea table Área da linha {startPosition, endPosition, width}
---@param requestingEntity table Entidade que faz a busca
---@return BaseEnemy[] Lista de inimigos encontrados
function CombatHelpers.findEnemiesInLineAreaOptimized(lineArea, requestingEntity)
    updateCache()

    -- Usa pool específico para linhas se disponível
    if #lineSearchPool > 0 then
        local pooledResult = table.remove(lineSearchPool)
        -- Limpa resultado anterior
        for i = #pooledResult, 1, -1 do
            pooledResult[i] = nil
        end

        -- Executa busca real
        local actualResult = CombatHelpers.findEnemiesInLineArea(lineArea, requestingEntity)

        -- Copia para o resultado pooled
        for i = 1, #actualResult do
            pooledResult[i] = actualResult[i]
        end

        return pooledResult
    else
        return CombatHelpers.findEnemiesInLineArea(lineArea, requestingEntity)
    end
end

--- Aplica efeitos em lote para melhor performance
---@param attackInstances table[] Lista de ataques a serem processados
---@param finalStats table Stats finais do jogador
---@param playerManager PlayerManager Instância do PlayerManager
---@param weaponInstance BaseWeapon Instância da arma
function CombatHelpers.applyBatchHitEffects(attackInstances, finalStats, playerManager, weaponInstance)
    local allKnockedBack = {}
    local totalEnemiesHit = 0

    for i = 1, #attackInstances do
        local attack = attackInstances[i]
        if attack.enemies and #attack.enemies > 0 then
            totalEnemiesHit = totalEnemiesHit + #attack.enemies
            CombatHelpers.applyHitEffects(
                attack.enemies,
                finalStats,
                attack.knockbackData,
                allKnockedBack,
                playerManager,
                weaponInstance
            )
        end
    end

    -- Registra estatísticas em lote
    if playerManager and playerManager.gameStatisticsManager and totalEnemiesHit > 0 then
        playerManager.gameStatisticsManager:registerEnemiesHit(totalEnemiesHit)
    end
end

--- Calcula dano com mecânica de Super Crítico
--- Sistema: Final Damage = Base Damage × (1 + Crit Bonus × Crit Stacks)
---@param baseDamage number Dano base
---@param critChance number Chance de crítico (ex: 3.10 = 310%)
---@param critBonus number Bônus de crítico por stack (ex: 2.20 = 220%)
---@return number damage, boolean isCritical, boolean isSuperCritical, number critStacks
function CombatHelpers.calculateSuperCriticalDamage(baseDamage, critChance, critBonus)
    if not critChance or critChance <= 0 then
        return baseDamage, false, false, 0
    end

    -- Calcula Crit Stacks baseado na Crit Chance
    local critStacks = math.floor(critChance)
    local decimalChance = critChance - critStacks

    -- Verifica se ganha stack adicional (decimal chance)
    if decimalChance > 0 and math.random() < decimalChance then
        critStacks = critStacks + 1
    end

    -- Determina se houve crítico
    local isCritical = critStacks > 0
    local isSuperCritical = critStacks > 1

    -- Calcula dano final: Final Damage = Base Damage × (1 + Crit Bonus × Crit Stacks)
    local finalDamage = baseDamage
    if isCritical then
        local critMultiplier = 1 + (critBonus * critStacks)
        finalDamage = math.floor(baseDamage * critMultiplier)
    end

    return finalDamage, isCritical, isSuperCritical, critStacks
end

--- Calcula dano otimizado (compatibilidade - DEPRECATED)
---@param baseDamage number Dano base
---@param critChance number Chance de crítico (0-1)
---@param critMultiplier number Multiplicador de crítico
---@return number damage, boolean isCritical, boolean isSuperCritical
function CombatHelpers.calculateOptimizedDamage(baseDamage, critChance, critMultiplier)
    -- Converte para nova mecânica de Super Crítico
    local critBonus = critMultiplier - 1 -- Converte multiplicador para bônus
    local damage, isCritical, isSuperCritical = CombatHelpers.calculateSuperCriticalDamage(
        baseDamage,
        critChance,
        critBonus
    )
    return damage, isCritical, isSuperCritical
end

--- Função de debug para monitor de performance
---@return table info Informações de performance
function CombatHelpers.getPerformanceInfo()
    local cacheCount = 0
    for _ in pairs(collisionCache) do
        cacheCount = cacheCount + 1
    end

    return {
        cacheEntries = cacheCount,
        cacheAge = love.timer.getTime() - lastCacheUpdateTime,
        poolSizes = {
            circular = #circularSearchPool,
            cone = #coneSearchPool,
            line = #lineSearchPool
        }
    }
end

--- Limpa todos os pools e caches (para limpeza de memória)
function CombatHelpers.cleanup()
    collisionCache = {}
    circularSearchPool = {}
    coneSearchPool = {}
    lineSearchPool = {}
    lastCacheUpdateTime = 0
end

return CombatHelpers
