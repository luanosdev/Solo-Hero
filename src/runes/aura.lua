--[[
    Aura Ability
    Uma aura que causa dano aos inimigos próximos periodicamente
]]

local Aura = {}

Aura.name = "Aura de Dano"
Aura.description = "Causa dano aos inimigos próximos periodicamente"
Aura.cooldown = 1 -- Tempo entre cada pulso de dano
Aura.damage = 10
Aura.damageType = "aura"
Aura.color = {1, 0.5, 0, 0.2} -- Cor laranja para a aura

Aura.radius = 100 -- Raio da aura
Aura.pulseDuration = 0.3 -- Duração do pulso visual
Aura.shadowOffset = 3 -- Deslocamento da sombra
Aura.shadowAlpha = 0.2 -- Transparência da sombra

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
    
    if self.aura.active then
        -- Atualiza o pulso visual
        if self.aura.pulseActive then
            self.aura.pulseTime = self.aura.pulseTime + dt
            if self.aura.pulseTime >= self.pulseDuration then
                self.aura.pulseActive = false
            end
        end
        
        -- Verifica se é hora de causar dano
        if self.cooldownRemaining <= 0 then
            -- Ativa o pulso visual antes de aplicar o dano
            self.aura.pulseActive = true
            self.aura.pulseTime = 0
            
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
        
        -- Desenha a sombra da aura
        love.graphics.setColor(0, 0, 0, self.shadowAlpha)
        love.graphics.circle("fill", 
            playerX + self.shadowOffset, 
            playerY + self.shadowOffset, 
            self.radius
        )
        
        -- Desenha a aura base
        love.graphics.setColor(self.color)
        love.graphics.circle("fill", 
            playerX, 
            playerY, 
            self.radius
        )
        
        -- Desenha o pulso se estiver ativo
        if self.aura.pulseActive then
            local progress = self.aura.pulseTime / self.pulseDuration
            local pulseRadius = self.radius * (1 + progress * 0.2) -- Aumenta 20% durante o pulso
            local alpha = 1 - progress
            
            love.graphics.setColor(self.color[1], self.color[2], self.color[3], self.color[4] * alpha)
            love.graphics.circle("line", 
                playerX, 
                playerY, 
                pulseRadius
            )
        end
    end
end

function Aura:cast()
    if self.cooldownRemaining > 0 then return false end
    
    -- Ativa a aura
    self.aura.active = true
    self.aura.pulseActive = true
    self.aura.pulseTime = 0
    
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