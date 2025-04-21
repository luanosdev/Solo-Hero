--[[----------------------------------------------------------------------------
    Chain Lightning Ability
    Dispara um raio que salta entre inimigos próximos.
----------------------------------------------------------------------------]]--

local ChainLightning = {}

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
        animationDuration = 0.15, -- Duração do brilho/fade do raio
        initialSearchRadius = 400, -- Raio para encontrar o PRIMEIRO alvo
        chainSearchRadius = 400, -- Raio para encontrar os PRÓXIMOS alvos (AUMENTADO)
        widthAreaScale = 0.5, -- Quanto cada ponto de 'Area' aumenta a largura do laser
        missEffectLength = 30 -- Comprimento da linha curta ao errar
    }
}

function ChainLightning:init(playerManager)
    self.playerManager = playerManager
    self.cooldownRemaining = 0
    self.isAttacking = false
    self.attackProgress = 0
    self.chainPoints = {} -- Armazena a sequência de pontos [player, enemy1, enemy2, ...]

    -- Cores
    self.visual.preview.color = self.previewColor or {0.2, 0.8, 1, 0.2}
    self.visual.attack.color = self.attackColor or {0.5, 1, 1, 0.9}

    -- Atributos da arma
    local weapon = self.playerManager.equippedWeapon
    self.baseDamage = weapon.damage
    self.baseCooldown = weapon.cooldown
    self.baseChainCount = weapon.range -- 'range' da arma é o número de saltos
    self.baseWidth = weapon.angle -- 'angle' da arma é a largura base

    -- Largura atual (será recalculada no update)
    self.currentWidth = self.baseWidth + self.playerManager.state:getTotalArea() * self.visual.attack.widthAreaScale
end

function ChainLightning:update(dt)
    -- Atualiza cooldown
    if self.cooldownRemaining > 0 then
        self.cooldownRemaining = self.cooldownRemaining - dt
    end

    -- Recalcula largura caso bônus de Área mudem
    self.currentWidth = self.baseWidth + self.playerManager.state:getTotalArea() * self.visual.attack.widthAreaScale
    
    -- Atualiza animação/fade do ataque
    if self.isAttacking then
        self.attackProgress = self.attackProgress + (dt / self.visual.attack.animationDuration)
        if self.attackProgress >= 1 then
            self.isAttacking = false
            self.attackProgress = 0
            self.chainPoints = {} -- Limpa os pontos após a animação
        end
    end
end

-- Função auxiliar para encontrar o inimigo mais próximo DENTRO DE UM RAIO
local function findClosestEnemyInRadius(position, maxDistSq, enemies, excludedIDs)
    local closestEnemy = nil
    local minDistSq = maxDistSq

    for _, enemy in pairs(enemies) do -- Alterado id para _ pois não é mais usado nos logs internos
        -- Passo 1: Verificar se o inimigo é VÁLIDO ANTES de calcular distância
        if not enemy.isAlive then
            -- print(string.format("      -> Skipping enemy ID %s (not alive)", tostring(enemy.id))) -- [REMOVIDO]
        elseif not enemy.id then
            -- print(string.format("      -> Skipping enemy with nil ID")) -- [REMOVIDO]
        elseif excludedIDs[enemy.id] then -- USA enemy.id AQUI para a verificação de exclusão!
            -- print(string.format("      -> Skipping enemy ID %s (already hit)", tostring(enemy.id))) -- [REMOVIDO]
        else
            -- Passo 2: Apenas calcular distância e comparar se for VÁLIDO e NÃO EXCLUÍDO
            local dx = enemy.position.x - position.x
            local dy = enemy.position.y - position.y
            local distSq = dx * dx + dy * dy
            -- [REMOVIDO] Log de verificação
            -- print(string.format("      -> Checking VALID enemy ID %s at (%.1f, %.1f), distSq = %.1f (current min: %.1f)", 
            --                    tostring(enemy.id), -- Usa enemy.id aqui
            --                    enemy.position.x, enemy.position.y, distSq, minDistSq))
            
            if distSq < minDistSq then 
                -- [REMOVIDO] Log de atualização
                -- print(string.format("        --> NEW closest: ID %s (distSq %.1f < %.1f)", 
                --                     tostring(enemy.id), distSq, minDistSq))
                minDistSq = distSq
                closestEnemy = enemy
            end
        end
    end

    -- [REMOVIDO] Imprime o resultado final antes de retornar
    -- if closestEnemy then
    --     print(string.format("  << Returning closest enemy ID %s", tostring(closestEnemy.id)))
    -- else
    --     print("  << Returning nil (no valid enemy found in range)")
    -- end

    return closestEnemy
end

-- Função auxiliar SIMPLIFICADA para encontrar o primeiro inimigo atingido por um raio
-- Retorna o inimigo mais próximo do início que colide com o segmento.
local function findClosestCollisionAlongRay(startPos, angle, maxLength, collisionWidth, enemies)
    local closestEnemy = nil
    local minHitDistSq = maxLength * maxLength + 1 -- Inicia com distância maior que o máximo
    
    local dirX = math.cos(angle)
    local dirY = math.sin(angle)
    local endX = startPos.x + dirX * maxLength
    local endY = startPos.y + dirY * maxLength
    local segmentLenSq = maxLength * maxLength

    for id, enemy in pairs(enemies) do
        if enemy.isAlive and id then
            local enemyRadius = enemy.radius
            local checkRadius = enemyRadius + collisionWidth / 2 -- Raio para checagem de colisão

            -- Vetor do início do segmento até o inimigo
            local vecX = enemy.position.x - startPos.x
            local vecY = enemy.position.y - startPos.y

            -- Projeção do vetor no segmento (produto escalar)
            local projection = vecX * dirX + vecY * dirY

            -- Ponto mais próximo no RAIO INFINITO ao centro do inimigo
            local closestPointX, closestPointY
            if projection <= 0 then -- Atrás ou no ponto inicial
                closestPointX = startPos.x
                closestPointY = startPos.y
            elseif projection * projection >= segmentLenSq then -- Além do ponto final
                closestPointX = endX
                closestPointY = endY
            else -- Em algum lugar no meio do segmento
                closestPointX = startPos.x + dirX * projection
                closestPointY = startPos.y + dirY * projection
            end

            -- Distância quadrada do centro do inimigo ao ponto mais próximo no SEGMENTO
            local distSqToSegment = (enemy.position.x - closestPointX)^2 + (enemy.position.y - closestPointY)^2

            -- Verifica colisão (distância < raio de checagem)
            if distSqToSegment <= checkRadius * checkRadius then
                -- Calcula distância do *início* do segmento ao inimigo (para ordenar)
                local distSqFromStart = vecX * vecX + vecY * vecY
                if distSqFromStart < minHitDistSq then
                    minHitDistSq = distSqFromStart
                    closestEnemy = enemy
                end
            end
        end
    end
    return closestEnemy
end

-- Aceita uma tabela de argumentos
function ChainLightning:cast(args)
    args = args or {} -- Garante que args seja uma tabela
    local angle = args.angle or 0 -- Extrai o ângulo, default para 0 se não fornecido

    if self.cooldownRemaining > 0 then
        return false
    end

    local attackSpeed = self.playerManager.state:getTotalAttackSpeed()
    self.cooldownRemaining = self.baseCooldown / attackSpeed

    local totalDamage = self.playerManager.state:getTotalDamage(self.baseDamage)
    local totalChains = self.baseChainCount + self.playerManager.state:getTotalRange()
    local criticalChance = self.playerManager.state:getTotalCriticalChance()
    local criticalMultiplier = self.playerManager.state:getTotalCriticalMultiplier()
    local laserWidth = self.currentWidth

    local enemies = self.playerManager.enemyManager:getEnemies()
    local hitEnemies = {} 
    self.chainPoints = {}

    local playerPos = self.playerManager.player.position
    table.insert(self.chainPoints, {x = playerPos.x, y = playerPos.y})

    local targetsHit = 0
    local currentPos = playerPos
    local maxTargets = 1 + totalChains -- Número máximo de inimigos a atingir

    print("--- Chain Lightning Cast (Manual First Hit) ---")

    -- 1. Tenta o primeiro acerto manual
    local firstTarget = findClosestCollisionAlongRay(playerPos, angle, self.visual.attack.initialSearchRadius, laserWidth, enemies)

    if firstTarget then
        print(string.format(" Initial manual hit on target ID %s at (%.1f, %.1f)", tostring(firstTarget.id), firstTarget.position.x, firstTarget.position.y))
        targetsHit = targetsHit + 1
        local targetPos = firstTarget.position
        local targetId = firstTarget.id
        
        table.insert(self.chainPoints, {x = targetPos.x, y = targetPos.y})
        hitEnemies[targetId] = true
        currentPos = targetPos -- Prepara para encadear a partir daqui

        -- Aplica Dano ao primeiro alvo
        local isCritical = math.random() * 100 <= criticalChance
        local damageToApply = totalDamage
        if isCritical then damageToApply = math.floor(damageToApply * criticalMultiplier) end
        firstTarget:takeDamage(damageToApply, isCritical)

        -- 2. Continua com o encadeamento automático (se houver mais alvos permitidos)
        for i = 2, maxTargets do
            local searchRadius = self.visual.attack.chainSearchRadius
            local maxSearchDistSq = searchRadius * searchRadius
            print(string.format(" Chain Step %d: Searching from (%.1f, %.1f) within radius %.1f", i, currentPos.x, currentPos.y, searchRadius))
            
            local nextTarget = findClosestEnemyInRadius(currentPos, maxSearchDistSq, enemies, hitEnemies)

            if not nextTarget then
                print("  -> No further target found.")
                break 
            end

            -- Encontrou próximo alvo na cadeia
            targetsHit = targetsHit + 1
            local nextTargetPos = nextTarget.position
            local nextTargetId = nextTarget.id
            print(string.format("  -> Found chain target ID %s at (%.1f, %.1f)", tostring(nextTargetId), nextTargetPos.x, nextTargetPos.y))
            
            table.insert(self.chainPoints, {x = nextTargetPos.x, y = nextTargetPos.y})
            hitEnemies[nextTargetId] = true
            currentPos = nextTargetPos

            -- Aplica Dano
            isCritical = math.random() * 100 <= criticalChance
            damageToApply = totalDamage
            if isCritical then damageToApply = math.floor(damageToApply * criticalMultiplier) end
            nextTarget:takeDamage(damageToApply, isCritical)
        end
    else
        -- Primeiro disparo manual não acertou ninguém
        print(" Initial manual shot missed.")
        local missLength = self.visual.attack.initialSearchRadius
        local endX = playerPos.x + math.cos(angle) * missLength -- Usa a variável local 'angle'
        local endY = playerPos.y + math.sin(angle) * missLength -- Usa a variável local 'angle'
        table.insert(self.chainPoints, {x = endX, y = endY})
    end
    print("-------------------------")

    -- Inicia a animação sempre
    self.isAttacking = true
    self.attackProgress = 0

    return targetsHit > 0 -- Retorna true se acertou pelo menos 1 inimigo
end

function ChainLightning:draw()
    -- Desenho da Prévia (se ativa)
    if self.visual.preview.active then
        self:drawPreviewRadius(self.visual.preview.color)
    end

    -- Desenho do Ataque (se ativo)
    if not self.isAttacking then return end

    local alpha = self.visual.attack.color[4] * (1 - self.attackProgress)
    if alpha <= 0 then return end
    love.graphics.setColor(self.visual.attack.color[1], self.visual.attack.color[2], self.visual.attack.color[3], alpha)

    if #self.chainPoints >= 2 then
        -- Desenha a cadeia normal ou o efeito de 'miss'
        love.graphics.setLineWidth(self.currentWidth)
        love.graphics.setLineStyle("rough")

        for i = 1, #self.chainPoints - 1 do
            local p1 = self.chainPoints[i]
            local p2 = self.chainPoints[i+1]
            love.graphics.line(p1.x, p1.y, p2.x, p2.y)
        end

        love.graphics.setLineStyle("smooth")
        love.graphics.setLineWidth(1)
    end
    -- Se #chainPoints < 2 (não deveria acontecer com a nova lógica, mas por segurança)
    -- poderia desenhar um ponto ou pequeno brilho no jogador aqui.

    love.graphics.setColor(1, 1, 1, 1)
end

-- Nova função para desenhar preview
function ChainLightning:drawPreviewRadius(color)
    if not self.playerManager or not self.playerManager.player then return end
    local cx = self.playerManager.player.position.x
    local cy = self.playerManager.player.position.y
    local radius = self.visual.attack.initialSearchRadius
    love.graphics.setColor(color)
    love.graphics.circle("line", cx, cy, radius, 48)
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