-- src/managers/procedural_map_manager.lua
-- Gerencia a geração procedural de mapas infinitos baseados em chunks.

local MapManager = require("src.managers.map_manager")
local Constants = require("src.config.constants")
local fonts = require("src.ui.fonts")

---@class ProceduralMapManager
---@field mapName string
---@field assetManager AssetManager
---@field mapData table
---@field chunks table
---@field chunkSize number
---@field viewDistance number
---@field groundImage love.Image
local ProceduralMapManager = {}
ProceduralMapManager.__index = ProceduralMapManager

--- Cria uma nova instância do ProceduralMapManager.
--- @param mapName string O nome do mapa a ser gerado (ex: "florest").
--- @param assetManager AssetManager A instância do AssetManager para carregar imagens.
--- @return ProceduralMapManager instance Uma nova instância do gerenciador.
function ProceduralMapManager:new(mapName, assetManager)
    local instance = setmetatable({}, ProceduralMapManager)
    instance.mapName = mapName
    instance.assetManager = assetManager
    Logger.info("ProceduralMapManager.new", "Criando ProceduralMapManager para o mapa: " .. mapName)

    -- Carrega os dados de configuração do mapa usando o MapManager estático.
    instance.mapData = MapManager:loadMap(mapName)

    -- Armazena os chunks gerados. A chave será uma string "x,y", e o valor será o SpriteBatch do chunk.
    instance.chunks = {}
    instance.chunkSize = 16   -- Tamanho do chunk em tiles (16x16).
    instance.viewDistance = 1 -- Distância em chunks ao redor do jogador (1 = grid 3x3).

    -- Recursos para renderização do chão.
    -- O groundBatch global foi removido.
    instance.groundImage = nil
    instance.groundQuad = nil

    instance:_initializeRenderer()

    return instance
end

--- Inicializa os recursos de renderização para o mapa.
function ProceduralMapManager:_initializeRenderer()
    local groundTilePath = self.mapData and self.mapData.ground and self.mapData.ground.tile
    if not groundTilePath then
        error("ProceduralMapManager: Caminho do tile de chão não definido para o mapa " .. self.mapName)
    end

    self.groundImage = self.assetManager:getImage(groundTilePath)
    if not self.groundImage then
        error("ProceduralMapManager: Falha ao carregar imagem do tile: " .. groundTilePath)
    end

    -- Assume que o tile usa a imagem inteira.
    local w, h = self.groundImage:getDimensions()
    self.groundQuad = love.graphics.newQuad(0, 0, w, h, w, h)

    -- Remove a criação do SpriteBatch global. Eles serão criados por chunk.
    Logger.info("ProceduralMapManager.start", "Renderizador do ProceduralMapManager inicializado.")
end

--- Gera um chunk específico do mapa.
-- Por enquanto, apenas preenche com o tile de chão padrão.
-- @param chunkX (number) A coordenada X do chunk.
-- @param chunkY (number) A coordenada Y do chunk.
function ProceduralMapManager:generateChunk(chunkX, chunkY)
    local chunkId = chunkX .. "," .. chunkY
    if self.chunks[chunkId] then
        return -- Chunk já foi gerado.
    end

    Logger.debug("ProceduralMapManager.generateChunk", "Gerando chunk: " .. chunkId)

    -- Cria um novo SpriteBatch para este chunk.
    local chunkBatch = love.graphics.newSpriteBatch(self.groundImage, self.chunkSize * self.chunkSize, "static")

    local TILE_WIDTH_HALF = Constants.TILE_WIDTH / 2
    local TILE_HEIGHT_HALF = Constants.TILE_HEIGHT / 2

    for tileY = 0, self.chunkSize - 1 do
        for tileX = 0, self.chunkSize - 1 do
            -- Converte de coordenadas do chunk para coordenadas de tile no mundo.
            local worldTileX = chunkX * self.chunkSize + tileX
            local worldTileY = chunkY * self.chunkSize + tileY

            -- Converte de coordenadas de tile para coordenadas isométricas (pixels).
            local isoX = (worldTileX - worldTileY) * TILE_WIDTH_HALF
            local isoY = (worldTileX + worldTileY) * TILE_HEIGHT_HALF

            -- Adiciona o tile ao SpriteBatch específico do chunk.
            chunkBatch:add(self.groundQuad, isoX, isoY)
        end
    end

    self.chunks[chunkId] = chunkBatch -- Armazena o batch do chunk.
end

--- Descarrega um chunk específico do mapa.
--- @param chunkId string O ID do chunk a ser descarregado (ex: "0,0").
function ProceduralMapManager:unloadChunk(chunkId)
    local chunkBatch = self.chunks[chunkId]
    if chunkBatch then
        Logger.debug("ProceduralMapManager.unloadChunk", "Descarregando chunk: " .. chunkId)
        chunkBatch:release() -- Libera os recursos do SpriteBatch.
        self.chunks[chunkId] = nil
    end
end

-- Atualiza o gerenciador do mapa.
-- Determina quais chunks carregar/descarregar com base na posição do jogador.
--- @param dt number O tempo delta.
--- @param playerPosition { x: number, y: number } A posição do jogador {x, y}.
function ProceduralMapManager:update(dt, playerPosition)
    if not playerPosition then return end

    -- Converte a posição isométrica (pixels) do jogador para coordenadas de tile no mundo.
    local TILE_WIDTH_HALF = Constants.TILE_WIDTH / 2
    local TILE_HEIGHT_HALF = Constants.TILE_HEIGHT / 2
    local worldTileX = (playerPosition.x / TILE_WIDTH_HALF + playerPosition.y / TILE_HEIGHT_HALF) / 2
    local worldTileY = (playerPosition.y / TILE_HEIGHT_HALF - playerPosition.x / TILE_WIDTH_HALF) / 2

    -- Converte as coordenadas de tile do mundo para coordenadas de chunk.
    local playerChunkX = math.floor(worldTileX / self.chunkSize)
    local playerChunkY = math.floor(worldTileY / self.chunkSize)

    -- Define a área de chunks que devem estar ativos.
    local requiredChunks = {}
    for y = playerChunkY - self.viewDistance, playerChunkY + self.viewDistance do
        for x = playerChunkX - self.viewDistance, playerChunkX + self.viewDistance do
            local chunkId = x .. "," .. y
            requiredChunks[chunkId] = true
            -- Gera o chunk se ele ainda não existir.
            self:generateChunk(x, y)
        end
    end

    -- Descarrega os chunks que não são mais necessários.
    local chunksToUnload = {}
    for chunkId, _ in pairs(self.chunks) do
        if not requiredChunks[chunkId] then
            table.insert(chunksToUnload, chunkId)
        end
    end

    for _, chunkId in ipairs(chunksToUnload) do
        self:unloadChunk(chunkId)
    end
end

--- Desenha o mapa procedural gerado.
function ProceduralMapManager:draw()
    -- Para a renderização isométrica correta, os chunks devem ser desenhados
    -- em uma ordem específica (de trás para frente).
    local chunksToDraw = {}
    for chunkId, chunkBatch in pairs(self.chunks) do
        local xStr, yStr = chunkId:match("^(-?%d+),(-?%d+)$")
        if xStr and yStr then
            table.insert(chunksToDraw, {
                x = tonumber(xStr),
                y = tonumber(yStr),
                batch = chunkBatch
            })
        end
    end

    -- A chave de ordenação principal é a soma das coordenadas (x + y). Chunks
    -- com uma soma menor estão mais "atrás" na projeção isométrica e devem ser
    -- desenhados primeiro.
    -- Como critério de desempate, usamos a coordenada y para garantir uma ordem estável.
    table.sort(chunksToDraw, function(a, b)
        local sumA = a.x + a.y
        local sumB = b.x + b.y
        if sumA == sumB then
            return a.y < b.y
        end
        return sumA < sumB
    end)

    -- Desenha os chunks na ordem correta.
    for _, chunkData in ipairs(chunksToDraw) do
        love.graphics.draw(chunkData.batch)

        if DEBUG_SHOW_CHUNK_BOUNDS then
            love.graphics.push()
            local TILE_WIDTH_HALF = Constants.TILE_WIDTH / 2
            local TILE_HEIGHT_HALF = Constants.TILE_HEIGHT / 2

            local chunkX, chunkY = chunkData.x, chunkData.y

            -- Calcula os 4 cantos do chunk em coordenadas de tile do mundo
            local topLeft = { x = chunkX * self.chunkSize, y = chunkY * self.chunkSize }
            local topRight = { x = (chunkX + 1) * self.chunkSize, y = chunkY * self.chunkSize }
            local bottomRight = { x = (chunkX + 1) * self.chunkSize, y = (chunkY + 1) * self.chunkSize }
            local bottomLeft = { x = chunkX * self.chunkSize, y = (chunkY + 1) * self.chunkSize }

            -- Converte os cantos para coordenadas isométricas
            local isoTopLeftX = (topLeft.x - topLeft.y) * TILE_WIDTH_HALF
            local isoTopLeftY = (topLeft.x + topLeft.y) * TILE_HEIGHT_HALF
            local isoTopRightX = (topRight.x - topRight.y) * TILE_WIDTH_HALF
            local isoTopRightY = (topRight.x + topRight.y) * TILE_HEIGHT_HALF
            local isoBottomRightX = (bottomRight.x - bottomRight.y) * TILE_WIDTH_HALF
            local isoBottomRightY = (bottomRight.x + bottomRight.y) * TILE_HEIGHT_HALF
            local isoBottomLeftX = (bottomLeft.x - bottomLeft.y) * TILE_WIDTH_HALF
            local isoBottomLeftY = (bottomLeft.x + bottomLeft.y) * TILE_HEIGHT_HALF

            love.graphics.setColor(1, 1, 0, 0.7) -- Amarelo semi-transparente
            love.graphics.setLineWidth(2)
            love.graphics.polygon('line', isoTopLeftX, isoTopLeftY, isoTopRightX, isoTopRightY, isoBottomRightX,
                isoBottomRightY, isoBottomLeftX, isoBottomLeftY)

            -- Calcula o centro do chunk para o texto
            local centerTileX = chunkX * self.chunkSize + self.chunkSize / 2
            local centerTileY = chunkY * self.chunkSize + self.chunkSize / 2
            local isoCenterX = (centerTileX - centerTileY) * TILE_WIDTH_HALF
            local isoCenterY = (centerTileX + centerTileY) * TILE_HEIGHT_HALF

            love.graphics.setFont(fonts.main)
            love.graphics.printf(chunkData.x .. "," .. chunkData.y, isoCenterX - 50, isoCenterY - 10, 100, 'center')

            love.graphics.pop() -- Restaura cor e outras propriedades gráficas
            love.graphics.setColor(1, 1, 1, 1)
        end
    end
end

--- Libera os recursos utilizados pelo gerenciador.
function ProceduralMapManager:destroy()
    -- Libera todos os SpriteBatches de chunks restantes.
    for chunkId, chunkBatch in pairs(self.chunks) do
        if chunkBatch and chunkBatch.release then
            chunkBatch:release()
        end
    end
    self.chunks = {}
    Logger.info("ProceduralMapManager.destroy", "ProceduralMapManager para o mapa " .. self.mapName .. " destruído.")
end

return ProceduralMapManager
