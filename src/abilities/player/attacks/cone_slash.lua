local EnemyManager = require("src.managers.enemy_manager")

--[[
    Cone Slash Ability
    A cone-shaped area of effect attack that serves as the character's primary attack method
]]

local Camera = require("src.config.camera")

local ConeSlash = {
    name = "Cone Slash",
    description = "Um ataque em cone que causa dano a todos os inimigos na área",
    cooldown = 0.5,
    damageType = "melee",
    angle = math.pi / 3, -- 60 graus
    visual = {
        preview = {
            active = false,
            segments = 20
        },
        attack = {
            segments = 20,
            animationDuration = 0.2 -- Duração da animação em segundos
        }
    }
}

function ConeSlash:init(owner)
    self.owner = owner
    self.cooldownRemaining = 0
    self.isAttacking = false
    self.attackProgress = 0
    
    -- Usa as cores da arma se disponíveis
    self.visual.preview.color = self.previewColor or {0.7, 0.7, 0.7, 0.2}
    self.visual.attack.color = self.attackColor or {1, 0.302, 0.302, 0.6}
    
    -- Usa os atributos da arma
    local weapon = owner.equippedWeapon
    self.area = {
        x = owner.player.x,
        y = owner.player.y,
        angle = 0,
        range = weapon.range, -- Usa o range da arma
        angleWidth = math.rad(90) -- Ângulo fixo de 90 graus
    }
end

function ConeSlash:update(dt)
    -- Atualiza cooldown
    if self.cooldownRemaining > 0 then
        self.cooldownRemaining = self.cooldownRemaining - dt
    end

    -- Atualiza animação do ataque
    if self.isAttacking then
        self.attackProgress = self.attackProgress + (dt / self.visual.attack.animationDuration)
        if self.attackProgress >= 1 then
            self.isAttacking = false
            self.attackProgress = 0
        end
    end

    -- Atualiza a posição do cone para seguir o jogador
    if self.area then
        self.area.x = self.owner.player.x
        self.area.y = self.owner.player.y -- Mantém o cone na mesma altura do jogador

        local mouseX, mouseY = love.mouse.getPosition()
        local worldX, worldY = Camera:screenToWorld(mouseX, mouseY)

        local dx = worldX - self.area.x
        local dy = worldY - self.area.y
        self.area.angle = math.atan2(dy, dx)
    end
end

function ConeSlash:cast(x, y)
    if self.cooldownRemaining > 0 then
        return false
    end
    
    -- Inicia a animação do ataque
    self.isAttacking = true
    self.attackProgress = 0
    
    -- Aplica o cooldown baseado na velocidade de ataque
    self.cooldownRemaining = self.cooldown / self.attackSpeed
    
    -- Calcula o número de ataques extras
    local multiAttackChance = self.owner.state:getTotalMultiAttackChance()
    local extraAttacks = math.floor(multiAttackChance)
    local decimalChance = multiAttackChance - extraAttacks
    
    -- Primeiro ataque sempre ocorre
    local success = self:executeAttack(x, y)
    
    -- Executa ataques extras
    for i = 1, extraAttacks do
        if success then
            success = self:executeAttack(x, y)
        end
    end
    
    -- Chance de ataque extra baseado no decimal
    if success and decimalChance > 0 and math.random() < decimalChance then
        self:executeAttack(x, y)
    end
    
    return success
end

-- Função auxiliar para executar um único ataque
function ConeSlash:executeAttack(x, y)
    -- Verifica colisão com inimigos
    local enemies = EnemyManager:getEnemies()
    local enemiesHit = 0
    local totalEnemies = 0
    
    for _, enemy in ipairs(enemies) do
        if enemy.isAlive then
            totalEnemies = totalEnemies + 1
            -- Verifica se o inimigo está dentro da área de ataque usando isPointInArea
            local isInArea = self:isPointInArea(enemy.positionX, enemy.positionY)
            
            if isInArea then
                enemiesHit = enemiesHit + 1
                -- Aplica o dano e verifica se o inimigo morreu
                self:applyDamage(enemy)
            end
        end
    end
    
    return true
end

function ConeSlash:isPointInArea(x, y)
    if not self.area then return false end
    
    -- Converte as coordenadas para o espaço isométrico
    local isoX = x - self.area.x
    local isoY = (y - self.area.y) * 2 -- Multiplica por 2 para compensar a escala isométrica
    
    -- Calcula a distância do ponto ao centro do cone
    local distance = math.sqrt(isoX * isoX + isoY * isoY)
    
    -- Verifica se está dentro do alcance
    if distance > self.area.range then
        return false
    end
    
    -- Calcula o ângulo do ponto em relação ao centro do cone
    local pointAngle = math.atan2(isoY, isoX)
    
    -- Normaliza os ângulos para o intervalo [0, 2π]
    local normalizedPointAngle = (pointAngle + 2 * math.pi) % (2 * math.pi)
    local normalizedConeAngle = (self.area.angle + 2 * math.pi) % (2 * math.pi)
    
    -- Calcula a diferença de ângulo
    local angleDiff = math.abs(normalizedPointAngle - normalizedConeAngle)
    if angleDiff > math.pi then
        angleDiff = 2 * math.pi - angleDiff
    end
    
    -- Verifica se está dentro do ângulo do cone
    return angleDiff <= self.area.angleWidth / 2
end

function ConeSlash:applyDamage(target)
    if not self.area then return false end
    
    if self:isPointInArea(target.positionX, target.positionY) then
        -- Obtém o dano da arma
        local weaponDamage = self.owner.equippedWeapon.damage
        
        -- Calcula o dano total com os bônus
        local totalDamage = self.owner.state:getTotalDamage(weaponDamage)
        
        -- Calcula se o dano é crítico
        local isCritical = math.random() <= self.owner.state:getTotalCriticalChance()
        if isCritical then
            totalDamage = math.floor(totalDamage * self.owner.state:getTotalCriticalMultiplier())
        end
        
        -- Aplica o dano
        return target:takeDamage(totalDamage, isCritical)
    end
    
    return false
end

function ConeSlash:draw()
    if not self.area then 
        error("[Erro] [ConeSlash.draw] Área não definida!")
        return
    end
    
    -- Desenha a prévia do cone se ativa
    if self.visual.preview.active then
        self:drawCone(self.visual.preview.color, 1)
    end
    
    -- Desenha a animação do ataque
    if self.isAttacking then
        self:drawCone(self.visual.attack.color, self.attackProgress)
    end
end

function ConeSlash:drawCone(color, progress)
    -- Configura a cor
    love.graphics.setColor(color)
    
    -- Salva o estado atual de transformação
    love.graphics.push()
    
    -- Translada para a posição do cone
    love.graphics.translate(self.area.x, self.area.y)
    
    -- Aplica a transformação isométrica
    love.graphics.scale(1, 0.5) -- Escala vertical para efeito isométrico
    
    -- Calcula os ângulos do cone
    local startAngle = self.area.angle - self.area.angleWidth / 2
    local endAngle = self.area.angle + self.area.angleWidth / 2
    
    -- Desenha o preenchimento do cone com animação de slash
    if progress > 0 then
        -- Calcula o ângulo de preenchimento baseado no progresso
        local fillEndAngle = startAngle + (self.area.angleWidth * progress)
        
        -- Desenha o setor circular preenchido
        love.graphics.setColor(color[1], color[2], color[3], color[4] * 0.8)
        love.graphics.arc(
            "fill",
            "pie",
            0, 0,
            self.area.range,
            startAngle,
            fillEndAngle,
            32 -- Número de segmentos para o arco
        )
        
        -- Desenha uma linha mais intensa no final do preenchimento
        love.graphics.setColor(color[1], color[2], color[3], color[4])
        love.graphics.line(
            0, 0,
            math.cos(fillEndAngle) * self.area.range,
            math.sin(fillEndAngle) * self.area.range
        )
    end
    
    -- Desenha as linhas do cone (contorno)
    love.graphics.setColor(color)
    love.graphics.line(
        0, 0,
        math.cos(startAngle) * self.area.range,
        math.sin(startAngle) * self.area.range
    )
    
    love.graphics.line(
        0, 0,
        math.cos(endAngle) * self.area.range,
        math.sin(endAngle) * self.area.range
    )
    
    -- Desenha o arco do cone
    love.graphics.arc(
        "line",
        "open",
        0, 0,
        self.area.range,
        startAngle,
        endAngle,
        32 -- Número de segmentos para o arco
    )
    
    -- Restaura o estado de transformação
    love.graphics.pop()
    
    -- Debug: Desenha um ponto no centro do cone
    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.circle("fill", self.area.x, self.area.y, 5)
end

function ConeSlash:getCooldownRemaining()
    return self.cooldownRemaining
end

function ConeSlash:togglePreview()
    self.visual.preview.active = not self.visual.preview.active
end

function ConeSlash:getPreview()
    return self.visual.preview.active
end

return ConeSlash