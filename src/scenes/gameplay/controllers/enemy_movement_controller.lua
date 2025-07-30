local MathUtils = require("src.utils.math_utils")

---@class EnemyMovementController
---@description Gerencia o cálculo do movimento de todos os inimigos, determinando sua velocidade.
local EnemyMovementController = {}
EnemyMovementController.__index = EnemyMovementController

---@return EnemyMovementController
function EnemyMovementController:new()
    local instance = setmetatable({}, EnemyMovementController)
    return instance
end

--- Inicializa o controller.
function EnemyMovementController:init()
    -- Inicialização, se necessário
    Logger.info("EnemyMovementController", "Controller de movimento inicializado.")
end

---@public Atualiza o vetor de velocidade para todos os inimigos.
---@param dt number Delta time.
---@param enemies BaseEnemy[] A lista de todos os inimigos ativos.
---@param playerPosition Vector2D A posição atual do jogador.
---@param mapInfo table Informações do mapa para cálculo toroidal.
function EnemyMovementController:update(dt, enemies, playerPosition, mapInfo)
    local currentTime = love.timer.getTime()

    for _, enemy in ipairs(enemies) do
        -- Apenas atualiza a direção se o tempo do intervalo de cache passou.
        if currentTime - enemy.lastDirectionUpdate >= enemy.directionUpdateInterval then
            enemy.lastDirectionUpdate = currentTime

            -- Escolhe a estratégia de cálculo de direção.
            if enemy.isBoss or enemy.isMVP then
                self:_calculateTorusChaseVector(enemy, playerPosition, mapInfo)
            else
                self:_calculateSimpleChaseVector(enemy, playerPosition)
            end
        end

        -- Aplica movimento usando a direção já cacheada.
        local moveSpeed = enemy.speed
        enemy.velocity.x = enemy.cachedDirection.x * moveSpeed
        enemy.velocity.y = enemy.cachedDirection.y * moveSpeed
    end
end

---@private Calcula o vetor de movimento para perseguição simples (linha reta).
---@param enemy BaseEnemy
---@param playerPosition Vector2D
function EnemyMovementController:_calculateSimpleChaseVector(enemy, playerPosition)
    if not playerPosition then
        enemy.cachedDirection.x = 0
        enemy.cachedDirection.y = 0
        return
    end

    local directionX = playerPosition.x - enemy.position.x
    local directionY = playerPosition.y - enemy.position.y

    enemy.cachedDirection.x, enemy.cachedDirection.y = MathUtils.normalize(directionX, directionY)
end

---@private Calcula o vetor de movimento para um inimigo que persegue o jogador em um mapa infinito (lógica toroidal).
---@param enemy BaseEnemy
---@param playerPosition Vector2D
---@param mapInfo table
function EnemyMovementController:_calculateTorusChaseVector(enemy, playerPosition, mapInfo)
    if not playerPosition then
        enemy.cachedDirection.x = 0
        enemy.cachedDirection.y = 0
        return
    end

    local enemyTilePos = mapInfo.isometricToCartesianTile(enemy.position.x, enemy.position.y)
    local playerTilePos = mapInfo.isometricToCartesianTile(playerPosition.x, playerPosition.y)

    local deltaTileX, deltaTileY = MathUtils.calculateShortestTorusVector(
        enemyTilePos.x,
        enemyTilePos.y,
        playerTilePos.x,
        playerTilePos.y,
        mapInfo.worldTileWidth,
        mapInfo.worldTileHeight
    )

    local nextStepTileX = enemyTilePos.x + deltaTileX
    local nextStepTileY = enemyTilePos.y + deltaTileY

    local targetIsoPos = mapInfo.cartesianToIsometric(nextStepTileX, nextStepTileY)

    local directionX = targetIsoPos.x - enemy.position.x
    local directionY = targetIsoPos.y - enemy.position.y

    enemy.cachedDirection.x, enemy.cachedDirection.y = MathUtils.normalize(directionX, directionY)
end

--- Destroi o controller e limpa recursos.
function EnemyMovementController:destroy()
    -- Limpeza, se necessário
end

return EnemyMovementController
