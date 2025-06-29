local fonts = require("src.ui.fonts")
local elements = require("src.ui.ui_elements")
local colors = require("src.ui.colors")
local ItemGridUI = require("src.ui.item_grid_ui")
local Constants = require("src.config.constants")
local SLOT_IDS = Constants.SLOT_IDS

local HunterStatsColumn = require("src.ui.components.HunterStatsColumn")
local HunterEquipmentColumn = require("src.ui.components.HunterEquipmentColumn")
local HunterLoadoutColumn = require("src.ui.components.HunterLoadoutColumn")
local ItemDetailsModalManager = require("src.managers.item_details_modal_manager")

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
    instance.itemToShowTooltip = nil -- Adicionado
    return instance
end

--- Adiciona uma função update para EquipmentScreen
---@param self EquipmentScreen
---@param dt number Delta time
---@param mx number Posição X global do mouse
---@param my number Posição Y global do mouse
---@param dragState table Estado do drag-and-drop da cena pai
function EquipmentScreen:update(dt, mx, my, dragState)
    self.itemToShowTooltip = nil                     -- Reseta a cada frame

    if not (dragState and dragState.isDragging) then -- Só mostra tooltip se não estiver arrastando
        -- 1. Checa hover em slots de equipamento
        if self.hunterManager and self.equipmentSlotAreas then
            local equippedItems = self.hunterManager:getActiveEquippedItems()
            if equippedItems then
                for slotId, area in pairs(self.equipmentSlotAreas) do
                    if area and mx >= area.x and mx < area.x + area.w and my >= area.y and my < area.y + area.h then
                        if equippedItems[slotId] then
                            self.itemToShowTooltip = equippedItems[slotId]
                            break
                        end
                    end
                end
            end
        end

        -- 2. Checa hover na grade de Armazenamento (Storage)
        if not self.itemToShowTooltip and self.lobbyStorageManager and self.storageGridArea.w and self.storageGridArea.w > 0 then
            local storageItemsDict = self.lobbyStorageManager:getItems(self.lobbyStorageManager:getActiveSectionIndex())
            local storageItemsList = {}
            for _, item in pairs(storageItemsDict or {}) do table.insert(storageItemsList, item) end

            local storageRows, storageCols = self.lobbyStorageManager:getActiveSectionDimensions()
            if #storageItemsList > 0 and storageRows and storageCols then
                local hoveredItem = ItemGridUI.getItemInstanceAtCoords(mx, my, storageItemsList, storageRows, storageCols,
                    self.storageGridArea.x, self.storageGridArea.y, self.storageGridArea.w, self.storageGridArea.h)
                if hoveredItem then
                    self.itemToShowTooltip = hoveredItem
                end
            end
        end

        -- 3. Checa hover na grade de Mochila (Loadout)
        if not self.itemToShowTooltip and self.loadoutManager and self.loadoutGridArea.w and self.loadoutGridArea.w > 0 then
            local loadoutItemsDict = self.loadoutManager:getItems()
            local loadoutItemsList = {}
            for _, item in pairs(loadoutItemsDict or {}) do table.insert(loadoutItemsList, item) end

            local loadoutRows, loadoutCols = self.loadoutManager:getDimensions()
            if #loadoutItemsList > 0 and loadoutRows and loadoutCols then
                local hoveredItem = ItemGridUI.getItemInstanceAtCoords(mx, my, loadoutItemsList, loadoutRows, loadoutCols,
                    self.loadoutGridArea.x, self.loadoutGridArea.y, self.loadoutGridArea.w, self.loadoutGridArea.h)
                if hoveredItem then
                    self.itemToShowTooltip = hoveredItem
                end
            end
        end
    end

    ItemDetailsModalManager.update(dt, mx, my, self.itemToShowTooltip)
end

--- Desenha a tela de equipamento completa.
---@param screenW number Largura da tela.
---@param screenH number Altura da tela.
---@param tabSettings table Configurações das tabs (para calcular altura disponível).
---@param dragState table Estado atual do drag-and-drop da cena pai.
---@param mx number Posição X do mouse (coordenada global da janela Love2D).
---@param my number Posição Y do mouse (coordenada global da janela Love2D).
---@return table storageArea, table loadoutArea, table equipmentSlotsAreas Áreas calculadas para detecção de hover/drop.
function EquipmentScreen:draw(screenW, screenH, tabSettings, dragState, mx, my)
    local padding = 20
    local topPadding = 100
    local areaY = topPadding
    local areaW = screenW
    local areaH = screenH - tabSettings.height -- Altura acima das tabs

    local sectionTopY = areaY
    local titleFont = fonts.title or love.graphics.getFont()
    local titleHeight = titleFont:getHeight()
    local contentMarginY = 10 -- Margem vertical entre título e conteúdo (Reduzido de 20 para 10)
    local contentStartY = sectionTopY + titleHeight + contentMarginY
    local sectionContentH = areaH - contentStartY - padding
    local totalPaddingWidth = padding * 5
    local sectionAreaW = areaW - totalPaddingWidth

    -- Divide a área útil HORIZONTAIS
    local statsW = math.floor(sectionAreaW * 0.25)
    local equipmentW = math.floor(sectionAreaW * 0.25)
    local storageW = math.floor(sectionAreaW * 0.35)
    local loadoutW = sectionAreaW - statsW - equipmentW - storageW

    -- Calcula posições HORIZONTAIS
    local statsX = padding
    local equipmentX = statsX + statsW + padding
    local storageX = equipmentX + equipmentW + padding
    local loadoutX = storageX + storageW + padding

    self.storageGridArea = { x = storageX, y = contentStartY, w = storageW, h = sectionContentH }
    self.loadoutGridArea = {}    -- Inicializa vazio
    self.equipmentSlotAreas = {} -- Inicializa vazio

    -- <<< DESENHA TÍTULOS DAS SEÇÕES >>>
    love.graphics.setFont(titleFont)
    love.graphics.setColor(colors.text_highlight)
    love.graphics.printf("ATRIBUTOS", statsX, sectionTopY, statsW, "left")
    love.graphics.printf("EQUIPAMENTO", equipmentX, sectionTopY, equipmentW, "center")
    love.graphics.printf("ARMAZENAMENTO", storageX, sectionTopY, storageW, "center")
    love.graphics.printf("MOCHILA", loadoutX, sectionTopY, loadoutW, "center")
    love.graphics.setColor(colors.white)
    love.graphics.setFont(fonts.main or titleFont)

    -- <<< DESENHA CONTEÚDO DAS SEÇÕES >>>

    -- Bloco para obter dados do caçador ativo (mantido aqui)
    local activeHunterId = nil
    local hunterData = nil
    local finalStats = nil
    local archetypeIds = nil
    local archetypeManager = nil

    if self.hunterManager then
        activeHunterId = self.hunterManager:getActiveHunterId()
        hunterData = activeHunterId and self.hunterManager.hunters[activeHunterId]
        finalStats = self.hunterManager:getActiveHunterFinalStats()
        archetypeIds = hunterData and hunterData.archetypeIds
        archetypeManager = self.hunterManager.archetypeManager
    end

    -- 1. Desenha Coluna de Stats e Arquétipos (usando o novo componente)
    local statsTooltipLines, statsTooltipX, statsTooltipY -- Para armazenar dados do tooltip de stats
    if self.hunterManager and finalStats and archetypeIds and archetypeManager then
        local statsColumnConfig = {
            finalStats = finalStats,
            archetypeIds = archetypeIds or {},
            mouseX = mx,
            mouseY = my
        }
        statsTooltipLines, statsTooltipX, statsTooltipY = HunterStatsColumn.draw(
            statsX,
            contentStartY,
            statsW,
            sectionContentH,
            statsColumnConfig
        )
    else
        -- Mensagem de erro se HunterManager ou dados essenciais não estiverem disponíveis
        love.graphics.setColor(colors.red)
        local errorMsg = "Erro: Hunter Manager ou dados do caçador indisponíveis."
        if not self.hunterManager then errorMsg = "Erro: Hunter Manager não inicializado!" end
        love.graphics.printf(errorMsg, statsX, contentStartY + sectionContentH / 2, statsW, "center")
    end
    love.graphics.setColor(colors.white) -- Reset cor

    -- 2. Desenha Coluna de Equipamento/Runas (usando o novo componente)
    if self.hunterManager then
        local activeHunterId = self.hunterManager:getActiveHunterId() -- Garante que temos o ID aqui
        self.equipmentSlotAreas = HunterEquipmentColumn.draw(
            equipmentX,
            contentStartY,
            equipmentW,
            sectionContentH,
            activeHunterId,
            nil
        )
    else
        -- Mensagem de erro se HunterManager não estiver disponível
        love.graphics.setColor(colors.red)
        love.graphics.printf("Erro: Hunter Manager não inicializado!", equipmentX, contentStartY + sectionContentH / 2,
            equipmentW, "center")
    end
    love.graphics.setColor(colors.white) -- Reset cor

    -- 3. Desenha Grade do Armazenamento (Storage)
    if self.lobbyStorageManager and self.itemDataManager then
        local storageItems = self.lobbyStorageManager:getItems(self.lobbyStorageManager:getActiveSectionIndex())
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
            self.storageGridArea.y + self.storageGridArea.h / 2, 0, "center")
        love.graphics.setColor(colors.white)
    end

    -- 4. Desenha Coluna da Mochila (Loadout) usando o novo componente
    if self.loadoutManager and self.itemDataManager then
        self.loadoutGridArea = HunterLoadoutColumn.draw(loadoutX, contentStartY, loadoutW, sectionContentH,
            self.loadoutManager, self.itemDataManager)
    else
        -- Mensagem de erro se os managers não estiverem disponíveis
        love.graphics.setColor(colors.red)
        love.graphics.printf("Erro: Loadout/Item Manager não inicializado!",
            loadoutX + loadoutW / 2, contentStartY + sectionContentH / 2, 0, "center")
        love.graphics.setColor(colors.white)
    end

    -- <<< DESENHO DO DRAG-AND-DROP (usa dragState da cena) >>>
    if dragState.isDragging and dragState.draggedItem then
        -- Usa coordenadas virtuais já convertidas pelo lobby_scene.update()
        -- (mx, my já são virtuais!)
        local ghostX = mx - (dragState.draggedItemOffsetX or 0) -- Offset em coordenadas virtuais
        local ghostY = my - (dragState.draggedItemOffsetY or 0) -- Offset em coordenadas virtuais
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
                if targetManager then
                    if dragState.targetGridId == "storage" then
                        targetRows, targetCols = targetManager:getActiveSectionDimensions()
                    else -- loadout
                        targetRows, targetCols = targetManager:getDimensions()
                    end

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
                -- Destaca a borda do slot de equipamento alvo
                local slotArea = self.equipmentSlotAreas and self.equipmentSlotAreas[dragState.targetSlotCoords]
                if slotArea then
                    local r, g, b, a
                    if dragState.isDropValid then
                        local validColor = colors.placement_valid or { 0, 1, 0 }
                        r, g, b = validColor[1], validColor[2], validColor[3]
                    else
                        local invalidColor = colors.placement_invalid or { 1, 0, 0 }
                        r, g, b = invalidColor[1], invalidColor[2], invalidColor[3]
                    end
                    love.graphics.setLineWidth(2)
                    love.graphics.setColor(r, g, b, 0.8)
                    love.graphics.rectangle('line', slotArea.x, slotArea.y, slotArea.w, slotArea.h)
                    love.graphics.setLineWidth(1)
                    love.graphics.setColor(colors.white)
                end
            end
        end
    end
    -- <<< FIM DRAG-AND-DROP DRAW >>>

    -- Desenha o Tooltip no final
    ItemDetailsModalManager.draw()

    -- Desenha o Tooltip de Stats (se houver)
    if statsTooltipLines and #statsTooltipLines > 0 then
        elements.drawTooltipBox(statsTooltipX, statsTooltipY, statsTooltipLines)
    end

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
            local storageItemsDict = self.lobbyStorageManager:getItems(self.lobbyStorageManager:getActiveSectionIndex())
            local storageItemsList = {}
            for _, item in pairs(storageItemsDict or {}) do table.insert(storageItemsList, item) end

            local storageRows, storageCols = self.lobbyStorageManager:getActiveSectionDimensions()
            itemClicked = ItemGridUI.getItemInstanceAtCoords(x, y, storageItemsList, storageRows, storageCols,
                self.storageGridArea.x, self.storageGridArea.y, self.storageGridArea.w, self.storageGridArea.h)
            if itemClicked then
                clickedGridId = "storage"
            end
        end

        -- Verifica clique na grade de Loadout (se não clicou no storage)
        if not itemClicked and self.loadoutManager and self.loadoutGridArea.w > 0 then
            local loadoutItemsDict = self.loadoutManager:getItems()
            local loadoutItemsList = {}
            for _, item in pairs(loadoutItemsDict or {}) do table.insert(loadoutItemsList, item) end

            local loadoutRows, loadoutCols = self.loadoutManager:getDimensions()
            itemClicked = ItemGridUI.getItemInstanceAtCoords(x, y, loadoutItemsList, loadoutRows, loadoutCols,
                self.loadoutGridArea.x, self.loadoutGridArea.y, self.loadoutGridArea.w, self.loadoutGridArea.h)
            if itemClicked then
                clickedGridId = "loadout"
            end
        end

        -- Se um item foi clicado, calcula offset e retorna dados para iniciar drag
        if itemClicked and clickedGridId then
            -- <<< ADICIONADO: Determina parâmetros e chama ItemGridUI.getItemScreenPos >>>
            local targetArea, targetRows, targetCols
            if clickedGridId == "storage" then
                targetArea = self.storageGridArea
                targetRows, targetCols = self.lobbyStorageManager:getActiveSectionDimensions()
            else -- loadout
                targetArea = self.loadoutGridArea
                targetRows, targetCols = self.loadoutManager:getDimensions()
            end

            local itemScreenX, itemScreenY = ItemGridUI.getItemScreenPos(
                itemClicked.row, itemClicked.col,
                targetRows, targetCols,
                targetArea.x, targetArea.y, targetArea.w, targetArea.h
            )
            -- <<< FIM ADIÇÃO >>>

            -- Calcula o offset do mouse em relação ao canto do item
            local itemOffsetX, itemOffsetY = 0, 0
            if itemScreenX and itemScreenY then -- Verifica se a função retornou valores válidos
                itemOffsetX = x - itemScreenX
                itemOffsetY = y - itemScreenY
            else
                print(string.format("AVISO (EquipmentScreen): Falha ao calcular itemScreenPos para item %d em %s",
                    itemClicked.instanceId, clickedGridId))
            end

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
    -- Helper para contar itens em uma tabela (pairs pode não funcionar para arrays simples)
    local function tableCount(tbl)
        local count = 0
        if tbl then
            for _ in pairs(tbl) do
                count = count + 1
            end
        end
        return count
    end

    if buttonIdx == 1 and dragState.isDragging then
        print("EquipmentScreen: handleMouseRelease chamado.")
        print(string.format("  DragState: isDragging=%s, draggedItem.id=%s, draggedItem.baseId=%s, qty=%d",
            tostring(dragState.isDragging),
            dragState.draggedItem and dragState.draggedItem.instanceId or "nil",
            dragState.draggedItem and dragState.draggedItem.itemBaseId or "nil",
            dragState.draggedItem and dragState.draggedItem.quantity or 0))
        print(string.format("  DragState: sourceGridId=%s, sourceSlotId=%s",
            tostring(dragState.sourceGridId), tostring(dragState.sourceSlotId)))
        print(string.format("  DragState: targetGridId=%s, targetSlotCoords=(%s,%s), isDropValid=%s",
            tostring(dragState.targetGridId),
            dragState.targetSlotCoords and dragState.targetSlotCoords.row or "nil",
            dragState.targetSlotCoords and dragState.targetSlotCoords.col or "nil",
            tostring(dragState.isDropValid)))

        -- 1. Verifica drop em SLOT DE EQUIPAMENTO PRIMEIRO
        local droppedOnEquipmentSlot = false
        local targetEquipmentSlotId = nil
        for slotId, area in pairs(dragState.equipmentSlotAreas or {}) do -- Usa as areas passadas no dragState
            if x >= area.x and x < area.x + area.w and y >= area.y and y < area.y + area.h then
                droppedOnEquipmentSlot = true
                targetEquipmentSlotId = slotId
                print(string.format("EquipmentScreen: Mouse sobre slot de equipamento:\t%s", targetEquipmentSlotId))
                break
            end
        end

        if droppedOnEquipmentSlot then
            local itemToEquip = dragState.draggedItem
            if not itemToEquip then
                return true -- Consome o evento mesmo com erro para evitar processamento adicional
            end

            local baseData = self.itemDataManager:getBaseItemData(itemToEquip.itemBaseId)
            if not baseData then
                return true -- Drop inválido (sem base data)
            end

            local itemType = baseData.type
            local isCompatible = false

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

            if isCompatible then
                if dragState.sourceGridId == "equipment" then
                    -- MOVIMENTAÇÃO ENTRE SLOTS DE EQUIPAMENTO - usar moveEquippedItem
                    local activeHunterId = self.hunterManager:getActiveHunterId()
                    if not activeHunterId then
                        return true
                    end

                    local success = self.hunterManager:moveEquippedItem(activeHunterId, dragState.sourceSlotId,
                        targetEquipmentSlotId)
                    return true -- Drop em equipamento tratado (sucesso ou falha)
                else
                    -- EQUIPAR NOVO ITEM DE STORAGE/LOADOUT
                    ---@type LobbyStorageManager|LoadoutManager
                    local sourceManager = (dragState.sourceGridId == "storage") and self.lobbyStorageManager or
                        self.loadoutManager

                    local equipped, oldItemInstance = self.hunterManager:equipItem(itemToEquip, targetEquipmentSlotId)

                    if equipped then
                        -- Origem era storage ou loadout (Equipar Normal)
                        local removed = sourceManager:removeItemInstance(itemToEquip.instanceId, itemToEquip.quantity)
                        if not removed then
                            print(string.format(
                                "ERRO GRAVE (EquipmentScreen): Item %s equipado, mas falha ao remover da origem %s!",
                                itemToEquip.instanceId, dragState.sourceGridId))
                        else
                            print(string.format("EquipmentScreen: Item %s removido de %s após equipar.",
                                itemToEquip.instanceId, dragState.sourceGridId))
                        end

                        if oldItemInstance then
                            print(string.format("EquipmentScreen: Tentando devolver item antigo (%s, ID: %s) para %s",
                                oldItemInstance.itemBaseId, oldItemInstance.instanceId, dragState.sourceGridId))
                            local addedBack = sourceManager:addItemInstance(oldItemInstance)
                            if addedBack then
                                print("EquipmentScreen: Item antigo devolvido com sucesso.")
                            else
                                print("ERRO (EquipmentScreen): Falha ao devolver item antigo ao inventário (" ..
                                    dragState.sourceGridId .. ")! Sem espaço? Item pode ter sido perdido.")
                            end
                        end

                        return true -- Drop em equipamento tratado com sucesso
                    else
                        print("EquipmentScreen: Falha ao equipar o item (hunterManager:equipItem retornou false).")
                        return true -- Drop em equipamento tentado, mas falhou (consome evento)
                    end
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
                local draggedItem = dragState.draggedItem
                local draggedItemBaseData = self.itemDataManager:getBaseItemData(draggedItem.itemBaseId)

                if not draggedItemBaseData then
                    print(
                        "ERRO (EquipmentScreen:handleMouseRelease): Não foi possível obter dados base para o item arrastado " ..
                        draggedItem.itemBaseId)
                    return true -- Consome o evento
                end

                -- A. TENTAR EMPILHAR PRIMEIRO
                print(string.format("  Attempting stack for: %s, stackable: %s", draggedItem.itemBaseId,
                    tostring(draggedItemBaseData.stackable)))
                if draggedItemBaseData.stackable then
                    local itemsInTargetGrid = targetManager:getItems()
                    if dragState.targetGridId == "storage" then
                        itemsInTargetGrid = targetManager:getItems(targetManager:getActiveSectionIndex())
                    end
                    print(string.format("  Items in target grid (%s) for stacking check: %d", dragState.targetGridId,
                        tableCount(itemsInTargetGrid)))

                    local itemAtTargetSlot = nil
                    -- Procurar item no slot alvo de forma mais robusta
                    -- Esta lógica assume que getItemInstanceAtCoords existe e funciona como esperado para encontrar um item em dadas coordenadas.
                    -- Se não, precisaremos de uma função similar ou iterar pelos itens checando a sobreposição de suas áreas com targetSlotCoords.
                    if targetManager.getItemInstanceAtCoords then -- Verifica se o manager tem um método para isso
                        itemAtTargetSlot = targetManager:getItemInstanceAtCoords(dragState.targetSlotCoords.row,
                            dragState.targetSlotCoords.col,
                            dragState.targetGridId == "storage" and targetManager:getActiveSectionIndex() or nil)
                        if itemAtTargetSlot then
                            print(string.format(
                                "  Found itemAtTargetSlot via getItemInstanceAtCoords: ID %s, BaseID %s, Qty %d",
                                itemAtTargetSlot.instanceId, itemAtTargetSlot.itemBaseId, itemAtTargetSlot.quantity))
                        else
                            print("  No item found at target slot using getItemInstanceAtCoords.")
                        end
                    else
                        -- Fallback para a lógica anterior (mais simples, focada em 1x1 e canto superior esquerdo)
                        print(
                            "  targetManager.getItemInstanceAtCoords not found, using simpler fallback for itemAtTargetSlot.")
                        for _, instance in pairs(itemsInTargetGrid) do
                            if instance.row == dragState.targetSlotCoords.row and instance.col == dragState.targetSlotCoords.col then
                                local instanceBaseData = self.itemDataManager:getBaseItemData(instance.itemBaseId)
                                -- Relaxando a restrição de 1x1 para o item alvo, mas ainda checando o ponto de drop
                                if instanceBaseData then
                                    itemAtTargetSlot = instance
                                    print(string.format(
                                        "  Found itemAtTargetSlot (fallback): ID %s, BaseID %s, Qty %d at [%d,%d]",
                                        instance.instanceId, instance.itemBaseId, instance.quantity, instance.row,
                                        instance.col))
                                    break
                                end
                            end
                        end
                        if not itemAtTargetSlot then print("  No itemAtTargetSlot found using fallback.") end
                    end


                    if itemAtTargetSlot and itemAtTargetSlot.itemBaseId == draggedItem.itemBaseId then
                        print(string.format(
                            "  Stacking condition met: itemAtTargetSlot.itemBaseId (%s) == draggedItem.itemBaseId (%s)",
                            itemAtTargetSlot.itemBaseId, draggedItem.itemBaseId))
                        local targetItemBaseData = self.itemDataManager:getBaseItemData(itemAtTargetSlot.itemBaseId)
                        if targetItemBaseData and targetItemBaseData.stackable then
                            print(string.format("  Target item %s is stackable. MaxStack: %d, CurrentQty: %d",
                                itemAtTargetSlot.itemBaseId, (targetItemBaseData.maxStack or 1),
                                itemAtTargetSlot.quantity))
                            local spaceInStack = (targetItemBaseData.maxStack or 1) - itemAtTargetSlot.quantity
                            print(string.format("  Space in stack for target: %d. Dragged item qty: %d", spaceInStack,
                                draggedItem.quantity))

                            if spaceInStack > 0 then
                                local amountToTransfer = math.min(draggedItem.quantity, spaceInStack)
                                print(string.format("  Amount to transfer: %d", amountToTransfer))

                                if amountToTransfer > 0 then
                                    itemAtTargetSlot.quantity = itemAtTargetSlot.quantity + amountToTransfer
                                    draggedItem.quantity = draggedItem.quantity - amountToTransfer

                                    print(string.format(
                                        "EquipmentScreen: Empilhado %d de '%s' (origem instId %s) em '%s' (alvo instId %s). Qtd alvo: %d. Qtd origem restante: %d",
                                        amountToTransfer, draggedItem.itemBaseId, draggedItem.instanceId,
                                        itemAtTargetSlot.itemBaseId, itemAtTargetSlot.instanceId,
                                        itemAtTargetSlot.quantity, draggedItem.quantity))

                                    local sourceManagerUtil = nil
                                    if dragState.sourceGridId == "storage" then
                                        sourceManagerUtil = self.lobbyStorageManager
                                    elseif dragState.sourceGridId == "loadout" then
                                        sourceManagerUtil = self.loadoutManager
                                    end

                                    if draggedItem.quantity <= 0 then
                                        if dragState.sourceGridId == "equipment" then
                                            -- Desequipa o item completamente
                                            self.hunterManager:unequipItemFromActiveHunter(dragState.sourceSlotId)
                                            print(string.format(
                                                "EquipmentScreen: Item '%s' (ID: %s) totalmente empilhado e desequipado da origem %s.",
                                                draggedItem.itemBaseId, draggedItem.instanceId, dragState.sourceSlotId))
                                        elseif sourceManagerUtil then
                                            sourceManagerUtil:removeItemByInstanceId(draggedItem.instanceId)
                                            print(string.format(
                                                "EquipmentScreen: Item '%s' (ID: %s) totalmente empilhado e removido da origem %s.",
                                                draggedItem.itemBaseId, draggedItem.instanceId, dragState.sourceGridId))
                                        end
                                    else
                                        -- Se sobrou quantidade, e a origem é um manager de inventário,
                                        -- a instância original no sourceManager já reflete a quantidade diminuída.
                                        -- Se a origem era equipamento e sobrou (caso raro para empilháveis), tratar.
                                        if dragState.sourceGridId == "equipment" then
                                            print(string.format(
                                                "AVISO (EquipmentScreen): Item de equipamento '%s' parcialmente empilhado. Quantidade restante na origem (%s) é %d. Esta situação pode precisar de tratamento especial.",
                                                draggedItem.itemBaseId, dragState.sourceSlotId, draggedItem.quantity))
                                            -- A instância original no equipamento ainda terá sua quantidade original, pois não há "update quantity" em equip.
                                            -- Isso implica que o empilhamento "copiou" uma parte.
                                        else
                                            -- Para storage/loadout, a alteração em draggedItem.quantity deve ser refletida
                                            -- se o manager opera diretamente nas instâncias.
                                            -- Se os managers salvam/carregam estados, essa mudança precisa ser persistida.
                                            print(string.format(
                                                "EquipmentScreen: Item '%s' (ID: %s) parcialmente empilhado. Quantidade restante na origem %s é %d.",
                                                draggedItem.itemBaseId, draggedItem.instanceId, dragState.sourceGridId,
                                                draggedItem.quantity))
                                        end
                                    end
                                    return true -- Empilhamento realizado, consome o evento
                                end
                            end
                        end
                    end
                end

                -- Lógica original para Mover ou Desequipar para a grade (continua se não houve empilhamento ou bloqueio de duplicata)
                print(string.format("  Proceeding to move/unequip. SourceGrid: %s, SourceSlot: %s",
                    dragState.sourceGridId, dragState.sourceSlotId))
                if dragState.sourceGridId == "equipment" then
                    print(string.format("  Attempting to unequip item from slot %s to %s", dragState.sourceSlotId,
                        dragState.targetGridId))
                    local unequippedItem = self.hunterManager:unequipItemFromActiveHunter(dragState.sourceSlotId)

                    if unequippedItem then
                        print(string.format("  Item %s (ID: %s) unequipped successfully.", unequippedItem.itemBaseId,
                            unequippedItem.instanceId))
                        print(string.format("  Attempting to add unequipped item to %s at [%d,%d], rotated: %s",
                            dragState.targetGridId, dragState.targetSlotCoords.row, dragState.targetSlotCoords.col,
                            tostring(dragState.draggedItemIsRotated)))

                        local added = targetManager:addItemInstanceAt(unequippedItem, dragState.targetSlotCoords.row,
                            dragState.targetSlotCoords.col, dragState.draggedItemIsRotated)

                        if not added then
                            print(string.format(
                                "ERRO CRÍTICO (EquipmentScreen): Falha ao adicionar item desequipado %s (ID: %s) a %s! Tentando devolver ao equipamento...",
                                unequippedItem.itemBaseId, unequippedItem.instanceId, dragState.targetGridId))
                            local reequipped, _ = self.hunterManager:equipItem(unequippedItem, dragState.sourceSlotId)
                            if not reequipped then
                                print(string.format(
                                    "ERRO GRAVÍSSIMO: Falha ao re-equipar item %s (ID: %s) no slot %s! Item perdido?",
                                    unequippedItem.itemBaseId, unequippedItem.instanceId, dragState.sourceSlotId))
                            end
                        else
                            print(string.format(
                                "EquipmentScreen: Item desequipado %s (ID: %s) adicionado a %s [%d,%d]",
                                unequippedItem.itemBaseId, unequippedItem.instanceId, dragState.targetGridId,
                                dragState.targetSlotCoords.row,
                                dragState.targetSlotCoords.col))
                        end
                    else
                        print(string.format(
                            "ERRO (EquipmentScreen): Falha ao desequipar item do slot %s (hunterManager:unequipItem falhou).",
                            dragState.sourceSlotId))
                    end
                    return true
                else -- Se a origem NÃO era "equipment" (ou seja, era "storage" ou "loadout")
                    ---@type LobbyStorageManager|LoadoutManager
                    local sourceManager = (dragState.sourceGridId == "storage") and self.lobbyStorageManager or
                        self.loadoutManager
                    local itemToMove = dragState.draggedItem -- Já temos como 'draggedItem'

                    print(string.format("  Attempting to move item %s (ID: %s) from %s to %s",
                        itemToMove.itemBaseId, itemToMove.instanceId, dragState.sourceGridId, dragState.targetGridId))

                    -- 1. Remove da origem
                    print(string.format("  Removing item %s (ID: %s) from sourceManager (%s)", itemToMove.itemBaseId,
                        itemToMove.instanceId, dragState.sourceGridId))
                    local removed = sourceManager:removeItemInstance(itemToMove.instanceId)
                    print(string.format("  Removal from source %s status: %s", dragState.sourceGridId, tostring(removed)))

                    if removed then
                        -- 2. Adiciona ao destino
                        print(string.format("  Adding item %s (ID: %s) to targetManager (%s) at [%d,%d], rotated: %s",
                            itemToMove.itemBaseId, itemToMove.instanceId, dragState.targetGridId,
                            dragState.targetSlotCoords.row, dragState.targetSlotCoords.col,
                            tostring(dragState.draggedItemIsRotated)))
                        local added = targetManager:addItemInstanceAt(itemToMove, dragState.targetSlotCoords.row,
                            dragState.targetSlotCoords.col, dragState.draggedItemIsRotated)
                        print(string.format("  Addition to target %s status: %s", dragState.targetGridId, tostring(added)))

                        if not added then
                            print(string.format(
                                "ERRO CRÍTICO (EquipmentScreen): Falha ao adicionar item %s (ID: %s) ao destino (%s) após remover da origem (%s)! Tentando devolver...",
                                itemToMove.itemBaseId, itemToMove.instanceId, dragState.targetGridId,
                                dragState.sourceGridId))
                            local addedBack = sourceManager:addItemInstance(itemToMove)
                            if not addedBack then
                                print(string.format(
                                    "ERRO GRAVÍSSIMO: Falha ao devolver item %s (ID: %s) para a origem %s! Item perdido?",
                                    itemToMove.itemBaseId, itemToMove.instanceId, dragState.sourceGridId))
                            else
                                print(string.format("  Item %s (ID: %s) successfully returned to source %s.",
                                    itemToMove.itemBaseId, itemToMove.instanceId, dragState.sourceGridId))
                            end
                        else
                            print(string.format("EquipmentScreen: Item %s (ID: %s) movido de %s para %s [%d,%d]",
                                itemToMove.itemBaseId, itemToMove.instanceId, dragState.sourceGridId,
                                dragState.targetGridId,
                                dragState.targetSlotCoords.row, dragState.targetSlotCoords.col))
                        end
                    else
                        print(string.format("ERRO (EquipmentScreen): Falha ao remover item %s (ID: %s) da origem %s.",
                            itemToMove.itemBaseId, itemToMove.instanceId, dragState.sourceGridId))
                    end
                    return true
                end
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
---@param dragState table Estado atual do drag-and-drop da cena pai.
---@return boolean wantsToRotate Se a tecla indica uma solicitação de rotação.
function EquipmentScreen:keypressed(key, dragState)
    if key == "space" then
        if dragState and dragState.isDragging and dragState.draggedItem then
            local item = dragState.draggedItem
            -- Itens com mesma largura e altura da grade (ex: 1x1, 2x2) não devem rotacionar.
            if item.gridWidth and item.gridHeight and item.gridWidth == item.gridHeight then
                print(string.format(
                    "(EquipmentScreen) Rotação NÃO permitida para item %s: dimensões da grade são iguais (%dx%d).",
                    item.itemBaseId, item.gridWidth, item.gridHeight))
                return false -- Não rotacionar
            end
            print(string.format("(EquipmentScreen) Rotação permitida e solicitada para item %s (%dx%d).",
                item.itemBaseId, item.gridWidth, item.gridHeight))
            return true -- Sinaliza para a cena que queremos rotacionar
        else
            -- Não está arrastando ou não tem item, permite o comportamento padrão (que pode ser nada)
            -- ou, se a intenção é APENAS rotacionar itens arrastados, poderia retornar false aqui também.
            -- Por enquanto, vamos assumir que a rotação só faz sentido se estiver arrastando um item.
            print(
                "(EquipmentScreen) Tecla de rotação pressionada, mas não há item sendo arrastado ou dragState está incompleto.")
            return false
        end
    end
    return false -- Nenhuma ação de rotação solicitada por outra tecla
end

return EquipmentScreen
