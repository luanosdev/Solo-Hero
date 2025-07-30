local EnemyPoolController = require("src.scenes.gameplay.controllers.enemy_pool_controller")
local MVPController = require("src.scenes.gameplay.controllers.mvp_controller")
local EnemySeparationController = require("src.scenes.gameplay.controllers.enemy_separation_controller")
local MVPRepositionController = require("src.scenes.gameplay.controllers.mvp_reposition_controller")
local TimerTaskRunner = require("src.core.timer_task_runner")
local EnemySpawnController = require("src.scenes.gameplay.controllers.enemy_spawn_controller")
local SpatialGridIncremental = require("src.utils.spatial_grid_incremental")
local RenderPipeline = require("src.core.render_pipeline")
local AnimatedSpritesheet = require("src.animations.animated_spritesheet")
local TablePool = require("src.utils.table_pool")
local Colors = require("src.ui.colors")
local Fonts = require("src.ui.fonts")
local EnemyCollisionController = require("src.scenes.gameplay.controllers.enemy_collision_controller")
local EnemyMovementController = require("src.scenes.gameplay.controllers.enemy_movement_controller")
local CullingController = require("src.scenes.gameplay.controllers.culling_controller")
local DespawnController = require("src.scenes.gameplay.controllers.despawn_controller")
-- local FrameTaskRunner = require("src.core.frame_task_runner") -- Se for usar

local Constants = require("src.config.constants")
local ServiceLocator = require("src.core.service_locator")
local ResolutionUtils = require("src.utils.resolution_utils")
local MathUtils = require("src.utils.math_utils")
local Camera = require("src.config.camera")

--- TODO: Remover o v2 quando o v1 for removido
---@class EnemyManager
---@description Gerencia a criação, atualização e destruição dos inimigos.
---@field context GameplaySceneContext
---@field playerManager PlayerManager
---@field dropManager DropManager
---@field cullingController CullingController
---@field mapManager InfinityWrapMapManager
---@field experienceOrbManager ExperienceOrbManager
---@field enemies BaseEnemy[]
---@field spawnController EnemySpawnController
---@field despawnController DespawnController
---@field poolController EnemyPoolController
---@field mvpController MVPController
---@field separationController EnemySeparationController
---@field collisionController EnemyCollisionController
---@field movementController EnemyMovementController
---@field repositionController MVPRepositionController
---@field periodicTasks table<number, TimerTaskRunner|FrameTaskRunner>
---@field spatialGrid SpatialGridIncremental
local EnemyManager = {}
EnemyManager.__index = EnemyManager

---@class EnemyManagerConstants
local CONST = {
    LOGIC_CULLING_MARGIN = 100, -- Margem em pixels para culling de lógica
    DRAW_CULLING_MARGIN = 50    -- Margem para culling de desenho
}

---@param context GameplaySceneContext
---@return EnemyManager
function EnemyManager:new(context)
    assert(context, "[EnemyManager] missing a GameplaySceneContext")

    local instance = setmetatable({}, EnemyManager)
    instance.context = context
    instance.enemies = {}

    return instance
end

function EnemyManager:init()
    Logger.info("enemy_manager.init", "[EnemyManager:init] Initializing...")
    -- Obter dependências do registry
    self.playerManager = self.context.registry:get("playerManager")
    self.mapManager = self.context.registry:get("mapManager")
    --self.experienceOrbManager = self.context.registry:get("experienceOrbManager")
    --self.dropManager = self.context.registry:get("dropManager")

    local spawnCallback = function(enemyClass) self:spawnEnemy(enemyClass) end

    -- Inicializar os controllers
    self.spawnController = EnemySpawnController:new()
    self.spawnController:init(self.context.args.portalData.hordeConfig, spawnCallback)

    self.poolController = EnemyPoolController:new()
    self.mvpController = MVPController:new()
    self.cullingController = CullingController:new()
    self.despawnController = DespawnController:new()

    -- Criar e passar a grade para o controller de separação
    local worldPixelWidth, worldPixelHeight = self.mapManager:getWorldPixelDimensions()
    local cellSize = 128 -- Tamanho da célula (pode ser constante)
    self.spatialGrid = SpatialGridIncremental:new(
        math.ceil(worldPixelWidth / cellSize),
        math.ceil(worldPixelHeight / cellSize),
        cellSize,
        cellSize,
        true -- Grid infinito
    )

    self.separationController = EnemySeparationController:new(self.spatialGrid)
    self.collisionController = EnemyCollisionController:new()
    self.movementController = EnemyMovementController:new()

    self.repositionController = MVPRepositionController:new()

    self.poolController:init()
    self.mvpController:init()
    self.separationController:init()
    self.collisionController:init()
    self.movementController:init()
    self.repositionController:init()

    -- Configurar tarefas periódicas
    self.periodicTasks = {}
    local optimizationTask = TimerTaskRunner:new({
        interval = 10,
        action = function() self:_runOptimizations() end
    })
    table.insert(self.periodicTasks, optimizationTask)


    Logger.info("enemy_manager.init.success", "[EnemyManager:init] initialized successfully.")
end

---@param dt number
function EnemyManager:update(dt)
    -- Atualizações Globais (não dependem de inimigos individuais)
    for _, task in ipairs(self.periodicTasks) do
        task:update(dt)
    end

    local gameTimerService = ServiceLocator.getGameTimerService()
    self.spawnController:update(dt, gameTimerService:getTime())

    -- Preparar dados para o Frame
    local playerPosition = self.playerManager:getPosition()
    local screenW, screenH = ResolutionUtils.getGameDimensions()
    local cameraData = {
        x = playerPosition.x - screenW / 2,
        y = playerPosition.y - screenH / 2,
        w = screenW,
        h = screenH
    }
    local worldW, worldH = self.mapManager:getWorldPixelDimensions()
    local worldDimensions = { w = worldW, h = worldH }
    local mapInfo = {
        worldTileWidth = worldDimensions.w / self.mapManager.tileWidth,
        worldTileHeight = worldDimensions.h / self.mapManager.tileHeight,
        tileWidth = self.mapManager.tileWidth,
        tileHeight = self.mapManager.tileHeight,
        isometricToCartesianTile = function(x, y) return self.mapManager:isometricToCartesianTile(x, y) end,
        cartesianToIsometric = function(x, y) return self.mapManager:cartesianToIsometric(x, y) end,
    }

    -- Culling e Preparação das Listas
    local activeEnemies = {}
    local isEnemySlowLookup = {}

    for _, enemy in ipairs(self.enemies) do
        if enemy.isAlive then
            local isInLogicView = self.cullingController:isInView(
                enemy,
                cameraData,
                worldDimensions,
                CONST.LOGIC_CULLING_MARGIN
            )
            if isInLogicView then
                table.insert(activeEnemies, enemy)
                isEnemySlowLookup[enemy.id] = false
            else
                isEnemySlowLookup[enemy.id] = true
            end
        end
    end

    -- Atualização da Lógica para Inimigos Ativos
    if #activeEnemies > 0 then
        -- Atualiza a grade com as posições dos inimigos ativos
        for _, enemy in ipairs(activeEnemies) do
            self.spatialGrid:updateEntityInGrid(enemy)
        end

        self.separationController:update(dt, activeEnemies, mapInfo)

        local playerData = { position = playerPosition, radius = Constants.PLAYER_RADIUS_COLLISION, isAlive = true }
        local collidedEnemies = self.collisionController:update(dt, activeEnemies, playerData)
        for _, enemy in ipairs(collidedEnemies) do
            local damageSource = TablePool.getDamageSource()
            damageSource.name = enemy.name
            damageSource.isBoss = enemy.isBoss
            damageSource.isMVP = enemy.isMVP
            damageSource.unitType = enemy.unitType
            -- self.playerManager:receiveDamage(enemy.damage, damageSource)
            TablePool.releaseDamageSource(damageSource)
        end

        self.movementController:update(dt, activeEnemies, playerPosition, mapInfo)
    end

    -- Loop de Atualização Base e Morte (para TODOS os inimigos)
    for i = #self.enemies, 1, -1 do
        local enemy = self.enemies[i]
        local isSlowUpdate = isEnemySlowLookup[enemy.id] or false

        if enemy.id == 1 then
            local isInView = self.cullingController:isInView(enemy, cameraData, worldDimensions,
                CONST.LOGIC_CULLING_MARGIN)
            Logger.debug("enemy_manager.update",
                string.format("[EnemyManager:update] Enemy ID 1: isInView = %s, isSlowUpdate = %s",
                    tostring(isInView), tostring(isSlowUpdate)))
        end

        enemy:update(dt, playerPosition, isSlowUpdate)

        if not enemy.isAlive then
            if not enemy.isDying then
                self:_onEnemyKilled(enemy)
                enemy.isDying = true -- Marca para não processar de novo
            end

            -- O próprio inimigo se marcará como 'shouldRemove' quando a animação de morte terminar.
            if enemy.shouldRemove then
                self.spatialGrid:removeEntityCompletely(enemy)
                -- TODO: Devolver ao pool em vez de apenas remover
                table.remove(self.enemies, i)
            end
        end
    end

    -- Despawn (processo final)
    local entitiesToDespawn = self.despawnController:updateAndGetEntitiesToDespawn(self.enemies, playerPosition, mapInfo)
    for i = #self.enemies, 1, -1 do
        local enemy = self.enemies[i]
        if entitiesToDespawn[enemy.id] then
            self.spatialGrid:removeEntityCompletely(enemy)
            table.remove(self.enemies, i)
        end
    end
end

---@public Retorna uma lista de inimigos proximos a uma posição.
--- TODO: Implementar a lógica de busca de inimigos pelo SpatialGrid
---@param position Vector2D
---@param radius number
---@return BaseEnemy[]
function EnemyManager:getNearbyEnemies(position, radius)
    -- Se não há inimigos, retorna lista vazia
    if not self.enemies or #self.enemies == 0 then
        return {}
    end

    -- Se não há spatialGrid, usa fallback com filtro manual por distância
    if not self.spatialGrid then
        Logger.warn("enemy_manager.getNearbyEnemies.no_spatial_grid",
            "[EnemyManager:getNearbyEnemies] SpatialGrid não disponível, usando filtro manual")
        local nearbyEnemies = {}
        local radiusSquared = radius * radius

        for _, enemy in ipairs(self.enemies) do
            if enemy and enemy.isAlive then
                local dx = enemy.position.x - position.x
                local dy = enemy.position.y - position.y
                local distanceSquared = dx * dx + dy * dy

                if distanceSquared <= radiusSquared then
                    table.insert(nearbyEnemies, enemy)
                end
            end
        end

        Logger.debug("enemy_manager.getNearbyEnemies.manual_filter",
            string.format("[EnemyManager:getNearbyEnemies] Filtro manual: %d/%d inimigos próximos",
                #nearbyEnemies, #self.enemies))
        return nearbyEnemies
    end

    -- Usa o spatialGrid para busca otimizada
    local nearbyEntities = self.spatialGrid:getNearbyEntities(position.x, position.y, radius)
    local nearbyEnemies = {}

    for _, entity in ipairs(nearbyEntities) do
        -- Verifica se a entidade é um inimigo válido
        if entity and entity.isAlive and entity.unitType then
            table.insert(nearbyEnemies, entity)
        end
    end

    Logger.debug("enemy_manager.getNearbyEnemies.spatial_grid",
        string.format("[EnemyManager:getNearbyEnemies] SpatialGrid: %d inimigos próximos em raio %.1f",
            #nearbyEnemies, radius))

    return nearbyEnemies
end

--- Lida com as consequências da morte de um inimigo.
---@param enemy BaseEnemy O inimigo que foi derrotado.
function EnemyManager:_onEnemyKilled(enemy)
    -- 1. Criar Orbs de Experiência
    -- if self.experienceOrbManager then
    --     self.experienceOrbManager:addOrb(enemy.position.x, enemy.position.y, enemy.experienceValue)
    -- end

    -- 2. Registrar Estatísticas
    local gameStatisticsManager = self.context.serviceLocator:getGameStatisticsService()
    gameStatisticsManager:registerEnemyDefeated(enemy:getEnemyType())

    -- 3. Notificar o Player (para sistema de poções, etc.)
    -- if self.playerManager and self.playerManager.onEnemyKilled then
    --     self.playerManager:onEnemyKilled()
    -- end

    -- 4. Lidar com drops de artefatos, etc. (futuro)
    -- if self.dropManager then
    --     self.dropManager:processDrops(enemy)
    -- end
end

---@param enemyClass table
function EnemyManager:spawnEnemy(enemyClass)
    local playerPos = self.playerManager:getPosition()

    -- Calcula um raio de spawn seguro, garantindo que seja sempre fora da tela.
    local screenW, screenH = ResolutionUtils.getGameDimensions()
    -- Raio da metade da diagonal da tela + uma margem de segurança.
    local spawnRadius = MathUtils.vectorLength(screenW / 2, screenH / 2) + 50

    local angle = math.random() * 2 * math.pi
    local x = playerPos.x + spawnRadius * math.cos(angle)
    local y = playerPos.y + spawnRadius * math.sin(angle)

    -- O ID será gerenciado pelo pool no futuro
    local newId = #self.enemies + 1
    local enemy = enemyClass:new({ x = x, y = y }, newId)
    Logger.debug(
        "EnemyManager:spawnEnemy",
        "Spawning enemy at x=" .. x .. ", y=" .. y .. " | Player at x=" .. playerPos.x .. ", y=" .. playerPos.y
    )
    table.insert(self.enemies, enemy)
    -- Adiciona a nova entidade ao grid espacial imediatamente
    self.spatialGrid:updateEntityInGrid(enemy)
    -- TODO: Adicionar ao CullingManager
end

--- Coleta os dados de renderização dos inimigos visíveis e os adiciona ao pipeline.
---@param renderPipeline RenderPipeline
function EnemyManager:collectRenderables(renderPipeline)
    -- Prepara os dados necessários para o culling, uma única vez por frame.
    local playerPos = self.playerManager:getPosition()
    local screenW, screenH = ResolutionUtils.getGameDimensions()
    local camX = playerPos.x - screenW / 2
    local camY = playerPos.y - screenH / 2
    local cameraData = { x = camX, y = camY, w = screenW, h = screenH }

    local worldW, worldH = self.mapManager:getWorldPixelDimensions()
    local worldDimensions = { w = worldW, h = worldH }

    for _, enemy in ipairs(self.enemies) do
        local shouldDraw = enemy.isAlive or (enemy.isDying and not enemy.isDeathAnimationComplete)
        if shouldDraw and self.cullingController:isInView(
                enemy,
                cameraData,
                worldDimensions,
                CONST.DRAW_CULLING_MARGIN
            ) then
            -- Adiciona o sprite principal do inimigo
            self:_collectEnemySprite(enemy, renderPipeline)

            -- Adiciona a barra de vida de MVP, se aplicável
            if enemy.isMVP and enemy.isAlive then
                self:_collectMvpBar(enemy, renderPipeline)
            end
        end
    end
end

---@param enemy BaseEnemy
---@param renderPipeline RenderPipeline
function EnemyManager:_collectEnemySprite(enemy, renderPipeline)
    local animState = enemy.sprite.animation
    if not animState then
        error("EnemyManager:_collectEnemySprite: animState is nil")
    end

    local currentAnimationKey = animState.isDead and animState.chosenDeathType or animState.activeMovementType
    if not currentAnimationKey then
        error("EnemyManager:_collectEnemySprite: currentAnimationKey is nil")
    end

    local assets = AnimatedSpritesheet.assets[enemy.unitType]
    if not assets then
        error("EnemyManager:_collectEnemySprite: assets is nil")
    end

    local batch = assets.sheets and assets.sheets[currentAnimationKey]
    local quads = assets.quads and assets.quads[currentAnimationKey]
    local maxFrames = assets.maxFrames and assets.maxFrames[currentAnimationKey]

    if not batch or not quads or not maxFrames or maxFrames == 0 then
        error("EnemyManager:_collectEnemySprite: batch, quads or maxFrames is nil")
    end

    local angleToDraw = animState.direction
    local quadsForAngle = quads[angleToDraw]

    if not quadsForAngle then
        error("EnemyManager:_collectEnemySprite: quadsForAngle is nil")
    end

    local maxFramesForCurrentAnim = assets.maxFrames and assets.maxFrames[currentAnimationKey]
    if not maxFramesForCurrentAnim or maxFramesForCurrentAnim == 0 then
        error("EnemyManager:_collectEnemySprite: maxFramesForCurrentAnim is nil")
    end

    local frameToDraw = animState.currentFrame
    if frameToDraw > maxFramesForCurrentAnim or frameToDraw <= 0 then
        frameToDraw = 1 -- Fallback para o primeiro frame
    end
    local quad = quadsForAngle[frameToDraw]

    if not quad then
        error("EnemyManager:_collectEnemySprite: quad is nil")
    end

    local baseUnitConfig = AnimatedSpritesheet.configs[enemy.unitType]
    local ox, oy
    if baseUnitConfig and baseUnitConfig.origin then
        ox = baseUnitConfig.origin.x
        oy = baseUnitConfig.origin.y
    else
        local _, _, q_w, q_h = quad:getViewport()
        ox = q_w / 2
        oy = q_h / 2
    end
    local sortY = enemy.position.y + oy * enemy.sprite.scale

    local rendable = TablePool.getArray()
    rendable.type = "enemy_sprite"
    rendable.sortY = sortY
    rendable.depth = RenderPipeline.DEPTH_ENTITIES
    rendable.texture = batch
    rendable.quad = quad
    rendable.x = enemy.position.x
    rendable.y = enemy.position.y
    rendable.scale = enemy.sprite.scale
    rendable.ox = ox
    rendable.oy = oy

    renderPipeline:add(rendable)
end

---@param enemy BaseEnemy
---@param renderPipeline RenderPipeline
function EnemyManager:_collectMvpBar(enemy, renderPipeline)
    local sortY = enemy.position.y + 1000 -- Garante que a barra fique sobre tudo
    local capturedEnemy = enemy

    local barRenderable = TablePool.getArray()
    barRenderable.type = "drawFunction"
    barRenderable.depth = RenderPipeline.DEPTH_EFFECTS_WORLD_UI
    barRenderable.sortY = sortY
    barRenderable.drawFunction = function(camX, camY)
        self:drawMvpBar(capturedEnemy, capturedEnemy.position.x - camX, capturedEnemy.position.y - camY)
    end
    renderPipeline:add(barRenderable)
end

--- Desenha a barra de vida e o nome de um inimigo MVP específico.
---@param enemy BaseEnemy O inimigo MVP a ser desenhado.
---@param x number Posição X na tela.
---@param y number Posição Y na tela.
function EnemyManager:drawMvpBar(enemy, x, y)
    -- Configurações
    local barWidth = 100
    local barHeight = 8
    local nameToBarSpacing = 4
    local spaceAboveSprite = 5

    -- Informações de Rank e Cor
    local titleData = enemy.mvpTitleData or { rank = "E", name = "MVP" }
    local rank = titleData.rank
    local rankColors = Colors.rankDetails[rank] or Colors.rankDetails["E"]

    -- 1. Preparar texto
    local fullName = string.format("%s, %s", enemy.mvpProperName or enemy.name, titleData.name)
    love.graphics.setFont(Fonts.main)
    local font = love.graphics.getFont()
    local _, wrappedLines = font:getWrap(fullName, barWidth)
    local textHeight = #wrappedLines * font:getHeight()

    -- 2. Calcular Posições
    local totalBlockHeight = textHeight + nameToBarSpacing + barHeight
    local spriteTopY = y - (enemy.radius or 32)
    local blockTopY = spriteTopY - spaceAboveSprite - totalBlockHeight
    local barX = x - (barWidth / 2)
    local barY = blockTopY + textHeight + nameToBarSpacing

    -- 3. Desenhar o Nome
    local currentTextY = blockTopY
    love.graphics.setColor(rankColors.text)
    for _, line in ipairs(wrappedLines) do
        local lineWidth = font:getWidth(line)
        love.graphics.print(line, x - (lineWidth / 2), currentTextY)
        currentTextY = currentTextY + font:getHeight()
    end

    -- 4. Desenhar a Barra de Vida
    local healthRatio = enemy.currentHealth / enemy.maxHealth
    love.graphics.setColor(Colors.bar_bg[1], Colors.bar_bg[2], Colors.bar_bg[3], 0.8)
    love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)
    if healthRatio > 0 then
        love.graphics.setColor(unpack(Colors.hp_fill))
        love.graphics.rectangle("fill", barX, barY, barWidth * healthRatio, barHeight)
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(unpack(Colors.bar_border))
    love.graphics.rectangle("line", barX, barY, barWidth, barHeight)

    love.graphics.setColor(1, 1, 1, 1)
end

--- Desenha o ID de um inimigo para fins de debug.
--- Esta função não faz mais a verificação de culling. Ela assume
--- que a cena que a chama já garantiu que o inimigo está visível.
---@param enemy BaseEnemy
function EnemyManager:_drawEnemyId(enemy)
    if not enemy or not enemy.id then return end

    local screenX, screenY = Camera:worldToScreen(enemy.position.x, enemy.position.y)

    love.graphics.setColor(Colors.white)
    love.graphics.setFont(Fonts.main) -- Usar uma fonte de debug se disponível
    love.graphics.print(tostring(enemy.id), enemy.position.x, enemy.position.y - 50)
end

function EnemyManager:destroy()
    self.enemies = {}
    self.spawnController:destroy()
    self.despawnController:destroy()
    self.separationController:destroy()
    self.collisionController:destroy()
    self.movementController:destroy()
    self.poolController:destroy()
    self.mvpController:destroy()
    self.repositionController:destroy()

    self.periodicTasks = {}

    Logger.info("enemy_manager.destroy.success", "[EnemyManager:destroy] destroyed successfully.")
end

--- Função privada para ser chamada pelo TimerTaskRunner
function EnemyManager:_runOptimizations()
    Logger.debug("EnemyManager", "Running periodic optimizations...")
    -- Lógica de otimização do SpatialGrid virá para cá
end

--- Retorna informações de debug sobre o estado do culling e dos inimigos.
---@return table
function EnemyManager:getDebugInfo()
    local activeCount = 0
    local slowCount = 0
    local totalCount = #self.enemies

    -- Reutiliza a lógica de culling para obter as contagens
    local playerPosition = self.playerManager:getPosition()
    local screenW, screenH = ResolutionUtils.getGameDimensions()
    local cameraData = {
        x = playerPosition.x - screenW / 2,
        y = playerPosition.y - screenH / 2,
        w = screenW,
        h = screenH
    }
    local worldW, worldH = self.mapManager:getWorldPixelDimensions()
    local worldDimensions = { w = worldW, h = worldH }

    for _, enemy in ipairs(self.enemies) do
        if enemy.isAlive then
            if self.cullingController:isInView(enemy, cameraData, worldDimensions, CONST.LOGIC_CULLING_MARGIN) then
                activeCount = activeCount + 1
            else
                slowCount = slowCount + 1
            end
        end
    end

    return {
        total = totalCount,
        active = activeCount,
        slow = slowCount,
    }
end

return EnemyManager
