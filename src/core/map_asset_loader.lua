---@class MapAssets
---@field mapData table Os dados crus do mapa, carregados do arquivo de definição.
---@field tiles table<string, love.Image> Um mapa onde a chave é o caminho do asset e o valor é o objeto Image carregado.

---@class MapAssetLoader
---@description Carrega de forma síncrona todos os assets de imagem associados a um mapa específico.
-- Este é um componente Core, projetado para ser usado durante a GameLoadingScene.
-- Ele lê um arquivo de definição de mapa, percorre todos os tilesets e tiles,
-- e carrega cada imagem de tile na memória.
local MapAssetLoader = {}
MapAssetLoader.__index = MapAssetLoader

--- Cria uma nova instância do MapAssetLoader.
function MapAssetLoader:new()
    local instance = setmetatable({}, MapAssetLoader)
    return instance
end

--- Carrega os assets para um determinado ID de mapa.
--- @param mapId string O identificador do mapa (ex: "jungle"), que corresponde ao nome do arquivo em 'src/data/maps/'.
--- @return string key A chave de asset (atualmente 'map').
--- @return MapAssets assets A tabela contendo os dados do mapa e os tiles carregados.
function MapAssetLoader:load(mapId)
    assert(mapId and type(mapId) == "string", "mapId deve ser uma string válida.")

    local mapDataPath = "src.data.maps." .. mapId
    Logger.info("map_asset_loader.load.start",
        string.format("[MapAssetLoader] Iniciando carregamento para o mapa: '%s'", mapId))

    local success, mapData = pcall(require, mapDataPath)
    if not success or not mapData then
        error(string.format("Falha ao carregar dados do mapa em '%s': %s", mapDataPath, tostring(mapData)))
    end

    ---@type table<string, love.Image>
    local loadedTiles = {}
    local tilesLoadedCount = 0

    if mapData.tilesets then
        for _, tileset in ipairs(mapData.tilesets) do
            if tileset.tiles then
                for _, tile in ipairs(tileset.tiles) do
                    if tile.image and not loadedTiles[tile.image] then
                        local imageSuccess, imageOrError = pcall(love.graphics.newImage, tile.image)
                        if imageSuccess then
                            loadedTiles[tile.image] = imageOrError
                            tilesLoadedCount = tilesLoadedCount + 1
                        else
                            Logger.warn("map_asset_loader.load.tile_error",
                                string.format("Falha ao carregar a imagem do tile '%s': %s", tile.image,
                                    tostring(imageOrError)))
                        end
                    end
                end
            end
        end
    end

    Logger.info("map_asset_loader.load.success",
        string.format("[MapAssetLoader] Carregamento concluído. %d tiles únicos carregados para o mapa '%s'.",
            tilesLoadedCount, mapId))

    ---@type MapAssets
    local assets = {
        mapData = mapData,
        tiles = loadedTiles
    }

    -- O primeiro valor de retorno é a chave que será usada no objeto preloadedAssets.
    return "map", assets
end

return MapAssetLoader
