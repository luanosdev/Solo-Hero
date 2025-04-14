local Camera = {
    x = 0,
    y = 0,
    scale = 1,
    rotation = 0,
    smoothness = 5,  -- Suavidade da câmera (maior = mais suave)
    screenWidth = 0,
    screenHeight = 0
}

function Camera:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Camera:init()
    -- Obtém dimensões da tela
    self.screenWidth = love.graphics.getWidth()
    self.screenHeight = love.graphics.getHeight()
end

function Camera:follow(target, dt)
    -- Calcula a posição alvo (centro da tela)
    local targetX = target.x - (self.screenWidth / 2)
    local targetY = target.y - (self.screenHeight / 2)
    
    -- Interpola suavemente para a posição alvo
    self.x = self.x + (targetX - self.x) * dt * self.smoothness
    self.y = self.y + (targetY - self.y) * dt * self.smoothness
end

function Camera:attach()
    love.graphics.push()
    love.graphics.translate(
        -math.floor(self.x + 0.5),
        -math.floor(self.y + 0.5)
    )
    love.graphics.scale(self.scale, self.scale)
    love.graphics.rotate(self.rotation)
end

function Camera:detach()
    love.graphics.pop()
end

-- Converte coordenadas da tela para coordenadas do mundo
function Camera:screenToWorld(screenX, screenY)
    return screenX + self.x, screenY + self.y
end

-- Converte coordenadas do mundo para coordenadas da tela
function Camera:worldToScreen(worldX, worldY)
    return worldX - self.x, worldY - self.y
end

return Camera 