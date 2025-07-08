-- examples/async_spawn_system_usage.lua
--[[
    EXEMPLO DE USO DO SISTEMA DE SPAWNS ASSÍNCRONOS

    Este arquivo demonstra como usar o sistema de spawns assíncronos otimizado,
    incluindo monitoramento de performance, configuração dinâmica e debugging.

    🚀 FUNCIONALIDADES DEMONSTRADAS:

    1. Uso básico do sistema assíncrono
    2. Configuração de performance em tempo real
    3. Monitoramento e análise de métricas
    4. Auto-otimização automática
    5. Debugging avançado
    6. Integração com EnemyManager

    ⚙️ CONFIGURAÇÕES IMPORTANTES:

    - O sistema é thread-like usando coroutines
    - Spawns são distribuídos ao longo de múltiplos frames
    - Priorização automática (Boss > MVP > Normal)
    - Métricas em tempo real para otimização
]]

-- Exemplo de integração no EnemyManager
local function setupAsyncSpawnSystem(enemyManager, playerManager, mapManager, hordeConfig)
    -- O SpawnController já vem com sistema assíncrono integrado
    local spawnController = SpawnController:new(enemyManager, playerManager, mapManager)
    spawnController:setup(hordeConfig)

    print("✅ Sistema de spawns assíncronos configurado!")
    print("   - Processamento distribuído ativo")
    print("   - Monitor de performance ativo")
    print("   - Auto-otimização ativa")

    return spawnController
end

-- Exemplo de monitoramento em tempo real
local function monitorSpawnPerformance(spawnController)
    -- Obtém estatísticas em tempo real
    local realtimeStats = spawnController:getRealtimeStats()

    print("\n📊 ESTATÍSTICAS EM TEMPO REAL:")
    print(string.format("   FPS: %.1f", realtimeStats.fps))
    print(string.format("   Frame Time: %.2fms", realtimeStats.frameTime))
    print(string.format("   Spawn Throughput: %.2f spawns/s", realtimeStats.spawnThroughput))
    print(string.format("   System Health: %s", realtimeStats.systemHealth))
    print(string.format("   Async Load: %d", realtimeStats.asyncLoad or 0))

    -- Verifica se precisa de atenção
    if realtimeStats.systemHealth == "overloaded" then
        print("⚠️  ATENÇÃO: Sistema sobrecarregado!")
        print("   Considere reduzir spawn rate ou ajustar configurações")
    elseif realtimeStats.systemHealth == "stressed" then
        print("⚠️  AVISO: Sistema sob stress")
        print("   Monitorando para possível otimização automática")
    end
end

-- Exemplo de configuração dinâmica
local function optimizeSpawnSettings(spawnController, targetFPS)
    targetFPS = targetFPS or 60
    local currentFPS = love.timer.getFPS()

    print(string.format("\n🔧 OTIMIZAÇÃO DINÂMICA (Target: %dfps, Atual: %.1ffps)", targetFPS, currentFPS))

    if currentFPS < targetFPS * 0.9 then
        -- Performance baixa: otimiza para performance
        local performanceConfig = {
            maxProcessTimePerFrame = 1.5, -- Reduz tempo por frame
            yieldCheckInterval = 3,       -- Mais yields
            batchSize = 6                 -- Batches menores
        }

        spawnController:configureAsyncSystem(performanceConfig)
        print("   ⚡ Configuração otimizada para PERFORMANCE")
        print("      - Tempo por frame reduzido")
        print("      - Yields mais frequentes")
        print("      - Batches menores")
    elseif currentFPS > targetFPS * 1.1 then
        -- Performance alta: otimiza para throughput
        local throughputConfig = {
            maxProcessTimePerFrame = 3.0, -- Mais tempo por frame
            yieldCheckInterval = 8,       -- Menos yields
            batchSize = 15                -- Batches maiores
        }

        spawnController:configureAsyncSystem(throughputConfig)
        print("   🚀 Configuração otimizada para THROUGHPUT")
        print("      - Tempo por frame aumentado")
        print("      - Yields menos frequentes")
        print("      - Batches maiores")
    else
        print("   ✅ Performance equilibrada - sem mudanças necessárias")
    end
end

-- Exemplo de análise de performance histórica
local function analyzePerformanceHistory(spawnController)
    local stats = spawnController:getAggregatedPerformanceStats()

    if stats.error then
        print("\n❌ ERRO: " .. stats.error)
        return
    end

    print("\n📈 ANÁLISE DE PERFORMANCE HISTÓRICA:")
    print(string.format("   Samples: %d (%.1fs de monitoramento)",
        stats.sampleCount, stats.timeSpan))

    print(string.format("   Frame Time - Mín: %.2fms, Máx: %.2fms, Média: %.2fms",
        stats.frameTime.min, stats.frameTime.max, stats.frameTime.avg))

    print(string.format("   FPS - Mín: %.1f, Máx: %.1f, Média: %.1f",
        stats.fps.min, stats.fps.max, stats.fps.avg))

    print(string.format("   Throughput - Mín: %.2f, Máx: %.2f, Média: %.2f spawns/s",
        stats.spawnThroughput.min, stats.spawnThroughput.max, stats.spawnThroughput.avg))

    print(string.format("   Total Yields: %d", stats.totalYields))

    -- Distribuição de health
    if stats.healthDistribution then
        print("   Distribuição de Health:")
        for health, count in pairs(stats.healthDistribution) do
            local percentage = (count / stats.sampleCount) * 100
            print(string.format("      %s: %.1f%% (%d samples)", health, percentage, count))
        end
    end
end

-- Exemplo de relatório completo
local function generateDetailedReport(spawnController)
    local report = spawnController:getPerformanceReport()

    if report.error then
        print("\n❌ ERRO: " .. report.error)
        return
    end

    print("\n📋 RELATÓRIO DETALHADO DE PERFORMANCE:")
    print(string.format("   Timestamp: %.2f", report.timestamp))
    print(string.format("   System Health: %s", report.summary.systemHealth))
    print(string.format("   Avg Frame Time: %.2fms", report.summary.avgFrameTime))
    print(string.format("   Avg FPS: %.1f", report.summary.avgFPS))
    print(string.format("   Avg Throughput: %.2f spawns/s", report.summary.avgThroughput))
    print(string.format("   Monitoring Time: %.1fs", report.summary.monitoringTime))

    -- Configuração atual
    print("\n   Configuração Atual:")
    print(string.format("      Max Process Time: %.1fms", report.currentConfig.maxProcessTimePerFrame))
    print(string.format("      Yield Interval: %d", report.currentConfig.yieldCheckInterval))
    print(string.format("      Batch Size: %d", report.currentConfig.batchSize))

    -- Recomendações
    if #report.recommendations > 0 then
        print("\n   💡 Recomendações:")
        for i, rec in ipairs(report.recommendations) do
            print(string.format("      %d. %s", i, rec))
        end
    end

    -- Eventos recentes
    if #report.recentEvents > 0 then
        print(string.format("\n   📅 Eventos Recentes (%d):", #report.recentEvents))
        for i, event in ipairs(report.recentEvents) do
            if event.type == "performance_alert" then
                print(string.format("      %d. [ALERT] %d alertas em %.2fs",
                    i, #event.alerts, event.timestamp))
            elseif event.type == "auto_optimization" then
                print(string.format("      %d. [AUTO-OPT] Otimização aplicada em %.2fs",
                    i, event.timestamp))
            end
        end
    end
end

-- Exemplo de debugging avançado
local function debugSpawnSystem(spawnController)
    print("\n🔍 DEBUG DO SISTEMA DE SPAWNS:")

    -- Info básica do sistema
    local queueInfo = spawnController:getSpawnQueueInfo()
    print(string.format("   Estado: Pausado=%s, Permanente=%s",
        tostring(queueInfo.isPaused), tostring(queueInfo.isPermanentlyPaused)))
    print(string.format("   Game Timer: %.2fs", queueInfo.gameTimer))
    print(string.format("   Tempo de Pausa Total: %.2fs", queueInfo.totalPauseTime))

    -- Sistema Legacy
    print(string.format("   Fila Legacy: %d spawns (max %d por frame)",
        queueInfo.legacyQueue.count, queueInfo.legacyQueue.maxPerFrame))

    -- Sistema Assíncrono
    if queueInfo.asyncSystem and queueInfo.asyncSystem.pendingRequests then
        print(string.format("   Sistema Assíncrono:"))
        print(string.format("      Requests Pendentes: %d", queueInfo.asyncSystem.pendingRequests))
        print(string.format("      Spawns Processados: %d", queueInfo.asyncSystem.processedSpawns))
        print(string.format("      Coroutines Ativas: %d", queueInfo.asyncSystem.activeCoroutines))
        print(string.format("      Total Processados: %d", queueInfo.asyncSystem.metrics.totalProcessed))
        print(string.format("      Total Yields: %d", queueInfo.asyncSystem.metrics.totalYields))
        print(string.format("      Tempo Médio: %.2fms", queueInfo.asyncSystem.metrics.avgProcessTime))
    end

    -- Test boss spawn control
    local debugInfo = spawnController:testBossSpawnControl(false)
    print(string.format("   Boss Info: Próximo=%d, Configurados=%d, Restantes=%d",
        debugInfo.nextBossIndex,
        debugInfo.totalBossesConfigured or 0,
        debugInfo.bossesRemaining or 0))
end

-- Exemplo de configuração do monitor de performance
local function configurePerformanceMonitoring(spawnController)
    print("\n⚙️  CONFIGURANDO MONITOR DE PERFORMANCE:")

    -- Ativa monitoramento com auto-otimização
    spawnController:configurePerformanceMonitor({
        enabled = true,
        autoOptimization = true
    })
    print("   ✅ Monitoramento ativado")
    print("   ✅ Auto-otimização ativada")

    -- Para desativar auto-otimização (se necessário)
    -- spawnController:configurePerformanceMonitor({
    --     autoOptimization = false
    -- })

    -- Para resetar histórico (se necessário)
    -- spawnController:resetPerformanceHistory()
end

-- Exemplo de uso completo em um game loop
local function gameLoopExample(spawnController, dt)
    -- 1. Update normal do sistema (já inclui processamento assíncrono)
    spawnController:update(dt)

    -- 2. Monitoramento periódico (a cada 5 segundos)
    local currentTime = love.timer.getTime()
    if not gameLoopExample.lastCheck then gameLoopExample.lastCheck = 0 end

    if currentTime - gameLoopExample.lastCheck >= 5.0 then
        gameLoopExample.lastCheck = currentTime

        -- Monitora performance
        monitorSpawnPerformance(spawnController)

        -- Otimização automática baseada na performance atual
        optimizeSpawnSettings(spawnController, 60) -- Target 60 FPS
    end

    -- 3. Relatório detalhado (a cada 30 segundos)
    if not gameLoopExample.lastReport then gameLoopExample.lastReport = 0 end

    if currentTime - gameLoopExample.lastReport >= 30.0 then
        gameLoopExample.lastReport = currentTime

        analyzePerformanceHistory(spawnController)
        generateDetailedReport(spawnController)
    end
end

-- Exemplo de configurações preset para diferentes cenários
local PERFORMANCE_PRESETS = {
    -- Para dispositivos de baixa performance
    LOW_END = {
        maxProcessTimePerFrame = 1.0,
        yieldCheckInterval = 3,
        batchSize = 5
    },

    -- Configuração balanceada
    BALANCED = {
        maxProcessTimePerFrame = 2.0,
        yieldCheckInterval = 5,
        batchSize = 10
    },

    -- Para dispositivos de alta performance
    HIGH_END = {
        maxProcessTimePerFrame = 4.0,
        yieldCheckInterval = 8,
        batchSize = 20
    },

    -- Para máximo throughput (muitos spawns)
    MAX_THROUGHPUT = {
        maxProcessTimePerFrame = 5.0,
        yieldCheckInterval = 10,
        batchSize = 25
    }
}

local function applyPerformancePreset(spawnController, presetName)
    local preset = PERFORMANCE_PRESETS[presetName]
    if not preset then
        print("❌ Preset não encontrado: " .. tostring(presetName))
        return
    end

    spawnController:configureAsyncSystem(preset)
    print(string.format("✅ Preset aplicado: %s", presetName))
    print(string.format("   MaxTime: %.1fms, YieldInterval: %d, BatchSize: %d",
        preset.maxProcessTimePerFrame, preset.yieldCheckInterval, preset.batchSize))
end

-- Função de exemplo para demonstrar uso completo
local function demonstrateAsyncSpawnSystem()
    print("🚀 DEMONSTRAÇÃO DO SISTEMA DE SPAWNS ASSÍNCRONOS")
    print("=" .. string.rep("=", 50))

    -- Nota: Este é um exemplo conceitual
    -- Em uso real, você obteria essas instâncias do seu sistema principal
    print("\n1. CONFIGURAÇÃO INICIAL")
    print("   SpawnController inicializado com:")
    print("   - AsyncSpawnProcessor integrado")
    print("   - SpawnPerformanceMonitor ativo")
    print("   - Auto-otimização habilitada")

    print("\n2. CONFIGURAÇÕES DISPONÍVEIS")
    print("   Presets de Performance:")
    for preset, config in pairs(PERFORMANCE_PRESETS) do
        print(string.format("   - %s: MaxTime=%.1fms, Batch=%d",
            preset, config.maxProcessTimePerFrame, config.batchSize))
    end

    print("\n3. FUNCIONALIDADES PRINCIPAIS")
    print("   ✅ Spawns distribuídos ao longo de múltiplos frames")
    print("   ✅ Priorização automática (Boss > MVP > Normal)")
    print("   ✅ Yield automático baseado em tempo de frame")
    print("   ✅ Monitoramento de performance em tempo real")
    print("   ✅ Auto-otimização baseada em métricas")
    print("   ✅ Debugging avançado com métricas detalhadas")

    print("\n4. BENEFÍCIOS")
    print("   🎯 Performance estável mesmo com muitos spawns")
    print("   🎯 Adaptação automática à capacidade do dispositivo")
    print("   🎯 Manutenção de 60fps em cenários intensos")
    print("   🎯 Transparência total para gameplay existente")

    print("\n✨ Sistema pronto para uso! Todas as funcionalidades")
    print("   originais de spawn são mantidas com performance otimizada.")
end

return {
    setupAsyncSpawnSystem = setupAsyncSpawnSystem,
    monitorSpawnPerformance = monitorSpawnPerformance,
    optimizeSpawnSettings = optimizeSpawnSettings,
    analyzePerformanceHistory = analyzePerformanceHistory,
    generateDetailedReport = generateDetailedReport,
    debugSpawnSystem = debugSpawnSystem,
    configurePerformanceMonitoring = configurePerformanceMonitoring,
    gameLoopExample = gameLoopExample,
    applyPerformancePreset = applyPerformancePreset,
    demonstrateAsyncSpawnSystem = demonstrateAsyncSpawnSystem,
    PERFORMANCE_PRESETS = PERFORMANCE_PRESETS
}
