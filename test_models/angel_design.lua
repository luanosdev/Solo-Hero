-- Angel design module for LÖVE2D
-- Inspired by Evangelion Angels geometric patterns

local Angel = {}

-- Configuration template for the Angel design
Angel.defaultConfig = {
    x = 0,              -- Position X
    y = 0,              -- Position Y
    size = 40,          -- Base size
    color = {0.9, 0.9, 1.0},  -- Default color (almost white)
    glow = {
        radius = 60,    -- Glow radius
        alpha = 0.3     -- Glow transparency
    },
    rotation = 0,       -- Current rotation
    core = {
        pulse = 0,      -- Core pulse value
        speed = 2       -- Pulse speed
    }
}

-- Main drawing function
-- @param config: table with the configuration (optional, will use defaults if not provided)
function Angel.draw(config)
    config = config or Angel.defaultConfig
    
    love.graphics.push()
    love.graphics.translate(config.x, config.y)
    
    -- Update rotation
    config.rotation = config.rotation + 0.5 * love.timer.getDelta()
    
    -- Update core pulse
    config.core.pulse = math.sin(love.timer.getTime() * config.core.speed) * 0.2 + 0.8
    
    -- Outer glow
    love.graphics.setColor(config.color[1], config.color[2], config.color[3], 0.2)
    love.graphics.circle('fill', 0, 0, config.glow.radius * 1.2)
    
    -- Rotating geometric patterns
    love.graphics.setColor(config.color[1], config.color[2], config.color[3], 0.6)
    for i = 1, 8 do
        local angle = (i * math.pi / 4) + config.rotation
        love.graphics.push()
        love.graphics.rotate(angle)
        -- Draw triangular wings
        love.graphics.polygon('fill', 
            0, -config.size * 1.2,
            config.size * 0.4, -config.size * 0.4,
            0, -config.size * 0.6
        )
        love.graphics.pop()
    end
    
    -- Inner geometric pattern
    love.graphics.setColor(config.color[1], config.color[2], config.color[3], 0.8)
    for i = 1, 4 do
        local angle = (i * math.pi / 2) + config.rotation * 0.5
        love.graphics.push()
        love.graphics.rotate(angle)
        -- Draw diamond shape
        love.graphics.polygon('fill',
            0, -config.size * 0.5,
            config.size * 0.3, 0,
            0, config.size * 0.5,
            -config.size * 0.3, 0
        )
        love.graphics.pop()
    end
    
    -- Core
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle('fill', 0, 0, config.size * 0.2 * config.core.pulse)
    
    -- Core ring
    love.graphics.setColor(config.color[1], config.color[2], config.color[3], 1)
    love.graphics.circle('line', 0, 0, config.size * 0.3)
    
    -- AT Field effect (hexagonal pattern)
    love.graphics.setColor(config.color[1], config.color[2], config.color[3], 0.3)
    for i = 1, 6 do
        local angle = (i * math.pi / 3) - config.rotation * 0.3
        love.graphics.push()
        love.graphics.rotate(angle)
        love.graphics.line(
            config.size * 0.4, 0,
            config.size * 0.8, 0
        )
        love.graphics.pop()
    end
    
    love.graphics.pop()
end

-- Create a new Angel configuration
-- @param overrides: table with values to override defaults
function Angel.newConfig(overrides)
    local config = {}
    for k, v in pairs(Angel.defaultConfig) do
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

return Angel 