--- @description Gerencia a renderização de um mapa isométrico infinito usando canvases pré-renderizados ("baked").
--- Este manager não carrega ou processa dados de mapa. Ele recebe os canvases prontos
--- da GameLoadingScene e gerencia apenas a lógica de "wrapping" (repetição) e o desenho
--- para criar a ilusão de um mundo contínuo.
local SceneManagerRegistry = require("src.core.scene_manager_registry")
local ServiceLocator = require("src.core.service_locator")

---@class InfinityWrapMapManagerV2
---@field registry SceneManagerRegistry
---@field renderPipeline RenderPipeline
---@field mapData table Os dados crus do mapa Tiled.
---@field bakedLayers table<string, love.Canvas> Os canvases pré-renderizados para cada camada.
---@field worldPixelWidth number Largura total do mapa em pixels isométricos.
---@field worldPixelHeight number Altura total do mapa em pixels isométricos.
---@field tileWidth number Largura de um tile em pixels.
---@field tileHeight number Altura de um tile em pixels.
---@field patchSize number Tamanho de um patch em pixels.
---@field tilesPerPatch number Número de tiles por patch.
---@field currentPatchX number O patch X atual do jogador.
---@field currentPatchY number O patch Y atual do jogador.
local InfinityWrapMapManager = {}
InfinityWrapMapManager.__index = InfinityWrapMapManager

---@param registry SceneManagerRegistry
---@param renderPipeline RenderPipeline
---@return InfinityWrapMapManagerV2
function InfinityWrapMapManager:new(registry, renderPipeline)
    assert(registry, "[InfinityWrapMapManager] missing a ManagerRegistry")
    assert(renderPipeline, "[InfinityWrapMapManager] missing a RenderPipeline")

    local instance = setmetatable({}, InfinityWrapMapManager)
    instance.registry = registry
    instance.renderPipeline = renderPipeline
    instance.mapData = nil
    instance.bakedLayers = nil
    instance.worldPixelWidth = 0
    instance.worldPixelHeight = 0

    instance.tileWidth = 0
    instance.tileHeight = 0
    instance.patchSize = 0
    instance.tilesPerPatch = 0
    instance.currentPatchX = 0
    instance.currentPatchY = 0

    return instance
end

--- Inicializa o manager com os assets pré-carregados e pré-renderizados.
---@param args GameplaySceneArgs A tabela de assets vinda da GameLoadingScene.
function InfinityWrapMapManager:init(args)
    -- Validação de entrada
    assert(args, "InfinityWrapMapManager:init - args is nil")
    assert(args.preloadedAssets, "InfinityWrapMapManager:init - preloadedAssets is nil")
    assert(args.preloadedAssets.map, "InfinityWrapMapManager:init - map is nil")
    assert(args.preloadedAssets.map.mapData, "InfinityWrapMapManager:init - mapData is nil")
    assert(args.preloadedAssets.bakedMap, "InfinityWrapMapManager:init - bakedMap is nil")
    assert(args.preloadedAssets.bakedMap.layers, "InfinityWrapMapManager:init - layers is nil")

    -- LOG DE INSPEÇÃO
    if args and args.preloadedAssets then
        local keys = {}
        for k, _ in pairs(args.preloadedAssets) do table.insert(keys, k) end
        Logger.info("InfinityWrapMapManager:init [INSPECT]",
            "Received preloadedAssets with keys: {" .. table.concat(keys, ", ") .. "}")
    else
        Logger.warn("InfinityWrapMapManager:init [INSPECT]", "Received args with nil or missing preloadedAssets!")
    end

    assert(args and args.preloadedAssets and args.preloadedAssets.map and args.preloadedAssets.bakedMap,
        "InfinityWrapMapManager:init requer map e bakedMap nos preloadedAssets.")

    self.mapData = args.preloadedAssets.map.mapData
    self.bakedLayers = args.preloadedAssets.bakedMap.layers

    -- LOG DE INSPEÇÃO DOS CANVASES
    if self.bakedLayers then
        for layerName, canvas in pairs(self.bakedLayers) do
            if canvas then
                Logger.info("InfinityWrapMapManager:init [CANVAS INSPECT]",
                    string.format("  - Received canvas for layer '%s': %d x %d", layerName, canvas:getWidth(),
                        canvas:getHeight())
                )
            else
                Logger.warn("InfinityWrapMapManager:init [CANVAS INSPECT]",
                    string.format("  - Canvas for layer '%s' is nil!", layerName)
                )
            end
        end
    else
        Logger.error("InfinityWrapMapManager:init [CANVAS INSPECT]", "self.bakedLayers is nil!")
    end

    -- CORREÇÃO: Atribui as dimensões do tile à instância para que outros métodos possam usá-las.
    self.tileWidth = self.mapData.tilewidth
    self.tileHeight = self.mapData.tileheight
    local mapGridWidth = self.mapData.width
    local mapGridHeight = self.mapData.height

    -- A largura e altura de um mapa isométrico em pixels
    self.worldPixelWidth = (mapGridWidth + mapGridHeight) * self.tileWidth / 2
    self.worldPixelHeight = (mapGridWidth + mapGridHeight) * self.tileHeight / 2

    self.tilesPerPatch = self.mapData.properties.grid_width
    self.patchSize = self.mapData.width / self.tilesPerPatch

    -- Inicializa o patch do jogador em uma posição inicial (pode ser ajustado)
    self.currentPatchX = 0
    self.currentPatchY = 0

    Logger.info("infinity_wrap_map_manager.init.success",
        string.format("[InfinityWrapMapManager] Inicializado com mapa '%s' (%dx%d pixels)",
            args.portalData.id,
            self.worldPixelWidth, self.worldPixelHeight))
end

--- O update deste manager é mínimo, pois a lógica de wrap é feita no draw.
--- Poderia ser usado para eventos de "wrap" no futuro, se necessário.
function InfinityWrapMapManager:update(dt)
    ---@type PlayerManager
    local playerMgr = self.registry:get("playerManager")
    if not playerMgr or not playerMgr.movementController then
        return
    end

    local worldPosition = playerMgr.movementController:getPosition()
    local currentTilePos = self:isometricToCartesianTile(worldPosition.x, worldPosition.y)
    local newPatchX = math.floor(currentTilePos.x / self.tilesPerPatch)
    local newPatchY = math.floor(currentTilePos.y / self.tilesPerPatch)

    if newPatchX ~= self.currentPatchX or newPatchY ~= self.currentPatchY then
        self.currentPatchX = newPatchX
        self.currentPatchY = newPatchY

        Logger.debug(
            "infinity_wrap_map_manager.update.player_wrapped",
            string.format("[InfinityWrapMapManager:update] Player wrapped to patch: %d, %d", newPatchX, newPatchY)
        )
        ---@type EventService
        local eventService = ServiceLocator.get("eventService")
        eventService:emit(eventService.EVENTS.PLAYER_WRAPPED)
    end
end

--- Calcula e retorna os offsets de câmera para alinhar entidades com o mapa.
--- Esta função centraliza a lógica de cálculo de offset que antes era
--- duplicada em várias entidades (drops, inimigos, etc).
---@return number, number Retorna os offsets X e Y da câmera.
function InfinityWrapMapManager:getCameraOffsets()
    ---@type PlayerManager
    local playerMgr = SceneManagerRegistry:get("playerManager")
    if not playerMgr or not playerMgr.movementController then
        return 0, 0
    end

    local playerPos = playerMgr.movementController:getPosition()
    local screenCenterX = ResolutionUtils.getGameWidth() / 2
    local screenCenterY = ResolutionUtils.getGameHeight() / 2

    local camOffsetX = screenCenterX - playerPos.x
    local camOffsetY = screenCenterY - playerPos.y

    return camOffsetX, camOffsetY
end

--- Retorna as dimensões totais do mapa base em tiles.
--- Essencial para a lógica de pathfinding em espaço toroidal.
---@return number width, number height
function InfinityWrapMapManager:getWorldTileDimensions()
    if not self.mapData then
        return 0, 0
    end
    return self.mapData.width, self.mapData.height
end

--- Retorna as dimensões totais do mapa base em pixels isométricos.
--- Essencial para a lógica de normalização de posições.
---@return number width, number height
function InfinityWrapMapManager:getWorldPixelDimensions()
    if not self.mapData then
        return 0, 0
    end

    -- Esta função agora funcionará corretamente pois self.tileWidth e self.tileHeight
    -- são definidos no init.
    local tileMapWidth = self.mapData.width
    local tileMapHeight = self.mapData.height

    local pixelWidth = (tileMapWidth + tileMapHeight) * (self.tileWidth / 2)
    local pixelHeight = (tileMapWidth + tileMapHeight) * (self.tileHeight / 2)

    return pixelWidth, pixelHeight
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

--- Desenha as camadas inferiores do mapa (abaixo do jogador).
--- A posição da câmera é gerenciada pelo RenderPipeline.
---@param playerPosition Vector2D A posição do jogador para o cálculo do wrap.
function InfinityWrapMapManager:draw(playerPosition)
    assert(playerPosition, "InfinityWrapMapManager:draw - playerPosition is nil")

    self:_drawLayers({ "ground", "ground_decoration" }, playerPosition)
end

--- Desenha as camadas superiores do mapa (acima do jogador).
--- A posição da câmera é gerenciada pelo RenderPipeline.
---@param playerPosition Vector2D A posição do jogador para o cálculo do wrap.
function InfinityWrapMapManager:drawTopLayers(playerPosition)
    assert(playerPosition, "InfinityWrapMapManager:drawTopLayers - playerPosition is nil")

    self:_drawLayers({ "decoration" }, playerPosition)
end

--- (Privado) Lógica central de desenho que aplica o "wrap".
---@param layerNames string[] Nomes das camadas a serem desenhadas.
---@param playerPosition Vector2D A posição do jogador que o pipeline está seguindo.
function InfinityWrapMapManager:_drawLayers(layerNames, playerPosition)
    local drawX = -playerPosition.x + (ResolutionUtils.getGameWidth() / 2)
    local drawY = -playerPosition.y + (ResolutionUtils.getGameHeight() / 2)

    -- CORREÇÃO: Usa uma fórmula de módulo que funciona corretamente com números negativos
    -- para garantir que o "wrap" aconteça em todas as direções.
    local wrappedDrawX = ((drawX % self.worldPixelWidth) + self.worldPixelWidth) % self.worldPixelWidth
    local wrappedDrawY = ((drawY % self.worldPixelHeight) + self.worldPixelHeight) % self.worldPixelHeight

    -- Desenha os 9 canvas para o efeito de wrap
    for i = -1, 1 do
        for j = -1, 1 do
            local offsetX = wrappedDrawX + i * self.worldPixelWidth
            local offsetY = wrappedDrawY + j * self.worldPixelHeight
            -- Logger.debug("InfinityWrapMapManager._drawLayers", string.format("  - Drawing canvas patch at: (%.2f, %.2f)", offsetX, offsetY))
            for _, layerName in ipairs(layerNames) do
                local canvas = self.bakedLayers[layerName]
                if canvas then
                    love.graphics.draw(canvas, offsetX, offsetY)
                end
            end
        end
    end
end

function InfinityWrapMapManager:destroy()
    if self.bakedLayers then
        for _, canvas in pairs(self.bakedLayers) do
            canvas:release()
        end
    end
    self.bakedLayers = nil
    Logger.info("infinity_wrap_map_manager.destroy", "[InfinityWrapMapManager] Canvases do mapa liberados.")
end

return InfinityWrapMapManager
