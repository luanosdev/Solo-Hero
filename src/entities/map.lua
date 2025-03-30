local MapConfig = require("src.config.map_config")

local Map = {
    matrix = nil,
    width = 0,
    height = 0,
    tileSize = MapConfig.tileSize,
    obstacles = {} -- Lista de obstáculos
}

function Map:new(matrix)
    local map = setmetatable({}, { __index = self })
    map.matrix = matrix
    map.height = #matrix
    map.width = #matrix[1]
    map:processMap()
    return map
end

function Map:processMap()
    -- Processa a matriz para encontrar obstáculos
    for y = 1, self.height do
        for x = 1, self.width do
            if self.matrix[y][x] == 1 then
                -- Converte coordenadas da matriz para coordenadas do mundo
                local worldX = (x - 1) * self.tileSize
                local worldY = (y - 1) * self.tileSize
                
                table.insert(self.obstacles, {
                    x = worldX,
                    y = worldY,
                    width = self.tileSize,
                    height = self.tileSize
                })
            end
        end
    end
end

function Map:isWall(x, y)
    -- Converte coordenadas do mundo para coordenadas da matriz
    local matrixX = math.floor(x / self.tileSize) + 1
    local matrixY = math.floor(y / self.tileSize) + 1
    
    -- Verifica se está dentro dos limites do mapa
    if matrixX < 1 or matrixX > self.width or matrixY < 1 or matrixY > self.height then
        return true -- Fora do mapa é considerado parede
    end
    
    -- Retorna true se for um obstáculo (1)
    return self.matrix[matrixY][matrixX] == 1
end

function Map:checkCollision(x, y, radius)
    -- Verifica colisão com paredes
    if self:isWall(x, y) then
        return true
    end
    
    -- Verifica colisão com obstáculos
    for _, obstacle in ipairs(self.obstacles) do
        local closestX = math.max(obstacle.x, math.min(x, obstacle.x + obstacle.width))
        local closestY = math.max(obstacle.y, math.min(y, obstacle.y + obstacle.height))
        
        local distanceX = x - closestX
        local distanceY = y - closestY
        
        if (distanceX * distanceX + distanceY * distanceY) < (radius * radius) then
            return true
        end
    end
    
    return false
end

function Map:draw()
    -- Desenha o mapa base
    love.graphics.setColor(MapConfig.colors.floor)
    love.graphics.rectangle("fill", 0, 0, self.width * self.tileSize, self.height * self.tileSize)
    
    -- Desenha as paredes e obstáculos
    love.graphics.setColor(MapConfig.colors.wall)
    for y = 1, self.height do
        for x = 1, self.width do
            if self.matrix[y][x] == 1 then
                love.graphics.rectangle("fill", 
                    (x - 1) * self.tileSize, 
                    (y - 1) * self.tileSize, 
                    self.tileSize, 
                    self.tileSize
                )
            end
        end
    end
end

return Map 