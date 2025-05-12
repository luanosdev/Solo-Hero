-- Módulo de gerenciamento de input do jogador
---@class InputManager
local InputManager = {}
local ManagerRegistry = require("src.managers.manager_registry")
local Camera = require("src.config.camera") -- Adicionado para conversão de coordenadas
-- Adiciona referências às UIs que podem interceptar input
local LevelUpModal = require("src.ui.level_up_modal")
local RuneChoiceModal = require("src.ui.rune_choice_modal")
print("[InputManager Top Level] type(RuneChoiceModal) after require:", type(RuneChoiceModal)) -- DEBUG
local InventoryScreen = require("src.ui.screens.inventory_screen")
local ItemDetailsModal = require("src.ui.item_details_modal") -- Adicionado require direto

-- Estado das teclas
InputManager.keys = {
    moveUp = false,
    moveDown = false,
    moveLeft = false,
    moveRight = false,
    autoAttack = false,
    autoAim = false,
    showAbilityVisual = false,
    enter = false
}

-- Estado do mouse
InputManager.mouse = {
    x = 0,
    y = 0,
    isLeftButtonDown = false,      -- Verdadeiro enquanto o botão esquerdo estiver pressionado
    isRightButtonDown = false,     -- Verdadeiro enquanto o botão direito estiver pressionado
    wasLeftButtonPressed = false,  -- Verdadeiro apenas no frame em que o botão esquerdo foi pressionado
    wasRightButtonPressed = false  -- Verdadeiro apenas no frame em que o botão direito foi pressionado
}

-- REMOVIDO: Referência para o modal de detalhes (será usado diretamente)
-- InputManager.itemDetailsModalInstance = nil

-- Variável local para rastrear se um modal/inventário está ativo
-- Isso é passado pelo main.lua para simplificar
local isUIBlockingInput = false

-- Inicializa o InputManager
function InputManager:init()
    -- REMOVIDO: Bloco que tentava obter a instância via require('main')
    print("InputManager inicializado.")
end

-- Atualiza o estado do input
function InputManager:update(dt, hasActiveModalOrInventory, isGamePaused)
    -- Atualiza o estado de bloqueio da UI
    isUIBlockingInput = hasActiveModalOrInventory or isGamePaused

    -- Reseta os estados de pressionamento do mouse (eventos de frame único)
    self.mouse.wasLeftButtonPressed = false
    self.mouse.wasRightButtonPressed = false

    -- Atualiza estado das teclas de movimento
    self.keys.moveUp = love.keyboard.isDown("w") or love.keyboard.isDown("up")
    self.keys.moveDown = love.keyboard.isDown("s") or love.keyboard.isDown("down")
    self.keys.moveLeft = love.keyboard.isDown("a") or love.keyboard.isDown("left")
    self.keys.moveRight = love.keyboard.isDown("d") or love.keyboard.isDown("right")

    -- Não processa movimento se a UI estiver bloqueando
    if isUIBlockingInput then return end

    local playerManager = ManagerRegistry:get("playerManager") ---@type PlayerManager

    -- Executa movimento se houver input
    if self.keys.moveUp or self.keys.moveDown or self.keys.moveLeft or self.keys.moveRight then
        local moveX, moveY = 0, 0
        if self.keys.moveUp then moveY = moveY - 1 end
        if self.keys.moveDown then moveY = moveY + 1 end
        if self.keys.moveLeft then moveX = moveX - 1 end
        if self.keys.moveRight then moveX = moveX + 1 end

        if moveX ~= 0 or moveY ~= 0 then
            local length = math.sqrt(moveX * moveX + moveY * moveY)
            moveX = moveX / length
            moveY = moveY / length
        end

        if playerManager and playerManager.player then
            local finalStats = playerManager:getCurrentFinalStats()
            local newX = playerManager.player.position.x + moveX * finalStats.moveSpeed * dt
            local newY = playerManager.player.position.y + moveY * finalStats.moveSpeed * dt

            playerManager.player.position.x = newX
            playerManager.player.position.y = newY
        end
    end
end

-- Manipulador de teclas pressionadas
function InputManager:keypressed(key, isGamePaused) -- Recebe o estado de pausa
    -- 1. Verifica se as UIs visíveis querem tratar a tecla (usa ItemDetailsModal direto)
    if ItemDetailsModal.isVisible and ItemDetailsModal:keypressed(key) then return true end
    if InventoryScreen.isVisible and InventoryScreen.keypressed(key) then return true end
    if LevelUpModal.visible and LevelUpModal:keypressed(key) then return true end
    if RuneChoiceModal.visible and RuneChoiceModal:keypressed(key) then return true end

    -- 2. Verifica teclas globais (não afetadas pela pausa ou modais)
    if key == "escape" then
        love.event.quit()
        return true -- Input tratado
    end
    if key == "f11" then
        -- Toggle fullscreen
        local fullscreen = love.window.getFullscreen()
        if fullscreen then
            love.window.setMode(800, 600, {fullscreen = false})
        else
            love.window.setMode(0, 0, {fullscreen = true})
        end
        return true -- Input tratado
    end
    -- A tecla 'tab' é tratada em main.lua para gerenciar a pausa

    -- 3. Se o jogo está pausado ou UI bloqueando, não processa mais nada
    if isGamePaused or isUIBlockingInput then return false end

    -- 4. Processa input do jogo (só executa se não pausado e nenhuma UI bloqueando)
    local playerManager = ManagerRegistry:get("playerManager") ---@type PlayerManager

    -- Verifica se é uma tecla de movimento (atualiza estado interno)
    if key == "w" or key == "up" then
        self.keys.moveUp = true
    elseif key == "s" or key == "down" then
        self.keys.moveDown = true
    elseif key == "a" or key == "left" then
        self.keys.moveLeft = true
    elseif key == "d" or key == "right" then
        self.keys.moveRight = true
    end
    
    if key == "return" then
        self.keys[key] = true
    end

    -- Verifica se é uma tecla de debug
    if key == "f3" then
        self.keys[key] = true
    end
    
    -- Ações específicas do jogador (só se playerManager existir)
    if playerManager then
        if key == "x" then playerManager:toggleAbilityAutoAttack() end
        if key == "z" then playerManager:toggleAutoAim() end
        if key == "v" then playerManager:toggleAttackPreview() end
    end

    return false -- Indica que o input não foi exclusivamente tratado por um modal/inventário
end

-- Manipulador de movimento do mouse
function InputManager:mousemoved(x, y, dx, dy)
    -- Atualiza a posição do mouse
    self.mouse.x = x
    self.mouse.y = y
end

-- Manipulador de clique do mouse
function InputManager:mousepressed(x, y, button, isGamePaused) -- Recebe estado de pausa
    print("InputManager:mousepressed - type(LevelUpModal):", type(LevelUpModal)) -- DEBUG
    -- 1. Verifica se as UIs visíveis querem tratar o clique (usa ItemDetailsModal direto)
    if ItemDetailsModal.isVisible and ItemDetailsModal:mousepressed(x, y, button) then return true end
    if InventoryScreen.isVisible and InventoryScreen.mousepressed(x, y, button) then return true end
    if LevelUpModal.visible and LevelUpModal:mousepressed(x, y, button) then return true end
    if RuneChoiceModal.visible and RuneChoiceModal:mousepressed(x, y, button) then return true end

    -- 2. Se o jogo está pausado ou UI bloqueando, não processa mais nada
    if isGamePaused or isUIBlockingInput then return false end

    -- 3. Processa cliques do jogo
    local playerManager = ManagerRegistry:get("playerManager")
    if button == 1 then -- Botão esquerdo
        self.mouse.isLeftButtonDown = true       -- Define o estado 'segurado' como verdadeiro
        self.mouse.wasLeftButtonPressed = true -- Define o evento 'pressionado' como verdadeiro para este frame
        if playerManager then
            playerManager:leftMouseClicked(x, y)
        end
    elseif button == 2 then -- Botão direito
        self.mouse.isRightButtonDown = true
        self.mouse.wasRightButtonPressed = true
    end

    return false -- Indica que o input não foi exclusivamente tratado por um modal/inventário
end

-- Manipulador do fim do clique do mouse
function InputManager:mousereleased(x, y, button, isGamePaused) -- Recebe estado de pausa
    -- 1. Verifica se as UIs visíveis querem tratar a liberação (usa ItemDetailsModal direto)
    if ItemDetailsModal.isVisible and ItemDetailsModal:mousereleased(x, y, button) then return true end
    -- if InventoryScreen.isVisible and InventoryScreen.mousereleased(x, y, button) then return true end
    -- if LevelUpModal.visible and LevelUpModal:mousereleased(x, y, button) then return true end

    -- 2. Se o jogo está pausado ou UI bloqueando, não processa mais nada
    if isGamePaused or isUIBlockingInput then return false end

    -- 3. Processa liberação de clique do jogo
    local playerManager = ManagerRegistry:get("playerManager")
    if button == 1 then -- Botão esquerdo
        self.mouse.isLeftButtonDown = false -- Define o estado 'segurado' como falso
        if playerManager then
            playerManager:leftMouseReleased(x, y)
        end
    elseif button == 2 then -- Botão direito
        self.mouse.isRightButtonDown = false
    end

    return false -- Indica que o input não foi exclusivamente tratado por um modal/inventário
end

function InputManager:keyreleased(key, isGamePaused) -- Recebe estado de pausa
    -- Não precisa verificar modais aqui, pois eles geralmente não se importam com keyreleased

    -- Se o jogo está pausado, não processa
    if isGamePaused or isUIBlockingInput then return end

    -- Processa liberação de teclas do jogo
    -- Verifica se é uma tecla de movimento
    if key == "w" or key == "up" then
        self.keys.moveUp = false
    elseif key == "s" or key == "down" then
        self.keys.moveDown = false
    elseif key == "a" or key == "left" then
        self.keys.moveLeft = false
    elseif key == "d" or key == "right" then
        self.keys.moveRight = false
    end
end

function InputManager:isKeyPressed(key)
    return self.keys[key] and self.keys[key].pressed
end

function InputManager:isKeyDown(key)
    return self.keys[key] and self.keys[key].down
end

-- Adiciona uma propriedade position para facilitar o acesso à posição do mouse na TELA
function InputManager:getMousePosition()
    return self.mouse.x, self.mouse.y
end

--[[-
    Retorna a posição atual do mouse em coordenadas do MUNDO.
    Utiliza a câmera para fazer a conversão.
    @return table: Uma tabela {x, y} com as coordenadas do mundo.
]]
function InputManager:getMouseWorldPosition()
    local screenX, screenY = self:getMousePosition()
    -- Usa a instância da câmera para converter
    local worldX, worldY = Camera:screenToWorld(screenX, screenY)
    return { x = worldX, y = worldY }
end

-- Atualiza a propriedade position para usar a função getMousePosition
-- InputManager.mouse.position = InputManager.getMousePosition -- Remover/Comentar: pode causar confusão entre tela/mundo

-- Retorna a tabela do módulo para que possa ser usada com require
return InputManager 