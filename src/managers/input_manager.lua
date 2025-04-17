-- Módulo de gerenciamento de input do jogador
local InputManager = {}

-- Estado das teclas
InputManager.keys = {
    moveUp = false,
    moveDown = false,
    moveLeft = false,
    moveRight = false,
    autoAttack = false,
    autoAim = false,
    showAbilityVisual = false
}

-- Estado do mouse
InputManager.mouse = {
    x = 0,
    y = 0,
    leftButton = false,
    rightButton = false,
    leftButtonPressed = false,
    rightButtonPressed = false
}

-- Referência para o PlayerManager
InputManager.playerManager = nil

-- Inicializa o InputManager
function InputManager.init(playerManager)
    InputManager.playerManager = playerManager
    print("InputManager inicializado")
end

-- Atualiza o estado do input
function InputManager.update(dt)
    -- Reseta os estados de pressionamento do mouse
    InputManager.mouse.leftButtonPressed = false
    InputManager.mouse.rightButtonPressed = false
    
    -- Atualiza estado das teclas de movimento
    InputManager.keys.moveUp = love.keyboard.isDown("w") or love.keyboard.isDown("up")
    InputManager.keys.moveDown = love.keyboard.isDown("s") or love.keyboard.isDown("down")
    InputManager.keys.moveLeft = love.keyboard.isDown("a") or love.keyboard.isDown("left")
    InputManager.keys.moveRight = love.keyboard.isDown("d") or love.keyboard.isDown("right")
    
    -- Executa movimento se houver input
    if InputManager.keys.moveUp or InputManager.keys.moveDown or InputManager.keys.moveLeft or InputManager.keys.moveRight then
        local moveX, moveY = 0, 0
        if InputManager.keys.moveUp then moveY = moveY - 1 end
        if InputManager.keys.moveDown then moveY = moveY + 1 end
        if InputManager.keys.moveLeft then moveX = moveX - 1 end
        if InputManager.keys.moveRight then moveX = moveX + 1 end
        
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
function InputManager.keypressed(key)
    -- Verifica se é uma tecla de movimento
    if key == "w" or key == "up" then
        InputManager.keys.moveUp = true
    elseif key == "s" or key == "down" then
        InputManager.keys.moveDown = true
    elseif key == "a" or key == "left" then
        InputManager.keys.moveLeft = true
    elseif key == "d" or key == "right" then
        InputManager.keys.moveRight = true
    end
    
    -- Verifica se é uma tecla de debug
    if key == "f3" then
        InputManager.keys[key] = true
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
    if key == "x" and InputManager.playerManager then
        InputManager.playerManager.toggleAbilityAutoCast()
    elseif key == "z" and InputManager.playerManager then
        InputManager.playerManager.toggleAutoAim()
    elseif key == "v" and InputManager.playerManager then
        InputManager.playerManager.toggleAbilityVisual()
    elseif key == "h" and InputManager.playerManager then
        InputManager.playerManager.heal(20)
    elseif key == "g" and InputManager.playerManager then
        InputManager.playerManager.takeDamage(30)
    end
end

-- Manipulador de movimento do mouse
function InputManager.mousemoved(x, y, dx, dy)
    -- Atualiza a posição do mouse
    InputManager.mouse.x = x
    InputManager.mouse.y = y
end

-- Manipulador de clique do mouse
function InputManager.mousepressed(x, y, button)
    if button == 1 then -- Botão esquerdo
        InputManager.mouse.leftButton = true
        InputManager.mouse.leftButtonPressed = true
        if InputManager.playerManager then
            InputManager.playerManager.leftMouseClicked(x, y)
        end
    elseif button == 2 then -- Botão direito
        InputManager.mouse.rightButton = true
        InputManager.mouse.rightButtonPressed = true
    end
end

-- Manipulador do fim do clique do mouse
function InputManager.mousereleased(x, y, button)
    if button == 1 then -- Botão esquerdo
        InputManager.mouse.leftButton = false
        if InputManager.playerManager then
            InputManager.playerManager.leftMouseReleased(x, y)
        end
    elseif button == 2 then -- Botão direito
        InputManager.mouse.rightButton = false
    end
end

function InputManager.keyreleased(key)
    -- Verifica se é uma tecla de movimento
    if key == "w" or key == "up" then
        InputManager.keys.moveUp = false
    elseif key == "s" or key == "down" then
        InputManager.keys.moveDown = false
    elseif key == "a" or key == "left" then
        InputManager.keys.moveLeft = false
    elseif key == "d" or key == "right" then
        InputManager.keys.moveRight = false
    end
end

function InputManager.isKeyPressed(key)
    return InputManager.keys[key] and InputManager.keys[key].pressed
end

function InputManager.isKeyDown(key)
    return InputManager.keys[key] and InputManager.keys[key].down
end

-- Adiciona uma propriedade position para facilitar o acesso à posição do mouse
function InputManager.getMousePosition()
    return InputManager.mouse.x, InputManager.mouse.y
end

-- Atualiza a propriedade position para usar a função getMousePosition
InputManager.mouse.position = InputManager.getMousePosition

return InputManager 