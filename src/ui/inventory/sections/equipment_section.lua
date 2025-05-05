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
--- @param hunterId string ID do caçador.
function EquipmentSection:draw(x, y, w, h, hunterManager, slotAreasTable, hunterId)
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

    local targetHunterId = hunterId or hunterManager:getActiveHunterId()
    if not targetHunterId then
        love.graphics.setColor(colors.red or { 1, 0, 0 })
        love.graphics.printf("Nenhum Caçador Ativo/Selecionado!", x, y + h / 2, w, "center")
        return -- Não pode desenhar sem um caçador
    end

    local equippedItems = hunterManager:getEquippedItems(targetHunterId)
    if not equippedItems then
        -- Isso pode acontecer se o activeHunterId for inválido por algum motivo
        love.graphics.setColor(colors.red or { 1, 0, 0 })
        love.graphics.printf("Erro: Não foi possível obter itens equipados do HunterManager!", x, y, w, "center")
        return
    end

    local hunterData = hunterManager.hunters and hunterManager.hunters[targetHunterId]
    if not hunterData then
        love.graphics.setColor(colors.red or { 1, 0, 0 })
        love.graphics.printf("Dados do Caçador %s não encontrados!", targetHunterId, x, y + h / 2, w, "center")
        return -- Não pode desenhar sem dados
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
    local weaponSlotW = w * 0.8 -- <<< LARGURA USADA ABAIXO
    local weaponSlotX = x + (w - weaponSlotW) / 2
    local weaponSlotY = currentY
    local weaponSlotId = SLOT_IDS.WEAPON
    local weaponInstance = equippedItems[weaponSlotId]

    -- Define as cores base do slot (padrão ou baseado na raridade da arma)
    local slotBgColor = colors.slot_empty_bg
    -- print(string.format("[EquipmentSection:draw - WEAPON] HunterID: %s, Weapon Slot ID: %s", targetHunterId, weaponSlotId)) -- DEBUG
    -- print(string.format("  - weaponInstance found: %s", tostring(weaponInstance ~= nil))) -- DEBUG
    if weaponInstance then
        -- print(string.format("    - weaponInstance.itemBaseId: %s", weaponInstance.itemBaseId or "nil")) -- DEBUG
        -- print(string.format("    - weaponInstance.icon exists: %s", tostring(weaponInstance.icon ~= nil))) -- DEBUG
        -- if weaponInstance.icon then -- DEBUG
        --     print(string.format("    - weaponInstance.icon type: %s", type(weaponInstance.icon))) -- DEBUG
        -- end -- DEBUG
        rarityColor = colors.rarity[weaponInstance.rarity or 'E'] or colors.rarity['E']
        slotBgColor = { rarityColor[1], rarityColor[2], rarityColor[3], 0.15 } -- Alpha baixo (15%)
        slotBorderColor = rarityColor
    end

    -- Desenha o fundo do slot usando as cores definidas
    elements.drawWindowFrame(weaponSlotX - 2, weaponSlotY - 2, weaponSlotW + 4, weaponSlotH + 4, nil,
        slotBgColor, slotBorderColor)
    if slotBgColor then
        love.graphics.setColor(slotBgColor[1], slotBgColor[2], slotBgColor[3], slotBgColor[4] or 1)
    else
        love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
    end
    love.graphics.rectangle("fill", weaponSlotX, weaponSlotY, weaponSlotW, weaponSlotH, 3, 3)
    love.graphics.setColor(1, 1, 1, 1) -- Reset

    if weaponInstance then
        -- Tenta obter dados base para stats mais detalhados
        local baseData = hunterManager.itemDataManager:getBaseItemData(weaponInstance.itemBaseId)
        local name = baseData and baseData.name or (weaponInstance.name or "Arma")
        local rank = baseData and baseData.rarity or (weaponInstance.rarity or 'E')
        local rankColor = colors.rarity[rank] or colors.white

        local damage = baseData and baseData.damage or (weaponInstance.damage or 0)
        local cooldown = baseData and baseData.cooldown or (weaponInstance.cooldown or 0)

        -- <<< INÍCIO: Desenha Ícone da Arma >>>
        if weaponInstance.icon and type(weaponInstance.icon) == "userdata" then
            local icon = weaponInstance.icon
            local iw, ih = icon:getDimensions()
            local rotation = 0
            local scale = 1
            local ox, oy = iw / 2, ih / 2
            local drawX, drawY
            local baseGridW = baseData and baseData.gridWidth or 1
            local baseGridH = baseData and baseData.gridHeight or 1
            if baseGridW > baseGridH then
                rotation = 0
                -- DEBUG: Print scale calculation factors
                -- print(string.format("    - Icon Draw (Horizontal): slotW=%.1f, slotH=%.1f, iw=%.1f, ih=%.1f", weaponSlotW, weaponSlotH, iw, ih)) -- DEBUG
                scale = math.min(weaponSlotW * 0.9 / iw, weaponSlotH * 0.9 / ih)
                drawX = weaponSlotX + weaponSlotW - (iw * scale / 2)
                drawY = weaponSlotY + weaponSlotH / 2
            else
                rotation = math.pi / 2
                -- DEBUG: Print scale calculation factors
                -- print(string.format("    - Icon Draw (Vertical): slotW=%.1f, slotH=%.1f, iw=%.1f, ih=%.1f", weaponSlotW, weaponSlotH, iw, ih)) -- DEBUG
                scale = math.min(weaponSlotW * 0.9 / ih, weaponSlotH * 0.9 / iw)
                drawX = weaponSlotX + weaponSlotW - (ih * scale / 2)
                drawY = weaponSlotY + weaponSlotH / 2
            end
            -- print(string.format("    - Calculated scale=%.2f, drawX=%.1f, drawY=%.1f, rotation=%.2f", scale, drawX, drawY, rotation)) -- DEBUG
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(icon, drawX, drawY, rotation, scale, scale, ox, oy)
        else
            -- print("    - Icon Draw: weaponInstance.icon is nil or not userdata") -- DEBUG
            local iconSize = math.min(weaponSlotW, weaponSlotH) * 0.8
            local iconX = weaponSlotX + (weaponSlotW - iconSize) / 2
            local iconY = weaponSlotY + (weaponSlotH - iconSize) / 2
            elements.drawEmptySlotBackground(iconX, iconY, iconSize, iconSize)
            love.graphics.setColor(colors.white)
            love.graphics.setFont(fonts.title)
            love.graphics.printf(string.sub(name, 1, 1), iconX, iconY + iconSize * 0.1, iconSize, "center")
            love.graphics.setFont(fonts.main)
        end
        -- <<< FIM: Desenha Ícone da Arma >>>

        -- <<< INÍCIO: Desenha Informações da Arma (Nome Estilizado e Stats) >>>
        local infoX = weaponSlotX + 10 -- Começa à esquerda, antes do ícone
        local infoY = weaponSlotY + 5

        -- Nome + Rank [R]
        love.graphics.setFont(fonts.main_large)
        love.graphics.setColor(rankColor)
        local nameWithRank = string.format("%s [%s]", name, rank)
        love.graphics.print(nameWithRank, infoX, infoY)
        infoY = infoY + fonts.main_large:getHeight() + 5

        -- Stats
        love.graphics.setFont(fonts.main)
        love.graphics.setColor(colors.text_main)
        love.graphics.printf(string.format("Dano: %.1f", damage), infoX, infoY, weaponSlotW * 0.6, "left") -- Limita largura para texto
        infoY = infoY + fonts.main:getHeight() + 2
        love.graphics.printf(string.format("Cooldown: %.2f/s", cooldown), infoX, infoY, weaponSlotW * 0.6, "left")
        -- <<< FIM: Desenha Informações da Arma >>>
    else
        -- Slot de arma vazio (sem alterações)
        love.graphics.setFont(fonts.main)
        love.graphics.setColor(colors.text_label)
        love.graphics.printf("Sem Arma Equipada", weaponSlotX, weaponSlotY + weaponSlotH / 2 - fonts.main:getHeight() / 2,
            weaponSlotW, "center")
    end
    love.graphics.setColor(1, 1, 1, 1) -- Reset cor após arma

    -- <<< ADICIONADO: Registra a área do slot da arma >>>
    slotAreasTable[weaponSlotId] = { x = weaponSlotX, y = weaponSlotY, w = weaponSlotW, h = weaponSlotH }

    -- Atualiza currentY para depois da arma
    currentY = weaponSlotY + weaponSlotH + 25 -- Aumenta espaço antes das runas

    -- <<< INÍCIO: Desenho dos Slots de Runa (Dinâmico e Vertical) >>>
    local maxRuneSlots = hunterManager:getActiveHunterMaxRuneSlots()

    if maxRuneSlots > 0 then
        -- Desenha Título "RUNAS" (Estilo Equipamento)
        love.graphics.setFont(fonts.title)
        love.graphics.setColor(colors.text_highlight)
        love.graphics.printf("RUNAS", x, currentY, w, "center")
        currentY = currentY + fonts.title:getHeight() + 10

        local runeSlotW = weaponSlotW -- <<< USA A MESMA LARGURA DA ARMA
        local runeSlotH = 60
        local runeSpacing = 10
        local runeStartX = x + (w - runeSlotW) / 2

        for i = 1, maxRuneSlots do
            local slotId = "rune_" .. i
            local itemInstance = equippedItems[slotId]
            local slotX = runeStartX
            local slotY = currentY

            -- --- Desenho do Slot de Runa (Estilo Arma) ---
            local slotBgColor = colors.slot_empty_bg
            local slotBorderColor = colors.slot_empty_border
            local runeBaseData = nil
            local rank = 'E'
            local rankColor = colors.rarity[rank]

            if itemInstance then
                runeBaseData = hunterManager.itemDataManager:getBaseItemData(itemInstance.itemBaseId)
                rank = (runeBaseData and runeBaseData.rarity) or (itemInstance.rarity or 'E')
                rankColor = colors.rarity[rank] or colors.rarity['E']
                slotBgColor = { rankColor[1], rankColor[2], rankColor[3], 0.15 }
                slotBorderColor = rankColor
            end

            -- Desenha frame e fundo
            elements.drawWindowFrame(slotX - 2, slotY - 2, runeSlotW + 4, runeSlotH + 4, nil, slotBgColor,
                slotBorderColor)
            if slotBgColor then
                love.graphics.setColor(slotBgColor[1], slotBgColor[2], slotBgColor[3],
                    slotBgColor[4] or 1)
            else
                love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
            end
            love.graphics.rectangle("fill", slotX, slotY, runeSlotW, runeSlotH, 3, 3)
            love.graphics.setColor(1, 1, 1, 1)

            -- <<< INÍCIO: Desenha Ícone e Informações da Runa >>>
            local textStartX = slotX + 10 -- Posição inicial para textos
            local textStartY = slotY + 5

            if itemInstance and itemInstance.icon and type(itemInstance.icon) == "userdata" then
                -- Desenha Ícone à direita
                local icon = itemInstance.icon
                local iw, ih = icon:getDimensions()
                local iconMaxH = runeSlotH * 0.8
                local iconScale = iconMaxH / ih
                local iconDrawW, iconDrawH = iw * iconScale, ih * iconScale
                local iconDrawX = slotX + runeSlotW - iconDrawW - 5 -- Alinha à direita
                local iconDrawY = slotY + (runeSlotH - iconDrawH) / 2
                love.graphics.draw(icon, iconDrawX, iconDrawY, 0, iconScale, iconScale)
                textStartX = slotX + 10 -- Área de texto fica à esquerda do ícone
            elseif itemInstance then
                -- Placeholder de Ícone (se não houver imagem)
                local iconSize = runeSlotH * 0.8
                local iconX = slotX + runeSlotW - iconSize - 5
                local iconY = slotY + (runeSlotH - iconSize) / 2
                elements.drawEmptySlotBackground(iconX, iconY, iconSize, iconSize)
                love.graphics.setColor(colors.white)
                love.graphics.setFont(fonts.title)
                love.graphics.printf(string.sub(itemInstance.name or "R", 1, 1), iconX, iconY + iconSize * 0.1, iconSize,
                    "center")
            end

            -- Desenha textos (Nome, Stats)
            if itemInstance and runeBaseData then
                -- Nome [Rank]
                love.graphics.setFont(fonts.main_large)
                love.graphics.setColor(rankColor)
                local nameWithRank = string.format("%s [%s]", runeBaseData.name or "Runa", rank)
                love.graphics.print(nameWithRank, textStartX, textStartY)
                textStartY = textStartY + fonts.main_large:getHeight() + 5

                -- Stats Específicos
                love.graphics.setFont(fonts.main_small)
                love.graphics.setColor(colors.text_main)
                local statText = ""
                if runeBaseData.effect == "orbital" then
                    statText = string.format("Dano: %s | Esferas: %s", tostring(runeBaseData.damage or '?'),
                        tostring(runeBaseData.num_projectiles or '?'))
                elseif runeBaseData.effect == "thunder" then
                    statText = string.format("Dano: %s | Intervalo: %.1fs", tostring(runeBaseData.damage or '?'),
                        runeBaseData.interval or '?')
                elseif runeBaseData.effect == "aura" then
                    statText = string.format("Dano/Tick: %s | Intervalo: %.1fs",
                        tostring(runeBaseData.damage_per_tick or '?'), runeBaseData.tick_interval or '?')
                else
                    statText = "Efeito desconhecido"
                end
                love.graphics.printf(statText, textStartX, textStartY, runeSlotW * 0.7, "left") -- Limita largura do texto
            elseif itemInstance then                                                            -- Tem item mas não achou baseData
                love.graphics.setFont(fonts.main_large)
                love.graphics.setColor(rankColor)
                love.graphics.print(itemInstance.name or "Runa ?", textStartX, textStartY)
                -- Poderia mostrar um erro aqui
            else
                -- Slot Vazio
                love.graphics.setFont(fonts.main)
                love.graphics.setColor(colors.text_label)
                love.graphics.printf("Slot de Runa", slotX, slotY + runeSlotH / 2 - fonts.main:getHeight() / 2, runeSlotW,
                    "center")
            end
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setFont(fonts.main)
            -- <<< FIM: Desenha Ícone e Informações da Runa >>>

            -- Registra a área do slot de runa com o ID dinâmico
            slotAreasTable[slotId] = { x = slotX, y = slotY, w = runeSlotW, h = runeSlotH }

            -- Atualiza Y para o próximo slot
            currentY = currentY + runeSlotH + runeSpacing
        end
        -- Ajusta currentY final
        currentY = currentY - runeSpacing + 15
    end
    -- <<< FIM: Desenho dos Slots de Runa (Dinâmico e Vertical) >>>

    -- Desenha Elementos de Drag-and-Drop (se estiver arrastando)
    -- Esta parte do código parece pertencer a outro contexto (InventoryScreen?) e foi removida
    -- if self.isDragging and self.draggedItem then
    -- ... (código de drag and drop removido daqui)
    -- end

    love.graphics.setLineWidth(1)
    love.graphics.setFont(fonts.main)
end

return EquipmentSection
