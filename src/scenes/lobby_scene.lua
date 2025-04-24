local SceneManager = require("src.core.scene_manager")
local fonts = require("src.ui.fonts")          -- Adiciona a dependência das fontes
local elements = require("src.ui.ui_elements") -- Adiciona a dependência dos elementos UI
local colors = require("src.ui.colors")        -- Adiciona a dependência das cores

--- Cena principal do Lobby.
-- Exibe uma barra de navegação inferior com opções (tabs).
-- Atualmente é um mock visual, sem funcionalidade real nos botões.
local LobbyScene = {}

-- Configuração dos botões/tabs inferiores
local tabs = {
    { text = "Vendedor",      highlighted = false },
    { text = "Criação",       highlighted = false },
    { text = "Equipamento",   highlighted = false },
    { text = "Portais",       highlighted = true },
    { text = "Personagens",   highlighted = false },
    { text = "Configurações", highlighted = false },
    { text = "Sair",          highlighted = false },
}

local tabSettings = {
    height = 50,
    padding = 10,  -- Espaço entre botões
    yPosition = 0, -- Calculado no load
    -- Define as cores referenciando o módulo colors.lua
    colors = {
        bgColor = colors.tab_bg,                              -- Usa a cor definida em colors.lua
        hoverColor = colors.tab_hover,                        -- Usa a cor definida em colors.lua
        highlightedBgColor = colors.tab_highlighted_bg,       -- Usa a cor definida em colors.lua
        highlightedHoverColor = colors.tab_highlighted_hover, -- Usa a cor definida em colors.lua
        textColor = colors.tab_text,                          -- Usa a cor definida em colors.lua
        borderColor = colors.tab_border                       -- Usa a cor definida em colors.lua
    }
}

--- Chamado quando a cena é carregada.
-- Calcula as dimensões e posições dos tabs inferiores.
-- @param args (table|nil) Argumentos (não usado).
function LobbyScene:load(args)
    print("LobbyScene:load")
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    -- Calcula a posição Y dos tabs (na parte inferior)
    tabSettings.yPosition = screenH - tabSettings.height

    -- Calcula a largura total necessária e a largura de cada tab
    local totalTabs = #tabs
    local totalPadding = (totalTabs + 1) * tabSettings.padding -- Padding nas bordas e entre tabs
    local availableWidth = screenW - totalPadding
    local tabWidth = availableWidth / totalTabs

    -- Calcula a posição X de cada tab
    local currentX = tabSettings.padding
    for i, tab in ipairs(tabs) do
        tab.x = currentX
        tab.y = tabSettings.yPosition
        tab.w = tabWidth
        tab.h = tabSettings.height
        tab.isHovering = false -- Inicializa estado de hover
        currentX = currentX + tabWidth + tabSettings.padding
    end
end

--- Atualiza a lógica da cena.
-- Verifica o estado de hover para cada tab.
-- @param dt (number) Delta time.
function LobbyScene:update(dt)
    local mx, my = love.mouse.getPosition()

    -- Verifica hover para cada tab
    for i, tab in ipairs(tabs) do
        if mx >= tab.x and mx <= tab.x + tab.w and my >= tab.y and my <= tab.y + tab.h then
            tab.isHovering = true
        else
            tab.isHovering = false
        end
    end
end

--- Desenha os elementos da cena.
-- Renderiza a barra de tabs na parte inferior usando ui_elements e cores globais.
function LobbyScene:draw()
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    -- Fundo da cena usando a cor definida em colors.lua
    love.graphics.setColor(colors.lobby_background)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Define a fonte para os tabs (se disponível)
    local tabFont = fonts.main or love.graphics.getFont()

    -- Desenha cada tab usando a função do ui_elements
    for i, tab in ipairs(tabs) do
        elements.drawTabButton({
            x = tab.x,
            y = tab.y,
            w = tab.w,
            h = tab.h,
            text = tab.text,
            isHovering = tab.isHovering,
            highlighted = tab.highlighted,
            font = tabFont,
            colors = tabSettings.colors -- Passa a tabela de cores (que agora referencia colors.lua)
        })
    end

    -- Reset color e fonte (boa prática)
    love.graphics.setColor(colors.white)  -- Usar colors.white aqui também!
    if fonts.main then
        love.graphics.setFont(fonts.main) -- Define uma fonte padrão após o loop
    end
end

--- Processa cliques do mouse.
-- Identifica qual tab foi clicado (sem ação por enquanto).
-- @param x (number) Posição X do clique.
-- @param y (number) Posição Y do clique.
-- @param buttonIdx (number) Índice do botão (1 = esquerdo).
function LobbyScene:mousepressed(x, y, buttonIdx, istouch, presses)
    if buttonIdx == 1 then -- Botão esquerdo
        for i, tab in ipairs(tabs) do
            if tab.isHovering then
                print(string.format("LobbyScene: Tab '%s' clicado!", tab.text))
                -- TODO: Implementar a lógica de abrir a janela/menu correspondente
                -- Exemplo: if tab.text == "Portais" then SceneManager.switchScene("game_loading_scene") end
                break -- Sai do loop assim que encontrar o tab clicado
            end
        end
    end
end

-- Adicionar outras funções de input (keypressed, etc.) se necessário

return LobbyScene
