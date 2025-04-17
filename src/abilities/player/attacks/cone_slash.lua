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
            lineLength = 50 -- Comprimento da linha de preview
        },
        attack = {
            segments = 20,
            animationDuration = 0.2 -- Duração da animação em segundos
        }
    }
}

function ConeSlash:init(playerManager)
    self.playerManager = playerManager
    self.cooldownRemaining = 0
    self.isAttacking = false
    self.attackProgress = 0

    -- Usa as cores da arma se disponíveis
    self.visual.preview.color = self.previewColor or {0.7, 0.7, 0.7, 0.2}
    self.visual.attack.color = self.attackColor or {1, 0.302, 0.302, 0.6}

    -- Usa os atributos da arma
    local weapon = self.playerManager.equippedWeapon
    self.area = {
        position = {
            x = self.playerManager.player.position.x,
            y = self.playerManager.player.position.y
        },
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
        self.area.position = self.playerManager.player.position

        local mouseX, mouseY = love.mouse.getPosition()
        local worldX, worldY = Camera:screenToWorld(mouseX, mouseY)

        local dx = worldX - self.area.position.x
        local dy = worldY - self.area.position.y
        self.area.angle = math.atan2(dy, dx)
    end
end

function ConeSlash:cast(enemies)
    if self.cooldownRemaining > 0 then
        return false
    end
    
    -- Inicia a animação do ataque
    self.isAttacking = true
    self.attackProgress = 0
    
    -- Aplica o cooldown baseado na velocidade de ataque do player
    local attackSpeed = self.playerManager.state:getTotalAttackSpeed()
    self.cooldownRemaining = self.cooldown / attackSpeed
    
    -- Calcula o número de ataques extras
    local multiAttackChance = self.playerManager.state:getTotalMultiAttackChance()
    local extraAttacks = math.floor(multiAttackChance)
    local decimalChance = multiAttackChance - extraAttacks
    
    -- Primeiro ataque sempre ocorre
    local success = self:executeAttack(enemies)
    
    -- Executa ataques extras
    for i = 1, extraAttacks do
        if success then
            success = self:executeAttack(enemies)
        end
    end
    
    -- Chance de ataque extra baseado no decimal
    if success and decimalChance > 0 and math.random() < decimalChance then
        self:executeAttack(enemies)
    end
    
    return success
end

-- Função auxiliar para executar um único ataque
function ConeSlash:executeAttack(enemies)
    -- Verifica colisão com inimigos
    local enemiesHit = 0
    local totalEnemies = 0
    
    for _, enemy in ipairs(enemies) do
        if enemy.isAlive then
            totalEnemies = totalEnemies + 1
            -- Verifica se o inimigo está dentro da área de ataque usando isPointInArea
            local isInArea = self:isPointInArea(enemy.position)
            
            if isInArea then
                enemiesHit = enemiesHit + 1
                -- Aplica o dano e verifica se o inimigo morreu
                self:applyDamage(enemy)
            end
        end
    end
    
    return true
end

function ConeSlash:isPointInArea(position)
    if not self.area then return false end
    if not self.area then return false end

    -- Transforma ambos para espaço isométrico
    local px, py = position.x, position.y * 2
    local ox, oy = self.area.position.x, self.area.position.y * 2

    local dx, dy = px - ox, py - oy
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance > self.area.range then return false end

    local pointAngle = math.atan2(dy, dx)
    local coneAngle = self.area.angle

    -- Normaliza e calcula diferença angular
    local diff = math.abs((pointAngle - coneAngle + math.pi) % (2 * math.pi) - math.pi)

    local tolerance = math.rad(5)
    return diff <= (self.area.angleWidth / 2 + tolerance)
end

function ConeSlash:applyDamage(target)
    if not self.area then return false end
    
    if self:isPointInArea(target.position) then
        -- Obtém o dano base da arma
        local weaponDamage = self.playerManager.equippedWeapon.damage

        
        -- Calcula o dano total com os bônus do player
        local totalDamage = self.playerManager.state:getTotalDamage(weaponDamage)

        
        -- Calcula se o dano é crítico
        local isCritical = math.random() <= self.playerManager.state:getTotalCriticalChance() / 100
        if isCritical then
            totalDamage = math.floor(totalDamage * self.playerManager.state:getTotalCriticalMultiplier())
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
    
    -- Desenha a prévia da linha se ativa
    if self.visual.preview.active then
        self:drawPreviewLine()
    end
    
    -- Desenha a animação do ataque
    if self.isAttacking then
        self:drawCone(self.visual.attack.color, self.attackProgress)
    end
end

function ConeSlash:drawPreviewLine()
    -- Configura a cor da linha de preview
    love.graphics.setColor(1, 1, 1, 0.5) -- Branco semi-transparente
    
    -- Salva o estado atual de transformação
    love.graphics.push()
    
    -- Translada para a posição do jogador
    love.graphics.translate(self.area.x, self.area.y)
    
    -- Aplica a transformação isométrica
    love.graphics.scale(1, 0.5)
    
    -- Desenha a linha na direção do mouse
    love.graphics.line(
        0, 0,
        math.cos(self.area.angle) * self.visual.preview.lineLength,
        math.sin(self.area.angle) * self.visual.preview.lineLength
    )
    
    -- Restaura o estado de transformação
    love.graphics.pop()
end

function ConeSlash:drawCone(color, progress)
    -- Configura a cor
    love.graphics.setColor(color)
    
    -- Salva o estado atual de transformação
    love.graphics.push()
    
    -- Translada para a posição do cone
    love.graphics.translate(self.area.position.x, self.area.position.y)
    
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