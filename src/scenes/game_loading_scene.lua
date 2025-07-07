local SceneManager = require("src.core.scene_manager")
local fonts = require("src.ui.fonts") -- Requer o módulo de fontes
local Bootstrap = require("src.core.bootstrap")
local ManagerRegistry = require("src.managers.manager_registry")
local AnimationLoader = require("src.animations.animation_loader")
local portalDefinitions = require("src.data.portals.portal_definitions")
local AnimatedSpritesheet = require("src.animations.animated_spritesheet")
local DashCooldownIndicator = require("src.ui.components.dash_cooldown_indicator")

-- === SISTEMA DE TEXTOS TEMÁTICOS EXPANDIDO ===
local THEMATIC_LOADING_TEXTS = {
    {
        technical = "Carregando fontes principais...",
        thematic = {
            title = "Inicializando Interface Tática",
            subtitle = "Configurando protocolos visuais",
            detail = "Estabelecendo sistema de comunicação..."
        }
    },
    {
        technical = "Carregando sprites do jogador...",
        thematic = {
            title = "Calibrando Perfil Biométrico",
            subtitle = "Escaneando dados do caçador",
            detail = "Preparando teleporte de caçador..."
        }
    },
    {
        technical = "Inicializando core do Bootstrap...",
        thematic = {
            title = "Ativando Núcleo Operacional",
            subtitle = "Preparando sistemas fundamentais",
            detail = "Estabelecendo base de comando..."
        }
    },
    {
        technical = "Configurando todos os managers...",
        thematic = {
            title = "Coordenando Sistemas de Apoio",
            subtitle = "Sincronizando unidades especializadas",
            detail = "Ativando protocolos de comando..."
        }
    },
    {
        technical = "Carregando animações básicas...",
        thematic = {
            title = "Escaneando Dados Biométricos",
            subtitle = "Mapeando padrões de movimento",
            detail = "Analisando perfis de ação..."
        }
    },
    {
        technical = "Carregando animações do portal...",
        thematic = {
            title = "Identificando Ameaças Hostis",
            subtitle = "Escaneando zona de operação",
            detail = "Preparando contra-medidas..."
        }
    },
    {
        technical = "Criando batches de renderização...",
        thematic = {
            title = "Otimizando Sistemas Visuais",
            subtitle = "Preparando pipeline gráfico",
            detail = "Configurando recursos visuais..."
        }
    },
    {
        technical = "Configurando caçador para missão...",
        thematic = {
            title = "Sincronizando Perfil do Caçador",
            subtitle = "Ativando controles de combate",
            detail = "Preparando sistemas de movimento..."
        }
    },
    {
        technical = "Otimizando memória...",
        thematic = {
            title = "Avaliado plano de ataque",
            subtitle = "Definindo estratégia",
            detail = "Instruindo posições táticas..."
        }
    },
    {
        technical = "Finalizando inicialização...",
        thematic = {
            title = "Validando Prontidão Operacional",
            subtitle = "Confirmando status de missão",
            detail = "Aguardando autorização final..."
        }
    }
}

-- === SISTEMA DE DICAS ALEATÓRIAS (ESTILO SOULS) ===
local HUNTER_TIPS = {
    -- Dicas de Combate
    "A vida é valiosa - não seja arrogante demais para recuar.",
    "A esquiva te deixa invulnerável - use-a para evitar danos.",
    "Sempre tenha em mente uma rota de fuga.",
    "A velocidade de movimento pode ser mais valiosa que seu poder de ataque.",
    "O nivel de monstros aumenta conforme você permanece no portal.",

    -- Dicas de Estratégia
    "Gerencie seu inventário - itens acumulados podem fazer a diferença na hora certa.",
    "Explore cada canto da área - recompensas desconhecidas podem ser encontradas.",
    "Absorver almas de monstros aumenta seu nivel no portal.",
    "Caçadores são unicos, use suas particularidades para melhor desempenho.",
    "Chefes podem ser traiçoeiros, esteja bem preparado.",

    -- Dicas de Progressão
    "Evoluir suas runas pode transformar completamente seu estilo de combate.",
    "Experimente diferentes combinações de equipamentos para descobrir sinergias.",
    "Caçadores de ranks baixos são perfeitos para portais de nivel baixo, use para conseguir recursos mais rapidamente.",
    "Caçadores de ranks alto precisam de equipamentos, prepare-se para batalhas longas e difíceis.",

    -- Dicas de Recursos
    "Poções de cura se regeneram automaticamente - use sem medo quando necessário.",
    "Materiais raros podem ser encontrados em inimigos mais poderosos.",
    "Teleporte de extração sempre podem ser usados, fugir é uma opção! Volte mais forte.",
    "Existe um tempo para sua vida recarregar depois de sofrer um golpe.",

    -- Dicas Lore/Atmosfera
    "Os portais apareceram do nada e em abundância, ninguém sabe de onde eles vieram.",
    "Somente caçadores tem poder o suficiente para sobreviver aos portais.",
    "A Organização monitora as agencias, liberam licenças e monitoram suas atividades.",
    "O Chefe do portal precisa ser derrotado para que o portal seja destruido.",
    "Cidades inteiras ja foram desimadas por não haver caçadores para protege-las.",

    -- Dicas Técnicas
    "Use (Q) para usar uma poção de cura.",
    "Use (Espaço) para usar a esquiva.",
    "Use (X) para ativar/desativar o ataque automático.",
    "Use (Z) para ativar/desativar a mira automática.",
    "Use (V) para ativar/desativar a mira."
}

-- Configurações de performance otimizada
local PERFORMANCE_CONFIG = {
    LOAD_BUDGET_MS = 8,        -- Aumentado de 5ms para 8ms (operações menos custosas agora)
    TASK_YIELD_FREQUENCY = 1,  -- Yield a cada operação
    TIP_CHANGE_INTERVAL = 8.0, -- Troca dica a cada 8 segundos
    ANIMATION_SPEED = 0.7,     -- Animações mais lentas para economia de recursos
    BATCH_CHUNK_SIZE = 3,      -- Volta para 3 batches por frame (operações mais leves)
}

--- Cena exibida enquanto o jogo principal está sendo carregado.
-- Mostra uma mensagem "Carregando Jogo..." com cor animada.
-- Atualmente, simula o carregamento com um temporizador.
local GameLoadingScene = {}

GameLoadingScene.sceneArgs = nil

-- Estado do carregamento
GameLoadingScene.loadingTasks = {}
GameLoadingScene.currentTaskIndex = 1
GameLoadingScene.totalTasks = 0
GameLoadingScene.currentTaskName = "Inicializando..."
GameLoadingScene.isComplete = false
GameLoadingScene.loadingCoroutine = nil

-- Novos campos para sistema temático
GameLoadingScene.currentThematicData = nil
GameLoadingScene.currentTip = ""
GameLoadingScene.tipTimer = 0
GameLoadingScene.animationTimer = 0

-- === ANIMAÇÃO DE LOADING ===
GameLoadingScene.loadingAnimator = nil
GameLoadingScene.loadingAnimationTimer = 0
GameLoadingScene.loadingAnimationSpeed = 0.4 -- MUITO mais lento para ser visível (era 1.5)
GameLoadingScene.currentLoadingFrame = 1
GameLoadingScene.maxLoadingFrames = 7

-- === ESTADOS DE CARREGAMENTO ===
GameLoadingScene.currentBatchIndex = 0
GameLoadingScene.totalBatches = 0

--- Inicializa as tarefas de carregamento baseadas nos dados do portal
function GameLoadingScene:_initializeLoadingTasks()
    self.loadingTasks = {}

    -- Construir tarefas usando textos temáticos CORRIGIDOS
    local taskFunctions = {
        function() return self:_loadFonts() end,
        function() return self:_loadPlayerSprites() end,
        function() return self:_initializeBootstrapCore() end,
        function() return self:_setupAllManagers() end,
        function() return self:_loadBasicAnimations() end,
        function() return self:_loadPortalAnimations() end,
        function() return self:_createSpriteBatchesChunked() end,
        function() return self:_setupPlayerForMission() end,
        function() return self:_optimizeMemory() end,
        function() return self:_finalizeLoading() end
    }

    for i, thematicData in ipairs(THEMATIC_LOADING_TEXTS) do
        if taskFunctions[i] then
            table.insert(self.loadingTasks, {
                name = thematicData.thematic.title,
                thematicData = thematicData.thematic,
                task = taskFunctions[i]
            })
        end
    end

    self.totalTasks = #self.loadingTasks
    self.currentTaskIndex = 1

    -- Preparar dados para carregamento chunked
    self:_prepareChunkedData()

    -- Inicializar sistema de dicas
    self:_selectRandomTip()
    self.tipTimer = 0
    self.animationTimer = 0

    -- === INICIALIZAR ANIMADOR DE LOADING ===
    self.loadingAnimator = DashCooldownIndicator:new()
    self.loadingAnimationTimer = 0
    self.currentLoadingFrame = 1

    Logger.info("GameLoadingScene", string.format("Inicializado carregamento otimizado com %d tarefas", self.totalTasks))
end

--- Prepara dados para carregamento
function GameLoadingScene:_prepareChunkedData()
    -- Resetar apenas índices de batches que ainda são usados
    self.currentBatchIndex = 0
    self.totalBatches = 0
end

--- Seleciona uma dica aleatória do pool
function GameLoadingScene:_selectRandomTip()
    if #HUNTER_TIPS > 0 then
        local randomIndex = love.math.random(1, #HUNTER_TIPS)
        self.currentTip = HUNTER_TIPS[randomIndex]
        Logger.debug("GameLoadingScene", "Nova dica selecionada: " .. string.sub(self.currentTip, 1, 50) .. "...")
    end
end

--- Cria corrotina principal de carregamento
function GameLoadingScene:_createLoadingCoroutine()
    return coroutine.create(function()
        local startTime = love.timer.getTime()

        for i, taskData in ipairs(self.loadingTasks) do
            self.currentTaskIndex = i
            self.currentTaskName = taskData.name
            self.currentThematicData = taskData.thematicData

            Logger.debug("GameLoadingScene",
                string.format("Executando tarefa %d/%d: %s", i, self.totalTasks, taskData.name))

            local taskStartTime = love.timer.getTime()

            -- Executa tarefa em loop até completar
            local completed = false
            while not completed do
                local success, result = pcall(taskData.task)

                if not success then
                    Logger.error("GameLoadingScene", string.format("Erro na tarefa '%s': %s", taskData.name, result))
                    error("game_loading_scene.update Falha no carregamento: " .. result)
                end

                -- Se a tarefa retornar true, está completa
                if result == true then
                    completed = true
                end

                -- Sempre yield para manter fluidez, mesmo se a tarefa não terminou
                coroutine.yield()
            end

            local taskTime = love.timer.getTime() - taskStartTime
            Logger.debug("GameLoadingScene",
                string.format("Tarefa '%s' completa em %.1fms", taskData.name, taskTime * 1000))

            -- === DELAY ARTIFICIAL PARA VISUALIZAÇÃO ===
            -- Garante que cada tarefa seja visível por pelo menos 1 segundo
            local minVisibleTime = 1.0
            local taskEndTime = love.timer.getTime()
            while (taskEndTime - taskStartTime) < minVisibleTime do
                coroutine.yield()
                taskEndTime = love.timer.getTime()
            end
        end

        local totalTime = love.timer.getTime() - startTime
        Logger.info("GameLoadingScene", string.format("Carregamento completo em %.1fms", totalTime * 1000))
        self.isComplete = true
    end)
end

-- === TAREFAS DE CARREGAMENTO CORRIGIDAS ===

--- Carrega todas as fontes necessárias
function GameLoadingScene:_loadFonts()
    -- Carrega fontes principais
    if not fonts.main then
        fonts.load()
    end

    -- Carrega fontes específicas de uma vez só
    local fontsToLoad = {
        { name = "gameOver",        path = "assets/fonts/Roboto-Bold.ttf",    size = 48 },
        { name = "gameOverDetails", path = "assets/fonts/Roboto-Regular.ttf", size = 24 },
        { name = "gameOverFooter",  path = "assets/fonts/Roboto-Regular.ttf", size = 20 }
    }

    for _, fontData in ipairs(fontsToLoad) do
        if not fonts[fontData.name] then
            local success, font = pcall(love.graphics.newFont, fontData.path, fontData.size)
            if success then
                fonts[fontData.name] = font
                Logger.debug("GameLoadingScene", string.format("Fonte carregada: %s", fontData.name))
            else
                -- Fallback para fonte padrão
                fonts[fontData.name] = fonts.main or love.graphics.getFont()
                Logger.warn("GameLoadingScene", string.format("Fallback para fonte: %s", fontData.name))
            end
        end
    end

    return true
end

--- Carrega sprites do jogador de forma chunked
function GameLoadingScene:_loadPlayerSprites()
    local SpritePlayer = require('src.animations.sprite_player')

    -- Carrega apenas sprites do corpo primeiro (operação custosa movida aqui)
    if not SpritePlayer.resources.body or not next(SpritePlayer.resources.body) then
        SpritePlayer._loadBodySprites()
        Logger.debug("GameLoadingScene", "Sprites do corpo do jogador carregados")
    end

    return true
end

--- Inicializa apenas o core do Bootstrap
function GameLoadingScene:_initializeBootstrapCore()
    -- Inicializa apenas partes essenciais do Bootstrap
    if Bootstrap and Bootstrap.initializeCore then
        Bootstrap.initializeCore()
        Logger.debug("GameLoadingScene", "Bootstrap core inicializado")
    else
        Logger.warn("GameLoadingScene", "Bootstrap.initializeCore não encontrado, usando initialize completo")
        Bootstrap.initialize()
    end
    return true
end

--- Configura todos os managers restantes se necessário
function GameLoadingScene:_setupAllManagers()
    -- Verifica quais managers ainda precisam ser criados
    local requiredManagers = {
        "inputManager", "playerManager", "enemyManager", "dropManager",
        "itemDataManager", "experienceOrbManager", "hudGameplayManager",
        "extractionPortalManager", "extractionManager", "inventoryManager"
    }

    local missing = {}
    for _, managerName in ipairs(requiredManagers) do
        if not ManagerRegistry:tryGet(managerName) then
            table.insert(missing, managerName)
        end
    end

    -- CRÍTICO: Só chama Bootstrap.initialize() se há managers faltando
    -- Isso evita recriar managers que já foram inicializados
    if #missing > 0 then
        Logger.warn("GameLoadingScene",
            string.format("Managers faltando: %s. Chamando Bootstrap.initialize().", table.concat(missing, ", ")))
        Bootstrap.initialize()

        -- Valida novamente após Bootstrap.initialize()
        local stillMissing = {}
        for _, managerName in ipairs(requiredManagers) do
            if not ManagerRegistry:get(managerName) then
                table.insert(stillMissing, managerName)
            end
        end

        if #stillMissing > 0 then
            error("Managers ainda faltando após Bootstrap.initialize(): " .. table.concat(stillMissing, ", "))
        end
    else
        Logger.info("GameLoadingScene", "Todos os managers já estão inicializados")
    end

    Logger.info("GameLoadingScene", "Validação de managers concluída com sucesso")
    return true
end

function GameLoadingScene:_loadBasicAnimations()
    AnimationLoader.loadInitial()
    return true
end

function GameLoadingScene:_loadPortalAnimations()
    if self.currentPortalData and self.currentPortalData.requiredUnitTypes then
        AnimationLoader.loadUnits(self.currentPortalData.requiredUnitTypes)
    else
        Logger.warn(
            "GameLoadingScene",
            string.format(
                "Portal '%s' não possui requiredUnitTypes definidos",
                self.portalId or "desconhecido"
            )
        )
    end
    return true
end

--- Cria SpriteBatches em chunks para evitar travamentos
function GameLoadingScene:_createSpriteBatchesChunked()
    ---@type EnemyManager
    local enemyMgr = ManagerRegistry:get("enemyManager")
    local maxSpritesInBatch = enemyMgr and enemyMgr.maxEnemies or 200

    if AnimatedSpritesheet and AnimatedSpritesheet.assets then
        local allBatches = {}

        -- Prepara lista de todos os batches a serem criados
        if self.totalBatches == 0 then
            for unitType, unitAssets in pairs(AnimatedSpritesheet.assets) do
                if unitAssets.sheets then
                    for animName, sheetTexture in pairs(unitAssets.sheets) do
                        if sheetTexture then
                            table.insert(allBatches, { unitType = unitType, animName = animName, texture = sheetTexture })
                        end
                    end
                end
            end
            self.totalBatches = #allBatches
        end

        -- Processa apenas um chunk de batches por vez
        local startIndex = self.currentBatchIndex + 1
        local endIndex = math.min(startIndex + PERFORMANCE_CONFIG.BATCH_CHUNK_SIZE - 1, self.totalBatches)

        for i = startIndex, endIndex do
            local batchData = allBatches[i]
            if batchData then
                -- Cria SpriteBatch para esta textura
                local newBatch = love.graphics.newSpriteBatch(batchData.texture, maxSpritesInBatch)
                Logger.debug("GameLoadingScene",
                    string.format("Batch criado: %s-%s", batchData.unitType, batchData.animName))
            end
        end

        self.currentBatchIndex = endIndex

        -- Retorna true se todos os batches foram processados
        return self.currentBatchIndex >= self.totalBatches
    end

    return true
end

--- Configura TODOS os managers completamente para a missão
function GameLoadingScene:_setupPlayerForMission()
    self:_setupAllManagersForGameplay()

    Logger.info("GameLoadingScene", "Todos os managers configurados para gameplay completo")
    return true
end

--- Configura todos os managers para gameplay
function GameLoadingScene:_setupAllManagersForGameplay()
    -- 1. CONFIGURAR PLAYER MANAGER
    Logger.debug("GameLoadingScene", "Configurando PlayerManager para gameplay...")
    ---@type PlayerManager
    local playerMgr = ManagerRegistry:get("playerManager")
    if not playerMgr then
        error("PlayerManager não encontrado para configuração da missão!")
    end
    if not self.hunterId then
        error("hunterId necessário para configurar o PlayerManager!")
    end

    -- Setup completo do PlayerManager (cria todos os controllers)
    playerMgr:setupGameplay(ManagerRegistry, self.hunterId)
    Logger.info("GameLoadingScene", string.format("PlayerManager configurado com hunter ID: %s", self.hunterId))

    -- 2. CONFIGURAR ENEMY MANAGER
    Logger.debug("GameLoadingScene", "Configurando EnemyManager para gameplay...")
    ---@type EnemyManager
    local enemyMgr = ManagerRegistry:get("enemyManager")
    ---@type DropManager
    local dropMgr = ManagerRegistry:get("dropManager")

    if enemyMgr and self.currentPortalData then
        -- Criar ProceduralMapManager aqui (era criado no gameplay_scene)
        local AssetManager = require("src.managers.asset_manager")
        local ProceduralMapManager = require("src.managers.procedural_map_manager")

        local mapName = self.currentPortalData.map
        if not mapName then
            error("GameLoadingScene - O portal não define um 'map'.")
        end

        self.mapManager = ProceduralMapManager:new(mapName, AssetManager)
        Logger.info("GameLoadingScene", string.format("ProceduralMapManager criado para mapa: %s", mapName))

        -- Configurar EnemyManager com todas as dependências
        local enemyManagerConfig = {
            hordeConfig = self.hordeConfig,
            playerManager = playerMgr,
            dropManager = dropMgr,
            mapManager = self.mapManager
        }
        enemyMgr:setupGameplay(enemyManagerConfig)
        Logger.info("GameLoadingScene", "EnemyManager configurado para gameplay")
    end

    -- 3. CONFIGURAR HUD GAMEPLAY MANAGER
    Logger.debug("GameLoadingScene", "Configurando HUDGameplayManager...")
    ---@type HUDGameplayManager
    local hudGameplayManager = ManagerRegistry:get("hudGameplayManager")
    if hudGameplayManager then
        hudGameplayManager:setupGameplay()
        Logger.info("GameLoadingScene", "HUDGameplayManager configurado")
    end

    -- 4. CONFIGURAR EXTRACTION MANAGERS
    Logger.debug("GameLoadingScene", "Configurando managers de extração...")
    ---@type ExtractionManager
    local extractionManager = ManagerRegistry:get("extractionManager")
    ---@type ExtractionPortalManager
    local extractionPortalManager = ManagerRegistry:get("extractionPortalManager")

    if extractionManager and self.currentPortalData then
        extractionManager:reset(self.currentPortalData)
        Logger.info("GameLoadingScene", "ExtractionManager configurado")
    end

    if extractionPortalManager then
        extractionPortalManager:spawnPortals()
        Logger.info("GameLoadingScene", "ExtractionPortalManager configurado")
    end

    -- 5. CONFIGURAR RENDER PIPELINE
    Logger.debug("GameLoadingScene", "Configurando RenderPipeline...")
    local RenderPipeline = require("src.core.render_pipeline")
    self.renderPipeline = RenderPipeline:new()

    if self.mapManager then
        self.renderPipeline:setMapManager(self.mapManager)
        Logger.debug("GameLoadingScene", "RenderPipeline configurado com MapManager")
    end

    -- 6. CRIAR SPRITEBATCHES PARA O RENDERPIPELINE
    Logger.debug("GameLoadingScene", "Criando SpriteBatches para RenderPipeline...")
    local AnimatedSpritesheet = require("src.animations.animated_spritesheet")
    if AnimatedSpritesheet and AnimatedSpritesheet.assets then
        for unitType, unitAssets in pairs(AnimatedSpritesheet.assets) do
            if unitAssets.sheets then
                for animName, sheetTexture in pairs(unitAssets.sheets) do
                    if sheetTexture and not self.renderPipeline.spriteBatchReferences[sheetTexture] then
                        local maxSpritesInBatch = enemyMgr and enemyMgr.maxEnemies or 200
                        local newBatch = love.graphics.newSpriteBatch(sheetTexture, maxSpritesInBatch)
                        self.renderPipeline:registerSpriteBatch(sheetTexture, newBatch)
                    end
                end
            end
        end
        Logger.info("GameLoadingScene", "SpriteBatches criados e registrados no RenderPipeline")
    end

    -- 7. CONFIGURAR MANAGERS DE GAME OVER E BOSS
    Logger.debug("GameLoadingScene", "Configurando managers de apresentação...")
    local GameOverManager = require("src.managers.game_over_manager")
    local BossPresentationManager = require("src.managers.boss_presentation_manager")
    local BossHealthBarManager = require("src.managers.boss_health_bar_manager")

    self.gameOverManager = GameOverManager:new()
    self.gameOverManager:init(ManagerRegistry, require("src.core.scene_manager"))
    self.gameOverManager:reset()

    self.bossPresentationManager = BossPresentationManager:new()

    -- Destruir e recriar BossHealthBarManager (padrão do projeto)
    if BossHealthBarManager.destroy then
        BossHealthBarManager:destroy()
    end
    BossHealthBarManager:init()

    Logger.info("GameLoadingScene", "Managers de apresentação configurados")

    -- 8. CALLBACK DE MORTE DO JOGADOR (configuração que era feita no gameplay_scene)
    if playerMgr then
        playerMgr:setOnPlayerDiedCallback(function()
            Logger.info("GameLoadingScene", "Callback de morte configurado - será usado no gameplay")
            -- O GameplayScene será responsável apenas por chamar GameOverManager
        end)
        Logger.debug("GameLoadingScene", "Callback de morte do jogador configurado")
    end

    -- 9. PREPARAR DADOS PARA GAMEPLAY_SCENE
    -- Criar objeto com todas as referências que o gameplay_scene precisará
    self.gameplayData = {
        renderPipeline = self.renderPipeline,
        mapManager = self.mapManager,
        gameOverManager = self.gameOverManager,
        bossPresentationManager = self.bossPresentationManager,
        portalId = self.portalId,
        hordeConfig = self.hordeConfig,
        hunterId = self.hunterId,
        currentPortalData = self.currentPortalData
    }

    Logger.info("GameLoadingScene", "*** CONFIGURAÇÃO COMPLETA DE TODOS OS MANAGERS PARA GAMEPLAY ***")
end

--- Otimiza memória de forma gradual
function GameLoadingScene:_optimizeMemory()
    -- Coleta de lixo ultra suave para evitar picos de performance
    collectgarbage("step", 50) -- Reduzido de 100 para 50 KB por vez
    return true
end

function GameLoadingScene:_finalizeLoading()
    -- Pequeна pausa para garantir que tudo foi processado
    love.timer.sleep(0.005) -- Reduzido de 0.01 para 0.005
    return true
end

--- Chamado quando a cena é carregada.
-- Reinicia o temporizador e armazena dados do portal.
-- @param args table|nil Argumentos da cena anterior (espera-se { portalId, hordeConfig, ... }).
function GameLoadingScene:load(args)
    self.sceneArgs = args -- Armazena a tabela de argumentos completa
    self.portalId = args and args.portalId or "floresta_assombrada"
    self.hordeConfig = args and args.hordeConfig or nil
    self.hunterId = args and args.hunterId or nil

    -- Carrega dados do portal
    self.currentPortalData = portalDefinitions[self.portalId]
    if not self.currentPortalData then
        error(string.format("Definição do portal '%s' não encontrada!", self.portalId))
    end

    -- Se hordeConfig não foi passado, usa do portal
    if not self.hordeConfig and self.currentPortalData.hordeConfig then
        self.hordeConfig = self.currentPortalData.hordeConfig
    end

    -- Validações
    if not self.hordeConfig then
        error("Nenhuma hordeConfig fornecida ou encontrada no portalDefinition!")
    end
    if not self.hunterId then
        error("Nenhum hunterId fornecido!")
    end

    Logger.info(
        "game_loading_scene.load",
        string.format(
            "[GameLoadingScene:load] Iniciando carregamento - Portal: %s, Hunter: %s",
            self.portalId, self.hunterId
        )
    )

    -- Inicializa sistema de carregamento assíncrono
    self:_initializeLoadingTasks()
    self.loadingCoroutine = self:_createLoadingCoroutine()
    self.isComplete = false

    -- Inicia primeira dica
    self:_selectRandomTip()
end

--- Chamado a cada frame para atualizar o carregamento.
function GameLoadingScene:update(dt)
    -- Monitoramento de performance rigoroso
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
        Logger.info(
            "game_loading_scene.update",
            "[GameLoadingScene:update] Carregamento concluído, trocando para GameplayScene..."
        )

        -- NOVA ARQUITETURA: Passar dados completamente configurados para gameplay_scene
        local gameplayArgs = self.gameplayData or self.sceneArgs
        SceneManager.switchScene("gameplay_scene", gameplayArgs)
        return
    end

    if self.loadingCoroutine then
        local startTime = love.timer.getTime()
        local iterations = 0

        -- Processa carregamento dentro do budget de tempo ULTRA RESTRITO
        while love.timer.getTime() - startTime < (PERFORMANCE_CONFIG.LOAD_BUDGET_MS / 1000) do
            local resumeStartTime = love.timer.getTime()
            local success, errorMsg = coroutine.resume(self.loadingCoroutine)
            local resumeTime = love.timer.getTime() - resumeStartTime

            iterations = iterations + 1

            if not success then
                error("game_loading_scene.update Falha crítica no carregamento: " .. errorMsg)
            end

            if coroutine.status(self.loadingCoroutine) == "dead" then
                break
            end

            -- Log operações que demoram mais que 2ms
            if resumeTime > 0.002 then
                Logger.warn("GameLoadingScene",
                    string.format("Operação custosa detectada: %.1fms na tarefa %d",
                        resumeTime * 1000, self.currentTaskIndex))
            end

            -- Força uma saída do loop se o tempo acabou
            if love.timer.getTime() - startTime >= (PERFORMANCE_CONFIG.LOAD_BUDGET_MS / 1000) then
                break
            end
        end

        -- Monitora performance geral do frame
        local totalFrameTime = love.timer.getTime() - frameStartTime
        if totalFrameTime > 0.016 then -- 16ms = 62.5 FPS
            Logger.warn("GameLoadingScene",
                string.format("Frame lento detectado: %.1fms (%d iterações)",
                    totalFrameTime * 1000, iterations))
        end
    end

    -- === ANIMAÇÃO DE LOADING ===
    if not self.isComplete then
        self.loadingAnimationTimer = self.loadingAnimationTimer + dt

        -- Avança para o próximo frame baseado na velocidade
        if self.loadingAnimationTimer >= (1 / self.loadingAnimationSpeed) then
            self.currentLoadingFrame = self.currentLoadingFrame + 1
            if self.currentLoadingFrame > self.maxLoadingFrames then
                self.currentLoadingFrame = 1 -- Volta ao início para loop infinito
            end
            self.loadingAnimationTimer = 0
        end
    end
end

--- Chamado a cada frame para desenhar o progresso.
function GameLoadingScene:draw()
    local w = ResolutionUtils.getGameWidth()
    local h = ResolutionUtils.getGameHeight()

    -- Fundo temático escuro
    love.graphics.setColor(0.08, 0.1, 0.14, 1)
    love.graphics.rectangle("fill", 0, 0, w, h)

    -- === DEFINIR POSIÇÕES DO LAYOUT ===
    local centerX = w / 2
    local headerY = h * 0.12  -- 12% da altura para cabeçalho
    local imageY = h * 0.35   -- 35% da altura para imagem
    local textY = h * 0.55    -- 55% da altura para textos
    local loadingY = h * 0.75 -- 75% da altura para loading

    -- Calcula progresso
    local progress = self.currentTaskIndex / math.max(1, self.totalTasks)

    -- === 1. CABEÇALHO ===
    love.graphics.setColor(1, 1, 1, 1)
    local titleFont = fonts.title_large or fonts.title or love.graphics.getFont()
    love.graphics.setFont(titleFont)

    local missionTitle = "PREPARANDO INCURSÃO"
    love.graphics.printf(missionTitle, 0, headerY, w, "center")

    -- === 2. IMAGEM (DASH COOLDOWN INDICATOR) ===
    if self.loadingAnimator and self.loadingAnimator.quads then
        local quad = self.loadingAnimator.quads[self.currentLoadingFrame]
        if quad then
            local scale = 0.8

            -- Opacidade reduzida (era 1.0, agora 0.4)
            love.graphics.setColor(0.3, 0.7, 1.0, 0.4)
            love.graphics.draw(
                self.loadingAnimator.image,
                quad,
                centerX - (self.loadingAnimator.frameWidth * scale) / 2,
                imageY - (self.loadingAnimator.frameHeight * scale) / 2,
                0,
                scale,
                scale
            )
        end
    end

    -- === 3. TEXTO DE BAIXO ===
    -- Textos temáticos
    if self.currentThematicData then
        -- Título da operação atual
        love.graphics.setColor(0.8, 0.9, 1.0, 1)
        local mainFont = fonts.main_large or fonts.main or love.graphics.getFont()
        love.graphics.setFont(mainFont)
        love.graphics.printf(self.currentThematicData.title, 0, textY, w, "center")

        -- Subtítulo
        love.graphics.setColor(0.6, 0.7, 0.9, 1)
        local detailFont = fonts.main or fonts.main_small or love.graphics.getFont()
        love.graphics.setFont(detailFont)
        love.graphics.printf(self.currentThematicData.subtitle, 0, textY + 35, w, "center")

        -- Detalhes técnicos
        love.graphics.setColor(0.5, 0.6, 0.7, 0.8)
        love.graphics.setFont(fonts.main_small or detailFont)
        love.graphics.printf(self.currentThematicData.detail, 0, textY + 65, w, "center")
    end

    -- Informações do portal
    if self.sceneArgs and self.sceneArgs.portalId then
        love.graphics.setColor(0.7, 0.8, 0.9, 0.9)
        love.graphics.setFont(fonts.main or love.graphics.getFont())
        local portalText = string.format("Zona de Operação: %s", self.sceneArgs.portalId)
        love.graphics.printf(portalText, 0, textY + 95, w, "center")
    end

    -- === 4. LOADING ===
    local barW = 500
    local barH = 8
    local barX = centerX - barW / 2

    -- Fundo da barra
    love.graphics.setColor(0.2, 0.25, 0.3, 0.8)
    love.graphics.rectangle("fill", barX, loadingY, barW, barH)

    -- Progresso
    love.graphics.setColor(0.3, 0.7, 1.0, 0.9)
    love.graphics.rectangle("fill", barX, loadingY, barW * progress, barH)

    -- Efeito de brilho simplificado
    if progress > 0 then
        love.graphics.setColor(0.6, 0.9, 1.0, 0.3)
        local glowX = barX + (barW * progress) - 10
        love.graphics.rectangle("fill", math.max(barX, glowX), loadingY, 10, barH)
    end

    -- Borda da barra
    love.graphics.setColor(0.5, 0.6, 0.7, 1)
    love.graphics.rectangle("line", barX, loadingY, barW, barH)

    -- Percentual
    love.graphics.setColor(0.9, 0.9, 0.9, 1)
    love.graphics.setFont(fonts.main_small or love.graphics.getFont())
    local percentText = string.format("%d%% COMPLETO", math.floor(progress * 100))
    love.graphics.printf(percentText, 0, loadingY + 20, w, "center")

    -- === SISTEMA DE DICAS ===
    if self.currentTip and #self.currentTip > 0 then
        -- Área da dica (parte inferior da tela)
        local tipBoxY = h - 180
        local tipBoxH = 140
        local tipPadding = 40

        -- Fundo semi-transparente para a dica
        love.graphics.setColor(0.05, 0.08, 0.12, 0.9)
        love.graphics.rectangle("fill", tipPadding, tipBoxY, w - tipPadding * 2, tipBoxH)

        -- Borda da área da dica
        love.graphics.setColor(0.3, 0.4, 0.5, 0.6)
        love.graphics.rectangle("line", tipPadding, tipBoxY, w - tipPadding * 2, tipBoxH)

        -- Título da seção de dicas
        love.graphics.setColor(0.7, 0.8, 0.9, 1)
        love.graphics.setFont(fonts.main or love.graphics.getFont())
        local tipTitleY = tipBoxY + 15
        love.graphics.printf("DICA DE SOBREVIVÊNCIA", tipPadding, tipTitleY, w - tipPadding * 2, "center")

        -- Texto da dica
        love.graphics.setColor(0.9, 0.9, 0.9, 1)
        love.graphics.setFont(fonts.main_small or love.graphics.getFont())
        local tipTextY = tipTitleY + 35
        love.graphics.printf(self.currentTip, tipPadding + 20, tipTextY, w - (tipPadding + 20) * 2, "center")

        -- Indicador de rotação das dicas
        love.graphics.setColor(0.5, 0.6, 0.7, 0.7)
        local remainingTime = PERFORMANCE_CONFIG.TIP_CHANGE_INTERVAL - self.tipTimer
        local tipIndicator = string.format("Nova dica em %.0fs", remainingTime)
        love.graphics.printf(tipIndicator, tipPadding, tipBoxY + tipBoxH - 25, w - tipPadding * 2, "center")
    end

    -- === ELEMENTOS DE INTERFACE SIMPLES ===
    -- Cantos minimalistas
    love.graphics.setColor(0.3, 0.7, 1.0, 0.4)
    love.graphics.setLineWidth(2)

    love.graphics.line(25, 25, 60, 25)
    love.graphics.line(25, 25, 25, 60)
    love.graphics.line(w - 25, 25, w - 60, 25)
    love.graphics.line(w - 25, 25, w - 25, 60)

    -- Status da agência
    love.graphics.setColor(0.4, 0.6, 0.8, 0.7)
    love.graphics.setFont(fonts.main_small or love.graphics.getFont())
    love.graphics.printf("SHADOW MONARCH AGENCY - SISTEMA OPERACIONAL ATIVO", 0, 30, w, "center")

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

return GameLoadingScene
