---@class TargetingController
---@description Gerencia a lógica de mira (targeting), decidindo para onde o jogador deve mirar.
--- Pode alternar entre mira automática no inimigo mais próximo e mira manual no mouse.
---@field enemyManager EnemyManager
---@field inputService InputService
---@field camera Camera
---@field autoAimEnabled boolean
local TargetingController = {}
TargetingController.__index = TargetingController

---@class TargetingControllerDeps
---@field enemyManager EnemyManager
---@field inputService InputService
---@field camera Camera

---@public
---@param deps TargetingControllerDeps
---@return TargetingController
function TargetingController:new(deps)
    local instance = setmetatable({}, TargetingController)
    instance.enemyManager = deps.enemyManager
    instance.inputService = deps.inputService
    instance.camera = deps.camera
    instance.autoAimEnabled = false -- Default to off
    return instance
end

---@public
function TargetingController:init()
    Logger.info("targeting_controller.init", "[TargetingController:init] Inicializado.")
end

---@public
--- Retorna a posição do alvo.
---@param playerPosition Vector2D A posição atual do jogador.
---@param forceMouse boolean Força o uso do mouse, ignorando o auto-aim.
---@return Vector2D
function TargetingController:getTargetPosition(playerPosition, forceMouse)
    if self.autoAimEnabled and not forceMouse then
        local closestEnemy = self:_findClosestEnemy(playerPosition)
        if closestEnemy then
            return closestEnemy.position
        end
    end

    -- Fallback para a posição do mouse
    local mouseX, mouseY = self.inputService:getMousePosition()
    local worldX, worldY = self.camera:screenToWorld(mouseX, mouseY)

    return {
        x = worldX,
        y = worldY
    }
end

---@private
--- Encontra o inimigo mais próximo da posição do jogador.
---@param position Vector2D Posição de referência (do jogador).
---@return BaseEnemy|nil O inimigo mais próximo ou nil.
function TargetingController:_findClosestEnemy(position)
    local enemies = self.enemyManager:getEnemies()
    if not enemies or #enemies == 0 then
        return nil
    end

    local closestEnemy = nil
    local minDistanceSq = math.huge

    for _, enemy in ipairs(enemies) do
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

    return closestEnemy
end

---@public
--- Define o estado do auto-aim.
---@param enabled boolean
function TargetingController:setAutoAimEnabled(enabled)
    self.autoAimEnabled = enabled
    Logger.info("targeting_controller.set.aim",
        string.format("[TargetingController:setAutoAimEnabled] Auto-aim definido para: %s", tostring(enabled))
    )
end

---@public
--- Alterna o estado do auto-aim.
function TargetingController:toggleAutoAim()
    self:setAutoAimEnabled(not self.autoAimEnabled)
end

---@public
--- Verifica se o auto-aim está habilitado.
---@return boolean
function TargetingController:isAutoAimEnabled()
    return self.autoAimEnabled
end

---@public
--- Limpa os recursos do controller.
function TargetingController:destroy()
    Logger.info("targeting_controller.destroy", "[TargetingController:destroy] Destruído.")
end

return TargetingController
