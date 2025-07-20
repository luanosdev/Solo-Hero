--- Este módulo é o coração da inicialização da cena de gameplay.
-- Ele implementa o ciclo de vida da nova arquitetura para garantir
-- que não haja condições de corrida na inicialização dos managers.
--
-- CICLO DE VIDA:
-- 1. CONSTRUÇÃO (:new)   -> Todos os managers são instanciados.
-- 2. REGISTRO (register) -> Todas as instâncias são adicionadas ao registry.
-- 3. INICIALIZAÇÃO (:init) -> O método :init() de cada manager é chamado.

local SceneManagerRegistry = require("src.core.scene_manager_registry")

-- Managers que seguem a NOVA arquitetura (baseados em classe/instância)
local EnemyManager = require("src.scenes.gameplay.managers.enemy_manager")
local CullingManager = require("src.managers.culling_manager")

---@class GameplayBootstrap
local GameplayBootstrap = {}

--- Inicializa todos os managers para uma nova sessão de gameplay.
--- @return SceneManagerRegistry registry Uma instância do registry populada com todos os managers da cena.
function GameplayBootstrap.initialize()
    Logger.info(
        "gameplay_bootstrap.initialize.start",
        "[GameplayBootstrap:initialize] Initializing gameplay session managers..."
    )

    local registry = SceneManagerRegistry:new()

    -- Definição dos managers a serem carregados
    local managersToLoad = {
        enemyManager = { class = EnemyManager },
        cullingManager = { class = CullingManager },
    }

    ---@type table<string, any>
    local instances = {}

    --== FASE 1: CONSTRUÇÃO ==--
    Logger.info(
        "gameplay_bootstrap.initialize.phase_1",
        "[GameplayBootstrap:initialize] Constructing manager instances..."
    )
    for key, def in pairs(managersToLoad) do
        local instance = def.class:new(registry)
        instances[key] = instance
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
    for _, instance in pairs(instances) do
        if type(instance.init) == "function" then
            instance:init()
        else
            Logger.error(
                "gameplay_bootstrap.initialize.phase_3.error",
                "[GameplayBootstrap:initialize] Manager '" .. instance.name .. "' does not have an :init() method."
            )
        end
    end

    Logger.info(
        "gameplay_bootstrap.initialize.success",
        "[GameplayBootstrap:initialize] All gameplay managers initialized successfully."
    )
    return registry
end

---
-- Destrói todos os managers da sessão de gameplay.
-- @param registry SceneManagerRegistry A instância do registry a ser limpa.
function GameplayBootstrap.destroy(registry)
    Logger.info("gameplay_bootstrap.destroy.start", "[GameplayBootstrap:destroy] Destroying gameplay managers...")
    if not registry then return end

    local allManagers = registry:getAll()
    for _, instance in pairs(allManagers) do
        if type(instance.destroy) == "function" then
            instance:destroy()
        else
            Logger.error(
                "gameplay_bootstrap.destroy.error",
                "[GameplayBootstrap:destroy] Manager '" .. instance.name .. "' does not have a :destroy() method."
            )
        end
    end
    registry:clear()
    Logger.info("gameplay_bootstrap.destroy.success", "[GameplayBootstrap:destroy] Gameplay managers destroyed.")
end

return GameplayBootstrap
