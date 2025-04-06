--[[
    Enemy Projectile Ability
    A projectile ability specifically designed for ranged enemies
]]

local BaseAbility = require("src.abilities.base_ability")

local EnemyProjectile = setmetatable({}, { __index = BaseAbility })

EnemyProjectile.name = "Enemy Projectile"
EnemyProjectile.cooldown = 1.5
EnemyProjectile.damage = 30
EnemyProjectile.damageType = "enemy_projectile"
EnemyProjectile.color = {1, 0.2, 0.2, 1} -- Cor vermelha para diferenciar dos projéteis do jogador

EnemyProjectile.speed = 180
EnemyProjectile.maxDistance = 400

function EnemyProjectile:init(owner)
    BaseAbility.init(self, owner)
    
    self.projectile = {
        active = false,
        x = 0,
        y = 0,
        angle = 0,
        distance = 0,
        radius = 6
    }
end

function EnemyProjectile:update(dt)
    BaseAbility.update(self, dt)
    
    if self.projectile.active then
        local dx = math.cos(self.projectile.angle) * self.speed * dt
        local dy = math.sin(self.projectile.angle) * self.speed * dt
        
        self.projectile.x = self.projectile.x + dx
        self.projectile.y = self.projectile.y + dy
        self.projectile.distance = self.projectile.distance + math.sqrt(dx * dx + dy * dy)
        
        -- Verifica colisão apenas com o jogador
        if self.owner.player then
            local player = self.owner.player
            local dx = player.positionX - self.projectile.x
            local dy = player.positionY - self.projectile.y
            local distance = math.sqrt(dx * dx + dy * dy)
            
            if distance <= (player.radius + self.projectile.radius) then
                if player:takeDamage(self.damage) then
                    self.projectile.active = false
                end
            end
        end
        
        if self.projectile.distance >= self.maxDistance then
            self.projectile.active = false
        end
    end
end

function EnemyProjectile:draw()
    if self.projectile.active then
        love.graphics.setColor(self.color)
        love.graphics.circle("fill", self.projectile.x, self.projectile.y, self.projectile.radius)
    end
end

function EnemyProjectile:cast(targetX, targetY)
    if self.cooldownRemaining > 0 then return false end
    
    local dx = targetX - self.owner.positionX
    local dy = targetY - self.owner.positionY
    local angle = math.atan2(dy, dx)
    
    self.projectile.active = true
    self.projectile.x = self.owner.positionX
    self.projectile.y = self.owner.positionY
    self.projectile.angle = angle
    self.projectile.distance = 0
    
    self.cooldownRemaining = self.cooldown
    
    return true
end

return EnemyProjectile 