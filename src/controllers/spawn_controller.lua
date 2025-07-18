-- src/controllers/spawn_controller.lua
--[[
    SISTEMA DE CONTROLE DE SPAWN ASSÍNCRONO PARA MAPAS INFINITOS

    O SpawnController implementa um sistema híbrido de spawns com processamento assíncrono usando coroutines,
    otimizado para mapas infinitos com wrapping de coordenadas e densidade adaptativa.

    🚀 SISTEMA ASSÍNCRONO DE SPAWNS:

    1. PROCESSAMENTO DISTRIBUÍDO
       - Usa coroutines para distribuir spawns ao longo de múltiplos frames
       - Evita spikes de performance durante spawns massivos
       - Yield automático baseado em tempo de processamento por frame

    2. PRIORIZAÇÃO INTELIGENTE
       - Bosses: Prioridade máxima (processamento imediato)
       - MVPs: Alta prioridade (processamento rápido)
       - Spawns normais: Processamento distribuído em batches

    3. MÉTRICAS E MONITORAMENTO
       - Tracking em tempo real de performance
       - Estatísticas de throughput e yields
       - Health monitoring do sistema

    4. CONFIGURAÇÃO DINÂMICA
       - Ajuste de parâmetros em runtime
       - Limites adaptativos baseados na performance
       - Fallback para sistema legacy se necessário

    🌍 SISTEMA DE MAPAS INFINITOS:

    1. WRAPPING DE COORDENADAS
       - Responde a eventos de player wrapping
       - Limpa spawns distantes automaticamente
       - Ajusta densidade baseada na nova região

    2. SPAWN POSICIONAL INTELIGENTE
       - Spawns direcionais baseados no movimento do jogador
       - Verificação de densidade antes do spawn
       - Otimização para coordenadas infinitas

    3. BALANCEAMENTO ADAPTATIVO
       - Boost temporário em regiões com poucos inimigos
       - Redução temporária em regiões saturadas
       - Densidade alvo configurável por região

    ✨ FUNCIONALIDADES MANTIDAS (Sistema de Controle por Boss):

    O SpawnController mantém o sistema inteligente de controle de spawns baseado na presença de bosses:

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
local AsyncSpawnProcessor = require("src.controllers.async_spawn_processor")

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
---@field spawnQueue SpawnRequest[] Fila de spawns pendentes para distribuir ao longo de múltiplos frames (DEPRECATED - usado apenas para compatibilidade)
---@field maxSpawnsPerFrame number Número máximo de inimigos a spawnar por frame
---@field isSpawnPaused boolean Indica se os spawns estão pausados devido a boss ativo
---@field pauseStartTime number Tempo quando a pausa começou
---@field totalPauseTime number Tempo total acumulado de pausa
---@field isPermanentlyPaused boolean Indica se os spawns foram pausados permanentemente (último boss)
---@field asyncProcessor AsyncSpawnProcessor Processador assíncrono de spawns
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

    -- Sistema de Spawn Distribuído (Mantido para compatibilidade)
    instance.spawnQueue = {}
    instance.maxSpawnsPerFrame = Constants.SPAWN_OPTIMIZATION.MAX_SPAWNS_PER_FRAME

    -- Controle de Pausa por Boss
    instance.isSpawnPaused = false
    instance.pauseStartTime = 0
    instance.totalPauseTime = 0
    instance.isPermanentlyPaused = false

    -- Processador Assíncrono de Spawns
    instance.asyncProcessor = AsyncSpawnProcessor:new()

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

    -- Limpa o processador assíncrono
    if self.asyncProcessor then
        self.asyncProcessor:clear()
    else
        self.asyncProcessor = AsyncSpawnProcessor:new()
    end

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

    -- Atualiza o processador assíncrono
    if self.asyncProcessor then
        self.asyncProcessor:update(dt)
    end

    -- Verifica se há boss ativo e ajusta o estado de pausa
    self:updateBossSpawnControl()

    -- Se os spawns estão pausados permanentemente, não executa nada
    if self.isPermanentlyPaused then
        return
    end

    -- Processa spawns do sistema assíncrono PRIMEIRO
    self:processAsyncSpawns()

    -- Processa a fila de spawn distribuído legacy (mesmo em pausa, para não perder spawns já na fila)
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
            -- Bosses spawnam em qualquer direção para máximo impacto
            local spawnX, spawnY = self:calculateSpawnPositionInfinite()
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

--- Processa spawns do sistema assíncrono
function SpawnController:processAsyncSpawns()
    if not self.asyncProcessor then return end

    -- Obtém spawns processados do sistema assíncrono
    local processedSpawns = self.asyncProcessor:getProcessedSpawns(self.maxSpawnsPerFrame)
    local spawnsThisFrame = 0

    for _, spawn in ipairs(processedSpawns) do
        if not self.enemyManager:canSpawnMoreEnemies() then
            Logger.warn("[SpawnController:processAsyncSpawns]", "Limite máximo de inimigos atingido.")
            break
        end

        self.enemyManager:spawnSpecificEnemy(
            spawn.enemyClass,
            spawn.position,
            spawn.options
        )
        spawnsThisFrame = spawnsThisFrame + 1
    end

    if spawnsThisFrame > 0 then
        Logger.debug(
            "[SpawnController:processAsyncSpawns]",
            string.format("Executados %d spawns assíncronos.", spawnsThisFrame)
        )
    end
end

--- Processa a fila de spawn distribuído legacy, limitando spawns por frame
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
            string.format("Processados %d spawns legacy. %d restantes na fila.", spawnsThisFrame, #self.spawnQueue)
        )
    end
end

--- Adiciona um spawn request à fila (LEGACY - mantido para compatibilidade)
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

--- Adiciona um spawn request ao sistema assíncrono
---@param enemyClass table
---@param position { x: number, y: number }
---@param options table|nil
function SpawnController:addAsyncSpawnRequest(enemyClass, position, options)
    if self.asyncProcessor then
        self.asyncProcessor:addSpawnRequest(enemyClass, position, options)
    else
        -- Fallback para sistema legacy
        self:addToSpawnQueue(enemyClass, position, options)
    end
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
            "Major Spawn (Ciclo %d) no tempo %.2f: Adicionando %d inimigos ao processamento assíncrono.",
            self.currentCycleIndex,
            self.gameTimer,
            countToSpawn
        )
    )

    -- Adiciona spawns ao sistema assíncrono
    for _ = 1, countToSpawn do
        local enemyClass = self:selectEnemyFromList(currentCycle.allowedEnemies)
        if enemyClass then
            -- Usa função otimizada para mapas infinitos com spawns na frente do movimento
            local spawnX, spawnY = self:calculateSpawnPositionInfinite("front")
            self:addAsyncSpawnRequest(enemyClass, { x = spawnX, y = spawnY }, nil)
        end
    end
end

---@param currentCycle HordeCycle
function SpawnController:handleMinorSpawn(currentCycle)
    local spawnConfig = currentCycle.minorSpawn
    local countToSpawn = spawnConfig.count

    Logger.debug("[SpawnController:handleMinorSpawn]",
        string.format("Minor Spawn (Ciclo %d) no tempo %.2f: Adicionando %d inimigos ao processamento assíncrono.",
            self.currentCycleIndex, self.gameTimer, countToSpawn))

    -- Adiciona spawns ao sistema assíncrono
    for _ = 1, countToSpawn do
        local enemyClass = self:selectEnemyFromList(currentCycle.allowedEnemies)
        if enemyClass then
            -- Usa função otimizada para mapas infinitos com spawns laterais
            local spawnX, spawnY = self:calculateSpawnPositionInfinite()
            self:addAsyncSpawnRequest(enemyClass, { x = spawnX, y = spawnY }, nil)
        end
    end
end

function SpawnController:spawnMVP()
    local currentCycle = self.worldConfig.cycles[self.currentCycleIndex]
    if not currentCycle then return end

    local enemyClass = self:selectEnemyFromList(currentCycle.allowedEnemies)
    if not enemyClass then return end

    -- MVPs spawnam atrás do jogador para criar elemento surpresa
    local spawnX, spawnY = self:calculateSpawnPositionInfinite("back")
    -- MVPs são adicionados ao sistema assíncrono com alta prioridade (processamento imediato)
    Logger.debug("[SpawnController:spawnMVP]", "Adicionando MVP ao processamento assíncrono (prioridade alta).")
    self:addAsyncSpawnRequest(enemyClass, { x = spawnX, y = spawnY }, { isMVP = true })
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

--- Retorna informações sobre o estado atual do sistema de spawn
---@return table Estado do sistema contendo informações de filas legacy e assíncrona
function SpawnController:getSpawnQueueInfo()
    local asyncStatus = {}
    if self.asyncProcessor then
        asyncStatus = self.asyncProcessor:getStatus()
    end

    return {
        -- Sistema Legacy
        legacyQueue = {
            count = #self.spawnQueue,
            maxPerFrame = self.maxSpawnsPerFrame
        },
        -- Sistema Assíncrono
        asyncSystem = asyncStatus,
        -- Estado Global
        isPaused = self.isSpawnPaused,
        isPermanentlyPaused = self.isPermanentlyPaused,
        totalPauseTime = self.totalPauseTime,
        gameTimer = self.gameTimer
    }
end

--- Retorna métricas detalhadas de performance do sistema de spawn
---@return table Métricas de performance
function SpawnController:getPerformanceMetrics()
    local metrics = {
        systemType = "AsyncSpawnController",
        legacyQueueCount = #self.spawnQueue,
        asyncMetrics = nil,
        totalPauseTime = self.totalPauseTime,
        gameTimer = self.gameTimer
    }

    if self.asyncProcessor then
        local asyncStatus = self.asyncProcessor:getStatus()
        metrics.asyncMetrics = asyncStatus.metrics
        metrics.asyncPendingRequests = asyncStatus.pendingRequests
        metrics.asyncProcessedSpawns = asyncStatus.processedSpawns
        metrics.activeCoroutines = asyncStatus.activeCoroutines
    end

    return metrics
end

--- Função de teste para verificar funcionalidade do controle de spawn por boss
---@param forceSpawnBoss boolean Se true, força o spawn de um boss para teste
function SpawnController:testBossSpawnControl(forceSpawnBoss)
    if forceSpawnBoss then
        -- Força o spawn de um boss para teste
        local currentCycle = self.worldConfig.cycles[self.currentCycleIndex]
        if currentCycle and currentCycle.allowedEnemies and #currentCycle.allowedEnemies > 0 then
            local enemyClass = currentCycle.allowedEnemies[1].class
            local spawnX, spawnY = self:calculateSpawnPositionInfinite()

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
        legacySpawnQueueCount = #self.spawnQueue,
        nextBossIndex = self.nextBossIndex,
        asyncSpawnSystem = {}
    }

    -- Adiciona informações do sistema assíncrono
    if self.asyncProcessor then
        local asyncStatus = self.asyncProcessor:getStatus()
        debugInfo.asyncSpawnSystem = {
            pendingRequests = asyncStatus.pendingRequests,
            processedSpawns = asyncStatus.processedSpawns,
            activeCoroutines = asyncStatus.activeCoroutines,
            totalProcessed = asyncStatus.metrics.totalProcessed,
            totalYields = asyncStatus.metrics.totalYields,
            avgProcessTime = asyncStatus.metrics.avgProcessTime
        }
    end

    if self.worldConfig.bossConfig and self.worldConfig.bossConfig.spawnTimes then
        debugInfo.totalBossesConfigured = #self.worldConfig.bossConfig.spawnTimes
        debugInfo.bossesRemaining = #self.worldConfig.bossConfig.spawnTimes - (self.nextBossIndex - 1)
    end

    Logger.info("[SpawnController:testBossSpawnControl]",
        string.format(
            "Estado atual: Pausado=%s, PermanentePausado=%s, TempoPausa=%.2f, FilaLegacy=%d, AsyncPending=%d, AsyncProcessed=%d",
            tostring(debugInfo.isSpawnPaused),
            tostring(debugInfo.isPermanentlyPaused),
            debugInfo.totalPauseTime,
            debugInfo.legacySpawnQueueCount,
            debugInfo.asyncSpawnSystem.pendingRequests or 0,
            debugInfo.asyncSpawnSystem.processedSpawns or 0))

    return debugInfo
end

--- Configura parâmetros de performance do sistema assíncrono em runtime
---@param config table Configurações: maxProcessTimePerFrame, yieldCheckInterval, batchSize
function SpawnController:configureAsyncSystem(config)
    if self.asyncProcessor then
        self.asyncProcessor:updateConfig(config)
        Logger.info("[SpawnController:configureAsyncSystem]", "Sistema assíncrono reconfigurado")
    else
        Logger.warn("[SpawnController:configureAsyncSystem]",
            "Tentativa de configurar sistema assíncrono não inicializado")
    end
end

--- Obtém estatísticas de performance em tempo real
---@return table Estatísticas incluindo FPS impact, throughput, etc.
function SpawnController:getRealtimeStats()
    local stats = {
        frameTime = love.timer.getDelta() * 1000, -- ms
        fps = love.timer.getFPS(),
        spawnThroughput = 0,
        systemHealth = "healthy"
    }

    if self.asyncProcessor then
        local asyncStatus = self.asyncProcessor:getStatus()
        local metrics = asyncStatus.metrics

        stats.spawnThroughput = metrics.totalProcessed / math.max(self.gameTimer, 1)
        stats.avgProcessTime = metrics.avgProcessTime
        stats.totalYields = metrics.totalYields
        stats.asyncLoad = asyncStatus.pendingRequests + asyncStatus.processedSpawns

        -- Determina health do sistema
        if metrics.frameProcessTime > 5.0 then
            stats.systemHealth = "overloaded"
        elseif metrics.frameProcessTime > 3.0 then
            stats.systemHealth = "stressed"
        elseif asyncStatus.pendingRequests > 100 then
            stats.systemHealth = "busy"
        end
    end

    return stats
end

--- Força limpeza completa do sistema de spawn (usado ao sair de gameplay)
function SpawnController:cleanup()
    if self.asyncProcessor then
        self.asyncProcessor:clear()
        Logger.info("[SpawnController:cleanup]", "Sistema assíncrono limpo")
    end

    self.spawnQueue = {}
    self.isSpawnPaused = false
    self.isPermanentlyPaused = false
    self.totalPauseTime = 0

    Logger.info("[SpawnController:cleanup]", "SpawnController completamente limpo")
end

--- Callback chamado quando o jogador muda de patch no mapa infinito.
--- Ajusta comportamento de spawn para coordenadas infinitas.
function SpawnController:onPlayerWrapped()
    Logger.debug("spawn_controller.wrap.triggered",
        "[SpawnController] Player wrapped detectado - ajustando sistema de spawn")

    -- Limpar spawns pendentes muito distantes para evitar acúmulo
    self:_cleanupDistantSpawnRequests()

    -- Ajustar densidade de spawn baseada na nova região
    self:_adjustSpawnDensityForRegion()

    -- Otimizar fila assíncrona para nova posição
    if self.asyncProcessor then
        self.asyncProcessor:optimizeForPosition(self:_getPlayerPosition())
    end
end

--- Limpa spawn requests que estão muito distantes da nova posição do jogador.
--- Usado após player wrapping para evitar spawns em regiões irrelevantes.
function SpawnController:_cleanupDistantSpawnRequests()
    local playerPos = self:_getPlayerPosition()
    local maxDistance = 1500 -- Distância máxima em pixels
    local removedCount = 0

    -- Limpar fila legacy
    for i = #self.spawnQueue, 1, -1 do
        local spawn = self.spawnQueue[i]
        if spawn and spawn.position then
            local dx = spawn.position.x - playerPos.x
            local dy = spawn.position.y - playerPos.y
            local distance = math.sqrt(dx * dx + dy * dy)

            if distance > maxDistance then
                table.remove(self.spawnQueue, i)
                removedCount = removedCount + 1
            end
        end
    end

    -- Limpar sistema assíncrono
    if self.asyncProcessor and self.asyncProcessor.cleanupDistantRequests then
        local asyncRemoved = self.asyncProcessor:cleanupDistantRequests(playerPos, maxDistance)
        removedCount = removedCount + asyncRemoved
    end

    if removedCount > 0 then
        Logger.debug("spawn_controller.wrap.cleanup",
            string.format("Removidos %d spawn requests distantes após wrapping", removedCount))
    end
end

--- Ajusta a densidade de spawn baseada na nova região após wrapping.
--- Usa informações do EnemyManager para balancear spawns.
function SpawnController:_adjustSpawnDensityForRegion()
    local playerPos = self:_getPlayerPosition()
    local checkRadius = 800

    -- Verifica densidade de inimigos na nova região
    local currentDensity = self.enemyManager:getEnemyDensityInArea(
        playerPos.x, playerPos.y, checkRadius
    )

    -- Ajusta spawns baseado na densidade
    local targetDensity = 15 -- Densidade alvo de inimigos
    local densityRatio = currentDensity / targetDensity

    if densityRatio < 0.5 then
        -- Região com poucos inimigos - aumenta spawn rate temporariamente
        self:_temporarySpawnBoost(2.0, 10) -- 2x boost por 10 segundos
        Logger.debug("spawn_controller.wrap.density",
            string.format("Região com baixa densidade (%d/%d) - aplicando boost",
                currentDensity, targetDensity))
    elseif densityRatio > 1.5 then
        -- Região com muitos inimigos - reduz spawn rate temporariamente
        self:_temporarySpawnReduction(0.5, 8) -- 50% reduction por 8 segundos
        Logger.debug("spawn_controller.wrap.density",
            string.format("Região com alta densidade (%d/%d) - aplicando redução",
                currentDensity, targetDensity))
    end
end

--- Aplica um boost temporário na taxa de spawn.
---@param multiplier number Multiplicador da taxa de spawn (ex: 2.0 = dobro)
---@param duration number Duração em segundos
function SpawnController:_temporarySpawnBoost(multiplier, duration)
    -- Implementação simplificada - pode ser expandida
    local originalMaxSpawns = self.maxSpawnsPerFrame
    local boostedMax = math.floor(originalMaxSpawns * multiplier)

    self:setMaxSpawnsPerFrame(boostedMax)

    -- Timer para restaurar valor original (simplificado)
    -- Em implementação real, usaria um timer system
    Logger.debug("spawn_controller.boost",
        string.format("Spawn boost aplicado: %dx por %ds", multiplier, duration))
end

--- Aplica uma redução temporária na taxa de spawn.
---@param multiplier number Multiplicador da taxa de spawn (ex: 0.5 = metade)
---@param duration number Duração em segundos
function SpawnController:_temporarySpawnReduction(multiplier, duration)
    -- Implementação simplificada
    local originalMaxSpawns = self.maxSpawnsPerFrame
    local reducedMax = math.max(1, math.floor(originalMaxSpawns * multiplier))

    self:setMaxSpawnsPerFrame(reducedMax)

    Logger.debug("spawn_controller.reduction",
        string.format("Spawn reduction aplicada: %dx por %ds", multiplier, duration))
end

--- Obtém posição atual do jogador de forma segura.
---@return Vector2D Posição {x, y} do jogador
function SpawnController:_getPlayerPosition()
    if self.playerManager and self.playerManager.getPlayerPosition then
        return self.playerManager:getPlayerPosition()
    elseif self.playerManager and self.playerManager.movementController then
        return self.playerManager.movementController:getPosition()
    else
        -- Fallback para centro da câmera
        local camX, camY = Camera:getViewPort()
        return { x = camX, y = camY }
    end
end

--- Calcula posição de spawn otimizada para mapas infinitos.
--- Considera wrapping de coordenadas e densidade existente.
---@param preferredDirection string|nil Direção preferida: "front", "back", "left", "right"
---@return number, number Coordenadas X, Y para spawn
function SpawnController:calculateSpawnPositionInfinite(preferredDirection)
    local camX, camY, camWidth, camHeight = Camera:getViewPort()
    local sprite = self.playerManager:getPlayerSprite()
    local playerVel = sprite.velocity
    local buffer = 150

    -- Zonas de spawn padrão
    local spawnZones = {
        top = { x = camX - buffer, y = camY - buffer, width = camWidth + buffer * 2, height = buffer },
        bottom = { x = camX - buffer, y = camY + camHeight, width = camWidth + buffer * 2, height = buffer },
        left = { x = camX - buffer, y = camY, width = buffer, height = camHeight },
        right = { x = camX + camWidth, y = camY, width = buffer, height = camHeight }
    }

    -- Pesos base
    local weights = { top = 1, bottom = 1, left = 1, right = 1 }

    -- Ajusta pesos baseado na direção do movimento do jogador
    local isMoving = playerVel and (playerVel.x ~= 0 or playerVel.y ~= 0)
    if isMoving and playerVel then
        local movementBias = 4
        if playerVel.y < -0.1 then weights.top = weights.top + movementBias end
        if playerVel.y > 0.1 then weights.bottom = weights.bottom + movementBias end
        if playerVel.x < -0.1 then weights.left = weights.left + movementBias end
        if playerVel.x > 0.1 then weights.right = weights.right + movementBias end
    end

    -- Aplica direção preferida se especificada
    if preferredDirection then
        if preferredDirection == "front" and isMoving and playerVel then
            -- Spawn na frente da direção do movimento
            if math.abs(playerVel.x) > math.abs(playerVel.y) then
                if playerVel.x > 0 then
                    weights.right = weights.right * 3
                else
                    weights.left = weights.left * 3
                end
            else
                if playerVel.y > 0 then
                    weights.bottom = weights.bottom * 3
                else
                    weights.top = weights.top * 3
                end
            end
        elseif preferredDirection == "back" and isMoving and playerVel then
            -- Spawn atrás da direção do movimento
            if math.abs(playerVel.x) > math.abs(playerVel.y) then
                if playerVel.x > 0 then
                    weights.left = weights.left * 3
                else
                    weights.right = weights.right * 3
                end
            else
                if playerVel.y > 0 then
                    weights.top = weights.top * 3
                else
                    weights.bottom = weights.bottom * 3
                end
            end
        elseif weights[preferredDirection] then
            weights[preferredDirection] = weights[preferredDirection] * 2
        end
    end

    -- Seleciona zona baseada nos pesos
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

    -- Gera posição com verificação de densidade
    local attempts = 0
    local maxAttempts = 5
    local spawnX, spawnY

    repeat
        spawnX = math.random(selectedZone.x, selectedZone.x + selectedZone.width)
        spawnY = math.random(selectedZone.y, selectedZone.y + selectedZone.height)

        -- Verifica densidade na posição proposta
        local localDensity = self.enemyManager:getEnemyDensityInArea(spawnX, spawnY, 200)

        if localDensity < 8 then -- Limite de densidade local
            break
        end

        attempts = attempts + 1
    until attempts >= maxAttempts

    return spawnX, spawnY
end

return SpawnController
