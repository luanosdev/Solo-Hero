local SceneManager = require("src.core.scene_manager")
local GameplayScene = {}

function GameplayScene:load(args)
    print("GameplayScene:load")
    if args then
        print("Argumentos recebidos:", args) -- Exemplo de como usar args
        -- Ex: self.levelName = args.level
    end
    -- TODO: Inicializar todos os sistemas do jogo (Player, Enemies, World, etc.)
    -- Esta será a parte que integraremos com o código existente do main.lua
end

function GameplayScene:update(dt)
    -- TODO: Chamar update de todos os sistemas do jogo
    -- Ex: PlayerManager:update(dt), EnemyManager:update(dt), etc.

    -- Exemplo: Voltar para o Lobby ao pressionar ESC
    if love.keyboard.isDown("escape") then
        print("GameplayScene: ESC pressionado, voltando para LobbyScene")
        SceneManager.switchScene("lobby_scene")
    end
end

function GameplayScene:draw()
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()

    -- TODO: Desenhar o mundo do jogo, jogador, inimigos, UI, etc.
    love.graphics.printf("Gameplay Scene - Pressione ESC para voltar ao Lobby", 0, h / 2 - 10, w, "center")

    -- Exemplo: Desenhar informação dos argumentos recebidos
    -- if self.levelName then
    --     love.graphics.print("Level: " .. self.levelName, 10, 10)
    -- end
end

function GameplayScene:keypressed(key, scancode, isrepeat)
    -- TODO: Delegar input para os sistemas relevantes (ex: PlayerController)
    print(string.format("GameplayScene: Tecla pressionada: %s", key))
end

-- Adicionar outros handlers de input (keyreleased, mousepressed, etc.) conforme necessário

function GameplayScene:unload()
    print("GameplayScene:unload - Descarregando recursos do gameplay...")
    -- TODO: Limpar recursos específicos da cena de gameplay (inimigos, etc.)
end

return GameplayScene
