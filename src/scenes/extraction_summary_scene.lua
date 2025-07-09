local SceneManager = require("src.core.scene_manager")
local fonts = require("src.ui.fonts")
local colors = require("src.ui.colors")
local elements = require("src.ui.ui_elements")
local Constants = require("src.config.constants")
local ItemDetailsModalManager = require("src.managers.item_details_modal_manager")
local HunterStatsColumn = require("src.ui.components.HunterStatsColumn")
local ReputationSummaryColumn = require("src.ui.components.ReputationSummaryColumn")
local GameStatsColumn = require("src.ui.components.GameStatsColumn")
local ItemGridUI = require("src.ui.item_grid_ui")

---@class ExtractionSummaryScene
local ExtractionSummaryScene = {}

-- Dados processados recebidos da extraction_transition_scene
ExtractionSummaryScene.processedData = nil -- Todos os dados já processados
ExtractionSummaryScene.tooltipItem = nil   -- Item atualmente sob o mouse para tooltip

-- Lista de áreas de itens clicáveis para tooltip
ExtractionSummaryScene.allItemsDisplayAreas = {} -- {{x,y,w,h,itemInstance}, ...}

-- Configurações de renderização otimizada
local RENDER_BATCH_SIZE = 15 -- Renderizar mais itens por vez já que não há loading

--- Chamado quando a cena é carregada.
---@param processedData table Dados completamente processados da extraction_transition_scene
function ExtractionSummaryScene:load(processedData)
    Logger.info("ExtractionSummaryScene", "Carregando cena de sumário com dados pré-processados...")

    if not processedData then
        error("[ExtractionSummaryScene] Dados processados não fornecidos!")
    end

    -- Receber dados já completamente processados da transition scene
    self.processedData = processedData

    -- Limpar áreas de tooltips
    self.allItemsDisplayAreas = {}
    self.tooltipItem = nil

    -- Garantir que listas de itens existem
    self.processedData.extractedEquipment = self.processedData.extractedEquipment or {}
    self.processedData.extractedItems = self.processedData.extractedItems or {}
    self.processedData.extractedArtefacts = self.processedData.extractedArtefacts or {}

    Logger.info("ExtractionSummaryScene",
        string.format("Cena carregada instantaneamente - %s com %d equipamentos, e %d outros itens/artefatos",
            self.processedData.extractionTitle or "Sumário",
            (function()
                local count = 0;
                for _ in pairs(self.processedData.extractedEquipment) do count = count + 1 end;
                return count
            end)(),
            #self.processedData.extractedItems + #self.processedData.extractedArtefacts
        ))
end

--- Atualiza a lógica da cena.
---@param dt number Delta time.
function ExtractionSummaryScene:update(dt)
    -- Converte coordenadas físicas do mouse para coordenadas virtuais
    local physicalMx, physicalMy = love.mouse.getPosition()
    local mx, my = ResolutionUtils.toGame(physicalMx, physicalMy)
    if not mx or not my then
        mx, my = 0, 0 -- Fallback se o mouse estiver fora da área do jogo
    end

    self.tooltipItem = nil -- Reseta a cada frame

    -- Verificar hover nos itens exibidos
    if self.allItemsDisplayAreas then
        for _, area in ipairs(self.allItemsDisplayAreas) do
            if area.item and mx >= area.x and mx <= area.x + area.w and my >= area.y and my <= area.y + area.h then
                self.tooltipItem = area.item -- Atribui a itemInstance completa
                break                        -- Encontrou item, para a busca
            end
        end
    end

    -- Atualiza o gerenciador de tooltip
    ItemDetailsModalManager.update(dt, mx, my, self.tooltipItem)
end

--- Desenha os elementos da cena.
function ExtractionSummaryScene:draw()
    local screenW, screenH = ResolutionUtils.getGameDimensions()

    -- Determinar tema baseado no tipo de extração
    local isDeath = self.processedData.isDeath or false
    local theme = isDeath and colors.extraction_transition.death or colors.extraction_transition.success

    -- Fundo temático baseado no resultado da extração
    love.graphics.setColor(theme.background)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    love.graphics.setColor(colors.white)

    -- Converte coordenadas físicas do mouse para coordenadas virtuais
    local physicalMx, physicalMy = love.mouse.getPosition()
    local mx, my = ResolutionUtils.toGame(physicalMx, physicalMy)
    if not mx or not my then
        mx, my = 0, 0 -- Fallback se o mouse estiver fora da área do jogo
    end

    local currentY = 20 -- Reduzido para dar mais espaço ao título do portal
    local centerX = screenW / 2

    -- Título com cor temática
    love.graphics.setFont(fonts.title_large or fonts.title)
    love.graphics.setColor(theme.text_primary)
    local titleText = self.processedData.extractionTitle or (isDeath and "Falha na Extração" or "Extração Concluída")
    love.graphics.printf(titleText, 0, currentY, screenW, "center")
    local titleHeight = (fonts.title_large or fonts.title):getHeight()
    currentY = currentY + titleHeight + 20

    -- Card do Portal (Usando elements.drawTextCard)
    if self.processedData and self.processedData.portalData then
        local portalCardW = screenW * 0.6
        local portalCardH = 60
        local portalCardX = centerX - portalCardW / 2
        local portalText = string.format("%s", self.processedData.portalData.name) -- Rank será desenhado separadamente

        elements.drawTextCard(portalCardX, currentY, portalCardW, portalCardH, portalText, {
            rankLetterForStyle = self.processedData.portalData.rank,
            font = fonts.title or fonts.main_large,
            h_align = 'center',
            v_align = 'middle',
            padding = 10,
            cornerRadius = 10
        })

        currentY = currentY + portalCardH + 30
    end

    -- Linha 2: Layout de 4 Colunas (Stats Partida, Atributos Finais, Reputação, Itens)
    local columnPaddingHorizontal = 20
    local sidePadding = 30
    local totalHorizontalPadding = sidePadding * 2 + columnPaddingHorizontal * 3
    local columnWidth = (screenW - totalHorizontalPadding) / 4

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
    love.graphics.setColor(theme.text_secondary)
    love.graphics.printf("Estatísticas da Partida", gameplayStatsX, columnTopY, columnWidth, "center")

    if self.processedData.gameplayStats then
        GameStatsColumn.draw(gameplayStatsX, columnContentStartY, columnWidth, columnContentHeight,
            self.processedData.gameplayStats)
    end

    -- Coluna 2: Atributos Finais
    local finalAttrsX = gameplayStatsX + columnWidth + columnPaddingHorizontal
    love.graphics.setFont(columnTitleFont)
    love.graphics.setColor(theme.text_secondary)
    love.graphics.printf("Atributos Finais", finalAttrsX, columnTopY, columnWidth, "center")

    if self.processedData and self.processedData.finalStats and self.processedData.archetypeIds and self.processedData.archetypeManagerInstance and HunterStatsColumn then
        HunterStatsColumn.draw(finalAttrsX, columnContentStartY, columnWidth, columnContentHeight, {
            finalStats = self.processedData.finalStats,
            archetypeIds = self.processedData.archetypeIds,
            archetypeManager = self.processedData.archetypeManagerInstance,
            mouseX = mx,
            mouseY = my
        })
    else
        love.graphics.setFont(fonts.main_small)
        love.graphics.setColor(theme.text_primary)
        love.graphics.printf("Dados de atributos finais não disponíveis.", finalAttrsX, columnContentStartY + 20,
            columnWidth, "center")
    end

    -- Coluna 3: Resumo da Reputação
    local reputationColX = finalAttrsX + columnWidth + columnPaddingHorizontal
    love.graphics.setFont(columnTitleFont)
    love.graphics.setColor(theme.text_secondary)
    love.graphics.printf("Resumo da Reputação", reputationColX, columnTopY, columnWidth, "center")

    if self.processedData.reputationDetails then
        ReputationSummaryColumn.draw(reputationColX, columnContentStartY, columnWidth, columnContentHeight,
            self.processedData.reputationDetails)
    end

    -- Coluna 4: Itens com título contextual
    local extractedItemsX = reputationColX + columnWidth + columnPaddingHorizontal
    love.graphics.setFont(columnTitleFont)
    love.graphics.setColor(theme.text_secondary)
    local itemsTitle = self.processedData.itemsSectionTitle or (isDeath and "Itens Perdidos" or "Itens Extraídos")
    love.graphics.printf(itemsTitle, extractedItemsX, columnTopY, columnWidth, "center")

    local itemDisplayY = columnContentStartY
    local itemCardW = columnWidth - 20 -- Largura do card do item, com padding na coluna
    local itemCardPadding = 5
    local itemIconSize = 48            -- Aumentado de 32
    local itemCardH = itemIconSize + itemCardPadding * 2
    local itemTextOffsetX = itemIconSize + itemCardPadding * 2 + 10
    local itemLineSpacing = 10                      -- Espaço entre cards de itens
    local itemFont = fonts.main or fonts.main_small -- Fonte para nome do item
    local iconInternalPadding = 4                   -- Padding DENTRO da área do ícone, entre a borda do card do ícone e o ícone real

    -- Função otimizada de renderização de itens com batching
    local itemBatchCount = 0
    local maxItemsPerFrame = RENDER_BATCH_SIZE

    local function drawItemEntry(itemInstance, currentItemY, columnX, colWidth)
        -- Verificação robusta para itemInstance e itemBaseId
        if not itemInstance or not itemInstance.itemBaseId or
            itemInstance.itemBaseId == "" or type(itemInstance.itemBaseId) ~= "string" then
            Logger.warn(
                "extraction_summary_scene.drawItemEntry.warning",
                string.format(
                    "[ExtractionSummaryScene] Item inválido ignorado: %s",
                    tostring(itemInstance and itemInstance.itemBaseId or "nil")
                )
            )
            return currentItemY
        end

        -- Controle de batch - limita quantos itens renderizar por frame
        itemBatchCount = itemBatchCount + 1
        if itemBatchCount > maxItemsPerFrame then
            return currentItemY, true -- Sinaliza overflow para parar renderização
        end

        if currentItemY + itemCardH > columnTopY + columnContentHeight then
            return currentItemY, true
        end

        -- Usar dados já processados (nome, raridade, etc.) da transition scene
        local itemName = itemInstance.name or "Item Desconhecido"
        local itemRarity = itemInstance.rarity or itemInstance.rank or 'E'
        local rankStyle = colors.rankDetails[itemRarity]
        local rankTextColor = (rankStyle and rankStyle.text) or theme.text_primary

        local entryDrawX = columnX + (colWidth - itemCardW) / 2
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

    local hasDrawnAnyItem = false

    -- 1. Desenha equipamentos
    if self.processedData and self.processedData.extractedEquipment then
        local displayOrder = Constants.EQUIPMENT_SLOTS_ORDER or {}
        for _, slotId in ipairs(displayOrder) do
            local itemInstance = self.processedData.extractedEquipment[slotId]
            if itemInstance and itemInstance.itemBaseId and itemInstance.itemBaseId ~= "" then
                local newY, hasOverflowed
                itemDisplayY, hasOverflowed = drawItemEntry(itemInstance, itemDisplayY, extractedItemsX, columnWidth)
                if hasOverflowed then break end
                hasDrawnAnyItem = true
            end
        end
    end

    -- 2. Desenha artefatos
    local hasArtefacts = self.processedData.extractedArtefacts and #self.processedData.extractedArtefacts > 0
    if hasArtefacts then
        if hasDrawnAnyItem and itemDisplayY + (itemFont:getHeight() * 0.5) < columnTopY + columnContentHeight then
            local sepY = itemDisplayY - itemLineSpacing / 2
            love.graphics.setColor(theme.accent_primary)
            love.graphics.rectangle("fill", extractedItemsX + 10, sepY, columnWidth - 20, 1)
            love.graphics.setColor(colors.white)
        end
        for _, artefactInstance in ipairs(self.processedData.extractedArtefacts) do
            local newY, hasOverflowed
            itemDisplayY, hasOverflowed = drawItemEntry(artefactInstance, itemDisplayY, extractedItemsX, columnWidth)
            if hasOverflowed then break end
            hasDrawnAnyItem = true
        end
    end

    -- 3. Desenha itens normais
    local hasNormalItems = self.processedData.extractedItems and #self.processedData.extractedItems > 0
    if hasNormalItems then
        if hasDrawnAnyItem and itemDisplayY + (itemFont:getHeight() * 0.5) < columnTopY + columnContentHeight then
            local sepY = itemDisplayY - itemLineSpacing / 2
            love.graphics.setColor(theme.accent_primary)
            love.graphics.rectangle("fill", extractedItemsX + 10, sepY, columnWidth - 20, 1)
            love.graphics.setColor(colors.white)
        end
        for _, itemInstance in ipairs(self.processedData.extractedItems) do
            if itemInstance and itemInstance.itemBaseId and itemInstance.itemBaseId ~= "" then
                local newY, hasOverflowed
                itemDisplayY, hasOverflowed = drawItemEntry(itemInstance, itemDisplayY, extractedItemsX, columnWidth)
                if hasOverflowed then break end
                hasDrawnAnyItem = true
            end
        end
    end


    if not hasDrawnAnyItem then
        love.graphics.setColor(theme.text_secondary)
        love.graphics.setFont(fonts.main_small)
        local noItemsText = isDeath and "Nenhum item foi perdido." or "Nenhum item extraído."
        love.graphics.printf(noItemsText, extractedItemsX, columnContentStartY + 20, columnWidth, "center")
    end

    -- Instrução para continuar com cor temática
    local instructionY = screenH - 40
    love.graphics.setFont(fonts.main_large)
    love.graphics.setColor(theme.text_secondary)
    love.graphics.printf("Pressione qualquer tecla para continuar", 0, instructionY, screenW, "center")

    -- Desenhar Tooltip
    ItemDetailsModalManager.draw()

    if self.itemDataManager and self.itemGridArea then
        ItemGridUI.drawItemGrid(self.items, self.gridRows, self.gridCols, self.itemGridArea.x, self.itemGridArea.y,
            self.itemGridArea.w, self.itemGridArea.h, self.itemDataManager)
    end

    love.graphics.setColor(colors.white) -- Reset final
end

--- Processa pressionamento de teclas.
---@param key string A tecla pressionada.
---@param scancode love.Scancode O scancode da tecla.
---@param isrepeat boolean Se o evento é uma repetição.
function ExtractionSummaryScene:keypressed(key, scancode, isrepeat)
    if isrepeat then return end

    -- Prepara argumentos mínimos para lobby_scene
    local lobbyArgs = {
        extractionSuccessful = self.processedData.wasSuccess or false,
        startTab = Constants.TabIds.SHOPPING
    }

    SceneManager.switchScene("lobby_scene", lobbyArgs)
end

--- Processa movimento do mouse (para tooltips).
function ExtractionSummaryScene:mousemoved(x, y, dx, dy, istouch)
    -- A lógica de identificar o item sob o mouse já está em :update()
end

--- Chamado quando a cena é descarregada.
function ExtractionSummaryScene:unload()
    Logger.info("ExtractionSummaryScene", "Descarregando cena de sumário...")

    -- Limpa dados da cena
    self.processedData = nil
    self.tooltipItem = nil
    self.allItemsDisplayAreas = {}

    Logger.info("ExtractionSummaryScene", "Cena descarregada com sucesso.")
end

return ExtractionSummaryScene
