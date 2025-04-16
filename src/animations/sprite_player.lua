-- Módulo de jogador animado usando sprite sheet
local SpritePlayer = {}

-- Configuração padrão
SpritePlayer.defaultConfig = {
    x = 0,              -- Posição X
    y = 0,              -- Posição Y
    scale = 1,          -- Fator de escala
    speed = 150,        -- Velocidade de movimento
    -- Configurações de animação
    animation = {
        currentFrame = 1,    -- Frame atual
        timer = 0,
        frameTime = {        -- Tempo entre frames para cada estado
            walk = 0.05,     -- Walk mais rápido
            idle = 0.1,      -- Idle mais lento
            attack = 0.03,   -- Attack mais rápido ainda
            attack_walk = 0.03 -- Attack andando
        },
        direction = 'E',     -- Direção atual (baseada no mouse)
        state = 'idle',      -- Estado atual (idle, walk, attack ou attack_walk)
        isMovingBackward = false,  -- Indicador de movimento para trás
        isAttacking = false,       -- Indicador de ataque
        -- Configurações do sprite sheet
        frameWidth = 128,     -- Largura de cada frame
        frameHeight = 128,    -- Altura de cada frame
        frames = {
            walk = {
                E = {row = 1, frames = 15},   -- Direita
                NE = {row = 2, frames = 15},  -- Direita-Cima
                N = {row = 3, frames = 15},   -- Cima
                NW = {row = 4, frames = 15},  -- Esquerda-Cima
                W = {row = 5, frames = 15},   -- Esquerda
                SW = {row = 6, frames = 15},  -- Esquerda-Baixo
                S = {row = 7, frames = 15},   -- Baixo
                SE = {row = 8, frames = 15}   -- Direita-Baixo
            },
            idle = {
                E = {row = 1, frames = 15},   -- Direita
                NE = {row = 2, frames = 15},  -- Direita-Cima
                N = {row = 3, frames = 15},   -- Cima
                NW = {row = 4, frames = 15},  -- Esquerda-Cima
                W = {row = 5, frames = 15},   -- Esquerda
                SW = {row = 6, frames = 15},  -- Esquerda-Baixo
                S = {row = 7, frames = 15},   -- Baixo
                SE = {row = 8, frames = 15}   -- Direita-Baixo
            },
            attack = {
                E = {row = 1, frames = 15},   -- Direita
                NE = {row = 2, frames = 15},  -- Direita-Cima
                N = {row = 3, frames = 15},   -- Cima
                NW = {row = 4, frames = 15},  -- Esquerda-Cima
                W = {row = 5, frames = 15},   -- Esquerda
                SW = {row = 6, frames = 15},  -- Esquerda-Baixo
                S = {row = 7, frames = 15},   -- Baixo
                SE = {row = 8, frames = 15}   -- Direita-Baixo
            },
            attack_walk = {
                E = {row = 1, frames = 15},   -- Direita
                NE = {row = 2, frames = 15},  -- Direita-Cima
                N = {row = 3, frames = 15},   -- Cima
                NW = {row = 4, frames = 15},  -- Esquerda-Cima
                W = {row = 5, frames = 15},   -- Esquerda
                SW = {row = 6, frames = 15},  -- Esquerda-Baixo
                S = {row = 7, frames = 15},   -- Baixo
                SE = {row = 8, frames = 15}   -- Direita-Baixo
            }
        }
    }
}

-- Carrega os recursos
function SpritePlayer.load()
    -- Carrega os sprite sheets
    SpritePlayer.spriteSheets = {}
    SpritePlayer.quads = {
        walk = {},
        idle = {},
        attack = {},
        attack_walk = {}
    }
    
    -- Carrega sprite sheet de caminhada
    local success, walkSheet = pcall(function()
        return love.graphics.newImage("assets/characters/warrior/walk.png")
    end)
    
    if success then
        SpritePlayer.spriteSheets.walk = walkSheet
        -- Cria os quads para cada frame de animação de caminhada
        for direction, info in pairs(SpritePlayer.defaultConfig.animation.frames.walk) do
            SpritePlayer.quads.walk[direction] = {}
            for frame = 1, info.frames do
                local x = (frame - 1) * SpritePlayer.defaultConfig.animation.frameWidth
                local y = (info.row - 1) * SpritePlayer.defaultConfig.animation.frameHeight
                
                SpritePlayer.quads.walk[direction][frame] = love.graphics.newQuad(
                    x, y,
                    SpritePlayer.defaultConfig.animation.frameWidth,
                    SpritePlayer.defaultConfig.animation.frameHeight,
                    walkSheet:getDimensions()
                )
            end
        end
    else
        print("Erro ao carregar sprite sheet de caminhada:", walkSheet)
    end
    
    -- Carrega sprite sheet de idle
    local success, idleSheet = pcall(function()
        return love.graphics.newImage("assets/characters/warrior/idle.png")
    end)
    
    if success then
        SpritePlayer.spriteSheets.idle = idleSheet
        -- Cria os quads para cada frame de animação idle
        for direction, info in pairs(SpritePlayer.defaultConfig.animation.frames.idle) do
            SpritePlayer.quads.idle[direction] = {}
            for frame = 1, info.frames do
                local x = (frame - 1) * SpritePlayer.defaultConfig.animation.frameWidth
                local y = (info.row - 1) * SpritePlayer.defaultConfig.animation.frameHeight
                
                SpritePlayer.quads.idle[direction][frame] = love.graphics.newQuad(
                    x, y,
                    SpritePlayer.defaultConfig.animation.frameWidth,
                    SpritePlayer.defaultConfig.animation.frameHeight,
                    idleSheet:getDimensions()
                )
            end
        end
    else
        print("Erro ao carregar sprite sheet de idle:", idleSheet)
    end

    -- Carrega sprite sheet de ataque
    local success, attackSheet = pcall(function()
        return love.graphics.newImage("assets/characters/warrior/attack.png")
    end)
    
    if success then
        SpritePlayer.spriteSheets.attack = attackSheet
        -- Cria os quads para cada frame de animação de ataque
        for direction, info in pairs(SpritePlayer.defaultConfig.animation.frames.attack) do
            SpritePlayer.quads.attack[direction] = {}
            for frame = 1, info.frames do
                local x = (frame - 1) * SpritePlayer.defaultConfig.animation.frameWidth
                local y = (info.row - 1) * SpritePlayer.defaultConfig.animation.frameHeight
                
                SpritePlayer.quads.attack[direction][frame] = love.graphics.newQuad(
                    x, y,
                    SpritePlayer.defaultConfig.animation.frameWidth,
                    SpritePlayer.defaultConfig.animation.frameHeight,
                    attackSheet:getDimensions()
                )
            end
        end
    else
        print("Erro ao carregar sprite sheet de ataque:", attackSheet)
    end

    -- Carrega sprite sheet de ataque andando
    local success, attackWalkSheet = pcall(function()
        return love.graphics.newImage("assets/characters/warrior/attack_walk.png")
    end)
    
    if success then
        SpritePlayer.spriteSheets.attack_walk = attackWalkSheet
        -- Cria os quads para cada frame de animação de ataque andando
        for direction, info in pairs(SpritePlayer.defaultConfig.animation.frames.attack_walk) do
            SpritePlayer.quads.attack_walk[direction] = {}
            for frame = 1, info.frames do
                local x = (frame - 1) * SpritePlayer.defaultConfig.animation.frameWidth
                local y = (info.row - 1) * SpritePlayer.defaultConfig.animation.frameHeight
                
                SpritePlayer.quads.attack_walk[direction][frame] = love.graphics.newQuad(
                    x, y,
                    SpritePlayer.defaultConfig.animation.frameWidth,
                    SpritePlayer.defaultConfig.animation.frameHeight,
                    attackWalkSheet:getDimensions()
                )
            end
        end
    else
        print("Erro ao carregar sprite sheet de ataque andando:", attackWalkSheet)
    end
end

-- Função auxiliar para determinar direção baseada no ângulo
function SpritePlayer.getDirectionFromAngle(angle)
    -- Normaliza o ângulo para 0-360
    while angle < 0 do
        angle = angle + 360
    end
    while angle >= 360 do
        angle = angle - 360
    end
    
    -- Converte ângulo para sistema de 8 direções
    -- Ajustado para corresponder à ordem do sprite sheet em sentido anti-horário:
    -- Row 1: Direita (E)
    -- Row 2: Direita-Cima (NE)
    -- Row 3: Cima (N)
    -- Row 4: Esquerda-Cima (NW)
    -- Row 5: Esquerda (W)
    -- Row 6: Esquerda-Baixo (SW)
    -- Row 7: Baixo (S)
    -- Row 8: Direita-Baixo (SE)
    if angle >= 337.5 or angle < 22.5 then
        return "E"  -- Direita (row 1)
    elseif angle >= 22.5 and angle < 67.5 then
        return "NE" -- Direita-Cima (row 2)
    elseif angle >= 67.5 and angle < 112.5 then
        return "N"  -- Cima (row 3)
    elseif angle >= 112.5 and angle < 157.5 then
        return "NW" -- Esquerda-Cima (row 4)
    elseif angle >= 157.5 and angle < 202.5 then
        return "W"  -- Esquerda (row 5)
    elseif angle >= 202.5 and angle < 247.5 then
        return "SW" -- Esquerda-Baixo (row 6)
    elseif angle >= 247.5 and angle < 292.5 then
        return "S"  -- Baixo (row 7)
    else
        return "SE" -- Direita-Baixo (row 8)
    end
end

-- Função auxiliar para calcular diferença entre ângulos
function SpritePlayer.getAngleDifference(angle1, angle2)
    local diff = (angle1 - angle2) % 360
    if diff > 180 then
        diff = diff - 360
    end
    return math.abs(diff)
end

-- Atualiza o estado da animação
function SpritePlayer.update(config, dt, camera)
    local dx, dy = 0, 0
    
    -- Processa entrada de movimento
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
    
    -- Normaliza movimento diagonal
    if dx ~= 0 or dy ~= 0 then
        local length = math.sqrt(dx * dx + dy * dy)
        dx = dx / length
        dy = dy / length
    end
    
    -- Atualiza posição
    config.x = config.x + dx * config.speed * dt
    config.y = config.y + dy * config.speed * dt
    
    -- Obtém posição do mouse relativa às coordenadas do mundo
    local mouseX, mouseY = love.mouse.getPosition()
    mouseX = mouseX + camera.x
    mouseY = mouseY + camera.y
    
    -- Calcula ângulo até o mouse
    local angleToMouse = math.atan2(mouseY - config.y, mouseX - config.x)
    angleToMouse = angleToMouse * (180 / math.pi)
    
    -- Calcula ângulo de movimento (se estiver movendo)
    local isMoving = dx ~= 0 or dy ~= 0
    if isMoving then
        local moveAngle = math.atan2(dy, dx) * (180 / math.pi)
        
        -- Calcula diferença de ângulo entre movimento e direção
        local angleDiff = SpritePlayer.getAngleDifference(angleToMouse, moveAngle)
        
        -- Se a diferença for maior que 90 graus, está movendo para trás
        config.animation.isMovingBackward = angleDiff > 90
    else
        config.animation.isMovingBackward = false
    end
    
    -- Atualiza direção baseada na posição do mouse
    config.animation.direction = SpritePlayer.getDirectionFromAngle(angleToMouse)
    
    -- Atualiza estado da animação e frames
    config.animation.timer = config.animation.timer + dt
    local currentFrameTime = config.animation.frameTime[config.animation.state]
    if config.animation.timer >= currentFrameTime then
        config.animation.timer = config.animation.timer - currentFrameTime
        
        -- Se estiver atacando, prioriza a animação de ataque
        if config.animation.isAttacking then
            -- Escolhe entre ataque parado ou em movimento
            config.animation.state = isMoving and 'attack_walk' or 'attack'
            local maxFrames = config.animation.frames[config.animation.state][config.animation.direction].frames
            config.animation.currentFrame = config.animation.currentFrame + 1
            
            -- Se chegou ao último frame do ataque, volta ao estado normal
            if config.animation.currentFrame > maxFrames then
                config.animation.currentFrame = 1
                config.animation.isAttacking = false
            end
        elseif isMoving then
            config.animation.state = 'walk'
            local maxFrames = config.animation.frames.walk[config.animation.direction].frames
            
            if config.animation.isMovingBackward then
                -- Movimento para trás: frames em ordem reversa
                config.animation.currentFrame = config.animation.currentFrame - 1
                if config.animation.currentFrame < 1 then
                    config.animation.currentFrame = maxFrames
                end
            else
                -- Movimento para frente: frames em ordem normal
                config.animation.currentFrame = config.animation.currentFrame + 1
                if config.animation.currentFrame > maxFrames then
                    config.animation.currentFrame = 1
                end
            end
        else
            -- Estado parado (idle)
            config.animation.state = 'idle'
            local maxFrames = config.animation.frames.idle[config.animation.direction].frames
            
            -- Atualiza frame da animação idle (sempre para frente)
            config.animation.currentFrame = config.animation.currentFrame + 1
            if config.animation.currentFrame > maxFrames then
                config.animation.currentFrame = 1
            end
        end
    end
end

-- Desenha o jogador animado
function SpritePlayer.draw(config)
    -- Verifica se o sprite sheet atual existe
    local currentState = config.animation.state
    if not SpritePlayer.spriteSheets[currentState] then return end
    
    love.graphics.push()
    love.graphics.translate(config.x, config.y)
    
    -- Obtém o quad atual
    local currentQuad = SpritePlayer.quads[currentState][config.animation.direction][config.animation.currentFrame]
    
    if currentQuad then
        -- Reseta cor para branco
        love.graphics.setColor(1, 1, 1, 1)
        
        -- Desenha o frame atual
        love.graphics.draw(
            SpritePlayer.spriteSheets[currentState],
            currentQuad,
            -config.animation.frameWidth * config.scale / 2,
            -config.animation.frameHeight * config.scale / 2,
            0,
            config.scale,
            config.scale
        )
    end
    
    love.graphics.pop()
end

-- Cria uma nova configuração de jogador
function SpritePlayer.newConfig(overrides)
    local config = {}
    for k, v in pairs(SpritePlayer.defaultConfig) do
        if type(v) == "table" then
            config[k] = {}
            for k2, v2 in pairs(v) do
                if type(v2) == "table" then
                    config[k][k2] = {}
                    for k3, v3 in pairs(v2) do
                        config[k][k2][k3] = v3
                    end
                else
                    config[k][k2] = v2
                end
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

-- Inicia a animação de ataque
function SpritePlayer.startAttackAnimation(config)
    if not config.animation.isAttacking then
        config.animation.isAttacking = true
        config.animation.currentFrame = 1
        config.animation.state = 'attack'
        config.animation.timer = 0
    end
end

return SpritePlayer 