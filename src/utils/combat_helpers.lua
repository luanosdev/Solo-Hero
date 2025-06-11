local Constants = require("src.config.constants")

---@class CombatHelpers
local CombatHelpers = {}

--- Aplica knockback a um inimigo alvo.
--- @param targetEnemy BaseEnemy O inimigo que sofrerá o knockback.
--- @param attackerPosition table Posição {x, y} da origem do ataque (jogador, centro do AoE).
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

--- Normaliza um ângulo para o intervalo [-pi, pi].
--- @param angle number Ângulo em radianos.
--- @return number Ângulo normalizado.
local function normalizeAngle(angle)
    return (angle + math.pi) % (2 * math.pi) - math.pi
end

--- Encontra inimigos em uma área circular, considerando o raio dos inimigos para uma detecção mais permissiva.
--- @param searchCenter table Posição {x, y} do centro da busca.
--- @param searchRadius number O raio do ataque.
--- @param requestingEntity table A entidade que iniciou a busca (para evitar auto-colisão, opcional).
--- @return table Uma lista (do TablePool) de inimigos atingidos.
function CombatHelpers.findEnemiesInCircularArea(searchCenter, searchRadius, requestingEntity)
    local ManagerRegistry = require("src.managers.manager_registry")
    local TablePool = require("src.utils.table_pool")
    local enemyManager = ManagerRegistry:get("enemyManager")
    local spatialGrid = enemyManager.spatialGrid
    local enemiesHit = TablePool.get()

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
            local combinedRadius = searchRadius + (enemy.radius or 0)
            if distanceSq <= (combinedRadius * combinedRadius) then
                table.insert(enemiesHit, enemy)
            end
        end
    end

    TablePool.release(nearbyEnemies)
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
    local enemiesHit = TablePool.get()

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
            local combinedRange = coneArea.range + (enemy.radius or 0)
            if distanceSq <= (combinedRange * combinedRange) then
                local pointAngle = math.atan2(dy, dx)
                local relativeAngle = normalizeAngle(pointAngle - coneArea.angle)

                -- Verificação de ângulo (poderia ser mais permissiva também, mas por agora está ok)
                if math.abs(relativeAngle) <= coneArea.halfWidth then
                    table.insert(enemiesHit, enemy)
                end
            end
        end
    end

    TablePool.release(nearbyEnemies)
    return enemiesHit
end

--- Aplica dano e knockback a uma lista de inimigos.
--- @param enemies table Lista de inimigos a serem atingidos.
--- @param finalStats table Stats finais do jogador (para dano, crítico, força).
--- @param knockbackData table Dados do knockback {power, force, attackerPosition}.
--- @param enemiesKnockedBackInThisCast table Tabela para rastrear IDs de inimigos que já sofreram knockback.
function CombatHelpers.applyHitEffects(enemies, finalStats, knockbackData, enemiesKnockedBackInThisCast)
    if not enemies or #enemies == 0 then return end

    local totalDamage = finalStats.weaponDamage
    if not totalDamage then return end

    for i = 1, #enemies do
        local enemy = enemies[i]
        if enemy and enemy.isAlive then
            -- Aplica Dano
            local isCritical = finalStats.critChance and (math.random() <= finalStats.critChance)
            local damageToApply = totalDamage
            if isCritical then
                damageToApply = totalDamage and finalStats.critDamage and math.floor(totalDamage * finalStats.critDamage) or
                    totalDamage
            end
            enemy:takeDamage(damageToApply, isCritical)

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
    local enemiesHit = TablePool.get()

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

            local combinedRange = coneArea.range + (enemy.radius or 0)
            if distanceSq <= (combinedRange * combinedRange) then
                local pointAngle = math.atan2(dy, dx)
                local relativeAngle = normalizeAngle(pointAngle - coneArea.angle)

                if checkLeft then -- Checa metade esquerda (ângulo relativo entre -halfWidth e 0)
                    if relativeAngle >= -coneArea.halfWidth and relativeAngle <= 0 then
                        table.insert(enemiesHit, enemy)
                    end
                else -- Checa metade direita (ângulo relativo entre 0 e +halfWidth)
                    if relativeAngle > 0 and relativeAngle <= coneArea.halfWidth then
                        table.insert(enemiesHit, enemy)
                    end
                end
            end
        end
    end

    TablePool.release(nearbyEnemies)
    return enemiesHit
end

return CombatHelpers
