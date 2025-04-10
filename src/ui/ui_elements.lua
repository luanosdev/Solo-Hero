local elements = {}
local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")
local glowShader = nil

-- Tabela para armazenar o último valor de vida de cada entidade
elements.lastHealth = {}

-- Tabela para armazenar o valor da barra de cache
elements.cacheHealth = {}

-- Velocidade de diminuição da barra de cache
elements.cacheSpeed = 0.5

function elements.setGlowShader(shader)
    glowShader = shader
end

function elements.drawWindowFrame(x, y, w, h, title)
    love.graphics.setColor(colors.window_bg)
    love.graphics.rectangle("fill", x, y, w, h, 5, 5)

    if glowShader then
        love.graphics.setShader(glowShader)
        local glowColor = {colors.window_border[1], colors.window_border[2], colors.window_border[3], 0.5}
        glowShader:send("glowColor", glowColor)
        glowShader:send("glowRadius", 4.0)
        love.graphics.setLineWidth(5)
        love.graphics.rectangle("line", x, y, w, h, 5, 5)
        love.graphics.setShader()
    end

    love.graphics.setColor(colors.window_border)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h, 5, 5)
    love.graphics.setLineWidth(1)

    if title then
        love.graphics.setFont(fonts.title)
        love.graphics.setColor(colors.window_title)
        local titleHeight = fonts.title:getHeight()
        local lineY = y + titleHeight * 1.5
        love.graphics.setColor(colors.window_border[1], colors.window_border[2], colors.window_border[3], 0.4)
        love.graphics.line(x + 10, lineY, x + w - 10, lineY)
        love.graphics.setColor(colors.window_title)
        love.graphics.printf(title, x, y + 10, w, "center")
    end
end

function elements.drawResourceBar(x, y, width, height, current, max, color, bgColor, borderColor, showText, textColor, textFormat)
    -- Garante que os valores sejam números válidos
    current = tonumber(current) or 0
    max = tonumber(max) or 1
    width = tonumber(width) or 100
    height = tonumber(height) or 20

    -- Garante que os valores estejam dentro de limites razoáveis
    current = math.max(0, math.min(current, max))
    max = math.max(1, max)

    -- Inicializa o cache para esta entidade se não existir
    local entityId = tostring(x) .. tostring(y) -- Identificador único para a entidade
    if not elements.lastHealth[entityId] then
        elements.lastHealth[entityId] = current
        elements.cacheHealth[entityId] = current
    end

    -- Atualiza o cache se a vida atual for menor que o cache
    if current < elements.cacheHealth[entityId] then
        elements.cacheHealth[entityId] = elements.cacheHealth[entityId] - elements.cacheSpeed
        if elements.cacheHealth[entityId] < current then
            elements.cacheHealth[entityId] = current
        end
    else
        elements.cacheHealth[entityId] = current
    end

    -- Atualiza o último valor de vida
    elements.lastHealth[entityId] = current

    -- Calcula as porcentagens
    local currentPercent = current / max
    local cachePercent = elements.cacheHealth[entityId] / max

    -- Garante que as cores sejam números
    local bgColor = bgColor or colors.bar_bg
    local color = color or colors.hp_fill
    local borderColor = borderColor or colors.bar_border
    local textColor = textColor or colors.text_main

    -- Desenha o fundo da barra
    love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)
    love.graphics.rectangle("fill", x, y, width, height)

    -- Desenha a barra de cache (parte que diminui suavemente)
    local darkerColor = {
        color[1] * 0.4,  -- Red
        color[2] * 0.4,  -- Green
        color[3] * 0.4,  -- Blue
        (color[4] or 1) * 0.8  -- Alpha
    }
    love.graphics.setColor(darkerColor)
    love.graphics.rectangle("fill", x, y, width * cachePercent, height)

    -- Desenha a barra de vida atual
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.rectangle("fill", x, y, width * currentPercent, height)

    -- Desenha a borda
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
    love.graphics.rectangle("line", x, y, width, height)

    -- Desenha o texto se necessário
    if showText then
        local text = textFormat and string.format(textFormat, current, max) or string.format("%d/%d", current, max)
        local font = love.graphics.getFont()
        local textWidth = font:getWidth(text)
        local textHeight = font:getHeight()
        local textX = x + (width - textWidth) / 2
        local textY = y + (height - textHeight) / 2

        -- Desenha a sombra do texto
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.print(text, textX + 1, textY + 1)

        -- Desenha o texto principal
        love.graphics.setColor(textColor[1], textColor[2], textColor[3], textColor[4] or 1)
        love.graphics.print(text, textX, textY)
    end
end

function elements.drawRarityBorderAndGlow(itemRarity, x, y, w, h)
    local rarityColor = colors.rarity[itemRarity] or colors.rarity['E']

    if glowShader then
        love.graphics.setShader(glowShader)
        local glowCol = {rarityColor.r, rarityColor.g, rarityColor.b, 0.6}
        glowShader:send("glowColor", glowCol)
        glowShader:send("glowRadius", 4.0)
        love.graphics.setLineWidth(5)
        love.graphics.rectangle("line", x, y, w, h, 3, 3)
        love.graphics.setShader()
    end

    love.graphics.setLineWidth(2)
    love.graphics.setColor(rarityColor.r, rarityColor.g, rarityColor.b, rarityColor.a)
    love.graphics.rectangle("line", x, y, w, h, 3, 3)
    love.graphics.setLineWidth(1)
end

return elements 