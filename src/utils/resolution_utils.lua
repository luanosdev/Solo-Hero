---@class ResolutionUtils
local ResolutionUtils = {}

-- Referência global para o sistema push (será definida no main.lua)
local push = nil

--- Inicializa o ResolutionUtils com a referência do push
---@param pushInstance table O objeto push inicializado
function ResolutionUtils.initialize(pushInstance)
    push = pushInstance
end

--- Converte coordenadas da tela real para coordenadas do jogo
---@param x number Coordenada X da tela
---@param y number Coordenada Y da tela
---@return number|nil gameX Coordenada X do jogo (nil se fora da área do jogo)
---@return number|nil gameY Coordenada Y do jogo (nil se fora da área do jogo)
function ResolutionUtils.toGame(x, y)
    if not push then
        return x, y -- Fallback se push não estiver inicializado
    end
    return push:toGame(x, y)
end

--- Converte coordenadas do jogo para coordenadas da tela real
---@param x number Coordenada X do jogo
---@param y number Coordenada Y do jogo
---@return number realX Coordenada X da tela
---@return number realY Coordenada Y da tela
function ResolutionUtils.toReal(x, y)
    if not push then
        return x, y -- Fallback se push não estiver inicializado
    end
    return push:toReal(x, y)
end

--- Retorna as dimensões do jogo (resolução virtual)
---@return number gameWidth Largura do jogo
---@return number gameHeight Altura do jogo
function ResolutionUtils.getGameDimensions()
    if not push then
        return 1920, 1080 -- Fallback para resolução padrão
    end
    return push:getDimensions()
end

--- Retorna a largura do jogo (resolução virtual)
---@return number gameWidth Largura do jogo
function ResolutionUtils.getGameWidth()
    if not push then
        return 1920 -- Fallback
    end
    return push:getWidth()
end

--- Retorna a altura do jogo (resolução virtual)
---@return number gameHeight Altura do jogo
function ResolutionUtils.getGameHeight()
    if not push then
        return 1080 -- Fallback
    end
    return push:getHeight()
end

--- Retorna informações de escala atual
---@return table scaleInfo Tabela com informações de escala
function ResolutionUtils.getScaleInfo()
    if not push then
        return {
            scaleX = 1,
            scaleY = 1,
            offsetX = 0,
            offsetY = 0,
            hasStencil = false
        }
    end

    -- Acesso às variáveis internas do push através de métodos auxiliares
    local gameW, gameH = push:getDimensions()
    local windowW, windowH = love.graphics.getDimensions()

    local scaleX = windowW / gameW
    local scaleY = windowH / gameH
    local scale = math.min(scaleX, scaleY)

    local offsetX = (windowW - (gameW * scale)) * 0.5
    local offsetY = (windowH - (gameH * scale)) * 0.5

    return {
        scaleX = scale,
        scaleY = scale,
        offsetX = offsetX,
        offsetY = offsetY,
        windowWidth = windowW,
        windowHeight = windowH,
        gameWidth = gameW,
        gameHeight = gameH,
        hasStencil = push:hasStencilSupport(),
        canvasInfo = push:getCanvasInfo()
    }
end

--- Verifica se um ponto está dentro da área visível do jogo
---@param x number Coordenada X (coordenadas de tela)
---@param y number Coordenada Y (coordenadas de tela)
---@return boolean isInside Se o ponto está dentro da área do jogo
function ResolutionUtils.isPointInGameArea(x, y)
    local gameX, gameY = ResolutionUtils.toGame(x, y)
    return gameX ~= nil and gameY ~= nil
end

--- Centraliza um elemento na tela (coordenadas de jogo)
---@param elementWidth number Largura do elemento
---@param elementHeight number Altura do elemento
---@return number centerX Posição X centralizada
---@return number centerY Posição Y centralizada
function ResolutionUtils.centerElement(elementWidth, elementHeight)
    local gameW, gameH = ResolutionUtils.getGameDimensions()
    return (gameW - elementWidth) / 2, (gameH - elementHeight) / 2
end

--- Centraliza um elemento horizontalmente
---@param elementWidth number Largura do elemento
---@return number centerX Posição X centralizada
function ResolutionUtils.centerHorizontally(elementWidth)
    local gameW = ResolutionUtils.getGameWidth()
    return (gameW - elementWidth) / 2
end

--- Centraliza um elemento verticalmente
---@param elementHeight number Altura do elemento
---@return number centerY Posição Y centralizada
function ResolutionUtils.centerVertically(elementHeight)
    local gameH = ResolutionUtils.getGameHeight()
    return (gameH - elementHeight) / 2
end

return ResolutionUtils
