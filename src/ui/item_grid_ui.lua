local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")
local elements = require("src.ui.ui_elements") -- Adicionado para desenhar botões/abas

--- Módulo responsável por desenhar uma grade genérica de itens.
local ItemGridUI = {}

local gridConfig = {
    -- Default values, might be overridden by passed parameters if needed
    slotSize = 48,
    padding = 5,
    itemIconSize = 40 -- Tamanho para desenhar o ícone do item dentro do slot
}

local sectionTabConfig = {
    height = 30,
    width = 40,
    padding = 5,
    yOffset = -35 -- Deslocamento para cima a partir do topo da grade
}

--- Desenha uma grade de itens dentro da área especificada.
-- @param items table Tabela de itens a desenhar { [instanceId] = itemInstanceData }.
-- @param gridRows number Número de linhas na grade.
-- @param gridCols number Número de colunas na grade.
-- @param areaX number Coordenada X do canto superior esquerdo da área de desenho da grade.
-- @param areaY number Coordenada Y do canto superior esquerdo da área de desenho da grade.
-- @param areaW number Largura da área de desenho da grade.
-- @param areaH number Altura da área de desenho da grade.
-- @param itemDataManager src.managers.ItemDataManager Instância do gerenciador de dados de itens.
-- @param sectionInfo table|nil Informações sobre seções { total=N, active=Idx } (Opcional).
function ItemGridUI.drawItemGrid(items, gridRows, gridCols, areaX, areaY, areaW, areaH, itemDataManager, sectionInfo)
    -- Define as dimensões da grade atual
    local currentGridRows = gridRows or 1 -- Default to 1 row/col if not provided
    local currentGridCols = gridCols or 1

    -- Usa a tabela de itens fornecida
    local currentItems = items or {}
    -- Cache para dados de item (pode ser melhorado, mas ok por enquanto)
    local itemDataCache = {}

    -- Calcula dimensões e posição da grade
    local slotTotalWidth = gridConfig.slotSize + gridConfig.padding
    local slotTotalHeight = gridConfig.slotSize + gridConfig.padding
    local gridTotalWidth = currentGridCols * slotTotalWidth - gridConfig.padding
    local gridTotalHeight = currentGridRows * slotTotalHeight - gridConfig.padding

    local startX = areaX + (areaW - gridTotalWidth) / 2
    local startY = areaY + (areaH - gridTotalHeight) / 2

    -- Desenha as abas das seções (se sectionInfo for fornecido)
    if sectionInfo and sectionInfo.total and sectionInfo.active then
        local tabY = startY + sectionTabConfig.yOffset
        local currentTabX = startX
        for i = 1, sectionInfo.total do
            local tabRect = {
                x = currentTabX,
                y = tabY,
                w = sectionTabConfig.width,
                h = sectionTabConfig.height
            }
            -- Determina se esta aba está com hover (precisa passar mx, my para a função)
            -- local isHovering = elements.isMouseOver(tabRect) -- Supondo que elements tem essa função
            local isHovering = false -- Placeholder

            elements.drawTabButton({
                x = tabRect.x,
                y = tabRect.y,
                w = tabRect.w,
                h = tabRect.h,
                text = tostring(i),
                isHovering = isHovering,
                highlighted = (i == sectionInfo.active),
                font = fonts.main_small,
                colors = {
                    bgColor = colors.tab_bg,
                    hoverColor = colors.tab_hover,
                    highlightedBgColor = colors.tab_highlighted_bg,
                    highlightedHoverColor = colors.tab_highlighted_hover,
                    textColor = colors.tab_text,
                    borderColor = colors.tab_border
                }
            })
            currentTabX = currentTabX + sectionTabConfig.width + sectionTabConfig.padding
        end
    end

    local slotFont = fonts.main_small or love.graphics.getFont()
    local originalFont = love.graphics.getFont()
    love.graphics.setFont(slotFont)

    -- Desenha os slots e itens
    for row = 1, currentGridRows do     -- Muda para loop baseado em 1
        for col = 1, currentGridCols do -- Muda para loop baseado em 1
            local slotX = startX + (col - 1) * slotTotalWidth
            local slotY = startY + (row - 1) * slotTotalHeight

            -- Desenha o fundo do slot
            love.graphics.setColor(colors.inventory_slot_bg)
            love.graphics.rectangle("fill", slotX, slotY, gridConfig.slotSize, gridConfig.slotSize, 5, 5)

            -- Desenha a borda do slot
            love.graphics.setColor(colors.inventory_slot_border)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", slotX, slotY, gridConfig.slotSize, gridConfig.slotSize, 5, 5)
        end
    end

    -- Desenha os itens POR CIMA dos slots vazios
    for instanceId, itemInfo in pairs(currentItems) do
        if itemInfo and itemInfo.itemBaseId and itemInfo.row and itemInfo.col then
            -- Calcula a posição do slot onde o item começa
            local itemSlotX = startX + (itemInfo.col - 1) * slotTotalWidth
            local itemSlotY = startY + (itemInfo.row - 1) * slotTotalHeight
            local itemDrawW = (itemInfo.gridWidth or 1) * slotTotalWidth - gridConfig.padding
            local itemDrawH = (itemInfo.gridHeight or 1) * slotTotalHeight - gridConfig.padding

            -- Tenta obter dados do item (com cache)
            local itemData = itemDataCache[itemInfo.itemBaseId]
            if not itemData then
                -- Tenta buscar usando o itemDataManager fornecido
                if itemDataManager and itemDataManager.getData then
                    itemData = itemDataManager:getData(itemInfo.itemBaseId)
                elseif itemDataManager and itemDataManager.getBaseItemData then -- Fallback
                    itemData = itemDataManager:getBaseItemData(itemInfo.itemBaseId)
                end
                itemDataCache[itemInfo.itemBaseId] = itemData
            end

            if itemData then
                -- Desenha o ícone do item (se existir nos dados base)
                -- Prioriza ícone da instância, se existir (pode ser diferente do base)
                local iconToDraw = itemInfo.icon or (itemData and itemData.icon)
                if iconToDraw and type(iconToDraw) == "userdata" and iconToDraw:typeOf("Image") then
                    local iconDrawSize = gridConfig.itemIconSize
                    -- Centraliza o ícone no espaço total do item (útil para itens > 1x1)
                    local iconX = itemSlotX + (itemDrawW - iconDrawSize) / 2
                    local iconY = itemSlotY + (itemDrawH - iconDrawSize) / 2
                    local scale = iconDrawSize / math.max(iconToDraw:getWidth(), iconToDraw:getHeight())
                    love.graphics.setColor(colors.white)
                    love.graphics.draw(iconToDraw, iconX, iconY, 0, scale, scale)
                else
                    -- Fallback: Desenha o ID do item se não houver ícone
                    love.graphics.setColor(colors.white)
                    love.graphics.printf(itemInfo.itemBaseId, itemSlotX, itemSlotY + itemDrawH / 3, itemDrawW, "center")
                end

                -- Desenha a quantidade (se maior que 1)
                if itemInfo.quantity and itemInfo.quantity > 1 then
                    love.graphics.setColor(colors.item_quantity_text)
                    local qtyText = tostring(itemInfo.quantity)
                    local textW = slotFont:getWidth(qtyText)
                    -- Posiciona no canto inferior direito do PRIMEIRO slot do item
                    local textX = itemSlotX + gridConfig.slotSize - textW - 3
                    local textY = itemSlotY + gridConfig.slotSize - slotFont:getHeight() - 2
                    love.graphics.setColor(colors.black_transparent_more)
                    love.graphics.print(qtyText, textX + 1, textY + 1)
                    love.graphics.setColor(colors.item_quantity_text)
                    love.graphics.print(qtyText, textX, textY)
                end
            else
                -- Se item existe mas não há dados base (erro?)
                love.graphics.setColor(colors.red)
                love.graphics.printf("?", itemSlotX, itemSlotY + itemDrawH / 3, itemDrawW, "center")
            end
        end
    end

    -- Restaura a fonte original e cor
    love.graphics.setFont(originalFont)
    love.graphics.setColor(colors.white)
end

--- Verifica se um clique ocorreu em uma das abas de seção.
-- @param mx number Coordenada X do mouse.
-- @param my number Coordenada Y do mouse.
-- @param sectionInfo table Informações das seções { total=N, active=Idx }.
-- @param areaX number Coordenada X da área da grade.
-- @param areaY number Coordenada Y da área da grade.
-- @param areaW number Largura da área da grade.
-- @param areaH number Altura da área da grade.
-- @param gridRows number Número de linhas da grade (para cálculo de altura total).
-- @param gridCols number Número de colunas da grade (para cálculo de largura total).
-- @return number|nil O índice da aba clicada (baseado em 1) ou nil.
function ItemGridUI.handleMouseClick(mx, my, sectionInfo, areaX, areaY, areaW, areaH, gridRows, gridCols)
    if not sectionInfo or not sectionInfo.total then return nil end

    -- Recalcula a posição inicial da grade para alinhar as abas
    local currentGridRows = gridRows or 1
    local currentGridCols = gridCols or 1
    local slotTotalWidth = gridConfig.slotSize + gridConfig.padding
    local slotTotalHeight = gridConfig.slotSize + gridConfig.padding
    local gridTotalWidth = currentGridCols * slotTotalWidth - gridConfig.padding
    local gridTotalHeight = currentGridRows * slotTotalHeight - gridConfig.padding
    local startX = areaX + (areaW - gridTotalWidth) / 2
    local startY = areaY + (areaH - gridTotalHeight) / 2

    -- Posição Y das abas
    local tabY = startY + sectionTabConfig.yOffset
    local currentTabX = startX

    for i = 1, sectionInfo.total do
        local tabRect = { x = currentTabX, y = tabY, w = sectionTabConfig.width, h = sectionTabConfig.height }
        -- Verifica se o clique (mx, my) está dentro do retângulo da aba
        if mx >= tabRect.x and mx <= tabRect.x + tabRect.w and my >= tabRect.y and my <= tabRect.y + tabRect.h then
            print("[ItemGridUI] Clique detectado na aba:", i)
            return i -- Retorna o índice da aba clicada
        end
        currentTabX = currentTabX + sectionTabConfig.width + sectionTabConfig.padding
    end

    return nil -- Nenhum clique em aba
end

return ItemGridUI
