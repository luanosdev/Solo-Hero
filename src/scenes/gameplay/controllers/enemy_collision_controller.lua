local TablePool = require("src.utils.table_pool")

---@class EnemyCollisionController
---@description Gerencia a lógica de colisão entre inimigos e o jogador.
local EnemyCollisionController = {}
EnemyCollisionController.__index = EnemyCollisionController

function EnemyCollisionController:new()
    local instance = setmetatable({}, EnemyCollisionController)
    return instance
end

function EnemyCollisionController:init()
    Logger.info("enemy_collision_controller.init.success",
        "[EnemyCollisionController:init] Enemy Collision Controller initialized.")
end

---@param dt number
---@param enemies BaseEnemy[]
---@param playerData { position: Vector2D, radius: number, isAlive: boolean } Dados do jogador para colisão.
---@return BaseEnemy[] Uma lista de inimigos que colidiram com o jogador.
function EnemyCollisionController:update(dt, enemies, playerData)
    if not playerData.isAlive then return {} end

    local collidingEnemies = {}
    local playerPos = playerData.position
    local playerRadius = playerData.radius

    for _, enemy in ipairs(enemies) do
        if enemy.isAlive then
            enemy.lastDamageTime = enemy.lastDamageTime + dt
            if enemy.lastDamageTime >= enemy.damageCooldown then
                local dx = playerPos.x - enemy.position.x
                local dy = playerPos.y - enemy.position.y
                local distSq = dx * dx + dy * dy
                local combinedRadius = enemy.radius + playerRadius
                if distSq <= combinedRadius * combinedRadius then
                    table.insert(collidingEnemies, enemy)
                    enemy.lastDamageTime = 0 -- Reseta o cooldown para evitar colisões múltiplas no mesmo instante
                end
            end
        end
    end

    return collidingEnemies
end

function EnemyCollisionController:destroy()
    Logger.info("enemy_collision_controller.destroy.success",
        "[EnemyCollisionController:destroy] Enemy Collision Controller destroyed.")
end

return EnemyCollisionController
