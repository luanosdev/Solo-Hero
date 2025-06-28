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
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.keyboard.setKeyRepeat(true) -- Habilita repetição de tecla

    math.randomseed(os.time() + tonumber(tostring(os.clock()):reverse():sub(1, 6)))

    -- Configuração do sistema de resolução adaptável
    local windowWidth, windowHeight = love.window.getDesktopDimensions()

    -- Em modo DEV, permite redimensionamento e modo janela para facilitar desenvolvimento
    -- Em modo PROD, usa fullscreen conforme configurado no conf.lua
    local pushOptions = {
        fullscreen = DEV and false or true, -- Janela em DEV, fullscreen em PROD
        resizable = true,
        canvas = true,
        pixelperfect = false,
        highdpi = true,
        stretched = false
    }

    push:setupScreen(1920, 1080, windowWidth, windowHeight, pushOptions)
    Logger.info(
        "love.load.resolution",
        "[love.load] Sistema de resolução configurado: 1920x1080 -> " .. windowWidth .. "x" .. windowHeight
    )

    -- Inicializa o utilitário de resolução
    ResolutionUtils.initialize(push)
    _G.ResolutionUtils = ResolutionUtils
    Logger.info("love.load.resolution_utils", "[love.load] ResolutionUtils inicializado e disponível globalmente")

    SceneManager.switchScene("bootloader_scene")

    Logger.debug("love.load.managers.start", "[love.load] Inicializando ManagerRegistry...")
    Logger.debug("love.load.managers.item_data_manager", "[love.load] Criando ItemDataManager...")
    local itemDataMgr = ItemDataManager:new()
    ManagerRegistry:register("itemDataManager", itemDataMgr)
    Logger.debug("love.load.managers.item_data_manager.registered", "[love.load] ItemDataManager registrado.")

    Logger.debug("love.load.managers.archetype_manager", "[love.load] Criando ArchetypeManager...")
    local archetypeMgr = ArchetypeManager:new()
    ManagerRegistry:register("archetypeManager", archetypeMgr)
    Logger.debug("love.load.managers.archetype_manager.registered", "[love.load] ArchetypeManager registrado.")

    Logger.debug("love.load.managers.lobby_storage_manager", "[love.load] Criando LobbyStorageManager...")
    local lobbyStorageMgr = LobbyStorageManager:new(itemDataMgr)
    ManagerRegistry:register("lobbyStorageManager", lobbyStorageMgr)
    Logger.debug("love.load.managers.lobby_storage_manager.registered", "[love.load] LobbyStorageManager registrado.")

    Logger.debug("love.load.managers.loadout_manager", "[love.load] Criando LoadoutManager...")
    local loadoutMgr = LoadoutManager:new(itemDataMgr)
    ManagerRegistry:register("loadoutManager", loadoutMgr)
    Logger.debug("love.load.managers.loadout_manager.registered", "[love.load] LoadoutManager registrado.")

    Logger.debug("love.load.managers.hunter_manager", "[love.load] Criando HunterManager...")
    local hunterMgr = HunterManager:new(loadoutMgr, itemDataMgr, archetypeMgr)
    ManagerRegistry:register("hunterManager", hunterMgr)
    Logger.debug("love.load.managers.hunter_manager.registered", "[love.load] HunterManager registrado.")

    Logger.debug("love.load.managers.agency_manager", "[love.load] Criando AgencyManager...")
    local agencyMgr = AgencyManager:new()
    ManagerRegistry:register("agencyManager", agencyMgr)
    Logger.debug("love.load.managers.agency_manager.registered", "[love.load] AgencyManager registrado.")

    Logger.debug("love.load.managers.reputation_manager", "[love.load] Criando ReputationManager...")
    local reputationMgr = ReputationManager:new(agencyMgr, itemDataMgr)
    ManagerRegistry:register("reputationManager", reputationMgr)
    Logger.debug("love.load.managers.reputation_manager.registered", "[love.load] ReputationManager registrado.")

    Logger.debug("love.load.managers.game_statistics_manager", "[love.load] Criando GameStatisticsManager...")
    local gameStatsMgr = GameStatisticsManager:new()
    ManagerRegistry:register("gameStatisticsManager", gameStatsMgr)
    Logger.debug("love.load.managers.game_statistics_manager.registered", "[love.load] GameStatisticsManager registrado.")

    Logger.debug("love.load.managers.registered", "[love.load] Managers persistentes registrados no ManagerRegistry.")

    Logger.debug("love.load.end", "[love.load] love.load() concluído.")
end

function love.update(dt)
    -- Delega o update para a cena atual (se não for encerrar)
    SceneManager.update(dt)

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

    -- Informações de resolução em modo DEV
    if DEV then
        love.graphics.setFont(fonts.main_small)
        local scaleInfo = ResolutionUtils.getScaleInfo()
        love.graphics.print(string.format(
            "FPS: %d | Resolução: %dx%d -> %dx%d | Escala: %.2f | Offset: %.0f,%.0f | Stencil: %s",
            love.timer.getFPS(),
            scaleInfo.gameWidth, scaleInfo.gameHeight,
            scaleInfo.windowWidth, scaleInfo.windowHeight,
            scaleInfo.scaleX,
            scaleInfo.offsetX, scaleInfo.offsetY,
            scaleInfo.hasStencil and "✓" or "✗"
        ), 10, 70)
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
    if key == "f10" then
        Logger.disable()
        profiler.start()
    end
    if key == "f12" then
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
    Logger.info("Main", "Janela redimensionada para: " .. w .. "x" .. h)
end

--[[
    Callback chamado quando o jogo está prestes a fechar.
    Ideal para salvar o estado final.
]]
function love.quit()
    Logger.debug("Main", "Iniciando love.quit()...")

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

            if isInActiveGameplaySession then
                Logger.info("Main",
                    "Detectada sessão ativa de gameplay - evitando salvamento para prevenir perda de progresso")
            end
        end
    end

    -- Chama o método de unload da cena atual, se existir
    if SceneManager.currentScene and SceneManager.currentScene.unload then
        SceneManager.currentScene:unload()
        SceneManager.currentScene = nil -- Limpa referência
    end

    -- Só salva se NÃO estiver numa sessão ativa de gameplay
    if not isInActiveGameplaySession then
        Logger.debug("Main", "Solicitando salvamento final dos managers persistentes...")
        local hunterMgr = ManagerRegistry:get("hunterManager")
        if hunterMgr and hunterMgr.saveState then
            Logger.debug("Main", "  - Salvando HunterManager...")
            hunterMgr:saveState()
        end
        local loadoutMgr = ManagerRegistry:get("loadoutManager")
        if loadoutMgr and loadoutMgr.saveState then -- saveState() pode não existir em LoadoutManager? Verificar
            Logger.debug("Main", "  - Salvando LoadoutManager...")
            loadoutMgr:saveState()                  -- Ou :saveAllLoadouts() se for o caso
        end
        local lobbyStorageMgr = ManagerRegistry:get("lobbyStorageManager")
        if lobbyStorageMgr and lobbyStorageMgr.saveStorage then
            Logger.debug("Main", "  - Salvando LobbyStorageManager...")
            lobbyStorageMgr:saveStorage()
        end
        -- Adicione saves para outros managers persistentes aqui se necessário

        ---@type AgencyManager
        local agencyMgr = ManagerRegistry:get("agencyManager")
        if agencyMgr and agencyMgr:hasAgency() then
            Logger.debug("Main", "  - Salvando AgencyManager...")
            agencyMgr:saveState()
        end
    else
        Logger.info("Main", "Salvamento ignorado devido à sessão ativa de gameplay")
    end

    Logger.debug("Main", "love.quit() concluído.")
    return false -- Retorna false para permitir o fechamento padrão
end

-- Em algum lugar que é executado (ex: main.lua ou um arquivo de debug)
_G.GSAddItem = function(itemId, quantity)
    local scene = SceneManager and SceneManager.currentScene
    Logger.debug("Main", "Current scene: " .. tostring(scene))
    if scene and scene.debugAddItemToPlayerInventory then
        scene:debugAddItemToPlayerInventory(itemId, quantity)
    else
        Logger.error("Main",
            "Não foi possível chamar debugAddItemToPlayerInventory. Cena atual ou método não encontrado.")
    end
end

_G.GSDropItem = function(itemId, quantity)
    local scene = SceneManager and SceneManager.currentScene
    if scene and scene.debugDropItemAtPlayer then
        scene:debugDropItemAtPlayer(itemId, quantity)
    else
        Logger.error("Main", "Não foi possível chamar debugDropItemAtPlayer. Cena atual ou método não encontrado.")
    end
end
