--- Gerencia o ciclo de vida e a transição entre cenas do jogo.
-- Mantém a referência da cena atual e fornece métodos para trocar,
-- atualizar e desenhar a cena ativa, além de delegar eventos de input.
local SceneManager = {}

--- A cena atualmente ativa. Deve ser um módulo de cena com métodos `load`, `update`, `draw`, etc.
SceneManager.currentScene = nil
SceneManager.scenes = {} -- Cache para cenas já carregadas, se necessário (atualmente não usado para forçar reload)

--- Troca para uma nova cena.
-- Descarrega a cena atual (se tiver o método `unload`), carrega o módulo da nova cena
-- (forçando reload ao limpar o cache do `package.loaded`), e chama o método `load` da nova cena.
-- @param sceneName (string) O nome do arquivo da cena (sem a extensão .lua) dentro de `src/scenes/`.
-- @param args (table|nil) Uma tabela opcional de argumentos a serem passados para o método `load` da nova cena.
function SceneManager.switchScene(sceneName, args)
    print(string.format("SceneManager: Tentando trocar para cena '%s'", sceneName))
    -- Descarregar cena atual (se houver e tiver método unload)
    if SceneManager.currentScene and SceneManager.currentScene.unload then
        SceneManager.currentScene:unload()
    end

    local scenePath = "src.scenes." .. sceneName
    -- Limpa o cache do package para forçar o reload do arquivo da cena
    package.loaded[scenePath] = nil

    local success, sceneModuleOrError = pcall(require, scenePath)

    if success then
        SceneManager.currentScene = sceneModuleOrError
        print(string.format("SceneManager: Cena '%s' carregada com sucesso.", sceneName))
        if SceneManager.currentScene.load then
            -- Passa os argumentos para a função load da nova cena
            local loadSuccess, loadError = pcall(SceneManager.currentScene.load, SceneManager.currentScene, args or {})
            if not loadSuccess then
                SceneManager.currentScene = nil -- Falha ao carregar, invalida a cena atual
                error(string.format("Erro ao chamar load da cena '%s': %s", sceneName, tostring(loadError)))
            end
        else
            print(string.format("Aviso: Cena '%s' não possui método load.", sceneName))
        end
    else
        SceneManager.currentScene = nil -- Falha ao carregar
        error(string.format("Erro ao carregar o módulo da cena '%s': %s", sceneName, tostring(sceneModuleOrError)))
    end
end

--- Atualiza a cena atual.
-- Chama o método `update(dt)` da cena ativa, se existir.
-- @param dt (number) O tempo decorrido desde o último frame (delta time).
function SceneManager.update(dt)
    if SceneManager.currentScene and SceneManager.currentScene.update then
        SceneManager.currentScene:update(dt)
    end
end

--- Desenha a cena atual.
-- Chama o método `draw()` da cena ativa, se existir.
function SceneManager.draw()
    if SceneManager.currentScene and SceneManager.currentScene.draw then
        SceneManager.currentScene:draw()
    end
end

-- Funções para delegar eventos de input para a cena atual

--- Delega o evento `love.keypressed` para a cena atual.
-- Chama o método `keypressed(key, scancode, isrepeat)` da cena ativa, se existir.
-- @param key (...) Argumentos originais de `love.keypressed`.
-- @param scancode (...) Argumentos originais de `love.keypressed`.
-- @param isrepeat (...) Argumentos originais de `love.keypressed`.
function SceneManager.keypressed(key, scancode, isrepeat)
    if SceneManager.currentScene and SceneManager.currentScene.keypressed then
        SceneManager.currentScene:keypressed(key, scancode, isrepeat)
    end
end

--- Delega o evento `love.keyreleased` para a cena atual.
-- Chama o método `keyreleased(key, scancode)` da cena ativa, se existir.
-- @param key (...) Argumentos originais de `love.keyreleased`.
-- @param scancode (...) Argumentos originais de `love.keyreleased`.
function SceneManager.keyreleased(key, scancode)
    if SceneManager.currentScene and SceneManager.currentScene.keyreleased then
        SceneManager.currentScene:keyreleased(key, scancode)
    end
end

--- Delega o evento `love.mousepressed` para a cena atual.
-- Chama o método `mousepressed(x, y, button, istouch, presses)` da cena ativa, se existir.
-- @param x (...) Argumentos originais de `love.mousepressed`.
-- @param y (...) Argumentos originais de `love.mousepressed`.
-- @param button (...) Argumentos originais de `love.mousepressed`.
-- @param istouch (...) Argumentos originais de `love.mousepressed`.
-- @param presses (...) Argumentos originais de `love.mousepressed`.
function SceneManager.mousepressed(x, y, button, istouch, presses)
    if SceneManager.currentScene and SceneManager.currentScene.mousepressed then
        SceneManager.currentScene:mousepressed(x, y, button, istouch, presses)
    end
end

--- Delega o evento `love.mousemoved` para a cena atual.
-- Chama o método `mousemoved(x, y, dx, dy, istouch)` da cena ativa, se existir.
-- @param x (...) Argumentos originais de `love.mousemoved`.
-- @param y (...) Argumentos originais de `love.mousemoved`.
-- @param dx (...) Argumentos originais de `love.mousemoved`.
-- @param dy (...) Argumentos originais de `love.mousemoved`.
-- @param istouch (...) Argumentos originais de `love.mousemoved`.
function SceneManager.mousemoved(x, y, dx, dy, istouch)
    if SceneManager.currentScene and SceneManager.currentScene.mousemoved then
        SceneManager.currentScene:mousemoved(x, y, dx, dy, istouch)
    end
end

--- Delega o evento `love.mousereleased` para a cena atual.
-- Chama o método `mousereleased(x, y, button, istouch, presses)` da cena ativa, se existir.
-- @param x (...) Argumentos originais de `love.mousereleased`.
-- @param y (...) Argumentos originais de `love.mousereleased`.
-- @param button (...) Argumentos originais de `love.mousereleased`.
-- @param istouch (...) Argumentos originais de `love.mousereleased`.
-- @param presses (...) Argumentos originais de `love.mousereleased`.
function SceneManager.mousereleased(x, y, button, istouch, presses)
    if SceneManager.currentScene and SceneManager.currentScene.mousereleased then
        SceneManager.currentScene:mousereleased(x, y, button, istouch, presses)
    end
end

return SceneManager
