local fonts = require("src.ui.fonts")
local elements = require("src.ui.ui_elements")
local colors = require("src.ui.colors")
local ItemGridUI = require("src.ui.item_grid_ui")
local StatsSection = require("src.ui.inventory.sections.stats_section")
local EquipmentSection = require("src.ui.inventory.sections.equipment_section")
local Constants = require("src.config.constants")
local SLOT_IDS = Constants.SLOT_IDS

---@class EquipmentScreen
---@field itemDataManager ItemDataManager
---@field hunterManager HunterManager
---@field lobbyStorageManager LobbyStorageManager
---@field loadoutManager LoadoutManager
---@field storageGridArea table
---@field loadoutGridArea table
local EquipmentScreen = {}
EquipmentScreen.__index = EquipmentScreen

--- Cria uma nova instância da tela de Equipamento.
---@param itemDataManager ItemDataManager
---@param hunterManager HunterManager
---@param lobbyStorageManager LobbyStorageManager
---@param loadoutManager LoadoutManager
---@return EquipmentScreen
function EquipmentScreen:new(itemDataManager, hunterManager, lobbyStorageManager, loadoutManager)
    local instance = setmetatable({}, EquipmentScreen)
    instance.itemDataManager = itemDataManager
    instance.hunterManager = hunterManager
    instance.lobbyStorageManager = lobbyStorageManager
    instance.loadoutManager = loadoutManager
    instance.storageGridArea = {}    -- Área calculada no draw
    instance.loadoutGridArea = {}    -- Área calculada no draw
    instance.equipmentSlotAreas = {} -- Área calculada no draw
    return instance
end

--- Desenha a tela de equipamento completa.
---@param screenW number Largura da tela.
---@param screenH number Altura da tela.
---@param tabSettings table Configurações das tabs (para calcular altura disponível).
---@param dragState table Estado atual do drag-and-drop da cena pai.
---@return table storageArea, table loadoutArea, table equipmentSlotsAreas Áreas calculadas para detecção de hover/drop.
function EquipmentScreen:draw(screenW, screenH, tabSettings, dragState)
    local padding = 20
    local topPadding = 100
    local areaY = topPadding                   -- <<< USA PADDING SUPERIOR MAIOR
    local areaW = screenW                      -- Largura total da tela
    local areaH = screenH - tabSettings.height -- Altura acima das tabs

    local sectionTopY = areaY
    local titleFont = fonts.title or love.graphics.getFont()
    local titleHeight = titleFont:getHeight()
    local contentMarginY = 20 -- Margem vertical entre título e conteúdo
    local contentStartY = sectionTopY + titleHeight + contentMarginY
    local sectionContentH = areaH - contentStartY - padding
    local totalPaddingWidth = padding * 5
    local sectionAreaW = areaW - totalPaddingWidth

    -- Divide a área útil
    local statsW = math.floor(sectionAreaW * 0.25)
    local equipmentW = math.floor(sectionAreaW * 0.25)
    local storageW = math.floor(sectionAreaW * 0.35)
    local loadoutW = sectionAreaW - statsW - equipmentW - storageW

    -- Calcula posições
    local statsX = padding
    local equipmentX = statsX + statsW + padding
    local storageX = equipmentX + equipmentW + padding
    local loadoutX = storageX + storageW + padding

    -- <<< ARMAZENA AS ÁREAS DAS GRIDES NA INSTÂNCIA >>>
    self.storageGridArea = { x = storageX, y = contentStartY, w = storageW, h = sectionContentH }
    self.loadoutGridArea = { x = loadoutX, y = contentStartY, w = loadoutW, h = sectionContentH }
    -- <<< FIM ARMAZENAMENTO >>>

    -- <<< DESENHA TÍTULOS DAS SEÇÕES (NOVA ORDEM) >>>
    love.graphics.setFont(titleFont)
    love.graphics.setColor(colors.text_highlight)
    love.graphics.printf("ATRIBUTOS", statsX, sectionTopY, statsW, "center")
    love.graphics.printf("EQUIPAMENTO", equipmentX, sectionTopY, equipmentW, "center")
    love.graphics.printf("ARMAZENAMENTO", storageX, sectionTopY, storageW, "center")
    love.graphics.printf("MOCHILA", loadoutX, sectionTopY, loadoutW, "center")
    love.graphics.setColor(colors.white)
    love.graphics.setFont(fonts.main or titleFont)

    -- <<< DESENHA CONTEÚDO DAS SEÇÕES (NOVA ORDEM) >>>

    -- Limpa/Recria áreas dos slots de equipamento a cada frame
    self.equipmentSlotAreas = {}

    -- 1. Desenha Seção de Atributos (Stats) - Seção 1
    if self.hunterManager then                -- Verifica se hunterManager existe
        local baseStats = self.hunterManager:getActiveHunterBaseStats()
        if baseStats and next(baseStats) then -- Verifica se a tabela de stats não está vazia
            StatsSection.drawBaseStats(statsX, contentStartY, statsW, sectionContentH, baseStats)
        else
            love.graphics.setColor(colors.red)
            love.graphics.printf("Erro: Stats base do caçador ativo não encontrados!", statsX + statsW / 2,
                contentStartY + sectionContentH / 2, 0, "center")
            love.graphics.setColor(colors.white)
        end
    else
        love.graphics.setColor(colors.red)
        love.graphics.printf("Erro: Hunter Manager não inicializado!", statsX + statsW / 2,
            contentStartY + sectionContentH / 2, 0, "center")
        love.graphics.setColor(colors.white)
    end

    -- 2. Desenha Seção de Equipamento/Runas (Equipment) - Seção 2
    EquipmentSection:draw(equipmentX, contentStartY, equipmentW, sectionContentH, self.hunterManager,
        self.equipmentSlotAreas) -- Passa a tabela para ser preenchida

    -- 3. Desenha Grade do Armazenamento (Storage) - Seção 3
    if self.lobbyStorageManager and self.itemDataManager then
        local storageItems = self.lobbyStorageManager:getItems(self.lobbyStorageManager
            :getActiveSectionIndex()) -- Itens da seção ativa

        local storageRows, storageCols = self.lobbyStorageManager:getActiveSectionDimensions()
        local sectionInfo = {
            total = self.lobbyStorageManager:getTotalSections(),
            active = self.lobbyStorageManager:getActiveSectionIndex()
        }
        ItemGridUI.drawItemGrid(storageItems, storageRows, storageCols,
            self.storageGridArea.x, self.storageGridArea.y, self.storageGridArea.w, self.storageGridArea.h,
            self.itemDataManager, sectionInfo)
    else
        love.graphics.setColor(colors.red)
        love.graphics.printf("Erro: Storage Manager não inicializado!",
            self.storageGridArea.x + self.storageGridArea.w / 2,
            self.storageGridArea.y + self.storageGridArea.h / 2, 0, "center") -- << USA COORDS STORAGE
        love.graphics.setColor(colors.white)
    end

    -- 4. Desenha Grade do Loadout - Seção 4
    if self.loadoutManager and self.itemDataManager then
        local loadoutItems = self.loadoutManager:getItems()
        local loadoutRows, loadoutCols = self.loadoutManager:getDimensions()
        ItemGridUI.drawItemGrid(loadoutItems, loadoutRows, loadoutCols,
            self.loadoutGridArea.x, self.loadoutGridArea.y, self.loadoutGridArea.w, self.loadoutGridArea.h,
            self.itemDataManager, nil) -- nil para sectionInfo
    else
        love.graphics.setColor(colors.red)
        love.graphics.printf("Erro: Loadout Manager não inicializado!",
            self.loadoutGridArea.x + self.loadoutGridArea.w / 2,
            self.loadoutGridArea.y + self.loadoutGridArea.h / 2, 0, "center") -- << USA COORDS LOADOUT
        love.graphics.setColor(colors.white)
    end

    -- <<< DESENHO DO DRAG-AND-DROP (usa dragState da cena) >>>
    if dragState.isDragging and dragState.draggedItem then
        local mx, my = love.mouse.getPosition()
        -- Desenha o item fantasma
        local ghostX = mx - dragState.draggedItemOffsetX
        local ghostY = my - dragState.draggedItemOffsetY
        elements.drawItemGhost(ghostX, ghostY, dragState.draggedItem, 0.75, dragState.draggedItemIsRotated)

        -- Desenha o indicador de drop (usa target info do dragState)
        if dragState.targetGridId and dragState.targetSlotCoords then
            local visualW, visualH -- Calcula dimensões visuais para o indicador
            local item = dragState.draggedItem
            if dragState.draggedItemIsRotated then
                visualW = item.gridHeight or 1
                visualH = item.gridWidth or 1
            else
                visualW = item.gridWidth or 1
                visualH = item.gridHeight or 1
            end

            if dragState.targetGridId == "storage" or dragState.targetGridId == "loadout" then
                local targetArea = (dragState.targetGridId == "storage") and self.storageGridArea or self
                    .loadoutGridArea
                local targetManager = (dragState.targetGridId == "storage") and self.lobbyStorageManager or
                    self.loadoutManager

                local targetRows, targetCols
                if targetManager then -- Garante que o manager existe
                    if dragState.targetGridId == "storage" then
                        targetRows, targetCols = targetManager:getActiveSectionDimensions()
                    else -- loadout
                        targetRows, targetCols = targetManager:getDimensions()
                    end

                    -- Só desenha se obteve as dimensões
                    if targetRows and targetCols then
                        elements.drawDropIndicator(
                            targetArea.x, targetArea.y, targetArea.w, targetArea.h,
                            targetRows, targetCols,
                            dragState.targetSlotCoords.row, dragState.targetSlotCoords.col,
                            visualW, visualH,
                            dragState.isDropValid
                        )
                    end
                end
            elseif dragState.targetGridId == "equipment" then
                -- TODO: Desenhar indicador de drop sobre slot de equipamento?
                -- Poderia destacar a borda do slot em self.equipmentSlotAreas[dragState.targetSlotCoords]
            end
        end
    end
    -- <<< FIM DRAG-AND-DROP DRAW >>>

    -- Retorna as áreas calculadas para a cena principal usar no update/input
    return self.storageGridArea, self.loadoutGridArea, self.equipmentSlotAreas
end

--- Processa cliques do mouse DENTRO da área da tela de equipamento.
--- Determina se o clique iniciou um drag ou interagiu com um elemento (ex: tabs do storage).
---@param x number Posição X do mouse.
---@param y number Posição Y do mouse.
---@param buttonIdx number Índice do botão do mouse.
---@return boolean consumed Se o clique foi consumido por esta tela.
---@return table|nil dragStartData Se um drag foi iniciado, contém { item, sourceGridId, offsetX, offsetY }.
function EquipmentScreen:handleMousePress(x, y, buttonIdx)
    if buttonIdx == 1 then
        local itemClicked = nil
        local clickedGridId = nil
        local itemOffsetX, itemOffsetY = 0, 0

        -- 1. Verifica clique nas tabs do Storage PRIMEIRO
        if self.lobbyStorageManager then
            local storageRows, storageCols = self.lobbyStorageManager:getActiveSectionDimensions()
            local sectionInfo = {
                total = self.lobbyStorageManager:getTotalSections(),
                active = self.lobbyStorageManager:getActiveSectionIndex()
            }
            -- Usa as áreas calculadas no último draw
            local clickedTabIndex = ItemGridUI.handleMouseClick(x, y, sectionInfo,
                self.storageGridArea.x, self.storageGridArea.y, self.storageGridArea.w, self.storageGridArea.h,
                storageRows, storageCols)

            if clickedTabIndex then
                print("EquipmentScreen: Clique na tab do storage", clickedTabIndex)
                self.lobbyStorageManager:setActiveSection(clickedTabIndex)
                return true, nil -- Consumiu o clique, mas não iniciou drag
            end
        end

        -- 2. Verifica clique para iniciar DRAG nas grades (Storage e Loadout)
        -- Verifica clique na grade de Armazenamento
        if self.lobbyStorageManager and self.storageGridArea.w > 0 then
            local storageItems = self.lobbyStorageManager:getItems(self.lobbyStorageManager:getActiveSectionIndex())
            local storageRows, storageCols = self.lobbyStorageManager:getActiveSectionDimensions()
            itemClicked = ItemGridUI.getItemInstanceAtCoords(x, y, storageItems, storageRows, storageCols,
                self.storageGridArea.x, self.storageGridArea.y, self.storageGridArea.w, self.storageGridArea.h)
            if itemClicked then
                clickedGridId = "storage"
            end
        end

        -- Verifica clique na grade de Loadout (se não clicou no storage)
        if not itemClicked and self.loadoutManager and self.loadoutGridArea.w > 0 then
            local loadoutItems = self.loadoutManager:getItems()
            local loadoutRows, loadoutCols = self.loadoutManager:getDimensions()
            itemClicked = ItemGridUI.getItemInstanceAtCoords(x, y, loadoutItems, loadoutRows, loadoutCols,
                self.loadoutGridArea.x, self.loadoutGridArea.y, self.loadoutGridArea.w, self.loadoutGridArea.h)
            if itemClicked then
                clickedGridId = "loadout"
            end
        end

        -- Se um item foi clicado, calcula offset e retorna dados para iniciar drag
        if itemClicked and clickedGridId then
            local itemScreenX = 0
            local itemScreenY = 0
            -- Requer config localmente ou passa como dependência
            local gridConfig = require("src.ui.item_grid_ui").__gridConfig
            local slotTotalWidth = (gridConfig and gridConfig.slotSize or 48) + (gridConfig and gridConfig.padding or 5)
            local slotTotalHeight = (gridConfig and gridConfig.slotSize or 48) + (gridConfig and gridConfig.padding or 5)

            if clickedGridId == "storage" then
                itemScreenX = self.storageGridArea.x + (itemClicked.col - 1) * slotTotalWidth
                itemScreenY = self.storageGridArea.y + (itemClicked.row - 1) * slotTotalHeight
            else -- loadout
                itemScreenX = self.loadoutGridArea.x + (itemClicked.col - 1) * slotTotalWidth
                itemScreenY = self.loadoutGridArea.y + (itemClicked.row - 1) * slotTotalHeight
            end
            itemOffsetX = x - itemScreenX
            itemOffsetY = y - itemScreenY

            local dragStartData = {
                item = itemClicked,
                sourceGridId = clickedGridId,
                offsetX = itemOffsetX,
                offsetY = itemOffsetY,
                isRotated = itemClicked.isRotated or false
            }
            return true, dragStartData -- Consumiu e iniciou drag
        end

        -- 3. Verifica clique nos slots de equipamento (para iniciar drag)
        if not itemClicked then -- Só checa se não clicou em item de grade
            local equippedItemClicked = nil
            local clickedEquipSlotId = nil
            for slotId, area in pairs(self.equipmentSlotAreas or {}) do
                if x >= area.x and x < area.x + area.w and y >= area.y and y < area.y + area.h then
                    -- Clique dentro da área de um slot de equipamento
                    local equippedItems = self.hunterManager:getActiveEquippedItems()
                    if equippedItems and equippedItems[slotId] then
                        -- Slot tem um item, inicia o drag
                        equippedItemClicked = equippedItems[slotId]
                        clickedEquipSlotId = slotId
                        print(string.format("EquipmentScreen: Clique para desequipar item %s do slot %s",
                            equippedItemClicked.itemBaseId, clickedEquipSlotId))
                        break -- Encontrou o slot clicado
                    end
                end
            end

            if equippedItemClicked and clickedEquipSlotId then
                -- Calcula offset relativo ao slot de equipamento
                local slotArea = self.equipmentSlotAreas[clickedEquipSlotId]
                itemOffsetX = x - slotArea.x
                itemOffsetY = y - slotArea.y

                local dragStartData = {
                    item = equippedItemClicked,
                    sourceGridId = "equipment",        -- Marca a origem como equipamento
                    sourceSlotId = clickedEquipSlotId, -- Guarda qual slot específico
                    offsetX = itemOffsetX,
                    offsetY = itemOffsetY,
                    isRotated = false      -- Item em slot de equipamento é sempre considerado não rotacionado visualmente
                }
                return true, dragStartData -- Consumiu e iniciou drag do equipamento
            end
        end
    end
    return false, nil -- Não consumiu o clique
end

--- Processa o soltar do mouse DENTRO da área da tela de equipamento.
--- Finaliza o drag-and-drop, tentando equipar ou mover o item.
---@param x number Posição X do mouse.
---@param y number Posição Y do mouse.
---@param buttonIdx number Índice do botão do mouse.
---@param dragState table Estado completo do drag-and-drop da cena pai.
---@return boolean consumed Se o drop foi tratado por esta tela.
function EquipmentScreen:handleMouseRelease(x, y, buttonIdx, dragState)
    if buttonIdx == 1 and dragState.isDragging then
        print("EquipmentScreen: handleMouseRelease chamado.")

        -- 1. Verifica drop em SLOT DE EQUIPAMENTO PRIMEIRO
        local droppedOnEquipmentSlot = false
        local targetEquipmentSlotId = nil
        for slotId, area in pairs(dragState.equipmentSlotAreas or {}) do -- Usa as areas passadas no dragState
            if x >= area.x and x < area.x + area.w and y >= area.y and y < area.y + area.h then
                droppedOnEquipmentSlot = true
                targetEquipmentSlotId = slotId
                print("EquipmentScreen: Mouse sobre slot de equipamento:", targetEquipmentSlotId)
                break
            end
        end

        if droppedOnEquipmentSlot then
            local itemToEquip = dragState.draggedItem
            if not itemToEquip then
                print("ERRO (EquipmentScreen): draggedItem é nil ao tentar equipar!")
                return true -- Consome o evento mesmo com erro para evitar processamento adicional
            end
            print(string.format("DEBUG (EquipmentScreen): Tentando equipar item ID %d (%s) no slot %s",
                itemToEquip.instanceId,
                itemToEquip.itemBaseId, targetEquipmentSlotId))

            local baseData = self.itemDataManager:getBaseItemData(itemToEquip.itemBaseId)
            if not baseData then
                print("ERRO (EquipmentScreen): baseData é nil para item", itemToEquip.itemBaseId)
                return true
            end

            -- Verifica compatibilidade do item com o slot
            local isCompatible = false
            local itemType = baseData.type
            local targetType = "unknown" -- Para log

            if targetEquipmentSlotId == SLOT_IDS.WEAPON then
                targetType = "weapon"
                isCompatible = (itemType == "weapon")
            elseif targetEquipmentSlotId == SLOT_IDS.HELMET then
                targetType = "helmet"
                isCompatible = (itemType == "helmet")
            elseif targetEquipmentSlotId == SLOT_IDS.CHEST then
                targetType = "chest"
                isCompatible = (itemType == "chest")
            elseif targetEquipmentSlotId == SLOT_IDS.GLOVES then
                targetType = "gloves"
                isCompatible = (itemType == "gloves")
            elseif targetEquipmentSlotId == SLOT_IDS.BOOTS then
                targetType = "boots"
                isCompatible = (itemType == "boots")
            elseif targetEquipmentSlotId == SLOT_IDS.LEGS then
                targetType = "legs"
                isCompatible = (itemType == "legs")
                -- <<< INÍCIO: VERIFICAÇÃO PARA RUNAS (Dinâmica) >>>
            elseif string.sub(targetEquipmentSlotId, 1, 5) == "rune_" then -- Verifica prefixo
                targetType = "rune"
                isCompatible = (itemType == "rune")                        -- Só aceita itens do tipo 'rune'
                -- <<< FIM: VERIFICAÇÃO PARA RUNAS (Dinâmica) >>>
            end

            print(string.format(
                "DEBUG (EquipmentScreen): Verificação de compatibilidade: slotId=%s (espera %s), itemType=%s, isCompatible=%s",
                targetEquipmentSlotId, targetType, itemType, tostring(isCompatible)))

            if isCompatible then
                local sourceManager = (dragState.sourceGridId == "storage") and self.lobbyStorageManager or
                    self.loadoutManager

                print("DEBUG (EquipmentScreen): Chamando hunterManager:equipItem...")
                local equipped, oldItemInstance = self.hunterManager:equipItem(itemToEquip, targetEquipmentSlotId)
                print(string.format(
                    "DEBUG (EquipmentScreen): hunterManager:equipItem retornou: equipped=%s, oldItemInstance=%s",
                    tostring(equipped), oldItemInstance and oldItemInstance.itemBaseId or "nil"))

                if equipped then
                    if dragState.sourceGridId == "equipment" then
                        -- Origem era um slot de equipamento (SWAP)
                        print(string.format("EquipmentScreen: Swap - Item %d movido para slot %s",
                            itemToEquip.instanceId, targetEquipmentSlotId))

                        if oldItemInstance then
                            -- Coloca o item antigo (que estava no slot destino) no slot de origem
                            print(string.format(
                                "EquipmentScreen: Swap - Colocando item antigo %d de volta no slot de origem %s",
                                oldItemInstance.instanceId, dragState.sourceSlotId))
                            -- Define diretamente para evitar chamadas aninhadas complexas de equipItem
                            local activeHunterId = self.hunterManager:getActiveHunterId()
                            if self.hunterManager.equippedItems[activeHunterId] then
                                self.hunterManager.equippedItems[activeHunterId][dragState.sourceSlotId] =
                                    oldItemInstance
                                -- TODO: Poderia precisar recalcular stats aqui também
                            else
                                print(string.format(
                                    "ERRO GRAVE (EquipmentScreen): Falha ao encontrar tabela de equipamento do caçador %s para swap! Item %d pode ter sido perdido.",
                                    activeHunterId, oldItemInstance.instanceId))
                            end
                        else
                            -- O slot de origem agora fica vazio, o que já foi feito implicitamente
                            -- ao mover o itemToEquip com a chamada equipItem inicial.
                            -- Apenas limpamos explicitamente por segurança?
                            -- self.hunterManager.equippedItems[activeHunterId][dragState.sourceSlotId] = nil
                            print(string.format(
                                "EquipmentScreen: Swap - Slot de origem %s ficou vazio (não havia item no destino %s).",
                                dragState.sourceSlotId, targetEquipmentSlotId))
                        end
                    else -- Origem era storage ou loadout (Equipar Normal)
                        local sourceManager = (dragState.sourceGridId == "storage") and self.lobbyStorageManager or
                            self.loadoutManager
                        local removed = sourceManager:removeItemByInstanceId(itemToEquip.instanceId)
                        if not removed then
                            print(string.format(
                                "ERRO GRAVE (EquipmentScreen): Item %d equipado, mas falha ao remover da origem %s!",
                                itemToEquip.instanceId, dragState.sourceGridId))
                        else
                            print(string.format("EquipmentScreen: Item %d removido de %s após equipar.",
                                itemToEquip.instanceId, dragState.sourceGridId))
                        end

                        if oldItemInstance then
                            print(string.format("EquipmentScreen: Tentando devolver item antigo (%s, ID: %d) para %s",
                                oldItemInstance.itemBaseId, oldItemInstance.instanceId, dragState.sourceGridId))
                            local addedBack = sourceManager:addItemInstance(oldItemInstance)
                            if addedBack then
                                print("EquipmentScreen: Item antigo devolvido com sucesso.")
                            else
                                print("ERRO (EquipmentScreen): Falha ao devolver item antigo ao inventário (" ..
                                    dragState.sourceGridId .. ")! Sem espaço? Item pode ter sido perdido.")
                            end
                        end
                    end

                    return true -- Drop em equipamento tratado com sucesso (seja swap ou equipar normal)
                else
                    print("EquipmentScreen: Falha ao equipar o item (hunterManager:equipItem retornou false).")
                    return true -- Drop em equipamento tentado, mas falhou (consome evento)
                end
            else
                print(string.format("EquipmentScreen: Item %s (%s) incompatível com o slot %s.", itemToEquip.itemBaseId,
                    baseData.type, targetEquipmentSlotId))
                return true -- Drop inválido em equipamento (consome evento)
            end
        end                 -- Fim do if droppedOnEquipmentSlot

        -- 2. Se não dropou em slot de equipamento, verifica drop nas GRADES (Storage/Loadout)
        -- Usa targetGridId, targetSlotCoords e isDropValid calculados pela CENA no update e passados via dragState
        if dragState.isDropValid and dragState.targetGridId and dragState.targetSlotCoords then
            -- Verifica se o targetGridId é 'storage' ou 'loadout', pois é isso que esta tela gerencia
            if dragState.targetGridId == "storage" or dragState.targetGridId == "loadout" then
                print(string.format("EquipmentScreen: Drop válido detectado em %s [%d,%d]", dragState.targetGridId,
                    dragState.targetSlotCoords.row,
                    dragState.targetSlotCoords.col))

                local targetManager = (dragState.targetGridId == "storage") and self.lobbyStorageManager or
                    self.loadoutManager

                -- <<< INÍCIO: Lógica para Mover ou Desequipar >>>
                if dragState.sourceGridId == "equipment" then
                    -- Desequipando item para a grade
                    print(string.format("EquipmentScreen: Tentando desequipar item do slot %s", dragState.sourceSlotId))
                    -- Chama a função para desequipar, esperando a instância do item de volta
                    local unequippedItem = self.hunterManager:unequipItem(dragState.sourceSlotId)

                    if unequippedItem then
                        print(string.format("EquipmentScreen: Item %d (%s) desequipado com sucesso.",
                            unequippedItem.instanceId,
                            unequippedItem.itemBaseId))

                        -- DEBUG: Imprime informações antes de adicionar
                        print(string.format(
                            "  DEBUG (EquipmentScreen): Tentando adicionar a %s. Item ID: %d. Coords: [%d,%d]. Rotated: %s",
                            dragState.targetGridId,
                            unequippedItem.instanceId,
                            dragState.targetSlotCoords.row,
                            dragState.targetSlotCoords.col,
                            tostring(dragState.draggedItemIsRotated)))
                        print("  DEBUG (EquipmentScreen): targetManager é nil?", targetManager == nil)

                        -- Tenta adicionar ao inventário alvo
                        local added = targetManager:addItemAt(unequippedItem, dragState.targetSlotCoords.row,
                            dragState.targetSlotCoords.col, dragState.draggedItemIsRotated)

                        -- DEBUG: Imprime o resultado do addItemAt
                        print(string.format("  DEBUG (EquipmentScreen): targetManager:addItemAt retornou: %s",
                            tostring(added)))

                        if not added then
                            print(string.format(
                                "ERRO CRÍTICO (EquipmentScreen): Falha ao adicionar item desequipado %d a %s! Tentando devolver ao equipamento...",
                                unequippedItem.instanceId, dragState.targetGridId))
                            -- Tenta re-equipar (pode falhar se outro item foi equipado enquanto arrastava?)
                            local reequipped, _ = self.hunterManager:equipItem(unequippedItem, dragState.sourceSlotId)
                            if not reequipped then
                                print(string.format(
                                    "ERRO GRAVÍSSIMO: Falha ao re-equipar item %d no slot %s! Item perdido?",
                                    unequippedItem.instanceId, dragState.sourceSlotId))
                                -- TODO: Implementar sistema de "item caído"?
                            end
                        else
                            print(string.format(
                                "EquipmentScreen: Item desequipado %d adicionado a %s [%d,%d]",
                                unequippedItem.instanceId, dragState.targetGridId, dragState.targetSlotCoords.row,
                                dragState.targetSlotCoords.col))
                        end
                    else
                        print(string.format(
                            "ERRO (EquipmentScreen): Falha ao desequipar item do slot %s (hunterManager:unequipItem falhou).",
                            dragState.sourceSlotId))
                        -- O item permanece equipado, o arraste falhou.
                    end
                    -- Mesmo que o desequipamento/adição falhe, consideramos o evento de drop tratado
                    -- para evitar que a cena tente fazer algo mais.
                    return true
                else -- Se a origem NÃO era "equipment" (ou seja, era "storage" ou "loadout")
                    -- Movendo item ENTRE grades (Storage/Loadout)
                    local sourceManager = (dragState.sourceGridId == "storage") and self.lobbyStorageManager or
                        self.loadoutManager
                    local itemToMove = dragState.draggedItem

                    -- 1. Remove da origem
                    local removed = sourceManager:removeItemByInstanceId(itemToMove.instanceId)

                    if removed then
                        -- 2. Adiciona ao destino
                        local added = targetManager:addItemAt(itemToMove, dragState.targetSlotCoords.row,
                            dragState.targetSlotCoords.col, dragState.draggedItemIsRotated)
                        if not added then
                            print(string.format(
                                "ERRO CRÍTICO (EquipmentScreen): Falha ao adicionar item ao destino (%s) após remover da origem (%s)! Tentando devolver...",
                                dragState.targetGridId, dragState.sourceGridId))
                            -- Tenta devolver para a origem
                            local addedBack = sourceManager:addItemInstance(itemToMove) -- Supõe que addItemInstance tenta achar espaço
                            if not addedBack then
                                print(string.format(
                                    "ERRO GRAVÍSSIMO: Falha ao devolver item %d para a origem %s! Item perdido?",
                                    itemToMove.instanceId, dragState.sourceGridId))
                            end
                        else
                            print(string.format("EquipmentScreen: Item %d movido de %s para %s [%d,%d]",
                                itemToMove.instanceId, dragState.sourceGridId, dragState.targetGridId,
                                dragState.targetSlotCoords.row, dragState.targetSlotCoords.col))
                        end
                    else
                        print(string.format("ERRO (EquipmentScreen): Falha ao remover item %d da origem %s.",
                            itemToMove.instanceId, dragState.sourceGridId))
                    end
                    -- Mesmo que a movimentação falhe, consideramos o evento de drop tratado.
                    return true
                end
                -- <<< FIM: Lógica para Mover ou Desequipar >>>
            end -- Fim do if targetGridId == storage or loadout
        end     -- Fim do if isDropValid

        -- Se chegou aqui, o drop não foi em um slot de equipamento válido nem em uma grade válida gerenciada por esta tela
        print("EquipmentScreen: Drop inválido ou fora de área gerenciada.")
        return false -- Não consumiu o drop (deixa a cena limpar o estado de drag)
    end
    return false     -- Não era botão esquerdo ou não estava arrastando
end

--- Processa pressionamento de teclas quando esta tela está ativa e um item está sendo arrastado.
---@param key string A tecla pressionada (love.keyboard.keys).
---@return boolean wantsToRotate Se a tecla indica uma solicitação de rotação.
function EquipmentScreen:keypressed(key)
    if key == "space" then
        print("(EquipmentScreen) Rotação solicitada (Espaço)")
        return true -- Sinaliza para a cena que queremos rotacionar
    end
    return false    -- Nenhuma ação de rotação solicitada
end

return EquipmentScreen
