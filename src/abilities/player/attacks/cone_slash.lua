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
        angle = 0, -- Ângulo inicializado, será atualizado pelo PlayerManager
        range = weapon.range + self.playerManager.state:getTotalRange(), -- Usa o range da arma + bônus do player
        angleWidth = weapon.angle + self.playerManager.state:getTotalArea() -- Usa o ângulo da arma + bônus do player
    }
end

function ConeSlash:update(dt, angle)
    -- Atualiza cooldown
    if self.cooldownRemaining > 0 then
        self.cooldownRemaining = self.cooldownRemaining - dt
    end

    -- Atualiza a posição do cone para seguir o jogador
    if self.area then
        self.area.position = self.playerManager.player.position
        self.area.angle = angle
    end

    
    -- Atualiza animação do ataque
    if self.isAttacking then
        self.attackProgress = self.attackProgress + (dt / self.visual.attack.animationDuration)
        if self.attackProgress >= 1 then
            self.isAttacking = false
            self.attackProgress = 0
        end
    end

end

function ConeSlash:cast()
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
    local success = self:executeAttack()
    
    -- Executa ataques extras
    for i = 1, extraAttacks do
        if success then
            success = self:executeAttack()
        end
    end
    
    -- Chance de ataque extra baseado no decimal
    if success and decimalChance > 0 and math.random() < decimalChance then
        self:executeAttack()
    end
    
    return success
end

-- Função auxiliar para executar um único ataque
function ConeSlash:executeAttack()
    -- Busca os inimigos diretamente do EnemyManager
    local enemies = self.playerManager.enemyManager:getEnemies()
    
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

    local dx, dy = position.x - self.area.position.x, position.y - self.area.position.y
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
    
    -- Desenha a linha na direção do mouse
    love.graphics.line(
        self.area.position.x, 
        self.area.position.y,
        self.area.position.x + math.cos(self.area.angle) * self.visual.preview.lineLength,
        self.area.position.y + math.sin(self.area.angle) * self.visual.preview.lineLength
    )
end

function ConeSlash:drawCone(color, progress)
    local innerRange = self.playerManager.radius * 1.5 -- Define o raio interno para remover a ponta
    local segments = 32 -- Número de segmentos para o arco

    -- Configura a cor base
    love.graphics.setColor(color)

    -- Posição central e raio externo
    local cx = self.area.position.x
    local cy = self.area.position.y
    local outerRange = self.area.range

    -- Calcula os ângulos do cone
    local startAngle = self.area.angle - self.area.angleWidth / 2
    local endAngle = self.area.angle + self.area.angleWidth / 2

    -- Desenha a animação do preenchimento (slash) como um setor de anel
    if progress > 0 then
        local fillEndAngle = startAngle + (self.area.angleWidth * progress)
        local vertices = {}
        -- Evita divisão por zero ou número inválido de segmentos se o ângulo for mínimo
        local currentSegments = math.max(1, math.ceil(segments * progress)) 
        local angle_step = (fillEndAngle - startAngle) / currentSegments

        -- Vértices do arco externo (sentido horário)
        for i = 0, currentSegments do
            local angle = startAngle + i * angle_step
            table.insert(vertices, cx + outerRange * math.cos(angle))
            table.insert(vertices, cy + outerRange * math.sin(angle))
        end

        -- Vértices do arco interno (sentido anti-horário)
        for i = currentSegments, 0, -1 do
            local angle = startAngle + i * angle_step
            table.insert(vertices, cx + innerRange * math.cos(angle))
            table.insert(vertices, cy + innerRange * math.sin(angle))
        end

        -- Desenha o polígono preenchido (setor do anel)
        love.graphics.setColor(color[1], color[2], color[3], color[4] * 0.8)
        if #vertices >= 6 then -- Precisa de pelo menos 3 pontos (6 coordenadas) para um polígono
             love.graphics.polygon("fill", vertices)
        end

        -- Desenha uma linha mais intensa no final do preenchimento (entre raio interno e externo)
        love.graphics.setColor(color[1], color[2], color[3], color[4])
        love.graphics.line(
            cx + innerRange * math.cos(fillEndAngle),
            cy + innerRange * math.sin(fillEndAngle),
            cx + outerRange * math.cos(fillEndAngle),
            cy + outerRange * math.sin(fillEndAngle)
        )
    end

    -- Desenha as linhas do contorno do cone (setor do anel)
    love.graphics.setColor(color) -- Cor original completa

    -- Linha radial inicial
    love.graphics.line(
        cx + innerRange * math.cos(startAngle),
        cy + innerRange * math.sin(startAngle),
        cx + outerRange * math.cos(startAngle),
        cy + outerRange * math.sin(startAngle)
    )

    -- Linha radial final
    love.graphics.line(
        cx + innerRange * math.cos(endAngle),
        cy + innerRange * math.sin(endAngle),
        cx + outerRange * math.cos(endAngle),
        cy + outerRange * math.sin(endAngle)
    )

    -- Arco externo
    love.graphics.arc(
        "line",
        "open",
        cx, cy,
        outerRange,
        startAngle,
        endAngle,
        segments
    )

    -- Arco interno
    love.graphics.arc(
        "line",
        "open",
        cx, cy,
        innerRange,
        startAngle,
        endAngle,
        segments
    )
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