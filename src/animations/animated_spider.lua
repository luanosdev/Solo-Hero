-- Módulo de animação para o boss Spider
local AnimatedSpider = {}

-- Configuração padrão
AnimatedSpider.defaultConfig = {
    position = {
        x = 0,
        y = 0,
    },
    scale = 2,
    speed = 80,
    animation = {
        currentFrame = 1, -- Começa do frame 1
        timer = 0,
        frameTime = 0.12, -- Tempo entre frames
        direction = 0,    -- Ângulo base (0, 30, 45, ...)
        state = 'walk',   -- walk ou death
        isDead = false,   -- Flag para indicar se está morto
        deathFrameTime = 0.1, -- Tempo mais rápido para a animação de morte
        deathType = 'die1' -- Tipo de animação de morte (die1 ou die2)
    }
}

-- Lista de ângulos disponíveis (em string para facilitar o nome do arquivo)
AnimatedSpider.angles = {0, 30, 45, 60, 90, 120, 135, 150, 180, 210, 225, 240, 270, 300, 315, 330}

-- Carrega os spritesheets e gera os quads
function AnimatedSpider.load()
    print("Iniciando carregamento dos sprites da aranha...")
    
    AnimatedSpider.bodySheets = {
        walk = {},
        death = {
            die1 = {},
            die2 = {}
        }
    }
    AnimatedSpider.shadowSheets = {
        walk = {},
        death = {
            die1 = {},
            die2 = {}
        }
    }
    AnimatedSpider.bodyQuads = {
        walk = {},
        death = {
            die1 = {},
            die2 = {}
        }
    }
    AnimatedSpider.shadowQuads = {
        walk = {},
        death = {
            die1 = {},
            die2 = {}
        }
    }
    
    local frameW, frameH = 256, 256
    local framesPerRow, framesPerCol = 4, 4
    
    -- Carrega sprites de caminhada
    for _, angle in ipairs(AnimatedSpider.angles) do
        local angleStr = string.format("%03d", angle)
        -- Carrega imagens de caminhada
        local bodyPath = string.format("assets/bosses/spider/walk/Walk_Body_%s.png", angleStr)
        local shadowPath = string.format("assets/bosses/spider/walk/Walk_Shadow_%s.png", angleStr)
        
        local successBody, bodyImg = pcall(function() return love.graphics.newImage(bodyPath) end)
        local successShadow, shadowImg = pcall(function() return love.graphics.newImage(shadowPath) end)
        
        if successBody then
            AnimatedSpider.bodySheets.walk[angle] = bodyImg
            AnimatedSpider.bodyQuads.walk[angle] = {}
            for row = 0, framesPerCol-1 do
                for col = 0, framesPerRow-1 do
                    local frame = row * framesPerRow + col + 1
                    AnimatedSpider.bodyQuads.walk[angle][frame] = love.graphics.newQuad(
                        col * frameW, row * frameH, frameW, frameH, bodyImg:getDimensions()
                    )
                end
            end
        else
            print("Erro ao carregar corpo spider: " .. bodyPath)
        end
        if successShadow then
            AnimatedSpider.shadowSheets.walk[angle] = shadowImg
            AnimatedSpider.shadowQuads.walk[angle] = {}
            for row = 0, framesPerCol-1 do
                for col = 0, framesPerRow-1 do
                    local frame = row * framesPerRow + col + 1
                    AnimatedSpider.shadowQuads.walk[angle][frame] = love.graphics.newQuad(
                        col * frameW, row * frameH, frameW, frameH, shadowImg:getDimensions()
                    )
                end
            end
        else
            print("Erro ao carregar sombra spider: " .. shadowPath)
        end
    end
    
    -- Carrega sprites de morte
    for _, angle in ipairs(AnimatedSpider.angles) do
        local angleStr = string.format("%03d", angle)
        
        -- Carrega imagens de morte do tipo 1
        local bodyPath1 = string.format("assets/bosses/spider/die1/Die1_Body_%s.png", angleStr)
        local shadowPath1 = string.format("assets/bosses/spider/die1/Die1_Shadow_%s.png", angleStr)
        
        print(string.format("\nTentando carregar sprites de morte1 para ângulo %s", angleStr))
        print("Caminho do corpo:", bodyPath1)
        print("Caminho da sombra:", shadowPath1)
        
        local successBody1, bodyImg1 = pcall(function() return love.graphics.newImage(bodyPath1) end)
        local successShadow1, shadowImg1 = pcall(function() return love.graphics.newImage(shadowPath1) end)
        
        if successBody1 then
            print(string.format("Corpo die1 carregado com sucesso para ângulo %s", angleStr))
            print(string.format("Dimensões do corpo: %dx%d", bodyImg1:getWidth(), bodyImg1:getHeight()))
            AnimatedSpider.bodySheets.death.die1[angle] = bodyImg1
            AnimatedSpider.bodyQuads.death.die1[angle] = {}
            
            -- Die1 tem 8x3 frames
            local die1FrameW = bodyImg1:getWidth() / 8
            local die1FrameH = bodyImg1:getHeight() / 3
            
            for row = 0, 2 do
                for col = 0, 7 do
                    local frame = row * 8 + col + 1
                    AnimatedSpider.bodyQuads.death.die1[angle][frame] = love.graphics.newQuad(
                        col * die1FrameW, row * die1FrameH, die1FrameW, die1FrameH, bodyImg1:getDimensions()
                    )
                end
            end
        else
            print("Erro ao carregar corpo spider (morte1): " .. bodyPath1)
            print("Erro detalhado:", bodyImg1)
        end
        
        if successShadow1 then
            print(string.format("Sombra die1 carregada com sucesso para ângulo %s", angleStr))
            print(string.format("Dimensões da sombra: %dx%d", shadowImg1:getWidth(), shadowImg1:getHeight()))
            AnimatedSpider.shadowSheets.death.die1[angle] = shadowImg1
            AnimatedSpider.shadowQuads.death.die1[angle] = {}
            
            -- Die1 tem 8x3 frames
            local die1FrameW = shadowImg1:getWidth() / 8
            local die1FrameH = shadowImg1:getHeight() / 3
            
            for row = 0, 2 do
                for col = 0, 7 do
                    local frame = row * 8 + col + 1
                    AnimatedSpider.shadowQuads.death.die1[angle][frame] = love.graphics.newQuad(
                        col * die1FrameW, row * die1FrameH, die1FrameW, die1FrameH, shadowImg1:getDimensions()
                    )
                end
            end
        else
            print("Erro ao carregar sombra spider (morte1): " .. shadowPath1)
            print("Erro detalhado:", shadowImg1)
        end
        
        -- Carrega imagens de morte do tipo 2
        local bodyPath2 = string.format("assets/bosses/spider/die2/Die2_Body_%s.png", angleStr)
        local shadowPath2 = string.format("assets/bosses/spider/die2/Die2_Shadow_%s.png", angleStr)
        
        print(string.format("\nTentando carregar sprites de morte2 para ângulo %s", angleStr))
        print("Caminho do corpo:", bodyPath2)
        print("Caminho da sombra:", shadowPath2)
        
        local successBody2, bodyImg2 = pcall(function() return love.graphics.newImage(bodyPath2) end)
        local successShadow2, shadowImg2 = pcall(function() return love.graphics.newImage(shadowPath2) end)
        
        if successBody2 then
            print(string.format("Corpo die2 carregado com sucesso para ângulo %s", angleStr))
            print(string.format("Dimensões do corpo: %dx%d", bodyImg2:getWidth(), bodyImg2:getHeight()))
            AnimatedSpider.bodySheets.death.die2[angle] = bodyImg2
            AnimatedSpider.bodyQuads.death.die2[angle] = {}
            
            -- Die2 tem 5x4 frames
            local die2FrameW = bodyImg2:getWidth() / 5
            local die2FrameH = bodyImg2:getHeight() / 4
            
            for row = 0, 3 do
                for col = 0, 4 do
                    local frame = row * 5 + col + 1
                    AnimatedSpider.bodyQuads.death.die2[angle][frame] = love.graphics.newQuad(
                        col * die2FrameW, row * die2FrameH, die2FrameW, die2FrameH, bodyImg2:getDimensions()
                    )
                end
            end
        else
            print("Erro ao carregar corpo spider (morte2): " .. bodyPath2)
            print("Erro detalhado:", bodyImg2)
        end
        
        if successShadow2 then
            print(string.format("Sombra die2 carregada com sucesso para ângulo %s", angleStr))
            print(string.format("Dimensões da sombra: %dx%d", shadowImg2:getWidth(), shadowImg2:getHeight()))
            AnimatedSpider.shadowSheets.death.die2[angle] = shadowImg2
            AnimatedSpider.shadowQuads.death.die2[angle] = {}
            
            -- Die2 tem 5x4 frames
            local die2FrameW = shadowImg2:getWidth() / 5
            local die2FrameH = shadowImg2:getHeight() / 4
            
            for row = 0, 3 do
                for col = 0, 4 do
                    local frame = row * 5 + col + 1
                    AnimatedSpider.shadowQuads.death.die2[angle][frame] = love.graphics.newQuad(
                        col * die2FrameW, row * die2FrameH, die2FrameW, die2FrameH, shadowImg2:getDimensions()
                    )
                end
            end
        else
            print("Erro ao carregar sombra spider (morte2): " .. shadowPath2)
            print("Erro detalhado:", shadowImg2)
        end
    end
    
    print("\nCarregamento de sprites concluído.")
    print("Verificando sprites carregados para ângulo 210:")
    print("Corpo die1:", AnimatedSpider.bodySheets.death.die1[210] ~= nil)
    print("Sombra die1:", AnimatedSpider.shadowSheets.death.die1[210] ~= nil)
    print("Corpo die2:", AnimatedSpider.bodySheets.death.die2[210] ~= nil)
    print("Sombra die2:", AnimatedSpider.shadowSheets.death.die2[210] ~= nil)
end

-- Função para pegar o ângulo mais próximo disponível
function AnimatedSpider.getClosestAngle(angle)
    local minDiff, closest = 360, 0
    for _, a in ipairs(AnimatedSpider.angles) do
        local diff = math.abs(((angle - a + 180) % 360) - 180)
        if diff < minDiff then
            minDiff = diff
            closest = a
        end
    end
    return closest
end

-- Atualiza a animação
function AnimatedSpider.update(config, dt, targetPosition)
    if config.animation.isDead then
        -- Atualiza a animação de morte
        config.animation.state = 'death'
        config.animation.timer = config.animation.timer + dt
        
        -- Usa um tempo de frame diferente para a animação de morte
        local frameTime = config.animation.deathFrameTime
        
        if config.animation.timer >= frameTime then
            config.animation.timer = 0 -- Reseta o timer
            local oldFrame = config.animation.currentFrame
            
            -- Die1 tem 24 frames (8x3), Die2 tem 20 frames (5x4)
            local maxFrames = config.animation.deathType == 'die1' and 24 or 20
            
            -- Só avança o frame se não estiver no último
            if config.animation.currentFrame < maxFrames then
                config.animation.currentFrame = config.animation.currentFrame + 1
            end
        end
        return
    end

    -- Calcula direção para o alvo
    local dx = targetPosition.x - config.position.x
    local dy = targetPosition.y - config.position.y
    local angle = math.atan2(dy, dx) * (180 / math.pi)
    if angle < 0 then angle = angle + 360 end
    -- Ajuste: subtrai 90 graus para alinhar 0° do sprite (cima) com 0° matemático (direita)
    angle = (angle + 90) % 360
    config.animation.direction = AnimatedSpider.getClosestAngle(angle)

    -- Movimento
    local length = math.sqrt(dx*dx + dy*dy)
    if length > 0 then
        dx = dx / length
        dy = dy / length
        config.position.x = config.position.x + dx * config.speed * dt
        config.position.y = config.position.y + dy * config.speed * dt
        -- Animação
        config.animation.timer = config.animation.timer + dt
        if config.animation.timer >= config.animation.frameTime then
            config.animation.timer = config.animation.timer - config.animation.frameTime
            config.animation.currentFrame = config.animation.currentFrame + 1
            if config.animation.currentFrame > 16 then config.animation.currentFrame = 1 end
        end
    end
end

-- Desenha o boss Spider (sombra + corpo)
function AnimatedSpider.draw(config)
    local angle = config.animation.direction
    local frame = config.animation.currentFrame
    local state = config.animation.state
    local deathType = config.animation.deathType
    
    -- Sombra
    if state == 'walk' then
        if AnimatedSpider.shadowSheets[state][angle] and AnimatedSpider.shadowQuads[state][angle][frame] then
            love.graphics.setColor(1,1,1,0.5)
            love.graphics.draw(
                AnimatedSpider.shadowSheets[state][angle],
                AnimatedSpider.shadowQuads[state][angle][frame],
                config.position.x, config.position.y,
                0,
                config.scale, config.scale,
                128, 128
            )
        end
    else -- death state
        if AnimatedSpider.shadowSheets.death[deathType][angle] and AnimatedSpider.shadowQuads.death[deathType][angle][frame] then
            love.graphics.setColor(1,1,1,0.5)
            love.graphics.draw(
                AnimatedSpider.shadowSheets.death[deathType][angle],
                AnimatedSpider.shadowQuads.death[deathType][angle][frame],
                config.position.x, config.position.y,
                0,
                config.scale, config.scale,
                128, 128
            )
        end
    end
    
    -- Corpo
    if state == 'walk' then
        if AnimatedSpider.bodySheets[state][angle] and AnimatedSpider.bodyQuads[state][angle][frame] then
            love.graphics.setColor(1,1,1,1)
            love.graphics.draw(
                AnimatedSpider.bodySheets[state][angle],
                AnimatedSpider.bodyQuads[state][angle][frame],
                config.position.x, config.position.y,
                0,
                config.scale, config.scale,
                128, 128
            )
        end
    else -- death state
        if AnimatedSpider.bodySheets.death[deathType][angle] and AnimatedSpider.bodyQuads.death[deathType][angle][frame] then
            love.graphics.setColor(1,1,1,1)
            love.graphics.draw(
                AnimatedSpider.bodySheets.death[deathType][angle],
                AnimatedSpider.bodyQuads.death[deathType][angle][frame],
                config.position.x, config.position.y,
                0,
                config.scale, config.scale,
                128, 128
            )
        end
    end
end

-- Cria nova config
function AnimatedSpider.newConfig(overrides)
    local config = {}
    for k, v in pairs(AnimatedSpider.defaultConfig) do
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
function AnimatedSpider.startDeath(config)
    config.animation.isDead = true
    config.animation.state = 'death'
    config.animation.currentFrame = 1 -- Começa do frame 1
    config.animation.timer = 0
    
    -- Usa love.math.random() que é mais confiável para aleatoriedade
    config.animation.deathType = love.math.random(2) == 1 and 'die1' or 'die2'
    print(string.format("Animação de morte escolhida: %s", config.animation.deathType))
end

return AnimatedSpider 