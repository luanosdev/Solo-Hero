local SceneManager = require("src.core.scene_manager")
local fonts = require("src.ui.fonts")
local colors = require("src.ui.colors")
local elements = require("src.ui.ui_elements")
local Constants = require("src.config.constants")
local TooltipManager = require("src.ui.tooltip_manager")
local ManagerRegistry = require("src.managers.manager_registry")
local HunterStatsColumn = require("src.ui.components.HunterStatsColumn")

---@class ExtractionSummaryScene
local ExtractionSummaryScene = {}

ExtractionSummaryScene.args = nil        -- Argumentos recebidos da GameplayScene
ExtractionSummaryScene.itemDataManager = nil ---@type ItemDataManager
ExtractionSummaryScene.tooltipItem = nil -- Item atualmente sob o mouse para tooltip

-- Modificado: Uma única lista para todas as áreas de itens clicáveis na coluna 3
ExtractionSummaryScene.allItemsDisplayAreas = {} -- {{x,y,w,h,itemInstance}, ...}

--- Chamado quando a cena é carregada.
---@param args table Argumentos da GameplayScene:
---   portalName (string), portalRank (string),
---   extractedItems (table), extractedEquipment (table<string, ItemInstance>),
---   hunterId (string), gameplayStats (table),
---   finalStats (table), archetypeIds (table), archetypeManagerInstance (ArchetypeManager)
function ExtractionSummaryScene:load(args)
    print("[ExtractionSummaryScene] Loading...")
    if args then
        print("  Portal Name: " .. tostring(args.portalName))
        print("  Portal Rank: " .. tostring(args.portalRank))
        print("  Hunter ID: " .. tostring(args.hunterId))
        print("  Num Extracted Items (Backpack): " .. tostring(args.extractedItems and #args.extractedItems or 0))
        local equipCount = 0
        if args.extractedEquipment then for _ in pairs(args.extractedEquipment) do equipCount = equipCount + 1 end end
        print("  Num Extracted Equipment: " .. equipCount)
        print("  FinalStats received: " .. tostring(args.finalStats ~= nil))
        print("  ArchetypeIds received: " .. tostring(args.archetypeIds ~= nil and #args.archetypeIds or 0))
        print("  ArchetypeManager instance received: " .. tostring(args.archetypeManagerInstance ~= nil))
    else
        print("  WARNING: No args received by ExtractionSummaryScene!")
    end

    self.args = args
    self.itemDataManager = ManagerRegistry:get("itemDataManager")

    if not self.itemDataManager then
        error("[ExtractionSummaryScene] ItemDataManager não encontrado no Registry!")
    end
    if self.args and not self.args.archetypeManagerInstance then
        print(
            "WARN [ExtractionSummaryScene] ArchetypeManager instance (args.archetypeManagerInstance) não recebida! Stats do caçador podem não incluir arquétipos.")
        -- Não é um erro fatal, mas HunterStatsColumn pode não ter todas as infos.
    end
    if self.args and not self.args.extractedEquipment then
        self.args.extractedEquipment = {}
        print("  WARN: args.extractedEquipment era nil, inicializado como tabela vazia.")
    end
    if self.args and not self.args.extractedItems then
        self.args.extractedItems = {}
        print("  WARN: args.extractedItems era nil, inicializado como tabela vazia.")
    end

    -- Limpar estado de tooltips e layouts anteriores
    self.tooltipItem = nil
    self.allItemsDisplayAreas = {} -- Reseta a lista unificada
end

--- Atualiza a lógica da cena.
---@param dt number Delta time.
function ExtractionSummaryScene:update(dt)
    local mx, my = love.mouse.getPosition()
    self.tooltipItem = nil -- Reseta a cada frame

    -- Verificar hover nos itens exibidos na coluna 3
    if self.allItemsDisplayAreas then
        for _, area in ipairs(self.allItemsDisplayAreas) do
            if area.item and mx >= area.x and mx <= area.x + area.w and my >= area.y and my <= area.y + area.h then
                self.tooltipItem = area.item -- Atribui a itemInstance completa
                break                        -- Encontrou item, para a busca
            end
        end
    end

    TooltipManager.update(dt, mx, my, self.tooltipItem)
end

--- Desenha os elementos da cena.
function ExtractionSummaryScene:draw()
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
    local mx, my = love.mouse.getPosition() -- Para passar ao HunterStatsColumn

    -- Fundo simples
    love.graphics.setColor(colors.lobby_background)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    love.graphics.setColor(colors.white)

    local currentY = 20 -- Reduzido para dar mais espaço ao título do portal
    local centerX = screenW / 2

    -- Título
    love.graphics.setFont(fonts.title_large or fonts.title)
    love.graphics.setColor(colors.text_title)
    love.graphics.printf("Extração Bem-Sucedida!", 0, currentY, screenW, "center")
    local titleHeight = (fonts.title_large or fonts.title):getHeight()
    currentY = currentY + titleHeight + 20

    -- Card do Portal (Usando elements.drawTextCard)
    if self.args and self.args.portalName and self.args.portalRank then
        local portalCardW = screenW * 0.6
        local portalCardH = 60
        local portalCardX = centerX - portalCardW / 2
        local portalText = string.format("%s", self.args.portalName) -- Rank será desenhado separadamente

        elements.drawTextCard(portalCardX, currentY, portalCardW, portalCardH, portalText, {
            rankLetterForStyle = self.args.portalRank,
            font = fonts.title or fonts.main_large,
            h_align = 'center',
            v_align = 'middle',
            padding = 10,
            cornerRadius = 10
        })

        currentY = currentY + portalCardH + 30
    end

    -- Linha 2: Layout de 3 Colunas
    local columnPaddingHorizontal = 25
    local sidePadding = 50
    local totalHorizontalPadding = sidePadding * 2 + columnPaddingHorizontal * 2
    local columnWidth = (screenW - totalHorizontalPadding) / 3

    local columnTopY = currentY
    local columnTitleFont = fonts.main_large or fonts.main
    local columnTitleHeight = columnTitleFont:getHeight()
    local columnTitlePaddingY = 10
    local columnContentStartY = columnTopY + columnTitleHeight + columnTitlePaddingY
    local columnContentHeight = screenH - columnContentStartY - 70 - 20

    -- Limpa a lista de áreas de itens para preenchimento neste frame
    self.allItemsDisplayAreas = {}

    -- Coluna 1: Estatísticas da Partida
    local gameplayStatsX = sidePadding
    love.graphics.setFont(columnTitleFont)
    love.graphics.setColor(colors.text_value)
    love.graphics.printf("Resumo da Partida", gameplayStatsX, columnTopY, columnWidth, "center")
    local currentStatY = columnContentStartY
    love.graphics.setFont(fonts.main_small)
    love.graphics.setColor(colors.text_main)
    local placeholderStats = self.args and self.args.gameplayStats or {
        { "Tempo de Jogo:",       "00:00" }, { "XP Coletado:", "0" },
        { "Inimigos Derrotados:", "0" }, { "Dano Causado:", "0" },
        { "Dano Sofrido:", "0" },
    }
    for _, stat in ipairs(placeholderStats) do
        love.graphics.printf(stat[1], gameplayStatsX + 10, currentStatY, columnWidth - 20, "left")
        love.graphics.printf(stat[2], gameplayStatsX + 10, currentStatY, columnWidth - 20, "right")
        currentStatY = currentStatY + (fonts.main_small):getHeight() + 5
        if currentStatY + (fonts.main_small):getHeight() > columnTopY + columnContentHeight then break end
    end

    -- Coluna 2: Atributos Finais
    local finalAttrsX = gameplayStatsX + columnWidth + columnPaddingHorizontal
    love.graphics.setFont(columnTitleFont)
    love.graphics.setColor(colors.text_value)
    love.graphics.printf("Atributos Finais", finalAttrsX, columnTopY, columnWidth, "center")

    if self.args and self.args.finalStats and self.args.archetypeIds and self.args.archetypeManagerInstance and HunterStatsColumn then
        HunterStatsColumn.draw(finalAttrsX, columnContentStartY, columnWidth, columnContentHeight, {
            finalStats = self.args.finalStats,
            archetypeIds = self.args.archetypeIds,
            archetypeManager = self.args.archetypeManagerInstance,
            mouseX = mx,
            mouseY = my
        })
    else
        love.graphics.setFont(fonts.main_small)
        love.graphics.setColor(colors.red)
        love.graphics.printf("Dados de atributos finais não disponíveis.", finalAttrsX, columnContentStartY + 20,
            columnWidth, "center")
    end

    -- Coluna 3: Itens Extraídos
    local extractedItemsX = finalAttrsX + columnWidth + columnPaddingHorizontal
    love.graphics.setFont(columnTitleFont)
    love.graphics.setColor(colors.text_value)
    love.graphics.printf("Itens Extraídos", extractedItemsX, columnTopY, columnWidth, "center")

    local itemDisplayY = columnContentStartY
    local itemCardW = columnWidth - 20 -- Largura do card do item, com padding na coluna
    local itemCardPadding = 5
    local itemIconSize = 48            -- Aumentado de 32
    local itemCardH = itemIconSize + itemCardPadding * 2
    local itemTextOffsetX = itemIconSize + itemCardPadding * 2 + 10
    local itemLineSpacing = 10                      -- Espaço entre cards de itens
    local itemFont = fonts.main or fonts.main_small -- Fonte para nome do item
    local iconInternalPadding = 4                   -- Padding DENTRO da área do ícone, entre a borda do card do ícone e o ícone real

    local function drawItemEntry(itemInstance, currentItemY)
        if not itemInstance or not itemInstance.itemBaseId then return currentItemY end
        if currentItemY + itemCardH > columnTopY + columnContentHeight then return currentItemY, true end

        local itemBaseData = self.itemDataManager:getBaseItemData(itemInstance.itemBaseId)
        local itemName = itemBaseData and itemBaseData.name or "Item Desconhecido"
        local itemRarity = itemInstance.rarity or 'E'
        local rankStyle = colors.rankDetails[itemRarity]
        local rankTextColor = (rankStyle and rankStyle.text) or colors.text_main

        local entryDrawX = extractedItemsX + (columnWidth - itemCardW) / 2
        local entryDrawY = currentItemY

        table.insert(self.allItemsDisplayAreas, {
            x = entryDrawX, y = entryDrawY, w = itemCardW, h = itemCardH, item = itemInstance
        })

        -- Posições e dimensões da ÁREA DO ÍCONE (onde o card de fundo do ícone será desenhado)
        local iconAreaX = entryDrawX + itemCardPadding
        local iconAreaY = entryDrawY + itemCardPadding
        -- itemIconSize já é o tamanho da área do ícone (ex: 48x48)

        -- 1. Desenha o card de fundo para o ícone usando elements.drawTextCard
        local iconCardConfig = {
            rankLetterForStyle = itemRarity, -- ADICIONADO: Para usar o gradiente de fundo e cor de texto da raridade
            borderWidth = 1,                 -- Este parâmetro não é usado por drawTextCard para uma borda de linha.
            -- O brilho (se ativo) pode fornecer um efeito de borda.
            cornerRadius = 5,
            padding = 0,     -- Padding do drawTextCard é para texto, não relevante aqui.
            showGlow = false -- Explicitamente desabilita o brilho para o card do ícone, a menos que queiramos.
            -- Se quisermos o brilho padrão de S/SS, podemos remover esta linha ou definir como true.
        }
        elements.drawTextCard(iconAreaX, iconAreaY, itemIconSize, itemIconSize, "", iconCardConfig)

        -- 2. Desenha o ícone real (ou slot vazio) DENTRO do card de fundo, com padding interno
        local actualIconSize = itemIconSize - iconInternalPadding * 2
        local actualIconDrawX = iconAreaX + iconInternalPadding
        local actualIconDrawY = iconAreaY + iconInternalPadding

        if itemInstance.icon then
            love.graphics.setColor(1, 1, 1, 1) -- Reset para cor branca para o ícone
            love.graphics.draw(itemInstance.icon, actualIconDrawX, actualIconDrawY, 0,
                actualIconSize / itemInstance.icon:getWidth(), actualIconSize / itemInstance.icon:getHeight())
        else
            -- Se não houver ícone, desenha um slot vazio dentro do card
            -- (drawEmptySlotBackground já tem sua própria borda e fundo, então pode parecer um pouco redundante
            --  se o card de fundo já for desenhado. Poderíamos simplesmente não desenhar nada ou um placeholder mais simples)
            elements.drawEmptySlotBackground(actualIconDrawX, actualIconDrawY, actualIconSize, actualIconSize)
        end

        -- 4. Desenha a QUANTIDADE do item (se > 1)
        if itemInstance.quantity and itemInstance.quantity > 1 then
            local quantityText = "x" .. tostring(itemInstance.quantity)
            local qtyFont = fonts
                .main_small                                                   -- Ou uma fonte específica para quantidade se tiver
            love.graphics.setFont(qtyFont)
            love.graphics.setColor(colors.item_quantity_text or colors.white) -- Cor para texto de quantidade

            local textWidth = qtyFont:getWidth(quantityText)
            local textHeight = qtyFont:getHeight()

            -- Desenha no canto inferior direito da ÁREA DO ÍCONE, com um pequeno padding
            local qtyPadding = 2 -- Padding do canto
            local qtyX = iconAreaX + itemIconSize - textWidth - qtyPadding
            local qtyY = iconAreaY + itemIconSize - textHeight - qtyPadding

            -- Sombra simples para o texto da quantidade para melhor legibilidade
            love.graphics.setColor(colors.black_transparent_more or { 0, 0, 0, 0.5 })
            love.graphics.print(quantityText, qtyX + 1, qtyY + 1)
            love.graphics.setColor(colors.item_quantity_text or colors.white)
            love.graphics.print(quantityText, qtyX, qtyY)
        end

        -- 3. Desenha o nome do item
        love.graphics.setFont(itemFont)
        love.graphics.setColor(rankTextColor) -- Usa a cor do texto da raridade para o nome

        -- Posição X para o nome do item, à direita do ícone
        local nameDrawX = actualIconDrawX + itemIconSize + 10 -- 10 pixels de espaço entre ícone e nome
        -- Largura disponível para o nome do item
        local nameAvailableWidth = itemCardW - (nameDrawX - entryDrawX) - itemCardPadding

        love.graphics.printf(itemName, nameDrawX,
            entryDrawY + (itemCardH - itemFont:getHeight()) / 2, -- Centraliza verticalmente no card
            nameAvailableWidth, "left")

        -- Retorna o próximo Y e indica que não houve overflow
        return currentItemY + itemCardH + itemLineSpacing, false
    end

    local hasDrawnAnyEquipment = false
    if self.args and self.args.extractedEquipment then
        local displayOrder = Constants.EQUIPMENT_SLOTS_ORDER or {}
        for _, slotId in ipairs(displayOrder) do
            local itemInstance = self.args.extractedEquipment[slotId]
            if itemInstance then
                local newY, hasOverflowed
                itemDisplayY, hasOverflowed = drawItemEntry(itemInstance, itemDisplayY)
                if hasOverflowed then break end
                hasDrawnAnyEquipment = true
            end
        end
    end

    if self.args and self.args.extractedItems and #self.args.extractedItems > 0 then
        if hasDrawnAnyEquipment and itemDisplayY + (itemFont:getHeight() * 0.5) < columnTopY + columnContentHeight then
            local sepY = itemDisplayY - itemLineSpacing / 2
            love.graphics.setColor(colors.bar_border or { 0.3, 0.3, 0.3 })
            love.graphics.rectangle("fill", extractedItemsX + 10, sepY, columnWidth - 20, 1)
            love.graphics.setColor(colors.white)
        end
        for _, itemInstance in ipairs(self.args.extractedItems) do
            local newY, hasOverflowed
            itemDisplayY, hasOverflowed = drawItemEntry(itemInstance, itemDisplayY)
            if hasOverflowed then break end
        end
    end

    if #self.allItemsDisplayAreas == 0 then
        love.graphics.setColor(colors.text_muted or { 0.5, 0.5, 0.5 })
        love.graphics.setFont(fonts.main_small)
        love.graphics.printf("Nenhum item extraído.", extractedItemsX, columnContentStartY + 20, columnWidth, "center")
    end

    -- Linha 3: Instrução para continuar
    local instructionY = screenH - 70
    love.graphics.setFont(fonts.main_large or fonts.main)
    love.graphics.setColor(colors.text_highlight)
    love.graphics.printf("Pressione qualquer tecla para continuar", 0, instructionY, screenW, "center")

    -- Desenhar Tooltip
    TooltipManager.draw()

    love.graphics.setColor(colors.white) -- Reset final
end

--- Processa pressionamento de teclas.
---@param key string A tecla pressionada.
---@param scancode love.Scancode O scancode da tecla.
---@param isrepeat boolean Se o evento é uma repetição.
function ExtractionSummaryScene:keypressed(key, scancode, isrepeat)
    if isrepeat then return end

    if self.args then
        -- Passa os mesmos args para a lobby_scene, pois eles já contêm
        -- extractedItems, extractedEquipment, hunterId.
        -- A lobby_scene já está preparada para lidar com eles.
        local lobbyArgs = shallowcopy(self.args)        -- Cria cópia rasa para não modificar original
        lobbyArgs.extractionSuccessful = true
        lobbyArgs.startTab = Constants.TabIds.EQUIPMENT -- Ou outro tab se preferir
        -- Remove dados que são apenas para esta cena de sumário
        lobbyArgs.portalName = nil
        lobbyArgs.portalRank = nil
        lobbyArgs.gameplayStats = nil
        lobbyArgs.finalStats = nil
        lobbyArgs.archetypeIds = nil
        lobbyArgs.archetypeManagerInstance = nil

        SceneManager.switchScene("lobby_scene", lobbyArgs)
    else
        SceneManager.switchScene("lobby_scene", { extractionSuccessful = false })
    end
end

--- Processa movimento do mouse (para tooltips).
function ExtractionSummaryScene:mousemoved(x, y, dx, dy, istouch)
    -- A lógica de identificar o item sob o mouse já está em :update()
end

--- Chamado quando a cena é descarregada.
function ExtractionSummaryScene:unload()
    print("[ExtractionSummaryScene] Unloading.")
    self.args = nil
    self.tooltipItem = nil
    self.allItemsDisplayAreas = {} -- Limpa a lista unificada
end

-- Função utilitária para cópia rasa de tabelas
function shallowcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

return ExtractionSummaryScene
