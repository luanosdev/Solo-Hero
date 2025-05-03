--[[----------------------------------------------------------------------------
    Circular Smash Ability
    Um ataque que causa dano em uma área circular ao redor de um ponto de impacto.
    Refatorado para receber weaponInstance e buscar stats dinamicamente.
----------------------------------------------------------------------------]] --

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

    -- Área de efeito será calculada dinamicamente no update/cast
    o.area = {
        position = { x = 0, y = 0 }, -- Posição do jogador
        angle = 0,                   -- Ângulo da mira
        radius = 0,                  -- Raio base do ataque (será atualizado)
    }
    if o.playerManager.player then
        o.area.position = o.playerManager.player.position -- Pega posição inicial
    end

    print("[CircularSmash:new] Instance created successfully.")
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

    -- Atualiza posição e ângulo base para seguir o jogador e a mira
    if self.area and self.playerManager.player then
        self.area.position = self.playerManager.player.position
        self.area.angle = angle

        -- CALCULA RAIO BASE AQUI (afetado por bônus de Range, não Area)
        local baseData = self.weaponInstance:getBaseData()
        local weaponBaseRange = (baseData and baseData.range) or 50        -- Range da arma define o raio base
        local rangeBonusPercent = self.playerManager.state:getTotalRange() -- Bônus de range aumenta o raio
        local newRadius = weaponBaseRange * (1 + rangeBonusPercent)

        if newRadius ~= self.area.radius then
            self.area.radius = newRadius
            print(string.format("  [CircularSmash UPDATE] Base Radius Recalculated: %.1f", self.area.radius))
        end
    end

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
    local angle = args.angle -- Espera receber o ângulo da mira

    if not angle then
        print("[CircularSmash:cast] WARN: Angle not provided in args, using 0.")
        angle = 0
    end

    if self.cooldownRemaining > 0 then
        return false -- Em cooldown
    end
    print("[CircularSmash:cast] Casting attack.")

    -- Calcula a posição do impacto (usando o raio BASE calculado em update)
    -- O raio da arma define a *distância* do impacto, não só o raio da explosão.
    local impactDist = self.area.radius
    self.targetPos.x = self.area.position.x + math.cos(angle) * impactDist
    self.targetPos.y = self.area.position.y + math.sin(angle) * impactDist
    print(string.format("  - Impact target set at (%.1f, %.1f), dist: %.1f", self.targetPos.x, self.targetPos.y,
        impactDist))

    -- Inicia a animação
    self.isAttacking = true
    self.attackProgress = 0

    -- Aplica cooldown
    local totalAttackSpeed = self.playerManager.state:getTotalAttackSpeed()
    local baseData = self.weaponInstance:getBaseData()
    local baseCooldown = (baseData and baseData.cooldown) or 1.0 -- Padrão 1s
    if totalAttackSpeed <= 0 then totalAttackSpeed = 1 end
    self.cooldownRemaining = baseCooldown / totalAttackSpeed
    print(string.format("  - Cooldown set to %.2fs (Base: %.2f / TotalAS: %.2f)", self.cooldownRemaining, baseCooldown,
        totalAttackSpeed))

    -- Calcula ataques extras
    local multiAttackChance = self.playerManager.state:getTotalMultiAttackChance()
    local extraAttacks = math.floor(multiAttackChance)
    local decimalChance = multiAttackChance - extraAttacks
    print(string.format("  - Multi-Attack Chance: %.2f (Extra: %d + %.2f%%)", multiAttackChance, extraAttacks,
        decimalChance * 100))

    -- Raio inicial para este cast é o raio base
    local currentRadiusMultiplier = 1.0
    self.currentAttackRadius = self.area.radius * currentRadiusMultiplier -- Raio para o primeiro golpe

    -- Executa o ataque principal
    local success = self:executeAttack()

    -- Ataques extras aumentam o raio para os golpes subsequentes DESTE cast
    for i = 1, extraAttacks do
        if success then
            currentRadiusMultiplier = currentRadiusMultiplier +
            0.20                                                     -- Aumenta raio em 20% por golpe extra (ajustável)
            self.currentAttackRadius = self.area.radius *
                currentRadiusMultiplier                              -- Atualiza raio para o próximo executeAttack
            print(string.format("    - Executing extra attack #%d with radius %.1f (Multiplier: %.2f)", i,
                self.currentAttackRadius, currentRadiusMultiplier))
            success = self:executeAttack() -- Ataque extra ainda centrado no mesmo targetPos
        else
            break
        end
    end

    if success and decimalChance > 0 and math.random() < decimalChance then
        currentRadiusMultiplier = currentRadiusMultiplier + 0.20
        self.currentAttackRadius = self.area.radius * currentRadiusMultiplier
        print(string.format("    - Executing decimal chance extra attack with radius %.1f (Multiplier: %.2f)",
            self.currentAttackRadius, currentRadiusMultiplier))
        self:executeAttack()
    end

    -- O raio base (self.area.radius) não é modificado permanentemente aqui.
    -- self.currentAttackRadius será resetado em update quando isAttacking se tornar false.

    return true -- Cast iniciado
end

--- Executa um único pulso de ataque circular.
--- Usa self.currentAttackRadius para determinar a área deste pulso.
---@return boolean Sempre retorna true.
function CircularSmash:executeAttack()
    local enemies = self.playerManager.enemyManager:getEnemies()
    local enemiesHitCount = 0
    local attackRadiusSq = self.currentAttackRadius * self.currentAttackRadius -- Usa o raio do golpe atual

    -- print(string.format("    [executeAttack] Checking enemies in radius %.1f at (%.1f, %.1f)", math.sqrt(attackRadiusSq), self.targetPos.x, self.targetPos.y))

    for i, enemy in ipairs(enemies) do
        if enemy.isAlive then
            -- Verifica se o inimigo está dentro do raio do golpe atual
            if self:isPointInArea(enemy.position, self.targetPos, attackRadiusSq) then
                enemiesHitCount = enemiesHitCount + 1
                self:applyDamage(enemy)
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
---@return boolean Resultado de target:takeDamage.
function CircularSmash:applyDamage(target)
    -- Busca o dano base da arma
    local baseData = self.weaponInstance:getBaseData()
    local weaponBaseDamage = (baseData and baseData.damage) or 0

    -- Calcula o dano total
    local totalDamage = self.playerManager.state:getTotalDamage(weaponBaseDamage)

    -- Calcula crítico
    local isCritical = math.random() <= self.playerManager.state:getTotalCritChance()
    if isCritical then
        totalDamage = math.floor(totalDamage * self.playerManager.state:getTotalCritDamage())
    end

    -- Aplica o dano
    return target:takeDamage(totalDamage, isCritical)
end

--- Desenha os elementos visuais da habilidade.
function CircularSmash:draw()
    if not self.area then return end

    -- Desenha preview (círculo no ponto de impacto futuro)
    if self.visual.preview.active then
        -- Calcula onde o centro do preview estaria usando o raio BASE
        local previewImpactDist = self.area.radius
        local previewCenterX = self.area.position.x + math.cos(self.area.angle) * previewImpactDist
        local previewCenterY = self.area.position.y + math.sin(self.area.angle) * previewImpactDist
        -- Desenha o círculo de preview com o raio BASE
        self:drawPreviewCircleAt(self.visual.preview.color, previewCenterX, previewCenterY, self.area.radius)
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
