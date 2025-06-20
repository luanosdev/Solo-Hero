--- @class ChunkMapManager
--- Gerencia um mapa "infinito" baseado em chunks, gerado proceduralmente.
--- Usa um shader para corrigir artefatos de borda (anti-aliasing) nos tiles.
local ChunkMapManager = {}
ChunkMapManager.__index = ChunkMapManager

local Constants = require("src.config.constants")
local TablePool = require("src.utils.table_pool")
local AssetManager = require("src.managers.asset_manager")

--- Cria uma nova instância do ChunkMapManager.
--- @param playerManager PlayerManager - Para obter a posição do jogador.
--- @return ChunkMapManager
function ChunkMapManager:new(playerManager)
    local instance = setmetatable({}, ChunkMapManager)
    instance.playerManager = playerManager
    instance.chunks = {}
    instance.sortedRenderList = {}
    instance.tileAssets = { ground = {}, grass = {} }
    instance.lastPlayerChunkX, instance.lastPlayerChunkY = nil, nil
    instance.renderListDirty = true
    instance.alphaShader = love.graphics.newShader("src/ui/shaders/alpha_fix.fs")
    instance:_loadTileAssetsAndCreateAtlas()
    return instance
end

-- Função auxiliar para "limpar" a borda de 1 pixel de um ImageData.
-- Esta função está correta e usa a API do LÖVE.
local function getCleanedImageData(originalImageData)
    local sourceData = originalImageData:clone()
    local w, h = sourceData:getDimensions()

    local function mapCallback(x, y, r, g, b, a)
        local newR, newG, newB, newA = r, g, b, a
        if x == 0 or x == w - 1 or y == 0 or y == h - 1 then
            local sampleX = math.max(1, math.min(x, w - 2))
            local sampleY = math.max(1, math.min(y, h - 2))
            newR, newG, newB, newA = sourceData:getPixel(sampleX, sampleY)
        end
        return newR, newG, newB, newA
    end

    originalImageData:mapPixel(mapCallback)
    return originalImageData
end

--- Carrega as imagens, corrige suas bordas em memória e cria um atlas perfeito.
function ChunkMapManager:_loadTileAssetsAndCreateAtlas()
    local path = "assets/tilesets/forest/tiles/"
    local directions = { "N", "S", "E", "W" }
    local allTileInfo = {}
    local totalWidth, maxHeight = 0, 0

    local tilePrefixes = { ground = "Ground A1_", grass = "Ground G1_" }
    for tileType, prefix in pairs(tilePrefixes) do
        for _, dir in ipairs(directions) do
            local fullPath = path .. prefix .. dir .. ".png"

            -- [[ ESTA É A CORREÇÃO FINAL E DEFINITIVA ]]
            -- 1. Carrega os dados da imagem (ImageData) diretamente do arquivo.
            local success, originalData = pcall(love.image.newImageData, fullPath)

            if success and originalData then
                -- 2. "Limpa" as bordas escuras, sobrescrevendo-as com a cor do vizinho.
                local cleanedData = getCleanedImageData(originalData)
                -- 3. Cria uma nova imagem, já corrigida e pronta para desenhar, a partir dos dados.
                local cleanedImage = love.graphics.newImage(cleanedData)

                table.insert(allTileInfo,
                    {
                        type = tileType,
                        dir = dir,
                        image = cleanedImage,
                        width = cleanedImage:getWidth(),
                        height =
                            cleanedImage:getHeight()
                    })
                totalWidth = totalWidth + cleanedImage:getWidth()
                maxHeight = math.max(maxHeight, cleanedImage:getHeight())
            else
                error("Falha ao carregar ImageData para atlas: " .. fullPath .. "\n" .. tostring(originalData))
            end
        end
    end
    if #allTileInfo == 0 then return end

    self.tileAtlas = love.graphics.newCanvas(totalWidth, maxHeight)
    self.tileAtlas:setFilter("nearest", "nearest")
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

    love.graphics.setCanvas()

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
    local mapX = (worldX / TILE_WIDTH) + (worldY / TILE_HEIGHT)
    local mapY = (worldY / TILE_HEIGHT) - (worldX / TILE_WIDTH)
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
function ChunkMapManager:_updateVisibleChunks(pcx, pcy)
    local radius = Constants.VISIBLE_CHUNKS_RADIUS
    local visibleChunks = {}
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
    for key, chunk in pairs(self.chunks) do
        if not visibleChunks[key] then
            self:_unloadChunk(key)
            self.renderListDirty = true
        end
    end
end

--- Gera os dados para um único chunk com posicionamento por inteiros.
function ChunkMapManager:_generateChunk(cx, cy)
    local key = cx .. "_" .. cy
    love.math.setRandomSeed(cx, cy)
    local chunk = TablePool.get()
    chunk.cx, chunk.cy, chunk.tiles = cx, cy, TablePool.get()
    local directions = { "N", "S", "E", "W" }

    local TILE_WIDTH_HALF = math.floor(Constants.TILE_WIDTH / 2)
    local TILE_HEIGHT_HALF = math.floor(Constants.TILE_HEIGHT / 2)

    for ty = 1, Constants.CHUNK_SIZE do
        for tx = 1, Constants.CHUNK_SIZE do
            local tileData = TablePool.get()
            local randomValue = love.math.random()
            local tileType = randomValue > 0.3 and "grass" or "ground"
            local dir = directions[love.math.random(1, 4)]

            -- Voltamos ao simples: só precisamos do Quad
            tileData.quad = self.tileAssets[tileType][dir].quad

            local mapX = (cx * Constants.CHUNK_SIZE) + tx
            local mapY = (cy * Constants.CHUNK_SIZE) + ty
            tileData.x = (mapX - mapY) * TILE_WIDTH_HALF
            tileData.y = (mapX + mapY) * TILE_HEIGHT_HALF

            table.insert(chunk.tiles, tileData)
        end
    end
    self.chunks[key] = chunk
end

--- Remove um chunk da memória e libera seus recursos.
function ChunkMapManager:_unloadChunk(key)
    local chunk = self.chunks[key]
    if chunk then
        for i = #chunk.tiles, 1, -1 do
            TablePool.release(chunk.tiles[i])
        end
        TablePool.release(chunk.tiles)
        TablePool.release(chunk)
        self.chunks[key] = nil
    end
end

--- Desenha o mapa. Otimizado para reconstruir o SpriteBatch apenas quando necessário.
--- Desenha o mapa. Agora muito mais simples.
function ChunkMapManager:draw()
    if self.renderListDirty then
        if self.sortedRenderList then TablePool.release(self.sortedRenderList) end
        self.sortedRenderList = TablePool.get()
        for _, chunk in pairs(self.chunks) do
            for _, tile in ipairs(chunk.tiles) do
                table.insert(self.sortedRenderList, tile)
            end
        end
        table.sort(self.sortedRenderList, function(a, b) return a.y < b.y end)

        self.mainSpriteBatch:clear()
        for _, tile in ipairs(self.sortedRenderList) do
            -- Sem offsets, sem arredondamento. Apenas a posição base.
            self.mainSpriteBatch:add(tile.quad, tile.x, tile.y)
        end
        self.renderListDirty = false
    end

    if self.mainSpriteBatch then
        love.graphics.setShader(self.alphaShader)
        self.alphaShader:send("threshold", 0.9)
        love.graphics.draw(self.mainSpriteBatch)
        love.graphics.setShader()
    end

    self:_drawDebug()
end

--- Desenha informações de debug, como as bordas dos chunks.
function ChunkMapManager:_drawDebug()
    if not DEBUG_SHOW_CHUNK_BOUNDS then return end
    -- O código de debug permanece o mesmo...
    local TILE_WIDTH_HALF = Constants.TILE_WIDTH / 2
    local TILE_HEIGHT_HALF = Constants.TILE_HEIGHT / 2
    local CHUNK_SIZE = Constants.CHUNK_SIZE

    love.graphics.setLineWidth(2)
    for key, chunk in pairs(self.chunks) do
        local cx, cy = chunk.cx, chunk.cy
        local corner1_mapX = cx * CHUNK_SIZE
        local corner1_mapY = cy * CHUNK_SIZE
        local corner1_isoX = (corner1_mapX - corner1_mapY) * TILE_WIDTH_HALF
        local corner1_isoY = (corner1_mapX + corner1_mapY) * TILE_HEIGHT_HALF
        local corner2_mapX = (cx + 1) * CHUNK_SIZE
        local corner2_mapY = cy * CHUNK_SIZE
        local corner2_isoX = (corner2_mapX - corner2_mapY) * TILE_WIDTH_HALF
        local corner2_isoY = (corner2_mapX + corner2_mapY) * TILE_HEIGHT_HALF
        local corner3_mapX = (cx + 1) * CHUNK_SIZE
        local corner3_mapY = (cy + 1) * CHUNK_SIZE
        local corner3_isoX = (corner3_mapX - corner3_mapY) * TILE_WIDTH_HALF
        local corner3_isoY = (corner3_mapX + corner3_mapY) * TILE_HEIGHT_HALF
        local corner4_mapX = cx * CHUNK_SIZE
        local corner4_mapY = (cy + 1) * CHUNK_SIZE
        local corner4_isoX = (corner4_mapX - corner4_mapY) * TILE_WIDTH_HALF
        local corner4_isoY = (corner4_mapX + corner4_mapY) * TILE_HEIGHT_HALF

        love.graphics.setColor(1, 0, 0, 0.8)
        love.graphics.polygon("line", corner1_isoX, corner1_isoY, corner2_isoX, corner2_isoY, corner3_isoX, corner3_isoY,
            corner4_isoX, corner4_isoY)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(key, corner1_isoX - 50, corner1_isoY + (corner3_isoY - corner1_isoY) / 2, 100, "center")
    end
    love.graphics.setLineWidth(1)
end

return ChunkMapManager
