--[[
    Linear Projectile Ability
    Um projétil que se move em linha reta até uma distância máxima
]]

local BaseAbility = require("src.abilities.base_ability")
local EnemyManager = require("src.managers.enemy_manager")

local LinearProjectile = setmetatable({}, { __index = BaseAbility })

LinearProjectile.name = "Linear Projectile"
LinearProjectile.cooldown = 2.0
LinearProjectile.damage = 50
LinearProjectile.damageType = "projectile"
LinearProjectile.color = {1, 0.8, 0, 1}

LinearProjectile.projectileSpeed = 400
LinearProjectile.projectileRadius = 4

-- Estado do Projétil
LinearProjectile.projectile = {
    active = false,
    x = 0,
    y = 0,
    angle = 0,
    distanceTraveled = 0,
    maxDistance = 200 -- TODO: Alterar futuramente para compartilhar com RANGE do player (todas as habilidades)
}

function LinearProjectile:init(owner)
    BaseAbility.init(self, owner)
end

function LinearProjectile:update(dt)
    BaseAbility.update(self, dt)
    
    -- Atualiza o projétil se estiver ativo
    if self.projectile.active then
        -- Calcula o movimento do projétil
        local moveX = math.cos(self.projectile.angle) * self.projectileSpeed * dt
        local moveY = math.sin(self.projectile.angle) * self.projectileSpeed * dt
        
        -- Atualiza a posição
        self.projectile.x = self.projectile.x + moveX
        self.projectile.y = self.projectile.y + moveY
        
        -- Atualiza a distância percorrida
        self.projectile.distanceTraveled = self.projectile.distanceTraveled + 
            math.sqrt(moveX * moveX + moveY * moveY)
        
        -- Verifica colisão com inimigos
        local enemies = EnemyManager:getEnemies()
        for _, enemy in ipairs(enemies) do
            if enemy.isAlive then
                -- Calcula a distância entre o projétil e o inimigo
                local dx = enemy.positionX - self.projectile.x
                local dy = enemy.positionY - self.projectile.y
                local distance = math.sqrt(dx * dx + dy * dy)
                
                -- Se a distância for menor que a soma dos raios, houve colisão
                if distance <= (self.projectileRadius + enemy.radius) then
                    -- Aplica o dano usando o método da classe base
                    self:applyDamage(enemy)
                    
                    -- Desativa o projétil após atingir um inimigo
                    self.projectile.active = false
                    break
                end
            end
        end
        
        -- Desativa o projétil se atingiu a distância máxima
        if self.projectile.distanceTraveled >= self.projectile.maxDistance then
            self.projectile.active = false
        end
    end
end

function LinearProjectile:draw()
    -- Desenha a linha que o projétil irá percorrer
    if self.visual.active then
        -- Calcula o ponto final da linha baseado no ângulo e distância máxima
        local endX = self.owner.positionX + math.cos(self.visual.angle) * self.projectile.maxDistance
        local endY = self.owner.positionY + math.sin(self.visual.angle) * self.projectile.maxDistance
        
        -- Desenha a linha de mira
        love.graphics.setColor(self.color[1], self.color[2], self.color[3], 0.3)
        love.graphics.line(self.owner.positionX, self.owner.positionY, endX, endY)
    end

    -- Desenha o projétil se estiver ativo
    if self.projectile.active then
        love.graphics.setColor(self.color)
        love.graphics.circle("fill", self.projectile.x, self.projectile.y, self.projectileRadius)
    end
end

function LinearProjectile:isPointInArea(x, y)
    if not self.projectile.active then return false end
    
    -- Calcula o vetor do projétil
    local projX = self.projectile.x
    local projY = self.projectile.y
    local projAngle = self.projectile.angle
    
    -- Calcula o vetor do ponto alvo até o projétil
    local dx = x - projX
    local dy = y - projY
    
    -- Calcula a distância do ponto até o projétil
    local distance = math.sqrt(dx * dx + dy * dy)
    
    -- Se o ponto estiver muito longe, retorna falso
    if distance > self.projectile.maxDistance then return false end
    
    -- Calcula o ângulo entre o vetor do projétil e o vetor até o ponto
    local pointAngle = math.atan2(dy, dx)
    
    -- Normaliza os ângulos para 0-2π
    if pointAngle < 0 then pointAngle = pointAngle + 2 * math.pi end
    if projAngle < 0 then projAngle = projAngle + 2 * math.pi end
    
    -- Calcula a diferença entre os ângulos
    local angleDiff = math.abs(pointAngle - projAngle)
    if angleDiff > math.pi then
        angleDiff = 2 * math.pi - angleDiff
    end
    
    -- Se o ângulo for muito grande, o ponto não está na trajetória
    if angleDiff > math.pi/4 then return false end
    
    -- Calcula a distância perpendicular do ponto até a linha do projétil
    local perpendicularDist = distance * math.sin(angleDiff)
    
    -- Se a distância perpendicular for menor que o raio do projétil, está na trajetória
    return perpendicularDist <= self.projectileRadius
end

function LinearProjectile:cast(x, y)
    if not BaseAbility.cast(self, x, y) then return false end
    
    -- Calcula o ângulo do projétil
    local worldX = (x + camera.x) / camera.scale
    local worldY = (y + camera.y) / camera.scale
    local dx = worldX - self.owner.positionX
    local dy = worldY - self.owner.positionY
    self.projectile.angle = math.atan2(dy, dx)
    
    -- Inicializa o projétil
    self.projectile.x = self.owner.positionX
    self.projectile.y = self.owner.positionY
    self.projectile.distanceTraveled = 0
    self.projectile.active = true
    
    return true
end

return LinearProjectile