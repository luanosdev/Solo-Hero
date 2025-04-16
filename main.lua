-- Main game configuration and initialization
local PlayerManager = require("src.managers.player_manager")
local Camera = require("src.config.camera")
local InputManager = require("src.managers.input_manager")
local EnemyManager = require("src.managers.enemy_manager")
local FloatingText = require("src.entities.floating_text")
local ExperienceOrbManager = require("src.managers.experience_orb_manager")
local AnimationLoader = require("src.animations.animation_loader")
local LevelUpModal = require("src.ui.level_up_modal")
local HUD = require("src.ui.hud")
local fonts = require("src.ui.fonts")

-- Variáveis globais
local camera
local floatingTexts = {}
local groundTexture

function love.load()
    -- Carrega as fontes antes de qualquer uso de UI
    fonts.load()
    -- Window settings - Fullscreen
    love.window.setMode(0, 0, {fullscreen = true})
    
    -- Carrega a textura do terreno
    groundTexture = love.graphics.newImage("assets/ground.png")
    groundTexture:setWrap("repeat", "repeat")
    
    -- Inicializa o player manager
    PlayerManager.init()
    
    -- Inicializa o ExperienceOrbManager
    ExperienceOrbManager:init()
    
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
    
    -- Carrega todas as animações
    AnimationLoader.loadAll()

    -- Inicializa o EnemyManager
    EnemyManager:init("default")
    
    -- Debug info
    print("Jogo iniciado")
    print("Posição inicial do jogador:", PlayerManager.player.x, PlayerManager.player.y)
end

function love.update(dt)
    if LevelUpModal.visible then
        return
    end

    -- Atualiza o input manager
    InputManager.update(dt)
    
    -- Atualiza o player
    PlayerManager.update(dt)
    
    -- Atualiza o EnemyManager
    EnemyManager:update(dt, {
        positionX = PlayerManager.player.x,
        positionY = PlayerManager.player.y,
        radius = PlayerManager.radius
    })
    
    -- Atualiza os orbs de experiência
    ExperienceOrbManager:update(dt)
    
    -- Atualiza os textos flutuantes
    for i = #floatingTexts, 1, -1 do
        if not floatingTexts[i]:update(dt) then
            table.remove(floatingTexts, i)
        end
    end

    -- Atualiza o LevelUpModal
    LevelUpModal:update()
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
    
    -- Desenha os inimigos através do EnemyManager
    EnemyManager:draw()
    
    -- Desenha os orbs de experiência
    ExperienceOrbManager:draw()
    
    -- Desenha os textos flutuantes
    for _, floatingText in ipairs(floatingTexts) do
        floatingText:draw()
    end


    Camera:detach()

    -- Desenha o HUD
    HUD:draw()

    -- Desenha o LevelUpModal acima de tudo
    LevelUpModal:draw()
    
    -- Debug info dos inimigos
    local enemies = EnemyManager:getEnemies()
    if #enemies > 0 then
        love.graphics.setColor(1, 1, 1, 1)
        local screenWidth = love.graphics.getWidth()
        local debugText = string.format(
            "Enemy Info:\nTotal Enemies: %d\nCurrent Cycle: %d\nGame Time: %.1f",
            #enemies,
            EnemyManager.currentCycleIndex,
            EnemyManager.gameTimer
        )

        -- Adiciona informações dos bosses vivos
        local bossCount = 0
        for _, enemy in ipairs(enemies) do
            if enemy.isBoss and enemy.isAlive then
                bossCount = bossCount + 1
                debugText = debugText .. string.format(
                    "\n\nBoss %d: %s\nVida: %.1f\nPosição: (%.1f, %.1f)",
                    bossCount,
                    enemy.name or "(sem nome)",
                    enemy.currentHealth or (enemy.state and enemy.state.currentHealth) or 0,
                    enemy.positionX or 0,
                    enemy.positionY or 0
                )
            end
        end
        love.graphics.print(debugText, screenWidth - 200, 10)
    end
end

-- Draw the isometric grid pattern
function drawIsometricGrid()
    local iso_scale = 0.5  -- Isometric perspective scale
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Calcula o tamanho do chunk baseado no tamanho da tela
    local chunkSize = 32  -- número de células por chunk
    local visibleChunksX = math.ceil(screenWidth / (grid.size/2)) / chunkSize + 4  -- chunks visíveis + buffer
    local visibleChunksY = math.ceil(screenHeight / (grid.size/2 * iso_scale)) / chunkSize + 4
    
    -- Obtém a posição do jogador
    local playerX = PlayerManager.player.x
    local playerY = PlayerManager.player.y
    
    -- Converte a posição do jogador para coordenadas do grid
    local playerGridX = math.floor(playerX / (grid.size/2))
    local playerGridY = math.floor(playerY / (grid.size/2 * iso_scale))
    
    -- Calcula o chunk atual do jogador
    local currentChunkX = math.floor(playerGridX / chunkSize)
    local currentChunkY = math.floor(playerGridY / chunkSize)
    
    -- Define a área de chunks a ser renderizada
    local startChunkX = currentChunkX - math.ceil(visibleChunksX/2)
    local endChunkX = currentChunkX + math.ceil(visibleChunksX/2)
    local startChunkY = currentChunkY - math.ceil(visibleChunksY/2)
    local endChunkY = currentChunkY + math.ceil(visibleChunksY/2)
    
    -- Apply camera transformation
    Camera:attach()
    
    -- Define a cor branca para não afetar a textura
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Renderiza os chunks
    for chunkX = startChunkX, endChunkX do
        for chunkY = startChunkY, endChunkY do
            -- Renderiza as células dentro do chunk
            local startX = chunkX * chunkSize
            local startY = chunkY * chunkSize
            local endX = startX + chunkSize
            local endY = startY + chunkSize
            
            for i = startX, endX do
                for j = startY, endY do
                    -- Calculate grid point positions
                    local x = (i - j) * (grid.size/2)
                    local y = (i + j) * (grid.size/2 * iso_scale)
                    
                    -- Desenha a textura do terreno
                    love.graphics.draw(
                        groundTexture,
                        x - grid.size/2,
                        y - grid.size/2,
                        0,  -- rotação
                        grid.size / groundTexture:getWidth(),  -- escala X
                        grid.size / groundTexture:getHeight()  -- escala Y
                    )
                end
            end
        end
    end
    
    Camera:detach()
end

-- Handle key press events
function love.keypressed(key)
    -- Se o LevelUpModal estiver visível, consome as teclas para navegação
    if LevelUpModal.visible then
        -- Navegação já é tratada no update do modal
        return
    end
    -- Adiciona o handler de teclas do PlayerManager
    PlayerManager.keypressed(key)
    InputManager.keypressed(key)
end

function love.keyreleased(key)
    InputManager.keyreleased(key)
end

function love.mousemoved(x, y, dx, dy)
    -- Se o LevelUpModal estiver visível, passa o evento para ele
    if LevelUpModal.visible then
        LevelUpModal:update() -- Força uma atualização do hover
        return
    end
    InputManager.mousemoved(x, y, dx, dy)
end

function love.mousepressed(x, y, button)
    -- Primeiro, verifica se o LevelUpModal está visível e consome o clique
    if LevelUpModal.visible then
        LevelUpModal:mousepressed(x, y, button)
        return
    end
    InputManager.mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
    InputManager.mousereleased(x, y, button)
end

-- Função para adicionar um novo texto flutuante
function addFloatingText(x, y, text, isCritical, target, customColor)
    local newText = FloatingText:new(x, y, text, isCritical, target, customColor)
    table.insert(floatingTexts, newText)
end
