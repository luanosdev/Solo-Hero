local SceneManager = require("src.core.scene_manager")
local fonts = require("src.ui.fonts") -- Requer o módulo de fontes
local Bootstrap = require("src.core.bootstrap")
local ManagerRegistry = require("src.managers.manager_registry")
local AnimationLoader = require("src.animations.animation_loader")
local AssetManager = require("src.managers.asset_manager")
local portalDefinitions = require("src.data.portals.portal_definitions")
local AnimatedSpritesheet = require("src.animations.animated_spritesheet")
local Constants = require("src.config.constants")
local GameOverManager = require("src.managers.game_over_manager")
local BossPresentationManager = require("src.managers.boss_presentation_manager")

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

-- Configurações de performance
local LOAD_BUDGET_MS = 16       -- 16ms por frame (~60fps)
local TASK_YIELD_FREQUENCY = 10 -- Yield a cada 10 operações pequenas

--- Inicializa as tarefas de carregamento baseadas nos dados do portal
function GameLoadingScene:_initializeLoadingTasks()
    self.loadingTasks = {
        {
            name = "Carregando fontes...",
            task = function() return self:_loadFonts() end
        },
        {
            name = "Inicializando Bootstrap...",
            task = function() return self:_initializeBootstrap() end
        },
        {
            name = "Carregando animações básicas...",
            task = function() return self:_loadBasicAnimations() end
        },
        {
            name = "Carregando animações do portal...",
            task = function() return self:_loadPortalAnimations() end
        },
        {
            name = "Configurando managers...",
            task = function() return self:_setupManagers() end
        },
        {
            name = "Criando SpriteBatches...",
            task = function() return self:_createSpriteBatches() end
        },
        {
            name = "Finalizando carregamento...",
            task = function() return self:_finalizeLoading() end
        }
    }

    self.totalTasks = #self.loadingTasks
    self.currentTaskIndex = 1
    Logger.info("GameLoadingScene", string.format("Inicializado carregamento com %d tarefas", self.totalTasks))
end

--- Cria corrotina principal de carregamento
function GameLoadingScene:_createLoadingCoroutine()
    return coroutine.create(function()
        local startTime = love.timer.getTime()

        for i, taskData in ipairs(self.loadingTasks) do
            self.currentTaskIndex = i
            self.currentTaskName = taskData.name
            Logger.debug("GameLoadingScene",
                string.format("Executando tarefa %d/%d: %s", i, self.totalTasks, taskData.name))

            local taskStartTime = love.timer.getTime()
            local success, result = pcall(taskData.task)

            if not success then
                Logger.error("GameLoadingScene", string.format("Erro na tarefa '%s': %s", taskData.name, result))
                error("game_loading_scene.update Falha no carregamento: " .. result)
            end

            local taskTime = love.timer.getTime() - taskStartTime
            if taskTime > 0.016 then -- Log tarefas que demoram mais que 16ms
                Logger.warn("GameLoadingScene",
                    string.format("Tarefa '%s' demorou %.1fms", taskData.name, taskTime * 1000))
            end

            -- Yield para permitir renderização do progresso
            coroutine.yield()
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

                        -- Yield periodicamente para evitar travamentos
                        if batchCount % TASK_YIELD_FREQUENCY == 0 then
                            coroutine.yield()
                        end
                    end
                end
            end
        end
        Logger.debug("GameLoadingScene", string.format("Criados %d SpriteBatches", batchCount))
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
end

--- Chamado a cada frame para atualizar o carregamento.
function GameLoadingScene:update(dt)
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
        while love.timer.getTime() - startTime < (LOAD_BUDGET_MS / 1000) do
            local success, errorMsg = coroutine.resume(self.loadingCoroutine)

            if not success then
                error("game_loading_scene.update Falha crítica no carregamento: " .. errorMsg)
            end

            if coroutine.status(self.loadingCoroutine) == "dead" then
                break
            end
        end
    end
end

--- Chamado a cada frame para desenhar o progresso.
function GameLoadingScene:draw()
    local w = ResolutionUtils.getGameWidth()
    local h = ResolutionUtils.getGameHeight()

    -- Fundo escuro
    love.graphics.setColor(0.1, 0.1, 0.1, 1)
    love.graphics.rectangle("fill", 0, 0, w, h)

    -- Calcula progresso
    local progress = self.currentTaskIndex / math.max(1, self.totalTasks)

    -- Cor animada para o texto principal
    local grayLevel = 0.5
    local colorSpeed = math.pi * 0.5
    local time = love.timer.getTime()
    local oscillation = (math.sin(time * colorSpeed) + 1) / 2
    local colorComponent = grayLevel + (1 - grayLevel) * oscillation
    love.graphics.setColor(colorComponent, colorComponent, colorComponent, 1)

    -- Texto principal
    local mainFont = fonts.title or love.graphics.getFont()
    local detailFont = fonts.main_small or love.graphics.getFont()
    love.graphics.setFont(mainFont)

    local loadingText = "Entrando no Portal..."
    local loadingH = mainFont:getHeight()
    local loadingY = (h / 2) - (loadingH + 60)
    love.graphics.printf(loadingText, 0, loadingY, w, "center")

    -- Informações do portal
    if self.sceneArgs and self.sceneArgs.portalId then
        love.graphics.setFont(detailFont)
        local portalText = string.format("Portal: %s", self.sceneArgs.portalId)
        local detailY = loadingY + loadingH + 10
        love.graphics.printf(portalText, 0, detailY, w, "center")
    end

    -- Barra de progresso
    love.graphics.setColor(0.3, 0.3, 0.3, 1)
    local barW = 400
    local barH = 20
    local barX = (w - barW) / 2
    local barY = h / 2 + 20
    love.graphics.rectangle("fill", barX, barY, barW, barH)

    -- Preenchimento da barra
    love.graphics.setColor(0.2, 0.8, 0.3, 1)
    love.graphics.rectangle("fill", barX, barY, barW * progress, barH)

    -- Borda da barra
    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.rectangle("line", barX, barY, barW, barH)

    -- Texto de status
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.setFont(detailFont)
    local statusText = self.currentTaskName or "Carregando..."
    love.graphics.printf(statusText, 0, barY + barH + 15, w, "center")

    -- Percentual
    local percentText = string.format("%d%%", math.floor(progress * 100))
    love.graphics.printf(percentText, 0, barY + barH + 35, w, "center")

    -- Restaura cor padrão
    love.graphics.setColor(1, 1, 1, 1)
end

return GameLoadingScene
