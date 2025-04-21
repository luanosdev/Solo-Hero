-- src/ui/inventory_screen.lua
local elements = require("src.ui.ui_elements")
local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")
local glowShader = nil -- Variável para armazenar o shader, se carregado
-- local player = require("src.entities.player") -- Assumindo que os dados do jogador virão daqui

local InventoryScreen = {}
InventoryScreen.isVisible = false
InventoryScreen.slotsPerRow = 8 -- Aumentado de 6 para 8
InventoryScreen.slotSize = 48 -- Tamanho base para inventário
InventoryScreen.slotSpacing = 5
InventoryScreen.equipmentSlotSize = 64 -- Tamanho maior para slots de equipamento
InventoryScreen.runeSlotSize = 32 -- Tamanho menor para runas

-- Função para obter o shader (será chamado pelo main.lua)
function InventoryScreen.setGlowShader(shader)
    glowShader = shader
end

-- Função para alternar a visibilidade e pausar/retomar o jogo
function InventoryScreen.toggle()
    -- print("  [InventoryScreen] toggle START. Current isVisible:", InventoryScreen.isVisible) -- DEBUG Removido
    InventoryScreen.isVisible = not InventoryScreen.isVisible
    -- print("  [InventoryScreen] toggle END. New isVisible:", InventoryScreen.isVisible) -- DEBUG Removido
    -- A lógica real de pausa/retomada será gerenciada no main.lua
    if InventoryScreen.isVisible then
        -- print("Inventário aberto.") -- DEBUG Removido
        -- TODO: Potencialmente buscar dados frescos do jogador aqui, se necessário
    else
        -- print("Inventário fechado.") -- DEBUG Removido
    end
    return InventoryScreen.isVisible -- Retorna o novo estado
end

function InventoryScreen.update(dt)
    if not InventoryScreen.isVisible then return end
    -- Lógica de atualização da UI, se houver (ex: efeitos de hover, animações)
end

-- Função principal de desenho da tela
function InventoryScreen.draw()
    if not InventoryScreen.isVisible then return end

    local screenW, screenH = love.graphics.getDimensions()
    -- Dimensões e posição do painel principal (Aumentado)
    local panelW = math.min(screenW * 0.95, 1400)
    local panelH = math.min(screenH * 0.85, 800)
    local panelX = (screenW - panelW) / 2
    local panelY = (screenH - panelH) / 2
    -- print("  [InventoryScreen.draw] Calculou Painel e Seções") -- DEBUG Removido

    -- print("  [InventoryScreen.draw] Chamando drawWindowFrame...") -- DEBUG Removido
    elements.drawWindowFrame(panelX, panelY, panelW, panelH, "CHEERFUL JACK")
    -- print("  [InventoryScreen.draw] Retornou de drawWindowFrame") -- DEBUG Removido

    -- Calcula dimensões e posições das seções
    local padding = 20
    local titleHeight = fonts.title:getHeight()
    -- Ajusta Y inicial das seções para caber títulos internos
    local sectionTopY = panelY + titleHeight * 1.5 + padding
    local sectionContentH = panelH - (sectionTopY - panelY) - padding

    -- Larguras das seções (Ajustando para talvez dar mais espaço ao equipamento?)
    local statsW = panelW * 0.25
    local equipmentW = panelW * 0.30 -- Aumentado
    local inventoryW = panelW - statsW - equipmentW - padding * 4 -- O restante

    local statsX = panelX + padding
    local equipmentX = statsX + statsW + padding
    local inventoryX = equipmentX + equipmentW + padding

    InventoryScreen.drawStats(statsX, sectionTopY, statsW, sectionContentH)
    InventoryScreen.drawEquipment(equipmentX, sectionTopY, equipmentW, sectionContentH)
    InventoryScreen.drawInventory(inventoryX, sectionTopY, inventoryW, sectionContentH)
end

-- Desenha a seção de estatísticas (esquerda)
function InventoryScreen.drawStats(x, y, w, h)
    -- print("    [InventoryScreen.drawStats] START") -- DEBUG Removido
    -- Adiciona Título da Seção
    love.graphics.setFont(fonts.hud)
    love.graphics.setColor(colors.text_highlight)
    love.graphics.printf("ESTATÍSTICAS", x, y, w, "center")
    local titleH = fonts.hud:getHeight() * 1.5
    local currentY = y + titleH -- Inicia conteúdo abaixo do título
    local contentH = h - titleH -- Altura disponível para o conteúdo

    local lineHeight = fonts.main:getHeight() * 1.3
    local sectionTitleLineHeight = fonts.hud:getHeight() * 1.5

    -- Dados de exemplo baseados na imagem (substituir com dados reais)
    local stats = {
        {label = "Hit Points", value = string.format("%d/%d", 612, 612), color = colors.hp_fill},
        {label = "Experience", value = string.format("%d/%d", 265783, 276000), color = colors.xp_fill},
        {spacer = lineHeight * 0.5},
        {label = "Action Points (AP)", value = 9},
        {label = "Saved AP", value = 5},
        {label = "Starting AP", value = 11},
        {label = "AP Maximum", value = 23},
        {spacer = lineHeight * 0.5},
        {label = "SECONDARY STATS", isTitle = true},
        {label = "Regeneration", value = 40, color = colors.heal},
        {label = "Close Quarters Damage", value = 15},
        {label = "Learnability", value = 98},
        {label = "Initiative", value = 30},
        {label = "Precision", value = 32},
        {label = "Encumbrance", value = string.format("%d/%d", 205, 290), color = colors.text_label}, -- Peso
        {label = "Inspiration", value = 0},
        {label = "Authority", value = 0},
        {label = "Movement Speed", value = 1.9},
        {label = "Critical Hit Chance", value = 35, color = colors.damage_crit},
        {label = "Psionic Damage", value = 11, color = {0.4, 0.0, 0.8, 1.0}}, -- Roxo
        {label = "Skill Points per Level", value = 17, color = colors.text_gold},
        {label = "Detection Time", value = 4.8},
    }

    love.graphics.setFont(fonts.main)
    for _, stat in ipairs(stats) do
        if stat.isTitle then
            love.graphics.setFont(fonts.hud)
            love.graphics.setColor(colors.text_highlight)
            love.graphics.print(stat.label, x, currentY)
            currentY = currentY + sectionTitleLineHeight
        elseif stat.spacer then
             currentY = currentY + stat.spacer
        else
            love.graphics.setFont(fonts.main)
            -- Etiqueta
            love.graphics.setColor(colors.text_label)
            love.graphics.print(stat.label, x, currentY)
            -- Valor
            love.graphics.setColor(stat.color or colors.text_value) -- Usa cor específica ou padrão
            local valueStr = tostring(stat.value)
            love.graphics.printf(valueStr, x, currentY, w, "right") -- Alinha valor à direita
            currentY = currentY + lineHeight
        end
        -- Impede que o texto ultrapasse a altura da seção de conteúdo
        if currentY > y + h - lineHeight then break end
    end
    love.graphics.setFont(fonts.main) -- Restaura a fonte padrão
    -- print("    [InventoryScreen.drawStats] END") -- DEBUG Removido
end

-- Desenha a seção de equipamento (centro)
function InventoryScreen.drawEquipment(x, y, w, h)
    -- print("    [InventoryScreen.drawEquipment] START") -- DEBUG Removido
    -- Adiciona Título da Seção
    love.graphics.setFont(fonts.hud)
    love.graphics.setColor(colors.text_highlight)
    love.graphics.printf("EQUIPAMENTO", x, y, w, "center")
    local titleH = fonts.hud:getHeight() * 1.5
    local contentStartY = y + titleH -- Y onde o conteúdo começa
    local contentH = h - titleH -- Altura disponível

    -- Área de pré-visualização do personagem (placeholder) - Mantendo por enquanto
    local previewH = contentH * 0.5 -- Reduzido para dar espaço aos slots
    local previewW = previewH * 0.6
    local previewX = x + (w - previewW) / 2
    local previewY = contentStartY + contentH * 0.05 -- Um pouco abaixo do título
    love.graphics.setColor(colors.slot_empty_border)
    love.graphics.rectangle("line", previewX, previewY, previewW, previewH)
    love.graphics.setColor(colors.text_label)
    love.graphics.printf("Visual", previewX, previewY + previewH/2 - fonts.main:getHeight()/2, previewW, "center")

    -- Slots de equipamento principais
    local eqSlotSize = InventoryScreen.equipmentSlotSize
    local eqSpacing = InventoryScreen.slotSpacing * 2 -- Espaçamento entre slots de equipamento

    -- Posições relativas ao centro da seção ou à preview? Vamos tentar relativo ao centro da seção.
    local centerX = x + w / 2
    local startEqY = previewY + previewH + eqSpacing * 2 -- Começa abaixo da preview

    local equipmentSlots = {
        {id = "weapon",   label="Arma",     relX = -1, relY = 0},
        {id = "armor",    label="Armadura", relX = 1,  relY = 0},
        {id = "amulet",   label="Amuleto",  relX = -1, relY = 1},
        {id = "backpack", label="Mochila",  relX = 1,  relY = 1},
    }

    love.graphics.setLineWidth(1)
    for _, slot in ipairs(equipmentSlots) do
        -- Calcula X baseado no centro, relX (-1 ou 1), tamanho e espaçamento
        local slotX = centerX + slot.relX * (eqSlotSize / 2 + eqSpacing / 2) - eqSlotSize / 2
        -- Calcula Y baseado na posição inicial e relY
        local slotY = startEqY + slot.relY * (eqSlotSize + eqSpacing)

        -- TODO: Obter o item equipado para este slot
        local equippedItem = nil -- Exemplo: PlayerManager.player.equipment[slot.id]

        InventoryScreen.drawSingleSlot(slotX, slotY, eqSlotSize, eqSlotSize, equippedItem, slot.label)
    end

    -- Slots de Runas
    local runeSlotSize = InventoryScreen.runeSlotSize
    local runeSpacing = InventoryScreen.slotSpacing
    local numRunes = 4 -- Quantidade de runas
    local totalRunesWidth = numRunes * runeSlotSize + (numRunes - 1) * runeSpacing
    local runesStartX = centerX - totalRunesWidth / 2
    local runesY = startEqY + 2 * (eqSlotSize + eqSpacing) -- Abaixo dos slots principais

    love.graphics.setFont(fonts.main)
    love.graphics.setColor(colors.text_label)
    love.graphics.printf("Runas", x, runesY - fonts.main:getHeight() * 1.5, w, "center") -- Título para runas

    for i = 1, numRunes do
        local slotX = runesStartX + (i-1) * (runeSlotSize + runeSpacing)
        -- TODO: Obter a runa equipada para este slot
        local equippedRune = nil -- Exemplo: PlayerManager.player.runes[i]

        InventoryScreen.drawSingleSlot(slotX, runesY, runeSlotSize, runeSlotSize, equippedRune)
    end

    love.graphics.setLineWidth(1)
    love.graphics.setFont(fonts.main) -- Garante fonte padrão
    -- print("    [InventoryScreen.drawEquipment] END") -- DEBUG Removido
end

-- Desenha a seção do inventário (direita)
function InventoryScreen.drawInventory(x, y, w, h)
    -- print("    [InventoryScreen.drawInventory] START") -- DEBUG Removido
    -- Adiciona Título da Seção
    love.graphics.setFont(fonts.hud)
    love.graphics.setColor(colors.text_highlight)

    local titleH = fonts.hud:getHeight() * 1.5
    local contentStartY = y + titleH -- Y onde o conteúdo começa
    local contentH = h - titleH -- Altura disponível

    local slotSize = InventoryScreen.slotSize
    local spacing = InventoryScreen.slotSpacing
    local cols = InventoryScreen.slotsPerRow -- Agora 8
    local rows = 6 -- Fixo em 6 linhas por enquanto

    -- Calcula a largura real da grade para centralizar título e itens
    local gridWidth = cols * slotSize + math.max(0, cols - 1) * spacing
    local gridStartX = x + (w - gridWidth) / 2 -- X onde a grade começa

    -- Conta itens atuais e calcula total de slots
    local currentItemCount = 0
    -- TODO: Obter inventário real do PlayerManager ou similar
    local inventoryItems = { -- Usando placeholder por enquanto
        { id = "potion_heal", quantity = 6, rarity = "C" }, { id = "scrap", quantity = 19, rarity = "E" }, nil, nil, nil, nil, nil, nil, -- Linha 1 (8 cols)
        { id = "molotov", quantity = 3, rarity = "B" }, { id = "notes", quantity = 2, rarity = "E" }, { id = "ammo_pistol", quantity = 7, rarity = "E" }, { id = "suit", rarity = "A" }, { id = "energy_cell", quantity = 2, rarity = "B" }, nil, nil, nil, -- Linha 2
        { id = "portal_device", rarity = "S" }, { id = "comic1", rarity = "D" }, { id = "duct_tape", quantity = 35, rarity = "E" }, { id = "crystal_shard", quantity = 6, rarity = "A" }, nil, nil, nil, nil, -- Linha 3
        { id = "energy_drink", quantity = 20, rarity = "E" }, { id = "component", quantity = 80, rarity = "E" }, { id = "food_can", quantity = 7, rarity = "E" }, { id = "comic2", rarity = "D" }, { id = "medkit", quantity = 1, rarity = "B"}, nil, nil, nil, -- Linha 4
        { id = "key", quantity = 4, rarity = "E" }, { id = "scissors", quantity = 4, rarity = "E" }, { id = "lighter", quantity = 2, rarity = "E" }, { id = "toolbox", rarity = "B" }, { id = "stimpack", quantity = 4, rarity = "C"}, nil, nil, nil, -- Linha 5
         nil, nil, nil, nil, nil, nil, nil, nil, -- Linha 6
    }
    -- Contagem real dos itens no placeholder
    for _, item in ipairs(inventoryItems) do
        if item then currentItemCount = currentItemCount + 1 end
    end
    local totalSlots = rows * cols -- 6 * 8 = 48
    local countText = string.format(" (%d/%d)", currentItemCount, totalSlots) -- TODO: O total deveria vir da mochila?

    -- Desenha Título Centralizado com Contagem
    local titleText = "INVENTÁRIO" .. countText
    love.graphics.printf(titleText, x, y, w, "center") -- Desenha o título

    -- Ajusta Y inicial da grade de slots para ficar abaixo do título
    local startY = contentStartY
    -- Ajusta X inicial da grade para centralizar
    local startX = gridStartX

    -- Preenche a tabela inventoryItems se necessário (usando o placeholder)
    local currentSize = #inventoryItems
    if currentSize < totalSlots then
        for i = currentSize + 1, totalSlots do
            inventoryItems[i] = nil -- Atribuição direta
        end
    elseif currentSize > totalSlots then -- Trunca se placeholder for maior
         for i = currentSize, totalSlots + 1, -1 do
             inventoryItems[i] = nil
         end
    end

    -- Reativando slotIndex e setLineWidth
    local slotIndex = 1
    love.graphics.setLineWidth(1)

    -- Loop principal para desenhar os slots
    for r = 0, rows - 1 do
        for c = 0, cols - 1 do
            local slotX = startX + c * (slotSize + spacing)
            local slotY = startY + r * (slotSize + spacing)
            local item = inventoryItems[slotIndex]

            -- Usa a função helper para desenhar o slot
            InventoryScreen.drawSingleSlot(slotX, slotY, slotSize, slotSize, item)

            slotIndex = slotIndex + 1
            -- Não precisamos mais do break interno aqui se a tabela já tem o tamanho certo
            -- if slotIndex > totalSlots then break end
        end
        -- Nem do break externo
        -- if slotIndex > totalSlots then break end
    end

    love.graphics.setLineWidth(1)
    love.graphics.setFont(fonts.main) -- Garante que a fonte padrão seja restaurada
    -- print("    [InventoryScreen.drawInventory] END (Código completo reativado)") -- DEBUG Removido
end


-- Função HELPER para desenhar um único slot (equipamento ou inventário)
function InventoryScreen.drawSingleSlot(slotX, slotY, slotW, slotH, item, label)
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
             local countStr = tostring(item.quantity)
             local textW = fonts.stack_count:getWidth(countStr)
             local textH = fonts.stack_count:getHeight()
             -- Posiciona no canto inferior direito
             local textX = slotX + slotW - textW - 3
             local textY = slotY + slotH - textH - 1

             love.graphics.setColor(0, 0, 0, 0.6) -- Fundo semi-transparente
             love.graphics.rectangle("fill", textX - 1, textY - 1, textW + 2, textH + 1, 2, 2)
             love.graphics.setColor(colors.white)
             love.graphics.print(countStr, textX, textY)
             love.graphics.setFont(fonts.main) -- Restaura fonte
         end
    else
        -- Desenha slot vazio
        love.graphics.setColor(colors.slot_empty_bg)
        love.graphics.rectangle("fill", slotX, slotY, slotW, slotH, 3, 3)
        love.graphics.setColor(colors.slot_empty_border)
        love.graphics.rectangle("line", slotX, slotY, slotW, slotH, 3, 3)

        -- Desenha label do slot se fornecido (para equipamento)
        if label then
            love.graphics.setFont(fonts.main_small)
            love.graphics.setColor(colors.text_label)
            love.graphics.printf(label, slotX, slotY + slotH/2 - fonts.main_small:getHeight()/2, slotW, "center")
            love.graphics.setFont(fonts.main)
        end
    end
end


-- Função para processar input quando o inventário está visível
function InventoryScreen.keypressed(key)
    if not InventoryScreen.isVisible then return false end

    -- TODO: Adicionar lógica de navegação/interação dentro do inventário
    if key == "escape" or key == "tab" then -- 'tab' também fecha (a pausa é tratada em main.lua)
        InventoryScreen.toggle()
        return true
    end

    -- print("Inventory handled key:", key) -- DEBUG Removido
    return true -- Consome outras teclas por enquanto
end

-- Função para tratar cliques do mouse quando o inventário está visível
function InventoryScreen.mousepressed(x, y, button)
    if not InventoryScreen.isVisible then return false end

    -- TODO: Lógica de clique nos slots
    -- print("Inventory click detection placeholder @", x, y, button) -- DEBUG Removido

    -- Consome o clique por enquanto para evitar interação com o jogo
    return true
end

return InventoryScreen 