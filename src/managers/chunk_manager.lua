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
    instance.tiles = {}                                                         -- Matriz [localY][localX]

    local baseGroundTilePath = "assets/tiles/basic_forest/grass/grass_base.png" -- ATUALIZADO
    if portalThemeData and portalThemeData.mapDefinition and portalThemeData.mapDefinition.tileAssets and portalThemeData.mapDefinition.tileAssets.grass then
        baseGroundTilePath = portalThemeData.mapDefinition.tileAssets.grass
    elseif portalThemeData and portalThemeData.mapDefinition and portalThemeData.mapDefinition.baseGroundTile then
        -- Fallback para baseGroundTile se tileAssets.grass não estiver definido
        baseGroundTilePath = portalThemeData.mapDefinition.baseGroundTile
    end

    for y = 1, instance.size do
        instance.tiles[y] = {}
        for x = 1, instance.size do
            instance.tiles[y][x] = {
                type = baseGroundTilePath,                 -- Caminho para o asset do tile
                isWalkable = true,
                worldX = (chunkX * instance.size) + x - 1, -- Coordenada global do tile (0-indexed)
                worldY = (chunkY * instance.size) + y - 1, -- Coordenada global do tile (0-indexed)
                localX = x,
                localY = y,
                objectId = nil,
                eventId = nil,
                regionId = nil,
                decorators = {},
                category = "grass" -- Categoria default
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
    if not self.currentPortalTheme or not self.currentPortalTheme.mapDefinition then
        print("ChunkManager Error: currentPortalTheme.mapDefinition não encontrado!")
        return nil
    end
    local mapDef = self.currentPortalTheme.mapDefinition
    local noiseParams = mapDef.noiseParameters
    local tileAssets = mapDef.tileAssets
    if not noiseParams or not tileAssets then
        print("ChunkManager Error: noiseParameters ou tileAssets não definidos!")
        return Chunk:new(chunkX, chunkY, self.chunkSize, self.currentPortalTheme)
    end
    if not self.noiseShader or not self.noiseCanvas or not NoiseLib or not NoiseLib.sample or not NoiseLib.types then
        print("ChunkManager Error: Sistema de noise via shader não está pronto. Usando tiles base.")
        return Chunk:new(chunkX, chunkY, self.chunkSize, self.currentPortalTheme) -- Retorna chunk base
    end

    local newChunk = Chunk:new(chunkX, chunkY, self.chunkSize, self.currentPortalTheme) -- Cria com tiles base primeiro
    local noiseScale = noiseParams.scale or 0.1

    -- Prepara para desenhar no canvas de noise
    love.graphics.pushState("all")
    love.graphics.setCanvas(self.noiseCanvas)
    love.graphics.clear() -- Limpa o canvas

    -- Coordenadas do canto do chunk no mundo do noise
    local noiseWorldX = chunkX * self.chunkSize * noiseScale
    local noiseWorldY = chunkY * self.chunkSize * noiseScale
    local noiseAreaWidth = self.chunkSize * noiseScale
    local noiseAreaHeight = self.chunkSize * noiseScale

    -- Amostra o noise para o canvas
    -- noise.sample(shader, noise_type, samples_x, samples_y, x, y, width, height, z, w)
    NoiseLib.sample(self.noiseShader, NoiseLib.types.simplex2d,
        self.chunkSize, self.chunkSize, -- samples_x, samples_y (um sample por pixel do canvas)
        noiseWorldX, noiseWorldY,       -- x, y (canto superior esquerdo no espaço do noise)
        noiseAreaWidth, noiseAreaHeight -- width, height (tamanho da área a ser amostrada no espaço do noise)
    -- z, w são opcionais para 2D e podem ser omitidos ou nil
    )
    love.graphics.setCanvas() -- Volta para o canvas principal
    love.graphics.popState()

    local imgData = self.noiseCanvas:newImageData()

    for ly = 1, newChunk.size do
        for lx = 1, newChunk.size do
            local r, g, b, a = imgData:getPixel(lx - 1, ly - 1) -- ImageData é 0-indexed
            local noiseValue = r /
                255                                             -- Assumindo que o noise (0-1) é armazenado no canal vermelho

            -- Se a biblioteca usar noise.decode, precisaríamos usá-lo aqui.
            -- Ex: local decodedValue = NoiseLib.decode(NoiseLib.encoding.default, r*255, g*255, b*255)
            -- Por enquanto, vamos assumir r/255.

            local selectedTileAssetPath = tileAssets.grass
            local isWalkable = true
            local tileCategory = "grass"

            if noiseValue < noiseParams.waterThreshold then
                selectedTileAssetPath = tileAssets.water
                isWalkable = false
                tileCategory = "water"
            elseif noiseValue < noiseParams.sandThreshold then
                selectedTileAssetPath = tileAssets.sand
                tileCategory = "sand"
            end

            newChunk:setTile(lx, ly, {
                type = selectedTileAssetPath,
                isWalkable = isWalkable,
                category = tileCategory
            })
        end
    end
    return newChunk
end

function ChunkManager:loadChunk(chunkX, chunkY)
    local key = self:_getChunkKey(chunkX, chunkY)
    if not self.activeChunks[key] then
        self.activeChunks[key] = self:_generateChunkData(chunkX, chunkY)
        if not self.activeChunks[key] then
            print(string.format("ChunkManager: Falha ao gerar chunk %s.", key))
        end
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

function ChunkManager:draw(cameraX, cameraY) -- cameraX, cameraY são o canto superior esquerdo da visão da câmera no mundo
    if not self.currentPortalTheme or not self.currentPortalTheme.mapDefinition or not self.assetManager then
        print("ChunkManager:draw - Pré-requisitos não atendidos (tema, mapDef, assetManager).")
        return
    end
    if not self.assetManager then
        print("ChunkManager:draw - AssetManager não definido.")
        return
    end

    -- Usa o tamanho global do tile
    local mapTileSize = { width = TILE_SIZE, height = TILE_SIZE }

    love.graphics.push()
    -- Aqui, assumimos que a câmera global já está aplicada (Camera:attach() em outro lugar)
    -- Se não, você precisaria aplicar transformações da câmera aqui ou passar a câmera.

    -- Determinar quais chunks estão visíveis (simplificado por agora, desenha todos os ativos)
    -- Uma otimização seria calcular os chunks que realmente estão na tela

    for key, chunk in pairs(self.activeChunks) do
        if chunk then
            for ty = 1, chunk.size do
                for tx = 1, chunk.size do
                    local tileData = chunk:getTile(tx, ty)
                    if tileData then
                        local isoX = (tileData.worldX - tileData.worldY) * (TILE_WIDTH / 2)
                        local isoY = (tileData.worldX + tileData.worldY) * (TILE_HEIGHT / 2)
                        local tileImage = self.assetManager:getImage(tileData.type)
                        if tileImage then
                            local imgW = tileImage:getWidth()
                            local imgH = tileImage:getHeight()
                            local scaleX = TILE_WIDTH / imgW
                            local scaleY = TILE_HEIGHT / imgH
                            -- Calcula o padding para centralizar o losango do PNG no losango lógico
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
                        else
                            local r, g, b = 0.5, 0.5, 0.5
                            if tileData.category == "water" then
                                r, g, b = 0, 0, 1
                            elseif tileData.category == "sand" then
                                r, g, b = 1, 1, 0
                            elseif tileData.category == "grass" then
                                r, g, b = 0, 1, 0
                            end
                            love.graphics.setColor(r, g, b, 0.8)
                            love.graphics.rectangle("fill", isoX, isoY, mapTileSize.width, mapTileSize.height / 2)
                            love.graphics.setColor(1, 1, 1, 1)
                        end
                        -- TODO: Desenhar objetos sobre o tile (tileData.objectId)
                    end
                end
            end
        end
    end
    love.graphics.pop()
end

return ChunkManager
