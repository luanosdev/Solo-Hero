local ExperienceOrb = require("src.entities.experience_orb")
local CullingController = require("src.scenes.gameplay.controllers.culling_controller")
local TablePool = require("src.utils.table_pool")
local colors = require("src.ui.colors")
local RenderPipeline = require("src.core.render_pipeline")
local Constants = require("src.config.constants")

---@class ExperienceOrbManager
---@field context GameplaySceneContext
---@field cullingController CullingController
---@field orbs ExperienceOrb[]
---@field orbPool ExperienceOrb[]
---@field spriteBatch love.SpriteBatch
---@field texture love.Image
---@field frameWidth number
---@field frameHeight number
---@field quadCache table<number, love.Quad>
---@field mergeGrid table<string, ExperienceOrb[]>
---@field gameTimerService GameTimerService
---@field visibleOrbs ExperienceOrb[]
---@field cullingTimerId string|nil
local ExperienceOrbManager = {}
ExperienceOrbManager.__index = ExperienceOrbManager

ExperienceOrbManager.ASSETS = {
    exp_orb = "assets/effects/exp_orb.png"
}
ExperienceOrbManager.MAX_SPRITE_BATCH_SIZE = 100
ExperienceOrbManager.MAX_POOL_SIZE = 100
ExperienceOrbManager.CULLING_INTERVAL = 0.2      -- Atualiza a visibilidade 5x por segundo
ExperienceOrbManager.CULLING_MARGIN_UPDATE = 200 -- Margem extra para atualização
ExperienceOrbManager.CULLING_MARGIN_MERGE = 100  -- Margem extra para merge

---@public Cria uma nova instância do ExperienceOrbManager.
---@param context GameplaySceneContext
---@return ExperienceOrbManager
function ExperienceOrbManager:new(context)
    local instance = setmetatable({}, ExperienceOrbManager)
    instance.context = context
    instance.orbs = {}
    instance.orbPool = {}
    instance.quadCache = {}
    instance.mergeGrid = {}
    instance.visibleOrbs = {}
    instance.cullingTimerId = nil
    return instance
end

---@public Inicializa o ExperienceOrbManager.
function ExperienceOrbManager:init()
    self:_loadSpriteBatch()

    self.gameTimerService = self.context.serviceLocator:getGameTimerService()
    self.cullingController = CullingController:new()

    local mapManager = self.context.registry:getMapManager()
    local worldW, worldH = mapManager:getWorldPixelDimensions()
    local worldDimensions = { w = worldW, h = worldH }
    self.cullingController:init(worldDimensions)

    -- Agenda a atualização de culling para rodar em intervalos regulares
    self.cullingTimerId = self.gameTimerService:addRecurringTimer(
        ExperienceOrbManager.CULLING_INTERVAL,
        function() self:_updateVisibleOrbs() end
    )
end

---@public Destrói o manager e limpa os recursos.
function ExperienceOrbManager:destroy()
    if self.cullingTimerId and self.gameTimerService then
        self.gameTimerService:removeTimer(self.cullingTimerId)
        self.cullingTimerId = nil
    end
    -- Limpeza adicional se necessário
end

---@public Adiciona um novo orbe de experiência no mundo.
---@param x number Posição X do orbe.
---@param y number Posição Y do orbe.
---@param experienceValue number A quantidade de experiência que o orbe contém.
function ExperienceOrbManager:addOrb(x, y, experienceValue)
    if not experienceValue or experienceValue <= 0 then return end

    local orb = self:_getOrbFromPool()
    orb:reset(x, y, experienceValue)

    table.insert(self.orbs, orb)
end

---@public Atualiza o ExperienceOrbManager.
---@param dt number Delta time.
function ExperienceOrbManager:update(dt)
    if not self.orbs or #self.orbs == 0 then return end

    self:_performLazyMerge()

    local playerManager = self.context.registry:getPlayerManager()
    local playerPosition = playerManager:getPosition()
    local finalPickupRadiusStats = playerManager.stateController:getStat("pickupRadius")

    -- Atualiza apenas os orbes visíveis
    for i = #self.visibleOrbs, 1, -1 do
        local orb = self.visibleOrbs[i]
        local wasCollected = orb:update(dt, playerPosition, finalPickupRadiusStats)

        if wasCollected then
            self:_processOrbCollection(orb)
            self:_returnOrbToPool(orb)

            -- Remove da lista principal procurando o orb específico
            for j = #self.orbs, 1, -1 do
                if self.orbs[j] == orb then
                    table.remove(self.orbs, j)
                    break
                end
            end
            -- Remove da lista de visíveis usando o índice correto
            table.remove(self.visibleOrbs, i)
        elseif not orb:isActive() then
            self:_returnOrbToPool(orb)

            -- Remove da lista principal procurando o orb específico
            for j = #self.orbs, 1, -1 do
                if self.orbs[j] == orb then
                    table.remove(self.orbs, j)
                    break
                end
            end
            -- Remove da lista de visíveis usando o índice correto
            table.remove(self.visibleOrbs, i)
        end
    end
end

---@public Coleta os renderables
---@param renderPipeline RenderPipeline
function ExperienceOrbManager:collectRenderables(renderPipeline)
    if not self.orbs or #self.orbs == 0 or #self.visibleOrbs == 0 then
        return
    end

    assert(self.spriteBatch, "SpriteBatch not initialized")
    assert(self.texture, "Texture not initialized")

    -- Limpa o SpriteBatch a cada frame
    self.spriteBatch:clear()

    -- Adiciona todos os orbs visíveis ao SpriteBatch
    for _, orb in ipairs(self.visibleOrbs) do
        local renderData = orb:getRenderData()
        if renderData then
            local frameIndex = renderData.frameX + renderData.frameY * ExperienceOrb.SPRITE_COLS + 1
            local quad = self.quadCache[frameIndex]

            if quad then
                self.spriteBatch:add(
                    quad,
                    renderData.x,
                    renderData.y,
                    renderData.rotation,
                    renderData.scale,
                    renderData.scale,
                    self.frameWidth / 2,
                    self.frameHeight / 2
                )
            end
        else
            error("Failed to get render data for orb")
        end
    end

    -- Cria um único renderableItem se houver sprites no batch
    if self.spriteBatch:getCount() > 0 then
        local avgSortY = 0
        for _, orb in ipairs(self.visibleOrbs) do
            local renderData = orb:getRenderData()
            if renderData then
                local isoY = (renderData.x + renderData.y) * (Constants.TILE_HEIGHT / 2)
                avgSortY = avgSortY + isoY
            end
        end
        avgSortY = avgSortY / #self.visibleOrbs

        local renderableItem = TablePool.getGeneric()
        renderableItem.type = "experience_orb_batch"
        renderableItem.sortY = avgSortY
        renderableItem.depth = RenderPipeline.DEPTH_DROPS
        renderableItem.drawFunction = function()
            self:_drawSpriteBatch()
        end
        renderPipeline:add(renderableItem)
    end
end

---@private Atualiza a lista de orbs visíveis na tela.
function ExperienceOrbManager:_updateVisibleOrbs()
    if not self.orbs or #self.orbs == 0 then
        self.visibleOrbs = {}
        return
    end

    local playerManager = self.context.registry:getPlayerManager()
    local playerPosition = playerManager:getPosition()

    local visible = {}
    for _, orb in ipairs(self.orbs) do
        local isOnView = self.cullingController:isInView(
            orb,
            playerPosition,
            ExperienceOrbManager.CULLING_MARGIN_MERGE
        )

        if orb:isActive() and isOnView then
            table.insert(visible, orb)
        end
    end

    self.visibleOrbs = visible
end

---@private Desenha o SpriteBatch dos orbes
function ExperienceOrbManager:_drawSpriteBatch()
    if self.spriteBatch and self.spriteBatch:getCount() > 0 then
        local previousBlendMode = love.graphics.getBlendMode()

        -- Usa blend mode "add" para tornar áreas pretas transparentes e criar efeito luminoso
        love.graphics.setBlendMode("add")

        -- Cor roxa luminosa para os orbes
        love.graphics.setColor(colors.solo_leveling.portal_purple) -- Roxo brilhante
        love.graphics.draw(self.spriteBatch)

        -- Restaura blend mode anterior
        love.graphics.setBlendMode(previousBlendMode)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

---@private Processa a coleta de um orbe.
---@param orb ExperienceOrb
function ExperienceOrbManager:_processOrbCollection(orb)
    Logger.info("experience_orb_manager._processOrbCollection",
        "[ExperienceOrbManager:_processOrbCollection] Processing orb collection")
    local playerManager = self.context.registry:getPlayerManager()
    playerManager:addExperience(orb:getTotalExperience())
end

---@private Junta os orbs que estão proximos
function ExperienceOrbManager:_performLazyMerge()
    -- Limpa grid apenas quando necessário
    self.mergeGrid = {}

    local playerManager = self.context.registry:getPlayerManager()
    local playerPosition = playerManager:getPosition()

    --- Processa obs fora da tela
    for _, orb in ipairs(self.orbs) do
        local isOnView = self.cullingController:isInView(
            orb,
            playerPosition,
            ExperienceOrbManager.CULLING_MARGIN_MERGE
        )
        if orb:isActive() and not orb.isMoving and not orb.isMerged and isOnView then
            local gridKey = self:_getGridKey(orb.position.x, orb.position.y)
            if not self.mergeGrid[gridKey] then
                self.mergeGrid[gridKey] = {}
            end
            table.insert(self.mergeGrid[gridKey], orb)
        end
    end

    -- Executa merge apenas em células com muitos orbes
    for gridKey, orbsInCell in pairs(self.mergeGrid) do
        if #orbsInCell >= 5 then -- Threshold mais alto = mais lazy
            self:_mergeOrbsInCell(orbsInCell)
        end
    end
end

---@private Junta os orbs em uma célula específica.
---@param orbs ExperienceOrb[]
function ExperienceOrbManager:_mergeOrbsInCell(orbs)
    local representativeOrb = orbs[1]
    local totalExperience = representativeOrb.experience
    local mergedCount = 1

    -- Coleta experiência de todos os outros orbes
    for i = 2, #orbs do
        totalExperience = totalExperience + orbs[i].experience
        mergedCount = mergedCount + 1
    end

    -- Configura o orbe representante
    representativeOrb.isMerged = true
    representativeOrb.mergedExperience = totalExperience
    representativeOrb.mergedCount = mergedCount

    -- Remove orbes excedentes de forma eficiente
    for i = 2, #orbs do
        local orbToRemove = orbs[i]
        self:_returnOrbToPool(orbToRemove)

        -- Remove da lista principal (busca reversa para eficiência)
        for j = #self.orbs, 1, -1 do
            if self.orbs[j] == orbToRemove then
                table.remove(self.orbs, j)
                break
            end
        end
    end
end

---@private Calcula a chave do grid para o orbe.
---@param x number
---@param y number
---@return string
function ExperienceOrbManager:_getGridKey(x, y)
    local gridX = math.floor(x / ExperienceOrb.MERGE_GRID_SIZE)
    local gridY = math.floor(y / ExperienceOrb.MERGE_GRID_SIZE)
    return gridX .. "," .. gridY
end

---@private Retorna um orbe do pool ou cria um novo.
---@return ExperienceOrb
function ExperienceOrbManager:_getOrbFromPool()
    if #self.orbPool > 0 then
        local orb = table.remove(self.orbPool)
        return orb
    else
        return ExperienceOrb:new(0, 0, 0)
    end
end

---@private Retorna um orbe ao pool.
---@param orb ExperienceOrb
function ExperienceOrbManager:_returnOrbToPool(orb)
    orb:deactivate()

    -- Limita o tamanho do pool
    if #self.orbPool < ExperienceOrbManager.MAX_POOL_SIZE then
        table.insert(self.orbPool, orb)
    end
end

---@private Carrega o SpriteBatch para renderização eficiente.
function ExperienceOrbManager:_loadSpriteBatch()
    local success, err = pcall(function()
        -- Carrega a textura do spritesheet
        local assetService = self.context.serviceLocator:getAssetService()
        local texture = assetService:getImage(self.ASSETS.exp_orb)

        assert(texture, "Failed to load exp_orb texture")

        self.texture = texture

        -- Calcula dimensões dos frames
        self.frameWidth = self.texture:getWidth() / ExperienceOrb.SPRITE_COLS
        self.frameHeight = self.texture:getHeight() / ExperienceOrb.SPRITE_ROWS

        -- Cria o SpriteBatch
        self.spriteBatch = love.graphics.newSpriteBatch(
            self.texture,
            ExperienceOrbManager.MAX_SPRITE_BATCH_SIZE,
            "dynamic"
        )

        -- Pré-cria todos os quads para cache
        for row = 0, ExperienceOrb.SPRITE_ROWS - 1 do
            for col = 0, ExperienceOrb.SPRITE_COLS - 1 do
                local frameIndex = row * ExperienceOrb.SPRITE_COLS + col + 1
                self.quadCache[frameIndex] = love.graphics.newQuad(
                    col * self.frameWidth,
                    row * self.frameHeight,
                    self.frameWidth,
                    self.frameHeight,
                    self.texture:getDimensions()
                )
            end
        end
    end)

    if not success then
        error("Failed to load sprite batch: " .. tostring(err))
    end
end

return ExperienceOrbManager
