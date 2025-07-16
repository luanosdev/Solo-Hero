-- main.lua
-- Love2D callbacks e inicialização principal

-- [[ Variáveis Globais Essenciais ]] --
local SceneManager = require("src.core.scene_manager")
local ManagerRegistry = require("src.managers.manager_registry")
local ItemDataManager = require("src.managers.item_data_manager")
local ArchetypeManager = require("src.managers.archetype_manager")
local LoadoutManager = require("src.managers.loadout_manager")
local LobbyStorageManager = require("src.managers.lobby_storage_manager")
local HunterManager = require("src.managers.hunter_manager")
local AgencyManager = require("src.managers.agency_manager")
local ReputationManager = require("src.managers.reputation_manager")
local GameStatisticsManager = require("src.managers.game_statistics_manager")
local ArtefactManager = require("src.managers.artefact_manager")
local PatrimonyManager = require("src.managers.patrimony_manager")
local NotificationManager = require("src.managers.notification_manager")
local EventManager = require("src.managers.event_manager")
local NotificationDisplay = require("src.ui.components.notification_display")
local fonts = require("src.ui.fonts")

local lovebird = require("src.libs.lovebird")
local profiler = require("src.libs.profiler")
local Logger = require("src.libs.logger")
local lurker = require("src.libs.lurker")
local push = require("src.libs.push")
local ResolutionUtils = require("src.utils.resolution_utils")

_G.Shaders = {}

-- [[ Inicialização LOVE ]] --
function love.load()
    --- Registra o Logger globalmente
    Logger.setVisibleLevels({ debug = false, info = true, warn = true, error = false })
    _G.Logger = Logger

    --- Inicializa o sistema de localização global
    require("src.utils.localization_init")

    Logger.debug("love.load.start", "[love.load] Iniciando love.load()...")
    Logger.debug("love.load.dev", "[love.load] Modo DEV: " .. tostring(DEV))

    if DEV and PROFILER then
        profiler.start()
    end

    pcall(function()
        _G.Shaders.glow = love.graphics.newShader("src/ui/shaders/simple_glow.fs")
        Logger.info("love.load.shaders", "[love.load] Shader de brilho carregado com sucesso.")
    end)

    fonts.load()
    -- Usar filtro linear para melhor qualidade visual
    love.graphics.setDefaultFilter("linear", "linear")
    love.keyboard.setKeyRepeat(true) -- Habilita repetição de tecla

    math.randomseed(os.time() + tonumber(tostring(os.clock()):reverse():sub(1, 6)))

    -- Configuração do sistema de resolução adaptável
    local gameWidth, gameHeight = 1920, 1080
    local windowWidth, windowHeight

    -- Em modo DEV, usa janela configurada no conf.lua
    -- Em modo produção, usa fullscreen com dimensões da área de trabalho
    if DEV then
        windowWidth, windowHeight = 1280, 720
    else
        windowWidth, windowHeight = love.window.getDesktopDimensions()
    end

    -- Detecta se as proporções são iguais ANTES de configurar o push
    local gameAspect = gameWidth / gameHeight
    local screenAspect = windowWidth / windowHeight
    local aspectDiff = math.abs(gameAspect - screenAspect)
    local shouldUseStretched = aspectDiff < 0.01

    push:setupScreen(
        gameWidth,
        gameHeight,
        windowWidth,
        windowHeight,
        {
            fullscreen = not DEV, -- Fullscreen apenas em produção
            resizable = DEV,      -- Redimensionável apenas em DEV
            pixelperfect = false,
            highdpi = true,
            canvas = true,
            stencil = true,
            stretched = shouldUseStretched -- TRUE para proporções iguais
        }
    )

    -- Inicializa o ResolutionUtils com a instância do push
    ResolutionUtils.initialize(push)
    _G.ResolutionUtils = ResolutionUtils



    SceneManager.switchScene("bootloader_scene")

    -- Inicializa managers persistentes
    local itemDataMgr = ItemDataManager:new()
    ManagerRegistry:register("itemDataManager", itemDataMgr)

    local archetypeMgr = ArchetypeManager:new()
    ManagerRegistry:register("archetypeManager", archetypeMgr)

    local lobbyStorageMgr = LobbyStorageManager:new(itemDataMgr)
    ManagerRegistry:register("lobbyStorageManager", lobbyStorageMgr)

    local loadoutMgr = LoadoutManager:new(itemDataMgr)
    ManagerRegistry:register("loadoutManager", loadoutMgr)

    local hunterMgr = HunterManager:new(loadoutMgr, itemDataMgr, archetypeMgr)
    ManagerRegistry:register("hunterManager", hunterMgr)

    local agencyMgr = AgencyManager:new()
    ManagerRegistry:register("agencyManager", agencyMgr)

    local reputationMgr = ReputationManager:new(agencyMgr, itemDataMgr)
    ManagerRegistry:register("reputationManager", reputationMgr)

    local gameStatsMgr = GameStatisticsManager:new()
    ManagerRegistry:register("gameStatisticsManager", gameStatsMgr)

    local artefactMgr = ArtefactManager:new()
    ManagerRegistry:register("artefactManager", artefactMgr)

    local patrimonyMgr = PatrimonyManager:new()
    ManagerRegistry:register("patrimonyManager", patrimonyMgr)

    -- Inicializar sistema de notificações global
    NotificationManager.init()
    NotificationDisplay.init()
    _G.NotificationManager = NotificationManager
    _G.NotificationDisplay = NotificationDisplay

    -- Inicializar sistema de eventos global
    local eventMgr = EventManager:new()
    ManagerRegistry:register("eventManager", eventMgr)
    _G.EventManager = eventMgr

    Logger.info("main.notifications.initialized", "[main.love.load] Sistema de notificações inicializado globalmente")
end

function love.update(dt)
    -- Delega o update para a cena atual (se não for encerrar)
    SceneManager.update(dt)

    -- Atualizar sistema de notificações
    if NotificationManager then
        NotificationManager.update(dt)
    end

    if LOGS_ON_CONSOLE then
        lovebird.update()
    end

    if DEV and HOT_RELOAD then
        lurker.update()
    end
end

function love.draw()
    -- Inicia o sistema de resolução adaptável
    push:start()

    -- Desenha a cena ativa
    SceneManager.draw()

    -- Desenhar notificações globais (sobre todas as cenas)
    if NotificationDisplay then
        NotificationDisplay.draw()
    end

    -- Info básica de debug (modo DEV)
    if DEV then
        love.graphics.setFont(fonts.main_small)
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.print(string.format("FPS: %d", love.timer.getFPS()), 10, 70)
    end

    Logger.draw()

    -- Finaliza o sistema de resolução adaptável
    push:finish()
end

-- [[ Callbacks de Input LOVE ]] --

function love.keypressed(key, scancode, isrepeat)
    -- Passa o evento para a cena ativa
    SceneManager.keypressed(key, scancode, isrepeat)

    -- Toggle Fullscreen com F11 (exemplo global)
    if key == "f11" then
        push:switchFullscreen()
    end

    -- Profiler com Shift+F10 (modo DEV)
    if key == "f10" and love.keyboard.isDown("lshift", "rshift") and DEV then
        Logger.disable()
        profiler.start()
    end
    if key == "f12" and DEV then
        profiler.stop()
        profiler.report("profiler_report.txt")
    end

    Logger.keypressed(key)
end

function love.keyreleased(key, scancode)
    SceneManager.keyreleased(key, scancode)
end

function love.mousepressed(x, y, button, istouch, presses)
    -- Converte coordenadas da tela para coordenadas do jogo
    local gameX, gameY = push:toGame(x, y)
    if gameX and gameY then
        SceneManager.mousepressed(gameX, gameY, button, istouch, presses)
    end
end

function love.mousereleased(x, y, button, istouch, presses)
    -- Converte coordenadas da tela para coordenadas do jogo
    local gameX, gameY = push:toGame(x, y)
    if gameX and gameY then
        SceneManager.mousereleased(gameX, gameY, button, istouch, presses)
    end
end

function love.textinput(t)
    SceneManager.textinput(t)
end

function love.mousemoved(x, y, dx, dy, istouch)
    -- Converte coordenadas da tela para coordenadas do jogo
    local gameX, gameY = push:toGame(x, y)
    if gameX and gameY then
        SceneManager.mousemoved(gameX, gameY, dx, dy, istouch)
    end
end

function love.resize(w, h)
    push:resize(w, h)
end

function love.quit()
    Logger.debug("main.love.quit.start", "[love.quit] Iniciando love.quit()...")

    -- Verifica se estamos numa sessão ativa de gameplay
    local isInActiveGameplaySession = false
    if SceneManager.currentScene then
        -- Verifica se é GameplayScene olhando por propriedades específicas
        local isGameplayScene = SceneManager.currentScene.gameOverManager ~= nil and
            SceneManager.currentScene.currentPortalData ~= nil and
            SceneManager.currentScene.hunterId ~= nil

        if isGameplayScene then
            -- Verifica se o player ainda não entrou na sequência de extração
            local extractionManager = ManagerRegistry:get("extractionManager")
            local isInExtractionSequence = extractionManager and extractionManager:isPlayingExtrationSequence()
            local isGameOver = SceneManager.currentScene.gameOverManager and
                SceneManager.currentScene.gameOverManager.isGameOverActive

            -- Se não está em extração E não está em game over, então está numa sessão ativa
            isInActiveGameplaySession = not isInExtractionSequence and not isGameOver
        end
    end

    -- Unload da cena atual
    if SceneManager.currentScene and SceneManager.currentScene.unload then
        SceneManager.currentScene:unload()
        SceneManager.currentScene = nil
    end

    -- Salva apenas se não estiver em sessão ativa
    if not isInActiveGameplaySession then
        ---@type HunterManager
        local hunterMgr = ManagerRegistry:get("hunterManager")
        if hunterMgr and hunterMgr.saveState then
            hunterMgr:saveState()
        end

        ---@type LoadoutManager
        local loadoutMgr = ManagerRegistry:get("loadoutManager")
        if loadoutMgr and loadoutMgr.saveState then
            loadoutMgr:saveState()
        end

        ---@type LobbyStorageManager
        local lobbyStorageMgr = ManagerRegistry:get("lobbyStorageManager")
        if lobbyStorageMgr and lobbyStorageMgr.saveStorage then
            lobbyStorageMgr:saveStorage()
        end

        ---@type AgencyManager
        local agencyMgr = ManagerRegistry:get("agencyManager")
        if agencyMgr and agencyMgr:hasAgency() then
            agencyMgr:saveState()
        end
    else
        Logger.info("main.love.quit.save.skipped", "[love.quit] Salvamento ignorado devido à sessão ativa de gameplay")
    end

    return false
end

-- Em algum lugar que é executado (ex: main.lua ou um arquivo de debug)
_G.GSAddItem = function(itemId, quantity)
    local scene = SceneManager and SceneManager.currentScene
    Logger.debug("Main", "Current scene: " .. tostring(scene))
    if scene and scene.debugAddItemToPlayerInventory then
        scene:debugAddItemToPlayerInventory(itemId, quantity)
    else
        error("Não foi possível chamar debugAddItemToPlayerInventory. Cena atual ou método não encontrado.")
    end
end

_G.GSDropItem = function(itemId, quantity)
    local scene = SceneManager and SceneManager.currentScene
    if scene and scene.debugDropItemAtPlayer then
        scene:debugDropItemAtPlayer(itemId, quantity)
    else
        error("Não foi possível chamar debugDropItemAtPlayer. Cena atual ou método não encontrado.")
    end
end

-- Função global para testar o sistema de notificações
_G.GSTestNotifications = function()
    if NotificationDisplay then
        Logger.info("main.test_notifications", "[GSTestNotifications] Testando sistema de notificações...")

        -- Teste de coleta de item comum
        NotificationDisplay.showItemPickup("Espada de Ferro", 1, nil, "E")

        -- Aguardar um pouco e testar item raro
        love.timer.sleep(1)
        NotificationDisplay.showItemPickup("Espada Lendária", 1, nil, "A")

        -- Teste de mudança de patrimônio
        love.timer.sleep(1)
        NotificationDisplay.showMoneyChange(500)

        -- Teste de compra
        love.timer.sleep(1)
        NotificationDisplay.showItemPurchase("Poção de Vida", 25)

        -- Teste de venda
        love.timer.sleep(1)
        NotificationDisplay.showItemSale("Equipamento Velho", 15)

        Logger.info("main.test_notifications", "[GSTestNotifications] Testes de notificação enviados!")
    else
        error("Sistema de notificações não está disponível.")
    end
end
