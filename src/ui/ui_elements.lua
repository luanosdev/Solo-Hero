local elements = {}
local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")
local glowShader = nil

-- Helper para formatar números (MOVIDO DE inventory_screen.lua)
function elements.formatNumber(num)
    num = math.floor(num or 0) -- Garante que seja um número inteiro
    if num < 1000 then
        return tostring(num)
    elseif num < 1000000 then
        return string.format("%.1fK", num / 1000):gsub("%.0K", "K")
    elseif num < 1000000000 then
        return string.format("%.1fM", num / 1000000):gsub("%.0M", "M")
    else
        return string.format("%.1fB", num / 1000000000):gsub("%.0B", "B")
    end
end

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
        local glowColor = { colors.window_border[1], colors.window_border[2], colors.window_border[3], 0.5 }
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

function elements.drawResourceBar(config)
    -- Valores padrão
    local defaults = {
        x = 0,
        y = 0,
        width = 100,
        height = 20,
        current = 0,
        max = 1,
        color = colors.hp_fill,
        bgColor = colors.bar_bg,
        borderColor = colors.bar_border,
        showText = false,
        textColor = colors.text_main,
        textFormat = "%d/%d",
        showShadow = true,
        shadowColor = { 0, 0, 0, 0.5 },
        segments = 0,
        segmentInterval = 0, -- Intervalo entre os segmentos (em unidades do recurso)
        segmentColor = nil,  -- Se nil, usa a cor da borda
        glow = false,
        glowColor = nil,
        glowRadius = 4.0,
        -- Configurações opcionais para largura dinâmica
        dynamicWidth = false, -- Ativa/desativa largura dinâmica
        baseWidth = 60,       -- Largura base da barra
        maxWidth = 120,       -- Largura máxima da barra
        scaleFactor = 0.5,    -- Fator de escala para o crescimento da barra
        minValue = 100,       -- Valor mínimo para começar a crescer
        maxValue = 2000       -- Valor máximo para parar de crescer
    }

    -- Mescla as configurações com os valores padrão
    config = setmetatable(config or {}, { __index = defaults })

    -- Garante que os valores sejam números válidos
    config.current = tonumber(config.current) or 0
    config.max = tonumber(config.max) or 1
    config.width = tonumber(config.width) or 100
    config.height = tonumber(config.height) or 20

    -- Garante que os valores estejam dentro de limites razoáveis
    config.current = math.max(0, math.min(config.current, config.max))
    config.max = math.max(1, config.max)

    -- Calcula a largura dinâmica se ativado
    if config.dynamicWidth then
        local valueScale = math.min(1, math.max(0, (config.max - config.minValue) / (config.maxValue - config.minValue)))
        local dynamicWidth = config.baseWidth + (config.maxWidth - config.baseWidth) * valueScale * config.scaleFactor
        config.width = dynamicWidth
    end

    -- Inicializa o cache para esta entidade se não existir
    local entityId = tostring(config.x) .. tostring(config.y)
    if not elements.lastHealth[entityId] then
        elements.lastHealth[entityId] = config.current
        elements.cacheHealth[entityId] = config.current
    end

    -- Atualiza o cache se a vida atual for menor que o cache
    if config.current < elements.cacheHealth[entityId] then
        elements.cacheHealth[entityId] = elements.cacheHealth[entityId] - elements.cacheSpeed
        if elements.cacheHealth[entityId] < config.current then
            elements.cacheHealth[entityId] = config.current
        end
    else
        elements.cacheHealth[entityId] = config.current
    end

    -- Atualiza o último valor de vida
    elements.lastHealth[entityId] = config.current

    -- Calcula as porcentagens
    local currentPercent = config.current / config.max
    local cachePercent = elements.cacheHealth[entityId] / config.max

    -- Desenha o fundo da barra
    love.graphics.setColor(config.bgColor[1], config.bgColor[2], config.bgColor[3], config.bgColor[4] or 1)
    love.graphics.rectangle("fill", config.x, config.y, config.width, config.height)

    -- Desenha a barra de cache (parte que diminui suavemente)
    local darkerColor = {
        config.color[1] * 0.4,
        config.color[2] * 0.4,
        config.color[3] * 0.4,
        (config.color[4] or 1) * 0.8
    }
    love.graphics.setColor(darkerColor)
    love.graphics.rectangle("fill", config.x, config.y, config.width * cachePercent, config.height)

    -- Desenha a barra de vida atual
    love.graphics.setColor(config.color[1], config.color[2], config.color[3], config.color[4] or 1)
    love.graphics.rectangle("fill", config.x, config.y, config.width * currentPercent, config.height)

    -- Desenha os segmentos se necessário
    if config.segments > 0 or config.segmentInterval > 0 then
        local segmentColor = config.segmentColor or config.borderColor
        love.graphics.setColor(segmentColor[1], segmentColor[2], segmentColor[3], segmentColor[4] or 1)

        if config.segments > 0 then
            -- Segmentos uniformemente distribuídos
            local segmentWidth = config.width / config.segments
            for i = 1, config.segments - 1 do
                local x = config.x + segmentWidth * i
                love.graphics.line(x, config.y, x, config.y + config.height / 2)
            end
        else
            -- Segmentos baseados no intervalo
            local segmentValue = config.segmentInterval
            while segmentValue < config.max do
                local segmentX = config.x + (segmentValue / config.max) * config.width
                love.graphics.line(segmentX, config.y, segmentX, config.y + config.height / 2)
                segmentValue = segmentValue + config.segmentInterval
            end
        end
    end

    -- Desenha a borda
    love.graphics.setColor(config.borderColor[1], config.borderColor[2], config.borderColor[3],
        config.borderColor[4] or 1)
    love.graphics.rectangle("line", config.x, config.y, config.width, config.height)

    -- Aplica o efeito de brilho se necessário
    if config.glow and glowShader then
        love.graphics.setShader(glowShader)
        local glowCol = config.glowColor or { config.color[1], config.color[2], config.color[3], 0.6 }
        glowShader:send("glowColor", glowCol)
        glowShader:send("glowRadius", config.glowRadius)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", config.x, config.y, config.width, config.height)
        love.graphics.setShader()
    end

    -- Desenha o texto se necessário
    if config.showText then
        local text = string.format(config.textFormat, config.current, config.max)
        local font = love.graphics.getFont()
        local textWidth = font:getWidth(text)
        local textHeight = font:getHeight()
        local textX = config.x + (config.width - textWidth) / 2
        local textY = config.y + (config.height - textHeight) / 2

        -- Desenha a sombra do texto se necessário
        if config.showShadow then
            love.graphics.setColor(config.shadowColor[1], config.shadowColor[2], config.shadowColor[3],
                config.shadowColor[4] or 1)
            love.graphics.print(text, textX + 1, textY + 1)
        end

        -- Desenha o texto principal
        love.graphics.setColor(config.textColor[1], config.textColor[2], config.textColor[3], config.textColor[4] or 1)
        love.graphics.print(text, textX, textY)
    end
end

function elements.drawRarityBorderAndGlow(itemRarity, x, y, w, h)
    local rarityColor = colors.rarity[itemRarity] or colors.rarity['E']

    if glowShader then
        love.graphics.setShader(glowShader)
        local glowCol = { rarityColor[1], rarityColor[2], rarityColor[3], 0.6 }
        glowShader:send("glowColor", glowCol)
        glowShader:send("glowRadius", 4.0)
        love.graphics.setLineWidth(5)
        love.graphics.rectangle("line", x, y, w, h, 3, 3)
        love.graphics.setShader()
    end

    love.graphics.setLineWidth(2)
    love.graphics.setColor(rarityColor[1], rarityColor[2], rarityColor[3], rarityColor[4])
    love.graphics.rectangle("line", x, y, w, h, 3, 3)
    love.graphics.setLineWidth(1)
end

-- Função HELPER para desenhar o FUNDO de um slot vazio (MOVIDO DE inventory_screen.lua)
function elements.drawEmptySlotBackground(slotX, slotY, slotW, slotH)
    love.graphics.setColor(colors.slot_empty_bg)
    love.graphics.rectangle("fill", slotX, slotY, slotW, slotH, 3, 3)
    love.graphics.setColor(colors.slot_empty_border)
    love.graphics.rectangle("line", slotX, slotY, slotW, slotH, 3, 3)
end

--- Desenha um botão de tabulação, com suporte a estado de hover e destaque.
---@param config table Tabela de configuração com os seguintes campos:
---   x (number): Posição X do botão.
---   y (number): Posição Y do botão.
---   w (number): Largura do botão.
---   h (number): Altura do botão.
---   text (string): Texto a ser exibido no botão.
---   isHovering (boolean): true se o mouse estiver sobre o botão.
---   highlighted (boolean): true se o botão deve ter a aparência de destaque.
---   font (Font): Objeto de fonte a ser usado para o texto.
---   colors (table): Tabela contendo as cores a serem usadas:
---   bgColor (table): Cor de fundo padrão {r, g, b}.
---   hoverColor (table): Cor de fundo ao passar o mouse {r, g, b}.
---   highlightedBgColor (table): Cor de fundo destacada {r, g, b}.
---   highlightedHoverColor (table): Cor de fundo destacada com hover {r, g, b}.
---   textColor (table): Cor do texto {r, g, b}.
---   borderColor (table|nil): Cor da borda opcional {r, g, b}. Se nil, sem borda.
function elements.drawTabButton(config)
    local currentBgColor
    -- Define a cor de fundo base (normal ou destacada)
    if config.highlighted then
        currentBgColor = config.isHovering and config.colors.highlightedHoverColor or config.colors.highlightedBgColor
    else
        currentBgColor = config.isHovering and config.colors.hoverColor or config.colors.bgColor
    end

    love.graphics.setColor(currentBgColor)
    love.graphics.rectangle("fill", config.x, config.y, config.w, config.h)

    -- Desenha borda se definida
    if config.colors.borderColor then
        love.graphics.setColor(config.colors.borderColor)
        love.graphics.rectangle("line", config.x, config.y, config.w, config.h)
    end

    -- Desenha o texto do tab centralizado
    local font = config.font or love.graphics.getFont()
    local fontHeight = font:getHeight()
    love.graphics.setFont(font)
    love.graphics.setColor(config.colors.textColor)
    love.graphics.printf(config.text, config.x, config.y + (config.h - fontHeight) / 2, config.w, "center")

    -- Importante: Resetar a fonte padrão depois, se necessário, ou garantir que a cena faça isso.
    -- love.graphics.setFont(fonts.main) -- Exemplo
end

--- Desenha um botão genérico com texto, suporte a hover e cores customizáveis.
---@param config table Tabela de configuração com os seguintes campos:
---   rect (table): Tabela com {x, y, w, h} para a posição e tamanho.
---   text (string): Texto a ser exibido no botão.
---   isHovering (boolean): Se o mouse está sobre o botão.
---   font (Font): Fonte a ser usada para o texto.
---   colors (table): Tabela opcional com cores:
---   bgColor (table): Cor de fundo normal.
---   hoverColor (table): Cor de fundo com hover.
---   textColor (table): Cor do texto.
---   borderColor (table): Cor da borda.
function elements.drawButton(config)
    local rect = config.rect
    local text = config.text or ""
    local isHovering = config.isHovering or false
    local font = config.font or love.graphics.getFont()
    local cols = config.colors or {}

    -- Define cores padrão se não fornecidas
    local bgColor = isHovering and (cols.hoverColor or colors.tab_hover) or (cols.bgColor or colors.tab_bg)
    local textColor = cols.textColor or colors.tab_text
    local borderColor = cols.borderColor or colors.tab_border

    -- Desenha o fundo
    love.graphics.setColor(bgColor)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 3, 3) -- Cantos levemente arredondados

    -- Desenha a borda
    love.graphics.setColor(borderColor)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 3, 3)

    -- Desenha o texto
    love.graphics.setFont(font)
    love.graphics.setColor(textColor)
    local textWidth = font:getWidth(text)
    local textHeight = font:getHeight()
    local textX = rect.x + (rect.w - textWidth) / 2
    local textY = rect.y + (rect.h - textHeight) / 2
    love.graphics.print(text, math.floor(textX), math.floor(textY)) -- Usa math.floor para evitar serrilhado
end

--- NOVO: Desenha um "fantasma" do item seguindo o mouse.
---@param x number Posição X do canto superior esquerdo do fantasma.
---@param y number Posição Y do canto superior esquerdo do fantasma.
---@param itemInstance table Instância do item a desenhar.
---@param alpha number Nível de transparência (0 a 1).
---@param isRotated boolean|nil Se o item deve ser desenhado rotacionado (90 graus).
function elements.drawItemGhost(x, y, itemInstance, alpha, isRotated)
    if not itemInstance then return end
    alpha = alpha or 0.75 -- Padrão para 75% de opacidade
    isRotated = isRotated or false

    -- Calcula dimensões visuais BASE originais baseado no grid
    local gridConfig = require("src.ui.item_grid_ui").__gridConfig -- Pode precisar ajustar acesso
    local slotSize = (gridConfig and gridConfig.slotSize or 48)
    local padding = (gridConfig and gridConfig.padding or 5)
    local slotTotalWidth = slotSize + padding
    local slotTotalHeight = slotSize + padding

    local originalGridW = itemInstance.gridWidth or 1
    local originalGridH = itemInstance.gridHeight or 1

    local baseVisualW = originalGridW * slotTotalWidth - padding
    local baseVisualH = originalGridH * slotTotalHeight - padding

    -- Ajusta dimensões visuais se rotacionado
    local visualW = isRotated and baseVisualH or baseVisualW
    local visualH = isRotated and baseVisualW or baseVisualH

    -- 1. Desenha um fundo semi-transparente
    love.graphics.setColor(0, 0, 0, alpha * 0.5) -- Preto com metade da opacidade do item
    love.graphics.rectangle("fill", x, y, visualW, visualH, 3, 3)

    -- 2. Desenha o ícone com a transparência principal e rotação
    love.graphics.setColor(1, 1, 1, alpha)
    local iconToDraw = itemInstance.icon
    if iconToDraw and type(iconToDraw) == "userdata" and iconToDraw:typeOf("Image") then
        local originalW = iconToDraw:getWidth()
        local originalH = iconToDraw:getHeight()

        -- Calcula a escala necessária para preencher baseVisualW e baseVisualH (dimensões originais do ícone)
        local scaleX = baseVisualW / originalW
        local scaleY = baseVisualH / originalH

        -- Calcula o centro para rotação e o deslocamento para desenhar no lugar certo
        local centerX = visualW / 2
        local centerY = visualH / 2
        local drawX = x + centerX
        local drawY = y + centerY
        local rotationAngle = isRotated and math.pi / 2 or 0

        -- Desenha a imagem escalonada, rotacionada e centralizada na posição x, y
        love.graphics.draw(iconToDraw, drawX, drawY, rotationAngle, scaleX, scaleY, originalW / 2, originalH / 2)
    else
        -- Fallback: Desenha letra do nome (a rotação aqui não é aplicada visualmente)
        local placeholderText = itemInstance.name and string.sub(itemInstance.name, 1, 1) or "?"
        local fnt = fonts.title or love.graphics.getFont()
        local oldFnt = love.graphics.getFont()
        love.graphics.setFont(fnt)
        love.graphics.printf(placeholderText, x, y + visualH * 0.1, visualW, "center")
        love.graphics.setFont(oldFnt)
    end

    -- 3. Desenha a borda da raridade (com as dimensões corretas)
    local rarity = itemInstance.rarity or 'E'
    elements.drawRarityBorderAndGlow(rarity, x, y, visualW, visualH, alpha)

    love.graphics.setColor(1, 1, 1, 1) -- Reseta cor
end

--- NOVO: Desenha um indicador de slot alvo para o drop.
---@param areaX, areaY, areaW, areaH number Área da grade alvo.
---@param gridRows, gridCols number Dimensões da grade alvo.
---@param targetRow, targetCol number Coordenadas do slot alvo.
---@param itemW, itemH number Dimensões do item (em slots).
---@param isValid boolean Se o drop na posição é válido.
function elements.drawDropIndicator(areaX, areaY, areaW, areaH, gridRows, gridCols, targetRow, targetCol, itemW, itemH,
                                    isValid)
    -- Calcula posição/dimensões da grade
    local gridConfig = require("src.ui.item_grid_ui").__gridConfig
    local slotSize = (gridConfig and gridConfig.slotSize or 48)
    local padding = (gridConfig and gridConfig.padding or 5)
    local slotTotalWidth = slotSize + padding
    local slotTotalHeight = slotSize + padding
    local gridTotalWidth = gridCols * slotTotalWidth - padding
    local gridTotalHeight = gridRows * slotTotalHeight - padding
    local startX = areaX + (areaW - gridTotalWidth) / 2
    local startY = areaY

    -- Calcula retângulo do indicador
    local indicatorX = startX + (targetCol - 1) * slotTotalWidth
    local indicatorY = startY + (targetRow - 1) * slotTotalHeight
    local indicatorW = itemW * slotTotalWidth - padding
    local indicatorH = itemH * slotTotalHeight - padding

    -- Define a cor baseada na validade
    local color = isValid and colors.placement_valid or colors.placement_invalid
    if not color then
        color = isValid and { 0, 1, 0 } or { 1, 0, 0 } -- Fallback Verde/Vermelho
    end

    -- Desenha o retângulo semi-transparente
    love.graphics.setColor(color[1], color[2], color[3], 0.5) -- 50% alpha
    love.graphics.rectangle("fill", indicatorX, indicatorY, indicatorW, indicatorH, 3, 3)
    love.graphics.setColor(1, 1, 1, 1)                        -- Reseta cor
end

--- NOVO: Desenha uma caixa de tooltip com várias linhas de texto coloridas.
---@param x number Posição X do canto superior esquerdo do tooltip.
---@param y number Posição Y do canto superior esquerdo do tooltip.
---@param lines table Tabela de linhas, onde cada linha é { text = "...", color = {r,g,b,a} }.
function elements.drawTooltipBox(x, y, lines)
    if not lines or #lines == 0 then return end

    local tooltipFont = fonts.tooltip or fonts.main_small or love.graphics.getFont()
    local padding = 8
    local lineHeight = tooltipFont:getHeight() * 1.1
    local maxWidth = 0
    local totalHeight = padding * 2 + (#lines * lineHeight) - (lineHeight * 0.1) -- Ajusta altura total

    -- Calcula a largura máxima necessária
    love.graphics.setFont(tooltipFont)
    for _, line in ipairs(lines) do
        maxWidth = math.max(maxWidth, tooltipFont:getWidth(line.text))
    end
    local totalWidth = padding * 2 + maxWidth

    -- Ajusta posição para não sair da tela (simples)
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    if x + totalWidth > screenW then
        x = screenW - totalWidth
    end
    if y + totalHeight > screenH then
        y = screenH - totalHeight
    end
    x = math.max(0, x) -- Garante que não saia pela esquerda
    y = math.max(0, y) -- Garante que não saia por cima

    -- Desenha fundo
    local bgColor = colors.window_bg or { 0.1, 0.1, 0.15, 0.95 }
    love.graphics.setColor(bgColor)
    love.graphics.rectangle("fill", x, y, totalWidth, totalHeight, 3, 3)

    -- Desenha borda
    local borderColor = colors.window_border or { 0.4, 0.45, 0.5, 0.8 }
    love.graphics.setLineWidth(1)
    love.graphics.setColor(borderColor)
    love.graphics.rectangle("line", x, y, totalWidth, totalHeight, 3, 3)

    -- Desenha as linhas de texto
    local currentY = y + padding
    for _, line in ipairs(lines) do
        local lineX = x + padding
        local lineColor = line.color or colors.text_main or { 1, 1, 1, 1 }
        love.graphics.setColor(lineColor)
        love.graphics.print(line.text, lineX, math.floor(currentY))
        currentY = currentY + lineHeight
    end

    love.graphics.setColor(1, 1, 1, 1) -- Reset
end

return elements
