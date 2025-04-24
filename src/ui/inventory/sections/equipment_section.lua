-- src/ui/inventory/sections/equipment_section.lua
local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")
local elements = require("src.ui.ui_elements")
local ManagerRegistry = require("src.managers.manager_registry") -- Adicionado
local SpritePlayer = require("src.animations.sprite_player")     -- Adicionado

local EquipmentSection = {}

-- Função HELPER para desenhar um único slot (EQUIPAMENTO ou RUNA)
-- (Adaptada de inventory_screen)
local function drawSingleSlot(slotX, slotY, slotW, slotH, item, label)
    -- Desenha o fundo e borda do slot no estilo do slot de arma vazio
    -- elements.drawEmptySlotBackground(slotX, slotY, slotW, slotH) -- REMOVIDO

    -- Desenha o frame estilizado (como na arma)
    elements.drawWindowFrame(slotX - 2, slotY - 2, slotW + 4, slotH + 4, nil,
        colors.slot_empty_bg, colors.slot_empty_border) -- Adiciona pequeno padding para o frame

    -- Desenha o fundo interno (como na arma)
    local bgColor = colors.slot_empty_bg
    if bgColor then
        love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)
    else
        print("AVISO: colors.slot_empty_bg não encontrado em drawSingleSlot, usando cor padrão.")
        love.graphics.setColor(0.1, 0.1, 0.1, 0.8) -- Fallback
    end
    love.graphics.rectangle("fill", slotX, slotY, slotW, slotH, 3, 3)

    -- Reset cor antes de desenhar conteúdo
    love.graphics.setColor(1, 1, 1, 1)

    if item then
        -- TODO: Desenhar ícone real do item baseado em item.icon ou item.id
        -- Placeholder: Desenha a primeira letra do ID
        love.graphics.setFont(fonts.title) -- Usando uma fonte maior para placeholder
        local placeholderText = item.name and string.sub(item.name, 1, 1) or "?"
        love.graphics.printf(placeholderText, slotX, slotY + slotH * 0.1, slotW, "center")
        love.graphics.setFont(fonts.main) -- Restaura fonte

        -- Desenha borda e brilho da raridade
        if elements and elements.drawRarityBorderAndGlow then
            elements.drawRarityBorderAndGlow(item.rarity or 'E', slotX, slotY, slotW, slotH)
        else -- Fallback
            local rarityColor = colors.rarity[item.rarity or 'E'] or colors.rarity['E']
            love.graphics.setLineWidth(2)
            -- Desempacota a tabela de cores para setColor
            if rarityColor then
                love.graphics.setColor(table.unpack(rarityColor))
            else
                print("AVISO: rarityColor é nil em drawSingleSlot, usando branco")
                love.graphics.setColor(colors.white[1], colors.white[2], colors.white[3], colors.white[4] or 1) -- Fallback seguro
            end
            love.graphics.rectangle("line", slotX, slotY, slotW, slotH, 3, 3)
            love.graphics.setLineWidth(1)
            love.graphics.setColor(1, 1, 1, 1) -- Reset color
        end
        -- Não desenha contagem aqui, equipamento não costuma empilhar
    elseif label then
        -- Desenha texto indicando slot vazio
        local emptyTextMap = {
            ["Cabeça"] = "Nenhuma Cabeça Equipada",
            ["Peito"] = "Nenhum Peito Equipado",
            ["Pernas"] = "Nenhuma Perna Equipada", -- Usando singular para Perna/Calça
            ["Pés"] = "Nenhum Calçado Equipado"
        }
        local emptyText = emptyTextMap[label] or "Slot Vazio" -- Fallback

        love.graphics.setFont(fonts.main_small)
        love.graphics.setColor(colors.text_label)
        -- Centraliza o texto dentro do slot (usando slotW)
        love.graphics.printf(emptyText, slotX + 4, slotY + slotH / 2 - fonts.main_small:getHeight() / 2, slotW - 8,
            "center")
        love.graphics.setFont(fonts.main)
    end
end

-- NOVO: Função HELPER para desenhar um slot de Runa com informações
local function drawRuneSlotInfo(slotX, slotY, slotW, slotH, rune)
    -- Desenha o fundo e borda do slot (estilo equipamento/arma)
    elements.drawWindowFrame(slotX - 2, slotY - 2, slotW + 4, slotH + 4, nil,
        colors.slot_empty_bg, colors.slot_empty_border)
    local bgColor = colors.slot_empty_bg
    if bgColor then
        love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)
    else
        love.graphics.setColor(0.1, 0.1, 0.1, 0.8) -- Fallback
    end
    love.graphics.rectangle("fill", slotX, slotY, slotW, slotH, 3, 3)
    love.graphics.setColor(1, 1, 1, 1) -- Reset color

    if rune then
        -- Extrai informações da runa (assumindo que elas existem)
        local rank = rune.rarity or '?'
        local level = rune.level or 1
        local maxLevel = rune.maxLevel or '?'
        local iconPlaceholder = rune.name and string.sub(rune.name, 1, 1) or 'R'
        local rarityColor = colors.rarity[rank] or colors.white

        -- 1. Ícone (Placeholder)
        local iconSize = slotH * 0.5 -- Ícone ocupa metade da altura
        local iconX = slotX + 5
        local iconY = slotY + 5
        elements.drawEmptySlotBackground(iconX, iconY, iconSize, iconSize)
        love.graphics.setColor(colors.white)
        love.graphics.setFont(fonts.title) -- Fonte maior para ícone
        love.graphics.printf(iconPlaceholder, iconX, iconY + iconSize * 0.1, iconSize, "center")
        -- Desenha borda da raridade no ícone
        if elements.drawRarityBorderAndGlow then
            elements.drawRarityBorderAndGlow(rank, iconX, iconY, iconSize, iconSize)
        end

        -- 2. Rank da Runa (ao lado do ícone)
        local rankX = iconX + iconSize + 5
        local rankY = iconY + iconSize * 0.1 -- Alinha com topo do ícone
        love.graphics.setFont(fonts.hud)     -- Fonte menor/bold para rank
        love.graphics.setColor(rarityColor)
        love.graphics.print("Rank: " .. rank, rankX, rankY)

        -- 3. Nível (abaixo do ícone/rank)
        local levelY = iconY + iconSize + 5
        love.graphics.setFont(fonts.main_small)
        love.graphics.setColor(colors.text_main)
        love.graphics.print(string.format("Lv: %d/%s", level, tostring(maxLevel)), slotX + 5, levelY)

        -- 4. Nome da Runa (abaixo do nível)
        local nameY = levelY + fonts.main_small:getHeight() + 3 -- Posição Y abaixo do nível
        local runeName = rune.name or "Runa Desconhecida"
        -- Trunca nome se for muito longo para caber
        local availableWidth = slotW - 10
        if fonts.main_small:getWidth(runeName) > availableWidth then
            -- Simple truncation logic (adjust as needed)
            local truncated = ""
            for i = 1, #runeName do
                if fonts.main_small:getWidth(truncated .. runeName:sub(i, i) .. "...") <= availableWidth then
                    truncated = truncated .. runeName:sub(i, i)
                else
                    break
                end
            end
            runeName = truncated .. "..."
        end
        love.graphics.printf(runeName, slotX + 5, nameY, availableWidth, "center")
    else
        -- Slot vazio para runa
        love.graphics.setFont(fonts.main_small)
        love.graphics.setColor(colors.text_label)
        love.graphics.printf("Slot de Runa Vazio", slotX + 4, slotY + slotH / 2 - fonts.main_small:getHeight() / 2,
            slotW - 8, "center")
    end
    love.graphics.setFont(fonts.main) -- Restaura fonte padrão
end

-- Desenha a seção de equipamento (centro)
function EquipmentSection:draw(x, y, w, h)
    -- Tenta obter o PlayerManager
    local playerManager = ManagerRegistry:get("playerManager")
    if not playerManager then
        love.graphics.setColor(colors.damage_player or { 1, 0, 0 }) -- Usa damage_player ou fallback vermelho
        love.graphics.printf("Erro: PlayerManager não encontrado!", x, y, w, "center")
        return
    end
    local player = playerManager.player     -- Referência ao sprite
    local playerState = playerManager.state -- Referência ao estado (para stats, talvez?)
    local equippedWeapon = playerManager.equippedWeapon

    -- 1. Área do Título
    love.graphics.setFont(fonts.title)
    love.graphics.setColor(colors.text_highlight)
    love.graphics.printf("EQUIPAMENTO", x, y, w, "center")
    local titleH = fonts.title:getHeight() * 1.2
    local currentY = y + titleH + 10 -- Y atual para posicionar elementos

    -- 3. Área da Grade de Equipamento 2x2
    -- local eqSlotW = w * 0.8 -- AJUSTADO: Mesma largura do slot de arma (REMOVIDO)
    -- local eqSlotH = 75      -- Mantém altura de 75 (ou ajuste se necessário) (REMOVIDO)
    local eqSpacing = 10                              -- Espaçamento entre slots
    local newSlotH = 100                              -- Altura definida anteriormente (100)
    -- local newSlotW = (w - eqSpacing) / 2 -- NOVA Largura: metade da seção menos espaçamento (REMOVIDO)
    local totalGridWidth = w * 0.8                    -- Largura total da grade igual à largura do slot de arma
    local newSlotW = (totalGridWidth - eqSpacing) / 2 -- Largura de cada slot na grade
    local gridStartX = x + (w - totalGridWidth) / 2   -- Posição X inicial para centralizar a grade
    local numRows = 2
    local numCols = 2

    -- Labels na ordem da grade (Linha 1: Cabeça, Peito; Linha 2: Pernas, Pés)
    local eqLabelsGrid = {
        { "Cabeça", "Peito" },
        { "Pernas", "Pés" }
    }

    for r = 1, numRows do
        for c = 1, numCols do
            -- local slotX = x + (c - 1) * (newSlotW + eqSpacing) -- Posição X da coluna (REMOVIDO)
            local slotX = gridStartX + (c - 1) * (newSlotW + eqSpacing) -- Posição X usando gridStartX
            local slotY = currentY + (r - 1) * (newSlotH + eqSpacing)   -- Posição Y da linha
            local label = eqLabelsGrid[r][c]

            -- TODO: Obter item equipado real para este slot (label)
            local equippedItem = nil -- Ex: playerManager:getEquippedItem(label:lower())

            -- Desenha o slot
            drawSingleSlot(slotX, slotY, newSlotW, newSlotH, equippedItem, label)
        end
    end

    -- Atualiza currentY para depois da grade 2x2
    currentY = currentY + numRows * newSlotH + (numRows - 1) * eqSpacing + 15

    -- 4. Área do Slot da Arma (Posição Y atualizada)
    local weaponSlotH = 75                        -- Altura do slot da arma (pode ser ajustada se necessário)
    local weaponSlotW = w * 0.8                   -- Largura maior (RESTAURADO)
    local weaponSlotX = x + (w - weaponSlotW) / 2 -- Atualizado para centralizar o slot original
    local weaponSlotY = currentY

    -- Desenha fundo do slot da arma (placeholder)
    elements.drawWindowFrame(weaponSlotX - 5, weaponSlotY - 5, weaponSlotW + 10, weaponSlotH + 10, nil,
        colors.slot_empty_bg, colors.slot_empty_border) -- Usa slot_empty_bg para o fundo
    -- Define a cor manualmente desempacotando os componentes
    local bgColor = colors.slot_empty_bg
    if bgColor then
        love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)
    else
        print("AVISO: colors.slot_empty_bg não encontrado, usando cor padrão.")
        love.graphics.setColor(0.1, 0.1, 0.1, 0.8) -- Fallback
    end
    love.graphics.rectangle("fill", weaponSlotX, weaponSlotY, weaponSlotW, weaponSlotH, 3, 3)

    if equippedWeapon then
        -- TODO: Obter dados da arma (rarity, damageType, damage)
        local weaponData = equippedWeapon -- A própria instância talvez tenha os dados
        local rarity = weaponData.rarity or 'E'
        local damage = weaponData.damage or 0
        local damageType = weaponData.damageType or "Físico"
        local name = weaponData.name or "Arma Desconhecida"

        -- Desenha ícone (placeholder)
        local iconSize = weaponSlotH * 0.8
        local iconX = weaponSlotX + 10
        local iconY = weaponSlotY + (weaponSlotH - iconSize) / 2
        elements.drawEmptySlotBackground(iconX, iconY, iconSize, iconSize)
        love.graphics.setColor(colors.white)
        love.graphics.setFont(fonts.title)
        love.graphics.printf(string.sub(name, 1, 1), iconX, iconY + iconSize * 0.1, iconSize, "center")
        if elements.drawRarityBorderAndGlow then -- Borda no ícone
            elements.drawRarityBorderAndGlow(rarity, iconX, iconY, iconSize, iconSize)
        end

        -- Desenha informações da arma
        local infoX = iconX + iconSize + 15
        local infoY = weaponSlotY + 5
        love.graphics.setFont(fonts.main_large) -- Usa main_large para nome
        love.graphics.setColor(colors.rarity[rarity] or colors.white)
        love.graphics.print(name, infoX, infoY)
        infoY = infoY + fonts.main_large:getHeight() + 5 -- Usa main_large para altura

        love.graphics.setFont(fonts.main)
        love.graphics.setColor(colors.text_main) -- Usa text_main em vez de text_normal
        love.graphics.printf(string.format("Dano: %.1f (%s)", damage, damageType), infoX, infoY,
            weaponSlotW - (infoX - weaponSlotX) - 10, "left")
        infoY = infoY + fonts.main:getHeight() + 2

        -- Rarity Text (like SSR)
        love.graphics.setFont(fonts.hud)                   -- Usa hud para tag de raridade
        love.graphics.setColor(colors.rarity[rarity] or colors.white)
        local rarityText = rarity                          -- Poderia mapear E->Common, S->SSR etc.
        local rarityTextW = fonts.hud:getWidth(rarityText) -- Usa hud para largura
        love.graphics.print(rarityText, weaponSlotX + weaponSlotW - rarityTextW - 5, weaponSlotY + 5)
    else
        love.graphics.setFont(fonts.main)
        love.graphics.setColor(colors.text_label)
        love.graphics.printf("Sem Arma", weaponSlotX, weaponSlotY + weaponSlotH / 2 - fonts.main:getHeight() / 2,
            weaponSlotW, "center")
    end
    currentY = weaponSlotY + weaponSlotH + 15

    -- 5. Área das Runas (Layout 2x2 - Mesmo tamanho dos Equipamentos)
    -- Adiciona Título "RUNAS" como texto simples
    love.graphics.setFont(fonts.title)
    love.graphics.setColor(colors.text_highlight)     -- Usa a mesma cor de "EQUIPAMENTO"
    love.graphics.printf("RUNAS", x, currentY, w, "center")
    local runesTitleH = fonts.title:getHeight() * 1.2 -- Calcula altura para espaçamento
    currentY = currentY + runesTitleH + 10            -- Espaçamento após título

    -- Configuração dos slots de runa (usando dimensões do equipamento)
    -- local runeSlotSize = 75 -- Tamanho quadrado (REMOVIDO)
    local runeSlotW = newSlotW -- USA LARGURA DO SLOT DE EQUIPAMENTO
    local runeSlotH = newSlotH -- USA ALTURA DO SLOT DE EQUIPAMENTO
    local runeSpacing = 10
    local numRuneRows = 2
    local numRuneCols = 2
    local numRunes = numRuneRows * numRuneCols

    -- Calcula largura total da grade e X inicial para centralizar (usando runeSlotW)
    local totalRuneGridWidth = numRuneCols * runeSlotW + (numRuneCols - 1) * runeSpacing
    local runeGridStartX = x + (w - totalRuneGridWidth) / 2 -- Centraliza a grade
    local runesY = currentY

    -- Busca os ITENS runa equipados do PlayerManager
    local equippedRunes = playerManager.equippedRuneItems or {}

    -- Desenha a grade 2x2
    for r = 1, numRuneRows do
        for c = 1, numRuneCols do
            local slotIndex = (r - 1) * numRuneCols + c
            if slotIndex <= numRunes then
                local slotX = runeGridStartX + (c - 1) * (runeSlotW + runeSpacing)
                local slotY = runesY + (r - 1) * (runeSlotH + runeSpacing) -- Usa runeSlotH
                local equippedRune = equippedRunes[slotIndex]

                drawRuneSlotInfo(slotX, slotY, runeSlotW, runeSlotH, equippedRune) -- Passa W e H
            end
        end
    end

    -- Atualiza currentY para depois da grade de runas (usando runeSlotH)
    currentY = runesY + numRuneRows * runeSlotH + (numRuneRows - 1) * runeSpacing + 15

    -- Desenha Elementos de Drag-and-Drop (se estiver arrastando)
    if self.isDragging and self.draggedItem then
        -- 1. Desenha a Sombra de Posicionamento
        if self.currentTargetSlot.row > 0 and self.currentTargetSlot.col > 0 then
            local shadowX = self.gridStartX + (self.currentTargetSlot.col - 1) * (self.slotSize + self.slotSpacing)
            local shadowY = self.gridStartY + (self.currentTargetSlot.row - 1) * (self.slotSize + self.slotSpacing)

            local effectiveW = self.draggedItem.gridWidth or 1
            local effectiveH = self.draggedItem.gridHeight or 1
            if self.draggedItemRotation == 1 then -- Se rotacionado
                effectiveW = self.draggedItem.gridHeight or 1
                effectiveH = self.draggedItem.gridWidth or 1
            end
            local shadowVisualW = effectiveW * self.slotSize + math.max(0, effectiveW - 1) * self.slotSpacing
            local shadowVisualH = effectiveH * self.slotSize + math.max(0, effectiveH - 1) * self.slotSpacing

            -- Usa as cores definidas em colors.lua
            local shadowColor = self.isPlacementValid and colors.placement_valid or colors.placement_invalid

            love.graphics.setColor(shadowColor[1], shadowColor[2], shadowColor[3], 0.5) -- Cor com transparência
            love.graphics.rectangle("fill", shadowX, shadowY, shadowVisualW, shadowVisualH, 3, 3)
        end

        -- 2. Desenha o Item "Fantasma" seguindo o mouse
        local ghostW = self.draggedItem.gridWidth or 1
        local ghostH = self.draggedItem.gridHeight or 1
        if self.draggedItemRotation == 1 then -- Se rotacionado
            ghostW = self.draggedItem.gridHeight or 1
            ghostH = self.draggedItem.gridWidth or 1
        end
        local ghostVisualW = ghostW * self.slotSize + math.max(0, ghostW - 1) * self.slotSpacing
        local ghostVisualH = ghostH * self.slotSize + math.max(0, ghostH - 1) * self.slotSpacing
        -- Centraliza o item fantasma no cursor do mouse
        local ghostX = self.currentMousePos.x - ghostVisualW / 2
        local ghostY = self.currentMousePos.y - ghostVisualH / 2
        -- Desenha o item fantasma com rotação e transparência
        drawPlacedItem(ghostX, ghostY, ghostVisualW, ghostVisualH, self.draggedItem, self.draggedItemRotation, 0.75)

        love.graphics.setColor(1, 1, 1, 1) -- Reseta cor global após desenhar elementos de drag
    end

    love.graphics.setLineWidth(1)
    love.graphics.setFont(fonts.main)
end

return EquipmentSection
