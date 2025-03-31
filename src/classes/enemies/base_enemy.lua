local FloatingTextManager = require("src.managers.floating_text_manager")

local BaseEnemy = {
    positionX = 0,
    positionY = 0,
    radius = 8,
    speed = 70,
    maxHealth = 50,
    currentHealth = 50,
    isAlive = true,
    damage = 10,
    lastDamageTime = 0,
    damageCooldown = 1,
    color = {1, 0, 0}, -- Cor padrão vermelha
    name = "BaseEnemy"
}

function BaseEnemy:new(x, y)
    local enemy = setmetatable({}, { __index = self })
    enemy.positionX = x
    enemy.positionY = y
    enemy.currentHealth = enemy.maxHealth
    enemy.isAlive = true
    enemy.lastDamageTime = 0
    
    -- Variação aleatória no dano (±20%)
    local damageVariation = 0.8 + math.random() * 0.4
    enemy.damage = math.floor(self.damage * damageVariation)
    
    return enemy
end

function BaseEnemy:update(dt, player, enemies)
    if not self.isAlive then return end
    
    -- Calcula a direção para o jogador
    local dx = player.positionX - self.positionX
    local dy = player.positionY - self.positionY
    
    -- Normaliza o vetor de direção
    local length = math.sqrt(dx * dx + dy * dy)
    if length > 0 then
        dx = dx / length
        dy = dy / length
    end
    
    -- Calcula a nova posição
    local newX = self.positionX + dx * self.speed * dt
    local newY = self.positionY + dy * self.speed * dt
    
    -- Verifica colisão com outros inimigos
    local canMove = true
    for _, other in ipairs(enemies) do
        if other ~= self and other.isAlive then
            local distance = math.sqrt(
                (other.positionX - newX) * (other.positionX - newX) + 
                (other.positionY - newY) * (other.positionY - newY)
            )
            
            if distance < (self.radius + other.radius) then
                canMove = false
                break
            end
        end
    end
    
    -- Só move se não houver colisão
    if canMove then
        self.positionX = newX
        self.positionY = newY
    end
    
    -- Verifica colisão com o jogador
    self:checkPlayerCollision(dt, player)
end

function BaseEnemy:checkPlayerCollision(dt, player)
    self.lastDamageTime = self.lastDamageTime + dt
    
    if self.lastDamageTime >= self.damageCooldown then
        local dx = player.positionX - self.positionX
        local dy = player.positionY - self.positionY
        local distance = math.sqrt(dx * dx + dy * dy)
        
        if distance <= (self.radius + player.radius) then
            if player:takeDamage(self.damage) then
                self.isAlive = false
            end
            
            FloatingTextManager:addText(
                player.positionX,
                player.positionY - player.radius - 10,
                "-" .. tostring(self.damage),
                false,
                player,
                {1, 0, 0}
            )
            
            self.lastDamageTime = 0
        end
    end
end

function BaseEnemy:draw()
    if not self.isAlive then return end
    
    -- Desenha o corpo do inimigo
    love.graphics.setColor(self.color)
    love.graphics.circle("fill", self.positionX, self.positionY, self.radius)
    
    -- Desenha a barra de vida
    local healthBarWidth = 30
    local healthBarHeight = 4
    local healthPercentage = self.currentHealth / self.maxHealth
    
    -- Fundo da barra de vida
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", 
        self.positionX - healthBarWidth/2, 
        self.positionY - self.radius - 8,
        healthBarWidth, 
        healthBarHeight
    )
    
    -- Barra de vida
    love.graphics.setColor(self.color)
    love.graphics.rectangle("fill", 
        self.positionX - healthBarWidth/2, 
        self.positionY - self.radius - 8,
        healthBarWidth * healthPercentage, 
        healthBarHeight
    )
end

function BaseEnemy:takeDamage(damage, isCritical)
    self.currentHealth = self.currentHealth - damage
    
    FloatingTextManager:addText(
        self.positionX,
        self.positionY - self.radius - 10,
        tostring(damage),
        isCritical,
        self
    )
    
    if self.currentHealth <= 0 then
        self.currentHealth = 0
        self.isAlive = false
        return true
    end
    return false
end

return BaseEnemy 