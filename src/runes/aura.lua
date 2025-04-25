--[[
    Aura Ability
    Uma aura que causa dano aos inimigos próximos periodicamente
]]

local Aura = {}

Aura.name = "Aura de Dano"
Aura.description = "Causa dano aos inimigos próximos periodicamente"
Aura.cooldown = 1 -- Tempo entre cada pulso de dano
Aura.damage = 50
Aura.damageType = "aura"
Aura.color = {0.8, 0, 0.8, 0.03} -- Cor roxa suave para a aura base

Aura.radius = 100 -- Raio da aura
Aura.pulseDuration = 0.3 -- Duração do pulso visual
Aura.shadowOffset = 3 -- Deslocamento da sombra
Aura.shadowAlpha = 0.2 -- Transparência da sombra

-- Configuração da onda de choque
Aura.shockwave = {
    currentRadius = 0,
    maxRadius = Aura.radius,
    duration = 0.5, -- Duração total da animação
    timer = 0,
    thickness = 4, -- Espessura da linha
    isActive = false,
    alpha = 0.8,
    particleCount = 32, -- Número de partículas no círculo
    particleSize = 3 -- Tamanho das partículas
}

function Aura:init(playerManager)
    self.playerManager = playerManager
    self.cooldownRemaining = 0
    
    -- Estado da aura
    self.aura = {
        active = false,
        pulseTime = 0,
        pulseActive = false
    }
end

function Aura:update(dt, enemies)
    if self.cooldownRemaining > 0 then
        self.cooldownRemaining = math.max(0, self.cooldownRemaining - dt)
    end
    
    -- Atualiza a onda de choque
    if self.shockwave.isActive then
        self.shockwave.timer = self.shockwave.timer + dt
        local progress = self.shockwave.timer / self.shockwave.duration
        
        if progress <= 1 then
            -- Easing quadrático para suavizar o movimento
            local easeProgress = progress * (2 - progress)
            self.shockwave.currentRadius = self.shockwave.maxRadius * easeProgress
            self.shockwave.alpha = 0.8 * (1 - progress)
        else
            self.shockwave.isActive = false
            self.shockwave.currentRadius = 0
            self.shockwave.timer = 0
        end
    end
    
    if self.aura.active then
        -- Verifica se é hora de causar dano
        if self.cooldownRemaining <= 0 then
            -- Inicia a onda de choque
            self.shockwave.isActive = true
            self.shockwave.currentRadius = 0
            self.shockwave.timer = 0
            
            -- Aplica o dano
            self:applyAuraDamage(enemies)
            
            -- Reseta o cooldown
            self.cooldownRemaining = self.cooldown
        end
    end
end

function Aura:draw()
    if self.aura.active then
        local playerX = self.playerManager.player.position.x
        local playerY = self.playerManager.player.position.y + 25 -- Ajusta para ficar nos pés do sprite
        
        -- Desenha um círculo base semi-transparente
        love.graphics.setColor(self.color)
        love.graphics.circle("fill", playerX, playerY, self.radius)
        
        -- Desenha a onda de choque
        if self.shockwave.isActive then
            -- Salva a largura da linha atual
            local previousLineWidth = love.graphics.getLineWidth()
            
            -- Desenha o círculo principal da onda
            love.graphics.setColor(0.8, 0, 0.8, self.shockwave.alpha)
            love.graphics.setLineWidth(self.shockwave.thickness)
            love.graphics.circle("line", playerX, playerY, self.shockwave.currentRadius)
            
            -- Desenha partículas ao redor do círculo
            local angleStep = (2 * math.pi) / self.shockwave.particleCount
            for i = 1, self.shockwave.particleCount do
                local angle = i * angleStep
                local particleX = playerX + math.cos(angle) * self.shockwave.currentRadius
                local particleY = playerY + math.sin(angle) * self.shockwave.currentRadius
                
                -- Partículas maiores no início da onda
                local particleScale = 1 - (self.shockwave.timer / self.shockwave.duration)
                local currentParticleSize = self.shockwave.particleSize * particleScale
                
                love.graphics.circle("fill", particleX, particleY, currentParticleSize)
            end
            
            -- Restaura a largura da linha anterior
            love.graphics.setLineWidth(previousLineWidth)
        end
    end
end

function Aura:cast()
    if self.cooldownRemaining > 0 then return false end
    
    -- Ativa a aura
    self.aura.active = true
    self.shockwave.isActive = true
    self.shockwave.currentRadius = 0
    self.shockwave.timer = 0
    
    return true
end

function Aura:applyDamage(target)
    if not target or not target.takeDamage then return false end
    return target:takeDamage(self.damage)
end

function Aura:applyAuraDamage(enemies)
    if not enemies then return end
    
    for _, enemy in ipairs(enemies) do
        if enemy.isAlive then
            local dx = enemy.position.x - self.playerManager.player.position.x
            local dy = enemy.position.y - self.playerManager.player.position.y
            local distance = math.sqrt(dx * dx + dy * dy)
            
            if distance <= self.radius then
                self:applyDamage(enemy)
            end
        end
    end
end

return Aura 