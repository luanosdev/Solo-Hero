--- Gerencia o ciclo de vida e a transição entre cenas do jogo.
-- Mantém a referência da cena atual e fornece métodos para trocar,
-- atualizar e desenhar a cena ativa, além de delegar eventos de input.
--- @class SceneManager
local SceneManager = {}

--- A cena atualmente ativa.
--- @type table | nil # Contém a instância da cena carregada (espera-se métodos como load, update, draw, etc.)
SceneManager.currentScene = nil
--- @type table # Cache para cenas já carregadas (atualmente não usado para forçar reload)
SceneManager.scenes = {}

--- @type boolean # Flag para indicar se o encerramento foi solicitado
SceneManager._quitRequested = false

--- Troca para uma nova cena.
-- Descarrega a cena atual (se tiver o método `unload`), carrega o módulo da nova cena
-- (forçando reload ao limpar o cache do `package.loaded`), e chama o método `load` da nova cena.
---@param sceneName string O nome do arquivo da cena (sem a extensão .lua) dentro de `src/scenes/`.
---@param args table | nil Uma tabela opcional de argumentos a serem passados para o método `load` da nova cena.
function SceneManager.switchScene(sceneName, args)
    print(string.format("SceneManager: Tentando trocar para cena '%s'", sceneName))
    -- Descarregar cena atual (se houver e tiver método unload)
    if SceneManager.currentScene and SceneManager.currentScene.unload then
        SceneManager.currentScene:unload()
    end

    local scenePath = "src.scenes." .. sceneName
    -- Limpa o cache do package para forçar o reload do arquivo da cena
    package.loaded[scenePath] = nil

    --- @type boolean
    --- @type table | string # O módulo da cena ou a mensagem de erro
    local success, sceneModuleOrError = pcall(require, scenePath)

    if success then
        SceneManager.currentScene = sceneModuleOrError
        print(string.format("SceneManager: Cena '%s' carregada com sucesso.", sceneName))
        if SceneManager.currentScene.load then
            -- Passa os argumentos para a função load da nova cena
            --- @type boolean
            --- @type any # Erro retornado por pcall
            local loadSuccess, loadError = pcall(SceneManager.currentScene.load, SceneManager.currentScene, args or {})
            if not loadSuccess then
                SceneManager.currentScene = nil -- Falha ao carregar, invalida a cena atual
                -- Lança um erro para interromper a execução e facilitar o debug
                error(string.format("Erro ao chamar load da cena '%s': %s", sceneName, tostring(loadError)))
            end
        else
            print(string.format("Aviso: Cena '%s' não possui método load.", sceneName))
        end
    else
        SceneManager.currentScene = nil -- Falha ao carregar
        -- Lança um erro para interromper a execução e facilitar o debug
        error(string.format("Erro ao carregar o módulo da cena '%s': %s", sceneName, tostring(sceneModuleOrError)))
    end
end

--- Atualiza a cena atual.
-- Chama o método `update(dt)` da cena ativa, se existir.
---@param dt number O tempo decorrido desde o último frame (delta time).
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
---@param key love.KeyConstant
---@param scancode love.Scancode
---@param isrepeat boolean
function SceneManager.keypressed(key, scancode, isrepeat)
    if SceneManager.currentScene and SceneManager.currentScene.keypressed then
        SceneManager.currentScene:keypressed(key, scancode, isrepeat)
    end
end

--- Delega o evento `love.keyreleased` para a cena atual.
-- Chama o método `keyreleased(key, scancode)` da cena ativa, se existir.
---@param key love.KeyConstant
---@param scancode love.Scancode
function SceneManager.keyreleased(key, scancode)
    if SceneManager.currentScene and SceneManager.currentScene.keyreleased then
        SceneManager.currentScene:keyreleased(key, scancode)
    end
end

--- Delega o evento `love.mousepressed` para a cena atual.
-- Chama o método `mousepressed(x, y, button, istouch, presses)` da cena ativa, se existir.
---@param x number
---@param y number
---@param button number
---@param istouch boolean
---@param presses number
function SceneManager.mousepressed(x, y, button, istouch, presses)
    if SceneManager.currentScene and SceneManager.currentScene.mousepressed then
        SceneManager.currentScene:mousepressed(x, y, button, istouch, presses)
    end
end

--- Delega o evento `love.mousemoved` para a cena atual.
-- Chama o método `mousemoved(x, y, dx, dy, istouch)` da cena ativa, se existir.
---@param x number
---@param y number
---@param dx number
---@param dy number
---@param istouch boolean
function SceneManager.mousemoved(x, y, dx, dy, istouch)
    if SceneManager.currentScene and SceneManager.currentScene.mousemoved then
        SceneManager.currentScene:mousemoved(x, y, dx, dy, istouch)
    end
end

--- Delega o evento `love.mousereleased` para a cena atual.
-- Chama o método `mousereleased(x, y, button, istouch, presses)` da cena ativa, se existir.
---@param x number
---@param y number
---@param button number
---@param istouch boolean
---@param presses number
function SceneManager.mousereleased(x, y, button, istouch, presses)
    if SceneManager.currentScene and SceneManager.currentScene.mousereleased then
        SceneManager.currentScene:mousereleased(x, y, button, istouch, presses)
    end
end

--- Delega o evento `love.textinput` para a cena atual.
-- Chama o método `textinput(t)` da cena ativa, se existir.
---@param t string O texto inserido.
function SceneManager.textinput(t)
    if SceneManager.currentScene and SceneManager.currentScene.textinput then
        SceneManager.currentScene:textinput(t)
    end
end

--- Marca que o jogo deve ser encerrado no próximo ciclo de update.
function SceneManager.requestQuit()
    print("SceneManager: Recebida solicitação para encerrar.")
    SceneManager._quitRequested = true
end

--- Verifica se o encerramento foi solicitado.
---@return boolean
function SceneManager.isQuitRequested()
    return SceneManager._quitRequested
end

return SceneManager
