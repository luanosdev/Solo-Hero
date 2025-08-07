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
---@field needsVisibilityUpdate boolean
---@field lastCullingUpdate number
local ExperienceOrbManager = {}
ExperienceOrbManager.__index = ExperienceOrbManager

ExperienceOrbManager.ASSETS = {
    exp_orb = "assets/effects/exp_orb.png"
}
ExperienceOrbManager.MAX_SPRITE_BATCH_SIZE = 100
ExperienceOrbManager.MAX_POOL_SIZE = 100
ExperienceOrbManager.CULLING_INTERVAL = 0.1      -- Atualiza a visibilidade 10x por segundo (mais responsivo)
ExperienceOrbManager.CULLING_MARGIN = 200        -- Margem única para consistência

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
    instance.needsVisibilityUpdate = true
    instance.lastCullingUpdate = 0
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
end

---@public Destrói o manager e limpa os recursos.
function ExperienceOrbManager:destroy()
    -- Limpeza dos recursos
    if self.spriteBatch then
        self.spriteBatch:release()
        self.spriteBatch = nil
    end
    
    -- Retorna todos os orbs ao pool
    for _, orb in ipairs(self.orbs) do
        self:_returnOrbToPool(orb)
    end
    self.orbs = {}
    self.orbPool = {}
    self.quadCache = {}
    self.mergeGrid = {}
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
    self.needsVisibilityUpdate = true
end

---@public Atualiza o ExperienceOrbManager.
---@param dt number Delta time.
function ExperienceOrbManager:update(dt)
    if not self.orbs or #self.orbs == 0 then return end

    -- Atualiza culling periodicamente
    self.lastCullingUpdate = self.lastCullingUpdate + dt
    if self.lastCullingUpdate >= ExperienceOrbManager.CULLING_INTERVAL or self.needsVisibilityUpdate then
        self.needsVisibilityUpdate = false
        self.lastCullingUpdate = 0
    end

    self:_performLazyMerge()

    local playerManager = self.context.registry:getPlayerManager()
    local playerPosition = playerManager:getPosition()
    local finalPickupRadiusStats = playerManager.stateController:getStat("pickupRadius")

    -- Processa TODOS os orbs (não apenas os visíveis)
    -- O culling é aplicado apenas na renderização
    for i = #self.orbs, 1, -1 do
        local orb = self.orbs[i]
        
        -- Verifica se o orb ainda é válido
        if not orb:isActive() then
            self:_returnOrbToPool(orb)
            table.remove(self.orbs, i)
            self.needsVisibilityUpdate = true
        else
            local wasCollected = orb:update(dt, playerPosition, finalPickupRadiusStats)

            if wasCollected then
                self:_processOrbCollection(orb)
                self:_returnOrbToPool(orb)
                table.remove(self.orbs, i)
                self.needsVisibilityUpdate = true
            end
        end
    end
end

---@public Coleta os renderables
---@param renderPipeline RenderPipeline
function ExperienceOrbManager:collectRenderables(renderPipeline)
    if not self.orbs or #self.orbs == 0 then return end

    assert(self.spriteBatch, "SpriteBatch not initialized")
    assert(self.texture, "Texture not initialized")

    -- Calcula orbs visíveis dinamicamente
    local visibleOrbs = self:_getVisibleOrbs()
    if #visibleOrbs == 0 then return end

    -- Limpa o SpriteBatch a cada frame
    self.spriteBatch:clear()

    -- Adiciona todos os orbs visíveis ao SpriteBatch
    local totalSortY = 0
    local validRenderCount = 0

    for _, orb in ipairs(visibleOrbs) do
        if orb:isActive() then -- Validação adicional
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

                    -- Calcula sortY para o pipeline de renderização
                    local isoY = (renderData.x + renderData.y) * (Constants.TILE_HEIGHT / 2)
                    totalSortY = totalSortY + isoY
                    validRenderCount = validRenderCount + 1
                end
            end
        end
    end

    -- Cria um único renderableItem se houver sprites no batch
    if self.spriteBatch:getCount() > 0 and validRenderCount > 0 then
        local avgSortY = totalSortY / validRenderCount

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

---@private Calcula e retorna os orbs visíveis na tela.
---@return ExperienceOrb[]
function ExperienceOrbManager:_getVisibleOrbs()
    if not self.orbs or #self.orbs == 0 then return {} end

    local playerManager = self.context.registry:getPlayerManager()
    local playerPosition = playerManager:getPosition()

    local visible = {}
    for _, orb in ipairs(self.orbs) do
        if orb:isActive() then -- Sempre verifica se o orb está ativo
            local isOnView = self.cullingController:isInView(
                orb,
                playerPosition,
                ExperienceOrbManager.CULLING_MARGIN
            )

            if isOnView then
                table.insert(visible, orb)
            end
        end
    end

    return visible
end

---@private Desenha o SpriteBatch dos orbes
function ExperienceOrbManager:_drawSpriteBatch()
    if self.spriteBatch and self.spriteBatch:getCount() > 0 then
        local previousBlendMode = love.graphics.getBlendMode()
        local r, g, b, a = love.graphics.getColor()

        -- Usa blend mode "add" para tornar áreas pretas transparentes e criar efeito luminoso
        love.graphics.setBlendMode("add")

        -- Cor roxa luminosa para os orbes
        love.graphics.setColor(colors.solo_leveling.portal_purple) -- Roxo brilhante
        love.graphics.draw(self.spriteBatch)

        -- Restaura estado anterior
        love.graphics.setBlendMode(previousBlendMode)
        love.graphics.setColor(r, g, b, a)
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

---@private Junta os orbs que estão próximos
function ExperienceOrbManager:_performLazyMerge()
    -- Limpa grid
    self.mergeGrid = {}

    local playerManager = self.context.registry:getPlayerManager()
    local playerPosition = playerManager:getPosition()

    -- Agrupa orbs por célula do grid (apenas os visíveis para otimização)
    for _, orb in ipairs(self.orbs) do
        if orb:isActive() and not orb.isMoving and not orb.isMerged then
            local isNearView = self.cullingController:isInView(
                orb,
                playerPosition,
                ExperienceOrbManager.CULLING_MARGIN * 1.5 -- Margem maior para merge
            )
            
            if isNearView then
                local gridKey = self:_getGridKey(orb.position.x, orb.position.y)
                if not self.mergeGrid[gridKey] then
                    self.mergeGrid[gridKey] = {}
                end
                table.insert(self.mergeGrid[gridKey], orb)
            end
        end
    end

    -- Executa merge apenas em células com muitos orbes
    for gridKey, orbsInCell in pairs(self.mergeGrid) do
        if #orbsInCell >= 5 then -- Threshold para merge
            self:_mergeOrbsInCell(orbsInCell)
        end
    end
end

---@private Junta os orbs em uma célula específica.
---@param orbs ExperienceOrb[]
function ExperienceOrbManager:_mergeOrbsInCell(orbs)
    if not orbs or #orbs < 2 then return end

    local representativeOrb = orbs[1]
    if not representativeOrb or not representativeOrb:isActive() then return end

    local totalExperience = representativeOrb.experience
    local mergedCount = 1

    -- Lista de orbs para remover
    local orbsToRemove = {}

    -- Coleta experiência de todos os outros orbes
    for i = 2, #orbs do
        local orb = orbs[i]
        if orb and orb:isActive() then
            totalExperience = totalExperience + orb.experience
            mergedCount = mergedCount + 1
            table.insert(orbsToRemove, orb)
        end
    end

    -- Só faz merge se realmente há orbs para unir
    if #orbsToRemove > 0 then
        -- Configura o orbe representante
        representativeOrb.isMerged = true
        representativeOrb.mergedExperience = totalExperience
        representativeOrb.mergedCount = mergedCount

        -- Remove orbes excedentes de forma eficiente
        for _, orbToRemove in ipairs(orbsToRemove) do
            self:_returnOrbToPool(orbToRemove)

            -- Remove da lista principal (busca reversa para eficiência)
            for j = #self.orbs, 1, -1 do
                if self.orbs[j] == orbToRemove then
                    table.remove(self.orbs, j)
                    break
                end
            end
        end

        self.needsVisibilityUpdate = true
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
    if not orb then return end
    
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