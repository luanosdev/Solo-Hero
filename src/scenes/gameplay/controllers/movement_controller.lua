--------------------------------------------------------------------------------
--- MovementController (v2)
--- @description Gerencia a posição, velocidade e estado de movimento do jogador.
--- Este controlador é "puro" e não lida com sprites ou animações. Ele apenas
--- calcula a posição do jogador no mundo com base no input e nos stats.
--------------------------------------------------------------------------------
local Constants = require("src.config.constants")

---@class MovementControllerV2
---@field playerStateController PlayerStateController Referência ao controlador de estado para obter stats.
---@field inputManager InputManager Referência para obter o vetor de movimento.
---@field worldPosition Vector2D Posição atual do jogador no mundo (em pixels).
---@field velocity Vector2D Vetor de velocidade atual (para animações).
---@field isDashing boolean Cache do estado de dash para evitar chamadas repetidas.
local MovementController = {}
MovementController.__index = MovementController

---@param deps table Tabela de dependências contendo os managers necessários.
---@return MovementControllerV2
function MovementController:new(deps)
    assert(deps.playerStateController, "MovementController requer playerStateController")
    assert(deps.inputManager, "MovementController requer inputManager")

    local instance = setmetatable({}, MovementController)
    instance.playerStateController = deps.playerStateController
    instance.inputManager = deps.inputManager
    instance.worldPosition = { x = 0, y = 0 }
    instance.velocity = { x = 0, y = 0 }
    instance.isDashing = false
    return instance
end

--- Inicializa o estado do controlador.
---@param initialPosition Vector2D A posição inicial do jogador no mundo.
function MovementController:init(initialPosition)
    self.worldPosition = initialPosition
    self.velocity = { x = 0, y = 0 }
    self.isDashing = false
    Logger.info("movement_controller.init",
        string.format("[MovementController] Inicializado na posição (%.1f, %.1f)", self.worldPosition.x,
            self.worldPosition.y))
end

--- Atualiza a posição do jogador com base no input e stats.
---@param dt number Delta time.
---@param isMovementBlocked boolean Se o movimento está bloqueado por uma UI ou outra ação.
function MovementController:update(dt, isMovementBlocked)
    if isMovementBlocked then
        self.velocity = { x = 0, y = 0 }
        return
    end

    local finalStats = self.playerStateController:getFinalStats()
    local moveSpeedInPixels = Constants.moveSpeedToPixels(finalStats.moveSpeed)
    local moveVector = self.inputManager:getMovementVector()

    -- O vetor de velocidade é o input bruto, para que a animação saiba a direção.
    self.velocity = { x = moveVector.x, y = moveVector.y }

    local magnitude = math.sqrt(moveVector.x * moveVector.x + moveVector.y * moveVector.y)
    if magnitude > 0 then
        local normalizedInputX = moveVector.x / magnitude
        local normalizedInputY = moveVector.y / magnitude
        local moveAmount = moveSpeedInPixels * dt

        -- Atualiza as coordenadas do mundo em pixels
        self.worldPosition.x = self.worldPosition.x + normalizedInputX * moveAmount
        self.worldPosition.y = self.worldPosition.y + normalizedInputY * moveAmount

        -- TODO: Registrar distância movida no GameStatisticsManager
    end
end

--- Retorna a posição atual do jogador no mundo.
---@return Vector2D
function MovementController:getPosition()
    return self.worldPosition
end

--- Retorna a velocidade atual do jogador.
---@return Vector2D
function MovementController:getVelocity()
    return self.velocity
end

--- Define a posição do jogador no mundo. Usado por sistemas como o Dash.
---@param newPosition Vector2D
function MovementController:setPosition(newPosition)
    self.worldPosition.x = newPosition.x
    self.worldPosition.y = newPosition.y
end

return MovementController
