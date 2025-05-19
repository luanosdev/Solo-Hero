local PersistenceManager = require("src.core.persistence_manager")
local ItemGridLogic = require("src.core.item_grid_logic")
local Constants = require("src.config.constants")
local uuid = require("src.utils.uuid")

---@class LoadoutManager
local LoadoutManager = {
    itemDataManager = nil ---@type ItemDataManager
}

LoadoutManager.__index = LoadoutManager

local SHARED_LOADOUT_SAVE_FILE = "shared_loadout.dat" -- Arquivo para o loadout compartilhado

-- Contador para IDs únicos de instância de item DENTRO do loadout
-- Usaremos um prefixo ou um range diferente para evitar colisão com LobbyStorageManager
-- Ou podemos usar um único contador global, mas isso exige mais coordenação.
-- Vamos começar com um contador local para o Loadout.
local nextInstanceId = 1 -- Reinicia em 1, IDs são locais para o loadout

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
    nextInstanceId = 1  -- Reseta contador local

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

--- NOVO: Obtém a instância do item em coordenadas específicas da grade.
--- @param targetRow integer Linha alvo (1-indexed).
--- @param targetCol integer Coluna alvo (1-indexed).
--- @return table|nil A instância do item se encontrada, caso contrário nil.
function LoadoutManager:getItemInstanceAtCoords(targetRow, targetCol)
    if not self.items or not targetRow or not targetCol then return nil end
    print(string.format("  [LoadoutManager:getItemInstanceAtCoords] Checking for item at [%d,%d]", targetRow, targetCol))
    local itemCount = 0
    for _ in pairs(self.items) do itemCount = itemCount + 1 end
    print(string.format("    Total items in loadout: %d", itemCount))

    for instanceId, item in pairs(self.items) do
        local itemOriginX, itemOriginY = item.col, item.row
        local itemDisplayW = item.isRotated and item.gridHeight or item.gridWidth
        local itemDisplayH = item.isRotated and item.gridWidth or item.gridHeight

        print(string.format("    Checking item: %s (ID %s) at [%d,%d] size [%dx%d] (display: %dx%d, rotated: %s)",
            item.itemBaseId, instanceId, itemOriginY, itemOriginX, item.gridWidth, item.gridHeight, itemDisplayW,
            itemDisplayH, tostring(item.isRotated)))

        -- Verifica se (targetRow, targetCol) está dentro da área ocupada pelo item
        if targetCol >= itemOriginX and targetCol < itemOriginX + itemDisplayW and
            targetRow >= itemOriginY and targetRow < itemOriginY + itemDisplayH then
            print(string.format("    FOUND item: %s (ID %s) at coords [%d,%d]", item.itemBaseId, instanceId, targetRow,
                targetCol))
            return item -- Encontrou o item que ocupa esta célula
        end
    end
    print(string.format("  [LoadoutManager:getItemInstanceAtCoords] No item found at [%d,%d]", targetRow, targetCol))
    return nil -- Nenhum item encontrado nesta célula
end

-- == Funções de Manipulação de Itens ==

--- Limpa todos os itens do loadout, resetando a grade e o contador de instâncias.
function LoadoutManager:clearAllItems()
    print("[LoadoutManager] Limpando todos os itens do loadout...")
    self:_createEmptyGrid(self.rows, self.cols)
    self.items = {}
    nextInstanceId = 1 -- Reseta o contador de ID de instância local
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

    -- A lógica é a mesma do _addItemToSection, mas opera diretamente em self.items e self.grid
    local baseData = self:_getItemBaseData(itemBaseId)
    if not baseData then
        print("ERRO [LoadoutManager]: Não foi possível obter dados para o item ID:", itemBaseId)
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
            local instanceId = uuid.generate()
            local newItemInstance = {
                instanceId = instanceId,
                itemBaseId = itemBaseId,
                quantity = amountForThisInstance,
                row = freeSpace.row,
                col = freeSpace.col,
                isRotated = false,
                gridWidth = width,
                gridHeight = height,
                stackable = stackable,
                maxStack = maxStack,
                name = baseData.name,
                icon = baseData.icon,
            }
            self.items[instanceId] = newItemInstance

            self:addItemAt(newItemInstance, freeSpace.row, freeSpace.col, newItemInstance.isRotated)

            addedQuantity = addedQuantity + amountForThisInstance
            remainingQuantity = remainingQuantity - amountForThisInstance
        else
            print(string.format("Sem espaço no loadout para %s (%dx%d).", itemBaseId, width, height))
            break
        end
    end

    if remainingQuantity > 0 then
        print(string.format("Não foi possível adicionar %d de %s (loadout cheio ou sem espaço adequado).",
            remainingQuantity, itemBaseId))
    end

    return addedQuantity
end

--- Remove uma instância específica de item do loadout.
--- @param instanceId number ID da instância a remover.
--- @param quantity number (Opcional) Quantidade a remover. Se omitido ou >= quantidade atual, remove tudo.
--- @return boolean True se removeu com sucesso.
function LoadoutManager:removeItemInstance(instanceId, quantity)
    local instance = self.items[instanceId]
    if not instance then
        print("AVISO [LoadoutManager]: Tentativa de remover instância de item inexistente:", instanceId)
        return false
    end

    local quantityToRemove = quantity or instance.quantity

    if instance.stackable and quantityToRemove < instance.quantity then
        instance.quantity = instance.quantity - quantityToRemove
        return true
    else
        -- Remove a instância inteira
        -- <<< INÍCIO: CORREÇÃO PARA LIMPAR GRID >>>
        -- Calcula dimensões REAIS de ocupação baseadas na rotação ARMAZENADA
        local itemW = instance.gridWidth or 1
        local itemH = instance.gridHeight or 1
        local actualW = instance.isRotated and itemH or itemW
        local actualH = instance.isRotated and itemW or itemH

        ItemGridLogic.clearGridArea(self.grid, self.rows, self.cols, instanceId, instance.row, instance.col, actualW,
            actualH)

        self.items[instanceId] = nil
        return true
    end
end

--- Remove uma instância de item específica pelo ID.
-- Wrapper simples para consistência com LobbyStorageManager.
--- @param instanceId number ID da instância a remover.
--- @return boolean Retorna true se removeu, false caso contrário.
function LoadoutManager:removeItemByInstanceId(instanceId)
    local success = self:removeItemInstance(instanceId, nil) -- Chama a função existente para remover tudo
    if success then
        print(string.format("[LoadoutManager] Item %s removido.", instanceId))
    else
        print(string.format("AVISO [LoadoutManager] Tentativa de remover item %s (não encontrado)", instanceId))
    end
    return success
end

--- Adiciona um item em uma posição específica na grade.
--- Assume que canPlaceItemAt já foi chamado e retornou true.
---@param item table A instância do item a ser adicionado.
---@param targetRow integer Linha alvo (1-indexed).
---@param targetCol integer Coluna alvo (1-indexed).
---@param isRotated boolean|nil Se o item deve ser armazenado como rotacionado.
---@return boolean True se o item foi adicionado, false caso contrário.
function LoadoutManager:addItemAt(item, targetRow, targetCol, isRotated)
    if not item or not targetRow or not targetCol then
        print("ERRO (addItemAt - Loadout): Parâmetros inválidos.")
        return false
    end

    -- Usa as dimensões REAIS do item (rotação NÃO é aplicada aqui, apenas armazenada)
    local itemW = item.gridWidth or 1
    local itemH = item.gridHeight or 1

    -- Atualiza a posição e o estado de rotação do item
    item.row = targetRow
    item.col = targetCol
    item.isRotated = isRotated or false -- Armazena o estado de rotação

    -- Adiciona o item à lista
    self.items[item.instanceId] = item

    -- <<< INÍCIO: CORREÇÃO PARA MARCAR GRID >>>
    -- Calcula dimensões REAIS de ocupação baseadas na rotação ARMAZENADA
    local actualW = item.isRotated and itemH or itemW
    local actualH = item.isRotated and itemW or itemH

    ItemGridLogic.markGridOccupied(self.grid, self.rows, self.cols, item.instanceId, targetRow, targetCol, actualW,
        actualH)

    print(string.format("(Loadout) Item %s (%s) adicionado/atualizado em [%d,%d], Rotacionado: %s", item.instanceId,
        item.itemBaseId, targetRow,
        targetCol, tostring(item.isRotated)))
    return true
end

--- NOVO: Tenta adicionar uma instância de item específica em qualquer espaço livre.
--- Utiliza _findFreeSpace e addItemAt.
--- @param itemInstance table A instância completa do item a adicionar.
--- @return boolean True se conseguiu adicionar, false caso contrário.
function LoadoutManager:addItemInstance(itemInstance)
    if not itemInstance then return false end

    local width = itemInstance.gridWidth or 1
    local height = itemInstance.gridHeight or 1
    local freeSpace = ItemGridLogic.findFreeSpace(self.grid, self.rows, self.cols, width, height)

    if freeSpace then
        -- Reusa a lógica de addItemAt para colocar no espaço encontrado
        -- Passa isRotated como nil ou false por padrão aqui, pois estamos apenas adicionando, não movendo um item rotacionado
        return self:addItemAt(itemInstance, freeSpace.row, freeSpace.col, itemInstance.isRotated or false)
    else
        print(string.format("[LoadoutManager:addItemInstance] Sem espaço para item %s (%s)", itemInstance.instanceId,
            itemInstance.itemBaseId))
        return false
    end
end

-- == Funções Auxiliares ==

--- Helper interno para obter dados base do item (igual ao LobbyStorageManager).
function LoadoutManager:_getItemBaseData(itemBaseId)
    if self.itemDataManager and self.itemDataManager.getBaseItemData then
        return self.itemDataManager:getBaseItemData(itemBaseId)
    else
        print("AVISO [LoadoutManager]: itemDataManager ausente ou método getBaseItemData não encontrado.")
        return nil
    end
end

--- Helper interno para gerar ID único local para o loadout.
function LoadoutManager:_getNextInstanceId()
    local id = nextInstanceId
    nextInstanceId = nextInstanceId + 1
    return id
end

-- == Funções de Persistência ==

--- Salva o estado atual do loadout compartilhado.
--- @return boolean True se salvou com sucesso.
function LoadoutManager:saveState()
    print(string.format("[LoadoutManager] Saving shared state to %s...", SHARED_LOADOUT_SAVE_FILE))

    -- Cria uma cópia serializável dos itens
    local serializableItems = {}
    for instanceId, itemInstance in pairs(self.items or {}) do
        serializableItems[instanceId] = {
            instanceId = itemInstance.instanceId,
            itemBaseId = itemInstance.itemBaseId,
            quantity = itemInstance.quantity or 1,
            row = itemInstance.row,
            col = itemInstance.col,
            isRotated = itemInstance.isRotated or false,
            -- Não salva: gridWidth, gridHeight, stackable, maxStack, name, icon (vem do baseData)
        }
    end

    local dataToSave = {
        version = 1, -- Versão inicial do save compartilhado
        -- <<< REMOVIDO: Não salva mais rows/cols >>>
        -- rows = self.rows,
        -- cols = self.cols,
        items = serializableItems,
        nextInstanceId = nextInstanceId -- Salva o contador local (mantido)
    }

    local success = PersistenceManager.saveData(SHARED_LOADOUT_SAVE_FILE, dataToSave)
    if success then
        print("[LoadoutManager] Shared state saved successfully.")
    else
        print("ERROR [LoadoutManager]: Failed to save shared state.")
    end
    return success
end

--- Carrega o estado do loadout compartilhado.
--- @return boolean True se carregou com sucesso.
function LoadoutManager:loadState()
    print(string.format("[LoadoutManager] Loading shared state from %s...", SHARED_LOADOUT_SAVE_FILE))
    local loadedData = PersistenceManager.loadData(SHARED_LOADOUT_SAVE_FILE)

    if not loadedData or type(loadedData) ~= "table" then
        print("[LoadoutManager] No valid shared save data found. Using defaults.")
        -- Garante que começa com uma estrutura vazia e válida se não houver save
        self.rows = Constants.GRID_ROWS
        self.cols = Constants.GRID_COLS
        self:_createEmptyGrid(self.rows, self.cols)
        self.items = {}
        nextInstanceId = 1
        return false
    end

    -- TODO: Adicionar verificação de versão se necessário no futuro

    -- <<< MODIFICADO: Ignora dimensões salvas, usa Constantes >>>
    print("[LoadoutManager] Ignorando dimensões salvas (se houver), usando Constantes.")
    self.rows = Constants.GRID_ROWS
    self.cols = Constants.GRID_COLS
    -- self.rows = loadedData.rows or Constants.GRID_ROWS -- REMOVIDO
    -- self.cols = loadedData.cols or Constants.GRID_COLS -- REMOVIDO
    nextInstanceId = loadedData.nextInstanceId or 1 -- Carrega o contador (mantido)
    self.items = {}                                 -- Limpa itens atuais antes de carregar
    self:_createEmptyGrid(self.rows, self.cols)     -- Cria a grade com as dimensões das Constantes

    -- Reconstrói as instâncias de itens
    local loadedItemsData = loadedData.items or {}
    local itemCount = 0
    for instanceId, savedItemData in pairs(loadedItemsData) do
        local baseData = self:_getItemBaseData(savedItemData.itemBaseId)
        if baseData then
            local newItemInstance = {
                instanceId = savedItemData.instanceId,
                itemBaseId = savedItemData.itemBaseId,
                quantity = savedItemData.quantity,
                row = savedItemData.row,
                col = savedItemData.col,
                isRotated = savedItemData.isRotated,
                -- Recria dados derivados do baseData
                gridWidth = baseData.gridWidth or 1,
                gridHeight = baseData.gridHeight or 1,
                stackable = baseData.stackable or false,
                maxStack = baseData.maxStack or (baseData.stackable and 99) or 1,
                name = baseData.name,
                icon = baseData.icon,
                rarity = baseData.rarity or 'E'
            }
            self.items[newItemInstance.instanceId] = newItemInstance
            itemCount = itemCount + 1

            -- Marca a grade como ocupada
            local actualW = newItemInstance.isRotated and newItemInstance.gridHeight or newItemInstance.gridWidth
            local actualH = newItemInstance.isRotated and newItemInstance.gridWidth or newItemInstance.gridHeight
            ItemGridLogic.markGridOccupied(self.grid, self.rows, self.cols, newItemInstance.instanceId,
                newItemInstance.row, newItemInstance.col, actualW, actualH)
        else
            print(string.format(
                "WARNING [LoadoutManager]: Could not find base data for loaded item '%s' (instance %d). Item skipped.",
                savedItemData.itemBaseId, savedItemData.instanceId))
        end
    end

    print(string.format("[LoadoutManager] Load complete. Grid: %dx%d. Loaded %d items. Next ID: %d",
        self.rows, self.cols, itemCount, nextInstanceId))
    return true
end

return LoadoutManager
