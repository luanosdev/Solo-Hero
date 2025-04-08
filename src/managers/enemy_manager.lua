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

local HordeManager = {
    hordes = {},
    currentHordeIndex = 1,
    hordeTimer = 0,
    hordeInterval = 30, -- Intervalo entre hordas em segundos
}

function EnemyManager:init()
    self.enemies = {}
    self.spawnTimer = 0
    HordeManager:init()
end

function EnemyManager:update(dt, player)
    self.spawnTimer = self.spawnTimer + dt
    if self.spawnTimer >= self.spawnInterval and #self.enemies < self.maxEnemies then
        self:spawnEnemy(player)
        self.spawnTimer = 0
    end
    for i = #self.enemies, 1, -1 do
        local enemy = self.enemies[i]
        enemy:update(dt, player, self.enemies)
        if not enemy.isAlive then
            table.remove(self.enemies, i)
        end
    end
    HordeManager:update(dt, player)
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

function HordeManager:init()
    self.hordes = {
        {time = 30, enemies = {{class = FastEnemy, count = 5}, {class = TankEnemy, count = 2}}},
        {time = 60, enemies = {{class = FastEnemy, count = 10}, {class = RangedEnemy, count = 5}}},
        {time = 120, enemies = {{class = FastEnemy, count = 15}, {class = TankEnemy, count = 5}, {class = RangedEnemy, count = 10}}},
        {time = 180, enemies = {{class = FastEnemy, count = 20}, {class = TankEnemy, count = 10}, {class = RangedEnemy, count = 15}}},
        {time = 240, enemies = {{class = FastEnemy, count = 25}, {class = TankEnemy, count = 15}, {class = RangedEnemy, count = 20}}},
        -- Adicione mais hordas conforme necessário
    }
    self.currentHordeIndex = 1
    self.hordeTimer = 0
end

function HordeManager:update(dt, player)
    self.hordeTimer = self.hordeTimer + dt
    local currentHorde = self.hordes[self.currentHordeIndex]
    if currentHorde and self.hordeTimer >= currentHorde.time then
        for _, enemyInfo in ipairs(currentHorde.enemies) do
            for i = 1, enemyInfo.count do
                EnemyManager:spawnSpecificEnemy(enemyInfo.class, player)
            end
        end
        self.hordeTimer = 0
        self.currentHordeIndex = self.currentHordeIndex + 1
    end
end

function EnemyManager:spawnSpecificEnemy(enemyClass, player)
    local minSpawnRadius = math.max(love.graphics.getWidth(), love.graphics.getHeight()) * 0.6
    local angle = math.random() * 2 * math.pi
    local spawnX = player.positionX + math.cos(angle) * minSpawnRadius
    local spawnY = player.positionY + math.sin(angle) * minSpawnRadius
    local enemy = enemyClass:new(spawnX, spawnY)
    table.insert(self.enemies, enemy)
end

return EnemyManager