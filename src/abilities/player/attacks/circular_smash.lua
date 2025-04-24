--[[----------------------------------------------------------------------------
    Circular Smash Ability
    Um ataque que causa dano em uma área circular ao redor do jogador.
----------------------------------------------------------------------------]]--

local CircularSmash = {}

-- Configurações
CircularSmash.name = "Esmagamento Circular"
CircularSmash.description = "Golpeia o chão, causando dano em área circular."
CircularSmash.damageType = "melee" -- Ou talvez 'blunt'/'crushing' se tiver tipos específicos
CircularSmash.visual = {
    preview = {
        active = false,
        -- Preview poderia mostrar o círculo de alcance
    },
    attack = {
        animationDuration = 0.3 -- Duração da animação da onda de choque
    }
}

function CircularSmash:init(playerManager)
    self.playerManager = playerManager
    self.cooldownRemaining = 0
    self.isAttacking = false
    self.attackProgress = 0
    self.targetPos = { x = 0, y = 0 } -- Posição onde o último ataque foi direcionado

    -- Cores
    self.visual.preview.color = self.previewColor or {0.7, 0.7, 0.7, 0.2}
    self.visual.attack.color = self.attackColor or {0.8, 0.8, 0.7, 0.8}

    -- Atributos da arma
    local weapon = self.playerManager.equippedWeapon
    self.area = {
        position = {x = 0, y = 0}, -- Posição central DO JOGADOR (para referência)
        radius = weapon.range + self.playerManager.state:getTotalRange(), -- Raio do ataque
        -- 'angle' e 'angleWidth' não são usados aqui
    }
    self.baseDamage = weapon.damage
    self.baseCooldown = weapon.cooldown

    self.area.position = self.playerManager.player.position -- Define posição inicial
end

function CircularSmash:update(dt, angle) -- Angle é importante agora!
    -- Atualiza cooldown
    if self.cooldownRemaining > 0 then
        self.cooldownRemaining = self.cooldownRemaining - dt
    end

    -- Atualiza a posição E o ÂNGULO para seguir o jogador e a mira
    if self.area then
        self.area.position = self.playerManager.player.position
        self.area.angle = angle -- Guarda o ângulo da mira
        -- Recalcula raio caso bônus de range mudem
        self.area.radius = self.playerManager.equippedWeapon.range + self.playerManager.state:getTotalRange()
    end
    
    -- Atualiza animação do ataque
    if self.isAttacking then
        -- O ataque acontece em targetPos, a animação é desenhada lá.
        -- O progresso da animação é atualizado normalmente.
        self.attackProgress = self.attackProgress + (dt / self.visual.attack.animationDuration)
        if self.attackProgress >= 1 then
            self.isAttacking = false
            self.attackProgress = 0
        end
    end
end

-- Aceita tabela de args
function CircularSmash:cast(args)
    args = args or {}
    local angle = args.angle or 0 -- Ângulo necessário para calcular a posição do impacto

    if self.cooldownRemaining > 0 then
        return false
    end
    
    -- Calcula a posição do impacto (à frente do jogador, na direção do ângulo)
    local impactDist = self.area.radius 
    self.targetPos.x = self.area.position.x + math.cos(angle) * impactDist -- Usa 'angle' extraído
    self.targetPos.y = self.area.position.y + math.sin(angle) * impactDist -- Usa 'angle' extraído

    -- Inicia a animação
    self.isAttacking = true
    self.attackProgress = 0
    
    -- Aplica cooldown
    local attackSpeed = self.playerManager.state:getTotalAttackSpeed()
    self.cooldownRemaining = self.baseCooldown / attackSpeed
    
    -- Calcula ataques extras (multi-ataque)
    local multiAttackChance = self.playerManager.state:getTotalMultiAttackChance()
    local extraAttacks = math.floor(multiAttackChance)
    local decimalChance = multiAttackChance - extraAttacks
    
    -- Executa o ataque principal (centrado em targetPos)
    local success = self:executeAttack()
    
    -- Ataques extras: Poderia aumentar o raio ou causar um segundo pulso?
    -- Por simplicidade, vamos fazer multi-ataque aumentar o raio temporariamente para os golpes extras
    local originalRadius = self.area.radius
    local radiusMultiplier = 1.0

    for i = 1, extraAttacks do
        if success then
            radiusMultiplier = radiusMultiplier + 0.15 -- Aumenta o raio em 15% a cada golpe extra
            self.area.radius = originalRadius * radiusMultiplier
            success = self:executeAttack() -- Ataque extra ainda centrado no mesmo targetPos
        end
    end
    
    if success and decimalChance > 0 and math.random() < decimalChance then
        radiusMultiplier = radiusMultiplier + 0.15
        self.area.radius = originalRadius * radiusMultiplier
        self:executeAttack() -- Ataque extra ainda centrado no mesmo targetPos
    end

    -- Restaura o raio original após o cast
    self.area.radius = originalRadius
    
    return success
end

-- Executa um único pulso de ataque circular
function CircularSmash:executeAttack()
    local enemies = self.playerManager.enemyManager:getEnemies()
    local enemiesHit = 0
    
    for _, enemy in ipairs(enemies) do
        if enemy.isAlive then
            -- Verifica se o inimigo está dentro do raio
            if self:isPointInArea(enemy.position) then
                enemiesHit = enemiesHit + 1
                self:applyDamage(enemy)
            end
        end
    end
    
    -- TODO: Adicionar efeito sonoro de impacto?
    return true
end

-- Verifica se um ponto está dentro da área circular (centrada em targetPos)
function CircularSmash:isPointInArea(position)
    if not self.area then return false end

    -- Calcula distância do PONTO ALVO (targetPos), não do jogador
    local dx = position.x - self.targetPos.x 
    local dy = position.y - self.targetPos.y
    local distanceSq = dx * dx + dy * dy -- Compara quadrados para evitar sqrt
    
    return distanceSq <= self.area.radius * self.area.radius
end

function CircularSmash:applyDamage(target)    
    local totalDamage = self.playerManager.state:getTotalDamage(self.baseDamage)
    local isCritical = math.random() <= self.playerManager.state:getTotalCriticalChance() / 100
    
    if isCritical then
        totalDamage = math.floor(totalDamage * self.playerManager.state:getTotalCriticalMultiplier())
    end
    
    return target:takeDamage(totalDamage, isCritical)
end

function CircularSmash:draw()
    if not self.area then return end
    
    -- Desenha preview (mostra o círculo de alcance na frente do player)
    if self.visual.preview.active then
        -- Calcula onde o centro do preview estaria
        local previewCenterX = self.area.position.x + math.cos(self.area.angle) * self.area.radius
        local previewCenterY = self.area.position.y + math.sin(self.area.angle) * self.area.radius
        self:drawPreviewCircleAt(self.visual.preview.color, previewCenterX, previewCenterY)
    end
    
    -- Desenha animação do ataque (centrada em targetPos)
    if self.isAttacking then
        self:drawAttackCircle(self.visual.attack.color, self.attackProgress, self.targetPos.x, self.targetPos.y)
    end
end

-- Modificada para desenhar o preview em um ponto específico
function CircularSmash:drawPreviewCircleAt(color, centerX, centerY)
    love.graphics.setColor(color)
    love.graphics.circle("line", centerX, centerY, self.area.radius, 32)
end

function CircularSmash:drawAttackCircle(color, progress, centerX, centerY)
    local segments = 48
    local currentRadius = self.area.radius * progress -- Círculo expande com o progresso
    local alpha = color[4] * (1 - progress^2) -- Fade out da animação
    local thickness = 3 * (1 - progress) + 1 -- Linha fica mais fina ao expandir

    if currentRadius > 1 and alpha > 0.05 then
        love.graphics.setColor(color[1], color[2], color[3], alpha)
        love.graphics.setLineWidth(thickness)
        love.graphics.circle("line", centerX, centerY, currentRadius, segments)
        love.graphics.setLineWidth(1) -- Reseta espessura da linha
    end
end

function CircularSmash:getCooldownRemaining()
    return self.cooldownRemaining or 0
end

function CircularSmash:togglePreview()
    self.visual.preview.active = not self.visual.preview.active
end

function CircularSmash:getPreview()
    return self.visual.preview.active
end

return CircularSmash 