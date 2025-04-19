-- Módulo de gerenciamento de input do jogador
local InputManager = {}
local ManagerRegistry = require("src.managers.manager_registry")

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

-- Referência para o PlayerManager
InputManager.playerManager = nil

-- Inicializa o InputManager
function InputManager:init()
    self.playerManager = ManagerRegistry:get("playerManager")
    self:registerCallbacks()
end

-- Registra os callbacks do LÖVE
function InputManager:registerCallbacks()
    love.keypressed = function(key) self:keypressed(key) end
    love.keyreleased = function(key) self:keyreleased(key) end
    love.mousemoved = function(x, y, dx, dy) self:mousemoved(x, y, dx, dy) end
    love.mousepressed = function(x, y, button) self:mousepressed(x, y, button) end
    love.mousereleased = function(x, y, button) self:mousereleased(x, y, button) end
end

-- Atualiza o estado do input
function InputManager:update(dt, hasActiveModal)
    if hasActiveModal then
        return
    end

    -- Reseta os estados de pressionamento do mouse (eventos de frame único)
    self.mouse.wasLeftButtonPressed = false
    self.mouse.wasRightButtonPressed = false
    
    -- Atualiza estado das teclas de movimento
    self.keys.moveUp = love.keyboard.isDown("w") or love.keyboard.isDown("up")
    self.keys.moveDown = love.keyboard.isDown("s") or love.keyboard.isDown("down")
    self.keys.moveLeft = love.keyboard.isDown("a") or love.keyboard.isDown("left")
    self.keys.moveRight = love.keyboard.isDown("d") or love.keyboard.isDown("right")
    
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
        
        if InputManager.playerManager and InputManager.playerManager.player then
            local newX = InputManager.playerManager.player.position.x + moveX * InputManager.playerManager.state:getTotalSpeed() * dt
            local newY = InputManager.playerManager.player.position.y + moveY * InputManager.playerManager.state:getTotalSpeed() * dt
            
            InputManager.playerManager.player.position.x = newX
            InputManager.playerManager.player.position.y = newY
        end
    end
end

-- Manipulador de teclas pressionadas
function InputManager:keypressed(key)
    -- Verifica se é uma tecla de movimento
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
    
    -- Verifica se é uma tecla de sistema
    if key == "escape" then
        love.event.quit()
    end
    if key == "f11" then
        -- Toggle fullscreen
        local fullscreen = love.window.getFullscreen()
        if fullscreen then
            love.window.setMode(800, 600, {fullscreen = false})
        else
            love.window.setMode(0, 0, {fullscreen = true})
        end
    end

    -- Ações específicas
    if key == "x" and self.playerManager then
        self.playerManager:toggleAbilityAutoCast()
    elseif key == "z" and self.playerManager then
        self.playerManager:toggleAutoAim()
    elseif key == "v" and self.playerManager then
        self.playerManager:toggleAbilityVisual()
    elseif key == "h" and self.playerManager then
        self.playerManager:heal(20)
    elseif key == "g" and self.playerManager then
        self.playerManager:takeDamage(30)
    end

    -- Tests
    if key == "f1" then
        self.playerManager:levelUp()
    end

    if key >= "1" and key <= "9" then
        local index = tonumber(key)
        self.playerManager:switchWeapon(index)
    end
end

-- Manipulador de movimento do mouse
function InputManager:mousemoved(x, y, dx, dy)
    -- Atualiza a posição do mouse
    self.mouse.x = x
    self.mouse.y = y
end

-- Manipulador de clique do mouse
function InputManager:mousepressed(x, y, button)
    if button == 1 then -- Botão esquerdo
        self.mouse.isLeftButtonDown = true       -- Define o estado 'segurado' como verdadeiro
        self.mouse.wasLeftButtonPressed = true -- Define o evento 'pressionado' como verdadeiro para este frame
        if self.playerManager then
            self.playerManager:leftMouseClicked(x, y)
        end
    elseif button == 2 then -- Botão direito
        self.mouse.isRightButtonDown = true
        self.mouse.wasRightButtonPressed = true
    end
end

-- Manipulador do fim do clique do mouse
function InputManager:mousereleased(x, y, button)
    if button == 1 then -- Botão esquerdo
        self.mouse.isLeftButtonDown = false -- Define o estado 'segurado' como falso
        if self.playerManager then
            self.playerManager:leftMouseReleased(x, y)
        end
    elseif button == 2 then -- Botão direito
        self.mouse.isRightButtonDown = false
    end
end

function InputManager:keyreleased(key)
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

-- Adiciona uma propriedade position para facilitar o acesso à posição do mouse
function InputManager:getMousePosition()
    return self.mouse.x, self.mouse.y
end

-- Atualiza a propriedade position para usar a função getMousePosition
InputManager.mouse.position = InputManager.getMousePosition

return InputManager 