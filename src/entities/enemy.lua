local FloatingTextManager = require("src.managers.floating_text_manager")

local Enemy = {
    positionX = 0,
    positionY = 0,
    radius = 8,
    speed = 70,
    maxHealth = 50,
    currentHealth = 50,
    isAlive = true,
    criticalChance = 0.15 -- 15% de chance de crítico
}

function Enemy:new(x, y)
    local enemy = setmetatable({}, { __index = self })
    enemy.positionX = x
    enemy.positionY = y
    enemy.currentHealth = enemy.maxHealth
    enemy.isAlive = true
    return enemy
end

function Enemy:update(dt, playerX, playerY)
    if not self.isAlive then return end
    
    -- Calcula a direção para o jogador
    local dx = playerX - self.positionX
    local dy = playerY - self.positionY
    
    -- Normaliza o vetor de direção
    local length = math.sqrt(dx * dx + dy * dy)
    if length > 0 then
        dx = dx / length
        dy = dy / length
    end
    
    -- Move o inimigo em direção ao jogador
    self.positionX = self.positionX + dx * self.speed * dt
    self.positionY = self.positionY + dy * self.speed * dt
end

function Enemy:draw()
    if not self.isAlive then return end
    
    -- Desenha o corpo do inimigo
    love.graphics.setColor(1, 0, 0)
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
    love.graphics.setColor(1, 0, 0)
    love.graphics.rectangle("fill", 
        self.positionX - healthBarWidth/2, 
        self.positionY - self.radius - 8,
        healthBarWidth * healthPercentage, 
        healthBarHeight
    )
end

function Enemy:takeDamage(damage, isCritical)
    -- Aplica o dano
    self.currentHealth = self.currentHealth - damage
    
    -- Mostra o número de dano
    FloatingTextManager:addText(
        self.positionX,
        self.positionY - self.radius - 10,
        tostring(damage),
        isCritical,
        self -- Passa a referência do inimigo
    )
    
    if self.currentHealth <= 0 then
        self.currentHealth = 0
        self.isAlive = false
        return true -- Retorna true se o inimigo morreu
    end
    return false
end

return Enemy 