---@class BakedMap
---@field layers table<MapTileLayer, love.Canvas> Um mapa onde a chave é o nome da camada (ex: "ground") e o valor é o Canvas pré-renderizado.

---@class MapBaker
---@description "Asa" (Bakes) os dados brutos de um mapa em um conjunto de Canvas pré-renderizados.
-- Este componente Core pega os dados carregados pelo MapAssetLoader e realiza a
-- operação de desenho, que é custosa, durante a GameLoadingScene. O resultado é um
-- conjunto de texturas (Canvas) que podem ser desenhadas rapidamente durante o gameplay.
local MapBaker = {}
MapBaker.__index = MapBaker

function MapBaker:new()
    local instance = setmetatable({}, MapBaker)
    return instance
end

--- Executa o processo de "assar" o mapa.
--- @param mapAssets MapAssets Os assets carregados pelo MapAssetLoader.
--- @return string key A chave de asset a ser usada ('bakedMap').
--- @return BakedMap bakedMap Os Canvas do mapa prontos para uso.
function MapBaker:bake(mapAssets)
    assert(mapAssets and mapAssets.mapData and mapAssets.tiles, "MapBaker:bake requer mapAssets válidos.")

    local mapData = mapAssets.mapData
    local loadedTiles = mapAssets.tiles
    local patchSize = 4

    ---@type table<MapTileLayer, table<number, table<number, love.Canvas>>>
    local bakedLayers = {}
    local layersToBake = { "ground", "ground_decoration", "decoration" }

    -- Inicializa a estrutura da tabela
    for _, layerName in ipairs(layersToBake) do
        bakedLayers[layerName] = {}
    end

    -- Itera sobre cada patch do mapa
    for patchY = 0, patchSize - 1 do
        for patchX = 0, patchSize - 1 do
            -- Itera sobre cada camada para este patch
            for _, layerName in ipairs(layersToBake) do
                local layerData = self:_findLayer(mapData.layers, layerName)

                if layerData and layerData.visible then
                    -- Inicializa a linha da tabela se ainda não existir
                    if not bakedLayers[layerName][patchY] then
                        bakedLayers[layerName][patchY] = {}
                    end

                    -- Assa o patch específico para a camada
                    local patchCanvas = self:_bakeLayerPatch(layerData, mapData, loadedTiles, patchX, patchY)
                    bakedLayers[layerName][patchY][patchX] = patchCanvas

                    Logger.debug("map_baker.bake.patch_complete",
                        string.format("[MapBaker] Patch (%d, %d) para a camada '%s' assado.", patchX, patchY,
                            layerName))
                end
            end
        end
    end

    Logger.info("map_baker.bake.success", "[MapBaker] Bake de todos os patches do mapa concluído.")

    ---@type BakedMap
    local bakedMap = {
        layers = bakedLayers
    }

    return "bakedMap", bakedMap
end

---@private Encontra uma camada pelo nome na lista de camadas do mapa.
function MapBaker:_findLayer(layers, name)
    for _, layer in ipairs(layers) do
        if layer.name == name then
            return layer
        end
    end
    return nil
end

---@private "Asa" (desenha) um único patch de uma camada em um novo canvas.
---@param layer table A camada a ser assada.
---@param mapData table Os dados do mapa.
---@param loadedTiles table Os tiles carregados.
---@param patchX number O índice X do patch a ser assado.
---@param patchY number O índice Y do patch a ser assado.
---@return love.Canvas O canvas com o patch desenhado.
function MapBaker:_bakeLayerPatch(layer, mapData, loadedTiles, patchX, patchY)
    local tileWidth = mapData.tilewidth
    local tileHeight = mapData.tileheight
    local mapGridWidth = mapData.width
    local tilesPerPatch = mapData.properties.grid_width or 4

    -- Calcula as dimensões de um único patch
    local patchGridWidth = tilesPerPatch
    local patchCanvasWidth = (patchGridWidth * 2) * tileWidth / 2
    local patchCanvasHeight = (patchGridWidth * 2) * tileHeight / 2

    local patchCanvas = love.graphics.newCanvas(patchCanvasWidth, patchCanvasHeight)
    love.graphics.push()
    love.graphics.setCanvas(patchCanvas)
    love.graphics.clear()

    -- Calcula o tile inicial (canto superior esquerdo) deste patch no mapa geral
    local startTileX = patchX * tilesPerPatch
    local startTileY = patchY * tilesPerPatch

    -- O offset para desenhar no canvas do patch, para que o tile (0,0) do patch
    -- fique no canto superior do losango.
    local baseOffsetX = (patchGridWidth - 1) * tileWidth / 2

    for y = 0, tilesPerPatch - 1 do
        for x = 0, tilesPerPatch - 1 do
            -- Coordenada do tile no mapa geral
            local mapTileX = startTileX + x
            local mapTileY = startTileY + y

            local index = mapTileY * mapGridWidth + mapTileX + 1
            local gid = layer.data[index]

            if gid and gid > 0 then
                local tileInfo = self:_findTileInfo(mapData.tilesets, gid)
                if tileInfo and loadedTiles[tileInfo.image] then
                    local image = loadedTiles[tileInfo.image]

                    -- Converte a coordenada LOCAL do tile (x,y) dentro do patch para pixel
                    local screenX = (x - y) * (tileWidth / 2) + baseOffsetX
                    local screenY = (x + y) * (tileHeight / 2)

                    -- Ajusta o desenho pela altura do sprite
                    local drawY = screenY - (image:getHeight() - tileHeight)

                    love.graphics.draw(image, screenX, drawY)
                end
            end
        end
    end

    love.graphics.setCanvas()
    love.graphics.pop()
    return patchCanvas
end

---@private Encontra a informação de um tile (como o path da imagem) a partir do seu GID.
function MapBaker:_findTileInfo(tilesets, gid)
    -- Itera de trás para frente, pois os tilesets são listados em ordem,
    -- e um GID sempre pertencerá ao tileset com o firstgid mais alto que seja menor ou igual ao GID.
    for i = #tilesets, 1, -1 do
        local tileset = tilesets[i]
        if gid >= tileset.firstgid then
            local localId = gid - tileset.firstgid
            for _, tile in ipairs(tileset.tiles) do
                if tile.id == localId then
                    return tile
                end
            end
        end
    end
    return nil
end

return MapBaker
