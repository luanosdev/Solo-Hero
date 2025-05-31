------------------------------------------------------------------------------
-- Chain Lightning Ability
-- Dispara um raio que salta entre inimigos próximos.
------------------------------------------------------------------------------

local ManagerRegistry = require("src.managers.manager_registry")
local TablePool = require("src.utils.table_pool")
local CombatHelpers = require("src.utils.combat_helpers")

---@class ChainLightning
local ChainLightning = {}
ChainLightning.__index = ChainLightning

-- Fator de decaimento para o alcance de salto a cada pulo
ChainLightning.JUMP_RANGE_DECAY = 0.85 -- Reduz 15% por salto

-- Configurações
ChainLightning.name = "Corrente Elétrica"
ChainLightning.description = "Um raio que atinge um inimigo e salta para outros próximos."
ChainLightning.damageType = "lightning" -- ou 'energy'
ChainLightning.visual = {
    preview = {
        active = false,
        -- Preview poderia mostrar o alcance inicial?
    },
    attack = {
        segmentDuration = 0.15, -- Quanto tempo cada segmento do raio fica visível
        thickness = 3           -- Espessura da linha do raio
        -- color será definido no :new
    }
}

--- Cria uma nova instância da habilidade ChainLightning.
---@param playerManager PlayerManager
---@param weaponInstance BaseWeapon Instância da arma (ChainLaser) que está usando esta habilidade.
function ChainLightning:new(playerManager, weaponInstance)
    local o = setmetatable({}, ChainLightning)

    o.playerManager = playerManager
    o.weaponInstance = weaponInstance
    o.cooldownRemaining = 0
    o.activeChains = {} -- Tabela para guardar informações das correntes de raios ativas (para desenho)

    -- Busca dados base da arma
    local baseData = o.weaponInstance:getBaseData()
    if not baseData then
        error(string.format("ChainLightning:new - Falha ao obter dados base para %s",
            o.weaponInstance.itemBaseId or "arma desconhecida"))
    end
    o.baseDamage = baseData and baseData.damage
    o.baseCooldown = baseData and baseData.cooldown
    o.baseRange = baseData and baseData.range
    o.baseChainCount = baseData and baseData.chainCount
    o.baseJumpRange = baseData and baseData.jumpRange
    o.baseThickness = o.visual.attack.thickness

    -- Knockback properties from weapon
    o.knockbackPower = baseData.knockbackPower or 0
    o.knockbackForce = baseData.knockbackForce or 0

    -- Define cores (usando as da arma ou padrão)
    o.visual.preview.color = o.weaponInstance.previewColor or { 0.2, 0.8, 1, 0.2 }
    o.visual.attack.color = o.weaponInstance.attackColor or { 0.5, 1, 1, 0.9 }

    -- Inicializa valores que serão atualizados no update
    o.currentPosition = { x = 0, y = 0 }
    -- currentAngle não é usado diretamente para mirar, mas pode ser útil saber a direção do jogador
    o.currentAngle = 0
    o.currentRange = o.baseRange
    o.currentThickness = o.baseThickness

    print("[ChainLightning:new] Instância criada.")
    return o
end

function ChainLightning:update(dt, angle)
    if self.cooldownRemaining > 0 then
        self.cooldownRemaining = self.cooldownRemaining - dt
    end

    if self.playerManager and self.playerManager.player and self.playerManager.player.position then
        self.currentPosition = self.playerManager.player.position
    else
        error("[ChainLightning:update] ERRO: Posição do jogador não disponível.")
    end
    self.currentAngle = angle

    local finalStats = self.playerManager:getCurrentFinalStats()
    self.currentRange = self.baseRange and finalStats.range and (self.baseRange * finalStats.range)
    self.currentThickness = self.baseThickness and finalStats.attackArea and (self.baseThickness * finalStats.attackArea)

    for i = #self.activeChains, 1, -1 do
        local chain = self.activeChains[i]
        chain.duration = chain.duration - dt
        if chain.duration <= 0 then
            table.remove(self.activeChains, i)
        end
    end
end

--- Encontra o inimigo mais próximo dentro de um raio a partir de um ponto.
--- Exclui inimigos cujos IDs estão na tabela `excludedIDs`.
---@param centerX number Posição X do centro da busca.
---@param centerY number Posição Y do centro da busca.
---@param radius number Raio máximo da busca.
---@param excludedIDs table Tabela com IDs de inimigos a serem ignorados { [id] = true }.
---@return table? Instância do inimigo encontrado ou nil.
function ChainLightning:findClosestEnemy(centerX, centerY, radius, excludedIDs)
    local enemyManager = ManagerRegistry:get("enemyManager")
    local spatialGrid = enemyManager.spatialGrid
    if not spatialGrid then
        error("ChainLightning:findClosestEnemy - spatialGrid não encontrado no enemyManager via ManagerRegistry.")
    end
    local nearbyEntities = spatialGrid:getNearbyEntities(centerX, centerY, radius, nil)

    local closestEnemy = nil
    local minDistanceSq = radius * radius + 1 -- Inicia com distância maior que o raio

    for _, enemy in ipairs(nearbyEntities) do
        if enemy and enemy.isAlive and (not excludedIDs or not excludedIDs[enemy.id]) then
            local dx = enemy.position.x - centerX
            local dy = enemy.position.y - centerY
            local distSq = dx * dx + dy * dy

            if distSq <= radius * radius and distSq < minDistanceSq then
                minDistanceSq = distSq
                closestEnemy = enemy
            end
        end
    end

    TablePool.release(nearbyEntities)
    return closestEnemy
end

--- Verifica colisão entre um segmento de linha e inimigos.
--- Retorna o inimigo mais próximo colidido ao longo do segmento a partir do início, ou nil.
---@param startX number Posição X inicial do segmento.
---@param startY number Posição Y inicial do segmento.
---@param endX number Posição X final do segmento.
---@param endY number Posição Y final do segmento.
---@param thickness number Espessura do segmento (para calcular raio de colisão).
---@param enemiesList table LISTA de inimigos a verificar (obtida do spatialGrid).
---@return table? Instância do inimigo colidido ou nil.
function ChainLightning:findCollisionOnSegment(startX, startY, endX, endY, thickness, enemiesList)
    local closestHitEnemy = nil
    local minHitDistSq = math.huge

    local segmentDirX = endX - startX
    local segmentDirY = endY - startY
    local segmentLenSq = segmentDirX * segmentDirX + segmentDirY * segmentDirY

    if segmentLenSq <= 0.0001 then
        return nil
    end
    local segmentLen = math.sqrt(segmentLenSq)
    segmentDirX = segmentDirX / segmentLen
    segmentDirY = segmentDirY / segmentLen

    -- Itera sobre a LISTA de inimigos fornecida
    for _, enemy in ipairs(enemiesList) do
        if enemy and enemy.isAlive then
            local enemyRadius = enemy.radius
            local checkRadius = enemyRadius + thickness / 2

            local vecX = enemy.position.x - startX
            local vecY = enemy.position.y - startY

            -- Projeção do vetor no segmento (produto escalar)
            local projection = vecX * segmentDirX + vecY * segmentDirY

            -- Ponto mais próximo no RAIO INFINITO ao centro do inimigo
            local closestPointX, closestPointY
            if projection <= 0 then
                closestPointX = startX
                closestPointY = startY
            elseif projection >= segmentLen then -- Ajustado para usar segmentLen diretamente
                closestPointX = endX
                closestPointY = endY
            else
                closestPointX = startX + segmentDirX * projection
                closestPointY = startY + segmentDirY * projection
            end

            local distSqToSegment = (enemy.position.x - closestPointX) ^ 2 + (enemy.position.y - closestPointY) ^ 2

            if distSqToSegment <= checkRadius * checkRadius then
                local distSqFromStart = vecX * vecX + vecY * vecY
                if distSqFromStart < minHitDistSq then
                    minHitDistSq = distSqFromStart
                    closestHitEnemy = enemy
                end
            end
        end
    end
    return closestHitEnemy
end

function ChainLightning:cast(args)
    args = args or {}
    local aimAngle = self.currentAngle -- Usa o ângulo atualizado em :update

    if self.cooldownRemaining > 0 then
        return false
    end

    local finalStats = self.playerManager:getCurrentFinalStats()

    -- Aplica o cooldown
    local totalAttackSpeed = finalStats.attackSpeed
    if not totalAttackSpeed or totalAttackSpeed <= 0 then totalAttackSpeed = 0.01 end -- Exceção

    if self.baseCooldown and totalAttackSpeed then
        self.cooldownRemaining = self.baseCooldown / totalAttackSpeed
    else
        error(string.format(
            "[ChainLightning:cast] ERRO: baseCooldown (%s) ou totalAttackSpeed (%s) é nil/inválido. Cooldown não aplicado.",
            tostring(self.baseCooldown), tostring(finalStats.attackSpeed)))
        -- Não definir cooldown ou definir um de fallback pode ser problemático, melhor falhar ou ter um cooldown padrão alto
        self.cooldownRemaining = 2 -- Cooldown de emergência para evitar spam
    end

    -- Calcula stats no momento do disparo
    local damagePerHit = finalStats.weaponDamage
    local criticalChance = finalStats.critChance
    local criticalMultiplier = finalStats.critDamage

    if damagePerHit == nil then
        error("[ChainLightning:cast] ERRO: finalStats.weaponDamage é nil. Não é possível calcular o dano.")
    end

    local playerStrength = finalStats.strength or 0 -- Força do jogador para knockback

    -- Calcula o número total de saltos permitidos
    -- Usa finalStats.range como multiplicador para o baseChainCount
    local totalAllowedJumps = self.baseChainCount and finalStats.range and
        math.floor(self.baseChainCount * finalStats.range)
    if totalAllowedJumps == nil then
        error(string.format(
            "[ChainLightning:cast] ERRO: Não foi possível calcular totalAllowedJumps. BaseChainCount: %s, FS.range: %s",
            tostring(self.baseChainCount), tostring(finalStats.range)))
        totalAllowedJumps = 0 -- Evita erro, mas o raio não saltará
    end
    print(string.format(
        "[ChainLightning:cast] Calculated totalAllowedJumps: %s (baseChainCount: %s, finalStats.range: %s)",
        tostring(totalAllowedJumps), tostring(self.baseChainCount), tostring(finalStats.range)))

    -- Busca entidades próximas ao jogador para o primeiro segmento
    local enemyManager = ManagerRegistry:get("enemyManager")
    local spatialGrid = enemyManager.spatialGrid
    if not spatialGrid then
        error("ChainLightning:cast - spatialGrid não encontrado no enemyManager via ManagerRegistry.")
    end

    local potentialFirstTargets = spatialGrid:getNearbyEntities(self.currentPosition.x, self.currentPosition.y,
        self.currentRange, nil)

    -- Tabelas que serão gerenciadas pelo TablePool
    local targetsHit = TablePool.get()
    local excludedIDs = TablePool.get()

    -- hitPositions não virá do pool pois pode ser armazenada em self.activeChains
    local hitPositions = {} -- Criada localmente

    local startPos = self.currentPosition
    if not startPos then
        error("[ChainLightning:cast] ERRO: startPos (currentPosition) é nil.")
        TablePool.release(targetsHit)
        TablePool.release(excludedIDs)
        if potentialFirstTargets then
            TablePool.release(potentialFirstTargets)
        end

        return false
    end

    -- Verifica se self.currentRange (calculado no update) é válido
    if not self.currentRange or self.currentRange <= 0 then
        error(string.format("[ChainLightning:cast] ERRO: self.currentRange inválido (%s) para o primeiro segmento.",
            tostring(self.currentRange)))
        TablePool.release(targetsHit)
        TablePool.release(excludedIDs)
        if potentialFirstTargets then
            TablePool.release(potentialFirstTargets)
        end
        return false
    end

    -- Calcula o ponto final do primeiro segmento
    local endX = startPos.x + math.cos(aimAngle) * self.currentRange
    local endY = startPos.y + math.sin(aimAngle) * self.currentRange
    table.insert(hitPositions, { x = startPos.x, y = startPos.y })

    local segmentThickness = self.currentThickness
    if not segmentThickness or segmentThickness <= 0 then
        error(string.format("[ChainLightning:cast] ERRO: segmentThickness inválido (%s) para o primeiro segmento.",
            tostring(segmentThickness)))
        segmentThickness = self.baseThickness
    end

    local firstHitEnemy = self:findCollisionOnSegment(startPos.x, startPos.y, endX, endY, segmentThickness,
        potentialFirstTargets)

    -- Libera potentialFirstTargets APÓS o uso, e antes de qualquer outro retorno ou erro que pularia a liberação no final.
    if potentialFirstTargets then
        TablePool.release(potentialFirstTargets)
        potentialFirstTargets = nil -- Define como nil para evitar dupla liberação
    end

    local startChainingFrom = nil

    if firstHitEnemy then
        Logger.debug(
            "[ChainLightning:cast] First segment HIT enemy ID: " .. tostring(firstHitEnemy.id) .. " at (%.1f, %.1f)",
            firstHitEnemy.position.x, firstHitEnemy.position.y)
        table.insert(hitPositions, { x = firstHitEnemy.position.x, y = firstHitEnemy.position.y })
        targetsHit[firstHitEnemy.id] = firstHitEnemy
        excludedIDs[firstHitEnemy.id] = true
        startChainingFrom = firstHitEnemy

        -- Lógica de Knockback para o PRIMEIRO ALVO refatorada
        if self.knockbackPower > 0 then -- A verificação de isAlive, etc., é feita pelo helper
            CombatHelpers.applyKnockback(
                firstHitEnemy,          -- targetEnemy
                startPos,               -- attackerPosition (jogador)
                self.knockbackPower,    -- attackKnockbackPower
                self.knockbackForce,    -- attackKnockbackForce
                playerStrength,         -- playerStrength
                nil                     -- knockbackDirectionOverride
            )
            -- Não precisamos mais do enemiesKnockedBackInThisCast para ChainLightning,
            -- pois cada inimigo só é atingido uma vez pela corrente.
        end
    else
        Logger.debug("[ChainLightning:cast] First segment MISSED. Endpoint: (%.1f, %.1f)", endX, endY)
        table.insert(hitPositions, { x = endX, y = endY })
    end

    local currentTarget = startChainingFrom
    local successfulJumps = 0
    Logger.debug("[ChainLightning:cast]",
        string.format(" Starting chain loop. StartChainingFrom is %s. TotalAllowedJumps: %d",
            tostring(startChainingFrom and startChainingFrom.id), totalAllowedJumps))

    while currentTarget and successfulJumps < totalAllowedJumps do
        local lastHitPosition = currentTarget.position
        Logger.debug("[ChainLightning:cast]", string.format(" Attempting Jump #%d from enemy %s at (%.1f, %.1f)",
            successfulJumps + 1, currentTarget.id, lastHitPosition.x, lastHitPosition.y))

        local decayedJumpRangeBase = self.baseJumpRange and
            (self.baseJumpRange * (ChainLightning.JUMP_RANGE_DECAY ^ successfulJumps))
        local currentJumpSearchRadius = decayedJumpRangeBase and finalStats.attackArea and
            (decayedJumpRangeBase * finalStats.attackArea)
        Logger.debug("[ChainLightning:cast]", string.format(
            "  - Jump params: decayedBaseJumpRange=%s, finalStats.attackArea=%s, currentJumpSearchRadius=%s",
            tostring(decayedJumpRangeBase), tostring(finalStats.attackArea), tostring(currentJumpSearchRadius)))

        if not currentJumpSearchRadius or currentJumpSearchRadius <= 0 then
            Logger.debug("[ChainLightning:cast]", string.format(
                " AVISO: Raio de salto inválido (%s) para o salto %d. Interrompendo corrente.",
                tostring(currentJumpSearchRadius), successfulJumps + 1))
            break -- Interrompe se o raio de salto for inválido
        end

        local nextTarget = self:findClosestEnemy(lastHitPosition.x, lastHitPosition.y, currentJumpSearchRadius,
            excludedIDs)

        if nextTarget then
            Logger.debug("[ChainLightning:cast]",
                string.format("  - Jump SUCCESS to enemy %s at (%.1f, %.1f)", nextTarget.id, nextTarget.position.x,
                    nextTarget.position.y))
            currentTarget = nextTarget
            table.insert(hitPositions, { x = currentTarget.position.x, y = currentTarget.position.y })
            targetsHit[currentTarget.id] = currentTarget
            excludedIDs[currentTarget.id] = true
            successfulJumps = successfulJumps + 1

            -- Lógica de Knockback refatorada para saltos subsequentes
            if self.knockbackPower > 0 then
                CombatHelpers.applyKnockback(
                    currentTarget,       -- targetEnemy
                    lastHitPosition,     -- attackerPosition (inimigo anterior)
                    self.knockbackPower, -- attackKnockbackPower
                    self.knockbackForce, -- attackKnockbackForce
                    playerStrength,      -- playerStrength
                    nil                  -- knockbackDirectionOverride
                )
            end
        else
            Logger.debug("[ChainLightning:cast]",
                "  - Jump FAILED: No next target found within jump radius or not excluded.")
            break
        end
    end

    for id, enemy in pairs(targetsHit) do
        local isCritical = criticalChance and (math.random() <= criticalChance)
        local finalDamage = damagePerHit
        if isCritical then
            if criticalMultiplier then
                finalDamage = math.floor(finalDamage * criticalMultiplier)
            else
                Logger.debug("[ChainLightning:cast]", "AVISO: Acerto crítico, mas finalStats.critMultiplier é nil.")
            end
        end
        self:applyDamage(enemy, isCritical, finalStats)
    end

    if #hitPositions > 1 then
        table.insert(self.activeChains, {
            points = hitPositions,
            duration = self.visual.attack.segmentDuration,
            color = self.visual.attack.color,
            thickness = segmentThickness
        })
    end

    TablePool.release(targetsHit)
    TablePool.release(excludedIDs)

    return true
end

function ChainLightning:draw()
    -- Desenha a prévia (agora uma linha de range inicial)
    if self.visual.preview.active then
        self:drawPreviewLine(self.visual.preview.color)
        -- Poderia desenhar um círculo menor para o jumpRange também
    end

    -- Desenha as correntes de raios ativas
    for _, chain in ipairs(self.activeChains) do
        love.graphics.setColor(chain.color)
        love.graphics.setLineWidth(chain.thickness)
        -- Desenha linhas conectando os pontos da corrente
        for i = 1, #chain.points - 1 do
            local p1 = chain.points[i]
            local p2 = chain.points[i + 1]
            love.graphics.line(p1.x, p1.y, p2.x, p2.y)
        end
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function ChainLightning:drawPreviewLine(color)
    love.graphics.setColor(color)
    -- Desenha uma linha do jogador na direção da mira com o comprimento do range atual
    local startX, startY = self.currentPosition.x, self.currentPosition.y
    local endX = startX + math.cos(self.currentAngle) * self.currentRange
    local endY = startY + math.sin(self.currentAngle) * self.currentRange
    love.graphics.line(startX, startY, endX, endY)
end

function ChainLightning:getCooldownRemaining()
    return self.cooldownRemaining or 0
end

function ChainLightning:togglePreview()
    self.visual.preview.active = not self.visual.preview.active
end

function ChainLightning:getPreview()
    return self.visual.preview.active
end

return ChainLightning
