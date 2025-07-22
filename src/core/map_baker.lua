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

    -- CORREÇÃO: Calcula as dimensões corretas para a bounding box de um mapa isométrico.
    local mapGridWidth = mapData.width
    local mapGridHeight = mapData.height
    local tileWidth = mapData.tilewidth
    local tileHeight = mapData.tileheight
    local mapWidthInPixels = (mapGridWidth + mapGridHeight) * tileWidth / 2
    local mapHeightInPixels = (mapGridWidth + mapGridHeight) * tileHeight / 2


    Logger.info("map_baker.bake.start",
        string.format("[MapBaker] Iniciando o bake do mapa. Dimensões do canvas: %dx%d", mapWidthInPixels,
            mapHeightInPixels))

    ---@type table<MapTileLayer, love.Canvas>
    local bakedLayers = {}
    local layersToBake = { "ground", "ground_decoration", "decoration" }

    for _, layerName in ipairs(layersToBake) do
        local layerData = self:_findLayer(mapData.layers, layerName)

        if layerData and layerData.visible then
            local canvas = love.graphics.newCanvas(mapWidthInPixels, mapHeightInPixels)
            bakedLayers[layerName] = canvas

            love.graphics.push()
            love.graphics.setCanvas(canvas)
            love.graphics.clear()

            self:_bakeLayer(layerData, mapData, loadedTiles, mapWidthInPixels)

            love.graphics.setCanvas()
            love.graphics.pop()

            Logger.debug("map_baker.bake.layer_complete",
                string.format("[MapBaker] Camada '%s' finalizada e 'assada' no seu canvas.", layerName))
        end
    end

    Logger.info("map_baker.bake.success", "[MapBaker] Bake de todas as camadas do mapa concluído.")

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

---@private "Asa" (desenha) uma única camada em um canvas.
function MapBaker:_bakeLayer(layer, mapData, loadedTiles, mapWidthInPixels)
    local tileWidth = mapData.tilewidth
    local tileHeight = mapData.tileheight
    local mapGridWidth = mapData.width
    local mapGridHeight = mapData.height
    local hasLoggedFirstTile = false -- Flag para logar apenas uma vez por camada

    -- O offset vertical é necessário para centralizar o mapa no canvas,
    -- já que a ponta superior do losango isométrico começa em y=0.
    local offsetY = (mapGridHeight - 1) * tileHeight / 2

    for i, gid in ipairs(layer.data) do
        if gid > 0 then
            local tileInfo = self:_findTileInfo(mapData.tilesets, gid)
            if tileInfo and loadedTiles[tileInfo.image] then
                local image = loadedTiles[tileInfo.image]

                -- Calcula a posição no grid 2D a partir do índice 1D
                local gridX = (i - 1) % mapGridWidth
                local gridY = math.floor((i - 1) / mapGridWidth)

                -- Converte coordenadas isométricas do grid para coordenadas de tela (pixel)
                -- O offset em X centraliza o mapa horizontalmente.
                local screenX = (gridX - gridY) * (tileWidth / 2) + (mapGridWidth - 1) * tileWidth / 2
                -- O offset em Y alinha a base dos tiles e centraliza o mapa verticalmente.
                local screenY = (gridX + gridY) * (tileHeight / 2) + offsetY
                -- O drawY ajusta pela altura da imagem do tile para o posicionamento correto.
                local drawY = screenY - (image:getHeight() - tileHeight)

                -- LOG DE INSPEÇÃO para o primeiro tile válido
                if not hasLoggedFirstTile then
                    Logger.info("MapBaker:_bakeLayer [INSPECT]",
                        string.format("  - Drawing first tile for layer '%s': GID=%d, Image='%s', Pos=(%.2f, %.2f)",
                            layer.name, gid, tileInfo.image, screenX, drawY)
                    )
                    hasLoggedFirstTile = true
                end

                love.graphics.draw(image, screenX, drawY)
            elseif not hasLoggedFirstTile then
                -- Se o primeiro tile já falhou, logue o motivo
                Logger.warn("MapBaker:_bakeLayer [INSPECT]",
                    string.format(
                        "  - Skipping first tile for layer '%s': GID=%d. tileInfo is nil? %s. Image loaded? %s",
                        layer.name, gid, tostring(tileInfo == nil),
                        tostring(tileInfo and loadedTiles[tileInfo.image] ~= nil))
                )
                hasLoggedFirstTile = true
            end
        end
    end
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
