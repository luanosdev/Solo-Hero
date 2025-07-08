local SceneManager = require("src.core.scene_manager")
local fonts = require("src.ui.fonts")
local ManagerRegistry = require("src.managers.manager_registry")
local DashCooldownIndicator = require("src.ui.components.dash_cooldown_indicator")
local Colors = require("src.ui.colors")
local ResolutionUtils = require("src.utils.resolution_utils")

-- === SISTEMA DE TEXTOS TEMÁTICOS PARA EXTRAÇÃO ===
local EXTRACTION_PROCESSING_TEXTS = {
    {
        technical = "Inicializando processamento de dados...",
        thematic = {
            title = "Iniciando Debriefing Operacional",
            subtitle = "Compilando dados da missão",
            detail = "Preparando relatório tático..."
        }
    },
    {
        technical = "Capturando dados da incursão...",
        thematic = {
            title = "Registrando Performance em Campo",
            subtitle = "Coletando métricas de combate",
            detail = "Analisando eficácia operacional..."
        }
    },
    {
        technical = "Limpando recursos do gameplay...",
        thematic = {
            title = "Encerrando Sistemas de Combate",
            subtitle = "Desativando protocolos de batalha",
            detail = "Finalizando conexões de campo..."
        }
    },
    {
        technical = "Processando itens extraídos...",
        thematic = {
            title = "Catalogando Recursos Obtidos",
            subtitle = "Verificando integridade dos materiais",
            detail = "Registrando aquisições em banco de dados..."
        }
    },
    {
        technical = "Calculando reputação e recompensas...",
        thematic = {
            title = "Avaliando Desempenho Operacional",
            subtitle = "Processando métricas de sucesso",
            detail = "Calculando impacto na reputação..."
        }
    },
    {
        technical = "Salvando progresso do caçador...",
        thematic = {
            title = "Atualizando Perfil do Caçador",
            subtitle = "Registrando evolução e experiência",
            detail = "Sincronizando dados com central..."
        }
    },
    {
        technical = "Processando dados da interface...",
        thematic = {
            title = "Preparando Interface de Resultados",
            subtitle = "Organizando dados para apresentação",
            detail = "Otimizando elementos visuais..."
        }
    },
    {
        technical = "Processando estatísticas finais...",
        thematic = {
            title = "Compilando Relatório Final",
            subtitle = "Consolidando dados da missão",
            detail = "Preparando sumário executivo..."
        }
    },
    {
        technical = "Preparando sumário de extração...",
        thematic = {
            title = "Finalizando Debriefing",
            subtitle = "Organizando apresentação final",
            detail = "Preparando interface de resultados..."
        }
    }
}

-- === SISTEMA DE DICAS PARA TRANSIÇÃO ===
local EXTRACTION_TIPS = {
    -- Dicas sobre Performance
    "Analize seus stats finais para identificar pontos de melhoria.",
    "Sobreviver por mais tempo rende mais experiência e reputação.",
    "Chefes derrotados concedem recompensas especiais.",

    -- Dicas sobre Progressão
    "Caçadores de rank alto precisam de equipamentos melhores.",
    "Combine diferentes tipos de equipamento para sinergias únicas.",
    "Administre bem seus recursos entre missões.",
    "Caçadores de rank mais alto não trazem tanta reputação em portais de rank mais baixo.",

    -- Dicas sobre Sistema
    "Use o tempo no lobby para organizar inventário e equipamentos.",
    "O mercado tem ofertas limitadas que mudam periodicamente.",
    "Diferentes portais têm diferentes tipos de recompensas.",
    "Falhar em uma missão não é o fim - aprenda e tente novamente.",

    -- Dicas Estratégicas
    "Portais de rank mais baixo são ideais para farmar recursos.",
    "Conhecimento dos inimigos é tão importante quanto equipamentos."
}

-- Configurações de performance ultra-otimizada para game over
local PERFORMANCE_CONFIG = {
    PROCESS_BUDGET_MS = 2,        -- Reduzido para 2ms para manter 60+ FPS mesmo em game over
    MAX_OPERATIONS_PER_FRAME = 1, -- Apenas 1 operação por frame para máxima estabilidade
    ANIMATION_SPEED = 1.5,        -- Animações mais rápidas para compensar processamento mais lento
    TIP_CHANGE_INTERVAL = 4.0,    -- Dicas trocam mais rápido para manter interesse visual
    GC_CHUNK_SIZE = 15,           -- Coleta de lixo ainda menor para evitar stutters
    FRAME_TARGET_MS = 16.67,      -- 60 FPS rigoroso
    MAX_RESUME_TIME_MS = 1.5      -- Máximo tempo permitido para uma operação de corrotina
}

--- Cena de transição exibida durante o processamento da extração
local ExtractionTransitionScene = {}

-- Estado do processamento
ExtractionTransitionScene.processingTasks = {}
ExtractionTransitionScene.currentTaskIndex = 1
ExtractionTransitionScene.totalTasks = 0
ExtractionTransitionScene.currentTaskName = "Iniciando..."
ExtractionTransitionScene.isComplete = false
ExtractionTransitionScene.processingCoroutine = nil

-- Dados recebidos do gameplay_scene
ExtractionTransitionScene.gameplayData = nil
ExtractionTransitionScene.extractionType = "success" -- "success", "death", "manual"

-- Dados processados para extraction_summary_scene
ExtractionTransitionScene.processedData = {}

-- Sistema temático
ExtractionTransitionScene.currentThematicData = nil
ExtractionTransitionScene.currentTip = ""
ExtractionTransitionScene.tipTimer = 0
ExtractionTransitionScene.animationTimer = 0

-- Animação de processamento
ExtractionTransitionScene.processingAnimator = nil
ExtractionTransitionScene.processingAnimationTimer = 0
ExtractionTransitionScene.processingAnimationSpeed = 0.5
ExtractionTransitionScene.currentProcessingFrame = 1
ExtractionTransitionScene.maxProcessingFrames = 7

-- Cache de processamento
ExtractionTransitionScene.processingCache = {
    itemsProcessed = 0,
    totalItems = 0,
    currentBatchIndex = 0,
    statsProcessed = false,
    reputationProcessed = false
}

--- Inicializa as tarefas de processamento
function ExtractionTransitionScene:_initializeProcessingTasks()
    self.processingTasks = {}

    local taskFunctions = {
        function() return self:_initializeTransition() end,
        function() return self:_captureGameplayData() end,
        function() return self:_cleanupGameplayResources() end,
        function() return self:_processExtractedItemsChunked() end,
        function() return self:_calculateReputationAndRewards() end,
        function() return self:_processSaveHunterProgress() end,
        function() return self:_prepareInterfaceData() end,
        function() return self:_processFinalStatistics() end,
        function() return self:_prepareExtractionSummary() end
    }

    for i, thematicData in ipairs(EXTRACTION_PROCESSING_TEXTS) do
        if taskFunctions[i] then
            table.insert(self.processingTasks, {
                name = thematicData.thematic.title,
                thematicData = thematicData.thematic,
                task = taskFunctions[i]
            })
        end
    end

    self.totalTasks = #self.processingTasks
    self.currentTaskIndex = 1

    -- Inicializar sistema de dicas
    self:_selectRandomTip()
    self.tipTimer = 0
    self.animationTimer = 0

    -- Inicializar animador de processamento
    self.processingAnimator = DashCooldownIndicator:new()
    self.processingAnimationTimer = 0
    self.currentProcessingFrame = 1

    Logger.info("ExtractionTransitionScene",
        string.format("Processamento de extração iniciado com %d tarefas", self.totalTasks))
end

--- Seleciona uma dica aleatória do pool
function ExtractionTransitionScene:_selectRandomTip()
    if #EXTRACTION_TIPS > 0 then
        local randomIndex = love.math.random(1, #EXTRACTION_TIPS)
        self.currentTip = EXTRACTION_TIPS[randomIndex]
        Logger.debug("ExtractionTransitionScene",
            "Nova dica selecionada: " .. string.sub(self.currentTip, 1, 50) .. "...")
    end
end

--- Cria corrotina principal de processamento
function ExtractionTransitionScene:_createProcessingCoroutine()
    return coroutine.create(function()
        local startTime = love.timer.getTime()

        for i, taskData in ipairs(self.processingTasks) do
            self.currentTaskIndex = i
            self.currentTaskName = taskData.name
            self.currentThematicData = taskData.thematicData

            Logger.debug("ExtractionTransitionScene",
                string.format("Executando tarefa %d/%d: %s", i, self.totalTasks, taskData.name))

            local taskStartTime = love.timer.getTime()

            -- Executa tarefa em loop até completar
            local completed = false
            while not completed do
                local success, result = pcall(taskData.task)

                if not success then
                    Logger.error("ExtractionTransitionScene",
                        string.format("ERRO CRÍTICO na tarefa %d/%d '%s': %s",
                            i, self.totalTasks, taskData.name, tostring(result)))

                    -- Log do stack trace para debug
                    Logger.error("ExtractionTransitionScene", debug.traceback())

                    error(string.format("Falha no processamento da tarefa '%s': %s", taskData.name, tostring(result)))
                end

                -- Se a tarefa retornar true, está completa
                if result == true then
                    completed = true
                end

                -- Sempre yield para manter fluidez
                coroutine.yield()
            end

            local taskTime = love.timer.getTime() - taskStartTime
            Logger.debug("ExtractionTransitionScene",
                string.format("Tarefa '%s' completa em %.1fms", taskData.name, taskTime * 1000))

            -- Delay artificial para visualização reduzido
            local minVisibleTime = 0.4
            local taskEndTime = love.timer.getTime()
            while (taskEndTime - taskStartTime) < minVisibleTime do
                coroutine.yield()
                taskEndTime = love.timer.getTime()
            end
        end

        local totalTime = love.timer.getTime() - startTime
        Logger.info("ExtractionTransitionScene", string.format("Processamento completo em %.1fms", totalTime * 1000))
        self.isComplete = true
    end)
end

-- === TAREFAS DE PROCESSAMENTO ===

--- Inicializa sistemas de transição
function ExtractionTransitionScene:_initializeTransition()
    -- Resetar cache
    self.processingCache = {
        itemsProcessed = 0,
        totalItems = 0,
        currentBatchIndex = 0,
        statsProcessed = false,
        reputationProcessed = false
    }

    -- Preparar estrutura de dados processados
    self.processedData = {
        portalData = nil,
        hunterId = nil,
        hunterData = nil,
        wasSuccess = nil,
        extractedItems = {},
        extractedEquipment = {},
        gameplayStats = {},
        finalStats = {},
        archetypeIds = {},
        archetypeManagerInstance = nil,
        reputationDetails = nil
    }

    return true
end

--- Captura todos os dados necessários do gameplay
function ExtractionTransitionScene:_captureGameplayData()
    if not self.gameplayData then
        error("Dados do gameplay não fornecidos!")
    end

    -- Extrair dados básicos
    self.processedData.portalData = self.gameplayData.portalData
    self.processedData.hunterId = self.gameplayData.hunterId
    self.processedData.wasSuccess = self.extractionType == "success"

    -- Usar dados do hunter já fornecidos pelo GameOverManager/ExtractionManager
    -- (para evitar tentar capturar dados de hunter já excluído)
    if self.gameplayData.hunterData then
        self.processedData.hunterData = self.gameplayData.hunterData
        Logger.debug("ExtractionTransitionScene",
            string.format("Dados do hunter obtidos via gameplayData: %s (rank %s)",
                self.processedData.hunterData.name or "Desconhecido",
                self.processedData.hunterData.finalRankId or "Desconhecido"))
    else
        -- Fallback: tentar capturar do HunterManager (caso seja extração bem-sucedida)
        ---@type HunterManager|nil
        local hunterManager = ManagerRegistry:tryGet("hunterManager")
        if hunterManager and self.gameplayData.hunterId then
            local hunterData = hunterManager:getHunterData(self.gameplayData.hunterId)
            if hunterData then
                self.processedData.hunterData = hunterData
                Logger.debug("ExtractionTransitionScene", "Dados do hunter capturados via fallback do HunterManager")
            else
                Logger.warn("ExtractionTransitionScene",
                    string.format("Hunter ID %s não encontrado e não fornecido via gameplayData",
                        tostring(self.gameplayData.hunterId)))
                self.processedData.hunterData = {
                    id = self.gameplayData.hunterId,
                    finalRankId = nil,
                    name = "Hunter Não Encontrado"
                }
            end
        else
            Logger.warn("ExtractionTransitionScene", "HunterManager não disponível e dados não fornecidos")
            self.processedData.hunterData = {
                id = self.gameplayData.hunterId,
                finalRankId = nil,
                name = "Dados Não Disponíveis"
            }
        end
    end

    -- Obter dados de gameplay dos managers (verificação defensiva)
    ---@type PlayerManager|nil
    local playerMgr = ManagerRegistry:tryGet("playerManager")
    ---@type InventoryManager|nil
    local inventoryMgr = ManagerRegistry:tryGet("inventoryManager")
    ---@type GameStatisticsManager|nil
    local gameStatsMgr = ManagerRegistry:tryGet("gameStatisticsManager")

    if playerMgr then
        -- Capturar stats finais e equipamentos
        if playerMgr.getCurrentFinalStats then
            self.processedData.finalStats = playerMgr:getCurrentFinalStats() or {}
        end
        if playerMgr.getCurrentEquipmentGameplay then
            self.processedData.extractedEquipment = playerMgr:getCurrentEquipmentGameplay() or {}
        end
        Logger.debug("ExtractionTransitionScene", "Dados do playerManager capturados")
    else
        Logger.warn("ExtractionTransitionScene", "PlayerManager não disponível")
        self.processedData.finalStats = {}
        self.processedData.extractedEquipment = {}
    end

    if inventoryMgr and inventoryMgr.getAllItemsGameplay then
        self.processedData.extractedItems = inventoryMgr:getAllItemsGameplay() or {}
        Logger.debug("ExtractionTransitionScene", "Dados do inventoryManager capturados")
    else
        Logger.warn("ExtractionTransitionScene", "InventoryManager não disponível")
        self.processedData.extractedItems = {}
    end

    if gameStatsMgr and gameStatsMgr.getRawStats then
        self.processedData.gameplayStats = gameStatsMgr:getRawStats() or {}
        Logger.debug("ExtractionTransitionScene", "Dados do gameStatisticsManager capturados")
    else
        Logger.warn("ExtractionTransitionScene", "GameStatisticsManager não disponível")
        self.processedData.gameplayStats = {}
    end

    -- Capturar manager de arquétipos
    ---@type ArchetypeManager|nil
    self.processedData.archetypeManagerInstance = ManagerRegistry:tryGet("archetypeManager")
    if self.processedData.hunterData and self.processedData.hunterData.archetypeIds then
        self.processedData.archetypeIds = self.processedData.hunterData.archetypeIds
    else
        self.processedData.archetypeIds = {}
    end

    Logger.info("ExtractionTransitionScene", "Dados do gameplay capturados com sucesso")
    return true
end

--- Limpa recursos do gameplay de forma chunked
function ExtractionTransitionScene:_cleanupGameplayResources()
    -- ETAPA 1: Limpar sistemas locais que o gameplay_scene não limpou
    local SceneManager = require("src.core.scene_manager")
    if SceneManager.currentScene and SceneManager.currentScene._cleanupLocalSystems then
        Logger.debug("ExtractionTransitionScene", "Limpando sistemas locais do gameplay_scene...")
        pcall(SceneManager.currentScene._cleanupLocalSystems, SceneManager.currentScene)
    end

    -- ETAPA 2: Lista de managers de gameplay na ordem correta de limpeza
    local gameplayManagers = {
        "extractionManager",
        "extractionPortalManager",
        "hudGameplayManager",
        "experienceOrbManager",
        "dropManager",
        "enemyManager"
        -- NÃO incluir playerManager e inventoryManager ainda - precisamos dos dados
    }

    for _, managerName in ipairs(gameplayManagers) do
        local manager = ManagerRegistry:tryGet(managerName)
        if manager then
            Logger.debug("ExtractionTransitionScene", string.format("Limpando %s...", managerName))

            -- Tenta diferentes métodos de limpeza
            if manager.destroy and type(manager.destroy) == "function" then
                manager:destroy()
            elseif manager.reset and type(manager.reset) == "function" then
                manager:reset()
            elseif manager.cleanup and type(manager.cleanup) == "function" then
                manager:cleanup()
            end

            -- Remove do registry
            ManagerRegistry:unregister(managerName)
            Logger.debug("ExtractionTransitionScene", string.format("%s limpo", managerName))
        end

        -- Yield a cada manager para manter responsividade
        coroutine.yield()
    end

    -- Força coleta de lixo suave (reduzida)
    collectgarbage("step", PERFORMANCE_CONFIG.GC_CHUNK_SIZE)
    Logger.info("ExtractionTransitionScene", "Recursos de gameplay limpos")
    return true
end

--- Processa itens extraídos de forma chunked
function ExtractionTransitionScene:_processExtractedItemsChunked()
    ---@type ItemDataManager|nil
    local itemDataMgr = ManagerRegistry:tryGet("itemDataManager")
    if not itemDataMgr then
        Logger.warn("ExtractionTransitionScene", "ItemDataManager não encontrado")
        return true
    end

    -- Calcula total de itens na primeira execução
    if self.processingCache.totalItems == 0 then
        local totalItems = 0
        if self.processedData.extractedItems then
            totalItems = totalItems + #self.processedData.extractedItems
        end
        if self.processedData.extractedEquipment then
            for _ in pairs(self.processedData.extractedEquipment) do
                totalItems = totalItems + 1
            end
        end
        self.processingCache.totalItems = totalItems
        Logger.debug("ExtractionTransitionScene", string.format("Total de itens para processar: %d", totalItems))
    end

    -- Processa lote de itens
    local itemsThisFrame = 0
    local maxItemsPerFrame = PERFORMANCE_CONFIG.MAX_OPERATIONS_PER_FRAME

    -- Processa itens da mochila
    if self.processedData.extractedItems then
        local startIndex = self.processingCache.currentBatchIndex + 1
        local endIndex = math.min(startIndex + maxItemsPerFrame - 1, #self.processedData.extractedItems)

        for i = startIndex, endIndex do
            local item = self.processedData.extractedItems[i]
            if item and item.itemBaseId then
                -- Validar e enriquecer dados do item
                local baseData = itemDataMgr:getBaseItemData(item.itemBaseId)
                if baseData then
                    item.icon = baseData.icon or nil
                    item.rarity = item.rarity or baseData.rarity or 'E'
                    self.processingCache.itemsProcessed = self.processingCache.itemsProcessed + 1
                    itemsThisFrame = itemsThisFrame + 1
                end
            end
        end

        self.processingCache.currentBatchIndex = endIndex

        -- Se ainda há itens para processar, não completou
        if endIndex < #self.processedData.extractedItems then
            return false
        end
    end

    -- Processa equipamentos (sempre será rápido, poucos itens)
    if self.processedData.extractedEquipment then
        for slotId, item in pairs(self.processedData.extractedEquipment) do
            if item and item.itemBaseId then
                local baseData = itemDataMgr:getBaseItemData(item.itemBaseId)
                if baseData then
                    item.icon = baseData.icon or nil
                    item.rarity = item.rarity or baseData.rarity or 'E'
                    self.processingCache.itemsProcessed = self.processingCache.itemsProcessed + 1
                end
            end
        end
    end

    Logger.info("ExtractionTransitionScene",
        string.format("Processamento de itens completo: %d/%d itens",
            self.processingCache.itemsProcessed, self.processingCache.totalItems))
    return true
end

--- Calcula reputação e recompensas
function ExtractionTransitionScene:_calculateReputationAndRewards()
    ---@type ReputationManager|nil
    local reputationManager = ManagerRegistry:tryGet("reputationManager")
    if not reputationManager then
        Logger.warn("ExtractionTransitionScene", "ReputationManager não encontrado")
        return true
    end

    -- Verificação defensiva: apenas processar reputação se temos dados válidos do hunter
    local hunterData = self.processedData.hunterData
    if not hunterData or not hunterData.finalRankId or hunterData.finalRankId == "" then
        Logger.warn("ExtractionTransitionScene",
            "Dados do hunter inválidos ou ausentes - criando reputationDetails padrão")
        self.processedData.reputationDetails = {
            basePoints = 0,
            rankBonusMultiplier = 1,
            rankBonusPoints = 0,
            lootPoints = 0,
            penaltyMultiplier = 0,
            totalChange = 0,
            wasSuccess = self.processedData.wasSuccess,
            errorMessage = "Hunter data not available (possibly deleted)"
        }
        return true
    end

    -- Combinar todos os itens extraídos
    local allExtractedItems = {}

    -- Adicionar itens da mochila
    if self.processedData.extractedItems then
        for _, item in ipairs(self.processedData.extractedItems) do
            if item and item.itemBaseId and item.itemBaseId ~= "" then
                table.insert(allExtractedItems, item)
            end
        end
    end

    -- Adicionar equipamentos
    if self.processedData.extractedEquipment then
        for _, item in pairs(self.processedData.extractedEquipment) do
            if item and item.itemBaseId and item.itemBaseId ~= "" then
                table.insert(allExtractedItems, item)
            end
        end
    end

    Logger.debug("ExtractionTransitionScene", "Processando reputação com dados válidos do hunter...")

    -- Processar resultado da incursão
    self.processedData.reputationDetails = reputationManager:processIncursionResult({
        portalData = self.processedData.portalData,
        wasSuccess = self.processedData.wasSuccess,
        hunterData = hunterData,
        lootedItems = allExtractedItems,
        gameplayStats = self.processedData.gameplayStats
    })

    Logger.info("ExtractionTransitionScene", "Reputação e recompensas calculadas")
    return true
end

--- Processa salvamento de dados do hunter
function ExtractionTransitionScene:_processSaveHunterProgress()
    -- A reputação já foi processada na tarefa anterior (_calculateReputationAndRewards)
    -- Esta tarefa é apenas para salvamento

    -- Salvar dados do caçador (apenas se ainda existe)
    ---@type HunterManager|nil
    local hunterMgr = ManagerRegistry:tryGet("hunterManager")
    if hunterMgr and self.processedData.hunterId then
        -- Verificar se o hunter ainda existe antes de tentar salvar
        local currentHunterData = hunterMgr:getHunterData(self.processedData.hunterId)
        if currentHunterData then
            hunterMgr:saveState()
            Logger.debug("ExtractionTransitionScene", "Dados do caçador salvos")
        else
            Logger.debug("ExtractionTransitionScene", "Hunter já foi excluído - pulando salvamento")
        end
        coroutine.yield()
    end

    -- Atualizar loadout se necessário (apenas para extrações bem-sucedidas)
    if self.processedData.wasSuccess then
        ---@type LoadoutManager|nil
        local loadoutManager = ManagerRegistry:tryGet("loadoutManager")
        if loadoutManager and loadoutManager.clearAllItems then
            loadoutManager:clearAllItems()

            -- Adicionar itens extraídos ao loadout
            if self.processedData.extractedItems then
                for _, item in ipairs(self.processedData.extractedItems) do
                    if item and item.itemBaseId and item.itemBaseId ~= "" then
                        loadoutManager:addItem(item.itemBaseId, item.quantity or 1)
                    end
                end
            end

            Logger.debug("ExtractionTransitionScene", "Loadout atualizado com itens extraídos")
        end
    else
        Logger.debug("ExtractionTransitionScene", "Extração falhou - não atualizando loadout")
    end

    return true
end

--- Prepara todos os dados da interface (movido da extraction_summary_scene)
function ExtractionTransitionScene:_prepareInterfaceData()
    Logger.debug("ExtractionTransitionScene", "Preparando dados da interface...")

    -- Garantir que ItemDataManager está disponível
    ---@type ItemDataManager|nil
    local itemDataManager = ManagerRegistry:tryGet("itemDataManager")
    if not itemDataManager then
        Logger.warn("ExtractionTransitionScene", "ItemDataManager não encontrado - usando dados básicos")
    end

    -- Pre-processar e enriquecer dados de itens para renderização otimizada
    if itemDataManager then
        -- Processar equipamentos extraídos
        if self.processedData.extractedEquipment then
            for slotId, itemInstance in pairs(self.processedData.extractedEquipment) do
                if itemInstance and itemInstance.itemBaseId and itemInstance.itemBaseId ~= "" then
                    local baseData = itemDataManager:getBaseItemData(itemInstance.itemBaseId)
                    if baseData then
                        -- Enriquecer com dados de renderização
                        itemInstance.icon = baseData.icon or nil
                        itemInstance.rarity = itemInstance.rarity or baseData.rarity or 'E'
                        itemInstance.name = baseData.name or "Item Desconhecido"
                        itemInstance.value = baseData.value or 0
                    end
                end
                coroutine.yield() -- Yield após cada item para manter performance
            end
        end

        -- Processar itens da mochila extraídos
        if self.processedData.extractedItems then
            local batchSize = PERFORMANCE_CONFIG.MAX_OPERATIONS_PER_FRAME
            for i, itemInstance in ipairs(self.processedData.extractedItems) do
                if itemInstance and itemInstance.itemBaseId and itemInstance.itemBaseId ~= "" then
                    local baseData = itemDataManager:getBaseItemData(itemInstance.itemBaseId)
                    if baseData then
                        -- Enriquecer com dados de renderização
                        itemInstance.icon = baseData.icon or nil
                        itemInstance.rarity = itemInstance.rarity or baseData.rarity or 'E'
                        itemInstance.name = baseData.name or "Item Desconhecido"
                        itemInstance.value = baseData.value or 0
                    end
                end

                -- Yield em lotes para manter performance
                if i % batchSize == 0 then
                    coroutine.yield()
                end
            end
        end
    end

    -- Carregar estatísticas do jogo se ainda não carregadas
    if not self.processedData.gameplayStats or not next(self.processedData.gameplayStats) then
        ---@type GameStatisticsManager|nil
        local gameStatsManager = ManagerRegistry:tryGet("gameStatisticsManager")
        if gameStatsManager and gameStatsManager.getRawStats then
            self.processedData.gameplayStats = gameStatsManager:getRawStats() or {}
            Logger.debug("ExtractionTransitionScene", "Estatísticas do jogo recarregadas")
        end
    end

    -- Adicionar informações de tema baseadas no tipo de extração
    self.processedData.extractionType = self.extractionType
    self.processedData.isDeath = (self.extractionType == "death")

    -- Preparar título contextual para itens
    if self.processedData.isDeath then
        self.processedData.itemsSectionTitle = "Itens Perdidos"
        self.processedData.extractionTitle = "Falha na Extração"
    else
        self.processedData.itemsSectionTitle = "Itens Extraídos"
        self.processedData.extractionTitle = "Extração Concluída"
    end

    -- Validar e limpar dados inválidos
    self:_validateAndCleanItemData()

    Logger.info("ExtractionTransitionScene", "Dados da interface preparados com sucesso")
    return true
end

--- Valida e limpa dados de itens inválidos
function ExtractionTransitionScene:_validateAndCleanItemData()
    -- Limpar equipamentos inválidos
    if self.processedData.extractedEquipment then
        local validEquipment = {}
        for slotId, itemInstance in pairs(self.processedData.extractedEquipment) do
            if itemInstance and itemInstance.itemBaseId and
                type(itemInstance.itemBaseId) == "string" and itemInstance.itemBaseId ~= "" then
                validEquipment[slotId] = itemInstance
            else
                Logger.warn("ExtractionTransitionScene",
                    string.format("Item de equipamento inválido removido do slot %s", tostring(slotId)))
            end
        end
        self.processedData.extractedEquipment = validEquipment
    end

    -- Limpar itens da mochila inválidos
    if self.processedData.extractedItems then
        local validItems = {}
        for _, itemInstance in ipairs(self.processedData.extractedItems) do
            if itemInstance and itemInstance.itemBaseId and
                type(itemInstance.itemBaseId) == "string" and itemInstance.itemBaseId ~= "" then
                table.insert(validItems, itemInstance)
            else
                Logger.warn("ExtractionTransitionScene",
                    "Item da mochila inválido removido")
            end
        end
        self.processedData.extractedItems = validItems
    end

    Logger.debug("ExtractionTransitionScene",
        string.format("Dados limpos: %d equipamentos, %d itens da mochila",
            self.processedData.extractedEquipment and
            (function()
                local count = 0; for _ in pairs(self.processedData.extractedEquipment) do count = count + 1 end; return
                    count
            end)() or 0,
            self.processedData.extractedItems and #self.processedData.extractedItems or 0))
end

--- Processa estatísticas finais
function ExtractionTransitionScene:_processFinalStatistics()
    -- Qualquer processamento adicional de estatísticas pode ser feito aqui
    -- Por enquanto, os dados já foram capturados na tarefa 2

    Logger.info("ExtractionTransitionScene", "Estatísticas finais processadas")
    return true
end

--- Prepara dados finais para extraction_summary_scene
function ExtractionTransitionScene:_prepareExtractionSummary()
    -- Criar argumentos finais para extraction_summary_scene
    -- (já temos todos os dados no processedData)

    -- Limpar managers restantes que não são mais necessários
    local remainingManagers = {
        "playerManager",
        "inventoryManager",
        "inputManager"
    }

    for _, managerName in ipairs(remainingManagers) do
        local manager = ManagerRegistry:tryGet(managerName)
        if manager then
            Logger.debug("ExtractionTransitionScene", string.format("Limpando %s final...", managerName))

            if manager.destroy and type(manager.destroy) == "function" then
                manager:destroy()
            elseif manager.reset and type(manager.reset) == "function" then
                manager:reset()
            elseif manager.cleanup and type(manager.cleanup) == "function" then
                manager:cleanup()
            end

            ManagerRegistry:unregister(managerName)
            Logger.debug("ExtractionTransitionScene", string.format("%s final limpo", managerName))
        end

        -- Yield para manter responsividade
        coroutine.yield()
    end

    -- Força coleta de lixo completa após toda a limpeza
    collectgarbage("collect")

    Logger.info("ExtractionTransitionScene", "Dados preparados para tela de sumário e limpeza final concluída")
    return true
end

--- Chamado quando a cena é carregada
function ExtractionTransitionScene:load(args)
    Logger.info("ExtractionTransitionScene", "Iniciando processamento de extração...")

    if not args then
        error("ExtractionTransitionScene: Argumentos não fornecidos!")
    end

    -- Extrair dados do gameplay_scene
    self.gameplayData = args.gameplayData or args
    self.extractionType = args.extractionType or "success"

    Logger.debug("ExtractionTransitionScene",
        string.format("Tipo de extração: %s", self.extractionType))

    -- Log de debug para verificar se hunterData está presente
    if self.gameplayData.hunterData then
        Logger.debug("ExtractionTransitionScene",
            string.format("HunterData recebido: %s (rank %s)",
                self.gameplayData.hunterData.name or "Nome ausente",
                self.gameplayData.hunterData.finalRankId or "Rank ausente"))
    else
        Logger.debug("ExtractionTransitionScene", "HunterData NÃO foi fornecido nos argumentos")
    end

    -- Inicializar sistema de processamento assíncrono
    self:_initializeProcessingTasks()
    self.processingCoroutine = self:_createProcessingCoroutine()
    self.isComplete = false
    self._themeLogged = false -- Flag para log único de tema

    -- Iniciar primeira dica
    self:_selectRandomTip()
end

--- Atualiza o processamento a cada frame
function ExtractionTransitionScene:update(dt)
    -- Monitoramento de performance
    local frameStartTime = love.timer.getTime()

    -- Atualizar timers de animação e dicas
    self.animationTimer = self.animationTimer + dt * PERFORMANCE_CONFIG.ANIMATION_SPEED
    self.tipTimer = self.tipTimer + dt

    -- Trocar dica periodicamente
    if self.tipTimer >= PERFORMANCE_CONFIG.TIP_CHANGE_INTERVAL then
        self:_selectRandomTip()
        self.tipTimer = 0
    end

    if self.isComplete then
        Logger.info("ExtractionTransitionScene", "Processamento concluído, indo para extraction_summary_scene...")
        SceneManager.switchScene("extraction_summary_scene", self.processedData)
        return
    end

    if self.processingCoroutine then
        local startTime = love.timer.getTime()
        local iterations = 0

        -- Processa dentro do budget de tempo mais restritivo
        while love.timer.getTime() - startTime < (PERFORMANCE_CONFIG.PROCESS_BUDGET_MS / 1000) do
            local resumeStartTime = love.timer.getTime()
            local success, errorMsg = coroutine.resume(self.processingCoroutine)
            local resumeTime = love.timer.getTime() - resumeStartTime

            iterations = iterations + 1

            if not success then
                error("extraction_transition_scene.update Falha no processamento: " .. errorMsg)
            end

            if coroutine.status(self.processingCoroutine) == "dead" then
                break
            end

            -- Log operações custosas (limite ultra-rígido)
            if resumeTime > (PERFORMANCE_CONFIG.MAX_RESUME_TIME_MS / 1000) then
                Logger.warn("ExtractionTransitionScene",
                    string.format("OPERAÇÃO ULTRA-CUSTOSA: %.1fms na tarefa %d (%s) - Frame pode estar lento!",
                        resumeTime * 1000, self.currentTaskIndex,
                        self.currentTaskName or "Tarefa Desconhecida"))
            end

            -- Quebra mais agressiva do budget para manter 60+ FPS
            if love.timer.getTime() - startTime >= (PERFORMANCE_CONFIG.PROCESS_BUDGET_MS / 1000) then
                break
            end
        end

        -- Monitora performance do frame
        local totalFrameTime = love.timer.getTime() - frameStartTime
        if totalFrameTime > (PERFORMANCE_CONFIG.FRAME_TARGET_MS / 1000) then
            Logger.warn("ExtractionTransitionScene",
                string.format("Frame lento detectado: %.1fms (%d iterações)",
                    totalFrameTime * 1000, iterations))
        end
    end

    -- Animação de processamento
    if not self.isComplete then
        self.processingAnimationTimer = self.processingAnimationTimer + dt

        if self.processingAnimationTimer >= (1 / self.processingAnimationSpeed) then
            self.currentProcessingFrame = self.currentProcessingFrame + 1
            if self.currentProcessingFrame > self.maxProcessingFrames then
                self.currentProcessingFrame = 1
            end
            self.processingAnimationTimer = 0
        end
    end
end

--- Desenha a tela de processamento
function ExtractionTransitionScene:draw()
    local w = ResolutionUtils.getGameWidth()
    local h = ResolutionUtils.getGameHeight()

    -- Selecionar tema baseado no tipo de extração
    local theme = self.extractionType == "death" and Colors.extraction_transition.death or
        Colors.extraction_transition.success

    -- Debug: Log da tematização aplicada
    if not self._themeLogged then
        Logger.debug("ExtractionTransitionScene",
            string.format("Tema aplicado: %s (extractionType: %s)",
                self.extractionType == "death" and "DEATH" or "SUCCESS",
                self.extractionType))
        self._themeLogged = true
    end

    -- Fundo temático baseado no resultado
    love.graphics.setColor(theme.background)
    love.graphics.rectangle("fill", 0, 0, w, h)

    -- Layout similar ao game_loading_scene
    local centerX = w / 2
    local headerY = h * 0.12
    local imageY = h * 0.35
    local textY = h * 0.55
    local loadingY = h * 0.75

    -- Progresso
    local progress = self.currentTaskIndex / math.max(1, self.totalTasks)

    -- Cabeçalho com cor temática
    love.graphics.setColor(theme.text_primary)
    local titleFont = fonts.title_large or fonts.title or love.graphics.getFont()
    love.graphics.setFont(titleFont)

    local missionTitle = self.extractionType == "death" and "PROCESSANDO DADOS DA MISSÃO" or "PROCESSANDO EXTRAÇÃO"
    love.graphics.printf(missionTitle, 0, headerY, w, "center")

    -- Subtítulo com status temático
    love.graphics.setColor(theme.text_secondary)
    local statusFont = fonts.title
    love.graphics.setFont(statusFont)

    local statusText = self.extractionType == "death" and "Coletando dados para análise pós-operação..." or
        "Transferindo dados para base segura..."
    love.graphics.printf(statusText, 0, headerY + 60, w, "center")

    -- Animação de processamento (com cor temática)
    if self.processingAnimator and self.processingAnimator.quads then
        local quad = self.processingAnimator.quads[self.currentProcessingFrame]
        love.graphics.setColor(theme.accent_secondary[1], theme.accent_secondary[2], theme.accent_secondary[3], 0.4)
        love.graphics.draw(self.processingAnimator.image, quad, centerX - 64, imageY - 64, 0, 2, 2)
    end

    -- Texto da tarefa atual com cor temática
    love.graphics.setColor(theme.text_primary)
    local taskFont = fonts.main_large or love.graphics.getFont()
    love.graphics.setFont(taskFont)

    local currentTaskName = "Iniciando..."
    if self.currentTaskIndex > 0 and self.processingTasks[self.currentTaskIndex] then
        currentTaskName = self.processingTasks[self.currentTaskIndex].name
    end
    love.graphics.printf(currentTaskName, 0, textY, w, "center")

    -- Barra de progresso com cores temáticas
    local barWidth = w * 0.5
    local barHeight = 12
    local barX = centerX - barWidth / 2

    -- Fundo da barra
    love.graphics.setColor(theme.progress_bg)
    love.graphics.rectangle("fill", barX, loadingY, barWidth, barHeight)

    -- Preenchimento da barra
    if progress > 0 then
        love.graphics.setColor(theme.progress_fill)
        love.graphics.rectangle("fill", barX, loadingY, barWidth * progress, barHeight)
    end

    -- Borda da barra
    love.graphics.setColor(theme.accent_primary)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", barX, loadingY, barWidth, barHeight)

    -- Texto de progresso
    love.graphics.setColor(theme.text_secondary)
    local progressFont = fonts.main or love.graphics.getFont()
    love.graphics.setFont(progressFont)
    local progressText = string.format("%d/%d", self.currentTaskIndex, self.totalTasks)
    love.graphics.printf(progressText, 0, loadingY + barHeight + 15, w, "center")

    -- Dica atual com cor temática
    love.graphics.setColor(theme.text_secondary)
    local tipFont = fonts.main_small
    love.graphics.setFont(tipFont)

    local tipY = loadingY + 60
    local tipText = self.currentTip or "Processando dados da missão..."
    love.graphics.printf(tipText, 50, tipY, w - 100, "center")

    -- Efeito de brilho no progresso (sutil)
    if progress > 0 and not self.isComplete then
        local glowIntensity = (math.sin(self.animationTimer * 2) + 1) / 4 + 0.1
        love.graphics.setColor(theme.glow_effect[1], theme.glow_effect[2], theme.glow_effect[3], glowIntensity)
        love.graphics.rectangle("fill", barX, loadingY - 2, barWidth * progress, barHeight + 4)
    end

    -- Reset de cor e linha
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

return ExtractionTransitionScene
