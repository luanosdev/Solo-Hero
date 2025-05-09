--[[-
    Inventory Manager
    Gerencia os itens que o jogador possui em uma grade 2D.
]]

local InventoryManager = {}
InventoryManager.__index = InventoryManager

-- Contador simples para IDs de instância únicos
local nextInstanceId = 1

--[[-
    Inicializa o gerenciador de inventário.
    @param config (table): Tabela de configuração contendo { rows, cols, itemDataManager }
]]
function InventoryManager:init(config)
    config = config or {}
    self.rows = config.rows or 6 -- Padrão de inventory_screen
    self.cols = config.cols or 7 -- Padrão de inventory_screen
    
    -- REMOVIDO: ItemDataManager agora é injetado apenas pelo construtor (:new)
    -- self.itemDataManager = config.itemDataManager 

    -- Verifica se o itemDataManager foi injetado pelo construtor
    if not self.itemDataManager then
        print("ERRO CRÍTICO [InventoryManager]: itemDataManager não foi injetado via construtor!")
    else
        print("[InventoryManager:init] itemDataManager encontrado (injetado via construtor).")
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

    print(string.format("InventoryManager inicializado com grade %dx%d.", self.rows, self.cols))
end

-- Helper interno para obter dados base do item
function InventoryManager:_getItemBaseData(itemBaseId)
    if self.itemDataManager and self.itemDataManager.getBaseItemData then
        return self.itemDataManager:getBaseItemData(itemBaseId) -- Assumindo nome da função
    else
        print("AVISO [InventoryManager]: Não foi possível obter dados base para", itemBaseId, "- itemDataManager ausente ou função getBaseItemData não encontrada.")
        return nil -- Retorna nil se não puder buscar
    end
end

-- Helper interno para gerar ID único
function InventoryManager:_getNextInstanceId()
    local id = nextInstanceId
    nextInstanceId = nextInstanceId + 1
    return id
end

-- Helper interno para verificar se uma área está livre
function InventoryManager:_isAreaFree(startRow, startCol, width, height)
    -- Verifica limites primeiro
    if startRow < 1 or startRow + height - 1 > self.rows or startCol < 1 or startCol + width - 1 > self.cols then
        return false
    end
    -- Verifica cada célula na área
    for r = startRow, startRow + height - 1 do
        for c = startCol, startCol + width - 1 do
            if self.grid[r][c] ~= nil then
                return false -- Encontrou célula ocupada
            end
        end
    end
    return true -- Nenhuma célula ocupada encontrada
end

-- Helper interno para encontrar espaço livre
function InventoryManager:_findFreeSpace(width, height)
    for r = 1, self.rows - height + 1 do
        for c = 1, self.cols - width + 1 do
            if self:_isAreaFree(r, c, width, height) then
                return { row = r, col = c } -- Encontrou espaço
            end
        end
    end
    return nil -- Nenhum espaço encontrado
end

--[[-
    Adiciona um item (ou quantidade de um item) ao inventário.
    Tenta empilhar se possível, senão tenta encontrar espaço na grade.

    @param itemBaseId (string): O ID base do item a ser adicionado.
    @param quantity (number): A quantidade a ser adicionada.
    @return number: A quantidade que foi *realmente* adicionada (pode ser 0).
]]
function InventoryManager:addItem(itemBaseId, quantity)
    if not itemBaseId or not quantity or quantity <= 0 then return 0 end

    local baseData = self:_getItemBaseData(itemBaseId)
    if not baseData then return 0 end -- Não pode adicionar sem dados base

    local width = baseData.gridWidth or 1
    local height = baseData.gridHeight or 1
    local stackable = baseData.stackable or false
    local maxStack = baseData.maxStack or (stackable and 99) or 1 -- Define um maxStack padrão se empilhável
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
                print(string.format("Empilhado %d em %s (ID %d). Total: %d/%d", amountToStack, itemBaseId, id, instance.quantity, maxStack))
                if remainingQuantity <= 0 then break end -- Sai se já adicionou tudo
            end
        end
    end

    -- 2. Tentar Colocar Novos Stacks/Itens (se ainda houver quantidade restante)
    while remainingQuantity > 0 do
        local amountForThisInstance = stackable and math.min(remainingQuantity, maxStack) or 1 -- 1 para não empilháveis
        
        local freeSpace = self:_findFreeSpace(width, height)
        if freeSpace then
            local instanceId = self:_getNextInstanceId()
            local newItemInstance = {
                instanceId = instanceId,
                itemBaseId = itemBaseId,
                quantity = amountForThisInstance,
                row = freeSpace.row,
                col = freeSpace.col,
                -- Incluir dados base relevantes para fácil acesso
                gridWidth = width,
                gridHeight = height,
                stackable = stackable,
                maxStack = maxStack,
                -- Poderia adicionar outros como name, rarity aqui se útil
                name = baseData.name,
                rarity = baseData.rarity
            }
            self.placedItems[instanceId] = newItemInstance

            -- Marcar a grade
            for r = freeSpace.row, freeSpace.row + height - 1 do
                for c = freeSpace.col, freeSpace.col + width - 1 do
                    self.grid[r][c] = instanceId
                end
            end

            addedQuantity = addedQuantity + amountForThisInstance
            remainingQuantity = remainingQuantity - amountForThisInstance
            print(string.format("Colocado novo item/stack de %s (ID %d) em [%d,%d] com %d unidade(s).", itemBaseId, instanceId, freeSpace.row, freeSpace.col, amountForThisInstance))

            if not stackable and remainingQuantity > 0 then
                 print(string.format("Item %s não é empilhável, adicionando próxima instância.", itemBaseId))
             end
        else
            print(string.format("Sem espaço livre na grade para %s (%dx%d).", itemBaseId, width, height))
            break -- Sai do loop se não encontrar espaço
        end
    end

    if remainingQuantity > 0 then
        print(string.format("Não foi possível adicionar %d de %s (inventário cheio ou sem espaço adequado).", remainingQuantity, itemBaseId))
    end

    return addedQuantity
end

--[[-
    Remove uma instância específica de item do inventário.
    @param instanceId (number): O ID da instância a ser removida.
    @param quantity (number, optional): Quantidade a remover (se empilhável). Se omitido ou maior/igual à quantidade atual, remove a instância inteira.
    @return boolean: true se removeu com sucesso, false caso contrário.
]]
function InventoryManager:removeItemInstance(instanceId, quantity)
    local instance = self.placedItems[instanceId]
    if not instance then return false end

    local quantityToRemove = quantity or instance.quantity -- Remove tudo se não especificar quantidade

    if instance.stackable and quantityToRemove < instance.quantity then
        -- Remove apenas uma parte da pilha
        instance.quantity = instance.quantity - quantityToRemove
        print(string.format("Removido %d de %s (ID %d). Restante: %d", quantityToRemove, instance.itemBaseId, instanceId, instance.quantity))
        return true
    else
        -- Remove a instância inteira (não empilhável ou quantidade >= total)
        -- Limpa a grade
        for r = instance.row, instance.row + instance.gridHeight - 1 do
            for c = instance.col, instance.col + instance.gridWidth - 1 do
                if self.grid[r][c] == instanceId then -- Segurança extra
                    self.grid[r][c] = nil
                end
            end
        end
        -- Remove da lista de itens colocados
        self.placedItems[instanceId] = nil
        print(string.format("Removida instância %d (%s) de [%d,%d].", instanceId, instance.itemBaseId, instance.row, instance.col))
        return true
    end
end

--[[-
    Retorna a quantidade total de um item específico no inventário.
    @param itemBaseId (string): O ID base do item (ex: "jewel_E").
    @return number: A quantidade total do item, ou 0 se não encontrado.
]]
function InventoryManager:getItemCount(itemBaseId)
    local totalQuantity = 0
    for _, instance in pairs(self.placedItems) do
        if instance.itemBaseId == itemBaseId then
            totalQuantity = totalQuantity + instance.quantity
        end
    end
    return totalQuantity
end

--[[-
    Retorna uma lista de itens formatada para a UI.
    @return table: Lista de tabelas no formato { itemId, quantity, row, col }.
]]
function InventoryManager:getInventoryGridItems()
    local uiItems = {}
    for _, instance in pairs(self.placedItems) do
        table.insert(uiItems, {
            itemId = instance.itemBaseId,
            quantity = instance.quantity,
            row = instance.row,
            col = instance.col
            -- A UI buscará os dados base (tamanho) usando o itemId
        })
    end
    return uiItems
end

--[[-
    Retorna a instância do item que ocupa uma célula específica da grade.
    @param row (number): Linha da célula.
    @param col (number): Coluna da célula.
    @return table: A instância do item de `placedItems`, ou nil se a célula estiver vazia.
]]
function InventoryManager:getItemAt(row, col)
    if row < 1 or row > self.rows or col < 1 or col > self.cols then
        return nil -- Fora dos limites
    end
    local instanceId = self.grid[row][col]
    if instanceId then
        return self.placedItems[instanceId]
    end
    return nil
end

--[[-
    Retorna as dimensões da grade.
    @return table: { rows = number, cols = number }.
]]
function InventoryManager:getGridDimensions()
    return { rows = self.rows, cols = self.cols }
end

--[[-
    (Exemplo) Imprime o estado atual do inventário no console.
]]
function InventoryManager:printInventory()
    print(string.format("--- Inventário (%dx%d) --- ", self.rows, self.cols))
    local itemCount = 0
    for id, instance in pairs(self.placedItems) do
        print(string.format("  ID %d: %s (%dx%d) [%d,%d] Qtd: %d",
                          instance.instanceId, instance.itemBaseId, instance.gridWidth, instance.gridHeight,
                          instance.row, instance.col, instance.quantity))
        itemCount = itemCount + 1
    end

    if itemCount == 0 then
        print("  (Vazio)")
    end

    -- Opcional: Imprimir a grade visualmente
    print("  Grade Visual (IDs de Instância):")
    for r = 1, self.rows do
        local rowStr = "  |"
        for c = 1, self.cols do
            local cellContent = self.grid[r][c]
            if cellContent == nil then
                rowStr = rowStr .. " . |" -- Vazio
            else
                 rowStr = rowStr .. string.format("%2d", cellContent) .. "|" -- ID da instância
            end
        end
        print(rowStr)
    end

    print("-----------------")
end

-- Construtor simplificado (se necessário, mas a inicialização principal é via :init)
function InventoryManager:new(config)
    local instance = setmetatable({}, InventoryManager)
    config = config or {}

    -- Injeta dependências essenciais do config ANTES de chamar init
    if config.itemDataManager then
        instance.itemDataManager = config.itemDataManager
        print("[InventoryManager:new] Injetou itemDataManager com sucesso.")
    else
        print("ERRO CRÍTICO [InventoryManager:new]: itemDataManager não foi fornecido na config do construtor!")
        -- Considerar lançar um erro aqui se for absolutamente essencial
    end

    instance:init(config) -- Chama init (que agora pode usar a dependência injetada)
    return instance
end

--[[- 
    Retorna uma NOVA grade 2D contendo as instâncias de itens reais.
    A UI usará esta função.
    @return table: Grade 2D [row][col] contendo instâncias de self.placedItems ou nil.
]]
function InventoryManager:getInventoryGrid()
    local uiGrid = {}
    for r = 1, self.rows do
        uiGrid[r] = {}
        for c = 1, self.cols do
            -- Usa getItemAt para buscar a instância completa
            uiGrid[r][c] = self:getItemAt(r, c)
        end
    end
    return uiGrid
end

--[[- 
    Retorna a contagem total de instâncias de itens únicas no inventário.
    (Conta cada stack como 1, ou cada item não-empilhável como 1)
    @return number: O número de slots ocupados por itens únicos.
]]
function InventoryManager:getTotalItemCount()
    local count = 0
    for _ in pairs(self.placedItems) do
        count = count + 1
    end
    return count
end

return InventoryManager 