local ResolutionUtils = require("src.utils.resolution_utils")

---@class GlobalPosition
---@field patchX integer O índice do "setor" do mundo no eixo X
---@field patchY integer O índice do "setor" do mundo no eixo Y
---@field localX number A posição X DENTRO do patch atual (em metros)
---@field localY number A posição Y DENTRO do patch atual (em metros)

---@class InfinityWrapMapManager2
---@description Gerencia um mapa isométrico infinito, sua renderização e eventos de "wrap".
--- Carrega os dados de um mapa Tiled, pré-renderiza suas camadas em canvases para
--- performance e emite eventos quando o jogador atravessa as bordas dos patches.
---@field context GameplaySceneContext
---@field mapData table Os dados brutos do mapa Tiled.
---@field mapName string O nome do arquivo do mapa a ser carregado (ex: "jungle").
---@field tiles table<number, love.Image> Tabela de imagens de tile individuais.
---@field layerCanvases table<string, love.Canvas> Canvases pré-renderizados para cada camada.
---@field canvasRenderData table Dados sobre a renderização do canvas.
---@field isLoading boolean True se o mapa estiver em processo de construção.
---@field loadingProgress number Progresso do carregamento (0 a 1).
---@field buildCoroutine thread A corrotina usada para construção assíncrona.
---@field tileWidth number
---@field tileHeight number
---@field patchSize number
---@field tilesPerPatch number
local InfinityWrapMapManager = {}
InfinityWrapMapManager.__index = InfinityWrapMapManager

InfinityWrapMapManager.TILES_PER_YIELD = 100

---@public Cria uma nova instância do InfinityWrapMapManager.
---@param context GameplaySceneContext
---@return InfinityWrapMapManager2
function InfinityWrapMapManager:new(context)
    assert(context, "[InfinityWrapMapManager] missing a GameplayContext")
    assert(context.args, "[InfinityWrapMapManager] missing a GameplaySceneArgs")
    assert(context.args.preloadedAssets, "[InfinityWrapMapManager] missing a MapAssets")

    local instance = setmetatable({}, InfinityWrapMapManager)

    instance.context = context

    instance.mapData = nil
    instance.tileWidth = 0
    instance.tileHeight = 0
    instance.patchSize = 0
    instance.tilesPerPatch = 0
    instance.tiles = {}

    return instance
end

---@public Inicializa o manager após a construção (chamado pelo bootstrap).
function InfinityWrapMapManager:init()
    self.mapData = self.context.args.preloadedAssets.map.mapData

    self.tileWidth = self.mapData.tilewidth
    self.tileHeight = self.mapData.tileheight
    self.patchSize = self.mapData.width / self.mapData.properties.grid_width
    self.tilesPerPatch = self.mapData.properties.grid_width
    self.tiles = self.context.args.preloadedAssets.map.tiles

    self:_initializeCanvasSystem()

    -- Inicia o processo de construção assíncrona dos canvases
    --- TODO: Verificar se é necessário, e furutamente teremos uma cena de entrada no mapa
    --- seria o tempo de construir os canvases
    self.isLoading = true
    self.buildCoroutine = coroutine.create(function()
        self:_buildCanvasesAsyncTask(true)
    end)
end

---@public Atualiza o estado do mapa, principalmente o processo de carregamento.
---@param dt number Delta time.
function InfinityWrapMapManager:update(dt)
    if self.isLoading then
        -- Continua o processo de construção dos canvases
        local status, err = coroutine.resume(self.buildCoroutine)
        if not status then
            Logger.error("infinity_wrap_map_manager.update.coroutine_error",
                "Erro na corrotina de construção do mapa: " .. tostring(err))
            self.isLoading = false
        end
        if coroutine.status(self.buildCoroutine) == "dead" then
            if self.isLoading then -- Executa apenas uma vez
                self.isLoading = false
                Logger.info("infinity_wrap_map_manager.update.complete", "Construção dos canvases do mapa concluída!")
                -- Força uma reconstrução final síncrona para garantir o estado.
                self:_updateAllCanvases(true)
            end
        end
    else
        self:_checkPlayerPatch()
    end
end

---@private Verifica se o jogador mudou de patch e dispara a atualização do canvas.
function InfinityWrapMapManager:_checkPlayerPatch()
    local playerManager = self.context.registry:getPlayerManager()

    local worldPosition = playerManager.movementController:getPosition()
    local currentTilePos = self:isometricToCartesianTile(worldPosition.x, worldPosition.y)
    local currentPatchX = math.floor(currentTilePos.x / self.tilesPerPatch)
    local currentPatchY = math.floor(currentTilePos.y / self.tilesPerPatch)

    local renderData = self.canvasRenderData
    if currentPatchX ~= renderData.lastRenderedPatchX or currentPatchY ~= renderData.lastRenderedPatchY then
        Logger.debug(
            "infinity_wrap_map_manager.update.player_wrapped",
            string.format("[InfinityWrapMapManager:update] Player wrapped from (%d, %d) to (%d, %d)",
                renderData.lastRenderedPatchX, renderData.lastRenderedPatchY, currentPatchX, currentPatchY
            )
        )

        -- Força o redesenho dos canvases
        self:_updateAllCanvases(true)

        local eventService = self.context.serviceLocator.getEventService()
        eventService:emit(eventService.EVENTS.PLAYER_WRAPPED)
    end
end

---@public Desenha as camadas inferiores do mapa (abaixo das entidades).
function InfinityWrapMapManager:drawBottomLayers()
    if self.isLoading then return end

    local canvasDrawX, canvasDrawY = self:_getCanvasDrawPosition()

    if self.layerCanvases["ground"] then
        love.graphics.draw(self.layerCanvases["ground"], canvasDrawX, canvasDrawY)
    end
    if self.layerCanvases["ground_decoration"] then
        love.graphics.draw(self.layerCanvases["ground_decoration"], canvasDrawX, canvasDrawY)
    end
end

---@public Desenha as camadas superiores do mapa (acima das entidades).
function InfinityWrapMapManager:drawTopLayers()
    if self.isLoading then return end

    local canvasDrawX, canvasDrawY = self:_getCanvasDrawPosition()

    if self.layerCanvases["decoration"] then
        love.graphics.draw(self.layerCanvases["decoration"], canvasDrawX, canvasDrawY)
    end
end

---@private Inicializa o sistema de canvas
function InfinityWrapMapManager:_initializeCanvasSystem()
    self.layerCanvases = {}
    self.canvasRenderData = {
        renderGridDiameter = 3,
        lastRenderedPatchX = -1,
        lastRenderedPatchY = -1
    }

    local canvasWidth, canvasHeight = self:_calculateCanvasDimensions()

    -- Cria um canvas para cada camada de tiles visível
    for _, layer in ipairs(self.mapData.layers) do
        if layer.type == "tilelayer" and layer.visible then
            -- Usamos pcall para o caso de o canvas ser grande demais para a GPU
            local ok, canvas = pcall(love.graphics.newCanvas, canvasWidth, canvasHeight)
            if ok then
                canvas:setFilter("nearest", "nearest")
                self.layerCanvases[layer.name] = canvas
                Logger.info(
                    "infinity_wrap_map_manager.canvas.success." .. layer.name,
                    string.format("Canvas de %dx%d criado para a camada '%s'.", canvasWidth, canvasHeight, layer.name)
                )
            else
                Logger.error(
                    "infinity_wrap_map_manager.canvas.fail." .. layer.name,
                    string.format("ERRO: Falha ao criar canvas de %dx%d para a camada '%s'.", canvasWidth, canvasHeight,
                        layer.name)
                )
            end
        end
    end
end

---@private Calcula as dimensões do canvas
---@return number canvasWidth, number canvasHeight
function InfinityWrapMapManager:_calculateCanvasDimensions()
    local renderData = self.canvasRenderData
    local gridSizeInTiles = renderData.renderGridDiameter * self.tilesPerPatch

    -- Pega a maior dimensão de tile
    local maxTileW, maxTileH = self:_getMaximumTileDimensions()
    local N = gridSizeInTiles

    -- A largura total do losango isométrico é (N-1)*tileWidth. Adicionamos maxTileW como margem.
    local canvasWidth = (N - 1) * self.tileWidth + maxTileW
    -- A altura total é (N-1)*tileHeight. Adicionamos maxTileH como margem.
    local canvasHeight = (N - 1) * self.tileHeight + maxTileH

    renderData.width = canvasWidth
    renderData.height = canvasHeight

    -- O offset X deve transladar a coordenada X mais negativa para zero.
    -- isoX_min é -(N-1)*tileWidth/2. O tile se estende por maxTileW/2 para a esquerda.
    renderData.offsetX = (N - 1) * self.tileWidth / 2 + (maxTileW / 2)
    -- O offset Y deve transladar a coordenada Y mais alta para zero.
    -- isoY_min é 0. O tile se estende para cima por (maxTileH - tileHeight/2).
    renderData.offsetY = maxTileH - (self.tileHeight / 2)

    return canvasWidth, canvasHeight
end

---@private Percorre todos os tiles para encontrar a maior dimensão de tile.
---@return number maxWidth, number maxHeight
function InfinityWrapMapManager:_getMaximumTileDimensions()
    local maxW, maxH = 0, 0
    if not self.tiles or not next(self.tiles) then return self.tileWidth, self.tileHeight * 2 end -- Fallback
    for _, img in pairs(self.tiles) do
        local w, h = img:getDimensions()
        if w > maxW then maxW = w end
        if h > maxH then maxH = h end
    end
    return maxW, maxH
end

---@private Verifica se os canvases precisam ser redesenhados e o faz de forma bloqueante.
---@param force boolean
function InfinityWrapMapManager:_updateAllCanvases(force)
    if force then
        self:_buildCanvasesAsyncTask(false) -- Executa a tarefa de forma bloqueante
    end
end

---@private Tarefa que constrói os canvases.
---@param isAsyncTask boolean Se deve pausar (yield) durante a execução.
function InfinityWrapMapManager:_buildCanvasesAsyncTask(isAsyncTask)
    local renderData = self.canvasRenderData

    -- Posição do jogador precisa ser obtida para centralizar a construção.
    local playerManager = self.context.registry:getPlayerManager()
    local worldPosition = playerManager.movementController:getPosition()

    local currentTilePos = self:isometricToCartesianTile(worldPosition.x, worldPosition.y)
    local currentPatchX = math.floor(currentTilePos.x / self.tilesPerPatch)
    local currentPatchY = math.floor(currentTilePos.y / self.tilesPerPatch)

    -- Atualiza qual patch está sendo renderizado
    renderData.lastRenderedPatchX = currentPatchX
    renderData.lastRenderedPatchY = currentPatchY

    for name, canvas in pairs(self.layerCanvases) do
        self:_renderLayerToCanvas(name, canvas, isAsyncTask)
        if isAsyncTask then coroutine.yield() end
    end
end

---@private Desenha uma camada de mapa usando love.graphics.draw individual.
---@param layerName string
---@param canvas love.Canvas
---@param isAsyncTask boolean
function InfinityWrapMapManager:_renderLayerToCanvas(layerName, canvas, isAsyncTask)
    local layer
    for _, l in ipairs(self.mapData.layers) do
        if l.name == layerName then
            layer = l
            break
        end
    end
    if not layer then return end

    local renderData = self.canvasRenderData
    local centerPatchX = renderData.lastRenderedPatchX
    local centerPatchY = renderData.lastRenderedPatchY
    local renderRadius = math.floor(renderData.renderGridDiameter / 2)

    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)

    local mapTotalWidth = self.mapData.width

    local gridOriginTileX = (centerPatchX - renderRadius) * self.tilesPerPatch
    local gridOriginTileY = (centerPatchY - renderRadius) * self.tilesPerPatch

    local tilesDrawnInFrame = 0

    for py = centerPatchY - renderRadius, centerPatchY + renderRadius do
        for px = centerPatchX - renderRadius, centerPatchX + renderRadius do
            local sourcePatchX = ((px % self.patchSize) + self.patchSize) % self.patchSize
            local sourcePatchY = ((py % self.patchSize) + self.patchSize) % self.patchSize

            local sourceTileStartX = sourcePatchX * self.tilesPerPatch
            local sourceTileStartY = sourcePatchY * self.tilesPerPatch

            for y = 0, self.tilesPerPatch - 1 do
                for x = 0, self.tilesPerPatch - 1 do
                    local sourceMapX = sourceTileStartX + x
                    local sourceMapY = sourceTileStartY + y
                    local index = sourceMapY * mapTotalWidth + sourceMapX + 1
                    local gid = layer.data[index]

                    if gid and gid > 0 and self.tiles[gid] then
                        local tileImage = self.tiles[gid]
                        local quadW, quadH = tileImage:getDimensions()

                        local destTileX = (px * self.tilesPerPatch + x) - gridOriginTileX
                        local destTileY = (py * self.tilesPerPatch + y) - gridOriginTileY

                        local iso = self:cartesianToIsometric(destTileX, destTileY)
                        local screenX = iso.x + renderData.offsetX
                        local screenY = iso.y + renderData.offsetY

                        local ox = quadW / 2
                        local oy = quadH - self.tileHeight / 2

                        love.graphics.draw(tileImage, math.floor(screenX), math.floor(screenY), 0, 1, 1, ox, oy)

                        tilesDrawnInFrame = tilesDrawnInFrame + 1

                        if isAsyncTask and tilesDrawnInFrame >= InfinityWrapMapManager.TILES_PER_YIELD then
                            coroutine.yield()
                            tilesDrawnInFrame = 0
                        end
                    end
                end
            end
        end
    end

    love.graphics.setCanvas()
end

---@private Calcula a posição do canvas para desenhar em coordenadas de mundo.
---@return number canvasDrawX, number canvasDrawY
function InfinityWrapMapManager:_getCanvasDrawPosition()
    local renderData = self.canvasRenderData

    -- Ponto de origem (tile 0,0) do grid que foi renderizado no canvas
    local renderRadius = math.floor(renderData.renderGridDiameter / 2)
    local gridOriginTileX = (renderData.lastRenderedPatchX - renderRadius) * self.tilesPerPatch
    local gridOriginTileY = (renderData.lastRenderedPatchY - renderRadius) * self.tilesPerPatch

    -- Converte a origem do grid para coordenadas isométricas (coordenadas de mundo)
    local gridOriginIso = self:cartesianToIsometric(gridOriginTileX, gridOriginTileY)

    -- O canvas deve ser desenhado na posição da origem do grid, ajustado pelos offsets de renderização
    local canvasDrawX = gridOriginIso.x - renderData.offsetX
    local canvasDrawY = gridOriginIso.y - renderData.offsetY

    return canvasDrawX, canvasDrawY
end

--- Converte coordenadas cartesianas para isométricas.
---@param x number
---@param y number
---@return Vector2D
function InfinityWrapMapManager:cartesianToIsometric(x, y)
    local isoX = (x - y) * (self.tileWidth / 2)
    local isoY = (x + y) * (self.tileHeight / 2)
    return { x = isoX, y = isoY }
end

--- Converte coordenadas isométricas (pixels) para coordenadas de tile cartesianas (ponto flutuante).
---@param isoX number
---@param isoY number
---@return Vector2D
function InfinityWrapMapManager:isometricToCartesianTile(isoX, isoY)
    local cartX = (isoX / (self.tileWidth / 2) + isoY / (self.tileHeight / 2)) / 2
    local cartY = (isoY / (self.tileHeight / 2) - isoX / (self.tileWidth / 2)) / 2
    return { x = cartX, y = cartY }
end

--- Retorna as dimensões do mundo em TILES.
---@return number width, number height
function InfinityWrapMapManager:getWorldTileDimensions()
    return self.mapData.width, self.mapData.height
end

--- Retorna as dimensões TOTAIS do mundo em PIXELS.
---@return number width, number height
function InfinityWrapMapManager:getWorldPixelDimensions()
    local w, h = self:getWorldTileDimensions()
    -- A largura e altura total do losango isométrico
    local pixelWidth = (w + h) * (self.tileWidth / 2)
    local pixelHeight = (w + h) * (self.tileHeight / 2)
    return pixelWidth, pixelHeight
end

function InfinityWrapMapManager:destroy()
    for _, canvas in pairs(self.layerCanvases) do
        canvas:release()
    end
    self.layerCanvases = {}
    self.canvasRenderData = nil
end

return InfinityWrapMapManager
