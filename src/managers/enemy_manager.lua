local Enemy = require("src.entities.enemy")

local EnemyManager = {
    enemies = {},
    spawnTimer = 0,
    spawnInterval = 2, -- Tempo entre spawns em segundos
    maxEnemies = 10,
    mapWidth = 800,  -- Largura do mapa
    mapHeight = 600  -- Altura do mapa
}

function EnemyManager:init()
    self.enemies = {}
    self.spawnTimer = 0
end

function EnemyManager:update(dt, playerX, playerY)
    -- Atualiza o timer de spawn
    self.spawnTimer = self.spawnTimer + dt
    
    -- Tenta spawnar um novo inimigo se o timer atingir o intervalo
    if self.spawnTimer >= self.spawnInterval and #self.enemies < self.maxEnemies then
        self:spawnEnemy()
        self.spawnTimer = 0
    end
    
    -- Atualiza todos os inimigos
    for i = #self.enemies, 1, -1 do
        local enemy = self.enemies[i]
        enemy:update(dt, playerX, playerY)
        
        -- Remove inimigos mortos
        if not enemy.isAlive then
            table.remove(self.enemies, i)
        end
    end
end

function EnemyManager:spawnEnemy()
    -- Escolhe uma borda aleatória para spawnar
    local side = math.random(1, 4) -- 1: topo, 2: direita, 3: baixo, 4: esquerda
    local x, y = 0, 0
    
    if side == 1 then -- Topo
        x = math.random(0, self.mapWidth)
        y = -20
    elseif side == 2 then -- Direita
        x = self.mapWidth + 20
        y = math.random(0, self.mapHeight)
    elseif side == 3 then -- Baixo
        x = math.random(0, self.mapWidth)
        y = self.mapHeight + 20
    else -- Esquerda
        x = -20
        y = math.random(0, self.mapHeight)
    end
    
    -- Cria e adiciona o novo inimigo
    local enemy = Enemy:new(x, y)
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