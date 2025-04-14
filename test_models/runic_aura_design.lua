-- Runic Aura design module for LÖVE2D
-- Creates an aura effect using rotating runic symbols

local RunicAura = {}

-- Lista de símbolos rúnicos (usando caracteres Unicode)
local runicSymbols = {
    "ᚠ", -- Fehu (Riqueza)
    "ᚢ", -- Uruz (Força)
    "ᚦ", -- Thurisaz (Thor)
    "ᚨ", -- Ansuz (Deus)
    "ᚱ", -- Raidho (Viagem)
    "ᚲ", -- Kenaz (Tocha)
    "ᚷ", -- Gebo (Presente)
    "ᚹ", -- Wunjo (Alegria)
    "ᚺ", -- Hagalaz (Granizo)
    "ᚾ", -- Nauthiz (Necessidade)
    "ᛁ", -- Isa (Gelo)
    "ᛃ", -- Jera (Ano)
    "ᛇ", -- Eihwaz (Defesa)
    "ᛈ", -- Perthro (Destino)
    "ᛉ", -- Algiz (Proteção)
    "ᛊ", -- Sowilo (Sol)
    "ᛏ", -- Tiwaz (Vitória)
    "ᛒ", -- Berkana (Crescimento)
    "ᛖ", -- Ehwaz (Movimento)
    "ᛗ", -- Mannaz (Humanidade)
    "ᛚ", -- Laguz (Água)
    "ᛜ", -- Ingwaz (Fertilidade)
    "ᛟ", -- Othala (Herança)
    "ᛞ"  -- Dagaz (Dia)
}

-- Configuration template for the RunicAura design
RunicAura.defaultConfig = {
    x = 0,              -- Position X
    y = 0,              -- Position Y
    radius = 100,       -- Base radius of the aura
    layers = {
        count = 3,      -- Number of circular layers
        spacing = 40    -- Space between layers
    },
    runes = {
        size = 35,      -- Size of the runic symbols
        count = 16,     -- Number of runes per layer
        rotation = 0,   -- Current rotation of runes
        color = {0.9, 0.95, 1.0},  -- Slightly blue-tinted white
        symbols = {}    -- Will store the selected symbols for each position
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

-- Draw a single runic symbol with glow
local function drawRune(x, y, size, rotation, alpha, color, symbol)
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(rotation)
    
    -- Glow effect
    love.graphics.setColor(color[1], color[2], color[3], alpha * 0.3)
    local glowSize = size * 1.2
    love.graphics.setFont(love.graphics.newFont(glowSize))
    love.graphics.print(symbol, -glowSize/3, -glowSize/2)
    
    -- Main rune
    love.graphics.setColor(color[1], color[2], color[3], alpha)
    love.graphics.setFont(love.graphics.newFont(size))
    love.graphics.print(symbol, -size/3, -size/2)
    
    -- Mystical particles around the rune
    for i = 1, 6 do
        local angle = (i / 6) * math.pi * 2
        local px = math.cos(angle) * size * 0.4
        local py = math.sin(angle) * size * 0.4
        love.graphics.setColor(1, 1, 1, alpha * 0.5)
        love.graphics.circle('fill', px, py, 2)
    end
    
    love.graphics.pop()
end

-- Draw aura glow effect
local function drawAuraGlow(config, currentRadius, alpha)
    love.graphics.setColor(config.runes.color[1], 
                          config.runes.color[2], 
                          config.runes.color[3], 
                          alpha * 0.2)
    love.graphics.circle('fill', 0, 0, currentRadius + 20)
    love.graphics.circle('line', 0, 0, currentRadius)
end

-- Initialize random runes for each position
local function initializeRunes(config)
    if #config.runes.symbols == 0 then
        for layer = 1, config.layers.count do
            config.runes.symbols[layer] = {}
            for i = 1, config.runes.count do
                local randomIndex = love.math.random(1, #runicSymbols)
                config.runes.symbols[layer][i] = runicSymbols[randomIndex]
            end
        end
    end
end

-- Main drawing function
function RunicAura.draw(config)
    config = config or RunicAura.defaultConfig
    local time = love.timer.getTime()
    
    -- Initialize runes if not already done
    initializeRunes(config)
    
    -- Update rotation
    config.runes.rotation = config.runes.rotation + 
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
        
        -- Draw runic symbols for this layer
        for i = 1, config.runes.count do
            local angle = (i / config.runes.count) * math.pi * 2 +
                         config.runes.rotation * (layer % 2 == 0 and -1 or 1)
            
            -- Add some wave movement
            local waveOffset = math.sin(time * 2 + i + layer) * 10
            local currentRadius = layerRadius + waveOffset
            
            local x = math.cos(angle) * currentRadius
            local y = math.sin(angle) * currentRadius
            
            -- Calculate individual rune rotation
            local runeRotation = angle + time * (layer % 2 == 0 and 1 or -1)
            
            -- Draw the rune with varying alpha based on position
            local runeAlpha = layerAlpha * (0.6 + math.sin(time * 3 + i + layer) * 0.4)
            drawRune(x, y, 
                    config.runes.size * (1.2 - layer * 0.1),
                    runeRotation, 
                    runeAlpha, 
                    config.runes.color,
                    config.runes.symbols[layer][i])
        end
    end
    
    -- Draw mystical energy particles
    for i = 1, 40 do
        local particleAngle = (i / 40) * math.pi * 2 + time
        local particleRadius = config.radius + 
                             math.sin(time * 3 + i) * config.layers.spacing
        
        local px = math.cos(particleAngle) * particleRadius
        local py = math.sin(particleAngle) * particleRadius
        
        love.graphics.setColor(1, 1, 1, 0.3 + math.sin(time * 2 + i) * 0.2)
        love.graphics.circle('fill', px, py, 2)
    end
    
    love.graphics.pop()
end

-- Create a new RunicAura configuration
function RunicAura.newConfig(overrides)
    local config = {}
    for k, v in pairs(RunicAura.defaultConfig) do
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

return RunicAura 