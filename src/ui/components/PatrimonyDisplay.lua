local fonts = require("src.ui.fonts")
local colors = require("src.ui.colors")

---@class PatrimonyDisplay
local PatrimonyDisplay = {}

--- Desenha o display do patrimônio
---@param x number Posição X
---@param y number Posição Y
---@param patrimonyManager PatrimonyManager Gerenciador de patrimônio
---@param alignment string|nil Alinhamento do texto ("left", "center", "right")
function PatrimonyDisplay.draw(x, y, patrimonyManager, alignment)
    alignment = alignment or "right"

    if not patrimonyManager then
        return
    end

    local currentGold = patrimonyManager:getCurrentGold()
    local formattedGold = patrimonyManager:formatGold(currentGold)

    -- Define a fonte para recursos
    love.graphics.setFont(fonts.resource_value or fonts.main_large)

    -- Desenha ícone de ouro (usando símbolo Unicode ou texto)
    local goldIcon = "💰" -- Pode ser substituído por um ícone personalizado
    local iconWidth = 0

    -- Se tiver ícone customizado, desenhar aqui
    -- Por enquanto, usa apenas texto

    -- Calcula largura total para alinhamento
    local textWidth = fonts.resource_value and fonts.resource_value:getWidth(formattedGold) or
        love.graphics.getFont():getWidth(formattedGold)
    local totalWidth = iconWidth + textWidth

    local drawX = x
    if alignment == "center" then
        drawX = x - totalWidth / 2
    elseif alignment == "right" then
        drawX = x - totalWidth
    end

    -- Desenha sombra do texto
    love.graphics.setColor(colors.black_transparent_more or { 0, 0, 0, 0.8 })
    love.graphics.print(formattedGold, drawX + iconWidth + 1, y + 1)

    -- Desenha texto principal
    love.graphics.setColor(colors.text_gold)
    love.graphics.print(formattedGold, drawX + iconWidth, y)

    -- Reset da cor
    love.graphics.setColor(colors.white)
end

--- Obtém as dimensões do display do patrimônio
---@param patrimonyManager PatrimonyManager Gerenciador de patrimônio
---@return number width, number height
function PatrimonyDisplay.getDimensions(patrimonyManager)
    if not patrimonyManager then
        return 0, 0
    end

    local formattedGold = patrimonyManager:formatGold()
    local font = fonts.resource_value or fonts.main_large or love.graphics.getFont()

    local width = font:getWidth(formattedGold)
    local height = font:getHeight()

    return width, height
end

--- Desenha um display de patrimônio com fundo e borda
---@param x number Posição X
---@param y number Posição Y
---@param w number Largura do fundo
---@param h number Altura do fundo
---@param patrimonyManager PatrimonyManager Gerenciador de patrimônio
function PatrimonyDisplay.drawWithBackground(x, y, w, h, patrimonyManager)
    if not patrimonyManager then
        return
    end

    -- Desenha fundo
    love.graphics.setColor(colors.lobby_background or { 0.1, 0.1, 0.1, 0.8 })
    love.graphics.rectangle("fill", x, y, w, h)

    -- Desenha borda
    love.graphics.setColor(colors.text_gold)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h)

    -- Centraliza o texto no fundo
    local textX = x + w / 2
    local textY = y + h / 2 - (fonts.resource_value and fonts.resource_value:getHeight() or 20) / 2

    PatrimonyDisplay.draw(textX, textY, patrimonyManager, "center")

    -- Reset
    love.graphics.setLineWidth(1)
    love.graphics.setColor(colors.white)
end

--- Desenha um display compacto para a navbar
---@param x number Posição X (canto direito)
---@param y number Posição Y
---@param patrimonyManager PatrimonyManager Gerenciador de patrimônio
---@return number totalWidth Largura total ocupada
function PatrimonyDisplay.drawCompact(x, y, patrimonyManager)
    if not patrimonyManager then
        return 0
    end

    local currentGold = patrimonyManager:getCurrentGold()
    local formattedGold = patrimonyManager:formatGold(currentGold)

    -- Usa fonte menor para modo compacto
    love.graphics.setFont(fonts.main_small or fonts.main)

    -- Calcula dimensões
    local font = love.graphics.getFont()
    local textWidth = font:getWidth(formattedGold)
    local textHeight = font:getHeight()

    -- Padding interno
    local padding = 6
    local bgWidth = textWidth + padding * 2
    local bgHeight = textHeight + padding * 2

    -- Posição do fundo (alinhado à direita)
    local bgX = x - bgWidth
    local bgY = y - bgHeight / 2

    -- Desenha fundo semi-transparente
    love.graphics.setColor(colors.black_transparent_more or { 0, 0, 0, 0.6 })
    love.graphics.rectangle("fill", bgX, bgY, bgWidth, bgHeight, 4) -- Cantos arredondados

    -- Desenha borda dourada
    love.graphics.setColor(colors.text_gold)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", bgX, bgY, bgWidth, bgHeight, 4)

    -- Desenha texto
    local textX = bgX + padding
    local textY = bgY + padding

    -- Sombra
    love.graphics.setColor(colors.black or { 0, 0, 0, 1 })
    love.graphics.print(formattedGold, textX + 1, textY + 1)

    -- Texto principal
    love.graphics.setColor(colors.text_gold)
    love.graphics.print(formattedGold, textX, textY)

    -- Reset
    love.graphics.setLineWidth(1)
    love.graphics.setColor(colors.white)

    return bgWidth
end

return PatrimonyDisplay
