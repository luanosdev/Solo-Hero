local BaseProjectile = require("src.entities.projectiles.base_projectile")
local TablePool = require("src.utils.table_pool")

-- Carrega o spritesheet e cria os Quads uma vez
local fireSheet = love.graphics.newImage("assets/attacks/fire_particle/fireSheet5x5.png")
local sheetWidth = fireSheet:getWidth()
local sheetHeight = fireSheet:getHeight()
local frameWidth = sheetWidth / 5
local frameHeight = sheetHeight / 5
local totalFrames = 25
local quads = {}
for row = 0, 4 do
    for col = 0, 4 do
        local frameIndex = row * 5 + col + 1
        quads[frameIndex] = love.graphics.newQuad(col * frameWidth, row * frameHeight, frameWidth, frameHeight,
            sheetWidth, sheetHeight)
    end
end

local animationFrameTime = 0.04 -- Tempo entre frames
local baseScale = 0.8           -- Fator de escala base padrão

local PARTICLE_VISUAL_ADJUSTMENT_FACTOR = 0.6

-- Constantes de crescimento
local INITIAL_GROWTH_DURATION_RATIO = 0.1 -- 10% da vida inicial para crescimento
local INITIAL_SCALE_MULTIPLIER = 0.15     -- Nasce com 15% do tamanho final

---@class FireParticle : BaseProjectile
---@field initialLifetime number O tempo de vida total original da partícula.
---@field collisionRadius number O raio de colisão dinâmico da partícula.
---@field currentScaleFactor number O fator de escala atual (para crescimento/encolhimento).
local FireParticle = setmetatable({}, { __index = BaseProjectile })
FireParticle.__index = FireParticle

--- Construtor para FireParticle.
--- @param params table Tabela de parâmetros.
function FireParticle:new(params)
    -- Define o custo de durabilidade por acerto para esta classe.
    -- Custo baixo: 0.10 permite ~10 acertos, simulando bem um efeito de fogo.
    params.hitCost = params.hitCost or 0.10

    local instance = setmetatable({}, FireParticle)
    instance:reset(params)
    return instance
end

function FireParticle:reset(params)
    -- Chama o reset da classe base
    BaseProjectile.reset(self, params)

    -- Propriedades específicas da FireParticle
    self.initialLifetime = params.lifetime
    self.areaMultiplier = params.areaMultiplier or 1.0

    local effectivePlayerBaseScale = (params.playerBaseScale or baseScale) * PARTICLE_VISUAL_ADJUSTMENT_FACTOR
    self.playerBaseScale = effectivePlayerBaseScale

    self.currentScaleFactor = INITIAL_SCALE_MULTIPLIER
    self.collisionRadius = (math.min(frameWidth, frameHeight) / 2) * self.currentScaleFactor *
        self.playerBaseScale * self.areaMultiplier

    -- Estado da Animação
    self.animationTimer = 0
    self.currentFrame = love.math.random(1, totalFrames)
end

function FireParticle:update(dt)
    if not self.isActive then return end

    -- 1. Consome durabilidade com base no tempo de vida
    self:_updateLifetime(dt)
    if not self.isActive then return end

    -- 2. Atualiza escala e raio de colisão (lógica de crescimento)
    self:_updateScaleAndRadius()

    -- 3. Move a partícula
    self.position.x = self.position.x + self.velocity.x * dt
    self.position.y = self.position.y + self.velocity.y * dt

    -- 4. Atualiza animação
    self:_updateAnimation(dt)

    -- 5. Verifica colisão
    self:checkCollision()
end

--- Consome durabilidade com base no tempo.
function FireParticle:_updateLifetime(dt)
    if self.initialLifetime <= 0 then return end

    local durabilityCost = dt / self.initialLifetime
    self.durability = self.durability - durabilityCost
    if self.durability <= 0 then
        self.isActive = false
    end
end

function FireParticle:_updateScaleAndRadius()
    local lifeProgress = 1.0 - self.durability -- Usa a durabilidade atual para o progresso

    if lifeProgress <= INITIAL_GROWTH_DURATION_RATIO then
        local growthProgress = lifeProgress / INITIAL_GROWTH_DURATION_RATIO
        self.currentScaleFactor = INITIAL_SCALE_MULTIPLIER + (1 - INITIAL_SCALE_MULTIPLIER) * growthProgress
    else
        self.currentScaleFactor = 1.0
    end

    local dynamicScale = self.playerBaseScale * self.areaMultiplier * self.currentScaleFactor
    self.collisionRadius = (math.min(frameWidth, frameHeight) / 2) * dynamicScale
end

function FireParticle:_updateAnimation(dt)
    self.animationTimer = self.animationTimer + dt
    while self.animationTimer >= animationFrameTime do
        self.animationTimer = self.animationTimer - animationFrameTime
        self.currentFrame = self.currentFrame + 1
        if self.currentFrame > totalFrames then
            self.currentFrame = 1
        end
    end
end

function FireParticle:_getSearchBounds()
    return { x = self.position.x, y = self.position.y, radius = self.collisionRadius * 1.5 }
end

function FireParticle:_getCollisionCircle()
    return { x = self.position.x, y = self.position.y, radius = self.collisionRadius }
end

function FireParticle:draw()
    if not self.isActive then return end

    local currentAlpha = self.durability -- A opacidade reflete a durabilidade restante
    local finalVisualScale = self.playerBaseScale * self.areaMultiplier * self.currentScaleFactor

    if finalVisualScale > 0.05 and currentAlpha > 0.05 then
        love.graphics.setColor(self.color[1], self.color[2], self.color[3], currentAlpha)

        local previousBlendMode = love.graphics.getBlendMode()
        love.graphics.setBlendMode("add")

        love.graphics.draw(
            fireSheet,
            quads[self.currentFrame],
            self.position.x,
            self.position.y,
            0,
            finalVisualScale,
            finalVisualScale,
            frameWidth / 2,
            frameHeight / 2
        )

        love.graphics.setBlendMode(previousBlendMode)
    end

    if DEBUG_SHOW_PARTICLE_COLLISION_RADIUS then
        love.graphics.push()
        love.graphics.setShader()
        local r, gr, b, a = love.graphics.getColor()
        love.graphics.setColor(0, 1, 0, 0.6)
        love.graphics.circle("line", self.position.x, self.position.y, self.collisionRadius)
        love.graphics.setColor(r, gr, b, a)
        love.graphics.pop()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return FireParticle
