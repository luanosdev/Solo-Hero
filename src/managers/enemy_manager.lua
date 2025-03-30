local Enemy = require("src.entities.enemy")
local MapConfig = require("src.config.map_config")

local EnemyManager = {
    enemies = {},
    spawnTimer = 0,
    spawnInterval = 2, -- Intervalo entre spawns em segundos
    maxEnemies = 10,
    mapWidth = 800,  -- Largura do mapa
    mapHeight = 600  -- Altura do mapa
}

function EnemyManager:init()
    self.enemies = {}
    self.spawnTimer = 0
end

function EnemyManager:update(dt, player, map)
    -- Atualiza o timer de spawn
    self.spawnTimer = self.spawnTimer + dt
    
    -- Spawn de novos inimigos
    if self.spawnTimer >= self.spawnInterval and #self.enemies < self.maxEnemies then
        self:spawnEnemy(player, map)
        self.spawnTimer = 0
    end
    
    -- Atualiza e remove inimigos mortos
    for i = #self.enemies, 1, -1 do
        local enemy = self.enemies[i]
        enemy:update(dt, player, self.enemies, map)
        if not enemy.isAlive then
            table.remove(self.enemies, i)
        end
    end
end

function EnemyManager:spawnEnemy(player, map)
    -- Escolhe uma posição aleatória dentro dos limites do mapa
    local spawnX, spawnY
    local attempts = 0
    local maxAttempts = 10
    
    repeat
        -- Gera uma posição aleatória dentro dos limites do mapa
        spawnX = math.random(1, map.width - 1) * MapConfig.tileSize
        spawnY = math.random(1, map.height - 1) * MapConfig.tileSize
        attempts = attempts + 1
    until not map:isWall(spawnX, spawnY) or attempts >= maxAttempts
    
    -- Se não encontrou uma posição válida, não spawna o inimigo
    if attempts >= maxAttempts then
        return
    end
    
    -- Cria o inimigo na posição válida
    local enemy = Enemy:new(spawnX, spawnY)
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