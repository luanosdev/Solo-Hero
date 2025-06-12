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
local fonts = require("src.ui.fonts")

local lovebird = require("src.libs.lovebird")
local profiler = require("src.libs.profiler")
local Logger = require("src.libs.logger")
local lurker = require("src.libs.lurker")

-- [[ Inicialização LOVE ]] --
function love.load()
    --- Registra o Logger globalmente
    Logger.setVisibleLevels({ debug = false, info = true, warn = true, error = false })
    _G.Logger = Logger

    Logger.debug("Main", "Iniciando love.load()...")
    Logger.debug("Main", "Modo DEV: " .. tostring(DEV))

    if DEV and PROFILER then
        profiler.start()
    end

    fonts.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.keyboard.setKeyRepeat(true) -- Habilita repetição de tecla

    math.randomseed(os.time() + tonumber(tostring(os.clock()):reverse():sub(1, 6)))

    SceneManager.switchScene("bootloader_scene")

    Logger.debug("Main", "Inicializando ManagerRegistry...")
    Logger.debug("Main", "Criando e carregando managers persistentes...")

    Logger.debug("Main", "  - Criando ItemDataManager...")
    local itemDataMgr = ItemDataManager:new()
    ManagerRegistry:register("itemDataManager", itemDataMgr)
    Logger.debug("Main", "    > ItemDataManager registrado.")

    Logger.debug("Main", "  - Criando ArchetypeManager...")
    local archetypeMgr = ArchetypeManager:new()
    ManagerRegistry:register("archetypeManager", archetypeMgr)
    Logger.debug("Main", "    > ArchetypeManager registrado.")

    Logger.debug("Main", "  - Criando LobbyStorageManager...")
    local lobbyStorageMgr = LobbyStorageManager:new(itemDataMgr) -- Injeta dependência
    ManagerRegistry:register("lobbyStorageManager", lobbyStorageMgr)
    Logger.debug("Main", "    > LobbyStorageManager registrado.")

    Logger.debug("Main", "  - Criando LoadoutManager...")
    local loadoutMgr = LoadoutManager:new(itemDataMgr) -- Passa apenas ItemDataManager
    ManagerRegistry:register("loadoutManager", loadoutMgr)
    Logger.debug("Main", "    > LoadoutManager registrado.")

    Logger.debug("Main", "  - Criando HunterManager...")
    local hunterMgr = HunterManager:new(loadoutMgr, itemDataMgr, archetypeMgr) -- Injeta dependências
    ManagerRegistry:register("hunterManager", hunterMgr)
    Logger.debug("Main", "    > HunterManager registrado.")

    Logger.debug("Main", "  - Criando AgencyManager...")
    local agencyMgr = AgencyManager:new()
    ManagerRegistry:register("agencyManager", agencyMgr)
    Logger.debug("Main", "    > AgencyManager registrado.")

    Logger.debug("Main", "  - Criando ReputationManager...")
    local reputationMgr = ReputationManager:new(agencyMgr, itemDataMgr) -- Injeta dependências
    ManagerRegistry:register("reputationManager", reputationMgr)
    Logger.debug("Main", "    > ReputationManager registrado.")

    Logger.debug("Main", "Managers persistentes registrados no ManagerRegistry.")

    Logger.debug("Main", "love.load() concluído.")
end

-- [[ Ciclo de Vida LOVE ]] --

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
    -- Desenha a cena ativa
    SceneManager.draw()

    -- Informações de Debug (FPS, etc.) - Opcional
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(fonts.main)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 10)

    Logger.draw()
end

-- [[ Callbacks de Input LOVE ]] --

function love.keypressed(key, scancode, isrepeat)
    -- Passa o evento para a cena ativa
    SceneManager.keypressed(key, scancode, isrepeat)

    -- Toggle Fullscreen com F11 (exemplo global)
    if key == "f11" then
        local isFullscreen, fullscreenType = love.window.getFullscreen()
        love.window.setFullscreen(not isFullscreen, "desktop")
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
    SceneManager.mousepressed(x, y, button, istouch, presses)
end

function love.mousereleased(x, y, button, istouch, presses)
    SceneManager.mousereleased(x, y, button, istouch, presses)
end

function love.textinput(t)
    SceneManager.textinput(t)
end

function love.mousemoved(x, y, dx, dy, istouch)
    SceneManager.mousemoved(x, y, dx, dy, istouch)
end

--[[
    Callback chamado quando o jogo está prestes a fechar.
    Ideal para salvar o estado final.
]]
function love.quit()
    Logger.debug("Main", "Iniciando love.quit()...")
    -- Chama o método de unload da cena atual, se existir
    if SceneManager.currentScene and SceneManager.currentScene.unload then
        SceneManager.currentScene:unload()
        SceneManager.currentScene = nil -- Limpa referência
    end

    -- Salvar estado de Managers Globais/Persistentes (Exemplo)
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

    Logger.debug("Main", "love.quit() concluído.")
    return false -- Retorna false para permitir o fechamento padrão
end

-- Em algum lugar que é executado (ex: main.lua ou um arquivo de debug)
_G.GSAddItem = function(itemId, quantity)
    local scene = SceneManager and SceneManager.currentScene
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
