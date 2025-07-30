local MathUtils = require("src.utils.math_utils")
local TablePool = require("src.utils.table_pool")

---@class EnemySeparationController
---@description Aplica forças de separação para evitar que inimigos se sobreponham.
---@field spatialGrid SpatialGridIncremental
---@field SEPARATION_STRENGTH number
local EnemySeparationController = {}
EnemySeparationController.__index = EnemySeparationController

---@param spatialGrid SpatialGridIncremental
function EnemySeparationController:new(spatialGrid)
    assert(spatialGrid, "EnemySeparationController requires a spatialGrid instance.")

    local instance = setmetatable({}, EnemySeparationController)
    instance.spatialGrid = spatialGrid
    instance.SEPARATION_STRENGTH = 15.0 -- Pode ser movido para Constants
    return instance
end

function EnemySeparationController:init()
    Logger.info("enemy_separation_controller.init.success",
        "[EnemySeparationController:init] Enemy Separation Controller initialized.")
end

---@param dt number
---@param enemies BaseEnemy[]
---@param mapInfo MapInfo
function EnemySeparationController:update(dt, enemies, mapInfo)
    if not self.spatialGrid then return end

    for _, enemy in ipairs(enemies) do
        if enemy.isAlive then
            self:_applySeparationToEnemy(enemy, dt, mapInfo)
        end
    end
end

---@param enemy BaseEnemy
---@param dt number
---@param mapInfo MapInfo
function EnemySeparationController:_applySeparationToEnemy(enemy, dt, mapInfo)
    local sepX, sepY = 0, 0
    local searchRadius = enemy.radius * 4
    local nearby = self.spatialGrid:getNearbyEntities(enemy.position.x, enemy.position.y, searchRadius, enemy)

    for _, other in ipairs(nearby) do
        if other.isAlive then -- A verificação de ID já é feita pelo getNearbyEntities
            -- Lógica de distância toroidal
            local selfTilePos = mapInfo.isometricToCartesianTile(enemy.position.x, enemy.position.y)
            local otherTilePos = mapInfo.isometricToCartesianTile(other.position.x, other.position.y)

            local deltaTileX, deltaTileY = MathUtils.calculateShortestTorusVector(
                selfTilePos.x, selfTilePos.y,
                otherTilePos.x, otherTilePos.y,
                mapInfo.worldTileWidth, mapInfo.worldTileHeight
            )

            local odx = (deltaTileX - deltaTileY) * (mapInfo.tileWidth / 2)
            local ody = (deltaTileX + deltaTileY) * (mapInfo.tileHeight / 2)
            odx, ody = -odx, -ody

            local dist = MathUtils.vectorLength(odx, ody)

            if dist > 0 then
                local desired = (enemy.radius + other.radius) * 1.1
                if dist < desired then
                    local force_factor = (desired - dist) / desired
                    local normalizedForce = force_factor * self.SEPARATION_STRENGTH / dist
                    sepX = sepX + odx * normalizedForce
                    sepY = sepY + ody * normalizedForce
                end
            else
                local random_angle = math.random() * math.pi * 2
                sepX = sepX + math.cos(random_angle) * self.SEPARATION_STRENGTH
                sepY = sepY + math.sin(random_angle) * self.SEPARATION_STRENGTH
            end
        end
    end

    if #nearby > 0 then
        local scale = dt * 2.5
        enemy.position.x = enemy.position.x + sepX * scale
        enemy.position.y = enemy.position.y + sepY * scale
    end

    TablePool.releaseArray(nearby)
end

function EnemySeparationController:destroy()
    Logger.info("enemy_separation_controller.destroy.success",
        "[EnemySeparationController:destroy] Enemy Separation Controller destroyed.")
end

return EnemySeparationController
