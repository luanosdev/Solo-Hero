local MathUtils = require("src.utils.math_utils")
local ResolutionUtils = require("src.utils.resolution_utils")

---@class DespawnEntity
---@field id number
---@field position Vector2D
---@field isBoss boolean
---@field isMVP boolean

---@class EntitiesToDespawn
---@field [number] boolean

---@class MapInfoForDespawn
---@field worldTileWidth number
---@field worldTileHeight number
---@field isometricToCartesianTile fun(x: number, y: number): Vector2D
---@field cartesianToIsometric fun(x: number, y: number): Vector2D

---@class DespawnController
---@description Gerencia a lógica de despawn de entidades em um mundo infinito de forma otimizada e stateless.
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
    local despawnDistance = ResolutionUtils.getSafeOffScreenDistance(DespawnController.DEFAULT_BUFFER)
    instance.despawnDistanceSq = despawnDistance * despawnDistance
    instance.batchSize = DespawnController.DEFAULT_BATCH_SIZE
    instance.currentIndex = 1
    return instance
end

--- Verifica um lote de entidades e retorna uma tabela de IDs daquelas que devem ser despawnadas.
---@param entities table<number, DespawnEntity> Uma lista de entidades a serem verificadas.
---@param playerPosition Vector2D A posição atual do jogador.
---@param mapInfo MapInfoForDespawn Informações e funções do mapa necessárias para os cálculos.
---@return EntitiesToDespawn entitiesToDespawn Uma tabela de lookup para as entidades a serem removidas.
function DespawnController:updateAndGetEntitiesToDespawn(entities, playerPosition, mapInfo)
    local entitiesToDespawn = {}
    local totalEntities = #entities

    if totalEntities == 0 then
        return entitiesToDespawn
    end

    if self.currentIndex > totalEntities then
        self.currentIndex = 1
    end

    local playerTilePos = mapInfo.isometricToCartesianTile(playerPosition.x, playerPosition.y)

    local entitiesChecked = 0
    while entitiesChecked < self.batchSize and self.currentIndex <= totalEntities do
        local entity = entities[self.currentIndex]

        if entity and entity.position and not entity.isBoss and not entity.isMVP then
            local entityTilePos = mapInfo.isometricToCartesianTile(entity.position.x, entity.position.y)

            local deltaTileX, deltaTileY = MathUtils.calculateShortestTorusVector(
                entityTilePos.x,
                entityTilePos.y,
                playerTilePos.x,
                playerTilePos.y,
                mapInfo.worldTileWidth,
                mapInfo.worldTileHeight
            )

            local distanceVectorIso = mapInfo.cartesianToIsometric(deltaTileX, deltaTileY)
            local distanceSq = distanceVectorIso.x * distanceVectorIso.x + distanceVectorIso.y * distanceVectorIso.y

            if distanceSq > self.despawnDistanceSq then
                entitiesToDespawn[entity.id] = true
            end
        end

        self.currentIndex = self.currentIndex + 1
        entitiesChecked = entitiesChecked + 1
    end

    if self.currentIndex > totalEntities then
        self.currentIndex = 1
    end

    return entitiesToDespawn
end

function DespawnController:destroy()
    self.despawnDistanceSq = nil
    self.batchSize = nil
    self.currentIndex = nil
end

return DespawnController
