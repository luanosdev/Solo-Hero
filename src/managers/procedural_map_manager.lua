-- src/managers/procedural_map_manager.lua
-- Gerencia a geração procedural de mapas infinitos baseados em chunks.

local MapManager = require("src.managers.map_manager")
local Constants = require("src.config.constants")
local fonts = require("src.ui.fonts")
local TextureAtlasManager = require("src.managers.texture_atlas_manager")

---@class ProceduralMapManager
---@field mapName string
---@field assetManager AssetManager
---@field mapData table
---@field chunks table
---@field chunkSize number
---@field viewDistance number
---@field groundImage love.Image
---@field groundQuad love.Quad
---@field decorationData table
---@field windStrength number
---@field windSpeed number
---@field decorationAtlas table
---@field decorationBatch love.SpriteBatch
local ProceduralMapManager = {}
ProceduralMapManager.__index = ProceduralMapManager

--- Cria uma nova instância do ProceduralMapManager.
--- @param mapName string O nome do mapa a ser gerado (ex: "florest").
--- @param assetManager AssetManager A instância do AssetManager para carregar imagens.
--- @return ProceduralMapManager instance Uma nova instância do gerenciador.
function ProceduralMapManager:new(mapName, assetManager)
    local instance = setmetatable({}, ProceduralMapManager)
    instance.mapName = mapName
    instance.assetManager = assetManager -- Mantido para o chão e outros possíveis assets.
    Logger.info("ProceduralMapManager.new", "Criando ProceduralMapManager para o mapa: " .. mapName)

    -- Carrega os dados de configuração do mapa.
    instance.mapData = MapManager:loadMap(mapName)

    -- Configurações do mapa procedural.
    instance.chunks = {}
    instance.chunkSize = 16
    instance.viewDistance = 1
    instance.sessionSeed = love.math.random(1, 1000000)

    -- Parâmetros de vento.
    instance.windStrength = 2
    instance.windSpeed = 1.5

    -- Recursos de renderização.
    instance.groundImage = nil
    instance.groundQuad = nil
    instance.decorationData = {}
    instance.decorationAtlas = nil
    instance.decorationBatch = nil

    -- O TextureAtlasManager agora é instanciado aqui.
    instance.textureAtlasManager = TextureAtlasManager:new()

    instance:_initializeRenderer()

    return instance
end

--- Inicializa os recursos de renderização para o mapa.
function ProceduralMapManager:_initializeRenderer()
    -- Carrega o chão (sem mudanças).
    local groundTilePath = self.mapData and self.mapData.ground and self.mapData.ground.tile
    if not groundTilePath then
        error("ProceduralMapManager: Caminho do tile de chão não definido para o mapa " .. self.mapName)
    end
    self.groundImage = self.assetManager:getImage(groundTilePath)
    if not self.groundImage then
        error("ProceduralMapManager: Falha ao carregar imagem do tile: " .. groundTilePath)
    end
    local w, h = self.groundImage:getDimensions()
    self.groundQuad = love.graphics.newQuad(0, 0, w, h, w, h)

    -- Gera o Atlas de Texturas para as decorações.
    self.decorationAtlas = self.textureAtlasManager:createAtlasForDecorations(self.mapData)

    -- Se o atlas foi criado, cria o SpriteBatch para ele.
    if self.decorationAtlas then
        self.decorationBatch = love.graphics.newSpriteBatch(self.decorationAtlas.canvas, 2048, "stream")
    end

    -- Carrega a estrutura das layers de decoração (sem carregar as imagens).
    if self.mapData.decorations and self.mapData.decorations.layers then
        self.decorationData = self.mapData.decorations.layers
    end

    Logger.info("ProceduralMapManager.start", "Renderizador do ProceduralMapManager inicializado.")
end

--- Gera um chunk específico do mapa.
function ProceduralMapManager:generateChunk(chunkX, chunkY)
    local chunkId = chunkX .. "," .. chunkY
    if self.chunks[chunkId] then
        return
    end

    Logger.debug("ProceduralMapManager.generateChunk", "Gerando chunk: " .. chunkId)

    local groundBatch = love.graphics.newSpriteBatch(self.groundImage, self.chunkSize * self.chunkSize, "static")
    local decorations = {}

    local TILE_WIDTH_HALF = Constants.TILE_WIDTH / 2
    local TILE_HEIGHT_HALF = Constants.TILE_HEIGHT / 2

    local rng = love.math.newRandomGenerator()

    for tileY = 0, self.chunkSize - 1 do
        for tileX = 0, self.chunkSize - 1 do
            local worldTileX = chunkX * self.chunkSize + tileX
            local worldTileY = chunkY * self.chunkSize + tileY

            local isoX = (worldTileX - worldTileY) * TILE_WIDTH_HALF
            local isoY = (worldTileX + worldTileY) * TILE_HEIGHT_HALF

            groundBatch:add(self.groundQuad, isoX, isoY)

            local noiseOffset = 0
            for layerIndex, layerData in ipairs(self.decorationData) do
                local shouldPlace = false
                local placementSeed = self.sessionSeed + noiseOffset
                rng:setSeed(placementSeed + worldTileX * 13 + worldTileY * 31)
                local randomValue = rng:random()

                if layerData.placement == "clustered" then
                    local clusterNoiseX = worldTileX / layerData.cluster_scale
                    local clusterNoiseY = worldTileY / layerData.cluster_scale
                    local clusterNoiseVal = (love.math.noise(clusterNoiseX, clusterNoiseY, placementSeed) + 1) / 2
                    if clusterNoiseVal > layerData.cluster_threshold then
                        if randomValue < layerData.cluster_density then
                            shouldPlace = true
                        end
                    end
                else
                    if randomValue < layerData.density then
                        shouldPlace = true
                    end
                end

                if shouldPlace and layerData.types and #layerData.types > 0 then
                    local typeIndex = rng:random(#layerData.types)
                    local decoType = layerData.types[typeIndex]

                    if decoType.variants and #decoType.variants > 0 then
                        local variantIndex = rng:random(#decoType.variants)
                        local variant = decoType.variants[variantIndex]

                        table.insert(decorations, {
                            path = variant.path, -- Armazena apenas o path.
                            pivot_x = variant.pivot_x or 0.5,
                            pivot_y = variant.pivot_y or 1,
                            affectedByWind = decoType.affectedByWind,
                            x = isoX + TILE_WIDTH_HALF,
                            y = isoY + TILE_HEIGHT_HALF
                        })
                    end
                end
                noiseOffset = noiseOffset + 100
            end
        end
    end

    self.chunks[chunkId] = {
        ground = groundBatch,
        decorations = decorations
    }
end

--- Descarrega um chunk específico do mapa.
--- @param chunkId string O ID do chunk a ser descarregado (ex: "0,0").
function ProceduralMapManager:unloadChunk(chunkId)
    local chunk = self.chunks[chunkId]
    if chunk then
        Logger.debug("ProceduralMapManager.unloadChunk", "Descarregando chunk: " .. chunkId)
        if chunk.ground and chunk.ground.release then
            chunk.ground:release() -- Libera os recursos do SpriteBatch do chão.
        end
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

--- Retorna a lista de chunks visíveis, ordenados para renderização isométrica.
--- @return table
function ProceduralMapManager:_getVisibleChunksSorted()
    local chunksToDraw = {}
    for chunkId, chunk in pairs(self.chunks) do
        local xStr, yStr = chunkId:match("^(-?%d+),(-?%d+)$")
        if xStr and yStr then
            table.insert(chunksToDraw, {
                x = tonumber(xStr),
                y = tonumber(yStr),
                chunk = chunk
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

    return chunksToDraw
end

--- Desenha o mapa procedural gerado.
function ProceduralMapManager:draw()
    -- 1. Desenha o chão.
    local chunksToDraw = self:_getVisibleChunksSorted()
    for _, chunkData in ipairs(chunksToDraw) do
        love.graphics.draw(chunkData.chunk.ground)
    end

    -- Se não houver atlas/batch, não há o que desenhar.
    if not self.decorationBatch then return end

    -- 2. Renderização ultra-otimizada das decorações usando o atlas.
    self.decorationBatch:clear()
    local time = love.timer.getTime()

    -- 2.1 Coleta todas as decorações visíveis.
    local allDecorations = {}
    for _, chunkData in ipairs(chunksToDraw) do
        for _, deco in ipairs(chunkData.chunk.decorations) do
            table.insert(allDecorations, deco)
        end
    end

    -- 2.2 Ordena pela posição Y para a perspectiva isométrica.
    table.sort(allDecorations, function(a, b) return a.y < b.y end)

    -- 2.3 Adiciona as decorações ordenadas ao batch.
    for _, deco in ipairs(allDecorations) do
        local quad = self.decorationAtlas.quads[deco.path]
        if quad then
            local x, y = deco.x, deco.y
            if deco.affectedByWind then
                local posOffset = (x + y) * 0.01
                local windEffect = math.sin(time * self.windSpeed + posOffset) * self.windStrength
                x = x + windEffect
            end

            -- Calcula o pivô em pixels a partir do quad.
            local quadW, quadH = quad:getViewport()
            local pivotX = quadW * deco.pivot_x
            local pivotY = quadH * deco.pivot_y

            self.decorationBatch:add(quad, x, y, 0, 1, 1, pivotX, pivotY)
        end
    end

    -- 2.4 Desenha o batch inteiro de uma só vez.
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.decorationBatch)

    -- Desenha as bordas de debug por cima de tudo, se ativado.
    if DEBUG_SHOW_CHUNK_BOUNDS then
        for _, chunkData in ipairs(chunksToDraw) do
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
    -- Libera os recursos do chão.
    for _, chunk in pairs(self.chunks) do
        if chunk.ground and chunk.ground.release then
            chunk.ground:release()
        end
    end
    self.chunks = {}

    -- Libera os recursos do atlas de decoração.
    if self.decorationBatch and self.decorationBatch.release then
        self.decorationBatch:release()
    end
    if self.decorationAtlas and self.decorationAtlas.canvas and self.decorationAtlas.canvas:isReleased() == false then
        self.decorationAtlas.canvas:release()
    end

    Logger.info("ProceduralMapManager.destroy", "ProceduralMapManager para o mapa " .. self.mapName .. " destruído.")
end

return ProceduralMapManager
