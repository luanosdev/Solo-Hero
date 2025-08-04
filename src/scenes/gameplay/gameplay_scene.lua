--------------------------------------------------------------------------------
--- GameplayScene (v2)
--- @description Cena principal do jogo, orquestradora da sessão de gameplay.
--- Esta versão utiliza a nova arquitetura de bootstrap e registry por cena.
--------------------------------------------------------------------------------

local GameplayBootstrap = require("src.scenes.gameplay.gameplay_bootstrap")
local RenderPipeline = require("src.core.render_pipeline")
local Camera = require("src.config.camera")
local ServiceLocator = require("src.core.service_locator")

--- TODO: Remover o v2 quando o v1 for removido
---@class GameplaySceneV2
---@field registry SceneManagerRegistry|nil
--- Propriedades que virão da cena de carregamento
---@field renderPipeline RenderPipeline
---@field preloadedAssets table
---@field portalId string
local GameplayScene = {}
GameplayScene.__index = GameplayScene

function GameplayScene:load(args)
    Logger.info("gameplay_scene.load.start", "[GameplayScene:load] Starting gameplay scene loading...")
    assert(args and args.preloadedAssets, "GameplayScene requires 'preloadedAssets' in loading arguments.")

    -- Inicia o timer global da sessão de jogo
    local gameTimerService = ServiceLocator.getGameTimerService()
    gameTimerService:start()

    local gameStatisticsService = ServiceLocator.getGameStatisticsService()
    gameStatisticsService:start(gameTimerService)

    -- Carrega dependências externas (da cena de loading)
    self.preloadedAssets = args.preloadedAssets
    self.portalId = args.portalId
    self.hunterId = args.hunterId
    self.renderPipeline = args.renderPipeline

    -- Inicializa o bootstrap da cena, passando o pipeline
    ---@type GameplayBootstrapParams
    local context = {
        renderPipeline = self.renderPipeline,
        preloadedAssets = self.preloadedAssets,
        serviceLocator = ServiceLocator,
        args = args,
    }

    local gameplayContext = GameplayBootstrap.initialize(context)
    self.registry = gameplayContext.registry

    -- Configura sistemas que dependem dos managers
    local playerManager = self.registry:getPlayerManager()
    local mapManager = self.registry:getMapManager()

    -- Configura o pipeline de renderização
    self.renderPipeline:setMapManager(mapManager)

    -- Inicializa a câmera
    Camera:init()

    -- Define a posição inicial da câmera com base na posição inicial do jogador.
    Logger.info("gameplay_scene.load.player_position",
        "[GameplayScene:load] Definindo posição inicial do jogador...")

    --mapManager:setPlayerOnWorldCenter()

    -- local playerInitialPosition = playerManager:getPosition()
    -- local camX = playerInitialPosition.x - (Camera.screenWidth / Camera.scale / 2)
    -- local camY = playerInitialPosition.y - (Camera.screenHeight / Camera.scale / 2)
    -- Camera:setPosition(camX, camY)

    -- A conexão com o RenderPipeline foi removida, o desenho do mapa é explícito.

    -- Inicializa o componente de debug
    -- Valida se o registry foi carregado corretamente
    if not self.registry then
        error("[GameplayScene:load] Failed to initialize registry.")
    else
        Logger.info("gameplay_scene.load.registry.success", "[GameplayScene:load] Registry loaded successfully.")
    end

    Logger.info("gameplay_scene.load.success", "[GameplayScene:load] Gameplay scene loaded and ready.")
end

function GameplayScene:update(dt)
    -- BLINDAGEM: Não executa a lógica de update se a cena não foi totalmente carregada.
    if not self.registry then
        Logger.error("gameplay_scene.update.error", "[GameplayScene:update] Registry is nil.")
        return
    end

    ---@type GameStateManager A pausa do jogo é controlada pelo GameStateManager.
    local gameStateManager = self.registry:get("gameStateManager")
    if not gameStateManager:isPaused() then
        self.registry:updateAll(dt)

        local playerManager = self.registry:getPlayerManager()
        if playerManager then
            Camera:follow(playerManager:getPosition(), dt)
        end
    end

    -- Lógica de UI (LevelUpModal, Inventory, etc.) será adicionada aqui depois
end

function GameplayScene:draw()
    -- BLINDAGEM: Não executa a lógica de desenho se a cena não foi totalmente carregada.
    if not self.registry then
        Logger.error("gameplay_scene.draw.error", "[GameplayScene:draw] Registry is nil.")
        return
    end

    Camera:attach()

    -- Reset do pipeline
    self.renderPipeline:reset()

    -- Coleta todos os renderizáveis dos managers
    self.registry:collectAllRenderables(self.renderPipeline)

    -- Desenha tudo que foi coletado, usando a posição do jogador como foco.
    self.renderPipeline:draw()

    -- Desenha o texto de debug para o inimigo com ID
    local enemyManager = self.registry:getEnemyManager()
    local enemies = enemyManager.enemies
    if enemies then
        for _, enemy in ipairs(enemies) do
            enemyManager:_drawEnemyId(enemy)
        end
    end

    Camera:detach()

    ---@type HUDGameplayManager
    local hudGameplayManager = self.registry:get("hudGameplayManager")
    if hudGameplayManager then
        hudGameplayManager:draw()
    end
end

function GameplayScene:keypressed(key, scancode, isrepeat)
    -- Debug toggle para o mapa infinito
    if key == "f3" then
        -- local mapManager = self.registry and self.registry:get("infinityWrapMapManager") -- Desativado
        -- if mapManager and mapManager.toggleDebug then
        --     mapManager:toggleDebug()
        -- end
    end
end

function GameplayScene:unload()
    Logger.info("gameplay_scene.unload.start", "[GameplayScene:unload] Unloading gameplay scene...")
    if self.registry then
        GameplayBootstrap.destroy(self.registry)
        self.registry = nil
    end

    -- Limpa o componente de debug
    if self.debugMapInfo then
        self.debugMapInfo = nil
    end

    Logger.info("gameplay_scene.leave.success", "[GameplayScene:leave] Gameplay scene resources cleaned.")
end

return GameplayScene
