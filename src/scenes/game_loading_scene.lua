local SceneManager = require("src.core.scene_manager")
local GameLoadingScene = {}

local timer = 0
local timeToSwitch = 1.5 -- Tempo simulando o carregamento antes de ir para Gameplay

function GameLoadingScene:load(args)
    print("GameLoadingScene:load - Simulando carregamento do jogo...")
    timer = 0
    -- Aqui, em uma implementação real, você iniciaria o carregamento
    -- assíncrono de assets, inicialização de sistemas do jogo, etc.
end

function GameLoadingScene:update(dt)
    timer = timer + dt
    if timer >= timeToSwitch then
        print("GameLoadingScene:update - Carregamento simulado concluído. Trocando para GameplayScene...")
        -- Aqui poderíamos passar argumentos para a cena de gameplay, se necessário
        -- Ex: SceneManager.switchScene("gameplay_scene", { level = "level1", difficulty = "normal" })
        SceneManager.switchScene("gameplay_scene")
    end
    -- Poderia ter lógica para atualizar uma barra de progresso aqui
end

function GameLoadingScene:draw()
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    love.graphics.printf("Carregando Jogo...", 0, h / 2 - 10, w, "center")
    -- Poderia desenhar uma barra de progresso
end

return GameLoadingScene
