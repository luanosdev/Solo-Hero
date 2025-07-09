-- src/controllers/async_spawn_processor.lua
--[[
    PROCESSADOR ASSÍNCRONO DE SPAWNS

    Sistema que utiliza coroutines para distribuir o processamento de spawns ao longo de múltiplos frames,
    evitando travamentos e mantendo performance máxima durante picos de spawn.

    🚀 FUNCIONALIDADES PRINCIPAIS:

    1. PROCESSAMENTO DISTRIBUÍDO
       - Usa coroutines para yield em pontos estratégicos
       - Distribui cálculos pesados ao longo de múltiplos frames
       - Evita spikes de performance durante spawns massivos

    2. CONTROLE DE TEMPO POR FRAME
       - Monitora tempo de processamento por frame
       - Yield automático quando excede limites de tempo
       - Ajuste dinâmico baseado na performance

    3. PRIORIZAÇÃO INTELIGENTE
       - Bosses têm prioridade máxima (processamento imediato)
       - MVPs têm alta prioridade
       - Spawns normais usam processamento distribuído

    4. MÉTRICAS DE PERFORMANCE
       - Tracking de tempo de processamento
       - Contadores de yields realizados
       - Estatísticas de throughput

    ⚙️ CONFIGURAÇÃO:

    - MAX_PROCESS_TIME_PER_FRAME: Tempo máximo por frame (ms)
    - YIELD_CHECK_INTERVAL: Intervalo para verificar se deve yield
    - BATCH_SIZE: Tamanho do lote para processamento em batch

    🎯 FUNCIONAMENTO:

    1. Recebe requests de spawn
    2. Classifica por prioridade
    3. Processa em batches com yield points
    4. Retorna spawns prontos para execução
]]

---@class SpawnRequest
---@field enemyClass table Classe do inimigo
---@field position { x: number, y: number } Posição de spawn
---@field options table|nil Opções do spawn (isMVP, isBoss, etc.)
---@field priority number Prioridade do spawn (1=max, 3=normal)
---@field createdAt number Timestamp de criação do request

---@class ProcessedSpawn
---@field enemyClass table
---@field position { x: number, y: number }
---@field options table|nil
---@field priority number

---@class AsyncSpawnProcessor
---@field pendingRequests SpawnRequest[] Fila de requests pendentes
---@field processedSpawns ProcessedSpawn[] Spawns prontos para execução
---@field activeCoroutines table<string, thread> Coroutines ativas por tipo
---@field isProcessing boolean Se está processando atualmente
---@field frameStartTime number Timestamp do início do frame atual
---@field maxProcessTimePerFrame number Tempo máximo de processamento por frame (ms)
---@field yieldCheckInterval number Intervalo para verificar yield
---@field batchSize number Tamanho do batch para processamento
---@field metrics table Métricas de performance
local AsyncSpawnProcessor = {}
AsyncSpawnProcessor.__index = AsyncSpawnProcessor

-- Constantes de configuração
local CONFIG = {
    MAX_PROCESS_TIME_PER_FRAME = 2.0, -- 2ms por frame
    YIELD_CHECK_INTERVAL = 5,         -- Verifica yield a cada 5 spawns
    BATCH_SIZE = 10,                  -- Processa 10 spawns por batch
    PRIORITY_HIGH = 1,                -- Boss/MVP
    PRIORITY_MEDIUM = 2,              -- Spawns especiais
    PRIORITY_NORMAL = 3               -- Spawns normais
}

function AsyncSpawnProcessor:new()
    local instance = setmetatable({}, AsyncSpawnProcessor)

    instance.pendingRequests = {}
    instance.processedSpawns = {}
    instance.activeCoroutines = {}
    instance.isProcessing = false

    -- Configuração de performance
    instance.maxProcessTimePerFrame = CONFIG.MAX_PROCESS_TIME_PER_FRAME
    instance.yieldCheckInterval = CONFIG.YIELD_CHECK_INTERVAL
    instance.batchSize = CONFIG.BATCH_SIZE

    -- Métricas de performance
    instance.metrics = {
        totalProcessed = 0,
        totalYields = 0,
        avgProcessTime = 0,
        frameProcessTime = 0,
        batchesProcessed = 0
    }

    Logger.info("[AsyncSpawnProcessor]",
        string.format("Processador assíncrono inicializado. MaxTime/Frame: %.1fms, BatchSize: %d",
            instance.maxProcessTimePerFrame, instance.batchSize))

    return instance
end

--- Adiciona um request de spawn à fila de processamento
---@param enemyClass table
---@param position { x: number, y: number }
---@param options table|nil
function AsyncSpawnProcessor:addSpawnRequest(enemyClass, position, options)
    options = options or {}

    -- Determina prioridade baseada no tipo
    local priority = CONFIG.PRIORITY_NORMAL
    if options.isBoss then
        priority = CONFIG.PRIORITY_HIGH
    elseif options.isMVP then
        priority = CONFIG.PRIORITY_MEDIUM
    end

    local request = {
        enemyClass = enemyClass,
        position = { x = position.x, y = position.y }, -- Copia posição
        options = options,
        priority = priority,
        createdAt = love.timer.getTime()
    }

    table.insert(self.pendingRequests, request)

    -- Ordena por prioridade (menor número = maior prioridade)
    table.sort(self.pendingRequests, function(a, b)
        if a.priority == b.priority then
            return a.createdAt < b.createdAt -- FIFO para mesma prioridade
        end
        return a.priority < b.priority
    end)

    Logger.debug("[AsyncSpawnProcessor:addSpawnRequest]",
        string.format("Request adicionado. Prioridade: %d, Fila: %d pending",
            priority, #self.pendingRequests))
end

--- Atualiza o processador, executando coroutines e gerenciando spawns
---@param dt number
function AsyncSpawnProcessor:update(dt)
    self.frameStartTime = love.timer.getTime()
    self.metrics.frameProcessTime = 0

    -- Processa requests de alta prioridade imediatamente
    self:processHighPriorityRequests()

    -- Inicia processamento assíncrono se há requests pendentes e não está processando
    if #self.pendingRequests > 0 and not self.isProcessing then
        self:startAsyncProcessing()
    end

    -- Resume coroutines ativas
    self:updateActiveCoroutines()

    -- Atualiza métricas
    self:updateMetrics()
end

--- Processa requests de alta prioridade (boss/MVP) imediatamente
function AsyncSpawnProcessor:processHighPriorityRequests()
    local processed = 0

    for i = #self.pendingRequests, 1, -1 do
        local request = self.pendingRequests[i]

        if request.priority == CONFIG.PRIORITY_HIGH then
            -- Remove da fila pendente
            table.remove(self.pendingRequests, i)

            -- Adiciona aos processados imediatamente
            table.insert(self.processedSpawns, {
                enemyClass = request.enemyClass,
                position = request.position,
                options = request.options,
                priority = request.priority
            })

            processed = processed + 1

            Logger.debug("[AsyncSpawnProcessor:processHighPriorityRequests]",
                "Spawn de alta prioridade processado imediatamente")
        end
    end

    if processed > 0 then
        self.metrics.totalProcessed = self.metrics.totalProcessed + processed
    end
end

--- Inicia o processamento assíncrono para requests de prioridade normal/média
function AsyncSpawnProcessor:startAsyncProcessing()
    if self.isProcessing then return end

    self.isProcessing = true

    -- Cria coroutine para processamento assíncrono
    local processingCoroutine = coroutine.create(function()
        return self:asyncProcessingLoop()
    end)

    self.activeCoroutines["main_processing"] = processingCoroutine

    Logger.debug("[AsyncSpawnProcessor:startAsyncProcessing]",
        string.format("Iniciando processamento assíncrono para %d requests", #self.pendingRequests))
end

--- Loop principal de processamento assíncrono
function AsyncSpawnProcessor:asyncProcessingLoop()
    local processed = 0
    local currentBatch = {}

    while #self.pendingRequests > 0 do
        -- Pega próximo request
        local request = table.remove(self.pendingRequests, 1)
        if request then
            table.insert(currentBatch, request)
        end

        processed = processed + 1

        -- Verifica se deve yield baseado no tempo
        if processed % self.yieldCheckInterval == 0 then
            if self:shouldYield() then
                -- Processa batch atual antes de yield
                if #currentBatch > 0 then
                    self:processBatch(currentBatch)
                    currentBatch = {}
                end

                self.metrics.totalYields = self.metrics.totalYields + 1
                coroutine.yield() -- Yield para próximo frame
            end
        end

        -- Processa em batches
        if #currentBatch >= self.batchSize then
            self:processBatch(currentBatch)
            currentBatch = {}
        end
    end

    -- Processa batch final se houver
    if #currentBatch > 0 then
        self:processBatch(currentBatch)
    end

    self.isProcessing = false
    self.metrics.totalProcessed = self.metrics.totalProcessed + processed

    Logger.debug("[AsyncSpawnProcessor:asyncProcessingLoop]",
        string.format("Processamento assíncrono finalizado. Processados: %d", processed))
end

--- Processa um batch de requests
---@param batch SpawnRequest[]
function AsyncSpawnProcessor:processBatch(batch)
    local batchStartTime = love.timer.getTime()

    for _, request in ipairs(batch) do
        -- Simula processamento (validação, cálculos, etc.)
        -- Em um cenário real, aqui seria feita validação de posição,
        -- verificação de colisões, ajustes de stats, etc.

        table.insert(self.processedSpawns, {
            enemyClass = request.enemyClass,
            position = request.position,
            options = request.options,
            priority = request.priority
        })
    end

    local batchTime = (love.timer.getTime() - batchStartTime) * 1000
    self.metrics.frameProcessTime = self.metrics.frameProcessTime + batchTime
    self.metrics.batchesProcessed = self.metrics.batchesProcessed + 1

    Logger.debug("[AsyncSpawnProcessor:processBatch]",
        string.format("Batch processado: %d spawns em %.2fms", #batch, batchTime))
end

--- Verifica se deve fazer yield baseado no tempo de processamento
---@return boolean
function AsyncSpawnProcessor:shouldYield()
    local currentTime = love.timer.getTime()
    local frameTime = (currentTime - self.frameStartTime) * 1000 -- Converte para ms

    return frameTime >= self.maxProcessTimePerFrame
end

--- Atualiza coroutines ativas
function AsyncSpawnProcessor:updateActiveCoroutines()
    for key, co in pairs(self.activeCoroutines) do
        if co then
            local status = coroutine.status(co)

            if status == "suspended" then
                -- Resume a coroutine
                local success, error = coroutine.resume(co)
                if not success then
                    Logger.warn("[AsyncSpawnProcessor:updateActiveCoroutines]",
                        string.format("Erro na coroutine %s: %s", key, tostring(error)))
                    self.activeCoroutines[key] = nil
                end
            elseif status == "dead" then
                -- Remove coroutine finalizada
                self.activeCoroutines[key] = nil
            end
        end
    end
end

--- Retorna e remove spawns processados prontos para execução
---@param maxCount number|nil Número máximo de spawns a retornar
---@return ProcessedSpawn[]
function AsyncSpawnProcessor:getProcessedSpawns(maxCount)
    maxCount = maxCount or math.huge
    local result = {}

    for i = 1, math.min(#self.processedSpawns, maxCount) do
        table.insert(result, table.remove(self.processedSpawns, 1))
    end

    if #result > 0 then
        Logger.debug("[AsyncSpawnProcessor:getProcessedSpawns]",
            string.format("Retornando %d spawns processados. %d restantes",
                #result, #self.processedSpawns))
    end

    return result
end

--- Atualiza métricas de performance
function AsyncSpawnProcessor:updateMetrics()
    -- Calcula tempo médio de processamento
    if self.metrics.batchesProcessed > 0 then
        self.metrics.avgProcessTime = self.metrics.frameProcessTime / self.metrics.batchesProcessed
    end
end

--- Retorna informações de status e métricas
---@return table
function AsyncSpawnProcessor:getStatus()
    return {
        pendingRequests = #self.pendingRequests,
        processedSpawns = #self.processedSpawns,
        isProcessing = self.isProcessing,
        activeCoroutines = self:countActiveCoroutines(),
        metrics = {
            totalProcessed = self.metrics.totalProcessed,
            totalYields = self.metrics.totalYields,
            avgProcessTime = self.metrics.avgProcessTime,
            frameProcessTime = self.metrics.frameProcessTime,
            batchesProcessed = self.metrics.batchesProcessed
        }
    }
end

--- Conta coroutines ativas
---@return number
function AsyncSpawnProcessor:countActiveCoroutines()
    local count = 0
    for _ in pairs(self.activeCoroutines) do
        count = count + 1
    end
    return count
end

--- Limpa todos os requests e spawns pendentes
function AsyncSpawnProcessor:clear()
    self.pendingRequests = {}
    self.processedSpawns = {}
    self.activeCoroutines = {}
    self.isProcessing = false

    Logger.info("[AsyncSpawnProcessor:clear]", "Processador limpo")
end

--- Ajusta configurações de performance em runtime
---@param config table
function AsyncSpawnProcessor:updateConfig(config)
    if config.maxProcessTimePerFrame then
        self.maxProcessTimePerFrame = config.maxProcessTimePerFrame
    end
    if config.yieldCheckInterval then
        self.yieldCheckInterval = config.yieldCheckInterval
    end
    if config.batchSize then
        self.batchSize = config.batchSize
    end

    Logger.info("[AsyncSpawnProcessor:updateConfig]",
        string.format("Configuração atualizada: MaxTime=%.1fms, YieldInterval=%d, BatchSize=%d",
            self.maxProcessTimePerFrame, self.yieldCheckInterval, self.batchSize))
end

return AsyncSpawnProcessor
