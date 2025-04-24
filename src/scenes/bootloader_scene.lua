local SceneManager = require("src.core.scene_manager")
local fonts = require("src.ui.fonts") -- Requer o módulo de fontes

--- Cena inicial do jogo.
-- Responsável por carregar recursos essenciais (como fontes e logo) e exibir
-- uma tela de "loading" por um tempo mínimo antes de transicionar para o Lobby.
local BootloaderScene = {}

local isLoadingComplete = false
local displayTimer = 0
local minDisplayTime = 10.5 -- Tempo mínimo em segundos que a cena ficará visível

local logo = nil
local logoPath = "assets/images/FDK_LOGO_WHITE.png" -- Caminho para a imagem da logo
local titleText = "Solo Hero"
local loadingText = "Loading..."

--- Chamado uma vez quando a cena é carregada pelo SceneManager.
-- Carrega as fontes e a imagem da logo.
-- @param args (table|nil) Argumentos passados pelo SceneManager.switchScene (não utilizado aqui).
function BootloaderScene:load(args)
    print("BootloaderScene:load - Carregando fontes e logo...")
    isLoadingComplete = false
    displayTimer = 0

    -- Carrega as fontes
    local fontSuccess, fontErr = pcall(fonts.load)
    if fontSuccess then
        print("Fontes carregadas com sucesso.")
    else
        print("Erro ao carregar fontes:", fontErr)
        -- Considerar logar o erro ou exibir uma mensagem mais visível
    end

    -- Carrega a logo
    local imgSuccess, imgErr = pcall(function()
        logo = love.graphics.newImage(logoPath)
    end)
    if imgSuccess and logo then
        print("Logo carregada com sucesso.")
    else
        print(string.format("Erro ao carregar a logo '%s': %s", logoPath, tostring(imgErr or "Imagem não encontrada")))
        logo = nil -- Garante que logo é nil se falhar
    end

    -- Marca o carregamento como completo para permitir a transição após o tempo mínimo.
    isLoadingComplete = true
    print("BootloaderScene: Carregamento inicial concluído.")
end

--- Chamado a cada frame para atualizar a lógica da cena.
-- Incrementa o temporizador e verifica se o carregamento está completo e
-- o tempo mínimo de exibição foi atingido para trocar para a LobbyScene.
-- @param dt (number) Delta time.
function BootloaderScene:update(dt)
    displayTimer = displayTimer + dt

    -- Verifica se o carregamento está completo e o tempo mínimo de exibição passou
    if isLoadingComplete and displayTimer >= minDisplayTime then
        print(string.format(
            "BootloaderScene:update - Carregamento completo e tempo mínimo (%.1fs) atingido. Trocando para LobbyScene",
            minDisplayTime))
        SceneManager.switchScene("lobby_scene")
    end
end

--- Chamado a cada frame para desenhar os elementos da cena.
-- Desenha a logo, o título do jogo e o texto "Loading..." piscante.
function BootloaderScene:draw()
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()

    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setColor(1, 1, 1, 1) -- Reseta para branco

    local logoY = 0                    -- Inicializa para evitar erro se logo não carregar
    local logoDrawH = 0                -- Altura da logo desenhada (para posicionar texto abaixo)
    local logoScale = 0.5              -- Fator de escala (0.5 = 50% do tamanho original). Ajuste conforme necessário!

    -- Desenha a Logo (se carregada)
    if logo then
        local logoW = logo:getWidth()
        local logoH = logo:getHeight()
        -- Calcula as dimensões da logo após aplicar a escala
        local scaledLogoW = logoW * logoScale
        local scaledLogoH = logoH * logoScale
        logoDrawH = scaledLogoH -- Guarda a altura que será efetivamente desenhada

        -- Calcula posição para centralizar a logo *redimensionada*
        local logoX = (w / 2) - (scaledLogoW / 2)
        logoY = (h / 2) - (scaledLogoH / 2) - 30 -- Centraliza um pouco acima do meio

        love.graphics.setColor(1, 1, 1, 1)       -- Cor branca padrão
        -- Desenha a logo com a escala aplicada nos parâmetros 5 e 6
        love.graphics.draw(logo, logoX, logoY, 0, logoScale, logoScale)
    end

    if fonts.title then
        love.graphics.setFont(fonts.title_large)
        -- Posiciona abaixo da logo (considerando a altura desenhada 'logoDrawH')
        local titleY = logoY + logoDrawH + 50 -- Adiciona um padding (15) abaixo da logo redimensionada
        if not logo then titleY = h / 2 end   -- Centraliza se não houver logo
        love.graphics.printf(titleText, 0, titleY, w, "center")
    else                                      -- Fallback caso a fonte do título não tenha sido carregada
        love.graphics.printf(titleText, 0, h / 2 + 50, w, "center")
    end

    -- Desenha o texto "Loading..." com cor animada
    local grayLevel = 0.5          -- Nível de cinza base (0 = preto, 1 = branco)
    local colorSpeed = math.pi * 0.5 -- Velocidade da animação (ciclo completo a cada 1 segundo)

    -- Calcula um valor oscilante entre 0 e 1 usando seno
    local oscillation = (math.sin(displayTimer * colorSpeed) + 1) / 2

    -- Interpola a cor entre cinza (grayLevel) e branco (1)
    local colorComponent = grayLevel + (1 - grayLevel) * oscillation

    -- Define a cor calculada (RGB iguais para escala de cinza) e alfa 1
    love.graphics.setColor(colorComponent, colorComponent, colorComponent, 1)

    -- Define a fonte (se carregada)
    if fonts.title then
        love.graphics.setFont(fonts.title) -- Usa a fonte principal
    end

    -- Calcula posição vertical
    local loadingH = (fonts.title and fonts.main:getHeight()) or 16 -- Altura da fonte ou fallback
    local paddingBottom = 40                                        -- Espaçamento da borda inferior
    local loadingY = h - loadingH - paddingBottom

    -- Desenha o texto
    love.graphics.printf(loadingText, 0, loadingY, w, "center")

    -- Restaura a cor padrão para branco para não afetar outros desenhos (importante!)
    love.graphics.setColor(1, 1, 1, 1)
end

--- Chamado quando a cena está prestes a ser trocada.
-- Poderia ser usado para descarregar recursos específicos desta cena (como a `logo`).
-- function BootloaderScene:unload()
--     print("BootloaderScene:unload")
--     logo = nil -- Exemplo: liberar a referência da imagem
-- end

return BootloaderScene
