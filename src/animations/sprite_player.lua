-- Módulo de jogador animado usando sprite sheet
local SpritePlayer = {}

-- Configuração padrão
SpritePlayer.defaultConfig = {
    position = {
        x = 0,   -- Posição X
        y = 0,   -- Posição Y
    },
    scale = 1,   -- Fator de escala
    speed = 150, -- Velocidade de movimento
    -- Configurações de animação
    animation = {
        currentFrame = 1,         -- Frame atual
        timer = 0,
        frameTime = {             -- Tempo entre frames para cada estado
            walk = 0.05,          -- Walk mais rápido
            idle = 0.1,           -- Idle mais lento
            attack = 0.03,        -- Attack mais rápido ainda
            attack_walk = 0.03    -- Attack andando
        },
        direction = 'E',          -- Direção atual (baseada no mouse)
        state = 'idle',           -- Estado atual (idle, walk, attack ou attack_walk)
        isMovingBackward = false, -- Indicador de movimento para trás
        isAttacking = false,      -- Indicador de ataque
        -- Configurações do sprite sheet
        frameWidth = 128,         -- Largura de cada frame
        frameHeight = 128,        -- Altura de cada frame
        frames = {
            walk = {
                E = { row = 1, frames = 15 },  -- Direita
                NE = { row = 2, frames = 15 }, -- Direita-Cima
                N = { row = 3, frames = 15 },  -- Cima
                NW = { row = 4, frames = 15 }, -- Esquerda-Cima
                W = { row = 5, frames = 15 },  -- Esquerda
                SW = { row = 6, frames = 15 }, -- Esquerda-Baixo
                S = { row = 7, frames = 15 },  -- Baixo
                SE = { row = 8, frames = 15 }  -- Direita-Baixo
            },
            idle = {
                E = { row = 1, frames = 15 },  -- Direita
                NE = { row = 2, frames = 15 }, -- Direita-Cima
                N = { row = 3, frames = 15 },  -- Cima
                NW = { row = 4, frames = 15 }, -- Esquerda-Cima
                W = { row = 5, frames = 15 },  -- Esquerda
                SW = { row = 6, frames = 15 }, -- Esquerda-Baixo
                S = { row = 7, frames = 15 },  -- Baixo
                SE = { row = 8, frames = 15 }  -- Direita-Baixo
            },
            attack = {
                E = { row = 1, frames = 15 },  -- Direita
                NE = { row = 2, frames = 15 }, -- Direita-Cima
                N = { row = 3, frames = 15 },  -- Cima
                NW = { row = 4, frames = 15 }, -- Esquerda-Cima
                W = { row = 5, frames = 15 },  -- Esquerda
                SW = { row = 6, frames = 15 }, -- Esquerda-Baixo
                S = { row = 7, frames = 15 },  -- Baixo
                SE = { row = 8, frames = 15 }  -- Direita-Baixo
            },
            attack_walk = {
                E = { row = 1, frames = 15 },  -- Direita
                NE = { row = 2, frames = 15 }, -- Direita-Cima
                N = { row = 3, frames = 15 },  -- Cima
                NW = { row = 4, frames = 15 }, -- Esquerda-Cima
                W = { row = 5, frames = 15 },  -- Esquerda
                SW = { row = 6, frames = 15 }, -- Esquerda-Baixo
                S = { row = 7, frames = 15 },  -- Baixo
                SE = { row = 8, frames = 15 }  -- Direita-Baixo
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
    -- Normaliza o ângulo para 0 a 2pi
    angle = angle % (2 * math.pi)
    if angle < 0 then
        angle = angle + 2 * math.pi
    end

    -- Converte radianos para graus (0-360)
    local degrees = math.deg(angle)

    -- Define as fatias para 8 direções
    local slice = 360 / 8 -- 45 graus por fatia

    if degrees >= (slice * 7.5) or degrees < (slice * 0.5) then
        return "E"
    elseif degrees >= (slice * 0.5) and degrees < (slice * 1.5) then
        return "NE"
    elseif degrees >= (slice * 1.5) and degrees < (slice * 2.5) then
        return "N"
    elseif degrees >= (slice * 2.5) and degrees < (slice * 3.5) then
        return "NW"
    elseif degrees >= (slice * 3.5) and degrees < (slice * 4.5) then
        return "W"
    elseif degrees >= (slice * 4.5) and degrees < (slice * 5.5) then
        return "SW"
    elseif degrees >= (slice * 5.5) and degrees < (slice * 6.5) then
        return "S"
    else -- degrees >= (slice * 6.5) and degrees < (slice * 7.5)
        return "SE"
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
function SpritePlayer.update(config, dt, targetPosition)
    local dx, dy = 0, 0
    local isMoving = false -- Flag para indicar se houve input de movimento

    -- Processa entrada de movimento
    if love.keyboard.isDown('w') or love.keyboard.isDown('up') then
        dy = -1
        isMoving = true
    end
    if love.keyboard.isDown('s') or love.keyboard.isDown('down') then
        dy = dy + 1                      -- Usa += para permitir cancelamento (W+S = 0)
        isMoving = isMoving or (dy ~= 0) -- Atualiza flag se houve mudança
    end
    if love.keyboard.isDown('a') or love.keyboard.isDown('left') then
        dx = -1
        isMoving = true
    end
    if love.keyboard.isDown('d') or love.keyboard.isDown('right') then
        dx = dx + 1                      -- Usa += para permitir cancelamento (A+D = 0)
        isMoving = isMoving or (dx ~= 0) -- Atualiza flag se houve mudança
    end

    -- <<< INÍCIO: Lógica de Direção com Histerese >>>
    local currentDirection = config.animation.direction
    local targetDx = targetPosition.x - config.position.x
    local targetDy = targetPosition.y - config.position.y

    -- Evita erro com atan2(0,0) e adiciona zona morta MÍNIMA
    if math.abs(targetDx) > 1 or math.abs(targetDy) > 1 then
        local targetAngle = math.atan2(targetDy, targetDx)
        local newDirection = SpritePlayer.getDirectionFromAngle(targetAngle)

        -- Lógica de Histerese: Só muda de direção se a nova for diferente
        -- E se o ângulo estiver um pouco além da fronteira.
        if newDirection ~= currentDirection then
            local angleDegrees = math.deg(targetAngle)
            if angleDegrees < 0 then angleDegrees = angleDegrees + 360 end

            local threshold = 10 -- Graus de tolerância para mudar
            local lowerBound, upperBound = SpritePlayer.getAngleBoundsForDirection(newDirection, threshold)

            -- Verifica se o ângulo está dentro dos limites da NOVA direção (com tolerância)
            local changeDirection = false
            if lowerBound > upperBound then -- Caso que cruza 0/360 graus (Direção E)
                if angleDegrees >= lowerBound or angleDegrees < upperBound then
                    changeDirection = true
                end
            else -- Caso normal
                if angleDegrees >= lowerBound and angleDegrees < upperBound then
                    changeDirection = true
                end
            end

            if changeDirection then
                config.animation.direction = newDirection
                -- Reinicia animação ao mudar de direção para evitar frames estranhos
                config.animation.currentFrame = 1
                config.animation.timer = 0
            end
        end
    end
    -- <<< FIM: Lógica de Direção com Histerese >>>

    -- Calcula o deslocamento
    local moveX = dx * config.speed * dt
    local moveY = dy * config.speed * dt

    -- Atualiza a posição
    config.position.x = config.position.x + moveX
    config.position.y = config.position.y + moveY

    -- Define o estado da animação
    local newState
    if config.animation.isAttacking then
        newState = isMoving and 'attack_walk' or 'attack'
    else
        newState = isMoving and 'walk' or 'idle'
    end

    -- Reseta a animação se o estado mudou
    if newState ~= config.animation.state then
        config.animation.state = newState
        config.animation.currentFrame = 1
        config.animation.timer = 0
    end

    -- Atualiza o timer da animação
    config.animation.timer = config.animation.timer + dt
    local frameTime = config.animation.frameTime[config.animation.state]

    -- Avança o frame se o tempo passou
    if config.animation.timer >= frameTime then
        config.animation.timer = config.animation.timer - frameTime
        local animInfo = config.animation.frames[config.animation.state][config.animation.direction]
        config.animation.currentFrame = (config.animation.currentFrame % animInfo.frames) + 1
    end

    -- Debug (opcional)
    -- if isMoving then
    --     print(string.format("SpritePlayer Update: Input detected dx=%d, dy=%d", dx*magnitude, dy*magnitude)) -- Mostra input original
    --     print(string.format("  -> Calculated move: mx=%.2f, my=%.2f (Speed=%.1f, dt=%.4f)", moveX, moveY, config.speed, dt))
    --     print(string.format("  -> New Position: x=%.1f, y=%.1f", config.position.x, config.position.y))
    -- end
end

--[[ Função Auxiliar para Histerese: Retorna os limites de ângulo (em graus) para uma direção, COM TOLERÂNCIA ]]
function SpritePlayer.getAngleBoundsForDirection(direction, threshold)
    local slice = 45 -- 360 / 8
    local centerAngle

    if direction == "E" then
        centerAngle = 0
    elseif direction == "NE" then
        centerAngle = slice * 1
    elseif direction == "N" then
        centerAngle = slice * 2
    elseif direction == "NW" then
        centerAngle = slice * 3
    elseif direction == "W" then
        centerAngle = slice * 4
    elseif direction == "SW" then
        centerAngle = slice * 5
    elseif direction == "S" then
        centerAngle = slice * 6
    elseif direction == "SE" then
        centerAngle = slice * 7
    else
        centerAngle = 0 -- Fallback
    end

    -- Calcula os limites exatos da fatia
    local lowerExact = centerAngle - slice / 2
    local upperExact = centerAngle + slice / 2

    -- Aplica a tolerância (threshold) para "apertar" os limites
    local lowerBound = (lowerExact + threshold) % 360
    local upperBound = (upperExact - threshold) % 360

    -- Ajusta para ângulos negativos que podem surgir do modulo
    if lowerBound < 0 then lowerBound = lowerBound + 360 end
    if upperBound < 0 then upperBound = upperBound + 360 end

    -- Garante que upperBound seja "maior" que lowerBound, mesmo cruzando 0/360
    -- Ex: Para E (centro 0), limites exatos -22.5 a 22.5.
    -- Com threshold 10: limites com tolerância ficam -12.5 a 12.5.
    -- Em graus 0-360: lowerBound=347.5, upperBound=12.5
    -- Neste caso específico, a verificação precisa ser OR (>= lower OU < upper)

    return lowerBound, upperBound
end

-- Desenha o jogador animado
function SpritePlayer.draw(config)
    -- Verifica se o sprite sheet atual existe
    local currentState = config.animation.state
    if not SpritePlayer.spriteSheets[currentState] then return end

    love.graphics.push()
    love.graphics.translate(config.position.x, config.position.y)

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
