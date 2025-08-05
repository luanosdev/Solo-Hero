--- Este módulo é o coração da inicialização da cena de gameplay.
-- Ele implementa o ciclo de vida da nova arquitetura para garantir
-- que não haja condições de corrida na inicialização dos managers.
--
-- CICLO DE VIDA:
-- 1. CONSTRUÇÃO (:new)   -> Todos os managers são instanciados.
-- 2. REGISTRO (register) -> Todas as instâncias são adicionadas ao registry.
-- 3. INICIALIZAÇÃO (:init) -> O método :init() de cada manager é chamado.
-- Managers que seguem a NOVA arquitetura (baseados em classe/instância)
local EnemyManager = require("src.scenes.gameplay.managers.enemy_manager")
local PlayerManager = require("src.scenes.gameplay.managers.player_manager")
local InfinityWrapMapManager = require("src.scenes.gameplay.managers.infinity_wrap_map_manager")
local SceneManagerRegistry = require("src.core.scene_manager_registry")
local HUDGameplayManager = require("src.scenes.gameplay.managers.hud_gameplay_manager")
local DamageNumberManager = require("src.scenes.gameplay.managers.damage_number_manager")
local ExperienceOrbManager = require("src.scenes.gameplay.managers.experience_orb_manager")
local LevelUpManager = require("src.scenes.gameplay.managers.level_up_manager")
local GameStateManager = require("src.scenes.gameplay.managers.game_state_manager")

---@class GameplayBootstrap
local GameplayBootstrap = {}

---@class GameplayBootstrapParams
---@field renderPipeline RenderPipeline
---@field serviceLocator ServiceLocator
---@field args GameplaySceneArgs

--- Inicializa todos os managers para uma nova sessão de gameplay.
--- @param context GameplayBootstrapParams Os dados do portal para esta sessão.
--- @return GameplaySceneContext context Uma instância do contexto de gameplay populada com todos os managers da cena.
function GameplayBootstrap.initialize(context)
    Logger.info(
        "gameplay_bootstrap.initialize.start",
        "[GameplayBootstrap:initialize] Initializing gameplay session managers..."
    )
    assert(context.renderPipeline, "GameplayBootstrap.initialize requires a RenderPipeline instance.")

    local registry = SceneManagerRegistry:new()

    ---@type GameplaySceneContext
    local gameplaySceneContext = {
        registry = registry,
        renderPipeline = context.renderPipeline,
        serviceLocator = context.serviceLocator,
        args = context.args
    }

    -- Definição dos managers a serem carregados em ordem explícita de inicialização.
    -- O mapa DEVE ser inicializado antes do jogador e dos inimigos.
    local managersToLoad = {
        {
            key = "gameStateManager",
            class = GameStateManager,
            isPausable = false,
        },
        {
            key = "playerManager",
            class = PlayerManager,
            isPausable = true,
        },
        {
            key = "mapManager",
            class = InfinityWrapMapManager,
            isPausable = true,
        },
        {
            key = "enemyManager",
            class = EnemyManager,
            isPausable = true,
        },
        {
            key = "damageNumberManager",
            class = DamageNumberManager,
            isPausable = true,
        },
        {
            key = "experienceOrbManager",
            class = ExperienceOrbManager,
            isPausable = true,
        },
        {
            key = "levelUpManager",
            class = LevelUpManager,
            isPausable = true,
        },
        {
            key = "hudGameplayManager",
            class = HUDGameplayManager,
            isPausable = false,
        },
    }

    ---@type table<string, any>
    local instances = {}

    --== FASE 1: CONSTRUÇÃO ==--
    Logger.info(
        "gameplay_bootstrap.initialize.phase_1",
        "[GameplayBootstrap:initialize] Constructing manager instances..."
    )
    for _, def in ipairs(managersToLoad) do
        Logger.debug("GameplayBootstrap:initialize", "  -> Construindo: " .. def.key)
        instances[def.key] = def.class:new(gameplaySceneContext)
        Logger.debug("GameplayBootstrap:initialize", "  -- Construído: " .. def.key)
    end

    --== FASE 2: REGISTRO ==--
    Logger.info(
        "gameplay_bootstrap.initialize.phase_2",
        "[GameplayBootstrap:initialize] Registering manager instances..."
    )
    for _, def in ipairs(managersToLoad) do
        registry:register(def.key, instances[def.key], def.isPausable)
    end

    --== FASE 3: INICIALIZAÇÃO (init) ==--
    -- A inicialização agora segue a ordem explícita de managersToLoad
    Logger.info("gameplay_bootstrap.initialize.phase_3", "[GameplayBootstrap:initialize] Initializing managers...")
    for _, def in ipairs(managersToLoad) do
        local key = def.key
        local instance = instances[key]

        Logger.debug("GameplayBootstrap:initialize", "  -> Inicializando: " .. key)
        if type(instance.init) == "function" then
            instance:init()
        else
            Logger.error(
                "gameplay_bootstrap.initialize.phase_3.error",
                "[GameplayBootstrap:initialize] Manager '" .. instance.name .. "' does not have an :init() method."
            )
        end
        Logger.debug("GameplayBootstrap:initialize", "  -- Inicializado: " .. key)
    end

    return gameplaySceneContext
end

--- Destrói todos os managers da sessão de gameplay.
--- @param registry SceneManagerRegistry A instância do registry a ser limpa.
function GameplayBootstrap.destroy(registry)
    Logger.info("gameplay_bootstrap.destroy.start", "[GameplayBootstrap:destroy] Destroying gameplay managers...")
    if not registry then return end

    local allManagers = registry:getAll()
    for managerName, instance in pairs(allManagers) do
        if type(instance.destroy) == "function" then
            instance:destroy()
        else
            -- log com nome da instancia
            Logger.error(
                "gameplay_bootstrap.destroy.error",
                "[GameplayBootstrap:destroy] Manager '" .. managerName .. "' does not have a :destroy() method."
            )
        end
    end
    registry:clear()
    Logger.info("gameplay_bootstrap.destroy.success", "[GameplayBootstrap:destroy] Gameplay managers destroyed.")
end

return GameplayBootstrap
