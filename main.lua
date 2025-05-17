-- main.lua
-- Love2D callbacks e inicialização principal

-- DEBUG: Configurar saída para UTF-8 se possível (tentativa)
xpcall(function()
    if love.system.getOS() == "Windows" then
        os.execute("chcp 65001 > nul") -- Tenta definir code page para UTF-8
    end
end, function(err)
    print("Aviso: Falha ao tentar definir code page para UTF-8:", err)
end)

-- [[ Variáveis Globais Essenciais ]] --
local SceneManager = require("src.core.scene_manager")
local ManagerRegistry = require("src.managers.manager_registry")
-- NOVOS REQUIRES para Managers Persistentes
local ItemDataManager = require("src.managers.item_data_manager")
local ArchetypeManager = require("src.managers.archetype_manager")
local LoadoutManager = require("src.managers.loadout_manager")
local LobbyStorageManager = require("src.managers.lobby_storage_manager")
local HunterManager = require("src.managers.hunter_manager")
local fonts = require("src.ui.fonts")

local lovebird = require("src.libs.lovebird")
local profiler = require("src.libs.profiler")

-- [[ Inicialização LOVE ]] --
function love.load()
    print("\n--- Iniciando love.load() ---")
    print("Modo DEV: " .. tostring(DEV))

    if DEV and PROFILER then
        profiler.start()
    end

    fonts.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.keyboard.setKeyRepeat(true) -- Habilita repetição de tecla

    SceneManager.switchScene("bootloader_scene")

    print("[main.lua] Inicializando ManagerRegistry...")
    print("[main.lua] Criando e carregando managers persistentes...")

    print("  - Criando ItemDataManager...")
    local itemDataMgr = ItemDataManager:new()
    ManagerRegistry:register("itemDataManager", itemDataMgr)
    print("    > ItemDataManager registrado.")

    print("  - Criando ArchetypeManager...")
    local archetypeMgr = ArchetypeManager:new()
    ManagerRegistry:register("archetypeManager", archetypeMgr)
    print("    > ArchetypeManager registrado.")

    print("  - Criando LobbyStorageManager...")
    local lobbyStorageMgr = LobbyStorageManager:new(itemDataMgr) -- Injeta dependência
    ManagerRegistry:register("lobbyStorageManager", lobbyStorageMgr)
    print("    > LobbyStorageManager registrado.")

    print("  - Criando LoadoutManager...")
    local loadoutMgr = LoadoutManager:new(itemDataMgr) -- Passa apenas ItemDataManager
    ManagerRegistry:register("loadoutManager", loadoutMgr)
    print("    > LoadoutManager registrado.")

    print("  - Criando HunterManager...")
    local hunterMgr = HunterManager:new(loadoutMgr, itemDataMgr, archetypeMgr) -- Injeta dependências
    ManagerRegistry:register("hunterManager", hunterMgr)
    print("    > HunterManager registrado.")

    print("[main.lua] Managers persistentes registrados no ManagerRegistry.")

    print("--- love.load() concluído ---")
end

-- [[ Ciclo de Vida LOVE ]] --

function love.update(dt)
    -- Delega o update para a cena atual (se não for encerrar)
    SceneManager.update(dt)

    if DEV then
        lovebird.update()
    end
end

function love.draw()
    -- Desenha a cena ativa
    SceneManager.draw()

    -- Informações de Debug (FPS, etc.) - Opcional
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(fonts.main)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 10)
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
    if key == "f12" then
        profiler.stop()
        profiler.report("profiler_report.txt")
    end
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

function love.mousemoved(x, y, dx, dy, istouch)
    SceneManager.mousemoved(x, y, dx, dy, istouch)
end

--[[
    Callback chamado quando o jogo está prestes a fechar.
    Ideal para salvar o estado final.
]]
function love.quit()
    print("\n--- Iniciando love.quit() ---")
    -- Chama o método de unload da cena atual, se existir
    if SceneManager.currentScene and SceneManager.currentScene.unload then
        SceneManager.currentScene:unload()
        SceneManager.currentScene = nil -- Limpa referência
    end

    -- Salvar estado de Managers Globais/Persistentes (Exemplo)
    print("[main.lua] Solicitando salvamento final dos managers persistentes...")
    local hunterMgr = ManagerRegistry:get("hunterManager")
    if hunterMgr and hunterMgr.saveState then
        print("  - Salvando HunterManager...")
        hunterMgr:saveState()
    end
    local loadoutMgr = ManagerRegistry:get("loadoutManager")
    if loadoutMgr and loadoutMgr.saveState then -- saveState() pode não existir em LoadoutManager? Verificar
        print("  - Salvando LoadoutManager...")
        loadoutMgr:saveState()                  -- Ou :saveAllLoadouts() se for o caso
    end
    local lobbyStorageMgr = ManagerRegistry:get("lobbyStorageManager")
    if lobbyStorageMgr and lobbyStorageMgr.saveStorage then
        print("  - Salvando LobbyStorageManager...")
        lobbyStorageMgr:saveStorage()
    end
    -- Adicione saves para outros managers persistentes aqui se necessário

    print("--- love.quit() concluído ---")
    return false -- Retorna false para permitir o fechamento padrão
end

-- Em algum lugar que é executado (ex: main.lua ou um arquivo de debug)
_G.GSAddItem = function(itemId, quantity)
    local scene = SceneManager and SceneManager.currentScene
    if scene and scene.debugAddItemToPlayerInventory then
        scene:debugAddItemToPlayerInventory(itemId, quantity)
    else
        print("DEBUG ERRO: Não foi possível chamar debugAddItemToPlayerInventory. Cena atual ou método não encontrado.")
    end
end

_G.GSDropItem = function(itemId, quantity)
    local scene = SceneManager and SceneManager.currentScene
    if scene and scene.debugDropItemAtPlayer then
        scene:debugDropItemAtPlayer(itemId, quantity)
    else
        print("DEBUG ERRO: Não foi possível chamar debugDropItemAtPlayer. Cena atual ou método não encontrado.")
    end
end
