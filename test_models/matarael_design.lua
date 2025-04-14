-- Matarael design module for LÖVE2D
-- Inspired by the 9th Angel from Evangelion

local Matarael = {}

-- Configuration template for the Matarael design
Matarael.defaultConfig = {
    x = 0,              -- Position X
    y = 0,              -- Position Y
    size = 20,          -- Base size (drastically reduced for much thinner body)
    color = {0.2, 0.2, 0.3},  -- Dark blue-grey color
    legs = {
        count = 8,      -- Number of legs
        length = 180,   -- Length of legs (much longer)
        width = 1.5,    -- Width of legs (even thinner)
        segments = 5,   -- Segments per leg (more segments for better curves)
        angleOffset = 0, -- Current leg animation offset
        curve = 0.4     -- Curve intensity for legs
    },
    eye = {
        size = 18,      -- Eye size (adjusted for new body size)
        pulse = 0,      -- Pulse animation value
        dropTimer = 0,  -- Timer for acid drops
        drops = {}      -- Table to store active acid drops
    },
    body = {
        segments = 5,   -- Body segment count (more segments)
        rotation = 0,   -- Current body rotation
        heightOffset = 8, -- Vertical spacing between segments (reduced for smaller body)
        taper = 0.25    -- Stronger tapering effect for more conical shape
    }
}

-- Update acid drops
local function updateDrops(config, dt)
    -- Add new drops
    config.eye.dropTimer = config.eye.dropTimer + dt
    if config.eye.dropTimer >= 1.5 then
        config.eye.dropTimer = 0
        table.insert(config.eye.drops, {
            x = config.x,
            y = config.y,
            size = 4,
            alpha = 1,
            speed = 100
        })
    end
    
    -- Update existing drops
    for i = #config.eye.drops, 1, -1 do
        local drop = config.eye.drops[i]
        drop.y = drop.y + drop.speed * dt
        drop.alpha = drop.alpha - dt * 0.5
        drop.size = drop.size - dt * 2
        
        if drop.alpha <= 0 or drop.size <= 0 then
            table.remove(config.eye.drops, i)
        end
    end
end

-- Draw a leg segment with curve
local function drawLegSegment(x1, y1, x2, y2, width)
    local angle = math.atan2(y2 - y1, x2 - x1)
    local length = math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
    
    love.graphics.push()
    love.graphics.translate(x1, y1)
    love.graphics.rotate(angle)
    
    -- Draw segment with slight curve
    local segments = 5
    local prevX, prevY = 0, 0
    for i = 1, segments do
        local t = i / segments
        local nextX = length * t
        local nextY = math.sin(t * math.pi) * width * 0.5
        
        if i > 1 then
            love.graphics.setLineWidth(width)
            love.graphics.line(prevX, prevY, nextX, nextY)
        end
        
        prevX, prevY = nextX, nextY
    end
    
    love.graphics.pop()
end

-- Main drawing function
function Matarael.draw(config)
    config = config or Matarael.defaultConfig
    
    -- Update animations
    config.body.rotation = config.body.rotation + 0.2 * love.timer.getDelta()
    config.legs.angleOffset = math.sin(love.timer.getTime() * 1.5) * 0.15
    config.eye.pulse = math.sin(love.timer.getTime() * 3) * 0.2 + 0.8
    updateDrops(config, love.timer.getDelta())
    
    -- Draw acid drops
    for _, drop in ipairs(config.eye.drops) do
        love.graphics.setColor(0.3, 0.8, 0.3, drop.alpha)
        love.graphics.circle('fill', drop.x, drop.y, drop.size)
    end
    
    -- Draw legs
    love.graphics.setColor(config.color[1], config.color[2], config.color[3], 0.9)
    for i = 1, config.legs.count do
        local baseAngle = (i * 2 * math.pi / config.legs.count) + config.legs.angleOffset
        local prevX, prevY = config.x, config.y
        
        for seg = 1, config.legs.segments do
            local segLength = config.legs.length / config.legs.segments
            -- Aumenta curvatura nas pernas
            local segAngle = baseAngle + 
                math.sin(config.body.rotation + i + seg) * config.legs.curve +
                math.sin(love.timer.getTime() * 1.5 + i * 0.7) * 0.2
            
            -- Adiciona mais movimento nas pontas
            local segmentFlex = (seg / config.legs.segments) ^ 2
            segAngle = segAngle + math.sin(love.timer.getTime() * 2 + i) * 0.3 * segmentFlex
            
            local nextX = prevX + math.cos(segAngle) * segLength
            local nextY = prevY + math.sin(segAngle) * segLength
            
            -- Diminui a largura mais drasticamente em direção à ponta
            local segmentWidth = config.legs.width * (1 - (seg-1)/config.legs.segments * 0.5)
            drawLegSegment(prevX, prevY, nextX, nextY, segmentWidth)
            
            prevX, prevY = nextX, nextY
        end
    end
    
    -- Draw body segments
    for i = config.body.segments, 1, -1 do
        local scale = 1 - (i-1) * config.body.taper  -- Redução mais acentuada
        local heightOffset = i * config.body.heightOffset
        love.graphics.setColor(config.color[1], config.color[2], config.color[3], 0.8)
        
        -- Corpo principal mais fino
        love.graphics.circle('fill', config.x, config.y - heightOffset, config.size * scale)
        
        -- Detalhes do corpo
        if i < config.body.segments then
            love.graphics.setColor(config.color[1], config.color[2], config.color[3], 0.4)
            love.graphics.circle('line', config.x, config.y - heightOffset, config.size * scale * 1.2)
            -- Adiciona linhas de detalhe verticais
            for j = 1, 3 do
                local angle = j * math.pi * 2 / 3 + config.body.rotation
                local length = config.size * scale * 0.8
                love.graphics.line(
                    config.x + math.cos(angle) * length * 0.5,
                    config.y - heightOffset + math.sin(angle) * length * 0.5,
                    config.x + math.cos(angle) * length,
                    config.y - heightOffset + math.sin(angle) * length
                )
            end
        end
    end
    
    -- Draw eye (mantido mais proeminente em relação ao corpo fino)
    love.graphics.setColor(0.8, 0.1, 0.1, 0.9)
    love.graphics.circle('fill', config.x, config.y, config.eye.size * config.eye.pulse)
    
    -- Draw eye details
    love.graphics.setColor(0.9, 0.9, 0.9, 1)
    love.graphics.circle('line', config.x, config.y, config.eye.size * 1.1)
    love.graphics.circle('line', config.x, config.y, config.eye.size * 0.7)
    
    -- Draw eye patterns (mais complexos)
    for i = 1, 8 do
        local angle = i * math.pi / 4 + config.body.rotation
        local x = config.x + math.cos(angle) * config.eye.size * 0.9
        local y = config.y + math.sin(angle) * config.eye.size * 0.9
        love.graphics.circle('fill', x, y, 1.5)
        
        -- Adiciona padrões geométricos no olho
        local innerX = config.x + math.cos(angle) * config.eye.size * 0.5
        local innerY = config.y + math.sin(angle) * config.eye.size * 0.5
        love.graphics.line(x, y, innerX, innerY)
        
        -- Conecta os pontos em padrão octogonal
        local nextAngle = ((i % 8) + 1) * math.pi / 4 + config.body.rotation
        local nextX = config.x + math.cos(nextAngle) * config.eye.size * 0.9
        local nextY = config.y + math.sin(nextAngle) * config.eye.size * 0.9
        love.graphics.line(x, y, nextX, nextY)
    end
end

-- Create a new Matarael configuration
function Matarael.newConfig(overrides)
    local config = {}
    for k, v in pairs(Matarael.defaultConfig) do
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

return Matarael 