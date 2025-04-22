-- src/ui/inventory/sections/inventory_grid_section.lua
local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")
local elements = require("src.ui.ui_elements")
local ManagerRegistry = require("src.managers.manager_registry")

local InventoryGridSection = {}

-- Função helper simples para cópia rasa (evita modificar o itemDataStore)
-- (Movida junto com a lógica do placeholder)
local function shallowcopy(original)
    if type(original) ~= 'table' then return original end
    local copy = {}
    for k, v in pairs(original) do
        copy[k] = v
    end
    return copy
end

-- Função HELPER para desenhar um ITEM COLOCADO (pode ocupar múltiplos slots)
local function drawPlacedItem(visualX, visualY, visualW, visualH, placedItemInstance)
    -- Acessa dados diretamente da instância (não mais .itemRef)
    local itemBaseId = placedItemInstance.itemBaseId
    local quantity = placedItemInstance.quantity
    local rarity = placedItemInstance.rarity or 'E'
    local stackable = placedItemInstance.stackable

    -- TODO: Desenhar ícone real do item (usando itemBaseId)
    -- Placeholder: Desenha a primeira letra do ID no espaço total
    love.graphics.setColor(colors.white)
    love.graphics.setFont(fonts.title)
    local char = string.sub(itemBaseId or "?", 1, 1)
    love.graphics.printf(char, visualX, visualY + visualH * 0.1, visualW, "center")
    love.graphics.setFont(fonts.main)

    -- Desenha borda e brilho da raridade ao redor do espaço total
    if elements and elements.drawRarityBorderAndGlow then
        elements.drawRarityBorderAndGlow(rarity, visualX, visualY, visualW, visualH)
    else -- Fallback
        local rarityColor = colors.rarity[rarity] or colors.rarity['E']
        love.graphics.setLineWidth(2)
        love.graphics.setColor(rarityColor)
        love.graphics.rectangle("line", visualX, visualY, visualW, visualH, 3, 3)
        love.graphics.setLineWidth(1)
    end

    -- Desenha contagem de itens (se aplicável e > 1)
    if stackable and quantity and quantity > 1 then
        love.graphics.setFont(fonts.stack_count)
        local countStr = elements.formatNumber(quantity) -- Usar helper formatNumber
        local textW = fonts.stack_count:getWidth(countStr)
        local textH = fonts.stack_count:getHeight()
        local textX = visualX + visualW - textW - 3
        local textY = visualY + visualH - textH - 1

        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.rectangle("fill", textX - 1, textY - 1, textW + 2, textH + 1, 2, 2)
        love.graphics.setColor(colors.white)
        love.graphics.print(countStr, textX, textY)
        love.graphics.setFont(fonts.main)
    end
end

-- Desenha a seção do inventário (direita)
function InventoryGridSection.draw(x, y, w, h)
    -- Obtém o InventoryManager do Registry
    local inventoryMgr = ManagerRegistry:get("inventoryManager")
    if not inventoryMgr then
        print("ERRO: InventoryManager não encontrado no Registry para desenhar a grade!")
        -- Desenha uma mensagem de erro na tela
        love.graphics.setFont(fonts.title)
        love.graphics.setColor(colors.red)
        love.graphics.printf("Erro: InventoryManager não encontrado!", x, y, w, "center")
        love.graphics.setFont(fonts.main)
        return
    end

    -- Obtém dados da grade do InventoryManager
    local inventoryGrid = inventoryMgr:getInventoryGrid() -- Agora existe!
    local rows = inventoryMgr.rows or 6 -- Acessa diretamente a propriedade
    local cols = inventoryMgr.cols or 7 -- Acessa diretamente a propriedade
    local currentItemCount = inventoryMgr:getTotalItemCount() -- Chama o novo método
    
    -- Define slotSize e spacing localmente (não pertencem ao InventoryManager)
    local slotSize = 58 
    local spacing = 5

    love.graphics.setFont(fonts.title)
    love.graphics.setColor(colors.text_highlight)

    local titleH = fonts.title:getHeight() * 1.2
    local contentStartY = y + titleH
    local contentH = h - titleH

    local gridWidth = cols * slotSize + math.max(0, cols - 1) * spacing
    local gridStartX = x + (w - gridWidth) / 2
    local startY = contentStartY
    local startX = gridStartX

    -- Desenha o título com a contagem real de itens
    local countText = string.format(" (%d itens)", currentItemCount)
    local titleText = "INVENTÁRIO" .. countText
    love.graphics.printf(titleText, x, y, w, "center")

    love.graphics.setLineWidth(1)
    local drawnItemInstances = {} -- Para evitar desenhar itens grandes múltiplas vezes

    -- Desenha a grade com base nos dados REAIS do inventoryGrid
    for r = 1, rows do
        for c = 1, cols do
            local slotX = startX + (c - 1) * (slotSize + spacing)
            local slotY = startY + (r - 1) * (slotSize + spacing)
            
            -- Acessa a grid real obtida do InventoryManager
            -- inventoryGrid[r][c] agora contém a instância do item ou nil
            local placedItemInstance = inventoryGrid[r] and inventoryGrid[r][c] or nil 

            if placedItemInstance then
                -- Verifica se este item já foi desenhado (importante para itens > 1x1)
                if not drawnItemInstances[placedItemInstance] then 
                    -- Obtém dimensões do grid da instância
                    local itemW = placedItemInstance.gridWidth or 1
                    local itemH = placedItemInstance.gridHeight or 1
                    
                    -- Calcula o tamanho visual total do item
                    local itemVisualW = itemW * slotSize + math.max(0, itemW - 1) * spacing
                    local itemVisualH = itemH * slotSize + math.max(0, itemH - 1) * spacing

                    -- Chama helper local para desenhar o item no slot inicial (slotX, slotY)
                    -- O helper foi ajustado para não usar .itemRef
                    drawPlacedItem(slotX, slotY, itemVisualW, itemVisualH, placedItemInstance)
                    
                    -- Marca esta instância específica como desenhada
                    drawnItemInstances[placedItemInstance] = true 
                end
            else
                -- Desenha um slot vazio se não houver item
                elements.drawEmptySlotBackground(slotX, slotY, slotSize, slotSize)
            end
        end
    end

    love.graphics.setLineWidth(1)
    love.graphics.setFont(fonts.main)
end

return InventoryGridSection 