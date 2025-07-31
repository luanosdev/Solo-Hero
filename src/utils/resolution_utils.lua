---@class ResolutionUtils
local ResolutionUtils = {}

-- Referência global para o sistema push (será definida no main.lua)
local push = nil
local AdaptiveScaleManager = require("src.utils.adaptive_scale_manager")

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

    -- Usa o estado atual do push para determinar escalas
    local scaleX, scaleY, offsetX, offsetY

    if push._stretched then
        -- Modo stretched: usa toda a tela (escalas independentes)
        scaleX = windowW / gameW
        scaleY = windowH / gameH
        offsetX = 0
        offsetY = 0
    else
        -- Modo normal: mantém proporção e centraliza
        local scale = math.min(windowW / gameW, windowH / gameH)
        scaleX = scale
        scaleY = scale
        offsetX = (windowW - (gameW * scale)) * 0.5
        offsetY = (windowH - (gameH * scale)) * 0.5
    end

    return {
        scaleX = scaleX,
        scaleY = scaleY,
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

--- Calcula uma distância segura fora da tela, baseada na diagonal da resolução virtual.
--- Útil para determinar quando uma entidade está longe o suficiente para despawn.
--- @param buffer? number | nil Uma margem extra a ser adicionada. Padrão 500.
--- @return number safeDistance A distância segura em pixels.
function ResolutionUtils.getSafeOffScreenDistance(buffer)
    local gameW, gameH = ResolutionUtils.getGameDimensions()
    local halfW = gameW / 2
    local halfH = gameH / 2

    -- Calcula a distância do centro até o canto (diagonal)
    local diagonalDistance = math.sqrt(halfW * halfW + halfH * halfH)

    -- Adiciona um buffer de segurança para garantir que está bem fora da tela
    local safeBuffer = buffer or 500 -- Buffer padrão de 500 pixels

    return diagonalDistance + safeBuffer
end

-- ========== FUNÇÕES ADAPTATIVAS ==========

--- Aplica escala adaptativa a um valor baseado na categoria
---@param value number Valor original
---@param category string Categoria do elemento (ui, text, gameplay, spacing, icons, hud)
---@return number scaledValue Valor com escala adaptativa aplicada
function ResolutionUtils.scaleAdaptive(value, category)
    return AdaptiveScaleManager.applyScale(value, category)
end

--- Aplica escala adaptativa para tamanhos de UI
---@param width number Largura original
---@param height number Altura original
---@return number scaledWidth Largura escalada
---@return number scaledHeight Altura escalada
function ResolutionUtils.scaleUI(width, height)
    local scale = AdaptiveScaleManager.getScale("ui")
    return width * scale, height * scale
end

--- Aplica escala adaptativa para tamanhos de texto/fontes
---@param fontSize number Tamanho da fonte original
---@return number scaledFontSize Tamanho da fonte escalado
function ResolutionUtils.scaleText(fontSize)
    return AdaptiveScaleManager.applyScale(fontSize, "text")
end

--- Aplica escala adaptativa para espaçamentos e padding
---@param spacing number Espaçamento original
---@return number scaledSpacing Espaçamento escalado
function ResolutionUtils.scaleSpacing(spacing)
    return AdaptiveScaleManager.applyScale(spacing, "spacing")
end

--- Aplica escala adaptativa para ícones
---@param iconSize number Tamanho do ícone original
---@return number scaledIconSize Tamanho do ícone escalado
function ResolutionUtils.scaleIcon(iconSize)
    return AdaptiveScaleManager.applyScale(iconSize, "icons")
end

--- Centraliza um elemento na tela com escala adaptativa aplicada
---@param elementWidth number Largura do elemento
---@param elementHeight number Altura do elemento
---@param category? string Categoria para escala (padrão: "ui")
---@return number centerX Posição X centralizada
---@return number centerY Posição Y centralizada
function ResolutionUtils.centerElementAdaptive(elementWidth, elementHeight, category)
    category = category or "ui"
    local scaledWidth = ResolutionUtils.scaleAdaptive(elementWidth, category)
    local scaledHeight = ResolutionUtils.scaleAdaptive(elementHeight, category)
    return ResolutionUtils.centerElement(scaledWidth, scaledHeight)
end

--- Obtém informações completas sobre resolução e escala adaptativa
---@return table adaptiveInfo Informações completas do sistema
function ResolutionUtils.getAdaptiveInfo()
    local baseInfo = ResolutionUtils.getScaleInfo()
    local adaptiveScaleInfo = AdaptiveScaleManager.getScaleInfo()

    return {
        -- Informações base do sistema de resolução
        resolution = baseInfo,
        -- Informações do sistema adaptativo
        adaptive = adaptiveScaleInfo,
        -- Funções de conveniência
        scaleFunctions = {
            ui = function(value) return ResolutionUtils.scaleAdaptive(value, "ui") end,
            text = function(value) return ResolutionUtils.scaleAdaptive(value, "text") end,
            spacing = function(value) return ResolutionUtils.scaleAdaptive(value, "spacing") end,
            icons = function(value) return ResolutionUtils.scaleAdaptive(value, "icons") end
        }
    }
end

--- Verifica se o dispositivo atual necessita de escala adaptativa
---@return boolean needsAdaptiveScale
function ResolutionUtils.needsAdaptiveScale()
    return AdaptiveScaleManager.needsAdaptiveScale()
end

return ResolutionUtils
