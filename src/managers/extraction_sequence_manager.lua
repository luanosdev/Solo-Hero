local lume = require("src.libs.lume")
local TeleportEffect = require("src.effects.teleport_effect")

---@class ExtractionSequenceManager
---@field registry ManagerRegistry
---@field isActive boolean
---@field portal ExtractionPortal
---@field playerManager PlayerManager
---@field inputManager InputManager
---@field teleportEffect TeleportEffect
---@field playerInitialPos { x: number, y: number }
---@field moveTimer number
---@field moveDuration number
local ExtractionSequenceManager = {}
ExtractionSequenceManager.__index = ExtractionSequenceManager

local PORTAL_HEIGHT = 252

function ExtractionSequenceManager:new()
    local instance = setmetatable({}, ExtractionSequenceManager)
    instance.registry = nil
    instance.isActive = false
    instance.portal = nil
    instance.playerManager = nil
    instance.inputManager = nil
    instance.teleportEffect = nil

    -- State for player movement
    instance.playerInitialPos = nil
    instance.moveTimer = 0
    instance.moveDuration = 0.8 -- Seconds for the player to move to the center

    return instance
end

---Inicializa o manager e obtém referências para outros managers.
---@param config { playerManager: PlayerManager, inputManager: InputManager }
function ExtractionSequenceManager:init(config)
    self.playerManager = config.playerManager
    self.inputManager = config.inputManager
end

---Inicia a sequência de extração.
---@param portal ExtractionPortal O portal que iniciou a extração.
function ExtractionSequenceManager:start(portal)
    if self.isActive then return end

    print("[ExtractionSequenceManager] Starting extraction sequence.")
    self.isActive = true
    self.portal = portal
    self.playerInitialPos = self.playerManager.player.position
    self.moveTimer = 0

    -- Desativa os inputs do jogador
    if self.inputManager then
        self.inputManager:setMovementEnabled(false)
        self.inputManager:setActionsEnabled(false)
    end

    -- Cria o efeito de teleporte na posição do portal
    local y = portal.position.y - PORTAL_HEIGHT / 2
    self.teleportEffect = TeleportEffect:new(portal.position.x, y)
end

function ExtractionSequenceManager:update(dt)
    if not self.isActive then return end

    -- 1. Mover o jogador suavemente para o centro do portal
    if self.moveTimer < self.moveDuration then
        self.moveTimer = self.moveTimer + dt
        local t = math.min(self.moveTimer / self.moveDuration, 1.0)

        local portalY = self.portal.position.y - PORTAL_HEIGHT / 4
        local newX = lume.lerp(self.playerInitialPos.x, self.portal.position.x, t)
        local newY = lume.lerp(self.playerInitialPos.y, portalY, t)

        self.playerManager:setPosition({ x = newX, y = newY })
    end

    -- 2. Atualizar o efeito de teleporte
    if self.teleportEffect then
        self.teleportEffect:update(dt)
    end

    -- (A lógica seguinte da sequência virá aqui)
end

function ExtractionSequenceManager:collectRenderables(renderPipeline)
    if not self.isActive or not self.teleportEffect then return end

    self.teleportEffect:collectRenderables(renderPipeline)
end

function ExtractionSequenceManager:getActive()
    return self.isActive
end

return ExtractionSequenceManager
