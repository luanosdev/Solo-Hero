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
---@field focalPoint Vector2D|nil Ponto de foco do mundo para a câmera e renderização.
local GameplayScene = {}
GameplayScene.__index = GameplayScene

function GameplayScene:new()
    local instance = setmetatable({}, GameplayScene)
    instance.registry = nil
    instance.isPaused = false
    instance.renderPipeline = RenderPipeline:new()
    instance.focalPoint = nil
    return instance
end

function GameplayScene:load(args)
    Logger.info("gameplay_scene.load.start", "[GameplayScene:load] Starting gameplay scene loading...")
    assert(args and args.preloadedAssets, "GameplayScene requires 'preloadedAssets' in loading arguments.")

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
    ---@type InfinityWrapMapManagerV2
    local mapManager = self.registry:get("infinityWrapMapManager")

    -- Define o ponto de foco inicial e a posição da câmera.
    -- Sem um jogador, o centro do mapa é o nosso ponto de foco.
    local worldW, worldH = mapManager:getWorldPixelDimensions()
    self.focalPoint = { x = worldW / 2, y = worldH / 2 }

    -- Calcula a posição (canto superior esquerdo) da câmera para que o focalPoint fique no centro da tela.
    local camX = self.focalPoint.x - (ResolutionUtils.getGameWidth() / Camera.scale / 2)
    local camY = self.focalPoint.y - (ResolutionUtils.getGameHeight() / Camera.scale / 2)
    Camera:setPosition(camX, camY)

    -- 3b. Conectar managers ao RenderPipeline
    self.renderPipeline:setMapManager(mapManager)

    Logger.info("gameplay_scene.load.success", "[GameplayScene:load] Gameplay scene loaded and ready.")
end

function GameplayScene:update(dt)
    if not self.registry then return end

    -- A lógica de pause será reimplementada aqui, controlando o update do registry
    if not self.isPaused then
        self.registry:updateAll(dt)

        ---@type PlayerManagerV2
        local playerManager = self.registry:get("playerManager")
        if playerManager and playerManager.movementController then
            -- No futuro, o ponto de foco será a posição do jogador.
            self.focalPoint = playerManager.movementController:getPosition()
            Camera:follow(self.focalPoint, dt)
        end
    end

    -- Lógica de UI (LevelUpModal, Inventory, etc.) será adicionada aqui depois
end

function GameplayScene:draw()
    if not self.registry then return end

    Camera:attach()

    -- Limpa o pipeline para o novo frame
    self.renderPipeline:reset()

    -- Coleta todos os renderizáveis dos managers
    self.registry:collectAllRenderables(self.renderPipeline)

    -- Desenha tudo que foi coletado, usando o ponto de foco do mundo
    -- como referência, exatamente como na cena antiga.
    if self.focalPoint then
        -- LOG CRÍTICO PARA DEBUG
        Logger.debug("GameplayScene:draw",
            string.format("Passing focalPoint to RenderPipeline: (%.1f, %.1f)", self.focalPoint.x, self.focalPoint.y))
        self.renderPipeline:draw(self.focalPoint)

        -- DEBUG VISUAL: Desenha um marcador no focalPoint para vermos onde ele está no mundo
        love.graphics.setColor(1, 0, 1, 1) -- Roxo brilhante
        love.graphics.circle("fill", self.focalPoint.x, self.focalPoint.y, 20)
    end

    Camera:detach()

    -- DEBUG VISUAL: Imprime informações na tela (fora da influência da câmera)
    local defaultFont = love.graphics.getFont()
    local debugFont = love.graphics.newFont(12)
    love.graphics.setFont(debugFont)
    love.graphics.setColor(1, 1, 0, 1) -- Amarelo

    local camX, camY = Camera:getPosition()
    local focalX = self.focalPoint and self.focalPoint.x or "nil"
    local focalY = self.focalPoint and self.focalPoint.y or "nil"

    local debugText = string.format(
        "SCENE DRAW EXECUTING\nFocal Point: (%.1f, %.1f)\nCamera At: (%.1f, %.1f)",
        focalX, focalY, camX, camY
    )
    love.graphics.print(debugText, 10, 10)
    love.graphics.setColor(1, 1, 1, 1) -- Reseta a cor
    love.graphics.setFont(defaultFont) -- Reseta a fonte


    -- TODO: Adicionar desenho de UI que não é afetado pela câmera aqui
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
