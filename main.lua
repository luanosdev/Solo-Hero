-- Novo sistema de cenas
local SceneManager = require("src.core.scene_manager")

function love.load()
    math.randomseed(os.time())              -- <<< NOVO: Inicializa o gerador de números aleatórios
    love.filesystem.setIdentity("SoloHero") -- <<< NOVO: Define a pasta de salvamento

    -- Window settings - Fullscreen (mantido, pode ser útil globalmente)
    love.window.setMode(0, 0, { fullscreen = true })
    -- Carrega a primeira cena
    SceneManager.switchScene("bootloader_scene")
end

function love.update(dt)
    -- Verifica se o SceneManager solicitou o encerramento
    if SceneManager.isQuitRequested() then
        print("main.lua: SceneManager solicitou quit. Descarregando cena atual...")
        -- Garante que a cena atual seja descarregada antes de sair
        if SceneManager.currentScene and SceneManager.currentScene.unload then
            SceneManager.currentScene:unload()
            SceneManager.currentScene = nil -- Limpa referência
        end
        print("main.lua: Chamando love.event.quit()")
        love.event.quit() -- Encerra o jogo
        return            -- Interrompe o update aqui
    end

    -- Delega o update para a cena atual (se não for encerrar)
    SceneManager.update(dt)
end

function love.draw()
    -- Clear the screen (pode ser definido pela cena, mas um default é bom)
    love.graphics.clear(0.1, 0.1, 0.1, 1) -- Cor de fundo padrão escura

    -- Delega o draw para a cena atual
    SceneManager.draw()
end

-- Delega eventos de input para o SceneManager
function love.keypressed(key, scancode, isrepeat)
    SceneManager.keypressed(key, scancode, isrepeat)
end

function love.mousepressed(x, y, button, istouch, presses)
    SceneManager.mousepressed(x, y, button, istouch, presses)
end

-- Adiciona funções para keyreleased e mousemoved para delegar também
function love.keyreleased(key, scancode)
    SceneManager.keyreleased(key, scancode)
end

function love.mousemoved(x, y, dx, dy, istouch)
    SceneManager.mousemoved(x, y, dx, dy, istouch)
end

function love.mousereleased(x, y, button, istouch, presses)
    SceneManager.mousereleased(x, y, button, istouch, presses)
end
