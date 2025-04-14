-- Animated skeleton module for LÖVE2D
local AnimatedSkeleton = {}

-- Configuration template
AnimatedSkeleton.defaultConfig = {
    x = 0,              -- Position X
    y = 0,              -- Position Y
    scale = 2,          -- Scale factor for the sprite
    speed = 100,        -- Movement speed
    -- Animation settings
    animation = {
        currentFrame = 0,
        timer = 0,
        frameTime = 0.1,    -- Time between frames (seconds)
        direction = 'S',    -- Current facing direction
        state = 'walk',     -- Current animation state (walk, death)
        isDead = false,     -- Flag para indicar se está morto
        deathFrameTime = 0.15 -- Tempo mais lento para a animação de morte
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
function AnimatedSkeleton.load()
    -- Carrega as imagens para cada direção
    AnimatedSkeleton.frames = {
        walk = {},  -- Frames de caminhada
        death = {} -- Frames de morte
    }
    
    -- Carrega frames de caminhada
    for dirKey, dirInfo in pairs(directions) do
        AnimatedSkeleton.frames.walk[dirKey] = {}
        -- Carrega os frames de 0 a 7 para cada direção
        for i = 0, 7 do
            local path = string.format(
                "assets/enemies/skeleton/walk/%s/skeleton_default_walk_%s_%s_%d.png",
                dirInfo.dir, dirInfo.dir, dirInfo.angle, i
            )
            print("Carregando walk skeleton: " .. path)
            local success, result = pcall(function()
                return love.graphics.newImage(path)
            end)
            
            if success then
                AnimatedSkeleton.frames.walk[dirKey][i] = result
            else
                print("Erro ao carregar walk skeleton: " .. path)
                print(result)
            end
        end
        
        -- Carrega frames de morte
        AnimatedSkeleton.frames.death[dirKey] = {}
        for i = 0, 7 do
            local deathPath = string.format(
                "assets/enemies/skeleton/death/%s/skeleton_special_death_%s_%s_%d.png",
                dirInfo.dir, dirInfo.dir, dirInfo.angle, i
            )
            print("Carregando death skeleton: " .. deathPath)
            local success, result = pcall(function()
                return love.graphics.newImage(deathPath)
            end)
            
            if success then
                AnimatedSkeleton.frames.death[dirKey][i] = result
            else
                print("Erro ao carregar death skeleton: " .. deathPath)
                print(result)
            end
        end
    end
end

-- Helper function to determine direction based on angle
function AnimatedSkeleton.getDirectionFromAngle(angle)
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

-- Update animation state
function AnimatedSkeleton.update(config, dt, targetX, targetY)
    if config.animation.isDead then
        -- Atualiza a animação de morte
        config.animation.state = 'death'
        config.animation.timer = config.animation.timer + dt
        
        -- Usa um tempo de frame diferente para a animação de morte
        local frameTime = config.animation.deathFrameTime
        
        if config.animation.timer >= frameTime then
            config.animation.timer = config.animation.timer - frameTime
            if config.animation.currentFrame < 7 then
                config.animation.currentFrame = config.animation.currentFrame + 1
            end
        end
        return
    end
    
    -- Calcula a direção para o alvo
    local dx = targetX - config.x
    local dy = targetY - config.y
    local angle = math.atan2(dy, dx)
    angle = angle * (180 / math.pi)  -- Converte para graus
    
    -- Atualiza a direção baseada no ângulo para o alvo
    config.animation.direction = AnimatedSkeleton.getDirectionFromAngle(angle)
    
    -- Normaliza o movimento
    local length = math.sqrt(dx * dx + dy * dy)
    if length > 0 then
        dx = dx / length
        dy = dy / length
        
        -- Atualiza a posição
        config.x = config.x + dx * config.speed * dt
        config.y = config.y + dy * config.speed * dt
        
        -- Atualiza a animação de caminhada
        config.animation.timer = config.animation.timer + dt
        if config.animation.timer >= config.animation.frameTime then
            config.animation.timer = config.animation.timer - config.animation.frameTime
            config.animation.currentFrame = (config.animation.currentFrame + 1) % 8
        end
    end
end

-- Draw the animated skeleton
function AnimatedSkeleton.draw(config)
    love.graphics.push()
    love.graphics.translate(config.x, config.y)
    
    -- Get current frame image based on state
    local frames = AnimatedSkeleton.frames[config.animation.state]
    local currentFrame = frames[config.animation.direction][config.animation.currentFrame]
    
    if currentFrame then
        -- Reset color to white (1,1,1,1) before drawing
        love.graphics.setColor(1, 1, 1, 1)
        
        -- Draw the current animation frame
        love.graphics.draw(
            currentFrame,
            -currentFrame:getWidth() * config.scale / 2,   -- Center horizontally
            -currentFrame:getHeight() * config.scale / 2,  -- Center vertically
            0,                   -- No rotation
            config.scale,        -- Scale X
            config.scale         -- Scale Y
        )
    else
        -- Debug: desenha um retângulo se não encontrar a imagem
        love.graphics.setColor(1, 0, 0, 1)
        love.graphics.rectangle('fill', -32, -32, 64, 64)
        print(string.format(
            "Frame não encontrado - Estado: %s, Direção: %s, Frame: %d",
            config.animation.state,
            config.animation.direction,
            config.animation.currentFrame
        ))
    end
    
    love.graphics.pop()
end

-- Create a new skeleton configuration
function AnimatedSkeleton.newConfig(overrides)
    local config = {}
    for k, v in pairs(AnimatedSkeleton.defaultConfig) do
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

-- Inicia a animação de morte
function AnimatedSkeleton.startDeath(config)
    config.animation.isDead = true
    config.animation.state = 'death'
    config.animation.currentFrame = 0
    config.animation.timer = 0
end

return AnimatedSkeleton 