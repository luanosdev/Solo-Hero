--- @class ChunkMapManager
--- Gerencia um mapa "infinito" baseado em chunks, gerado proceduralmente.
--- Foca em otimização através do uso de SpriteBatch e carregamento/descarregamento dinâmico de chunks.
local ChunkMapManager = {}
ChunkMapManager.__index = ChunkMapManager

local Constants = require("src.config.constants")
local TablePool = require("src.utils.table_pool")
local AssetManager = require("src.managers.asset_manager")

--- Cria uma nova instância do ChunkMapManager.
--- @param playerManager PlayerManager - Para obter a posição do jogador e determinar os chunks visíveis.
--- @return ChunkMapManager
function ChunkMapManager:new(playerManager)
    local instance = setmetatable({}, ChunkMapManager)

    instance.playerManager = playerManager

    -- Armazena os chunks ativos. A chave é uma string "cx_cy".
    instance.chunks = {}

    -- Atlas de textura para todos os tiles e o único SpriteBatch.
    instance.tileAtlas = nil
    instance.mainSpriteBatch = nil

    -- Lista de todos os tiles dos chunks visíveis, para ordenação.
    instance.sortedRenderList = {}

    -- Estrutura para armazenar os assets (quads) dos tiles carregados.
    instance.tileAssets = {
        ground = {},
        grass = {}
    }

    -- Para controlar quando a atualização de chunks visíveis é necessária.
    instance.lastPlayerChunkX = nil
    instance.lastPlayerChunkY = nil

    -- Flag para indicar que a lista de renderização e o batch precisam ser reconstruídos.
    instance.renderListDirty = true

    instance:_loadTileAssetsAndCreateAtlas()

    return instance
end

--- Carrega as imagens dos tiles, cria um atlas de textura dinâmico (Canvas)
--- e o SpriteBatch único para renderização otimizada.
function ChunkMapManager:_loadTileAssetsAndCreateAtlas()
    local path = "assets/tilesets/forest/tiles/"
    local directions = { "N", "S", "E", "W" }
    local allTileInfo = {}
    local totalWidth = 0
    local maxHeight = 0

    -- 1. Coleta informações de todas as imagens de tiles
    local tilePrefixes = { ground = "Ground A1_", grass = "Ground G1_" }
    for tileType, prefix in pairs(tilePrefixes) do
        for _, dir in ipairs(directions) do
            local filename = prefix .. dir .. ".png"
            local fullPath = path .. filename
            local image = AssetManager:getImage(fullPath)
            if image then
                table.insert(allTileInfo, {
                    type = tileType,
                    dir = dir,
                    image = image,
                    width = image:getWidth(),
                    height = image:getHeight()
                })
                totalWidth = totalWidth + image:getWidth()
                maxHeight = math.max(maxHeight, image:getHeight())
            else
                error("Falha ao carregar imagem para atlas: " .. fullPath)
            end
        end
    end

    if #allTileInfo == 0 then return end

    -- 2. Cria o Canvas (atlas), desenha as imagens e cria os Quads
    self.tileAtlas = love.graphics.newCanvas(totalWidth, maxHeight)
    love.graphics.setCanvas(self.tileAtlas)
    love.graphics.clear()

    local currentX = 0
    for _, info in ipairs(allTileInfo) do
        love.graphics.draw(info.image, currentX, 0)
        self.tileAssets[info.type][info.dir] = {
            quad = love.graphics.newQuad(currentX, 0, info.width, info.height, self.tileAtlas:getDimensions())
        }
        currentX = currentX + info.width
    end

    love.graphics.setCanvas() -- Volta para a tela

    -- 3. Cria o único SpriteBatch para o atlas
    local maxTiles = Constants.CHUNK_SIZE * Constants.CHUNK_SIZE * (Constants.VISIBLE_CHUNKS_RADIUS * 2 + 1) ^ 2
    self.mainSpriteBatch = love.graphics.newSpriteBatch(self.tileAtlas, maxTiles, "stream")
end

--- Converte coordenadas do mundo para coordenadas de chunk.
--- @param worldX number
--- @param worldY number
--- @return number, number
function ChunkMapManager:_worldToChunkCoords(worldX, worldY)
    local TILE_WIDTH = Constants.TILE_WIDTH
    local TILE_HEIGHT = Constants.TILE_HEIGHT
    local CHUNK_SIZE = Constants.CHUNK_SIZE

    -- Inverte a projeção isométrica para obter as coordenadas do grid (mapX, mapY)
    -- A projeção é:
    -- isoX = (mapX - mapY) * TILE_WIDTH / 2
    -- isoY = (mapX + mapY) * TILE_HEIGHT / 2
    -- A fórmula inversa, para encontrar (mapX, mapY) a partir de (isoX, isoY), é:
    local mapX = (worldX / TILE_WIDTH) + (worldY / TILE_HEIGHT)
    local mapY = (worldY / TILE_HEIGHT) - (worldX / TILE_WIDTH)

    -- Converte as coordenadas do grid de tiles para coordenadas de chunk
    local chunkX = math.floor(mapX / CHUNK_SIZE)
    local chunkY = math.floor(mapY / CHUNK_SIZE)

    return chunkX, chunkY
end

--- Atualiza o mapa, carregando/descarregando chunks com base na posição do jogador.
function ChunkMapManager:update(dt)
    local playerPos = self.playerManager.player.position
    if not playerPos then return end

    local p_cx, p_cy = self:_worldToChunkCoords(playerPos.x, playerPos.y)

    if p_cx ~= self.lastPlayerChunkX or p_cy ~= self.lastPlayerChunkY then
        self:_updateVisibleChunks(p_cx, p_cy)
        self.lastPlayerChunkX = p_cx
        self.lastPlayerChunkY = p_cy
    end
end

--- Garante que todos os chunks visíveis estejam carregados e descarrega os que não estão.
--- @param pcx number Posição X do chunk do jogador.
--- @param pcy number Posição Y do chunk do jogador.
function ChunkMapManager:_updateVisibleChunks(pcx, pcy)
    local radius = Constants.VISIBLE_CHUNKS_RADIUS
    local visibleChunks = {}

    -- Carrega novos chunks na área visível
    for cx = pcx - radius, pcx + radius do
        for cy = pcy - radius, pcy + radius do
            local key = cx .. "_" .. cy
            visibleChunks[key] = true
            if not self.chunks[key] then
                self:_generateChunk(cx, cy)
                self.renderListDirty = true
            end
        end
    end

    -- Descarrega chunks antigos que não estão mais visíveis
    for key, chunk in pairs(self.chunks) do
        if not visibleChunks[key] then
            self:_unloadChunk(key)
            self.renderListDirty = true
        end
    end
end

--- Gera os dados para um único chunk.
--- @param cx number Coordenada X do chunk.
--- @param cy number Coordenada Y do chunk.
function ChunkMapManager:_generateChunk(cx, cy)
    local key = cx .. "_" .. cy
    love.math.setRandomSeed(cx, cy) -- Gera um mapa consistente para as mesmas coordenadas

    local chunk = TablePool.get()
    chunk.cx = cx
    chunk.cy = cy
    chunk.tiles = TablePool.get()

    local directions = { "N", "S", "E", "W" }

    for ty = 1, Constants.CHUNK_SIZE do
        for tx = 1, Constants.CHUNK_SIZE do
            local tileData = TablePool.get()

            -- Lógica de geração procedural simples
            local randomValue = love.math.random()
            local tileType = randomValue > 0.3 and "grass" or "ground"
            local dir = directions[love.math.random(1, 4)]
            local assetInfo = self.tileAssets[tileType][dir]

            tileData.quad = assetInfo.quad

            -- Calcula a posição no mundo isométrico
            local mapX = (cx * Constants.CHUNK_SIZE) + tx
            local mapY = (cy * Constants.CHUNK_SIZE) + ty
            tileData.x = (mapX - mapY) * (Constants.TILE_WIDTH / 2)
            tileData.y = (mapX + mapY) * (Constants.TILE_HEIGHT / 2)

            table.insert(chunk.tiles, tileData)
        end
    end

    self.chunks[key] = chunk
end

--- Remove um chunk da memória e libera seus recursos.
--- @param key string A chave do chunk a ser descarregado.
function ChunkMapManager:_unloadChunk(key)
    local chunk = self.chunks[key]
    if chunk then
        for i = #chunk.tiles, 1, -1 do
            TablePool.release(chunk.tiles[i])
            table.remove(chunk.tiles, i)
        end
        TablePool.release(chunk.tiles)
        TablePool.release(chunk)
        self.chunks[key] = nil
    end
end

--- Desenha o mapa. Otimizado para reconstruir a lista de renderização e o SpriteBatch apenas quando necessário.
function ChunkMapManager:draw()
    if self.renderListDirty then
        -- 1. Libera a lista antiga e cria uma nova.
        if self.sortedRenderList then
            TablePool.release(self.sortedRenderList)
        end
        self.sortedRenderList = TablePool.get()

        -- 2. Popula a lista com todos os tiles dos chunks ativos.
        for _, chunk in pairs(self.chunks) do
            for _, tile in ipairs(chunk.tiles) do
                table.insert(self.sortedRenderList, tile)
            end
        end

        -- 3. Ordena a lista pela posição Y para renderização isométrica correta.
        table.sort(self.sortedRenderList, function(a, b) return a.y < b.y end)

        -- 4. Preenche o SpriteBatch com os tiles ordenados.
        self.mainSpriteBatch:clear()
        for _, tile in ipairs(self.sortedRenderList) do
            self.mainSpriteBatch:add(tile.quad, tile.x, tile.y)
        end

        self.renderListDirty = false
    end

    -- Desenha o batch inteiro de uma só vez.
    if self.mainSpriteBatch then
        love.graphics.draw(self.mainSpriteBatch)
    end

    -- Desenha informações de debug.
    self:_drawDebug()
end

--- Desenha informações de debug, como as bordas dos chunks.
function ChunkMapManager:_drawDebug()
    if not DEBUG_SHOW_CHUNK_BOUNDS then return end

    local TILE_WIDTH_HALF = Constants.TILE_WIDTH / 2
    local TILE_HEIGHT_HALF = Constants.TILE_HEIGHT / 2
    local CHUNK_SIZE = Constants.CHUNK_SIZE

    love.graphics.setLineWidth(2)
    for key, chunk in pairs(self.chunks) do
        -- Calcula os 4 cantos do chunk no espaço isométrico
        local cx, cy = chunk.cx, chunk.cy

        -- Coordenadas do tile no canto superior (menor mapX, menor mapY)
        local corner1_mapX = cx * CHUNK_SIZE
        local corner1_mapY = cy * CHUNK_SIZE
        local corner1_isoX = (corner1_mapX - corner1_mapY) * TILE_WIDTH_HALF
        local corner1_isoY = (corner1_mapX + corner1_mapY) * TILE_HEIGHT_HALF

        -- Canto direito
        local corner2_mapX = (cx + 1) * CHUNK_SIZE
        local corner2_mapY = cy * CHUNK_SIZE
        local corner2_isoX = (corner2_mapX - corner2_mapY) * TILE_WIDTH_HALF
        local corner2_isoY = (corner2_mapX + corner2_mapY) * TILE_HEIGHT_HALF

        -- Canto inferior
        local corner3_mapX = (cx + 1) * CHUNK_SIZE
        local corner3_mapY = (cy + 1) * CHUNK_SIZE
        local corner3_isoX = (corner3_mapX - corner3_mapY) * TILE_WIDTH_HALF
        local corner3_isoY = (corner3_mapX + corner3_mapY) * TILE_HEIGHT_HALF

        -- Canto esquerdo
        local corner4_mapX = cx * CHUNK_SIZE
        local corner4_mapY = (cy + 1) * CHUNK_SIZE
        local corner4_isoX = (corner4_mapX - corner4_mapY) * TILE_WIDTH_HALF
        local corner4_isoY = (corner4_mapX + corner4_mapY) * TILE_HEIGHT_HALF

        -- Desenha o losango do chunk
        love.graphics.setColor(1, 0, 0, 0.8) -- Vermelho para as bordas
        love.graphics.polygon("line", corner1_isoX, corner1_isoY, corner2_isoX, corner2_isoY, corner3_isoX,
            corner3_isoY, corner4_isoX, corner4_isoY)

        -- Escreve as coordenadas do chunk no centro
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(key, corner1_isoX - 50, corner1_isoY + (corner3_isoY - corner1_isoY) / 2, 100, "center")
    end
    love.graphics.setLineWidth(1)
end

return ChunkMapManager
