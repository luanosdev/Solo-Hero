local Constants = require("src.config.constants")

---@class MovementControllerV2
--- @description Gerencia a posição do jogador no mundo.
--- Responsável EXCLUSIVAMENTE por calcular a `worldPosition` com base no input
--- e nos stats de velocidade. Não tem conhecimento sobre sprites ou animações.
---@field worldPosition Vector2D Posição do jogador no mundo em pixels.
---@field lastMoveDistance number Distância movida no último frame (em metros).
local MovementController = {}
MovementController.__index = MovementController

---@return MovementControllerV2
function MovementController:new()
    local instance = setmetatable({}, MovementController)

    instance.worldPosition = { x = 0, y = 0 }
    instance.lastMoveDistance = 0

    return instance
end

function MovementController:init()
    -- Lógica de inicialização, se necessária no futuro.
end

--- Atualiza a posição do jogador no mundo.
---@param dt number Delta time.
---@param moveSpeedInPixels number A velocidade de movimento final, já em pixels/s.
---@param moveVector Vector2D O vetor de input normalizado do movimento.
function MovementController:update(dt, moveSpeedInPixels, moveVector)
    self.lastMoveDistance = 0

    if not moveSpeedInPixels or not moveVector then return end

    local magnitude = math.sqrt(moveVector.x * moveVector.x + moveVector.y * moveVector.y)
    if magnitude > 0 then
        local normalizedInputX = moveVector.x / magnitude
        local normalizedInputY = moveVector.y / magnitude

        local moveAmountInPixels = moveSpeedInPixels * dt

        self.worldPosition.x = self.worldPosition.x + normalizedInputX * moveAmountInPixels
        self.worldPosition.y = self.worldPosition.y + normalizedInputY * moveAmountInPixels

        self.lastMoveDistance = Constants.pixelsToMeters(moveAmountInPixels)
    end
end

--- Retorna a distância em metros que o jogador moveu no último frame.
--- Utilizado pelo GameStatisticsManager.
---@return number
function MovementController:getLastMoveDistance()
    return self.lastMoveDistance
end

--- Retorna a posição ATUAL do jogador no mundo (em pixels)
---@return Vector2D
function MovementController:getPosition()
    return self.worldPosition
end

--- Define a posição do jogador no MUNDO (em pixels).
--- Usado pelo PlayerManager para definir a posição inicial.
---@param worldPosition Vector2D
function MovementController:setPosition(worldPosition)
    self.worldPosition = worldPosition
    Logger.info("MovementController:setPosition",
        string.format("Posição do jogador definida para: (%.1f, %.1f)", worldPosition.x, worldPosition.y))
end

function MovementController:stopMovement()
    -- No futuro, poderia zerar o vetor de input no InputManager ou ter um state aqui.
    -- Por agora, a lógica de update já não move se o vetor for zero.
end

function MovementController:destroy()
    -- No futuro, poderia limpar recursos ou se desregistra de eventos.
end

return MovementController
