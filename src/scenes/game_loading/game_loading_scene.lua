local SceneManager = require("src.core.scene_manager")
local GameLoadingUI = require("src.scenes.game_loading.ui.game_loading_ui")
local AnimationLoader = require("src.animations.animation_loader")
local Constants = require("src.config.constants")
local RenderPipeline = require("src.core.render_pipeline")
local ServiceLocator = require("src.core.service_locator")
local ExperienceOrbManager = require("src.scenes.gameplay.managers.experience_orb_manager")

--- Assets
local levelUpData = require("src.data.effects.level_up_data")

--- @class GameLoadingScene
--- @description Orquestra o carregamento assíncrono de ativos e gerencia o estado do processo de carregamento.
--- @field currentPortalData PortalData
--- @field loadingCoroutine thread
--- @field isComplete boolean
--- @field loadingState GameLoadingDrawData
--- @field currentTaskIndex number
--- @field totalTasks number
--- @field currentThematicData PortalData
--- @field currentTip string
--- @field loadingFunction function A função da corrotina, encapsulada pelo coroutine.wrap
--- @field renderPipeline RenderPipeline
local GameLoadingScene = {}
GameLoadingScene.__index = GameLoadingScene

GameLoadingScene.LOADING_TASKS = {
    MAP_ASSETS = "loading_map_assets",
    BAKE_MAP = "baking_map",
    SKILLS_ASSETS = "loading_skills_assets",
    ANIMATIONS = "loading_animations",
    PLAYER_SPRITES = "loading_player_sprites",
    PLAYER_EQUIPMENT = "loading_player_equipment",
    ENEMY_ASSETS = "loading_enemy_assets",
    SPRITE_BATCHES = "creating_sprite_batches",
    FINISHING_LOADING = "finishing_loading",
    IMAGE_ASSETS = "loading_image_assets",
}

function GameLoadingScene:new()
    local instance = setmetatable({}, GameLoadingScene)

    instance.loadingCoroutine = nil
    instance.isComplete = false
    instance.args = nil
    instance.renderPipeline = nil

    -- A tabela 'state' contém tudo que a UI precisa para se desenhar
    instance.loadingState = {
        progress = 0,
        currentTaskIndex = 0,
        totalTasks = 0,
        currentTask = GameLoadingScene.LOADING_TASKS.MAP_ASSETS,
        currentTip = "",
        portalRank = ""
    }

    return instance
end

---@param args GameLoadingSceneArgs
function GameLoadingScene:load(args)
    assert(args and args.portalData, "GameLoadingScene requires portalData.")

    self.args = args -- Armazena os argumentos para uso na corrotina
    self.currentPortalData = args.portalData
    self.loadingState.portalRank = self.currentPortalData.rank


    GameLoadingUI.init()
    self.isComplete = false
    self.loadingState.progress = 0
    self.renderPipeline = RenderPipeline:new()

    self.loadingFunction = coroutine.wrap(function() self:_runTasks() end)
end

function GameLoadingScene:update(dt)
    if self.isComplete then return end

    GameLoadingUI.update(dt) -- Atualiza a animação da UI

    if self.loadingFunction then
        -- Chama a função encapsulada. Ela vai rodar até o próximo yield.
        local finished, err = self.loadingFunction()

        if err then
            self.loadingFunction = nil
            self.isComplete = true
            error("Erro crítico na corrotina de carregamento: " .. tostring(err))
            return
        end

        if finished then
            self.loadingFunction = nil
            self.isComplete = true
        end
    end
end

function GameLoadingScene:draw()
    GameLoadingUI.draw(self.loadingState)
end

function GameLoadingScene:unload()
    GameLoadingUI.destroy()
    self.loadingFunction = nil
end

-- O método _initializeLoadingTasks foi removido.

function GameLoadingScene:_loadMapAssets()
    local MapAssetLoader = require("src.core.map_asset_loader")
    local loader = MapAssetLoader:new()
    local mapId = self.currentPortalData.mapId
    Logger.info("game_loading_scene._loadMapAssets", "Loading map assets for: " .. mapId)
    return loader:load(mapId)
end

function GameLoadingScene:_loadPlayerSprites()
    local SpritePlayer = require('src.animations.sprite_player')
    SpritePlayer._loadBodySprites()
    Logger.info("game_loading_scene._loadPlayerSprites", "Body player sprites loaded")
end

function GameLoadingScene:_loadPlayerEquipment()
    --- TODO: Esta função deve retornar os assets carregados em vez de depender de estado global.
    local SpritePlayer = require('src.animations.sprite_player')
    SpritePlayer._loadWeaponSprites()
    SpritePlayer._loadEquipmentSprites()
    Logger.info("game_loading_scene._loadPlayerEquipment", "Equipment player sprites loaded")
end

--- Carrega os assets dos inimigos necessários para o portal atual.
function GameLoadingScene:_loadEnemyAssets()
    if self.currentPortalData and self.currentPortalData.requiredUnitTypes then
        Logger.info("game_loading_scene._loadEnemyAssets.start", "Loading required enemy assets...")
        AnimationLoader.loadUnits(self.currentPortalData.requiredUnitTypes)
        Logger.info("game_loading_scene._loadEnemyAssets.end", "Enemy assets loaded.")
    else
        Logger.warn(
            "game_loading_scene._loadEnemyAssets",
            string.format(
                "Portal '%s' não possui requiredUnitTypes definidos",
                self.currentPortalData.id or "desconhecido"
            )
        )
    end
end

--- Carrega os assets de imagem necessários para o portal atual.
--- TODO: Da uma melhorada nessa função.
function GameLoadingScene:_loadImageAssets()
    local assetService = ServiceLocator:getAssetService()
    assetService:getImage(levelUpData.baseImagePath)
    assetService:getImage(levelUpData.overlayImagePath)
    assetService:getImage(ExperienceOrbManager.ASSETS.exp_orb)
end

--- Lógica da corrotina que executa as tarefas de carregamento de forma explícita e sequencial.
function GameLoadingScene:_runTasks()
    local preloadedAssets = {}
    local totalTasks = 5 -- Aumentado de 3 para 4 para incluir os inimigos

    -- Mock: Carregar o portal diretamente
    self.currentPortalData = require("src.data.portals.rank_e.001_undead_plains")
    self.loadingState.portalRank = self.currentPortalData.rank

    -- Tarefa 1: Carregar Mapa
    self.loadingState.currentTask = GameLoadingScene.LOADING_TASKS.MAP_ASSETS
    self.loadingState.progress = 0 / totalTasks
    local mapAssetsKey, mapAssets = self:_loadMapAssets()
    preloadedAssets[mapAssetsKey] = mapAssets
    coroutine.yield()

    -- Tarefa 2: Carregar Sprites do Jogador
    self.loadingState.currentTask = GameLoadingScene.LOADING_TASKS.PLAYER_SPRITES
    self.loadingState.progress = 1 / totalTasks
    self:_loadPlayerSprites() -- Esta tarefa não retorna assets
    coroutine.yield()

    -- Tarefa 3: Carregar Equipamento do Jogador
    self.loadingState.currentTask = GameLoadingScene.LOADING_TASKS.PLAYER_EQUIPMENT
    self.loadingState.progress = 2 / totalTasks
    self:_loadPlayerEquipment() -- Esta tarefa não retorna assets
    coroutine.yield()

    -- Tarefa 4: Carregar Assets dos Inimigos
    self.loadingState.currentTask = GameLoadingScene.LOADING_TASKS.ENEMY_ASSETS
    self.loadingState.progress = 3 / totalTasks
    self:_loadEnemyAssets()
    coroutine.yield()

    -- Tarefa 5: Criar SpriteBatches
    self.loadingState.currentTask = GameLoadingScene.LOADING_TASKS.SPRITE_BATCHES
    self.loadingState.progress = 3.5 / totalTasks
    local batchesDone = false
    while not batchesDone do
        batchesDone = self:_createSpriteBatchesChunked()
        coroutine.yield()
    end

    -- Tarefa 6: Carregar Assets de Imagem
    self.loadingState.currentTask = GameLoadingScene.LOADING_TASKS.IMAGE_ASSETS
    self.loadingState.progress = 4 / totalTasks
    self:_loadImageAssets()
    coroutine.yield()

    -- Finalização
    self.loadingState.progress = 1
    self.loadingState.currentTask = GameLoadingScene.LOADING_TASKS.FINISHING_LOADING
    coroutine.yield()
    love.timer.sleep(0.5)

    ---@type GameplaySceneArgs
    local gameplayArgs = {
        portalData = self.currentPortalData,
        hunterId = self.args.hunterId,
        preloadedAssets = preloadedAssets,
        renderPipeline = self.renderPipeline
    }

    SceneManager.goToGameplayScene(gameplayArgs)

    return true
end

--- Cria SpriteBatches em chunks para evitar travamentos
function GameLoadingScene:_createSpriteBatchesChunked()
    local maxSpritesInBatch = Constants.SPAWN_SYSTEM.MAX_ENEMIES_PER_BATCH
    local AnimatedSpritesheet = require("src.animations.animated_spritesheet")

    if AnimatedSpritesheet and AnimatedSpritesheet.assets then
        local allBatches = {}

        -- Prepara lista de todos os batches a serem criados
        if not self.totalBatches or self.totalBatches == 0 then
            self.totalBatches = 0
            self.currentBatchIndex = 0
            for unitType, unitAssets in pairs(AnimatedSpritesheet.assets) do
                if unitAssets.sheets then
                    for animName, sheetTexture in pairs(unitAssets.sheets) do
                        if sheetTexture then
                            table.insert(allBatches, { unitType = unitType, animName = animName, texture = sheetTexture })
                        end
                    end
                end
            end
            self.totalBatches = #allBatches
            self.allBatchesList = allBatches
        end

        -- Processa apenas um chunk de batches por vez
        local startIndex = self.currentBatchIndex + 1
        local endIndex = math.min(startIndex + Constants.SPAWN_SYSTEM.BATCH_CHUNK_SIZE - 1, self.totalBatches)

        for i = startIndex, endIndex do
            local batchData = self.allBatchesList[i]
            if batchData then
                -- Cria SpriteBatch para esta textura
                local newBatch = love.graphics.newSpriteBatch(batchData.texture, maxSpritesInBatch)
                self.renderPipeline:registerSpriteBatch(batchData.texture, newBatch)

                Logger.debug(
                    "game_loading_scene._createSpriteBatchesChunked" .. batchData.unitType,
                    string.format("Batch criado: %s-%s", batchData.unitType, batchData.animName)
                )
            end
        end

        self.currentBatchIndex = endIndex

        -- Retorna true se todos os batches foram processados
        return self.currentBatchIndex >= self.totalBatches
    end

    return true
end

return GameLoadingScene
