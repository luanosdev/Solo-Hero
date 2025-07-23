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
---@field isPaused boolean
--- Propriedades que virão da cena de carregamento
---@field renderPipeline RenderPipeline
---@field preloadedAssets table
---@field portalId string
local GameplayScene = {}
GameplayScene.__index = GameplayScene

function GameplayScene:load(args)
    Logger.info("gameplay_scene.load.start", "[GameplayScene:load] Starting gameplay scene loading...")
    assert(args and args.preloadedAssets, "GameplayScene requires 'preloadedAssets' in loading arguments.")

    self.isPaused = false
    self.renderPipeline = RenderPipeline:new()

    -- Inicia o timer global da sessão de jogo
    ---@type GameTimerService
    local gameTimerService = ServiceLocator.get("gameTimerService")
    gameTimerService:start()

    -- 1. Carregar dependências externas (da cena de loading)
    self.preloadedAssets = args.preloadedAssets
    self.portalId = args.portalId
    self.hunterId = args.hunterId

    -- 2. Inicializar o bootstrap da cena, passando o pipeline
    self.registry = GameplayBootstrap.initialize(args, self.renderPipeline)

    -- 3. Configurar sistemas que dependem dos managers
    ---@type PlayerManagerV2
    local playerManager = self.registry:get("playerManager")
    ---@type InfinityWrapMapManagerV2
    local mapManager = self.registry:get("infinityWrapMapManager")

    -- Define a posição inicial da câmera com base na posição inicial do jogador.
    local playerInitialPosition = playerManager:getPosition()
    local camX = playerInitialPosition.x - (ResolutionUtils.getGameWidth() / Camera.scale / 2)
    local camY = playerInitialPosition.y - (ResolutionUtils.getGameHeight() / Camera.scale / 2)
    Camera:setPosition(camX, camY)

    -- A conexão com o RenderPipeline foi removida, o desenho do mapa é explícito.

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

    -- A lógica de pause será reimplementada aqui, controlando o update do registry
    if not self.isPaused then
        self.registry:updateAll(dt)

        ---@type PlayerManagerV2
        local playerManager = self.registry:get("playerManager")
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

    -- Pega a posição do jogador UMA VEZ por frame para garantir consistência.
    ---@type PlayerManagerV2
    local playerManager = self.registry:get("playerManager")
    local playerPosition = playerManager and playerManager:getPosition()
    ---@type InfinityWrapMapManagerV2
    local mapManager = self.registry:get("infinityWrapMapManager")

    Camera:attach()

    -- 1. Desenha as camadas de baixo do mapa
    if mapManager and playerPosition then
        mapManager:draw()
    end

    -- 2. Limpa e processa o pipeline para entidades (jogador, inimigos, drops)
    self.renderPipeline:reset()
    -- NOTA: O mapa não é mais coletado aqui
    self.registry:collectAllRenderables(self.renderPipeline)
    if playerPosition then
        self.renderPipeline:draw(playerPosition)
    end

    -- 3. Desenha as camadas de cima do mapa
    if mapManager and playerPosition then
        mapManager:drawTopLayers()
    end

    Camera:detach()
end

function GameplayScene:keypressed(key, scancode, isrepeat)
    -- A lógica de input será delegada para o InputManager através do registry
end

function GameplayScene:mousepressed(x, y, button, istouch, presses)
    -- A lógica de input será delegada para o InputManager através do registry
end

function GameplayScene:mousereleased(x, y, button, istouch, presses)
    -- A lógica de input será delegada para o InputManager através do registry
end

function GameplayScene:unload()
    Logger.info("gameplay_scene.unload.start", "[GameplayScene:unload] Unloading gameplay scene...")
    if self.registry then
        GameplayBootstrap.destroy(self.registry)
        self.registry = nil
    end
    Logger.info("gameplay_scene.leave.success", "[GameplayScene:leave] Gameplay scene resources cleaned.")
end

return GameplayScene
