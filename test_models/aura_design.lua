-- Aura design module for LÖVE2D
-- Creates an aura effect using rotating X characters

local Aura = {}

-- Configuration template for the Aura design
Aura.defaultConfig = {
    x = 0,              -- Position X
    y = 0,              -- Position Y
    radius = 100,       -- Base radius of the aura
    layers = {
        count = 3,      -- Number of circular layers
        spacing = 40    -- Space between layers
    },
    characters = {
        size = 30,      -- Size of the X characters
        count = 16,     -- Number of X's per layer
        rotation = 0,   -- Current rotation of characters
        color = {0.9, 0.95, 1.0}  -- Slightly blue-tinted white
    },
    aura = {
        intensity = 0.8,    -- Base intensity of the aura glow
        pulseSpeed = 1.2,   -- Speed of the pulse effect
        rotationSpeed = 0.8 -- Base rotation speed
    },
    isometric = {
        scale = 0.5,    -- Vertical scale for isometric view
        tilt = 0.3      -- Tilt angle for isometric perspective
    }
}

-- Draw a single X character with glow
local function drawX(x, y, size, rotation, alpha, color)
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(rotation)
    
    -- Glow effect
    love.graphics.setColor(color[1], color[2], color[3], alpha * 0.3)
    local glowSize = size * 1.2
    love.graphics.setLineWidth(8)
    love.graphics.line(-glowSize/2, -glowSize/2, glowSize/2, glowSize/2)
    love.graphics.line(-glowSize/2, glowSize/2, glowSize/2, -glowSize/2)
    
    -- Main X
    love.graphics.setColor(color[1], color[2], color[3], alpha)
    love.graphics.setLineWidth(4)
    love.graphics.line(-size/2, -size/2, size/2, size/2)
    love.graphics.line(-size/2, size/2, size/2, -size/2)
    
    -- Center point
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.circle('fill', 0, 0, size * 0.1)
    
    love.graphics.pop()
end

-- Draw aura glow effect
local function drawAuraGlow(config, currentRadius, alpha)
    love.graphics.setColor(config.characters.color[1], 
                          config.characters.color[2], 
                          config.characters.color[3], 
                          alpha * 0.2)
    love.graphics.circle('fill', 0, 0, currentRadius + 20)
    love.graphics.circle('line', 0, 0, currentRadius)
end

-- Main drawing function
function Aura.draw(config)
    config = config or Aura.defaultConfig
    local time = love.timer.getTime()
    
    -- Update rotation
    config.characters.rotation = config.characters.rotation + 
                               config.aura.rotationSpeed * love.timer.getDelta()
    
    love.graphics.push()
    love.graphics.translate(config.x, config.y)
    
    -- Apply isometric transformation
    love.graphics.scale(1, config.isometric.scale)
    love.graphics.rotate(config.isometric.tilt)
    
    -- Draw each layer of the aura
    for layer = 1, config.layers.count do
        local layerRadius = config.radius + (layer - 1) * config.layers.spacing
        local layerAlpha = config.aura.intensity * 
                          (1 - (layer - 1) / config.layers.count) *
                          (0.7 + math.sin(time * config.aura.pulseSpeed) * 0.3)
        
        -- Draw the aura glow for this layer
        drawAuraGlow(config, layerRadius, layerAlpha)
        
        -- Draw X characters for this layer
        for i = 1, config.characters.count do
            local angle = (i / config.characters.count) * math.pi * 2 +
                         config.characters.rotation * (layer % 2 == 0 and -1 or 1)
            
            -- Add some wave movement
            local waveOffset = math.sin(time * 2 + i + layer) * 10
            local currentRadius = layerRadius + waveOffset
            
            local x = math.cos(angle) * currentRadius
            local y = math.sin(angle) * currentRadius
            
            -- Calculate individual X rotation
            local xRotation = angle + time * (layer % 2 == 0 and 1 or -1)
            
            -- Draw the X with varying alpha based on position
            local charAlpha = layerAlpha * (0.6 + math.sin(time * 3 + i + layer) * 0.4)
            drawX(x, y, config.characters.size * (1.2 - layer * 0.1),
                 xRotation, charAlpha, config.characters.color)
        end
    end
    
    -- Draw energy particles
    for i = 1, 30 do
        local particleAngle = (i / 30) * math.pi * 2 + time
        local particleRadius = config.radius + 
                             math.sin(time * 3 + i) * config.layers.spacing
        
        local px = math.cos(particleAngle) * particleRadius
        local py = math.sin(particleAngle) * particleRadius
        
        love.graphics.setColor(1, 1, 1, 0.3 + math.sin(time * 2 + i) * 0.2)
        love.graphics.circle('fill', px, py, 2)
    end
    
    love.graphics.pop()
end

-- Create a new Aura configuration
function Aura.newConfig(overrides)
    local config = {}
    for k, v in pairs(Aura.defaultConfig) do
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

return Aura 