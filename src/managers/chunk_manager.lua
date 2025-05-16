local NoiseLib -- Será o módulo de noise carregado
local Constants = require("src.config.constants")

-- Defina o tamanho lógico do tile (em pixels) globalmente
local TILE_SIZE = Constants.TILE_SIZE
local TILE_WIDTH = Constants.TILE_WIDTH
local TILE_HEIGHT = Constants.TILE_HEIGHT

-- Define a classe Chunk primeiro
---@class Chunk
---@field chunkX number Coordenada X do chunk no grid de chunks
---@field chunkY number Coordenada Y do chunk no grid de chunks
---@field size number Tamanho do chunk (ex: 32 para 32x32 tiles)
---@field tiles table Matriz 2D (tabela de tabelas) para os tiles
---@field worldTiles table<string, table> Mapeamento de "x,y" local para dados de tile global
local Chunk = {}
Chunk.__index = Chunk

--- Cria uma nova instância de Chunk.
---@param chunkX number Coordenada X do chunk.
---@param chunkY number Coordenada Y do chunk.
---@param chunkSize number Tamanho do chunk (ex: 32).
---@param portalThemeData table Dados do tema do portal atual.
---@param globalSeed number Seed global para geração procedural.
---@return Chunk
function Chunk:new(chunkX, chunkY, chunkSize, portalThemeData, globalSeed)
    local instance = setmetatable({}, Chunk)
    instance.chunkX = chunkX
    instance.chunkY = chunkY
    instance.size = chunkSize
    instance.tiles = {}
    instance.decorations = {}
    local themeName = portalThemeData and portalThemeData.mapDefinition and portalThemeData.mapDefinition.theme or
        "forest"
    local theme = require("src.mapthemes." .. themeName)
    local tileAsset = theme.groundTile
    for y = 1, instance.size do
        instance.tiles[y] = {}
        for x = 1, instance.size do
            local worldX = (chunkX * instance.size) + (x - 1)
            local worldY = (chunkY * instance.size) + (y - 1)
            instance.tiles[y][x] = { worldX = worldX, worldY = worldY, type = tileAsset }
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

-- Carrega a biblioteca de noise (DEVE ser chamada ANTES de initialize se for usada lá diretamente)
-- ou dentro de initialize.
local noiseLoaded, noiseModuleOrError = pcall(require, "src.libs.noise") -- Assumindo que você nomeou o arquivo da lib para noise.lua
if noiseLoaded then
    NoiseLib = noiseModuleOrError
    print("Noise library 'src.libs.noise' loaded successfully.")
    -- A biblioteca 25A0/love2d-noise precisa de noise.init()
    if NoiseLib.init then
        NoiseLib.init() -- Chamar uma vez
        print("NoiseLib.init() called.")
    else
        print("WARN: NoiseLib.init() não encontrado. A biblioteca pode não precisar ou não é a esperada.")
    end
else
    print("ChunkManager ERRO: Falha ao carregar 'src.libs.noise'. Detalhes: " .. tostring(noiseModuleOrError))
    NoiseLib = nil -- Garante que está nil se falhar
end

function ChunkManager:initialize(portalThemeData, chunkSize, assetManagerInstance, randomSeed, maxDecorationsPerChunk)
    self.activeChunks = {}
    self.currentPortalTheme = portalThemeData
    self.chunkSize = chunkSize or 32
    self.bufferDistance = 1
    self.assetManager = assetManagerInstance
    self.currentSeed = randomSeed or os.time()
    self.maxDecorationsPerChunk = maxDecorationsPerChunk
    self.tileBatches = {} -- Para SpriteBatch por textura de tile
    self.tileQuads = {}   -- Para Quads reutilizáveis por textura de tile
    -- self.decorationBatches removido, não será usado com a nova abordagem de renderList
    print(string.format("ChunkManager initialized. ChunkSize: %d, Seed: %s", self.chunkSize, tostring(self.currentSeed)))
end

function ChunkManager:_getChunkKey(chunkX, chunkY) return chunkX .. "," .. chunkY end

function ChunkManager:_generateChunkData(chunkX, chunkY)
    local newChunk = Chunk:new(chunkX, chunkY, self.chunkSize, self.currentPortalTheme, self.currentSeed)
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
        self.activeChunks[key] = self:_generateChunkData(chunkX, chunkY)
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
    local screenW, screenH = love.graphics.getDimensions()
    cameraX = cameraX or 0; cameraY = cameraY or 0
    local bufferPx = (self.bufferDistance or 1) * self.chunkSize * TILE_WIDTH
    local minWorldXVisible = cameraX - bufferPx
    local minWorldYVisible = cameraY - bufferPx           -- Ajuste: Y isométrico para culling de chunks
    local maxWorldXVisible = cameraX + screenW + bufferPx
    local maxWorldYVisible = cameraY + screenH + bufferPx -- Ajuste: Y isométrico para culling de chunks

    -- Conversão para coordenadas de chunk (considerando tiles isométricos)
    -- A área de chunks a carregar precisa cobrir a projeção isométrica da tela
    local minChunkX = math.floor(minWorldXVisible / (self.chunkSize * TILE_WIDTH)) - self.bufferDistance -
        1 -- Buffer extra para bordas
    local maxChunkX = math.floor(maxWorldXVisible / (self.chunkSize * TILE_WIDTH)) + self.bufferDistance + 1
    local minChunkY = math.floor(minWorldYVisible / (self.chunkSize * TILE_HEIGHT * 0.5)) - self.bufferDistance -
        2 -- TILE_HEIGHT * 0.5 pela natureza isométrica e buffer maior em Y
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

    if DEV then
        if loadedThisFrame > 0 or unloadedThisFrame > 0 then
            print(string.format("[CM Update] Active: %d | Loaded: %d | Unloaded: %d | RangeCX: %d-%d | RangeCY: %d-%d",
                tablelength(self.activeChunks), loadedThisFrame, unloadedThisFrame, minChunkX, maxChunkX, minChunkY,
                maxChunkY))
        end
    end
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

    -- Limpa todos os batches de tiles no início de cada coleta
    for texturePath, batch in pairs(self.tileBatches) do
        batch:clear()
    end

    for _, chunk in pairs(self.activeChunks) do
        if chunk then
            -- Culling de Chunk
            local minTileX = chunk.chunkX * chunk.size
            local minTileY = chunk.chunkY * chunk.size
            local maxTileX = minTileX + chunk.size - 1
            local maxTileY = minTileY + chunk.size - 1

            -- Cantos do chunk em coordenadas de tile do mundo:
            -- p1 (minTileX, minTileY) - Canto superior do mapa, mais à esquerda na tela
            -- p2 (maxTileX, minTileY) - Canto direito do mapa, topo
            -- p3 (minTileX, maxTileY) - Canto esquerdo do mapa, base
            -- p4 (maxTileX, maxTileY) - Canto inferior do mapa, mais à direita na tela

            -- Bounding box do chunk em coordenadas isométricas (tela)
            -- Ponto mais à esquerda na tela: canto esquerdo do tile (minTileX, maxTileY)
            local chunkScreenMinX = (minTileX - maxTileY) * TILE_WIDTH_HALF - TILE_WIDTH_HALF
            -- Ponto mais à direita na tela: canto direito do tile (maxTileX, minTileY)
            local chunkScreenMaxX = (maxTileX - minTileY) * TILE_WIDTH_HALF + TILE_WIDTH_HALF
            -- Ponto mais ao topo na tela: pico do tile (minTileX, minTileY)
            local chunkScreenMinY = (minTileX + minTileY) * TILE_HEIGHT_HALF
            -- Ponto mais abaixo na tela: base do tile (maxTileX, maxTileY)
            local chunkScreenMaxY = (maxTileX + maxTileY) * TILE_HEIGHT_HALF + Constants.TILE_HEIGHT

            if chunkScreenMaxX < camMinX or chunkScreenMinX > camMaxX or chunkScreenMaxY < camMinY or chunkScreenMinY > camMaxY then
                -- Chunk está completamente fora da tela, pular para o próximo
                goto continue_chunk_loop
            end

            -- Coleta Tiles
            for ty = 1, chunk.size do
                for tx = 1, chunk.size do
                    local tileData = chunk:getTile(tx, ty)
                    if tileData then
                        local tileAssetPath = tileData.type -- type é o caminho do asset
                        local tileImage = self.assetManager:getImage(tileAssetPath)
                        if tileImage then
                            local imgW, imgH = tileImage:getDimensions()
                            local isoX = (tileData.worldX - tileData.worldY) *
                                TILE_WIDTH_HALF -- Correção aqui, já era TILE_WIDTH/2
                            local isoY = (tileData.worldX + tileData.worldY) *
                                TILE_HEIGHT_HALF -- Correção aqui, já era TILE_HEIGHT/2

                            -- Culling básico de tiles (pode ser mais preciso)
                            if isoX + Constants.TILE_WIDTH > camMinX and isoX - Constants.TILE_WIDTH < camMaxX and isoY + Constants.TILE_HEIGHT * 2 > camMinY and isoY < camMaxY then
                                local scaleX = Constants.TILE_WIDTH / imgW
                                local scaleY = Constants.TILE_HEIGHT / imgH

                                local finalDrawX = isoX -
                                    TILE_WIDTH_HALF -- Correção aqui, já era Constants.TILE_WIDTH / 2
                                local finalDrawY = isoY

                                -- Gerencia SpriteBatch e Quad para esta textura de tile
                                if not self.tileBatches[tileAssetPath] then
                                    self.tileBatches[tileAssetPath] = love.graphics.newSpriteBatch(tileImage, 2048,
                                        "static")
                                end
                                if not self.tileQuads[tileAssetPath] then
                                    self.tileQuads[tileAssetPath] = love.graphics.newQuad(0, 0, imgW, imgH,
                                        tileImage:getDimensions())
                                end

                                local batch = self.tileBatches[tileAssetPath]
                                local quad = self.tileQuads[tileAssetPath]
                                batch:add(quad, finalDrawX, finalDrawY, 0, scaleX, scaleY)

                                -- REMOVIDO: Inserção individual de tiles na renderList
                                -- table.insert(renderList, {
                                --     type = "tile",
                                --     sortY = isoY + Constants.TILE_HEIGHT, -- Ordena pela base do tile
                                --     image = tileImage,
                                --     drawX = finalDrawX,
                                --     drawY = finalDrawY,
                                --     scaleX = scaleX,
                                --     scaleY = scaleY,
                                --     depth = 0 -- Tiles do chão são a base
                                -- })
                            end
                        end
                    end
                end
            end

            -- Coleta Decorações
            if chunk.decorations then
                for _, deco in ipairs(chunk.decorations) do
                    local decoImage = self.assetManager:getImage(deco.asset)
                    if decoImage then
                        local imgW, imgH = decoImage:getDimensions()

                        -- Coordenadas de pixel cartesianas globais da âncora da decoração
                        local anchorPx = (chunk.chunkX * chunk.size * Constants.TILE_WIDTH) + deco.px
                        local anchorPy = (chunk.chunkY * chunk.size * Constants.TILE_HEIGHT) + deco.py

                        -- Converte coordenadas da âncora para "unidades de tile" equivalentes
                        local worldX_eq_deco = anchorPx / Constants.TILE_WIDTH
                        local worldY_eq_deco = anchorPy / Constants.TILE_HEIGHT

                        -- Calcula o Y isométrico de referência (como se fosse o topo de um tile no ponto da âncora)
                        local isoY_deco_ref_top = (worldX_eq_deco + worldY_eq_deco) * (Constants.TILE_HEIGHT / 2)
                        -- A sortY da decoração é este Y de referência + a altura visual padrão (como os tiles)
                        -- Isso garante que a "base" da decoração seja comparável à "base" de um tile.
                        -- Usamos math.ceil para garantir que a decoração seja ordenada corretamente
                        -- em relação aos tiles, cujas sortY são efetivamente inteiras.
                        -- Adicionamos um pequeno offset para sombras mais longas.
                        local shadow_fudge_factor = 24 -- Pixels extras para empurrar a base da sombra para baixo (novo aumento)
                        local decoration_sortY = isoY_deco_ref_top + Constants.TILE_HEIGHT + shadow_fudge_factor

                        -- Calcula o X isométrico de referência para centralização
                        local isoX_deco_ref_center = (worldX_eq_deco - worldY_eq_deco) * (Constants.TILE_WIDTH / 2)

                        -- O drawX é o X de referência menos metade da largura da imagem para centralizar.
                        local drawX = isoX_deco_ref_center - imgW / 2
                        -- O drawY é a sortY (base da decoração no chão) menos a altura total da imagem.
                        local drawY = decoration_sortY - imgH

                        -- Culling de decoração individual (já existia, mas pode ser refinado se necessário)
                        if drawX + imgW > camMinX and drawX < camMaxX and drawY + imgH > camMinY and drawY < camMaxY then
                            table.insert(renderList, {
                                type = "decoration",
                                sortY = decoration_sortY, -- Ordena pela base da decoração no chão
                                image = decoImage,
                                drawX = drawX,
                                drawY = drawY,
                                depth = 2 -- Decorações agora têm depth 2, acima de jogador/inimigos (1)
                            })
                        end
                    end
                end
            end
        end
        ::continue_chunk_loop:: -- Label para o goto
    end

    -- Adiciona os batches de tiles à renderList
    for texturePath, batch in pairs(self.tileBatches) do
        if batch:getCount() > 0 then -- Verifica se o batch tem algo para desenhar
            table.insert(renderList, {
                type = "tile_batch",
                batch = batch,
                sortY = -10000, -- Garante que seja desenhado primeiro
                depth = -1      -- Define uma profundidade baixa
            })
        end
    end
end

-- Função de draw foi removida/substituída por collectRenderables
-- A cena agora é responsável por ordenar e desenhar a renderList.

function tablelength(T)
    local c = 0
    for _ in pairs(T) do c = c + 1 end
    return c
end

return ChunkManager
