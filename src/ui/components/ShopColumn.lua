local fonts = require("src.ui.fonts")
local colors = require("src.ui.colors")
local elements = require("src.ui.ui_elements")

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

    -- Desenha borda da coluna
    love.graphics.setColor(colors.tab_border)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h)
    love.graphics.setLineWidth(1)

    -- Desenha fundo da coluna
    love.graphics.setColor(colors.lobby_background)
    love.graphics.rectangle("fill", x + 1, y + 1, w - 2, h - 2)

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

    -- Desenha seção de itens em promoção
    if #currentShop.featuredItems > 0 then
        love.graphics.setColor(colors.text_highlight)
        love.graphics.printf("🌟 PROMOÇÕES 🌟", x + padding, currentY, w - padding * 2, "center")
        currentY = currentY + 20 + padding / 2

        -- Desenha itens em promoção
        for i, item in ipairs(currentShop.featuredItems) do
            local itemY = currentY + (i - 1) * 80
            if itemY + 80 > y + h then break end -- Não desenha se sair da área

            ShopColumn.drawShopItem(
                x + padding,
                itemY,
                w - padding * 2,
                75,
                item,
                itemDataManager,
                mx,
                my,
                true
            )
        end
        currentY = currentY + #currentShop.featuredItems * 80 + padding
    end

    -- Desenha seção de itens normais
    if #currentShop.items > 0 then
        love.graphics.setColor(colors.text_highlight)
        love.graphics.printf("ITENS DISPONÍVEIS", x + padding, currentY, w - padding * 2, "center")
        currentY = currentY + 20 + padding / 2

        -- Desenha itens normais
        for i, item in ipairs(currentShop.items) do
            local itemY = currentY + (i - 1) * 70
            if itemY + 70 > y + h then break end -- Não desenha se sair da área

            ShopColumn.drawShopItem(
                x + padding,
                itemY,
                w - padding * 2,
                65,
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

    -- Cor de fundo baseada na cor do ranking (mais transparente)
    local bgColor = { rankGradientStart[1], rankGradientStart[2], rankGradientStart[3], 0.15 }
    if isPromotion then
        bgColor = { rankGradientStart[1], rankGradientStart[2], rankGradientStart[3], 0.25 }
    end
    if isHovering then
        bgColor = { rankGradientEnd[1], rankGradientEnd[2], rankGradientEnd[3], 0.3 }
    end

    -- Desenha fundo do item
    love.graphics.setColor(bgColor)
    love.graphics.rectangle("fill", x, y, w, h)

    -- Desenha borda vertical (como citação) com cor do ranking
    local borderWidth = 4
    local borderColor = isPromotion and colors.text_gold or rankColor
    love.graphics.setColor(borderColor)
    love.graphics.rectangle("fill", x, y, borderWidth, h)

    -- Layout: [Ícone 60px] [Info central] [Preço direita]
    local iconSize = h - 10
    local iconX = x + borderWidth + 8 -- Espaçamento após borda vertical
    local iconY = y + 5

    -- Desenha ícone do item
    if baseData.icon and type(baseData.icon) == "userdata" then
        local icon = baseData.icon
        local iw, ih = icon:getDimensions()
        local scale = math.min(iconSize / iw, iconSize / ih)
        local drawW, drawH = iw * scale, ih * scale
        local drawX = iconX + (iconSize - drawW) / 2
        local drawY = iconY + (iconSize - drawH) / 2

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(icon, drawX, drawY, 0, scale, scale)
    else
        -- Placeholder se não houver ícone
        love.graphics.setColor(rankColor)
        love.graphics.rectangle("fill", iconX, iconY, iconSize, iconSize)
        love.graphics.setColor(colors.tab_border)
        love.graphics.rectangle("line", iconX, iconY, iconSize, iconSize)

        -- Primeira letra do nome como placeholder
        love.graphics.setFont(fonts.title)
        love.graphics.setColor(colors.white)
        local placeholderText = baseData.name and string.sub(baseData.name, 1, 1) or "?"
        love.graphics.printf(placeholderText, iconX, iconY + iconSize / 2 - fonts.title:getHeight() / 2, iconSize,
            "center")
    end

    -- Área de informações central
    local infoX = iconX + iconSize + 10
    local infoW = w - iconSize - 120 -- Deixa espaço para o preço
    local infoY = y + 5

    -- Nome do item com cor do ranking
    love.graphics.setFont(fonts.main)
    love.graphics.setColor(rankColor)
    love.graphics.printf(baseData.name or shopItem.itemId, infoX, infoY, infoW, "left")

    -- Estoque na segunda linha
    infoY = infoY + fonts.main:getHeight() + 5
    love.graphics.setFont(fonts.main_small)
    love.graphics.setColor(colors.text_default)
    love.graphics.printf("Estoque: " .. shopItem.stock, infoX, infoY, infoW, "left")

    -- Área do preço à direita (seguindo padrão do patrimônio)
    local priceX = x + w - 110
    local priceW = 100
    local priceY = y + 8

    -- Estilo do patrimônio: fonte resource_value com sombra
    love.graphics.setFont(fonts.resource_value or fonts.main_large)
    local shadowColor = colors.black_transparent_more or { 0, 0, 0, 0.7 }

    if shopItem.isOnSale and shopItem.salePrice then
        -- Preço original riscado (menor, sem sombra)
        love.graphics.setFont(fonts.main_small)
        love.graphics.setColor(colors.text_default)
        local originalPriceText = shopItem.price .. "G"
        local originalTextWidth = fonts.main_small:getWidth(originalPriceText)
        local originalPriceX = priceX + priceW - originalTextWidth
        love.graphics.print(originalPriceText, originalPriceX, priceY - 5)
        -- Linha riscando o preço original
        love.graphics.line(originalPriceX, priceY, originalPriceX + originalTextWidth, priceY)

        -- Preço em promoção (estilo patrimônio)
        love.graphics.setFont(fonts.resource_value or fonts.main_large)
        local salePriceText = shopItem.salePrice .. "G"
        local saleTextWidth = (fonts.resource_value or fonts.main_large):getWidth(salePriceText)
        local salePriceX = priceX + priceW - saleTextWidth
        drawTextWithShadow(salePriceText, salePriceX, priceY + 12, colors.text_gold, shadowColor, 1)
    else
        -- Preço normal (estilo patrimônio)
        local priceText = shopItem.price .. "G"
        local textWidth = (fonts.resource_value or fonts.main_large):getWidth(priceText)
        local finalPriceX = priceX + priceW - textWidth
        drawTextWithShadow(priceText, finalPriceX, priceY + 8, colors.text_gold, shadowColor, 1)
    end

    -- Quantidade atual/restante embaixo do preço
    love.graphics.setFont(fonts.main_small)
    love.graphics.setColor(colors.text_default)
    local quantityText = "Restante: " .. shopItem.stock
    local quantityWidth = fonts.main_small:getWidth(quantityText)
    local quantityX = priceX + priceW - quantityWidth
    local quantityY = y + h - fonts.main_small:getHeight() - 5
    love.graphics.print(quantityText, quantityX, quantityY)

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
    local currentY = shopArea.y + padding + 60 -- Após header

    -- Verifica botão "Vender Tudo"
    local sellButtonY = currentY
    if x >= shopArea.x + padding and x <= shopArea.x + shopArea.w - padding and
        y >= sellButtonY and y <= sellButtonY + 30 then
        return { action = "sell_all" }
    end

    currentY = currentY + 30 + padding * 2

    -- Verifica itens em promoção
    if #currentShop.featuredItems > 0 then
        currentY = currentY + 20 + padding / 2

        for i, item in ipairs(currentShop.featuredItems) do
            local itemY = currentY + (i - 1) * 80
            if y >= itemY and y <= itemY + 75 and
                x >= shopArea.x + padding and x <= shopArea.x + shopArea.w - padding then
                return item
            end
        end
        currentY = currentY + #currentShop.featuredItems * 80 + padding
    end

    -- Verifica itens normais
    if #currentShop.items > 0 then
        currentY = currentY + 20 + padding / 2

        for i, item in ipairs(currentShop.items) do
            local itemY = currentY + (i - 1) * 70
            if y >= itemY and y <= itemY + 65 and
                x >= shopArea.x + padding and x <= shopArea.x + shopArea.w - padding then
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
    local currentY = shopArea.y + padding + 60 + 30 + padding * 2 -- Após header e botão vender tudo

    -- Verifica itens em promoção
    if #currentShop.featuredItems > 0 then
        currentY = currentY + 20 + padding / 2

        for i, item in ipairs(currentShop.featuredItems) do
            local itemY = currentY + (i - 1) * 80
            if y >= itemY and y <= itemY + 75 and
                x >= shopArea.x + padding and x <= shopArea.x + shopArea.w - padding then
                return item
            end
        end
        currentY = currentY + #currentShop.featuredItems * 80 + padding
    end

    -- Verifica itens normais
    if #currentShop.items > 0 then
        currentY = currentY + 20 + padding / 2

        for i, item in ipairs(currentShop.items) do
            local itemY = currentY + (i - 1) * 70
            if y >= itemY and y <= itemY + 65 and
                x >= shopArea.x + padding and x <= shopArea.x + shopArea.w - padding then
                return item
            end
        end
    end

    return nil
end

return ShopColumn
