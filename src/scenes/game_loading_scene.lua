local SceneManager = require("src.core.scene_manager")
local fonts = require("src.ui.fonts") -- Requer o módulo de fontes

--- Cena exibida enquanto o jogo principal está sendo carregado.
-- Mostra uma mensagem "Carregando Jogo..." com cor animada.
-- Atualmente, simula o carregamento com um temporizador.
local GameLoadingScene = {}

GameLoadingScene.sceneArgs = nil            -- <<< RENOMEADO: Para armazenar todos os args
local timer = 0
local timeToSwitch = 0.5                    -- Aumentei um pouco o tempo de carregamento simulado
local loadingText = "Entrando no Portal..." -- <<< Texto ajustado

--- Chamado quando a cena é carregada.
-- Reinicia o temporizador e armazena dados do portal.
-- @param args table|nil Argumentos da cena anterior (espera-se { portalId, hordeConfig, ... }).
function GameLoadingScene:load(args)
    self.sceneArgs = args -- Armazena a tabela de argumentos completa
    if self.sceneArgs and self.sceneArgs.portalId then
        -- Extrai nome/rank para display, se existirem na hordeConfig ou portalId?
        -- Assumindo que args contenham nome/rank diretamente ou dentro de hordeConfig?
        -- Se não, precisaria buscar em portalDefinitions usando portalId.
        -- Por ora, vamos mostrar apenas ID se disponível.
        print(string.format("GameLoadingScene:load - Carregando para portal ID: %s...", self.sceneArgs.portalId))
    else
        print("GameLoadingScene:load - Aviso: Nenhum dado de portal recebido. Carregando jogo padrão...")
    end
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
        -- Passa os argumentos armazenados para a próxima cena
        SceneManager.switchScene("gameplay_scene", self.sceneArgs)
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

    -- Calcula cor animada
    local grayLevel = 0.5
    local colorSpeed = math.pi * 0.5
    local oscillation = (math.sin(timer * colorSpeed) + 1) / 2
    local colorComponent = grayLevel + (1 - grayLevel) * oscillation
    love.graphics.setColor(colorComponent, colorComponent, colorComponent, 1)

    -- Define a fonte
    local mainFont = fonts.title or love.graphics.getFont()
    local detailFont = fonts.main_small or love.graphics.getFont()
    love.graphics.setFont(mainFont)

    -- Calcula posição vertical centralizada para texto principal
    local loadingH = mainFont:getHeight()
    local loadingY = (h / 2) - (loadingH) -- Um pouco acima do centro

    -- Desenha o texto principal centralizado
    love.graphics.printf(loadingText, 0, loadingY, w, "center")

    -- <<< NOVO: Desenha nome e rank do portal abaixo >>>
    if self.sceneArgs and self.sceneArgs.portalId then
        love.graphics.setFont(detailFont)
        local portalText = string.format("ID: %s", self.sceneArgs.portalId)
        local detailY = loadingY + loadingH + 10 -- Posição abaixo do texto principal
        love.graphics.printf(portalText, 0, detailY, w, "center")
    end

    -- Restaura a cor padrão para branco
    love.graphics.setColor(1, 1, 1, 1)

    -- TODO: Desenhar barra de progresso
end

return GameLoadingScene
