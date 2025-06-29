local SceneManager = require("src.core.scene_manager")
local fonts = require("src.ui.fonts")
local colors = require("src.ui.colors")
local elements = require("src.ui.ui_elements")
local Constants = require("src.config.constants")
local ItemDetailsModalManager = require("src.managers.item_details_modal_manager")
local ManagerRegistry = require("src.managers.manager_registry")
local HunterStatsColumn = require("src.ui.components.HunterStatsColumn")
local ReputationSummaryColumn = require("src.ui.components.ReputationSummaryColumn")
local GameStatsColumn = require("src.ui.components.GameStatsColumn")
local ItemGridUI = require("src.ui.item_grid_ui")

---@class ExtractionSummaryScene
local ExtractionSummaryScene = {}

ExtractionSummaryScene.args = nil              -- Argumentos recebidos da GameplayScene
ExtractionSummaryScene.reputationDetails = nil -- Detalhes da reputação
ExtractionSummaryScene.itemDataManager = nil ---@type ItemDataManager
ExtractionSummaryScene.tooltipItem = nil       -- Item atualmente sob o mouse para tooltip
ExtractionSummaryScene.gameStats = nil         -- Estatísticas do jogo

-- Sistema de carregamento assíncrono
ExtractionSummaryScene.loadingCoroutine = nil
ExtractionSummaryScene.loadingTasks = {}
ExtractionSummaryScene.currentTaskIndex = 1
ExtractionSummaryScene.totalTasks = 0
ExtractionSummaryScene.currentTaskName = "Iniciando..."
ExtractionSummaryScene.isLoadingComplete = false
ExtractionSummaryScene.loadingProgress = 0

-- Configurações de performance
local LOAD_BUDGET_MS = 8     -- 8ms por frame para carregamento
local ITEM_PROCESS_BATCH = 5 -- Processar 5 itens por frame
local RENDER_BATCH_SIZE = 10 -- Renderizar 10 itens por vez

-- Modificado: Uma única lista para todas as áreas de itens clicáveis na coluna 3
ExtractionSummaryScene.allItemsDisplayAreas = {} -- {{x,y,w,h,itemInstance}, ...}

-- Cache para otimização de renderização
ExtractionSummaryScene.renderCache = {
    processedItems = {},
    itemCards = {},
    lastFrameTime = 0,
    needsRefresh = true
}

--- Inicializa as tarefas de carregamento assíncrono
function ExtractionSummaryScene:_initializeLoadingTasks()
    self.loadingTasks = {
        {
            name = "Carregando managers...",
            task = function() return self:_loadManagers() end
        },
        {
            name = "Processando reputação...",
            task = function() return self:_processReputation() end
        },
        {
            name = "Carregando estatísticas...",
            task = function() return self:_loadGameStats() end
        },
        {
            name = "Processando itens extraídos...",
            task = function() return self:_processExtractedItems() end
        },
        {
            name = "Preparando interface...",
            task = function() return self:_prepareInterface() end
        },
        {
            name = "Finalizando carregamento...",
            task = function() return self:_finalizeLoading() end
        }
    }

    self.totalTasks = #self.loadingTasks
    self.currentTaskIndex = 1
    Logger.info(
        "extraction_summary_scene.load",
        string.format(
            "[ExtractionSummaryScene] Carregamento assíncrono iniciado com %d tarefas",
            self.totalTasks
        )
    )
end

--- Cria corrotina principal de carregamento
function ExtractionSummaryScene:_createLoadingCoroutine()
    return coroutine.create(function()
        local startTime = love.timer.getTime()

        for i, taskData in ipairs(self.loadingTasks) do
            self.currentTaskIndex = i
            self.currentTaskName = taskData.name
            self.loadingProgress = (i - 1) / self.totalTasks

            Logger.debug(
                "extraction_summary_scene.createLoadingCoroutine.execute",
                string.format("[ExtractionSummaryScene] Executando tarefa %d/%d: %s", i, self.totalTasks, taskData.name))

            local taskStartTime = love.timer.getTime()
            local success, result = pcall(taskData.task)

            if not success then
                Logger.error(
                    "extraction_summary_scene.createLoadingCoroutine.execute.error",
                    string.format("[ExtractionSummaryScene] Erro na tarefa '%s': %s", taskData.name, tostring(result)))
            end

            local taskTime = love.timer.getTime() - taskStartTime
            if taskTime > LOAD_BUDGET_MS / 1000 then
                Logger.warn(
                    "extraction_summary_scene.createLoadingCoroutine.execute.warning",
                    string.format(
                        "[ExtractionSummaryScene] Tarefa '%s' excedeu budget (%.2fms)",
                        taskData.name,
                        taskTime * 1000
                    )
                )
            end

            -- Yield para manter responsividade
            coroutine.yield()
        end

        self.isLoadingComplete = true
        self.loadingProgress = 1.0

        local totalTime = love.timer.getTime() - startTime
        Logger.info(
            "extraction_summary_scene.createLoadingCoroutine.execute.success",
            string.format(
                "[ExtractionSummaryScene] Carregamento concluído em %.2fms",
                totalTime * 1000
            )
        )
    end)
end

--- Carrega managers necessários
function ExtractionSummaryScene:_loadManagers()
    ---@type ItemDataManager
    self.itemDataManager = ManagerRegistry:get("itemDataManager")
    if not self.itemDataManager then
        error("[ExtractionSummaryScene] ItemDataManager não encontrado no Registry!")
    end
end

--- Processa dados de reputação
function ExtractionSummaryScene:_processReputation()
    ---@class ReputationManager
    local reputationManager = ManagerRegistry:get("reputationManager")
    if not reputationManager then
        error("[ExtractionSummaryScene] CRITICAL: ReputationManager não encontrado no Registry!")
    end

    -- Combinar itens da mochila e equipamentos extraídos com validação robusta
    local extractedItemsList = {}

    if self.args.extractedItems then
        for _, item in ipairs(self.args.extractedItems) do
            if item and item.itemBaseId and
                type(item.itemBaseId) == "string" and item.itemBaseId ~= "" then
                table.insert(extractedItemsList, item)
            else
                Logger.warn(
                    "extraction_summary_scene.processReputation.warning",
                    string.format(
                        "[ExtractionSummaryScene] Item da mochila inválido ignorado: itemBaseId = %s",
                        tostring(item and item.itemBaseId or "nil")))
            end
        end
    end

    if self.args.extractedEquipment then
        for _, item in pairs(self.args.extractedEquipment) do
            if item and item.itemBaseId and
                type(item.itemBaseId) == "string" and item.itemBaseId ~= "" then
                table.insert(extractedItemsList, item)
            else
                Logger.warn(
                    "extraction_summary_scene.processReputation.warning",
                    string.format(
                        "[ExtractionSummaryScene] Item de equipamento inválido ignorado: itemBaseId = %s",
                        tostring(item and item.itemBaseId or "nil")))
            end
        end
    end

    self.reputationDetails = reputationManager:processIncursionResult({
        portalData = self.args.portalData,
        wasSuccess = self.args.wasSuccess,
        hunterData = self.args.hunterData,
        lootedItems = extractedItemsList,
        gameplayStats = self.args.gameplayStats
    })
end

--- Carrega estatísticas do jogo
function ExtractionSummaryScene:_loadGameStats()
    local gameStatsManager = ManagerRegistry:get("gameStatisticsManager")
    if gameStatsManager then
        self.gameStats = gameStatsManager:getRawStats()
    end
end

--- Processa itens extraídos em lotes para otimizar performance
function ExtractionSummaryScene:_processExtractedItems()
    -- Garante que listas existem
    if not self.args.extractedEquipment then
        self.args.extractedEquipment = {}
    end
    if not self.args.extractedItems then
        self.args.extractedItems = {}
    end

    -- Pre-processa itens válidos
    self.renderCache.processedItems.equipment = {}
    self.renderCache.processedItems.backpack = {}

    -- Processa equipamentos
    local displayOrder = Constants.EQUIPMENT_SLOTS_ORDER or {}
    for _, slotId in ipairs(displayOrder) do
        local itemInstance = self.args.extractedEquipment[slotId]
        if itemInstance and itemInstance.itemBaseId and
            type(itemInstance.itemBaseId) == "string" and itemInstance.itemBaseId ~= "" then
            table.insert(self.renderCache.processedItems.equipment, itemInstance)
        end
    end

    -- Processa itens da mochila
    for _, itemInstance in ipairs(self.args.extractedItems) do
        if itemInstance and itemInstance.itemBaseId and
            type(itemInstance.itemBaseId) == "string" and itemInstance.itemBaseId ~= "" then
            table.insert(self.renderCache.processedItems.backpack, itemInstance)
        end
    end

    Logger.debug(
        "extraction_summary_scene.processExtractedItems",
        string.format(
            "[ExtractionSummaryScene] Processados %d equipamentos e %d itens da mochila",
            #self.renderCache.processedItems.equipment,
            #self.renderCache.processedItems.backpack)
    )
end

--- Prepara interface para renderização
function ExtractionSummaryScene:_prepareInterface()
    -- Limpar estado de tooltips e layouts anteriores
    self.tooltipItem = nil
    self.allItemsDisplayAreas = {}
    self.renderCache.needsRefresh = true

    -- Pre-calcular dimensões da interface
    local screenW, screenH = ResolutionUtils.getGameDimensions()
    self.renderCache.screenDimensions = { w = screenW, h = screenH }
end

--- Finaliza o carregamento
function ExtractionSummaryScene:_finalizeLoading()
    -- Força coleta de lixo
    collectgarbage("collect")

    -- Pequena pausa para garantir estabilidade
    love.timer.sleep(0.01)
end

--- Processa fila de carregamento assíncrono
function ExtractionSummaryScene:_processLoadingQueue(maxTime)
    if not self.loadingCoroutine or self.isLoadingComplete then
        return
    end

    local startTime = love.timer.getTime()

    while love.timer.getTime() - startTime < maxTime do
        local success, result = coroutine.resume(self.loadingCoroutine)

        if not success then
            Logger.error(
                "extraction_summary_scene.processLoadingQueue.error",
                string.format(
                    "[ExtractionSummaryScene] Erro na corrotina de carregamento: %s",
                    tostring(result)
                )
            )
            self.isLoadingComplete = true
            break
        elseif coroutine.status(self.loadingCoroutine) == 'dead' then
            break
        end
    end
end

--- Chamado quando a cena é carregada.
---@param args table Argumentos da GameplayScene:
---   portalName (string), portalRank (string),
---   extractedItems (table), extractedEquipment (table<string, ItemInstance>),
---   hunterId (string), gameplayStats (table),
---   finalStats (table), archetypeIds (table), archetypeManagerInstance (ArchetypeManager)
function ExtractionSummaryScene:load(args)
    Logger.info(
        "extraction_summary_scene.load",
        "[ExtractionSummaryScene] Iniciando carregamento assíncrono..."
    )

    if args then
        Logger.debug(
            "extraction_summary_scene.load",
            string.format(
                "[ExtractionSummaryScene] Portal: %s (Rank %s), Hunter: %s, Itens: %d, Equipamentos: %d",
                tostring(args.portalData and args.portalData.name or "N/A"),
                tostring(args.portalData and args.portalData.rank or "N/A"),
                tostring(args.hunterId),
                tostring(args.extractedItems and #args.extractedItems or 0),
                args.extractedEquipment and
                (function()
                    local count = 0; for _ in pairs(args.extractedEquipment) do count = count + 1 end; return count
                end)() or 0
            ))
    else
        Logger.warn("ExtractionSummaryScene", "Nenhum argumento recebido!")
    end

    self.args = args

    -- Verifica argumentos críticos e define padrões
    if not self.args.archetypeManagerInstance then
        Logger.warn(
            "extraction_summary_scene.load.warning",
            "[ExtractionSummaryScene] ArchetypeManager instance não recebida!"
        )
    end
    if not self.args.extractedEquipment then
        self.args.extractedEquipment = {}
    end
    if not self.args.extractedItems then
        self.args.extractedItems = {}
    end

    -- Inicializa sistema de carregamento assíncrono
    self:_initializeLoadingTasks()
    self.loadingCoroutine = self:_createLoadingCoroutine()
    self.isLoadingComplete = false
    self.loadingProgress = 0
end

--- Atualiza a lógica da cena.
---@param dt number Delta time.
function ExtractionSummaryScene:update(dt)
    -- Processa carregamento assíncrono se ainda não completou
    if not self.isLoadingComplete then
        self:_processLoadingQueue(LOAD_BUDGET_MS / 1000)
        return -- Não processa outros updates até carregamento completar
    end

    local mx, my = love.mouse.getPosition()
    self.tooltipItem = nil -- Reseta a cada frame

    -- Verificar hover nos itens exibidos na coluna 3 (apenas se carregamento completo)
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

    -- Atualiza cache de renderização se necessário
    if self.renderCache.needsRefresh then
        self:_refreshRenderCache()
        self.renderCache.needsRefresh = false
    end
end

--- Atualiza cache de renderização para otimizar performance
function ExtractionSummaryScene:_refreshRenderCache()
    -- Limpa áreas de itens anteriores
    self.allItemsDisplayAreas = {}

    -- Força coleta de lixo para liberar memória
    if collectgarbage("count") > 50000 then -- Se > 50MB
        collectgarbage("collect")
    end

    Logger.debug(
        "extraction_summary_scene.refreshRenderCache",
        "[ExtractionSummaryScene] Cache de renderização atualizado"
    )
end

--- Desenha tela de carregamento otimizada
function ExtractionSummaryScene:_drawLoadingScreen(screenW, screenH)
    local centerX, centerY = screenW / 2, screenH / 2

    -- Título
    love.graphics.setFont(fonts.title_large or fonts.title)
    love.graphics.setColor(colors.text_title)
    love.graphics.printf("Processando Extração...", 0, centerY - 100, screenW, "center")

    -- Barra de progresso
    local barW, barH = 400, 20
    local barX, barY = centerX - barW / 2, centerY - 20

    -- Fundo da barra
    love.graphics.setColor(colors.border_active or { 0.2, 0.2, 0.2 })
    love.graphics.rectangle("fill", barX, barY, barW, barH)

    -- Preenchimento da barra
    love.graphics.setColor(colors.text_value or { 0.2, 0.6, 1.0 })
    love.graphics.rectangle("fill", barX, barY, barW * self.loadingProgress, barH)

    -- Borda da barra
    love.graphics.setColor(colors.bar_border or { 0.4, 0.4, 0.4 })
    love.graphics.rectangle("line", barX, barY, barW, barH)

    -- Texto do progresso
    love.graphics.setFont(fonts.main or fonts.main_small)
    love.graphics.setColor(colors.text_main)
    love.graphics.printf(self.currentTaskName, 0, centerY + 30, screenW, "center")

    -- Porcentagem
    local percentText = string.format("%.0f%%", self.loadingProgress * 100)
    love.graphics.printf(percentText, 0, centerY + 60, screenW, "center")

    love.graphics.setColor(colors.white) -- Reset
end

--- Desenha os elementos da cena.
function ExtractionSummaryScene:draw()
    local screenW, screenH = ResolutionUtils.getGameDimensions()

    -- Fundo simples
    love.graphics.setColor(colors.lobby_background)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    love.graphics.setColor(colors.white)

    -- Se ainda está carregando, mostra tela de carregamento
    if not self.isLoadingComplete then
        self:_drawLoadingScreen(screenW, screenH)
        return
    end

    -- Converte coordenadas físicas do mouse para coordenadas virtuais
    local physicalMx, physicalMy = love.mouse.getPosition()
    local mx, my = ResolutionUtils.toGame(physicalMx, physicalMy)
    if not mx or not my then
        mx, my = 0, 0 -- Fallback se o mouse estiver fora da área do jogo
    end

    local currentY = 20 -- Reduzido para dar mais espaço ao título do portal
    local centerX = screenW / 2

    -- Título
    love.graphics.setFont(fonts.title_large or fonts.title)
    love.graphics.setColor(colors.text_title)
    local titleText = "Extração Concluída"
    if not self.args.wasSuccess then
        titleText = "Falha na Extração"
    end
    love.graphics.printf(titleText, 0, currentY, screenW, "center")
    local titleHeight = (fonts.title_large or fonts.title):getHeight()
    currentY = currentY + titleHeight + 20

    -- Card do Portal (Usando elements.drawTextCard)
    if self.args and self.args.portalData then
        local portalCardW = screenW * 0.6
        local portalCardH = 60
        local portalCardX = centerX - portalCardW / 2
        local portalText = string.format("%s", self.args.portalData.name) -- Rank será desenhado separadamente

        elements.drawTextCard(portalCardX, currentY, portalCardW, portalCardH, portalText, {
            rankLetterForStyle = self.args.portalData.rank,
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
    love.graphics.setColor(colors.text_value)
    love.graphics.printf("Estatísticas da Partida", gameplayStatsX, columnTopY, columnWidth, "center")

    if self.gameStats then
        GameStatsColumn.draw(gameplayStatsX, columnContentStartY, columnWidth, columnContentHeight, self.gameStats)
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

    -- Coluna 3: Resumo da Reputação
    local reputationColX = finalAttrsX + columnWidth + columnPaddingHorizontal
    love.graphics.setFont(columnTitleFont)
    love.graphics.setColor(colors.text_value)
    love.graphics.printf("Resumo da Reputação", reputationColX, columnTopY, columnWidth, "center")

    if self.reputationDetails then
        ReputationSummaryColumn.draw(reputationColX, columnContentStartY, columnWidth, columnContentHeight,
            self.reputationDetails)
    end

    -- Coluna 4: Itens Extraídos
    local extractedItemsX = reputationColX + columnWidth + columnPaddingHorizontal
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

    -- Função otimizada de renderização de itens com batching
    local itemBatchCount = 0
    local maxItemsPerFrame = RENDER_BATCH_SIZE

    local function drawItemEntry(itemInstance, currentItemY)
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
            -- Verificação adicional antes de chamar drawItemEntry
            if itemInstance and itemInstance.itemBaseId and
                type(itemInstance.itemBaseId) == "string" and itemInstance.itemBaseId ~= "" then
                local newY, hasOverflowed
                itemDisplayY, hasOverflowed = drawItemEntry(itemInstance, itemDisplayY)
                if hasOverflowed then break end
                hasDrawnAnyEquipment = true
            elseif itemInstance then
                Logger.warn("[ExtractionSummaryScene:draw]",
                    string.format("Item de equipamento inválido ignorado no slot %s: itemBaseId = %s",
                        tostring(slotId), tostring(itemInstance.itemBaseId)))
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
            -- Verificação adicional antes de chamar drawItemEntry
            if itemInstance and itemInstance.itemBaseId and
                type(itemInstance.itemBaseId) == "string" and itemInstance.itemBaseId ~= "" then
                local newY, hasOverflowed
                itemDisplayY, hasOverflowed = drawItemEntry(itemInstance, itemDisplayY)
                if hasOverflowed then break end
            elseif itemInstance then
                Logger.warn("[ExtractionSummaryScene:draw]",
                    string.format("Item da mochila inválido ignorado: itemBaseId = %s",
                        tostring(itemInstance.itemBaseId)))
            end
        end
    end

    if #self.allItemsDisplayAreas == 0 then
        love.graphics.setColor(colors.text_muted or { 0.5, 0.5, 0.5 })
        love.graphics.setFont(fonts.main_small)
        love.graphics.printf("Nenhum item extraído.", extractedItemsX, columnContentStartY + 20, columnWidth, "center")
    end

    -- Instrução para continuar
    local instructionY = screenH - 40
    love.graphics.setFont(fonts.main_large)
    love.graphics.setColor(colors.text_label)
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

    -- Só permite continuar se carregamento estiver completo
    if not self.isLoadingComplete then
        Logger.debug(
            "extraction_summary_scene.keypressed",
            "[ExtractionSummaryScene] Aguardando carregamento completar..."
        )
        return
    end

    -- Otimização: salva itens de forma assíncrona para evitar travamentos
    self:_saveItemsAsync()

    -- Limpa recursos antes de mudar de cena
    self:_cleanupResources()

    -- Prepara argumentos para lobby_scene
    local lobbyArgs = {}
    if self.args then
        lobbyArgs = shallowcopy(self.args)
        lobbyArgs.extractionSuccessful = self.reputationDetails and self.reputationDetails.wasSuccess or false
        lobbyArgs.startTab = Constants.TabIds.SHOPPING

        -- Remove dados pesados que não são necessários na lobby
        lobbyArgs.portalName = nil
        lobbyArgs.portalRank = nil
        lobbyArgs.portalData = nil
        lobbyArgs.gameplayStats = nil
        lobbyArgs.finalStats = nil
        lobbyArgs.archetypeIds = nil
        lobbyArgs.archetypeManagerInstance = nil
    else
        lobbyArgs = { extractionSuccessful = false, startTab = Constants.TabIds.SHOPPING }
    end

    SceneManager.switchScene("lobby_scene", lobbyArgs)
end

--- Salva itens de forma assíncrona para evitar travamentos
function ExtractionSummaryScene:_saveItemsAsync()
    if not self.args or not self.args.wasSuccess then
        return
    end

    Logger.info(
        "extraction_summary_scene.saveItemsAsync",
        "[ExtractionSummaryScene] Iniciando salvamento assíncrono de itens..."
    )

    -- Usar corrotina para salvar em lotes
    local saveCoroutine = coroutine.create(function()
        ---@type LoadoutManager
        local loadoutManager = ManagerRegistry:get("loadoutManager")

        if loadoutManager and self.args.extractedItems then
            loadoutManager:clearAllItems()

            local validItemsCount = 0
            local batchSize = ITEM_PROCESS_BATCH

            -- Processa itens em lotes
            for i, itemInstance in ipairs(self.args.extractedItems) do
                if itemInstance and itemInstance.itemBaseId and
                    type(itemInstance.itemBaseId) == "string" and itemInstance.itemBaseId ~= "" then
                    loadoutManager:addItem(itemInstance.itemBaseId, itemInstance.quantity)
                    validItemsCount = validItemsCount + 1
                else
                    Logger.warn(
                        "extraction_summary_scene.saveItemsAsync.warning",
                        string.format(
                            "[ExtractionSummaryScene] Item inválido ignorado: itemBaseId = %s",
                            tostring(itemInstance and itemInstance.itemBaseId or "nil")))
                end

                -- Yield a cada lote para manter responsividade
                if i % batchSize == 0 then
                    coroutine.yield()
                end
            end

            Logger.info(
                "extraction_summary_scene.saveItemsAsync.success",
                string.format(
                    "[ExtractionSummaryScene] Salvamento concluído: %d itens válidos de %d total",
                    validItemsCount, #self.args.extractedItems))
        end
    end)

    -- Executa salvamento (pode ser feito em uma frame ou duas)
    local success, result = coroutine.resume(saveCoroutine)
    if not success then
        Logger.error(
            "extraction_summary_scene.saveItemsAsync.error",
            string.format(
                "[ExtractionSummaryScene] Erro no salvamento assíncrono: %s",
                tostring(result)
            )
        )
    end
end

--- Limpa recursos para evitar vazamentos de memória
function ExtractionSummaryScene:_cleanupResources()
    -- Limpa cache de renderização
    if self.renderCache then
        self.renderCache.processedItems = {}
        self.renderCache.itemCards = {}
        self.renderCache.needsRefresh = false
    end

    -- Limpa áreas de itens
    self.allItemsDisplayAreas = {}

    -- Para corrotinas ativas
    if self.loadingCoroutine then
        self.loadingCoroutine = nil
    end

    -- Limpa tarefas de carregamento
    self.loadingTasks = {}

    -- Força coleta de lixo
    collectgarbage("collect")

    Logger.debug(
        "extraction_summary_scene.cleanupResources",
        "[ExtractionSummaryScene] Recursos limpos antes de mudar de cena"
    )
end

--- Processa movimento do mouse (para tooltips).
function ExtractionSummaryScene:mousemoved(x, y, dx, dy, istouch)
    -- A lógica de identificar o item sob o mouse já está em :update()
end

--- Chamado quando a cena é descarregada.
function ExtractionSummaryScene:unload()
    Logger.info(
        "extraction_summary_scene.unload",
        "[ExtractionSummaryScene] Descarregando cena com limpeza otimizada..."
    )

    -- Usa limpeza otimizada de recursos
    self:_cleanupResources()

    -- Limpa dados específicos da cena
    self.args = nil
    self.reputationDetails = nil
    self.gameStats = nil
    self.tooltipItem = nil
    self.itemDataManager = nil

    -- Reset estado de carregamento
    self.isLoadingComplete = false
    self.loadingProgress = 0
    self.currentTaskIndex = 1
    self.currentTaskName = "Iniciando..."

    Logger.info(
        "extraction_summary_scene.unload.success",
        "[ExtractionSummaryScene] Cena descarregada com sucesso."
    )
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
