local PersistenceManager = require("src.core.persistence_manager")

---@class LoadoutManager
local LoadoutManager = {
    itemDataManager = nil ---@type ItemDataManager
}

LoadoutManager.__index = LoadoutManager

local SAVE_FILE = "loadout_save.dat"
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

    -- Tenta carregar dados existentes
    if not instance:loadLoadout() then
        print("[LoadoutManager] Nenhum save encontrado. Inicializando loadout vazio.")
        -- Inicializa grid vazia se o carregamento falhar
        instance:_createEmptyGrid(instance.rows, instance.cols)
        instance.items = {} -- Garante que a tabela de itens esteja vazia
        nextInstanceId = 1  -- Reseta contador local
    end

    print(string.format("[LoadoutManager] Pronto. Loadout %dx%d carregado/inicializado.",
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

-- == Funções Auxiliares ==

--- Helper interno para obter dados base do item (igual ao LobbyStorageManager).
function LoadoutManager:_getItemBaseData(itemBaseId)
    if self.itemDataManager and self.itemDataManager.getData then
        return self.itemDataManager:getData(itemBaseId)
    elseif self.itemDataManager and self.itemDataManager.getBaseItemData then
        return self.itemDataManager:getBaseItemData(itemBaseId)
    else
        print("AVISO [LoadoutManager]: itemDataManager ausente ou método de busca de dados não encontrado.")
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

--- Salva o estado atual do loadout.
function LoadoutManager:saveLoadout()
    print("[LoadoutManager] Solicitando salvamento do loadout...")
    local dataToSave = {
        version = 1,
        rows = self.rows, -- Salva dimensões caso mudem
        cols = self.cols,
        items = {},
        nextInstanceId = nextInstanceId -- Salva o próximo ID local
    }

    for id, item in pairs(self.items) do
        dataToSave.items[id] = {
            itemBaseId = item.itemBaseId,
            quantity = item.quantity,
            row = item.row,
            col = item.col
        }
    end

    local success = PersistenceManager.saveData(SAVE_FILE, dataToSave)
    if success then
        print("[LoadoutManager] Loadout salvo com sucesso.")
    else
        print("ERRO [LoadoutManager]: Falha ao salvar o loadout.")
    end
    return success
end

--- Carrega o estado do loadout do arquivo de save.
--- @return boolean True se carregou com sucesso, False caso contrário.
function LoadoutManager:loadLoadout()
    print("[LoadoutManager] Tentando carregar loadout...")
    local loadedData = PersistenceManager.loadData(SAVE_FILE)

    if not loadedData or type(loadedData) ~= "table" then
        print("[LoadoutManager] Nenhum dado de save válido encontrado para o loadout.")
        return false
    end

    if loadedData.version ~= 1 then
        print(string.format("AVISO [LoadoutManager]: Versão do save (%s) incompatível com a atual (1).",
            tostring(loadedData.version)))
        -- Adicionar lógica de migração aqui se necessário
    end

    -- Carrega dimensões (ou usa padrão se não salvas)
    self.rows = loadedData.rows or DEFAULT_LOADOUT_ROWS
    self.cols = loadedData.cols or DEFAULT_LOADOUT_COLS

    -- Carrega o próximo ID local
    nextInstanceId = loadedData.nextInstanceId or 1

    -- Recria a grade e os itens
    self:_createEmptyGrid(self.rows, self.cols) -- Cria grid com as dimensões carregadas/padrão
    self.items = {}                             -- Limpa itens antes de carregar
    local maxInstanceIdFound = 0
    local itemCount = 0                         -- Contador de itens carregados

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
                    }
                    self.items[numInstanceId] = newItemInstance
                    itemCount = itemCount + 1 -- Incrementa contador de itens

                    -- Marca a grade
                    for r = itemSaveData.row, itemSaveData.row + height - 1 do
                        for c = itemSaveData.col, itemSaveData.col + width - 1 do
                            if self.grid[r] and self.grid[r][c] == nil then
                                self.grid[r][c] = numInstanceId
                            else
                                print(string.format(
                                    "ERRO/AVISO [LoadoutManager]: Célula de grid [%d,%d] inválida ou já ocupada ao carregar item %d (%s).",
                                    r, c, numInstanceId, itemSaveData.itemBaseId))
                            end
                        end
                    end
                    maxInstanceIdFound = math.max(maxInstanceIdFound, numInstanceId)
                else
                    print(string.format(
                        "AVISO [LoadoutManager]: Não foi possível encontrar dados base para o item ID '%s' (instância %d) ao carregar save. Item ignorado.",
                        tostring(itemSaveData.itemBaseId), numInstanceId))
                end
            else
                print(string.format(
                    "AVISO [LoadoutManager]: ID de instância inválido ('%s') encontrado ao carregar itens. Ignorando.",
                    tostring(id)))
            end
        end
    end

    -- Ajusta nextInstanceId local
    if nextInstanceId <= maxInstanceIdFound then
        print(string.format("AVISO [LoadoutManager]: nextInstanceId local (%d) ajustado para %d.", nextInstanceId,
            maxInstanceIdFound + 1))
        nextInstanceId = maxInstanceIdFound + 1
    end

    print(string.format("[LoadoutManager] Carregamento concluído. %d itens carregados. Próximo ID local: %d",
        itemCount, nextInstanceId)) -- Usa o contador itemCount

    return true
end

return LoadoutManager
