--[[
    Base Enemy
    Classe base para todos os tipos de inimigos
]]

local FloatingTextManager = require("src.managers.floating_text_manager")
local ExperienceOrbManager = require("src.managers.experience_orb_manager")
local PlayerManager = require("src.managers.player_manager")
local elements = require("src.ui.ui_elements")
local colors = require("src.ui.colors")

local BaseEnemy = {
    positionX = 0,
    positionY = 0,
    radius = 8,
    speed = 30,
    maxHealth = 50,
    currentHealth = 50,
    isAlive = true,
    damage = 10, -- Dano base do inimigo
    lastDamageTime = 0, -- Tempo do último dano causado
    damageCooldown = 1, -- Cooldown entre danos em segundos
    attackSpeed = 1,
    color = {1, 0, 0}, -- Cor padrão vermelha
    name = "BaseEnemy",
    experienceValue = 10, -- Experiência base para todos os inimigos
    healthBarWidth = 30 -- Largura padrão da barra de vida
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
    
    -- Obtém a posição de colisão do jogador
    local playerCollision = PlayerManager.getCollisionPosition()
    
    -- Calcula a direção para o jogador usando a posição de colisão
    local dx = playerCollision.x - self.positionX
    local dy = (playerCollision.y - self.positionY) * 2 -- Ajusta para o modo isométrico
    
    -- Normaliza o vetor de direção
    local length = math.sqrt(dx * dx + dy * dy)
    if length > 0 then
        dx = dx / length
        dy = dy / length
    end
    
    -- Calcula a nova posição
    local newX = self.positionX + dx * self.speed * dt
    local newY = self.positionY + dy * self.speed * dt
    
    -- Verifica se a nova posição colide com algum outro inimigo
    local canMove = true

    -- Verifica colisão com outros inimigos
    if canMove then
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
    end
    
    -- Só move se não houver colisão
    if canMove then
        self.positionX = newX
        self.positionY = newY
    end
    
    -- Verifica colisão com o jogador usando a posição de colisão
    self:checkPlayerCollision(dt, playerCollision)
end

function BaseEnemy:checkPlayerCollision(dt, playerCollision)
    -- Atualiza o tempo do último dano
    self.lastDamageTime = self.lastDamageTime + dt
    
    -- Calcula distância entre o inimigo e a posição de colisão do jogador
    local dx = playerCollision.x - self.positionX
    local dy = (playerCollision.y - self.positionY) * 2 -- Ajusta para o modo isométrico
    
    local distance = math.sqrt(dx * dx + dy * dy)

    -- Se houver colisão (distância menor que a soma dos raios)
    if distance <= (self.radius + playerCollision.radius) then
        -- Verifica se pode causar dano (cooldown)
        if self.lastDamageTime >= self.damageCooldown then
            -- Causa dano ao jogador usando o PlayerManager
            if PlayerManager.takeDamage(self.damage) then
                -- Se o jogador morreu, remove o inimigo
                self.isAlive = false
            end
            
            -- Mostra o número de dano
            FloatingTextManager:addText(
                playerCollision.x,
                playerCollision.y - playerCollision.radius - 10,
                "-" .. tostring(self.damage),
                false, -- Sempre falso pois inimigos não causam dano crítico
                PlayerManager.player,
                {1, 0, 0} -- Cor vermelha para dano ao jogador
            )
            
            -- Reseta o cooldown
            self.lastDamageTime = 0
        end
    end
end

function BaseEnemy:draw()
    if not self.isAlive then return end
    
    -- Desenha a barra de vida
    local healthBarWidth = self.healthBarWidth
    local healthBarHeight = 4
    local healthPercentage = self.currentHealth / self.maxHealth
    
    -- Fundo da barra de vida
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", 
        self.positionX - healthBarWidth/2, 
        self.positionY - 40,
        healthBarWidth, 
        healthBarHeight
    )
    
    -- Barra de vida
    love.graphics.setColor(1, 0, 0)
    love.graphics.rectangle("fill", 
        self.positionX - healthBarWidth/2, 
        self.positionY - 40,
        healthBarWidth * healthPercentage, 
        healthBarHeight
    )
end

function BaseEnemy:takeDamage(damage, isCritical)
    -- Aplica o dano
    self.currentHealth = self.currentHealth - damage
    
    -- Mostra o número de dano
    addFloatingText(
        self.positionX,
        self.positionY - self.radius - 10,
        tostring(damage),
        isCritical
    )
    
    if self.currentHealth <= 0 then
        self.currentHealth = 0
        
        -- Marca o inimigo como morto, mas não o remove ainda
        self.isAlive = false
        
        -- Dropa o orbe de experiência
        ExperienceOrbManager:addOrb(self.positionX, self.positionY, self.experienceValue)
        
        return true -- Retorna true se o inimigo morreu
    end
    return false
end

return BaseEnemy 