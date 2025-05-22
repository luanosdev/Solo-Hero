local Camera = {
    x = 0,
    y = 0,
    scale = 1.8,
    rotation = 0,
    smoothness = 5, -- Suavidade da câmera (maior = mais suave)
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

function Camera:follow(position, dt)
    -- Calcula a posição alvo (centro da tela)
    local targetX = position.x - (self.screenWidth / 2)
    local targetY = position.y - (self.screenHeight / 2)

    -- Interpola suavemente para a posição alvo
    -- self.x = self.x + (targetX - self.x) * dt * self.smoothness
    -- self.y = self.y + (targetY - self.y) * dt * self.smoothness
    -- PARA TESTE: Remover suavização
    self.x = targetX
    self.y = targetY
end

function Camera:attach()
    love.graphics.push()
    -- Centraliza o ponto de origem do zoom/rotação no centro da tela
    love.graphics.translate(self.screenWidth / 2, self.screenHeight / 2)
    love.graphics.scale(self.scale, self.scale)
    love.graphics.rotate(self.rotation)
    -- Move o mundo de volta para a posição correta
    love.graphics.translate(
        -math.floor(self.x + 0.5) - self.screenWidth / 2,
        -math.floor(self.y + 0.5) - self.screenHeight / 2
    )
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

--- Define a posição da câmera diretamente.
---@param x number Coordenada X do canto superior esquerdo da câmera.
---@param y number Coordenada Y do canto superior esquerdo da câmera.
function Camera:setPosition(x, y)
    self.x = x
    self.y = y
end

function Camera:getViewPort()
    return {
        x = self.x,
        y = self.y,
        width = self.screenWidth,
        height = self.screenHeight
    }
end

return Camera
