local SceneManager = require("src.core.scene_manager")
local fonts = require("src.ui.fonts") -- Requer o módulo de fontes

--- Cena exibida enquanto o jogo principal está sendo carregado.
-- Mostra uma mensagem "Carregando Jogo..." com cor animada.
-- Atualmente, simula o carregamento com um temporizador.
local GameLoadingScene = {}

local timer = 0
local timeToSwitch = 3.0 -- Aumentei um pouco o tempo de carregamento simulado
local loadingText = "Carregando Jogo..."

--- Chamado quando a cena é carregada.
-- Reinicia o temporizador de carregamento simulado.
-- @param args (table|nil) Argumentos da cena anterior (não usado aqui).
function GameLoadingScene:load(args)
    print("GameLoadingScene:load - Simulando carregamento do jogo...")
    timer = 0
    -- TODO: Iniciar carregamento real de assets/sistemas aqui (preferencialmente assíncrono)
end

--- Chamado a cada frame para atualizar a lógica.
-- Incrementa o temporizador e troca para GameplayScene quando o tempo é atingido.
-- @param dt (number) Delta time.
function GameLoadingScene:update(dt)
    timer = timer + dt
    if timer >= timeToSwitch then
        print("GameLoadingScene:update - Carregamento simulado concluído. Trocando para GameplayScene...")
        -- Ex: SceneManager.switchScene("gameplay_scene", { level = "level1", difficulty = "normal" })
        SceneManager.switchScene("gameplay_scene")
    end
    -- TODO: Atualizar barra de progresso com base no carregamento real
end

--- Chamado a cada frame para desenhar a cena.
-- Desenha o texto "Carregando Jogo..." com animação de cor.
function GameLoadingScene:draw()
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()

    -- Define fundo escuro
    love.graphics.setColor(0.1, 0.1, 0.1, 1)
    love.graphics.rectangle("fill", 0, 0, w, h)

    -- Desenha o texto "Carregando Jogo..." com cor animada
    local grayLevel = 0.5            -- Nível de cinza base
    local colorSpeed = math.pi * 0.5 -- Velocidade da animação (mais lenta agora)

    -- Calcula a oscilação da cor usando o timer da cena
    local oscillation = (math.sin(timer * colorSpeed) + 1) / 2

    -- Interpola a cor
    local colorComponent = grayLevel + (1 - grayLevel) * oscillation

    -- Define a cor calculada
    love.graphics.setColor(colorComponent, colorComponent, colorComponent, 1)

    -- Define a fonte (se carregada)
    if fonts.title then -- Usando a fonte title para o loading
        love.graphics.setFont(fonts.title)
    end

    -- Calcula posição vertical centralizada
    local loadingH = (fonts.title and fonts.title:getHeight()) or 24 -- Altura da fonte ou fallback
    local loadingY = (h / 2) - (loadingH / 2)

    -- Desenha o texto centralizado
    love.graphics.printf(loadingText, 0, loadingY, w, "center")

    -- Restaura a cor padrão para branco
    love.graphics.setColor(1, 1, 1, 1)

    -- TODO: Desenhar barra de progresso
end

return GameLoadingScene
