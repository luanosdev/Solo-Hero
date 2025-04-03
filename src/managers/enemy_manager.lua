local FastEnemy = require("src.classes.enemies.fast_enemy")
local TankEnemy = require("src.classes.enemies.tank_enemy")
local RangedEnemy = require("src.classes.enemies.ranged_enemy")

local EnemyManager = {
    enemies = {},
    spawnTimer = 0,
    spawnInterval = 0.5, -- Intervalo entre spawns em segundos
    maxEnemies = 100,
    enemyTypes = {
        {class = FastEnemy, weight = 1},    -- Mais comum
        {class = TankEnemy, weight = 1},    -- Menos comum
        {class = RangedEnemy, weight = 10},  -- Inimigo à distância
    }
}

function EnemyManager:init()
    self.enemies = {}
    self.spawnTimer = 0
end

function EnemyManager:update(dt, player)
    -- Atualiza o timer de spawn
    self.spawnTimer = self.spawnTimer + dt
    
    -- Spawn de novos inimigos
    if self.spawnTimer >= self.spawnInterval and #self.enemies < self.maxEnemies then
        self:spawnEnemy(player)
        self.spawnTimer = 0
    end
    
    -- Atualiza e remove inimigos mortos
    for i = #self.enemies, 1, -1 do
        local enemy = self.enemies[i]
        enemy:update(dt, player, self.enemies)
        if not enemy.isAlive then
            table.remove(self.enemies, i)
        end
    end
end

function EnemyManager:spawnEnemy(player)
    -- Define o raio mínimo de spawn (fora da tela)
    local minSpawnRadius = math.max(love.graphics.getWidth(), love.graphics.getHeight()) * 0.6
    
    -- Gera um ângulo aleatório em radianos
    local angle = math.random() * 2 * math.pi
    
    -- Calcula a posição de spawn baseada no ângulo e raio
    local spawnX = player.positionX + math.cos(angle) * minSpawnRadius
    local spawnY = player.positionY + math.sin(angle) * minSpawnRadius
    
    -- Escolhe o tipo de inimigo baseado nos pesos
    local totalWeight = 0
    for _, enemyType in ipairs(self.enemyTypes) do
        totalWeight = totalWeight + enemyType.weight
    end
    
    local randomValue = math.random() * totalWeight
    local selectedEnemyType
    
    for _, enemyType in ipairs(self.enemyTypes) do
        randomValue = randomValue - enemyType.weight
        if randomValue <= 0 then
            selectedEnemyType = enemyType.class
            break
        end
    end
    
    -- Cria o inimigo na posição calculada
    local enemy = selectedEnemyType:new(spawnX, spawnY)
    table.insert(self.enemies, enemy)
end

function EnemyManager:draw()
    for _, enemy in ipairs(self.enemies) do
        enemy:draw()
    end
end

function EnemyManager:getEnemies()
    return self.enemies
end

return EnemyManager