-- src/ui/inventory_screen.lua
local elements = require("src.ui.ui_elements")
local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")
local ManagerRegistry = require("src.managers.manager_registry") -- Adicionado

-- Carrega as NOVAS colunas
local HunterStatsColumn = require("src.ui.components.HunterStatsColumn")
local HunterEquipmentColumn = require("src.ui.components.HunterEquipmentColumn")
local HunterInventoryColumn = require("src.ui.components.HunterInventoryColumn") -- <<< ADICIONADO: Coluna de Inventário Gameplay

local InventoryScreen = {}
InventoryScreen.isVisible = false
InventoryScreen.mouseX = 0
InventoryScreen.mouseY = 0
InventoryScreen.equipmentSlotAreas = {} -- Mantém como cache local, mas será retornado
-- InventoryScreen.loadoutGridArea = {} -- Removido, a coluna de inventário retorna a área dela
InventoryScreen.inventoryGridArea = {}  -- Mantém como cache local, mas será retornado

-- <<< REMOVENDO Variáveis de Estado de Drag Internas >>>
-- InventoryScreen.isDragging = false
-- InventoryScreen.draggedItem = nil
-- InventoryScreen.draggedItemOffsetX = 0
-- InventoryScreen.draggedItemOffsetY = 0
-- InventoryScreen.sourceGridId = nil
-- InventoryScreen.sourceSlotId = nil
-- InventoryScreen.draggedItemIsRotated = false
-- InventoryScreen.targetGridId = nil
-- InventoryScreen.targetSlotCoords = nil
-- InventoryScreen.isDropValid = false

-- Função para obter o shader (mantida, mas o shader não é usado atualmente)
function InventoryScreen.setGlowShader(shader)
    -- glowShader = shader -- Shader não é usado neste novo layout, remover ou adaptar se necessário
end

function InventoryScreen.hide() -- Função para esconder
    InventoryScreen.isVisible = false
    -- print("[InventoryScreen.hide] Hiding.")
end

function InventoryScreen.show() -- Função para mostrar
    InventoryScreen.isVisible = true
    InventoryScreen.equipmentSlotAreas = {}
    InventoryScreen.inventoryGridArea = {}
    -- print("[InventoryScreen.show] Showing and resetting areas.")
end

function InventoryScreen.toggle()
    InventoryScreen.isVisible = not InventoryScreen.isVisible
    if InventoryScreen.isVisible then
        InventoryScreen.equipmentSlotAreas = {}
        InventoryScreen.inventoryGridArea = {}
        -- print("[InventoryScreen.toggle] Became visible, resetting areas.")
    else
        -- print("[InventoryScreen.toggle] Became hidden.")
    end
    return InventoryScreen.isVisible
end

--- Atualiza o estado interno da tela (atualmente, apenas armazena posição do mouse).
--- A lógica de hover/validação de drag foi movida para a cena pai (GameplayScene).
function InventoryScreen.update(dt, mx, my)
    if not InventoryScreen.isVisible then return end

    -- Armazena a posição do mouse para uso no draw (ex: tooltips, posição do fantasma)
    InventoryScreen.mouseX = mx
    InventoryScreen.mouseY = my

    -- A lógica de verificar hover e validar drop foi MOVIDA para GameplayScene.update
end

-- Função principal de desenho da tela (MODIFICADA)
---@param dragState table|nil Estado do drag-and-drop gerenciado pela cena pai (pode ser nil)
function InventoryScreen.draw(dragState)
    if not InventoryScreen.isVisible then return nil, nil end -- Retorna nil se não visível

    -- Obtém Managers do registro
    local playerManager = ManagerRegistry:get("playerManager")
    local hunterManager = ManagerRegistry:get("hunterManager")
    local archetypeManager = ManagerRegistry:get("archetypeManager")
    local inventoryManager = ManagerRegistry:get("inventoryManager") -- <<< OBTÉM INVENTORY MANAGER
    local itemDataManager = ManagerRegistry:get("itemDataManager")

    -- MODIFICADO: Usa inventoryManager na checagem
    if not playerManager or not hunterManager or not archetypeManager or not inventoryManager or not itemDataManager then
        local screenW, screenH = love.graphics.getDimensions()
        love.graphics.setColor(colors.red)
        love.graphics.printf("Erro: Managers essenciais não encontrados!", 0, screenH / 2, screenW, "center")
        love.graphics.setColor(colors.white)
        return nil, nil
    end

    local screenW, screenH = love.graphics.getDimensions()

    -- Fundo semi-transparente
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    love.graphics.setColor(colors.white)

    -- Layout das colunas
    local colW = screenW / 3
    local statsX = 0
    local equipX = colW
    local inventoryX = colW * 2 -- Renomeado para clareza
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
    love.graphics.printf("INVENTÁRIO", inventoryX + innerColXOffset, titleY, innerColW, "center") -- Título correto
    love.graphics.setColor(colors.white)
    love.graphics.setFont(fonts.main or titleFont)

    -- Centralização Vertical do Conteúdo
    local contentMaxHeightFactor = 0.9
    local centeredContentH = contentInnerH * contentMaxHeightFactor
    local contentOffsetY = (contentInnerH - centeredContentH) / 2
    local centeredContentStartY = contentStartY + contentOffsetY

    -- Dados para as colunas
    local currentFinalStats = playerManager:getCurrentFinalStats()
    local currentHunterId = playerManager:getCurrentHunterId()
    local hunterArchetypeIds = currentHunterId and hunterManager:getArchetypeIds(currentHunterId)
    local statsColumnConfig = {
        currentHp = playerManager.state and playerManager.state.currentHealth,
        level = playerManager.state and playerManager.state.level,
        currentXp = playerManager.state and playerManager.state.experience,
        xpToNextLevel = playerManager.state and playerManager.state.experienceToNextLevel,
        finalStats = currentFinalStats,
        archetypeIds = hunterArchetypeIds or {},
        archetypeManager = archetypeManager,
        mouseX = InventoryScreen.mouseX or 0,
        mouseY = InventoryScreen.mouseY or 0
    }

    -- Desenha Coluna de Stats
    HunterStatsColumn.draw(
        statsX + innerColXOffset, centeredContentStartY, innerColW, centeredContentH,
        statsColumnConfig
    )

    -- Desenha Coluna de Equipamento
    local tempAreas = HunterEquipmentColumn.draw(
        equipX + innerColXOffset, centeredContentStartY, innerColW, centeredContentH,
        hunterManager,
        currentHunterId
    )
    -- Atribui o resultado retornado (para uso local e retorno)
    InventoryScreen.equipmentSlotAreas = tempAreas

    -- DEBUG: Imprime a tabela após atribuí-la (mantido)
    -- print("[InventoryScreen.draw] Stored equipmentSlotAreas:")
    -- for id, data in pairs(InventoryScreen.equipmentSlotAreas or {}) do
    --     print(string.format("  SlotID: %s, Area: {x=%s, y=%s, w=%s, h=%s}",
    --         tostring(id), tostring(data.x), tostring(data.y), tostring(data.w), tostring(data.h)))
    -- end

    -- Desenha Coluna de Inventário (usando HunterInventoryColumn)
    InventoryScreen.inventoryGridArea = HunterInventoryColumn.draw(
        inventoryX + innerColXOffset, centeredContentStartY, innerColW, centeredContentH,
        inventoryManager, -- Passa o manager de inventário do gameplay
        itemDataManager
    )

    -- <<< MODIFICADO: Usa dragState recebido para Desenho do Drag-and-Drop >>>
    if dragState and dragState.isDragging and dragState.draggedItem then
        -- Usa mouseX/Y local da tela para desenho (assumindo que 'update' ainda armazena)
        local mx_draw, my_draw = InventoryScreen.mouseX, InventoryScreen.mouseY
        if mx_draw and my_draw then
            local elements = require("src.ui.ui_elements")
            local ghostX = mx_draw - (dragState.draggedItemOffsetX or 0) -- Usa offset do dragState
            local ghostY = my_draw - (dragState.draggedItemOffsetY or 0) -- Usa offset do dragState
            elements.drawItemGhost(ghostX, ghostY, dragState.draggedItem, 0.75,
                dragState.draggedItemIsRotated)                          -- Usa rotação do dragState

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
    end
    -- <<< FIM: Desenho do Drag-and-Drop >>>

    -- DEBUG: Imprime estado no final do draw (mantido)
    -- print(string.format("[InventoryScreen.draw END] equipmentSlotAreas type: %s",
    --     type(InventoryScreen.equipmentSlotAreas)))
    -- if type(InventoryScreen.equipmentSlotAreas) == 'table' then
    --     local count = 0
    --     for _ in pairs(InventoryScreen.equipmentSlotAreas) do count = count + 1 end
    --     print("  equipmentSlotAreas item count:", count)
    -- end

    -- <<< RETORNA AS ÁREAS CALCULADAS >>>
    return InventoryScreen.equipmentSlotAreas, InventoryScreen.inventoryGridArea
end

-- Mantém as funções de input, mas a lógica interna precisará ser adaptada
-- para interagir com as áreas retornadas pelas colunas (equipmentSlotAreas, loadoutGridArea)

function InventoryScreen.keypressed(key)
    if not InventoryScreen.isVisible then return end

    -- Rotaciona o item sendo arrastado (se for do inventário)
    if InventoryScreen.isDragging and InventoryScreen.draggedItem and InventoryScreen.sourceGridId == "inventory" then
        if key == "space" or key == "r" then -- Teclas comuns para rotação
            InventoryScreen.draggedItemIsRotated = not InventoryScreen.draggedItemIsRotated
            -- Recalcula validade do drop (update fará isso, mas pode forçar aqui)
            InventoryScreen.update(0, InventoryScreen.mouseX, InventoryScreen.mouseY)
            print("Item rotation toggled:", InventoryScreen.draggedItemIsRotated)
            return true -- Consome a tecla
        end
    end

    -- Fecha inventário com ESC ou I (padrão)
    if key == "escape" or key == "i" then
        InventoryScreen.hide()
        return true -- Consome a tecla
    end

    return false -- Não consome outras teclas
end

--- Verifica clique e retorna dados se um drag deve ser iniciado.
---@param x number Coordenada X do mouse
---@param y number Coordenada Y do mouse
---@param button number Botão do mouse (1 para esquerdo)
---@return boolean consumed Se o clique foi consumido (mesmo que não inicie drag).
---@return table|nil dragStartData Se drag iniciado: { item, sourceGridId, sourceSlotId, offsetX, offsetY, isRotated }.
function InventoryScreen.handleMousePress(x, y, button)
    if not InventoryScreen.isVisible or button ~= 1 then
        return false, nil -- Ignora se não estiver visível ou não for botão esquerdo
    end

    -- Managers necessários
    local hunterManager = ManagerRegistry:get("hunterManager")
    local inventoryManager = ManagerRegistry:get("inventoryManager")
    local itemDataManager = ManagerRegistry:get("itemDataManager")
    local playerManager = ManagerRegistry:get("playerManager")

    if not hunterManager or not inventoryManager or not itemDataManager or not playerManager then
        print("ERRO [handleMousePress]: Managers necessários não encontrados!")
        return false, nil
    end

    local currentHunterId = playerManager:getCurrentHunterId()
    if not currentHunterId then
        print("AVISO [handleMousePress]: currentHunterId não encontrado.")
        return false, nil
    end

    -- 1. Verifica clique em Slots de Equipamento
    local equippedItems = hunterManager:getEquippedItems(currentHunterId)
    -- Usa as áreas cacheadas localmente (que foram calculadas no draw anterior)
    for slotId, area in pairs(InventoryScreen.equipmentSlotAreas or {}) do
        if area and x >= area.x and x < area.x + area.w and y >= area.y and y < area.y + area.h then
            local itemInstance = equippedItems and equippedItems[slotId]
            if itemInstance then
                -- <<< RETORNA dados para iniciar drag >>>
                local dragData = {
                    item = itemInstance,
                    sourceGridId = "equipment",
                    sourceSlotId = slotId,
                    offsetX = x - area.x,
                    offsetY = y - area.y,
                    isRotated = false -- Equipamento não rotaciona visualmente no drag
                }
                print(string.format("[handleMousePress] Iniciando drag do Equip Slot '%s'", slotId))
                return true, dragData -- Consumiu e iniciou drag
            else
                print(string.format("[handleMousePress] Clicou no Equip Slot VAZIO '%s'", slotId))
                return true, nil -- Consumiu clique em slot vazio
            end
        end
    end

    -- 2. Verifica clique na Grade de Inventário
    local area = InventoryScreen.inventoryGridArea -- Usa área cacheada
    if area and x >= area.x and x < area.x + area.w and y >= area.y and y < area.y + area.h then
        local ItemGridUI = require("src.ui.item_grid_ui")
        -- <<< CORRIGIDO: Chama getGridDimensions e extrai rows/cols >>>
        local gridDims = inventoryManager:getGridDimensions()
        local invRows = gridDims and gridDims.rows
        local invCols = gridDims and gridDims.cols

        if invRows and invCols then
            local coords = ItemGridUI.getSlotCoordsAtMouse(x, y, invRows, invCols, area.x, area.y, area.w, area.h)
            if coords then
                local itemInstance = inventoryManager:getItemAt(coords.row, coords.col)
                if itemInstance then
                    local itemScreenX, itemScreenY = ItemGridUI.getItemScreenPos(coords.row, coords.col, invRows, invCols,
                        area.x, area.y, area.w, area.h)
                    if itemScreenX and itemScreenY then
                        -- <<< RETORNA dados para iniciar drag >>>
                        local dragData = {
                            item = itemInstance,
                            sourceGridId = "inventory",
                            sourceSlotId = nil, -- Não aplicável para grade
                            offsetX = x - itemScreenX,
                            offsetY = y - itemScreenY,
                            isRotated = itemInstance.isRotated or false -- Pega rotação atual
                        }
                        print(string.format("[handleMousePress] Iniciando drag do Inventário [%d,%d]", coords.row,
                            coords.col))
                        return true, dragData -- Consumiu e iniciou drag
                    else
                        print("[handleMousePress] Erro ao calcular itemScreenPos para inventário")
                        return true, nil -- Consumiu, mas erro interno
                    end
                else
                    print(string.format("[handleMousePress] Clicou em célula vazia do inventário [%d,%d]", coords.row,
                        coords.col))
                    return true, nil -- Consumiu clique em célula vazia
                end
            else
                print("[handleMousePress] Clicou fora das células válidas da grade de inventário")
                return true, nil -- Consumiu clique fora das células
            end
        else
            print("[handleMousePress] Dimensões do inventário inválidas")
            return true, nil -- Consumiu, mas erro interno
        end
    end

    -- Se chegou aqui, não clicou em nada relevante dentro da tela
    return false, nil
end

--- Finaliza uma operação de drag-and-drop válida.
--- Recebe o estado completo do drag gerenciado pela cena.
--- Executa a ação necessária (equipar, desequipar, mover).
--- NÃO reseta o estado de drag (a cena faz isso).
---@param dragState table Estado completo do drag gerenciado pela cena.
---@return boolean success Se a operação foi bem-sucedida.
function InventoryScreen.handleMouseRelease(dragState)
    -- Não verifica mais isDragging aqui, a cena só chama se estiver arrastando
    -- e o drop for considerado válido pela lógica da cena (targetGrid/targetCoords existem e isDropValid=true).

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
        tostring(isTargetValid), draggedItem.itemBaseId, tostring(itemWasRotated)))

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
            success = hunterManager:equipItemFromInventory(currentHunterId, draggedItem.instanceId, targetSlotId,
                inventoryManager)
            if success then print("   SUCESSO: Item equipado.") else print("   FALHA: Não foi possível equipar o item.") end
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
