-- Animated player module for LÖVE2D
local AnimatedPlayer = {}

-- Configuration template
AnimatedPlayer.defaultConfig = {
    x = 0,              -- Position X
    y = 0,              -- Position Y
    scale = 1,          -- Scale factor for the sprite
    speed = 150,        -- Movement speed
    -- Animation settings
    animation = {
        currentFrame = 0,    -- Começa do frame 0
        timer = 0,
        frameTime = 0.1,    -- Time between frames (seconds)
        direction = 'S',    -- Current facing direction (based on mouse)
        state = 'idle',    -- Current animation state (idle, walk_forward, or walk_backward)
        isMovingBackward = false  -- Flag para indicar movimento para trás
    }
}

-- Direções disponíveis e seus ângulos
local directions = {
    N = {dir = "N", angle = "90.0"},      -- Norte
    NE = {dir = "NE", angle = "45.0"},    -- Nordeste
    E = {dir = "E", angle = "0.0"},       -- Leste
    SE = {dir = "SE", angle = "315.0"},   -- Sudeste
    S = {dir = "S", angle = "270.0"},     -- Sul
    SW = {dir = "SW", angle = "225.0"},   -- Sudoeste
    W = {dir = "W", angle = "180.0"},     -- Oeste
    NW = {dir = "NW", angle = "135.0"}    -- Noroeste
}

-- Load resources when the module is required
function AnimatedPlayer.load()
    -- Carrega as imagens para cada direção
    AnimatedPlayer.frames = {
        walk = {},  -- Frames de caminhada
        idle = {}   -- Frames de idle
    }
    
    -- Carrega frames de caminhada
    for dirKey, dirInfo in pairs(directions) do
        AnimatedPlayer.frames.walk[dirKey] = {}
        -- Carrega os frames de 0 a 7 para cada direção
        for i = 0, 7 do
            local path = string.format(
                "assets/characters/warrior/warrior_armed_walk/%s/warrior_armed_walk_%s_%s_%d.png",
                dirInfo.dir, dirInfo.dir, dirInfo.angle, i
            )
            print("Carregando walk: " .. path)
            local success, result = pcall(function()
                return love.graphics.newImage(path)
            end)
            
            if success then
                AnimatedPlayer.frames.walk[dirKey][i] = result
            else
                print("Erro ao carregar walk: " .. path)
                print(result)
            end
        end
        
        -- Carrega frame de idle
        AnimatedPlayer.frames.idle[dirKey] = {}
        local idlePath = string.format(
            "assets/characters/warrior/warrior_armed_idle/%s/warrior_armed_idle_%s_%s_0.png",
            dirInfo.dir, dirInfo.dir, dirInfo.angle
        )
        print("Carregando idle: " .. idlePath)
        local success, result = pcall(function()
            return love.graphics.newImage(idlePath)
        end)
        
        if success then
            AnimatedPlayer.frames.idle[dirKey][0] = result
        else
            print("Erro ao carregar idle: " .. idlePath)
            print(result)
        end
    end
end

-- Helper function to determine direction based on angle
function AnimatedPlayer.getDirectionFromAngle(angle)
    -- Normalize angle to 0-360
    while angle < 0 do
        angle = angle + 360
    end
    while angle >= 360 do
        angle = angle - 360
    end
    
    -- Convert angle to 8-direction system
    if angle >= 337.5 or angle < 22.5 then
        return "E"
    elseif angle >= 22.5 and angle < 67.5 then
        return "SE"
    elseif angle >= 67.5 and angle < 112.5 then
        return "S"
    elseif angle >= 112.5 and angle < 157.5 then
        return "SW"
    elseif angle >= 157.5 and angle < 202.5 then
        return "W"
    elseif angle >= 202.5 and angle < 247.5 then
        return "NW"
    elseif angle >= 247.5 and angle < 292.5 then
        return "N"
    else
        return "NE"
    end
end

-- Helper function to calculate angle difference
function AnimatedPlayer.getAngleDifference(angle1, angle2)
    local diff = (angle1 - angle2) % 360
    if diff > 180 then
        diff = diff - 360
    end
    return math.abs(diff)
end

-- Update animation state
function AnimatedPlayer.update(config, dt, camera)
    local dx, dy = 0, 0
    
    -- Handle movement input
    if love.keyboard.isDown('w') or love.keyboard.isDown('up') then
        dy = -1
    end
    if love.keyboard.isDown('s') or love.keyboard.isDown('down') then
        dy = 1
    end
    if love.keyboard.isDown('a') or love.keyboard.isDown('left') then
        dx = -1
    end
    if love.keyboard.isDown('d') or love.keyboard.isDown('right') then
        dx = 1
    end
    
    -- Normalize diagonal movement
    if dx ~= 0 or dy ~= 0 then
        local length = math.sqrt(dx * dx + dy * dy)
        dx = dx / length
        dy = dy / length
    end
    
    -- Update position
    config.x = config.x + dx * config.speed * dt
    config.y = config.y + dy * config.speed * dt
    
    -- Get mouse position relative to world coordinates
    local mouseX, mouseY = love.mouse.getPosition()
    mouseX = mouseX + camera.x
    mouseY = mouseY + camera.y
    
    -- Calculate angle to mouse
    local angleToMouse = math.atan2(mouseY - config.y, mouseX - config.x)
    angleToMouse = angleToMouse * (180 / math.pi)  -- Convert to degrees
    
    -- Calculate movement angle (if moving)
    local isMoving = dx ~= 0 or dy ~= 0
    if isMoving then
        local moveAngle = math.atan2(dy, dx) * (180 / math.pi)
        
        -- Calculate angle difference between movement and facing direction
        local angleDiff = AnimatedPlayer.getAngleDifference(angleToMouse, moveAngle)
        
        -- If angle difference is greater than 90 degrees, we're moving backward
        config.animation.isMovingBackward = angleDiff > 90
    else
        config.animation.isMovingBackward = false
    end
    
    -- Update direction based on mouse position
    config.animation.direction = AnimatedPlayer.getDirectionFromAngle(angleToMouse)
    
    -- Update animation state based on movement
    if isMoving then
        -- Set animation state based on movement direction
        config.animation.state = 'walk'
        
        -- Update animation frame (reverse frame order if moving backward)
        config.animation.timer = config.animation.timer + dt
        if config.animation.timer >= config.animation.frameTime then
            config.animation.timer = config.animation.timer - config.animation.frameTime
            if config.animation.isMovingBackward then
                -- Andar para trás: frames em ordem reversa
                config.animation.currentFrame = config.animation.currentFrame - 1
                if config.animation.currentFrame < 0 then
                    config.animation.currentFrame = 7
                end
            else
                -- Andar para frente: frames em ordem normal
                config.animation.currentFrame = (config.animation.currentFrame + 1) % 8
            end
        end
    else
        -- Set to idle state
        config.animation.state = 'idle'
        config.animation.currentFrame = 0
        config.animation.timer = 0
    end
end

-- Draw the animated player
function AnimatedPlayer.draw(config)
    love.graphics.push()
    love.graphics.translate(config.x, config.y)
    
    -- Get current frame image based on state
    local frames = AnimatedPlayer.frames[config.animation.state]
    local currentFrame = frames[config.animation.direction][config.animation.currentFrame]
    
    if currentFrame then
        -- Reset color to white (1,1,1,1) before drawing
        love.graphics.setColor(1, 1, 1, 1)
        
        -- Draw the current animation frame
        -- Centraliza horizontalmente e verticalmente
        love.graphics.draw(
            currentFrame,
            -currentFrame:getWidth() * config.scale / 2,   -- Center horizontally
            -currentFrame:getHeight() * config.scale / 2,  -- Center vertically
            0,                   -- No rotation
            config.scale,        -- Scale X
            config.scale         -- Scale Y
        )
        
        -- Debug: indicador de movimento para trás
        if config.animation.isMovingBackward then
            love.graphics.setColor(1, 0, 0, 0.5)
            love.graphics.circle('fill', 0, -20, 5)
        end
    else
        -- Debug: desenha um retângulo se não encontrar a imagem
        love.graphics.setColor(1, 0, 0, 1)
        love.graphics.rectangle('fill', -32, -32, 64, 64)  -- Centralizado
        print("Frame não encontrado: " .. config.animation.state .. " - " .. config.animation.direction .. " - " .. config.animation.currentFrame)
    end
    
    love.graphics.pop()
end

-- Create a new player configuration
function AnimatedPlayer.newConfig(overrides)
    local config = {}
    for k, v in pairs(AnimatedPlayer.defaultConfig) do
        if type(v) == "table" then
            config[k] = {}
            for k2, v2 in pairs(v) do
                config[k][k2] = v2
            end
        else
            config[k] = v
        end
    end
    
    if overrides then
        for k, v in pairs(overrides) do
            if type(v) == "table" then
                for k2, v2 in pairs(v) do
                    config[k][k2] = v2
                end
            else
                config[k] = v
            end
        end
    end
    
    return config
end

return AnimatedPlayer 