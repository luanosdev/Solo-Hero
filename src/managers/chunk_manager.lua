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
---@return Chunk
function Chunk:new(chunkX, chunkY, chunkSize, portalThemeData)
    local instance = setmetatable({}, Chunk)
    instance.chunkX = chunkX
    instance.chunkY = chunkY
    instance.size = chunkSize
    instance.tiles = {}

    local tileAsset = "assets/tiles/basic_forest/ground/ground_base.png"
    if portalThemeData and portalThemeData.mapDefinition and portalThemeData.mapDefinition.tileAsset then
        tileAsset = portalThemeData.mapDefinition.tileAsset
    end

    for y = 1, instance.size do
        instance.tiles[y] = {}
        for x = 1, instance.size do
            local worldX = (chunkX * instance.size) + (x - 1)
            local worldY = (chunkY * instance.size) + (y - 1)
            instance.tiles[y][x] = {
                worldX = worldX,
                worldY = worldY,
                type = tileAsset
            }
        end
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

function ChunkManager:initialize(portalThemeData, chunkSize, assetManagerInstance, randomSeed)
    self.activeChunks = {}
    self.currentPortalTheme = portalThemeData
    self.chunkSize = chunkSize or 32
    self.viewDistance = 2
    self.assetManager = assetManagerInstance
    self.noiseShader = nil
    self.noiseCanvas = nil
    self.currentSeed = randomSeed or os.time()

    if not self.assetManager then
        print("ChunkManager WARN: AssetManager não fornecido na inicialização.")
    end

    if NoiseLib and NoiseLib.build_shader then
        local shaderPath = "assets/shaders/noise.frag"
        local success, shader_or_error = pcall(NoiseLib.build_shader, shaderPath, self.currentSeed)
        if success then
            self.noiseShader = shader_or_error
            print(string.format("Noise shader '%s' compilado com seed %d.", shaderPath, self.currentSeed))
            -- Cria o canvas para amostragem de noise
            if love.graphics.newCanvas then
                local canvasSuccess, canvas_or_error = pcall(love.graphics.newCanvas, self.chunkSize, self.chunkSize)
                if canvasSuccess then
                    self.noiseCanvas = canvas_or_error
                    print(string.format("Noise canvas %dx%d criado.", self.chunkSize, self.chunkSize))
                else
                    print("ChunkManager ERRO: Falha ao criar noiseCanvas: " .. tostring(canvas_or_error))
                end
            else
                print("ChunkManager ERRO: love.graphics.newCanvas não disponível (versão antiga do LÖVE?)")
            end
        else
            print(string.format("ChunkManager ERRO: Falha ao compilar noise shader '%s': %s", shaderPath,
                tostring(shader_or_error)))
        end
    else
        print(
            "ChunkManager WARN: NoiseLib.build_shader não disponível. Geração de noise procedural via shader não funcionará.")
        -- Poderíamos implementar um fallback para uma função de noise puramente Lua aqui se desejado
    end

    print(string.format("ChunkManager initialized. ChunkSize: %d, ViewDistance: %d", self.chunkSize, self.viewDistance))
end

function ChunkManager:_getChunkKey(chunkX, chunkY)
    return chunkX .. "," .. chunkY
end

function ChunkManager:_generateChunkData(chunkX, chunkY)
    local newChunk = Chunk:new(chunkX, chunkY, self.chunkSize, self.currentPortalTheme)
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
    if self.activeChunks[key] then
        self.activeChunks[key] = nil
    end
end

function ChunkManager:getTileAt(worldX, worldY)
    local chunkX = math.floor(worldX / self.chunkSize)
    local chunkY = math.floor(worldY / self.chunkSize)
    local localX = worldX - (chunkX * self.chunkSize) + 1
    local localY = worldY - (chunkY * self.chunkSize) + 1
    local chunk = self:loadChunk(chunkX, chunkY)
    if chunk then
        return chunk:getTile(localX, localY)
    end
    return nil
end

function ChunkManager:update(playerWorldX, playerWorldY)
    if not playerWorldX or not playerWorldY then
        return
    end
    local currentPlayerChunkX = math.floor(playerWorldX / self.chunkSize)
    local currentPlayerChunkY = math.floor(playerWorldY / self.chunkSize)
    for dx = -self.viewDistance, self.viewDistance do
        for dy = -self.viewDistance, self.viewDistance do
            self:loadChunk(currentPlayerChunkX + dx, currentPlayerChunkY + dy)
        end
    end
    local chunksToUnload = {}
    for key, chunk in pairs(self.activeChunks) do
        local distSq = (chunk.chunkX - currentPlayerChunkX) ^ 2 + (chunk.chunkY - currentPlayerChunkY) ^ 2
        if distSq > (self.viewDistance + 1) ^ 2 then
            table.insert(chunksToUnload, key)
        end
    end
    for _, keyToUnload in ipairs(chunksToUnload) do
        local chunkCoords = {}
        for coordStr in string.gmatch(keyToUnload, "([^-?,]+)") do
            table.insert(chunkCoords, tonumber(coordStr))
        end
        if #chunkCoords == 2 then
            self:unloadChunk(chunkCoords[1], chunkCoords[2])
        end
    end
end

function ChunkManager:draw(cameraX, cameraY)
    if not self.currentPortalTheme or not self.currentPortalTheme.mapDefinition or not self.assetManager then
        print("ChunkManager:draw - Pré-requisitos não atendidos (tema, mapDef, assetManager).")
        return
    end
    local mapTileSize = { width = TILE_SIZE, height = TILE_SIZE }
    love.graphics.push()
    for key, chunk in pairs(self.activeChunks) do
        if chunk then
            for ty = 1, chunk.size do
                for tx = 1, chunk.size do
                    local tile = chunk:getTile(tx, ty)
                    if tile then
                        local isoX = (tile.worldX - tile.worldY) * (TILE_WIDTH / 2)
                        local isoY = (tile.worldX + tile.worldY) * (TILE_HEIGHT / 2)
                        local tileImage = self.assetManager:getImage(tile.type)
                        if tileImage then
                            local imgW = tileImage:getWidth()
                            local imgH = tileImage:getHeight()
                            local scaleX = TILE_WIDTH / imgW
                            local scaleY = TILE_HEIGHT / imgH
                            local padX = (imgW - TILE_WIDTH) / 2
                            local padY = (imgH - TILE_HEIGHT) / 2
                            love.graphics.draw(
                                tileImage,
                                isoX - padX * scaleX,
                                isoY - (TILE_HEIGHT / 2) - padY * scaleY,
                                0,
                                scaleX,
                                scaleY
                            )
                        end
                    end
                end
            end
        end
    end
    love.graphics.pop()
end

return ChunkManager
