-- src/ui/inventory/sections/equipment_section.lua
local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")
local elements = require("src.ui.ui_elements")

local EquipmentSection = {}

-- Função HELPER para desenhar um único slot (EQUIPAMENTO ou RUNA)
-- (Movido de inventory_screen, pois é usado apenas aqui por enquanto)
local function drawSingleSlot(slotX, slotY, slotW, slotH, item, label)
    if item then
        -- TODO: Desenhar ícone real do item baseado em item.id
        -- Placeholder: Desenha a primeira letra do ID
        love.graphics.setColor(colors.white)
        love.graphics.setFont(fonts.title) -- Usando uma fonte maior para placeholder
        love.graphics.printf(string.sub(item.id, 1, 1), slotX, slotY + slotH * 0.1, slotW, "center")
        love.graphics.setFont(fonts.main) -- Restaura fonte

        -- Desenha borda e brilho da raridade
        if elements and elements.drawRarityBorderAndGlow then
            elements.drawRarityBorderAndGlow(item.rarity or 'E', slotX, slotY, slotW, slotH)
        else -- Fallback
            local rarityColor = colors.rarity[item.rarity or 'E'] or colors.rarity['E']
            love.graphics.setLineWidth(2)
            love.graphics.setColor(rarityColor)
            love.graphics.rectangle("line", slotX, slotY, slotW, slotH, 3, 3)
            love.graphics.setLineWidth(1)
        end

        -- Desenha contagem de itens (se aplicável e > 1)
        if item.quantity and item.quantity > 1 then
            love.graphics.setFont(fonts.stack_count)
            local countStr = elements.formatNumber(item.quantity)
            local textW = fonts.stack_count:getWidth(countStr)
            local textH = fonts.stack_count:getHeight()
            local textX = slotX + slotW - textW - 3
            local textY = slotY + slotH - textH - 1

            love.graphics.setColor(0, 0, 0, 0.6)
            love.graphics.rectangle("fill", textX - 1, textY - 1, textW + 2, textH + 1, 2, 2)
            love.graphics.setColor(colors.white)
            love.graphics.print(countStr, textX, textY)
            love.graphics.setFont(fonts.main)
        end
    else
        -- Desenha slot vazio (usando a nova helper)
        elements.drawEmptySlotBackground(slotX, slotY, slotW, slotH)

        -- Desenha label do slot se fornecido (para equipamento)
        if label then
            love.graphics.setFont(fonts.main_small)
            love.graphics.setColor(colors.text_label)
            love.graphics.printf(label, slotX, slotY + slotH/2 - fonts.main_small:getHeight()/2, slotW, "center")
            love.graphics.setFont(fonts.main)
        end
    end
end


-- Desenha a seção de equipamento (centro) (Movido de inventory_screen)
-- TODO: Precisa receber PlayerManager ou dados de equipamento?
function EquipmentSection.draw(x, y, w, h)
    love.graphics.setFont(fonts.hud)
    love.graphics.setColor(colors.text_highlight)
    love.graphics.printf("EQUIPAMENTO", x, y, w, "center")
    local titleH = fonts.hud:getHeight() * 1.5
    local contentStartY = y + titleH
    local contentH = h - titleH

    -- Área de pré-visualização do personagem (placeholder)
    local previewH = contentH * 0.5
    local previewW = previewH * 0.6
    local previewX = x + (w - previewW) / 2
    local previewY = contentStartY + contentH * 0.05
    love.graphics.setColor(colors.slot_empty_border)
    love.graphics.rectangle("line", previewX, previewY, previewW, previewH)
    love.graphics.setColor(colors.text_label)
    love.graphics.printf("Visual", previewX, previewY + previewH/2 - fonts.main:getHeight()/2, previewW, "center")

    -- Slots de equipamento principais
    local eqSlotSize = 64 -- Usa valor fixo aqui, ou busca de InventoryScreen?
    local eqSpacing = 10 -- Usa valor fixo aqui, ou busca de InventoryScreen?

    local centerX = x + w / 2
    local startEqY = previewY + previewH + eqSpacing * 2

    local equipmentSlots = {
        {id = "weapon",   label="Arma",     relX = -1, relY = 0},
        {id = "armor",    label="Armadura", relX = 1,  relY = 0},
        {id = "amulet",   label="Amuleto",  relX = -1, relY = 1},
        {id = "backpack", label="Mochila",  relX = 1,  relY = 1},
    }

    love.graphics.setLineWidth(1)
    for _, slot in ipairs(equipmentSlots) do
        local slotX = centerX + slot.relX * (eqSlotSize / 2 + eqSpacing / 2) - eqSlotSize / 2
        local slotY = startEqY + slot.relY * (eqSlotSize + eqSpacing)

        -- TODO: Obter o item equipado para este slot (precisa do PlayerManager)
        local equippedItem = nil -- Exemplo: PlayerManager.player.equipment[slot.id]

        -- Chama a função local drawSingleSlot
        drawSingleSlot(slotX, slotY, eqSlotSize, eqSlotSize, equippedItem, slot.label)
    end

    -- Slots de Runas
    local runeSlotSize = 32 -- Usa valor fixo aqui?
    local runeSpacing = 5 -- Usa valor fixo aqui?
    local numRunes = 4
    local totalRunesWidth = numRunes * runeSlotSize + (numRunes - 1) * runeSpacing
    local runesStartX = centerX - totalRunesWidth / 2
    local runesY = startEqY + 2 * (eqSlotSize + eqSpacing)

    love.graphics.setFont(fonts.main)
    love.graphics.setColor(colors.text_label)
    love.graphics.printf("Runas", x, runesY - fonts.main:getHeight() * 1.5, w, "center")

    for i = 1, numRunes do
        local slotX = runesStartX + (i-1) * (runeSlotSize + runeSpacing)
        -- TODO: Obter a runa equipada para este slot
        local equippedRune = nil

        -- Chama a função local drawSingleSlot
        drawSingleSlot(slotX, runesY, runeSlotSize, runeSlotSize, equippedRune)
    end

    love.graphics.setLineWidth(1)
    love.graphics.setFont(fonts.main)
end

return EquipmentSection 