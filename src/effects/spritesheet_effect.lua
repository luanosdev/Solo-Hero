local TablePool = require("src.utils.table_pool")
local RenderPipeline = require("src.core.render_pipeline")

---@class SpritesheetEffectConfig
---@field position Vector2D Posição do efeito no mundo.
---@field baseImage love.Image A imagem principal da spritesheet.
---@field overlayImage love.Image|nil A imagem de overlay (opcional).
---@field grid { columns: number, rows: number } A configuração da grade da spritesheet.
---@field frameDuration number Duração de cada frame em segundos.
---@field tint table|nil A tonalidade a ser aplicada na imagem base. {r,g,b,a}
---@field overlayTint table|nil A tonalidade a ser aplicada no overlay. {r,g,b,a}
---@field expandingCircle table|nil Configuração para um círculo expansível. {initialRadius, maxRadius, color, lineWidth}

---@class SpritesheetEffect
--------------------------------------------------------------------------------
-- Efeito Visual Genérico de Spritesheet
-- Classe puramente visual, orientada a dados, para renderizar animações
-- a partir de uma spritesheet. É sem estado (stateless) em relação à lógica
-- de jogo e não possui dependências de serviços.
--------------------------------------------------------------------------------
---@field config SpritesheetEffectConfig
---@field width number
---@field height number
---@field frameWidth number
---@field frameHeight number
---@field quads table
---@field overlayQuads table|nil
---@field animTimer number
---@field currentFrame number
---@field isFinished boolean
---@field expandingCircleState table|nil Estado dinâmico do círculo. {currentRadius, alpha}
local SpritesheetEffect = {}
SpritesheetEffect.__index = SpritesheetEffect

--- Cria uma nova instância de um efeito de spritesheet.
---@param config SpritesheetEffectConfig A tabela de configuração completa para o efeito.
---@return SpritesheetEffect
function SpritesheetEffect:new(config)
    -- Validação de parâmetros essenciais
    assert(config, "SpritesheetEffect: A configuração 'config' é obrigatória.")
    assert(config.position, "SpritesheetEffect: 'config.position' é obrigatório.")
    assert(config.baseImage, "SpritesheetEffect: 'config.baseImage' é obrigatório.")
    assert(config.grid, "SpritesheetEffect: 'config.grid' é obrigatório.")
    assert(config.frameDuration, "SpritesheetEffect: 'config.frameDuration' é obrigatório.")

    local instance = setmetatable({}, SpritesheetEffect)

    instance.config = config
    instance.isFinished = false
    instance.animTimer = 0
    instance.currentFrame = 1

    -- Processa a imagem base
    instance.width = config.baseImage:getWidth()
    instance.height = config.baseImage:getHeight()
    instance.frameWidth = instance.width / config.grid.columns
    instance.frameHeight = instance.height / config.grid.rows
    instance.quads = SpritesheetEffect._createQuads(
        config.grid.rows, config.grid.columns,
        instance.frameWidth, instance.frameHeight,
        instance.width, instance.height
    )

    -- Processa a imagem de overlay, se existir
    if config.overlayImage then
        instance.overlayQuads = SpritesheetEffect._createQuads(
            config.grid.rows, config.grid.columns,
            instance.frameWidth, instance.frameHeight,
            config.overlayImage:getWidth(), config.overlayImage:getHeight()
        )
    end

    -- Inicializa o estado do círculo expansível, se configurado
    if config.expandingCircle then
        instance.expandingCircleState = {
            currentRadius = config.expandingCircle.initialRadius,
            alpha = (config.expandingCircle.color and config.expandingCircle.color.a) or 1.0,
        }
    end

    return instance
end

--- Cria e retorna uma tabela de Quads para uma spritesheet.
---@return love.Quad[]
function SpritesheetEffect._createQuads(rows, columns, frameWidth, frameHeight, imageWidth, imageHeight)
    local quads = {}
    for r = 0, rows - 1 do
        for c = 0, columns - 1 do
            local quad = love.graphics.newQuad(
                c * frameWidth, r * frameHeight,
                frameWidth, frameHeight,
                imageWidth, imageHeight
            )
            table.insert(quads, quad)
        end
    end
    return quads
end

--- Atualiza o estado da animação e do círculo.
---@param dt number Delta time.
function SpritesheetEffect:update(dt)
    if self.isFinished then return end

    -- Atualiza a animação da spritesheet
    self.animTimer = self.animTimer + dt
    if self.animTimer >= self.config.frameDuration then
        self.animTimer = self.animTimer - self.config.frameDuration
        self.currentFrame = self.currentFrame + 1
        if self.currentFrame > #self.quads then
            self.isFinished = true
            return
        end
    end

    -- Atualiza o círculo expansível, se existir
    if self.config.expandingCircle and self.expandingCircleState then
        self:_updateExpandingCircle()
    end
end

--- Lógica interna para atualizar o círculo expansível.
function SpritesheetEffect:_updateExpandingCircle()
    local circleConfig = self.config.expandingCircle

    if not circleConfig then return end

    local totalFrames = #self.quads
    local progress = math.min(self.currentFrame / totalFrames, 1)


    -- Expansão do raio
    self.expandingCircleState.currentRadius = circleConfig.initialRadius +
        (circleConfig.maxRadius - circleConfig.initialRadius) * progress

    -- Fade out do alpha
    local baseAlpha = (circleConfig.color and circleConfig.color.a) or 1.0
    self.expandingCircleState.alpha = baseAlpha * (1 - progress * 0.7)
end

--- Coleta os elementos visuais para o pipeline de renderização.
---@param renderPipeline RenderPipeline
function SpritesheetEffect:collectRenderables(renderPipeline)
    if self.isFinished then return end

    local position = self.config.position
    local depth = RenderPipeline.DEPTH_EFFECTS_WORLD_UI

    -- Adiciona o círculo de knockback (se existir)
    if self.config.expandingCircle then
        local circleItem = TablePool.getGeneric()
        circleItem.depth = depth
        circleItem.type = "spritesheet_effect_circle"
        circleItem.sortY = position.y
        circleItem.drawFunction = function() self:_drawExpandingCircle() end
        renderPipeline:add(circleItem)
    end

    -- Adiciona a camada base
    local baseItem = TablePool.getGeneric()
    baseItem.depth = depth
    baseItem.type = "spritesheet_effect_base"
    baseItem.sortY = position.y + 1 -- Garante que renderize sobre o círculo
    baseItem.drawFunction = function() self:_drawBase() end
    renderPipeline:add(baseItem)

    -- Adiciona a camada overlay (se existir)
    if self.config.overlayImage then
        local overlayItem = TablePool.getGeneric()
        overlayItem.depth = depth
        overlayItem.type = "spritesheet_effect_overlay"
        overlayItem.sortY = position.y + 2 -- Garante que renderize sobre a base
        overlayItem.drawFunction = function() self:_drawOverlay() end
        renderPipeline:add(overlayItem)
    end
end

--- Desenha a imagem base.
function SpritesheetEffect:_drawBase()
    if self.isFinished or self.currentFrame > #self.quads then return end

    love.graphics.setColor(self.config.tint)

    local quad = self.quads[self.currentFrame]
    local drawX = self.config.position.x - (self.frameWidth / 2)
    local drawY = self.config.position.y - (self.frameHeight - 70)

    love.graphics.draw(self.config.baseImage, quad, drawX, drawY)

    love.graphics.setColor(1, 1, 1, 1)
end

--- Desenha a imagem de overlay.
function SpritesheetEffect:_drawOverlay()
    if self.isFinished or not self.overlayQuads or self.currentFrame > #self.overlayQuads then return end

    local previousBlendMode = love.graphics.getBlendMode()
    love.graphics.setBlendMode("add")

    love.graphics.setColor(self.config.overlayTint)

    local quad = self.overlayQuads[self.currentFrame]
    local drawX = self.config.position.x - (self.frameWidth / 2)
    local drawY = self.config.position.y - (self.frameHeight - 70)

    love.graphics.draw(self.config.overlayImage, quad, drawX, drawY)

    love.graphics.setBlendMode(previousBlendMode)
    love.graphics.setColor(1, 1, 1, 1)
end

--- Desenha o círculo expansível.
function SpritesheetEffect:_drawExpandingCircle()
    local circleConfig = self.config.expandingCircle
    local circleState = self.expandingCircleState
    if self.isFinished or not circleConfig or not circleState or circleState.currentRadius <= circleConfig.initialRadius then
        return
    end

    love.graphics.setColor(circleConfig.color)

    local radiusX = circleState.currentRadius
    local radiusY = circleState.currentRadius * 0.5 -- Perspectiva isométrica
    local circleX = self.config.position.x
    local circleY = self.config.position.y + 10

    love.graphics.setLineWidth(circleConfig.lineWidth or 1)
    love.graphics.ellipse("line", circleX, circleY, radiusX, radiusY)

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

return SpritesheetEffect
