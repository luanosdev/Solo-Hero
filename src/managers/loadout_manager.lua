local PersistenceManager = require("src.core.persistence_manager")
local ItemGridLogic = require("src.core.item_grid_logic")
local Constants = require("src.config.constants")

---@class LoadoutManager
local LoadoutManager = {
    itemDataManager = nil ---@type ItemDataManager
}

LoadoutManager.__index = LoadoutManager

local SHARED_LOADOUT_SAVE_FILE = "shared_loadout.dat" -- Arquivo para o loadout compartilhado

--- Cria uma nova instância do gerenciador de loadout.
--- @param itemDataManager ItemDataManager Instância do ItemDataManager.
--- @return LoadoutManager
function LoadoutManager:new(itemDataManager)
    print("[LoadoutManager] Criando nova instância...")
    local instance = setmetatable({}, LoadoutManager)
    instance.itemDataManager = itemDataManager
    if not instance.itemDataManager then
        error("ERRO CRÍTICO [LoadoutManager]: itemDataManager não foi injetado!")
    end

    -- Define padrões iniciais (serão sobrescritos pelo loadState se houver save)
    instance.rows = Constants.GRID_ROWS
    instance.cols = Constants.GRID_COLS
    instance.grid = {}  -- Grade 2D para referência rápida de ocupação
    instance.items = {} -- Tabela de instâncias de itens { [instanceId] = itemInstanceData }

    -- Tenta carregar o estado salvo
    instance:loadState()

    -- Garante que a grade exista mesmo se o load falhar ou for a primeira vez
    if not next(instance.grid) then
        instance:_createEmptyGrid(instance.rows, instance.cols)
        print("  [LoadoutManager] Grid recriado (primeira vez ou load falhou).")
    end

    print(string.format("[LoadoutManager] Pronto. Manager inicializado com grid %dx%d e %d itens.",
        instance.rows, instance.cols, table.maxn(instance.items or {})))

    return instance
end

--- Helper interno para criar/recriar a grade 2D vazia.
--- @param rows number Número de linhas.
--- @param cols number Número de colunas.
function LoadoutManager:_createEmptyGrid(rows, cols)
    self.grid = {}
    for r = 1, rows do
        self.grid[r] = {}
        for c = 1, cols do
            self.grid[r][c] = nil
        end
    end
end

-- == Funções de Acesso ==

--- Obtém a tabela de itens no loadout.
--- @return table Tabela de itens { [instanceId] = itemInstanceData }.
function LoadoutManager:getItems()
    return self.items or {} -- Retorna tabela vazia se nil
end

--- Obtém as dimensões da grade do loadout.
--- @return number, number Linhas e Colunas.
function LoadoutManager:getDimensions()
    return self.rows, self.cols
end

--- Obtém a instância do item em coordenadas específicas da grade.
--- @param targetRow integer Linha alvo (1-indexed).
--- @param targetCol integer Coluna alvo (1-indexed).
--- @return table|nil A instância do item se encontrada, caso contrário nil.
function LoadoutManager:getItemInstanceAtCoords(targetRow, targetCol)
    if not self.items or not targetRow or not targetCol then return nil end
    if DEV then
        Logger.debug("[LoadoutManager:getItemInstanceAtCoords]",
            string.format("Checking for item at [%d,%d]", targetRow, targetCol))
        local itemCount = 0
        for _ in pairs(self.items) do itemCount = itemCount + 1 end
        Logger.debug("[LoadoutManager:getItemInstanceAtCoords]", string.format("Total items in loadout: %d", itemCount))
    end

    for instanceId, item in pairs(self.items) do
        local itemOriginX, itemOriginY = item.col, item.row
        local itemDisplayW = item.isRotated and item.gridHeight or item.gridWidth
        local itemDisplayH = item.isRotated and item.gridWidth or item.gridHeight

        Logger.debug("[LoadoutManager:getItemInstanceAtCoords]",
            string.format("    Checking item: %s (ID %s) at [%d,%d] size [%dx%d] (display: %dx%d, rotated: %s)",
                item.itemBaseId, instanceId, itemOriginY, itemOriginX, item.gridWidth, item.gridHeight, itemDisplayW,
                itemDisplayH, tostring(item.isRotated)))

        -- Verifica se (targetRow, targetCol) está dentro da área ocupada pelo item
        if targetCol >= itemOriginX and targetCol < itemOriginX + itemDisplayW and
            targetRow >= itemOriginY and targetRow < itemOriginY + itemDisplayH then
            Logger.debug("[LoadoutManager:getItemInstanceAtCoords]",
                string.format("    FOUND item: %s (ID %s) at coords [%d,%d]", item.itemBaseId, instanceId, targetRow,
                    targetCol))
            return item -- Encontrou o item que ocupa esta célula
        end
    end
    -- print(string.format("  [LoadoutManager:getItemInstanceAtCoords] No item found at [%d,%d]", targetRow, targetCol))
    return nil -- Nenhum item encontrado nesta célula
end

-- == Funções de Manipulação de Itens ==

--- Limpa todos os itens do loadout, resetando a grade.
function LoadoutManager:clearAllItems()
    print("[LoadoutManager] Limpando todos os itens do loadout...")
    self:_createEmptyGrid(self.rows, self.cols)
    self.items = {}
    print("[LoadoutManager] Loadout limpo.")
end

--- Verifica se um item pode ser colocado em uma posição específica.
---@param item table Instância do item a ser colocado.
---@param targetRow integer Linha alvo (1-indexed).
---@param targetCol integer Coluna alvo (1-indexed).
---@param checkWidth integer|nil Largura a ser usada para a checagem (usa item.gridWidth se nil).
---@param checkHeight integer|nil Altura a ser usada para a checagem (usa item.gridHeight se nil).
---@return boolean True se o item pode ser colocado, false caso contrário.
function LoadoutManager:canPlaceItemAt(item, targetRow, targetCol, checkWidth, checkHeight)
    if not item or not targetRow or not targetCol then
        print("ERRO (canPlaceItemAt - Loadout): Parâmetros inválidos.")
        return false
    end

    -- Usa as dimensões fornecidas para a checagem, ou as do item como fallback
    local itemW = checkWidth or item.gridWidth or 1
    local itemH = checkHeight or item.gridHeight or 1

    -- Verifica se já existe um item no slot alvo
    local itemAtTarget = self:getItemInstanceAtCoords(targetRow, targetCol)
    if itemAtTarget and itemAtTarget.instanceId ~= item.instanceId then
        local baseData = self.itemDataManager:getBaseItemData(itemAtTarget.itemBaseId)
        if baseData and baseData.stackable and itemAtTarget.itemBaseId == item.itemBaseId then
            local maxStack = baseData.maxStack or 99
            if itemAtTarget.quantity < maxStack then
                return true
            end
        end
        return false
    end

    return ItemGridLogic.canPlaceItemAt(self.grid, self.rows, self.cols, item.instanceId, targetRow, targetCol, itemW,
        itemH)
end

--- Adiciona um item (ou quantidade) ao loadout.
--- @param itemBaseId string ID base do item.
--- @param quantity number Quantidade a adicionar.
--- @return number Quantidade realmente adicionada.
function LoadoutManager:addItem(itemBaseId, quantity)
    if not itemBaseId or not quantity or quantity <= 0 then return 0 end

    local baseData = self:_getItemBaseData(itemBaseId)
    if not baseData then
        Logger.error("[LoadoutManager]: Não foi possível obter dados para o item ID:", itemBaseId)
        return 0
    end

    local width = baseData.gridWidth or 1
    local height = baseData.gridHeight or 1
    local stackable = baseData.stackable or false
    local maxStack = baseData.maxStack or (stackable and 99) or 1
    local addedQuantity = 0
    local remainingQuantity = quantity

    -- 1. Tentar Empilhar
    if stackable then
        for id, instance in pairs(self.items) do
            if instance.itemBaseId == itemBaseId and instance.quantity < maxStack then
                local spaceAvailable = maxStack - instance.quantity
                local amountToStack = math.min(remainingQuantity, spaceAvailable)
                instance.quantity = instance.quantity + amountToStack
                addedQuantity = addedQuantity + amountToStack
                remainingQuantity = remainingQuantity - amountToStack
                if remainingQuantity <= 0 then break end
            end
        end
    end

    -- 2. Tentar Colocar Novos Stacks/Itens
    while remainingQuantity > 0 do
        local amountForThisInstance = stackable and math.min(remainingQuantity, maxStack) or 1
        local freeSpace = ItemGridLogic.findFreeSpace(self.grid, self.rows, self.cols, width, height)

        if freeSpace then
            local newItemInstance = self.itemDataManager:createItemInstanceById(itemBaseId, amountForThisInstance)

            if newItemInstance then
                -- Define a posição e rotação na instância recém-criada
                newItemInstance.row = freeSpace.row
                newItemInstance.col = freeSpace.col
                newItemInstance.isRotated = false -- Padrão ao adicionar

                -- Adiciona ao registro de itens
                self.items[newItemInstance.instanceId] = newItemInstance

                -- Marca a grade como ocupada
                local actualW = newItemInstance.gridWidth
                local actualH = newItemInstance.gridHeight
                ItemGridLogic.markGridOccupied(self.grid, self.rows, self.cols, newItemInstance.instanceId,
                    newItemInstance.row, newItemInstance.col, actualW, actualH)

                addedQuantity = addedQuantity + amountForThisInstance
                remainingQuantity = remainingQuantity - amountForThisInstance
            else
                -- Falha ao criar a instância, para o loop
                error(string.format("ERRO [LoadoutManager:addItem] Falha ao criar instância de item para %s. Abortando.",
                    itemBaseId))
                break -- Sai do loop se a criação da instância falhar
            end
        else
            Logger.warn("[LoadoutManager:addItem]",
                string.format("Sem espaço no loadout para %s (%dx%d).", itemBaseId, width, height))
            break -- Sai do loop se não houver espaço
        end
    end

    if remainingQuantity > 0 then
        Logger.warn("[LoadoutManager:addItem]",
            string.format("Não foi possível adicionar %d de %s (loadout cheio ou sem espaço adequado).",
                remainingQuantity, itemBaseId))
    end

    return addedQuantity
end

--- Remove uma instância específica de item do loadout.
--- @param instanceId any ID da instância a remover.
--- @param quantity? number (Opcional) Quantidade a remover. Se omitido ou >= quantidade atual, remove tudo.
--- @return boolean True se removeu com sucesso.
function LoadoutManager:removeItemInstance(instanceId, quantity)
    local instance = self.items[instanceId]
    if not instance then
        Logger.warn("[LoadoutManager:removeItemInstance]",
            string.format("Tentativa de remover instância de item inexistente: %s", instanceId))
        return false
    end

    local quantityToRemove = quantity or instance.quantity

    if instance.stackable and quantityToRemove < instance.quantity then
        -- Apenas diminui a quantidade
        instance.quantity = instance.quantity - quantityToRemove
        Logger.info("[LoadoutManager:removeItemInstance]",
            string.format("Quantidade do item %s (ID %s) diminuída para %d.",
                instance.itemBaseId, instanceId, instance.quantity))
        return true
    else
        -- Remove a instância inteira
        local actualW = instance.isRotated and instance.gridHeight or instance.gridWidth
        local actualH = instance.isRotated and instance.gridWidth or instance.gridHeight
        ItemGridLogic.clearGridArea(
            self.grid,
            self.rows,
            self.cols,
            instanceId,
            instance.row,
            instance.col,
            actualW,
            actualH
        )
        self.items[instanceId] = nil
        Logger.info("[LoadoutManager:removeItemInstance]",
            string.format("Item %s (ID %s) removido.", instance.itemBaseId, instanceId))
        return true
    end
end

--- Adiciona uma instância de item existente ao loadout, encontrando automaticamente um espaço livre.
--- Esta função NÃO cria um novo item, ela apenas o "coloca" no loadout.
--- Útil para mover itens entre inventários.
--- @param itemInstance table A instância completa do item a ser adicionado.
--- @return boolean True se o item foi adicionado com sucesso.
function LoadoutManager:addItemInstance(itemInstance)
    if not itemInstance or not itemInstance.instanceId or not itemInstance.itemBaseId then
        Logger.error("[LoadoutManager:addItemInstance]",
            string.format("Instância de item inválida: %s",
                tostring(itemInstance and itemInstance.itemBaseId or "nil")))
        return false
    end

    -- Tenta empilhar primeiro se o item for stackable
    local baseData = self:_getItemBaseData(itemInstance.itemBaseId)
    if baseData and baseData.stackable then
        local maxStack = baseData.maxStack or 99

        -- Procura por stacks existentes do mesmo item que tenham espaço
        for id, existingInstance in pairs(self.items) do
            if existingInstance.itemBaseId == itemInstance.itemBaseId and
                existingInstance.quantity < maxStack then
                local spaceAvailable = maxStack - existingInstance.quantity
                local amountToStack = math.min(itemInstance.quantity, spaceAvailable)

                existingInstance.quantity = existingInstance.quantity + amountToStack
                itemInstance.quantity = itemInstance.quantity - amountToStack

                Logger.info("[LoadoutManager:addItemInstance]",
                    string.format("Empilhado %d unidades de %s em stack existente",
                        amountToStack, itemInstance.itemBaseId))

                -- Se toda a quantidade foi empilhada, retorna sucesso
                if itemInstance.quantity <= 0 then
                    return true
                end
            end
        end
    end

    -- Se restou quantidade (ou não é stackable), procura espaço livre
    if itemInstance.quantity > 0 then
        local width = itemInstance.gridWidth or baseData.gridWidth or 1
        local height = itemInstance.gridHeight or baseData.gridHeight or 1

        local freeSpace = ItemGridLogic.findFreeSpace(self.grid, self.rows, self.cols, width, height)

        if freeSpace then
            return self:addItemInstanceAt(itemInstance, freeSpace.row, freeSpace.col, false)
        else
            Logger.warn("[LoadoutManager:addItemInstance]",
                string.format("Sem espaço no loadout para %s (%dx%d).",
                    itemInstance.itemBaseId, width, height))
            return false
        end
    end

    return true
end

--- Adiciona uma instância de item existente ao loadout em uma posição específica.
--- Esta função NÃO cria um novo item, ela apenas o "coloca" no loadout.
--- Útil para mover itens entre inventários.
--- @param itemInstance table A instância completa do item a ser adicionado.
--- @param targetRow integer A linha alvo para o canto superior esquerdo do item.
--- @param targetCol integer A coluna alvo para o canto superior esquerdo do item.
--- @param isRotated boolean Se o item deve ser adicionado rotacionado.
--- @return boolean True se o item foi adicionado com sucesso.
function LoadoutManager:addItemInstanceAt(itemInstance, targetRow, targetCol, isRotated)
    if not itemInstance or not itemInstance.instanceId or not targetRow or not targetCol then
        error("ERRO [LoadoutManager:addItemInstanceAt]: Argumentos inválidos.")
        return false
    end

    -- Atualiza as propriedades da instância com a nova posição/rotação
    itemInstance.row = targetRow
    itemInstance.col = targetCol
    itemInstance.isRotated = isRotated or false

    local actualW = itemInstance.isRotated and itemInstance.gridHeight or itemInstance.gridWidth
    local actualH = itemInstance.isRotated and itemInstance.gridWidth or itemInstance.gridHeight

    -- Verifica se o local está livre (excluindo o próprio item, se já estivesse aqui)
    if not ItemGridLogic.canPlaceItemAt(self.grid, self.rows, self.cols, itemInstance.instanceId, targetRow, targetCol, actualW, actualH) then
        Logger.error("[LoadoutManager:addItemInstanceAt]", string.format("Não é possível colocar o item %s em [%d,%d].",
            itemInstance.itemBaseId, targetRow, targetCol))
        return false
    end

    -- Remove o item de sua posição antiga (se houver uma) para evitar "fantasmas" na grade
    -- Esta é uma suposição segura; se o item era novo, esta chamada não fará nada de errado.
    for id, item in pairs(self.items) do
        if id == itemInstance.instanceId then
            local oldW = item.isRotated and item.gridHeight or item.gridWidth
            local oldH = item.isRotated and item.gridWidth or item.gridHeight
            ItemGridLogic.clearGridArea(self.grid, self.rows, self.cols, item.instanceId, item.row, item.col, oldW, oldH)
            break
        end
    end

    -- Adiciona/atualiza a instância e marca a nova posição na grade
    self.items[itemInstance.instanceId] = itemInstance
    ItemGridLogic.markGridOccupied(self.grid, self.rows, self.cols, itemInstance.instanceId, targetRow, targetCol,
        actualW, actualH)

    Logger.info("[LoadoutManager:addItemInstanceAt]",
        string.format("Item %s (ID %s) colocado em [%d,%d], Rotacionado: %s",
            itemInstance.itemBaseId, itemInstance.instanceId, targetRow, targetCol, tostring(itemInstance.isRotated)))

    return true
end

-- == Funções Auxiliares ==

--- Helper interno para obter dados base do item.
--- @param itemBaseId string ID base do item.
--- @return table Dados base do item.
function LoadoutManager:_getItemBaseData(itemBaseId)
    if self.itemDataManager and self.itemDataManager.getBaseItemData then
        return self.itemDataManager:getBaseItemData(itemBaseId)
    else
        error("AVISO [LoadoutManager]: itemDataManager ausente ou método getBaseItemData não encontrado.")
    end
end

-- == Funções de Persistência ==

--- Salva o estado atual do loadout compartilhado.
--- @return boolean True se salvou com sucesso.
function LoadoutManager:saveState()
    print(string.format("[LoadoutManager] Saving shared state to %s...", SHARED_LOADOUT_SAVE_FILE))

    -- Prepara uma tabela com os dados a serem salvos
    local dataToSave = {
        items = {},
    }

    -- Processa apenas os itens, salvando os dados essenciais
    for instanceId, itemInstance in pairs(self.items) do
        dataToSave.items[instanceId] = {
            instanceId = itemInstance.instanceId,
            itemBaseId = itemInstance.itemBaseId,
            quantity = itemInstance.quantity,
            row = itemInstance.row,
            col = itemInstance.col,
            isRotated = itemInstance.isRotated or false,
        }
    end

    local success = PersistenceManager.saveData(SHARED_LOADOUT_SAVE_FILE, dataToSave)
    if success then
        print("[LoadoutManager] Loadout salvo com sucesso.")
    else
        print("ERROR [LoadoutManager]: Failed to save shared state.")
    end
    return success
end

--- Carrega o estado do loadout compartilhado a partir de um arquivo.
--- @return boolean True se carregou com sucesso.
function LoadoutManager:loadState()
    local loadedData = PersistenceManager.loadData(SHARED_LOADOUT_SAVE_FILE)
    if not loadedData then
        print("[LoadoutManager] Nenhum arquivo de save encontrado para o loadout compartilhado. Usando estado padrão.")
        return false
    end
    print("[LoadoutManager] Carregando estado do loadout de " .. SHARED_LOADOUT_SAVE_FILE)

    -- Mantém as dimensões atuais das Constantes, ignorando as salvas
    self.rows = Constants.GRID_ROWS
    self.cols = Constants.GRID_COLS
    self.items = {}                             -- Limpa itens atuais antes de carregar
    self:_createEmptyGrid(self.rows, self.cols) -- Cria a grade com as dimensões das Constantes

    -- Reconstrói as instâncias de itens
    local loadedItemsData = loadedData.items or {}
    local itemCount = 0
    for instanceId, savedItemData in pairs(loadedItemsData) do
        local baseData = self:_getItemBaseData(savedItemData.itemBaseId)
        if baseData then
            -- Recria a instância do item com todos os dados base + dados salvos
            local newItemInstance = self.itemDataManager:createItemInstanceById(savedItemData.itemBaseId,
                savedItemData.quantity)

            -- Sobrescreve o ID da instância com o que foi salvo para manter a referência
            newItemInstance.instanceId = savedItemData.instanceId
            newItemInstance.row = savedItemData.row
            newItemInstance.col = savedItemData.col
            newItemInstance.isRotated = savedItemData.isRotated

            self.items[newItemInstance.instanceId] = newItemInstance
            itemCount = itemCount + 1

            -- Marca a grade como ocupada
            local actualW = newItemInstance.isRotated and newItemInstance.gridHeight or newItemInstance.gridWidth
            local actualH = newItemInstance.isRotated and newItemInstance.gridWidth or newItemInstance.gridHeight
            ItemGridLogic.markGridOccupied(self.grid, self.rows, self.cols, newItemInstance.instanceId,
                newItemInstance.row, newItemInstance.col, actualW, actualH)
        else
            Logger.warn("[LoadoutManager:loadState]", string.format(
                "WARNING [LoadoutManager]: Could not find base data for loaded item '%s' (instance %s). Item skipped.",
                savedItemData.itemBaseId, tostring(savedItemData.instanceId)))
        end
    end

    print(string.format("[LoadoutManager] Load complete. Grid: %dx%d. Loaded %d items.",
        self.rows, self.cols, itemCount))
    return true
end

return LoadoutManager
