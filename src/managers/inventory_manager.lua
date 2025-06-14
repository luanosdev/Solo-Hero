--[[-
    Inventory Manager
    Gerencia os itens que o jogador possui em uma grade 2D.
]]
local ItemGridLogic = require("src.core.item_grid_logic")
local Constants = require("src.config.constants")

---@class InventoryManager
---@field rows number
---@field cols number
---@field itemDataManager ItemDataManager
---@field grid table<number, table<number, any>>
---@field placedItems table<any, table>
local InventoryManager = {}
InventoryManager.__index = InventoryManager

--- Inicializa o gerenciador de inventário.
--- @param config { rows: number, cols: number, itemDataManager: ItemDataManager } Tabela de configuração.
function InventoryManager:init(config)
    config = config or {}
    self.rows = config.rows or Constants.GRID_ROWS
    self.cols = config.cols or Constants.GRID_COLS

    if not self.itemDataManager then
        error("ERRO CRÍTICO [InventoryManager]: itemDataManager não foi injetado via construtor!")
    end

    -- Inicializa a grade 2D com nil
    self.grid = {}
    for r = 1, self.rows do
        self.grid[r] = {}
        for c = 1, self.cols do
            self.grid[r][c] = nil
        end
    end

    -- Armazena as instâncias de itens colocados (chave = instanceId)
    self.placedItems = {}

    Logger.info("[InventoryManager:init]", string.format("Inicializado com grade %dx%d.", self.rows, self.cols))
end

--- Helper interno para obter dados base do item
--- @param itemBaseId string O ID base do item a ser buscado.
--- @return table itemBaseData Dados base do item ou nil se não encontrado.
function InventoryManager:_getItemBaseData(itemBaseId)
    if self.itemDataManager and self.itemDataManager.getBaseItemData then
        return self.itemDataManager:getBaseItemData(itemBaseId)
    else
        error("AVISO [InventoryManager]: Não foi possível obter dados base para " .. itemBaseId ..
            " - itemDataManager ausente ou função getBaseItemData não encontrada.")
    end
end

--- Adiciona um item (ou quantidade de um item) ao inventário.
--- Tenta empilhar se possível, senão tenta encontrar espaço na grade.
--- @param itemBaseId string O ID base do item a ser adicionado.
--- @param quantity number A quantidade a ser adicionada.
--- @return number addedQuantity A quantidade que foi *realmente* adicionada (pode ser 0).
function InventoryManager:addItem(itemBaseId, quantity)
    if not itemBaseId or not quantity or quantity <= 0 then return 0 end

    local baseData = self:_getItemBaseData(itemBaseId)
    if not baseData then return 0 end

    local width = baseData.gridWidth or 1
    local height = baseData.gridHeight or 1
    local stackable = baseData.stackable or false
    local maxStack = baseData.maxStack or (stackable and 99) or 1
    local addedQuantity = 0
    local remainingQuantity = quantity

    -- 1. Tentar Empilhar (se aplicável)
    if stackable then
        for id, instance in pairs(self.placedItems) do
            if instance.itemBaseId == itemBaseId and instance.quantity < maxStack then
                local spaceAvailable = maxStack - instance.quantity
                local amountToStack = math.min(remainingQuantity, spaceAvailable)
                instance.quantity = instance.quantity + amountToStack
                addedQuantity = addedQuantity + amountToStack
                remainingQuantity = remainingQuantity - amountToStack
                if remainingQuantity <= 0 then
                    Logger.info("[InventoryManager:addItem]",
                        string.format("Item %s (ID %s) empilhado com %d de %d", itemBaseId, id, amountToStack, quantity))
                    break
                end
            end
        end
    end

    -- 2. Tentar Colocar Novos Stacks/Itens (se ainda houver quantidade restante)
    while remainingQuantity > 0 do
        -- TODO: Adicionar logica para tentar colocar o item rotacionado
        local amountForThisInstance = stackable and math.min(remainingQuantity, maxStack) or 1
        local freeSpace = ItemGridLogic.findFreeSpace(self.grid, self.rows, self.cols, width, height)

        if freeSpace then
            local newItemInstance = self.itemDataManager:createItemInstanceById(itemBaseId, amountForThisInstance)
            if newItemInstance then
                newItemInstance.row = freeSpace.row
                newItemInstance.col = freeSpace.col
                newItemInstance.isRotated = false

                self.placedItems[newItemInstance.instanceId] = newItemInstance
                ItemGridLogic.markGridOccupied(self.grid, self.rows, self.cols, newItemInstance.instanceId, freeSpace
                    .row, freeSpace.col, width, height)

                addedQuantity = addedQuantity + amountForThisInstance
                remainingQuantity = remainingQuantity - amountForThisInstance
            else
                error(string.format("ERRO [InventoryManager:addItem] Falha ao criar instância de item para %s",
                    itemBaseId))
                break
            end
        else
            Logger.warn("[InventoryManager:addItem]",
                string.format("Sem espaço livre na grade para %s (%dx%d).", itemBaseId, width, height))
            break
        end
    end

    if remainingQuantity > 0 then
        Logger.warn("[InventoryManager:addItem]",
            string.format("Não foi possível adicionar %d de %s (inventário cheio ou sem espaço adequado).",
                remainingQuantity, itemBaseId))
    end

    return addedQuantity
end

--- Remove uma instância específica de item do inventário.
--- @param instanceId any O ID da instância a ser removida.
--- @param quantity number? Quantidade a remover (se empilhável). Se omitido ou maior/igual à quantidade atual, remove a instância inteira.
--- @return boolean success true se removeu com sucesso, false caso contrário.
function InventoryManager:removeItemInstance(instanceId, quantity)
    local instance = self.placedItems[instanceId]
    if not instance then return false end

    local quantityToRemove = quantity or instance.quantity

    if instance.stackable and quantityToRemove < instance.quantity then
        -- Remove apenas uma parte da pilha
        instance.quantity = instance.quantity - quantityToRemove
        Logger.info("[InventoryManager:removeItemInstance]",
            string.format("Item %s (ID %s) removido parcialmente da grade", instance.itemBaseId, instanceId))
        return true
    else
        -- Remove a instância inteira (não empilhável ou quantidade >= total)
        -- Determina as dimensões reais de ocupação com base na rotação
        local itemW = instance.gridWidth or 1
        local itemH = instance.gridHeight or 1
        local actualW = instance.isRotated and itemH or itemW
        local actualH = instance.isRotated and itemW or itemH

        ItemGridLogic.clearGridArea(self.grid, self.rows, self.cols, instance.instanceId, instance.row, instance.col,
            actualW, actualH)
        self.placedItems[instanceId] = nil
        Logger.info("[InventoryManager:removeItemInstance]",
            string.format("Item %s (ID %s) removido da grade", instance.itemBaseId, instanceId))
        return true
    end
end

--- Retorna a quantidade total de um item específico no inventário.
--- @param itemBaseId string O ID base do item (ex: "jewel_E").
--- @return number totalQuantity A quantidade total do item, ou 0 se não encontrado.
function InventoryManager:getItemCount(itemBaseId)
    local totalQuantity = 0
    for _, instance in pairs(self.placedItems) do
        if instance.itemBaseId == itemBaseId then
            totalQuantity = totalQuantity + instance.quantity
        end
    end
    return totalQuantity
end

--- Retorna uma lista de itens formatada para a UI.
--- @return { itemId: string, quantity: number, row: number, col: number } gridItems Lista de tabelas.
function InventoryManager:getInventoryGridItems()
    local uiItems = {}
    for _, instance in pairs(self.placedItems) do
        table.insert(uiItems, instance) -- A instância já tem todos os dados necessários
    end
    return uiItems
end

--- Retorna a instância do item que ocupa uma célula específica da grade.
--- @param row number Linha da célula.
--- @param col number Coluna da célula.
--- @return table|nil itemInstance A instância do item de `placedItems`, ou nil se a célula estiver vazia.
function InventoryManager:getItemAt(row, col)
    if not self.grid or not self.grid[row] or not self.grid[row][col] then
        return nil
    end
    local instanceId = self.grid[row][col]
    if instanceId then
        return self.placedItems[instanceId]
    end
    return nil
end

--- Adiciona uma instância de item existente ao inventário em um local específico.
--- @param itemInstance table A instância do item a ser colocada.
--- @param targetRow number Linha alvo.
--- @param targetCol number Coluna alvo.
--- @param isRotated boolean Se o item está rotacionado.
--- @return boolean success True se o item foi colocado com sucesso.
function InventoryManager:addItemAt(itemInstance, targetRow, targetCol, isRotated)
    if not itemInstance or not itemInstance.instanceId then return false end

    itemInstance.row = targetRow
    itemInstance.col = targetCol
    itemInstance.isRotated = isRotated or false

    local itemW = itemInstance.gridWidth or 1
    local itemH = itemInstance.gridHeight or 1
    local actualW = itemInstance.isRotated and itemH or itemW
    local actualH = itemInstance.isRotated and itemW or itemH

    if not ItemGridLogic.canPlaceItemAt(self.grid, self.rows, self.cols, itemInstance.instanceId, targetRow, targetCol, actualW, actualH) then
        return false
    end

    ItemGridLogic.markGridOccupied(self.grid, self.rows, self.cols, itemInstance.instanceId, targetRow, targetCol,
        actualW, actualH)
    self.placedItems[itemInstance.instanceId] = itemInstance
    return true
end

--- Limpa o inventário completamente.
function InventoryManager:clear()
    self.grid = {}
    for r = 1, self.rows do
        self.grid[r] = {}
        for c = 1, self.cols do
            self.grid[r][c] = nil
        end
    end
    self.placedItems = {}
    Logger.info("[InventoryManager:clear]", "Inventário limpo.")
end

--- Retorna todos os itens do inventário (para gameplay).
--- @return table<table, any> allItems Lista de itens.
function InventoryManager:getAllItemsGameplay()
    local allItems = {}
    for _, itemInstance in pairs(self.placedItems) do
        table.insert(allItems, itemInstance)
    end
    return allItems
end

--- Retorna as dimensões da grade.
--- @return {rows: number, cols: number} gridDimensions As dimensões da grade.
function InventoryManager:getGridDimensions()
    return { rows = self.rows, cols = self.cols }
end

--- Retorna a grade interna (para lógica de UI).
--- @return table
function InventoryManager:getInternalGrid()
    return self.grid
end

--- Construtor
--- @param config table Configuração opcional.
--- @return table InventoryManager A instância do gerenciador de inventário.
function InventoryManager:new(config)
    local instance = setmetatable({}, InventoryManager)
    config = config or {}

    if config.itemDataManager then
        instance.itemDataManager = config.itemDataManager
    else
        error("ERRO CRÍTICO [InventoryManager:new]: itemDataManager não foi fornecido na config do construtor!")
    end

    instance:init(config)
    return instance
end

return InventoryManager
