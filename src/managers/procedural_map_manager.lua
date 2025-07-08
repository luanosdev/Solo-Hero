-- src/managers/procedural_map_manager.lua
-- Gerencia a geração procedural de mapas infinitos baseados em chunks.
-- V2: Sistema otimizado com foco em performance real

local MapManager = require("src.managers.map_manager")
local Constants = require("src.config.constants")
local fonts = require("src.ui.fonts")
local TextureAtlasManager = require("src.managers.texture_atlas_manager")
local TablePool = require("src.utils.table_pool")

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
---@field textureAtlasManager TextureAtlasManager
---@field sessionSeed number
---@field generationQueue table
---@field generatingTask table|nil
---@field workPerFrame number
---@field chunkPool table Pool simples de chunks para reutilização
---@field frameCounter number Contador para operações menos frequentes
local ProceduralMapManager = {}
ProceduralMapManager.__index = ProceduralMapManager

-- Constantes de otimização simplificadas
local WORK_PER_FRAME = 12        -- Mais trabalho por frame para ser eficiente
local POOL_MAX_SIZE = 20         -- Pool pequeno e eficiente
local UNLOAD_CHECK_INTERVAL = 30 -- Verifica unload a cada 30 frames (~0.5s)

--- Cria uma nova instância do ProceduralMapManager.
--- @param mapName string O nome do mapa a ser gerado (ex: "florest").
--- @param assetManager AssetManager A instância do AssetManager para carregar imagens.
--- @return ProceduralMapManager instance Uma nova instância do gerenciador.
function ProceduralMapManager:new(mapName, assetManager)
    local instance = setmetatable({}, ProceduralMapManager)
    instance.mapName = mapName
    instance.assetManager = assetManager -- Mantido para o chão e outros possíveis assets.
    Logger.info("ProceduralMapManager.new", "Criando ProceduralMapManager otimizado para o mapa: " .. mapName)

    -- Carrega os dados de configuração do mapa.
    instance.mapData = MapManager:loadMap(mapName)

    -- Configurações do mapa procedural otimizadas
    instance.chunks = {}
    instance.chunkSize = 24   -- Mantém compatibilidade com sistema isométrico existente
    instance.viewDistance = 1 -- Volta para o valor original eficiente
    instance.sessionSeed = love.math.random(1, 1000000)

    -- Sistema assíncrono simplificado
    instance.generationQueue = {}
    instance.generatingTask = nil
    instance.workPerFrame = WORK_PER_FRAME

    -- Pool simples de chunks
    instance.chunkPool = {}

    -- Contador para operações menos frequentes
    instance.frameCounter = 0

    -- Parâmetros de vento.
    instance.windStrength = 1.2
    instance.windSpeed = 1.2

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

--- Pool simples e eficiente para chunks
---@return table
function ProceduralMapManager:_getChunkFromPool()
    if #self.chunkPool > 0 then
        local chunk = table.remove(self.chunkPool)
        return chunk
    else
        return {}
    end
end

---@param chunk table
function ProceduralMapManager:_returnChunkToPool(chunk)
    if #self.chunkPool < POOL_MAX_SIZE then
        -- Limpa SpriteBatch se existir
        if chunk.ground and type(chunk.ground.release) == "function" then
            if type(chunk.ground.isReleased) == "function" then
                if not chunk.ground:isReleased() then
                    chunk.ground:release()
                end
            else
                chunk.ground:release()
            end
        end

        -- Limpa chunk para reutilização
        chunk.ground = nil
        chunk.decorations = nil

        table.insert(self.chunkPool, chunk)
    end
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

    Logger.info("ProceduralMapManager.start", "Renderizador otimizado do ProceduralMapManager inicializado.")
end

--- Verifica se um chunk está na fila de geração ou sendo gerado (versão eficiente).
--- @param chunkX number
--- @param chunkY number
--- @return boolean
function ProceduralMapManager:_isChunkInQueueOrGenerating(chunkX, chunkY)
    -- Verifica tarefa ativa (mais provável)
    if self.generatingTask then
        local task = self.generatingTask
        if task.x == chunkX and task.y == chunkY then
            return true
        end
    end

    -- Verifica fila (menos provável, fila pequena)
    for i = 1, #self.generationQueue do
        local task = self.generationQueue[i]
        if task.x == chunkX and task.y == chunkY then
            return true
        end
    end

    return false
end

--- Cria uma corotina otimizada para gerar um chunk de forma assíncrona.
function ProceduralMapManager:_createChunkGenerator(chunkX, chunkY)
    return coroutine.create(function()
        local chunk = self:_getChunkFromPool()

        local groundBatch = love.graphics.newSpriteBatch(self.groundImage, self.chunkSize * self.chunkSize, "static")
        local decorationsByTile = {}
        local TILE_WIDTH_HALF = Constants.TILE_WIDTH / 2
        local TILE_HEIGHT_HALF = Constants.TILE_HEIGHT / 2
        local rng = love.math.newRandomGenerator()

        -- Yield counter otimizado
        local yieldCounter = 0

        for tileY = 0, self.chunkSize - 1 do
            decorationsByTile[tileY] = {}
            for tileX = 0, self.chunkSize - 1 do
                decorationsByTile[tileY][tileX] = {}
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
                            table.insert(decorationsByTile[tileY][tileX], {
                                path = variant.path,
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

                -- Yield otimizado
                yieldCounter = yieldCounter + 1
                if yieldCounter >= self.workPerFrame then
                    yieldCounter = 0
                    coroutine.yield()
                end
            end
        end

        chunk.ground = groundBatch
        chunk.decorations = decorationsByTile

        -- Armazena no chunks table diretamente
        if not self.chunks[chunkY] then
            self.chunks[chunkY] = {}
        end
        self.chunks[chunkY][chunkX] = chunk

        Logger.debug("ProceduralMapManager._createChunkGenerator", "Chunk gerado: " .. chunkX .. "," .. chunkY)
    end)
end

--- Processa a fila de geração de chunks de forma eficiente.
function ProceduralMapManager:_processGenerationQueue()
    -- Se há um chunk sendo gerado, continua sua execução.
    if self.generatingTask then
        local co = self.generatingTask.coroutine
        local status, err = coroutine.resume(co)
        if not status then
            Logger.error("ProceduralMapManager._processGenerationQueue", "Erro na corotina: " .. tostring(err))
            self.generatingTask = nil -- Aborta em caso de erro.
        elseif coroutine.status(co) == 'dead' then
            self.generatingTask = nil -- Limpa a tarefa quando concluída.
        end
    end

    -- Se não há tarefa ativa e a fila tem itens, inicia a próxima.
    if not self.generatingTask and #self.generationQueue > 0 then
        local taskData = table.remove(self.generationQueue, 1)
        Logger.debug("ProceduralMapManager._processGenerationQueue",
            "Iniciando geração de chunk: " .. taskData.x .. "," .. taskData.y)
        local co = self:_createChunkGenerator(taskData.x, taskData.y)
        self.generatingTask = {
            x = taskData.x,
            y = taskData.y,
            coroutine = co
        }
    end
end

--- Atualiza o gerenciador do mapa de forma eficiente.
-- Determina quais chunks carregar/descarregar com base na posição do jogador.
--- @param dt number O tempo delta.
--- @param playerPosition { x: number, y: number } A posição do jogador {x, y}.
function ProceduralMapManager:update(dt, playerPosition)
    if not playerPosition then return end

    -- Incrementa contador de frames
    self.frameCounter = self.frameCounter + 1

    -- Converte a posição isométrica (pixels) do jogador para coordenadas de tile no mundo.
    local TILE_WIDTH_HALF = Constants.TILE_WIDTH / 2
    local TILE_HEIGHT_HALF = Constants.TILE_HEIGHT / 2
    local worldTileX = (playerPosition.x / TILE_WIDTH_HALF + playerPosition.y / TILE_HEIGHT_HALF) / 2
    local worldTileY = (playerPosition.y / TILE_HEIGHT_HALF - playerPosition.x / TILE_WIDTH_HALF) / 2

    -- Converte as coordenadas de tile do mundo para coordenadas de chunk.
    local playerChunkX = math.floor(worldTileX / self.chunkSize)
    local playerChunkY = math.floor(worldTileY / self.chunkSize)

    -- Define a área de chunks que devem estar ativos.
    local requiredChunks = TablePool.get()
    for y = playerChunkY - self.viewDistance, playerChunkY + self.viewDistance do
        for x = playerChunkX - self.viewDistance, playerChunkX + self.viewDistance do
            requiredChunks[x .. "," .. y] = true
            -- Adiciona o chunk à fila de geração se ele não existir e não estiver sendo processado.
            local chunkExists = self.chunks[y] and self.chunks[y][x]
            if not chunkExists and not self:_isChunkInQueueOrGenerating(x, y) then
                -- Adiciona no início da fila para priorizar os mais próximos.
                table.insert(self.generationQueue, 1, { x = x, y = y })
            end
        end
    end

    -- Descarrega os chunks que não são mais necessários (menos frequente).
    if self.frameCounter % UNLOAD_CHECK_INTERVAL == 0 then
        local chunksToUnload = TablePool.get()
        for y, row in pairs(self.chunks) do
            for x, chunk in pairs(row) do
                local chunkId = x .. "," .. y
                if not requiredChunks[chunkId] then
                    table.insert(chunksToUnload, { x = x, y = y })
                end
            end
        end

        for _, pos in ipairs(chunksToUnload) do
            if self.chunks[pos.y] and self.chunks[pos.y][pos.x] then
                self:_returnChunkToPool(self.chunks[pos.y][pos.x])
                self.chunks[pos.y][pos.x] = nil
                if next(self.chunks[pos.y]) == nil then
                    self.chunks[pos.y] = nil -- Limpa a linha se estiver vazia.
                end
            end
        end
        TablePool.release(chunksToUnload)
    end

    TablePool.release(requiredChunks)

    -- Processa a geração de chunks pendentes.
    self:_processGenerationQueue()
end

--- Retorna a lista de chunks visíveis, ordenados para renderização isométrica.
--- @return table
function ProceduralMapManager:_getVisibleChunksSorted()
    local chunksToDraw = TablePool.get()
    for y, row in pairs(self.chunks) do
        for x, chunk in pairs(row) do
            if chunk then -- Garante que o chunk existe antes de adicioná-lo.
                table.insert(chunksToDraw, {
                    x = x,
                    y = y,
                    chunk = chunk
                })
            end
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
        if chunkData.chunk.ground then
            love.graphics.draw(chunkData.chunk.ground)
        end
    end

    -- 2. Desenha as decorações se houver um batch.
    if self.decorationBatch then
        -- A iteração sobre os chunks (já ordenados) e sobre os tiles na ordem
        -- correta (de trás para frente) garante a perspectiva isométrica sem
        -- a necessidade de ordenar a lista de todas as decorações.
        self.decorationBatch:clear()
        local time = love.timer.getTime()

        for _, chunkData in ipairs(chunksToDraw) do
            local decorationsByTile = chunkData.chunk.decorations
            if decorationsByTile then
                -- Itera sobre a grade de tiles na ordem de renderização correta (Y, depois X).
                for tileY = 0, self.chunkSize - 1 do
                    if decorationsByTile[tileY] then
                        for tileX = 0, self.chunkSize - 1 do
                            if decorationsByTile[tileY][tileX] then
                                for _, deco in ipairs(decorationsByTile[tileY][tileX]) do
                                    local quad = self.decorationAtlas.quads[deco.path]
                                    if quad then
                                        local x, y = deco.x, deco.y
                                        if deco.affectedByWind then
                                            local posOffset = (x + y) * 0.01
                                            local windEffect = math.sin(time * self.windSpeed + posOffset) *
                                                self.windStrength
                                            x = x + windEffect
                                        end

                                        -- Calcula o pivô em pixels a partir do quad.
                                        local quadW, quadH = quad:getViewport()
                                        local pivotX = quadW * deco.pivot_x
                                        local pivotY = quadH * deco.pivot_y

                                        self.decorationBatch:add(quad, x, y, 0, 1, 1, pivotX, pivotY)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        -- Desenha o batch inteiro de uma só vez.
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.decorationBatch)
    end

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

    TablePool.release(chunksToDraw)
end

--- Obtém informações básicas de performance
---@return table
function ProceduralMapManager:getPerformanceInfo()
    local chunksLoaded = 0
    for y, row in pairs(self.chunks) do
        for x, chunk in pairs(row) do
            if chunk then
                chunksLoaded = chunksLoaded + 1
            end
        end
    end

    return {
        chunks = {
            loaded = chunksLoaded,
            inQueue = #self.generationQueue,
        },
        pools = {
            chunks = #self.chunkPool,
        },
        optimizations = {
            "Object pooling simples para chunks",
            "Verificação de unload menos frequente (cada 0.5s)",
            "Geração assíncrona eficiente",
            "Eliminação de overhead de cache LRU",
            "Foco em performance real ao invés de complexidade"
        }
    }
end

--- Libera os recursos utilizados pelo gerenciador de forma eficiente.
function ProceduralMapManager:destroy()
    Logger.info("ProceduralMapManager.destroy", "Iniciando destruição do ProceduralMapManager...")

    -- Para geração ativa
    self.generatingTask = nil
    self.generationQueue = {}

    -- Libera chunks e pool
    for y, row in pairs(self.chunks) do
        for x, chunk in pairs(row) do
            if chunk then
                self:_returnChunkToPool(chunk)
            end
        end
    end
    self.chunks = {}

    -- Limpa pool
    for _, chunk in ipairs(self.chunkPool) do
        if chunk.ground and type(chunk.ground.release) == "function" then
            if type(chunk.ground.isReleased) == "function" then
                if not chunk.ground:isReleased() then
                    chunk.ground:release()
                end
            else
                chunk.ground:release()
            end
        end
    end
    self.chunkPool = {}

    -- Libera os recursos do atlas de decoração.
    if self.decorationBatch then
        if type(self.decorationBatch.release) == "function" then
            -- Verifica se o SpriteBatch já foi liberado
            if type(self.decorationBatch.isReleased) == "function" then
                if self.decorationBatch:isReleased() == false then
                    self.decorationBatch:release()
                end
            else
                -- Se isReleased não existe, apenas libera
                self.decorationBatch:release()
            end
        end
    end

    -- Verifica se o decorationAtlas e seu canvas existem antes de tentar liberar
    if self.decorationAtlas and self.decorationAtlas.canvas then
        -- Verifica se o método isReleased existe e se o canvas não foi liberado
        if type(self.decorationAtlas.canvas.isReleased) == "function" then
            if self.decorationAtlas.canvas:isReleased() == false then
                self.decorationAtlas.canvas:release()
            end
        elseif type(self.decorationAtlas.canvas.release) == "function" then
            -- Se isReleased não existe, mas release existe, apenas libera
            self.decorationAtlas.canvas:release()
        end
    end

    -- Limpa referências restantes
    self.decorationBatch = nil
    self.decorationAtlas = nil

    Logger.info("procedural_map_manager.destroy.finalized",
        "[ProceduralMapManager:destroy] ProceduralMapManager otimizado para o mapa " .. self.mapName .. " destruído.")
end

return ProceduralMapManager
