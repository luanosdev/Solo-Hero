-- Armisael design module for LÖVE2D
-- Inspired by the 16th Angel from Evangelion

local Armisael = {}

-- Configuration template for the Armisael design
Armisael.defaultConfig = {
    x = 0,              -- Position X
    y = 0,              -- Position Y
    radius = 150,       -- Ring radius
    thickness = 8,      -- Base thickness of the ring
    segments = 120,     -- Number of segments for smooth circle
    pattern = {
        count = 40,     -- Reduced number of X patterns (to prevent overlap with larger size)
        size = 35,      -- Size of X patterns (significantly increased)
        spacing = 12    -- Increased space between patterns
    },
    rotation = {
        ring = 0,       -- Current ring rotation
        pattern = 0     -- Current pattern rotation
    },
    color = {
        primary = {0.9, 0.9, 1.0},  -- Main color
        glow = {1.0, 1.0, 1.0},     -- Glow color
        xPattern = {0.95, 0.95, 1.0}, -- X pattern color (slight blue tint)
        alpha = 0.8                  -- Base alpha
    },
    animation = {
        speed = {
            ring = 0.2,    -- Ring rotation speed
            pattern = 0.5, -- Pattern rotation speed
            pulse = 1.0    -- Pulse animation speed
        },
        wave = {
            amplitude = 4, -- Wave effect amplitude
            frequency = 2  -- Wave effect frequency
        }
    },
    isometric = {
        scale = 0.5,    -- Vertical scale for isometric view
        tilt = 0.3      -- Tilt angle for isometric perspective
    }
}

-- Draw a single X pattern
local function drawXPattern(x, y, size, angle, alpha, color)
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(angle)
    
    -- Draw the X with glow effect
    local halfSize = size * 0.7  -- Increased size multiplier
    
    -- Glow effect
    love.graphics.setLineWidth(6)  -- Increased line width for more prominence
    love.graphics.setColor(color[1], color[2], color[3], alpha * 0.4)  -- Increased glow opacity
    love.graphics.line(-halfSize, -halfSize, halfSize, halfSize)
    love.graphics.line(-halfSize, halfSize, halfSize, -halfSize)
    
    -- Main X lines
    love.graphics.setLineWidth(3)  -- Increased line width
    love.graphics.setColor(color[1], color[2], color[3], alpha)
    love.graphics.line(-halfSize, -halfSize, halfSize, halfSize)
    love.graphics.line(-halfSize, halfSize, halfSize, -halfSize)
    
    -- Center point
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.circle('fill', 0, 0, size * 0.15)  -- Increased center point size
    
    love.graphics.pop()
end

-- Main drawing function
function Armisael.draw(config)
    config = config or Armisael.defaultConfig
    local time = love.timer.getTime()
    
    -- Update rotations
    config.rotation.ring = config.rotation.ring + config.animation.speed.ring * love.timer.getDelta()
    config.rotation.pattern = config.rotation.pattern + config.animation.speed.pattern * love.timer.getDelta()
    
    love.graphics.push()
    love.graphics.translate(config.x, config.y)
    
    -- Apply isometric transformation
    love.graphics.scale(1, config.isometric.scale)
    love.graphics.rotate(config.rotation.ring + config.isometric.tilt)
    
    -- Draw the main ring glow
    local glowRadius = config.radius + math.sin(time * config.animation.speed.pulse) * 5
    love.graphics.setColor(config.color.glow[1], config.color.glow[2], config.color.glow[3], 0.2)
    love.graphics.circle('line', 0, 0, glowRadius + 10)
    love.graphics.circle('line', 0, 0, glowRadius - 10)
    
    -- Draw the double helix effect
    for i = 1, config.segments do
        local angle = (i / config.segments) * math.pi * 2
        local wave = math.sin(angle * config.animation.wave.frequency + time * 2) 
                    * config.animation.wave.amplitude
        
        -- Outer ring
        local outerRadius = config.radius + wave
        local x1 = math.cos(angle) * outerRadius
        local y1 = math.sin(angle) * outerRadius
        
        -- Inner ring
        local innerRadius = config.radius - wave
        local x2 = math.cos(angle) * innerRadius
        local y2 = math.sin(angle) * innerRadius
        
        -- Draw connecting lines with gradient
        local alpha = 0.3 + math.abs(math.sin(angle * 2 + time)) * 0.4
        love.graphics.setColor(config.color.primary[1], config.color.primary[2], config.color.primary[3], alpha)
        love.graphics.setLineWidth(config.thickness * (0.5 + math.abs(wave/config.animation.wave.amplitude) * 0.5))
        love.graphics.line(x1, y1, x2, y2)
        
        -- Draw X patterns along the ring
        if i % math.floor(config.segments / config.pattern.count) == 0 then
            local patternAngle = angle + config.rotation.pattern
            local patternX = math.cos(angle) * config.radius
            local patternY = math.sin(angle) * config.radius
            
            -- Draw main X with enhanced visuals
            drawXPattern(patternX, patternY, config.pattern.size, patternAngle, 
                        0.9 + math.sin(time * 3 + angle) * 0.1,
                        config.color.xPattern)
            
            -- Draw echo X patterns with enhanced visuals
            for j = 1, 2 do
                local echo = j * config.pattern.spacing
                drawXPattern(patternX + math.cos(angle) * echo, 
                           patternY + math.sin(angle) * echo,
                           config.pattern.size * (1 - j * 0.2),
                           patternAngle,
                           0.5 - j * 0.1,
                           config.color.xPattern)
                           
                drawXPattern(patternX - math.cos(angle) * echo,
                           patternY - math.sin(angle) * echo,
                           config.pattern.size * (1 - j * 0.2),
                           patternAngle,
                           0.5 - j * 0.1,
                           config.color.xPattern)
            end
        end
    end
    
    -- Draw energy particles
    for i = 1, 20 do
        local particleAngle = (i / 20) * math.pi * 2 + time
        local distance = config.radius + math.sin(time * 3 + i) * 20
        local x = math.cos(particleAngle) * distance
        local y = math.sin(particleAngle) * distance
        
        love.graphics.setColor(1, 1, 1, 0.3 + math.sin(time * 2 + i) * 0.2)
        love.graphics.circle('fill', x, y, 2)
    end
    
    love.graphics.pop()
end

-- Create a new Armisael configuration
function Armisael.newConfig(overrides)
    local config = {}
    for k, v in pairs(Armisael.defaultConfig) do
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

return Armisael 