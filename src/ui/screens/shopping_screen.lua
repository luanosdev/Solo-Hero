local fonts = require("src.ui.fonts")
local elements = require("src.ui.ui_elements")
local colors = require("src.ui.colors")
local ItemGridUI = require("src.ui.item_grid_ui")
local ShopColumn = require("src.ui.components.ShopColumn")
local HunterLoadoutColumn = require("src.ui.components.HunterLoadoutColumn")
local ItemDetailsModalManager = require("src.managers.item_details_modal_manager")
local ArtefactsDisplay = require("src.ui.components.ArtefactsDisplay")
local ManagerRegistry = require("src.managers.manager_registry")

---@class ShoppingScreen
---@field itemDataManager ItemDataManager
---@field shopManager ShopManager
---@field lobbyStorageManager LobbyStorageManager
---@field loadoutManager LoadoutManager
---@field patrimonyManager PatrimonyManager|nil
---@field storageGridArea table
---@field loadoutGridArea table
---@field shopArea table
---@field artefactsArea table
---@field itemToShowTooltip table|nil
local ShoppingScreen = {}
ShoppingScreen.__index = ShoppingScreen

--- Cria uma nova instância da tela de Shopping
---@param itemDataManager ItemDataManager
---@param shopManager ShopManager
---@param lobbyStorageManager LobbyStorageManager
---@param loadoutManager LoadoutManager
---@param patrimonyManager PatrimonyManager|nil
---@return ShoppingScreen
function ShoppingScreen:new(itemDataManager, shopManager, lobbyStorageManager, loadoutManager, patrimonyManager)
    local instance = setmetatable({}, ShoppingScreen)
    instance.itemDataManager = itemDataManager
    instance.shopManager = shopManager
    instance.lobbyStorageManager = lobbyStorageManager
    instance.loadoutManager = loadoutManager
    instance.patrimonyManager = patrimonyManager
    -- Inicializa áreas com valores padrão para evitar erros
    instance.shopArea = { x = 0, y = 0, w = 0, h = 0 }
    instance.storageGridArea = { x = 0, y = 0, w = 0, h = 0 }
    instance.loadoutGridArea = { x = 0, y = 0, w = 0, h = 0 }
    instance.artefactsArea = { x = 0, y = 0, w = 0, h = 0 }
    instance.itemToShowTooltip = nil

    return instance
end

--- Atualiza a tela de Shopping
---@param self ShoppingScreen
---@param dt number Delta time
---@param mx number Posição X global do mouse
---@param my number Posição Y global do mouse
---@param dragState table Estado do drag-and-drop da cena pai
function ShoppingScreen:update(dt, mx, my, dragState)
    self.itemToShowTooltip = nil

    -- Atualiza o ShopManager (para timer da loja, etc.)
    if self.shopManager then
        self.shopManager:update(dt)
    end

    if not (dragState and dragState.isDragging) then
        -- 0. Checa hover na loja (primeiro para prioridade)
        if self.shopManager and self.shopArea then
            local hoveredShopItem = ShopColumn.getItemForTooltip(mx, my, self.shopArea, self.shopManager)
            if hoveredShopItem and hoveredShopItem.itemId then
                local baseData = self.itemDataManager:getBaseItemData(hoveredShopItem.itemId)
                if baseData then
                    -- Cria um item temporário para o modal usando os dados base
                    local tempItem = {
                        itemBaseId = hoveredShopItem.itemId,
                        name = baseData.name,
                        description = baseData.description,
                        rarity = baseData.rarity,
                        icon = baseData.icon,
                        type = baseData.type,
                        gridWidth = baseData.gridWidth,
                        gridHeight = baseData.gridHeight,
                        value = baseData.value,
                        -- Adiciona dados específicos da loja
                        shopPrice = hoveredShopItem.price,
                        shopStock = hoveredShopItem.stock,
                        isOnSale = hoveredShopItem.isOnSale,
                        salePrice = hoveredShopItem.salePrice
                    }
                    self.itemToShowTooltip = tempItem
                end
            end
        end

        -- 1. Checa hover na grade de Armazenamento (Storage)
        if not self.itemToShowTooltip and self.lobbyStorageManager and self.storageGridArea.w and self.storageGridArea.w > 0 then
            local storageItemsDict = self.lobbyStorageManager:getItems(self.lobbyStorageManager:getActiveSectionIndex())
            local storageItemsList = {}
            for _, item in pairs(storageItemsDict or {}) do table.insert(storageItemsList, item) end

            local storageRows, storageCols = self.lobbyStorageManager:getActiveSectionDimensions()
            if #storageItemsList > 0 and storageRows and storageCols then
                local hoveredItem = ItemGridUI.getItemInstanceAtCoords(
                    mx,
                    my,
                    storageItemsList,
                    storageRows,
                    storageCols,
                    self.storageGridArea.x,
                    self.storageGridArea.y,
                    self.storageGridArea.w,
                    self.storageGridArea.h
                )
                if hoveredItem then
                    self.itemToShowTooltip = hoveredItem
                end
            end
        end

        -- 2. Checa hover na grade de Mochila (Loadout)
        if not self.itemToShowTooltip and self.loadoutManager and self.loadoutGridArea.w and self.loadoutGridArea.w > 0 then
            local loadoutItemsDict = self.loadoutManager:getItems()
            local loadoutItemsList = {}
            for _, item in pairs(loadoutItemsDict or {}) do table.insert(loadoutItemsList, item) end

            local loadoutRows, loadoutCols = self.loadoutManager:getDimensions()
            if #loadoutItemsList > 0 and loadoutRows and loadoutCols then
                local hoveredItem = ItemGridUI.getItemInstanceAtCoords(
                    mx,
                    my,
                    loadoutItemsList,
                    loadoutRows,
                    loadoutCols,
                    self.loadoutGridArea.x,
                    self.loadoutGridArea.y,
                    self.loadoutGridArea.w,
                    self.loadoutGridArea.h
                )
                if hoveredItem then
                    self.itemToShowTooltip = hoveredItem
                end
            end
        end

        -- Checa hover em artefatos
        if not self.itemToShowTooltip then
            local hoveredItem = ArtefactsDisplay.hoveredArtefact
            if hoveredItem then
                self.itemToShowTooltip = hoveredItem
            end
        end
    end

    ItemDetailsModalManager.update(dt, mx, my, self.itemToShowTooltip)
end

--- Desenha a tela de Shopping completa.
---@param screenW number Largura da tela.
---@param screenH number Altura da tela.
---@param tabSettings table Configurações das tabs.
---@param dragState table Estado atual do drag-and-drop da cena pai.
---@param mx number Posição X do mouse.
---@param my number Posição Y do mouse.
---@param navbarHeight number Altura da navbar.
---@return table storageArea, table loadoutArea, table shopArea
function ShoppingScreen:draw(screenW, screenH, tabSettings, dragState, mx, my, navbarHeight)
    navbarHeight = navbarHeight or 0 -- Para compatibilidade se não for passado
    local padding = 20
    local topPadding = 30
    local areaY = navbarHeight + topPadding
    local areaW = screenW
    local areaH = screenH - navbarHeight - tabSettings.height

    local sectionTopY = areaY
    local titleFont = fonts.title or love.graphics.getFont()
    local titleHeight = titleFont:getHeight()
    local contentMarginY = 10
    local contentStartY = sectionTopY + titleHeight + contentMarginY
    local sectionContentH = areaH - contentStartY - padding
    local totalPaddingWidth = padding * 4
    local sectionAreaW = areaW - totalPaddingWidth

    -- Divide a área útil HORIZONTALMENTE (3 colunas)
    local shopW = math.floor(sectionAreaW * 0.4)     -- 40% para o mercado
    local storageW = math.floor(sectionAreaW * 0.35) -- 35% para armazenamento
    local loadoutW = sectionAreaW - shopW - storageW -- restante para loadout

    -- Calcula posições HORIZONTAIS
    local shopX = padding
    local storageX = shopX + shopW + padding
    local loadoutX = storageX + storageW + padding

    self.shopArea = { x = shopX, y = contentStartY, w = shopW, h = sectionContentH }
    self.storageGridArea = { x = storageX, y = contentStartY, w = storageW, h = sectionContentH }
    self.loadoutGridArea = {}

    -- Desenha títulos das seções
    love.graphics.setFont(titleFont)
    love.graphics.setColor(colors.text_highlight)
    love.graphics.printf("MERCADO", shopX, sectionTopY, shopW, "center")
    love.graphics.printf("ARMAZENAMENTO", storageX, sectionTopY, storageW, "center")
    love.graphics.printf("MOCHILA", loadoutX, sectionTopY, loadoutW, "center")
    love.graphics.setColor(colors.white)
    love.graphics.setFont(fonts.main or titleFont)

    -- 1. Desenha Coluna do Mercado
    if self.shopManager then
        ShopColumn.draw(
            shopX,
            contentStartY,
            shopW,
            sectionContentH,
            self.shopManager,
            self.itemDataManager,
            mx,
            my
        )
    else
        love.graphics.setColor(colors.red)
        love.graphics.printf("Erro: Shop Manager não inicializado!",
            shopX + shopW / 2, contentStartY + sectionContentH / 2, 0, "center")
        love.graphics.setColor(colors.white)
    end

    -- 2. Desenha Grade do Armazenamento (Storage)
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

    -- Divide o espaço da coluna de loadout entre a mochila e os artefatos
    local artefactsHeight = 120
    local artefactsPadding = 15
    local loadoutFixedHeight = 350

    -- 3. Desenha Coluna da Mochila (Loadout)
    if self.loadoutManager and self.itemDataManager then
        self.loadoutGridArea = HunterLoadoutColumn.draw(
            loadoutX,
            contentStartY,
            loadoutW,
            loadoutFixedHeight,
            self.loadoutManager,
            self.itemDataManager
        )
    else
        love.graphics.setColor(colors.red)
        love.graphics.printf("Erro: Loadout Manager não inicializado!",
            loadoutX + loadoutW / 2, contentStartY + sectionContentH / 2, 0, "center")
        love.graphics.setColor(colors.white)
    end

    -- Desenha Display de Artefatos abaixo do loadout
    if artefactsHeight > 0 then
        local artefactsY = contentStartY + loadoutFixedHeight + artefactsPadding
        self.artefactsArea = { x = loadoutX, y = artefactsY, w = loadoutW, h = artefactsHeight }
        ---@type ArtefactManager
        local artefactManager = ManagerRegistry:tryGet("artefactManager")
        if artefactManager then
            ArtefactsDisplay:draw(
                self.artefactsArea.x,
                self.artefactsArea.y,
                self.artefactsArea.w,
                self.artefactsArea.h,
                true, -- showSellButton
                mx,
                my
            )
        end
    end

    -- Desenho do Drag-and-Drop
    if dragState.isDragging and dragState.draggedItem then
        local current_mx, current_my = love.mouse.getPosition()
        local ghostX = current_mx - dragState.draggedItemOffsetX
        local ghostY = current_my - dragState.draggedItemOffsetY
        elements.drawItemGhost(ghostX, ghostY, dragState.draggedItem, 0.75, dragState.draggedItemIsRotated)

        -- Desenha indicador de drop
        if dragState.targetGridId and dragState.targetSlotCoords then
            local visualW, visualH
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
                    else
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
            end
        end
    end

    -- Desenha o Tooltip
    ItemDetailsModalManager.draw()

    return self.storageGridArea, self.loadoutGridArea, self.shopArea
end

--- Processa cliques do mouse na tela de Shopping.
---@param x number Posição X do mouse.
---@param y number Posição Y do mouse.
---@param buttonIdx number Índice do botão do mouse.
---@return boolean consumed, table|nil dragStartData
function ShoppingScreen:handleMousePress(x, y, buttonIdx)
    if buttonIdx == 1 then
        -- 1. Verifica clique nas tabs do Storage PRIMEIRO
        if self.lobbyStorageManager then
            local storageRows, storageCols = self.lobbyStorageManager:getActiveSectionDimensions()
            local sectionInfo = {
                total = self.lobbyStorageManager:getTotalSections(),
                active = self.lobbyStorageManager:getActiveSectionIndex()
            }
            local clickedTabIndex = ItemGridUI.handleMouseClick(
                x,
                y,
                sectionInfo,
                self.storageGridArea.x,
                self.storageGridArea.y,
                self.storageGridArea.w,
                self.storageGridArea.h,
                storageRows,
                storageCols
            )

            if clickedTabIndex then
                self.lobbyStorageManager:setActiveSection(clickedTabIndex)
                return true, nil
            end
        end

        -- Verifica clique no botão de vender artefatos
        if self.artefactsArea and self.artefactsArea.w > 0 then
            local consumed = ArtefactsDisplay:handleClick(x, y, self.artefactsArea.x, self.artefactsArea.y,
                self.artefactsArea.w, self.artefactsArea.h)
            if consumed then
                return true, nil
            end
        end

        -- 2. Verifica clique na área da loja (para comprar itens ou vender tudo)
        if self.shopManager and x >= self.shopArea.x and x < self.shopArea.x + self.shopArea.w and
            y >= self.shopArea.y and y < self.shopArea.y + self.shopArea.h then
            local shopItem = self.shopManager:getItemAtPosition(x, y, self.shopArea)
            if shopItem then
                -- Verifica se clicou no botão "Vender Tudo"
                if shopItem.action == "sell_all" then
                    local totalValue = self.shopManager:sellAllFromLoadout(self.loadoutManager)
                    Logger.info(
                        "shopping_screen.sell_all",
                        "[ShoppingScreen.handleMousePress] Vendidos itens do loadout por: " .. totalValue
                    )
                    return true, nil
                end

                -- Obtém dados base do item para dimensões corretas
                local baseData = self.itemDataManager:getBaseItemData(shopItem.itemId)

                -- Cria um item temporário para o drag de compra
                local purchaseItem = {
                    itemBaseId = shopItem.itemId,
                    quantity = 1,
                    instanceId = "shop_temp_" .. shopItem.itemId,
                    gridWidth = baseData and baseData.gridWidth or shopItem.gridWidth or 1,
                    gridHeight = baseData and baseData.gridHeight or shopItem.gridHeight or 1,
                    isShopPurchase = true,
                    shopPrice = shopItem.isOnSale and shopItem.salePrice or shopItem.price,
                    icon = baseData and baseData.icon or "default"
                }

                local dragStartData = {
                    item = purchaseItem,
                    sourceGridId = "shop",
                    offsetX = 20,
                    offsetY = 20,
                    isRotated = false
                }
                return true, dragStartData
            end
        end

        -- 3. Verifica clique para drag nas grades (Storage e Loadout)
        local itemClicked = nil
        local clickedGridId = nil

        -- Verifica Storage
        if self.lobbyStorageManager and self.storageGridArea.w > 0 then
            local storageItemsDict = self.lobbyStorageManager:getItems(self.lobbyStorageManager:getActiveSectionIndex())
            local storageItemsList = {}
            for _, item in pairs(storageItemsDict or {}) do table.insert(storageItemsList, item) end

            local storageRows, storageCols = self.lobbyStorageManager:getActiveSectionDimensions()
            itemClicked = ItemGridUI.getItemInstanceAtCoords(
                x,
                y,
                storageItemsList,
                storageRows,
                storageCols,
                self.storageGridArea.x,
                self.storageGridArea.y,
                self.storageGridArea.w,
                self.storageGridArea.h
            )
            if itemClicked then
                clickedGridId = "storage"
            end
        end

        -- Verifica Loadout
        if not itemClicked and self.loadoutManager and self.loadoutGridArea.w > 0 then
            local loadoutItemsDict = self.loadoutManager:getItems()
            local loadoutItemsList = {}
            for _, item in pairs(loadoutItemsDict or {}) do table.insert(loadoutItemsList, item) end

            local loadoutRows, loadoutCols = self.loadoutManager:getDimensions()
            itemClicked = ItemGridUI.getItemInstanceAtCoords(
                x,
                y,
                loadoutItemsList,
                loadoutRows,
                loadoutCols,
                self.loadoutGridArea.x,
                self.loadoutGridArea.y,
                self.loadoutGridArea.w,
                self.loadoutGridArea.h
            )
            if itemClicked then
                clickedGridId = "loadout"
            end
        end

        -- Se clicou em um item, inicia drag
        if itemClicked and clickedGridId then
            local targetArea, targetRows, targetCols
            if clickedGridId == "storage" then
                targetArea = self.storageGridArea
                targetRows, targetCols = self.lobbyStorageManager:getActiveSectionDimensions()
            else
                targetArea = self.loadoutGridArea
                targetRows, targetCols = self.loadoutManager:getDimensions()
            end

            local itemScreenX, itemScreenY = ItemGridUI.getItemScreenPos(
                itemClicked.row,
                itemClicked.col,
                targetRows,
                targetCols,
                targetArea.x,
                targetArea.y,
                targetArea.w,
                targetArea.h
            )

            local itemOffsetX, itemOffsetY = 0, 0
            if itemScreenX and itemScreenY then
                itemOffsetX = x - itemScreenX
                itemOffsetY = y - itemScreenY
            end

            local dragStartData = {
                item = itemClicked,
                sourceGridId = clickedGridId,
                offsetX = itemOffsetX,
                offsetY = itemOffsetY,
                isRotated = itemClicked.isRotated or false
            }
            return true, dragStartData
        end
    end

    return false, nil
end

--- Processa o soltar do mouse na tela de Shopping.
---@param x number Posição X do mouse.
---@param y number Posição Y do mouse.
---@param buttonIdx number Índice do botão do mouse.
---@param dragState table Estado do drag-and-drop.
---@return boolean consumed
function ShoppingScreen:handleMouseRelease(x, y, buttonIdx, dragState)
    if buttonIdx == 1 and dragState.isDragging then
        -- Se estava comprando um item da loja
        if dragState.sourceGridId == "shop" then
            -- Verifica se soltou em área válida (storage ou loadout)
            if dragState.isDropValid and dragState.targetGridId and dragState.targetSlotCoords then
                local success = self.shopManager:purchaseItem(dragState.draggedItem.itemBaseId, 1)

                if success then
                    -- Cria instância real do item comprado
                    local itemInstance = self.itemDataManager:createItemInstanceById(dragState.draggedItem.itemBaseId, 1)

                    local targetManager = (dragState.targetGridId == "storage") and self.lobbyStorageManager or
                        self.loadoutManager
                    local added = targetManager:addItemInstanceAt(itemInstance,
                        dragState.targetSlotCoords.row, dragState.targetSlotCoords.col,
                        dragState.draggedItemIsRotated)

                    if not added then
                        -- Se falhou em adicionar, devolver o dinheiro
                        if self.patrimonyManager then
                            self.patrimonyManager:addGold(
                                dragState.draggedItem.shopPrice,
                                "purchase_refund_" .. dragState.draggedItem.itemBaseId
                            )
                        end
                        Logger.warn(
                            "shopping_screen.purchase_failed",
                            "[ShoppingScreen:handleMouseRelease] Falha ao adicionar item comprado ao inventário - dinheiro devolvido"
                        )
                    end
                end
                return true
            else
                -- Cancelar compra se soltou em área inválida
                return true
            end
        end

        -- Verifica se item está sendo arrastado para a área da loja para vender
        if (dragState.sourceGridId == "storage" or dragState.sourceGridId == "loadout") and
            self.shopArea and
            x >= self.shopArea.x and x <= self.shopArea.x + self.shopArea.w and
            y >= self.shopArea.y and y <= self.shopArea.y + self.shopArea.h then
            -- Vendendo item para a loja
            local itemToSell = dragState.draggedItem
            local sellPrice = self.shopManager:sellItem(itemToSell)

            if sellPrice > 0 then
                -- Remove o item do inventário de origem
                local sourceManager = (dragState.sourceGridId == "storage") and self.lobbyStorageManager or
                    self.loadoutManager
                sourceManager:removeItemInstance(itemToSell.instanceId)

                Logger.info("shopping_screen.sell_item",
                    string.format("[ShoppingScreen:handleMouseRelease] Item vendido por %d gold", sellPrice))
            end

            return true
        end

        -- Lógica normal de drag entre storage e loadout (similar ao equipment_screen)
        if dragState.isDropValid and dragState.targetGridId and dragState.targetSlotCoords then
            if dragState.targetGridId == "storage" or dragState.targetGridId == "loadout" then
                local targetManager = (dragState.targetGridId == "storage") and self.lobbyStorageManager or
                    self.loadoutManager
                local sourceManager = (dragState.sourceGridId == "storage") and self.lobbyStorageManager or
                    self.loadoutManager
                local itemToMove = dragState.draggedItem

                local removed = sourceManager:removeItemInstance(itemToMove.instanceId)
                if removed then
                    local added = targetManager:addItemInstanceAt(
                        itemToMove,
                        dragState.targetSlotCoords.row,
                        dragState.targetSlotCoords.col,
                        dragState.draggedItemIsRotated
                    )

                    if not added then
                        -- Devolver se falhou
                        sourceManager:addItemInstance(itemToMove)
                    end
                end
                return true
            end
        end
    end

    return false
end

--- Processa pressionamento de teclas na tela de Shopping.
---@param key string A tecla pressionada.
---@param dragState table Estado do drag-and-drop.
---@return boolean wantsToRotate
function ShoppingScreen:keypressed(key, dragState)
    if key == "space" then
        if dragState and dragState.isDragging and dragState.draggedItem then
            local item = dragState.draggedItem
            if item.gridWidth and item.gridHeight and item.gridWidth ~= item.gridHeight then
                Logger.info(
                    "shopping_screen.rotate_item",
                    "[ShoppingScreen:keypressed] Rotacionando item: " .. (item.itemBaseId or "unknown") ..
                    " de " .. item.gridWidth .. "x" .. item.gridHeight ..
                    " para " .. item.gridHeight .. "x" .. item.gridWidth
                )
                return true
            end
        end
    end
    return false
end

return ShoppingScreen
