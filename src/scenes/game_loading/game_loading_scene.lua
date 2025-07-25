local SceneManager = require("src.core.scene_manager")
local GameLoadingUI = require("src.scenes.game_loading.ui.game_loading_ui")

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
    FINISHING_LOADING = "finishing_loading",
}

function GameLoadingScene:new()
    local instance = setmetatable({}, GameLoadingScene)

    instance.loadingCoroutine = nil
    instance.isComplete = false
    instance.args = nil

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
    local mapId = self.currentPortalData.id
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

--- Lógica da corrotina que executa as tarefas de carregamento de forma explícita e sequencial.
function GameLoadingScene:_runTasks()
    local preloadedAssets = {}
    local totalTasks = 3 -- Definido manualmente para simplicidade

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

    -- Finalização
    self.loadingState.progress = 1
    self.loadingState.currentTask = GameLoadingScene.LOADING_TASKS.FINISHING_LOADING
    coroutine.yield()
    love.timer.sleep(0.5)

    local gameplayArgs = {
        portalData = self.currentPortalData,
        hunterId = self.args.hunterId,
        preloadedAssets = preloadedAssets
    }
    SceneManager.goToGameplayScene(gameplayArgs)

    return true
end

-- Mantém a compatibilidade com a arquitetura antiga, onde o arquivo retorna a instância.
local sceneInstance = GameLoadingScene:new()
return sceneInstance
