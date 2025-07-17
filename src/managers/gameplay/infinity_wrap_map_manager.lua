local ManagerRegistry = require("src.managers.manager_registry")

---@class InfinityWrapMapManager
---@description Gerencia um mapa isométrico infinito, sua renderização e eventos de "wrap".
--- Carrega os dados de um mapa Tiled, pré-renderiza suas camadas em canvases para
--- performance e emite eventos quando o jogador atravessa as bordas dos patches.
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

--- Cria uma nova instância do InfinityWrapMapManager.
---@param mapName string O nome do arquivo do mapa a ser carregado (ex: "jungle").
---@return InfinityWrapMapManager
function InfinityWrapMapManager:new(mapName)
    local instance = setmetatable({}, InfinityWrapMapManager)
    instance.mapName = mapName
    instance:loadMapData()

    if not instance.mapData then
        error("Não foi possível carregar os dados do mapa: " .. mapName)
    end

    instance:init()
    return instance
end

--- Carrega os dados do mapa Tiled.
function InfinityWrapMapManager:loadMapData()
    local mapPath = "src.data.maps." .. self.mapName
    local ok, mapData = pcall(require, mapPath)
    if ok then
        self.mapData = mapData
    else
        self.mapData = nil
    end
end

--- Inicializa os componentes do gerenciador de mapa.
function InfinityWrapMapManager:init()
    -- Configurações do tile isométrico baseadas no mapa
    self.tileWidth = self.mapData.tilewidth
    self.tileHeight = self.mapData.tileheight
    self.patchSize = self.mapData.width / self.mapData.properties.grid_width
    self.tilesPerPatch = self.mapData.properties.grid_width

    -- Carrega as imagens dos tiles e as mantém individualmente
    self.tiles = {}
    for _, tile in ipairs(self.mapData.tilesets[1].tiles) do
        local gid = tile.id + self.mapData.tilesets[1].firstgid
        self.tiles[gid] = love.graphics.newImage(tile.image)
    end

    self:initializeCanvasSystem()

    -- Inicia o processo de construção assíncrona dos canvases
    self.isLoading = true
    self.loadingProgress = 0
    self.buildCoroutine = coroutine.create(function()
        self:buildCanvasesAsyncTask(true)
    end)

    EventManager:on(EventManager.EVENTS.PLAYER_WRAPPED, self.onPlayerWrapped, self)
end

--- Listener para o evento de wrap do jogador. Força a reconstrução dos canvases.
function InfinityWrapMapManager:onPlayerWrapped()
    self:updateAllCanvases(true)
end

--- Atualiza o estado do mapa, principalmente o processo de carregamento.
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
                self:updateAllCanvases(true)
            end
        end
    end
end

--- Desenha as camadas inferiores do mapa (abaixo do jogador).
---@param worldPosition Vector2D posição do jogador no mundo
function InfinityWrapMapManager:draw(worldPosition)
    if self.isLoading then return end

    local renderData = self.canvasRenderData

    -- Ponto de origem (tile 0,0) do grid que foi renderizado no canvas
    local renderRadius = math.floor(renderData.renderGridDiameter / 2)
    local gridOriginTileX = (renderData.lastRenderedPatchX - renderRadius) * self.tilesPerPatch
    local gridOriginTileY = (renderData.lastRenderedPatchY - renderRadius) * self.tilesPerPatch

    -- Posição isométrica do ponto de origem do grid
    local gridOriginIso = self:cartesianToIsometric(gridOriginTileX, gridOriginTileY)

    -- A posição do jogador relativa ao canvas é a posição no mundo menos a origem do grid (em pixels iso)
    -- mais o offset de renderização interno do canvas.
    local playerRelativeX = worldPosition.x - gridOriginIso.x
    local playerRelativeY = worldPosition.y - gridOriginIso.y

    -- Para centralizar o jogador na tela, o canvas deve ser desenhado em uma posição que
    -- mova o ponto isométrico do jogador para o centro da tela.
    local canvasDrawX = ResolutionUtils.getGameWidth() / 2 - playerRelativeX - renderData.offsetX
    local canvasDrawY = ResolutionUtils.getGameHeight() / 2 - playerRelativeY - renderData.offsetY


    -- Desenha os canvases na ordem correta, verificando se eles existem
    if self.layerCanvases["ground"] then
        love.graphics.draw(self.layerCanvases["ground"], canvasDrawX, canvasDrawY)
    end
    if self.layerCanvases["ground_decoration"] then
        love.graphics.draw(self.layerCanvases["ground_decoration"], canvasDrawX, canvasDrawY)
    end
end

--- Desenha as camadas superiores do mapa (acima do jogador).
---@param worldPosition Vector2D posição do jogador no mundo
function InfinityWrapMapManager:drawTopLayers(worldPosition)
    if self.isLoading then return end

    local renderData = self.canvasRenderData
    local renderRadius = math.floor(renderData.renderGridDiameter / 2)
    local gridOriginTileX = (renderData.lastRenderedPatchX - renderRadius) * self.tilesPerPatch
    local gridOriginTileY = (renderData.lastRenderedPatchY - renderRadius) * self.tilesPerPatch
    local gridOriginIso = self:cartesianToIsometric(gridOriginTileX, gridOriginTileY)
    local playerRelativeX = worldPosition.x - gridOriginIso.x
    local playerRelativeY = worldPosition.y - gridOriginIso.y
    local canvasDrawX = ResolutionUtils.getGameWidth() / 2 - playerRelativeX - renderData.offsetX
    local canvasDrawY = ResolutionUtils.getGameHeight() / 2 - playerRelativeY - renderData.offsetY

    if self.layerCanvases["decoration"] then
        love.graphics.draw(self.layerCanvases["decoration"], canvasDrawX, canvasDrawY)
    end
    if self.layerCanvases["collision"] then
        love.graphics.draw(self.layerCanvases["collision"], canvasDrawX, canvasDrawY)
    end
end

-- === Funções Auxiliares de Construção ===

--- Percorre todos os tiles para encontrar a maior dimensão de tile.
function InfinityWrapMapManager:getMaximumTileDimensions()
    local maxW, maxH = 0, 0
    if not self.tiles or not next(self.tiles) then return self.tileWidth, self.tileHeight * 2 end -- Fallback
    for _, img in pairs(self.tiles) do
        local w, h = img:getDimensions()
        if w > maxW then maxW = w end
        if h > maxH then maxH = h end
    end
    return maxW, maxH
end

--- Inicializa o sistema de renderização por canvas.
function InfinityWrapMapManager:initializeCanvasSystem()
    self.layerCanvases = {}
    self.canvasRenderData = {
        renderGridDiameter = 3,  -- Renderiza um grid de 3x3 patches
        lastRenderedPatchX = -1, -- Inicia com valor inválido para forçar a primeira renderização
        lastRenderedPatchY = -1
    }

    local renderData = self.canvasRenderData
    local gridSizeInTiles = renderData.renderGridDiameter * self.tilesPerPatch

    local maxTileW, maxTileH = self:getMaximumTileDimensions()
    local N = gridSizeInTiles

    local canvasWidth = (N - 1) * self.tileWidth + maxTileW
    local canvasHeight = (N - 1) * self.tileHeight + maxTileH

    renderData.width = canvasWidth
    renderData.height = canvasHeight
    renderData.offsetX = (N - 1) * self.tileWidth / 2 + (maxTileW / 2)
    renderData.offsetY = maxTileH - (self.tileHeight / 2)

    for _, layer in ipairs(self.mapData.layers) do
        if layer.type == "tilelayer" and layer.visible then
            local ok, canvas = pcall(love.graphics.newCanvas, canvasWidth, canvasHeight)
            if ok then
                canvas:setFilter("nearest", "nearest")
                self.layerCanvases[layer.name] = canvas
            else
                Logger.error("infinity_wrap_map_manager.canvas.fail",
                    string.format("ERRO: Falha ao criar canvas de %dx%d para a camada '%s'.", canvasWidth, canvasHeight,
                        layer.name))
            end
        end
    end
end

--- Verifica se os canvases precisam ser redesenhados e o faz de forma bloqueante.
---@param force boolean
function InfinityWrapMapManager:updateAllCanvases(force)
    if force then
        self:buildCanvasesAsyncTask(false) -- Executa a tarefa de forma bloqueante
    end
end

--- Tarefa que constrói os canvases.
---@param isAsyncTask boolean Se deve pausar (yield) durante a execução.
function InfinityWrapMapManager:buildCanvasesAsyncTask(isAsyncTask)
    local renderData = self.canvasRenderData

    -- Posição do jogador precisa ser obtida para centralizar a construção.
    ---@type PlayerManager
    local playerMgr = ManagerRegistry:get("playerManager")
    local worldPosition = { x = 0, y = 0 }
    if playerMgr and playerMgr.movementController then
        worldPosition = playerMgr.movementController:getPosition()
    end

    -- Converte a posição de pixel do mundo para uma posição de tile para encontrar o patch atual
    local currentTilePos = self:isometricToCartesianTile(worldPosition.x, worldPosition.y)
    local currentPatchX = math.floor(currentTilePos.x / self.tilesPerPatch)
    local currentPatchY = math.floor(currentTilePos.y / self.tilesPerPatch)

    renderData.lastRenderedPatchX = currentPatchX
    renderData.lastRenderedPatchY = currentPatchY

    local totalLayers = 0
    for _ in pairs(self.layerCanvases) do totalLayers = totalLayers + 1 end
    local layersProcessed = 0

    for name, canvas in pairs(self.layerCanvases) do
        self:renderLayerToCanvas(name, canvas, isAsyncTask)
        layersProcessed = layersProcessed + 1
        self.loadingProgress = layersProcessed / totalLayers
        if isAsyncTask then coroutine.yield() end
    end
end

--- Desenha uma camada de mapa usando love.graphics.draw individual.
---@param layerName string
---@param canvas love.Canvas
---@param isAsyncTask boolean
function InfinityWrapMapManager:renderLayerToCanvas(layerName, canvas, isAsyncTask)
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
    local TILES_PER_YIELD = 100

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
                        if isAsyncTask and tilesDrawnInFrame >= TILES_PER_YIELD then
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

return InfinityWrapMapManager
