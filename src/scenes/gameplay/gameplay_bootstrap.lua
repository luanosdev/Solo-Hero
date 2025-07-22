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
local CullingManager = require("src.managers.culling_manager")
local SceneManagerRegistry = require("src.core.scene_manager_registry")

---@class GameplayBootstrap
local GameplayBootstrap = {}

--- Inicializa todos os managers para uma nova sessão de gameplay.
--- @param args GameplaySceneArgs Os dados do portal para esta sessão.
--- @param renderPipeline RenderPipeline A instância do pipeline de renderização da cena.
--- @return SceneManagerRegistry instance Uma instância do registry populada com todos os managers da cena.
function GameplayBootstrap.initialize(args, renderPipeline)
    Logger.info(
        "gameplay_bootstrap.initialize.start",
        "[GameplayBootstrap:initialize] Initializing gameplay session managers..."
    )
    assert(renderPipeline, "GameplayBootstrap.initialize requires a RenderPipeline instance.")

    local registry = SceneManagerRegistry:new()

    -- Definição dos managers a serem carregados
    local managersToLoad = {
        -- Passa o pipeline para os managers que precisam dele
        playerManager = { class = PlayerManager, needsPipeline = true },
        infinityWrapMapManager = { class = InfinityWrapMapManager, needsPipeline = true },
        enemyManager = { class = EnemyManager, needsPipeline = true },
        -- CullingManager não desenha, então não precisa do pipeline
        cullingManager = { class = CullingManager, needsPipeline = false },
    }

    ---@type table<string, any>
    local instances = {}

    --== FASE 1: CONSTRUÇÃO ==--
    Logger.info(
        "gameplay_bootstrap.initialize.phase_1",
        "[GameplayBootstrap:initialize] Constructing manager instances..."
    )
    for key, def in pairs(managersToLoad) do
        Logger.debug("GameplayBootstrap:initialize", "  -> Construindo: " .. key)
        local instance
        if def.needsPipeline then
            instance = def.class:new(registry, renderPipeline)
        else
            instance = def.class:new(registry)
        end
        instances[key] = instance
        Logger.debug("GameplayBootstrap:initialize", "  -- Construído: " .. key)
    end

    --== FASE 2: REGISTRO ==--
    Logger.info(
        "gameplay_bootstrap.initialize.phase_2",
        "[GameplayBootstrap:initialize] Registering manager instances..."
    )
    for key, instance in pairs(instances) do
        registry:register(key, instance)
    end

    --== FASE 3: INICIALIZAÇÃO (init) ==--
    Logger.info("gameplay_bootstrap.initialize.phase_3", "[GameplayBootstrap:initialize] Initializing managers...")
    for key, instance in pairs(instances) do
        Logger.debug("GameplayBootstrap:initialize", "  -> Inicializando: " .. key)
        if type(instance.init) == "function" then
            instance:init(args)
        else
            Logger.error(
                "gameplay_bootstrap.initialize.phase_3.error",
                "[GameplayBootstrap:initialize] Manager '" .. instance.name .. "' does not have an :init() method."
            )
        end
        Logger.debug("GameplayBootstrap:initialize", "  -- Inicializado: " .. key)
    end

    --== FASE 4: SETUP DE GAMEPLAY ==--
    Logger.info("gameplay_bootstrap.initialize.phase_4", "[GameplayBootstrap:initialize] Setting up gameplay data...")
    local enemyManager = registry:get("enemyManager")
    if enemyManager and enemyManager.setupGameplay then
        enemyManager:setupGameplay(args.portalData.hordeConfig)
    end

    Logger.info(
        "gameplay_bootstrap.initialize.success",
        "[GameplayBootstrap:initialize] All gameplay managers initialized successfully."
    )
    return registry
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
