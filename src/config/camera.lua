---@class Camera
---@field x number
---@field y number
---@field scale number
---@field defaultScale number
---@field rotation number
---@field smoothness number
---@field screenWidth number
---@field screenHeight number
---@field offsetX number
---@field offsetY number
---@field moveSpeed number
local Camera = {
    x = 0,
    y = 0,
    scale = 1.5,
    defaultScale = 1.5,
    rotation = 0,
    smoothness = 5, -- Suavidade da câmera (maior = mais suave)
    offsetX = 0,
    offsetY = 0,
    screenWidth = 0,
    screenHeight = 0,
    moveSpeed = 4
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
    local targetX = position.x - (self.screenWidth / self.scale / 2)
    local targetY = position.y - (self.screenHeight / self.scale / 2)

    -- Interpola suavemente para a posição alvo
    self.x = self.x + (targetX - self.x) * dt * self.smoothness
    self.y = self.y + (targetY - self.y) * dt * self.smoothness
    -- PARA TESTE: Remover suavização
    self.x = targetX
    self.y = targetY
end

function Camera:attach()
    love.graphics.push()
    love.graphics.scale(self.scale)
    love.graphics.translate(
        -math.floor(self.x + self.offsetX),
        -math.floor(self.y + self.offsetY)
    )
end

function Camera:detach()
    love.graphics.pop()
end

-- Converte coordenadas da tela para coordenadas do mundo
function Camera:screenToWorld(screenX, screenY)
    return (screenX / self.scale) + self.x, (screenY / self.scale) + self.y
end

-- Converte coordenadas do mundo para coordenadas da tela
function Camera:worldToScreen(worldX, worldY)
    return (worldX - self.x) * self.scale, (worldY - self.y) * self.scale
end

--- Define a posição da câmera diretamente.
---@param x number Coordenada X do canto superior esquerdo da câmera.
---@param y number Coordenada Y do canto superior esquerdo da câmera.
function Camera:setPosition(x, y)
    self.x = x
    self.y = y
end

---@return number x, number y, number width, number height
function Camera:getViewPort()
    return self.x, self.y, self.screenWidth / self.scale, self.screenHeight / self.scale
end

function Camera:getPosition()
    return self.x, self.y
end

return Camera
