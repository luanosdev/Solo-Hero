local SceneManager = require("src.core.scene_manager")
local fonts = require("src.ui.fonts") -- Requer o módulo de fontes
local Bootstrap = require("src.core.bootstrap")
local ManagerRegistry = require("src.managers.manager_registry")
local AnimationLoader = require("src.animations.animation_loader")
local portalDefinitions = require("src.data.portals.portal_definitions")
local AnimatedSpritesheet = require("src.animations.animated_spritesheet")
local DashCooldownIndicator = require("src.ui.components.dash_cooldown_indicator")

-- === SISTEMA DE TEXTOS TEMÁTICOS ===
local THEMATIC_LOADING_TEXTS = {
    {
        technical = "Carregando fontes...",
        thematic = {
            title = "Sincronizando Interface Tática",
            subtitle = "Calibrando sistemas de comunicação",
            detail = "Estabelecendo protocolos de comando..."
        }
    },
    {
        technical = "Inicializando Bootstrap...",
        thematic = {
            title = "Ativando Protocolos de Missão",
            subtitle = "Preparando sistemas operacionais",
            detail = "Calibrando equipamentos de combate..."
        }
    },
    {
        technical = "Carregando animações básicas...",
        thematic = {
            title = "Sincronizando Dados Biométricos",
            subtitle = "Mapeando padrões de movimento",
            detail = "Analisando perfis de combate..."
        }
    },
    {
        technical = "Carregando animações do portal...",
        thematic = {
            title = "Escaneando Zona de Operação",
            subtitle = "Identificando ameaças hostis",
            detail = "Preparando contra-medidas táticas..."
        }
    },
    {
        technical = "Configurando managers...",
        thematic = {
            title = "Ativando Suporte de Comando",
            subtitle = "Estabelecendo link de comunicação",
            detail = "Coordenando equipe de apoio..."
        }
    },
    {
        technical = "Criando SpriteBatches...",
        thematic = {
            title = "Otimizando Sistemas de Combate",
            subtitle = "Testando equipamentos de combate...",
            detail = "Preparando arsenal tático..."
        }
    },
    {
        technical = "Finalizando carregamento...",
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
    LOAD_BUDGET_MS = 300,      -- Aumentado drasticamente de 12ms para 300ms (muito mais lento)
    TASK_YIELD_FREQUENCY = 1,  -- Reduzido de 5 para 1 (yield a cada operação)
    TIP_CHANGE_INTERVAL = 8.0, -- Troca dica a cada 8 segundos
    ANIMATION_SPEED = 0.7,     -- Animações mais lentas para economia de recursos
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

--- Inicializa as tarefas de carregamento baseadas nos dados do portal
function GameLoadingScene:_initializeLoadingTasks()
    self.loadingTasks = {}

    -- Construir tarefas usando textos temáticos
    local taskFunctions = {
        function() return self:_loadFonts() end,
        function() return self:_initializeBootstrap() end,
        function() return self:_loadBasicAnimations() end,
        function() return self:_loadPortalAnimations() end,
        function() return self:_setupManagers() end,
        function() return self:_createSpriteBatches() end,
        function() return self:_finalizeLoading() end
    }

    for i, thematicData in ipairs(THEMATIC_LOADING_TEXTS) do
        table.insert(self.loadingTasks, {
            name = thematicData.thematic.title,
            thematicData = thematicData.thematic,
            task = taskFunctions[i]
        })
    end

    self.totalTasks = #self.loadingTasks
    self.currentTaskIndex = 1

    -- Inicializar sistema de dicas
    self:_selectRandomTip()
    self.tipTimer = 0
    self.animationTimer = 0

    -- === INICIALIZAR ANIMADOR DE LOADING ===
    self.loadingAnimator = DashCooldownIndicator:new()
    self.loadingAnimationTimer = 0
    self.currentLoadingFrame = 1

    Logger.info("GameLoadingScene", string.format("Inicializado carregamento temático com %d tarefas", self.totalTasks))
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
            local success, result = pcall(taskData.task)

            if not success then
                Logger.error("GameLoadingScene", string.format("Erro na tarefa '%s': %s", taskData.name, result))
                error("game_loading_scene.update Falha no carregamento: " .. result)
            end

            local taskTime = love.timer.getTime() - taskStartTime
            if taskTime > 0.012 then -- Log tarefas que demoram mais que 12ms (ajustado)
                Logger.warn("GameLoadingScene",
                    string.format("Tarefa '%s' demorou %.1fms", taskData.name, taskTime * 1000))
            end

            -- Yield para permitir renderização do progresso
            coroutine.yield()

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

-- Tarefas de carregamento individuais

function GameLoadingScene:_loadFonts()
    if not fonts.main then
        fonts.load()
    end

    -- Carrega fontes específicas do Game Over
    if not fonts.gameOver then
        local success, font = pcall(love.graphics.newFont, "assets/fonts/Roboto-Bold.ttf", 48)
        if success then
            fonts.gameOver = font
        else
            fonts.gameOver = fonts.title_large or fonts.main
        end
    end

    if not fonts.gameOverDetails then
        local success, font = pcall(love.graphics.newFont, "assets/fonts/Roboto-Regular.ttf", 24)
        if success then
            fonts.gameOverDetails = font
        else
            fonts.gameOverDetails = fonts.main_small or fonts.main
        end
    end

    if not fonts.gameOverFooter then
        local success, font = pcall(love.graphics.newFont, "assets/fonts/Roboto-Regular.ttf", 20)
        if success then
            fonts.gameOverFooter = font
        else
            fonts.gameOverFooter = fonts.debug or fonts.main_small
        end
    end
end

function GameLoadingScene:_initializeBootstrap()
    Bootstrap.initialize()
end

function GameLoadingScene:_loadBasicAnimations()
    AnimationLoader.loadInitial()
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
end

function GameLoadingScene:_setupManagers()
    -- Os managers já foram inicializados pelo Bootstrap
    -- Aqui apenas validamos se estão disponíveis
    local requiredManagers = {
        "playerManager", "enemyManager", "dropManager",
        "itemDataManager", "experienceOrbManager", "hudGameplayManager",
        "extractionPortalManager", "extractionManager", "inventoryManager"
    }

    local missing = {}
    for _, managerName in ipairs(requiredManagers) do
        if not ManagerRegistry:get(managerName) then
            table.insert(missing, managerName)
        end
    end

    if #missing > 0 then
        error("Managers essenciais não encontrados: " .. table.concat(missing, ", "))
    end
end

function GameLoadingScene:_createSpriteBatches()
    ---@type EnemyManager
    local enemyMgr = ManagerRegistry:get("enemyManager")
    local maxSpritesInBatch = enemyMgr and enemyMgr.maxEnemies or 200

    if AnimatedSpritesheet and AnimatedSpritesheet.assets then
        local batchCount = 0
        for unitType, unitAssets in pairs(AnimatedSpritesheet.assets) do
            if unitAssets.sheets then
                for animName, sheetTexture in pairs(unitAssets.sheets) do
                    if sheetTexture then
                        -- Cria SpriteBatch para esta textura
                        local newBatch = love.graphics.newSpriteBatch(sheetTexture, maxSpritesInBatch)
                        -- Nota: renderPipeline será configurado na GameplayScene
                        batchCount = batchCount + 1

                        -- Yield periodicamente para evitar travamentos (usando nova configuração)
                        if batchCount % PERFORMANCE_CONFIG.TASK_YIELD_FREQUENCY == 0 then
                            coroutine.yield()
                        end
                    end
                end
            end
        end
        Logger.debug("GameLoadingScene", string.format("Criados %d SpriteBatches otimizados", batchCount))
    end
end

function GameLoadingScene:_finalizeLoading()
    -- Força coleta de lixo antes de entrar no gameplay
    collectgarbage("collect")

    -- Pequeна pausa para garantir que tudo foi processado
    love.timer.sleep(0.01)
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
        SceneManager.switchScene("gameplay_scene", self.sceneArgs)
        return
    end

    if self.loadingCoroutine then
        local startTime = love.timer.getTime()

        -- Processa carregamento dentro do budget de tempo
        while love.timer.getTime() - startTime < (PERFORMANCE_CONFIG.LOAD_BUDGET_MS / 1000) do
            local success, errorMsg = coroutine.resume(self.loadingCoroutine)

            if not success then
                error("game_loading_scene.update Falha crítica no carregamento: " .. errorMsg)
            end

            if coroutine.status(self.loadingCoroutine) == "dead" then
                break
            end
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
