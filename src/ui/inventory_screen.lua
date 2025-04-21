-- src/ui/inventory_screen.lua
local elements = require("src.ui.ui_elements")
local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")
local glowShader = nil -- Variável para armazenar o shader, se carregado
-- local player = require("src.entities.player") -- Assumindo que os dados do jogador virão daqui

local InventoryScreen = {}
InventoryScreen.isVisible = false
InventoryScreen.slotsPerRow = 6 -- Exemplo, ajuste conforme necessário
InventoryScreen.slotSize = 48
InventoryScreen.slotSpacing = 5

-- Função para obter o shader (será chamado pelo main.lua)
function InventoryScreen.setGlowShader(shader)
    glowShader = shader
end

-- Função para alternar a visibilidade e pausar/retomar o jogo
function InventoryScreen.toggle()
    print("  [InventoryScreen] toggle START. Current isVisible:", InventoryScreen.isVisible) -- DEBUG
    InventoryScreen.isVisible = not InventoryScreen.isVisible
    print("  [InventoryScreen] toggle END. New isVisible:", InventoryScreen.isVisible) -- DEBUG
    -- A lógica real de pausa/retomada será gerenciada no main.lua
    if InventoryScreen.isVisible then
        print("Inventário aberto.")
        -- TODO: Potencialmente buscar dados frescos do jogador aqui, se necessário
    else
        print("Inventário fechado.")
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
    local panelW = math.min(screenW * 0.95, 1400) -- Aumentado de 0.9/1200
    local panelH = math.min(screenH * 0.85, 800)
    local panelX = (screenW - panelW) / 2
    local panelY = (screenH - panelH) / 2
    print("  [InventoryScreen.draw] Calculou Painel e Seções") -- DEBUG

    print("  [InventoryScreen.draw] Chamando drawWindowFrame...") -- DEBUG
    elements.drawWindowFrame(panelX, panelY, panelW, panelH, "CHEERFUL JACK")
    print("  [InventoryScreen.draw] Retornou de drawWindowFrame") -- DEBUG

    -- Calcula dimensões e posições das seções
    local padding = 20
    local titleHeight = fonts.title:getHeight()
    -- Ajusta Y inicial das seções para caber títulos internos
    local sectionTopY = panelY + titleHeight * 1.5 + padding
    local sectionContentH = panelH - (sectionTopY - panelY) - padding

    -- Larguras das seções (Voltando para 3 seções, ex: 25%, 25%, 50%)
    local statsW = panelW * 0.25
    local equipmentW = panelW * 0.25
    local inventoryW = panelW - statsW - equipmentW - padding * 4 -- O restante
    -- local detailsW = ... -- Removido

    local statsX = panelX + padding
    local equipmentX = statsX + statsW + padding
    local inventoryX = equipmentX + equipmentW + padding
    -- local detailsX = ... -- Removido
    -- print("InventoryScreen.draw - Calculou Seções") -- DEBUG

    InventoryScreen.drawStats(statsX, sectionTopY, statsW, sectionContentH)

    InventoryScreen.drawEquipment(equipmentX, sectionTopY, equipmentW, sectionContentH)

    InventoryScreen.drawInventory(inventoryX, sectionTopY, inventoryW, sectionContentH)

end

-- Desenha a seção de estatísticas (esquerda)
function InventoryScreen.drawStats(x, y, w, h)
    print("    [InventoryScreen.drawStats] START") -- DEBUG
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
            local valueWidth = fonts.main:getWidth(valueStr)
            love.graphics.printf(valueStr, x, currentY, w, "right") -- Alinha valor à direita
            currentY = currentY + lineHeight
        end
        -- Impede que o texto ultrapasse a altura da seção de conteúdo
        if currentY > y + h - lineHeight then break end -- Usa y+h como limite inferior total
    end
    love.graphics.setFont(fonts.main) -- Restaura a fonte padrão
    print("    [InventoryScreen.drawStats] END") -- DEBUG
end

-- Desenha a seção de equipamento (centro)
function InventoryScreen.drawEquipment(x, y, w, h)
    print("    [InventoryScreen.drawEquipment] START") -- DEBUG
    -- Adiciona Título da Seção
    love.graphics.setFont(fonts.hud)
    love.graphics.setColor(colors.text_highlight)
    love.graphics.printf("EQUIPAMENTO", x, y, w, "center")
    local titleH = fonts.hud:getHeight() * 1.5
    local contentStartY = y + titleH -- Y onde o conteúdo começa
    local contentH = h - titleH -- Altura disponível

    -- Área de pré-visualização do personagem (placeholder)
    local previewH = contentH * 0.6
    local previewW = previewH * 0.6 -- Proporção visual
    local previewX = x + (w - previewW) / 2
    -- Ajusta Y da preview para começar abaixo do título
    local previewY = contentStartY + contentH * 0.05
    love.graphics.setColor(colors.slot_empty_border)
    love.graphics.rectangle("line", previewX, previewY, previewW, previewH)
    love.graphics.setColor(colors.text_label)
    love.graphics.printf("Visual do Personagem", previewX, previewY + previewH/2 - fonts.main:getHeight()/2, previewW, "center")

    -- Slots de equipamento (posições de exemplo, ajuste conforme necessário)
    local slotSize = InventoryScreen.slotSize
    local spacing = InventoryScreen.slotSpacing * 3 -- Aumentado de 2 para 3 para mais espaço
    local slots = {
        -- Coluna Esquerda
        {id = "head",     relX = -1, relY = 0},
        {id = "chest",    relX = -1, relY = 1},
        {id = "legs",     relX = -1, relY = 2},
        {id = "feet",     relX = -1, relY = 3},
        -- Coluna Direita
        {id = "necklace", relX = 1, relY = 0},
        {id = "backpack", relX = 1, relY = 1},
        {id = "belt",     relX = 1, relY = 2},
        {id = "gloves",   relX = 1, relY = 3},
        -- Abaixo
        {id = "ring1",    relX = -0.5, relY = 4.5},
        {id = "ring2",    relX = 0.5,  relY = 4.5},
        {id = "weapon1",  relX = -0.5, relY = 5.5, sizeMultiplier = 1.5}, -- Slot maior para arma?
        {id = "weapon2",  relX = 0.5,  relY = 5.5, sizeMultiplier = 1.5},
    }

    local equipmentOriginX = previewX + previewW / 2
    local equipmentOriginY = previewY

    love.graphics.setLineWidth(1)
    for _, slot in ipairs(slots) do
        local currentSlotSize = slot.sizeMultiplier and slotSize * slot.sizeMultiplier or slotSize
        local slotX = equipmentOriginX + slot.relX * (slotSize + spacing) - (slot.relX > 0 and currentSlotSize or (slot.relX < 0 and 0 or currentSlotSize/2))
        local slotY = equipmentOriginY + slot.relY * (slotSize + spacing)

        -- TODO: Obter o item equipado para este slot (PlayerManager.player.equipment[slot.id] ou algo assim)
        local equippedItem = nil -- Exemplo: PlayerManager.player.equipment[slot.id]

        if equippedItem then
             -- TODO: Desenhar ícone do item
             -- love.graphics.draw(equippedItem.icon, slotX, slotY, 0, slotSize / equippedItem.icon:getWidth(), slotSize / equippedItem.icon:getHeight())
             -- Desenhar borda de raridade
             if elements and elements.drawRarityBorderAndGlow then
                elements.drawRarityBorderAndGlow(equippedItem.rarity, slotX, slotY, slotSize, slotSize)
             else -- Fallback se a função de brilho não existir
                local rarityColor = colors.rarity[equippedItem.rarity or 'E'] or colors.rarity['E']
                love.graphics.setLineWidth(2)
                love.graphics.setColor(rarityColor)
                love.graphics.rectangle("line", slotX, slotY, currentSlotSize, slotSize, 3, 3)
                love.graphics.setLineWidth(1)
             end
        else
            -- Desenha slot vazio
            love.graphics.setColor(colors.slot_empty_bg)
            love.graphics.rectangle("fill", slotX, slotY, currentSlotSize, slotSize, 3, 3)
            love.graphics.setColor(colors.slot_empty_border)
            love.graphics.rectangle("line", slotX, slotY, currentSlotSize, slotSize, 3, 3)
        end
    end
    love.graphics.setLineWidth(1)
    print("    [InventoryScreen.drawEquipment] END") -- DEBUG
end

-- Desenha a seção do inventário (direita)
function InventoryScreen.drawInventory(x, y, w, h)
    print("    [InventoryScreen.drawInventory] START") -- DEBUG
    -- Adiciona Título da Seção
    love.graphics.setFont(fonts.hud)
    love.graphics.setColor(colors.text_highlight)

    local titleH = fonts.hud:getHeight() * 1.5
    local contentStartY = y + titleH -- Y onde o conteúdo começa
    local contentH = h - titleH -- Altura disponível

    local slotSize = InventoryScreen.slotSize
    local spacing = InventoryScreen.slotSpacing
    local cols = InventoryScreen.slotsPerRow
    local rows = math.floor((contentH + spacing) / (slotSize + spacing))

    -- Calcula a largura real da grade para centralizar título e itens
    local gridWidth = cols * slotSize + math.max(0, cols - 1) * spacing
    local gridStartX = x + (w - gridWidth) / 2 -- X onde a grade começa

    -- Conta itens atuais e total de slots
    local currentItemCount = 0
    local inventoryItems = { -- Usando placeholder por enquanto
        { id = "potion_heal", quantity = 6, rarity = "C" }, { id = "scrap", quantity = 19, rarity = "E" }, nil, nil, nil, nil, -- Linha 1
        { id = "molotov", quantity = 3, rarity = "B" }, { id = "notes", quantity = 2, rarity = "E" }, { id = "ammo_pistol", quantity = 7, rarity = "E" }, { id = "suit", rarity = "A" }, { id = "energy_cell", quantity = 2, rarity = "B" }, nil, -- Linha 2
        { id = "portal_device", rarity = "S" }, { id = "comic1", rarity = "D" }, { id = "duct_tape", quantity = 35, rarity = "E" }, { id = "crystal_shard", quantity = 6, rarity = "A" }, nil, nil, -- Linha 3
        { id = "energy_drink", quantity = 20, rarity = "E" }, { id = "component", quantity = 80, rarity = "E" }, { id = "food_can", quantity = 7, rarity = "E" }, { id = "comic2", rarity = "D" }, { id = "medkit", quantity = 1, rarity = "B"}, nil, -- Linha 4
        { id = "key", quantity = 4, rarity = "E" }, { id = "scissors", quantity = 4, rarity = "E" }, { id = "lighter", quantity = 2, rarity = "E" }, { id = "toolbox", rarity = "B" }, { id = "stimpack", quantity = 4, rarity = "C"}, nil, -- Linha 5
    }
    for _, item in ipairs(inventoryItems) do
        if item then currentItemCount = currentItemCount + 1 end
    end
    local totalSlots = rows * cols
    local countText = string.format(" (%d/%d)", currentItemCount, totalSlots)

    -- Desenha Título Centralizado com Contagem
    local titleText = "INVENTÁRIO" .. countText
    -- Alternativa (centralizado na grade): love.graphics.printf(titleText, gridStartX, y, gridWidth, "center")

    -- Ajusta Y inicial da grade de slots para ficar abaixo do título
    local startY = contentStartY
    -- Ajusta X inicial da grade para centralizar
    local startX = gridStartX

    --[[ -- COMENTANDO PREPARAÇÃO DO LOOP TAMBÉM ]] -- Removendo comentário do while abaixo
    -- Dados de exemplo do inventário (já definidos acima para contagem)

    -- DEBUG: Verificar valores antes do loop while
    --[[ -- Removendo debug prints
    print(string.format("    [DEBUG] Antes do while: rows=%s, cols=%s, totalSlots=%s, #inventoryItems=%s",
        tostring(rows), tostring(cols), tostring(totalSlots), tostring(#inventoryItems)))
    --]]

    -- Substituindo o while por um for para evitar table.insert dentro do draw
    local currentSize = #inventoryItems
    if currentSize < totalSlots then
        -- print(string.format("    [DEBUG] Preenchendo inventário de %d até %d", currentSize + 1, totalSlots)) -- DEBUG Removido
        for i = currentSize + 1, totalSlots do
            inventoryItems[i] = nil -- Atribuição direta
            -- ADICIONAR verificação de segurança?
            -- if i > 10000 then print("AVISO: Loop for passou de 10000 iterações!"); break end
        end
    end
    --[[ -- Loop while original comentado
    while #inventoryItems < totalSlots do
        -- DEBUG: Verificar condição dentro do loop while (pode gerar muito log)
        -- print(string.format("    [DEBUG] Dentro do while: #inventoryItems=%d, totalSlots=%d", #inventoryItems, totalSlots))
        table.insert(inventoryItems, nil) -- Adiciona nil até que o total de slots seja atendido
        -- ADICIONAR verificação de segurança?
        -- if #inventoryItems > 10000 then print("AVISO: Loop while passou de 10000 iterações!"); break end
    end
    --]]
    -- print("    [DEBUG] Após o preenchimento: #inventoryItems=", #inventoryItems) -- DEBUG Removido

    --[[ -- Mantendo estes comentados por enquanto --]]
    -- Reativando slotIndex e setLineWidth
    local slotIndex = 1
    love.graphics.setLineWidth(1)

    -- Loop principal para desenhar os slots (Estrutura ativa, conteúdo comentado)
    -- Reativando conteúdo do loop
    for r = 0, rows - 1 do
        for c = 0, cols - 1 do
            --[[ -- CONTEÚDO DO LOOP INTERNO AINDA COMENTADO --]]
            -- Reativando conteúdo:
            local slotX = startX + c * (slotSize + spacing)
            local slotY = startY + r * (slotSize + spacing)
            local item = inventoryItems[slotIndex]

            -- Desenha o fundo do slot
            love.graphics.setColor(colors.slot_empty_bg)
            love.graphics.rectangle("fill", slotX, slotY, slotSize, slotSize, 3, 3)

            --[[ -- Removido if item pois item depende de slotIndex --]]
            -- Reativando lógica do item
            if item then
                -- TODO: Desenhar ícone real do item baseado em item.id
                -- Placeholder: Desenha a primeira letra do ID
                love.graphics.setColor(colors.white)
                love.graphics.setFont(fonts.title) -- Usando uma fonte maior para placeholder
                love.graphics.printf(string.sub(item.id, 1, 1), slotX, slotY + slotSize * 0.1, slotSize, "center")
                love.graphics.setFont(fonts.main) -- Restaura fonte

                -- Desenha borda e brilho da raridade
                if elements and elements.drawRarityBorderAndGlow then
                    elements.drawRarityBorderAndGlow(item.rarity or 'E', slotX, slotY, slotSize, slotSize)
                else
                    local rarityColor = colors.rarity[item.rarity or 'E'] or colors.rarity['E']
                    love.graphics.setLineWidth(2)
                    love.graphics.setColor(rarityColor)
                    love.graphics.rectangle("line", slotX, slotY, slotSize, slotSize, 3, 3)
                    love.graphics.setLineWidth(1)
                end

                -- Desenha contagem de itens
                if item.quantity and item.quantity > 1 then
                    love.graphics.setFont(fonts.stack_count)
                    local countStr = tostring(item.quantity)
                    local textW = fonts.stack_count:getWidth(countStr)
                    local textH = fonts.stack_count:getHeight()
                    local textX = slotX + slotSize - textW - 3
                    local textY = slotY + slotSize - textH - 1

                    love.graphics.setColor(0, 0, 0, 0.6)
                    love.graphics.rectangle("fill", textX - 1, textY - 1, textW + 2, textH + 1, 2, 2)
                    love.graphics.setColor(colors.white)
                    love.graphics.print(countStr, textX, textY)
                    love.graphics.setFont(fonts.main)
                end
            else
                -- Desenha borda do slot vazio
                love.graphics.setColor(colors.slot_empty_border)
                love.graphics.rectangle("line", slotX, slotY, slotSize, slotSize, 3, 3)
            end
            -- slotIndex = slotIndex + 1 -- Depende de slotIndex
            -- if slotIndex > totalSlots then break end -- Depende de slotIndex
            -- Reativando incremento e break interno
            slotIndex = slotIndex + 1
            if slotIndex > totalSlots then break end
            --]] -- Fim do comentário original do conteúdo
        end
         --[[ -- Break externo comentado também, pois depende de slotIndex --]]
         -- Reativando break externo
         if slotIndex > totalSlots then break end -- Segurança externa também
         --]]
    end

    love.graphics.setLineWidth(1) -- Restaurado aqui fora, caso tenha sido alterado
    love.graphics.setFont(fonts.main) -- Garante que a fonte padrão seja restaurada
    print("    [InventoryScreen.drawInventory] END (Código completo reativado)") -- DEBUG
end

-- Função para processar input quando o inventário está visível
function InventoryScreen.keypressed(key)
    -- A tecla 'tab' é tratada em main.lua para garantir que a pausa seja gerenciada corretamente
    if not InventoryScreen.isVisible then
        return false -- Não trata input se não estiver visível
    end

    -- TODO: Adicionar lógica de navegação/interação dentro do inventário (WASD, Enter, Mouse, etc.)
    if key == "escape" then -- Fecha o inventário com ESC também
        InventoryScreen.toggle() -- Apenas alterna a visibilidade, a pausa é tratada no main.lua
        return true
    end

    -- Se o inventário está visível mas não tratou a tecla,
    -- considera o input como tratado para evitar que o jogo o processe
    print("Inventory handled key:", key) -- Debug
    return true
end

-- Função para tratar cliques do mouse quando o inventário está visível
function InventoryScreen.mousepressed(x, y, button)
    if not InventoryScreen.isVisible then
        return false -- Não trata cliques se não estiver visível
    end

    -- TODO: Adicionar lógica de clique nos slots para ABRIR o ItemDetailsModal
    -- 1. Calcular em qual seção o clique ocorreu (Inventário ou Equipamento)
    -- 2. Calcular qual slot foi clicado dentro da seção
    -- 3. Obter o item naquele slot (se houver)
    -- 4. Chamar ItemDetailsModal:show(item)

    -- Exemplo de detecção de clique na área do inventário (PRECISA REFINAR)
    -- Precisa das posições X, Y, W, H da seção de inventário calculadas em draw()
    -- Esta lógica é melhor feita dentro de drawInventory/drawEquipment ou funções helper
    print("Inventory click detection placeholder @", x, y, button)


    -- Se o inventário está visível, considera o clique como tratado (impedindo clique no jogo)
    -- Mas não impede o clique de ser processado por elementos da UI do inventário
    -- Se um clique em slot for detectado e abrir o modal, esta função deve retornar true.
    -- Por enquanto, retornamos true para consumir o clique e evitar que o jogo o receba.
    return true
end

return InventoryScreen 