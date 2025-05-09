---------------------------------------------------------------------------
--- Circular Smash Ability
--- Um ataque que causa dano em uma área circular ao redor de um ponto de impacto.
--- Refatorado para receber weaponInstance e buscar stats dinamicamente.
----------------------------------------------------------------------------

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
    local finalAttackAreaMultiplier = finalStats.attackArea or 1.0
    self.finalImpactDistance = self.baseAreaEffectRadius * finalAttackAreaMultiplier

    -- Calcula finalExplosionRadius (afetado por finalStats.attackArea)
    -- finalStats.attackArea é um multiplicador (ex: 1.0 = base, 1.1 = +10%)
    self.finalExplosionRadius = self.baseAreaEffectRadius * finalAttackAreaMultiplier

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
    self.targetPos.x = self.currentPosition.x + math.cos(angle) * self.finalImpactDistance
    self.targetPos.y = self.currentPosition.y + math.sin(angle) * self.finalImpactDistance
    print(string.format("  - Impact target at (%.1f, %.1f), dist: %.1f, explosion_radius: %.1f", self.targetPos.x,
        self.targetPos.y,
        self.finalImpactDistance, self.finalExplosionRadius))

    -- Inicia a animação
    self.isAttacking = true
    self.attackProgress = 0

    -- Aplica cooldown usando finalStats.attackSpeed
    -- attackSpeed é um multiplicador (ex: 1.0 = base, 1.2 = 20% mais rápido)
    local baseData = self.weaponInstance:getBaseData()
    local baseCooldown = baseData and baseData.cooldown
    local finalAttackSpeedMultiplier = finalStats.attackSpeed
    if not finalAttackSpeedMultiplier or finalAttackSpeedMultiplier <= 0 then finalAttackSpeedMultiplier = 0.01 end

    self.cooldownRemaining = baseCooldown / finalAttackSpeedMultiplier

    -- Calcula ataques extras usando finalStats.multiAttackChance
    -- multiAttackChance é uma fração (ex: 0.0 para 0%, 0.5 para 50%, 1.0 para 1 golpe extra garantido)
    local finalMultiAttackChance = finalStats.multiAttackChance
    if finalMultiAttackChance == nil then finalMultiAttackChance = 0 end
    local extraAttacks = math.floor(finalMultiAttackChance)
    local decimalChance = finalMultiAttackChance - extraAttacks

    -- Multiplicador de range do jogador para os ataques extras
    local playerRangeMultiplierForExtraHits = finalStats.range or 1.0

    -- Ataque principal usa o raio de explosão final sem o multiplicador progressivo ou de range para extras
    self.currentAttackRadius = self.finalExplosionRadius
    local success = self:executeAttack(finalStats)

    -- Multiplicador progressivo para o raio dos ataques extras
    local progressiveMultiplierForExtraRadius = 1.0

    for i = 1, extraAttacks do
        if success then
            progressiveMultiplierForExtraRadius = progressiveMultiplierForExtraRadius + 0.20
            -- Aplica o range do jogador AO MULTIPLICADOR PROGRESSIVO
            local combinedMultiplier = progressiveMultiplierForExtraRadius * playerRangeMultiplierForExtraHits
            self.currentAttackRadius = self.finalExplosionRadius * combinedMultiplier
            print(string.format("    - Extra attack #%d, radius %.1f (ProgMult: %.2f, RangeMult: %.2f)", i,
                self.currentAttackRadius, progressiveMultiplierForExtraRadius, playerRangeMultiplierForExtraHits))
            success = self:executeAttack(finalStats)
        else
            break
        end
    end

    if success and decimalChance > 0 and math.random() < decimalChance then
        progressiveMultiplierForExtraRadius = progressiveMultiplierForExtraRadius + 0.20
        local combinedMultiplier = progressiveMultiplierForExtraRadius * playerRangeMultiplierForExtraHits
        self.currentAttackRadius = self.finalExplosionRadius * combinedMultiplier
        print(string.format("    - Decimal chance extra attack, radius %.1f (ProgMult: %.2f, RangeMult: %.2f)",
            self.currentAttackRadius, progressiveMultiplierForExtraRadius, playerRangeMultiplierForExtraHits))
        self:executeAttack(finalStats)
    end

    return true
end

--- Executa um único pulso de ataque circular.
--- Usa self.currentAttackRadius para determinar a área deste pulso.
---@param finalStats table A tabela de stats finais do jogador.
---@return boolean Sempre retorna true.
function CircularSmash:executeAttack(finalStats)
    local enemies = self.playerManager.enemyManager:getEnemies()
    local enemiesHitCount = 0
    local attackRadiusSq = self.currentAttackRadius * self.currentAttackRadius -- Usa o raio do golpe atual
    local finalCritChance = finalStats.critChance
    if finalCritChance == nil then finalCritChance = 0 end
    local isCritical = math.random() <= finalCritChance

    -- print(string.format("    [executeAttack] Checking enemies in radius %.1f at (%.1f, %.1f)", math.sqrt(attackRadiusSq), self.targetPos.x, self.targetPos.y))

    for i, enemy in ipairs(enemies) do
        if enemy.isAlive then
            -- Verifica se o inimigo está dentro do raio do golpe atual
            if self:isPointInArea(enemy.position, self.targetPos, attackRadiusSq) then
                enemiesHitCount = enemiesHitCount + 1
                self:applyDamage(enemy, isCritical, finalStats)
            end
        end
    end
    if enemiesHitCount > 0 then
        print(string.format("    [executeAttack] Hit %d enemies with radius %.1f.", enemiesHitCount,
            math.sqrt(attackRadiusSq)))
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
    local totalDamage = finalStats.weaponDamage or 0

    -- Calcula crítico usando finalStats
    local finalCritDamageMultiplier = finalStats.critDamage
    if finalCritDamageMultiplier == nil then finalCritDamageMultiplier = 1.0 end
    if isCritical then
        totalDamage = math.floor(totalDamage * finalCritDamageMultiplier)
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
    if radius <= 0 then return end
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
    if attackRadius <= 0 then return end
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
