-- src/controllers/spawn_controller.lua
--[[
    SISTEMA DE CONTROLE DE SPAWN POR BOSS

    O SpawnController agora implementa um sistema inteligente de controle de spawns baseado na presença de bosses:

    ✨ FUNCIONALIDADES PRINCIPAIS:

    1. PAUSA AUTOMÁTICA DE SPAWNS
       - Quando um boss é spawnado, todos os spawns (major, minor, MVP) são pausados
       - A fila de spawns continua sendo processada para não perder inimigos já na fila
       - Novos spawns não são adicionados à fila enquanto há boss ativo

    2. CONTROLE DE TEMPO DE PAUSA
       - O sistema registra quando a pausa começou (pauseStartTime)
       - Calcula o tempo total de pausa acumulado (totalPauseTime)
       - Ajusta todos os timers de spawn baseado no tempo pausado

    3. DETECÇÃO DE ÚLTIMO BOSS
       - Verifica se é o último boss configurado no worldConfig.bossConfig.spawnTimes
       - Se for o último boss, após sua morte os spawns são pausados permanentemente
       - Se não for o último boss, os spawns são retomados com timers ajustados

    4. SISTEMA DE LOGS
       - Registra quando spawns são pausados/retomados
       - Informa se é o último boss
       - Mostra tempo de pausa e ajustes nos timers

    5. FUNÇÕES DE DEBUG
       - getSpawnQueueInfo() retorna estado completo do sistema
       - testBossSpawnControl() permite testar a funcionalidade
       - EnemyManager:getDebugInfo() mostra informações dos bosses ativos

    ⚙️ CONFIGURAÇÃO:

    Para usar o sistema, configure os bosses no worldConfig.bossConfig.spawnTimes:

    bossConfig = {
        spawnTimes = {
            { time = 300, class = BossClass1, unitType = "boss_type_1", rank = "E" },
            { time = 600, class = BossClass2, unitType = "boss_type_2", rank = "D" },
            -- ... mais bosses
        }
    }

    🔧 VARIÁVEIS DE CONTROLE:

    - isSpawnPaused: Boolean que indica se spawns estão pausados temporariamente
    - isPermanentlyPaused: Boolean que indica se spawns estão pausados permanentemente
    - pauseStartTime: Timestamp quando a pausa atual começou
    - totalPauseTime: Tempo total acumulado de todas as pausas
    - nextBossIndex: Índice do próximo boss a ser spawnado

    🎯 COMPORTAMENTO ESPERADO:

    1. Jogo inicia com spawns normais
    2. Primeiro boss spawna → spawns pausam
    3. Boss morre → spawns retomam com timers ajustados
    4. Segundo boss spawna → spawns pausam novamente
    5. Segundo boss morre → spawns retomam (se não for último)
    6. Último boss spawna → spawns pausam
    7. Último boss morre → spawns pausam PERMANENTEMENTE
]]

local Camera = require("src.config.camera")
local Logger = require("src.libs.logger")
local Constants = require("src.config.constants")

---@class SpawnRequest
---@field enemyClass table
---@field position { x: number, y: number }
---@field options table|nil

---@class SpawnController
---@field enemyManager EnemyManager
---@field playerManager PlayerManager
---@field mapManager MapManager
---@field worldConfig table|nil
---@field currentCycleIndex number
---@field gameTimer number
---@field timeInCurrentCycle number
---@field nextMajorSpawnTime number
---@field nextMinorSpawnTime number
---@field nextMVPSpawnTime number
---@field nextBossIndex number
---@field spawnQueue SpawnRequest[] Fila de spawns pendentes para distribuir ao longo de múltiplos frames
---@field maxSpawnsPerFrame number Número máximo de inimigos a spawnar por frame
---@field isSpawnPaused boolean Indica se os spawns estão pausados devido a boss ativo
---@field pauseStartTime number Tempo quando a pausa começou
---@field totalPauseTime number Tempo total acumulado de pausa
---@field isPermanentlyPaused boolean Indica se os spawns foram pausados permanentemente (último boss)
local SpawnController = {}
SpawnController.__index = SpawnController

---@param enemyManager EnemyManager
---@param playerManager PlayerManager
---@param mapManager MapManager
function SpawnController:new(enemyManager, playerManager, mapManager)
    local instance = setmetatable({}, SpawnController)
    instance.enemyManager = enemyManager
    instance.playerManager = playerManager
    instance.mapManager = mapManager

    -- Estado de Ciclo e Tempo
    instance.worldConfig = nil
    instance.currentCycleIndex = 1
    instance.gameTimer = 0
    instance.timeInCurrentCycle = 0

    -- Timers de Spawn (baseados no gameTimer)
    instance.nextMajorSpawnTime = 0
    instance.nextMinorSpawnTime = 0
    instance.nextMVPSpawnTime = 0
    instance.nextBossIndex = 1

    -- Sistema de Spawn Distribuído
    instance.spawnQueue = {}
    instance.maxSpawnsPerFrame = Constants.SPAWN_OPTIMIZATION.MAX_SPAWNS_PER_FRAME

    -- Controle de Pausa por Boss
    instance.isSpawnPaused = false
    instance.pauseStartTime = 0
    instance.totalPauseTime = 0
    instance.isPermanentlyPaused = false

    return instance
end

---@param hordeConfig PortalDefinition
function SpawnController:setup(hordeConfig)
    self.worldConfig = hordeConfig
    self.gameTimer = 0
    self.timeInCurrentCycle = 0
    self.currentCycleIndex = 1
    self.nextBossIndex = 1

    -- Limpa a fila de spawn de sessões anteriores
    self.spawnQueue = {}

    if not self.worldConfig or not self.worldConfig.cycles or #self.worldConfig.cycles == 0 then
        error("Erro [SpawnController:setup]: Configuração de horda inválida ou vazia fornecida.")
    end
    if not self.worldConfig.mvpConfig then
        error("Erro [SpawnController:setup]: Configuração de horda não possui 'mvpConfig'.")
    end

    local firstCycle = self.worldConfig.cycles[1]
    if not firstCycle or not firstCycle.majorSpawn or not firstCycle.minorSpawn then
        error("Erro [SpawnController:setup]: Primeiro ciclo inválido ou sem configuração de spawn.")
    end

    self.nextMajorSpawnTime = firstCycle.majorSpawn.interval
    self.nextMinorSpawnTime = self:calculateMinorSpawnInterval(firstCycle)
    self.nextMVPSpawnTime = self.worldConfig.mvpConfig.spawnInterval

    local mapRank = self.worldConfig.mapRank or "E"
    Logger.info(
        "[SpawnController]",
        string.format(
            "SpawnController inicializado com Horda Config. Rank Mapa: %s. %d ciclo(s). Max spawns/frame: %d. Bosses: %d",
            mapRank,
            #self.worldConfig.cycles,
            self.maxSpawnsPerFrame,
            #self.worldConfig.bossConfig.spawnTimes
        )
    )
end

---@param dt number
function SpawnController:update(dt)
    self.gameTimer = self.gameTimer + dt
    self.timeInCurrentCycle = self.timeInCurrentCycle + dt

    -- Verifica se há boss ativo e ajusta o estado de pausa
    self:updateBossSpawnControl()

    -- Se os spawns estão pausados permanentemente, não executa nada
    if self.isPermanentlyPaused then
        return
    end

    -- Processa a fila de spawn distribuído PRIMEIRO (mesmo em pausa, para não perder spawns já na fila)
    self:processSpawnQueue()

    -- Se spawns estão pausados, não executa novos spawns
    if self.isSpawnPaused then
        return
    end

    -- MVP Spawn
    if self.gameTimer >= self.nextMVPSpawnTime then
        self:spawnMVP()
        self.nextMVPSpawnTime = self.gameTimer + self.worldConfig.mvpConfig.spawnInterval
    end

    -- Boss Spawn
    if self.worldConfig.bossConfig and self.worldConfig.bossConfig.spawnTimes then
        local nextBoss = self.worldConfig.bossConfig.spawnTimes[self.nextBossIndex]
        if nextBoss and self.gameTimer >= nextBoss.time then
            local spawnX, spawnY = self:calculateSpawnPosition()
            self.enemyManager:spawnBoss(nextBoss, { x = spawnX, y = spawnY })
            self.nextBossIndex = self.nextBossIndex + 1

            -- Verifica se é o último boss
            if self.nextBossIndex > #self.worldConfig.bossConfig.spawnTimes then
                Logger.info(
                    "[SpawnController:update]",
                    "Último boss spawnado. Spawns serão pausados permanentemente após sua morte."
                )
            end
        end
    end

    -- Lógica de Ciclos
    local currentCycle = self.worldConfig.cycles[self.currentCycleIndex]
    if not currentCycle then
        return
    end

    if self.timeInCurrentCycle >= currentCycle.duration and self.currentCycleIndex < #self.worldConfig.cycles then
        self.currentCycleIndex = self.currentCycleIndex + 1
        self.timeInCurrentCycle = self.timeInCurrentCycle - currentCycle.duration
        currentCycle = self.worldConfig.cycles[self.currentCycleIndex]
        Logger.info(
            "[SpawnController]",
            string.format("Entrando no Ciclo %d no tempo %.2f", self.currentCycleIndex, self.gameTimer)
        )

        -- Ajusta os timers considerando o tempo de pausa
        self.nextMajorSpawnTime = self.gameTimer + currentCycle.majorSpawn.interval
        self.nextMinorSpawnTime = self.gameTimer + self:calculateMinorSpawnInterval(currentCycle)
    end

    -- Major Spawn
    if self.gameTimer >= self.nextMajorSpawnTime then
        self:handleMajorSpawn(currentCycle)
        self.nextMajorSpawnTime = self.gameTimer + currentCycle.majorSpawn.interval
    end

    -- Minor Spawn
    if self.gameTimer >= self.nextMinorSpawnTime then
        self:handleMinorSpawn(currentCycle)
        local nextInterval = self:calculateMinorSpawnInterval(currentCycle)
        self.nextMinorSpawnTime = self.gameTimer + nextInterval
    end
end

--- Processa a fila de spawn distribuído, limitando spawns por frame
function SpawnController:processSpawnQueue()
    local spawnsThisFrame = 0

    while #self.spawnQueue > 0 and spawnsThisFrame < self.maxSpawnsPerFrame do
        if not self.enemyManager:canSpawnMoreEnemies() then
            Logger.warn("[SpawnController:processSpawnQueue]", "Limite máximo de inimigos atingido.")
            break
        end

        local spawnRequest = table.remove(self.spawnQueue, 1)
        if spawnRequest and spawnRequest.enemyClass then
            self.enemyManager:spawnSpecificEnemy(
                spawnRequest.enemyClass,
                spawnRequest.position,
                spawnRequest.options
            )
            spawnsThisFrame = spawnsThisFrame + 1
        end
    end

    if spawnsThisFrame > 0 then
        Logger.debug(
            "[SpawnController:processSpawnQueue]",
            string.format("Processados %d spawns. %d restantes na fila.", spawnsThisFrame, #self.spawnQueue)
        )
    end
end

--- Adiciona um spawn request à fila
---@param enemyClass table
---@param position { x: number, y: number }
---@param options table|nil
function SpawnController:addToSpawnQueue(enemyClass, position, options)
    table.insert(self.spawnQueue, {
        enemyClass = enemyClass,
        position = position,
        options = options
    })
end

---@param currentCycle HordeCycle
function SpawnController:handleMajorSpawn(currentCycle)
    local spawnConfig = currentCycle.majorSpawn
    local minutesPassed = self.gameTimer / 60
    local countToSpawn = math.floor(spawnConfig.baseCount +
        (spawnConfig.baseCount * spawnConfig.countScalePerMin * minutesPassed))

    Logger.debug(
        "[SpawnController:handleMajorSpawn]",
        string.format(
            "Major Spawn (Ciclo %d) no tempo %.2f: Adicionando %d inimigos à fila de spawn. %d restantes na fila.",
            self.currentCycleIndex,
            self.gameTimer,
            countToSpawn,
            #self.spawnQueue
        )
    )

    -- Adiciona spawns à fila ao invés de spawnar imediatamente
    for _ = 1, countToSpawn do
        local enemyClass = self:selectEnemyFromList(currentCycle.allowedEnemies)
        if enemyClass then
            local spawnX, spawnY = self:calculateSpawnPosition()
            self:addToSpawnQueue(enemyClass, { x = spawnX, y = spawnY }, nil)
        end
    end
end

---@param currentCycle HordeCycle
function SpawnController:handleMinorSpawn(currentCycle)
    local spawnConfig = currentCycle.minorSpawn
    local countToSpawn = spawnConfig.count

    Logger.debug("[SpawnController:handleMinorSpawn]",
        string.format("Minor Spawn (Ciclo %d) no tempo %.2f: Adicionando %d inimigos à fila de spawn.",
            self.currentCycleIndex, self.gameTimer, countToSpawn))

    -- Adiciona spawns à fila ao invés de spawnar imediatamente
    for _ = 1, countToSpawn do
        local enemyClass = self:selectEnemyFromList(currentCycle.allowedEnemies)
        if enemyClass then
            local spawnX, spawnY = self:calculateSpawnPosition()
            self:addToSpawnQueue(enemyClass, { x = spawnX, y = spawnY }, nil)
        end
    end
end

function SpawnController:spawnMVP()
    local currentCycle = self.worldConfig.cycles[self.currentCycleIndex]
    if not currentCycle then return end

    local enemyClass = self:selectEnemyFromList(currentCycle.allowedEnemies)
    if not enemyClass then return end

    local spawnX, spawnY = self:calculateSpawnPosition()
    -- MVPs são spawnados imediatamente por prioridade, mas só 1 por vez então não causa gargalo
    Logger.debug("[SpawnController:spawnMVP]", "Spawnando MVP diretamente (prioridade alta).")
    self.enemyManager:spawnSpecificEnemy(enemyClass, { x = spawnX, y = spawnY }, { isMVP = true })
end

---@param cycleConfig HordeCycle
function SpawnController:calculateMinorSpawnInterval(cycleConfig)
    local spawnConfig = cycleConfig.minorSpawn
    local minutesPassed = self.gameTimer / 60
    local interval = spawnConfig.baseInterval - (spawnConfig.intervalReductionPerMin * minutesPassed)
    return math.max(interval, spawnConfig.minInterval)
end

---@param enemyList AllowedEnemy[]
function SpawnController:selectEnemyFromList(enemyList)
    if not enemyList or #enemyList == 0 then
        Logger.warn("[SpawnController:selectEnemyFromList]", "Tentando selecionar inimigo de uma lista vazia.")
        return nil
    end

    local totalWeight = 0
    for _, enemyType in ipairs(enemyList) do
        totalWeight = totalWeight + (enemyType.weight or 1)
    end

    if totalWeight <= 0 then
        Logger.warn("[SpawnController:selectEnemyFromList]", "Peso total zero ou negativo na lista de inimigos.")
        return #enemyList > 0 and enemyList[1].class or nil
    end

    local randomValue = math.random() * totalWeight

    for _, enemyType in ipairs(enemyList) do
        randomValue = randomValue - (enemyType.weight or 1)
        if randomValue <= 0 then
            return enemyType.class
        end
    end

    Logger.warn("[SpawnController:selectEnemyFromList]",
        "Falha ao selecionar inimigo por peso, retornando o primeiro.")
    return #enemyList > 0 and enemyList[1].class or nil
end

function SpawnController:calculateSpawnPosition()
    local camX, camY, camWidth, camHeight = Camera:getViewPort()
    local sprite = self.playerManager:getPlayerSprite()
    local playerVel = sprite.velocity
    local buffer = 150

    local spawnZones = {
        top = { x = camX - buffer, y = camY - buffer, width = camWidth + buffer * 2, height = buffer },
        bottom = { x = camX - buffer, y = camY + camHeight, width = camWidth + buffer * 2, height = buffer },
        left = { x = camX - buffer, y = camY, width = buffer, height = camHeight },
        right = { x = camX + camWidth, y = camY, width = buffer, height = camHeight }
    }

    local weights = { top = 1, bottom = 1, left = 1, right = 1 }
    local isMoving = playerVel and (playerVel.x ~= 0 or playerVel.y ~= 0)

    if isMoving and playerVel then
        local movementBias = 4
        if playerVel.y < -0.1 then weights.top = weights.top + movementBias end
        if playerVel.y > 0.1 then weights.bottom = weights.bottom + movementBias end
        if playerVel.x < -0.1 then weights.left = weights.left + movementBias end
        if playerVel.x > 0.1 then weights.right = weights.right + movementBias end
    end

    local totalWeight = weights.top + weights.bottom + weights.left + weights.right
    local randomVal = math.random() * totalWeight
    local selectedZoneKey

    if randomVal <= weights.top then
        selectedZoneKey = "top"
    elseif randomVal <= weights.top + weights.bottom then
        selectedZoneKey = "bottom"
    elseif randomVal <= weights.top + weights.bottom + weights.left then
        selectedZoneKey = "left"
    else
        selectedZoneKey = "right"
    end

    local selectedZone = spawnZones[selectedZoneKey]
    local spawnX = math.random(selectedZone.x, selectedZone.x + selectedZone.width)
    local spawnY = math.random(selectedZone.y, selectedZone.y + selectedZone.height)

    return spawnX, spawnY
end

--- Ajusta o limite de spawns por frame para fine-tuning de performance
---@param newLimit number Novo limite de spawns por frame
function SpawnController:setMaxSpawnsPerFrame(newLimit)
    local minLimit = Constants.SPAWN_OPTIMIZATION.MIN_SPAWNS_PER_FRAME
    local maxLimit = Constants.SPAWN_OPTIMIZATION.MAX_SPAWNS_PER_FRAME_LIMIT

    if newLimit and newLimit >= minLimit and newLimit <= maxLimit then
        self.maxSpawnsPerFrame = newLimit
        Logger.info("[SpawnController:setMaxSpawnsPerFrame]",
            string.format("Limite de spawns por frame ajustado para: %d", newLimit))
    else
        Logger.warn("[SpawnController:setMaxSpawnsPerFrame]",
            string.format("Limite inválido (%s). Deve ser entre %d e %d.",
                tostring(newLimit), minLimit, maxLimit))
    end
end

--- Verifica se há boss ativo e controla o estado de pausa dos spawns
function SpawnController:updateBossSpawnControl()
    -- Verifica se há boss ativo
    local hasBossActive = false
    for _, enemy in ipairs(self.enemyManager.enemies) do
        if enemy.isBoss and enemy.isAlive then
            hasBossActive = true
            break
        end
    end

    -- Se há boss ativo e não estava pausado, inicia a pausa
    if hasBossActive and not self.isSpawnPaused then
        self:pauseSpawns()
        -- Se não há boss ativo e estava pausado, retoma os spawns
    elseif not hasBossActive and self.isSpawnPaused then
        self:resumeSpawns()
    end
end

--- Pausa os spawns devido a boss ativo
function SpawnController:pauseSpawns()
    self.isSpawnPaused = true
    self.pauseStartTime = self.gameTimer

    Logger.info("[SpawnController:pauseSpawns]",
        string.format("Spawns pausados devido a boss ativo no tempo %.2f", self.gameTimer))
end

--- Retoma os spawns após boss morrer
function SpawnController:resumeSpawns()
    if self.isPermanentlyPaused then
        return -- Não retoma se estiver permanentemente pausado
    end

    -- Calcula o tempo de pausa
    local pauseDuration = self.gameTimer - self.pauseStartTime
    self.totalPauseTime = self.totalPauseTime + pauseDuration

    -- Verifica se é o último boss (não há mais bosses para spawnar)
    local isLastBoss = true
    if self.worldConfig.bossConfig and self.worldConfig.bossConfig.spawnTimes then
        isLastBoss = self.nextBossIndex > #self.worldConfig.bossConfig.spawnTimes
    end

    if isLastBoss then
        -- Último boss morreu, pausa permanentemente
        self.isPermanentlyPaused = true
        self.isSpawnPaused = false -- Reseta o flag temporário

        Logger.info("[SpawnController:resumeSpawns]",
            string.format("Último boss morreu. Spawns pausados permanentemente após %.2f segundos de pausa total.",
                pauseDuration))
    else
        -- Ajusta os timers de spawn baseado no tempo de pausa
        self.nextMajorSpawnTime = self.nextMajorSpawnTime + pauseDuration
        self.nextMinorSpawnTime = self.nextMinorSpawnTime + pauseDuration
        self.nextMVPSpawnTime = self.nextMVPSpawnTime + pauseDuration

        self.isSpawnPaused = false

        Logger.info("[SpawnController:resumeSpawns]",
            string.format(
                "Spawns retomados após %.2f segundos de pausa. Timers ajustados. Pausa total acumulada: %.2f segundos.",
                pauseDuration, self.totalPauseTime))
    end
end

--- Retorna informações sobre o estado atual da fila de spawn
---@return table Estado da fila contendo: count (número de spawns pendentes), maxPerFrame (limite por frame), isPaused (se spawns estão pausados), isPermanentlyPaused (se pausados permanentemente)
function SpawnController:getSpawnQueueInfo()
    return {
        count = #self.spawnQueue,
        maxPerFrame = self.maxSpawnsPerFrame,
        isPaused = self.isSpawnPaused,
        isPermanentlyPaused = self.isPermanentlyPaused,
        totalPauseTime = self.totalPauseTime
    }
end

--- Função de teste para verificar funcionalidade do controle de spawn por boss
---@param forceSpawnBoss boolean Se true, força o spawn de um boss para teste
function SpawnController:testBossSpawnControl(forceSpawnBoss)
    if forceSpawnBoss then
        -- Força o spawn de um boss para teste
        local currentCycle = self.worldConfig.cycles[self.currentCycleIndex]
        if currentCycle and currentCycle.allowedEnemies and #currentCycle.allowedEnemies > 0 then
            local enemyClass = currentCycle.allowedEnemies[1].class
            local spawnX, spawnY = self:calculateSpawnPosition()

            -- Cria um boss temporário para teste
            local testBoss = {
                time = self.gameTimer + 5, -- Spawn em 5 segundos
                class = enemyClass,
                unitType = currentCycle.allowedEnemies[1].unitType,
                rank = self.worldConfig.mapRank or "E"
            }

            Logger.info("[SpawnController:testBossSpawnControl]",
                "Forçando spawn de boss para teste em 5 segundos...")

            -- Simula o spawn do boss
            self.enemyManager:spawnBoss(testBoss, { x = spawnX, y = spawnY })
        end
    end

    -- Retorna informações de debug
    local debugInfo = {
        isSpawnPaused = self.isSpawnPaused,
        isPermanentlyPaused = self.isPermanentlyPaused,
        totalPauseTime = self.totalPauseTime,
        gameTimer = self.gameTimer,
        spawnQueueCount = #self.spawnQueue,
        nextBossIndex = self.nextBossIndex
    }

    if self.worldConfig.bossConfig and self.worldConfig.bossConfig.spawnTimes then
        debugInfo.totalBossesConfigured = #self.worldConfig.bossConfig.spawnTimes
        debugInfo.bossesRemaining = #self.worldConfig.bossConfig.spawnTimes - (self.nextBossIndex - 1)
    end

    Logger.info("[SpawnController:testBossSpawnControl]",
        string.format("Estado atual: Pausado=%s, PermanentePausado=%s, TempoPausa=%.2f, FilaSpawn=%d",
            tostring(debugInfo.isSpawnPaused),
            tostring(debugInfo.isPermanentlyPaused),
            debugInfo.totalPauseTime,
            debugInfo.spawnQueueCount))

    return debugInfo
end

return SpawnController
