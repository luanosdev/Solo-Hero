-- src/ui/inventory/sections/equipment_section.lua
local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")
local elements = require("src.ui.ui_elements")
local ManagerRegistry = require("src.managers.manager_registry") -- Adicionado
local SpritePlayer = require("src.animations.sprite_player")     -- Adicionado

local EquipmentSection = {}

-- Constantes para identificar os slots (poderiam vir do HunterManager se preferir)
local SLOT_IDS = {
    HEAD = "helmet",
    CHEST = "chest",
    LEGS = "legs", -- Mapeia para o nome da chave esperado pelo HunterManager
    FEET = "boots",
    WEAPON = "weapon"
    -- Adicione outros conforme necessário
}

-- Função HELPER para desenhar um único slot (EQUIPAMENTO ou RUNA)
-- (Adaptada de inventory_screen)
local function drawSingleSlot(slotX, slotY, slotW, slotH, itemInstance, label)
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

    if itemInstance and itemInstance.icon and type(itemInstance.icon) == "userdata" then
        local icon = itemInstance.icon
        local iw, ih = icon:getDimensions()
        local scale = math.min(slotW * 0.8 / iw, slotH * 0.8 / ih) -- Escala para caber com 80% de margem
        local drawW, drawH = iw * scale, ih * scale
        local drawX = slotX + (slotW - drawW) / 2
        local drawY = slotY + (slotH - drawH) / 2
        love.graphics.setColor(1, 1, 1, 1) -- Garante branco
        love.graphics.draw(icon, drawX, drawY, 0, scale, scale)
    elseif itemInstance then
        -- Placeholder se item existe mas sem ícone válido
        love.graphics.setFont(fonts.title)
        local placeholderText = itemInstance.name and string.sub(itemInstance.name, 1, 1) or "?"
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(placeholderText, slotX, slotY + slotH * 0.1, slotW, "center")
        love.graphics.setFont(fonts.main)
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

    -- Desenha borda da raridade (se houver item)
    if itemInstance then
        elements.drawRarityBorderAndGlow(itemInstance.rarity or 'E', slotX, slotY, slotW, slotH)
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
--- @param hunterManager HunterManager Instância do gerenciador de caçadores.
--- @param slotAreasTable table Tabela vazia a ser preenchida com as áreas dos slots { [slotId] = {x,y,w,h} }.
function EquipmentSection:draw(x, y, w, h, hunterManager, slotAreasTable)
    if not hunterManager then
        love.graphics.setColor(colors.red or { 1, 0, 0 })
        love.graphics.printf("Erro: HunterManager não fornecido para EquipmentSection!", x, y, w, "center")
        return
    end
    if not slotAreasTable then
        love.graphics.setColor(colors.red or { 1, 0, 0 })
        love.graphics.printf("Erro: Tabela de áreas de slot não fornecida para EquipmentSection!", x, y, w, "center")
        return
    end

    local equippedItems = hunterManager:getActiveEquippedItems()
    if not equippedItems then
        -- Isso pode acontecer se o activeHunterId for inválido por algum motivo
        love.graphics.setColor(colors.red or { 1, 0, 0 })
        love.graphics.printf("Erro: Não foi possível obter itens equipados do HunterManager!", x, y, w, "center")
        return
    end

    local currentY = y
    local eqSpacing = 10
    local newSlotH = 100
    local totalGridWidth = w * 0.8
    local newSlotW = (totalGridWidth - eqSpacing) / 2
    local gridStartX = x + (w - totalGridWidth) / 2
    local numRows = 2
    local numCols = 2

    -- Mapeamento Label -> Slot ID (para buscar em equippedItems)
    local eqLabelsToSlotIds = {
        ["Cabeça"] = SLOT_IDS.HEAD,
        ["Peito"] = SLOT_IDS.CHEST,
        ["Pernas"] = SLOT_IDS.LEGS,
        ["Pés"] = SLOT_IDS.FEET
    }
    local eqLabelsGrid = { { "Cabeça", "Peito" }, { "Pernas", "Pés" } }

    -- Desenha Grade 2x2 de Armadura
    for r = 1, numRows do
        for c = 1, numCols do
            local label = eqLabelsGrid[r][c]
            local slotId = eqLabelsToSlotIds[label]
            local itemInstance = equippedItems[slotId]
            local slotX = gridStartX + (c - 1) * (newSlotW + eqSpacing)
            local slotY = currentY + (r - 1) * (newSlotH + eqSpacing)
            drawSingleSlot(slotX, slotY, newSlotW, newSlotH, itemInstance, label)
            slotAreasTable[slotId] = { x = slotX, y = slotY, w = newSlotW, h = newSlotH }
        end
    end

    currentY = currentY + numRows * newSlotH + (numRows - 1) * eqSpacing + 15

    -- Desenha Slot da Arma (Lógica Separada Novamente)
    local weaponSlotH = 75
    local weaponSlotW = w * 0.8
    local weaponSlotX = x + (w - weaponSlotW) / 2
    local weaponSlotY = currentY
    local weaponSlotId = SLOT_IDS.WEAPON
    local weaponInstance = equippedItems[weaponSlotId]

    -- Desenha o fundo do slot
    elements.drawWindowFrame(weaponSlotX - 2, weaponSlotY - 2, weaponSlotW + 4, weaponSlotH + 4, nil,
        colors.slot_empty_bg, colors.slot_empty_border)
    local bgColor = colors.slot_empty_bg
    if bgColor then
        love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)
    else
        love.graphics
            .setColor(0.1, 0.1, 0.1, 0.8)
    end
    love.graphics.rectangle("fill", weaponSlotX, weaponSlotY, weaponSlotW, weaponSlotH, 3, 3)
    love.graphics.setColor(1, 1, 1, 1)

    if weaponInstance then
        local rarity = weaponInstance.rarity or 'E'
        local name = weaponInstance.name or "Arma"
        -- Tenta obter dados base para stats mais detalhados (dano, etc.)
        local baseData = hunterManager.itemDataManager:getBaseItemData(weaponInstance.itemBaseId)
        local damage = baseData and baseData.damage or (weaponInstance.damage or 0)
        local attackSpeed = baseData and baseData.attackSpeed or (weaponInstance.attackSpeed or 0)
        -- damageType precisaria ser definido nos dados base se quisermos exibi-lo
        local damageType = "Físico" -- Placeholder

        -- Desenha Ícone
        if weaponInstance.icon and type(weaponInstance.icon) == "userdata" then
            local icon = weaponInstance.icon
            local iw, ih = icon:getDimensions()
            local iconSize = weaponSlotH * 0.8 -- Ajusta tamanho do ícone
            local scale = math.min(iconSize / iw, iconSize / ih)
            local iconDrawW, iconDrawH = iw * scale, ih * scale
            local iconX = weaponSlotX + 10
            local iconY = weaponSlotY + (weaponSlotH - iconDrawH) / 2
            love.graphics.draw(icon, iconX, iconY, 0, scale, scale)
            -- Desenha borda no ícone
            elements.drawRarityBorderAndGlow(rarity, iconX, iconY, iconDrawW, iconDrawH)
        else
            -- Placeholder de Ícone
            local iconSize = weaponSlotH * 0.8
            local iconX = weaponSlotX + 10
            local iconY = weaponSlotY + (weaponSlotH - iconSize) / 2
            elements.drawEmptySlotBackground(iconX, iconY, iconSize, iconSize)
            love.graphics.setColor(colors.white)
            love.graphics.setFont(fonts.title)
            love.graphics.printf(string.sub(name, 1, 1), iconX, iconY + iconSize * 0.1, iconSize, "center")
            love.graphics.setFont(fonts.main)
            elements.drawRarityBorderAndGlow(rarity, iconX, iconY, iconSize, iconSize)
        end

        -- Desenha Informações da Arma (Nome, Dano, etc.)
        local infoX = weaponSlotX + 10 + (weaponSlotH * 0.8) + 15 -- Posição X após o espaço do ícone
        local infoY = weaponSlotY + 5
        love.graphics.setFont(fonts.main_large)                   -- Usa main_large para nome
        love.graphics.setColor(colors.rarity[rarity] or colors.white)
        love.graphics.print(name, infoX, infoY)
        infoY = infoY + fonts.main_large:getHeight() + 5

        love.graphics.setFont(fonts.main)
        love.graphics.setColor(colors.text_main)
        love.graphics.printf(string.format("Dano: %.1f", damage), infoX, infoY, weaponSlotW - (infoX - weaponSlotX) - 10,
            "left")
        infoY = infoY + fonts.main:getHeight() + 2
        love.graphics.printf(string.format("Vel. Atq: %.2f/s", attackSpeed), infoX, infoY,
            weaponSlotW - (infoX - weaponSlotX) - 10, "left")
        -- Adicionar Range se desejado
    else
        -- Slot de arma vazio
        love.graphics.setFont(fonts.main)
        love.graphics.setColor(colors.text_label)
        love.graphics.printf("Sem Arma Equipada", weaponSlotX, weaponSlotY + weaponSlotH / 2 - fonts.main:getHeight() / 2,
            weaponSlotW, "center")
    end

    -- <<< ADICIONADO: Registra a área do slot da arma >>>
    slotAreasTable[weaponSlotId] = { x = weaponSlotX, y = weaponSlotY, w = weaponSlotW, h = weaponSlotH }

    -- TODO: Adicionar slots de Runa abaixo da arma
    currentY = weaponSlotY + weaponSlotH + 15 -- Atualiza currentY para depois da arma

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
    local equippedRunes = hunterManager.equippedRuneItems or {}

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
