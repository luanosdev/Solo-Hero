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
    -- Armazena os SpriteBatches por textura de tileset.
    instance.spriteBatches = {}

    -- Estrutura para armazenar os assets (quads e texturas) dos tiles carregados.
    instance.tileAssets = {
        ground = {},
        grass = {}
    }

    -- Para controlar quando a atualização de chunks visíveis é necessária.
    instance.lastPlayerChunkX = nil
    instance.lastPlayerChunkY = nil

    -- Flag para indicar que os SpriteBatches precisam ser reconstruídos.
    instance.batchesDirty = true

    instance:_loadTileAssets()

    return instance
end

--- Carrega as imagens e quads dos tiles e cria os SpriteBatches.
function ChunkMapManager:_loadTileAssets()
    local path = "assets/tilesets/forest/tiles/"
    local directions = { "N", "S", "E", "W" }

    -- Helper para garantir que um batch exista para uma textura
    local function getOrCreateBatch(texture)
        if not self.spriteBatches[texture] then
            self.spriteBatches[texture] = love.graphics.newSpriteBatch(texture, 10000, "stream")
        end
    end

    -- Carrega os quads e texturas para os tiles de terra (Ground)
    for _, dir in ipairs(directions) do
        local imageName = "Ground A1_" .. dir .. ".png" -- Corrigido para o nome de arquivo real
        local fullPath = path .. imageName
        print("[ChunkMapManager] Tentando carregar imagem: " .. fullPath)
        local image = AssetManager:getImage(fullPath)

        if image then
            -- Correção: O objeto 'image' já é a textura. Não é necessário chamar :getTexture().
            local texture = image
            getOrCreateBatch(texture)
            self.tileAssets.ground[dir] = {
                texture = texture,
                quad = love.graphics.newQuad(0, 0, image:getWidth(), image:getHeight(), texture:getDimensions())
            }
        else
            error("Não foi possível carregar a imagem para 'ground': " .. fullPath)
        end
    end

    -- Carrega os quads e texturas para os tiles de grama (Grass)
    for _, dir in ipairs(directions) do
        local imageName = "Ground G1_" .. dir .. ".png" -- Corrigido para o nome de arquivo real
        local fullPath = path .. imageName
        print("[ChunkMapManager] Tentando carregar imagem: " .. fullPath)
        local image = AssetManager:getImage(fullPath)

        if image then
            -- Correção: O objeto 'image' já é a textura. Não é necessário chamar :getTexture().
            local texture = image
            getOrCreateBatch(texture)
            self.tileAssets.grass[dir] = {
                texture = texture,
                quad = love.graphics.newQuad(0, 0, image:getWidth(), image:getHeight(), texture:getDimensions())
            }
        else
            error("Não foi possível carregar a imagem para 'grass': " .. fullPath)
        end
    end
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
                self.batchesDirty = true
            end
        end
    end

    -- Descarrega chunks antigos que não estão mais visíveis
    for key, chunk in pairs(self.chunks) do
        if not visibleChunks[key] then
            self:_unloadChunk(key)
            self.batchesDirty = true
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

            tileData.texture = assetInfo.texture
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

--- Desenha o mapa. Otimizado para reconstruir o SpriteBatch apenas quando necessário.
function ChunkMapManager:draw()
    if self.batchesDirty then
        -- Limpa todos os batches
        for _, batch in pairs(self.spriteBatches) do
            batch:clear()
        end

        -- Preenche os batches com os tiles dos chunks ativos
        for _, chunk in pairs(self.chunks) do
            for _, tile in ipairs(chunk.tiles) do
                local batch = self.spriteBatches[tile.texture]
                if batch then
                    batch:add(tile.quad, tile.x, tile.y)
                end
            end
        end
        self.batchesDirty = false
    end

    -- Desenha todos os batches
    for _, batch in pairs(self.spriteBatches) do
        love.graphics.draw(batch)
    end

    -- <<< ADICIONADO: Lógica de Debug Visual >>>
    if DEBUG_SHOW_CHUNK_BOUNDS then
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
    -- <<< FIM DA ADIÇÃO >>>
end

return ChunkMapManager
