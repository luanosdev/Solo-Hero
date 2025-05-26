---------------------------------------------------------------------------
--- Circular Smash Ability
--- Um ataque que causa dano em uma área circular ao redor de um ponto de impacto.
--- Refatorado para receber weaponInstance e buscar stats dinamicamente.
----------------------------------------------------------------------------

local ManagerRegistry = require("src.managers.manager_registry")
local TablePool = require("src.utils.table_pool")

local CircularSmash = {}
CircularSmash.__index = CircularSmash -- Para permitir :new

-- Configurações visuais PADRÃO
CircularSmash.name = "Esmagamento Circular"
CircularSmash.description = "Golpeia o chão, causando dano em área circular."
CircularSmash.damageType = "melee" -- Ou talvez 'blunt'/'crushing' se tiver tipos específicos
CircularSmash.visual = {
    preview = {
        active = false,
        -- Preview poderia mostrar o círculo de alcance
        color = { 0.7, 0.7, 0.7, 0.2 } -- Cor padrão preview
    },
    attack = {
        animationDuration = 0.3,       -- Duração da animação da onda de choque
        color = { 0.8, 0.8, 0.7, 0.8 } -- Cor padrão ataque
    }
}

--- Cria uma nova instância da habilidade CircularSmash.
---@param playerManager PlayerManager Instância do PlayerManager.
---@param weaponInstance BaseWeapon Instância da arma que está usando esta habilidade.
function CircularSmash:new(playerManager, weaponInstance)
    local o = setmetatable({}, self)
    print("[CircularSmash:new] Creating instance...")

    if not playerManager or not weaponInstance then
        error("CircularSmash:new - playerManager e weaponInstance são obrigatórios.")
        return nil
    end

    o.playerManager = playerManager
    o.weaponInstance = weaponInstance

    o.cooldownRemaining = 0
    o.isAttacking = false
    o.attackProgress = 0
    o.targetPos = { x = 0, y = 0 } -- Posição onde o último ataque foi direcionado
    o.currentAttackRadius = 0      -- Raio do ataque atual (considerando multi-ataque)

    -- Busca cores da weaponInstance
    o.visual.preview.color = weaponInstance.previewColor or o.visual.preview.color
    o.visual.attack.color = weaponInstance.attackColor or o.visual.attack.color
    print("  - Preview/Attack colors set.")

    -- As áreas de efeito são calculadas dinamicamente.
    -- Estes são os raios *base* definidos pela arma/habilidade.
    -- Os bônus do jogador (range, attackArea) os modificarão.
    local baseData = o.weaponInstance:getBaseData()
    o.baseAreaEffectRadius = baseData and baseData.baseAreaEffectRadius

    -- Estes serão os raios FINAIS calculados em update
    o.finalImpactDistance = o.baseAreaEffectRadius
    o.finalExplosionRadius = o.baseAreaEffectRadius

    if o.playerManager.player then
        o.currentPosition = o.playerManager.player.position -- Pega posição inicial para referência
    else
        o.currentPosition = { x = 0, y = 0 }
    end
    o.currentAngle = 0

    print("[CircularSmash:new] Instance created successfully. BaseAreaEffectRadius: " .. o.baseAreaEffectRadius)
    return o
end

--- Atualiza o estado da habilidade.
---@param dt number Delta time.
---@param angle number Ângulo atual da mira do jogador.
function CircularSmash:update(dt, angle)
    -- Atualiza cooldown
    if self.cooldownRemaining > 0 then
        self.cooldownRemaining = self.cooldownRemaining - dt
    end

    local finalStats = self.playerManager:getCurrentFinalStats()

    if self.playerManager.player then
        self.currentPosition = self.playerManager.player.position
    end
    self.currentAngle = angle

    -- Calcula finalImpactDistance (afetado por finalStats.range)
    -- finalStats.range é um multiplicador (ex: 1.0 = base, 1.1 = +10%)
    -- Se finalStats.attackArea for nil, os valores finais podem ser nil, o que é intencional.
    local finalAttackAreaMultiplier = finalStats.attackArea -- Sem fallback

    -- Se self.baseAreaEffectRadius ou finalAttackAreaMultiplier for nil, o resultado será nil.
    self.finalImpactDistance = self.baseAreaEffectRadius and finalAttackAreaMultiplier and
        (self.baseAreaEffectRadius * finalAttackAreaMultiplier)
    self.finalExplosionRadius = self.baseAreaEffectRadius and finalAttackAreaMultiplier and
        (self.baseAreaEffectRadius * finalAttackAreaMultiplier)

    -- Atualiza animação do ataque
    if self.isAttacking then
        -- O ataque acontece em targetPos, a animação é desenhada lá.
        self.attackProgress = self.attackProgress + (dt / self.visual.attack.animationDuration)
        if self.attackProgress >= 1 then
            self.isAttacking = false
            self.attackProgress = 0
            self.currentAttackRadius = 0 -- Reseta raio do ataque atual
        end
    end
end

--- Tenta executar o ataque.
---@param args table Contém o 'angle' da mira.
---@return boolean True se o ataque foi iniciado, False se estava em cooldown.
function CircularSmash:cast(args)
    args = args or {}
    local angle = args.angle

    if not angle then
        print("[CircularSmash:cast] WARN: Angle not provided in args, using current angle.")
        angle = self.currentAngle
    end

    if self.cooldownRemaining > 0 then
        return false
    end
    print("[CircularSmash:cast] Casting attack.")

    local finalStats = self.playerManager:getCurrentFinalStats()

    -- Calcula a posição do impacto usando a distância de impacto FINAL
    -- Se self.finalImpactDistance for nil, a operação de multiplicação causará erro (intencional)
    self.targetPos.x = self.currentPosition.x + math.cos(angle) * self.finalImpactDistance
    self.targetPos.y = self.currentPosition.y + math.sin(angle) * self.finalImpactDistance
    print(string.format("  - Impact target at (%.1f, %.1f), dist: %s, explosion_radius: %s", self.targetPos.x,
        self.targetPos.y,
        tostring(self.finalImpactDistance), tostring(self.finalExplosionRadius)))

    -- Inicia a animação
    self.isAttacking = true
    self.attackProgress = 0

    -- Aplica cooldown usando finalStats.attackSpeed
    local baseData = self.weaponInstance:getBaseData()
    local baseCooldown = baseData and baseData.cooldown       -- Sem fallback para baseCooldown
    local finalAttackSpeedMultiplier = finalStats.attackSpeed -- Sem fallback inicial
    -- Exceção: Evitar divisão por zero ou cooldown inválido
    if not finalAttackSpeedMultiplier or finalAttackSpeedMultiplier <= 0 then finalAttackSpeedMultiplier = 0.01 end

    if baseCooldown and finalAttackSpeedMultiplier then
        self.cooldownRemaining = baseCooldown / finalAttackSpeedMultiplier
    else
        print(
            "[CircularSmash:cast] ERRO: baseCooldown ou finalAttackSpeedMultiplier é nil. Não é possível calcular cooldown.")
        -- Decide como lidar: talvez retornar false ou não setar cooldown, o que pode levar a spam de ataques.
        -- Por ora, apenas loga e continua, o que pode significar cooldown não aplicado.
        self.cooldownRemaining = 1 -- Cooldown de fallback em caso de erro de dados
    end

    -- Calcula ataques extras usando finalStats.multiAttackChance
    local finalMultiAttackChance = finalStats.multiAttackChance -- Sem fallback
    local extraAttacks = 0
    local decimalChance = 0

    if finalMultiAttackChance then
        extraAttacks = math.floor(finalMultiAttackChance)
        decimalChance = finalMultiAttackChance - extraAttacks
    else
        print("[CircularSmash:cast] AVISO: finalMultiAttackChance é nil. Nenhum ataque extra será calculado.")
    end

    -- Multiplicador de range do jogador para os ataques extras
    local playerRangeMultiplierForExtraHits = finalStats.range -- Sem fallback

    -- Ataque principal usa o raio de explosão final sem o multiplicador progressivo ou de range para extras
    self.currentAttackRadius = self.finalExplosionRadius
    local success = self:executeAttack(finalStats)

    -- Multiplicador progressivo para o raio dos ataques extras
    local progressiveMultiplierForExtraRadius = 1.0

    for i = 1, extraAttacks do
        if success then
            progressiveMultiplierForExtraRadius = progressiveMultiplierForExtraRadius + 0.20
            -- Aplica o range do jogador AO MULTIPLICADOR PROGRESSIVO
            -- Se playerRangeMultiplierForExtraHits for nil, combinedMultiplier pode ser nil.
            local combinedMultiplier = playerRangeMultiplierForExtraHits and
                (progressiveMultiplierForExtraRadius * playerRangeMultiplierForExtraHits) or
                progressiveMultiplierForExtraRadius
            self.currentAttackRadius = self.finalExplosionRadius and combinedMultiplier and
                (self.finalExplosionRadius * combinedMultiplier)
            print(string.format("    - Extra attack #%d, radius %s (ProgMult: %.2f, RangeMult: %s)", i,
                tostring(self.currentAttackRadius), progressiveMultiplierForExtraRadius,
                tostring(playerRangeMultiplierForExtraHits)))
            if self.currentAttackRadius then
                success = self:executeAttack(finalStats)
            else
                print("    - AVISO: currentAttackRadius para ataque extra é nil. Pulando ataque extra.")
                success = false -- Considera falha para não continuar com mais extras baseados em nil
            end
        else
            break
        end
    end

    if success and decimalChance > 0 and math.random() < decimalChance then
        progressiveMultiplierForExtraRadius = progressiveMultiplierForExtraRadius + 0.20
        local combinedMultiplier = playerRangeMultiplierForExtraHits and
            (progressiveMultiplierForExtraRadius * playerRangeMultiplierForExtraHits) or
            progressiveMultiplierForExtraRadius
        self.currentAttackRadius = self.finalExplosionRadius and combinedMultiplier and
            (self.finalExplosionRadius * combinedMultiplier)
        print(string.format("    - Decimal chance extra attack, radius %s (ProgMult: %.2f, RangeMult: %s)",
            tostring(self.currentAttackRadius), progressiveMultiplierForExtraRadius,
            tostring(playerRangeMultiplierForExtraHits)))
        if self.currentAttackRadius then
            self:executeAttack(finalStats)
        else
            print("    - AVISO: currentAttackRadius para ataque extra decimal é nil. Pulando ataque.")
        end
    end

    return true
end

--- Executa um único pulso de ataque circular.
--- Usa self.currentAttackRadius para determinar a área deste pulso.
---@param finalStats table A tabela de stats finais do jogador.
---@return boolean Sempre retorna true.
function CircularSmash:executeAttack(finalStats)
    local enemyManager = ManagerRegistry:get("enemyManager")
    local spatialGrid = enemyManager.spatialGrid
    local enemiesHitCount = 0

    if not self.currentAttackRadius or self.currentAttackRadius <= 0 then
        error(string.format("    [executeAttack] AVISO: Raio de ataque inválido (%s). Nenhum inimigo será atingido.",
            tostring(self.currentAttackRadius)))
    end

    if not spatialGrid then
        error("[executeAttack] AVISO: spatialGrid não disponível. Não é possível buscar inimigos.")
    end

    -- Busca inimigos próximos usando o spatialGrid
    -- O centro da busca é self.targetPos, e o raio é self.currentAttackRadius
    local nearbyEnemies = spatialGrid:getNearbyEntities(self.targetPos.x, self.targetPos.y, self
        .currentAttackRadius, nil)

    local attackRadiusSq = self.currentAttackRadius * self.currentAttackRadius

    local finalCritChance = finalStats.critChance -- Sem fallback
    -- Se finalCritChance for nil, isCritical será false. Isso é aceitável aqui.
    local isCritical = finalCritChance and (math.random() <= finalCritChance)

    -- print(string.format("    [executeAttack] Checking %d nearby enemies in radius %.1f at (%.1f, %.1f)", #nearbyEnemies, self.currentAttackRadius, self.targetPos.x, self.targetPos.y))

    for _, enemy in ipairs(nearbyEnemies) do
        if enemy.isAlive then
            -- Verifica se o inimigo está dentro do raio do golpe atual (verificação circular precisa)
            if self:isPointInArea(enemy.position, self.targetPos, attackRadiusSq) then
                enemiesHitCount = enemiesHitCount + 1
                self:applyDamage(enemy, isCritical, finalStats)
            end
        end
    end

    TablePool.release(nearbyEnemies)

    if enemiesHitCount > 0 then
        print(string.format("    [executeAttack] Hit %d enemies with radius %.1f.", enemiesHitCount,
            self.currentAttackRadius))
    end
    return true
end

--- Verifica se um ponto está dentro de uma área circular definida.
---@param pointPos table Posição {x, y} do ponto a verificar.
---@param centerPos table Posição {x, y} do centro do círculo.
---@param radiusSq number O QUADRADO do raio do círculo.
---@return boolean True se o ponto está na área.
function CircularSmash:isPointInArea(pointPos, centerPos, radiusSq)
    -- Calcula distância quadrada do PONTO CENTRAL fornecido
    local dx = pointPos.x - centerPos.x
    local dy = pointPos.y - centerPos.y
    local distanceSq = dx * dx + dy * dy
    return distanceSq <= radiusSq
end

--- Aplica dano a um alvo.
---@param target BaseEnemy Instância do inimigo a ser atingido.
---@param isCritical boolean Se o ataque foi critico
---@param finalStats table A tabela de stats finais do jogador.
---@return boolean Resultado de target:takeDamage.
function CircularSmash:applyDamage(target, isCritical, finalStats)
    -- Usa o dano final da arma já calculado em finalStats
    -- Se finalStats.weaponDamage for nil, totalDamage será nil.
    local totalDamage = finalStats.weaponDamage

    -- Calcula crítico usando finalStats
    if isCritical then
        -- Se finalStats.critDamage for nil, a multiplicação resultará em nil.
        totalDamage = totalDamage and finalStats.critDamage and math.floor(totalDamage * finalStats.critDamage)
    end

    return target:takeDamage(totalDamage, isCritical)
end

--- Desenha os elementos visuais da habilidade.
function CircularSmash:draw()
    if not self.currentPosition then return end

    -- Desenha preview (círculo no ponto de impacto futuro)
    if self.visual.preview.active then
        -- Calcula onde o centro do preview estaria usando o raio FINAL
        local previewImpactX = self.currentPosition.x + math.cos(self.currentAngle) * self.finalImpactDistance
        local previewImpactY = self.currentPosition.y + math.sin(self.currentAngle) * self.finalImpactDistance
        -- Desenha o círculo de preview com o raio FINAL
        self:drawPreviewCircleAt(self.visual.preview.color, previewImpactX, previewImpactY, self.finalExplosionRadius)
    end

    -- Desenha animação do ataque (onda de choque no ponto de impacto)
    if self.isAttacking then
        -- Usa o raio do golpe atual (que pode ter sido aumentado por multi-ataque)
        self:drawAttackCircle(self.visual.attack.color, self.attackProgress, self.targetPos.x, self.targetPos.y,
            self.currentAttackRadius)
    end
end

--- Desenha o círculo de preview em um ponto específico com um raio específico.
---@param color table Cor RGBA.
---@param centerX number Coordenada X do centro.
---@param centerY number Coordenada Y do centro.
---@param radius number Raio do círculo.
function CircularSmash:drawPreviewCircleAt(color, centerX, centerY, radius)
    if not radius or radius <= 0 then return end
    love.graphics.setColor(color)
    love.graphics.circle("line", centerX, centerY, radius, 32)
    love.graphics.setColor(1, 1, 1, 1)
end

--- Desenha a animação da onda de choque circular.
---@param color table Cor RGBA.
---@param progress number Progresso da animação (0 a 1).
---@param centerX number Coordenada X do centro do impacto.
---@param centerY number Coordenada Y do centro do impacto.
---@param attackRadius number O raio máximo para este pulso de ataque.
function CircularSmash:drawAttackCircle(color, progress, centerX, centerY, attackRadius)
    if not attackRadius or attackRadius <= 0 then return end
    local segments = 48
    local currentRadius = attackRadius * progress   -- Círculo expande com o progresso até o attackRadius
    local alpha = color[4] or 0.8
    local currentAlpha = alpha * (1 - progress ^ 2) -- Fade out da animação
    local thickness = 3 * (1 - progress) + 1        -- Linha fica mais fina ao expandir

    if currentRadius > 1 and currentAlpha > 0.05 then
        love.graphics.setColor(color[1], color[2], color[3], currentAlpha)
        love.graphics.setLineWidth(thickness)
        love.graphics.circle("line", centerX, centerY, currentRadius, segments)
        love.graphics.setLineWidth(1) -- Reseta espessura da linha
        love.graphics.setColor(1, 1, 1, 1)
    end
end

--- Retorna o cooldown restante.
---@return number
function CircularSmash:getCooldownRemaining()
    return self.cooldownRemaining or 0
end

--- Alterna a visualização da prévia.
function CircularSmash:togglePreview()
    self.visual.preview.active = not self.visual.preview.active
end

--- Retorna se a prévia está ativa.
---@return boolean
function CircularSmash:getPreview()
    return self.visual.preview.active
end

return CircularSmash
