local fonts = require("src.ui.fonts")
local colors = require("src.ui.colors")
local elements = require("src.ui.ui_elements")
local ManagerRegistry = require("src.managers.manager_registry")

---@class ArtefactsDisplay
local ArtefactsDisplay = {
    hoveredArtefact = nil
}

function ArtefactsDisplay:new()
    local instance = {}
    setmetatable(instance, self)
    self.__index = self
    return instance
end

--- Desenha a seção de artefatos coletados.
---@param x number Posição X inicial
---@param y number Posição Y inicial
---@param w number Largura disponível
---@param h number Altura disponível
---@param showSellButton boolean Se deve mostrar botão de venda
---@param mx number Posição X do mouse (para hover)
---@param my number Posição Y do mouse (para hover)
---@return table|nil sellButtonArea Área do botão de venda se mostrado
---@return table|nil hoveredArtefact Artefato sob o mouse (para ItemDetailsModal)
function ArtefactsDisplay:draw(x, y, w, h, showSellButton, mx, my)
    ---@type ArtefactManager
    local artefactManager = ManagerRegistry:tryGet("artefactManager")

    if not artefactManager then
        love.graphics.setColor(colors.red)
        love.graphics.printf("ArtefactManager não disponível", x, y + h / 2, w, "center")
        love.graphics.setColor(colors.white)
        return nil, nil
    end

    local padding = 8
    local titleFont = fonts.title or love.graphics.getFont()
    local titleHeight = titleFont:getHeight()
    local titleMarginY = 15
    local contentStartY = y + titleHeight + titleMarginY
    local availableContentH = h - titleHeight - titleMarginY

    -- Título da seção (usando mesma fonte e estilo do inventário)
    love.graphics.setFont(titleFont)
    love.graphics.setColor(colors.text_highlight)
    love.graphics.printf("ARTEFATOS DIMENSIONAIS", x, y, w, "center")
    love.graphics.setColor(colors.white)
    love.graphics.setFont(fonts.main or titleFont)

    -- Obtém artefatos coletados
    local collectedArtefacts = artefactManager:getAllArtefacts()
    local totalArtefacts = artefactManager:getTotalArtefactsCount()
    local totalValue = artefactManager:getTotalArtefactsValue()

    -- Se não há artefatos, mostra mensagem
    if totalArtefacts == 0 then
        love.graphics.setColor(colors.text_muted)
        love.graphics.printf("Nenhum artefato coletado", x, contentStartY + availableContentH / 2, w, "center")
        love.graphics.setColor(colors.white)
        return nil, nil
    end

    -- Área para botão de venda (se mostrado)
    local sellButtonArea = nil
    local sellButtonHeight = 30
    local sellButtonPadding = 5
    local artefactsContentH = availableContentH

    if showSellButton then
        artefactsContentH = availableContentH - sellButtonHeight - sellButtonPadding

        -- Calcula área do botão de venda
        sellButtonArea = {
            x = x,
            y = contentStartY + artefactsContentH + sellButtonPadding,
            w = w,
            h = sellButtonHeight
        }

        -- Desenha botão de venda
        local isHoverSell = mx >= sellButtonArea.x and mx < sellButtonArea.x + sellButtonArea.w and
            my >= sellButtonArea.y and my < sellButtonArea.y + sellButtonArea.h

        local buttonColor = isHoverSell and colors.button_primary.hoverColor or colors.button_primary.bgColor
        love.graphics.setColor(buttonColor)
        love.graphics.rectangle("fill", sellButtonArea.x, sellButtonArea.y, sellButtonArea.w, sellButtonArea.h)

        love.graphics.setColor(colors.button_border)
        love.graphics.rectangle("line", sellButtonArea.x, sellButtonArea.y, sellButtonArea.w, sellButtonArea.h)

        love.graphics.setColor(colors.text_default)
        love.graphics.setFont(fonts.main)
        local sellText = string.format("Vender Todos (%dG)", totalValue)
        love.graphics.printf(sellText, sellButtonArea.x,
            sellButtonArea.y + (sellButtonArea.h - fonts.main:getHeight()) / 2, sellButtonArea.w, "center")
    end

    -- Configuração do grid (artefatos são 1.5x1.5)
    local slotSize = 32      -- Tamanho base do slot
    local slotPadding = 2    -- Espaçamento entre slots
    local artefactSize = 1.5 -- Todos os artefatos são 1.5x1.5
    local itemVisualSize = slotSize * artefactSize
    local itemTotalSize = itemVisualSize + slotPadding

    -- Calcula quantos itens cabem por linha
    local itemsPerRow = math.max(1, math.floor((w - slotPadding) / itemTotalSize))

    local currentX = x + slotPadding
    local currentY = contentStartY
    local itemsInCurrentRow = 0
    local hoveredArtefact = nil

    -- Ordena artefatos por categoria e valor
    local sortedArtefacts = {}
    for artefactId, quantity in pairs(collectedArtefacts) do
        local artefactData = artefactManager:getArtefactDefinition(artefactId)
        if artefactData then
            table.insert(sortedArtefacts, {
                id = artefactId,
                data = artefactData,
                quantity = quantity
            })
        end
    end

    -- Ordena por categoria e depois por valor
    local categoryOrder = { essence = 1, crystal = 2, relic = 3, legendary = 4 }
    table.sort(sortedArtefacts, function(a, b)
        local catA = categoryOrder[a.data.category] or 99
        local catB = categoryOrder[b.data.category] or 99
        if catA == catB then
            return a.data.value > b.data.value -- Maior valor primeiro
        end
        return catA < catB
    end)

    -- Desenha cada artefato
    for _, artefact in ipairs(sortedArtefacts) do
        local artefactData = artefact.data
        local quantity = artefact.quantity

        -- Verifica se cabe na linha atual
        if itemsInCurrentRow >= itemsPerRow then
            currentX = x + slotPadding
            currentY = currentY + itemTotalSize
            itemsInCurrentRow = 0
        end

        -- Verifica se ainda cabe na altura disponível
        if currentY + itemVisualSize > contentStartY + artefactsContentH then
            -- Desenha indicador de "mais itens"
            love.graphics.setColor(colors.text_muted)
            love.graphics.printf("...", currentX, currentY, w - (currentX - x), "left")
            break
        end

        -- Área do item atual
        local itemArea = {
            x = currentX,
            y = currentY,
            w = itemVisualSize,
            h = itemVisualSize
        }

        -- Verifica hover
        local isHover = mx >= itemArea.x and mx < itemArea.x + itemArea.w and
            my >= itemArea.y and my < itemArea.y + itemArea.h

        -- Desenha fundo do item usando drawTextCard (como no ItemGrid)
        local cardConfig = {
            rankLetterForStyle = artefactData.rank,
            text = "",
            showGlow = true
        }
        elements.drawTextCard(itemArea.x, itemArea.y, itemArea.w, itemArea.h, "", cardConfig)
        love.graphics.setColor(colors.white)

        -- Desenha ícone se existir
        if artefactData.icon and type(artefactData.icon) == "userdata" then
            local iconPadding = 4
            local originalW = artefactData.icon:getWidth()
            local originalH = artefactData.icon:getHeight()

            local availableW = itemArea.w - (iconPadding * 2)
            local availableH = itemArea.h - (iconPadding * 2)

            local scaleX = availableW / originalW
            local scaleY = availableH / originalH
            local scale = math.min(scaleX, scaleY)
            if scale <= 0 then scale = 0.01 end

            local scaledW = originalW * scale
            local scaledH = originalH * scale

            local drawX = itemArea.x + (itemArea.w - scaledW) / 2 + (scaledW / 2)
            local drawY = itemArea.y + (itemArea.h - scaledH) / 2 + (scaledH / 2)

            love.graphics.setColor(1, 1, 1, 1) -- Garantir cor branca
            love.graphics.draw(artefactData.icon, drawX, drawY, 0, scale, scale, originalW / 2, originalH / 2)
        else
            -- Placeholder se não houver ícone
            love.graphics.setColor(colors.white)
            local placeholderText = string.sub(artefactData.name, 1, 1)
            love.graphics.setFont(fonts.title)
            love.graphics.printf(placeholderText, itemArea.x, itemArea.y + itemArea.h * 0.1, itemArea.w, "center")

            -- Debug para identificar o problema
            print("[ArtefactsDisplay] Ícone não carregado para: " .. artefactData.name ..
                " | Tipo: " .. type(artefactData.icon or "nil") .. " | Categoria: " .. (artefactData.category or "nil"))
        end

        -- Desenha quantidade (se maior que 1)
        if quantity > 1 then
            love.graphics.setColor(colors.item_quantity_text)
            local qtyText = tostring(quantity)
            local qtyFont = fonts.main_small
            love.graphics.setFont(qtyFont)
            local textW = qtyFont:getWidth(qtyText)
            local textX = itemArea.x + itemArea.w - textW - 3
            local textY = itemArea.y + itemArea.h - qtyFont:getHeight() - 2

            -- Sombra
            love.graphics.setColor(colors.black_transparent_more)
            love.graphics.print(qtyText, textX + 1, textY + 1)
            love.graphics.setColor(colors.item_quantity_text)
            love.graphics.print(qtyText, textX, textY)
        end

        -- Prepara dados do artefato para ItemDetailsModal se hover
        if isHover then
            self.hoveredArtefact = {
                -- Dados da instância do item
                itemBaseId = artefact.id,
                instanceId = artefact.id .. "_artefact",
                rarity = artefactData.rank,
                type = "artefact",
                icon = artefactData.icon,
                quantity = quantity,
                sellValue = artefactData.value * quantity,
                value = artefactData.value,
                -- Dados base do item (simulando o que viria do ItemDataManager)
                _baseItemData = {
                    name = artefactData.name,
                    description = artefactData.description,
                    type = "artefact",
                    rarity = artefactData.rank,
                    icon = artefactData.icon,
                    value = artefactData.value,
                    category = artefactData.category
                }
            }
        elseif self.hoveredArtefact and not isHover and self.hoveredArtefact.instanceId == artefact.id .. "_artefact" then
            self.hoveredArtefact = nil
        end

        -- Avança para próximo item
        currentX = currentX + itemTotalSize
        itemsInCurrentRow = itemsInCurrentRow + 1
    end

    -- Desenha resumo no final
    if #sortedArtefacts > 0 then
        local summaryY = math.min(currentY + itemVisualSize + padding * 2,
            contentStartY + artefactsContentH - fonts.main_small:getHeight())
        love.graphics.setColor(colors.text_muted)
        love.graphics.setFont(fonts.main_small)
        local summaryText = string.format("Total: %d artefatos (%dG)", totalArtefacts, totalValue)
        love.graphics.printf(summaryText, x, summaryY, w, "center")
    end

    love.graphics.setColor(colors.white) -- Reset cor
    return sellButtonArea, hoveredArtefact
end

--- Detecta cliques no display de artefatos (especialmente botão de venda)
---@param mx number Posição X do mouse
---@param my number Posição Y do mouse
---@param x number Posição X inicial do display
---@param y number Posição Y inicial do display
---@param w number Largura do display
---@param h number Altura do display
---@return boolean sellButtonClicked Se o botão de venda foi clicado
function ArtefactsDisplay:handleClick(mx, my, x, y, w, h)
    ---@type ArtefactManager
    local artefactManager = ManagerRegistry:get("artefactManager")

    local padding = 8
    local titleHeight = fonts.main:getHeight()
    local contentStartY = y + titleHeight + padding
    local availableContentH = h - titleHeight - padding

    -- Verifica se há artefatos (senão não tem botão)
    local totalArtefacts = artefactManager:getTotalArtefactsCount()
    if totalArtefacts == 0 then
        return false
    end

    -- Calcula área do botão de venda
    local sellButtonHeight = 30
    local sellButtonPadding = 5
    local artefactsContentH = availableContentH - sellButtonHeight - sellButtonPadding

    local sellButtonArea = {
        x = x,
        y = contentStartY + artefactsContentH + sellButtonPadding,
        w = w,
        h = sellButtonHeight
    }

    -- Verifica se clicou no botão de venda
    if mx >= sellButtonArea.x and mx < sellButtonArea.x + sellButtonArea.w and
        my >= sellButtonArea.y and my < sellButtonArea.y + sellButtonArea.h then
        -- Executa venda de todos os artefatos
        local totalValue = artefactManager:getTotalArtefactsValue()
        if totalValue > 0 then
            local soldValue = artefactManager:sellAllArtefacts()
            if soldValue > 0 then
                print(string.format("[ArtefactsDisplay] Vendidos todos os artefatos por %dG", soldValue))
            else
                print("[ArtefactsDisplay] Falha ao vender artefatos")
            end
        end

        return true
    end

    return false
end

return ArtefactsDisplay
