--[[
    Efeito visual de level up
    Baseado no TeleportEffect mas com múltiplas camadas e tonalidade roxa
]]

local AssetManager = require("src.managers.asset_manager")
local TablePool = require("src.utils.table_pool")
local RenderPipeline = require("src.core.render_pipeline")

---@class LevelUpEffect
---@field position { x: number, y: number }
---@field baseImage love.Image
---@field overlayImage love.Image
---@field width number
---@field height number
---@field grid { columns: number, rows: number }
---@field frameWidth number
---@field frameHeight number
---@field baseQuads table
---@field overlayQuads table
---@field animTimer number
---@field frameDuration number
---@field currentFrame number
---@field isFinished boolean
---@field purpleTint { r: number, g: number, b: number, a: number }
---@field knockbackCircle { initialRadius: number, maxRadius: number, currentRadius: number, alpha: number }
local LevelUpEffect = {}
LevelUpEffect.__index = LevelUpEffect

---@param position { x: number, y: number }
function LevelUpEffect:new(position)
    local instance = setmetatable({}, LevelUpEffect)

    instance.position = position

    -- Carrega as duas imagens
    local baseImage = AssetManager:getImage("assets/effects/teleporter-effect-var-5.png")
    local overlayImage = AssetManager:getImage("assets/effects/teleporter-effect-var-5-overlay.png")

    if not baseImage then
        error("LevelUpEffect base image not found: assets/effects/teleporter-effect-var-5.png")
    end
    if not overlayImage then
        error("LevelUpEffect overlay image not found: assets/effects/teleporter-effect-var-5-overlay.png")
    end

    instance.baseImage = baseImage
    instance.overlayImage = overlayImage
    instance.width = instance.baseImage:getWidth()
    instance.height = instance.baseImage:getHeight()

    -- Configuração da grid (assumindo mesmo layout do teleport effect)
    instance.grid = { columns = 10, rows = 10 }
    instance.frameWidth = instance.width / instance.grid.columns
    instance.frameHeight = instance.height / instance.grid.rows

    -- Cria quads para ambas as imagens
    instance.baseQuads = {}
    instance.overlayQuads = {}

    for r = 0, instance.grid.rows - 1 do
        for c = 0, instance.grid.columns - 1 do
            local quad = love.graphics.newQuad(
                c * instance.frameWidth,
                r * instance.frameHeight,
                instance.frameWidth,
                instance.frameHeight,
                instance.width,
                instance.height
            )
            table.insert(instance.baseQuads, quad)

            -- Reutiliza o mesmo quad para overlay (assumindo mesmo layout)
            local overlayQuad = love.graphics.newQuad(
                c * instance.frameWidth,
                r * instance.frameHeight,
                instance.frameWidth,
                instance.frameHeight,
                instance.overlayImage:getWidth(),
                instance.overlayImage:getHeight()
            )
            table.insert(instance.overlayQuads, overlayQuad)
        end
    end

    instance.animTimer = 0
    instance.frameDuration = 0.01
    instance.currentFrame = 1
    instance.isFinished = false

    -- Tonalidade roxa para o efeito de level up (mais transparente)
    instance.purpleTint = { r = 0.8, g = 0.3, b = 1.0, a = 1 }

    -- Configuração do círculo de knockback (mais transparente)
    instance.knockbackCircle = {
        initialRadius = 10,
        maxRadius = 120,
        currentRadius = 10,
        alpha = 0.4 -- Reduzido para manter consistência
    }

    Logger.debug(
        "level_up_effect.new.circle_init",
        "[LevelUpEffect:new] Círculo de knockback inicializado com raio máximo de 120 pixels"
    )

    return instance
end

function LevelUpEffect:update(dt)
    if self.isFinished then
        return
    end

    self.animTimer = self.animTimer + dt
    if self.animTimer >= self.frameDuration then
        self.animTimer = self.animTimer - self.frameDuration
        self.currentFrame = self.currentFrame + 1
        if self.currentFrame > #self.baseQuads then
            self.isFinished = true
        end
    end

    -- Atualiza o círculo de knockback
    self:updateKnockbackCircle(dt)
end

function LevelUpEffect:collectRenderables(renderPipeline)
    if self.isFinished then
        return
    end

    -- Adiciona o círculo de knockback (atrás de tudo)
    local circleItem = TablePool.get()
    circleItem.depth = RenderPipeline.DEPTH_EFFECTS_WORLD_UI
    circleItem.type = "level_up_effect_circle"
    circleItem.sortY = self.position.y
    circleItem.drawFunction = function() self:drawKnockbackCircle() end
    renderPipeline:add(circleItem)

    -- Adiciona a camada base
    local baseItem = TablePool.get()
    baseItem.depth = RenderPipeline.DEPTH_EFFECTS_WORLD_UI
    baseItem.type = "level_up_effect_base"
    baseItem.sortY = self.position.y + 999
    baseItem.drawFunction = function() self:drawBase() end
    renderPipeline:add(baseItem)

    -- Adiciona a camada overlay
    local overlayItem = TablePool.get()
    overlayItem.depth = RenderPipeline.DEPTH_EFFECTS_WORLD_UI
    overlayItem.type = "level_up_effect_overlay"
    overlayItem.sortY = self.position.y + 999
    overlayItem.drawFunction = function() self:drawOverlay() end
    renderPipeline:add(overlayItem)
end

function LevelUpEffect:drawBase()
    if self.isFinished or self.currentFrame > #self.baseQuads then
        return
    end

    -- Aplica tonalidade roxa com transparência aumentada
    love.graphics.setColor(
        self.purpleTint.r,
        self.purpleTint.g,
        self.purpleTint.b,
        self.purpleTint.a * 0.9 -- Reduz ainda mais a opacidade
    )

    local quad = self.baseQuads[self.currentFrame]
    local drawX = self.position.x - (self.frameWidth / 2)
    local drawY = self.position.y - (self.frameHeight - 70)

    love.graphics.draw(self.baseImage, quad, drawX, drawY)
    love.graphics.setColor(1, 1, 1, 1)
end

function LevelUpEffect:drawOverlay()
    if self.isFinished or self.currentFrame > #self.overlayQuads then
        return
    end

    -- Salva o blend mode atual
    local previousBlendMode = love.graphics.getBlendMode()

    -- Usa blend mode "add" para tornar áreas pretas transparentes e criar efeito luminoso
    love.graphics.setBlendMode("add")

    -- Overlay com transparência aumentada
    love.graphics.setColor(
        self.purpleTint.r * 1.1,
        self.purpleTint.g * 0.8,
        self.purpleTint.b,
        self.purpleTint.a * 0.9 -- Muito mais transparente
    )

    local quad = self.overlayQuads[self.currentFrame]
    local drawX = self.position.x - (self.frameWidth / 2)
    local drawY = self.position.y - (self.frameHeight - 70)

    love.graphics.draw(self.overlayImage, quad, drawX, drawY)

    -- Restaura configurações
    love.graphics.setBlendMode(previousBlendMode)
    love.graphics.setColor(1, 1, 1, 1)

    Logger.debug(
        "level_up_effect.draw.overlay_blend",
        "[LevelUpEffect:drawOverlay] Renderizando overlay com blend mode 'add' para remover fundo preto"
    )
end

--- Atualiza o círculo de knockback
function LevelUpEffect:updateKnockbackCircle(dt)
    if self.isFinished then
        return
    end

    -- Calcula o progresso da animação (0 a 1)
    local totalFrames = #self.baseQuads
    local progress = math.min(self.currentFrame / totalFrames, 1)

    -- Expansão do raio baseada no progresso
    self.knockbackCircle.currentRadius = self.knockbackCircle.initialRadius +
        (self.knockbackCircle.maxRadius - self.knockbackCircle.initialRadius) * progress

    -- Alpha diminui conforme expande (efeito de fade out)
    self.knockbackCircle.alpha = 0.4 * (1 - progress * 0.7)
end

--- Desenha o círculo de knockback em perspectiva isométrica
function LevelUpEffect:drawKnockbackCircle()
    if self.isFinished or self.knockbackCircle.currentRadius <= self.knockbackCircle.initialRadius then
        return
    end

    -- Cor roxa com alpha dinâmico
    love.graphics.setColor(
        self.purpleTint.r,
        self.purpleTint.g,
        self.purpleTint.b,
        self.knockbackCircle.alpha
    )

    -- Desenha elipse para simular perspectiva isométrica
    -- Raio horizontal normal, raio vertical reduzido para perspectiva
    local radiusX = self.knockbackCircle.currentRadius
    local radiusY = self.knockbackCircle.currentRadius * 0.5 -- Perspectiva isométrica

    -- Posição ligeiramente abaixo do personagem
    local circleX = self.position.x
    local circleY = self.position.y + 10

    -- Desenha círculo com linha grossa para melhor visibilidade
    love.graphics.setLineWidth(3)
    love.graphics.ellipse("line", circleX, circleY, radiusX, radiusY)

    -- Adiciona um círculo interno mais tênue
    love.graphics.setColor(
        self.purpleTint.r,
        self.purpleTint.g,
        self.purpleTint.b,
        self.knockbackCircle.alpha * 0.8
    )
    love.graphics.ellipse("fill", circleX, circleY, radiusX * 0.8, radiusY * 0.8)

    -- Restaura configurações
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

return LevelUpEffect
