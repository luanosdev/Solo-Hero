-- Main game configuration and initialization
local Camera = require("src.config.camera")
local AnimationLoader = require("src.animations.animation_loader")
local LevelUpModal = require("src.ui.level_up_modal")
local RuneChoiceModal = require("src.ui.rune_choice_modal")
local HUD = require("src.ui.hud")
local fonts = require("src.ui.fonts")
local elements = require("src.ui.ui_elements")
print("[DEBUG] Antes de require ItemDetailsModal") -- DEBUG
local InventoryScreen = require("src.ui.inventory_screen")
-- print(string.format("[DEBUG] Depois de require InventoryScreen - Tipo: %s", type(InventoryScreen))) -- Removendo print incorreto
local ItemDetailsModal = require("src.ui.item_details_modal")
print(string.format("[DEBUG] Depois de require ItemDetailsModal - Tipo: %s", type(ItemDetailsModal))) -- DEBUG (Corrigido)

-- Importa os managers
local ManagerRegistry = require("src.managers.manager_registry")
local PlayerManager = require("src.managers.player_manager")
local InputManager = require("src.managers.input_manager")
local EnemyManager = require("src.managers.enemy_manager")
local FloatingTextManager = require("src.managers.floating_text_manager")
local ExperienceOrbManager = require("src.managers.experience_orb_manager")
local DropManager = require("src.managers.drop_manager")
local RuneManager = require("src.managers.rune_manager")
local InventoryManager = require("src.managers.inventory_manager")

-- Variáveis globais
local camera
local groundTexture

-- Variável de estado de pausa
local game = { isPaused = false }

function love.load()
    -- Carrega as fontes antes de qualquer uso de UI
    fonts.load()
    
    -- Carrega o shader de brilho (se existir)
    local success, shaderOrErr = pcall(love.graphics.newShader, "assets/shaders/glow.fs")
    if success then
        elements.setGlowShader(shaderOrErr)
        InventoryScreen.setGlowShader(shaderOrErr)
        print("Glow shader loaded.")
    else
        print("Warning: Failed to load glow shader. Glow effects partially disabled.", shaderOrErr)
    end
    
    -- Window settings - Fullscreen
    love.window.setMode(0, 0, {fullscreen = true})
    
    -- Carrega a textura do terreno
    groundTexture = love.graphics.newImage("assets/ground.png")
    groundTexture:setWrap("repeat", "repeat")
    
    -- Registra os managers
    ManagerRegistry:register("playerManager", PlayerManager, false)
    ManagerRegistry:register("inputManager", InputManager, false)
    ManagerRegistry:register("inventoryManager", InventoryManager:new(), false)
    ManagerRegistry:register("enemyManager", EnemyManager, true)
    ManagerRegistry:register("floatingTextManager", FloatingTextManager, true)
    ManagerRegistry:register("experienceOrbManager", ExperienceOrbManager, true)
    ManagerRegistry:register("dropManager", DropManager, true)
    ManagerRegistry:register("runeManager", RuneManager, true)
    
    -- Inicializa todos os managers na ordem correta
    ManagerRegistry:init()
    
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
    
    -- Carrega todas as animações (agora centralizado no AnimationLoader)
    AnimationLoader.loadAll()
    -- Debug info
    print("Jogo iniciado")
    print("Posição inicial do jogador:", PlayerManager.player.position.x, PlayerManager.player.position.y)
end

function love.update(dt)
    -- Permite atualizar a UI do inventário mesmo pausado
    InventoryScreen.update(dt)
    -- Permite atualizar a UI do modal de detalhes mesmo pausado
    ItemDetailsModal:update(dt)

    -- Inclui o ItemDetailsModal na verificação de UI ativa
    local hasActiveModalOrInventory = LevelUpModal.visible or RuneChoiceModal.visible or InventoryScreen.isVisible or ItemDetailsModal.isVisible
    -- Atualiza o InputManager, passando o estado de pausa e se alguma UI está ativa
    InputManager:update(dt, hasActiveModalOrInventory, game.isPaused)

    -- Pula a lógica principal se o jogo está pausado OU se algum modal está visível
    if game.isPaused or hasActiveModalOrInventory then
        -- Permite que os modais (que não pausam o jogo globalmente) se atualizem
        if LevelUpModal.visible then LevelUpModal:update() end
        if RuneChoiceModal.visible then RuneChoiceModal:update() end
        -- ItemDetailsModal já foi atualizado no início
        return
    end

    -- Atualiza todos os managers do jogo
    ManagerRegistry:update(dt)
end

function love.draw()
    -- Clear the screen with a very light background color
    love.graphics.setBackgroundColor(0.95, 0.95, 0.95)
    
    -- Draw the isometric grid
    drawIsometricGrid()
    
    -- Desenha todos os managers
    ManagerRegistry:draw()

    -- Aplica transformação da câmera
    Camera:attach()

    ManagerRegistry:CameraDraw()

    Camera:detach()

    -- Desenha o LevelUpModal acima de tudo
    LevelUpModal:draw()
    
    -- Desenha o RuneChoiceModal acima de tudo
    RuneChoiceModal:draw()

    -- Desenha a tela de inventário (se visível)
    InventoryScreen.draw()

    -- Desenha o ItemDetailsModal (se visível, por cima do inventário)
    ItemDetailsModal:draw()
    
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

    -- Desenha o HUD
    HUD:draw()
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
    local playerX = PlayerManager.player.position.x
    local playerY = PlayerManager.player.position.y
    
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

-- Função para adicionar um novo texto flutuante
function addFloatingText(x, y, text, isCritical, target, customColor)
    FloatingTextManager:addText(x, y, text, isCritical, target, customColor)
end

function love.keypressed(key, scancode, isrepeat)
    print(string.format("[main.lua] love.keypressed START - key: %s", key)) -- DEBUG
    -- Primeiro, trata a tecla TAB para abrir/fechar o inventário e controlar a pausa
    if key == "tab" then
        print("[main.lua] TAB pressionado! Chamando InventoryScreen.toggle()...") -- DEBUG
        game.isPaused = InventoryScreen.toggle() -- Alterna visibilidade E estado de pausa
        print(string.format("[main.lua] Retornou de toggle. isPaused: %s. Retornando de keypressed.", tostring(game.isPaused))) -- DEBUG
        return -- Input tratado aqui
    end

    -- Delega o restante do tratamento de teclas para o InputManager
    print("[main.lua] Delegando tecla para InputManager...") -- DEBUG
    InputManager:keypressed(key, game.isPaused)
    print("[main.lua] Retornou do InputManager:keypressed") -- DEBUG
end

function love.mousepressed(x, y, button, istouch, presses)
    -- Delega o tratamento de cliques para o InputManager
    -- O InputManager agora precisa verificar internamente o ItemDetailsModal
    InputManager:mousepressed(x, y, button, game.isPaused)

    -- OBS: A estrutura do InputManager já verifica Modais e Inventário.
    -- Precisamos ajustar InputManager:mousepressed para incluir ItemDetailsModal na verificação.
end

-- Adiciona funções para keyreleased e mousemoved para delegar também
function love.keyreleased(key, scancode)
    InputManager:keyreleased(key, game.isPaused)
end

function love.mousemoved(x, y, dx, dy, istouch)
    -- Geralmente não precisa de verificação de pausa, mas passamos para consistência
    InputManager:mousemoved(x, y, dx, dy)
end

function love.mousereleased(x, y, button, istouch, presses)
    InputManager:mousereleased(x, y, button, game.isPaused)
end
