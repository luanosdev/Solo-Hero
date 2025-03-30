local Camera = {
    x = 0,
    y = 0,
    scale = 1,
    rotation = 0
}

function Camera:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Camera:follow(target)
    -- Suavização da câmera
    local smoothSpeed = 0.1
    
    -- Obtém as dimensões da janela
    local windowWidth = love.graphics.getWidth()
    local windowHeight = love.graphics.getHeight()
    
    -- Calcula a posição alvo (centro da tela)
    local targetX = target.positionX - (windowWidth / (2 * self.scale))
    local targetY = target.positionY - (windowHeight / (2 * self.scale))
    
    -- Interpola suavemente para a posição alvo
    self.x = self.x + (targetX - self.x) * smoothSpeed
    self.y = self.y + (targetY - self.y) * smoothSpeed
end

function Camera:attach()
    love.graphics.push()
    love.graphics.translate(-self.x, -self.y)
    love.graphics.scale(self.scale, self.scale)
    love.graphics.rotate(self.rotation)
end

function Camera:detach()
    love.graphics.pop()
end

return Camera 