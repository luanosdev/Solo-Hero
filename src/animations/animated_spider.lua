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
        state = 'walk',   -- Por enquanto só walk
    }
}

-- Lista de ângulos disponíveis (em string para facilitar o nome do arquivo)
AnimatedSpider.angles = {0, 30, 45, 60, 90, 120, 135, 150, 180, 210, 225, 240, 270, 300, 315, 330}

-- Carrega os spritesheets e gera os quads
function AnimatedSpider.load()
    AnimatedSpider.bodySheets = {}
    AnimatedSpider.shadowSheets = {}
    AnimatedSpider.bodyQuads = {}
    AnimatedSpider.shadowQuads = {}
    
    local frameW, frameH = 256, 256
    local framesPerRow, framesPerCol = 4, 4
    
    for _, angle in ipairs(AnimatedSpider.angles) do
        local angleStr = string.format("%03d", angle)
        -- Carrega imagens
        local bodyPath = string.format("assets/bosses/spider/walk/Walk_Body_%s.png", angleStr)
        local shadowPath = string.format("assets/bosses/spider/walk/Walk_Shadow_%s.png", angleStr)
        
        local successBody, bodyImg = pcall(function() return love.graphics.newImage(bodyPath) end)
        local successShadow, shadowImg = pcall(function() return love.graphics.newImage(shadowPath) end)
        
        if successBody then
            AnimatedSpider.bodySheets[angle] = bodyImg
            AnimatedSpider.bodyQuads[angle] = {}
            for row = 0, framesPerCol-1 do
                for col = 0, framesPerRow-1 do
                    local frame = row * framesPerRow + col + 1
                    AnimatedSpider.bodyQuads[angle][frame] = love.graphics.newQuad(
                        col * frameW, row * frameH, frameW, frameH, bodyImg:getDimensions()
                    )
                end
            end
        else
            print("Erro ao carregar corpo spider: " .. bodyPath)
        end
        if successShadow then
            AnimatedSpider.shadowSheets[angle] = shadowImg
            AnimatedSpider.shadowQuads[angle] = {}
            for row = 0, framesPerCol-1 do
                for col = 0, framesPerRow-1 do
                    local frame = row * framesPerRow + col + 1
                    AnimatedSpider.shadowQuads[angle][frame] = love.graphics.newQuad(
                        col * frameW, row * frameH, frameW, frameH, shadowImg:getDimensions()
                    )
                end
            end
        else
            print("Erro ao carregar sombra spider: " .. shadowPath)
        end
    end
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
function AnimatedSpider.update(config, dt, targetX, targetY)
    -- Calcula direção para o alvo
    local dx = targetX - config.position.x
    local dy = targetY - config.position.y
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
    -- Sombra
    if AnimatedSpider.shadowSheets[angle] and AnimatedSpider.shadowQuads[angle][frame] then
        love.graphics.setColor(1,1,1,0.5)
        love.graphics.draw(
            AnimatedSpider.shadowSheets[angle],
            AnimatedSpider.shadowQuads[angle][frame],
            config.position.x, config.position.y,
            0,
            config.scale, config.scale,
            128, 128
        )
    end
    -- Corpo
    if AnimatedSpider.bodySheets[angle] and AnimatedSpider.bodyQuads[angle][frame] then
        love.graphics.setColor(1,1,1,1)
        love.graphics.draw(
            AnimatedSpider.bodySheets[angle],
            AnimatedSpider.bodyQuads[angle][frame],
            config.position.x, config.position.y,
            0,
            config.scale, config.scale,
            128, 128
        )
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

return AnimatedSpider 