--------------------------------------------------------------------------------
--- GameplayScene (v2)
--- @description Cena principal do jogo, orquestradora da sessão de gameplay.
--- Esta versão utiliza a nova arquitetura de bootstrap e registry por cena.
--------------------------------------------------------------------------------

local GameplayBootstrap = require("src.scenes.gameplay.gameplay_bootstrap")
local Camera = require("src.config.camera")

--- TODO: Remover o v2 quando o v1 for removido
---@class GameplaySceneV2
---@field registry SceneManagerRegistry|nil
---@field isPaused boolean
--- Propriedades que virão da cena de carregamento
---@field renderPipeline RenderPipeline
---@field mapManager InfinityWrapMapManager
---@field portalId string
---@field hunterId string
local GameplayScene = {}
GameplayScene.__index = GameplayScene

function GameplayScene:new()
    local instance = setmetatable({}, GameplayScene)
    instance.registry = nil
    instance.isPaused = false
    return instance
end

function GameplayScene:load(args)
    Logger.info("gameplay_scene.load.start", "[GameplayScene:load] Starting gameplay scene loading...")
    assert(args and args.mapManager, "GameplayScene requires 'mapManager' in loading arguments.")

    -- 1. Carregar dependências externas (da cena de loading)
    self.mapManager = args.mapManager
    self.renderPipeline = args.renderPipeline
    self.portalId = args.portalId
    self.hunterId = args.hunterId

    -- 2. Inicializar o bootstrap da cena
    -- O bootstrap é responsável por criar e inicializar todos os managers da cena
    self.registry = GameplayBootstrap.initialize()

    -- 3. Configurar sistemas que dependem dos managers
    ---@type PlayerManager
    local playerManager = self.registry:get("playerManager")
    local playerInitialPos = playerManager:getPlayerPosition()
    if playerInitialPos then
        Camera:setPosition(playerInitialPos.x, playerInitialPos.y)
    end

    Logger.info("gameplay_scene.load.success", "[GameplayScene:load] Gameplay scene loaded and ready.")
end

function GameplayScene:update(dt)
    if not self.registry then return end

    -- A lógica de pause será reimplementada aqui, controlando o update do registry
    if not self.isPaused then
        self.registry:updateAll(dt)
        self.mapManager:update(dt) -- O mapa ainda é controlado externamente

        ---@type PlayerManager
        local playerManager = self.registry:get("playerManager")
        if playerManager and playerManager.movementController then
            Camera:follow(playerManager.movementController:getPosition(), dt)
        end
    end

    -- Lógica de UI (LevelUpModal, Inventory, etc.) será adicionada aqui depois
end

function GameplayScene:draw()
    if not self.registry then return end

    self.renderPipeline:reset()

    ---@type PlayerManager
    local playerManager = self.registry:get("playerManager")

    -- Coletar renderizáveis de todos os managers
    -- Esta parte será refatorada para ser mais elegante
    local managers = self.registry:getAll()
    for _, manager in pairs(managers) do
        if manager.collectRenderables then
            manager:collectRenderables(self.renderPipeline)
        end
    end

    Camera:attach()
    if playerManager and playerManager.movementController then
        self.renderPipeline:draw(playerManager.movementController:getPosition())
    end
    self.registry:drawAllInCamera() -- Para debug ou efeitos especiais na câmera
    Camera:detach()

    -- Lógica de UI (HUD, Modais, etc) será adicionada aqui depois
    self.registry:drawAll() -- Desenha managers de UI que ficam fora da câmera
end

function GameplayScene:keypressed(key, scancode, isrepeat)
    if not self.registry then return end
    -- A lógica de input será delegada para o InputManager através do registry
end

function GameplayScene:mousepressed(x, y, button, istouch, presses)
    if not self.registry then return end
    -- A lógica de input será delegada para o InputManager através do registry
end

function GameplayScene:mousereleased(x, y, button, istouch, presses)
    if not self.registry then return end
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

return GameplayScene:new()
