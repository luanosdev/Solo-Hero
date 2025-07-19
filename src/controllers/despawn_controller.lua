local MathUtils = require("src.utils.math_utils")
local ResolutionUtils = require("src.utils.resolution_utils")

---@class DespawnEntity
---@field id number
---@field position Vector2D
---@field isBoss boolean
---@field isMVP boolean

---@class EntitiesToDespawn
---@field [number] boolean

---@class DespawnController
---@description Gerencia a lógica de despawn de entidades em um mundo infinito de forma otimizada.
---@field despawnDistanceSq number A distância (ao quadrado) a partir da qual uma entidade deve ser despawnada.
---@field batchSize number Quantas entidades verificar por chamada de update.
---@field currentIndex number O índice na lista de entidades onde a próxima verificação começará.
local DespawnController = {}
DespawnController.__index = DespawnController

DespawnController.DEFAULT_BUFFER = 500
DespawnController.DEFAULT_BATCH_SIZE = 10

--- Cria uma nova instância do DespawnController.
---@return DespawnController
function DespawnController:new()
    local instance = setmetatable({}, DespawnController)

    -- Calcula a distância de despawn uma vez e a armazena ao quadrado para otimização.
    local despawnDistance = ResolutionUtils.getSafeOffScreenDistance(DespawnController.DEFAULT_BUFFER)
    instance.despawnDistanceSq = despawnDistance * despawnDistance

    -- Configurações para a verificação em lotes (throttling)
    instance.batchSize = DespawnController.DEFAULT_BATCH_SIZE
    instance.currentIndex = 1

    return instance
end

--- Verifica um lote de entidades e retorna uma tabela de IDs daquelas que devem ser despawnadas.
---@param entities table<number, DespawnEntity> Uma lista de entidades a serem verificadas. Cada entidade deve ter .id e .position.
---@param playerPosition Vector2D A posição atual do jogador.
---@param mapManager InfinityWrapMapManager A instância do gerenciador de mapas para conversões de coordenadas.
---@return EntitiesToDespawn entitiesToDespawn Uma tabela de lookup para as entidades a serem removidas.
function DespawnController:getEntitiesToDespawn(entities, playerPosition, mapManager)
    local entitiesToDespawn = {}
    local totalEntities = #entities

    if totalEntities == 0 then
        return entitiesToDespawn
    end

    -- Garante que o índice atual seja válido
    if self.currentIndex > totalEntities then
        self.currentIndex = 1
    end

    local worldWidth, worldHeight = mapManager:getWorldTileDimensions()
    local playerTilePos = mapManager:isometricToCartesianTile(playerPosition.x, playerPosition.y)

    local entitiesChecked = 0
    while entitiesChecked < self.batchSize and self.currentIndex <= totalEntities do
        local entity = entities[self.currentIndex]

        if entity and entity.position and not entity.isBoss and not entity.isMVP then
            local entityTilePos = mapManager:isometricToCartesianTile(entity.position.x, entity.position.y)

            -- Calcula o vetor de distância mais curto no mundo toroidal
            local deltaTileX, deltaTileY = MathUtils.calculateShortestTorusVector(
                entityTilePos.x,
                entityTilePos.y,
                playerTilePos.x,
                playerTilePos.y,
                worldWidth,
                worldHeight
            )

            -- Converte o vetor de volta para o espaço isométrico para obter a distância real
            local distanceVectorIso = mapManager:cartesianToIsometric(deltaTileX, deltaTileY)
            local distanceSq = distanceVectorIso.x * distanceVectorIso.x + distanceVectorIso.y * distanceVectorIso.y

            -- Compara com a distância de despawn (ao quadrado)
            if distanceSq > self.despawnDistanceSq then
                entitiesToDespawn[entity.id] = true
            end
        end

        self.currentIndex = self.currentIndex + 1
        entitiesChecked = entitiesChecked + 1
    end

    -- Se o índice passou do final, volta ao início para o próximo quadro
    if self.currentIndex > totalEntities then
        self.currentIndex = 1
    end

    return entitiesToDespawn
end

return DespawnController
