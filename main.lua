-- Main game configuration and initialization
local PlayerManager = require("src.managers.player_manager")
local Camera = require("src.config.camera")
local InputManager = require("src.managers.input_manager")
local Skeleton = require("src.classes.enemies.skeleton")

-- Variáveis globais
local camera
local enemy

function love.load()
    -- Window settings - Fullscreen
    love.window.setMode(0, 0, {fullscreen = true})
    
    -- Inicializa o player manager
    PlayerManager.init()
    
    -- Isometric grid configuration
    grid = {
        size = 128,
        rows = 100,
        columns = 100,
        color = {0.3, 0.3, 0.3, 0.2}
    }
    
    -- Inicializa a câmera
    camera = Camera:new()
    camera:init()
    
    -- Carrega os recursos do esqueleto
    require("src.animations.animated_skeleton").load()
    
    -- Cria um esqueleto inimigo em uma posição aleatória fora da tela
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local spawnSide = math.random(1, 4)
    local x, y
    
    if spawnSide == 1 then -- Topo
        x = math.random(0, screenWidth)
        y = -50
    elseif spawnSide == 2 then -- Direita
        x = screenWidth + 50
        y = math.random(0, screenHeight)
    elseif spawnSide == 3 then -- Baixo
        x = math.random(0, screenWidth)
        y = screenHeight + 50
    else -- Esquerda
        x = -50
        y = math.random(0, screenHeight)
    end
    
    -- Cria o esqueleto usando a nova classe
    enemy = Skeleton:new(x, y)
    
    -- Debug info
    print("Jogo iniciado")
    print("Posição inicial do jogador:", PlayerManager.player.x, PlayerManager.player.y)
end

function love.update(dt)
    -- Atualiza o input manager
    InputManager.update(dt)
    
    -- Atualiza o player
    PlayerManager.update(dt)
    
    -- Atualiza o inimigo se ele existir
    if enemy then
        enemy:update(dt, {
            positionX = PlayerManager.player.x,
            positionY = PlayerManager.player.y,
            radius = PlayerManager.radius
        }, {}) -- Passa a posição do jogador e uma lista vazia de inimigos
        
        -- Se o inimigo estiver morto e a animação de morte terminou, remove-o
        if not enemy.isAlive and enemy.sprite.animation.currentFrame >= 7 then
            enemy = nil
            print("Esqueleto removido após animação de morte")
        end
    end
    
    -- Se pressionar espaço, causa dano ao esqueleto (para teste)
    if love.keyboard.isDown('space') and enemy then
        enemy:takeDamage(10)
    end
end

function love.draw()
    -- Clear the screen with a very light background color
    love.graphics.setBackgroundColor(0.95, 0.95, 0.95)
    
    -- Draw the isometric grid
    drawIsometricGrid()
    
    -- Draw player and related elements
    PlayerManager.draw()
    
    -- Aplica transformação da câmera
    Camera:attach()
    
    -- Desenha o inimigo se ele existir
    if enemy then
        enemy:draw()
    end
    
    Camera:detach()
    
    -- Draw HUD
    drawHUD()
    
    -- Debug info do inimigo
    if enemy then
        love.graphics.setColor(0, 0, 0, 1) -- Cor preta
        local screenWidth = love.graphics.getWidth()
        love.graphics.print(string.format(
            "Enemy Info:\nHealth: %d/%d\nPosition: (%.0f, %.0f)\nState: %s\nAlive: %s",
            enemy.currentHealth,
            enemy.maxHealth,
            enemy.positionX,
            enemy.positionY,
            enemy.sprite.animation.state,
            enemy.isAlive and "Yes" or "No"
        ), screenWidth - 200, 10) -- Posiciona no canto direito
    end
end

-- Draw the isometric grid pattern
function drawIsometricGrid()
    local iso_scale = 0.5  -- Isometric perspective scale
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Calculate visible grid area
    -- Aumentamos a área de cálculo para garantir cobertura total
    local cellsX = math.ceil(screenWidth / (grid.size/2)) + 20  -- Mais células horizontais
    local cellsY = math.ceil(screenHeight / (grid.size/2 * iso_scale)) + 20  -- Mais células verticais
    
    local startX = math.floor(Camera.x / (grid.size/2)) - cellsX/2
    local startY = math.floor(Camera.y / (grid.size/2 * iso_scale)) - cellsY/2
    local endX = startX + cellsX
    local endY = startY + cellsY
    
    -- Apply camera transformation
    Camera:attach()
    
    -- Draw the grid with thicker lines
    love.graphics.setLineWidth(2)  -- Linha mais grossa para melhor visibilidade
    
    for i = startX, endX do
        for j = startY, endY do
            -- Calculate grid point positions
            local x = (i - j) * (grid.size/2)
            local y = (i + j) * (grid.size/2 * iso_scale)
            
            -- Draw grid points
            love.graphics.setColor(grid.color[1], grid.color[2], grid.color[3], grid.color[4])
            love.graphics.circle('fill', x, y, 3)
            
            -- Draw horizontal grid lines
            if i > startX then
                love.graphics.line(
                    x, y,
                    x + grid.size/2, y - grid.size/2 * iso_scale
                )
            end
            
            -- Draw vertical grid lines
            if j > startY then
                love.graphics.line(
                    x, y,
                    x - grid.size/2, y - grid.size/2 * iso_scale
                )
            end
        end
    end
    
    -- Reset line width
    love.graphics.setLineWidth(1)
    
    Camera:detach()
end

-- Draw the heads-up display (HUD)
function drawHUD()
    local screenWidth = love.graphics.getWidth()
    
    -- Draw health bar background
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle('fill', screenWidth - 210, 10, 200, 30)
    
    -- Draw health bar fill
    love.graphics.setColor(0.2, 0.9, 0.3)
    love.graphics.rectangle('fill', screenWidth - 208, 12, 196, 26)
    
    -- Draw health percentage
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("100%", screenWidth - 205, 15)
end

-- Handle key press events
function love.keypressed(key)
    -- Adiciona o handler de teclas do PlayerManager
    PlayerManager.keypressed(key)

    InputManager.keypressed(key)
end

function love.keyreleased(key)
    InputManager.keyreleased(key)
end

function love.mousemoved(x, y, dx, dy)
    InputManager.mousemoved(x, y, dx, dy)
end

function love.mousepressed(x, y, button)
    InputManager.mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
    InputManager.mousereleased(x, y, button)
end
