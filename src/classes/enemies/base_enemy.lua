--[[
    Base Enemy
    Classe base para todos os tipos de inimigos
]]

local FloatingTextManager = require("src.managers.floating_text_manager")
local ExperienceOrbManager = require("src.managers.experience_orb_manager")
local PlayerManager = require("src.managers.player_manager")

local BaseEnemy = {
    position = {
        x = 0,
        y = 0,
    },
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
    healthBarWidth = 30, -- Largura padrão da barra de vida
    id = 0 -- ID único do inimigo
}

function BaseEnemy:new(position, id)
    local enemy = {}
    setmetatable(enemy, { __index = self })
    
    -- Copia todas as propriedades base
    enemy.position = {
        x = position.x or 0,
        y = position.y or 0
    }
    enemy.radius = self.radius
    enemy.speed = self.speed
    enemy.maxHealth = self.maxHealth
    enemy.currentHealth = self.maxHealth
    enemy.isAlive = true
    enemy.damage = self.damage
    enemy.lastDamageTime = 0
    enemy.damageCooldown = self.damageCooldown
    enemy.attackSpeed = self.attackSpeed
    enemy.color = self.color
    enemy.name = self.name
    enemy.id = id or 0 -- Atribui o ID fornecido ou usa 0 como fallback
    enemy.experienceValue = self.experienceValue
    enemy.healthBarWidth = self.healthBarWidth

    print(string.format("BaseEnemy criado com ID: %d", enemy.id)) -- Log para debug
    
    return enemy
end

function BaseEnemy:update(dt, playerManager, enemies)
    if not self.isAlive then return end
    
    -- Obtém a posição de colisão do jogador
    local playerCollision = playerManager:getCollisionPosition()

    -- Calcula a direção para o jogador usando a posição de colisão
    local dx = playerCollision.position.x - self.position.x
    local dy = (playerCollision.position.y - self.position.y) * 2 -- Ajusta para o modo isométrico
    
    -- Normaliza o vetor de direção
    local length = math.sqrt(dx * dx + dy * dy)
    if length > 0 then
        dx = dx / length
        dy = dy / length
    end
    
    -- Calcula a posição alvo inicial baseada na direção do jogador
    local targetX = self.position.x + dx * self.speed * dt
    local targetY = self.position.y + dy * self.speed * dt
    
    -- Calcula a força de separação total devido a outros inimigos
    local totalSeparationX = 0
    local totalSeparationY = 0
    local separationStrength = 1.5 -- Fator de força da separação (ajustável)

    -- Verifica colisão com outros inimigos e calcula separação
    for _, other in ipairs(enemies) do
        if other ~= self and other.isAlive then
            -- Usa a posição atual para verificar a colisão, não a posição alvo
            local distSq = (other.position.x - self.position.x)^2 + ((other.position.y - self.position.y) * 2)^2 -- Ajuste isométrico na distância Y
            local minDist = self.radius + other.radius
            
            if distSq < minDist * minDist and distSq > 0 then -- Evita divisão por zero se distSq for 0
                local distance = math.sqrt(distSq)
                local overlap = minDist - distance
                
                -- Calcula vetor de separação normalizado (de other para self)
                local sepX = self.position.x - other.position.x
                local sepY = (self.position.y - other.position.y) * 2 -- Ajuste isométrico
                
                -- Normaliza
                sepX = sepX / distance 
                sepY = sepY / distance 
                
                -- Adiciona força de separação proporcional ao overlap
                -- A força é maior quanto maior o overlap
                totalSeparationX = totalSeparationX + sepX * overlap * separationStrength
                totalSeparationY = totalSeparationY + sepY * overlap * separationStrength
            elseif distSq == 0 then -- Exatamente na mesma posição
                -- Empurra em uma direção aleatória para separá-los
                local angle = math.random() * 2 * math.pi
                totalSeparationX = totalSeparationX + math.cos(angle) * self.radius * separationStrength
                totalSeparationY = totalSeparationY + math.sin(angle) * self.radius * separationStrength * 0.5 -- Menos força no Y devido à isometria
            end
        end
    end
    
    -- Adiciona a força de separação ao movimento alvo
    -- A separação pode temporariamente mover o inimigo "para trás" se for forte o suficiente
    targetX = targetX + totalSeparationX * dt -- Escala por dt para movimento mais suave
    targetY = targetY + totalSeparationY * dt
    
    -- Atualiza a posição do inimigo
    self.position.x = targetX
    self.position.y = targetY
    
    -- Verifica colisão com o jogador usando a posição de colisão
    self:checkPlayerCollision(dt, playerManager)
end

function BaseEnemy:checkPlayerCollision(dt, playerManager)
    -- Obtém a posição de colisão do jogador
    local playerCollision = playerManager:getCollisionPosition()

    -- Atualiza o tempo do último dano
    self.lastDamageTime = self.lastDamageTime + dt
    
    -- Calcula a distância entre a colisão do jogador e o inimigo
    -- Obtém a posição de colisão do inimigo
    local enemyCollision = self:getCollisionPosition()
    local dx = playerCollision.position.x - enemyCollision.position.x
    local dy = (playerCollision.position.y - enemyCollision.position.y) * 2 -- Ajusta para o modo isométrico
    
    local distance = math.sqrt(dx * dx + dy * dy)

    -- Se houver colisão (distância menor que a soma dos raios)
    if distance <= (self.radius + playerCollision.radius) then
        -- Verifica se pode causar dano (cooldown)
        if self.lastDamageTime >= self.damageCooldown then
            -- Causa dano ao jogador usando o PlayerManager
            if playerManager:takeDamage(self.damage) then
                -- Se o jogador morreu, remove o inimigo
                self.isAlive = false
            end
            
            -- Mostra o número de dano
            FloatingTextManager:addText(
                playerCollision.position.x,
                playerCollision.position.y - playerCollision.radius - 10,
                "-" .. tostring(self.damage),
                false, -- Sempre falso pois inimigos não causam dano crítico
                PlayerManager.player.position,
                {1, 0, 0} -- Cor vermelha para dano ao jogador
            )
            
            -- Reseta o cooldown
            self.lastDamageTime = 0
        end
    end
end

function BaseEnemy:draw()
    if not self.isAlive then return end
    
    -- Desenha a area de colisão
    local collisionPosition = self:getCollisionPosition()
    love.graphics.setColor(1, 0, 0, 0.5)
    love.graphics.circle("line", collisionPosition.position.x, collisionPosition.position.y, collisionPosition.radius)
end

function BaseEnemy:takeDamage(damage, isCritical)
    -- Aplica o dano
    self.currentHealth = self.currentHealth - damage
    print(string.format("Inimigo ID: %d, Dano: %d, Vida: %d", self.id, damage, self.currentHealth))
    -- Mostra o número de dano
    addFloatingText(
        self.position.x,
        self.position.y - self.radius - 10,
        tostring(damage),
        isCritical
    )
    
    if self.currentHealth <= 0 then
        self.currentHealth = 0
        
        -- Marca o inimigo como morto, mas não o remove ainda
        self.isAlive = false
        
        -- Dropa o orbe de experiência
        ExperienceOrbManager:addOrb(self.position.x, self.position.y, self.experienceValue)
        
        return true -- Retorna true se o inimigo morreu
    end
    return false
end

function BaseEnemy:getCollisionPosition()
    return {
        position = {
            x = self.position.x,
            y = self.position.y + 10,
        },
        radius = self.radius
    }
end

return BaseEnemy 