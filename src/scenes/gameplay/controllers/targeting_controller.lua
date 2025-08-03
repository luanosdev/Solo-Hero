local BaseController = require("src.controllers.base_controller")
local Camera = require("src.config.camera")
local ActionTypes = require("src.types.action_types")
local TablePool = require("src.utils.table_pool")

---@class TargetingController : BaseController
---@description Gerencia a lógica de mira (targeting), decidindo para onde o jogador deve mirar.
--- Pode alternar entre mira automática no inimigo mais próximo e mira manual no mouse.
---@field autoAimEnabled boolean
local TargetingController = setmetatable({}, { __index = BaseController })
TargetingController.__index = TargetingController

TargetingController.TARGETING_RADIUS = 300

---@public
---@param context GameplayControllerContext
---@return TargetingController
function TargetingController:new(context)
    assert(context, "[TargetingController:new] 'context' dependency is missing.")

    ---@type TargetingController
    local instance = BaseController.new(self, context)

    instance.autoAimEnabled = false -- Default to off

    return instance
end

---@public Retorna a posição do alvo.
---@param playerPosition Vector2D A posição atual do jogador.
---@param spatialGrid SpatialGridIncremental
---@param forceMouse boolean Força o uso do mouse, ignorando o auto-aim.
---@return Vector2D
function TargetingController:getTargetPosition(playerPosition, spatialGrid, forceMouse)
    if self.autoAimEnabled and not forceMouse then
        local closestEnemy = self:_findClosestEnemy(playerPosition, spatialGrid)
        if closestEnemy then
            return closestEnemy.position
        end
    end

    local inputService = self.context.services.inputService
    local mouseX, mouseY = inputService:getMousePosition()
    local worldX, worldY = Camera:screenToWorld(mouseX, mouseY)

    return {
        x = worldX,
        y = worldY
    }
end

---@public
function TargetingController:update()
    if self.context.services.inputService:wasActionPressed(ActionTypes.TOGGLE_AUTO_AIM) then
        self:toggleAutoAim()
    end
end

---@private Encontra o inimigo mais próximo da posição do jogador.
---@param position Vector2D Posição de referência (do jogador).
---@param spatialGrid SpatialGridIncremental
---@return BaseEnemy|nil O inimigo mais próximo ou nil.
function TargetingController:_findClosestEnemy(position, spatialGrid)
    local nearbyEntities = spatialGrid:getNearbyEntities(
        position.x,
        position.y,
        TargetingController.TARGETING_RADIUS,
        nil
    )

    -- Encontra o inimigo mais próximo
    local closestEnemy = nil
    local minDistanceSq = math.huge

    for _, enemy in ipairs(nearbyEntities) do
        if enemy.isAlive then
            local dx = enemy.position.x - position.x
            local dy = enemy.position.y - position.y
            local distanceSq = dx * dx + dy * dy
            if distanceSq < minDistanceSq then
                minDistanceSq = distanceSq
                closestEnemy = enemy
            end
        end
    end

    TablePool.releaseArray(nearbyEntities)

    return closestEnemy
end

---@public Define o estado do auto-aim.
---@param enabled boolean
function TargetingController:setAutoAimEnabled(enabled)
    self.autoAimEnabled = enabled
    Logger.info(
        "targeting_controller.set.aim",
        string.format("[TargetingController:setAutoAimEnabled] Auto-aim definido para: %s", tostring(enabled))
    )
end

---@public Alterna o estado do auto-aim.
function TargetingController:toggleAutoAim()
    self:setAutoAimEnabled(not self.autoAimEnabled)
end

---@public Verifica se o auto-aim está habilitado.
---@return boolean
function TargetingController:isAutoAimEnabled()
    return self.autoAimEnabled
end

return TargetingController
