local Colors = require("src.ui.colors")
local Fonts = require("src.ui.fonts")
local Formatters = require("src.utils.formatters")

--- Componente UI responsável por renderizar notificações com animações
--- @class NotificationDisplay
local NotificationDisplay = {}

-- Constantes do Sistema de Notificações
NotificationDisplay.NOTIFICATION_SYSTEM = {
    -- Máximo de notificações simultâneas na tela
    MAX_VISIBLE_NOTIFICATIONS = 5,
    -- Duração padrão em segundos antes da notificação desaparecer
    DEFAULT_DURATION = 4.0,
    -- Duração da animação de entrada em segundos
    SLIDE_IN_DURATION = 0.4,
    -- Duração da animação de saída em segundos
    FADE_OUT_DURATION = 0.3,
    -- Delay entre o aparecimento de novas notificações
    DELAY_BETWEEN_NOTIFICATIONS = 0.3,
    -- Altura de cada notificação em pixels
    NOTIFICATION_HEIGHT = 60,
    -- Largura das notificações em pixels
    NOTIFICATION_WIDTH = 300,
    -- Espaçamento entre notificações em pixels
    NOTIFICATION_SPACING = 10,
    -- Posição X das notificações (margem esquerda)
    NOTIFICATION_X = 20,
    -- Posição Y inicial das notificações (margem superior)
    NOTIFICATION_START_Y = 80,
    -- Tamanho do ícone dentro da notificação
    ICON_SIZE = 40,
    -- Pool inicial de notificações para evitar garbage collection
    POOL_SIZE = 10,
    -- Distância da animação de slide (pixels fora da tela)
    SLIDE_DISTANCE = 350,
    -- Alpha inicial da notificação
    INITIAL_ALPHA = 0.8,
    -- Duração da animação de "bump" do valor
    VALUE_UPDATE_ANIMATION_DURATION = 0.4,
    -- Escala máxima do valor durante a animação
    VALUE_UPDATE_SCALE = 1.5,
}

-- Tipos de notificação para diferentes contextos
NotificationDisplay.NOTIFICATION_TYPES = {
    ITEM_PICKUP = "item_pickup",
    ARTEFACT_PICKUP = "artefact_pickup",
    MONEY_CHANGE = "money_change",
    ITEM_PURCHASE = "item_purchase",
    ITEM_SALE = "item_sale",
    LEVEL_UP = "level_up",
    ACHIEVEMENT = "achievement",
}

--- Inicializa o sistema de renderização de notificações
function NotificationDisplay.init()
    -- Cache de fontes para performance
    NotificationDisplay.titleFont = Fonts.main_bold
    NotificationDisplay.valueFont = Fonts.main

    Logger.debug("notification_display.init.completed", "[NotificationDisplay:init] Sistema de renderização inicializado")
end

--- Renderiza todas as notificações ativas
function NotificationDisplay.draw()
    if not NotificationManager then
        return
    end

    local notifications = NotificationManager.getActiveNotifications()
    if not notifications or #notifications == 0 then
        return
    end

    for _, notification in ipairs(notifications) do
        NotificationDisplay._drawNotification(notification)
    end
end

--- Renderiza uma notificação individual
--- @param notification NotificationData
function NotificationDisplay._drawNotification(notification)
    if not notification or notification.animationPhase == "fading_out" and notification.alpha <= 0 then
        return
    end

    local finalX = 0 -- Posição final fixa na borda esquerda
    local y = notification.currentY
    local width = NotificationDisplay.NOTIFICATION_SYSTEM.NOTIFICATION_WIDTH
    local height = NotificationDisplay.NOTIFICATION_SYSTEM.NOTIFICATION_HEIGHT

    -- O 'x' representa a posição atual do canto esquerdo, que anima.
    local x = finalX
    if notification.animationPhase == "sliding_in" then
        local progress = math.min(
            notification.animationTime / NotificationDisplay.NOTIFICATION_SYSTEM.SLIDE_IN_DURATION,
            1.0
        )
        local easeProgress = 1 - math.pow(1 - progress, 3)
        x = (-width) + (width + finalX) * easeProgress -- Desliza de fora da tela (-width) para finalX
    end

    -- Aplicar transparência
    local alpha = notification.alpha or NotificationDisplay.NOTIFICATION_SYSTEM.INITIAL_ALPHA

    -- Salvar estado gráfico
    love.graphics.push()

    -- Desenhar fundo da notificação
    NotificationDisplay._drawBackground(x, y, width, height, notification.rarityColor, alpha)

    -- Desenhar ícone com padding interno
    local contentPadding = NotificationDisplay.NOTIFICATION_SYSTEM.NOTIFICATION_X
    local iconX = x + contentPadding
    local iconY = y + (height - NotificationDisplay.NOTIFICATION_SYSTEM.ICON_SIZE) / 2
    NotificationDisplay._drawIcon(iconX, iconY, notification.icon, alpha)

    -- Desenhar texto com padding
    local textStartX = iconX + NotificationDisplay.NOTIFICATION_SYSTEM.ICON_SIZE + 10
    local textContainerWidth = width - (textStartX - x) - contentPadding
    NotificationDisplay._drawText(textStartX, y, textContainerWidth, notification, alpha)

    -- Restaurar estado gráfico
    love.graphics.pop()
end

--- Desenha o fundo da notificação com cor de raridade
--- @param x number
--- @param y number
--- @param width number
--- @param height number
--- @param rarityColor table|nil
--- @param alpha number
function NotificationDisplay._drawBackground(x, y, width, height, rarityColor, alpha)
    -- Cor de fundo base
    local bgColor = Colors.black
    if rarityColor then
        bgColor = rarityColor
    end

    -- Desenhar sombra
    love.graphics.setColor(0, 0, 0, 0.3 * alpha)
    love.graphics.rectangle("fill", x + 2, y + 2, width, height)

    -- Desenhar fundo principal
    love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4] * alpha)
    love.graphics.rectangle("fill", x, y, width, height)
end

--- Desenha o ícone da notificação
--- @param x number
--- @param y number
--- @param icon love.Image|nil
--- @param alpha number
function NotificationDisplay._drawIcon(x, y, icon, alpha)
    if not icon then
        -- Desenhar ícone padrão se não houver imagem
        love.graphics.setColor(
            Colors.text_muted[1],
            Colors.text_muted[2],
            Colors.text_muted[3],
            alpha
        )
        love.graphics.rectangle(
            "fill",
            x,
            y,
            NotificationDisplay.NOTIFICATION_SYSTEM.ICON_SIZE,
            NotificationDisplay.NOTIFICATION_SYSTEM.ICON_SIZE,
            4,
            4
        )
        return
    end

    -- Calcular escala para ajustar o ícone ao tamanho desejado
    local iconSize = NotificationDisplay.NOTIFICATION_SYSTEM.ICON_SIZE
    local scaleX = iconSize / icon:getWidth()
    local scaleY = iconSize / icon:getHeight()
    local scale = math.min(scaleX, scaleY)

    -- Centralizar o ícone
    local iconWidth = icon:getWidth() * scale
    local iconHeight = icon:getHeight() * scale
    local offsetX = (iconSize - iconWidth) / 2
    local offsetY = (iconSize - iconHeight) / 2

    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(icon, x + offsetX, y + offsetY, 0, scale, scale)
end

--- Desenha o texto da notificação (título e valor)
--- @param x number
--- @param yContainer number
--- @param containerWidth number
--- @param notification NotificationData
--- @param alpha number
function NotificationDisplay._drawText(x, yContainer, containerWidth, notification, alpha)
    -- Configurar fontes e cores
    local titleFont = NotificationDisplay.titleFont
    local valueFont = NotificationDisplay.valueFont
    local titleColor = Colors.text_main
    local valueColor = Colors.white

    local title = notification.title or ""
    local valueText = tostring(notification.value or "")

    -- Centralizar verticalmente o conteúdo de texto
    local containerHeight = NotificationDisplay.NOTIFICATION_SYSTEM.NOTIFICATION_HEIGHT
    local textHeight = titleFont:getHeight()
    local y = yContainer + (containerHeight - textHeight) / 2

    if valueText ~= "" then
        love.graphics.setFont(valueFont)
        love.graphics.setColor(valueColor[1], valueColor[2], valueColor[3], alpha)
        local valueWidth = valueFont:getWidth(valueText)
        local valueHeight = valueFont:getHeight()
        local valueX = x + containerWidth - valueWidth

        -- Animação de escala do valor ao ser atualizado
        local valueScale = 1.0
        if notification.isUpdatingValue then
            local animDuration = NotificationDisplay.NOTIFICATION_SYSTEM.VALUE_UPDATE_ANIMATION_DURATION
            local maxScale = NotificationDisplay.NOTIFICATION_SYSTEM.VALUE_UPDATE_SCALE
            local progress = notification.valueAnimationTime / animDuration

            -- Animação de "bounce": sobe e desce
            if progress < 0.5 then
                local t = progress * 2                                         -- 0 -> 1
                valueScale = 1.0 + (maxScale - 1.0) * (1 - math.pow(1 - t, 2)) -- EaseOut
            else
                local t = (progress - 0.5) * 2                                 -- 0 -> 1
                valueScale = maxScale - (maxScale - 1.0) * (t * t)             -- EaseIn
            end
        end

        -- Desenha o valor com a animação de escala
        local ox = valueWidth / 2
        local oy = valueHeight / 2
        love.graphics.print(valueText, valueX + ox, y + oy, 0, valueScale, valueScale, ox, oy)

        love.graphics.setFont(titleFont)
        love.graphics.setColor(titleColor[1], titleColor[2], titleColor[3], alpha)
        local titleMaxWidth = containerWidth - valueWidth - 10 -- 10px de espaçamento
        local truncatedTitle = NotificationDisplay._truncateText(title, titleFont, titleMaxWidth)
        love.graphics.print(truncatedTitle, x, y)
    else
        -- Apenas o título
        love.graphics.setFont(titleFont)
        love.graphics.setColor(titleColor[1], titleColor[2], titleColor[3], alpha)
        local truncatedTitle = NotificationDisplay._truncateText(title, titleFont, containerWidth)
        love.graphics.print(truncatedTitle, x, y)
    end
end

--- Trunca texto se for muito longo para o espaço disponível
--- @param text string
--- @param font love.Font
--- @param maxWidth number
--- @return string
function NotificationDisplay._truncateText(text, font, maxWidth)
    local textWidth = font:getWidth(text)
    if textWidth <= maxWidth then
        return text
    end

    -- Adicionar reticências e ajustar
    local ellipsis = "..."
    local ellipsisWidth = font:getWidth(ellipsis)
    local availableWidth = maxWidth - ellipsisWidth

    if availableWidth <= 0 then
        return ellipsis
    end

    -- Encontrar o máximo de caracteres que cabem
    local truncated = ""
    for i = 1, #text do
        local char = string.sub(text, i, i)
        local testText = truncated .. char
        if font:getWidth(testText) > availableWidth then
            break
        end
        truncated = testText
    end

    return truncated .. ellipsis
end

--- Obtém a cor de fundo baseada na raridade do item
--- @param rarity string|nil
--- @return table
function NotificationDisplay.getRarityColor(rarity)
    if not rarity then
        return Colors.black
    end

    -- Converter raridade para uppercase para padronização
    local rarityUpper = string.upper(rarity)

    if Colors.rankDetails[rarityUpper] then
        return Colors.rankDetails[rarityUpper].gradientStart
    else
        return Colors.black
    end
end

--- Cria uma notificação para coleta de item
--- @param itemName string
--- @param quantity number|string
--- @param icon love.Image|nil
--- @param rarity string|nil
function NotificationDisplay.showItemPickup(itemName, quantity, icon, rarity)
    local title = itemName
    local value = quantity and ("x" .. tostring(quantity)) or ""
    local rarityColor = NotificationDisplay.getRarityColor(rarity)

    NotificationManager.show({
        type = NotificationDisplay.NOTIFICATION_TYPES.ITEM_PICKUP,
        title = title,
        value = value,
        icon = icon,
        rarityColor = rarityColor,
        duration = NotificationDisplay.NOTIFICATION_SYSTEM.DEFAULT_DURATION
    })
end

--- Cria uma notificação para mudança de patrimônio
--- @param amount number
function NotificationDisplay.showMoneyChange(amount)
    local title = amount >= 0 and "Patrimônio Ganho" or "Patrimônio Gasto"
    local value = "R$" .. tostring(Formatters.formatCompactNumber(amount, 2))
    local color = amount >= 0 and Colors.extraction_transition.success.background or
        Colors.extraction_transition.death.background

    NotificationManager.show({
        type = NotificationDisplay.NOTIFICATION_TYPES.MONEY_CHANGE,
        title = title,
        value = value,
        rarityColor = color,
        duration = NotificationDisplay.NOTIFICATION_SYSTEM.DEFAULT_DURATION
    })
end

--- Cria uma notificação para compra de item
--- @param itemName string
--- @param icon love.Image|nil
--- @param cost number
function NotificationDisplay.showItemPurchase(itemName, icon, cost)
    local title = itemName
    local value = "R$ " .. tostring(Formatters.formatCompactNumber(cost, 2))

    NotificationManager.show({
        type = NotificationDisplay.NOTIFICATION_TYPES.ITEM_PURCHASE,
        title = title,
        value = value,
        icon = icon,
        rarityColor = Colors.black,
        duration = NotificationDisplay.NOTIFICATION_SYSTEM.DEFAULT_DURATION
    })
end

--- Cria uma notificação para venda de item
--- @param itemName string
--- @param earnings number
function NotificationDisplay.showItemSale(itemName, icon, earnings)
    local title = itemName
    local value = "R$ " .. tostring(Formatters.formatCompactNumber(earnings, 2))

    NotificationManager.show({
        type = NotificationDisplay.NOTIFICATION_TYPES.ITEM_SALE,
        title = title,
        value = value,
        icon = icon,
        rarityColor = Colors.black,
        duration = NotificationDisplay.NOTIFICATION_SYSTEM.DEFAULT_DURATION
    })
end

return NotificationDisplay
