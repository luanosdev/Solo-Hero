--[[
    Ranged Enemy
    Um inimigo que ataca à distância usando projéteis
]]

local BaseEnemy = require("src.classes.enemies.base_enemy")
local LinearProjectile = require("src.abilities.linear_projectile")

local RangedEnemy = setmetatable({}, { __index = BaseEnemy })

RangedEnemy.name = "Ranged Enemy"
RangedEnemy.radius = 10
RangedEnemy.speed = 55
RangedEnemy.maxHealth = 40
RangedEnemy.damage = 15
RangedEnemy.attackRange = 200  -- Distância ideal para atacar
RangedEnemy.attackCooldown = 2.0  -- Tempo entre ataques
RangedEnemy.lastAttackTime = 0
RangedEnemy.attackAbility = nil
RangedEnemy.color = {0.8, 0.2, 0.2} -- Cor vermelha mais escura
RangedEnemy.experienceValue = 15 -- Mais experiência que o inimigo base

function RangedEnemy:new(x, y)
    local enemy = BaseEnemy.new(self, x, y)
    setmetatable(enemy, { __index = self })
    
    -- Cria uma nova instância da habilidade de ataque
    enemy.attackAbility = setmetatable({}, { __index = LinearProjectile })
    enemy.attackAbility:init(enemy)
    
    -- Ajusta os atributos da habilidade para o inimigo
    enemy.attackAbility.cooldown = self.attackCooldown
    enemy.attackAbility.damage = self.damage
    enemy.attackAbility.speed = 100 -- Velocidade do projétil
    enemy.attackAbility.maxDistance = 300 -- Distância máxima do projétil
    
    return enemy
end

function RangedEnemy:update(dt, player, enemies)
    if not self.isAlive then return end
    
    -- Atualiza o cooldown do ataque
    self.lastAttackTime = self.lastAttackTime + dt
    
    -- Calcula a distância até o jogador
    local dx = player.positionX - self.positionX
    local dy = player.positionY - self.positionY
    local distance = math.sqrt(dx * dx + dy * dy)
    
    -- Se estiver fora do alcance de ataque, move em direção ao jogador
    if distance > self.attackRange then
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
                local enemyDx = other.positionX - newX
                local enemyDy = other.positionY - newY
                local enemyDistance = math.sqrt(enemyDx * enemyDx + enemyDy * enemyDy)
                
                if enemyDistance < (self.radius + other.radius) then
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
    end
    
    -- Se estiver dentro do alcance de ataque e o cooldown estiver pronto, ataca
    if distance <= self.attackRange and self.lastAttackTime >= self.attackCooldown then
        -- Ataca o jogador
        self:attack(player)
        self.lastAttackTime = 0
    end
    
    -- Atualiza a habilidade de ataque
    self.attackAbility:update(dt)
end

function RangedEnemy:draw()
    -- Desenha o inimigo
    BaseEnemy.draw(self)
    
    -- Desenha a habilidade de ataque
    self.attackAbility:draw()
end

function RangedEnemy:attack(player)
    -- Passa a referência do jogador para a habilidade
    self.attackAbility.owner.player = player
    
    -- Passa a referência do mundo para a habilidade
    self.attackAbility.owner.world = { enemies = self.enemies }
    
    -- Calcula o ângulo para o jogador
    local dx = player.positionX - self.positionX
    local dy = player.positionY - self.positionY
    local angle = math.atan2(dy, dx)
    
    -- Usa a habilidade de projétil para atacar o jogador com o ângulo calculado
    self.attackAbility:cast(angle, nil, true)
end

return RangedEnemy 