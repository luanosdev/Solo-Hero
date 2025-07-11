--[[
    Drop Entity
    Representa um item dropado no mundo que pode ser coletado pelo jogador
    Usa o spritesheet beam_drop.png para animação
]]

local Constants = require("src.config.constants")
local Colors = require("src.ui.colors")
local ManagerRegistry = require("src.managers.manager_registry")

---@class DropEntity
local DropEntity = {
    position = {
        x = 0,
        y = 0
    },
    initialPosition = {
        x = 0,
        y = 0
    },
    radius = 10,
    config = nil,
    collected = false,

    -- Configurações de animação
    animationTimer = 0,
    currentFrame = 1,
    animationSpeed = 8, -- frames por segundo (base)
    frameWidth = 0,
    frameHeight = 0,
    spritesheet = nil,

    -- Configurações visuais baseadas na raridade
    color = { 1, 1, 1, 1 },
    scale = 1.0,
    height = 32, -- altura do sprite

    -- Configurações de efeito visual
    glowTimer = 0,
    pulseTimer = 0
}

-- Configurações por raridade
local rarityConfigs = {
    ["E"] = {
        color = Colors.rankDetails.E.text,
        scale = 0.5,
        animationSpeed = 6,
    },
    ["D"] = {
        color = Colors.rankDetails.D.gradientStart,
        scale = 0.8,
        animationSpeed = 8,
    },
    ["C"] = {
        color = Colors.rankDetails.C.gradientStart,
        scale = 1.1,
        animationSpeed = 10,
    },
    ["B"] = {
        color = Colors.rankDetails.B.gradientStart,
        scale = 1.4,
        animationSpeed = 12,
    },
    ["A"] = {
        color = Colors.rankDetails.A.gradientStart,
        scale = 1.8,
        animationSpeed = 15,
    },
    ["S"] = {
        color = Colors.rankDetails.S.gradientStart,
        scale = 2.2,
        animationSpeed = 18,
    }
}

-- Carrega o spritesheet (estático)
local beamDropSheet = nil
local function loadSpritesheet()
    if not beamDropSheet then
        beamDropSheet = love.graphics.newImage("assets/effects/beam_drop.png")
    end
    return beamDropSheet
end

---@param position table Posição inicial do drop
---@param config table Configuração do drop
---@return DropEntity
function DropEntity:new(position, config)
    local drop = setmetatable({}, { __index = self })
    drop.initialPosition = { x = position.x, y = position.y }
    drop.position = { x = position.x, y = position.y }
    drop.config = config
    drop.collected = false
    drop.animationTimer = 0
    drop.currentFrame = 1
    drop.glowTimer = love.math.random() * 10
    drop.pulseTimer = love.math.random() * 5

    -- Carrega o spritesheet
    drop.spritesheet = loadSpritesheet()
    local imageWidth = drop.spritesheet:getWidth()
    local imageHeight = drop.spritesheet:getHeight()

    -- Calcula dimensões dos frames (10 colunas, 2 linhas)
    drop.frameWidth = imageWidth / 10
    drop.frameHeight = imageHeight / 2

    -- Configura baseado na raridade do item
    drop:_setupRarityConfig()

    return drop
end

--- Configura as propriedades visuais baseadas na raridade
function DropEntity:_setupRarityConfig()
    local rarity = "E" -- default

    -- Determina a raridade baseada no config
    if self.config.type == "item" and self.config.itemId then
        -- Obtém a raridade do item através do ItemDataManager
        ---@type ItemDataManager
        local itemDataManager = ManagerRegistry:get("itemDataManager")
        local baseData = itemDataManager:getBaseItemData(self.config.itemId)
        if baseData and baseData.rarity then
            rarity = baseData.rank or baseData.rarity
        end
    end

    -- Aplica as configurações da raridade
    local rarityConfig = rarityConfigs[rarity] or rarityConfigs["E"]
    self.color = rarityConfig.color
    self.scale = rarityConfig.scale
    self.animationSpeed = rarityConfig.animationSpeed
end

--- Reseta um drop para reutilização a partir de um pool de objetos.
---@param position table Posição inicial do drop
---@param config table Configuração do drop
function DropEntity:reset(position, config)
    self.initialPosition = { x = position.x, y = position.y }
    self.position = { x = position.x, y = position.y }
    self.config = config
    self.collected = false
    self.animationTimer = 0
    self.currentFrame = 1
    self.glowTimer = love.math.random() * 10
    self.pulseTimer = love.math.random() * 5

    -- Carrega o spritesheet se necessário
    if not self.spritesheet then
        self.spritesheet = loadSpritesheet()
        local imageWidth = self.spritesheet:getWidth()
        local imageHeight = self.spritesheet:getHeight()
        self.frameWidth = imageWidth / 10
        self.frameHeight = imageHeight / 2
    end

    -- Configura baseado na raridade do item
    self:_setupRarityConfig()
end

---@param dt number Delta time
---@param playerManager PlayerManager Instância do PlayerManager
---@return boolean True se a coleta foi concluída, false caso contrário
function DropEntity:update(dt, playerManager)
    if self.collected then return true end

    -- Atualiza timers
    self.animationTimer = self.animationTimer + dt
    self.glowTimer = self.glowTimer + dt
    self.pulseTimer = self.pulseTimer + dt

    -- Atualiza animação
    local frameTime = 1.0 / self.animationSpeed
    if self.animationTimer >= frameTime then
        self.animationTimer = self.animationTimer - frameTime
        self.currentFrame = self.currentFrame + 1
        if self.currentFrame > 20 then
            self.currentFrame = 1
        end
    end

    -- Verifica coleta automática
    local playerPos = playerManager:getPlayerPosition()
    local dx = playerPos.x - self.position.x
    local dy = playerPos.y - self.position.y
    local distance = math.sqrt(dx * dx + dy * dy)

    local currentFinalStats = playerManager:getCurrentFinalStats()
    local pickupRadiusInPixels = Constants.metersToPixels(currentFinalStats.pickupRadius)

    -- Coleta automática ao atingir a área
    if distance <= pickupRadiusInPixels then
        self.collected = true
        return true
    end

    return false
end

--- Desenha o drop usando o spritesheet beam_drop.png
function DropEntity:draw()
    if self.collected then return end

    local x, y = self.position.x, self.position.y

    -- Calcula frame atual no spritesheet
    local row = (self.currentFrame <= 10) and 0 or 1
    local col = ((self.currentFrame - 1) % 10)

    -- Cria quad para o frame atual
    local quad = love.graphics.newQuad(
        col * self.frameWidth,
        row * self.frameHeight,
        self.frameWidth,
        self.frameHeight,
        self.spritesheet:getWidth(),
        self.spritesheet:getHeight()
    )

    love.graphics.push()
    love.graphics.translate(x, y)

    -- Aplica cor da raridade
    love.graphics.setColor(self.color)

    -- Desenha o sprite centralizado
    love.graphics.draw(
        self.spritesheet,
        quad,
        0,
        0,
        0,
        self.scale,
        self.scale,
        self.frameWidth / 2,
        self.frameHeight
    )

    -- Efeito de brilho adicional para raridades altas
    if self.config and self.config.type == "item" then
        local rarity = self:_getRarity()
        if rarity == "A" or rarity == "S" then
            local glowAlpha = 0.3 + math.sin(self.glowTimer * 2) * 0.2
            love.graphics.setColor(self.color[1], self.color[2], self.color[3], glowAlpha)
            love.graphics.scale(1.2, 1.2)
            love.graphics.draw(
                self.spritesheet,
                quad,
                0,
                -self.height,
                0,
                1,
                1,
                self.frameWidth / 2,
                self.frameHeight
            )
        end
    end

    love.graphics.pop()

    -- Restaura cor
    love.graphics.setColor(1, 1, 1, 1)
end

--- Obtém a raridade do item
---@return string Raridade do item
function DropEntity:_getRarity()
    if self.config.type == "item" and self.config.itemId then
        ---@type ItemDataManager
        local itemDataManager = ManagerRegistry:get("itemDataManager")
        local baseData = itemDataManager:getBaseItemData(self.config.itemId)
        if baseData and baseData.rarity then
            return baseData.rarity
        end
    end
    return "E"
end

return DropEntity
