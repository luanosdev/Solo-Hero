local PersistenceManager = require("src.core.persistence_manager")

---@class LoadoutManager
local LoadoutManager = {
    itemDataManager = nil ---@type ItemDataManager
}

LoadoutManager.__index = LoadoutManager

local DEFAULT_LOADOUT_ROWS = 8
local DEFAULT_LOADOUT_COLS = 4

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

    instance.rows = DEFAULT_LOADOUT_ROWS
    instance.cols = DEFAULT_LOADOUT_COLS
    instance.grid = {}  -- Grade 2D para referência rápida de ocupação
    instance.items = {} -- Tabela de instâncias de itens { [instanceId] = itemInstanceData }

    -- REMOVIDO: Carregamento não é feito no construtor, mas sim pelo HunterManager
    instance:_createEmptyGrid(instance.rows, instance.cols) -- Sempre começa vazio
    instance.items = {}                                     -- Garante que a tabela de itens esteja vazia
    nextInstanceId = 1                                      -- Reseta contador local

    print(string.format("[LoadoutManager] Pronto. Manager inicializado com grid %dx%d.",
        instance.rows, instance.cols))

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

-- == Funções de Manipulação de Itens ==

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
        local freeSpace = self:_findFreeSpace(width, height) -- Busca no grid do loadout

        if freeSpace then
            local instanceId = self:_getNextInstanceId() -- Usa o contador local do loadout
            local newItemInstance = {
                instanceId = instanceId,
                itemBaseId = itemBaseId,
                quantity = amountForThisInstance,
                row = freeSpace.row,
                col = freeSpace.col,
                gridWidth = width,
                gridHeight = height,
                stackable = stackable,
                maxStack = maxStack,
                name = baseData.name,
                icon = baseData.icon,
            }
            self.items[instanceId] = newItemInstance

            -- Marcar a grade
            for r = freeSpace.row, freeSpace.row + height - 1 do
                for c = freeSpace.col, freeSpace.col + width - 1 do
                    if self.grid[r] then
                        self.grid[r][c] = instanceId
                    end
                end
            end

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
        for r = instance.row, instance.row + (instance.gridHeight or 1) - 1 do
            for c = instance.col, instance.col + (instance.gridWidth or 1) - 1 do
                if self.grid[r] then
                    self.grid[r][c] = nil
                end
            end
        end
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
        print(string.format("[LoadoutManager] Item %d removido.", instanceId))
    else
        print(string.format("AVISO [LoadoutManager] Tentativa de remover item %d (não encontrado)", instanceId))
    end
    return success
end

--- Verifica se um item pode ser colocado na posição especificada.
-- Não modifica o estado, apenas verifica.
--- @param itemInstance table A instância do item a ser colocada.
--- @param targetRow number Linha alvo.
--- @param targetCol number Coluna alvo.
--- @return boolean True se o espaço estiver livre e dentro dos limites.
function LoadoutManager:canPlaceItemAt(itemInstance, targetRow, targetCol)
    if not itemInstance then return false end
    local width = itemInstance.gridWidth or 1
    local height = itemInstance.gridHeight or 1
    -- Usa a função _isAreaFree do próprio loadout
    return self:_isAreaFree(targetRow, targetCol, width, height)
end

--- Adiciona uma instância de item específica na posição dada.
-- Assume que a validade já foi checada com canPlaceItemAt.
--- @param itemInstance table A instância completa do item a ser adicionada.
--- @param targetRow number Linha alvo.
--- @param targetCol number Coluna alvo.
--- @return boolean True se adicionado com sucesso.
function LoadoutManager:addItemAt(itemInstance, targetRow, targetCol)
    if not itemInstance or not targetRow or not targetCol then
        print("ERRO [LoadoutManager:addItemAt]: Argumentos inválidos.")
        return false
    end

    local instanceId = itemInstance.instanceId
    local width = itemInstance.gridWidth or 1
    local height = itemInstance.gridHeight or 1

    -- Atualiza posição na instância
    itemInstance.row = targetRow
    itemInstance.col = targetCol

    -- Adiciona à tabela de itens
    self.items[instanceId] = itemInstance

    -- Marca a grade
    for r = targetRow, targetRow + height - 1 do
        for c = targetCol, targetCol + width - 1 do
            if self.grid[r] then
                self.grid[r][c] = instanceId
            else
                print(string.format("ERRO [LoadoutManager:addItemAt]: Linha %d inválida na grade ao marcar!", r))
            end
        end
    end
    print(string.format("[LoadoutManager:addItemAt] Item %d (%s) adicionado em [%d,%d]", instanceId,
        itemInstance.itemBaseId, targetRow, targetCol))
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
    local freeSpace = self:_findFreeSpace(width, height)

    if freeSpace then
        -- Reusa a lógica de addItemAt para colocar no espaço encontrado
        return self:addItemAt(itemInstance, freeSpace.row, freeSpace.col)
    else
        print(string.format("[LoadoutManager:addItemInstance] Sem espaço para item %d (%s)", itemInstance.instanceId,
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

--- Helper interno para verificar se uma área está livre no grid do loadout.
function LoadoutManager:_isAreaFree(startRow, startCol, width, height)
    if startRow < 1 or startRow + height - 1 > self.rows or startCol < 1 or startCol + width - 1 > self.cols then
        return false
    end
    for r = startRow, startRow + height - 1 do
        for c = startCol, startCol + width - 1 do
            if not self.grid[r] or self.grid[r][c] ~= nil then
                return false
            end
        end
    end
    return true
end

--- Helper interno para encontrar espaço livre no grid do loadout.
function LoadoutManager:_findFreeSpace(width, height)
    for r = 1, self.rows - height + 1 do
        for c = 1, self.cols - width + 1 do
            if self:_isAreaFree(r, c, width, height) then
                return { row = r, col = c }
            end
        end
    end
    return nil
end

-- == Funções de Persistência ==

--- Salva o estado atual do loadout para um caçador específico.
--- @param hunterId string ID do caçador para quem salvar o loadout.
--- @return boolean True se salvou com sucesso.
function LoadoutManager:saveLoadout(hunterId)
    if not hunterId then
        print("ERRO [LoadoutManager:saveLoadout]: hunterId não fornecido!")
        return false
    end
    local filename = string.format("loadout_%s.dat", hunterId) -- Nome dinâmico
    print(string.format("[LoadoutManager] Solicitando salvamento do loadout para '%s' em '%s'...", hunterId, filename))

    local dataToSave = {
        version = 1,
        rows = self.rows,
        cols = self.cols,
        items = {},
        nextInstanceId = nextInstanceId
    }

    for id, item in pairs(self.items) do
        dataToSave.items[id] = {
            itemBaseId = item.itemBaseId,
            quantity = item.quantity,
            row = item.row,
            col = item.col
        }
    end

    local success = PersistenceManager.saveData(filename, dataToSave)
    if success then
        print(string.format("[LoadoutManager] Loadout para '%s' salvo com sucesso.", hunterId))
    else
        print(string.format("ERRO [LoadoutManager]: Falha ao salvar loadout para '%s'.", hunterId))
    end
    return success
end

--- Carrega o estado do loadout de um caçador específico.
--- @param hunterId string ID do caçador de quem carregar o loadout.
--- @return boolean True se carregou com sucesso (ou arquivo não existe), False se houve erro de leitura/formato.
function LoadoutManager:loadLoadout(hunterId)
    if not hunterId then
        print("ERRO [LoadoutManager:loadLoadout]: hunterId não fornecido!")
        return false
    end
    local filename = string.format("loadout_%s.dat", hunterId) -- Nome dinâmico
    print(string.format("[LoadoutManager] Tentando carregar loadout para '%s' de '%s'...", hunterId, filename))

    local loadedData = PersistenceManager.loadData(filename)

    if loadedData then
        print("DEBUG: Dados crus carregados de", filename, ":")
        if loadedData.items then
            local count = 0
            for _ in pairs(loadedData.items) do count = count + 1 end
            print(string.format("  -> Tabela 'items' encontrada com %d entradas.", count))
        else
            print("  -> Tabela 'items' NÃO encontrada nos dados carregados.")
        end
    end

    -- Limpa estado atual ANTES de carregar
    self:_createEmptyGrid(self.rows, self.cols)
    self.items = {}
    nextInstanceId = 1 -- Reseta ID local

    if not loadedData then
        print(string.format("[LoadoutManager] Nenhum save encontrado para '%s'. Loadout permanecerá vazio.", hunterId))
        return true
    end

    if type(loadedData) ~= "table" or loadedData.version ~= 1 then
        print(string.format(
            "AVISO [LoadoutManager]: Dados de save para '%s' inválidos ou versão incompatível (versão %s). Ignorando save.",
            hunterId, tostring(loadedData.version or '??')))
        return false
    end

    self.rows = loadedData.rows or DEFAULT_LOADOUT_ROWS
    self.cols = loadedData.cols or DEFAULT_LOADOUT_COLS
    self:_createEmptyGrid(self.rows, self.cols)

    nextInstanceId = loadedData.nextInstanceId or 1
    local maxInstanceIdFound = 0

    if loadedData.items and type(loadedData.items) == "table" then
        for id, itemSaveData in pairs(loadedData.items) do
            local numInstanceId = tonumber(id)
            if numInstanceId then
                local baseData = self:_getItemBaseData(itemSaveData.itemBaseId)
                if baseData then
                    local width = baseData.gridWidth or 1
                    local height = baseData.gridHeight or 1
                    local newItemInstance = {
                        instanceId = numInstanceId,
                        itemBaseId = itemSaveData.itemBaseId,
                        quantity = itemSaveData.quantity,
                        row = itemSaveData.row,
                        col = itemSaveData.col,
                        gridWidth = width,
                        gridHeight = height,
                        stackable = baseData.stackable or false,
                        maxStack = baseData.maxStack or (baseData.stackable and 99) or 1,
                        name = baseData.name,
                        icon = baseData.icon,
                        rarity = baseData.rarity or 'E'
                    }
                    self.items[numInstanceId] = newItemInstance

                    for r = itemSaveData.row, itemSaveData.row + height - 1 do
                        for c = itemSaveData.col, itemSaveData.col + width - 1 do
                            if self.grid[r] and self.grid[r][c] == nil then
                                self.grid[r][c] = numInstanceId
                            else
                                print(string.format(
                                    "ERRO/AVISO [LoadoutManager]: Célula de grid [%d,%d] inválida ou já ocupada ao carregar item %d (%s) para '%s'. Verifique save ou lógica.",
                                    r, c, numInstanceId, itemSaveData.itemBaseId, hunterId))
                            end
                        end
                    end
                    maxInstanceIdFound = math.max(maxInstanceIdFound, numInstanceId)
                else
                    print(string.format(
                        "AVISO [LoadoutManager]: Não foi possível encontrar dados base para item '%s' (instância %d) ao carregar loadout de '%s'. Item ignorado.",
                        tostring(itemSaveData.itemBaseId), numInstanceId, hunterId))
                end
            else
                print(string.format(
                    "AVISO [LoadoutManager]: ID de instância inválido ('%s') encontrado ao carregar loadout de '%s'. Ignorando.",
                    tostring(id), hunterId))
            end
        end
    end

    if nextInstanceId <= maxInstanceIdFound then
        print(string.format(
            "AVISO [LoadoutManager]: nextInstanceId (%d) para '%s' era menor/igual ao maior ID carregado (%d). Ajustando para %d.",
            nextInstanceId, hunterId, maxInstanceIdFound, maxInstanceIdFound + 1))
        nextInstanceId = maxInstanceIdFound + 1
    end

    local itemCount = 0; for _ in pairs(self.items) do itemCount = itemCount + 1 end
    print(string.format("[LoadoutManager] Carregamento para '%s' concluído. %d itens carregados. Próximo ID local: %d",
        hunterId, itemCount, nextInstanceId))
    return true
end

return LoadoutManager
