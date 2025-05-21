-- Gerencia o carregamento, estado e desenho do mapa do jogo.

--- @class MapManager
local MapManager = {}
MapManager.__index = MapManager

local Constants = require("src.config.constants")

--- Cria uma nova instância do MapManager.
--- @param mapName string Nome do arquivo do mapa (sem extensão, ex: "forest").
--- @param assetManager AssetManager Instância do AssetManager.
--- @return MapManager Uma nova instância de MapManager.
function MapManager:new(mapName, assetManager)
    local instance = setmetatable({}, MapManager) --- @class MapManager
    instance.mapName = mapName
    instance.mapPath = "src/maps/" .. mapName .. ".lua"
    instance.mapData = nil               -- Será carregado em :loadMap()
    instance.tileBatches = {}            -- Tabela para armazenar SpriteBatches por textura de tileset
    instance.assetManager = assetManager -- Guardar a referência do AssetManager

    if not instance.assetManager then
        Logger.error("MapManager", "AssetManager não fornecido ao criar MapManager para o mapa: " .. mapName)
    end
    return instance
end

--- Carrega os dados do mapa e prepara os SpriteBatches para renderização.
--- @return boolean True se o mapa foi carregado com sucesso, false caso contrário.
function MapManager:loadMap()
    if not self.mapPath then
        Logger.error("MapManager", "LOAD_MAP: Erro - Caminho do mapa não especificado.")
        return false
    end

    Logger.debug("MapManager", "LOAD_MAP: Tentando carregar mapa de: " .. self.mapPath)

    -- Tenta carregar o arquivo e obter a função que ele retorna
    local chunk, loadError = love.filesystem.load(self.mapPath)

    if not chunk then
        Logger.error("MapManager",
            "LOAD_MAP: FALHA CRÍTICA ao carregar o CHUNK do arquivo do mapa: " ..
            self.mapPath .. " Erro: " .. tostring(loadError))
        return false
    end
    Logger.debug("MapManager",
        "LOAD_MAP: love.filesystem.load retornou um chunk para: " .. self.mapPath .. ". Tipo do chunk: " .. type(chunk))

    -- Agora executa o chunk carregado para obter a definição do mapa (que deve ser uma tabela)
    local success, mapDefinitionOrError = pcall(chunk)

    if not success then
        Logger.error("MapManager",
            "LOAD_MAP: FALHA CRÍTICA ao EXECUTAR o chunk do mapa: " ..
            self.mapPath .. " Erro: " .. tostring(mapDefinitionOrError))
        return false
    end
    Logger.debug("MapManager", "LOAD_MAP: Chunk do mapa executado. Tipo retornado: " .. type(mapDefinitionOrError))

    if type(mapDefinitionOrError) ~= "table" then
        Logger.error("MapManager",
            "LOAD_MAP: Erro - Chunk do mapa " ..
            self.mapPath .. " não retornou uma tabela. Retornou tipo: " .. type(mapDefinitionOrError))
        return false
    end

    self.mapData = mapDefinitionOrError -- Atribui o resultado da execução do chunk
    Logger.debug("MapManager",
        string.format(
            "LOAD_MAP: Mapa '%s' processado. tilewidth: %s, tileheight: %s, map width: %s, map height: %s. Chamando _prepareTileBatches...",
            self.mapName, tostring(self.mapData.tilewidth), tostring(self.mapData.tileheight),
            tostring(self.mapData.width), tostring(self.mapData.height)))

    self:_prepareTileBatches()

    Logger.debug("MapManager",
        "LOAD_MAP: Chamada para _prepareTileBatches concluída para '" .. self.mapName .. "'. Mapa pronto.")
    return true
end

--- Prepara os SpriteBatches com base nos dados do mapa carregado.
function MapManager:_prepareTileBatches()
    if not self.mapData then -- Adicionada verificação de mapData primeiro
        Logger.error("MapManager", "_prepareTileBatches chamado sem mapData.")
        return
    end
    if not self.mapData.layers or not self.mapData.tilesets then
        Logger.error("MapManager", "Dados do mapa incompletos (sem layers ou tilesets) para preparar batches.")
        return
    end

    -- Log inicial para verificar a estrutura dos tilesets
    if self.mapData.tilesets[1] and self.mapData.tilesets[1].tiles then
        Logger.debug("MapManager",
            "Primeiro tileset (estrutura parcial): name=" ..
            tostring(self.mapData.tilesets[1].name) .. ", firstgid=" .. tostring(self.mapData.tilesets[1].firstgid))
        local count = 0
        for localId, tileEntry in pairs(self.mapData.tilesets[1].tiles) do
            Logger.debug("MapManager", string.format("  Tile localId '%s': image=%s, w=%s, h=%s, vh=%s",
                tostring(localId),
                tostring(tileEntry.image),
                tostring(tileEntry.width),
                tostring(tileEntry.height),
                tostring(tileEntry.visible_height)
            ))
            count = count + 1
            if count >= 3 then
                Logger.debug("MapManager", "  (mostrando até 3 tiles do primeiro tileset...)"); break
            end
        end
    else
        Logger.warn("MapManager", "Primeiro tileset ou sua tabela 'tiles' não encontrada ou malformada para log inicial.")
    end

    -- Limpa batches antigos, se houver
    for _, batch in pairs(self.tileBatches) do
        batch:release()
    end
    self.tileBatches = {}

    local TILE_WIDTH_HALF = Constants.TILE_WIDTH / 2
    local TILE_HEIGHT_HALF = Constants.TILE_HEIGHT / 2 -- Altura da célula isométrica

    local gidToTileRenderInfo = {}
    Logger.debug("MapManager", "Iniciando processamento de tilesets...")

    for ts_idx, tileset in ipairs(self.mapData.tilesets) do
        Logger.debug("MapManager",
            string.format("Processando tileset #%d: %s, firstgid: %s", ts_idx, tileset.name or "NOME_DESCONHECIDO",
                tileset.firstgid))
        if not self.assetManager then
            Logger.error("MapManager",
                "AssetManager não disponível para tileset: " .. (tileset.name or "NOME_DESCONHECIDO"))
            goto continue_tileset_processing
        end
        if not tileset.tiles or type(tileset.tiles) ~= "table" then
            Logger.warn("MapManager",
                "Tileset '" ..
                (tileset.name or "NOME_DESCONHECIDO") .. "' não possui uma tabela 'tiles' definida. Pulando.")
            goto continue_tileset_processing
        end
        if not tileset.firstgid then
            Logger.error("MapManager",
                "Tileset '" .. (tileset.name or "NOME_DESCONHECIDO") .. "' está sem 'firstgid'. Pulando.")
            goto continue_tileset_processing
        end

        -- Itera sobre os tiles individuais definidos DENTRO do tileset
        for localTileId, tileData in pairs(tileset.tiles) do
            -- IMPORTANTE: Verifique se localTileId é 0-indexed ou 1-indexed no seu arquivo .lua
            local currentGid = tileset.firstgid + localTileId -- ASSUME 0-INDEXED localTileId
            Logger.debug("MapManager",
                string.format("  Processando tile individual: localId=%s, GID Calculado=%s, firstgid=%s", localTileId,
                    currentGid, tileset.firstgid))

            if not tileData.image then
                Logger.warn("MapManager",
                    "  Tile (GID: " ..
                    currentGid .. ") no tileset '" .. (tileset.name or "N/A") .. "' não tem 'image'. Pulando tile.")
                goto continue_individual_tile
            end

            -- VALIDAÇÃO DE DIMENSÕES E FALLBACK PARA VISIBLE_HEIGHT
            if not tileData.width or not tileData.height then
                Logger.warn("MapManager",
                    "  Tile (GID: " ..
                    currentGid ..
                    ", Imagem: " .. tileData.image .. ") está com width ou height faltando. Pulando tile.")
                goto continue_individual_tile
            end

            local tileType = tileData.type or "ground"

            local visibleHeightToUse = tileData.visible_height
            if type(visibleHeightToUse) ~= "number" then
                if tileType == "ground" then
                    visibleHeightToUse = Constants.TILE_HEIGHT -- ✅ CORRETO
                else
                    visibleHeightToUse = tileData.height
                end
            end

            Logger.debug("MapManager", string.format("    Carregando imagem para GID %d: %s", currentGid, tileData.image))
            local individualTileImage = self.assetManager:getImage(tileData.image)
            if not individualTileImage then
                Logger.error("MapManager",
                    "    FALHA ao carregar imagem para tile (GID: " .. currentGid .. ") em '" .. tileData.image .. "'")
                goto continue_individual_tile
            end
            Logger.debug("MapManager",
                string.format("    Imagem carregada para GID %d. Asset W: %d, H: %d. Visible H (usado): %d", currentGid,
                    tileData.width, tileData.height, visibleHeightToUse))

            local assetImgW, assetImgH = individualTileImage:getDimensions()
            if assetImgW ~= tileData.width or assetImgH ~= tileData.height then
                Logger.warn("MapManager",
                    "    Divergência de dimensões para " ..
                    tileData.image ..
                    ": Imagem real (" ..
                    assetImgW ..
                    "x" .. assetImgH .. "), Definido no mapa (" .. tileData.width .. "x" .. tileData.height .. ")")
            end

            -- Swapped viewportHeight para tileData.height no final, pois refHeight é a altura total da imagem original do tile.
            local quad = love.graphics.newQuad(0, 0, tileData.width, tileData.height, tileData.width, tileData.height)
            local pivotX = tileData.pivot_x or (tileData.width / 2)
            local pivotY = tileType == "ground"
                and (tileData.pivot_y or (tileData.height - Constants.TILE_HEIGHT))
                or (tileData.pivot_y or tileData.height)
            Logger.debug("MapManager",
                string.format("    Quad criado para GID %d: (0,0, %d, %d) ref (%d, %d)", currentGid, tileData.width,
                    visibleHeightToUse, tileData.width, tileData.height))

            gidToTileRenderInfo[currentGid] = {
                image = individualTileImage,
                quad = quad,
                asset_width = tileData.width,
                asset_height = tileData.height,
                asset_visible_height = visibleHeightToUse,
                type = tileType,
                pivot_x = pivotX,
                pivot_y = pivotY,
            }
            Logger.debug("MapManager",
                string.format("    Informações de renderização para GID %d armazenadas.", currentGid))
            ::continue_individual_tile::
        end
        ::continue_tileset_processing::
    end

    local mappedGidCount = 0
    for _ in pairs(gidToTileRenderInfo) do mappedGidCount = mappedGidCount + 1 end
    Logger.debug("MapManager",
        "Processamento de tilesets concluído. " .. mappedGidCount .. " GIDs mapeados para render info.")

    Logger.debug("MapManager", "Iniciando processamento de camadas...")
    local tilesAddedToBatches = 0
    for layer_idx, layer in ipairs(self.mapData.layers) do
        if layer.type == "tilelayer" and layer.data then
            Logger.debug("MapManager",
                string.format("  Processando tilelayer #%d: %s, %d tiles de dados", layer_idx,
                    layer.name or "NOME_DESCONHECIDO", #layer.data))
            if not layer.width or layer.width == 0 then
                Logger.warn("MapManager",
                    "  Layer '" .. (layer.name or "NOME_DESCONHECIDO") .. "' não tem largura válida. Pulando layer.")
                goto continue_layer
            end
            for i, gidInLayer in ipairs(layer.data) do
                if gidInLayer ~= 0 then
                    Logger.debug("MapManager",
                        string.format("    Camada '%s', Tile #%d, GID: %d", layer.name or "N/A", i, gidInLayer))
                    if gidToTileRenderInfo[gidInLayer] then
                        local tileRenderInfo = gidToTileRenderInfo[gidInLayer]
                        local tileImage = tileRenderInfo.image
                        local tileQuad = tileRenderInfo.quad
                        Logger.debug("MapManager",
                            string.format("      GID %d encontrado em gidToTileRenderInfo. Imagem associada: %s",
                                gidInLayer, tostring(tileImage)))

                        local mapTileX = (i - 1) % layer.width
                        local mapTileY = math.floor((i - 1) / layer.width)

                        local isoX = (mapTileX - mapTileY) * TILE_WIDTH_HALF
                        local isoY = (mapTileX + mapTileY) * TILE_HEIGHT_HALF

                        local scaleX = Constants.TILE_WIDTH / tileRenderInfo.asset_width
                        local scaleY = Constants.TILE_HEIGHT / tileRenderInfo.asset_visible_height

                        local tileType = tileRenderInfo.type or "ground"

                        local pivotX = tileRenderInfo.pivot_x or (tileRenderInfo.asset_width / 2)
                        local pivotY

                        if tileType == "ground" then
                            pivotY = tileRenderInfo.pivot_y or (tileRenderInfo.asset_height - Constants.TILE_HEIGHT)
                        else
                            pivotY = tileRenderInfo.pivot_y or tileRenderInfo.asset_height
                        end

                        local finalDrawX = isoX - pivotX * scaleX
                        local finalDrawY = isoY - pivotY * scaleY

                        -- Adiciona ao batch apenas se for tile ground
                        if tileType == "ground" then
                            if not self.tileBatches[tileImage] then
                                Logger.debug("MapManager",
                                    string.format("      Criando novo SpriteBatch para imagem: %s", tostring(tileImage)))
                                self.tileBatches[tileImage] = love.graphics.newSpriteBatch(tileImage,
                                    self.mapData.width * self.mapData.height, "static")
                            end
                            self.tileBatches[tileImage]:add(tileQuad, finalDrawX, finalDrawY, 0, scaleX, scaleY)
                            tilesAddedToBatches = tilesAddedToBatches + 1
                            Logger.debug("MapManager",
                                string.format(
                                    "      GID %d adicionado ao batch. finalX: %.2f, finalY: %.2f, scaleX: %.2f, scaleY: %.2f",
                                    gidInLayer, finalDrawX, finalDrawY, scaleX, scaleY))
                        end
                    else
                        Logger.warn("MapManager",
                            string.format(
                                "      GID %d na camada '%s' não encontrado em gidToTileRenderInfo. Tile não será desenhado.",
                                gidInLayer, layer.name or "N/A"))
                    end
                end
            end
        end
        ::continue_layer::
    end
    Logger.debug("MapManager",
        "Processamento de camadas concluído. " .. tilesAddedToBatches .. " tiles adicionados aos batches.")
end

--- Atualiza o estado do mapa.
-- @param dt Delta time.
-- @realm client
function MapManager:update(dt)
    -- Lógica de atualização do mapa, se houver (ex: tiles animados, efeitos climáticos no mapa)
    -- Por enquanto, o mapa é estático após o carregamento.
end

--- Desenha o mapa.
-- Opcionalmente, pode aceitar cameraX, cameraY para culling se necessário no futuro,
-- mas por enquanto desenha todos os batches.
-- @realm client
function MapManager:draw(cameraX, cameraY) -- cameraX, cameraY podem ser usados para culling futuro
    if not self.mapData then return end

    local batchCount = 0
    for _ in pairs(self.tileBatches) do batchCount = batchCount + 1 end
    Logger.debug("MapManager:draw", "Iniciando desenho do mapa. Número de batches: " .. batchCount)

    love.graphics.push()
    if cameraX and cameraY then
        -- Aplica o deslocamento da câmera.
        -- No jogo principal, a câmera geralmente é aplicada antes de desenhar qualquer coisa.
        -- Se o MapManager for responsável por sua própria câmera, descomente:
        -- love.graphics.translate(-cameraX, -cameraY)
    end

    for image, batch in pairs(self.tileBatches) do
        local countInBatch = batch:getCount()
        if countInBatch > 0 then
            Logger.debug("MapManager:draw",
                string.format("  Desenhando batch para imagem %s. Contagem: %d", tostring(image), countInBatch))
            love.graphics.draw(batch)
        else
            -- Logger.debug("MapManager:draw", string.format("  Pulando batch para imagem %s (vazio).", image:typeOf()))
        end
    end

    love.graphics.pop()

    -- Debug: Desenha informações do mapa
    -- if self.mapData then
    --     love.graphics.setColor(1,0,0)
    --     love.graphics.print("Mapa: " .. self.mapName, 10, 10)
    --     love.graphics.print("Tilesets: " .. #self.mapData.tilesets, 10, 30)
    --     local totalTilesInBatches = 0
    --     for _,b in pairs(self.tileBatches) do totalTilesInBatches = totalTilesInBatches + b:getCount() end
    --     love.graphics.print("Tiles nos batches: " .. totalTilesInBatches, 10, 50)
    --     love.graphics.setColor(1,1,1)
    -- end
    Logger.debug("MapManager:draw", "Desenho do mapa concluído.")
end

--- Limpa os recursos do mapa.
-- Chamado quando o mapa não é mais necessário.
-- @realm client
function MapManager:destroy()
    Logger.debug("MapManager", "Destruindo MapManager para: " .. self.mapName)
    for _, batch in pairs(self.tileBatches) do
        Logger.debug("MapManager:destroy", string.format("  Liberando batch para imagem %s", tostring(batch)))
        batch:release() -- Libera o SpriteBatch
    end
    self.tileBatches = {}
    self.mapData = nil
    Logger.debug("MapManager", "MapManager destruído para: " .. self.mapName .. " concluído.")
end

return MapManager
