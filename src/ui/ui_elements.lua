local elements = {}
local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")
local glowShader = nil

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

function elements.drawResourceBar(x, y, w, h, percent, bgColor, fillColor, label, valueText)
    percent = math.max(0, math.min(1, percent))
    love.graphics.setColor(bgColor or colors.bar_bg)
    love.graphics.rectangle("fill", x, y, w, h, 3, 3)
    love.graphics.setColor(fillColor or colors.white)
    love.graphics.rectangle("fill", x + 1, y + 1, (w - 2) * percent, h - 2, 2, 2)
    love.graphics.setColor(colors.bar_border)
    love.graphics.rectangle("line", x, y, w, h, 3, 3)

    if label or valueText then
        love.graphics.setFont(fonts.main_small)
        love.graphics.setColor(colors.white)
        local fullText = label and valueText and (label .. ": " .. valueText) or label or valueText or ""
        love.graphics.setColor(0,0,0,0.7)
        love.graphics.printf(fullText, x + 1, y + h/2 - fonts.main_small:getHeight()/2 + 1, w - 2, "center")
        love.graphics.setColor(colors.white)
        love.graphics.printf(fullText, x, y + h/2 - fonts.main_small:getHeight()/2, w - 2, "center")
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