--[[
    Linear Projectile Ability
    A linear projectile attack that travels in a straight line
]]

local BaseAbility = require("src.abilities.player._base_ability")
local Camera = require("src.config.camera")

local LinearProjectile = {
    name = "Linear Projectile",
    description = "Um projétil que viaja em linha reta",
    cooldown = 0.5,
    damageType = "physical",
    visual = {
        preview = {
            color = {0, 0.5, 1, 0.3}, -- Cor da prévia (azul semi-transparente)
        },
        attack = {
            color = {0, 0.2, 1, 0.5}, -- Cor do ataque (azul mais intenso)
            animationDuration = 0.2, -- Duração da animação em segundos
        }
    }
}

function LinearProjectile:init(owner)
    self.owner = owner
    self.cooldownRemaining = 0
    self.visualEnabled = true
    self.isAttacking = false
    self.attackProgress = 0
    self.area = nil
end

function LinearProjectile:update(dt)
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
            self.visualEnabled = false
        end
    end
end

function LinearProjectile:cast(x, y)
    if self.cooldownRemaining > 0 then
        return false
    end
    
    -- Calcula a direção do ataque
    local dx = x - self.owner.player.x
    local dy = y - self.owner.player.y
    local angle = math.atan2(dy, dx)
    
    -- Define a área do projétil
    self.area = {
        x = self.owner.player.x,
        y = self.owner.player.y,
        angle = angle,
        range = self.range
    }
    
    -- Inicia a animação do ataque
    self.isAttacking = true
    self.attackProgress = 0
    self.visualEnabled = true
    
    -- Aplica o cooldown baseado na velocidade de ataque
    self.cooldownRemaining = self.cooldown / self.attackSpeed
    
    return true
end

function LinearProjectile:isPointInArea(x, y)
    if not self.area then return false end
    
    -- Calcula a distância do ponto à linha do projétil
    local dx = x - self.area.x
    local dy = y - self.area.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    -- Verifica se está dentro do alcance
    if distance > self.range then
        return false
    end
    
    -- Calcula o ângulo do ponto em relação ao centro do projétil
    local pointAngle = math.atan2(dy, dx)
    local angleDiff = math.abs((pointAngle - self.area.angle + math.pi) % (2 * math.pi) - math.pi)
    
    -- Verifica se está dentro da largura do projétil
    return angleDiff <= math.pi / 12 -- 15 graus
end

function LinearProjectile:applyDamage(target)
    if not self.area then return false end
    
    if self:isPointInArea(target.positionX, target.positionY) then
        return target:takeDamage(self.damage)
    end
    
    return false
end

function LinearProjectile:draw()
    if not self.area then return end
    
    -- Desenha a prévia do projétil se não estiver atacando
    if not self.isAttacking and self.visualEnabled then
        self:drawProjectile(self.visual.preview.color)
    end
    
    -- Desenha a animação do ataque
    if self.isAttacking then
        self:drawProjectile(self.visual.attack.color)
    end
end

function LinearProjectile:drawProjectile(color)
    -- Configura a cor
    love.graphics.setColor(color)
    
    -- Calcula a posição inicial (centro do jogador)
    local startX = self.owner.player.x
    local startY = self.owner.player.y
    
    -- Calcula a posição final (baseado no alcance e ângulo)
    local endX = startX + math.cos(self.area.angle) * self.range
    local endY = startY + math.sin(self.area.angle) * self.range
    
    -- Desenha a linha do projétil
    love.graphics.line(startX, startY, endX, endY)
    
    -- Desenha o círculo no final
    love.graphics.circle("fill", endX, endY, 5)
end

function LinearProjectile:getCooldownRemaining()
    return self.cooldownRemaining
end

function LinearProjectile:toggleVisual()
    if not self.isAttacking then
        self.visualEnabled = not self.visualEnabled
    end
end

function LinearProjectile:getVisual()
    return self.visualEnabled
end

return LinearProjectile