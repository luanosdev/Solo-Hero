local Constants = require("src.config.constants")

-- Defina o tamanho lógico do tile (em pixels) globalmente
local TILE_WIDTH = Constants.TILE_WIDTH
local TILE_HEIGHT = Constants.TILE_HEIGHT

-- Define a classe Chunk primeiro
---@class Chunk
---@field chunkX number Coordenada X do chunk no grid de chunks
---@field chunkY number Coordenada Y do chunk no grid de chunks
---@field size number Tamanho do chunk (ex: 32 para 32x32 tiles)
---@field tiles table Matriz 2D (tabela de tabelas) para os tiles, agora contendo image e quad
---@field decorations table Lista de decorações do chunk
local Chunk = {}
Chunk.__index = Chunk

--- Cria uma nova instância de Chunk.
---@param chunkX number Coordenada X do chunk.
---@param chunkY number Coordenada Y do chunk.
---@param chunkSize number Tamanho do chunk (ex: 32).
---@param theme table O objeto do tema carregado.
---@param globalSeed number Seed global para geração procedural.
---@param groundTileAssetPath string Caminho do asset para o tile de chão.
---@param groundTileImage love.Image Imagem pré-carregada para o tile de chão.
---@param groundTileFullQuad love.Quad Quad pré-criado para o tile de chão (cobrindo imagem inteira).
---@param groundTileFaceQuad love.Quad Quad da face plana visível do tile.
---@return Chunk
function Chunk:new(
    chunkX,
    chunkY,
    chunkSize,
    theme,
    globalSeed,
    groundTileAssetPath,
    groundTileImage,
    groundTileFullQuad,
    groundTileFaceQuad
)
    local instance = setmetatable({}, Chunk)
    instance.chunkX = chunkX
    instance.chunkY = chunkY
    instance.size = chunkSize
    instance.tiles = {}
    instance.decorations = {}

    -- Preenche os tiles do chunk com a imagem e quad pré-carregados
    for y = 1, instance.size do
        instance.tiles[y] = {}
        for x = 1, instance.size do
            local worldX = (chunkX * instance.size) + (x - 1)
            local worldY = (chunkY * instance.size) + (y - 1)
            instance.tiles[y][x] = {
                worldX = worldX,
                worldY = worldY,
                assetPath = groundTileAssetPath,
                image = groundTileImage,
                quad_full = groundTileFullQuad,
                quad_face = groundTileFaceQuad
            }
        end
    end

    if theme.generateDecorations then
        instance.decorations = theme.generateDecorations(chunkX, chunkY, chunkSize, globalSeed)
    end
    return instance
end

--- Obtém um tile específico dentro do chunk (coordenadas locais 1-indexed).
---@param localX number Coordenada X local (1 a N).
---@param localY number Coordenada Y local (1 a N).
---@return table|nil Dados do tile ou nil se fora dos limites.
function Chunk:getTile(localX, localY)
    if localX >= 1 and localX <= self.size and localY >= 1 and localY <= self.size then
        return self.tiles[localY][localX]
    end
    return nil
end

--- Define dados de um tile (coordenadas locais 1-indexed).
---@param localX number Coordenada X local.
---@param localY number Coordenada Y local.
---@param tileData table Dados a serem mesclados no tile.
---@return boolean True se sucesso, false caso contrário.
function Chunk:setTile(localX, localY, tileData)
    if localX >= 1 and localX <= self.size and localY >= 1 and localY <= self.size then
        local currentTile = self.tiles[localY][localX]
        for k, v in pairs(tileData) do
            currentTile[k] = v
        end
        return true
    end
    return false
end

-- Define o ChunkManager
---@class ChunkManager
---@field activeChunks table<string, Chunk> Chunks ativos, chaveados por "chunkX,chunkY"
---@field chunkSize number Tamanho de cada chunk (ex: 32x32 tiles)
---@field viewDistance number Raio de chunks a manter carregados (ex: 2 = 5x5 area)
---@field noiseShader function Função de Perlin/Simplex Noise a ser usada
---@field currentPortalTheme table Dados do tema do portal atual (de portal_definitions.lua)
---@field assetManager AssetManager Referência ao AssetManager
local ChunkManager = {}

function ChunkManager:initialize(portalThemeData, chunkSize, assetManagerInstance, randomSeed, maxDecorationsPerChunk)
    self.activeChunks = {}
    self.currentPortalTheme = portalThemeData
    self.chunkSize = chunkSize or 32
    self.bufferDistance = 1
    self.assetManager = assetManagerInstance
    self.currentSeed = randomSeed or os.time()
    self.maxDecorationsPerChunk = maxDecorationsPerChunk
    self.tileBatches = {}
    self.wallHeightToIgnore = 14
end

function ChunkManager:_getChunkKey(chunkX, chunkY) return chunkX .. "," .. chunkY end

function ChunkManager:_generateChunkData(chunkX, chunkY)
    local themeName = self.currentPortalTheme and self.currentPortalTheme.mapDefinition and
        self.currentPortalTheme.mapDefinition.theme or "forest"
    local theme = require("src.mapthemes." .. themeName)
    local groundAssetPath = theme.groundTile
    if not groundAssetPath then
        Logger.error("ChunkManager", "Theme '" .. themeName .. "' não define 'groundTile'!")
    end

    local groundTileImage = self.assetManager:getImage(groundAssetPath)
    if not groundTileImage then
        Logger.warn("ChunkManager",
            "Image for groundTile '" .. groundAssetPath .. "' of theme '" .. themeName .. "' not found.")
        return nil
    end

    local imgW, imgH = groundTileImage:getDimensions()
    local groundTileFullQuad = love.graphics.newQuad(0, 0, imgW, imgH, imgW, imgH)

    -- Cria o quad da face plana aqui
    local quadVisibleContentHeight = imgH - self.wallHeightToIgnore
    if quadVisibleContentHeight <= 0 then quadVisibleContentHeight = imgH end -- Evita altura negativa/zero
    local groundTileFaceQuad = love.graphics.newQuad(0, 0, imgW, quadVisibleContentHeight, imgW, imgH)

    local newChunk = Chunk:new(chunkX, chunkY, self.chunkSize, theme, self.currentSeed, groundAssetPath, groundTileImage,
        groundTileFullQuad, groundTileFaceQuad)

    if self.maxDecorationsPerChunk and newChunk.decorations and #newChunk.decorations > self.maxDecorationsPerChunk then
        local limited = {}
        for i = 1, self.maxDecorationsPerChunk do table.insert(limited, newChunk.decorations[i]) end
        newChunk.decorations = limited
    end
    return newChunk
end

function ChunkManager:loadChunk(chunkX, chunkY)
    local key = self:_getChunkKey(chunkX, chunkY)
    if not self.activeChunks[key] then
        local generatedChunk = self:_generateChunkData(chunkX, chunkY)
        if generatedChunk then
            self.activeChunks[key] = generatedChunk
        else
            Logger.error("ChunkManager", "Failed to generate data for chunk " .. chunkX .. ", " .. chunkY .. ".")
        end
    end
    return self.activeChunks[key]
end

function ChunkManager:unloadChunk(chunkX, chunkY)
    local key = self:_getChunkKey(chunkX, chunkY)
    if self.activeChunks[key] then self.activeChunks[key] = nil end
end

function ChunkManager:getTileAt(worldX, worldY)
    local chunkX = math.floor(worldX / self.chunkSize)
    local chunkY = math.floor(worldY / self.chunkSize)
    local localX = worldX - (chunkX * self.chunkSize) + 1
    local localY = worldY - (chunkY * self.chunkSize) + 1
    local chunk = self:loadChunk(chunkX, chunkY)
    return chunk and chunk:getTile(localX, localY) or nil
end

function ChunkManager:update(playerWorldX, playerWorldY, cameraX, cameraY)
    if not playerWorldX or not playerWorldY then return end
    local screenW, screenH = love.graphics.getDimensions() -- Chamada única aqui
    cameraX = cameraX or 0; cameraY = cameraY or 0
    local bufferPx = (self.bufferDistance or 1) * self.chunkSize * TILE_WIDTH
    local minWorldXVisible = cameraX - bufferPx
    local minWorldYVisible = cameraY - bufferPx
    local maxWorldXVisible = cameraX + screenW + bufferPx
    local maxWorldYVisible = cameraY + screenH + bufferPx

    local minChunkX = math.floor(minWorldXVisible / (self.chunkSize * TILE_WIDTH)) - self.bufferDistance - 1
    local maxChunkX = math.floor(maxWorldXVisible / (self.chunkSize * TILE_WIDTH)) + self.bufferDistance + 1
    local minChunkY = math.floor(minWorldYVisible / (self.chunkSize * TILE_HEIGHT * 0.5)) - self.bufferDistance - 2
    local maxChunkY = math.floor(maxWorldYVisible / (self.chunkSize * TILE_HEIGHT * 0.5)) + self.bufferDistance + 2

    local loadedThisFrame = 0
    local unloadedThisFrame = 0
    local requiredChunks = {}

    for cx = minChunkX, maxChunkX do
        for cy = minChunkY, maxChunkY do
            local key = self:_getChunkKey(cx, cy)
            requiredChunks[key] = true
            if not self.activeChunks[key] then
                self:loadChunk(cx, cy)
                loadedThisFrame = loadedThisFrame + 1
            end
        end
    end

    local chunksToUnload = {}
    for key, _ in pairs(self.activeChunks) do
        if not requiredChunks[key] then table.insert(chunksToUnload, key) end
    end

    for _, keyToUnload in ipairs(chunksToUnload) do
        local chunkCoords = {}
        for coordStr in string.gmatch(keyToUnload, "([^-?,]+)") do table.insert(chunkCoords, tonumber(coordStr)) end
        if #chunkCoords == 2 then
            self:unloadChunk(chunkCoords[1], chunkCoords[2])
            unloadedThisFrame = unloadedThisFrame + 1
        end
    end

    Logger.debug("ChunkManager", "Loaded " .. loadedThisFrame .. " chunks, unloaded " .. unloadedThisFrame .. " chunks.")
end

--- Coleta todos os objetos renderizáveis (tiles e decorações) dos chunks ativos.
---@param cameraX number Posição X da câmera.
---@param cameraY number Posição Y da câmera.
---@param renderList table Lista onde os objetos renderizáveis serão adicionados.
function ChunkManager:collectRenderables(cameraX, cameraY, renderList)
    if not self.currentPortalTheme or not self.currentPortalTheme.mapDefinition or not self.assetManager then return end
    local screenW, screenH = love.graphics.getDimensions()
    local TILE_WIDTH_HALF = Constants.TILE_WIDTH / 2
    local TILE_HEIGHT_HALF = Constants.TILE_HEIGHT / 2
    local camMinX = cameraX
    local camMaxX = cameraX + screenW
    local camMinY = cameraY
    local camMaxY = cameraY + screenH

    for _, batch in pairs(self.tileBatches) do
        batch:clear()
    end

    for _, chunk in pairs(self.activeChunks) do
        if chunk then
            -- Culling de Chunk (lógica existente mantida)
            local chunkWorldMinX = chunk.chunkX * chunk.size * Constants.TILE_WIDTH
            local chunkWorldMinY = chunk.chunkY * chunk.size * Constants.TILE_HEIGHT
            local chunkWorldMaxX = chunkWorldMinX + chunk.size * Constants.TILE_WIDTH
            local chunkWorldMaxY = chunkWorldMinY + chunk.size * Constants.TILE_HEIGHT
            local chunkScreenCorner1X = (chunkWorldMinX - chunkWorldMaxY) * TILE_WIDTH_HALF
            local chunkScreenCorner1Y = (chunkWorldMinX + chunkWorldMaxY) * TILE_HEIGHT_HALF
            local chunkScreenCorner2X = (chunkWorldMaxX - chunkWorldMinY) * TILE_WIDTH_HALF
            local chunkScreenCorner2Y = (chunkWorldMaxX + chunkWorldMinY) * TILE_HEIGHT_HALF
            local chunkVisibleMinX = math.min(chunkScreenCorner1X, chunkScreenCorner2X) - Constants.TILE_WIDTH
            local chunkVisibleMaxX = math.max(chunkScreenCorner1X, chunkScreenCorner2X) + Constants.TILE_WIDTH
            local chunkVisibleMinY = math.min(chunkScreenCorner1Y, chunkScreenCorner2Y,
                (chunkWorldMinX + chunkWorldMinY) * TILE_HEIGHT_HALF) - Constants.TILE_HEIGHT
            local chunkVisibleMaxY = math.max(chunkScreenCorner1Y, chunkScreenCorner2Y,
                (chunkWorldMaxX + chunkWorldMaxY) * TILE_HEIGHT_HALF) + Constants.TILE_HEIGHT
            if chunkVisibleMaxX < camMinX or chunkVisibleMinX > camMaxX or chunkVisibleMaxY < camMinY or chunkVisibleMinY > camMaxY then
                goto continue_chunk_loop
            end

            -- Coleta Tiles
            for ty = 1, chunk.size do
                for tx = 1, chunk.size do
                    local tileData = chunk.tiles[ty][tx]
                    if tileData and tileData.image and tileData.quad_face then
                        local tileImage = tileData.image
                        local tileFaceQuad = tileData.quad_face

                        local worldTileX = tileData.worldX
                        local worldTileY = tileData.worldY
                        local isoX = (worldTileX - worldTileY) * TILE_WIDTH_HALF
                        local isoY = (worldTileX + worldTileY) * TILE_HEIGHT_HALF

                        if isoX + Constants.TILE_WIDTH > camMinX and isoX - Constants.TILE_WIDTH < camMaxX and isoY + Constants.TILE_HEIGHT * 2 > camMinY and isoY < camMaxY then
                            local imgW_actual, imgH_actual = tileImage:getDimensions()
                            local _, _, _, qFaceH = tileFaceQuad:getViewport()

                            local scaleX = Constants.TILE_WIDTH / imgW_actual
                            local scaleY = Constants.TILE_HEIGHT / qFaceH

                            local finalDrawX = isoX - (Constants.TILE_WIDTH / 2)
                            local finalDrawY = isoY

                            if not self.tileBatches[tileImage] then
                                self.tileBatches[tileImage] = love.graphics.newSpriteBatch(tileImage, 2048, "static")
                            end
                            self.tileBatches[tileImage]:add(tileFaceQuad, finalDrawX, finalDrawY, 0, scaleX, scaleY)
                        end
                    end
                end
            end
        end
        ::continue_chunk_loop::
    end

    for _, batch in pairs(self.tileBatches) do
        if batch:getCount() > 0 then
            table.insert(renderList, {
                type = "tile_batch",
                batch = batch,
                sortY = -10000,
                depth = -1
            })
        end
    end
end

return ChunkManager
