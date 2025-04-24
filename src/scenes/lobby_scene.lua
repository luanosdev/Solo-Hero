local SceneManager = require("src.core.scene_manager")
local LobbyScene = {}

-- Configuração do botão
local button = {
    x = 0, -- Centralizado horizontalmente
    y = 0, -- Posicionado abaixo do título
    w = 250,
    h = 60,
    text = "Iniciar Jogo",
    bgColor = { 0.2, 0.6, 0.2 },
    hoverColor = { 0.3, 0.8, 0.3 },
    textColor = { 1, 1, 1 },
    isHovering = false
}

function LobbyScene:load(args)
    print("LobbyScene:load")
    -- Centraliza o botão na tela
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    button.x = (screenW - button.w) / 2
    button.y = screenH / 2 -- Ajuste conforme necessário
end

function LobbyScene:update(dt)
    -- Verifica se o mouse está sobre o botão
    local mx, my = love.mouse.getPosition()
    if mx > button.x and mx < button.x + button.w and my > button.y and my < button.y + button.h then
        button.isHovering = true
    else
        button.isHovering = false
    end
end

function LobbyScene:draw()
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    -- Título da cena
    love.graphics.printf("Lobby Principal", 0, screenH / 4, screenW, "center")

    -- Desenha o botão
    if button.isHovering then
        love.graphics.setColor(button.hoverColor)
    else
        love.graphics.setColor(button.bgColor)
    end
    love.graphics.rectangle("fill", button.x, button.y, button.w, button.h, 5, 5) -- Cantos arredondados

    -- Desenha o texto do botão
    love.graphics.setColor(button.textColor)
    love.graphics.printf(button.text, button.x, button.y + (button.h / 2) - 10, button.w, "center")

    -- Reset color
    love.graphics.setColor(1, 1, 1)
end

function LobbyScene:mousepressed(x, y, buttonIdx, istouch, presses)
    -- Verifica se o clique foi no botão "Iniciar Jogo"
    if buttonIdx == 1 and button.isHovering then
        print("LobbyScene: Botão 'Iniciar Jogo' clicado. Trocando para GameLoadingScene...")
        SceneManager.switchScene("game_loading_scene")
    end
end

return LobbyScene
