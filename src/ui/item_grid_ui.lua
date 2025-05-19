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
    local startY = areaY -- Versão nova que alinha ao topo da areaY fornecida

    -- Desenha as abas das seções (se sectionInfo for fornecido)
    if sectionInfo and sectionInfo.total and sectionInfo.active then
        local tabY = startY + gridTotalHeight + gridConfig.padding -- Posiciona abaixo da grade com padding
        local currentTabX = startX                                 -- Começa sempre alinhado à esquerda da grade

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

            -- Desenha slot usando elements.drawWindowFrame
            elements.drawWindowFrame(slotX - 2, slotY - 2, gridConfig.slotSize + 4, gridConfig.slotSize + 4, nil,
                colors.slot_empty_bg, colors.slot_empty_border)
            -- Desenha fundo interno
            local bgColor = colors.slot_empty_bg
            if bgColor then
                love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)
            else
                love
                    .graphics.setColor(0.1, 0.1, 0.1, 0.8)
            end
            love.graphics.rectangle("fill", slotX, slotY, gridConfig.slotSize, gridConfig.slotSize, 3, 3)
            love.graphics.setColor(colors.white) -- Reset color
        end
    end

    -- Desenha os itens POR CIMA dos slots vazios
    for instanceId, itemInfo in pairs(currentItems) do
        if itemInfo and itemInfo.itemBaseId and itemInfo.row and itemInfo.col then
            -- Calcula a posição do slot onde o item começa
            local itemSlotX = startX + (itemInfo.col - 1) * slotTotalWidth
            local itemSlotY = startY + (itemInfo.row - 1) * slotTotalHeight

            -- <<< INÍCIO: Modificação para rotação >>>
            local isRotated = itemInfo.isRotated or false
            local gridW = itemInfo.gridWidth or 1
            local gridH = itemInfo.gridHeight or 1

            -- Dimensões VISUAIS (para desenho e borda)
            local visualW = isRotated and (gridH * slotTotalHeight - gridConfig.padding) or
                (gridW * slotTotalWidth - gridConfig.padding)
            local visualH = isRotated and (gridW * slotTotalWidth - gridConfig.padding) or
                (gridH * slotTotalHeight - gridConfig.padding)
            -- <<< FIM: Modificação para rotação >>>

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

            if itemData or itemInfo.name then -- Usa itemInfo.name como fallback se data falhar
                -- <<< MODIFICADO: Usar drawTextCard para o fundo >>>
                local rarity = itemInfo.rarity or 'E'
                local cardConfig = {
                    rankLetterForStyle = rarity,
                    -- Não precisamos de texto dentro do card de fundo, o ícone virá por cima
                    text = "",
                    -- Outras configs de drawTextCard podem ser adicionadas se necessário (cornerRadius, etc.)
                    -- Se drawTextCard já inclui um brilho/borda adequado, podemos remover drawRarityBorderAndGlow abaixo.
                    showGlow = true -- Assumindo que queremos o brilho do rank
                }
                elements.drawTextCard(itemSlotX, itemSlotY, visualW, visualH, "", cardConfig)

                -- Restaurar cor padrão caso drawTextCard a modifique e não a restaure
                love.graphics.setColor(colors.white)

                -- 3. Desenha Ícone (se existir)
                local iconToDraw = itemInfo.icon
                if not iconToDraw and itemData then iconToDraw = itemData.icon end

                local iconExists = iconToDraw and type(iconToDraw) == "userdata" and iconToDraw:typeOf("Image")
                if iconExists then
                    -- Desenha o ícone escalonado e rotacionado se necessário
                    local originalW = iconToDraw:getWidth()
                    local originalH = iconToDraw:getHeight()

                    -- <<< INÍCIO: Cálculo de escala e rotação com PADDING INTERNO >>>
                    local iconPadding = 4 -- Define o padding interno para o ícone

                    -- A escala é baseada nas dimensões NÃO ROTACIONADAS do espaço que o item ocupa, MENOS o padding
                    local baseVisualW_noPadding = (gridW * slotTotalWidth - gridConfig.padding) - (iconPadding * 2)
                    local baseVisualH_noPadding = (gridH * slotTotalHeight - gridConfig.padding) - (iconPadding * 2)

                    local scaleX = baseVisualW_noPadding / originalW
                    local scaleY = baseVisualH_noPadding / originalH
                    -- Para manter a proporção do ícone e não distorcer, usamos a menor escala
                    local scale = math.min(scaleX, scaleY)
                    if scale <= 0 then scale = 0.01 end -- Evita escala zero ou negativa

                    -- As dimensões reais do ícone desenhado serão:
                    local scaledIconW = originalW * scale
                    local scaledIconH = originalH * scale

                    -- Centro da área VISUAL (visualW, visualH do card de fundo) para centralizar o ícone COM padding
                    local drawOffsetX = (visualW - scaledIconW) / 2
                    local drawOffsetY = (visualH - scaledIconH) / 2

                    local drawX = itemSlotX + drawOffsetX +
                        (scaledIconW / 2) -- Adiciona scaledIconW/2 para centralizar a origem da imagem
                    local drawY = itemSlotY + drawOffsetY +
                        (scaledIconH / 2) -- Adiciona scaledIconH/2 para centralizar a origem da imagem

                    local rotationAngle = isRotated and math.pi / 2 or 0

                    love.graphics.draw(iconToDraw, drawX, drawY, rotationAngle, scale, scale, originalW / 2,
                        originalH / 2)
                    -- <<< FIM: Cálculo de escala e rotação com PADDING INTERNO >>>
                else
                    -- 4. Desenha placeholder APENAS se não houver ícone
                    love.graphics.setColor(colors.white)
                    local placeholderText = itemInfo.name and string.sub(itemInfo.name, 1, 1) or "?"
                    love.graphics.setFont(fonts.title)
                    love.graphics.printf(placeholderText, itemSlotX, itemSlotY + visualH * 0.1, visualW, "center") -- Usa visualW/H
                    love.graphics.setFont(slotFont)
                end

                -- 5. Desenha borda/brilho da raridade (Usa a mesma variável 'rarity')
                -- elements.drawRarityBorderAndGlow(rarity, itemSlotX, itemSlotY, visualW, visualH) -- REMOVIDO, pois drawTextCard deve cuidar disso

                -- Desenha a quantidade (se maior que 1)
                if itemInfo.quantity and itemInfo.quantity > 1 then
                    love.graphics.setColor(colors.item_quantity_text)
                    local qtyText = tostring(itemInfo.quantity)
                    local textW = slotFont:getWidth(qtyText)
                    -- Posiciona o canto inferior direito no ultimo slot VISUAL do item
                    local textX = itemSlotX + visualW - textW - 3                -- Usa visualW
                    local textY = itemSlotY + visualH - slotFont:getHeight() - 2 -- Usa visualH

                    love.graphics.setColor(colors.black_transparent_more)
                    love.graphics.print(qtyText, textX + 1, textY + 1)
                    love.graphics.setColor(colors.item_quantity_text)
                    love.graphics.print(qtyText, textX, textY)
                end
            else
                -- Se item existe mas não há dados base (erro?)
                love.graphics.setColor(colors.red)
                love.graphics.printf("?", itemSlotX, itemSlotY + visualH / 3, visualW, "center")
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
    local startY = areaY -- Versão nova que alinha ao topo da areaY fornecida

    -- Posição Y das abas
    local tabY = startY + gridTotalHeight + gridConfig.padding -- Posiciona abaixo da grade com padding
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

--- NOVO: Retorna a instância do item sob as coordenadas do mouse.
-- @param mx number Coordenada X do mouse.
-- @param my number Coordenada Y do mouse.
-- @param items table Tabela de itens da grade { [instanceId] = itemInstanceData }.
-- @param gridRows number Número de linhas da grade.
-- @param gridCols number Número de colunas da grade.
-- @param areaX number Coordenada X da área da grade.
-- @param areaY number Coordenada Y da área da grade.
-- @param areaW number Largura da área da grade.
-- @param areaH number Altura da área da grade.
-- @return table|nil A tabela da instância do item ou nil.
function ItemGridUI.getItemInstanceAtCoords(mx, my, items, gridRows, gridCols, areaX, areaY, areaW, areaH)
    if not items then return nil end

    -- Recalcula posição/dimensões da grade
    local currentGridRows = gridRows or 1
    local currentGridCols = gridCols or 1
    local slotTotalWidth = gridConfig.slotSize + gridConfig.padding
    local slotTotalHeight = gridConfig.slotSize + gridConfig.padding
    local gridTotalWidth = currentGridCols * slotTotalWidth - gridConfig.padding
    local gridTotalHeight = currentGridRows * slotTotalHeight - gridConfig.padding
    local startX = areaX + (areaW - gridTotalWidth) / 2
    local startY = areaY -- Alinhado ao topo

    -- Itera pelos itens para encontrar qual está sob o mouse
    for instanceId, itemInfo in pairs(items) do
        if itemInfo and itemInfo.row and itemInfo.col then
            local itemSlotX = startX + (itemInfo.col - 1) * slotTotalWidth
            local itemSlotY = startY + (itemInfo.row - 1) * slotTotalHeight

            -- <<< INÍCIO: Calcula dimensões para checagem de clique considerando rotação >>>
            local isRotated = itemInfo.isRotated or false
            local gridW = itemInfo.gridWidth or 1
            local gridH = itemInfo.gridHeight or 1

            local checkGridW = isRotated and gridH or gridW
            local checkGridH = isRotated and gridW or gridH

            local itemCheckW = checkGridW * slotTotalWidth - gridConfig.padding
            local itemCheckH = checkGridH * slotTotalHeight - gridConfig.padding
            -- <<< FIM: Calcula dimensões para checagem de clique >>>

            -- Verifica se o mouse está dentro do retângulo de checagem do item
            if mx >= itemSlotX and mx < itemSlotX + itemCheckW and my >= itemSlotY and my < itemSlotY + itemCheckH then
                return itemInfo -- Retorna a instância completa do item
            end
        end
    end

    return nil -- Nenhum item encontrado nas coordenadas
end

--- NOVO: Retorna as coordenadas (linha, coluna) do slot da grade sob o mouse.
-- @param mx number Coordenada X do mouse.
-- @param my number Coordenada Y do mouse.
-- @param gridRows number Número de linhas da grade.
-- @param gridCols number Número de colunas da grade.
-- @param areaX number Coordenada X da área da grade.
-- @param areaY number Coordenada Y da área da grade.
-- @param areaW number Largura da área da grade.
-- @param areaH number Altura da área da grade.
-- @return table|nil Tabela {row, col} ou nil se fora da grade.
function ItemGridUI.getSlotCoordsAtMouse(mx, my, gridRows, gridCols, areaX, areaY, areaW, areaH)
    -- Recalcula posição/dimensões da grade
    local currentGridRows = gridRows or 1
    local currentGridCols = gridCols or 1
    local slotTotalWidth = gridConfig.slotSize + gridConfig.padding
    local slotTotalHeight = gridConfig.slotSize + gridConfig.padding
    local gridTotalWidth = currentGridCols * slotTotalWidth - gridConfig.padding
    local gridTotalHeight = currentGridRows * slotTotalHeight - gridConfig.padding
    local startX = areaX + (areaW - gridTotalWidth) / 2
    local startY = areaY -- Alinhado ao topo

    -- Verifica se o mouse está dentro dos limites da grade
    if mx >= startX and mx < startX + gridTotalWidth and my >= startY and my < startY + gridTotalHeight then
        -- Calcula a linha e coluna relativas
        local relativeX = mx - startX
        local relativeY = my - startY
        local col = math.floor(relativeX / slotTotalWidth) + 1
        local row = math.floor(relativeY / slotTotalHeight) + 1

        -- Garante que estão dentro dos limites reais da grade
        if row >= 1 and row <= currentGridRows and col >= 1 and col <= currentGridCols then
            return { row = row, col = col }
        end
    end

    return nil -- Mouse fora da área da grade
end

--- NOVO: Retorna as coordenadas de tela (X, Y) do canto superior esquerdo de um item.
-- @param itemRow number Linha do item (1-indexed).
-- @param itemCol number Coluna do item (1-indexed).
-- @param gridRows number Número de linhas da grade.
-- @param gridCols number Número de colunas da grade.
-- @param areaX number Coordenada X da área da grade.
-- @param areaY number Coordenada Y da área da grade.
-- @param areaW number Largura da área da grade.
-- @param areaH number Altura da área da grade.
-- @return number|nil screenX Coordenada X ou nil se inválido.
-- @return number|nil screenY Coordenada Y ou nil se inválido.
function ItemGridUI.getItemScreenPos(itemRow, itemCol, gridRows, gridCols, areaX, areaY, areaW, areaH)
    if not itemRow or not itemCol then return nil, nil end

    -- Recalcula posição/dimensões da grade (igual a outras funções)
    local currentGridRows = gridRows or 1
    local currentGridCols = gridCols or 1
    local slotTotalWidth = gridConfig.slotSize + gridConfig.padding
    local slotTotalHeight = gridConfig.slotSize + gridConfig.padding
    local gridTotalWidth = currentGridCols * slotTotalWidth - gridConfig.padding
    -- local gridTotalHeight = currentGridRows * slotTotalHeight - gridConfig.padding -- Não necessário para X,Y
    local startX = areaX + (areaW - gridTotalWidth) / 2
    local startY = areaY -- Alinhado ao topo

    -- Calcula a posição do slot onde o item começa
    local itemSlotX = startX + (itemCol - 1) * slotTotalWidth
    local itemSlotY = startY + (itemRow - 1) * slotTotalHeight

    return itemSlotX, itemSlotY
end

return ItemGridUI
