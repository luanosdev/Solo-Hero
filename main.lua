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

    Logger.info(
        "love.load.resolution",
        string.format(
            "[love.load] Sistema de resolução configurado: %dx%d -> %dx%d (Stretched: %s, Aspect: %.6f vs %.6f)",
            gameWidth, gameHeight, windowWidth, windowHeight,
            shouldUseStretched and "SIM" or "NÃO",
            gameAspect, screenAspect)
    )

    -- Verifica se as dimensões da janela estão corretas após a inicialização
    if DEV then
        local actualWidth, actualHeight = love.graphics.getDimensions()
        if actualWidth ~= windowWidth or actualHeight ~= windowHeight then
            Logger.info("Main", string.format(
                "AVISO: Dimensões da janela foram alteradas de %dx%d para %dx%d após inicialização",
                windowWidth, windowHeight, actualWidth, actualHeight
            ))
        end
    end

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
        local gameAspect = scaleInfo.gameWidth / scaleInfo.gameHeight
        local screenAspect = scaleInfo.windowWidth / scaleInfo.windowHeight
        local isCorrectAspect = math.abs(gameAspect - screenAspect) < 0.01

        -- Linha 1: Info básica
        love.graphics.print(string.format(
            "FPS: %d | Janela: %dx%d | Stretched: %s | Offset: %.0f,%.0f",
            love.timer.getFPS(),
            scaleInfo.windowWidth, scaleInfo.windowHeight,
            push._stretched and "SIM" or "NÃO",
            scaleInfo.offsetX, scaleInfo.offsetY
        ), 10, 70)

        -- Linha 2: Diagnóstico do problema
        local problemText = ""
        if not isCorrectAspect then
            problemText = " ⚠️ PROPORÇÃO INCORRETA!"
        elseif not push._stretched then
            problemText = " ⚠️ STRETCHED DESATIVADO!"
        elseif scaleInfo.offsetX ~= 0 or scaleInfo.offsetY ~= 0 then
            problemText = " ⚠️ BORDAS DETECTADAS!"
        else
            problemText = " ✅ CONFIGURAÇÃO OK"
        end

        love.graphics.print(string.format(
            "Aspect: %.3f vs %.3f | Escala: %.3f,%.3f%s",
            gameAspect, screenAspect,
            scaleInfo.scaleX, scaleInfo.scaleY,
            problemText
        ), 10, 90)

        -- Linha 3: Controles
        love.graphics.print(
            "F8: Forçar 1280x720 | F9: Toggle Stretched | F11: Fullscreen",
            10, 110
        )
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

    -- Toggle Stretched Mode com F9 (modo DEV)
    if key == "f9" and DEV then
        push._stretched = not push._stretched
        push:initValues()
        Logger.info("Main", "Modo Stretched alterado para: " .. (push._stretched and "ATIVO" or "INATIVO"))
    end

    -- Força dimensões corretas com F8 (modo DEV)
    if key == "f8" and DEV then
        local targetWidth, targetHeight = 1280, 720
        Logger.info("Main", "Forçando dimensões para: " .. targetWidth .. "x" .. targetHeight)

        love.window.setMode(targetWidth, targetHeight, {
            fullscreen = false,
            resizable = false,
            centered = true
        })

        -- Força o push a usar as dimensões corretas
        push._RWIDTH = targetWidth
        push._RHEIGHT = targetHeight
        local gameAspect = 1920 / 1080
        local screenAspect = targetWidth / targetHeight
        push._stretched = math.abs(gameAspect - screenAspect) < 0.01
        push:initValues()
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
    -- Em modo DEV, força dimensões 16:9 se foram alteradas incorretamente
    if DEV then
        local gameAspect = 1920 / 1080 -- 1.777778
        local screenAspect = w / h
        local aspectDiff = math.abs(gameAspect - screenAspect)

        -- Se as proporções estão muito diferentes, força correção
        if aspectDiff > 0.05 then
            local targetWidth = 1280
            local targetHeight = 720

            Logger.info("Main", string.format(
                "Redimensionamento incorreto detectado %dx%d (aspect: %.6f). Forçando para %dx%d",
                w, h, screenAspect, targetWidth, targetHeight
            ))

            love.window.setMode(targetWidth, targetHeight, {
                fullscreen = false,
                resizable = false,
                centered = true
            })

            -- Atualiza o push com as dimensões corretas
            push._RWIDTH = targetWidth
            push._RHEIGHT = targetHeight
            push:initValues()
            return
        end
    end

    push:resize(w, h)

    -- Debug da detecção de stretched após resize
    local gameAspect = 1920 / 1080
    local screenAspect = w / h
    local aspectDiff = math.abs(gameAspect - screenAspect)
    local shouldBeStretched = aspectDiff < 0.01

    Logger.info("Main", string.format(
        "Janela redimensionada para: %dx%d | Aspect: %.6f vs %.6f | Diff: %.6f | Stretched: %s",
        w, h, gameAspect, screenAspect, aspectDiff, shouldBeStretched and "SIM" or "NÃO"
    ))
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
