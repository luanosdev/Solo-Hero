---@class EnemySpawnController
---@description Interpreta a configuração de horda e orquestra o spawn de inimigos.
local EnemySpawnController = {}
EnemySpawnController.__index = EnemySpawnController

local TimerTaskRunner = require("src.core.timer_task_runner")
local FrameTaskRunner = require("src.core.frame_task_runner")

function EnemySpawnController:new()
    local instance = setmetatable({}, EnemySpawnController)
    instance.hordeConfig = nil
    instance.currentPhaseIndex = 0
    instance.phaseTimer = 0
    instance.taskRunners = {} -- Lista para guardar todos os task runners da fase atual

    Logger.info("enemy_spawn_controller.new.success", "[EnemySpawnController:new] Enemy Spawn Controller created.")
    return instance
end

--- Configura o controller com a horda para a sessão de gameplay atual.
---@param hordeConfig HordeConfigData
function EnemySpawnController:setup(hordeConfig)
    self.hordeConfig = hordeConfig
    self.currentPhaseIndex = 0
    self.phaseTimer = 0

    Logger.info("enemy_spawn_controller.setup.success", "[EnemySpawnController:setup] Enemy Spawn Controller setup.")
    self:_startNextPhase()
end

--- Lógica de atualização chamada a cada frame pelo EnemyManager.
---@param dt number O delta time do frame.
---@param gameTime number O tempo total da partida, fornecido pelo GameTimerService.
function EnemySpawnController:update(dt, gameTime)
    if not self.hordeConfig then return end

    -- Lógica para avançar as fases
    local currentPhase = self.hordeConfig.phases[self.currentPhaseIndex]
    if currentPhase then
        self.phaseTimer = self.phaseTimer + dt
        if self.phaseTimer >= currentPhase.duration then
            self:_startNextPhase()
        end
    end

    -- Atualiza todos os task runners (de tempo e de frame)
    for _, runner in ipairs(self.taskRunners) do
        runner:update(dt) -- FrameTaskRunner ignora o dt, o que é ok.
    end

    -- Lógica para spawnar bosses (baseado no gameTime)
    -- ... a ser implementada ...
end

--- Função interna para iniciar a próxima fase da horda.
function EnemySpawnController:_startNextPhase()
    self.phaseTimer = 0
    self.currentPhaseIndex = self.currentPhaseIndex + 1

    -- Limpa os runners da fase anterior
    self.taskRunners = {}

    local newPhase = self.hordeConfig.phases[self.currentPhaseIndex]
    if not newPhase then
        Logger.info(
            "enemy_spawn_controller.start_next_phase.success",
            "[EnemySpawnController:_startNextPhase] All phases of the horde have been completed."
        )
        return
    end

    Logger.info(
        "enemy_spawn_controller.start_next_phase.success",
        "[EnemySpawnController:_startNextPhase] Starting phase " .. self.currentPhaseIndex
    )

    -- Cria os novos task runners para a fase atual
    for _, pattern in ipairs(newPhase.spawnPatterns) do
        if pattern.type == "Wave" then
            local waveRunner = TimerTaskRunner:new({
                interval = pattern.interval,
                action = function() self:_triggerWave(pattern) end
            })
            table.insert(self.taskRunners, waveRunner)
        elseif pattern.type == "Trickle" then
            local trickleRunner = TimerTaskRunner:new({
                interval = pattern.interval,
                action = function() self:_spawnSingleEnemy(pattern.enemyClass) end
            })
            table.insert(self.taskRunners, trickleRunner)
        end
    end
end

--- Dispara uma onda de inimigos usando um FrameTaskRunner para diluir o custo.
---@param wavePattern SpawnPatternData
function EnemySpawnController:_triggerWave(wavePattern)
    local enemiesToSpawn = wavePattern.count
    local spawnedCount = 0

    local waveFrameRunner = FrameTaskRunner:new({
        intervalFrames = 1, -- Spawna 1 por frame
        action = function()
            if spawnedCount < enemiesToSpawn then
                self:_spawnSingleEnemy(wavePattern.enemyClass)
                spawnedCount = spawnedCount + 1
            else
                -- Auto-destruição? Precisamos gerenciar a vida dos runners.
                -- Por agora, eles apenas param de fazer a ação.
            end
        end
    })
    table.insert(self.taskRunners, waveFrameRunner)
end

--- Lógica para spawnar um único inimigo (a ser completada).
---@param enemyClass table
function EnemySpawnController:_spawnSingleEnemy(enemyClass)
    -- Esta função irá, no futuro:
    -- 1. Chamar uma função no EnemyManager para pegar um inimigo do pool.
    -- 2. Chamar uma função utilitária para calcular a posição de spawn.
    -- 3. Configurar o inimigo e adicioná-lo à lista de inimigos ativos do manager.
    Logger.debug("EnemySpawnController", "Pedido de spawn para: " .. tostring(enemyClass))
end

function EnemySpawnController:destroy()
    self.taskRunners = {}
    Logger.info("EnemySpawnController", "Enemy Spawn Controller destroyed.")
end

return EnemySpawnController
