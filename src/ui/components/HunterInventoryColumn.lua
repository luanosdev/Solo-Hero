local ItemGridUI = require("src.ui.item_grid_ui")
local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")
local elements = require("src.ui.ui_elements") -- Adicionado para desenhar ícones/slots

local HunterInventoryColumn = {}

--- Desenha a coluna do Inventário (Gameplay) ou uma lista de itens fornecida.
---@param x number Posição X da coluna.
---@param y number Posição Y inicial do conteúdo da coluna.
---@param w number Largura da coluna.
---@param h number Altura total disponível para o conteúdo da coluna.
---@param inventoryManager InventoryManager|nil Instância do InventoryManager (gameplay), nil se overrideItemsList for usado.
---@param itemDataManager ItemDataManager Instância do ItemDataManager.
---@param overrideItemsList table|nil Lista de itemInstance para exibir (usado por ExtractionSummaryScene).
---@return table itemClickAreas Tabela de áreas clicáveis para os itens desenhados (se overrideItemsList) ou a inventoryGridArea.
function HunterInventoryColumn.draw(x, y, w, h, inventoryManager, itemDataManager, overrideItemsList)
    if not itemDataManager then
        print("ERRO [HunterInventoryColumn.draw]: itemDataManager é obrigatório.")
        love.graphics.setColor(colors.red)
        love.graphics.printf("Erro: ItemData Mgr!", x + w / 2, y + h / 2, 0, "center")
        love.graphics.setColor(colors.white)
        return {}
    end

    if overrideItemsList then
        local itemSlotSize = 48
        local itemPadding = 5

        local colsAvailable = math.max(1, math.floor((w - itemPadding) / (itemSlotSize + itemPadding)))
        local rowsAvailable = math.max(1, math.floor((h - itemPadding) / (itemSlotSize + itemPadding)))

        local totalGridRenderWidth = colsAvailable * itemSlotSize + math.max(0, colsAvailable - 1) * itemPadding
        local totalGridRenderHeight = rowsAvailable * itemSlotSize + math.max(0, rowsAvailable - 1) * itemPadding

        local gridStartX = x + (w - totalGridRenderWidth) / 2
        local gridStartY = y + (h - totalGridRenderHeight) / 2 -- Centraliza a grade na altura também

        local drawnItemAreas = {}                              -- Para tooltips, se necessário no futuro

        -- 1. Desenha o fundo da grade para todas as células visíveis
        for r = 0, rowsAvailable - 1 do
            for c = 0, colsAvailable - 1 do
                local cellX = gridStartX + c * (itemSlotSize + itemPadding)
                local cellY = gridStartY + r * (itemSlotSize + itemPadding)
                elements.drawEmptySlotBackground(cellX, cellY, itemSlotSize, itemSlotSize)
            end
        end

        -- 2. Desenha os itens sobre a grade
        local itemCount = 0
        for r = 0, rowsAvailable - 1 do
            for c = 0, colsAvailable - 1 do
                itemCount = itemCount + 1
                if itemCount > #overrideItemsList then break end

                local itemInstance = overrideItemsList[itemCount]
                if itemInstance and itemInstance.icon then
                    local cellX = gridStartX + c * (itemSlotSize + itemPadding)
                    local cellY = gridStartY + r * (itemSlotSize + itemPadding)

                    local area = {
                        x = cellX,
                        y = cellY,
                        w = itemSlotSize,
                        h = itemSlotSize,
                        item = itemInstance
                    }
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.draw(itemInstance.icon, area.x, area.y, 0,
                        area.w / itemInstance.icon:getWidth(), area.h / itemInstance.icon:getHeight())
                    elements.drawRarityBorderAndGlow(itemInstance.rarity or 'E', area.x, area.y, area.w, area.h)
                    table.insert(drawnItemAreas, area) -- Guarda a área do item desenhado
                end
            end
            if itemCount > #overrideItemsList then break end
        end

        -- Retorna a área da grade e as áreas dos itens desenhados
        -- A cena de sumário usará 'drawnItemAreas' para tooltips
        -- e 'gridArea' se precisar saber os limites da grade como um todo.
        return {
            gridArea = { x = gridStartX, y = gridStartY, w = totalGridRenderWidth, h = totalGridRenderHeight },
            itemSlots = drawnItemAreas
        }
    else
        -- Comportamento original: usa InventoryManager (para InventoryScreen)
        local inventoryGridArea = { x = x, y = y, w = w, h = h }
        if inventoryManager then
            local inventoryItems = inventoryManager:getInventoryGridItems()
            local gridDims = inventoryManager:getGridDimensions()
            local invRows = gridDims and gridDims.rows
            local invCols = gridDims and gridDims.cols

            if invRows and invCols then
                ItemGridUI.drawItemGrid(inventoryItems, invRows, invCols,
                    x, y, w, h, itemDataManager, nil)
            else
                love.graphics.setColor(colors.red)
                love.graphics.printf("Erro: Dimensões Inválidas!", x + w / 2, y + h / 2, 0, "center", "center")
                love.graphics.setColor(colors.white)
            end
        else
            love.graphics.setColor(colors.red)
            love.graphics.printf("Erro: Inv Manager!", x + w / 2, y + h / 2, 0, "center", "center")
            love.graphics.setColor(colors.white)
        end
        return inventoryGridArea -- Retorna a área da grade como antes
    end
end

return HunterInventoryColumn
