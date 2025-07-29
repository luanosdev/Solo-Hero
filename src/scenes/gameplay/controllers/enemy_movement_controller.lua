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
    for _, enemy in ipairs(enemies) do
        -- Por enquanto, todos os inimigos usam a mesma lógica de perseguição.
        -- Futuramente, podemos ter um campo enemy.movementBehavior para selecionar a estratégia.
        self:_calculateChaseVector(dt, enemy, playerPosition, mapInfo)
    end
end

---@private Calcula o vetor de movimento para um inimigo que persegue o jogador (lógica toroidal).
---@param dt number
---@param enemy BaseEnemy
---@param playerPosition Vector2D
---@param mapInfo table
function EnemyMovementController:_calculateChaseVector(dt, enemy, playerPosition, mapInfo)
    local currentTime = love.timer.getTime()

    if not playerPosition then
        enemy.cachedDirection.x = 0
        enemy.cachedDirection.y = 0
        enemy.velocity.x = 0
        enemy.velocity.y = 0
        return
    end

    -- Atualiza direção apenas quando necessário (throttling)
    if currentTime - enemy.lastDirectionUpdate >= enemy.directionUpdateInterval then
        enemy.lastDirectionUpdate = currentTime

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

        -- Precisamos da posição isométrica do tile de destino para calcular o vetor de direção
        local nextStepTileX = enemyTilePos.x + deltaTileX
        local nextStepTileY = enemyTilePos.y + deltaTileY

        -- O mapManager já foi refatorado, então não temos acesso direto a cartesianToIsometric aqui.
        -- Precisamos de uma função utilitária ou de passar a função no mapInfo.
        -- Por simplicidade, vamos calcular o vetor de direção em tiles e convertê-lo para pixels.
        local targetIsoPos = mapInfo.cartesianToIsometric(nextStepTileX, nextStepTileY)

        local directionX = targetIsoPos.x - enemy.position.x
        local directionY = targetIsoPos.y - enemy.position.y

        local lenSq = directionX * directionX + directionY * directionY
        if lenSq > 0 then
            local invLen = 1 / math.sqrt(lenSq)
            enemy.cachedDirection.x = directionX * invLen
            enemy.cachedDirection.y = directionY * invLen
        else
            enemy.cachedDirection.x = 0
            enemy.cachedDirection.y = 0
        end
    end

    -- Aplica movimento usando direção cached, mas armazena em 'velocity'
    local moveSpeed = enemy.speed
    enemy.velocity.x = enemy.cachedDirection.x * moveSpeed
    enemy.velocity.y = enemy.cachedDirection.y * moveSpeed
end

--- Destroi o controller e limpa recursos.
function EnemyMovementController:destroy()
    -- Limpeza, se necessário
end

return EnemyMovementController
