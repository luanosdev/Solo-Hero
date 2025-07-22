---------------------------------------------------------------------------
--- EnemyManager
--- @description Gerencia a criação, atualização e destruição dos inimigos.
---------------------------------------------------------------------------

local ServiceLocator = require("src.core.service_locator")

--- TODO: Remover o v2 quando o v1 for removido
---@class EnemyManagerv2
---@field registry SceneManagerRegistry
---@field renderPipeline RenderPipeline
---@field playerManager PlayerManager
---@field dropManager DropManager
---@field cullingManager CullingManager
---@field mapManager InfinityWrapMapManager
---@field enemies BaseEnemy[]
---@field spawnController SpawnController
---@field despawnController DespawnController
---@field poolController EnemyPoolController
---@field mvpController MVPController
---@field separationController EnemySeparationController
---@field repositionController MVPRepositionController
---@field periodicTasks table<number, TimerTaskRunner|FrameTaskRunner>
local EnemyManager = {}
EnemyManager.__index = EnemyManager

local EnemyPoolController = require("src.scenes.gameplay.controllers.enemy_pool_controller")
local MVPController = require("src.scenes.gameplay.controllers.mvp_controller")
local EnemySeparationController = require("src.scenes.gameplay.controllers.enemy_separation_controller")
local MVPRepositionController = require("src.scenes.gameplay.controllers.mvp_reposition_controller")
local TimerTaskRunner = require("src.core.timer_task_runner")
-- local FrameTaskRunner = require("src.core.frame_task_runner") -- Se for usar

---@param registry SceneManagerRegistry
---@return EnemyManagerv2
function EnemyManager:new(registry, renderPipeline)
    assert(registry, "[EnemyManager] missing a ManagerRegistry")

    local instance = setmetatable({}, EnemyManager)
    instance.registry = registry
    instance.renderPipeline = renderPipeline
    instance.enemies = {}

    return instance
end

function EnemyManager:init()
    Logger.info("enemy_manager.init", "[EnemyManager:init] Initializing...")
    -- Obter dependências do registry
    self.playerManager = self.registry:get("playerManager")
    --self.dropManager = self.registry:get("dropManager")
    self.cullingManager = self.registry:get("cullingManager")
    --self.mapManager = self.registry:get("mapManager")

    -- Inicializar os controllers
    self.poolController = EnemyPoolController:new()
    self.mvpController = MVPController:new()
    self.separationController = EnemySeparationController:new()
    self.repositionController = MVPRepositionController:new()

    self.poolController:init()
    self.mvpController:init()
    self.separationController:init()
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

--- Configura o manager com os dados específicos da horda para a sessão de gameplay.
---@param hordeConfig HordeConfigData
function EnemyManager:setupGameplay(hordeConfig)
    assert(hordeConfig, "[EnemyManager:setupGameplay] HordeConfig is required.")
    --self.spawnController:setup(hordeConfig)
    Logger.info("enemy_manager.setupGameplay.success", "[EnemyManager] Gameplay setup complete.")
end

---@param dt number
function EnemyManager:update(dt)
    -- Atualizar tarefas periódicas
    for _, task in ipairs(self.periodicTasks) do
        task:update(dt)
    end

    local gameTimerService = ServiceLocator.get("gameTimerService")
    local gameTime = gameTimerService:getTime()
    --self.spawnController:update(dt, gameTime)
    -- self.despawnController:update(dt)
    -- self.separationController:update(dt)

    for i = #self.enemies, 1, -1 do
        local enemy = self.enemies[i]
        -- enemy:update(dt)
        if not enemy.isAlive then
            table.remove(self.enemies, i)
        end
    end
end

function EnemyManager:draw()
    for _, enemy in ipairs(self.enemies) do
        -- enemy:draw()
    end
end

function EnemyManager:destroy()
    self.enemies = {}
    -- self.spawnController:destroy()
    -- self.despawnController:destroy()
    -- self.separationController:destroy()
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

return EnemyManager
