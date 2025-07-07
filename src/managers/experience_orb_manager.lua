-------------------------------------------------------
-- Experience Orb Manager
-- Gerencia os orbes de experiência com otimizações avançadas
-- Usa SpriteBatch para renderização eficiente e pooling para performance

local ExperienceOrb = require("src.entities.experience_orb")
local ManagerRegistry = require("src.managers.manager_registry")
local Constants = require("src.config.constants")
local TablePool = require("src.utils.table_pool")
local Culling = require("src.core.culling")
local Camera = require("src.config.camera")
local RenderPipeline = require("src.core.render_pipeline")
local Colors = require("src.ui.colors")

---@class ExperienceOrbManager
---@field orbs ExperienceOrb[] Lista de orbes de experiência ativos
---@field orbPool ExperienceOrb[] Pool de orbes inativos para reutilização
---@field spriteBatch love.SpriteBatch | nil SpriteBatch para renderização eficiente
---@field texture love.Image | nil Textura do spritesheet dos orbs
---@field frameWidth number Largura de cada frame do spritesheet
---@field frameHeight number Altura de cada frame do spritesheet
---@field quadCache table Cache de quads para cada frame
---@field maxPoolSize number Tamanho máximo do pool
---@field lastCullingUpdate number Último tempo de atualização do culling
---@field cullingInterval number Intervalo entre atualizações de culling
---@field mergeGrid table<string, ExperienceOrb[]> Grid para agrupamento de orbes
---@field lastMergeUpdate number Último tempo de merge
---@field mergeInterval number Intervalo entre merges (segundos)
---@field needsUnmergeCheck boolean Flag para verificar desagrupamento
---@field lastCameraPosition {x: number, y: number}
---@field cameraMovementThreshold number
---@field lazyMergeCounter number Contador para merge ultra-lazy
---@field mergeFrequency number Frequência de merge (a cada X updates)
local ExperienceOrbManager = {
    orbs = {},
    orbPool = {},
    spriteBatch = nil,
    texture = nil,
    frameWidth = 0,
    frameHeight = 0,
    quadCache = {},
    maxPoolSize = 200,
    lastCullingUpdate = 0,
    cullingInterval = 0.1 -- Atualiza culling a cada 100ms
}

function ExperienceOrbManager:init()
    self.orbs = {}
    self.orbPool = {}
    self.quadCache = {}
    self.lastCullingUpdate = 0
    self.mergeGrid = {}
    self.lastMergeUpdate = 0
    self.mergeInterval = 2.0 -- Merge a cada 2 segundos (bem lazy)
    self.needsUnmergeCheck = false
    self.lastCameraPosition = { x = 0, y = 0 }
    self.cameraMovementThreshold = 300 -- Só verifica unmerge se câmera se moveu muito
    self.lazyMergeCounter = 0
    self.mergeFrequency = 180          -- Merge só a cada 180 updates (~3 segundos a 60fps)

    -- Carrega o spritesheet
    self:_loadSpriteBatch()
end

function ExperienceOrbManager:_loadSpriteBatch()
    local success, err = pcall(function()
        -- Carrega a textura do spritesheet
        self.texture = love.graphics.newImage("assets/effects/exp_orb.png")

        -- Calcula dimensões dos frames
        self.frameWidth = self.texture:getWidth() / ExperienceOrb.SPRITE_COLS
        self.frameHeight = self.texture:getHeight() / ExperienceOrb.SPRITE_ROWS

        -- Cria o SpriteBatch
        self.spriteBatch = love.graphics.newSpriteBatch(self.texture, 1000, "dynamic")

        -- Pré-cria todos os quads para cache
        for row = 0, ExperienceOrb.SPRITE_ROWS - 1 do
            for col = 0, ExperienceOrb.SPRITE_COLS - 1 do
                local frameIndex = row * ExperienceOrb.SPRITE_COLS + col + 1
                self.quadCache[frameIndex] = love.graphics.newQuad(
                    col * self.frameWidth,
                    row * self.frameHeight,
                    self.frameWidth,
                    self.frameHeight,
                    self.texture
                )
            end
        end
    end)

    if not success then
        Logger.warn("experience_orb_manager.load_sprite_batch",
            "[ExperienceOrbManager:_loadSpriteBatch] Erro ao carregar spritesheet: " .. tostring(err))
        self.texture = nil
        self.spriteBatch = nil
    end
end

function ExperienceOrbManager:update(dt)
    if not self.orbs or #self.orbs == 0 then return end

    -- Merge ultra-lazy (muito esporádico)
    self:_lazyMergeCheck()

    local currentTime = love.timer.getTime()
    local shouldUpdateCulling = (currentTime - self.lastCullingUpdate) >= self.cullingInterval

    local camX, camY, camWidth, camHeight
    if shouldUpdateCulling then
        camX, camY, camWidth, camHeight = Camera:getViewPort()
        self.lastCullingUpdate = currentTime
    end

    local playerManager = ManagerRegistry:get("playerManager") ---@type PlayerManager

    -- Atualiza orbes ativos
    for i = #self.orbs, 1, -1 do
        local orb = self.orbs[i]

        if not orb:isActive() then
            -- Remove orbe inativo da lista ativa
            self:_returnOrbToPool(orb)
            table.remove(self.orbs, i)
        else
            -- Otimização: só atualiza orbes visíveis na tela (com margem)
            local inViewForUpdate = true
            if shouldUpdateCulling then
                inViewForUpdate = Culling.isInView(orb, camX, camY, camWidth, camHeight, 100)
            end

            if inViewForUpdate then
                local wasCollected = orb:update(dt)
                if wasCollected then
                    -- Adiciona experiência ao jogador
                    self:_processOrbCollection(orb, playerManager)

                    -- Retorna orbe ao pool
                    self:_returnOrbToPool(orb)
                    table.remove(self.orbs, i)
                end
            end
        end
    end
end

function ExperienceOrbManager:addOrb(x, y, experience)
    local orb = self:_getOrbFromPool()
    orb:reset(x, y, experience)
    table.insert(self.orbs, orb)
end

-- Obtém um orbe do pool ou cria um novo
function ExperienceOrbManager:_getOrbFromPool()
    if #self.orbPool > 0 then
        local orb = table.remove(self.orbPool)
        return orb
    else
        return ExperienceOrb:new(0, 0, 0)
    end
end

-- Retorna um orbe ao pool
function ExperienceOrbManager:_returnOrbToPool(orb)
    orb:deactivate()

    -- Limita o tamanho do pool
    if #self.orbPool < self.maxPoolSize then
        table.insert(self.orbPool, orb)
    end
end

--- Coleta os orbes de experiência renderizáveis para a lista de renderização da cena.
---@param renderPipeline RenderPipeline RenderPipeline para adicionar os dados de renderização do orbe.
function ExperienceOrbManager:collectRenderables(renderPipeline)
    if not self.orbs or #self.orbs == 0 then
        return
    end

    -- Limpa o SpriteBatch
    if self.spriteBatch then
        self.spriteBatch:clear()
    end

    local camX, camY, camWidth, camHeight = Camera:getViewPort()
    ---@type ExperienceOrb[]
    local visibleOrbs = {}

    -- Coleta orbes visíveis
    for _, orb in ipairs(self.orbs) do
        if orb:isActive() then
            -- Verifica se o orbe está visível na tela
            if Culling.isInView(orb, camX, camY, camWidth, camHeight, 50) then
                table.insert(visibleOrbs, orb)
            end
        end
    end

    -- Se não há orbes visíveis, não adiciona ao pipeline
    if #visibleOrbs == 0 then
        return
    end

    if self.spriteBatch and self.texture then
        -- Popula o SpriteBatch com os orbes visíveis
        for _, orb in ipairs(visibleOrbs) do
            local renderData = orb:getRenderData()
            if renderData then
                local frameIndex = renderData.frameX + renderData.frameY * ExperienceOrb.SPRITE_COLS + 1
                local quad = self.quadCache[frameIndex]

                if quad then
                    -- Adiciona ao SpriteBatch com transformações
                    self.spriteBatch:add(
                        quad,
                        renderData.x,
                        renderData.y,
                        renderData.rotation,
                        renderData.scale,
                        renderData.scale,
                        self.frameWidth / 2, -- Offset X para centralizar
                        self.frameHeight / 2 -- Offset Y para centralizar
                    )
                end
            end
        end

        -- Adiciona ao pipeline de renderização apenas se há sprites no batch
        if self.spriteBatch:getCount() > 0 then
            -- Calcula sortY médio dos orbes visíveis (para ordenação)
            local avgSortY = 0
            for _, orb in ipairs(visibleOrbs) do
                local renderData = orb:getRenderData()
                if renderData then
                    local isoY = (renderData.x + renderData.y) * (Constants.TILE_HEIGHT / 2)
                    avgSortY = avgSortY + isoY
                end
            end
            avgSortY = avgSortY / #visibleOrbs

            local renderableItem = TablePool.get()
            renderableItem.type = "experience_orb_batch"
            renderableItem.sortY = avgSortY
            renderableItem.depth = RenderPipeline.DEPTH_DROPS
            renderableItem.drawFunction = function()
                self:_drawSpriteBatch()
            end
            renderPipeline:add(renderableItem)
        end
    end
end

-- Desenha o SpriteBatch dos orbes
function ExperienceOrbManager:_drawSpriteBatch()
    if self.spriteBatch and self.spriteBatch:getCount() > 0 then
        local previousBlendMode = love.graphics.getBlendMode()

        -- Usa blend mode "add" para tornar áreas pretas transparentes e criar efeito luminoso
        love.graphics.setBlendMode("add")

        -- Cor roxa luminosa para os orbes
        love.graphics.setColor(Colors.purple) -- Roxo brilhante
        love.graphics.draw(self.spriteBatch)

        -- Restaura blend mode anterior
        love.graphics.setBlendMode(previousBlendMode)
    end
end

-- Obtém estatísticas do manager (para debug)
function ExperienceOrbManager:getStats()
    return {
        activeOrbs = #self.orbs,
        pooledOrbs = #self.orbPool,
        spriteBatchCount = self.spriteBatch and self.spriteBatch:getCount() or 0,
        maxPoolSize = self.maxPoolSize,
        hasSpritesheet = self.texture ~= nil,
        hasSpriteBatch = self.spriteBatch ~= nil,
        frameSize = self.frameWidth .. "x" .. self.frameHeight
    }
end

-- Limpa todos os orbes (útil para mudanças de cena)
function ExperienceOrbManager:clearAll()
    -- Retorna todos os orbes ativos ao pool
    for _, orb in ipairs(self.orbs) do
        self:_returnOrbToPool(orb)
    end

    self.orbs = {}

    if self.spriteBatch then
        self.spriteBatch:clear()
    end
end

--- Destrói o manager de orbes de experiência.
function ExperienceOrbManager:destroy()
    self:clearAll()

    -- Limpa recursos
    self.orbPool = {}
    self.quadCache = {}

    if self.spriteBatch then
        self.spriteBatch:release()
        self.spriteBatch = nil
    end

    if self.texture then
        self.texture:release()
        self.texture = nil
    end
end

-- Função para calcular chave do grid
function ExperienceOrbManager:_getGridKey(x, y)
    local gridX = math.floor(x / ExperienceOrb.MERGE_GRID_SIZE)
    local gridY = math.floor(y / ExperienceOrb.MERGE_GRID_SIZE)
    return gridX .. "," .. gridY
end

-- Função para verificar se orbe está longe da câmera
function ExperienceOrbManager:_isOrbFarFromCamera(orb)
    local camX, camY, camWidth, camHeight = Camera:getViewPort()
    local dx = orb.position.x - (camX + camWidth / 2)
    local dy = orb.position.y - (camY + camHeight / 2)
    local distance = math.sqrt(dx * dx + dy * dy)
    return distance > ExperienceOrb.MIN_MERGE_DISTANCE
end

-- Sistema ultra-lazy de merge
function ExperienceOrbManager:_lazyMergeCheck()
    -- Só executa merge ocasionalmente
    self.lazyMergeCounter = self.lazyMergeCounter + 1
    if self.lazyMergeCounter < self.mergeFrequency then
        return
    end
    self.lazyMergeCounter = 0

    -- Só faz merge se há orbes suficientes
    if #self.orbs < 20 then
        return
    end

    -- Só faz merge se tem muitos orbes fora da tela
    local offscreenCount = 0
    for _, orb in ipairs(self.orbs) do
        if orb:isActive() and not orb.isMoving and self:_isOrbFarFromCamera(orb) then
            offscreenCount = offscreenCount + 1
        end
    end

    -- Só executa merge se há muitos orbes fora da tela
    if offscreenCount >= 15 then
        self:_performLazyMerge()
    end
end

-- Merge ultra-otimizado
function ExperienceOrbManager:_performLazyMerge()
    -- Limpa grid apenas quando necessário
    self.mergeGrid = {}

    -- Processa apenas orbes fora da tela
    for _, orb in ipairs(self.orbs) do
        if orb:isActive() and not orb.isMoving and not orb.isMerged then
            if self:_isOrbFarFromCamera(orb) then
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
        if #orbsInCell >= 5 then -- Threshold mais alto = mais lazy
            self:_mergeOrbsInCell(orbsInCell)
        end
    end
end

-- Merge em uma célula específica
function ExperienceOrbManager:_mergeOrbsInCell(orbsInCell)
    local representativeOrb = orbsInCell[1]
    local totalExperience = representativeOrb.experience
    local mergedCount = 1

    -- Coleta experiência de todos os orbes
    for i = 2, #orbsInCell do
        totalExperience = totalExperience + orbsInCell[i].experience
        mergedCount = mergedCount + 1
    end

    -- Configura o orbe representante
    representativeOrb.isMerged = true
    representativeOrb.mergedExperience = totalExperience
    representativeOrb.mergedCount = mergedCount

    -- Remove orbes excedentes de forma eficiente
    for i = 2, #orbsInCell do
        local orbToRemove = orbsInCell[i]
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

-- Processamento de coleta otimizado
function ExperienceOrbManager:_processOrbCollection(orb, playerManager)
    local experienceToAdd = orb.isMerged and orb.mergedExperience or orb.experience
    playerManager:addExperience(experienceToAdd)
end

return ExperienceOrbManager
