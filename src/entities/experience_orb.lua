--[[
    Experience Orb
    Representa um orbe de experiência que pode ser coletado pelo jogador
    Usando spritesheet animado com otimizações de performance
]]

local ManagerRegistry = require("src.managers.manager_registry")
local Constants = require("src.config.constants")

---@class ExperienceOrb
---@field position Vector2D Posição atual do orbe
---@field initialPosition Vector2D Posição inicial do orbe
---@field experience number Quantidade de experiência
---@field collected boolean Se o orbe foi coletado
---@field collectionProgress number Progresso da animação de coleta (0 a 1)
---@field levitationTime number Timer para animação de levitação
---@field currentFrame number Frame atual da animação
---@field animationTimer number Timer para animação
---@field lastUpdateTime number Último tempo de update (para otimização)
---@field tiltAngle number Ângulo de inclinação atual
---@field isMoving boolean Se o orbe está se movendo
---@field velocity Vector2D Velocidade atual do orbe
---@field active boolean Se o orbe está ativo (para pooling)
local ExperienceOrb = {}
ExperienceOrb.__index = ExperienceOrb

-- Configurações estáticas do spritesheet
ExperienceOrb.SPRITE_COLS = 5
ExperienceOrb.SPRITE_ROWS = 2
ExperienceOrb.TOTAL_FRAMES = 10
ExperienceOrb.ANIMATION_SPEED = 0.1   -- Tempo entre frames em segundos
ExperienceOrb.UPDATE_INTERVAL = 0.033 -- ~30 FPS para updates de física (otimização)

-- Configurações de coleta
ExperienceOrb.IMMEDIATE_COLLECTION_RADIUS = 25 -- Raio para coleta imediata
ExperienceOrb.COLLECTION_SPEED = 8.0           -- Velocidade de animação de coleta

-- Configurações de movimento e visual
ExperienceOrb.LEVITATION_HEIGHT = 5
ExperienceOrb.LEVITATION_SPEED = 3
ExperienceOrb.MAX_TILT_ANGLE = 0.3 -- Máxima inclinação em radianos (~17 graus)

function ExperienceOrb:new(x, y, exp)
    local orb = setmetatable({
        position = { x = x, y = y },
        initialPosition = { x = x, y = y },
        experience = exp or 1,
        collected = false,
        collectionProgress = 0,
        levitationTime = math.random() * math.pi * 2,
        currentFrame = 1,
        animationTimer = 0,
        lastUpdateTime = 0,
        tiltAngle = 0,
        isMoving = false,
        velocity = { x = 0, y = 0 },
        active = true
    }, self)

    return orb
end

-- Método para resetar o orbe (para pooling)
function ExperienceOrb:reset(x, y, exp)
    self.position.x = x
    self.position.y = y
    self.initialPosition.x = x
    self.initialPosition.y = y
    self.experience = exp or 1
    self.collected = false
    self.collectionProgress = 0
    self.levitationTime = math.random() * math.pi * 2
    self.currentFrame = 1
    self.animationTimer = 0
    self.lastUpdateTime = 0
    self.tiltAngle = 0
    self.isMoving = false
    self.velocity.x = 0
    self.velocity.y = 0
    self.active = true
end

-- Método para desativar o orbe (para pooling)
function ExperienceOrb:deactivate()
    self.active = false
    self.collected = true
end

function ExperienceOrb:update(dt)
    if self.collected or not self.active then return false end

    local currentTime = love.timer.getTime()

    -- Otimização: não atualizar física a cada frame
    local shouldUpdatePhysics = (currentTime - self.lastUpdateTime) >= self.UPDATE_INTERVAL

    -- Sempre atualizar animação para manter fluida
    self:_updateAnimation(dt)

    if shouldUpdatePhysics then
        self.lastUpdateTime = currentTime
        return self:_updatePhysics(dt)
    end

    return false
end

function ExperienceOrb:_updateAnimation(dt)
    -- Atualiza animação do spritesheet
    self.animationTimer = self.animationTimer + dt
    if self.animationTimer >= self.ANIMATION_SPEED then
        self.animationTimer = 0
        self.currentFrame = (self.currentFrame % self.TOTAL_FRAMES) + 1
    end

    -- Atualiza levitação
    self.levitationTime = self.levitationTime + dt * self.LEVITATION_SPEED

    -- Atualiza inclinação suavemente
    if self.isMoving then
        -- Calcula ângulo baseado na velocidade
        local targetAngle = math.atan2(self.velocity.y, self.velocity.x)
        local angleDiff = targetAngle - self.tiltAngle

        -- Normaliza diferença de ângulo
        if angleDiff > math.pi then
            angleDiff = angleDiff - 2 * math.pi
        elseif angleDiff < -math.pi then
            angleDiff = angleDiff + 2 * math.pi
        end

        -- Aplica suavização
        self.tiltAngle = self.tiltAngle + angleDiff * dt * 10

        -- Limita inclinação máxima
        local tiltMagnitude = math.abs(math.sin(self.tiltAngle))
        if tiltMagnitude > self.MAX_TILT_ANGLE then
            self.tiltAngle = (self.tiltAngle > 0 and 1 or -1) * self.MAX_TILT_ANGLE
        end
    else
        -- Volta gradualmente para posição neutra
        self.tiltAngle = self.tiltAngle * (1 - dt * 5)
    end
end

function ExperienceOrb:_updatePhysics(dt)
    local playerManager = ManagerRegistry:get("playerManager") ---@type PlayerManager
    local playerPos = playerManager:getPlayerPosition()

    local dx = playerPos.x - self.position.x
    local dy = playerPos.y - self.position.y
    local distance = math.sqrt(dx * dx + dy * dy)

    -- Área de coleta aumentada
    local currentFinalStats = playerManager:getCurrentFinalStats()
    local pickupRadiusInPixels = Constants.metersToPixels(currentFinalStats.pickupRadius)

    if distance <= pickupRadiusInPixels then
        -- Coleta imediata se muito próximo
        if distance <= self.IMMEDIATE_COLLECTION_RADIUS then
            self.collected = true
            return true
        end

        -- Inicia animação de coleta
        self.isMoving = true
        self.collectionProgress = math.min(self.collectionProgress + dt * self.COLLECTION_SPEED, 1)

        -- Função de easing para movimento suave
        local t = self.collectionProgress
        local easeOutQuad = 1 - (1 - t) * (1 - t)

        -- Calcula nova posição
        local newX = self.initialPosition.x + (playerPos.x - self.initialPosition.x) * easeOutQuad
        local newY = self.initialPosition.y + (playerPos.y - self.initialPosition.y) * easeOutQuad

        -- Atualiza velocidade para inclinação
        self.velocity.x = (newX - self.position.x) / dt
        self.velocity.y = (newY - self.position.y) / dt

        -- Atualiza posição
        self.position.x = newX
        self.position.y = newY

        -- Finaliza coleta
        if self.collectionProgress >= 1 then
            self.collected = true
            return true
        end
    else
        self.isMoving = false
        self.velocity.x = 0
        self.velocity.y = 0
    end

    return false
end

-- Método para obter dados de renderização para SpriteBatch
function ExperienceOrb:getRenderData()
    if self.collected or not self.active then return nil end

    local levitationOffset = math.sin(self.levitationTime) * self.LEVITATION_HEIGHT
    local x = self.position.x
    local y = self.position.y + levitationOffset

    -- Calcula UV do frame atual
    local frameX = (self.currentFrame - 1) % self.SPRITE_COLS
    local frameY = math.floor((self.currentFrame - 1) / self.SPRITE_COLS)

    return {
        x = x,
        y = y,
        rotation = self.tiltAngle,
        frameX = frameX,
        frameY = frameY,
        scale = 0.15 + (self.collectionProgress * 0.2), -- Cresce ligeiramente durante coleta
        alpha = 1 - (self.collectionProgress * 0.3)     -- Fade out durante coleta
    }
end

-- Método para obter posição para culling
function ExperienceOrb:getPosition()
    return self.position
end

-- Método para verificar se está ativo
function ExperienceOrb:isActive()
    return self.active and not self.collected
end

return ExperienceOrb
