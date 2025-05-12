--[[----------------------------------------------------------------------------
    Chain Lightning Ability
    Dispara um raio que salta entre inimigos próximos.
----------------------------------------------------------------------------]] --

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
        return nil
    end
    o.baseDamage = baseData.damage
    o.baseCooldown = baseData.cooldown
    o.baseRange = baseData.range                -- Alcance para o primeiro alvo
    o.baseChainCount = baseData.chainCount      -- Número MÁXIMO de saltos adicionais
    o.baseJumpRange = baseData.jumpRange        -- Distância MÁXIMA para saltar
    o.baseThickness = o.visual.attack.thickness -- Armazena a espessura base

    -- Define cores (usando as da arma ou padrão)
    o.visual.preview.color = o.weaponInstance.previewColor or { 0.2, 0.8, 1, 0.2 }
    o.visual.attack.color = o.weaponInstance.attackColor or { 0.5, 1, 1, 0.9 }

    -- Inicializa valores que serão atualizados no update
    o.currentPosition = { x = 0, y = 0 }
    -- currentAngle não é usado diretamente para mirar, mas pode ser útil saber a direção do jogador
    o.currentAngle = 0
    o.currentRange = o.baseRange
    -- o.currentJumpRange = o.baseJumpRange -- REMOVIDO: Será calculado no cast
    o.currentThickness = o.baseThickness -- Inicializa a espessura atual

    print("[ChainLightning:new] Instância criada.")
    return o
end

function ChainLightning:update(dt, angle)
    -- Atualiza cooldown
    if self.cooldownRemaining > 0 then
        self.cooldownRemaining = self.cooldownRemaining - dt
    end

    -- Atualiza posição e ângulo
    if self.playerManager and self.playerManager.player and self.playerManager.player.position then
        self.currentPosition = self.playerManager.player.position
    else
        error("[ChainLightning:update] ERRO: Posição do jogador não disponível.")
    end
    self.currentAngle = angle

    -- Obtem stats finais do jogador
    local finalStats = self.playerManager:getCurrentFinalStats()

    -- Calcula valores FINAIS para este frame
    -- self.baseRange e self.baseThickness são definidos em :new
    -- finalStats.range e finalStats.attackArea são os multiplicadores totais
    self.currentRange = self.baseRange and finalStats.range and (self.baseRange * finalStats.range)
    self.currentThickness = self.baseThickness and finalStats.attackArea and (self.baseThickness * finalStats.attackArea)

    -- Log para verificar os valores calculados
    -- print(string.format("[ChainLightning:update] currentRange: %s, currentThickness: %s (BaseRange: %s, BaseThick: %s, FS.range: %s, FS.area: %s)",
    --     tostring(self.currentRange), tostring(self.currentThickness), tostring(self.baseRange), tostring(self.baseThickness), tostring(finalStats.range), tostring(finalStats.attackArea)))

    -- Atualiza a duração dos raios visíveis
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
    -- Tenta usar getEnemiesInRange se existir, senão usa getEnemies e filtra
    local enemies
    if self.playerManager.enemyManager.getEnemiesInRange then
        enemies = self.playerManager.enemyManager:getEnemiesInRange(centerX, centerY, radius)
    else
        enemies = self.playerManager.enemyManager:getEnemies()
    end

    local closestEnemy = nil
    local minDistanceSq = radius * radius + 1 -- Inicia com distância maior que o raio

    for id, enemy in pairs(enemies) do
        -- Verifica se o inimigo está vivo e não está na lista de exclusão
        if enemy.isAlive and (not excludedIDs or not excludedIDs[enemy.id]) then
            local dx = enemy.position.x - centerX
            local dy = enemy.position.y - centerY
            local distSq = dx * dx + dy * dy

            -- Verifica se está dentro do raio e é mais próximo que o anterior
            if distSq <= radius * radius and distSq < minDistanceSq then
                -- Adiciona checagem adicional se getEnemiesInRange não foi usado
                if not self.playerManager.enemyManager.getEnemiesInRange then
                    if distSq > radius * radius then -- Garante que está dentro do raio se filtramos manualmente
                        goto continue                -- Pula para a próxima iteração (Lua 5.2+)
                    end
                end
                minDistanceSq = distSq
                closestEnemy = enemy
            end
        end
        ::continue:: -- Label para goto (Lua 5.2+)
    end
    return closestEnemy
end

--- Verifica colisão entre um segmento de linha e inimigos.
--- Retorna o inimigo mais próximo colidido ao longo do segmento a partir do início, ou nil.
---@param startX number Posição X inicial do segmento.
---@param startY number Posição Y inicial do segmento.
---@param endX number Posição X final do segmento.
---@param endY number Posição Y final do segmento.
---@param thickness number Espessura do segmento (para calcular raio de colisão).
---@param enemies table Tabela de inimigos a verificar.
---@return table? Instância do inimigo colidido ou nil.
function ChainLightning:findCollisionOnSegment(startX, startY, endX, endY, thickness, enemies)
    local closestHitEnemy = nil
    local minHitDistSq = math.huge -- Inicia com infinito

    local segmentDirX = endX - startX
    local segmentDirY = endY - startY
    local segmentLenSq = segmentDirX * segmentDirX + segmentDirY * segmentDirY

    -- Normaliza a direção do segmento (se o comprimento for > 0)
    if segmentLenSq > 0.0001 then
        local segmentLen = math.sqrt(segmentLenSq)
        segmentDirX = segmentDirX / segmentLen
        segmentDirY = segmentDirY / segmentLen
    else -- Segmento de comprimento zero, não faz nada
        return nil
    end

    for id, enemy in pairs(enemies) do
        if enemy.isAlive and id then
            local enemyRadius = enemy.radius
            local checkRadius = enemyRadius + thickness / 2 -- Raio para checagem de colisão

            -- Vetor do início do segmento até o inimigo
            local vecX = enemy.position.x - startX
            local vecY = enemy.position.y - startY

            -- Projeção do vetor no segmento (produto escalar)
            local projection = vecX * segmentDirX + vecY * segmentDirY

            -- Ponto mais próximo no RAIO INFINITO ao centro do inimigo
            local closestPointX, closestPointY
            if projection <= 0 then -- Atrás ou no ponto inicial
                closestPointX = startX
                closestPointY = startY
            elseif projection * projection >= segmentLenSq then -- Além do ponto final
                closestPointX = endX
                closestPointY = endY
            else -- Em algum lugar no meio do segmento
                closestPointX = startX + segmentDirX * projection
                closestPointY = startY + segmentDirY * projection
            end

            -- Distância quadrada do centro do inimigo ao ponto mais próximo no SEGMENTO
            local distSqToSegment = (enemy.position.x - closestPointX) ^ 2 + (enemy.position.y - closestPointY) ^ 2

            -- Verifica colisão (distância < raio de checagem)
            if distSqToSegment <= checkRadius * checkRadius then
                -- Calcula distância do *início* do segmento ao inimigo (para ordenar)
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
        return false -- Não dispara se o dano não puder ser calculado
    end

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

    -- Busca todos os inimigos uma vez
    local allEnemies = self.playerManager.enemyManager:getEnemies()

    local targetsHit = {}
    local hitPositions = {}
    local excludedIDs = {}

    local startPos = self.currentPosition
    if not startPos then
        error("[ChainLightning:cast] ERRO: startPos (currentPosition) é nil.")
        return false
    end

    -- Verifica se self.currentRange (calculado no update) é válido
    if not self.currentRange or self.currentRange <= 0 then
        error(string.format("[ChainLightning:cast] ERRO: self.currentRange inválido (%s) para o primeiro segmento.",
            tostring(self.currentRange)))
        return false
    end
    local endX = startPos.x + math.cos(aimAngle) * self.currentRange
    local endY = startPos.y + math.sin(aimAngle) * self.currentRange
    table.insert(hitPositions, { x = startPos.x, y = startPos.y })
    print(string.format(
        "[ChainLightning:cast] Aiming first segment: start=(%.1f,%.1f), end=(%.1f,%.1f), range=%s, angle=%.2f",
        startPos.x,
        startPos.y, endX, endY, tostring(self.currentRange), aimAngle))

    -- Verifica se self.currentThickness (calculado no update) é válido
    local segmentThickness = self.currentThickness
    if not segmentThickness or segmentThickness <= 0 then
        error(string.format("[ChainLightning:cast] ERRO: segmentThickness inválido (%s) para o primeiro segmento.",
            tostring(segmentThickness)))
        segmentThickness = self.baseThickness or 1 -- Fallback mínimo para evitar mais erros
    end

    local firstHitEnemy = self:findCollisionOnSegment(startPos.x, startPos.y, endX, endY, segmentThickness, allEnemies)
    local startChainingFrom = nil

    if firstHitEnemy then
        print("[ChainLightning:cast] First segment HIT enemy ID: " .. tostring(firstHitEnemy.id) .. " at (%.1f, %.1f)",
            firstHitEnemy.position.x, firstHitEnemy.position.y)
        table.insert(hitPositions, { x = firstHitEnemy.position.x, y = firstHitEnemy.position.y })
        targetsHit[firstHitEnemy.id] = firstHitEnemy
        excludedIDs[firstHitEnemy.id] = true
        startChainingFrom = firstHitEnemy
    else
        print("[ChainLightning:cast] First segment MISSED. Endpoint: (%.1f, %.1f)", endX, endY)
        table.insert(hitPositions, { x = endX, y = endY })
    end

    local currentTarget = startChainingFrom
    local successfulJumps = 0
    print(string.format("[ChainLightning:cast] Starting chain loop. StartChainingFrom is %s. TotalAllowedJumps: %d",
        tostring(startChainingFrom and startChainingFrom.id), totalAllowedJumps))

    while currentTarget and successfulJumps < totalAllowedJumps do
        local lastHitPosition = currentTarget.position
        print(string.format("[ChainLightning:cast] Attempting Jump #%d from enemy %s at (%.1f, %.1f)",
            successfulJumps + 1, currentTarget.id, lastHitPosition.x, lastHitPosition.y))

        local decayedJumpRangeBase = self.baseJumpRange and
            (self.baseJumpRange * (ChainLightning.JUMP_RANGE_DECAY ^ successfulJumps))
        local currentJumpSearchRadius = decayedJumpRangeBase and finalStats.attackArea and
            (decayedJumpRangeBase * finalStats.attackArea)
        print(string.format(
            "  - Jump params: decayedBaseJumpRange=%s, finalStats.attackArea=%s, currentJumpSearchRadius=%s",
            tostring(decayedJumpRangeBase), tostring(finalStats.attackArea), tostring(currentJumpSearchRadius)))

        if not currentJumpSearchRadius or currentJumpSearchRadius <= 0 then
            print(string.format(
                "[ChainLightning:cast] AVISO: Raio de salto inválido (%s) para o salto %d. Interrompendo corrente.",
                tostring(currentJumpSearchRadius), successfulJumps + 1))
            break -- Interrompe se o raio de salto for inválido
        end

        local nextTarget = self:findClosestEnemy(lastHitPosition.x, lastHitPosition.y, currentJumpSearchRadius,
            excludedIDs)

        if nextTarget then
            print(string.format("  - Jump SUCCESS to enemy %s at (%.1f, %.1f)", nextTarget.id, nextTarget.position.x,
                nextTarget.position.y))
            currentTarget = nextTarget
            table.insert(hitPositions, { x = currentTarget.position.x, y = currentTarget.position.y })
            targetsHit[currentTarget.id] = currentTarget
            excludedIDs[currentTarget.id] = true
            successfulJumps = successfulJumps + 1
        else
            print("  - Jump FAILED: No next target found within jump radius or not excluded.")
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
                print("[ChainLightning:cast] AVISO: Acerto crítico, mas finalStats.critMultiplier é nil.")
            end
        end
        enemy:takeDamage(finalDamage, isCritical)
    end

    if #hitPositions > 1 then
        table.insert(self.activeChains, {
            points = hitPositions,
            duration = self.visual.attack.segmentDuration,
            color = self.visual.attack.color,
            thickness = segmentThickness -- Usa a espessura do segmento (que pode ter tido fallback)
        })
    end

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
    love.graphics.setLineWidth(1)      -- Reseta a espessura da linha
    love.graphics.setColor(1, 1, 1, 1) -- Reseta a cor
end

-- Renomeada de drawPreviewCircle para drawPreviewLine
function ChainLightning:drawPreviewLine(color)
    love.graphics.setColor(color)
    -- Desenha uma linha do jogador na direção da mira com o comprimento do range atual
    local startX, startY = self.currentPosition.x, self.currentPosition.y
    local endX = startX + math.cos(self.currentAngle) * self.currentRange
    local endY = startY + math.sin(self.currentAngle) * self.currentRange
    love.graphics.line(startX, startY, endX, endY)

    -- Opcional: Desenha círculo menor para jump range (a partir do jogador, só como referência)
    -- love.graphics.circle("line", self.currentPosition.x, self.currentPosition.y, self.baseJumpRange * (1+self.playerManager.state:getTotalArea()))
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

return ChainLightning -- GARANTIR QUE ESTA LINHA ESTEJA PRESENTE E CORRETA
