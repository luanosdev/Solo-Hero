local EnemyManager = {
    enemies = {},
    spawnTimer = 0,
    spawnInterval = 5, -- Tempo entre spawns em segundos
    maxEnemies = 10,
    BasicEnemy = require("src.classes.basic_enemy")
}

function EnemyManager:init()
    self.enemies = {}
    self.spawnTimer = 0
end

function EnemyManager:update(dt, player)
    -- Atualiza todos os inimigos
    for _, enemy in ipairs(self.enemies) do
        enemy:setTarget(player.positionX, player.positionY)

        enemy:update(dt)
    end
end

function EnemyManager:draw()
    for _, enemy in ipairs(self.enemies) do
        enemy:draw()
    end
end

function EnemyManager:spawnEnemy(player)
    -- Gera posição aleatória na tela
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Converte as coordenadas da tela para coordenadas do mundo
    local worldX = (love.math.random(0, screenWidth) + camera.x) / camera.scale
    local worldY = (love.math.random(0, screenHeight) + camera.y) / camera.scale
    
    -- Cria um novo inimigo básico
    local enemy = setmetatable({}, {__index = self.BasicEnemy})
    enemy:init(worldX, worldY)
    enemy:setTarget(player.positionX, player.positionY)
    
    table.insert(self.enemies, enemy)
end

function EnemyManager:getEnemies()
    return self.enemies
end

return EnemyManager