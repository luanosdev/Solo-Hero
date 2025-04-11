--[[
    Aura Ability
    Uma aura que causa dano aos inimigos próximos periodicamente
]]

local BaseAbility = require("src.abilities.player._base_ability")

local Aura = setmetatable({}, { __index = BaseAbility })

Aura.name = "Aura de Dano"
Aura.description = "Causa dano aos inimigos próximos periodicamente"
Aura.cooldown = 1-- Tempo entre cada pulso de dano
Aura.damage = 20
Aura.damageType = "aura"
Aura.color = {1, 0.5, 0, 0.2} -- Cor laranja para a aura

Aura.radius = 100 -- Raio da aura
Aura.pulseDuration = 0.3 -- Duração do pulso visual

function Aura:init(owner)
    BaseAbility.init(self, owner)
    
    -- Estado da aura
    self.aura = {
        active = false,
        pulseTime = 0,
        pulseActive = false
    }
end

function Aura:update(dt)
    BaseAbility.update(self, dt)
    
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
            self:applyAuraDamage()
            
            -- Reseta o cooldown
            self.cooldownRemaining = self.cooldown
        end
    end
end

function Aura:draw()
    if self.aura.active then
        -- Desenha a aura base
        love.graphics.setColor(self.color)
        love.graphics.circle("fill", 
            self.owner.positionX, 
            self.owner.positionY, 
            self.radius
        )
        
        -- Desenha o pulso se estiver ativo
        if self.aura.pulseActive then
            local progress = self.aura.pulseTime / self.pulseDuration
            local pulseRadius = self.radius * (1 + progress * 0.2) -- Aumenta 20% durante o pulso
            local alpha = 1 - progress
            
            love.graphics.setColor(self.color[1], self.color[2], self.color[3], self.color[4] * alpha)
            love.graphics.circle("line", 
                self.owner.positionX, 
                self.owner.positionY, 
                pulseRadius
            )
        end
    end
end

function Aura:cast()
    if not BaseAbility.cast(self, self.owner.positionX, self.owner.positionY) then return false end
    
    -- Ativa a aura
    self.aura.active = true
    self.aura.pulseActive = true
    self.aura.pulseTime = 0
    
    return true
end

function Aura:applyAuraDamage()
    if not self.owner.world or not self.owner.world.enemies then return end
    
    for _, enemy in ipairs(self.owner.world.enemies) do
        if enemy.isAlive then
            local dx = enemy.positionX - self.owner.positionX
            local dy = enemy.positionY - self.owner.positionY
            local distance = math.sqrt(dx * dx + dy * dy)
            
            if distance <= self.radius then
                self:applyDamage(enemy)
            end
        end
    end
end

function Aura:toggleVisual()
    self.aura.active = not self.aura.active
    if self.aura.active then
        self:cast()
    end
end

return Aura 