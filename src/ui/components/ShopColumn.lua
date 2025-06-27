local fonts = require("src.ui.fonts")
local colors = require("src.ui.colors")
local elements = require("src.ui.ui_elements")
local Formatters = require("src.utils.formatters")

---@class ShopColumn
local ShopColumn = {}

--- Desenha a coluna da loja
---@param x number Posição X da coluna
---@param y number Posição Y da coluna
---@param w number Largura da coluna
---@param h number Altura da coluna
---@param shopManager ShopManager Gerenciador da loja
---@param itemDataManager ItemDataManager Gerenciador de dados dos itens
---@param mx number Posição X do mouse
---@param my number Posição Y do mouse
function ShopColumn.draw(x, y, w, h, shopManager, itemDataManager, mx, my)
    local currentShop = shopManager:getCurrentShop()
    if not currentShop then
        love.graphics.setColor(colors.text_default)
        love.graphics.printf("Nenhuma loja disponível", x, y + h / 2, w, "center")
        return
    end

    -- Desenha fundo da coluna (sem borda)
    love.graphics.setColor(colors.lobby_background)
    love.graphics.rectangle("fill", x, y, w, h)

    local padding = 10
    local currentY = y + padding

    -- Header da loja
    love.graphics.setFont(fonts.title)
    love.graphics.setColor(colors.text_highlight)
    love.graphics.printf(currentShop.name, x + padding, currentY, w - padding * 2, "center")
    currentY = currentY + fonts.title:getHeight() + padding

    -- Timer de atualização
    local timeLeft = currentShop.timeUntilRefresh
    local minutes = math.floor(timeLeft / 60)
    local seconds = math.floor(timeLeft % 60)
    local timeText = string.format("Atualiza em: %02d:%02d", minutes, seconds)

    love.graphics.setFont(fonts.main_small or love.graphics.newFont(12))
    love.graphics.setColor(colors.text_default)
    love.graphics.printf(timeText, x + padding, currentY, w - padding * 2, "center")
    currentY = currentY + (fonts.main_small and fonts.main_small:getHeight() or 12) + padding

    -- Botão "Vender Tudo"
    local sellButtonH = 30
    local sellButtonY = currentY
    local isHoveringSellButton = mx >= x + padding and mx <= x + w - padding and
        my >= sellButtonY and my <= sellButtonY + sellButtonH

    local sellButtonColor = isHoveringSellButton and colors.button_primary.hoverColor or colors.button_primary.bgColor
    love.graphics.setColor(sellButtonColor)
    love.graphics.rectangle("fill", x + padding, sellButtonY, w - padding * 2, sellButtonH)

    love.graphics.setColor(colors.text_default)
    love.graphics.setFont(fonts.main or love.graphics.newFont(14))
    love.graphics.printf("Vender Tudo do Loadout", x + padding, sellButtonY + sellButtonH / 2 - 7,
        w - padding * 2, "center")

    currentY = currentY + sellButtonH + padding * 2

    -- Desenha seção de itens em promoção (duas colunas, como itens normais)
    if #currentShop.featuredItems > 0 then
        love.graphics.setColor(colors.text_highlight)
        love.graphics.printf("🌟 PROMOÇÕES 🌟", x + padding, currentY, w - padding * 2, "center")
        currentY = currentY + 20 + padding / 2

        -- Layout de duas colunas para promoções
        local itemsPerRow = 2
        local cardWidth = (w - padding * 2 - padding) / 2
        local cardHeight = 80 -- Mesma altura dos cards normais
        local itemSpacing = padding

        for i, item in ipairs(currentShop.featuredItems) do
            local row = math.floor((i - 1) / itemsPerRow)
            local col = (i - 1) % itemsPerRow

            local itemX = x + padding + col * (cardWidth + itemSpacing)
            local itemY = currentY + row * (cardHeight + itemSpacing)

            if itemY + cardHeight > y + h then break end -- Não desenha se sair da área

            ShopColumn.drawShopItem(
                itemX,
                itemY,
                cardWidth,
                cardHeight,
                item,
                itemDataManager,
                mx,
                my,
                true
            )
        end

        -- Calcula quantas linhas foram usadas
        local numRows = math.ceil(#currentShop.featuredItems / itemsPerRow)
        currentY = currentY + numRows * (cardHeight + itemSpacing) + padding
    end

    -- Desenha seção de itens normais (duas colunas, cards menores)
    if #currentShop.items > 0 then
        love.graphics.setColor(colors.text_highlight)
        love.graphics.printf("ITENS DISPONÍVEIS", x + padding, currentY, w - padding * 2, "center")
        currentY = currentY + 20 + padding / 2

        -- Layout de duas colunas
        local itemsPerRow = 2
        local cardWidth = (w - padding * 2 - padding) / 2 -- Espaço entre as duas colunas
        local cardHeight = 80                             -- Mesma altura dos cards promocionais
        local itemSpacing = padding

        for i, item in ipairs(currentShop.items) do
            local row = math.floor((i - 1) / itemsPerRow)
            local col = (i - 1) % itemsPerRow

            local itemX = x + padding + col * (cardWidth + itemSpacing)
            local itemY = currentY + row * (cardHeight + itemSpacing)

            if itemY + cardHeight > y + h then break end -- Não desenha se sair da área

            ShopColumn.drawShopItem(
                itemX,
                itemY,
                cardWidth,
                cardHeight,
                item,
                itemDataManager,
                mx,
                my,
                false
            )
        end
    end

    love.graphics.setColor(colors.white)
end

--- Desenha texto com sombra (copiado do lobby_navbar para consistência)
---@param text string
---@param x number
---@param y number
---@param textColor table
---@param shadowColor table
---@param shadowOffset number
local function drawTextWithShadow(text, x, y, textColor, shadowColor, shadowOffset)
    shadowOffset = shadowOffset or 1

    -- Sombra
    love.graphics.setColor(shadowColor)
    love.graphics.print(text, x + shadowOffset, y + shadowOffset)

    -- Texto principal
    love.graphics.setColor(textColor)
    love.graphics.print(text, x, y)
end

--- Desenha um item individual da loja
---@param x number Posição X do item
---@param y number Posição Y do item
---@param w number Largura do item
---@param h number Altura do item
---@param shopItem ShopItem Item da loja
---@param itemDataManager ItemDataManager Gerenciador de dados dos itens
---@param mx number Posição X do mouse
---@param my number Posição Y do mouse
---@param isPromotion boolean Se é um item em promoção
function ShopColumn.drawShopItem(x, y, w, h, shopItem, itemDataManager, mx, my, isPromotion)
    local isHovering = mx >= x and mx <= x + w and my >= y and my <= y + h
    local baseData = itemDataManager:getBaseItemData(shopItem.itemId)

    if not baseData then return end

    -- Obtém cor do ranking
    local rarity = baseData.rarity or 'E'
    local rankColor = colors.rankDetails[rarity].text
    local rankGradientStart = colors.rankDetails[rarity].gradientStart
    local rankGradientEnd = colors.rankDetails[rarity].gradientEnd

    -- Verifica se item está esgotado
    local isOutOfStock = shopItem.stock <= 0

    -- Cor de fundo baseada na cor do ranking (mais transparente)
    local bgColor = { rankGradientStart[1], rankGradientStart[2], rankGradientStart[3], 0.15 }
    if isOutOfStock then
        -- Item esgotado fica 50% mais transparente
        bgColor = { rankGradientStart[1], rankGradientStart[2], rankGradientStart[3], 0.075 }
    elseif isPromotion then
        bgColor = { rankGradientStart[1], rankGradientStart[2], rankGradientStart[3], 1 }
    end
    if isHovering and not isOutOfStock then
        bgColor = { rankGradientEnd[1], rankGradientEnd[2], rankGradientEnd[3], 0.3 }
    end

    -- Padding vertical interno
    local verticalPadding = 8
    local innerY = y + verticalPadding
    local innerH = h - (verticalPadding * 2)

    -- Animação de sombra para itens em promoção
    if isPromotion then
        local time = love.timer.getTime()
        local pulseIntensity = (math.sin(time * 3) + 1) * 0.3 + 0.4 -- Varia entre 0.4 e 1.0
        local shadowSize = 2

        -- Sombra animada colorida
        local shadowColor = {
            colors.text_gold[1],
            colors.text_gold[2],
            colors.text_gold[3],
            pulseIntensity * 0.6
        }

        love.graphics.setColor(shadowColor)
        love.graphics.rectangle("fill", x - shadowSize, y - shadowSize, w + shadowSize * 2, h + shadowSize * 2)
    end

    -- Desenha fundo do item
    love.graphics.setColor(bgColor)
    love.graphics.rectangle("fill", x, y, w, h)

    -- Desenha borda vertical (como citação) com cor do ranking
    local borderWidth = 4
    local borderColor = isPromotion and colors.text_gold or rankColor
    if isOutOfStock then
        -- Borda mais transparente para itens esgotados
        borderColor = { borderColor[1], borderColor[2], borderColor[3], 0.5 }
    end
    love.graphics.setColor(borderColor)
    love.graphics.rectangle("fill", x, y, borderWidth, h)

    -- Layout: [Ícone] [Info central] [Preço direita centralizado]
    local iconSize = math.min(innerH, innerH - 10) -- Máximo 80% da altura do card interno
    local iconX = x + borderWidth + 8
    local iconY = innerY + (innerH - iconSize) / 2 -- Centraliza verticalmente no espaço interno

    -- Desenha ícone do item
    local itemColor = isOutOfStock and { 1, 1, 1, 0.5 } or { 1, 1, 1, 1 }
    if baseData.icon and type(baseData.icon) == "userdata" then
        local icon = baseData.icon
        local iw, ih = icon:getDimensions()
        local scale = math.min(iconSize / iw, iconSize / ih)
        local drawW, drawH = iw * scale, ih * scale
        local drawX = iconX + (iconSize - drawW) / 2
        local drawY = iconY + (iconSize - drawH) / 2

        love.graphics.setColor(itemColor)
        love.graphics.draw(icon, drawX, drawY, 0, scale, scale)
    else
        -- Placeholder se não houver ícone
        local placeholderColor = isOutOfStock and { rankColor[1], rankColor[2], rankColor[3], 0.5 } or rankColor
        love.graphics.setColor(placeholderColor)
        love.graphics.rectangle("fill", iconX, iconY, iconSize, iconSize)
        love.graphics.setColor(colors.tab_border)
        love.graphics.rectangle("line", iconX, iconY, iconSize, iconSize)

        -- Primeira letra do nome como placeholder
        love.graphics.setFont(fonts.title)
        love.graphics.setColor(isOutOfStock and { 1, 1, 1, 0.5 } or colors.white)
        local placeholderText = baseData.name and string.sub(baseData.name, 1, 1) or "?"
        love.graphics.printf(placeholderText, iconX, iconY + iconSize / 2 - fonts.title:getHeight() / 2, iconSize,
            "center")
    end

    -- Área de informações central
    local infoX = iconX + iconSize + 10
    local infoW = w * 0.8 -- 80% da largura para info
    local infoY = innerY + 5

    -- Nome do item com cor do ranking e fonte em bold
    love.graphics.setFont(fonts.main_large) -- Fonte bold para nomes dos itens
    local nameColor = isOutOfStock and { rankColor[1], rankColor[2], rankColor[3], 0.5 } or rankColor
    love.graphics.setColor(nameColor)
    love.graphics.printf(baseData.name or shopItem.itemId, infoX, infoY, infoW, "left")

    -- Porcentagem de desconto para itens em promoção
    if isPromotion and shopItem.isOnSale and shopItem.salePrice then
        local originalPrice = shopItem.price
        local salePrice = shopItem.salePrice
        local discountPercent = math.floor((1 - salePrice / originalPrice) * 100)

        local discountY = infoY + (fonts.main_bold or fonts.main):getHeight() + 2
        love.graphics.setFont(fonts.main_small)
        love.graphics.setColor(colors.text_gold)
        love.graphics.printf("-" .. discountPercent .. "%", infoX, discountY, infoW, "left")
    end

    -- Área do preço à direita (centralizada verticalmente, máximo 80% do card interno)
    local priceAreaMaxHeight = innerH * 0.8
    local priceX = x + w * 0.6 -- Últimos 40% da largura
    local priceW = w * 0.35

    -- Centraliza verticalmente o preço no espaço interno
    local priceAreaY = innerY + (innerH - priceAreaMaxHeight) / 2
    local priceCenterY = priceAreaY + priceAreaMaxHeight / 2

    -- Estilo do patrimônio: fonte resource_value com sombra
    love.graphics.setFont(fonts.resource_value or fonts.main_large)
    local shadowColor = colors.black_transparent_more or { 0, 0, 0, 0.7 }
    local priceColor = isOutOfStock and { colors.text_gold[1], colors.text_gold[2], colors.text_gold[3], 0.5 } or
        colors.text_gold

    local priceText, finalPriceY
    if shopItem.isOnSale and shopItem.salePrice then
        -- Preço original riscado (menor, acima do preço promocional)
        love.graphics.setFont(fonts.main_small)
        local originalPriceText = Formatters.formatCompactNumber(shopItem.price)
        originalPriceText = "R$ " .. originalPriceText
        local originalTextWidth = fonts.main_small:getWidth(originalPriceText)
        local originalPriceX = priceX + priceW - originalTextWidth
        local originalPriceY = priceCenterY - 25

        local originalColor = isOutOfStock and
            { colors.text_default[1], colors.text_default[2], colors.text_default[3], 0.5 } or colors.text_default
        love.graphics.setColor(originalColor)
        love.graphics.print(originalPriceText, originalPriceX, originalPriceY)
        -- Linha riscando o preço original
        love.graphics.line(originalPriceX, originalPriceY + 7, originalPriceX + originalTextWidth, originalPriceY + 7)

        -- Preço em promoção (centralizado, abaixo do preço original)
        love.graphics.setFont(fonts.resource_value or fonts.main_large)
        priceText = Formatters.formatCompactNumber(shopItem.salePrice)
        priceText = "R$ " .. priceText
        local priceHeight = (fonts.resource_value or fonts.main_large):getHeight()
        finalPriceY = priceCenterY - 15

        local textWidth = (fonts.resource_value or fonts.main_large):getWidth(priceText)
        local finalPriceX = priceX + priceW - textWidth

        if not isOutOfStock then
            drawTextWithShadow(priceText, finalPriceX, finalPriceY, priceColor, shadowColor, 1)
        else
            love.graphics.setColor(priceColor)
            love.graphics.print(priceText, finalPriceX, finalPriceY)
        end
    else
        -- Preço normal (centralizado)
        priceText = Formatters.formatCompactNumber(shopItem.price)
        priceText = "R$ " .. priceText
        local priceHeight = (fonts.resource_value or fonts.main_large):getHeight()
        finalPriceY = priceCenterY - priceHeight / 2

        local textWidth = (fonts.resource_value or fonts.main_large):getWidth(priceText)
        local finalPriceX = priceX + priceW - textWidth

        if not isOutOfStock then
            drawTextWithShadow(priceText, finalPriceX, finalPriceY, priceColor, shadowColor, 1)
        else
            love.graphics.setColor(priceColor)
            love.graphics.print(priceText, finalPriceX, finalPriceY)
        end
    end

    -- Texto de estoque embaixo do preço
    love.graphics.setFont(fonts.main_small)
    local stockColor = isOutOfStock and colors.text_gold or colors.text_default

    local stockText
    if shopItem.stock <= 0 then
        stockText = "Esgotado!"
    elseif shopItem.stock == 1 then
        stockColor = colors.text_gold
        stockText = "Último restante!"
    else
        stockText = "Restam " .. shopItem.stock
    end

    love.graphics.setColor(stockColor)
    local stockWidth = fonts.main_small:getWidth(stockText)
    local stockX = priceX + priceW - stockWidth
    local stockY = finalPriceY + (fonts.resource_value or fonts.main_large):getHeight() - 5
    love.graphics.print(stockText, stockX, stockY)

    love.graphics.setColor(colors.white)
end

--- Verifica se o mouse está sobre um item específico
---@param x number Posição X do mouse
---@param y number Posição Y do mouse
---@param shopArea table Área da loja {x, y, w, h}
---@param shopManager ShopManager Gerenciador da loja
---@return ShopItem|nil item Item clicado se houver
function ShopColumn.getItemAtPosition(x, y, shopArea, shopManager)
    if not shopArea or not shopArea.y or not shopManager then return nil end

    local currentShop = shopManager:getCurrentShop()
    if not currentShop then return nil end

    local padding = 10
    -- Replica exatamente a mesma lógica da função draw()
    local currentY = shopArea.y + padding

    -- Header da loja (título)
    currentY = currentY + fonts.title:getHeight() + padding

    -- Timer de atualização
    currentY = currentY + (fonts.main_small and fonts.main_small:getHeight() or 12) + padding

    -- Verifica botão "Vender Tudo"
    local sellButtonY = currentY
    if x >= shopArea.x + padding and x <= shopArea.x + shopArea.w - padding and
        y >= sellButtonY and y <= sellButtonY + 30 then
        return { action = "sell_all" }
    end

    currentY = currentY + 30 + padding * 2

    -- Verifica itens em promoção (layout de duas colunas)
    if #currentShop.featuredItems > 0 then
        currentY = currentY + 20 + padding / 2

        local itemsPerRow = 2
        local cardWidth = (shopArea.w - padding * 2 - padding) / 2
        local cardHeight = 80
        local itemSpacing = padding

        for i, item in ipairs(currentShop.featuredItems) do
            local row = math.floor((i - 1) / itemsPerRow)
            local col = (i - 1) % itemsPerRow

            local itemX = shopArea.x + padding + col * (cardWidth + itemSpacing)
            local itemY = currentY + row * (cardHeight + itemSpacing)

            if y >= itemY and y <= itemY + cardHeight and
                x >= itemX and x <= itemX + cardWidth then
                return item
            end
        end

        local numRows = math.ceil(#currentShop.featuredItems / itemsPerRow)
        currentY = currentY + numRows * (cardHeight + itemSpacing) + padding
    end

    -- Verifica itens normais (layout de duas colunas)
    if #currentShop.items > 0 then
        currentY = currentY + 20 + padding / 2

        local itemsPerRow = 2
        local cardWidth = (shopArea.w - padding * 2 - padding) / 2
        local cardHeight = 80 -- Deve corresponder ao valor usado na função draw
        local itemSpacing = padding

        for i, item in ipairs(currentShop.items) do
            local row = math.floor((i - 1) / itemsPerRow)
            local col = (i - 1) % itemsPerRow

            local itemX = shopArea.x + padding + col * (cardWidth + itemSpacing)
            local itemY = currentY + row * (cardHeight + itemSpacing)

            if y >= itemY and y <= itemY + cardHeight and
                x >= itemX and x <= itemX + cardWidth then
                return item
            end
        end
    end

    return nil
end

--- Verifica se o mouse está sobre um item específico (para tooltip/modal)
---@param x number Posição X do mouse
---@param y number Posição Y do mouse
---@param shopArea table Área da loja {x, y, w, h}
---@param shopManager ShopManager Gerenciador da loja
---@return ShopItem|nil item Item para mostrar tooltip
function ShopColumn.getItemForTooltip(x, y, shopArea, shopManager)
    -- Usa a mesma lógica de getItemAtPosition, mas ignora o botão "Vender Tudo"
    if not shopArea or not shopArea.y or not shopManager then return nil end

    local currentShop = shopManager:getCurrentShop()
    if not currentShop then return nil end

    local padding = 10
    -- Replica exatamente a mesma lógica da função draw()
    local currentY = shopArea.y + padding

    -- Header da loja (título)
    currentY = currentY + fonts.title:getHeight() + padding

    -- Timer de atualização
    currentY = currentY + (fonts.main_small and fonts.main_small:getHeight() or 12) + padding

    -- Pula o botão "Vender Tudo" (não detecta hover)
    currentY = currentY + 30 + padding * 2

    -- Verifica itens em promoção (layout de duas colunas)
    if #currentShop.featuredItems > 0 then
        currentY = currentY + 20 + padding / 2

        local itemsPerRow = 2
        local cardWidth = (shopArea.w - padding * 2 - padding) / 2
        local cardHeight = 80
        local itemSpacing = padding

        for i, item in ipairs(currentShop.featuredItems) do
            local row = math.floor((i - 1) / itemsPerRow)
            local col = (i - 1) % itemsPerRow

            local itemX = shopArea.x + padding + col * (cardWidth + itemSpacing)
            local itemY = currentY + row * (cardHeight + itemSpacing)

            if y >= itemY and y <= itemY + cardHeight and
                x >= itemX and x <= itemX + cardWidth then
                return item
            end
        end

        local numRows = math.ceil(#currentShop.featuredItems / itemsPerRow)
        currentY = currentY + numRows * (cardHeight + itemSpacing) + padding
    end

    -- Verifica itens normais (layout de duas colunas)
    if #currentShop.items > 0 then
        currentY = currentY + 20 + padding / 2

        local itemsPerRow = 2
        local cardWidth = (shopArea.w - padding * 2 - padding) / 2
        local cardHeight = 80 -- Deve corresponder ao valor usado na função draw
        local itemSpacing = padding

        for i, item in ipairs(currentShop.items) do
            local row = math.floor((i - 1) / itemsPerRow)
            local col = (i - 1) % itemsPerRow

            local itemX = shopArea.x + padding + col * (cardWidth + itemSpacing)
            local itemY = currentY + row * (cardHeight + itemSpacing)

            if y >= itemY and y <= itemY + cardHeight and
                x >= itemX and x <= itemX + cardWidth then
                return item
            end
        end
    end

    return nil
end

return ShopColumn
