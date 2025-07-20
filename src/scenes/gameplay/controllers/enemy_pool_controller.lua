---@class EnemyPoolController
---@description Gerencia a reutilização de instâncias de inimigos para otimização.
---@field enemyPool table<string, BaseEnemy>
local EnemyPoolController = {}
EnemyPoolController.__index = EnemyPoolController

---@return EnemyPoolController
function EnemyPoolController:new()
    local instance = setmetatable({}, EnemyPoolController)
    instance.enemyPool = {}
    return instance
end

function EnemyPoolController:init()
    Logger.info("enemy_pool_controller.init.success", "[EnemyPoolController:init] Enemy Pool Controller initialized.")
end

function EnemyPoolController:destroy()
    self.enemyPool = {}
    Logger.info("enemy_pool_controller.destroy.success", "[EnemyPoolController:destroy] Enemy Pool Controller destroyed.")
end

return EnemyPoolController
