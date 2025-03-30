local Enemy = {
    -- Propriedades base
    name = "Enemy",
    maxHealth = 100,
    health = 100,
    positionX = 0,
    positionY = 0,
    speed = 100,
    size = 32,
    color = {1, 0, 0, 1}, -- Vermelho por padrão
    
    -- Estado
    isAlive = true,
    targetX = 0,
    targetY = 0,
    
    -- Habilidades
    abilities = {},
    
    -- Métodos
    init = function(self, x, y)
        -- Inicializa as propriedades básicas
        self.positionX = x
        self.positionY = y
        self.health = self.maxHealth
        self.isAlive = true
        
        self.targetX = x
        self.targetY = y
        self.abilities = {}
        
        -- Inicializa as habilidades
        self:initAbilities()
    end,
    
    update = function(self, dt)
        if not self.isAlive then return end
        
        -- Atualiza posição em direção ao alvo
        local dx = self.targetX - self.positionX
        local dy = self.targetY - self.positionY
        local distance = math.sqrt(dx * dx + dy * dy)
        
        -- Se estiver longe do alvo, move em sua direção
        if distance > 1 then
            local moveX = (dx / distance) * self.speed * dt
            local moveY = (dy / distance) * self.speed * dt
            self.positionX = self.positionX + moveX
            self.positionY = self.positionY + moveY
        end
        
        -- Atualiza habilidades
        for _, ability in ipairs(self.abilities) do
            ability:update(dt)
        end
    end,
    
    draw = function(self)
        if not self.isAlive then return end
        
        -- Desenha o inimigo
        love.graphics.setColor(self.color)
        love.graphics.circle("fill", self.positionX, self.positionY, self.size/2)
        
        -- Desenha a barra de vida
        local healthBarWidth = self.size
        local healthBarHeight = 4
        local healthPercentage = self.health / self.maxHealth
        
        -- Fundo da barra de vida
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("fill", 
            self.positionX - healthBarWidth/2,
            self.positionY - self.size/2 - 10,
            healthBarWidth,
            healthBarHeight
        )
        
        -- Barra de vida atual
        love.graphics.setColor(0, 1, 0, 1)
        love.graphics.rectangle("fill", 
            self.positionX - healthBarWidth/2,
            self.positionY - self.size/2 - 10,
            healthBarWidth * healthPercentage,
            healthBarHeight
        )
        
        -- Desenha habilidades
        for _, ability in ipairs(self.abilities) do
            ability:draw()
        end
    end,
    
    takeDamage = function(self, damage)
        self.health = math.max(0, self.health - damage)
        if self.health <= 0 then
            self.isAlive = false
        end
    end,
    
    setTarget = function(self, x, y)
        self.targetX = x
        self.targetY = y
    end,
    
    initAbilities = function(self)
        -- Será sobrescrito pelas classes específicas
    end
}

return Enemy 