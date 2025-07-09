-----------------------------------------------------------
--- Tela de Inventário durante a cena de jogo
-----------------------------------------------------------

local elements = require("src.ui.ui_elements")
local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")
local ManagerRegistry = require("src.managers.manager_registry")
local ItemDetailsModalManager = require("src.managers.item_details_modal_manager")
local ItemGridUI = require("src.ui.item_grid_ui")
local HunterStatsColumn = require("src.ui.components.HunterStatsColumn")
local HunterEquipmentColumn = require("src.ui.components.HunterEquipmentColumn")
local HunterInventoryColumn = require("src.ui.components.HunterInventoryColumn")
local ArtefactsDisplay = require("src.ui.components.ArtefactsDisplay")

local InventoryScreen = {}
InventoryScreen.isVisible = false
InventoryScreen.mouseX = 0
InventoryScreen.mouseY = 0
InventoryScreen.equipmentSlotAreas = {} -- Mantém como cache local, mas será retornado
InventoryScreen.inventoryGridArea = {}  -- Mantém como cache local, mas será retornado
InventoryScreen.itemToShowTooltip = nil -- Adicionado para armazenar o item para tooltip

function InventoryScreen.hide()         -- Função para esconder
    InventoryScreen.isVisible = false
    ItemDetailsModalManager.hide()
end

function InventoryScreen.show() -- Função para mostrar
    InventoryScreen.isVisible = true
    InventoryScreen.equipmentSlotAreas = {}
    InventoryScreen.inventoryGridArea = {}
    InventoryScreen.itemToShowTooltip = nil
end

function InventoryScreen.toggle()
    InventoryScreen.isVisible = not InventoryScreen.isVisible
    if InventoryScreen.isVisible then
        InventoryScreen.equipmentSlotAreas = {}
        InventoryScreen.inventoryGridArea = {}
        InventoryScreen.itemToShowTooltip = nil
    else
        InventoryScreen.itemToShowTooltip = nil
    end
    return InventoryScreen.isVisible
end

--- Atualiza o estado interno da tela, incluindo a lógica de hover para tooltips.
---@param dt number Delta time.
---@param mx number Posição X do mouse.
---@param my number Posição Y do mouse.
---@param dragState table|nil Estado do drag-and-drop gerenciado pela cena pai (pode ser nil)
function InventoryScreen.update(dt, mx, my, dragState)
    if not InventoryScreen.isVisible then return end

    -- Armazena a posição do mouse para uso no draw (ex: tooltips, posição do fantasma)
    InventoryScreen.mouseX = mx
    InventoryScreen.mouseY = my
    InventoryScreen.itemToShowTooltip = nil -- Reseta a cada frame

    -- Só mostra tooltip se não estiver arrastando
    if not (dragState and dragState.isDragging) then
        ---@type HunterManager
        local hunterManager = ManagerRegistry:get("hunterManager")
        ---@type PlayerManager
        local playerManager = ManagerRegistry:get("playerManager")
        ---@type InventoryManager
        local inventoryManager = ManagerRegistry:get("inventoryManager")
        ---@type ArtefactManager
        local artefactManager = ManagerRegistry:get("artefactManager")

        -- 1. Checa hover em slots de equipamento
        local currentHunterId = playerManager:getCurrentHunterId()
        if currentHunterId and InventoryScreen.equipmentSlotAreas then
            local equippedItems = hunterManager:getEquippedItems(currentHunterId)
            if equippedItems then
                for slotId, area in pairs(InventoryScreen.equipmentSlotAreas) do
                    if mx >= area.x and mx < area.x + area.w and
                        my >= area.y and my < area.y + area.h then
                        if equippedItems[slotId] then
                            InventoryScreen.itemToShowTooltip = equippedItems[slotId]
                            break
                        end
                    end
                end
            end
        end

        -- 2. Checa hover na grade de Inventário (se não achou no equipamento)
        if not InventoryScreen.itemToShowTooltip and inventoryManager and
            InventoryScreen.inventoryGridArea and InventoryScreen.inventoryGridArea.w and
            InventoryScreen.inventoryGridArea.w > 0 then
            local invItemsList = inventoryManager:getInventoryGridItems()
            local gridDims = inventoryManager:getGridDimensions()
            local invRows = gridDims and gridDims.rows
            local invCols = gridDims and gridDims.cols

            if invItemsList and invRows and invCols then
                local hoveredItem = ItemGridUI.getItemInstanceAtCoords(mx, my,
                    invItemsList,
                    invRows, invCols,
                    InventoryScreen.inventoryGridArea.x, InventoryScreen.inventoryGridArea.y,
                    InventoryScreen.inventoryGridArea.w, InventoryScreen.inventoryGridArea.h)

                if hoveredItem then
                    InventoryScreen.itemToShowTooltip = hoveredItem
                end
            end
        end

        -- 3. Checa hover em artefatos
        if not InventoryScreen.itemToShowTooltip and artefactManager then
            local hoveredItem = ArtefactsDisplay.hoveredArtefact
            if hoveredItem then
                InventoryScreen.itemToShowTooltip = hoveredItem
            end
        end
    end

    -- Atualiza o gerenciador de tooltips com o item sob o mouse
    local itemForTooltip = InventoryScreen.itemToShowTooltip

    -- Usa o sistema unificado para todos os tipos de item (incluindo artefatos)
    ItemDetailsModalManager.update(dt, InventoryScreen.mouseX, InventoryScreen.mouseY, itemForTooltip)
end

---@param dragState table|nil Estado do drag-and-drop gerenciado pela cena pai (pode ser nil)
function InventoryScreen.draw(dragState)
    if not InventoryScreen.isVisible then return nil, nil end

    -- Obtém Managers do registro
    ---@type PlayerManager
    local playerManager = ManagerRegistry:get("playerManager")
    ---@type HunterManager
    local hunterManager = ManagerRegistry:get("hunterManager")
    ---@type ArchetypeManager
    local archetypeManager = ManagerRegistry:get("archetypeManager")
    ---@type InventoryManager
    local inventoryManager = ManagerRegistry:get("inventoryManager")
    ---@type ItemDataManager
    local itemDataManager = ManagerRegistry:get("itemDataManager")
    ---@type ArtefactManager
    local artefactManager = ManagerRegistry:get("artefactManager")

    local screenW, screenH = ResolutionUtils.getGameDimensions()

    -- Fundo semi-transparente
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    love.graphics.setColor(colors.white)

    -- Layout das colunas
    local colW = screenW / 3
    local statsX = 0
    local equipX = colW
    local inventoryX = colW * 2
    local padding = 10
    local topPadding = 100
    local innerColW = colW - padding * 2
    local innerColXOffset = padding
    local innerColY = topPadding + padding
    local innerColH = screenH - topPadding - padding

    -- Títulos
    local titleFont = fonts.title or love.graphics.getFont()
    local titleHeight = titleFont:getHeight()
    local titleMarginY = 15
    local titleY = innerColY
    local contentStartY = titleY + titleHeight + titleMarginY
    local contentInnerH = innerColH - (titleHeight + titleMarginY)
    love.graphics.setFont(titleFont)
    love.graphics.setColor(colors.text_highlight)
    love.graphics.printf("ATRIBUTOS", statsX + innerColXOffset, titleY, innerColW, "center")
    love.graphics.printf("EQUIPAMENTO", equipX + innerColXOffset, titleY, innerColW, "center")
    love.graphics.printf("INVENTÁRIO", inventoryX + innerColXOffset, titleY, innerColW, "center")
    love.graphics.setColor(colors.white)
    love.graphics.setFont(fonts.main or titleFont)

    -- Centralização Vertical do Conteúdo
    local contentMaxHeightFactor = 0.95
    local centeredContentH = contentInnerH * contentMaxHeightFactor
    local contentOffsetY = (contentInnerH - centeredContentH) / 2
    local centeredContentStartY = contentStartY + contentOffsetY

    -- Dados para as colunas
    local currentFinalStats = playerManager:getCurrentFinalStats()
    local currentHunterId = playerManager:getCurrentHunterId()
    local hunterArchetypeIds = currentHunterId and hunterManager:getArchetypeIds(currentHunterId)

    local statsColumnConfig = {
        currentHp = playerManager.stateController and playerManager.stateController.currentHealth,
        level = playerManager.stateController and playerManager.stateController:getCurrentLevel(),
        currentXp = playerManager.stateController and playerManager.stateController:getCurrentExperience(),
        xpToNextLevel = playerManager.stateController and playerManager.stateController.experienceToNextLevel,
        finalStats = currentFinalStats,
        archetypeIds = hunterArchetypeIds or {},
        mouseX = InventoryScreen.mouseX or 0,
        mouseY = InventoryScreen.mouseY or 0
    }

    -- Desenha Coluna de Stats
    local statsTooltipLines, statsTooltipX, statsTooltipY = HunterStatsColumn.draw(
        statsX + innerColXOffset,
        centeredContentStartY,
        innerColW,
        centeredContentH,
        statsColumnConfig
    )

    -- Desenha Coluna de Equipamento
    local tempAreas = HunterEquipmentColumn.draw(
        equipX + innerColXOffset,
        centeredContentStartY,
        innerColW,
        centeredContentH,
        currentHunterId
    )
    -- Atribui o resultado retornado (para uso local e retorno)
    InventoryScreen.equipmentSlotAreas = tempAreas

    -- Usa altura fixa mais razoável para o inventário
    local inventoryFixedHeight = 350 -- Altura fixa razoável para o inventário
    local artefactsHeight = 120      -- Altura da seção de artefatos
    local artefactsPadding = 15      -- Padding entre inventário e artefatos

    -- Desenha Coluna de Inventário (usando HunterInventoryColumn)
    InventoryScreen.inventoryGridArea = HunterInventoryColumn.draw(
        inventoryX + innerColXOffset,
        centeredContentStartY,
        innerColW,
        inventoryFixedHeight,
        inventoryManager, -- Passa o manager de inventário do gameplay
        itemDataManager
    )

    -- Desenha Display de Artefatos abaixo do inventário
    local artefactsY = centeredContentStartY + inventoryFixedHeight + artefactsPadding
    if artefactManager then
        ArtefactsDisplay:draw(
            inventoryX + innerColXOffset,
            artefactsY,
            innerColW,
            artefactsHeight,
            false,
            InventoryScreen.mouseX,
            InventoryScreen.mouseY
        )
    end


    if dragState and dragState.isDragging and dragState.draggedItem then
        -- Usa coordenadas virtuais já convertidas pelo gameplay_scene.update()
        -- (InventoryScreen.mouseX/Y já são virtuais!)
        local ghostX = InventoryScreen.mouseX - (dragState.draggedItemOffsetX or 0) -- Offset em coordenadas virtuais
        local ghostY = InventoryScreen.mouseY - (dragState.draggedItemOffsetY or 0) -- Offset em coordenadas virtuais
        elements.drawItemGhost(
            ghostX,
            ghostY,
            dragState.draggedItem,
            0.75,
            dragState.draggedItemIsRotated
        )

        if dragState.targetGridId and dragState.targetSlotCoords then
            local visualW = dragState.draggedItem.gridWidth or 1
            local visualH = dragState.draggedItem.gridHeight or 1
            if dragState.draggedItemIsRotated then
                visualW = dragState.draggedItem.gridHeight or 1
                visualH = dragState.draggedItem.gridWidth or 1
            end

            if dragState.targetGridId == "inventory" then
                local targetArea = InventoryScreen.inventoryGridArea -- Usa área local calculada neste frame
                local targetManager = inventoryManager
                if targetManager then
                    local gridDims = targetManager:getGridDimensions()
                    local targetRows = gridDims and gridDims.rows
                    local targetCols = gridDims and gridDims.cols
                    -- Usa targetCoords e isDropValid do dragState
                    if targetRows and targetCols and dragState.targetSlotCoords.row then
                        elements.drawDropIndicator(
                            targetArea.x, targetArea.y, targetArea.w, targetArea.h,
                            targetRows, targetCols,
                            dragState.targetSlotCoords.row, dragState.targetSlotCoords.col,
                            visualW, visualH,
                            dragState.isDropValid -- Usa validade do dragState
                        )
                    end
                end
            elseif dragState.targetGridId == "equipment" then
                local slotId = dragState.targetSlotCoords
                -- Usa áreas locais calculadas neste frame
                local area = InventoryScreen.equipmentSlotAreas and InventoryScreen.equipmentSlotAreas[slotId]
                if area then
                    -- Indicador temporário (usa isDropValid do dragState)
                    local r, g, b, a
                    if dragState.isDropValid then
                        local validColor = colors.placement_valid
                        r, g, b, a = validColor[1], validColor[2], validColor[3], 0.5 -- Usa alpha 0.5
                    else
                        local invalidColor = colors.placement_invalid
                        r, g, b, a = invalidColor[1], invalidColor[2], invalidColor[3], 0.5 -- Usa alpha 0.5
                    end
                    love.graphics.setColor(r, g, b, a)
                    love.graphics.rectangle('fill', area.x, area.y, area.w, area.h)
                    love.graphics.setColor(colors.white) -- Resetar cor
                end
            end
        end
    end

    -- Desenha o tooltip no final
    ItemDetailsModalManager.draw()

    -- Desenha o Tooltip de Stats (se houver)
    if statsTooltipLines and #statsTooltipLines > 0 then
        elements.drawTooltipBox(statsTooltipX, statsTooltipY, statsTooltipLines)
    end

    return InventoryScreen.equipmentSlotAreas, InventoryScreen.inventoryGridArea
end

-- Mantém as funções de input, mas a lógica interna precisará ser adaptada
-- para interagir com as áreas retornadas pelas colunas (equipmentSlotAreas, loadoutGridArea)
function InventoryScreen.keypressed(key)
    if not InventoryScreen.isVisible then return end

    -- <<< MODIFICADO: Retorna consumed, wantsToRotate >>>
    if key == "space" or key == "r" then -- Tecla para rotação
        print("[InventoryScreen] Rotação solicitada (Espaço/R)")
        return true, true                -- Consumiu, e quer rotacionar
    end

    -- Fecha inventário com ESC ou I (padrão)
    if key == "escape" or key == "tab" then
        InventoryScreen.hide()
        return true, false -- Consumiu, mas não quer rotacionar
    end

    return false, false -- Não consumiu
end

--- Verifica clique e retorna dados se um drag deve ser iniciado.
---@param x number Coordenada X do mouse
---@param y number Coordenada Y do mouse
---@param button number Botão do mouse (1 para esquerdo, 2 para direito)
---@return boolean consumed Se o clique foi consumido.
---@return table|nil dragStartData Se drag iniciado: { item, sourceGridId, sourceSlotId, offsetX, offsetY, isRotated }.
---@return table|nil useItemData Se uso de item solicitado: { item }.
function InventoryScreen.handleMousePress(x, y, button)
    if not InventoryScreen.isVisible then
        return false, nil, nil -- Ignora se não estiver visível
    end

    -- Managers necessários
    local hunterManager = ManagerRegistry:get("hunterManager")
    local inventoryManager = ManagerRegistry:get("inventoryManager")
    local itemDataManager = ManagerRegistry:get("itemDataManager")
    local playerManager = ManagerRegistry:get("playerManager")

    if not hunterManager or not inventoryManager or not itemDataManager or not playerManager then
        print("ERRO [InventoryScreen.handleMousePress]: Managers necessários não encontrados!")
        return false, nil, nil
    end

    local currentHunterId = playerManager:getCurrentHunterId()
    if not currentHunterId then
        print("AVISO [InventoryScreen.handleMousePress]: currentHunterId não encontrado.")
        return false, nil, nil
    end

    -- Lógica para Botão Esquerdo (Drag and Drop)
    if button == 1 then
        -- 1. Verifica clique em Slots de Equipamento
        local equippedItems = hunterManager:getEquippedItems(currentHunterId)
        for slotId, area in pairs(InventoryScreen.equipmentSlotAreas or {}) do
            if area and x >= area.x and x < area.x + area.w and y >= area.y and y < area.y + area.h then
                local itemInstance = equippedItems and equippedItems[slotId]
                if itemInstance then
                    local dragData = {
                        item = itemInstance,
                        sourceGridId = "equipment",
                        sourceSlotId = slotId,
                        offsetX = x - area.x,
                        offsetY = y - area.y,
                        isRotated = false
                    }
                    print(string.format("[InventoryScreen.handleMousePress] Drag iniciado do Equip Slot '%s'", slotId))
                    return true, dragData, nil -- Consumiu, iniciou drag, sem uso de item
                else
                    return true, nil, nil      -- Consumiu clique em slot vazio
                end
            end
        end

        -- 3. Verifica clique na Grade de Inventário
        local area = InventoryScreen.inventoryGridArea
        if area and x >= area.x and x < area.x + area.w and y >= area.y and y < area.y + area.h then
            local ItemGridUI = require("src.ui.item_grid_ui")
            local gridDims = inventoryManager:getGridDimensions()
            local invRows = gridDims and gridDims.rows
            local invCols = gridDims and gridDims.cols

            if invRows and invCols then
                local coords = ItemGridUI.getSlotCoordsAtMouse(x, y, invRows, invCols, area.x, area.y, area.w, area.h)
                if coords then
                    local itemInstance = inventoryManager:getItemAt(coords.row, coords.col)
                    if itemInstance then
                        local itemScreenX, itemScreenY = ItemGridUI.getItemScreenPos(coords.row, coords.col, invRows,
                            invCols,
                            area.x, area.y, area.w, area.h)
                        if itemScreenX and itemScreenY then
                            local dragData = {
                                item = itemInstance,
                                sourceGridId = "inventory",
                                sourceSlotId = nil,
                                offsetX = x - itemScreenX,
                                offsetY = y - itemScreenY,
                                isRotated = itemInstance.isRotated or false
                            }
                            print(string.format("[InventoryScreen.handleMousePress] Drag iniciado do Inventário [%d,%d]",
                                coords.row,
                                coords.col))
                            return true, dragData, nil -- Consumiu, iniciou drag, sem uso de item
                        else
                            return true, nil, nil      -- Consumiu, mas erro interno
                        end
                    else
                        return true, nil, nil -- Consumiu clique em célula vazia
                    end
                else
                    return true, nil, nil -- Consumiu clique fora das células
                end
            else
                return true, nil, nil -- Consumiu, mas erro interno (dimensões inválidas)
            end
        end
        return false, nil, nil -- Não clicou em nada relevante para botão esquerdo

        -- Lógica para Botão Direito (Uso de Item)
    elseif button == 2 then
        local area = InventoryScreen.inventoryGridArea
        if area and x >= area.x and x < area.x + area.w and y >= area.y and y < area.y + area.h then
            local ItemGridUI = require("src.ui.item_grid_ui")
            local gridDims = inventoryManager:getGridDimensions()
            local invRows = gridDims and gridDims.rows
            local invCols = gridDims and gridDims.cols

            if invRows and invCols then
                local coords = ItemGridUI.getSlotCoordsAtMouse(x, y, invRows, invCols, area.x, area.y, area.w, area.h)
                if coords then
                    local itemInstance = inventoryManager:getItemAt(coords.row, coords.col)
                    if itemInstance then
                        -- Verifica se o item é usável (tem useDetails)
                        local baseData = itemDataManager:getBaseItemData(itemInstance.itemBaseId)
                        if baseData and baseData.useDetails then
                            print(string.format(
                                "[InventoryScreen.handleMousePress] Uso solicitado para item \'%s\' (ID: %s) do Inventário [%d,%d]",
                                baseData.name, itemInstance.instanceId, coords.row, coords.col))
                            return true, nil, { item = itemInstance } -- Consumiu, sem drag, dados para uso
                        else
                            print(string.format("[InventoryScreen.handleMousePress] Item \'%s\' (ID: %s) não é usável.",
                                (baseData and baseData.name) or itemInstance.itemBaseId, itemInstance.instanceId))
                            return true, nil, nil -- Consumiu, mas item não usável
                        end
                    else
                        -- Clicou em célula vazia com botão direito, não faz nada
                        return true, nil, nil
                    end
                else
                    -- Clicou fora das células válidas com botão direito
                    return true, nil, nil
                end
            else
                -- Dimensões do inventário inválidas
                return true, nil, nil
            end
        end
        -- Se clicou com botão direito fora da grade do inventário, considera não consumido para esta tela
        return false, nil, nil
    end

    -- Se não for botão 1 ou 2, ou se nada foi interagido
    return false, nil, nil
end

--- Finaliza uma operação de drag-and-drop válida.
--- Recebe o estado completo do drag gerenciado pela cena.
--- Executa a ação necessária (equipar, desequipar, mover).
--- NÃO reseta o estado de drag (a cena faz isso).
---@param dragState table Estado completo do drag gerenciado pela cena.
---@return boolean success Se a operação foi bem-sucedida.
function InventoryScreen.handleMouseRelease(dragState)
    -- Captura estado do parâmetro dragState
    local draggedItem = dragState.draggedItem

    local sourceGrid = dragState.sourceGridId
    local sourceSlot = dragState.sourceSlotId
    local targetGrid = dragState.targetGridId
    local targetCoords = dragState.targetSlotCoords
    local isTargetValid = dragState.isDropValid -- Confia na validação da cena
    local itemWasRotated = dragState.draggedItemIsRotated

    -- Verifica se temos todos os dados necessários do dragState
    if not draggedItem or not sourceGrid or not targetGrid or not targetCoords then
        print("ERRO [handleMouseRelease]: dragState incompleto recebido!",
            "Item:", draggedItem ~= nil, "Source:", sourceGrid, "Target:", targetGrid, "Coords:", targetCoords ~= nil)
        return false
    end

    print(string.format(
        "[handleMouseRelease] Processing Drop: Source=%s (%s), Target=%s (%s), Valid=%s, Item=%s, Rotated=%s",
        sourceGrid or "nil", sourceSlot or "grid", targetGrid or "nil",
        (type(targetCoords) == "string" and targetCoords) or
        (type(targetCoords) == "table" and string.format("[%d,%d]", targetCoords.row, targetCoords.col) or "nil"),
        tostring(isTargetValid), draggedItem.itemBaseId, tostring(draggedItem.instanceId), tostring(itemWasRotated)))

    -- Se a cena passou isDropValid=false (ex: tipo incompatível, sem espaço), não faz nada.
    -- A cena é responsável por resetar o estado de drag mesmo assim.
    if not isTargetValid then
        print("[handleMouseRelease] Drop inválido (isDropValid=false). Nenhuma ação tomada.")
        return false -- Indica falha na operação de drop
    end

    -- Managers necessários
    local hunterManager = ManagerRegistry:get("hunterManager")
    local inventoryManager = ManagerRegistry:get("inventoryManager")
    local playerManager = ManagerRegistry:get("playerManager")

    if not hunterManager or not inventoryManager or not playerManager then
        print("ERRO [handleMouseRelease]: Managers necessários não encontrados!")
        return false
    end

    local currentHunterId = playerManager:getCurrentHunterId()
    if not currentHunterId then
        print("ERRO [handleMouseRelease]: currentHunterId não encontrado.")
        return false
    end

    local success = false -- Flag para o resultado da operação

    -- Lógica de Ação baseada em Origem e Destino
    if targetGrid == "equipment" then
        local targetSlotId = targetCoords
        if type(targetSlotId) ~= "string" then
            print("ERRO [handleMouseRelease]: Target é equipment, mas targetCoords não é string!", type(targetCoords))
            return false
        end

        if sourceGrid == "inventory" then
            -- Ação: Equipar item do inventário
            print(string.format("-> Ação: Equipar item %s (ID: %s) do Inventário no Slot %s", draggedItem.itemBaseId,
                draggedItem.instanceId, targetSlotId))

            -- <<< CORRIGIDO: Usa hunterManager:equipItem e trata remoção/item antigo manualmente >>>
            -- 1. Tenta equipar o item
            local equipped, oldItemInstance = hunterManager:equipItem(draggedItem, targetSlotId)

            if equipped then
                print(string.format("   SUCESSO: hunterManager:equipItem equipou %s (ID: %s)", draggedItem.itemBaseId,
                    draggedItem.instanceId))
                -- 2. Remove o item equipado do InventoryManager
                local removed = inventoryManager:removeItemInstance(draggedItem.instanceId)
                if not removed then
                    print(string.format("   ERRO GRAVE: Item %s equipado, mas falha ao remover do inventário!",
                        draggedItem.instanceId))
                    -- Tentar desequipar como fallback? Ou deixar como está? Por ora, apenas log.
                else
                    print(string.format("   Item %s removido do inventário.", draggedItem.instanceId))
                end

                -- 3. Se havia um item antigo no slot, tenta adicioná-lo ao InventoryManager
                if oldItemInstance then
                    print(string.format(
                        "   -> Item antigo %s (ID: %s) estava no slot. Tentando adicionar ao inventário...",
                        oldItemInstance.itemBaseId, oldItemInstance.instanceId))
                    -- Tenta adicionar em qualquer lugar, retorna quantidade adicionada (0 se falhar)
                    local addedQuantity = inventoryManager:addItem(oldItemInstance.itemBaseId,
                        oldItemInstance.quantity or 1)

                    if addedQuantity > 0 then
                        print(string.format("   Item antigo %s adicionado de volta ao inventário.",
                            oldItemInstance.itemBaseId))
                    else
                        print(string.format(
                            "   AVISO: Falha ao adicionar item antigo %s de volta ao inventário (sem espaço?). Dropando no chão...",
                            oldItemInstance.itemBaseId))

                        -- <<< ADICIONADO: Lógica para dropar o item no chão >>>
                        local dropManager = ManagerRegistry:get("dropManager")
                        local playerManager = ManagerRegistry:get("playerManager")

                        if dropManager and playerManager and playerManager.player and playerManager.player.position then
                            local dropConfig = {
                                type = "item",
                                itemId = oldItemInstance.itemBaseId,
                                quantity = oldItemInstance.quantity or 1
                            }
                            -- Cria o drop perto do jogador
                            local dropPos = {
                                x = playerManager.player.position.x + love.math.random(-15, 15),
                                y =
                                    playerManager.player.position.y + love.math.random(-15, 15)
                            }
                            dropManager:createDrop(dropConfig, dropPos)
                            print(string.format("   Item antigo %s dropado em [%.1f, %.1f].", oldItemInstance.itemBaseId,
                                dropPos.x, dropPos.y))
                        else
                            print(
                                "   ERRO GRAVE: DropManager ou PlayerManager indisponível para dropar item antigo! Item perdido.")
                        end
                    end
                end
                success = true -- Marca a operação geral como sucesso
            else
                print(string.format("   FALHA: hunterManager:equipItem não conseguiu equipar %s.", draggedItem
                    .itemBaseId))
                success = false
            end
        elseif sourceGrid == "equipment" then
            -- Ação: Mover item entre slots de equipamento (swap)
            if sourceSlot == targetSlotId then
                print("-> Ação: Mover Equipamento para o mesmo slot. Nenhuma ação.")
                success = true
            else
                print(string.format("-> Ação: Mover item %s do Slot %s para Slot %s", draggedItem.itemBaseId, sourceSlot,
                    targetSlotId))
                success = hunterManager:moveEquippedItem(currentHunterId, sourceSlot, targetSlotId)
                if success then
                    print("   SUCESSO: Item movido/trocado entre slots.")
                else
                    print(
                        "   FALHA: Não foi possível mover o item entre slots.")
                end
            end
        else
            print("ERRO [handleMouseRelease]: Origem inválida ('" ..
                tostring(sourceGrid) .. "') para destino 'equipment'")
            success = false
        end
    elseif targetGrid == "inventory" then
        if type(targetCoords) ~= "table" or not targetCoords.row then
            print("ERRO [handleMouseRelease]: Target é inventory, mas targetCoords não é tabela válida!",
                type(targetCoords))
            return false
        end
        local targetRow, targetCol = targetCoords.row, targetCoords.col

        if sourceGrid == "equipment" then
            -- Ação: Desequipar item para o inventário
            print(string.format("-> Ação: Desequipar item do Slot %s para Inv [%d,%d], Rotated: %s", sourceSlot,
                targetRow, targetCol, tostring(itemWasRotated)))

            -- 1. Tenta desequipar do HunterManager
            --    NOTA: Precisamos garantir que unequipItem receba os parâmetros corretos.
            --    Verificando a definição, parece que só precisa do slotId se usar o activeHunterId interno.
            --    Se precisar do hunterId, a chamada seria: hunterManager:unequipItem(currentHunterId, sourceSlot)
            --    Assumindo que usa activeHunterId implicitamente ou foi adaptado para receber hunterId:
            local unequippedItem = hunterManager:unequipItem(sourceSlot)

            if unequippedItem then
                print(string.format("   Item %s (ID: %s) desequipado com sucesso.", unequippedItem.itemBaseId,
                    unequippedItem.instanceId))
                -- 2. Tenta adicionar ao InventoryManager na posição exata
                success = inventoryManager:addItemAt(unequippedItem, targetRow, targetCol, itemWasRotated)
                if success then
                    print("   SUCESSO: Item adicionado ao inventário em [%d,%d].", targetRow, targetCol)
                else
                    print(string.format(
                        "   FALHA: Não foi possível adicionar item desequipado ao inventário em [%d,%d] (sem espaço?). Tentando adicionar em qualquer lugar...",
                        targetRow, targetCol))
                    -- Tenta adicionar em qualquer lugar como fallback
                    local addedBackAnywhere = inventoryManager:addItem(unequippedItem) -- addItem geralmente tenta achar espaço
                    if addedBackAnywhere then
                        print("      AVISO: Item desequipado adicionado em outra posição do inventário.")
                        -- Consideramos a operação de drop original como falha, pois não foi na posição desejada.
                        success = false
                    else
                        print(
                            "      ERRO GRAVE: Falha ao adicionar item desequipado de volta ao inventário! Item pode estar perdido.")
                        -- Tentar re-equipar como último recurso?
                        -- Assumindo que equipItem existe e aceita hunterId e instância
                        local reequipped = hunterManager:equipItem(currentHunterId, unequippedItem, sourceSlot)
                        if reequipped then
                            print("      AVISO: Item perdido no inventário foi re-equipado no slot original '%s'.",
                                sourceSlot)
                        else
                            print(
                                "      ERRO GRAVÍSSIMO: Falha ao re-equipar item '%s' no slot '%s'! Item pode estar perdido permanentemente.",
                                unequippedItem.itemBaseId, sourceSlot)
                        end
                        success = false
                    end
                end
            else
                print(string.format(
                    "   FALHA: Não foi possível desequipar o item do slot '%s' (hunterManager:unequipItem falhou?).",
                    sourceSlot))
                success = false -- Falha ao desequipar
            end
        elseif sourceGrid == "inventory" then
            -- Ação: Mover item dentro do inventário
            print(string.format("-> Ação: Mover item %s (ID: %s) dentro do Inventário para [%d,%d], Rotated: %s",
                draggedItem.itemBaseId, draggedItem.instanceId, targetRow, targetCol, tostring(itemWasRotated)))
            local removed = inventoryManager:removeItemInstance(draggedItem.instanceId)
            if removed then
                local placed = inventoryManager:addItemAt(draggedItem, targetRow, targetCol, itemWasRotated)
                if placed then
                    print("   SUCESSO: Item movido dentro do inventário.")
                    success = true
                else
                    print(string.format(
                        "   FALHA: Não foi possível colocar o item na nova posição [%d,%d]. Tentando devolver...",
                        targetRow,
                        targetCol))
                    local addedBack = inventoryManager:addItem(draggedItem) -- Tenta devolver sem pos específica
                    if addedBack then
                        print("      AVISO: Item devolvido ao inventário em outra posição.")
                    else
                        print(
                            "      ERRO GRAVE: Falha ao colocar o item de volta! Item perdido?")
                    end
                    success = false -- Movimentação original falhou
                end
            else
                print(string.format("   FALHA: Não foi possível remover o item (ID: %s) da origem para mover.",
                    draggedItem.instanceId))
                success = false
            end
        else
            print("ERRO [handleMouseRelease]: Origem inválida ('" ..
                tostring(sourceGrid) .. "') para destino 'inventory'")
            success = false
        end
    else
        print("ERRO [handleMouseRelease]: targetGrid inválido:", targetGrid)
        success = false
    end

    -- Recalcula stats SE a operação teve sucesso
    if success then
        print("[handleMouseRelease] Ação concluída com sucesso. Recalculando stats...")
        -- playerManager:recalculateStats()
    else
        print("[handleMouseRelease] Ação falhou ou não realizada. Stats não recalculados.")
    end

    return success -- Retorna se a operação principal foi bem-sucedida
end

return InventoryScreen
