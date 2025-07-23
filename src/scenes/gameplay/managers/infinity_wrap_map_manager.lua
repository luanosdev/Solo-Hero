--- @description Gerencia um mapa isométrico infinito, sua renderização e eventos de "wrap".
--- Carrega os dados de um mapa Tiled, pré-renderiza suas camadas em canvases para
--- performance e emite eventos quando o jogador atravessa as bordas dos patches.
local SceneManagerRegistry = require("src.core.scene_manager_registry")
local ServiceLocator = require("src.core.service_locator")

---@class InfinityWrapMapManagerV2
---@field registry SceneManagerRegistry
---@field mapData table Os dados crus do mapa Tiled.
---@field tiles table<number, love.Image> Tabela de imagens de tile individuais.
---@field layerCanvases table<string, love.Canvas> Canvases pré-renderizados para cada camada.
---@field canvasRenderData table Dados sobre a renderização do canvas.
---@field isBaking boolean True se o mapa estiver em processo de construção.
---@field bakingCoroutine thread A corrotina usada para construção assíncrona.
---@field tileWidth number
---@field tileHeight number
---@field patchGridSize number -- No código antigo, isso era 'patchSize'
---@field tilesPerPatch number
local InfinityWrapMapManager = {}
InfinityWrapMapManager.__index = InfinityWrapMapManager

function InfinityWrapMapManager:new(registry)
    local instance = setmetatable({}, InfinityWrapMapManager)
    instance.registry = registry
    instance.mapData = nil
    instance.tiles = {}
    instance.layerCanvases = {}
    instance.canvasRenderData = {}
    instance.isBaking = true
    instance.bakingCoroutine = nil
    instance.tileWidth = 0
    instance.tileHeight = 0
    instance.patchGridSize = 0
    instance.tilesPerPatch = 0
    return instance
end

function InfinityWrapMapManager:init(args)
    self.mapData = args.preloadedAssets.map.mapData
    self.tiles = args.preloadedAssets.map.tiles
    self.tileWidth = self.mapData.tilewidth
    self.tileHeight = self.mapData.tileheight
    self.patchGridSize = self.mapData.width / self.mapData.properties.grid_width
    self.tilesPerPatch = self.mapData.properties.grid_width

    self:_initializeCanvasSystem()

    self.isBaking = true
    self.bakingCoroutine = coroutine.create(function() self:_buildCanvasesAsyncTask(true) end)

    -- AGORA que o mapa conhece suas dimensões, ele posiciona o jogador.
    self:_setInitialPlayerPosition()
end

function InfinityWrapMapManager:update(dt)
    if self.isBaking then
        local status, err = coroutine.resume(self.bakingCoroutine)
        if not status then
            Logger.error("IWMM.update.coroutine_error", "Erro na corrotina de construção do mapa: " .. tostring(err))
            self.isBaking = false
        end
        if coroutine.status(self.bakingCoroutine) == "dead" then
            if self.isBaking then
                self.isBaking = false
                self:_updateAllCanvases(true)
            end
        end
    else
        local playerMgr = self.registry:get("playerManager")
        if not playerMgr or not playerMgr.movementController then return end
        local worldPosition = playerMgr:getPosition()
        local currentTilePos = self:isometricToCartesianTile(worldPosition.x, worldPosition.y)
        local currentPatchX = math.floor(currentTilePos.x / self.tilesPerPatch)
        local currentPatchY = math.floor(currentTilePos.y / self.tilesPerPatch)
        if currentPatchX ~= self.canvasRenderData.lastRenderedPatchX or currentPatchY ~= self.canvasRenderData.lastRenderedPatchY then
            local eventService = ServiceLocator.get("eventService")
            eventService:emit("PLAYER_WRAPPED") -- TODO: Usar enum de eventos
            self:_updateAllCanvases(true)
        end
    end
end

function InfinityWrapMapManager:draw()
    if self.isBaking then return end
    local playerMgr = self.registry:get("playerManager")
    local worldPosition = playerMgr and playerMgr:getPosition()
    if not worldPosition then return end

    local canvasDrawX, canvasDrawY = self:_calculateCanvasDrawPosition(worldPosition)
    if self.layerCanvases["ground"] then love.graphics.draw(self.layerCanvases["ground"], canvasDrawX, canvasDrawY) end
    if self.layerCanvases["ground_decoration"] then
        love.graphics.draw(
            self.layerCanvases["ground_decoration"],
            canvasDrawX,
            canvasDrawY
        )
    end
end

function InfinityWrapMapManager:drawTopLayers()
    if self.isBaking then return end
    local playerMgr = self.registry:get("playerManager")
    local worldPosition = playerMgr and playerMgr:getPosition()
    if not worldPosition then return end

    local canvasDrawX, canvasDrawY = self:_calculateCanvasDrawPosition(worldPosition)
    if self.layerCanvases["decoration"] then
        love.graphics.draw(
            self.layerCanvases["decoration"],
            canvasDrawX,
            canvasDrawY
        )
    end
end

function InfinityWrapMapManager:_setInitialPlayerPosition()
    local worldW, worldH = self:getWorldPixelDimensions()
    local startPosition = { x = worldW / 2, y = worldH / 2 }

    ---@type PlayerManagerV2
    local playerManager = self.registry:get("playerManager")
    if playerManager and playerManager.movementController then
        playerManager.movementController:setPosition(startPosition)
    else
        Logger.error("IWMM._setInitialPlayerPosition",
            "Não foi possível encontrar o playerManager ou seu movementController para definir a posição inicial.")
    end
end

function InfinityWrapMapManager:_calculateCanvasDrawPosition(worldPosition)
    local renderData = self.canvasRenderData
    local renderRadius = math.floor(renderData.renderGridDiameter / 2)
    local gridOriginTileX = (renderData.lastRenderedPatchX - renderRadius) * self.tilesPerPatch
    local gridOriginTileY = (renderData.lastRenderedPatchY - renderRadius) * self.tilesPerPatch
    local gridOriginIso = self:cartesianToIsometric(gridOriginTileX, gridOriginTileY)
    local playerRelativeX = worldPosition.x - gridOriginIso.x
    local playerRelativeY = worldPosition.y - gridOriginIso.y
    local canvasDrawX = ResolutionUtils.getGameWidth() / 2 - playerRelativeX - renderData.offsetX
    local canvasDrawY = ResolutionUtils.getGameHeight() / 2 - playerRelativeY - renderData.offsetY
    return canvasDrawX, canvasDrawY
end

function InfinityWrapMapManager:_initializeCanvasSystem()
    self.layerCanvases = {}
    self.canvasRenderData = {
        renderGridDiameter = 3,
        lastRenderedPatchX = -1,
        lastRenderedPatchY = -1
    }
    local renderData = self.canvasRenderData
    local gridSizeInTiles = renderData.renderGridDiameter * self.tilesPerPatch
    local maxTileW, maxH = self:_getMaximumTileDimensions()
    local N = gridSizeInTiles
    local canvasWidth = (N - 1) * self.tileWidth + maxTileW
    local canvasHeight = (N - 1) * self.tileHeight + maxH
    renderData.width = canvasWidth
    renderData.height = canvasHeight
    renderData.offsetX = (N - 1) * self.tileWidth / 2 + (maxTileW / 2)
    renderData.offsetY = maxH - (self.tileHeight / 2)
    for _, layer in ipairs(self.mapData.layers) do
        if layer.type == "tilelayer" and layer.visible then
            self.layerCanvases[layer.name] = love.graphics.newCanvas(canvasWidth, canvasHeight, { format = "rgba8" })
        end
    end
end

function InfinityWrapMapManager:_getMaximumTileDimensions()
    local maxW, maxH = 0, 0
    if not self.tiles or not next(self.tiles) then return self.tileWidth, self.tileHeight * 2 end
    for _, img in pairs(self.tiles) do
        maxW = math.max(maxW, img:getWidth())
        maxH = math.max(maxH, img:getHeight())
    end
    return maxW, maxH
end

function InfinityWrapMapManager:_updateAllCanvases(force)
    if force then
        self:_buildCanvasesAsyncTask(false)
    end
end

function InfinityWrapMapManager:_buildCanvasesAsyncTask(isAsyncTask)
    local playerMgr = self.registry:get("playerManager")
    local worldPosition = playerMgr and playerMgr:getPosition() or { x = 0, y = 0 }
    local currentTilePos = self:isometricToCartesianTile(worldPosition.x, worldPosition.y)
    local currentPatchX = math.floor(currentTilePos.x / self.tilesPerPatch)
    local currentPatchY = math.floor(currentTilePos.y / self.tilesPerPatch)
    self.canvasRenderData.lastRenderedPatchX = currentPatchX
    self.canvasRenderData.lastRenderedPatchY = currentPatchY
    for name, canvas in pairs(self.layerCanvases) do
        self:_renderLayerToCanvas(name, canvas, isAsyncTask)
    end
end

function InfinityWrapMapManager:_renderLayerToCanvas(layerName, canvas, isAsyncTask)
    local layer = self:_findLayer(self.mapData.layers, layerName)
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
    local yieldFunc = isAsyncTask and coroutine.yield or function() end
    for py = centerPatchY - renderRadius, centerPatchY + renderRadius do
        for px = centerPatchX - renderRadius, centerPatchX + renderRadius do
            local sourcePatchX = ((px % self.patchGridSize) + self.patchGridSize) % self.patchGridSize
            local sourcePatchY = ((py % self.patchGridSize) + self.patchGridSize) % self.patchGridSize
            local sourceTileStartX = sourcePatchX * self.tilesPerPatch
            local sourceTileStartY = sourcePatchY * self.tilesPerPatch
            for y = 0, self.tilesPerPatch - 1 do
                for x = 0, self.tilesPerPatch - 1 do
                    local sourceMapX = sourceTileStartX + x
                    local sourceMapY = sourceTileStartY + y
                    local index = sourceMapY * mapTotalWidth + sourceMapX + 1
                    local gid = layer.data[index]
                    if gid and gid > 0 then
                        local tileInfo = self:_findTileInfo(self.mapData.tilesets, gid)
                        if tileInfo and self.tiles[tileInfo.image] then
                            local tileImage = self.tiles[tileInfo.image]
                            local destTileX = (px * self.tilesPerPatch + x) - gridOriginTileX
                            local destTileY = (py * self.tilesPerPatch + y) - gridOriginTileY
                            local iso = self:cartesianToIsometric(destTileX, destTileY)
                            local screenX = iso.x + renderData.offsetX
                            local screenY = iso.y + renderData.offsetY
                            local ox = tileImage:getWidth() / 2
                            local oy = tileImage:getHeight() - self.tileHeight / 2
                            love.graphics.draw(tileImage, math.floor(screenX), math.floor(screenY), 0, 1, 1, ox, oy)
                            tilesDrawnInFrame = tilesDrawnInFrame + 1
                            if tilesDrawnInFrame >= TILES_PER_YIELD then
                                yieldFunc()
                                tilesDrawnInFrame = 0
                            end
                        end
                    end
                end
            end
        end
    end
    love.graphics.setCanvas()
end

-- Funções auxiliares portadas 1:1
function InfinityWrapMapManager:_findLayer(layers, name)
    for _, l in ipairs(layers) do if l.name == name then return l end end; return nil
end

function InfinityWrapMapManager:_findTileInfo(tilesets, gid)
    for i = #tilesets, 1, -1 do
        local ts = tilesets[i]; if gid >= ts.firstgid then
            local lid = gid - ts.firstgid; for _, t in ipairs(ts.tiles) do if t.id == lid then return t end end
        end
    end; return nil
end

function InfinityWrapMapManager:cartesianToIsometric(x, y)
    return {
        x = (x - y) * (self.tileWidth / 2),
        y = (x + y) *
            (self.tileHeight / 2)
    }
end

function InfinityWrapMapManager:isometricToCartesianTile(isoX, isoY)
    return {
        x = (isoX / (self.tileWidth / 2) + isoY / (self.tileHeight / 2)) /
            2,
        y = (isoY / (self.tileHeight / 2) - isoX / (self.tileWidth / 2)) / 2
    }
end

--- Retorna as dimensões totais do mapa base em pixels isométricos.
--- Essencial para a lógica de normalização de posições.
---@return number width, number height
function InfinityWrapMapManager:getWorldPixelDimensions()
    if not self.mapData then
        return 0, 0
    end

    -- CORREÇÃO FINAL: A fórmula correta para a bounding box de um mapa isométrico.
    local tileMapWidth = self.mapData.width
    local tileMapHeight = self.mapData.height

    local pixelWidth = (tileMapWidth + tileMapHeight - 2) * (self.tileWidth / 2)
    local pixelHeight = (tileMapWidth + tileMapHeight - 2) * (self.tileHeight / 2)

    return pixelWidth, pixelHeight
end

--- Libera todos os canvases criados.
---@private
function InfinityWrapMapManager:destroy() for _, c in pairs(self.layerCanvases) do c:release() end end

return InfinityWrapMapManager
